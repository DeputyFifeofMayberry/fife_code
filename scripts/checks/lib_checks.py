"""Shared check library for the category wrappers in scripts/checks/.

Check logic is ported from the LOC-13 adoption gate (R2 commit 2f9d16c,
scripts/verify.py) so every functioning check survives the v2.2.1 migration
verbatim. Conventions are unchanged:

  - No fake passes: a check that cannot run here is SKIP + reason, never PASS.
  - A crashing check is a FAIL, never silently ignored.
  - The live v2 contract gate is never triggered by automation; only its
    offline guard runs, with V2_BASE/V2_USER/V2_PASSWORD stripped so no server
    is contacted.
  - SKIP is never success and never fails the run; any FAIL exits nonzero.

Adaptations from the R2 gate (documented in docs/decisions/ADR-0001-fife-foundation.md):
  - python-compile also scans scripts/checks/ (new in the v2.2.1 adoption).
  - foundation-config validates the v2.2.1 schema via scripts/verify.py's own
    parse_config() (the schema stores the doc contract in the gate, not in
    project.json).
  - required-docs sources the required list from scripts/verify.py's
    MANDATORY_DOCS (same reason).
"""

import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

PASS, FAIL, SKIP = "PASS", "FAIL", "SKIP"


class Result:
    def __init__(self, status, detail=""):
        self.status = status
        self.detail = detail


# --- Linux-runnable checks (ported from R2 2f9d16c scripts/verify.py) ---------

def check_python_compile():
    targets = []
    for sub in ("", "tests", "checks"):
        directory = os.path.join(REPO_ROOT, "scripts", sub)
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.endswith(".py"):
                targets.append(os.path.join(directory, name))
    if not targets:
        return Result(FAIL, "no python files found under scripts/")
    errors = []
    for path in targets:
        rel = os.path.relpath(path, REPO_ROOT)
        try:
            with open(path, "rb") as fh:
                source = fh.read()
            # In-memory compile only: never writes __pycache__, so the gate
            # also works on read-only checkouts (reviewer/QA mode).
            compile(source, path, "exec")
        except (SyntaxError, ValueError) as exc:
            errors.append(f"{rel}: {exc}")
        except OSError as exc:
            errors.append(f"{rel}: filesystem error: {exc}")
    if errors:
        return Result(FAIL, "; ".join(errors))
    return Result(PASS, f"{len(targets)} files compiled (in-memory; no bytecode written)")


def _load_gate_module():
    scripts_dir = os.path.join(REPO_ROOT, "scripts")
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    import verify
    return verify


def check_foundation_config():
    path = os.path.join(REPO_ROOT, ".foundation", "project.json")
    if not os.path.isfile(path):
        return Result(FAIL, ".foundation/project.json missing")
    try:
        import json
        with open(path, "r", encoding="utf-8") as fh:
            json.load(fh)
    except (OSError, ValueError) as exc:
        return Result(FAIL, f"invalid JSON: {exc}")
    try:
        _load_gate_module().parse_config()
    except (OSError, ValueError, TypeError) as exc:
        return Result(FAIL, f"schema validation failed: {exc}")
    return Result(PASS, "valid JSON; passes the gate's schema-v2 parse_config() validation")


def check_required_docs():
    try:
        verify = _load_gate_module()
    except (OSError, ValueError) as exc:
        return Result(SKIP, f"cannot load scripts/verify.py ({exc}); docs list unavailable")
    required = verify.MANDATORY_DOCS
    missing = [rel for rel in required
               if not os.path.isfile(os.path.join(REPO_ROOT, rel))]
    if missing:
        return Result(FAIL, "missing: " + ", ".join(missing))
    return Result(PASS, f"{len(required)} docs present")


