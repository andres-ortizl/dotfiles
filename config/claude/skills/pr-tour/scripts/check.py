#!/usr/bin/env python3
"""Sanity-check a built tour page: every chunk has lines, every test slice starts at its def, slices land on boundaries."""

import json
import re
import sys

html = open(sys.argv[1]).read()
payload = (
    re.search(r"const TOUR = (.*?);\nconst STOPS", html, re.S)
    .group(1)
    .replace("<\\/", "</")
)
tour = json.loads(payload)
problems = 0
for flow in tour["flows"]:
    for stop in flow["stops"]:
        for c in stop["chunks"]:
            if not c["lines"]:
                print("EMPTY", stop["id"], c["ref"])
                problems += 1
            first, last = c["lines"][0]["s"], c["lines"][-1]["s"]
            print(
                f"{stop['id']:<12} {c['ref']:<28} first={first.strip()[:50]!r:<54} last={last.strip()[:40]!r}"
            )
        for t in stop["test_chunks"]:
            head = t["lines"][0]["s"].strip()
            if not (head.startswith("def ") or head.startswith("@")):
                print("TESTSLICE?", stop["id"], t["test"], repr(head))
                problems += 1
print("problems", problems)
