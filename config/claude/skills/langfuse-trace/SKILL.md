---
name: langfuse-trace
description: "Fetch and debug a Langfuse trace from langfuse.anyformat.ai by ID or URL. Shows span tree overview first, then asks which part to drill into before loading heavy LLM I/O. Anyformat-only — assumes LANGFUSE_TRACING_* env vars. Do NOT use for other Langfuse hosts."
---

# Debug a Langfuse Trace

## Setup

Extract the trace ID from the argument (bare ID or URL last segment).

Credentials are always:
```bash
LANGFUSE_PUBLIC_KEY=$LANGFUSE_TRACING_PUBLIC_KEY
LANGFUSE_SECRET_KEY=$LANGFUSE_TRACING_SECRET_KEY
LANGFUSE_HOST=https://langfuse.anyformat.ai
```

---

## Delegation

All phases (1 and 3) MUST be executed by a `general-purpose` subagent with `model: "sonnet"`. Spawn the subagent with the full instructions for that phase. This keeps exploration cost low since the parent model may be Opus.

---

## Phase 1: Fetch Overview (always do this first)

Fetch the trace and render a lightweight overview — span tree + cost summary only. No LLM I/O yet.

```bash
LANGFUSE_PUBLIC_KEY=$LANGFUSE_TRACING_PUBLIC_KEY \
LANGFUSE_SECRET_KEY=$LANGFUSE_TRACING_SECRET_KEY \
LANGFUSE_HOST=https://langfuse.anyformat.ai \
  npx langfuse-cli api traces get <trace-id> --json 2>/dev/null | python3 -c "
import json, sys
outer = json.load(sys.stdin)
d = outer['body']
obs = d.get('observations', [])
obs.sort(key=lambda o: o.get('startTime', ''))

parent_map = {o['id']: o.get('parentObservationId') for o in obs}
id_to_name = {o['id']: o.get('name','?') for o in obs}

def depth(oid):
    n = 0
    while parent_map.get(oid):
        oid = parent_map[oid]
        n += 1
        if n > 20: break
    return n

print(f'Trace:    {d[\"id\"]}')
print(f'Name:     {d.get(\"name\") or \"(unnamed)\"}')
print(f'Time:     {d.get(\"timestamp\")}')
print(f'Latency:  {d.get(\"latency\", \"?\")}s   Cost: \${d.get(\"totalCost\") or 0:.4f}')
print(f'Env:      {d.get(\"environment\")}')
print(f'URL:      https://langfuse.anyformat.ai{d.get(\"htmlPath\",\"\")}')
print()

errors = [o for o in obs if o.get('level') in ('ERROR', 'WARNING') or o.get('statusMessage')]
if errors:
    print('=== Errors / Warnings ===')
    for o in errors:
        print(f'  [{o.get(\"level\")}] {o.get(\"name\")}: {o.get(\"statusMessage\")}')
    print()

print('=== Span Tree ===')
# DFS traversal to avoid parallel workers' children bleeding into each other visually
children_map = {}
roots = []
obs_by_id = {o['id']: o for o in obs}
for o in obs:
    pid = o.get('parentObservationId')
    if pid and pid in obs_by_id:
        children_map.setdefault(pid, []).append(o)
    else:
        roots.append(o)
# Sort each level by startTime so siblings appear chronologically
roots.sort(key=lambda o: o.get('startTime', ''))
for v in children_map.values():
    v.sort(key=lambda o: o.get('startTime', ''))

def print_tree(o, indent=0):
    typ = o.get('type', 'SPAN')
    name = o.get('name', '?')
    lat = f'{o.get(\"latency\",\"?\"):.1f}s' if isinstance(o.get('latency'), (int,float)) else ''
    model = f' [{o.get(\"model\")}]' if o.get('model') else ''
    tokens = f' {o[\"totalTokens\"]}tok' if o.get('totalTokens') else ''
    cost = f' \${o[\"calculatedTotalCost\"]:.4f}' if o.get('calculatedTotalCost') else ''
    warn = ' ⚠' if o.get('level') in ('ERROR','WARNING') else ''
    print(f'{"  "*indent}{typ} {name}{model}{tokens}{cost} {lat}{warn}')
    for child in children_map.get(o['id'], []):
        print_tree(child, indent+1)

for r in roots:
    print_tree(r)

print()
# Group spans by top-level parent for the user to choose
top_spans = [o for o in obs if not o.get('parentObservationId') or o.get('parentObservationId') not in {x['id'] for x in obs}]
named = [o for o in obs if o.get('name') and o.get('type') == 'SPAN']
unique_names = sorted(set(o['name'] for o in named))
print('=== Available sections to drill into ===')
for name in unique_names:
    print(f'  - {name}')
"
```

---

## Phase 2: Ask before drilling

After the Phase 1 subagent returns its output, relay it to the user, then **stop and ask**:

> Which section do you want to drill into? (e.g. `smart_table_supervisor`, `smart_table_worker_*`, `_parse_all_blocks`, or `all` for everything)

Do NOT load LLM inputs/outputs until the user specifies a focus area. Traces are large and loading everything floods context.

---

## Phase 3: Drill into a specific section

