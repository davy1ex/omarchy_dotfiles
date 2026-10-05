#!/usr/bin/env python3
"""Print a plugins.txt manifest for the plugins installed on this machine.

Reads the JSON from `omarchy plugin list --json` on stdin and writes a
tab-separated manifest to stdout:

    <plugin-id>\t<git-url>\t<enabled|disabled>

Only third-party plugins are recorded; first-party ones ship with Omarchy.
The git URL is read from each plugin's origin remote, so the manifest is
enough to reinstall them elsewhere with `omarchy plugin add`.
"""

import json
import pathlib
import subprocess
import sys

HEADER = "# <plugin-id><TAB><git-url><TAB><enabled|disabled>"


def origin_of(plugin_dir: pathlib.Path) -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(plugin_dir), "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def main() -> int:
    plugins = [p for p in json.load(sys.stdin) if not p["firstParty"]]

    rows = [HEADER]
    for plugin in sorted(plugins, key=lambda p: p["id"]):
        url = origin_of(pathlib.Path.home() / ".config/omarchy/plugins" / plugin["id"])
        if not url:
            continue
        state = "enabled" if plugin["enabled"] else "disabled"
        rows.append(f"{plugin['id']}\t{url}\t{state}")

    sys.stdout.write("\n".join(rows) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
