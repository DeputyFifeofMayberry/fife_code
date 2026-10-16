#!/usr/bin/env python3
"""Project verifier. Fails closed for required checks and project-specific documents.

Commands are argument arrays, executed without a shell. Configuration is trusted
repository code: require independent review of changes to this file and config.
"""
from __future__ import annotations

import argparse
import json
import re
from urllib.parse import unquote
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / '.foundation' / 'project.json'
# Hardcoded required categories: they cannot be bypassed just by editing project.json.
REQUIRED = ('lint', 'typecheck', 'unit', 'integration', 'e2e', 'build', 'security', 'architecture')
PROJECT_DOCS = (
    'ARCHITECTURE.md', 'docs/BASELINE.md', 'docs/PRODUCT.md', 'docs/PRODUCT_SENSE.md',
    'docs/DESIGN.md', 'docs/FRONTEND.md', 'docs/TESTING.md',
    'docs/SECURITY.md', 'docs/RELIABILITY.md', 'docs/QUALITY_SCORE.md',
)
MANDATORY_DOCS = (
    'AGENTS.md', 'README.md', 'docs/USER_GUIDE.md', 'docs/INDEX.md', 'docs/CHECKLISTS.md',
    'CHANGELOG.md', 'docs/RUNBOOKS.md', 'docs/REVIEW_EVIDENCE.md', 'docs/TECH_DEBT.md',
    *PROJECT_DOCS,
)
# The only documents a project may declare not applicable (headless/API-only projects).
NA_ELIGIBLE_DOCS = ('docs/DESIGN.md', 'docs/FRONTEND.md')
MAX_TIMEOUT_SECONDS = 7200


def report_error(message: str) -> None:
    print('FAIL: ' + message, file=sys.stderr, flush=True)


def docs_check(config: dict) -> bool:
    errors = []
    # Documents with a valid NA declaration are treated as configured; they need not
    # exist. TODO_REQUIRED content in an existing NA document still fails (an NA
    # declaration never coexists with unconfigured content).
    na_docs = config.get('not_applicable') or {}
    for rel in MANDATORY_DOCS:
        declared_na = rel in na_docs
        file = ROOT / rel
        if not file.is_file():
            if not declared_na:
                errors.append(f'Missing required documentation: {rel}')
            continue
        content = file.read_text(encoding='utf-8')
        if not content.strip() and not declared_na:
            errors.append(f'Empty required documentation: {rel}')
        if rel in PROJECT_DOCS and 'TODO_REQUIRED' in content:
            errors.append(f'Unconfigured project-specific documentation: {rel}')
    # Validate relative Markdown links so documentation remains navigable for agents.
    # Absolute HTTP(S), mailto, and same-page anchors are intentionally excluded.
    pattern = re.compile(r'(?<!!)\[[^\]]+\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)')
    tracked_docs = [*ROOT.glob('*.md'), *(ROOT / 'docs').rglob('*.md')]
    pr_template = ROOT / '.github' / 'PULL_REQUEST_TEMPLATE.md'
    if pr_template.exists():
        tracked_docs.append(pr_template)
    for document in tracked_docs:
        try:
            body = document.read_text(encoding='utf-8')
        except OSError as exc:
            errors.append(f'Unable to read {document}: {exc}')
            continue
        # Fenced code samples may contain deliberately fictional paths.
        body = re.sub(r'```.*?```', '', body, flags=re.DOTALL)
        for link in pattern.findall(body):
            location = unquote(link.split('#', 1)[0])
            if not location or ':' in location or location.startswith('//'):
                continue
            resolved = (document.parent / location).resolve()
            if not resolved.is_relative_to(ROOT.resolve()) or not resolved.exists():
                errors.append(f'Broken/unsafe documentation link in {document.relative_to(ROOT)}: {link}')
    for error in errors:
        report_error(error)
    return not errors


