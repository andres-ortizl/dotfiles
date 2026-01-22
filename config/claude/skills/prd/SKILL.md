---
name: prd
description: "Generate a Product Requirements Document (PRD) for ralph-tui task orchestration. Creates PRDs with u
ser stories that can be converted to beads issues or prd.json for automated execution. Triggers on: create a prd,
write prd for, plan this feature, requirements for, spec out."
---

# Ralph TUI PRD Generator

Create detailed Product Requirements Documents optimized for AI agent execution via ralph-tui.

---

## The Job

1. Receive a feature description from the user
2. Ask 3-5 essential clarifying questions (with lettered options) - one set at a time
3. **Always ask about quality gates** (what commands must pass)
4. After each answer, ask follow-up questions if needed (adaptive exploration)
5. Generate a structured PRD when you have enough context
6. Output the PRD wrapped in `[PRD]...[/PRD]` markers for TUI parsing

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 1: Clarifying Questions (Iterative)

Ask questions one set at a time. Each answer should inform your next questions. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?
- **Integration:** How does it fit with existing features?
- **Quality Gates:** What commands must pass for each story? (REQUIRED)

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only
```

This lets users respond with "1A, 2C" for quick iteration.

### Quality Gates Question (REQUIRED)
