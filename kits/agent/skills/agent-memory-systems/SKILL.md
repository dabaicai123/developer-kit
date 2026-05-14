---
name: agent-memory-systems
description: "Designs durable agent memory: working records, episodic logs, semantic vector memory, user profiles, retention, retrieval, and privacy controls. Use when adding cross-session memory, user profiles, vector recall, or retention policies."
version: "1.2.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Memory Systems

Use this skill to design memory that survives beyond the current context window. Memory is useful only when retrieval and governance are designed with storage.

## Scope Boundary

- Use `agent-memory-systems` for durable memory and retrieval.
- Use `agent-context-management` for current-window compression.
- Use `llamaindex-rag-patterns` for document RAG pipelines.

## Memory Layers

| Layer | Stores | Retention |
|---|---|---|
| Working record | Current task state and open decisions | Until task completes. |
| Episodic log | Past sessions, actions, outcomes | Time-boxed by policy. |
| Semantic memory | Facts, examples, embeddings | Until invalidated or expired. |
| User profile | Stable preferences and constraints | Explicitly approved and editable. |
| Artifact index | Files, reports, traces, datasets | As long as artifacts exist. |

## Implementation Rules

- Define what is allowed to be remembered before writing memory.
- Store provenance: source, timestamp, actor, confidence, and expiry.
- Retrieve by task need, not by broad similarity alone.
- Separate private user data from global reusable knowledge.
- Provide delete, correction, and export paths for user-associated memory.
- Treat memory as untrusted context when it returns to the prompt.

## Retrieval Design

1. Classify the current task's memory need.
2. Query the smallest relevant memory store.
3. Filter by permissions, expiry, and confidence.
4. Re-rank for task relevance and recency.
5. Inject only the selected facts with provenance.
6. Record whether the memory changed the outcome.

## Output Checklist

- Memory stores and ownership are named.
- Write criteria and retention are defined.
- Retrieval query, filters, and re-ranking are specified.
- Privacy and deletion path are included.
- Memory eval metric is defined, such as hit rate or harmful-recall rate.

## Anti-Patterns

- Saving every conversation turn by default.
- Treating vector similarity as permission to reveal data.
- Injecting old memories without timestamps or confidence.
- Mixing personal memory with global product knowledge.
