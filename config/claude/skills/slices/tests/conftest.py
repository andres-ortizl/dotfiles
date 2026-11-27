"""Fixtures: the real `slices` script runs as a subprocess; `gh` is a fake executable that replays canned JSON."""

import json
import os
import stat
import subprocess
from pathlib import Path

import pytest

SLICES = Path(__file__).resolve().parent.parent / "slices"

FAKE_GH = """#!/usr/bin/env python3
import json, os, sys
line = " ".join(sys.argv[1:])
fixtures = json.load(open(os.environ["FAKE_GH_FIXTURES"]))
for entry in fixtures:
    if all(part in line for part in entry["match"]):
        sys.stdout.write(json.dumps(entry["out"]))
        sys.exit(entry.get("rc", 0))
sys.stderr.write("fake gh: no fixture for " + line + "\\n")
sys.exit(1)
"""

HEAD = "a" * 40


class Fake:
    """Canned gh answers for one test; the earliest matching fixture wins."""

    def __init__(self, tmp: Path):
        self.tmp = tmp
        self.bin = tmp / "bin"
        self.bin.mkdir()
        gh = self.bin / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
        self.fixtures: list[dict] = []
        self.path = tmp / "fixtures.json"

    def add(self, *match: str, out, rc: int = 0) -> None:
        self.fixtures.append({"match": list(match), "out": out, "rc": rc})

    def pr(
        self,
        number: int,
        *,
        repo: str = "o/r",
        state: str = "OPEN",
        base: str = "dev",
        ref: str | None = None,
        head: str = HEAD,
        draft: bool = False,
        mergeable: str = "MERGEABLE",
        checks: list[dict] | None = None,
        score: int | None = 5,
        reviewed: str | None = HEAD,
        threads: int = 0,
        behind: int = 0,
        merge_commit: str | None = None,
    ) -> None:
        ref = ref or f"branch-{number}"
        if checks is None:
            checks = [{"name": "test", "status": "COMPLETED", "conclusion": "SUCCESS"}]
        self.add(
            f"pr view {number} --repo {repo} --json state",
            out={
                "state": state,
                "isDraft": draft,
                "baseRefName": base,
                "headRefName": ref,
                "headRefOid": head,
                "mergeable": mergeable,
                "mergeCommit": {"oid": merge_commit} if merge_commit else None,
                "statusCheckRollup": checks,
            },
        )
        comments = []
        if score is not None:
            body = f"Confidence Score: {score}/5"
            if reviewed:
                body += f"\nLast reviewed commit: [x](https://github.com/{repo}/commit/{reviewed})"
            comments = [{"user": {"login": "greptile-apps[bot]"}, "body": body}]
        self.add(f"repos/{repo}/issues/{number}/comments", out=[comments])
        nodes = [
            {
                "isResolved": False,
                "comments": {"nodes": [{"author": {"login": "greptile-apps"}}]},
            }
            for _ in range(threads)
        ]
        nodes.append(
            {
                "isResolved": False,
                "comments": {"nodes": [{"author": {"login": "a-human"}}]},
            }
        )
        nodes.append(
            {
                "isResolved": True,
                "comments": {"nodes": [{"author": {"login": "greptile-apps"}}]},
            }
        )
        self.add(
            f"n={number} -f",
            "graphql",
            out={
                "data": {
                    "repository": {"pullRequest": {"reviewThreads": {"nodes": nodes}}}
                }
            },
        )
        self.add(f"repos/{repo}/compare/{base}...{head}", out={"behind_by": behind})

    def run(
        self, *args: str, extra_env: dict | None = None
    ) -> subprocess.CompletedProcess:
        self.path.write_text(json.dumps(self.fixtures))
        env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "FAKE_GH_FIXTURES": str(self.path),
        }
        env.pop("NO_COLOR", None)
        env.update(extra_env or {})
        return subprocess.run(
            [str(SLICES), *args], capture_output=True, text=True, env=env
        )

    def status(self, *args: str) -> dict:
        done = self.run("status", "--json", *args)
        assert done.returncode == 0, done.stderr
        return json.loads(done.stdout)


@pytest.fixture
def fake(tmp_path: Path) -> Fake:
    return Fake(tmp_path)


def blockers(data: dict, number: int) -> list[str]:
    pr = next(p for p in data["prs"] if p["pr"] == number)
    return [b["kind"] for b in pr["blockers"]]
