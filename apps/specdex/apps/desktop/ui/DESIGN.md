# specdex — Design System

The visual identity for **specdex**: a desktop app (Tauri, vanilla HTML/CSS/JS) that
visualizes autonomous AI coding runs as a living **fleet**. Each running spec is a
**minion** — a small card that quietly carries a lifecycle phase, a health state, and
0–2 working agents.

The system is **minimal + tactile**: calm, generous negative space and a restrained
palette, but the surfaces are **physical** — drams hardware, not flat web chrome.
Cards are raised and lift toward you; toggles and buttons press; status reads as
**glowing LEDs** and recessed sockets. It is a *single-window tool*, not a marketing
site — every token is chosen for legibility at a glance and for hours of ambient
watching without fatigue.

> **Note (2026-06):** this system started near-flat (hairline rules, `box-shadow:
> none`). It was deliberately re-skinned toward drams' *physical* component language —
> soft layered depth, pressed wells, LED indicators. The sections below describe the
> tactile system as shipped; `drams-components.html` is the live component reference.

---

## 1. Inspiration → concrete cues

Derived from **https://drams.framer.website/** (a Dieter-Rams-themed Framer site,
"less, but better"). The live page was inspected directly; the cues that drove this
system:

| Cue from Drams | What it became here |
|---|---|
| Near-black ink `rgb(38,38,38)` on off-white paper `#f7f7f7` / `#f4f4f4` | `--ink` / `--paper` — the whole light theme is built on this exact pair, not pure black-on-white (softer, calmer). |
| **Inter** at weights **400 / 450 / 500**, 700 only rarely | Our type scale tops out at **560**; body is 400/450. No bold-heavy headings. |
| Two accents: a calm blue `rgb(0,153,255)` and a warm orange `#FF611A`, used *sparingly* | Blue `#0a84ff` is the single interactive accent. The Drams orange inspired our **`needs-you`** ember `#e8601a` — the one warm hue, reserved for "a human is needed." |
| Soft, rounded **hardware** corners — knobs, buttons, switch tracks | Cards use a soft `12px`; circles (`50%`) for the LED life-dot, agent pips, rail sockets, and the sidebar push-button. |
| **Physical depth** — the components are raised plastic with soft drop shadows, pressed wells, dished faces | The `--lift` / `--lift-hover` / `--press` / `--well` token set. Cards are raised and lift on hover; toggles/buttons press in; rail sockets are recessed. Shadows are *soft and warm*, never harsh. |
| The **LED indicator dot** — a small lit pip with a colored halo | The life-dot and active agent pips are radial-sheen LEDs with a `--hue` glow; the current rail node is a lit LED; the sidebar button's LED lights ember when expanded. |
| Muted neutral grays `#6e6e6e`, `#cfcfcf` | `--ink-muted` / `--ink-faint` for secondary + tertiary text. |
| Airy, unobtrusive, "shouldn't be taken too seriously" but never cartoonish | The minion is a *creature you read*, not an emoji. Personality comes from the breathing LED and the tactile surfaces, not faces. |

---

## 2. Color

Defined as CSS custom properties on `:root` (light) and `:root[data-theme="dark"]`.
Two surfaces deep, hairline rules, one interactive accent, five health hues.

### Light (default)

```css
:root {
  /* surfaces */
  --paper:      #f4f4f2;
  --surface:    #ffffff;
  --surface-2:  #faf9f7;
  --rule:       #d9d6cf;
  --rule-soft:  #ece9e2;

  /* ink */
  --ink:        #262420;
  --ink-muted:  #6e6a62;
  --ink-faint:  #a29d92;

  /* single interactive accent — links, PR, current rail node. Never status. */
  --accent:     #0a86e8;
  --accent-fg:  #ffffff;
  --accent-soft:#dbeefd;

  /* health hues — dot color + soft wash. ONLY the dot carries these. */
  --alive:  #3f9d6b;  --alive-soft: #e6f1ea;   /* working — green, breathing */
  --idle:   #8b8780;  --idle-soft:  #edebe6;   /* waiting — neutral hollow ring */
  --stale:  #b08a3e;  --stale-soft: #f5edda;   /* no heartbeat — muted amber */
  --needs:  var(--ember);  --needs-soft: var(--ember-soft); /* blocked — ember */
  /* done = NEUTRAL, NOT blue. Blue is reserved for interactive + current rail node. */
  --done:   #7c7a72;  --done-soft:  #eceae5;
}
```

