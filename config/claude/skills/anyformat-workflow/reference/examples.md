# Working examples

All examples assume:

```bash
export BASE=http://localhost:8080
export TOKEN=sk-dev-...     # reference/auth.md
export ORG_ID=...
```

## 1) Linear parse → extract (one-shot POST)

<a id="linear"></a>

Simplest case. One call, everything embedded.

```bash
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

---

## 2) Splitter → two extract branches

<a id="splitter"></a>

This is the pattern to use whenever you have more than one extract node. **Two calls**: POST creates workflow + graph, PUT attaches per-node schemas.

### Step A — create workflow (graph + nodes only)

```bash
CREATE_BODY=$(cat <<'EOF'
{
  "name": "Invoices + Emails splitter",
  "description": "Parse -> split -> extract (invoices | emails)",
  "graph": "digraph G { \"parse_1\" [class=\"parse\"]; \"splitter_1\" [class=\"document_splitter\"]; \"extract_1\" [class=\"extract\"]; \"extract_2\" [class=\"extract\"]; \"parse_1\" -> \"splitter_1\"; \"splitter_1\":\"invoices\" -> \"extract_1\"; \"splitter_1\":\"emails\" -> \"extract_2\"; }",
  "nodes": [
    {"node_id":"parse_1",   "type":"parse",             "config":{"engine":"Fast","visual_grounding_enabled":true}, "position":{"x":200,"y":300}},
    {"node_id":"splitter_1","type":"document_splitter", "config":{"rules":[
      {"id":"r-inv","name":"invoices","description":"Invoice documents: has invoice number, line items, total, vendor."},
      {"id":"r-eml","name":"emails",  "description":"Email correspondence: has from/to, subject, date, body."}
    ]}, "position":{"x":450,"y":300}},
    {"node_id":"extract_1", "type":"extract", "config":{"engine":"Fast","use_images":false}, "position":{"x":750,"y":180}},
    {"node_id":"extract_2", "type":"extract", "config":{"engine":"Fast","use_images":false}, "position":{"x":750,"y":420}}
  ]
}
EOF
)

CREATE=$(curl -sS "$BASE/api/v2/saas_manager/workflows/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" \
  -H "Content-Type: application/json" -d "$CREATE_BODY")

WORKFLOW_ID=$(echo "$CREATE" | jq -r .id)
VERSION_ID=$( echo "$CREATE" | jq -r .versions[0].id)
echo "workflow=$WORKFLOW_ID initial_version=$VERSION_ID"
```

### Step B — PUT config with per-node schemas

```bash
PUT_BODY=$(jq -n --argjson v "$VERSION_ID" '{
  version_id: $v,
  graph: "digraph G { \"parse_1\" [class=\"parse\"]; \"splitter_1\" [class=\"document_splitter\"]; \"extract_1\" [class=\"extract\"]; \"extract_2\" [class=\"extract\"]; \"parse_1\" -> \"splitter_1\"; \"splitter_1\":\"invoices\" -> \"extract_1\"; \"splitter_1\":\"emails\" -> \"extract_2\"; }",
  nodes: {
    parse_1:    {type:"parse",             config:{engine:"Fast",visual_grounding_enabled:true}, position:{x:200,y:300}, fields:[]},
    splitter_1: {type:"document_splitter", config:{rules:[
      {id:"r-inv",name:"invoices",description:"Invoice documents: has invoice number, line items, total, vendor."},
      {id:"r-eml",name:"emails",  description:"Email correspondence: has from/to, subject, date, body."}
    ]}, position:{x:450,y:300}, fields:[]},
    extract_1: {type:"extract", config:{engine:"Fast",use_images:false}, position:{x:750,y:180}, fields:[
      {name:"invoice_number",description:"Invoice ID / reference number as printed on the document",data_type:"string", source:"extraction",is_list:false,display_order:10000},
      {name:"issue_date",    description:"Date the invoice was issued",                              data_type:"date",   source:"extraction",is_list:false,display_order:20000},
      {name:"due_date",      description:"Payment due date",                                         data_type:"date",   source:"extraction",is_list:false,display_order:30000},
      {name:"vendor_name",   description:"Name of the issuing vendor / supplier",                    data_type:"string", source:"extraction",is_list:false,display_order:40000},
      {name:"total_amount",  description:"Grand total including taxes",                              data_type:"float",  source:"extraction",is_list:false,display_order:50000},
      {name:"currency",      description:"ISO 4217 currency code (USD, EUR, ...)",                   data_type:"string", source:"extraction",is_list:false,display_order:60000}
    ]},
    extract_2: {type:"extract", config:{engine:"Fast",use_images:false}, position:{x:750,y:420}, fields:[
      {name:"sender",         description:"Email address in the From: header",       data_type:"string",  source:"extraction",is_list:false,display_order:10000},
      {name:"recipients",     description:"All To: / Cc: recipient email addresses", data_type:"string",  source:"extraction",is_list:true, display_order:20000},
      {name:"subject",        description:"Email subject line",                      data_type:"string",  source:"extraction",is_list:false,display_order:30000},
      {name:"sent_at",        description:"Datetime the email was sent",             data_type:"datetime",source:"extraction",is_list:false,display_order:40000},
      {name:"body_summary",   description:"One-sentence summary of the email body",  data_type:"string",  source:"extraction",is_list:false,display_order:50000},
      {name:"has_attachments",description:"Whether the email mentions attachments",  data_type:"boolean", source:"extraction",is_list:false,display_order:60000}
    ]}
  },
  manual_fields: []
}')

