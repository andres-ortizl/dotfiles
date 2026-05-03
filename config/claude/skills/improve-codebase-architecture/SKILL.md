---
name: improve-codebase-architecture
description: Find deepening opportunities in a codebase and propose refactors that turn shallow modules into deep ones. Aim is testability and AI-navigability. Use when the user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more testable.
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

## Vocabulary

Use these terms exactly in every suggestion. Consistent language is the point — don't drift into "component," "service," "API," or "boundary."

- **Module** — anything with an interface and an implementation (function, class, package, slice).
- **Interface** — everything a caller must know to use the module: types, invariants, error modes, ordering, config. Not just the type signature.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface: a lot of behaviour behind a small interface. **Deep** = high leverage. **Shallow** = interface nearly as complex as the implementation.
- **Seam** — where an interface lives; a place behaviour can be altered without editing in place. (Use this, not "boundary.")
- **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — what callers get from depth.
- **Locality** — what maintainers get from depth: change, bugs, knowledge concentrated in one place.

Key principles:

- **Deletion test**: imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.**
- **One adapter = hypothetical seam. Two adapters = real seam.**

## Process

### 1. Explore

Use the Agent tool with `subagent_type=Explore` to walk the codebase. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

If a `CONTEXT.md` exists at the repo root (or `CONTEXT-MAP.md` for multi-context repos), read it first — its vocabulary is the project's shared language and you should use it when naming modules. If `docs/adr/` exists, scan ADRs in the area you're touching so you don't re-litigate decisions. If neither exists, proceed without them; just don't invent ceremony.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each candidate:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage, and in how tests would improve

Use the project's actual domain vocabulary (from `CONTEXT.md` if present, otherwise the names already in the code) when describing modules — not generic terms like "FooBarHandler" or "the Order service" when "Order intake" is what the team would say.

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly (e.g. _"contradicts ADR-0007 — but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to explore?"

### 3. Discuss the chosen candidate

Once the user picks a candidate, walk the design tree with them — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Stay in conversation; don't go off and refactor unilaterally. The output of this skill is a clear refactor plan the user can hand to `/spec` or `/chunked-review`, not the refactor itself.

## Companion skills

- `/diagnose` — when an architectural problem was uncovered while debugging ("no good test seam exists for this bug"), `/diagnose` Phase 6 hands the finding here. Treat that as a prioritised candidate.
- `/spec` or `/chunked-review` — once a candidate is agreed, the actual implementation goes through one of those loops, not this skill.
- `/zoom-out` — if the user is unfamiliar with the area you're proposing to refactor, run `/zoom-out` first to give them a map.
