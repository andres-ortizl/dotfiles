# API reference

Base URL for local dev: `http://localhost:8080`. All requests require:

- `Authorization: Bearer $TOKEN`
- `X-Current-Org: $ORG_ID` (strictly required on `/api/v3/`; recommended on `/api/v2/`)

## Versioning invariant — read this

Every `PUT /api/v2/saas_manager/workflow-versions/{id}/config/` call **creates a new WorkflowVersion row**, it does NOT mutate in place. The POST `…/workflows/` returns `versions[0].id = N`; your first PUT bumps it to `N+1`. Use the latest `version_id` for subsequent operations (extraction runs, fields GET, results fetch).

---

## 1) Create workflow

<a id="create"></a>

`POST /api/v2/saas_manager/workflows/`

Creates a Workflow + initial WorkflowVersion + graph nodes + (optionally) extraction fields in one atomic call. Use when: all fields belong to **one** extract node (or you'll attach schemas via a follow-up PUT config).

### Request

```json
{
  "name": "...",
  "description": "...",
  "graph": "digraph G { ... }",
  "nodes": [
    { "node_id": "...", "type": "...", "config": { ... }, "position": {"x":0,"y":0} }
  ],
  "fields": [
    { "name": "...", "description": "...", "data_type": "...", "source": "extraction", "display_order": 10000 }
  ],
  "manual_fields": []
}
```

### Rules

- `graph` and `nodes` must be **both present or both absent** — if absent, default `parse_1 → extract_1` is created.
- `fields[]` without per-field `graph_node_id` → all fields bound to `extract_1` by name. For multi-extract, use the config PUT instead (below).
- `data_type` ∈ `string|date|datetime|float|integer|boolean|enum|multi_select|object`.

### Response (201)

```json
{
  "id": "<workflow_uuid>",
  "name": "...",
  "versions": [{ "id": 123, "name": "...", "created_at": "..." }]
}
```

Capture `id` (workflow UUID) and `versions[0].id` (numeric version_id).

---

## 2) Atomic config (multi-extract path, schema edits)

<a id="config"></a>

`GET /api/v2/saas_manager/workflow-versions/{version_id}/config/` — read current config.
`PUT /api/v2/saas_manager/workflow-versions/{version_id}/config/` — save full config, creating a new version.

### Key difference from POST workflows/

`nodes` is a **dict keyed by node_id**, and `fields` are **nested under each node** (not flat top-level).

### PUT request

```json
{
  "version_id": 4,
  "graph": "digraph G { ... }",
  "nodes": {
    "parse_1":    { "type": "parse",             "config": {...}, "position": {...}, "fields": [] },
    "splitter_1": { "type": "document_splitter", "config": {...}, "position": {...}, "fields": [] },
    "extract_1":  { "type": "extract",           "config": {...}, "position": {...}, "fields": [ { ... }, { ... } ] },
    "extract_2":  { "type": "extract",           "config": {...}, "position": {...}, "fields": [ { ... }, { ... } ] }
  },
  "manual_fields": []
}
```

### Response (200)

```json
{ "version_id": 5 }
```

The returned `version_id` is the **new** version. Use it for subsequent extraction runs.

### Common errors

- `400` with `"graph and nodes must be provided together"` — you sent one without the other.
- `400` field-bearing-on-non-field-node — only `extract`, `smart_table`, `smart_lookup`, `master_file` can have `fields`.
- `409` version conflict — the `version_id` in the body doesn't match the current latest (optimistic concurrency).

---

## 3) Upload a PDF

<a id="upload"></a>

`POST /api/v2/files/upload/`

JSON body, base64-encoded file content.

### Request

```json
{
  "content": "<base64>",
  "filename": "invoice.pdf",
  "format": "pdf",
  "extraction_name": "invoice-2026-04",
  "workflow_id": "<workflow_uuid>",
  "file_collection_id": null,
  "manual_field_values": {}
}
```

### Response (201)

```json
{
  "file_id": 789,
  "file_uri": "s3://...",
  "file_collection_id": "<collection_uuid>",
  "filename": "invoice.pdf"
}
```

Capture `file_collection_id` — it's the anchor for runs and result fetches.

### Generating a test PDF

```python
from reportlab.pdfgen import canvas
c = canvas.Canvas("invoice.pdf")
c.drawString(100, 800, "INVOICE #INV-2026-001")
c.drawString(100, 780, "Date: 2026-04-21")
c.drawString(100, 760, "Total: $1,234.56")
c.save()
```

---

## 4) Run the extraction

<a id="run"></a>

`POST /api/v2/demo/run_extraction_demo/` — enqueues the workflow run (async).

### Request

```json
{ "version_id": 5, "file_collection_id": "<collection_uuid>" }
```

### Response (200)

```json
{ "status": "success", "extraction_id": 456, ... }
```

---

## 5) Poll status

`GET /api/v3/file-collections/{collection_id}/extraction-status/`

### Response

```json
{ "status": "pending|queued|in_progress|processed|failed|cancelled", "processed_at": "...", "workflow_version_id": 5 }
```

---

## 6) Fetch results

`GET /api/v3/file-collections/{collection_id}/results/?workflow_version_id={id}`

### Response

```json
{
  "collection_id": "...",
  "verification_url": "https://...",
  "results": [
    { "field_name": "invoice_number", "value": "INV-001", "confidence": 0.95, "evidence": [...] }
  ]
}
```

---

## 7) Other useful endpoints

- `GET /api/v2/saas_manager/workflows/` — list workflows. Add `?include=versions,fields,file_count,file_status_count,extraction_count`.
- `GET /api/v2/saas_manager/workflows/{id}/` — fetch one workflow.
- `GET /api/v2/saas_manager/workflows/{id}/graph/?version_id={v}` — render-friendly view with DOT + per-node config + positions.
- `GET /api/v2/saas_manager/workflow-versions/{id}/fields/` — list fields (read-only; writes go through PUT config).
- `POST /api/v2/saas_manager/workflows/{id}/duplicate/` — clone a workflow.
- `DELETE /api/v2/saas_manager/workflows/{id}/` — soft delete.

---

## Source anchors

<a id="source-anchors"></a>

If endpoint shapes drift, verify against these files:

| Endpoint | File:line |
|---|---|
| `POST /workflows/` | `anyformat/services/backend/src/anyformat/backend/apps/saas_manager/views/workflow_views.py:378` |
| Serializer for POST body | `…/apps/workflow_manager/serializers.py:372` (`WorkflowFromJsonSerializer`) |
| `PUT/GET /workflow-versions/{id}/config/` | `…/apps/saas_manager/views/workflow_version_views.py:450` |
| Fields shape | `…/apps/saas_manager/serializers/field_serializer.py:198` (`FieldCreationSerializer`) |
| Bulk field validator | `…/apps/saas_manager/serializers/field_bulk_serializer.py:15` |
| `POST /files/upload/` | `…/apps/workflow_manager/serializers.py:22` (`UploadFileSerializer`) |
| `POST /demo/run_extraction_demo/` | `…/apps/extraction_manager/views.py:26` |
| v3 status/results | `…/apps/v3/files.py:586` (status), `:617` (results) |
| Auth middleware | `…/utils/auth/rest_authenticators.py:164` (`Auth0JWTMachineAuthentication`) |
