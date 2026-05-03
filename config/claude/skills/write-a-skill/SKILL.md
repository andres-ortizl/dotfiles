---
name: write-a-skill
description: Create new agent skills with proper structure, progressive disclosure, and bundled resources. Merges Anthropic's authoring best practices with a pragmatic process for our repo. Use when the user wants to create, write, or build a new skill.
---

# Writing Skills

A skill is a directory under `~/.claude/skills/` containing a `SKILL.md` (required) and any reference files, templates, or scripts needed. Claude pre-loads only the skill's name and description; everything else is read on demand.

## Process

1. **Gather requirements** — ask the user:
   - What task / domain does the skill cover? Concrete trigger examples?
   - What specific use cases must it handle?
   - Does it need executable scripts, or just instructions?
   - Any reference materials to include (existing docs, code patterns, golden examples)?

2. **Draft the skill** — create:
   - `SKILL.md` with concise instructions (under 500 lines).
   - Reference files for content that isn't needed every invocation.
   - Utility scripts only for deterministic operations.

3. **Review with user** — present the draft and ask:
   - Does this cover your use cases?
   - Anything missing or unclear?
   - Any section under- or over-specified?

4. **Verify against the checklist** at the bottom of this file before declaring done.

## Skill structure

```
skill-name/
├── SKILL.md          # Main instructions (required)
├── REFERENCE.md      # Detailed docs (only if needed)
├── EXAMPLES.md       # Usage examples (only if needed)
└── scripts/          # Utility scripts (only if needed)
    └── helper.py
```

Place new skills under `config/claude/skills/<name>/` in the dotfiles repo. They are symlinked into `~/.claude/skills/` by dotbot. Do not write directly into `~/.claude/skills/`.

## SKILL.md template

```md
---
name: skill-name
description: One-sentence capability statement. Use when [specific triggers].
---

# Skill Name

## Quick start

[Minimal working example]

## Workflows

[Step-by-step processes with checklists for complex tasks]

## Advanced

[Link out to REFERENCE.md / EXAMPLES.md if any]
```

## Frontmatter rules (hard requirements)

`name`:
- Max 64 chars, lowercase letters, numbers, hyphens only.
- No XML tags. No reserved words: `anthropic`, `claude`.

`description`:
- Max 1024 chars, non-empty.
- Third person ("Processes Excel files…"), never first or second person.
- First sentence: what the skill does.
- Second sentence: `Use when [specific triggers]`.
- Include keywords/contexts the user is likely to type — this is the only string Claude sees when choosing among 100+ skills.

**Good** description:
> `Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.`

**Bad** description:
> `Helps with documents.` (no triggers, no specificity)
> `I can help you process Excel files…` (first person — breaks discovery)

## Core principles

### Concise is key

Claude is already very smart. Only add context Claude doesn't already have. For each paragraph, ask:

- Does Claude really need this explanation?
- Can I assume Claude already knows this?
- Does this paragraph justify its token cost?

Once Claude loads SKILL.md, every token competes with conversation history and other context.

### Set appropriate degrees of freedom

Match specificity to the task's fragility:

- **High freedom** (text-based instructions) — multiple valid approaches, decisions depend on context. _Code review, design discussions._
- **Medium freedom** (pseudocode or parameterised scripts) — preferred pattern with allowed variation. _Templated reports, schema generation._
- **Low freedom** (specific scripts, no params) — fragile or destructive operations where consistency is critical. _DB migrations, deploy steps._

Analogy: narrow bridge with cliffs → low freedom. Open field → high freedom.

### Progressive disclosure

SKILL.md should read like a table of contents. Push details into separate files Claude can load on demand:

```
pdf/
├── SKILL.md          # Overview, points to references
├── FORMS.md          # Form-filling guide (loaded as needed)
├── reference.md      # API reference
└── scripts/
    └── analyze_form.py
```

**One level deep only.** Don't chain `SKILL.md → advanced.md → details.md` — Claude may partial-read intermediate files and miss the actual content. Every reference file should link directly from SKILL.md.

For reference files over 100 lines, put a table of contents at the top so Claude can see the scope even if it only previews the first chunk.

### Workflows + feedback loops

For multi-step or fragile tasks, give Claude a copyable checklist:

