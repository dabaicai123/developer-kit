---
name: agent-context-management
description: "Defines context-window budgets, compaction triggers, summarization, retrieval reinjection, and sub-agent context isolation. Use when building long-running agents, context compression, prompt budgets, or conversation state handling."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Context Management

Use this skill to keep an agent's active context small, current, and recoverable. It owns in-session context policy, not durable memory storage.

## Scope Boundary

- Use `agent-context-management` for active prompt windows, summaries, compaction, and reinjection.
- Use `agent-memory-systems` for cross-session memory, vector stores, profiles, and episodic records.
- Use `agent-prompt-engineering` for prompt assembly order and instruction hierarchy.

## Required Decisions

1. Set a hard context budget before implementation.
2. Reserve fixed space for system instructions, tool schemas, current task state, and final response.
3. Choose one compression trigger: token threshold, step count, tool-result size, or semantic drift.
4. Define what is never compressed: active user constraints, open blockers, safety decisions, and file paths being edited.
5. Define how compressed facts are reintroduced: summary block, retrieved snippets, or task ledger.

## Patterns

| Pattern | Use when | Rule |
|---|---|---|
| Rolling summary | Chat or iterative work exceeds the budget | Rewrite the summary after each major state change. |
| Sliding window | Recent turns dominate relevance | Keep the latest turns verbatim and summarize older turns. |
| Semantic retrieval | Many old facts may become relevant later | Store chunks with stable IDs and cite retrieved IDs. |
| Entity ledger | Users, systems, files, or accounts recur | Maintain one canonical record per entity. |
| Artifact ledger | Work produces files or decisions | Track path, owner, status, and next action. |
| Sub-agent isolation | Delegated work needs less context | Send only the objective, constraints, owned files, and expected output. |

## Implementation Rules

- Compress before the model is forced to drop context; a 70 percent budget threshold is the default trigger.
- Preserve source links, file paths, command outputs, and exact user requirements verbatim when they may affect correctness.
- Replace large tool outputs with summaries plus the command that produced them.
- Keep summaries factual and dated; do not include speculation as fact.
- Record unresolved questions separately from completed decisions.

## Output Checklist

- Context budget and trigger are stated.
- Non-compressible facts are listed.
- Compression format is defined.
- Retrieval or reinjection path is defined.
- Failure mode is defined for missing or stale context.

## Anti-Patterns

- Summarizing away user constraints, approvals, or safety decisions.
- Keeping full logs in the prompt when a ledger would answer the same question.
- Mixing cross-session memory policy into context-window compression.
- Delegating with a full transcript when a scoped packet is enough.