### Dark

```css
:root[data-theme="dark"] {
  --paper:      #181610;
  --surface:    #211e17;
  --surface-2:  #1b1812;
  --rule:       #36322a;
  --rule-soft:  #2a261f;

  --ink:        #ece7da;
  --ink-muted:  #a39c8c;
  --ink-faint:  #6f695c;

  --accent:     #4fa8ff;
  --alive: #5fc08a;  --alive-soft: #1a2a20;
  --idle:  #9a958a;  --idle-soft:  #26231b;
  --stale: #d3a85a;  --stale-soft: #2f2818;
  --needs: var(--ember);  --needs-soft: var(--ember-soft);
  --done:  #9b968a;  --done-soft:  #262219;
}
```

**Rules**

- **One interactive accent** (`--accent`, blue). Links, PR, the current rail node — the
  live cursor. Never status.
- **`needs-you` owns the only warm hue.** The ember `--needs` is the single point of
  warmth — that is *why* it draws the eye without an alarm.
- **Health is the dot only.** No card top-edge stripe; no health hue on the rail.
  The labeled legend above the fleet is the single key.
- **`--done` is neutral grey**, not blue. Blue exclusively means "interactive."
- **Theme toggle cycles system → light → dark** (3-state, `localStorage.dexTheme`).

---

## 3. Typography

System stack only — no Google Fonts, no CDN. Inter if locally installed (the Drams
face), otherwise the platform UI font.

```css
--font-sans: "Inter", "Inter Variable", -apple-system, BlinkMacSystemFont,
             "Segoe UI", system-ui, sans-serif;
--font-mono: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
```

**Scale** — small, tight, restrained. Headings never exceed weight **560**
(Drams uses 500; 700 is rare). Letter-spacing tightens as size grows.

| Token | size / line-height | weight | use |
|---|---|---|---|
| `--t-display` | 22px / 1.2  | 560 | fleet title |
| `--t-h2`      | 15px / 1.3  | 540 | section labels |
| `--t-name`    | 14px / 1.3  | 520 | minion name |
| `--t-body`    | 13px / 1.45 | 440 | reasons, meta |
| `--t-meta`    | 12px / 1.4  | 450 | phase, counts |
| `--t-micro`   | 10.5px / 1.3| 540 | uppercase eyebrow labels, tracking `.08em` |
| `--t-mono`    | 12px / 1.4  | 450 | PR #, project path |

- Numerals use `font-variant-numeric: tabular-nums` everywhere they update live
  (review round, PR, scores) so the layout never jitters.
- Uppercase micro-labels carry the only letter-spacing; everything else is tight or neutral.

---

## 4. Spacing, radius, shadow

A **4px base grid**. Density is "airy desktop" — comfortable, not cramped, not webby.

```css
--s-1: 4px;  --s-2: 8px;  --s-3: 12px; --s-4: 16px;
--s-5: 24px; --s-6: 32px; --s-7: 48px; --s-8: 64px;

--r-card: 12px;   /* minion card, spec-doc well — soft hardware corners */
--r-pill: 999px;  /* LED dots, rail sockets, toggle track, chips */
--r-chip: 6px;    /* small tags, the attach button */
```

**Depth tokens** — the tactile system. Soft, warm, layered; never harsh:

```css
--lift:       /* a raised surface (cards, buttons, timeline nodes) */
--lift-1:     /* a lighter raise (knobs, chips, the sidebar button) */
--lift-hover: /* lifts toward you on hover */
--press:      /* an inset/recessed press (toggle track, pressed button, spec-doc well) */
--well:       /* the flat color of an empty recessed socket (rail sockets/grooves) */
```

