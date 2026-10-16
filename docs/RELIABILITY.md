# Reliability and recoverability

- Critical flows/SLOs: (placeholders — to be quantified with the owner)
  connect-and-read works on LAN within seconds of app open; a sent
  instruction surfaces an error within the request timeout, never silently
  drops; streaming updates resume after backgrounding without a manual
  restart.
- Error logging/telemetry: no telemetry; failures surface in the UI
  (unified error handling pattern from code review 3.2), console logs, and
  CI logs. Polling parse noise is logged, not treated as disconnection
  (`docs/WORKING.md` Problem 7).
- Offline/retry behavior: SSE is the main channel with a one-shot
  compensating full sync on reconnect/session entry (`docs/lessons.md`
  lesson 9); after a send, a bounded 60-second polling fallback covers missed
  events; foreground transitions reconnect SSE. v2 part ids are
  reconnect-stable (`docs/v2_server_compatibility.md` SSE table), so
  streaming state survives reconnects without duplication.
- Recovery tests (anchors): `SSELifecycleTests` (connection lifecycle),
  `SessionDeletionRecoveryTests` (deleted-session handling),
  `QuestionWebPreviewRecoveryTests` (+ UITests) (question/web-preview
  recovery), send-failure input restoration (unit-tested), and the offline
  fixture UI suites that pin recovery behavior (`docs/TESTING.md`
  inventory).
- Rollback/release process: revert the offending commit on the integration
  branch and re-run the gate; releases are new TestFlight uploads (no server
  component) — disable/expire a bad build in TestFlight (`docs/RUNBOOKS.md`).
- Backup/restore/disaster recovery: repository state is the only durable
  artifact; device state is disposable by design. ASC signing material is
  reproducible from the stored certificate/profile secrets.

For important failures: record reproduction, root cause, detection gap, the
permanent test or alert added, and remaining exposure, tied to the tested
commit (`docs/REVIEW_EVIDENCE.md`). Repeated regressions are a
missing-harness signal — improve the harness instead of re-patching
symptoms.
