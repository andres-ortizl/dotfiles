import json
import os
import pty
import re
import subprocess

import pytest

from conftest import HEAD, SLICES, blockers

OLD = "b" * 40
RUNNING = {"name": "test", "status": "IN_PROGRESS", "conclusion": ""}
FAILED = {"name": "lint", "status": "COMPLETED", "conclusion": "FAILURE"}
PASSED = {"name": "test", "status": "COMPLETED", "conclusion": "SUCCESS"}
DRAWING = re.compile(r"\x1b|[─-╿]")


def only(fake, number=1):
    data = fake.status(f"o/r#{number}")
    return next(p for p in data["prs"] if p["pr"] == number), data


def kinds(pr):
    return [b["kind"] for b in pr["blockers"]]


def run_on_tty(fake, extra_env=None):
    fake.path.write_text(json.dumps(fake.fixtures))
    env = {
        **os.environ,
        "PATH": f"{fake.bin}{os.pathsep}{os.environ['PATH']}",
        "FAKE_GH_FIXTURES": str(fake.path),
    }
    env.pop("NO_COLOR", None)
    env.update(extra_env or {})
    leader, follower = pty.openpty()
    child = subprocess.Popen(
        [str(SLICES), "status", "o/r#1"],
        stdout=follower,
        stdin=subprocess.DEVNULL,
        env=env,
    )
    os.close(follower)
    out = b""
    while True:
        try:
            chunk = os.read(leader, 1 << 16)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    os.close(leader)
    assert child.wait() == 0
    return out.decode()


def test_ready_pr_has_no_blockers(fake):
    fake.pr(1)
    pr, data = only(fake)
    assert pr["ready"] is True and pr["blockers"] == []
    assert pr["ci"] == {"state": "ok", "failed": [], "pending": []}
    assert pr["bot"] == {"score": 5, "reviewed_sha": HEAD, "stale": False}
    assert pr["open_threads"] == 0 and pr["behind"] == 0
    assert data["schema"] == 1 and data["signals_open"] is None


def test_json_keys(fake):
    fake.pr(1)
    pr, data = only(fake)
    assert set(data) == {"schema", "prs", "signals_open"}
    expected = {
        "pr",
        "repo",
        "url",
        "state",
        "base",
        "head",
        "ci",
        "bot",
        "open_threads",
        "mergeable",
        "behind",
        "ready",
        "blockers",
    }
    assert expected <= set(pr)
    assert pr["head"] == HEAD and pr["repo"] == "o/r" and pr["state"] == "open"


def test_ci_pending(fake):
    fake.pr(1, checks=[RUNNING])
    pr, _ = only(fake)
    assert kinds(pr) == ["ci_pending"]
    assert pr["ci"]["pending"] == ["test"] and pr["ready"] is False


def test_missing_checks_are_pending(fake):
    fake.pr(1, checks=[])
    pr, _ = only(fake)
    assert kinds(pr) == ["ci_pending"]
    assert pr["ci"]["state"] == "none"


def test_ci_failed(fake):
    fake.pr(1, checks=[PASSED, FAILED])
    pr, _ = only(fake)
    assert kinds(pr) == ["ci_failed"]
    assert pr["ci"]["failed"] == ["lint"]


def test_bot_missing(fake):
    fake.pr(1, score=None)
    pr, _ = only(fake)
    assert kinds(pr) == ["bot_missing"]
    assert pr["bot"]["score"] is None


def test_bot_below_threshold(fake):
    fake.pr(1, score=3)
    pr, _ = only(fake)
    assert kinds(pr) == ["bot_below_threshold"]


def test_stale_score_is_a_note_not_a_blocker(fake):
    fake.pr(1, score=4, reviewed=OLD)
    pr, _ = only(fake)
    assert pr["ready"] is True and pr["blockers"] == []
    assert pr["bot"]["stale"] is True and pr["bot"]["reviewed_sha"] == OLD
    assert [n["kind"] for n in pr["notes"]] == ["bot_stale"]


def test_open_threads_count_only_unresolved_bot_threads(fake):
    fake.pr(1, threads=2)
    pr, _ = only(fake)
    assert kinds(pr) == ["open_threads"]
    assert pr["open_threads"] == 2


def test_conflict(fake):
    fake.pr(1, mergeable="CONFLICTING")
    pr, _ = only(fake)
    assert kinds(pr) == ["conflict"]


def test_draft(fake):
    fake.pr(1, draft=True)
    pr, _ = only(fake)
    assert kinds(pr) == ["draft"]


