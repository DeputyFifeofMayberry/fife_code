# yage fix work record

Records the local fixes we made on our own fork to opencode-official + oh-my-openagent (OMO), and the investigation process. `adhoc_jobs/opencode_ios_client/opencode-official` is a local checkout of the official opencode repository tracking origin/dev; `/private/tmp/oh-my-openagent/` is a source checkout of OMO 3.17.13.

## 2026-05-04 concurrent race of multiple generation fibers on the same sessionID

### Symptoms

After upgrading to OMO 3.17.x, when a user chatted with the main session in the web UI, it frequently showed "two or three thinkings running at once with similar but inconsistent content, accelerated context window consumption, and compaction also often running concurrently".

The hard evidence at the database level comes from the prod db (`~/.local/share/opencode/opencode.db`), for one user message of session `ses_20ac172c1ffe4DAFzQzpgSw0mx`: a single user message had 22 assistant messages hanging under it, all sharing the same parentID; the time series shows at least 6 sibling assistants with `finish=stop`, their input token usage not increasing, and the first two, 270ms apart, each independently called exactly the same `background_output(task_id=bg_xxx)`. A normal multi-step generation loop uses `tool-calls` for intermediate steps, `stop` for the last step, and then breaks out; this "multiple stops under one parent" shape can only be explained by multiple independent generation fibers writing to the same sessionID in parallel.

### Root cause

The sessionID-level mutex provided by the opencode server's `SessionRunState.defaultLayer` is not globally unique within the process.

`SessionRunState.defaultLayer` is re-`Layer.provide`d in four places:

1. `packages/opencode/src/effect/app-runtime.ts`
2. `packages/opencode/src/server/routes/instance/httpapi/server.ts`
3. `packages/opencode/src/session/prompt.ts` (provided by `SessionPrompt.defaultLayer`)
4. `packages/opencode/src/session/revert.ts` (provided by `SessionRevert.defaultLayer`)

Every `Layer.provide(SessionRunState.defaultLayer)` rebuilds that layer, triggering its internal `InstanceState.make(...)` to run `Effect.gen` once, which creates an independent `runners: Map<SessionID, Runner>`. Multiple `runners` Maps exist at the same time within one process for the same directory, each starting from empty.

Under concurrency:

- Request A uses layer instance 1's `SessionRunState`; `runners_v1.get(sessionID)` misses → `Runner.make` → starts fiber_A running `runLoop`.
- Request B uses layer instance 2's `SessionRunState`; `runners_v2.get(sessionID)` also misses → another `Runner.make` → starts fiber_B.
- Both fibers run `runLoop` on the same `sessionID`, each re-reading messages from the db, each doing step++, each writing tool calls into the `parts` table, each calling the LLM. The `SynchronizedRef` is effectively useless, because it protects the state of a single `Runner` instance and there are two `Runner` instances.

Daily user conversations rarely hit this race because normal conversation is naturally serial (the user sends one message, waits for the reply, then sends the next), and by the time the second prompt arrives the first is long idle. OMO 3.17.x has 7 hooks such as background-task notifications, `unstable-agent-babysitter`, `todo-continuation-enforcer`, and `compaction-context-injector/recovery` that proactively call `client.session.promptAsync(...)` while an existing fiber has not exited yet, exposing this already-broken lock most frequently.

### Key points of the investigation

1. **A different occurrence of the same phenomenon**: the first one seen in the prod db, session `ses_20b312218ffevzQP9joW0u5mYD`, also had 9 independent assistants under a single user message, the first two 270ms apart each calling background_output(`bg_66da62a9`), input tokens not accumulating, confirming real concurrency rather than a step chain.
2. **First-round misdiagnosis**: attributed the race to commit `5ba68a28 refactor(httpapi): scope async prompt fiber (#25213)`. That commit replaced `Effect.runFork` with `Effect.forkIn(scope, ...)` and removed the explicit `provideService(InstanceRef, ...)`, raising the suspicion that the forked fiber lost its per-request InstanceRef binding and obtained a different InstanceState. Shipped one round of a fix that explicitly provided InstanceRef + WorkspaceRef to the forked fiber; after deploying, the race had not disappeared and the db again showed 22 stop siblings for the same user.
3. **Adding traces for empirical evidence**: added `Effect.logInfo` to the reuse/create branches of `SessionRunState.runner` and stamped each InstanceState instance with a random `mapId`. After restarting the server, the logs showed 0 reuse / 9 create; the second prompt for the same sessionID still created instead of reusing, confirming the race lived at the multiple-`runners`-Map layer rather than the fiber binding layer.
4. **More traces, looking at the cache**: added `cacheSize / cacheHit / cacheKeys` logs to `InstanceStore.load` and saw the same directory `/Users/grapeot/co/knowledge_working` booted twice under different InstanceStore instances (once by AppRuntime during startup, once by the HTTP server at startup), and `SessionRunState` showed two different `mapId`s across multiple prompts.
5. **Pinned down the repeated Layer builds**: grepping `SessionRunState.defaultLayer` showed the four `Layer.provide` sites, confirming this as the root cause of the layer reference being built into multiple service instances at different locations.

