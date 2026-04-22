---
name: anyformat-workflow
description: "Create an anyformat workflow (graph + extraction schema) against the local backend, upload a PDF, and fetch results. Covers all 10 node types. Use when the user asks to build/create/spin up a workflow, upload a schema, or run a document through the local backend."
triggers:
  - create workflow
  - new workflow
  - upload schema
  - upload pdf
  - run workflow locally
---

# anyformat-workflow

End-to-end recipe for creating a workflow, attaching an extraction schema, uploading a PDF, and fetching results against the **local** anyformat backend.

## Decision guide — read this first

| Case | Endpoints |
|---|---|
| **Single extract** (linear `parse → extract`, or any graph with one extract node) | `POST /api/v2/saas_manager/workflows/` — graph + nodes + flat `fields[]` in one call (defaults to `extract_1`) |
| **Multiple extracts** (splitter/classify routing to >1 extract) | `POST …/workflows/` with graph + nodes **only**, then `PUT /api/v2/saas_manager/workflow-versions/{version_id}/config/` with `nodes` as a **dict keyed by node_id**, `fields` nested under each |
| **Edit schema on existing workflow** | `PUT …/workflow-versions/{id}/config/` — creates a **new version**, does not mutate in place |

Why: the one-shot POST takes a flat `fields[]` that binds all fields to `extract_1` (or a single `graph_node_id`). Per-node schemas need the atomic config PUT. Learned empirically — don't try to cram a splitter workflow into one POST.

## The 4-step flow

1. **Auth** — mint an API key (or reuse one). See [`reference/auth.md`](reference/auth.md).
2. **Create workflow (+ schema)** — POST `/api/v2/saas_manager/workflows/`, optionally followed by PUT config. See [`reference/api.md`](reference/api.md#create) and [`reference/schemas.md`](reference/schemas.md).
3. **Upload PDF** — POST `/api/v2/files/upload/` (base64). See [`reference/api.md`](reference/api.md#upload).
4. **Run & fetch** — POST `/api/v2/demo/run_extraction_demo/`, poll `/api/v3/file-collections/{id}/extraction-status/`, then GET `…/results/`. See [`reference/api.md`](reference/api.md#run).

## Quick reference

- **All 10 node types** (config shapes, routing rules, DOT syntax) → [`reference/nodes.md`](reference/nodes.md)
- **Endpoints** (request/response shapes, auth, versioning) → [`reference/api.md`](reference/api.md)
- **Auth setup** (mint API key, X-Current-Org) → [`reference/auth.md`](reference/auth.md)
- **Schema shape** (field types, nesting, enums, per-node scoping) → [`reference/schemas.md`](reference/schemas.md)
- **Working payloads** (linear, splitter, classify, smart_lookup) → [`reference/examples.md`](reference/examples.md)
- **Fake PDF generator** for the splitter schemas (faker + reportlab via PEP 723) → [`reference/fixtures/make_fixtures.py`](reference/fixtures/make_fixtures.py) — see [`reference/examples.md#fixtures`](reference/examples.md#fixtures)
- **3-way mixed PDF** (invoice + package label + boarding pass, one page each) for splitter end-to-end runs with real data in every branch → [`scripts/make_mixed.py`](scripts/make_mixed.py)

## Quickstart — linear parse → extract (one POST)

```bash
export BASE=http://localhost:8080
export TOKEN=...   # reference/auth.md
export ORG_ID=...

curl -sS "$BASE/api/v2/saas_manager/workflows/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Invoice extractor",
    "graph": "digraph G { \"parse_1\" [class=\"parse\"]; \"extract_1\" [class=\"extract\"]; \"parse_1\" -> \"extract_1\"; }",
    "nodes": [
      {"node_id":"parse_1","type":"parse","config":{"engine":"Fast"}},
      {"node_id":"extract_1","type":"extract","config":{"engine":"Fast","use_images":false}}
    ],
    "fields": [
      {"name":"invoice_number","description":"Invoice ID","data_type":"string","display_order":10000},
      {"name":"total_amount","description":"Grand total","data_type":"float","display_order":20000}
    ]
  }'
```

For multi-extract (splitter/classify), see [`reference/examples.md#splitter`](reference/examples.md#splitter).

## Gotcha — `engine` is mandatory on parse / extract / master_file

Every `parse`, `extract`, and `master_file` node config MUST include `"engine": "Fast"` or `"engine": "Performant"`. The backend's `execution_builder.py:243` silently drops these node types from `task_settings` when `engine` is missing. Core then crashes at runtime with `RuntimeError: No config provided for task: <node_id>` inside `_synthesize_lookup_nodes` — a misleading stack trace that points at the synthesis pass, not the real cause.

Always include `engine` alongside `use_images`, `lookup_enabled`, or any other extract config:
```json
{"node_id":"extract_1","type":"extract","config":{"engine":"Fast","use_images":false}}
```

## Full end-to-end bash

See [`reference/examples.md#end-to-end`](reference/examples.md#end-to-end) — pasteable script covering create → upload PDF → run → poll → fetch results.

## Verified against

- Local backend at commit on `feat/splits-identity-rebuild` (2026-04-21) — this skill was dog-fooded on a splitter workflow with two extract branches and the PUT config flow worked end-to-end.
- Source anchors and drift check: [`reference/api.md#source-anchors`](reference/api.md#source-anchors)
