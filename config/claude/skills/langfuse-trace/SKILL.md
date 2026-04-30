---
name: langfuse-trace
description: "Fetches and debugs a Langfuse trace by ID or URL. Renders a span-tree overview with auto-suggested drill targets, then drills into a chosen section to surface system prompts, tool calls, and tool results. Supports comparing two spans side-by-side. Use when the user provides a Langfuse trace ID or URL, mentions a langfuse.* link, or asks to debug, inspect, or compare spans in an LLM trace. Defaults to anyformat credentials (LANGFUSE_TRACING_*) and host (langfuse.anyformat.ai); other hosts work if LANGFUSE_HOST and LANGFUSE_PUBLIC_KEY/LANGFUSE_SECRET_KEY are set."
---

# Debug a Langfuse Trace

All trace fetching, parsing, and rendering happens in `trace.py` (in this skill's directory). Do NOT rewrite the parsing logic inline — invoke the script.

`trace.py` is a self-contained PEP 723 / `uv run` script (declares its own deps). Run it directly: `<skill_dir>/trace.py <args>`. Requires `uv` (Astral). On first invocation, `uv` resolves and caches `httpx` (~1s); subsequent runs are <200ms with the trace cache warm.

## Workflow

Tick each step before moving to the next. Steps are deliberately ordered to keep context lean: the overview is small, drills are large.

- [ ] **Step 1 — Overview.** Run `<skill_dir>/trace.py <trace_id_or_url> overview` (delegate to a `general-purpose` subagent with `model: sonnet` to keep parent context clean). Relay the output to the user.
- [ ] **Step 2 — Ask which section to drill.** After Step 1, stop and ask: *"Which section do you want to drill into? You can pass a name substring, an 8-char span id, or `compare A B`."* Do NOT proceed without an answer unless the overview surfaced a single obvious target (one ERROR span, or one span >70% of trace latency) — in which case suggest it explicitly and wait for confirmation.
- [ ] **Step 3 — Drill or compare.** Spawn a fresh `general-purpose` subagent (`model: sonnet`) and run `<skill_dir>/trace.py <trace_id> drill <pattern>` or `... compare <a> <b>`. The cache means re-fetching is free.
- [ ] **Step 4 — Synthesize.** The drill output is the raw evidence. Read it, then explain to the user what it means in your own words. Do NOT relay raw drill output to the user without commentary.

For follow-up drills in the same session, prefer `SendMessage` to the existing subagent over spawning a new one — the fetched trace is cached on disk regardless, but staying in one agent preserves any in-memory analysis.

## Subcommands of `trace.py`

```
trace.py <trace_id> overview                 # span tree, errors, suggested drills
trace.py <trace_id> drill <pattern>          # full message history; pattern = name substring or id-prefix
trace.py <trace_id> drill ""                 # everything (warn user — large output)
trace.py <trace_id> compare <a> <b>          # side-by-side metadata + messages for two spans
trace.py <trace_id> raw <span_id>            # full JSON of one span, no truncation
```

Pass the trace ID as a bare ID OR as a full URL — the last path segment is taken either way.

### Useful flags

- `--refresh` — bypass the `/tmp/langfuse-traces/<id>.json` cache (1h TTL).
- `--truncate-system` — truncate system prompts to 1500 chars. **Do NOT use** when the user is investigating prompt content; system prompts are full by default precisely because they are usually the answer.
- `--tool-input-max N`, `--tool-result-max N`, `--output-max N` — adjust per-message truncation. Defaults: 2500 / 600 / 2000 chars. Bump these when the user's question depends on a specific tool's full input.
- `--inline-io-max N` (overview only) — inline I/O for non-GENERATION spans up to N chars; default 400.

## Subagent rules

When delegating Step 1 or Step 3 to a subagent, include this verbatim in the prompt:

> Return the script output **raw**. Do NOT abbreviate, summarize, or replace
> sections with placeholders like `[as shown above]`, `[truncated]`, or `…`.
> If output is large, return it as-is — the parent will excerpt. Your job is
> to run the script and pass the bytes back.

This rule exists because the most common failure mode is a subagent silently summarizing a system prompt or tool call, forcing a second round-trip to recover the dropped text.

## When to use which subcommand

- **Default starting point:** `overview`. Always.
- **"Why did span X behave that way?"** → `drill <id-prefix-of-X>`. Use the id-prefix instead of the name when names repeat (e.g. multiple workers).
- **"Why did A do one thing and B do another?"** → `compare <A> <B>`. Pre-aligns metadata and shows both message histories.
- **"I need every byte of span X"** → `raw <id>`. Returns the full JSON observation with no truncation.
- **User asks for "the whole trace":** push back. Suggest `overview` first, then a targeted drill. `drill ""` is a last resort and you should warn before running it.

## Credentials and host

The script reads:
- `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` — preferred,
- falls back to `LANGFUSE_TRACING_PUBLIC_KEY` / `LANGFUSE_TRACING_SECRET_KEY` (anyformat convention),
- `LANGFUSE_HOST` defaults to `https://langfuse.anyformat.ai`.

If the script exits with a credentials error, tell the user which env var is missing — do not retry blindly.

## Output contract (what `trace.py` prints)

So you know what to expect without reading the script:

- **`overview`** — header (id, name, latency, cost, env, URL), errors block (if any), span tree with id-prefixes and per-node latency/tokens/cost, "Suggested next drills" (errors first, then spans >30% of total latency), and a list of drill targets.
- **`drill`** — per matching span: `━━━ [id8] TYPE name path latency ━━━` header, then either GENERATION message history (system, user, assistant text, `tool_call`, `tool_result`, `→OUT`) or non-GENERATION `IN:` / `OUT:` blocks.
- **`compare`** — two-column metadata table with `≠` markers on differing fields, then each span rendered as in `drill`.
- **`raw`** — pretty-printed JSON of one observation.

## Error handling

`trace.py` exits with a printed message on:
- missing credentials (instructs which env var to set),
- `langfuse-cli` failure (relays stderr),
- `No spans match <pattern>` (drill),
- `Ambiguous id prefix` / `Name not unique` (compare/raw — script lists candidate ids).

If you see one of these, fix it directly (e.g. retry with a longer id-prefix) rather than punting to the user.
