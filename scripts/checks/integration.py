#!/usr/bin/env python3
"""integration verification category: the v2 contract gate, offline guard.

Linux: runs the same offline-guard proof the R2 gate ran —
scripts/v2_contract_check.py must refuse to run without V2_PASSWORD
(exit 2, no network), with V2_BASE/V2_USER/V2_PASSWORD stripped from the
environment so no server is ever contacted (R2 2f9d16c semantics, preserved
verbatim; AGENTS.md forbids automation touching the user's live server).

The live contract pass-rate run (V2_BASE + V2_PASSWORD against a dedicated
test server) is deliberately a human-invoked command, never triggered by this
wrapper or by `verify.py --ci` — see docs/TESTING.md and docs/RUNBOOKS.md.
"""
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(REPO_ROOT, "scripts", "v2_contract_check.py")


def main():
    if not os.path.isfile(SCRIPT):
        print("FAIL v2-contract-offline-guard  scripts/v2_contract_check.py missing",
              file=sys.stderr)
        return 1
    env = {k: v for k, v in os.environ.items()
           if k not in ("V2_BASE", "V2_USER", "V2_PASSWORD")}
    try:
        proc = subprocess.run([sys.executable, SCRIPT], capture_output=True,
                              text=True, timeout=60, env=env, cwd=REPO_ROOT)
    except subprocess.TimeoutExpired:
        print("FAIL v2-contract-offline-guard  offline guard run timed out", file=sys.stderr)
        return 1
    if proc.returncode == 2 and "V2_PASSWORD is required" in proc.stderr:
        print("PASS v2-contract-offline-guard  refuses to run without V2_PASSWORD "
              "(exit 2, no network); live contract run remains human-invoked")
        print("integration: 1 passed, 0 failed, 0 skipped (SKIP is never success)")
        print("integration: OK — all non-skipped checks passed")
        return 0
    print(f"FAIL v2-contract-offline-guard  expected exit 2 + V2_PASSWORD warning, "
          f"got rc={proc.returncode} stderr={proc.stderr.strip()[:120]!r}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
