#!/usr/bin/env python3
"""e2e verification category: the iOS UI-test suite.

macOS: execs ./scripts/test_ui.sh (Tier 2/4 XCUITest suites via the pinned
simulator). Linux: honest SKIP per the gate convention — SKIP is never
success, never fake, and never fails the run (LOC-82 A4; R2 2f9d16c semantics).
"""
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COMMAND = ["./scripts/test_ui.sh"]
TIMEOUT_SECONDS = 5400


def main():
    if shutil.which("xcodebuild") is None:
        print(f"SKIP ios-ui-tests  {COMMAND[0]} (OpenCodeClientUITests) — "
              "NOT RUNNABLE ON LINUX, needs a macOS machine/runner")
        print("e2e: 0 passed, 0 failed, 1 skipped (SKIP is never success)")
        print("e2e: OK — nothing ran; macOS execution is still required")
        return 0
    print(f"RUN e2e: {COMMAND}", flush=True)
    try:
        proc = subprocess.run(COMMAND, cwd=REPO_ROOT, timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print(f"FAIL ios-ui-tests  timed out after {TIMEOUT_SECONDS}s", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL ios-ui-tests  could not launch: {exc}", file=sys.stderr)
        return 1
    if proc.returncode != 0:
        print(f"FAIL ios-ui-tests  exit code {proc.returncode}", file=sys.stderr)
        return 1
    print("PASS ios-ui-tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
