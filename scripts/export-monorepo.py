#!/usr/bin/env python3
"""Create a clean source snapshot without changing any existing Git history."""
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
destination = Path(sys.argv[1]).expanduser().resolve()
if destination.exists():
    raise SystemExit('Destination already exists; refusing to overwrite it.')
excluded = {'.git', '.local', '.idea', '.claude', '.codex', '.agents', '.dart_tool',
            'node_modules', 'build', 'dist', 'target', 'uploads', '__pycache__',
            'Pods', '.symlinks', 'ephemeral', '.gradle', '.swiftpm'}
files = set()
for component in ('ant', 'clinicapp'):
    data = subprocess.check_output(['git', '-C', str(root / component), 'ls-files',
                                    '-z', '--cached', '--others', '--exclude-standard'])
    files.update(Path(component) / name.decode() for name in data.split(b'\0') if name)
for folder in ('dashboard', 'infrastructure', 'knowledge', 'load-tests', 'scripts', '.github'):
    # Prune generated directories before walking.
    import os
    for base, dirs, names in os.walk(root / folder):
        dirs[:] = [d for d in dirs if d not in excluded]
        files.update((Path(base) / n).relative_to(root) for n in names)
files.update(Path(name) for name in ('README.md', 'DEPLOYMENT.md', 'AI_SUPPORT_SETUP.md', '.gitignore'))
selected = []
for path in sorted(files):
    source = root / path
    if set(path.parts) & excluded or not source.is_file() or source.is_symlink():
        continue
    if path.name.startswith('.env') and path.name != '.env.example':
        continue
    if path.name in ('.DS_Store', 'local.properties', 'key.properties', '.flutter-plugins-dependencies'):
        continue
    if source.suffix in ('.log', '.pyc', '.iml', '.jks', '.keystore', '.p12', '.mobileprovision', '.dump', '.db'):
        continue
    data = source.read_bytes()
    if re.search(rb'sk-(?:proj-)?[A-Za-z0-9_-]{40,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', data):
        raise SystemExit(f'Possible credential in {path}; export stopped (value not printed).')
    selected.append(path)
for path in selected:
    target = destination / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / path, target)
subprocess.run(['git', 'init', '-b', 'main', str(destination)], check=True)
print(f'Exported {len(selected)} source files to {destination}. No remote, commit or push performed.')