- **Depth carries the hardware feel.** Raised cards/buttons use `--lift`; recessed
  wells and pressed states use `--press`; the rail's empty sockets use `--well`.
- Cards **lift on hover** (`--lift-hover` + `translateY(-2px)`); buttons press on
  `:active`. Motion + depth = the tactile response.
- Card min-width ~280px, grid auto-fills; gutters `--s-4`. The fleet breathes.

---

## 5. Motion

Calm, slow, optional. Motion conveys *life*, never urgency.

```css
--ease: cubic-bezier(.4, .0, .2, 1);     /* standard */
--ease-soft: cubic-bezier(.25,.1,.25,1); /* settles, no overshoot */
--dur-fast: 140ms; --dur: 240ms; --dur-slow: 420ms;
```

Principles:

1. **The life-dot breathes.** The single source of "this is alive" is a slow opacity +
   scale pulse on the health dot (~2.6s for `alive`, slower/none for calmer states).
   Nothing else animates on idle.
2. **Enter/leave is a settle, not a pop.** New minions fade + rise `6px` over `--dur-slow`;
   leaving ones fade + drop. No bounce — the playfulness lives in the *tactile* response,
   not in springy entrances.
2b. **Tactile response.** Cards lift toward you on hover (`--lift-hover` + `-2px`);
   buttons and the sidebar push-button press in on `:active`; the toggle knob slides with
   a slight spring. Depth changing under the cursor is the "feel" of the hardware.
3. **State changes cross-fade** the dot color and left-edge tint over `--dur`. A phase
   advance slides the rail node, it doesn't jump.
4. **Respect `prefers-reduced-motion`** — all looping/transform animation is disabled;
   states still read via color and the static dot.
5. No spinners. Activity is shown by the breathing dot + active agent pips, not a throbber.

---

## 6. Minion anatomy

A minion is a **card you read like a face without a face**. Reading order, top-left to
bottom-right:

```
┌──────────────────────────────────────────────┐
│  ● parse-cache                       PR 4012 │   health dot + name      · pr (mono, right)
│  anyformat-backend                           │   project path (mono, muted)
│                                              │
│  ◐ ◐ ◑ ◑ ◐ ◐ ◑ ●━━━━━━━━━━━━━━━━━○ ○        │   phase rail (8 nodes; neutral, accent=current)
│  verify                                      │   current phase label
│                                              │
│  [coder ●] [reviewer ○]      round 2 · ★ 4   │   agent pips (left) · review meta (right)
│  ⚑ infra flake                               │   blocked reason — only when needs-you
└──────────────────────────────────────────────┘
```

### Parts

1. **Health dot** — the **only** surface that carries health color. A glowing LED
   (`--r-pill`, 10px). States:
   - `alive` — `--alive` green, **breathing** (2.8s pulse).
   - `idle` — **hollow ring** in `--idle` grey, no fill. At rest.
   - `stale` — `--stale` amber + faint dashed ring (heartbeat missed).
   - `needs-you` — `--needs` ember, **slow attention pulse** (3.4s).
   - `done` — `--done` neutral grey, flat fill + a tiny inset **check glyph**, no glow.

   A labeled **legend** above the fleet is the single key. No health stripe on cards.

2. **Name** (`--t-name`) — the spec name, the identity. Project path sits beneath in
   mono `--ink-muted` (the `project` field).

3. **Phase rail** — a hardware progress strip of 8 sockets (`setup·plan·build·review·
   ship·verify·complete·accepted`). **Strictly neutral — never a health hue.**
   - Done nodes → ink-grey (`--ink-faint`).
   - Current node → `--accent` blue (the live cursor; consistent with interactive blue).
   - Future sockets → recessed `--well`.
   - A done spec: rail fully ink-grey, no blue cursor (`.rail.complete`).

