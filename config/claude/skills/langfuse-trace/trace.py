#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx>=0.27"]
# ///
"""Generic Langfuse trace inspector.

Subcommands:
  overview            Span tree, errors, auto-suggested drill targets, inline
                      I/O for small non-GENERATION spans.
  drill <pattern>     Show full message history for spans matching <pattern>
                      (substring of name, or 8-char id prefix; "" = all).
  compare <a> <b>     Side-by-side metadata + message history for two spans.
                      Args are id prefixes or unique names.
  raw <span_id>       Dump one span verbatim (full JSON, no truncation).

Trace JSON is cached at /tmp/langfuse-traces/<trace_id>.json (1h TTL).
Pass --refresh to force re-fetch. Trace ID can be a bare ID or a URL.

I/O truncation defaults are tuned for typical Anthropic-style messages but
configurable via --tool-input-max / --tool-result-max / --output-max.
System prompts are NEVER truncated unless --truncate-system is passed.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import httpx

CACHE_DIR = Path("/tmp/langfuse-traces")
CACHE_TTL_SECONDS = 3600


def fetch_trace(trace_id: str, refresh: bool = False) -> dict:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = CACHE_DIR / f"{trace_id}.json"
    if cache.exists() and not refresh:
        if time.time() - cache.stat().st_mtime < CACHE_TTL_SECONDS:
            try:
                return json.loads(cache.read_text())
            except json.JSONDecodeError:
                pass  # corrupted cache — re-fetch

    pub = os.environ.get("LANGFUSE_PUBLIC_KEY") or os.environ.get("LANGFUSE_TRACING_PUBLIC_KEY")
    sec = os.environ.get("LANGFUSE_SECRET_KEY") or os.environ.get("LANGFUSE_TRACING_SECRET_KEY")
    host = os.environ.get("LANGFUSE_HOST", "https://langfuse.anyformat.ai").rstrip("/")
    if not pub or not sec:
        sys.exit(
            "Missing credentials. Set LANGFUSE_PUBLIC_KEY/LANGFUSE_SECRET_KEY, "
            "or LANGFUSE_TRACING_PUBLIC_KEY/LANGFUSE_TRACING_SECRET_KEY (anyformat).",
        )

    url = f"{host}/api/public/traces/{trace_id}"
    try:
        resp = httpx.get(url, auth=(pub, sec), timeout=30.0)
    except httpx.HTTPError as e:
        sys.exit(f"Fetch failed ({type(e).__name__}): {e}")
    if resp.status_code == 404:
        sys.exit(f"Trace {trace_id!r} not found at {host}.")
    if resp.status_code in (401, 403):
        sys.exit(f"Auth rejected by {host} ({resp.status_code}). Check LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY.")
    if resp.status_code >= 400:
        sys.exit(f"Fetch failed: HTTP {resp.status_code} — {resp.text[:300]}")
    # Mirror the legacy CLI's `{body: ...}` envelope so cached files are interchangeable.
    payload = {"body": resp.json()}
    cache.write_text(json.dumps(payload))
    return payload


def build_indices(obs: list[dict]) -> tuple[dict, dict, dict]:
    by_id = {o["id"]: o for o in obs}
    parent_map = {o["id"]: o.get("parentObservationId") for o in obs}
    children_map: dict[str, list[dict]] = {}
    for o in obs:
        pid = o.get("parentObservationId")
        if pid and pid in by_id:
            children_map.setdefault(pid, []).append(o)
    for v in children_map.values():
        v.sort(key=lambda o: o.get("startTime", ""))
    return by_id, parent_map, children_map


def ancestor_names(oid: str, parent_map: dict, by_id: dict, max_depth: int = 12) -> list[str]:
    parts: list[str] = []
    cur = parent_map.get(oid)
    while cur and cur in by_id and len(parts) < max_depth:
        parts.append(by_id[cur].get("name", "?"))
        cur = parent_map.get(cur)
    return list(reversed(parts))


def descendants(oid: str, children_map: dict) -> set[str]:
    out: set[str] = set()
    queue = [c["id"] for c in children_map.get(oid, [])]
    while queue:
        cid = queue.pop()
        out.add(cid)
        queue.extend(c["id"] for c in children_map.get(cid, []))
    return out


def _indent(text: str, n: int) -> str:
    pad = " " * n
    return "\n".join(pad + line for line in text.splitlines())


def _flatten(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(b.get("text", "") for b in content if isinstance(b, dict))
    return str(content) if content is not None else ""


def _short_id(oid: str) -> str:
    return oid[:8] if oid else "?"


def render_generation(
    o: dict,
    *,
    system_full: bool,
    tool_input_max: int,
    tool_result_max: int,
    output_max: int,
) -> list[str]:
    """Render a GENERATION span's full message history as printable lines."""
    lines: list[str] = []
    inp = o.get("input")
    out = o.get("output")
    seen_tools: set[str] = set()

    if isinstance(inp, list):
        for msg in inp:
            if not isinstance(msg, dict):
                continue
            role = (msg.get("role") or "?").upper()
            content = msg.get("content")
            if msg.get("role") == "system":
                text = _flatten(content)
                if system_full:
                    lines.append(f"  [SYSTEM] ({len(text)} chars):")
                    lines.append(_indent(text, 4))
                else:
                    lines.append(f"  [SYSTEM] ({len(text)} chars, truncated):")
                    lines.append(_indent(text[:1500] + ("…" if len(text) > 1500 else ""), 4))
                continue
            if isinstance(content, str):
                if content.strip():
                    lines.append(f"  [{role}]: {content[:output_max]}")
                continue
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    btype = block.get("type", "?")
                    if btype == "text":
                        t = block.get("text", "").strip()
                        if t:
                            lines.append(f"  [{role}] text: {t[:output_max]}")
                    elif btype == "tool_use":
                        bid = block.get("id", "")
                        if bid in seen_tools:
                            continue
                        seen_tools.add(bid)
                        ti = json.dumps(block.get("input", {}))
                        suffix = "…" if len(ti) > tool_input_max else ""
                        lines.append(f"  [{role}] tool_call {block.get('name')}: {ti[:tool_input_max]}{suffix}")
                    elif btype == "tool_result":
                        text = _flatten(block.get("content", ""))
                        if text.strip():
                            suffix = "…" if len(text) > tool_result_max else ""
                            lines.append(f"  [{role}] tool_result: {text[:tool_result_max]}{suffix}")

    if isinstance(out, dict):
        c = out.get("content", "")
        if isinstance(c, str) and c.strip():
            lines.append(f"  →OUT text: {c[:output_max]}")
        elif isinstance(c, list):
            for block in c:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text" and block.get("text", "").strip():
                    lines.append(f"  →OUT text: {block['text'][:output_max]}")
                elif block.get("type") == "tool_use":
                    ti = json.dumps(block.get("input", {}))
                    suffix = "…" if len(ti) > tool_input_max else ""
                    lines.append(f"  →OUT tool_call {block.get('name')}: {ti[:tool_input_max]}{suffix}")
    return lines