def test_base_moved_on_a_file_the_pr_changes(fake):
    moved = {"ahead_by": 2, "files": [{"filename": "a.py"}, {"filename": "b.py"}]}
    fake.pr(1, behind=2, moved=moved, pr_files=["b.py", "z.py"])
    pr, _ = only(fake)
    (blocker,) = pr["blockers"]
    assert blocker["kind"] == "base_moved"
    assert blocker["commits"] == 2 and blocker["files"] == ["b.py"]
    assert pr["behind"] == 2


def test_base_moved_on_other_files_does_not_block(fake):
    fake.pr(
        1,
        behind=2,
        moved={"ahead_by": 2, "files": [{"filename": "a.py"}]},
        pr_files=["z.py"],
    )
    pr, _ = only(fake)
    assert pr["ready"] is True and pr["behind"] == 2


def test_base_moved_ignores_ci_rerun_times(fake):
    checks = [
        {**PASSED, "completedAt": "2026-11-20T10:00:00Z"},
        {**PASSED, "name": "lint", "completedAt": "2026-11-20T12:00:00Z"},
    ]
    fake.pr(
        1,
        behind=1,
        checks=checks,
        moved={"ahead_by": 1, "files": [{"filename": "b.py"}]},
        pr_files=["b.py"],
    )
    pr, _ = only(fake)
    assert kinds(pr) == ["base_moved"]


def test_base_moved_fails_closed_at_the_300_file_cap(fake):
    files = [{"filename": f"f{i}.py"} for i in range(300)]
    fake.pr(1, behind=5, moved={"ahead_by": 5, "files": files}, pr_files=["z.py"])
    pr, _ = only(fake)
    (blocker,) = pr["blockers"]
    assert blocker["kind"] == "base_moved"
    assert (
        blocker["detail"]
        == "unknown: the base changed more than 300 files since the merge base; merge the base in"
    )


@pytest.mark.parametrize(
    "failing", ["compare/dev...", f"compare/{'m' * 40}...dev", "pulls/1/files"]
)
def test_base_moved_fails_closed_when_gh_fails(fake, failing):
    fake.add(failing, out=None, rc=1)
    fake.pr(
        1, moved={"ahead_by": 1, "files": [{"filename": "a.py"}]}, pr_files=["a.py"]
    )
    pr, _ = only(fake)
    (blocker,) = pr["blockers"]
    assert blocker["kind"] == "base_moved" and blocker["detail"].startswith("unknown: ")
    assert "\n" not in blocker["detail"]


def test_ready_iff_no_blockers(fake):
    fake.pr(1)
    fake.pr(2, checks=[FAILED], score=3, threads=1, mergeable="CONFLICTING")
    data = fake.status("o/r#1", "o/r#2")
    for pr in data["prs"]:
        assert pr["ready"] == (pr["blockers"] == [])
    assert blockers(data, 2) == [
        "ci_failed",
        "bot_below_threshold",
        "open_threads",
        "conflict",
    ]


def test_stacked_pr_waits_for_its_parent(fake):
    fake.pr(1, ref="parent", checks=[RUNNING])
    fake.pr(2, ref="child", base="parent", head="d" * 40, reviewed="d" * 40)
    data = fake.status("o/r#1", "o/r#2")
    assert blockers(data, 2) == ["stack_parent_not_ready"]
    child = next(p for p in data["prs"] if p["pr"] == 2)
    assert (
        child["blockers"][0]["detail"] == "base #1 not ready"
        and child["ready"] is False
    )


def test_stacked_pr_is_ready_when_parent_is(fake):
    fake.pr(1, ref="parent")
    fake.pr(2, ref="child", base="parent", head="d" * 40, reviewed="d" * 40)
    data = fake.status("o/r#1", "o/r#2")
    assert blockers(data, 2) == [] and blockers(data, 1) == []


def test_stacked_pr_skips_a_ready_parent_and_finds_the_grandparent(fake):
    fake.pr(1, ref="a", checks=[FAILED])
    fake.pr(2, ref="b", base="a", head="d" * 40, reviewed="d" * 40)
    fake.pr(3, ref="c", base="b", head="e" * 40, reviewed="e" * 40)
    data = fake.status("o/r#1", "o/r#2", "o/r#3")
    assert blockers(data, 3) == ["stack_parent_not_ready"]
    assert (
        next(p for p in data["prs"] if p["pr"] == 3)["blockers"][0]["detail"]
        == "base #1 not ready"
    )