def parse_config() -> dict:
    if not CONFIG.is_file():
        raise ValueError('Missing .foundation/project.json')
    config = json.loads(CONFIG.read_text(encoding='utf-8'))
    if not isinstance(config, dict) or config.get('schema_version') != 2:
        raise ValueError('schema_version must be 2')
    name = config.get('project_name')
    if not isinstance(name, str) or not name.strip() or 'TODO_REQUIRED' in name:
        raise ValueError('Configure a real project_name')
    checks = config.get('checks')
    if not isinstance(checks, dict) or set(checks) != set(REQUIRED):
        raise ValueError('checks must contain exactly all required categories: ' + ', '.join(REQUIRED))
    required = config.get('required_ci_checks')
    if not isinstance(required, list) or len(required) != len(REQUIRED) or set(required) != set(REQUIRED):
        raise ValueError('required_ci_checks must list all required categories once')
    for key in REQUIRED:
        value = checks[key]
        if not isinstance(value, dict):
            raise ValueError(f'{key}: use object with argv and timeout_seconds')
        argv = value.get('argv')
        timeout = value.get('timeout_seconds')
        if not isinstance(argv, list) or not argv or any(not isinstance(v, str) or not v.strip() for v in argv):
            raise ValueError(f'{key}: argv must be non-empty list of non-blank strings')
        if isinstance(timeout, bool) or not isinstance(timeout, int) or not 1 <= timeout <= MAX_TIMEOUT_SECONDS:
            raise ValueError(f'{key}: timeout_seconds must be integer between 1 and {MAX_TIMEOUT_SECONDS}')
        # Obvious no-ops are rejected. Meaningful test design still requires review.
        if argv[0].lower() in {'echo', 'true', ':'} or argv[1:2] in (['-c'], ['-e']):
            raise ValueError(f'{key}: apparent no-op/inline command not permitted; use a real project check')
    # Optional NA declarations: whitelist-enforced and fail-closed. schema_version
    # stays 2; configurations without this key are unaffected.
    na = config.get('not_applicable')
    if na is not None:
        if not isinstance(na, dict):
            raise ValueError('not_applicable must be an object mapping document path to reason')
        for path in na:
            reason = na[path]
            if path not in NA_ELIGIBLE_DOCS:
                raise ValueError('not_applicable: only ' + ', '.join(NA_ELIGIBLE_DOCS) + ' may be declared NA, not ' + str(path))
            if not isinstance(reason, str) or not reason.strip():
                raise ValueError(f'not_applicable: {path} requires a non-empty reason string')
    return config


def resolve_executable(command: str) -> str | None:
    candidate = Path(command)
    if candidate.is_absolute() or '/' in command or chr(92) in command:
        target = (ROOT / candidate).resolve() if not candidate.is_absolute() else candidate
        return str(target) if target.is_file() else None
    resolved = shutil.which(command)
    if resolved is None and sys.platform == 'win32':
        resolved = shutil.which(command + '.cmd')
    return resolved


def run_one(name: str, spec: dict) -> bool:
    argv = spec['argv']
    program = resolve_executable(argv[0])
    if not program:
        report_error(f'{name}: command unavailable: {argv[0]}')
        return False
    print(f'RUN {name}: {argv} (timeout {spec["timeout_seconds"]}s)', flush=True)
    try:
        process = subprocess.run([program, *argv[1:]], cwd=ROOT, check=False, timeout=spec['timeout_seconds'])
    except subprocess.TimeoutExpired:
        report_error(f'{name}: timed out after {spec["timeout_seconds"]}s')
        return False
    except OSError as exc:
        report_error(f'{name}: could not launch: {exc}')
        return False
    if process.returncode != 0:
        report_error(f'{name}: exit code {process.returncode}')
        return False
    print(f'PASS {name}', flush=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--ci', action='store_true', help='run every required check (never skips)')
    group.add_argument('--list', action='store_true', help='display requirements and configuration')
    group.add_argument('--check', choices=REQUIRED, help='run one category for local debugging, not PR acceptance')
    args = parser.parse_args()
    # --list is available during onboarding before project_name and commands are filled.
    if args.list:
        try:
            raw = json.loads(CONFIG.read_text(encoding='utf-8'))
            checks = raw.get('checks', {})
        except (OSError, ValueError, AttributeError) as exc:
            report_error(str(exc))
            return 2
        print('Project:', raw.get('project_name', '<unset>'))
        for key in REQUIRED:
            spec = checks.get(key, {})
            print(f'{key}: {spec.get("argv", []) if isinstance(spec, dict) else spec}')
        na = raw.get('not_applicable')
        if isinstance(na, dict) and na:
            print('Not applicable (treated as configured; whitelist-enforced):')
            for path in sorted(na):
                print(f'  {path}: {na[path]}')
        return 0
    try:
        cfg = parse_config()
    except (OSError, ValueError, TypeError) as exc:
        report_error(str(exc))
        return 2
    na = cfg.get('not_applicable') or {}
    for path in sorted(na):
        print(f'NA {path}: {na[path]}', flush=True)
    healthy = docs_check(cfg)
    selected = [args.check] if args.check else list(REQUIRED)
    # Do not short-circuit: surface every failure while still returning nonzero.
    for name in selected:
        healthy = run_one(name, cfg['checks'][name]) and healthy
    if healthy:
        print('PASS: selected checks and mandatory documents')
        return 0
    report_error('Verification failed; do not mark task complete or merge')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