def render_span_io(o: dict, output_max: int) -> list[str]:
    """Render a non-GENERATION span's input/output."""
    lines: list[str] = []
    for label, val in (("IN", o.get("input")), ("OUT", o.get("output"))):
        if val is None:
            continue
        if isinstance(val, list):
            # Treat as message list (rare for SPAN type)
            try:
                serialized = json.dumps(val, indent=2)
            except (TypeError, ValueError):
                serialized = str(val)
        elif isinstance(val, str):
            serialized = val
        else:
            try:
                serialized = json.dumps(val, indent=2)
            except (TypeError, ValueError):
                serialized = str(val)
        cap = output_max * 2
        suffix = "…" if len(serialized) > cap else ""
        lines.append(f"  {label}:")
        lines.append(_indent(serialized[:cap] + suffix, 4))
    return lines


def cmd_overview(d: dict, obs: list[dict], args: argparse.Namespace) -> None:
    by_id, parent_map, children_map = build_indices(obs)
    roots = [o for o in obs if not o.get("parentObservationId") or o.get("parentObservationId") not in by_id]
    roots.sort(key=lambda o: o.get("startTime", ""))

    lat = d.get("latency")
    print(f"Trace:    {d['id']}")
    print(f"Name:     {d.get('name') or '(unnamed)'}")
    print(f"Time:     {d.get('timestamp')}")
    print(f"Latency:  {lat:.1f}s" if isinstance(lat, (int, float)) else f"Latency:  {lat}")
    print(f"Cost:     ${d.get('totalCost') or 0:.4f}")
    print(f"Env:      {d.get('environment')}")
    host = os.environ.get("LANGFUSE_HOST", "https://langfuse.anyformat.ai")
    print(f"URL:      {host}{d.get('htmlPath', '')}")
    print(f"Spans:    {len(obs)} total, {len(roots)} root(s)")
    print()

    errors = [o for o in obs if o.get("level") in ("ERROR", "WARNING") or o.get("statusMessage")]
    if errors:
        print("=== Errors / Warnings ===")
        for o in errors:
            print(f"  [{o.get('level')}] {o.get('name')} ({_short_id(o['id'])}): "
                  f"{o.get('statusMessage') or '(no message)'}")
        print()

    print("=== Span Tree ===")

    def print_node(o: dict, indent: int = 0) -> None:
        typ = o.get("type", "SPAN")
        name = o.get("name", "?")
        sid = _short_id(o["id"])
        lat = o.get("latency")
        lat_s = f"{lat:.1f}s" if isinstance(lat, (int, float)) else ""
        model = f" [{o.get('model')}]" if o.get("model") else ""
        tokens = f" {o['totalTokens']}tok" if o.get("totalTokens") else ""
        cost = f" ${o['calculatedTotalCost']:.4f}" if o.get("calculatedTotalCost") else ""
        warn = " ⚠" if o.get("level") in ("ERROR", "WARNING") else ""
        prefix = "  " * indent
        print(f"{prefix}{typ} {name} ({sid}){model}{tokens}{cost} {lat_s}{warn}")
        # Inline I/O for small non-GENERATION spans — high-signal, low-cost
        if typ != "GENERATION":
            for label, val in (("↳IN", o.get("input")), ("↳OUT", o.get("output"))):
                if val is None or isinstance(val, list):
                    continue
                s = val if isinstance(val, str) else json.dumps(val)
                if 0 < len(s) <= args.inline_io_max:
                    print(f"{prefix}  {label}: {s}")
        for child in children_map.get(o["id"], []):
            print_node(child, indent + 1)

    for r in roots:
        print_node(r)
    print()

    print("=== Suggested next drills ===")
    suggestions: list[str] = []
    if errors:
        for e in errors[:3]:
            suggestions.append(
                f"  ⚠ Error in `{e.get('name')}` ({_short_id(e['id'])}) — "
                f"`drill {_short_id(e['id'])}` to investigate",
            )
    total_lat = d.get("latency") or 0
    if total_lat:
        # Rank spans by self-latency that exceeds 30% of total
        candidates = [(o, o.get("latency") or 0) for o in obs]
        candidates.sort(key=lambda x: -x[1])
        for o, lat in candidates[:5]:
            if lat > total_lat * 0.30 and lat < total_lat * 0.99:
                pct = lat / total_lat * 100
                suggestions.append(
                    f"  🔥 `{o.get('name')}` ({_short_id(o['id'])}) — "
                    f"{lat:.1f}s ({pct:.0f}% of trace)",
                )
    if not suggestions:
        suggestions.append("  (no obvious targets — pick a section by name below)")
    for s in suggestions[:5]:
        print(s)
    print()

    spans_only = [o for o in obs if o.get("type") == "SPAN"]
    name_counts: dict[str, int] = {}
    for o in spans_only:
        nm = o.get("name", "?")
        name_counts[nm] = name_counts.get(nm, 0) + 1
    print("=== Drill targets (substring match against names; or use 8-char id) ===")
    for name in sorted(name_counts):
        marker = f" (×{name_counts[name]})" if name_counts[name] > 1 else ""
        print(f"  - {name}{marker}")


