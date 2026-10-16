#!/usr/bin/env python3
"""build verification category: xcodebuild build of the iOS app.

macOS: runs the xcodebuild presence probe (the R2 gate's
`xcodebuild-available` check, preserved verbatim) and then the project's
canonical build command (docs/tests.md, Recommended Verification Commands).
Linux: honest SKIP per the gate convention — SKIP is never success, never
fake, and never fails the run (LOC-82 A4; R2 2f9d16c semantics).
"""
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD_COMMAND = [
    "xcodebuild", "build",
    "-project", "OpenCodeClient/OpenCodeClient.xcodeproj",
    "-scheme", "OpenCodeClient",
    "-destination", "generic/platform=iOS Simulator",
]
TIMEOUT_SECONDS = 3600


def main():
    if shutil.which("xcodebuild") is None:
        print("SKIP xcodebuild-available  xcodebuild not available on this platform — "
              "NOT RUNNABLE ON LINUX, needs a macOS machine/runner")
        print("build: 0 passed, 0 failed, 1 skipped (SKIP is never success)")
        print("build: OK — nothing ran; macOS execution is still required")
        return 0
    try:
        probe = subprocess.run(["xcodebuild", "-version"], capture_output=True,
                               text=True, timeout=60)
    except subprocess.TimeoutExpired:
        print("FAIL xcodebuild-available  xcodebuild -version timed out", file=sys.stderr)
        return 1
    if probe.returncode != 0:
        print(f"FAIL xcodebuild-available  xcodebuild -version rc={probe.returncode}",
              file=sys.stderr)
        return 1
    print(f"PASS xcodebuild-available  {probe.stdout.strip().splitlines()[0]}")
    print(f"RUN build: {' '.join(BUILD_COMMAND)}", flush=True)
    try:
        proc = subprocess.run(BUILD_COMMAND, cwd=REPO_ROOT, timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print(f"FAIL ios-build  timed out after {TIMEOUT_SECONDS}s", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL ios-build  could not launch: {exc}", file=sys.stderr)
        return 1
    if proc.returncode != 0:
        print(f"FAIL ios-build  exit code {proc.returncode}", file=sys.stderr)
        return 1
    print("PASS ios-build")
    return 0


if __name__ == "__main__":
    sys.exit(main())