### Fix

`packages/opencode/src/session/run-state.ts`: moved the `runners` Map to the module top level as `sharedRunners`, so all `SessionRunState` layer instances share one Map. The scope still exists per InstanceState for forking the run fiber, but the sessionID lock is decoupled from the number of layer instances.

```ts
// module top-level
const sharedRunners = new Map<SessionID, Runner.Runner<MessageV2.WithParts>>()

// in layer init
return { runners: sharedRunners, scope, __id }
```

The finalizer no longer calls `runners.clear()`, because this Map is now process-wide and other layer instances may still be using it. Active runners are cancelled when their own fiber scope closes; the normal lifecycle does not depend on this finalizer for cleanup.

Post-deploy verification: consecutive prompts in the same main session produced a single fiber per run and 1 user → ≤4 sequential assistants under a single user message (tool-calls in the middle, stop at the end); the race was gone.

### Diagnostic traces removed

The `mapId` + `sharedRunners.size` logs added to `packages/opencode/src/session/run-state.ts` during the investigation, and the `InstanceStore.load called` log in `packages/opencode/src/project/instance-store.ts`, were all removed after the fix was verified (commit `ae98a8c7 chore(server): remove sessionID race diagnostics now that fix is verified`), and `bun run build` repackaged `packages/opencode/dist/opencode-darwin-arm64/bin/opencode`. The structural fix of hoisting `sharedRunners` to module scope is unchanged.

The next start of the opencode web server uses this new binary by default. No server is currently running; start one manually when needed. When starting it, cd into the target working directory (for example `/Users/grapeot/co/knowledge_working`); the server inherits that cwd as the directory of the initial InstanceState.

### One more fix that came along (kept)

`packages/opencode/src/server/routes/instance/httpapi/handlers/session.ts`: explicitly `provideService(InstanceRef, instance)` + `provideService(WorkspaceRef, workspace)` for the forked fiber before `forkIn`. This is the fix from the misdiagnosis path above; on its own it is also reasonable (it restores the semantics from before commit `5ba68a28`, avoiding a forked async prompt fiber resolving to the wrong instance under some timing), it does not conflict with the real fix, and it stays in place.

## 2026-05-04 OMO 3.17.13 background_output "Task not found" race (fixed)

### Symptoms

After OMO sent the `[ALL BACKGROUND TASKS COMPLETE]` system notification to the parent session, the model immediately called `background_output(task_id="bg_xxxxxx")`, and **the first call returned `Task not found`; retrying once with the same id immediately got the result**. This race is not rare in daily use; it still occurred after the race fix was deployed, so it is unrelated to the server lock we had just fixed and is an internal OMO timing problem.

The practical workaround recorded in memory (`feedback*` / `reference*`) was "retry once immediately on the first not found", but the root cause had not been pinned down.

### Code path identified so far

`/private/tmp/oh-my-openagent/src/tools/background-task/create-background-output.ts:61` calls `manager.getTask(args.task_id)` and returns `Task not found: <id>` directly when it gets `undefined`. On the manager side, the `tasks: Map<string, BackgroundTask>` is set in `BackgroundManager.addTask` (`features/background-agent/manager.ts:328-337`), and task.id looks like `bg_<8 hex>` (manager.ts:396).

The only deletion path is `removeTask` (339-341), called by `scheduleTaskRemoval` after `setTimeout(..., TASK_CLEANUP_DELAY_MS=10min)`. So "not found right after the notification" is not premature cleanup.

### Two suspicions not yet verified

1. **Multiple BackgroundManager instances**: a possibility isomorphic to the server-side multiple `runners` instances just fixed. If the OMO plugin gets initialized multiple times across multi-directory / multi-layer paths, each manager has its own `tasks` Map, and the manager that sends the notification is not the one that serves the tool call.
2. **task.id inconsistent between notification and registration**: in theory the manager sent the notification before the task reached `addTask`; or the task was reissued a new id while the notification carried the old one.

Next step: add traces at `BackgroundManager.addTask` / `getTask` / `notifyParentSession` (logging the manager instance id + tasks Map size + the task id being operated on); one reproduction after a restart would settle it.

### Empirical evidence

Cloned the OMO source locally to `adhoc_jobs/opencode_ios_client/oh-my-openagent`, checked out the 3.17.13 tag, ran `bun install && bun run build`, and changed the plugin entry in `~/.config/opencode/opencode.json` from `oh-my-openagent@3.17.13` to the local absolute path, so the opencode plugin loader goes through the file path channel (`pluginSource(spec)` hits `isPathPluginSpec`).

Added traces in the `BackgroundManager` constructor / `addTask` / `getTask` / `removeTask`: each instance gets a random 6-character `__omoMgrId`, and each operation logs `mgrId` + `taskId` + `tasks Map size` + all current keys. OMO's own `log()` writes through `os.tmpdir()` to `/var/folders/.../T/oh-my-opencode.log` (on macOS this is not `/tmp`; you need the concrete directory from `os.tmpdir()` to tail it).