def cmd_drill(d: dict, obs: list[dict], args: argparse.Namespace) -> None:
    by_id, parent_map, children_map = build_indices(obs)
    pattern = (args.pattern or "").lower()

    def matches(o: dict) -> bool:
        if not pattern:
            return True
        if pattern in o.get("name", "").lower():
            return True
        # 8-char (or longer) id-prefix match
        return len(pattern) >= 4 and o["id"].lower().startswith(pattern)

    matching_ids = {o["id"] for o in obs if matches(o)}
    if not matching_ids:
        sys.exit(f"No spans match {args.pattern!r}")

    relevant_ids = set(matching_ids)
    if args.descendants:
        for mid in list(matching_ids):
            relevant_ids |= descendants(mid, children_map)

    relevant = [o for o in obs if o["id"] in relevant_ids]
    relevant.sort(key=lambda o: o.get("startTime", ""))
    relevant_names = {by_id[i].get("name") for i in relevant_ids}

    print(f"=== Drilling into: {args.pattern!r} ({len(relevant)} spans) ===\n")

    for o in relevant:
        chain = ancestor_names(o["id"], parent_map, by_id)
        # Only show ancestors that are themselves in the relevant set, for brevity
        chain = [c for c in chain if c in relevant_names]
        path = " > ".join(chain + [o.get("name", "?")])
        sid = _short_id(o["id"])
        typ = o.get("type", "SPAN")
        lat = o.get("latency")
        lat_s = f"{lat:.1f}s" if isinstance(lat, (int, float)) else ""
        model = f" [{o.get('model')}]" if o.get("model") else ""
        print(f"━━━ [{sid}] {typ} {path}{model} {lat_s} ━━━")

        if typ == "GENERATION":
            for line in render_generation(
                o,
                system_full=not args.truncate_system,
                tool_input_max=args.tool_input_max,
                tool_result_max=args.tool_result_max,
                output_max=args.output_max,
            ):
                print(line)
        else:
            for line in render_span_io(o, args.output_max):
                print(line)
        print()


