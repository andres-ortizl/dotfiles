#!/usr/bin/env python3
"""Print the hunks of one or more files (repo-relative paths) from hunks.json as plain diff text (for the tour author)."""

import json
import sys

data = json.load(open(sys.argv[1]))
wanted = set(sys.argv[2:])
for f in data["files"]:
    if wanted and f["path"] not in wanted:
        continue
    print(f"==== {f['path']} [{f['status']}]")
    for h in f["hunks"]:
        print(f"--- {h['id']} @{h['new_start']} {h['context']}")
        for line in h["lines"]:
            print(line["t"] + line["s"])
