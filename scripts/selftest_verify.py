#!/usr/bin/env python3
"""Adversarial regression tests for the project verifier; no real repo files edited."""
from __future__ import annotations
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from unittest import mock

BASE = Path(__file__).resolve().parents[1]
NAMES = ('lint', 'typecheck', 'unit', 'integration', 'e2e', 'build', 'security', 'architecture')
REQUIRED_DOCS = (
    'AGENTS.md', 'README.md', 'docs/USER_GUIDE.md', 'docs/INDEX.md', 'docs/CHECKLISTS.md',
    'CHANGELOG.md', 'docs/RUNBOOKS.md', 'docs/REVIEW_EVIDENCE.md', 'docs/TECH_DEBT.md',
    'ARCHITECTURE.md', 'docs/BASELINE.md', 'docs/PRODUCT.md', 'docs/PRODUCT_SENSE.md',
    'docs/DESIGN.md', 'docs/FRONTEND.md', 'docs/TESTING.md',
    'docs/SECURITY.md', 'docs/RELIABILITY.md', 'docs/QUALITY_SCORE.md',
)

class VerifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for rel in REQUIRED_DOCS:
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('# Configured\nReal project-specific content.\n', encoding='utf-8')
        script = self.root/'scripts/verify.py'
        script.parent.mkdir(parents=True, exist_ok=True)
        script.write_bytes((BASE/'scripts/verify.py').read_bytes())
        for filename, content in {
            'check_ok.py': 'raise SystemExit(0)\n',
            'check_bad.py': 'raise SystemExit(9)\n',
            'check_wait.py': 'import time; time.sleep(3)\n',
        }.items():
            (self.root/filename).write_text(content, encoding='utf-8')
        self.config_path = self.root/'.foundation/project.json'
        self.config_path.parent.mkdir(parents=True)
        self.cfg = {
            'schema_version': 2, 'project_name': 'example',
            'checks': {name: {'argv': [sys.executable, 'check_ok.py'], 'timeout_seconds': 4} for name in NAMES},
            'required_ci_checks': list(NAMES),
        }
        self.save()

    def save(self):
        self.config_path.write_text(json.dumps(self.cfg), encoding='utf-8')

    def run_verify(self, *args):
        return subprocess.run([sys.executable, str(self.root/'scripts/verify.py'), *args], capture_output=True, text=True)

    def test_success(self):
        result = self.run_verify('--ci')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertGreaterEqual(result.stdout.count('PASS '), 8)

    def test_failing_command(self):
        self.cfg['checks']['e2e']['argv'] = [sys.executable, 'check_bad.py']
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_unconfigured_command(self):
        self.cfg['checks']['unit']['argv'] = []
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_cannot_drop_required_gate(self):
        del self.cfg['checks']['e2e']
        self.cfg['required_ci_checks'].remove('e2e')
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_cannot_duplicate_check(self):
        self.cfg['required_ci_checks'][-1] = 'unit'
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_missing_document(self):
        (self.root/'docs/SECURITY.md').unlink()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_missing_changelog(self):
        (self.root/'CHANGELOG.md').unlink()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_missing_runbooks(self):
        (self.root/'docs/RUNBOOKS.md').unlink()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_missing_review_evidence(self):
        (self.root/'docs/REVIEW_EVIDENCE.md').unlink()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_missing_tech_debt(self):
        (self.root/'docs/TECH_DEBT.md').unlink()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_not_applicable_headless_pass(self):
        (self.root/'docs/DESIGN.md').unlink()
        (self.root/'docs/FRONTEND.md').unlink()
        self.cfg['not_applicable'] = {
            'docs/DESIGN.md': 'Headless service; no user interface surface.',
            'docs/FRONTEND.md': 'API-only project; no frontend runtime.',
        }
        self.save()
        self.assertEqual(self.run_verify('--ci').returncode, 0)

    def test_not_applicable_empty_reason_fails(self):
        self.cfg['not_applicable'] = {'docs/DESIGN.md': '   '}
        self.save()
        result = self.run_verify('--check', 'unit')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not_applicable', result.stderr)

    def test_not_applicable_non_whitelisted_path_fails(self):
        self.cfg['not_applicable'] = {'docs/SECURITY.md': 'Handled by the platform security team.'}
        self.save()
        result = self.run_verify('--check', 'unit')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not_applicable', result.stderr)

    def test_not_applicable_with_todo_content_fails(self):
        (self.root/'docs/DESIGN.md').write_text('TODO_REQUIRED', encoding='utf-8')
        self.cfg['not_applicable'] = {'docs/DESIGN.md': 'No UI planned.'}
        self.save()
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_not_applicable_malformed_object_fails(self):
        self.cfg['not_applicable'] = ['docs/DESIGN.md']
        self.save()
        result = self.run_verify('--check', 'unit')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not_applicable', result.stderr)

    def test_todo_document(self):
        (self.root/'docs/DESIGN.md').write_text('TODO_REQUIRED', encoding='utf-8')
        self.assertNotEqual(self.run_verify('--check','unit').returncode, 0)

    def test_broken_local_link(self):
        (self.root/'README.md').write_text('[Missing](docs/does-not-exist.md)\n', encoding='utf-8')
        self.assertNotEqual(self.run_verify('--check', 'unit').returncode, 0)

    def test_timeout(self):
        self.cfg['checks']['unit'] = {'argv':[sys.executable,'check_wait.py'], 'timeout_seconds':1}
        self.save()
        result = self.run_verify('--check','unit')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('timed out', result.stderr)

    def test_reject_noop(self):
        self.cfg['checks']['build']['argv'] = ['echo', 'OK']
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_reject_inline_noop(self):
        self.cfg['checks']['build']['argv'] = [sys.executable,'-c','print(1)']
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_bad_schema(self):
        self.cfg['schema_version'] = 1
        self.save()
        self.assertNotEqual(self.run_verify('--ci').returncode, 0)

    def test_list_available_before_initialization(self):
        self.cfg['project_name'] = 'TODO_REQUIRED'
        self.save()
        self.assertEqual(self.run_verify('--list').returncode, 0)

