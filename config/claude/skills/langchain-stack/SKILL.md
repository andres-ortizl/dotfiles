---
name: langchain-stack
description: "Router for LangChain, LangGraph, and Deep Agents skills. Load this ONCE — it tells you which sub-skill file to read for the specific task."
triggers:
  - langchain
  - langgraph
  - deep agents
  - agent framework
  - create agent
  - state graph
---

# LangChain / LangGraph / Deep Agents — Skill Router

Do NOT load all sub-skills. Read ONLY the file(s) relevant to the current task.

## Step 1: Pick framework

If unsure which framework to use, read **framework-selection** first:
→ `~/.skills-library/langchain/framework-selection/SKILL.md` (163 lines)

## Step 2: Load the relevant sub-skill(s)

### LangChain (simple agents, tool calling)

| When | Read |
|---|---|
| Creating agents, defining tools, basic agent loop | `~/.skills-library/langchain/langchain-fundamentals/SKILL.md` (394 lines) |
| Human-in-the-loop approval, custom middleware, structured output | `~/.skills-library/langchain/langchain-middleware/SKILL.md` (388 lines) |
| RAG: document loaders, splitters, embeddings, vector stores | `~/.skills-library/langchain/langchain-rag/SKILL.md` (517 lines) |
| Package versions, installation, dependency management | `~/.skills-library/langchain/langchain-dependencies/SKILL.md` (419 lines) |

### LangGraph (stateful graphs, complex workflows)

| When | Read |
|---|---|
| StateGraph, nodes, edges, Command, Send, streaming | `~/.skills-library/langchain/langgraph-fundamentals/SKILL.md` (811 lines) |
| interrupt(), approval workflows, error handling tiers | `~/.skills-library/langchain/langgraph-human-in-the-loop/SKILL.md` (532 lines) |
| Checkpointers, thread_id, time travel, Store, subgraph persistence | `~/.skills-library/langchain/langgraph-persistence/SKILL.md` (560 lines) |

### Deep Agents (hierarchical agent systems)

| When | Read |
|---|---|
| create_deep_agent(), harness architecture, SKILL.md format | `~/.skills-library/langchain/deep-agents-core/SKILL.md` (423 lines) |
| SubAgentMiddleware, TodoList planning, HITL interrupts | `~/.skills-library/langchain/deep-agents-orchestration/SKILL.md` (471 lines) |
| StateBackend, StoreBackend, FilesystemMiddleware, CompositeBackend | `~/.skills-library/langchain/deep-agents-memory/SKILL.md` (301 lines) |

## Rules

- Read the sub-skill file with the Read tool — it contains full API reference and examples
- For multi-concern tasks, read multiple files (e.g. langgraph-fundamentals + langgraph-persistence)
- Never guess APIs from memory — always read the file first