def check_workflow_yaml():
    try:
        import yaml
    except ImportError:
        return Result(SKIP, "PyYAML not installed on this machine; workflows not parsed here")
    wf_dir = os.path.join(REPO_ROOT, ".github", "workflows")
    if not os.path.isdir(wf_dir):
        return Result(FAIL, ".github/workflows missing")
    errors = []
    count = 0
    for name in sorted(os.listdir(wf_dir)):
        if not name.endswith((".yml", ".yaml")):
            continue
        count += 1
        path = os.path.join(wf_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                doc = yaml.safe_load(fh)
        except Exception as exc:
            errors.append(f"{name}: {exc}")
            continue
        jobs = doc.get("jobs") if isinstance(doc, dict) else None
        if not isinstance(jobs, dict) or not jobs:
            errors.append(f"{name}: no jobs defined")
    if errors:
        return Result(FAIL, "; ".join(errors))
    return Result(PASS, f"{count} workflows parsed")


def check_v2_contract_offline_guard():
    script = os.path.join(REPO_ROOT, "scripts", "v2_contract_check.py")
    if not os.path.isfile(script):
        return Result(FAIL, "scripts/v2_contract_check.py missing")
    env = {k: v for k, v in os.environ.items()
           if k not in ("V2_BASE", "V2_USER", "V2_PASSWORD")}
    try:
        proc = subprocess.run([sys.executable, script], capture_output=True,
                              text=True, timeout=60, env=env, cwd=REPO_ROOT)
    except subprocess.TimeoutExpired:
        return Result(FAIL, "offline guard run timed out")
    if proc.returncode == 2 and "V2_PASSWORD is required" in proc.stderr:
        return Result(PASS, "refuses to run without V2_PASSWORD (exit 2, no network)")
    return Result(FAIL, f"expected exit 2 + V2_PASSWORD warning, got rc={proc.returncode} "
                        f"stderr={proc.stderr.strip()[:120]!r}")


def check_script_unit_tests():
    tests_dir = os.path.join(REPO_ROOT, "scripts", "tests")
    if not os.path.isdir(tests_dir):
        return Result(SKIP, "scripts/tests/ does not exist yet")
    try:
        proc = subprocess.run(
            [sys.executable, "-m", "unittest", "discover",
             "-s", tests_dir, "-t", os.path.dirname(tests_dir)],
            capture_output=True, text=True, timeout=300, cwd=REPO_ROOT)
    except subprocess.TimeoutExpired:
        return Result(FAIL, "script unit tests timed out")
    if proc.returncode == 0:
        lines = proc.stderr.strip().splitlines() or proc.stdout.strip().splitlines()
        return Result(PASS, lines[-1] if lines else "unittest discover OK")
    tail = (proc.stderr or proc.stdout).strip().splitlines()
    return Result(FAIL, " | ".join(tail[-3:]) if tail else f"unittest rc={proc.returncode}")


# --- macOS-gated checks (SKIP on Linux, never faked; R2 semantics) ------------

def _macos_skip(what):
    return Result(SKIP, f"{what} — NOT RUNNABLE ON LINUX, needs a macOS machine/runner")


def check_xcodebuild():
    if shutil.which("xcodebuild") is None:
        return _macos_skip("xcodebuild not available on this platform")
    try:
        proc = subprocess.run(["xcodebuild", "-version"], capture_output=True,
                              text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return Result(FAIL, "xcodebuild -version timed out")
    if proc.returncode == 0:
        return Result(PASS, proc.stdout.strip().splitlines()[0])
    return Result(FAIL, f"xcodebuild -version rc={proc.returncode}")


def check_macos_suite(rel):
    if shutil.which("xcodebuild") is None:
        return _macos_skip(f"xcodebuild unavailable; {rel} not executed here")
    return Result(SKIP, f"{rel} is run by its own CI job / manually on macOS, "
                        "not inside this gate")


# --- category registry ---------------------------------------------------------

# Mapping decision (Technical Lead, LOC-82; recorded in
# docs/decisions/ADR-0001-fife-foundation.md and docs/TESTING.md):
#   lint         = python-compile + workflow-yaml   (static syntax/parse layer)
#   typecheck    = foundation-config                (config schema validation)
#   security     = v2-contract-offline-guard        (credential-less refusal)
#   architecture = required-docs + script-unit-tests (docs + tooling architecture)
#   unit/e2e/build = macOS-only app gates (SKIP-honest on Linux)
#   integration  = v2 contract offline guard semantics (live run is human-invoked)
CATEGORIES = {
    "lint": [check_python_compile, check_workflow_yaml],
    "typecheck": [check_foundation_config],
    "security": [check_v2_contract_offline_guard],
    "architecture": [check_required_docs, check_script_unit_tests],
}


def run_category(category, checks):
    results = []
    for fn in checks:
        try:
            res = fn()
        except Exception as exc:  # a crashing check is a failure, never a pass
            res = Result(FAIL, f"check crashed: {exc!r}")
        results.append((fn.__name__.replace("check_", "", 1), res))
    width = max(len(name) for name, _ in results)
    failed = skipped = 0
    for name, res in results:
        print(f"{res.status:<4} {name:<{width}}  {res.detail}")
        if res.status == FAIL:
            failed += 1
        elif res.status == SKIP:
            skipped += 1
    passed = len(results) - failed - skipped
    print(f"{category}: {passed} passed, {failed} failed, {skipped} skipped "
          "(SKIP is never success)")
    if failed:
        print(f"{category}: FAIL — {failed} check(s) failed", file=sys.stderr)
        return 1
    print(f"{category}: OK — all non-skipped checks passed")
    return 0


def main(category):
    if category in CATEGORIES:
        return run_category(category, CATEGORIES[category])
    print(f"unknown category: {category}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: lib_checks.py <category>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
