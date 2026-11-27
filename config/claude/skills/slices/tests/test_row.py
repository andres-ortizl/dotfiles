import subprocess

from conftest import SLICES

LOOP = """# epic - loop

| Slice | Goal | Status |
|---|---|---|
| S1 | one | todo |
| S10 | ten | todo |
| added S1 | extra | todo |

## Other

| Slice | Goal | Status |
|---|---|---|
| S1 | elsewhere | todo |
"""


def row(path, *args):
    return subprocess.run(
        [str(SLICES), "row", str(path), *args], capture_output=True, text=True
    )


def test_exact_key_updates_only_its_row(tmp_path):
    loop = tmp_path / "loop.md"
    loop.write_text(LOOP)
    done = row(loop, "epic - loop", "S1", "Status", "done | merged")
    assert done.returncode == 0, done.stderr
    assert done.stdout.strip() == "| S1 | one | done \\| merged |"
    text = loop.read_text().split("\n")
    assert "| S1 | one | done \\| merged |" in text
    assert "| S10 | ten | todo |" in text and "| added S1 | extra | todo |" in text
    assert "| S1 | elsewhere | todo |" in text


def test_a_prefix_key_matches_nothing(tmp_path):
    loop = tmp_path / "loop.md"
    loop.write_text(LOOP)
    done = row(loop, "epic - loop", "S", "Status", "done")
    assert done.returncode == 1 and "found 0" in done.stderr
    assert loop.read_text() == LOOP


def test_unknown_key_section_and_column_exit_1(tmp_path):
    loop = tmp_path / "loop.md"
    loop.write_text(LOOP)
    for args in (
        ("epic - loop", "S99", "Status", "x"),
        ("Nope", "S1", "Status", "x"),
        ("epic - loop", "S1", "Nope", "x"),
    ):
        done = row(loop, *args)
        assert done.returncode == 1 and "Traceback" not in done.stderr
    assert loop.read_text() == LOOP