Once the user picks a section, spawn another `general-purpose` subagent with `model: "sonnet"` to run the drill. Filter observations by name pattern and show full I/O for that subset only.

```bash
LANGFUSE_PUBLIC_KEY=$LANGFUSE_TRACING_PUBLIC_KEY \
LANGFUSE_SECRET_KEY=$LANGFUSE_TRACING_SECRET_KEY \
LANGFUSE_HOST=https://langfuse.anyformat.ai \
  npx langfuse-cli api traces get <trace-id> --json 2>/dev/null | python3 -c "
import json, sys
FILTER = '<section-name-pattern>'  # e.g. 'smart_table', 'supervisor', '_parse'

outer = json.load(sys.stdin)
d = outer['body']
obs = d.get('observations', [])
obs.sort(key=lambda o: o.get('startTime', ''))
id_to_name = {o['id']: o.get('name','?') for o in obs}

# Find relevant observations: name matches OR is a descendant of a matching span
def matches(o):
    return FILTER.lower() in o.get('name','').lower()

# Build children map for descendant traversal
children_map = {}
for o in obs:
    pid = o.get('parentObservationId')
    if pid:
        children_map.setdefault(pid, []).append(o['id'])

def all_descendant_ids(oid):
    result = set()
    queue = list(children_map.get(oid, []))
    while queue:
        cid = queue.pop()
        result.add(cid)
        queue.extend(children_map.get(cid, []))
    return result

matching_ids = {o['id'] for o in obs if matches(o)}
descendant_ids = set()
for mid in matching_ids:
    descendant_ids |= all_descendant_ids(mid)
relevant_ids = matching_ids | descendant_ids
relevant = [o for o in obs if o['id'] in relevant_ids]
relevant.sort(key=lambda o: o.get('startTime', ''))

# Build ancestor label for each span (e.g. "worker_abc > transformer_xyz")
def ancestor_label(oid):
    parts = []
    cur = id_to_name.get(oid, '?')
    pid = next((o.get('parentObservationId') for o in obs if o['id'] == oid), None)
    while pid and pid in {o['id'] for o in obs}:
        parts.append(id_to_name.get(pid, '?'))
        pid = next((o.get('parentObservationId') for o in obs if o['id'] == pid), None)
        if len(parts) > 5: break
    # Only include ancestors that are within the filtered set for brevity
    relevant_ancestors = [p for p in reversed(parts) if p in {id_to_name[i] for i in relevant_ids}]
    return ' > '.join(relevant_ancestors + [cur]) if relevant_ancestors else cur

print(f'=== Drilling into: {FILTER} ({len(relevant)} spans) ===')
print()

seen_tools = set()
for o in relevant:
    name = o.get('name','?')
    label = ancestor_label(o['id'])
    parent_name = id_to_name.get(o.get('parentObservationId',''), '?')
    typ = o.get('type', 'SPAN')
    inp = o.get('input')
    out = o.get('output')

    # Non-GENERATION spans (e.g. smart_table_plan) store data directly on input/output
    if typ != 'GENERATION':
        if inp is not None and not isinstance(inp, list):
            print(f'[{label}] INPUT: {json.dumps(inp)[:800]}')
        if out is not None:
            print(f'[{label}] OUTPUT: {json.dumps(out)[:800]}')
        if inp is not None or out is not None:
            print()
        continue

    # GENERATION spans: dig into message history for tool calls and results
    if inp and isinstance(inp, list):
        for msg in inp:
            if not isinstance(msg, dict): continue
            if msg.get('role') == 'assistant':
                for block in (msg.get('content') or []):
                    if not isinstance(block, dict) or block.get('type') != 'tool_use': continue
                    bid = block.get('id','')
                    if bid in seen_tools: continue
                    seen_tools.add(bid)
                    print(f'[{label}] TOOL_CALL {block[\"name\"]}: {json.dumps(block.get(\"input\",{}))[:600]}')
            for block in (msg.get('content') or []):
                if not isinstance(block, dict) or block.get('type') != 'tool_result': continue
                rc = block.get('content','')
                text = rc if isinstance(rc, str) else ' '.join(b.get('text','') for b in rc if isinstance(b,dict))
                if text.strip():
                    print(f'[{label}] TOOL_RESULT: {text[:400]}')

    if out and isinstance(out, dict):
        content = out.get('content','')
        if isinstance(content, str) and content.strip():
            print(f'[{name}] OUTPUT: {content[:600]}')
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get('type') == 'text' and block['text'].strip():
                    print(f'[{name}] OUTPUT: {block[\"text\"][:600]}')
    print()
"
```

---

## Rules

- **Always show overview first, always ask before drilling.** Never dump full I/O without asking.
- Traces easily exceed 200KB — be selective.
- If errors are present in Phase 1, highlight them and suggest drilling into that span first.
- If the user says `all`, drill with `FILTER = ''` (matches everything) but warn it will be large.
- The Langfuse UI link is always `https://langfuse.anyformat.ai` + `htmlPath` from the trace.
- Credentials: use `LANGFUSE_TRACING_PUBLIC_KEY` / `LANGFUSE_TRACING_SECRET_KEY` (not the generic names).
