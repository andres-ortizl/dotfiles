#!/usr/bin/env python3
"""Turn `git diff base..head` into hunks.json: one entry per file, one per hunk, ids stable across rebuilds."""

import json
import re
import subprocess
import sys
from pathlib import Path

LANG = {
    ".py": "python",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".md": "markdown",
    ".toml": "ini",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".sql": "sql",
    ".sh": "bash",
    "Dockerfile": "dockerfile",
    ".lock": "ini",
}
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)$")


def lang_of(path: str) -> str:
    p = Path(path)
    return LANG.get(p.name) or LANG.get(p.suffix, "plaintext")


def parse(diff: str) -> list[dict]:
    files: list[dict] = []
    cur = None
    hunk = None
    for raw in diff.split("\n"):
        if raw.startswith("diff --git"):
            path = raw.split(" b/", 1)[1]
            cur = {
                "path": path,
                "name": Path(path).name,
                "lang": lang_of(path),
                "status": "modified",
                "hunks": [],
            }
            files.append(cur)
            hunk = None
            continue
        if cur is None:
            continue
        if raw.startswith("new file mode"):
            cur["status"] = "added"
            continue
        if raw.startswith("deleted file mode"):
            cur["status"] = "deleted"
            continue
        m = HUNK.match(raw)
        if m:
            n = len(cur["hunks"]) + 1
            hunk = {
                "id": f"{cur['name']}#{n}",
                "old_start": int(m[1]),
                "old_lines": int(m[2] or 1),
                "new_start": int(m[3]),
                "new_lines": int(m[4] or 1),
                "context": m[5].strip(),
                "lines": [],
            }
            cur["hunks"].append(hunk)
            continue
        if hunk is None or raw.startswith("\\ No newline"):
            continue
        if raw[:1] in (" ", "+", "-"):
            hunk["lines"].append({"t": raw[0], "s": raw[1:]})
    return files


def main() -> None:
    repo, base, head, out = sys.argv[1:5]
    diff = subprocess.run(
        ["git", "-C", repo, "diff", "-U4", f"{base}..{head}"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    files = parse(diff)
    for f in files:
        f["hunk_ids"] = [h["id"] for h in f["hunks"]]
    Path(out).write_text(
        json.dumps({"base": base, "head": head, "files": files}, ensure_ascii=False)
    )
    for f in files:
        adds = sum(1 for h in f["hunks"] for line in h["lines"] if line["t"] == "+")
        dels = sum(1 for h in f["hunks"] for line in h["lines"] if line["t"] == "-")
        print(f"{f['path']} [{f['status']}] +{adds}/-{dels}")
        for h in f["hunks"]:
            print(f"   {h['id']:<40} @{h['new_start']:<5} {h['context'][:70]}")


if __name__ == "__main__":
    main()
