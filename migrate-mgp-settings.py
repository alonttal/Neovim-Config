#!/usr/bin/env python3
"""Migrate saved mgp_serving launch settings without replacing other settings."""
import hashlib
import json
import os
from pathlib import Path
import tempfile


def main():
    root = '/home/alontalmor/dev/Projects/mgp_serving/trunk'
    data_home = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    path = data_home / 'nvim/project-settings' / (hashlib.sha256(root.encode()).hexdigest() + '.json')
    original = path.read_bytes()
    settings = json.loads(original)
    run = settings['run']
    runner_dir = Path(__file__).resolve().parent
    expected_old = ['bash', str(runner_dir / 'run-mgp-serving.sh')]
    expected_new = ['bash', str(runner_dir / 'run-catalina.sh')]
    if run.get('command') not in (expected_old, expected_new):
        raise SystemExit('Launch command differs from the known runner; left unchanged.')
    env = run.setdefault('env', {})
    for old, new in {
        'MGP_PROJECT_ROOT': 'NVIM_PROJECT_ROOT',
        'MGP_TOMEE_HOME': 'NVIM_SERVER_HOME',
        'MGP_TOMEE_BASE': 'NVIM_SERVER_BASE',
        'MGP_HTTP_PORT': 'NVIM_HTTP_PORT',
        'MGP_DEBUG_PORT': 'NVIM_DEBUG_PORT',
    }.items():
        if old in env:
            if new in env and env[new] != env[old]:
                raise SystemExit(f'Conflicting {old}/{new} settings; left unchanged.')
            env[new] = env.pop(old)
    env.setdefault('NVIM_WAR_FILE', 'target/ROOT.war')
    env.setdefault('NVIM_CONTEXT_PATH', '/')
    run['command'] = expected_new
    if json.loads(original) == settings:
        print('Already using the shared runner; no changes needed.')
        return
    updated = json.dumps(settings, indent=2) + '\n'
    backup = path.with_suffix('.json.before-shared-runner')
    # Stage the new file before touching saved settings; failed writes leave
    # the original intact. Preserve the original once as a private backup.
    staged = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as temp:
            staged = Path(temp.name)
            temp.write(updated)
        if not backup.exists():
            fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'wb') as output:
                output.write(original)
        os.replace(staged, path)
        print(f'Migrated: {path}')
        print(f'Original backup: {backup}')
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except OSError as error:
        raise SystemExit(f'Could not migrate settings: {error}')
