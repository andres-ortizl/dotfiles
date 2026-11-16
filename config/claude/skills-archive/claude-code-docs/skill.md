---
name: claude-code-docs
description: Fetch and review official Claude Code documentation before answering questions about Claude Code features, configuration, settings, hooks, MCP, skills, permissions, agents, or any Claude Code capability.
triggers:
  - claude code docs
  - claude code documentation
  - how does claude code
  - claude code config
  - claude code settings
  - claude code hooks
  - claude code mcp
  - claude code skills
  - claude code permissions
  - claude code agents
  - claude code subagents
  - configure claude code
  - set up claude code
  - claude code features
proactive: true
---

# Claude Code Documentation Lookup

When the user asks about Claude Code features, configuration, setup, or capabilities, fetch the relevant official documentation BEFORE answering. Do not rely on training data alone — Claude Code updates frequently.

---

## Step 1: Identify relevant docs

Use the docs map below to identify which page(s) are relevant to the user's question. Pick the 1-3 most relevant pages.

### Docs Map (topic -> URL)

**Core concepts:**
- How Claude Code works: `https://code.claude.com/docs/en/how-claude-code-works.md`
- Features overview: `https://code.claude.com/docs/en/features-overview.md`
- .claude directory: `https://code.claude.com/docs/en/claude-directory.md`
- Context window: `https://code.claude.com/docs/en/context-window.md`

**Memory & instructions:**
- Memory (CLAUDE.md, auto memory, rules): `https://code.claude.com/docs/en/memory.md`

**Permissions & security:**
- Permission modes: `https://code.claude.com/docs/en/permission-modes.md`
- Permissions reference: `https://code.claude.com/docs/en/permissions.md`
- Sandboxing: `https://code.claude.com/docs/en/sandboxing.md`
- Security: `https://code.claude.com/docs/en/security.md`

**Workflows & best practices:**
- Common workflows: `https://code.claude.com/docs/en/common-workflows.md`
- Best practices: `https://code.claude.com/docs/en/best-practices.md`

**Agents:**
- Subagents: `https://code.claude.com/docs/en/sub-agents.md`
- Agent teams: `https://code.claude.com/docs/en/agent-teams.md`

**Tools & plugins:**
- MCP servers: `https://code.claude.com/docs/en/mcp.md`
- Plugins: `https://code.claude.com/docs/en/plugins.md`
- Discover plugins: `https://code.claude.com/docs/en/discover-plugins.md`
- Skills: `https://code.claude.com/docs/en/skills.md`
- Plugin marketplaces: `https://code.claude.com/docs/en/plugin-marketplaces.md`

**Automation:**
- Hooks guide: `https://code.claude.com/docs/en/hooks-guide.md`
- Hooks reference: `https://code.claude.com/docs/en/hooks.md`
- Channels: `https://code.claude.com/docs/en/channels.md`
- Scheduled tasks: `https://code.claude.com/docs/en/scheduled-tasks.md`
- Headless mode: `https://code.claude.com/docs/en/headless.md`

**Configuration:**
- Settings: `https://code.claude.com/docs/en/settings.md`
- Terminal config: `https://code.claude.com/docs/en/terminal-config.md`
- Fullscreen: `https://code.claude.com/docs/en/fullscreen.md`
- Model config: `https://code.claude.com/docs/en/model-config.md`
- Fast mode: `https://code.claude.com/docs/en/fast-mode.md`
- Voice dictation: `https://code.claude.com/docs/en/voice-dictation.md`
- Output styles: `https://code.claude.com/docs/en/output-styles.md`
- Status line: `https://code.claude.com/docs/en/statusline.md`
- Keybindings: `https://code.claude.com/docs/en/keybindings.md`

