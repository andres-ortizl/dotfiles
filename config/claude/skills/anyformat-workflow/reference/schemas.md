# Extraction schema reference

A "schema" in anyformat is a list of **fields** attached to one or more extract-capable nodes within a WorkflowVersion. There is no standalone schema resource.

## Field shape

```json
{
  "name": "invoice_number",
  "description": "Invoice ID as printed on the document",
  "data_type": "string",
  "source": "extraction",
  "is_list": false,
  "display_order": 10000,

  "enum_options": null,
  "nested_fields": null,
  "custom_id": null,
  "graph_node_id": null
}
```

### Required per field

- `name` — human-readable; the backend also derives a `sanitized_name` for uniqueness.
- `description` — fed to the LLM prompt. Treat this as an instruction to the model. Quality of extraction correlates strongly with description quality.
- `data_type` — one of the values below.

### Optional

- `source` — `"extraction"` (default) or `"smart_lookup"`. The latter marks fields that are populated by a `smart_lookup` successor, not the extract LLM.
- `is_list` — set `true` when the value is naturally repeated (e.g., `recipients` on an email). Implied for `multi_select`.
- `display_order` — integer; smaller renders first. Leave wide gaps (10000, 20000, …) so intermediate insertions don't need renumbering.
- `enum_options` — required when `data_type` ∈ `enum`, `multi_select`. Each: `{ "name": "...", "description": "..." }`.
- `nested_fields` — required when `data_type == "object"`. Each entry is another field (but **cannot itself be `object`** — nesting is one level deep).
- `custom_id` — opaque string for integration with external systems.
- `graph_node_id` — UUID of the target GraphNode. Only needed when attaching fields via a call that doesn't already know which node is being targeted.

## Data types

| `data_type` | Typical value | Notes |
|---|---|---|
| `string` | `"INV-001"` | Default for free text. |
| `date` | `"2026-04-21"` | ISO 8601 date. |
| `datetime` | `"2026-04-21T14:30:00Z"` | ISO 8601 with time. |
| `float` | `1234.56` | Use for monetary amounts too. |
| `integer` | `42` | |
| `boolean` | `true` | |
| `enum` | `"draft"` | Single value from `enum_options`. |
| `multi_select` | `["draft","archived"]` | Multiple values from `enum_options`; implies `is_list`. |
| `object` | `{...}` | Structured nested group; requires `nested_fields`. |

## Per-node scoping

A field belongs to exactly one **graph node**. How you express that depends on which endpoint you use:

### Via POST `/workflows/` (one-shot)

`fields[]` is a **flat top-level array**. All fields bind to `extract_1` by name, unless you supply either:

- top-level `graph_node_id: <uuid>` applied to the whole batch, OR
- per-field `graph_node_id: <uuid>`.

Since UUIDs aren't known before creation, this is only practical when there's one extract node called `extract_1`. **Don't use for multi-extract workflows.**

### Via PUT `/workflow-versions/{id}/config/` (atomic)

`nodes` is a **dict keyed by node_id**, with each node's `fields` nested under it:

```json
{
  "nodes": {
    "extract_1": { "type": "extract", "config": {...}, "fields": [ {...}, {...} ] },
    "extract_2": { "type": "extract", "config": {...}, "fields": [ {...}, {...} ] }
  }
}
```

This is the right choice for anything non-trivial — splitter/classify workflows, schema edits, multi-extract routing.

## Fields vs manual_fields

- `fields` — extracted from the document by the LLM/lookup/master_file nodes. Scoped per-node.
- `manual_fields` — collection-level metadata entered by humans (e.g., "client name" set at upload time). Never populated from the document. Live on the WorkflowVersion, not on any graph node. Written via the `manual_field_values` map on `POST /files/upload/`.

## Nesting example

```json
{
  "name": "line_items",
  "description": "Individual invoice line items",
  "data_type": "object",
  "is_list": true,
  "display_order": 50000,
  "nested_fields": [
    { "name": "sku",         "description": "Product code",               "data_type": "string",  "display_order": 10000 },
    { "name": "description", "description": "Line description",           "data_type": "string",  "display_order": 20000 },
    { "name": "quantity",    "description": "Units purchased",            "data_type": "integer", "display_order": 30000 },
    { "name": "unit_price",  "description": "Price per unit, pre-tax",    "data_type": "float",   "display_order": 40000 }
  ]
}
```

## Enum example

```json
{
  "name": "payment_method",
  "description": "How the invoice was paid",
  "data_type": "enum",
  "display_order": 60000,
  "enum_options": [
    { "name": "card",     "description": "Paid by credit/debit card" },
    { "name": "transfer", "description": "Paid by bank transfer" },
    { "name": "cash",     "description": "Paid in cash" }
  ]
}
```

## Gotchas

- `enum` and `multi_select` **require** non-empty `enum_options` or validation will 400.
- Non-enum `data_type`s **cannot** have `enum_options`; sending `[]` is OK (coerced to `null`), sending actual options 400s.
- `nested_fields` are only valid on `object`. For any other type, omit them.
- Field **names are unique per node after sanitization** (lowercased, punctuation stripped). `Invoice Number` and `invoice_number` collide.
- Manual fields cannot have `data_type == "object"` (no nesting at the collection level).
