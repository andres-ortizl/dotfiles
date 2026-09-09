---
name: andrew-vibe-designer
description: "Router for the vendored design skill library. Load this ONCE when the work is about how something looks or feels: judging a screen, fixing typography/color/layout/spacing/accessibility, choosing a visual direction, building a landing page or marketing site, or adding motion. It names the ONE library file to read next."
triggers:
  - design
  - looks bad
  - looks generic
  - make it beautiful
  - critique this
  - is this good
  - visual polish
  - landing page
  - typography
  - color palette
  - spacing
  - layout
  - animation
  - micro-interaction
  - accessibility
---

# Vibe designer — router

The library lives at `~/.skills-library/design/`. It holds 118 skills from seven upstream
repos. **They are not registered skills.** Read them as files.

Read this router once, pick a lane, read **one** library file. Two at most. The library is
2.4 MB; loading it is not the point of it existing.

## The loop — do this without being asked

Andrew judges rendered screens well and specifies poorly. He will not tell you to use these
skills. Run the loop anyway, every time visual work is in play.

1. **Render it first.** Screenshot the real screen in a real browser before forming any
   opinion. A critique of code you have only read is a guess. If you cannot render it, say
   so out loud rather than reasoning from the source.
2. **Judge with a file, never from memory.** The moment you are about to state a design
   opinion — "it feels unbalanced", "that's too big" — stop and read the lens that covers
   it. Your own taste is the fallback, not the method. Do not skip this because the answer
   seems obvious; the obvious answer is what the lens is checking.
3. **Fan the lenses out.** The judge lane is cheap in the main thread because each lens goes
   to its own subagent. Six parallel critics cost you one message. The two-file cap below
   governs what *you* read, not what you delegate.
4. **Re-render and re-judge after the change.** A fix is not done because the diff looks
   right. Capture it again and run the lens that flagged it.
5. **Report what the lenses said, not what you concluded.** Name the dimension and its
   rating. When two independent lenses flag the same element, that is a finding, not an
   opinion — act on it.

Skipping the loop to save a round trip is the failure mode this library exists to prevent.

## Step 1 — pick the lane

Ask what the user is actually holding.

- They are showing you something and asking whether it works → **Judge**
- They named the flaw already ("the spacing is off", "these colors fight") → **Fix**
- Nothing exists yet and there is no visual direction → **Taste**
- Nothing exists yet and the direction is settled → **Build**
- It is static and should not be → **Motion**

When two lanes fit, judge first. A critique that names the dimension turns any other lane
into a one-file read.

## Step 2 — read one file

Paths are relative to `~/.skills-library/design/`.

### Judge

| When | Read |
|---|---|
| A whole screen, want a prioritised fix list | run the `/critique-screen` command |
| One dimension you already suspect | `judge/critique/critique-{visual-hierarchy,composition,typography,color,affordance,information-density,brand-consistency}/SKILL.md` |
| A diff, a branch, or a PR rather than a screen | `judge/interface-review/SKILL.md` |

### Fix

| When | Read |
|---|---|
| Type, fonts, scale, measure, truncation | `fix/better-typography/SKILL.md` |
| Palette, dark mode, contrast, semantic color | `fix/better-colors/SKILL.md` |
| Page structure, what collapses at small sizes | `fix/better-layout/SKILL.md` |
| Component polish, hover/focus/active states, "it feels cheap" | `fix/better-ui/SKILL.md` |
| Keyboard, screen reader, ARIA, custom widgets | `fix/better-accessibility/SKILL.md` |
| Button labels, error text, empty states | `fix/better-writing/SKILL.md` |
| You would rather choose than specify | `fix/variant/SKILL.md` |

`fix/variant` builds several genuinely different versions behind a picker in the real page.
Reach for it whenever the user can judge a result but cannot describe the target.

### Taste

| When | Read |
|---|---|
| App and product UI, component-level polish | `taste/emil-design-eng/SKILL.md` |
| Gesture-driven, spring physics, native feel | `taste/apple-design/SKILL.md` |
| Systematic web design with a critique loop | `taste/web-design-engineer/SKILL.md` |
| Whole-site style lock, anti-slop pass | `taste/tastemaker/SKILL.md` |
| One on-brand illustration for a concept | `taste/tastemaker/ideagram/SKILL.md` |

`taste/tastemaker/SKILL.md` is 55 KB. Read its `references/` files individually instead
when the task is narrow.

### Build

| When | Read |
|---|---|
| Marketing or landing page | `build/landing-page-design/SKILL.md` |
| Motion-led, cinematic, awwwards-bar site | `build/mengto-web-design/build-awwwards-quality-sites/SKILL.md` **plus exactly one style recipe** |
| Pricing page | `build/mengto-web-design/pricing-page/SKILL.md` |
| Throwaway prototype to compare approaches | `build/prototype/SKILL.md` |
| Choosing a component library | `build/pick-ui-library/SKILL.md` |
| Toasts | `build/ask-sonner/SKILL.md` |

### Motion

| When | Read |
|---|---|
| Should anything animate here at all | `motion/find-animation-opportunities/SKILL.md` — **start here** |
| Implement a web animation | `motion/animate/SKILL.md` (recipes in `RECIPES.md`) |
| React Native or Expo | `motion/animate-expo/SKILL.md` |
| Existing animation feels wrong | `motion/improve-animations/SKILL.md` |
| Review animation quality | `motion/review-animations/SKILL.md` |
| Name a motion so it can be asked for | `motion/animation-vocabulary/SKILL.md` |

## Named looks

Two catalogues of named aesthetics. Pick one recipe, name it out loud, build only that.

- `build/mengto-web-design/` — 88 looks and techniques, one directory each (`glass-dark-ui`,
  `editorial-tech`, `light-mode-paper-technical`, `documentary-brutalist-agency`, ...)
- `taste/web-design-engineer/references/style-recipes/INDEX.md` — 25 looks anchored to real
  brands and studios (Linear, Stripe Press, Muji, Bloomberg Terminal, Tufte, ...)

`build-awwwards-quality-sites` requires this: it says to select and name one compatible
web-design skill. Give it one from the first list.

## Rules

**Never blend two aesthetic sources.** Apple HIG restraint, awwwards maximalism, and
Jakub's minimalism contradict each other on purpose. Pick one, say which, build it. A
blend produces exactly the generic result these skills exist to prevent.

**Two library files per task, maximum.** These files are long. Spending the context window
on advice leaves none for the code the advice is about.

**Show, do not describe.** The user judges rendered output well and specs poorly. Build the
thing, or build three variants, then ask. Do not ask which typeface pairing they prefer.

**Defer to the skills that already own their surface.** `artifact-design` owns Artifacts,
`dataviz` owns every chart, `frontend-design` covers generic UI direction. This library is
for what they do not cover.

## Full catalogue

`~/.skills-library/design/INDEX.md` — every one of the 118 skills with its description,
grouped by lane. Read it only when this router's tables have no obvious match.

## Provenance

Vendored, not fetched at runtime. `bin/design-skills-sync` re-pulls at the SHAs in
`~/.skills-library/design/sources.lock`. Edit `sources.tsv` to add or drop a source. All
seven upstreams are MIT; see `licenses/`.
