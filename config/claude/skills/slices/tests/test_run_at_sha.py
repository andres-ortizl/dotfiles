import subprocess
import sys
from pathlib import Path

from conftest import SLICES


def git(cwd, *args):
    done = subprocess.run(
        ["git", "-C", str(cwd), *args], capture_output=True, text=True, check=True
    )
    return done.stdout.strip()


def make_repo(tmp_path: Path) -> tuple[Path, str, str]:
    """A repo whose src/pkg changes between two commits; the test file lives in the worktree and wants the new behaviour."""
    repo = tmp_path / "repo"
    (repo / "pkg" / "src" / "mypkg").mkdir(parents=True)
    (repo / "pkg" / "tests").mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
    git(repo, "config", "user.email", "t@example.com")
    git(repo, "config", "user.name", "t")
    (repo / "pkg" / "src" / "mypkg" / "__init__.py").write_text("VALUE = 1\n")
    (repo / "pkg" / "tests" / "test_value.py").write_text(
        "import mypkg\n\ndef test_value():\n    assert mypkg.VALUE == 2\n"
    )
    git(repo, "add", ".")
    git(repo, "commit", "-q", "-m", "parent")
    parent = git(repo, "rev-parse", "HEAD")
    (repo / "pkg" / "src" / "mypkg" / "__init__.py").write_text("VALUE = 2\n")
    git(repo, "commit", "-q", "-am", "head")
    head = git(repo, "rev-parse", "HEAD")
    venv = repo / ".venv" / "bin"
    venv.mkdir(parents=True)
    # a worktree venv stand-in that runs the interpreter of this test suite, which has pytest
    (venv / "python").write_text(f'#!/bin/sh\nexec "{sys.executable}" "$@"\n')
    (venv / "python").chmod(0o755)
    (repo / ".gitignore").write_text(".venv\n")
    return repo, parent, head


def run_at(repo: Path, sha: str, *pytest_args: str):
    return subprocess.run(
        [str(SLICES), "run-at-sha", str(repo), sha, "--", *pytest_args],
        capture_output=True,
        text=True,
    )


def test_fails_at_the_parent_and_passes_at_head_and_leaves_no_worktree(tmp_path):
    repo, parent, head = make_repo(tmp_path)
    pytest_args = ("-q", "-p", "no:cacheprovider", "pkg/tests/test_value.py")
    old = run_at(repo, parent, *pytest_args)
    assert old.returncode == 1, old.stdout + old.stderr
    assert (
        f"run-at-sha-{parent[:10]}" in old.stdout and "mypkg resolves to" in old.stdout
    )
    assert "assert 1 == 2" in old.stdout

    new = run_at(repo, head, *pytest_args)
    assert new.returncode == 0, new.stdout + new.stderr
    assert f"run-at-sha-{head[:10]}" in new.stdout

    assert "run-at-sha" not in git(repo, "worktree", "list")
    assert not (repo / ".claude" / "worktrees" / f"run-at-sha-{parent[:10]}").exists()


def test_a_bad_sha_exits_1_and_leaves_no_worktree(tmp_path):
    repo, _, _ = make_repo(tmp_path)
    done = run_at(repo, "nosuchcommit", "-q")
    assert done.returncode == 1 and "Traceback" not in done.stderr
    assert "run-at-sha" not in git(repo, "worktree", "list")
