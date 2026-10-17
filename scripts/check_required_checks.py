#!/usr/bin/env python3
"""Fail-closed validator for required GitHub status checks.

Local half of the canonical required-check rule (docs/RUNBOOKS.md, GitHub
setup): proves that every required check name matches exactly one configured
workflow job in ``.github/workflows/`` and that the job's run steps pass on
the current tree. Any absent, ambiguous, red, or locally unverifiable job
(matrix, conditional, environment-, working-directory-, container-, or
services-dependent, continue-on-error, or without runnable steps) exits
nonzero, as does any workflow file that implements a configured required
check while falling outside the supported subset or that cannot be read.
Workflow files that
implement none of the configured required checks (e.g. adopter-owned release
workflows) are left unvalidated; a required check found only in such a file
still fails closed through the normal no-match path. Hosted merge
enforcement is a separate required confirmation documented in
docs/RUNBOOKS.md (GitHub setup step 6).

Supported workflow subset (parsed with the standard library only): mapping
jobs under a top-level ``jobs:`` key; step items with ``name``, ``uses``,
``run``, ``shell``, ``with``, and ``id`` attributes; block-scalar ``run``
values. ``uses:`` steps are assumed satisfied by the local checkout and
interpreter; a job that genuinely needs more fails on its run steps. Leading bare
``python`` tokens (per line) are mapped to the running interpreter when no
``python`` executable exists on PATH, so hosted YAML runs unchanged locally.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

WORKFLOW_EXTENSIONS = {'.yml', '.yaml'}
JOB_ID_LINE_PREFIX = '  '
BLOCKING_JOB_ATTRS = {
    'if': 'conditional',
    'strategy': 'matrix strategy',
    'container': 'container',
    'services': 'services',
    'env': 'custom environment',
    'defaults': 'run defaults',
    'continue-on-error': 'continue-on-error',
}
BLOCKING_STEP_ATTRS = {
    'if': 'conditional step',
    'working-directory': 'custom working directory',
    'env': 'custom environment',
    'continue-on-error': 'continue-on-error',
}
IGNORED_JOB_ATTRS = {'name', 'runs-on', 'timeout-minutes', 'permissions', 'concurrency', 'outputs', 'needs'}
IGNORED_STEP_ATTRS = {'name', 'uses', 'shell', 'id'}


class WorkflowError(Exception):
    pass


@dataclass
class Job:
    job_id: str
    source: str
    name: str | None = None
    run_steps: list[str] = field(default_factory=list)
    blocked_reason: str | None = None


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(' '))


def _split_key(value: str) -> tuple[str, str | None]:
    key, sep, rest = value.partition(':')
    if not sep:
        raise WorkflowError(f'expected key: value, got {value!r}')
    rest = rest.strip()
    return key.strip(), (rest or None)


def _strip_inline_comment(value: str) -> str:
    """Drop a trailing YAML comment from a scalar, honoring quoted sections."""
    quote: str | None = None
    escaped = False
    for index, char in enumerate(value):
        if quote == '"' and escaped:
            escaped = False
            continue
        if quote:
            if char == '\\' and quote == '"':
                escaped = True
            elif char == quote:
                quote = None
        elif char in ('\'', '"'):
            quote = char
        elif char == '#' and (index == 0 or value[index - 1] in (' ', '\t')):
            return value[:index].rstrip()
    return value


def _parse_block_scalar(lines: list[str], start: int, header_indent: int) -> tuple[str, int]:
    content_indent: int | None = None
    collected: list[str] = []
    i = start
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            collected.append('')
            i += 1
            continue
        indent = _indent(line)
        if indent <= header_indent:
            break
        if content_indent is None:
            content_indent = indent
        collected.append(line[content_indent:])
        i += 1
    while collected and collected[-1] == '':
        collected.pop()
    return '\n'.join(collected), i


def parse_workflow_jobs(text: str, source: str) -> dict[str, Job]:
    lines = text.splitlines()
    jobs: dict[str, Job] = {}
    in_jobs = False
    jobs_closed = False
    current: Job | None = None
    in_steps = False
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            i += 1
            continue
        indent = _indent(line)
        if indent == 0:
            key, value = _split_key(stripped)
            if key == 'jobs' and value is None:
                if in_jobs or jobs:
                    raise WorkflowError(f'{source}: duplicate jobs section')
                in_jobs = True
            elif in_jobs:
                in_jobs = False
                jobs_closed = True
            i += 1
            continue
        if jobs_closed:
            raise WorkflowError(f'{source}: unsupported content after jobs section: {stripped!r}')
        if not in_jobs:
            i += 1
            continue
        if indent == 2:
            if not stripped.endswith(':') or ':' in stripped[:-1]:
                raise WorkflowError(f'{source}: unsupported job entry: {stripped!r}')
            job_id = stripped[:-1].strip()
            if not job_id or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in job_id):
                raise WorkflowError(f'{source}: unsupported job id: {job_id!r}')
            if job_id in jobs:
                raise WorkflowError(f'{source}: duplicate job id {job_id!r}')
            current = Job(job_id=job_id, source=source)
            jobs[job_id] = current
            in_steps = False
            i += 1
            continue
        if current is None:
            raise WorkflowError(f'{source}: content outside a job: {stripped!r}')
        if indent == 4:
            key, value = _split_key(stripped)
            if key == 'steps' and value is None:
                in_steps = True
                i += 1
                continue
            in_steps = False
            if key == 'name':
                if value is None:
                    raise WorkflowError(f'{source}: job name must be inline')
                current.name = _strip_inline_comment(value).strip('\'"')
                i += 1
                continue
            if key in BLOCKING_JOB_ATTRS:
                current.blocked_reason = BLOCKING_JOB_ATTRS[key]
            elif key not in IGNORED_JOB_ATTRS:
                raise WorkflowError(f'{source}: unsupported job attribute {key!r}')
            if value is None:
                i += 1
                while i < len(lines):
                    deeper = lines[i]
                    if not deeper.strip() or deeper.strip().startswith('#'):
                        i += 1
                        continue
                    if _indent(deeper) > 4:
                        i += 1
                        continue
                    break
                continue
            i += 1
            continue
        if in_steps:
            if indent == 6 and stripped.startswith('- '):
                item = stripped[2:].strip()
                if not item:
                    i += 1
                    continue
                key, value = _split_key(item)
                if key in IGNORED_STEP_ATTRS:
                    if key == 'uses' and current.blocked_reason is None:
                        pass
                    i += 1
                    continue
                if key == 'run':
                    if value in ('|', '|-', '>', '>-'):
                        command, i = _parse_block_scalar(lines, i + 1, indent)
                    else:
                        if value is None:
                            raise WorkflowError(f'{source}: run step without a command')
                        command = value
                        i += 1
                    current.run_steps.append(command)
                    continue
                raise WorkflowError(f'{source}: unsupported step entry: {item!r}')
            if indent == 8:
                key, value = _split_key(stripped)
                if key in BLOCKING_STEP_ATTRS:
                    current.blocked_reason = BLOCKING_STEP_ATTRS[key]
                elif key == 'run':
                    if value in ('|', '|-', '>', '>-'):
                        command, i = _parse_block_scalar(lines, i + 1, indent)
                    else:
                        if value is None:
                            raise WorkflowError(f'{source}: run step without a command')
                        command = value
                        i += 1
                    current.run_steps.append(command)
                    continue
                elif key not in IGNORED_STEP_ATTRS and key != 'with':
                    raise WorkflowError(f'{source}: unsupported step attribute {key!r}')
                if value is None and key == 'with':
                    i += 1
                    while i < len(lines):
                        deeper = lines[i]
                        if not deeper.strip() or deeper.strip().startswith('#'):
                            i += 1
                            continue
                        if _indent(deeper) > 8:
                            i += 1
                            continue
                        break
                    continue
                i += 1
                continue
            raise WorkflowError(f'{source}: unsupported steps content: {stripped!r}')
        raise WorkflowError(f'{source}: unsupported job content: {stripped!r}')
    if not jobs:
        raise WorkflowError(f'{source}: no jobs found')
    return jobs


def _required_jobs_in_unparsed(text: str, names: list[str]) -> list[str]:
    """Return configured required checks an unparseable workflow still declares (job id or job name).

    Mirrors the parsed matcher: an explicit job display name replaces the job
    id, so a job id counts only when its job declares no display name.
    """
    matched: list[str] = []
    job_id: str | None = None
    job_named = False

    def close_job() -> None:
        if job_id is not None and not job_named and job_id in names and job_id not in matched:
            matched.append(job_id)

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        indent = _indent(line)
        if indent == 2:
            close_job()
            job_id = stripped[:-1].strip() if stripped.endswith(':') else None
            job_named = False
        elif indent == 4 and stripped.startswith('name:'):
            if job_id is not None:
                job_named = True
            candidate = _strip_inline_comment(stripped.partition(':')[2].strip()).strip('\'"')
            if candidate in names and candidate not in matched:
                matched.append(candidate)
    close_job()
    return matched


def _adapt_interpreter(command: str) -> str:
    if shutil.which('python') is not None:
        return command
    adapted: list[str] = []
    for line in command.split('\n'):
        stripped = line.lstrip()
        if stripped == 'python' or stripped.startswith('python '):
            stripped = sys.executable + stripped[len('python'):]
            line = line[:len(line) - len(line.lstrip())] + stripped
        adapted.append(line)
    return '\n'.join(adapted)


def _execute(job: Job, root: Path, timeout: int) -> str | None:
    shell = shutil.which('bash') or shutil.which('sh')
    if shell is None:
        return 'no shell available to execute run steps'
    if not job.run_steps:
        return 'job has no runnable (run) steps locally'
    for index, step in enumerate(job.run_steps, start=1):
        try:
            proc = subprocess.run(
                [shell, '-e', '-c', _adapt_interpreter(step)],
                cwd=str(root), capture_output=True, text=True, timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            return f'run step {index} timed out after {timeout}s: {step}'
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or '').strip()
            suffix = f': {detail}' if detail else ''
            return f'run step {index} exited {proc.returncode}{suffix}: {step}'
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description='Fail-closed local validation of GitHub required status checks '
                    '(canonical rule: docs/RUNBOOKS.md, GitHub setup).')
    parser.add_argument('--required', action='append', required=True, metavar='NAME[,NAME...]',
                        help='required check name; repeatable, comma-separated lists allowed')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1],
                        help='repository root (default: the repository containing this script)')
    parser.add_argument('--timeout-seconds', type=int, default=600,
                        help='per-step execution timeout in seconds (default: 600)')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    names: list[str] = []
    for chunk in args.required:
        for name in chunk.split(','):
            name = name.strip()
            if name and name not in names:
                names.append(name)
    workflow_dir = root / '.github' / 'workflows'
    workflow_files = sorted(
        path for path in workflow_dir.glob('*')
        if path.is_file() and path.suffix in WORKFLOW_EXTENSIONS
    ) if workflow_dir.is_dir() else []
    if not workflow_files:
        print(f'FAIL no workflow files found under {workflow_dir}', file=sys.stderr)
        return 1
    jobs: dict[str, Job] = {}
    unparsed: list[tuple[str, str, str]] = []
    for path in workflow_files:
        source = str(path.relative_to(root))
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError) as exc:
            print(f'FAIL {source}: workflow file cannot be read: {exc}', file=sys.stderr)
            return 1
        try:
            jobs.update(parse_workflow_jobs(text, source))
        except (WorkflowError, OSError, UnicodeDecodeError) as exc:
            unparsed.append((source, text, str(exc)))
    for source, text, error in unparsed:
        declared = _required_jobs_in_unparsed(text, names)
        if declared:
            print(f'FAIL {source}: declares required check(s) {", ".join(declared)} '
                  f'but cannot be validated: {error}', file=sys.stderr)
            return 1
        print(f'NOTE {source}: not validated; implements none of the configured required checks ({error})')
    failures: list[str] = []
    for name in names:
        matches = [
            job for job in jobs.values()
            if job.name == name or (job.name is None and job.job_id == name)
        ]
        if not matches:
            failures.append(f'{name}: no workflow job or job name matches in '
                            f'.github/workflows/ (configured jobs: {", ".join(sorted(jobs)) or "none"})')
            continue
        if len(matches) > 1:
            failures.append(f'{name}: ambiguous; matches {len(matches)} jobs '
                            f'({", ".join(sorted(job.job_id for job in matches))})')
            continue
        job = matches[0]
        if job.blocked_reason:
            failures.append(f'{name}: job {job.job_id!r} ({job.source}) uses a {job.blocked_reason}; '
                            f'not locally verifiable, confirm hosted enforcement instead')
            continue
        failure = _execute(job, root, args.timeout_seconds)
        if failure:
            failures.append(f'{name}: job {job.job_id!r} ({job.source}) fails on the current tree; {failure}')
            continue
        print(f'OK {name}: job {job.job_id!r} ({job.source}); {len(job.run_steps)} run step(s) passed')
    if failures:
        for failure in failures:
            print(f'FAIL {failure}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
