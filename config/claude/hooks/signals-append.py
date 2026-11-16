#!/usr/bin/env python3
"""PostToolUse on Agent: append the report's Signals entries to the signals.md of the loop its brief names.

A slices-wave run is not an Agent call, so the main agent still copies the signals field of its result.
"""

import datetime
import json
import re
import sys
from pathlib import Path

LOOP = re.compile(r"(~|/Users/[^/\s]+)/\.artifacts/[\w.-]+/loops/[\w.-]+")
NONE = re.compile(r'^\(?"?(none|ninguna|-)"?\)?\W*$', re.IGNORECASE)


def signals(report: str) -> list[str]:
    found = []
    lines = report.splitlines()
    for i, line in enumerate(lines):
        if not line.startswith("Signals:"):
            continue
        first = line.removeprefix("Signals:").strip()
        if first:
            found.append(first)
        for more in lines[i + 1 :]:
            if not more.strip().startswith(("- [", "[")):
                break
            found.append(more.strip().removeprefix("- "))
    return [s for s in found if not NONE.match(s)]


def main() -> None:
    event = json.load(sys.stdin)
    response = event.get("tool_response") or {}
    if not isinstance(response, dict) or response.get("status") != "completed":
        return
    match = LOOP.search(event.get("tool_input", {}).get("prompt", ""))
    if not match:
        return
    target = Path(match.group(0)).expanduser() / "signals.md"
    if not target.is_file():
        return
    report = "\n".join(
        block.get("text", "")
        for block in response.get("content") or []
        if isinstance(block, dict)
    )
    entries = signals(report)
    if not entries:
        return
    date = datetime.date.today().isoformat()
    agent = response.get("agentType") or event.get("tool_input", {}).get(
        "subagent_type", "agent"
    )
    with target.open("a") as fh:
        fh.writelines(f"- {date} [{agent}] {entry}\n" for entry in entries)


if __name__ == "__main__":
    main()