```
Task Progress:
- [ ] Step 1: …
- [ ] Step 2: …
- [ ] Step 3: …
```

For quality-critical work, add a validation loop: _run validator → fix errors → repeat → only proceed when clean_. The validator can be a script or a reference doc Claude reads against (e.g. `STYLE_GUIDE.md`).

### When to add scripts

Pre-made utility scripts beat asking Claude to generate code when:

- The operation is deterministic (validation, formatting, parsing).
- The same code would be regenerated repeatedly.
- Errors need explicit handling.

Scripts save tokens (Claude executes them rather than loading their contents) and improve reliability.

When you do write a script: **solve, don't punt** — handle the error rather than letting it bubble back to Claude with no context. Document any constants ("HTTP requests typically complete within 30s" beats `TIMEOUT = 47  # ?`).

Make execution intent explicit:
- "Run `analyze_form.py` to extract fields" → execute.
- "See `analyze_form.py` for the extraction algorithm" → read as reference.

### When to split files

Split when:

- SKILL.md exceeds ~500 lines (hard limit for performance) or 100 lines (split early if natural).
- Content has distinct domains (e.g. `reference/finance.md`, `reference/sales.md` — load only the relevant one).
- Advanced features are rarely needed (push them out of the hot path).

## Naming

Use **gerund form** (verb + -ing) when the skill is an activity:

- ✓ `processing-pdfs`, `analyzing-spreadsheets`, `writing-documentation`
- Acceptable: noun-phrase (`pdf-processing`) or imperative (`process-pdfs`).
- Avoid: `helper`, `utils`, `tools`, `documents` — too vague.

Stay consistent within our skill collection. Existing names in this repo are flat (`spec`, `pr`, `tdd`, `diagnose`); follow that convention unless there's a reason not to.

## Anti-patterns

- **Time-sensitive info** — "After August 2025, use the new API" — will rot. Put deprecated content in a collapsed `<details>` block titled "Old patterns" instead.
- **Inconsistent terminology** — pick one term ("API endpoint", "field", "extract") and use it throughout. Mixing synonyms confuses both Claude and readers.
- **Too many options** — "use pypdf or pdfplumber or PyMuPDF or…" — pick a default, mention escape hatches in one line.
- **Windows-style paths** — always forward slashes, even in examples.
- **Deeply nested references** — see "progressive disclosure" above.

## Iterative development

The most reliable way to write a skill:

1. **Do the task without a skill** with one Claude session. Notice what context you keep providing.
2. **Identify the reusable pattern** — what would be useful for similar future tasks?
3. **Ask Claude to draft the skill** capturing that pattern. Claude knows the format natively; no special prompt needed.
4. **Review for conciseness** — remove explanations Claude already knows.
5. **Test with a fresh Claude session** loading the skill against a similar task.
6. **Iterate from observed behavior** — if the agent misses something, the skill needs to make it more prominent (stronger language, earlier in the doc, or a checklist).

## Companion skills

- `/zoom-out` if you're writing a skill that wraps an unfamiliar codebase area.
- `/diagnose` if you're writing a skill to capture a debugging recipe.
- `/improve-codebase-architecture` for skills that propose structural changes — borrow that vocabulary.

## Final checklist

Core quality:

- [ ] Description is specific, third-person, includes triggers ("Use when…")
- [ ] SKILL.md body is under 500 lines (under 100 ideal)
- [ ] References are one level deep from SKILL.md
- [ ] Reference files over 100 lines have a TOC
- [ ] No time-sensitive info (or sealed in an "Old patterns" block)
- [ ] Consistent terminology
- [ ] Examples are concrete, not abstract
- [ ] Workflows have copyable checklists where useful
- [ ] No Windows-style paths

Code/scripts (if any):

- [ ] Scripts solve problems rather than punt errors back to Claude
- [ ] No magic numbers — every constant justified
- [ ] Required packages listed and verified available
- [ ] Execution intent ("run this" vs "read this") is explicit

Testing:

- [ ] Tested against at least one realistic scenario in a fresh session
- [ ] Triggers fire correctly (try the keywords from the description)
- [ ] Skill is in `config/claude/skills/<name>/`, not directly in `~/.claude/skills/`
