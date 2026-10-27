#!/usr/bin/env python3
"""Assemble a PR tour page: tour.json (stops, narration) + hunks.json (diff) + template.html -> out.html.

Hunk refs: "file.py#3" (whole hunk) or "file.py#3:10-42" (line indexes within the hunk, inclusive).
Test refs: "test_file.py::test_name" (the def and its body, sliced out of whichever hunk adds it).
`build.py index hunks.json file.py#3` prints the hunk's lines with their indexes, for writing slices.
"""

import hashlib
import json
import re
import sys
from pathlib import Path

REF = re.compile(r"^(?P<hunk>[^:]+#\d+)(?::(?P<a>\d+)-(?P<b>\d+))?$")


def load_hunks(path: str) -> tuple[dict, dict[str, dict], dict[str, dict]]:
    data = json.load(open(path))
    by_id = {h["id"]: {**h, "file": f} for f in data["files"] for h in f["hunks"]}
    files = {f["name"]: f for f in data["files"]}
    return data, by_id, files


def resolve_hunk(ref: str, by_id: dict[str, dict]) -> dict:
    m = REF.match(ref)
    if not m or m["hunk"] not in by_id:
        raise SystemExit(f"unknown hunk ref: {ref}")
    h = by_id[m["hunk"]]
    lines = h["lines"]
    a, b = 0, len(lines) - 1
    if m["a"] is not None:
        a, b = int(m["a"]), int(m["b"])
    sliced = lines[a : b + 1]
    old_start, new_start = h["old_start"], h["new_start"]
    for line in lines[:a]:
        if line["t"] != "+":
            old_start += 1
        if line["t"] != "-":
            new_start += 1
    return {
        "ref": ref,
        "path": h["file"]["path"],
        "name": h["file"]["name"],
        "lang": h["file"]["lang"],
        "status": h["file"]["status"],
        "context": h["context"],
        "old_start": old_start,
        "new_start": new_start,
        "lines": sliced,
    }


def resolve_test(ref: str, files: dict[str, dict]) -> dict:
    file_name, _, test_name = ref.partition("::")
    f = files.get(file_name)
    if f is None:
        raise SystemExit(f"unknown test file: {ref}")
    for h in f["hunks"]:
        lines = h["lines"]
        for i, line in enumerate(lines):
            if line["t"] == "+" and line["s"].lstrip().startswith(f"def {test_name}("):
                indent = len(line["s"]) - len(line["s"].lstrip())
                start = i
                while (
                    start > 0
                    and lines[start - 1]["t"] == "+"
                    and lines[start - 1]["s"].lstrip().startswith("@")
                ):
                    start -= 1
                end = i + 1
                while end < len(lines):
                    s = lines[end]["s"]
                    stripped = s.lstrip()
                    if (
                        stripped
                        and (len(s) - len(stripped)) <= indent
                        and lines[end]["t"] != "-"
                    ):
                        break
                    end += 1
                while end > i and not lines[end - 1]["s"].strip():
                    end -= 1
                return resolve_hunk(
                    f"{h['id']}:{start}-{end - 1}", {h["id"]: {**h, "file": f}}
                ) | {"test": test_name}
    raise SystemExit(f"test not found in the diff: {ref}")


def signature(chunks: list[dict]) -> str:
    text = "\n".join(line["t"] + line["s"] for c in chunks for line in c["lines"])
    return hashlib.sha1(text.encode()).hexdigest()[:12]


def build(tour_path: str, hunks_path: str, template_path: str, out_path: str) -> None:
    tour = json.load(open(tour_path))
    data, by_id, files = load_hunks(hunks_path)
    used: set[str] = set()
    for flow in tour["flows"]:
        for stop in flow["stops"]:
            chunks = [resolve_hunk(ref, by_id) for ref in stop.get("hunks", [])]
            tests = [resolve_test(ref, files) for ref in stop.get("tests", [])]
            used.update(REF.match(ref)["hunk"] for ref in stop.get("hunks", []))
            used.update(t["ref"].split(":")[0] for t in tests)
            stop["chunks"] = chunks
            stop["test_chunks"] = tests
            stop["sig"] = signature(chunks)
    leftovers = [h for h in by_id if h not in used]
    tour["leftovers"] = [resolve_hunk(h, by_id) for h in leftovers]
    tour["base"] = data["base"]
    tour["head"] = data["head"]
    tour["files"] = [
        {"path": f["path"], "status": f["status"], "hunks": len(f["hunks"])}
        for f in data["files"]
    ]
    payload = json.dumps(tour, ensure_ascii=False).replace("</", "<\\/")
    html = (
        Path(template_path)
        .read_text()
        .replace("__TITLE__", tour["title"])
        .replace("/*__TOUR__*/null", payload)
    )
    Path(out_path).write_text(html)
    stops = sum(len(f["stops"]) for f in tour["flows"])
    print(
        f"{out_path}: {stops} stops, {len(by_id)} hunks, {len(leftovers)} not in any stop"
    )
    for h in leftovers:
        print(f"   leftover {h}")


def index(hunks_path: str, hunk_id: str) -> None:
    _, by_id, _ = load_hunks(hunks_path)
    for i, line in enumerate(by_id[hunk_id]["lines"]):
        print(f"{i:4} {line['t']}{line['s'][:110]}")


if __name__ == "__main__":
    if sys.argv[1] == "index":
        index(sys.argv[2], sys.argv[3])
    else:
        build(*sys.argv[1:5])
