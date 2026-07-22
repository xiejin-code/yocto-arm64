#!/usr/bin/env python3
"""Compare the local setup JSON with the configuration saved by bitbake-setup."""

import json
import sys
from pathlib import Path


def normalize(value):
    if isinstance(value, dict):
        return {
            key: normalize(item)
            for key, item in value.items()
            if key != "oe-fragment-choices"
        }
    if isinstance(value, list):
        return [normalize(item) for item in value]
    return value


if len(sys.argv) != 3:
    print(
        "Usage: compare-setup-config.py SETUP_CONFIG CONFIG_UPSTREAM",
        file=sys.stderr,
    )
    raise SystemExit(2)

try:
    with Path(sys.argv[1]).open(encoding="utf-8") as stream:
        current_config = json.load(stream)
    with Path(sys.argv[2]).open(encoding="utf-8") as stream:
        saved_config = json.load(stream)["data"]
except (OSError, UnicodeError, json.JSONDecodeError, KeyError, TypeError) as error:
    print(f"Error: could not compare setup configurations: {error}", file=sys.stderr)
    raise SystemExit(2)

raise SystemExit(0 if normalize(current_config) == normalize(saved_config) else 1)
