---
name: python-hygiene
description: "Hygiene pass for Python: run Astral's ty (type check) + ruff (lint + autofix + format). Autofix what's fixable, report what's not. Use after editing Python or before committing."
triggers:
  - python hygiene
  - check python
  - fix python
  - lint python
  - clean up python
  - ruff
  - ty check
  - run ty
  - autofix
---

# Python hygiene (ty + ruff)

Run Astral's two tools to catch and fix Python issues:

- `ruff check --fix` — lints with the project's rules and autofixes anything fixable.
- `ruff format` — applies the project's format.
- `ty check` — runs Astral's type checker.

Project rules come from `pyproject.toml` / `ruff.toml` / `ty.toml`. Don't override them on the command line.

## When to invoke

- Right after editing one or more `.py` files (especially after a non-trivial change).
- When the user says "check this", "lint this", "fix this", "is this clean?", or names ruff / ty explicitly.
- Before staging Python changes for commit.

## Steps

1. **Identify scope.** Prefer the files Claude just edited. If unclear, fall back to the package directory; only run on the whole repo if the user asks for it.

2. **Autofix with ruff first** (cheap, removes noise before type-checking):

   ```bash
   ruff check --fix <paths>
   ruff format <paths>
   ```

   Anything fixable is now fixed on disk.

3. **Re-run ruff in check-only mode** to surface what couldn't be autofixed:

   ```bash
   ruff check <paths>
   ```

   Read the remaining findings. They are real issues, not stylistic noise.

4. **Type-check with ty:**

   ```bash
   ty check <paths>
   ```

   Treat ty errors as authoritative — fix the code, not the type annotation, unless the annotation is genuinely wrong.

5. **Smell check (manual — ruff and ty don't catch these).** Open each file you touched and look for:

   - **AI-flavoured comments.** Anything written *to the human reading the diff* rather than describing a non-obvious invariant. Examples to delete: `# Now we iterate over the items`, `# Updated to fix the bug`, `# Added per review feedback`, `# Note: this works`, multi-line preambles paraphrasing the next 5 lines.
   - **Redundant comments.** If the comment restates what the next line of code already says (`# Increment counter` above `counter += 1`), delete it. A comment earns its place only when the *why* is non-obvious — hidden constraint, subtle invariant, workaround for a specific bug, behaviour that would surprise a reader.
   - **Decorative section dividers.** Delete `# -----`, `# =====`, `# ### Section ###`, `# ━━━━`, ASCII banners, and any other ornamental comment whose purpose is visual structure rather than meaning. Functions and classes are the structure.
   - **Spammy / trivial tests.** Delete tests that:
     - Assert the language works (re-export checks, isinstance on trivial objects, ABC instantiation raises `TypeError`, `hasattr(Repo, "save")`).
     - Assert that prop-forwarding, label-mapping, or render-without-crash happens — TypeScript / type checks already cover these.
     - Cannot fail when the production code is broken (test passes against an empty implementation).
     - Restate `setUp` data back to the test (`assertEqual(self.user.name, "alice")` after creating `User(name="alice")`).

   If you find any of these, delete (or fix) them in the same hygiene pass — don't leave them for "later".

6. **Soft smells (flag, don't auto-fix).** These aren't blockers; surface them in the report so the user can decide. Don't refactor without permission.

   - **Type hints — missing or baroque.**
     - Missing on public functions, methods, dataclass fields, and module-level constants used elsewhere. Internal one-liners are fine without annotations.
     - Cargo-cult complexity like `tuple[str, list[dict[str, list[Any]]]]` — when the type signature reads like a Russian novel, a `dataclass` / `TypedDict` / `NamedTuple` is almost always clearer. Suggest the refactor; don't apply it.
     - `Any` used as a punt rather than a deliberate escape hatch. Flag it; suggest the real type if obvious.
     - Don't flag legitimately complex generic types (`Callable[[Sequence[int]], Awaitable[Result[T, E]]]`) — those earn their complexity.
   - **Unreadable code.**
     - Long expression chains and nested ternaries that fight the reader. Suggest splitting into named intermediate variables.
     - Single-letter / generic names (`x`, `data`, `result`, `tmp`) at non-trivial scope. OK inside a 3-line comprehension; not OK as a function parameter.
     - Functions that do multiple things and span >50 lines, especially with mixed levels of abstraction (HTTP parsing next to business logic next to logging).
     - Deeply nested comprehensions / generators (3+ levels) — usually clearer as a `for` loop with a name.
   - **Missing abstractions or patterns.**
     - The same 5+ lines repeated 3+ times across files — flag for extraction.
     - Two functions that differ only in a single value or call — flag for parametrisation.
     - A pattern already used elsewhere in the codebase being re-implemented from scratch — point to the existing one.
     - **Calibration:** 3 similar lines is *not* a smell. Premature abstraction is worse than duplication. Only flag when the duplication is real (≥3 occurrences) and the shape is stable, or when the codebase already has an established pattern for this case.

7. **Report.** Summarise what was autofixed (count is fine), what manual issues remain, what comments / tests you removed (step 5), and the soft smells flagged for the user to decide on (step 6). End with whether ty is clean. Do NOT paste raw tool output unless the user asks.

## Rules

- **Don't add a global ignore** to silence a finding. Either fix the code or, if the rule is genuinely wrong for this codebase, suggest editing `pyproject.toml` and ask for confirmation.
- **Don't commit on RED.** If ty or ruff still reports errors after autofix, surface them to the user before continuing.
- **Don't run on third-party / vendored code** (`.venv`, `node_modules`, `dist`, generated migrations). `ruff` and `ty` already exclude these via project config — don't pass them explicitly.
- **No `--unsafe-fixes`** unless the user explicitly opts in. Default ruff autofix is safe; unsafe fixes can change semantics.
- **`ty` exits non-zero on errors.** Inspect output carefully — a single 500 in CI usually traces back to a ty error that wasn't surfaced locally.

## Why this exists

The Claude Code `LSP` tool (e.g. via the `ty` plugin in [andres-ortizl/ty-lsp-claude-code-plugin](https://github.com/andres-ortizl/ty-lsp-claude-code-plugin)) consumes symbol-intelligence operations only — hover, goto, references, symbols, call hierarchy. It does **not** surface LSP diagnostics.

To actually see ty / ruff errors, the tools have to be invoked directly. This skill does that on demand.