First reproduction (the Sisyphus orchestrator had a sub-agent run a minimal echo):

```
[03:02:13.836] addTask  mgrId=cmat84  taskId=bg_e6a5c0c1  mapSize=1
[03:02:13.837] getTask  mgrId=cmat84  taskId=bg_e6a5c0c1  hit=yes
[03:02:13.938] getTask  mgrId=cmat84  taskId=bg_e6a5c0c1  hit=yes (×2)
[03:03:14.759] getTask  mgrId=yga2vq  taskId=bg_e6a5c0c1  hit=NO   mapSize=0  keys=[]
```

The `tasks` Maps of different `mgrId`s cannot see each other. Within the same process and the same directory, the opencode plugin loader re-`import()`s a fresh copy of the plugin on every boot along the InstanceState bootstrap path (the log directly shows `service=plugin path=oh-my-openagent@... loading plugin` appearing more than once); each plugin copy constructs its own BackgroundManager with its own tasks Map.

The notification was registered using the task on mgrId=cmat84, but the later `background_output(task_id=bg_e6a5c0c1)` tool call routed by the server landed in another plugin copy's tool closure, so it looked up the tasks Map of mgrId=yga2vq and not found was inevitable. The two same-id retries happened to hit the original manager's tool registration, which is why "one retry fixed it".

### Fix

`src/features/background-agent/manager.ts`: hoisted all five task-state Maps of BackgroundManager to the module top level as `SHARED_*`:

```ts
const SHARED_TASKS: Map<string, BackgroundTask> = new Map()
const SHARED_TASKS_BY_PARENT_SESSION: Map<string, Set<string>> = new Map()
const SHARED_NOTIFICATIONS: Map<string, BackgroundTask[]> = new Map()
const SHARED_PENDING_NOTIFICATIONS: Map<string, string[]> = new Map()
const SHARED_PENDING_BY_PARENT: Map<string, Set<string>> = new Map()
```

In the constructor, `this.tasks = SHARED_TASKS` and the like replace the original `new Map()` calls. task.id is `bg_<8 hex>`, unique process-wide, and sessionID `ses_xxx` is also process-wide unique, so sharing the key space across instances has no conflicts. Structurally this mirrors the earlier fix of the server `runners` Map.

The shutdown path `tasks.clear() / ...` behavior is preserved. Shutdown only triggers in the process exit signal handler (`process-cleanup.ts`); when the process is exiting anyway, clearing everything is fine, and there is no path where one manager shutting down alone wipes another's state.

### Verification

`bun run build` repackaged OMO; `kill -9` on the old opencode server, then restarted the web server from the `cd /Users/grapeot/co/knowledge_working` cwd.

Running the same background-agent task again, the key trace:

```
[03:05:11] BackgroundManager constructor mgrId=30ty70 dir=/Users/grapeot/co/knowledge_working
[03:05:26] BackgroundManager constructor mgrId=0huwx9 dir=/Users/grapeot/co/knowledge_working
[03:05:36] addTask  mgrId=30ty70  taskId=bg_a8321bf7  mapSize=1
[03:05:36] getTask  mgrId=30ty70  taskId=bg_a8321bf7  hit=yes
[03:05:47] [background-agent] notifyParentSession bg_a8321bf7 ; Task completed via session.idle
[03:05:53] getTask  mgrId=0huwx9  taskId=bg_a8321bf7  hit=YES   keys=["bg_a8321bf7"]
```
The two BackgroundManager instances still exist (the plugin multi-instance behavior itself was untouched), but the second manager can now find the task the first manager added, proving the `tasks` Map is process-wide shared. This is exactly the "not found right after the notification" moment from the user-reported path; after the fix, the cross-manager lookup hits directly.

### Deployment

OMO runs as a local file path plugin, with the configuration hardcoded in `~/.config/opencode/opencode.json` as `plugin: ["/Users/grapeot/co/.../oh-my-openagent"]`. To upgrade OMO's upstream version later, a local git fetch + rebase + fresh `bun run build` is needed, keeping these five SHARED local modifications. A future option is proposing an upstream OMO PR to turn the tasks/notifications maps into a module-level singleton or to fall back to an explicit `globalThis.__omoBackgroundManagerState__`.

### Diagnostic traces removed

The `__omoMgrId` + `addTask/getTask/removeTask` omo-trace was removed from the source after the fix was verified (commit `d5357f77 chore(background-agent): remove omo-trace diagnostics now that fix is verified`), and the OMO bundle was rebuilt. The local historical log file `/var/folders/.../T/oh-my-opencode.log` (grown to 170 MB) was also trashed. The structural fix of the five SHARED Maps is retained.

### The remaining more upstream problem (unfixed)

The opencode plugin loader initializes multiple plugin instances within the same process and directory; the SHARED Map fix **works around** this problem rather than **curing** it. The complete fix is for the opencode server to make plugin init per-process (rather than per-InstanceState), so there is truly only one BackgroundManager. That is equivalent to "direction B" of the earlier server `runners` race: a large invasive surface and high risk, left as a later task. The SHARED Map already makes the race observed on the OMO side disappear, so it is in use for now.