PUT=$(curl -sS -X PUT "$BASE/api/v2/saas_manager/workflow-versions/$VERSION_ID/config/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" \
  -H "Content-Type: application/json" -d "$PUT_BODY")

NEW_VERSION_ID=$(echo "$PUT" | jq -r .version_id)
echo "active_version=$NEW_VERSION_ID"
```

The PUT returns a **new** version_id. Use `NEW_VERSION_ID` for extraction runs, not `VERSION_ID`.

---

## 3) Classify → routed extract

Same shape as splitter — classify is the LLM-classifier variant. Port labels on edges must match `categories[].name`.

```
digraph G {
  "parse_1"    [class="parse"];
  "classify_1" [class="classify"];
  "extract_a"  [class="extract"];
  "extract_b"  [class="extract"];

  "parse_1" -> "classify_1";
  "classify_1":"invoice" -> "extract_a";
  "classify_1":"receipt" -> "extract_b";
}
```

`classify_1` config:

```json
{
  "user_prompt": "Classify this document as either an invoice or a receipt.",
  "categories": [
    { "id": "c-inv", "name": "invoice", "description": "Has invoice number, line items, total." },
    { "id": "c-rec", "name": "receipt", "description": "Store receipt, typically shorter." }
  ]
}
```

---

## 4) Extract with smart_lookup enrichment

Instead of declaring a separate `smart_lookup` node, set `lookup_enabled: true` on the extract. The core synthesizes the successor at runtime.

```json
{
  "node_id": "extract_1",
  "type": "extract",
  "config": {
    "engine": "Fast",
    "use_images": false,
    "lookup_enabled": true,
    "lookup_files": ["s3://bucket/vendor_catalog.csv"],
    "lookup_schema": [
      { "name": "vendor_id", "description": "Vendor ID from catalog", "data_type": "string" }
    ],
    "lookup_suggestion": "Match the extracted vendor_name against the catalog's 'company_name' column."
  }
}
```

---

## Generating fake test PDFs

<a id="fixtures"></a>

For schema-driven test data, use `fixtures/make_fixtures.py`. It's a self-contained [PEP 723](https://peps.python.org/pep-0723/) script — dependencies declared inline, no venv setup. Generates two PDFs aligned with the splitter workflow's schemas:

- **`invoice.pdf`** — contains `invoice_number`, `issue_date`, `due_date`, `vendor_name`, `total_amount`, `currency`. Routes to `extract_1` via the splitter's `invoices` port.
- **`email.pdf`** — contains `sender`, `recipients`, `subject`, `sent_at`, `body_summary`, `has_attachments`. Routes to `extract_2` via the `emails` port.

### Run

```bash
uv run /Users/andrew/.claude/skills/anyformat-workflow/reference/fixtures/make_fixtures.py
# → /tmp/anyformat-demo/invoice.pdf
# → /tmp/anyformat-demo/email.pdf

