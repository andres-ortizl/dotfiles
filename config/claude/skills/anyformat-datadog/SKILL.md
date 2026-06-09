---
name: anyformat-datadog
description: Query and debug anyformat's Datadog observability (logs, metrics, traces, monitors, incidents) via the plugin:datadog:mcp server, accounting for our non-standard loguru log structure. Use when searching or debugging anyformat logs/metrics/traces/monitors/incidents in Datadog, or when a Datadog log search for anyformat-core/backend returns 0 results.
---

# anyformat Datadog

Querying anyformat's observability through `plugin:datadog:mcp`. The thing that wastes time if you don't know it: **our service logs are non-standard** — read the gotcha before searching.

## Setup
- Site: **EU** → MCP domain `mcp.datadoghq.eu`, server id `plugin:datadog:mcp`.
- First call each session: do the MCP's own skill discovery — `load_datadog_skill('datadog/logs')` (or `datadog/traces`, `datadog/metrics`) **and** `list_datadog_skills(query=...)` in parallel, per the server's instructions. Then use the tools.

## ⚠️ The log-structure gotcha (read first)
`anyformat-core` and `backend` ship **loguru** logs where the human-readable message is in the **`@custom.text`** attribute (also `@custom.record.message`). The standard Datadog **`message` field is EMPTY**, and `@custom.text` is **not a registered facet**.

Consequence: **text search on these logs silently returns 0 even when the logs exist.** Do NOT trust a zero result from any of these on core/backend logs:
- free-text (`"Parse cache HIT"`)
- attribute search (`@custom.text:"..."`)
- `analyze_datadog_logs` with `@custom.text` in `extra_columns` (binds to null, or errors `cannot be resolved`)
- `use_log_patterns` clustering on `@custom.text` (collapses to one blank pattern)

You can filter on real tags — just not on the message text.

## What works for filtering
Real tags: `service` (`anyformat-core`, `backend`, `api`), `env` (`dev` / `prod`), `status` (`info`/`warn`/`error`), `host`, `version`. Useful attrs under `@custom.record.extra`: `extraction_id`, `workflow_name`.

## How to read the actual log text
`search_datadog_logs` with `extra_fields=['*']`, then read the message client-side from the returned `attributes`:
- `custom.text` — the rendered message
- `custom.record.message` — same message; plus `custom.record.{file,function,line,module,level}` for the source location

You cannot *filter* or *aggregate* on the text — only fetch and eyeball. Narrow the fetch with real tags (service/env/status) and a small time window so the text you want is in the first page.

## Recipes

**Confirm a feature/log line is firing in dev** (the common "is my change working?" check):
1. `search_datadog_logs(query="service:anyformat-core env:dev", from="now-1h", extra_fields=["*"], sort="-timestamp")`.
2. Read `attributes.custom.text` in the results for your line. (A free-text search for the line will falsely return 0 — that's the gotcha, not evidence the code isn't running.)
3. Too noisy? Add `status:` or narrow the window; or scan `custom.record.extra.workflow_name`.

**Recent errors in a service:**
- `search_datadog_logs(query="service:anyformat-core env:prod status:error", from="now-4h", extra_fields=["*"])` → read `custom.record.message` + `custom.record.{file,function,line}` for the origin. (`status` is a real tag, so this filter works.)

**Count / aggregate:** `analyze_datadog_logs` works on the standard columns (`service`, `env`, `status`, `host`, `version`, `timestamp`) and any *facetized* attribute — but NOT on `@custom.text`. Count by tag, never by message text.

## Root fix (recommended; not done yet)
The real fix is a **Datadog log pipeline remap** so the loguru message maps to the standard `message` attribute (and/or a facet on `@custom.text`). After that, normal text search + aggregation + monitors work and most of this skill's workarounds become unnecessary. The MCP is read-only — apply this in the Datadog UI / API / Terraform.