FIXTURE_WORKFLOW = """\
name: Fixture
on: [push]
jobs:
  maintenance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - name: Passing step
        run: python scripts/fixture_ok.py
      - name: Passing block step
        run: |
          python scripts/fixture_ok.py
          python scripts/fixture_ok.py
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Passing step
        run: python scripts/fixture_ok.py
  verify:
    runs-on: ubuntu-latest
    steps:
      - name: Failing step
        run: python scripts/fixture_bad.py
  matrixjob:
    strategy:
      matrix:
        python: ['3.11', '3.12']
    runs-on: ubuntu-latest
    steps:
      - run: python scripts/fixture_ok.py
  conditional:
    if: ${{ github.event_name == 'push' }}
    runs-on: ubuntu-latest
    steps:
      - run: python scripts/fixture_ok.py
  usesonly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
"""

UNRELATED_STEP_ENV_WORKFLOW = """\
name: Adopter-owned release checks
on: [push]
jobs:
  testflight:
    name: TestFlight upload
    runs-on: ubuntu-latest
    steps:
      - name: Upload to TestFlight
        env:
          API_KEY: ${{ secrets.API_KEY }}
        run: echo uploaded
"""

DISPLAY_NAME_MISMATCH_WORKFLOW = """\
name: Deploy previews
on: [push]
jobs:
  verify:
    name: Deploy previews
    environment: preview
    runs-on: ubuntu-latest
    steps:
      - run: echo deployed
"""

INLINE_COMMENT_NAME_WORKFLOW = """\
name: Duplicate verify
on: [push]
jobs:
  verifydup:
    name: verify # duplicate check
    environment: preview
    runs-on: ubuntu-latest
    steps:
      - run: echo duplicate
"""

