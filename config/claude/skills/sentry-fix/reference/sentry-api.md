# Sentry API URLs — use org-scoped endpoints

**All Sentry API calls must use the org-scoped form.** Non-org-scoped endpoints return 404 for both list and mutation operations:

| Purpose | ✅ Correct | ❌ Wrong |
|---|---|---|
| List issues | `/api/0/projects/<org>/<project>/issues/` | (this one is fine for list) |
| Fetch latest event | `/api/0/organizations/<org>/issues/<id>/events/latest/` | `/api/0/issues/<id>/events/latest/` (404) |
| Resolve issue (PUT) | `/api/0/organizations/<org>/issues/<id>/` | `/api/0/issues/<id>/` (404) |

Canonical resolve call:
```bash
curl -s -X PUT "https://sentry.io/api/0/organizations/$SENTRY_ORG/issues/$issue_id/" \
  -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"resolved"}'
```

Do NOT include `statusDetails.inCommit` unless you've pre-registered the repo in Sentry's integration settings — it returns 400 with `"Unable to find the given repository."` otherwise.

Sentry issue URL format: `https://<org>.sentry.io/issues/<id>/` (subdomain = org slug, not `sentry.io/organizations/...`).
