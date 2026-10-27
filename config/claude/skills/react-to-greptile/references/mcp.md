# Method: Greptile MCP

Use this when `mcp__greptile__get_me` succeeds. Replies and thread resolution still go through `gh` GraphQL; the MCP has no tool for them.

## The repository tuple

Every PR tool takes the same tuple. Build it once:

- `name`: `<owner>/<repo>`
- `remote`: `github`
- `defaultBranch`: the repository's default branch, not the PR base: `gh repo view "$REPO" --json defaultBranchRef -q .defaultBranchRef.name`
- `prNumber`: the PR number

`defaultBranch` is required on every call, even where the schema marks it optional.

## Read the summary

1. `mcp__greptile__get_merge_request(<tuple>)` returns:
   - `reviewAnalysis.hasNewCommitsSinceReview`: true means the latest review predates HEAD.
   - `reviewAnalysis.reviewCompleteness`: for example "3/5 Greptile comments addressed".
   - `codeReviews[]`: the reviews of this PR, with their `codeReviewId` and status.
2. `mcp__greptile__get_code_review(codeReviewId)` on the newest completed review returns its `body`: the summary with the confidence score and the summary-only findings.

Greptile's `addressed` flag is its own judgement. It is not the GitHub thread state, so it never replaces the GraphQL thread query in Phase 2.

## Trigger a review

1. Post the context comment **without** any `@greptile` mention, so it does not start a second review:
   ```bash
   gh pr comment <number> --repo "$REPO" --body "$(cat <<'EOF'
   Addressed in <sha>.

   Summary-only items resolved:
   - <finding> - fixed in <sha>
   EOF
   )"
   ```
2. Call `mcp__greptile__trigger_code_review(<tuple>)`. Success means the review is queued, not finished. Wait with the Phase 7 loop.

After the loop, confirm with `mcp__greptile__list_code_reviews(<tuple>, limit: 1)`: the newest review has `status: COMPLETED` and `metadata.headSha` equal to `$SHA`. `FAILED` or `SKIPPED` means no new verdict; report it.

## Recurring findings

`mcp__greptile__search_greptile_comments` searches Greptile comments across all PRs. When a finding repeats, propose a rule in `.greptile/` or a lesson in `docs/memory/` instead of fixing it PR by PR.
