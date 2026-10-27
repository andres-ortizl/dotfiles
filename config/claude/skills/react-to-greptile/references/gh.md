# Method: gh only

Use this when the Greptile MCP server is not installed or not signed in.

## Read the summary

Greptile re-posts its summary on every review. Read only the latest one:

```bash
gh api "/repos/$REPO/issues/<number>/comments" --paginate \
  --jq '[.[] | select(.user.login | ascii_downcase | contains("greptile"))] | sort_by(.created_at) | last | .body'
```

Filter with `contains("greptile")`. The bot's login is `greptile-apps[bot]`, so an exact `=="greptile-apps"` match returns nothing.

The summary names its "Last reviewed commit". After Phase 7, check that it equals `$SHA`. If it does not, the summary is from an older review.

## Trigger a review

Post one PR comment that holds both the context and the trigger phrase:

```bash
gh pr comment <number> --repo "$REPO" --body "$(cat <<'EOF'
@greptile review

Addressed in <sha>. Please re-check each open thread and re-score.

Summary-only items resolved:
- <finding> - fixed in <sha>
EOF
)"
```

Only a comment containing `@greptile review` starts a review. A bare `@greptile-apps` mention does not, and a push does not start one in this repo.
