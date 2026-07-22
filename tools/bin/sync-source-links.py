#!/usr/bin/env python3
"""Recreate project-level bb-source-* links for downloaded sources in the setup JSON."""

import json
import sys
from pathlib import Path


if len(sys.argv) != 4:
    raise SystemExit("Usage: sync-source-links.py SETUP_CONFIG LAYERS_DIR PROJECT_DIR")

config_file = Path(sys.argv[1]).resolve()
layers_dir = Path(sys.argv[2]).resolve()
project_dir = Path(sys.argv[3]).resolve()

with config_file.open(encoding="utf-8") as stream:
    sources = json.load(stream).get("sources")

if not isinstance(sources, dict):
    raise SystemExit(f"{config_file}: missing valid 'sources' object")

targets = []
for name in sources:
    if name in {".", ".."} or Path(name).name != name:
        raise SystemExit(f"{config_file}: invalid source name: {name}")

    target = layers_dir / name
    if target.is_dir():
        targets.append((name, target))

for link in project_dir.glob("bb-source-*"):
    if link.is_symlink():
        link.unlink()

for name, target in targets:
    link = project_dir / f"bb-source-{name}"
    if link.exists():
        print(f"Warning: refusing to replace non-symlink: {link}", file=sys.stderr)
        continue

    link.symlink_to(target.relative_to(project_dir))