def test_merged_pr(fake):
    fake.pr(1, state="MERGED", merge_commit="f" * 40)
    pr, _ = only(fake)
    assert pr["state"] == "merged" and pr["ready"] is False and pr["blockers"] == []
    assert pr["merge_commit"] == "f" * 40


def test_child_of_a_merged_parent_must_retarget(fake):
    fake.pr(1, ref="parent", state="MERGED", merge_commit="f" * 40)
    fake.pr(
        2,
        ref="child",
        base="parent",
        head="d" * 40,
        reviewed="d" * 40,
        parent_prs=[{"number": 1, "state": "MERGED"}],
    )
    child = next(p for p in fake.status("o/r#1", "o/r#2")["prs"] if p["pr"] == 2)
    assert kinds(child) == ["stack_parent_not_ready"]
    assert (
        child["blockers"][0]["detail"] == "base branch belongs to merged #1; retarget"
    )


def test_child_of_a_closed_unlisted_parent_must_retarget(fake):
    fake.pr(
        2, ref="child", base="parent", parent_prs=[{"number": 9, "state": "CLOSED"}]
    )
    pr, _ = only(fake, 2)
    assert pr["blockers"][0]["detail"] == "base branch belongs to closed #9; retarget"


def test_unlisted_open_parent_that_is_not_ready_blocks_its_child(fake):
    fake.pr(9, ref="parent", checks=[FAILED])
    fake.pr(2, ref="child", base="parent", parent_prs=[{"number": 9, "state": "OPEN"}])
    data = fake.status("o/r#2")
    assert [p["pr"] for p in data["prs"]] == [2]
    assert blockers(data, 2) == ["stack_parent_not_ready"]
    assert data["prs"][0]["blockers"][0]["detail"] == "base #9 not ready"


def test_unlisted_open_parent_that_is_ready_does_not_block(fake):
    fake.pr(9, ref="parent")
    fake.pr(2, ref="child", base="parent", parent_prs=[{"number": 9, "state": "OPEN"}])
    assert blockers(fake.status("o/r#2"), 2) == []


def test_protected_base_with_old_closed_prs_is_not_a_stack(fake):
    fake.pr(
        2,
        ref="release",
        base="main",
        base_protected=True,
        parent_prs=[{"number": 9, "state": "CLOSED"}],
    )
    assert blockers(fake.status("o/r#2"), 2) == []


def test_base_without_a_pr_does_not_block(fake):
    fake.pr(2, ref="child", base="release/1")
    assert blockers(fake.status("o/r#2"), 2) == []


def test_pr_urls_are_accepted(fake):
    fake.pr(7, repo="acme/app")
    done = fake.run("status", "--json", "https://github.com/acme/app/pull/7")
    assert json.loads(done.stdout)["prs"][0]["repo"] == "acme/app"


def test_loop_file_lists_linked_prs_and_counts_open_signals(fake, tmp_path):
    loop = tmp_path / "loop"
    loop.mkdir()
    (loop / "loop.md").write_text(
        "| S1 | x | merged | | https://github.com/o/r/pull/2 |\n| S2 | y | pr | | https://github.com/o/r/pull/1 |\n"
    )
    (loop / "signals.md").write_text(
        "# signals\n- one\n- two [used]\n- three [dup]\n- four [dropped: no]\n- five\n"
    )
    fake.pr(1)
    fake.pr(2, state="MERGED", merge_commit="f" * 40)
    data = fake.status(str(loop))
    assert [p["pr"] for p in data["prs"]] == [1, 2]
    assert data["signals_open"] == 2


def test_check_exit_codes(fake):
    fake.pr(1)
    fake.pr(2, checks=[FAILED])
    fake.pr(3, state="MERGED", merge_commit="f" * 40)
    assert fake.run("status", "--check", "o/r#1", "o/r#3").returncode == 0
    assert fake.run("status", "--check", "o/r#1", "o/r#2").returncode == 3
    assert fake.run("status", "o/r#2").returncode == 0


def test_wait_times_out_with_one_stderr_line(fake):
    fake.pr(1, checks=[RUNNING])
    done = fake.run("status", "--wait", "--timeout", "1", "--interval", "1", "o/r#1")
    assert done.returncode == 1
    assert len(done.stderr.strip().splitlines()) == 1 and "timed out" in done.stderr


def test_wait_returns_when_nothing_is_pending(fake):
    fake.pr(1, checks=[FAILED])
    done = fake.run("status", "--wait", "--timeout", "5", "--interval", "1", "o/r#1")
    assert done.returncode == 0 and "CI failed" in done.stdout