4. **Agent pips** — up to two: `coder`, `reviewer`. Filled = `active:true`, hollow ring
   = inactive. Active pips glow **green** (`--alive`), independent of spec health.
   Label in `--t-meta`. Absent role = absent pip.

6. **Review meta** (right of agents) — `round N` and a small `★ score` (1–5) when
   `review_round` / `review_score` are present. Tabular nums so they don't jitter on
   update. Hidden when zero/absent.

7. **PR badge** — top-right, mono `PR 4012`, `--accent` text only when present, links out.
   Absent → nothing (no empty slot).

8. **Blocked reason** — a single line with a small `⚑` flag glyph, shown **only** for
   `needs-you`, in `--needs` ink. This is the call to action; it's the lowest line so the
   eye lands on it last but unmistakably.

### Health → treatment summary

| health | dot | motion | extra |
|---|---|---|---|
| `alive` | green LED | breathe 2.8s | active agent pips glow green |
| `idle` | grey **hollow ring** | none | — |
| `stale` | amber + dashed ring | none | "no heartbeat" read |
| `needs-you` | ember | slow pulse 3.4s | blocked-reason line + flag |
| `done` | neutral grey + **check** | none, solid | rail fully ink-grey (`.rail.complete`) |

No card top-edge stripe. No card wash. Status reads from the **dot + its tooltip**
(`working` / `idle` / `stale — no heartbeat` / `needs you — blocked` / `done`) — there is
no standing legend; a thin toolbar under the topbar carries the layout/sort controls.

### Phase → treatment

Phase drives the **rail** (node positions) and the **label** only. The rail is **fully
neutral** — `done` nodes in ink-grey, `current` node in `--accent` blue, future in
`--well`. Health has no effect on rail color.

---

## 6b. Scrollbars

DRAMS "soft hardware": thin (9px), no track, a quiet pill thumb in `--rule` that darkens
to `--ink-faint` on hover. Applied app-wide (`*::-webkit-scrollbar*` plus the
`scrollbar-width:thin; scrollbar-color` fallback). Reuses existing tokens — no new colour,
adapts light↔dark for free. Scrolling is never an accent or health hue: scrolling is not
status.

## 6c. Live-team terminal screen

A dedicated full-height view (`#liveteam`, `calc(100vh - 57px)`) reached from a spec
detail's "live team ↗" header; the external **watch** button (a real terminal) is kept
alongside. Layout is L-C: a `dex-coder / dex-reviewer` segmented switcher above one big
scrolling terminal (`.lt-term`).

The terminal renders the captured swarm pane (tmux `capture-pane -e`, so ANSI survives)
through a zen parser that re-tones the colour into the system rather than reproducing it:

- The 16 ANSI slots map to the app's own tokens (`--term-*`): green=`--alive`,
  gold=`--stale`, blue=`--accent`, greys=`--ink*`; only brick/mauve/teal get their own
  muted values (with dark variants).
- 256-colour and truecolour are **hue-snapped** to the nearest token — nothing vivid
  escapes the palette.
- ANSI **backgrounds render as a 14% `color-mix` wash**, never a saturated fill, with
  readable ink text — a diff's "removed" line is a faint band, not a block.

Surface is the `--sunk` inset with DRAMS scrollbars; polling is 1.5s and sticks to the
bottom when already scrolled there.

---

## 7. Files

- `DESIGN.md` — this document.
- `index.html` — the prototype shell (topbar, soft theme toggle, sidebar, fleet grid).
- `style.css` — all tokens (incl. the `--lift`/`--press`/`--well` depth set) + every
  component, light & dark.
- `app.js` — renders ~6 hardcoded sample minions (every health state, several phases)
  from the `FleetRow` shape, wires the 3-state theme toggle (system → light → dark),
  and manages the `Cards ⇄ List` layout toggle (default: List, persisted).
- `drams-components.html` — self-contained reference gallery of the tactile components
  (soft toggle, push buttons, slider, rotary dial, segmented switch) in the palette.

Open `index.html` or `drams-components.html` directly in a browser — no build step, no
framework, no CDN.
