---
description: Critique a screen across seven visual dimensions and return one prioritised fix list.
argument-hint: "[screenshot, URL, route, or component path]"
---

# /critique-screen

Adapted from `Owl-Listener/designer-skills`. The upstream command calls its seven critiques
by skill name; they are vendored here as files instead, so read the file.

## Target

$ARGUMENTS

If that is a route or a URL and no screenshot was given, capture one first with the
`claude-in-chrome` tools. Critiquing source code instead of a rendered screen misses
everything these dimensions measure.

## Steps

Run all seven. Each file at `~/.skills-library/design/judge/critique/<name>/SKILL.md`:

1. `critique-visual-hierarchy` — entry point, eye flow, weight, emphasis
2. `critique-brand-consistency` — mood, voice, token alignment (skip if no brand files exist)
3. `critique-composition` — balance, whitespace, rhythm, gestalt grouping
4. `critique-typography` — scale, readability, consistency, token compliance
5. `critique-color` — contrast ratios, palette coherence, semantic color
6. `critique-affordance` — clickability signals, state visibility, CTA clarity
7. `critique-information-density` — cognitive load, priority, scanning, progressive disclosure

The seven are independent. Dispatch them as parallel subagents against the same screenshot,
one dimension each, then merge.

## Output

One list, ranked, not seven reports:

- **P1** breaks usability, accessibility, or brand compliance. Fix before shipping.
- **P2** degrades the experience or creates inconsistency. Fix this sprint.
- **P3** polish. When there is capacity.

Each item: what is wrong, which dimension, and the specific change. Close with one
paragraph naming the strongest and the weakest dimension.

Do not fix anything. This command reports. Fixing is `fix/better-*` in the
`andrew-vibe-designer` router.