**Platforms:**
- Platforms overview: `https://code.claude.com/docs/en/platforms.md`
- Claude Code on the web: `https://code.claude.com/docs/en/claude-code-on-the-web.md`
- Web scheduled tasks: `https://code.claude.com/docs/en/web-scheduled-tasks.md`
- Desktop app: `https://code.claude.com/docs/en/desktop.md`
- Remote control: `https://code.claude.com/docs/en/remote-control.md`
- Chrome: `https://code.claude.com/docs/en/chrome.md`
- Computer use: `https://code.claude.com/docs/en/computer-use.md`
- VS Code: `https://code.claude.com/docs/en/vs-code.md`
- JetBrains: `https://code.claude.com/docs/en/jetbrains.md`
- Slack: `https://code.claude.com/docs/en/slack.md`

**CI/CD & code review:**
- Code review: `https://code.claude.com/docs/en/code-review.md`
- GitHub Actions: `https://code.claude.com/docs/en/github-actions.md`
- GitHub Enterprise Server: `https://code.claude.com/docs/en/github-enterprise-server.md`
- GitLab CI/CD: `https://code.claude.com/docs/en/gitlab-ci-cd.md`

**Deployment:**
- Third-party integrations: `https://code.claude.com/docs/en/third-party-integrations.md`
- Amazon Bedrock: `https://code.claude.com/docs/en/amazon-bedrock.md`
- Google Vertex AI: `https://code.claude.com/docs/en/google-vertex-ai.md`
- Microsoft Foundry: `https://code.claude.com/docs/en/microsoft-foundry.md`
- Network config: `https://code.claude.com/docs/en/network-config.md`
- LLM gateway: `https://code.claude.com/docs/en/llm-gateway.md`
- Devcontainer: `https://code.claude.com/docs/en/devcontainer.md`

**Administration:**
- Setup & install: `https://code.claude.com/docs/en/setup.md`
- Authentication: `https://code.claude.com/docs/en/authentication.md`
- Server-managed settings: `https://code.claude.com/docs/en/server-managed-settings.md`
- Data usage: `https://code.claude.com/docs/en/data-usage.md`
- Zero data retention: `https://code.claude.com/docs/en/zero-data-retention.md`
- Monitoring usage: `https://code.claude.com/docs/en/monitoring-usage.md`
- Costs: `https://code.claude.com/docs/en/costs.md`
- Analytics: `https://code.claude.com/docs/en/analytics.md`

**Reference:**
- CLI reference: `https://code.claude.com/docs/en/cli-reference.md`
- Commands: `https://code.claude.com/docs/en/commands.md`
- Environment variables: `https://code.claude.com/docs/en/env-vars.md`
- Tools reference: `https://code.claude.com/docs/en/tools-reference.md`
- Interactive mode: `https://code.claude.com/docs/en/interactive-mode.md`
- Checkpointing: `https://code.claude.com/docs/en/checkpointing.md`
- Plugins reference: `https://code.claude.com/docs/en/plugins-reference.md`
- Channels reference: `https://code.claude.com/docs/en/channels-reference.md`

**Troubleshooting:**
- Troubleshooting: `https://code.claude.com/docs/en/troubleshooting.md`

---

## Step 2: Fetch the relevant page(s)

Use `WebFetch` to fetch the identified page(s). Use a prompt like:

> "Return the complete content of this documentation page. Preserve all headings, code blocks, configuration examples, and important details. Do not summarize."

Fetch up to 3 pages in parallel if multiple are relevant.

---

## Step 3: Answer using the fetched docs

- Base your answer on the **fetched documentation**, not training data
- Quote specific configuration examples, settings, or code blocks from the docs
- If the docs contradict your training data, trust the docs
- If the docs don't cover the user's question, say so and suggest where else to look
- Link to the source page so the user can read more

---

## Rules

- **Always fetch before answering** — even if you think you know the answer. Docs change frequently.
- **Be specific** — show exact config snippets, setting names, file paths from the docs
- **Don't fabricate** — if a feature isn't in the docs, don't invent it
- **Stay concise** — fetch thoroughly, answer briefly
