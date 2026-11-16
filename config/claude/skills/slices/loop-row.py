"""Set one cell of one row in a markdown table of a loop file, found by its section and its first cell.

Usage: loop-row.py <file> <section heading> <row key> <column name> <value>
Example: loop-row.py loop.md "Slices" C Status "done (merged 2026-11-11)"
"""

import sys


def cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def main(path: str, section: str, key: str, column: str, value: str) -> None:
    lines = open(path).read().split("\n")
    start = next(
        (
            i
            for i, line in enumerate(lines)
            if line.startswith("#") and line.lstrip("#").strip() == section
        ),
        None,
    )
    if start is None:
        sys.exit(f"no section '{section}' in {path}")
    header = next(i for i in range(start + 1, len(lines)) if lines[i].startswith("|"))
    names = cells(lines[header])
    if column not in names:
        sys.exit(f"no column '{column}' in section '{section}': {names}")
    rows = []
    for i in range(header + 2, len(lines)):
        if not lines[i].startswith("|"):
            break
        if cells(lines[i])[0] == key:
            rows.append(i)
    if len(rows) != 1:
        sys.exit(f"expected one row '{key}' in section '{section}', found {len(rows)}")
    row = cells(lines[rows[0]])
    row[names.index(column)] = value.replace("|", "\\|")
    lines[rows[0]] = "| " + " | ".join(row) + " |"
    open(path, "w").write("\n".join(lines))
    print(lines[rows[0]])


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])
