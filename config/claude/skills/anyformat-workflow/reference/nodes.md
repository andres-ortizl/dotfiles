# Node types reference

10 node types. Each node's `type` in the `nodes` payload matches the DOT `class=` attribute for that node in the `graph` string.

## Summary table

| `type` | Purpose | Required `config` | Routing |
|---|---|---|---|
| `parse` | PDFs / spreadsheets / text → markdown (OCR, page rotation, figure enhancement, visual grounding). | `{}` (all optional: `engine`, `prompt_hint`, `page_rotation`, `figure_enhancement_enabled`, `visual_grounding_enabled`, `settings`) | linear |
| `extract` | Markdown + schema → structured JSON via LLM. Can auto-synthesize a `smart_lookup` successor. | `{}` (optional: `use_images`, `smart_table_enabled`, `lookup_enabled`, `lookup_schema`, `lookup_suggestion`, `lookup_files`, `settings`). Schema supplied via `fields[]`. | linear |
| `smart_table` | Multi-pass agentic table extraction w/ block-ID + bbox enrichment. Schema comes from `fields[]`. | `{}` (optional `settings`) | linear |
| `smart_lookup` | Post-extraction enrichment — matches values against master CSV/catalog files. | `master_file_uris: [s3_uri, ...]` (required), optional `suggestion`, `settings`. Schema via `fields[]`. | linear |
| `document_splitter` | LLM-routes one doc to multiple downstream extract nodes by category. | `rules: [{ id, name, description, partition_key? }, ...]` | **port-labeled** — each out-edge needs `source_port` matching a rule `name` |
| `classify` | LLM-classifies doc into categories; routes downstream by label. | `user_prompt: str`, `categories: [{ id, name, description }, ...]` | **port-labeled** — each out-edge needs `source_port` matching a category `name` |
| `filter` | Binary LLM gate — discards or forwards docs based on criteria. | `criteria: str`, optional `settings` | conditional (true → forward, false → end) |
| `master_file` | Extraction guided by a reference/template file. | `master_file_uri: s3_uri` (required). Schema via `fields[]`. Optional `settings`. | linear |
| `table_parse` | PDF → HTML tables (structural parsing, no LLM). | `{}` (none required) | linear |
| `validate` | Checks extraction results against rules; appends verdicts to state. | `rules: [{ id, description, severity?, source_fields? }, ...]`, optional `settings` | linear |

## Schema-bearing nodes

Only these node types accept `fields[]`:

- `extract`
- `smart_table`
- `smart_lookup`
- `master_file`
- `parse` (limited — mostly for prompt hints)

For other node types, `fields` must be empty or omitted. PUT config will reject fields on e.g. a `classify` or `filter` node.

## Edge syntax

### Linear

```
"parse_1" -> "extract_1"
```

### Port-labeled (required for `classify` and `document_splitter`)

The string after the colon is the edge's `source_port` and must match a category/rule `name`.

```
"classify_1":"invoice" -> "extract_invoices"
"classify_1":"receipt" -> "extract_receipts"
```

Inside a JSON string the inner double-quotes need escaping. In a shell heredoc:

```bash
GRAPH='digraph G {
  "splitter_1":"invoices" -> "extract_1";
  "splitter_1":"emails"   -> "extract_2";
}'
```

When building JSON by hand, escape as `\"splitter_1\":\"invoices\" -> \"extract_1\"`.

## Splitter / classify example

```json
{
  "node_id": "splitter_1",
  "type": "document_splitter",
  "config": {
    "rules": [
      { "id": "r-inv", "name": "invoices", "description": "Invoice documents: has invoice number, line items, total, vendor." },
      { "id": "r-eml", "name": "emails",   "description": "Email correspondence: has from/to, subject, date, body." }
    ]
  }
}
```

The `name` on each rule/category is the port label. Your DOT edges must match exactly (case-sensitive).

## Implicit node synthesis

- `extract` with `smart_table_enabled: true` → rewritten to `smart_table` at runtime.
- `extract` with `lookup_enabled: true` + `lookup_files` + `lookup_schema` → auto-synthesizes a `smart_lookup` successor.

You don't need to write these into the graph yourself — the core resolves them.

## Source anchors

Node classes live in `anyformat/services/anyformat-core/anyformat_core/graph/nodes/`:

- `parse_node.py` — `ParseNode`
- `extraction_node.py` — `ExtractionNode`
- `smart_table_node.py` — `SmartTableNode`
- `smart_lookup_node.py` — `SmartLookupNode`
- `document_splitter_node.py` — `DocumentSplitterNode`
- `classify_node.py` — `ClassifyNode`
- `filter_node.py` — `FilterNode`
- `master_file_extraction_node.py` — `MasterFileExtractionNode`
- `table_parsing_node.py` — `TableParsingNode`
- `validate_node.py` — `ValidateNode`

DOT → node-type dispatch: `anyformat/services/anyformat-core/anyformat_core/graph/dot_graph.py:194`.
