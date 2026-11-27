import subprocess
from pathlib import Path

import pytest
from conftest import SLICES


def git(cwd, *args):
    done = subprocess.run(
        ["git", "-C", str(cwd), *args], capture_output=True, text=True, check=True
    )
    return done.stdout.strip()


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


@pytest.fixture(scope="module")
def repo(tmp_path_factory) -> tuple[Path, str, str]:
    """Three layouts that change between two commits, each with a test written for the new behaviour.

    The venv lists the source roots in an editable .pth, as `uv sync` does for a workspace.
    """
    root = tmp_path_factory.mktemp("ras") / "repo"
    subprocess.run(["git", "init", "-q", "-b", "main", str(root)], check=True)
    git(root, "config", "user.email", "t@example.com")
    git(root, "config", "user.name", "t")
    write(root / ".gitignore", ".venv\n")
    write(root / "pkg/src/mypkg/__init__.py", "VALUE = 1\n")
    write(
        root / "pkg/tests/test_value.py",
        "import mypkg\n\ndef test_value():\n    assert mypkg.VALUE == 2\n",
    )
    write(root / "ns/src/ns/a/__init__.py", "V = 1\n")
    write(
        root / "ns/tests/test_ns.py",
        "def test_b():\n    import ns.b\n\n    assert ns.b.V == 2\n",
    )
    write(root / "flat/flatpkg/__init__.py", "V = 1\n")
    write(
        root / "flat/tests/test_flat.py",
        "import flatpkg\n\ndef test_v():\n    assert flatpkg.V == 2\n",
    )
    git(root, "add", ".")
    git(root, "commit", "-q", "-m", "parent")
    parent = git(root, "rev-parse", "HEAD")
    write(root / "pkg/src/mypkg/__init__.py", "VALUE = 2\n")
    write(root / "ns/src/ns/b/__init__.py", "V = 2\n")
    write(root / "flat/flatpkg/__init__.py", "V = 2\n")
    git(root, "add", ".")
    git(root, "commit", "-q", "-m", "head")
    head = git(root, "rev-parse", "HEAD")
    subprocess.run(["uv", "venv", "-q", str(root / ".venv")], check=True)
    subprocess.run(
        [
            "uv",
            "pip",
            "install",
            "-q",
            "--python",
            str(root / ".venv/bin/python"),
            "pytest",
        ],
        check=True,
    )
    (site,) = (root / ".venv/lib").glob("python*/site-packages")
    write(site / "editable.pth", f"{root}/pkg/src\n{root}/ns/src\n{root}/flat\n")
    return root, parent, head


def run_at(repo: Path, sha: str, *pytest_args: str):
    return subprocess.run(
        [
            str(SLICES),
            "run-at-sha",
            str(repo),
            sha,
            "--",
            "-q",
            "-p",
            "no:cacheprovider",
            *pytest_args,
        ],
        capture_output=True,
        text=True,
    )


@pytest.mark.parametrize(
    "test_file",
    ["pkg/tests/test_value.py", "ns/tests/test_ns.py", "flat/tests/test_flat.py"],
)
def test_fails_at_the_parent_and_passes_at_head_and_leaves_no_worktree(repo, test_file):
    root, parent, head = repo
    old = run_at(root, parent, test_file)
    assert old.returncode == 1, old.stdout + old.stderr
    assert f"run-at-sha-{parent[:10]}" in old.stdout

    new = run_at(root, head, test_file)
    assert new.returncode == 0, new.stdout + new.stderr

    assert "run-at-sha" not in git(root, "worktree", "list")
    assert not (root / ".claude/worktrees" / f"run-at-sha-{parent[:10]}").exists()


def test_prints_one_line_per_mapped_root(repo):
    root, parent, _ = repo
    out = run_at(root, parent, "pkg/tests/test_value.py").stdout
    detached = root / ".claude/worktrees" / f"run-at-sha-{parent[:10]}"
    for rel in ("pkg/src", "ns/src", "flat"):
        assert f"{root}/{rel} -> {detached}/{rel}" in out


def test_an_editable_path_missing_at_the_sha_is_left_out(repo):
    root, parent, _ = repo
    git(root, "checkout", "-q", "--orphan", "bare")
    git(root, "rm", "-rqf", ".")
    write(root / "keep.txt", "x\n")
    git(root, "add", "keep.txt")
    git(root, "commit", "-q", "-m", "bare")
    bare = git(root, "rev-parse", "HEAD")
    git(root, "checkout", "-q", "-f", "main")
    done = run_at(root, bare, "-k", "nothing")
    assert "missing at" in done.stdout
    assert "run-at-sha" not in git(root, "worktree", "list")


def test_a_bad_sha_exits_1_and_leaves_no_worktree(repo):
    root, _, _ = repo
    done = run_at(root, "nosuchcommit")
    assert done.returncode == 1 and "Traceback" not in done.stderr
    assert "run-at-sha" not in git(root, "worktree", "list")