# or write somewhere else:
uv run .../make_fixtures.py /path/to/out_dir
```

### Output (truth shipped to stdout)

Each run prints the ground-truth values that were baked into the PDF, so you can sanity-check extraction fidelity:

```
[invoice] invoice.pdf: {'invoice_number': 'INV-2019-7067', 'issue_date': '2026-01-22', 'due_date': '2026-02-05', 'vendor_name': 'Casey Group', 'total_amount': 4202.57, 'currency': 'GBP'}
[email]   email.pdf:   {'sender': 'johnsontyler@anderson.com', 'recipients': [...], 'subject': '...', 'sent_at': '...', 'has_attachments': False}
```

### Why reportlab, not pdfplumber

`pdfplumber` **reads** PDFs; for **generation** you need `reportlab` (or `fpdf2`). The script uses `reportlab` + `faker`, declared inline via PEP 723:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["reportlab", "faker"]
# ///
```

`uv run` reads those headers, builds an ephemeral venv, and runs the script — first invocation pulls deps (~2s), subsequent runs are instant.

### Extending the script

- Match a new schema: add a `make_<kind>()` function that draws the expected fields onto a canvas, return a `{field_name: truth_value}` dict so the printed truth matches your schema.
- Skew the distribution: biased coin flips on `has_attachments`, `currency`, line-item count, etc., are already in the script — tweak in place.
- Deterministic fixtures: add `Faker.seed_instance(42)` and `random.seed(42)` at the top for reproducible fixtures across runs.

---

## End-to-end (generate → upload → run → poll → fetch)

<a id="end-to-end"></a>

Assumes you've already run Example 1 or 2 and have `WORKFLOW_ID` + `NEW_VERSION_ID` in scope.

```bash
# 0. Generate a fake PDF matching the schema
uv run /Users/andrew/.claude/skills/anyformat-workflow/reference/fixtures/make_fixtures.py
PDF=/tmp/anyformat-demo/invoice.pdf   # or email.pdf

# Upload PDF
PDF_B64=$(base64 -i "$PDF" | tr -d '\n')
UPLOAD=$(curl -sS "$BASE/api/v2/files/upload/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"$PDF_B64\",\"filename\":\"$(basename $PDF)\",\"format\":\"pdf\",\"extraction_name\":\"demo\",\"workflow_id\":\"$WORKFLOW_ID\"}")
COLLECTION_ID=$(echo "$UPLOAD" | jq -r .file_collection_id)

# Run
curl -sS "$BASE/api/v2/demo/run_extraction_demo/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" \
  -H "Content-Type: application/json" \
  -d "{\"version_id\":$NEW_VERSION_ID,\"file_collection_id\":\"$COLLECTION_ID\"}"

# Poll
until [ "$(curl -sS "$BASE/api/v3/file-collections/$COLLECTION_ID/extraction-status/" \
           -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" | jq -r .status)" = "processed" ]; do
  sleep 3
done

# Fetch
curl -sS "$BASE/api/v3/file-collections/$COLLECTION_ID/results/?workflow_version_id=$NEW_VERSION_ID" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID" | jq .
```

## Known-good reference run

The splitter example above (Example 2) was executed successfully against local backend on 2026-04-21:

- Workflow `069e7d8f-cd78-7da2-8000-e808599213c3`
- `extract_1` got 6 invoice fields; `extract_2` got 6 email fields (including `recipients` with `is_list: true`)
- POST returned version 4; PUT-config returned version 5
- Verified via GET `…/config/` round-trip that all nodes, configs, and per-node fields persisted correctly
