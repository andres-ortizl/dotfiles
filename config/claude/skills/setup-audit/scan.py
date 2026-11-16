#!/usr/bin/env python3
"""Mechanical drift checks for the Claude Code setup. Prints names and counts only.

Usage: scan.py [--days N]   (default 28)

Never reads ~/.claude.json or any settings file: they can hold secrets.
"""

import argparse
import re
import subprocess
import time
from collections import Counter
from pathlib import Path

HOME = Path.home()
CLAUDE = HOME / ".claude"
DOTFILES = HOME / "code" / "dotfiles"
DOTFILES_SKILLS = DOTFILES / "config" / "claude" / "skills"
LINKED_DIRS = ["skills", "commands", "agents", "workflows"]
LOOPS = HOME / ".artifacts"
OUTCOME = re.compile(r"\[(used|dup|dropped)")


def section(title: str, lines: list[str]) -> None:
    print(f"\n## {title} ({len(lines)})")
    for line in lines or ["none"]:
        print(f"- {line}")


def dangling_links() -> list[str]:
    found = []
    for name in LINKED_DIRS:
        root = CLAUDE / name
        if root.is_dir():
            found += [
                str(p) for p in root.rglob("*") if p.is_symlink() and not p.exists()
            ]
    return found


def unversioned_skill_files() -> list[str]:
    """Files in ~/.claude/skills that are not links into dotfiles: git does not track them."""
    root = CLAUDE / "skills"
    per_folder: Counter = Counter()
    for p in root.rglob("*"):
        rel = p.relative_to(root)
        if (
            p.is_symlink()
            or p.is_dir()
            or rel.parts[0] == "synced"
            or p.name == ".DS_Store"
        ):
            continue
        per_folder[rel.parts[0] if len(rel.parts) > 1 else str(rel)] += 1
    return [f"{folder}: {n} files" for folder, n in sorted(per_folder.items())]


def unlinked_tracked_files() -> list[str]:
    """Files git tracks in the dotfiles skills folder that ~/.claude/skills does not show."""
    tracked = subprocess.run(
        ["git", "-C", str(DOTFILES), "ls-files", "config/claude/skills"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    missing = []
    for rel in tracked:
        sub = Path(rel).relative_to("config/claude/skills")
        if (
            not (CLAUDE / "skills" / sub).exists()
            and not (CLAUDE / "skills" / sub.parts[0]).is_symlink()
        ):
            missing.append(str(sub))
    return missing


def personal_skills() -> list[str]:
    root = CLAUDE / "skills"
    return sorted(
        p.name
        for p in root.iterdir()
        if (p / "SKILL.md").exists() or (p / "skill.md").exists()
    )


def shadowed(personal: list[str]) -> list[str]:
    """A personal skill with the same name as a repo skill hides the repo's copy."""
    found = []
    for repo in sorted((HOME / "code").iterdir()):
        skills = repo / ".claude" / "skills"
        if skills.is_dir():
            found += [
                f"{name} hides {repo.name}/.claude/skills/{name}"
                for name in personal
                if (skills / name).is_dir()
            ]
    return found


def usage(names: list[str], days: int) -> Counter:
    cutoff = time.time() - days * 86400
    pattern = re.compile(r'"skill":"([\w:.-]+)"|<command-name>/([\w:.-]+)<')
    counts: Counter = Counter()
    for f in (CLAUDE / "projects").glob("*/*.jsonl"):
        if f.stat().st_mtime < cutoff:
            continue
        with f.open(errors="ignore") as fh:
            for line in fh:
                for m in pattern.finditer(line):
                    counts[m.group(1) or m.group(2)] += 1
    return Counter({n: counts.get(n, 0) for n in names})


def open_signals() -> list[str]:
    found = []
    for f in sorted(LOOPS.glob("*/loops/*/signals.md")):
        lines = [
            x for x in f.read_text(errors="ignore").splitlines() if x.startswith("- ")
        ]
        pending = sum(1 for x in lines if not OUTCOME.search(x))
        if pending:
            found.append(
                f"{f.parent.relative_to(LOOPS)}: {pending} of {len(lines)} without outcome"
            )
    return found


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=28)
    days = parser.parse_args().days

    section("Dangling links under ~/.claude", dangling_links())
    section(
        "Files in ~/.claude/skills that git does not track", unversioned_skill_files()
    )
    section(
        "Tracked skill files missing from ~/.claude/skills (run dotbot)",
        unlinked_tracked_files(),
    )
    names = personal_skills()
    section("Personal skills that hide a repo skill", shadowed(names))
    counts = usage(names, days)
    section(
        f"Personal skill uses in the last {days} days",
        [f"{n}: {c}" for n, c in sorted(counts.items(), key=lambda x: x[1])],
    )
    section("Loops with signals no retro has given an outcome", open_signals())


if __name__ == "__main__":
    main()
