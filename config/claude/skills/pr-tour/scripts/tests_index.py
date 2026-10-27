#!/usr/bin/env python3
"""List the test functions and classes each test hunk adds, to attach tests to tour stops."""

import json
import sys

data = json.load(open(sys.argv[1]))
for f in data["files"]:
    if "test" not in f["path"]:
        continue
    for h in f["hunks"]:
        added = [line["s"].strip() for line in h["lines"] if line["t"] == "+"]
        names = [
            s[:90]
            for s in added
            if s.startswith("def test_") or s.startswith("class Test")
        ]
        print(h["id"], f"+{len(added)}", names)
