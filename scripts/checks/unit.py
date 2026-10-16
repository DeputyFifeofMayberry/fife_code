#!/usr/bin/env python3
"""unit verification category: the iOS app unit-test suite.

macOS: execs ./scripts/test_unit.sh (Tier 1+2 Swift Testing suite via the
pinned simulator). Linux: honest SKIP per the gate convention — SKIP is never
success, never fake, and never fails the run (LOC-82 A4; R2 2f9d16c semantics).
"""
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COMMAND = ["./scripts/test_unit.sh"]
TIMEOUT_SECONDS = 3600


def main():
    if shutil.which("xcodebuild") is None:
        print(f"SKIP ios-unit-tests  {COMMAND[0]} (OpenCodeClientTests) — "
              "NOT RUNNABLE ON LINUX, needs a macOS machine/runner")
        print("unit: 0 passed, 0 failed, 1 skipped (SKIP is never success)")
        print("unit: OK — nothing ran; macOS execution is still required")
        return 0
    print(f"RUN unit: {COMMAND}", flush=True)
    try:
        proc = subprocess.run(COMMAND, cwd=REPO_ROOT, timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print(f"FAIL ios-unit-tests  timed out after {TIMEOUT_SECONDS}s", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL ios-unit-tests  could not launch: {exc}", file=sys.stderr)
        return 1
    if proc.returncode != 0:
        print(f"FAIL ios-unit-tests  exit code {proc.returncode}", file=sys.stderr)
        return 1
    print("PASS ios-unit-tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