def _resolve_span(arg: str, obs: list[dict]) -> dict:
    # Exact id, then id prefix (≥4 chars), then unique name match
    for o in obs:
        if o["id"] == arg:
            return o
    if len(arg) >= 4:
        prefixes = [o for o in obs if o["id"].startswith(arg)]
        if len(prefixes) == 1:
            return prefixes[0]
        if len(prefixes) > 1:
            sys.exit(f"Ambiguous id prefix {arg!r}: matches {len(prefixes)} spans")
    by_name = [o for o in obs if o.get("name") == arg]
    if len(by_name) == 1:
        return by_name[0]
    if len(by_name) > 1:
        sys.exit(
            f"Name {arg!r} is not unique ({len(by_name)} matches). Use an id "
            f"prefix instead: {[_short_id(o['id']) for o in by_name[:5]]}",
        )
    sys.exit(f"No span matches {arg!r}")


def cmd_compare(d: dict, obs: list[dict], args: argparse.Namespace) -> None:
    by_id, _, children_map = build_indices(obs)
    a = _resolve_span(args.span_a, obs)
    b = _resolve_span(args.span_b, obs)

    def parent_name(o: dict) -> str:
        pid = o.get("parentObservationId")
        return by_id[pid].get("name", "—") if pid and pid in by_id else "—"

    rows = [
        ("id", _short_id(a["id"]), _short_id(b["id"])),
        ("name", a.get("name", "?"), b.get("name", "?")),
        ("type", a.get("type", "?"), b.get("type", "?")),
        ("model", a.get("model", "—"), b.get("model", "—")),
        ("latency", f"{a.get('latency') or 0:.2f}s", f"{b.get('latency') or 0:.2f}s"),
        ("tokens", str(a.get("totalTokens", "—")), str(b.get("totalTokens", "—"))),
        ("cost", f"${a.get('calculatedTotalCost') or 0:.4f}", f"${b.get('calculatedTotalCost') or 0:.4f}"),
        ("parent", parent_name(a), parent_name(b)),
        ("children", str(len(children_map.get(a["id"], []))), str(len(children_map.get(b["id"], [])))),
    ]
    width = 44
    print("=== Compare ===\n")
    print(f"  {'':>10}  {'A':<{width}}  {'B':<{width}}")
    print(f"  {'':>10}  {'-'*width}  {'-'*width}")
    for label, va, vb in rows:
        diff = "  " if va == vb else "≠ "
        print(f"  {label:>10}  {diff}{str(va):<{width-2}}  {str(vb):<{width}}")
    print()

    def render(o: dict, label: str) -> None:
        print(f"--- {label}: [{_short_id(o['id'])}] {o.get('name')} ---")
        if o.get("type") == "GENERATION":
            for line in render_generation(
                o,
                system_full=not args.truncate_system,
                tool_input_max=args.tool_input_max,
                tool_result_max=args.tool_result_max,
                output_max=args.output_max,
            ):
                print(line)
        else:
            for line in render_span_io(o, args.output_max):
                print(line)
            kids = children_map.get(o["id"], [])
            if kids:
                print("  CHILDREN:")
                for c in kids:
                    clat = c.get("latency")
                    clat_s = f"{clat:.1f}s" if isinstance(clat, (int, float)) else "?"
                    print(f"    {c.get('type')} {c.get('name')} ({_short_id(c['id'])}) {clat_s}")
        print()

    render(a, "A")
    render(b, "B")