def test_plain_output_has_no_ansi_or_box_characters(fake):
    fake.pr(1, score=4, reviewed=OLD)
    fake.pr(2, checks=[FAILED])
    done = fake.run("status", "o/r#1", "o/r#2")
    assert done.returncode == 0, done.stderr
    assert not DRAWING.search(done.stdout)
    lines = done.stdout.strip().splitlines()
    assert len(lines) == 2
    assert "READY yes" in lines[0] and "stale@" in lines[0]
    assert "READY no: CI failed: lint" in lines[1]


def test_tty_output_is_a_rich_table(fake):
    fake.pr(1)
    assert re.search(r"[─-╿]", run_on_tty(fake))


def test_no_color_forces_plain_output_on_a_tty(fake):
    fake.pr(1)
    out = run_on_tty(fake, {"NO_COLOR": "1"})
    assert not DRAWING.search(out) and "READY yes" in out


def test_bad_reference_is_one_stderr_line(fake):
    done = fake.run("status", "nonsense")
    assert done.returncode == 1 and "Traceback" not in done.stderr
    assert len(done.stderr.strip().splitlines()) == 1


def test_gh_failure_is_one_stderr_line_without_traceback(fake):
    fake.add("pr view 1", out=None, rc=1)
    done = fake.run("status", "o/r#1")
    assert done.returncode == 1 and "Traceback" not in done.stderr
    assert len(done.stderr.strip().splitlines()) == 1


@pytest.mark.parametrize(
    ("check", "expected"),
    [
        ({"context": "required-ci", "state": "EXPECTED"}, "ci_pending"),
        ({"name": "t", "status": "QUEUED", "conclusion": ""}, "ci_pending"),
        ({"name": "t", "status": "WAITING", "conclusion": ""}, "ci_pending"),
        ({"context": "legacy", "state": "PENDING"}, "ci_pending"),
        (
            {"name": "t", "status": "COMPLETED", "conclusion": "STARTUP_FAILURE"},
            "ci_failed",
        ),
        (
            {"name": "t", "status": "COMPLETED", "conclusion": "ACTION_REQUIRED"},
            "ci_failed",
        ),
        ({"name": "t", "status": "COMPLETED", "conclusion": "STALE"}, "ci_failed"),
        ({"context": "legacy", "state": "FAILURE"}, "ci_failed"),
    ],
)
def test_ci_is_an_allow_list(fake, check, expected):
    fake.pr(1, checks=[PASSED, check])
    pr, _ = only(fake)
    assert kinds(pr) == [expected]


@pytest.mark.parametrize(
    "check",
    [
        {"name": "t", "status": "COMPLETED", "conclusion": "NEUTRAL"},
        {"name": "t", "status": "COMPLETED", "conclusion": "SKIPPED"},
        {"context": "legacy", "state": "SUCCESS"},
    ],
)
def test_neutral_skipped_and_successful_statuses_are_green(fake, check):
    fake.pr(1, checks=[PASSED, check])
    pr, _ = only(fake)
    assert pr["ready"] is True and pr["ci"]["state"] == "ok"


def test_mergeable_unknown_after_the_retry_is_its_own_blocker(fake):
    fake.pr(1, mergeable="UNKNOWN")
    pr, _ = only(fake)
    assert kinds(pr) == ["mergeable_unknown"] and pr["ready"] is False


def test_mergeable_unknown_resolved_by_the_retry(fake):
    fake.pr(1, mergeable="UNKNOWN", mergeable_retry="MERGEABLE")
    pr, _ = only(fake)
    assert pr["ready"] is True and pr["mergeable"] == "MERGEABLE"


def test_wait_treats_mergeable_unknown_as_pending(fake):
    fake.pr(1, mergeable="UNKNOWN")
    done = fake.run("status", "--wait", "--timeout", "1", "--interval", "1", "o/r#1")
    assert done.returncode == 1 and "timed out" in done.stderr


def test_open_threads_are_paged(fake):
    fake.pr(1, threads=1, thread_page2=2)
    pr, _ = only(fake)
    assert pr["open_threads"] == 3


def test_usage_error_is_one_plain_stderr_line(fake):
    done = fake.run("status")
    assert done.returncode == 1
    assert len(done.stderr.strip().splitlines()) == 1 and done.stderr.startswith(
        "slices: "
    )
    assert not DRAWING.search(done.stderr)


@pytest.mark.parametrize("command", ["status", "row", "run-at-sha"])
def test_help_shows_one_example(fake, command):
    done = fake.run(command, "--help")
    assert done.returncode == 0 and done.stdout.count("Example:") == 1
