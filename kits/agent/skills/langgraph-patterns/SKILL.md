---
name: langgraph-patterns
description: "Applies LangGraph patterns: StateGraph, nodes, conditional routing, ToolNode, interrupts, checkpointers, memory, subgraphs, and multi-agent graphs. Use when building stateful graph agents, LangGraph workflows, or checkpointed agent flows."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LangGraph Patterns

Use this skill for stateful graph-based agents and workflows built with LangGraph.

## Scope Boundary

- Use `langgraph-patterns` for LangGraph StateGraph, nodes, routing, persistence, interrupts, and graph agents.
- Use `agent-loop-patterns` for framework-neutral loop selection.
- Use `multi-agent-orchestration` for framework-neutral agent topology.

## Current Compatibility Rules

- Follow the current LangGraph docs for package imports and prebuilt agents; avoid pinning old import paths in skill text.
- Model graph state as a typed schema.
- Keep node functions small and deterministic except for explicit model or tool nodes.
- Use checkpointers for persistence, resume, and human-in-the-loop workflows.
- Use interrupts for human approval or clarification instead of ad hoc blocking calls.

## Graph Design

| Element | Rule |
|---|---|
| State | TypedDict, Pydantic model, or current supported schema. |
| Node | Reads state and returns a partial state update. |
| Edge | Static transition for fixed order. |
| Conditional edge | Router function for branching. |
| Tool node | Tool execution with typed tool definitions. |
| Checkpointer | Required for resume, interrupts, and durable workflows. |
| Subgraph | Use for reusable or isolated workflow segments. |

## Implementation Rules

- Define state before nodes.
- Keep route labels finite and documented.
- Validate tool inputs before the ToolNode executes external side effects.
- Put long-running or approval-required work behind checkpoints.
- Add graph-level tests for state transitions and route decisions.
- Record graph version with traces and eval results.

## Output Checklist

- State schema and reducers are specified.
- Nodes and route labels are listed.
- Persistence/checkpointer decision is stated.
- Interrupt points are defined when humans participate.
- Graph tests cover normal, edge, and failure routes.

## Anti-Patterns

- Storing hidden mutable state outside the graph state.
- Returning free-form route names that are not mapped to nodes.
- Using a graph when a linear loop is sufficient.
- Running approval steps without checkpoint support.