def cmd_raw(d: dict, obs: list[dict], args: argparse.Namespace) -> None:
    target = _resolve_span(args.span_id, obs)
    print(json.dumps(target, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("trace_id", help="Trace ID or full URL (last path segment is taken)")
    parser.add_argument("--refresh", action="store_true", help="Bypass /tmp cache")
    parser.add_argument("--truncate-system", action="store_true", help="Truncate system prompts (off by default)")
    parser.add_argument("--tool-input-max", type=int, default=2500)
    parser.add_argument("--tool-result-max", type=int, default=600)
    parser.add_argument("--output-max", type=int, default=2000)
    parser.add_argument("--inline-io-max", type=int, default=400,
                        help="In overview, inline I/O for non-GENERATION spans up to this many chars")

    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("overview", help="Span tree + auto-suggestions (default first step)")
    p_drill = sub.add_parser("drill", help="Show full message history for matching spans")
    p_drill.add_argument("pattern", help='Substring of name, or id-prefix (≥4 chars). "" matches all.')
    p_drill.add_argument("--no-descendants", dest="descendants", action="store_false", default=True,
                         help="Do NOT include children of matching spans")
    p_cmp = sub.add_parser("compare", help="Side-by-side comparison of two spans")
    p_cmp.add_argument("span_a", help="id-prefix or unique name")
    p_cmp.add_argument("span_b", help="id-prefix or unique name")
    p_raw = sub.add_parser("raw", help="Dump one span as full JSON")
    p_raw.add_argument("span_id", help="id-prefix or unique name")

    args = parser.parse_args()

    # Accept either a bare ID or a URL — take the last path segment
    tid = args.trace_id.rstrip("/").rsplit("/", 1)[-1]

    outer = fetch_trace(tid, refresh=args.refresh)
    d = outer.get("body", outer)
    obs = sorted(d.get("observations", []), key=lambda o: o.get("startTime", ""))

    handlers = {
        "overview": cmd_overview,
        "drill": cmd_drill,
        "compare": cmd_compare,
        "raw": cmd_raw,
    }
    handlers[args.cmd](d, obs, args)


if __name__ == "__main__":
    main()
