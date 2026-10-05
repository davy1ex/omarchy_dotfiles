#!/usr/bin/env python3
"""Print whether the plugin named on argv[1] is enabled.

Reads the JSON from `omarchy plugin list --json` on stdin and prints
`True` or `False`, or an empty string when the plugin is not installed.
"""

import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <plugin-id>", file=sys.stderr)
        return 2

    plugins = json.load(sys.stdin)
    enabled = next((p["enabled"] for p in plugins if p["id"] == sys.argv[1]), None)

    if enabled is not None:
        print(str(enabled))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
