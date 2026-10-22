# <epic> - plan

**Goal:** <one sentence: what the user can do or see when the epic is done>

**Out of scope:** <list>

**Locked decisions:** <each decision the user made, with its date; these are not reopened without asking>

## Code map

<written from the explorer's map: subsystems, key files by symbol, invariants the slices must respect>

## Slices

### S1: <name>
- **Goal:** <one sentence, user-visible or behavioural>
- **Out of scope:** <list>
- **Touches:** <files or areas>
- **Depends on:** <slice ids, or none>
- **Acceptance:**
  - AC1: `<command>` -> <expected result>
  - AC2: `<command>` -> <expected result>
- **Ends in:** <a PR against <base> | a local change | no code>

## Waves

| Wave | Slices | Isolation |
|---|---|---|
| 1 | S1, S2 | none |
| 2 | S3 | none |
