---
name: pr-tour
description: Build a guided review page for a pull request, ordered by execution flow instead of by file, with a verdict and a comment per stop persisted in the page. Use when the user says a PR is hard to review, asks for a tour, a walkthrough, or "review this PR in order".
---

# pr-tour

GitHub orders a diff by path. A tour orders it by what runs first. Each stop is a
few hunks that belong together in the execution flow, a short "why it is here",
the tests that prove it, and a verdict (OK / Cambiar / Pregunta) plus a comment
that the page saves. The lead reads the verdicts back with `read_db` and turns
them into the next coder round, then republishes the tour so the stops show
what changed since the reviewer's comment.

## Quick start

```
S=$DOTFILES/config/claude/skills/pr-tour/scripts
T=<workdir for this PR>                      # e.g. ~/.artifacts/<repo>/<epic>/tour
python3 $S/hunks.py <worktree> <base-sha> <head-sha> $T/hunks.json   # prints the hunk index
python3 $S/tests_index.py $T/hunks.json                            # tests added per hunk
python3 $S/show.py $T/hunks.json snapshot.py > $T/snapshot.diff      # read the diff per file
python3 $S/build.py index $T/hunks.json 'snapshot.py#6'              # line indexes, to slice a hunk
# write $T/tour.json (see below)
python3 $S/build.py $T/tour.json $T/hunks.json $S/../template.html $T/<name>.html
python3 $S/check.py $T/<name>.html                                   # slices start where you meant
```

Then publish `$T/<name>.html` with the Artifact tool, `capabilities: {db: {}, user: {}}`,
one favicon for the life of the tour. Republish the same path after every coder round.

Base is the merge-base with the target branch (`git merge-base HEAD origin/dev`),
never the target branch tip, or the tour shows other people's commits.

## Writing tour.json

The order is the whole value of the tour and no script can produce it: read the
diff, find the entry points (the actor, the endpoint, the command), and walk the
call path. One flow per entry point; four is plenty. Inside a flow, a stop is
one idea: what a reader would want to see on one screen before moving on.
Twenty stops for eighty hunks is a good ratio.

```json
{
  "id": "any-1234-pr-5678",            // db path segment: letters, digits, "-"
  "title": "Tour PR 5678", "subtitle": "one line", "pr": "<url>", "repo": "<repo url>",
  "flows": [{
    "id": "publish", "name": "Publicar", "blurb": "what this flow is, one or two sentences",
    "stops": [{
      "id": "publish-01", "title": "…",
      "why": "two to five sentences; **bold** and `code` allowed",
      "hunks": ["s3_utils.py#1", "snapshot.py#6:0-47"],
      "tests": ["test_knowledge_snapshot.py::test_name"],
      "notes": [{"kind": "greptile", "text": "an open finding on this stop and who owns it"}]
    }]
  }]
}
```

- `file.py#n` is the n-th hunk of that file; `#n:a-b` slices it by the line
  indexes `build.py index` prints (inclusive). A hunk may appear in two stops.
- `tests` are sliced out of whichever hunk adds the `def`; test hunks listed in
  `hunks` (assertions added to existing tests) render under the same "Pruebas"
  fold because their path contains `/tests/`.
- Every hunk must land in a stop: `build.py` prints the leftovers and the page
  shows them at the end. Imports go with the first stop that uses them.
- Write the narration in the reviewer's language and in plain words. Say why the
  code is there and what would break without it, not what the lines do.
- A stop with a known open finding (Greptile, validator) carries it as a note, so
  the reviewer does not re-find it.

## The loop

1. Reviewer reads the page, marks each stop, comments. Saved per stop at
   `reviews/<tour.id>/stops/<stop.id>` with `{verdict, comment, sig, head, updatedAt}`.
2. Lead: `Artifact read_db` (`list` on that collection). "change" and "ask" become
   the coder brief; answer "ask" in the chat.
3. Coder pushes. Lead re-runs `hunks.py` on the new head, edits `tour.json` where
   hunks moved (ids are per file and ordinal, so an inserted hunk shifts the ones
   after it: re-check with `build.py index`), rebuilds, republishes the same path.
   A stop whose content changed shows "cambió desde tu comentario"; verdicts stay.
4. Repeat until every stop is OK. The summary view copies the review as Markdown.

## What the page does

Rail with flows and stops, an execution-flow strip per flow, one stop at a time
with syntax-highlighted hunks and `file:line` links to the head sha on GitHub,
tests folded under the stop, keyboard `j`/`k`, `1`/`2`/`3`, `c`. Verdicts write to
the artifact db when it is available and to `localStorage` otherwise (the badge
in the header says which). Light and dark themes, reduced motion respected.