class RequiredChecksTests(unittest.TestCase):
    """Protected-branch regression scenarios (c), (d), (f), (g); scenarios (a), (b), and the hosted half of (e) need GitHub enforcement and are executed per docs/RUNBOOKS.md (GitHub setup step 6)."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        workflow_dir = self.root/'.github/workflows'
        workflow_dir.mkdir(parents=True)
        (workflow_dir/'ci.yml').write_text(FIXTURE_WORKFLOW, encoding='utf-8')
        (self.root/'scripts').mkdir()
        (self.root/'scripts/fixture_ok.py').write_text('raise SystemExit(0)\n', encoding='utf-8')
        (self.root/'scripts/fixture_bad.py').write_text('print("deliberate failure"); raise SystemExit(9)\n', encoding='utf-8')

    def run_check(self, *args):
        return subprocess.run(
            [sys.executable, str(Path(__file__).resolve().parent/'check_required_checks.py'),
             '--root', str(self.root), *args],
            capture_output=True, text=True, cwd=str(self.root), timeout=120,
        )

    def test_configured_required_check_passes(self):
        result = self.run_check('--required', 'maintenance', '--timeout-seconds', '60')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('OK maintenance', result.stdout)

    def test_multiple_required_names_pass(self):
        result = self.run_check('--required', 'maintenance,lint', '--timeout-seconds', '60')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nonexistent_required_check_fails(self):
        result = self.run_check('--required', 'nonexistent')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('nonexistent', result.stderr)

    def test_red_required_check_fails_release_readiness(self):
        result = self.run_check('--required', 'verify')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('fails on the current tree', result.stderr)

    def test_matrix_job_not_locally_verifiable(self):
        result = self.run_check('--required', 'matrixjob')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('matrix strategy', result.stderr)

    def test_conditional_job_not_locally_verifiable(self):
        result = self.run_check('--required', 'conditional')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('conditional', result.stderr)

    def test_uses_only_job_not_locally_verifiable(self):
        result = self.run_check('--required', 'usesonly')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no runnable', result.stderr)

    def test_missing_workflow_directory_fails_closed(self):
        for path in (self.root/'.github/workflows/ci.yml',):
            path.unlink()
        (self.root/'.github/workflows').rmdir()
        self.assertNotEqual(self.run_check('--required', 'maintenance').returncode, 0)

    def test_unconfigured_adopter_verify_fails_closed(self):
        script = self.root/'scripts/verify.py'
        script.write_bytes((BASE/'scripts/verify.py').read_bytes())
        workflow_dir = self.root/'.github/workflows'
        (workflow_dir/'ci.yml').unlink()
        (workflow_dir/'ci.yml').write_text(
            FIXTURE_WORKFLOW.replace('python scripts/fixture_bad.py', 'python scripts/verify.py --ci'),
            encoding='utf-8',
        )
        result = self.run_check('--required', 'verify', '--timeout-seconds', '60')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('fails on the current tree', result.stderr)

    def test_unrelated_workflow_step_env_does_not_fail_gate(self):
        (self.root/'.github/workflows'/'check-testflight.yml').write_text(
            UNRELATED_STEP_ENV_WORKFLOW, encoding='utf-8')
        result = self.run_check('--required', 'maintenance', '--timeout-seconds', '60')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('not validated', result.stdout)

    def test_required_check_workflow_step_env_fails_closed(self):
        (self.root/'.github/workflows/ci.yml').write_text(
            FIXTURE_WORKFLOW.replace(
                '  maintenance:\n    runs-on: ubuntu-latest\n    steps:\n'
                '      - uses: actions/checkout@v7\n        with:\n          persist-credentials: false\n'
                '      - name: Passing step\n        run: python scripts/fixture_ok.py\n',
                '  maintenance:\n    runs-on: ubuntu-latest\n    steps:\n'
                '      - name: Sign build\n        env:\n          API_KEY: ${{ secrets.API_KEY }}\n'
                '        run: python scripts/fixture_ok.py\n'),
            encoding='utf-8')
        result = self.run_check('--required', 'maintenance')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('maintenance', result.stderr)
        self.assertIn('cannot be validated', result.stderr)

    def test_display_name_mismatch_not_recorded_as_required_check(self):
        (self.root/'.github/workflows'/'ci.yml').write_text(
            FIXTURE_WORKFLOW.replace('python scripts/fixture_bad.py', 'python scripts/fixture_ok.py'),
            encoding='utf-8')
        (self.root/'.github/workflows'/'deploy.yml').write_text(
            DISPLAY_NAME_MISMATCH_WORKFLOW, encoding='utf-8')
        result = self.run_check('--required', 'maintenance,verify', '--timeout-seconds', '60')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('deploy.yml', result.stdout)
        self.assertIn('not validated', result.stdout)

    def test_inline_comment_job_name_matches_required_check(self):
        (self.root/'.github/workflows'/'duplicate.yml').write_text(
            INLINE_COMMENT_NAME_WORKFLOW, encoding='utf-8')
        result = self.run_check('--required', 'verify')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('duplicate.yml', result.stderr)
        self.assertIn('cannot be validated', result.stderr)

    def test_unreadable_workflow_fails_closed(self):
        unreadable = self.root/'.github/workflows'/'restricted.yml'
        unreadable.write_text(
            'name: Restricted\non: [push]\njobs:\n  other:\n    runs-on: ubuntu-latest\n'
            '    steps:\n      - run: echo restricted\n', encoding='utf-8')
        script_path = Path(__file__).resolve().parent/'check_required_checks.py'
        spec = importlib.util.spec_from_file_location('check_required_checks_injected', script_path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        original_read_text = Path.read_text

        def injected_read_text(path_self, *args, **kwargs):
            if path_self.name == 'restricted.yml':
                raise OSError(13, 'simulated unreadable workflow (injected fault)')
            return original_read_text(path_self, *args, **kwargs)

        stderr = io.StringIO()
        with mock.patch.object(Path, 'read_text', injected_read_text):
            with redirect_stderr(stderr):
                returncode = module.main(
                    ['--root', str(self.root), '--required', 'maintenance',
                     '--timeout-seconds', '60'])
        self.assertNotEqual(returncode, 0)
        self.assertIn('restricted.yml', stderr.getvalue())
        self.assertIn('cannot be read', stderr.getvalue())
        self.assertIn('simulated unreadable workflow (injected fault)', stderr.getvalue())

if __name__ == '__main__':
    unittest.main(verbosity=2)
