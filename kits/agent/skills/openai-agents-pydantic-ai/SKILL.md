---
name: openai-agents-pydantic-ai
description: "Applies OpenAI Agents SDK and PydanticAI patterns: agents, tools, handoffs, guardrails, structured output, dependencies, streaming, and tracing. Use with these Python agent frameworks."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# OpenAI Agents SDK and PydanticAI

Use this skill for Python agents built with the OpenAI Agents SDK or PydanticAI. Keep framework details separated because their abstractions differ.

## Scope Boundary

- Use this skill for OpenAI Agents SDK and PydanticAI implementation patterns.
- Use `agent-tool-design` for framework-neutral tool contracts.
- Use `agent-guardrails`, `agent-observability`, and `agent-evaluation` for production controls.

## Current Compatibility Rules

- Follow current official docs for imports and exact APIs.
- OpenAI Agents SDK centers on agents, tools, handoffs, guardrails, tracing, and runs.
- PydanticAI centers on typed agents, dependencies, tools, structured output, and evaluation-friendly design.
- Prefer structured outputs and typed dependencies over free-form prompt conventions.

## OpenAI Agents SDK Rules

- Define clear agent instructions and tool sets.
- Use handoffs for specialist transfer when the next agent owns a distinct task.
- Use guardrails for input or output validation around runs.
- Enable tracing for tool calls, handoffs, and model calls in production paths.
- Keep tool schemas strict and return typed, compact results.

## PydanticAI Rules

- Define dependency types explicitly and pass runtime services through dependencies.
- Use typed outputs for downstream code.
- Keep tools small and validated with Pydantic models.
- Separate agent definition from application orchestration.
- Use evals or tests around structured outputs and tool trajectories.

## Framework Choice

| Need | Prefer |
|---|---|
| Handoffs, guardrails, tracing with OpenAI stack | OpenAI Agents SDK. |
| Pythonic typed dependencies and Pydantic-first outputs | PydanticAI. |
| Graph persistence and interrupts | LangGraph. |
| Document RAG pipeline | LlamaIndex. |
| Role-based teams and Flows | CrewAI. |

## Output Checklist

- Framework choice is justified.
- Agent instructions, tools, and output schema are explicit.
- Handoff or dependency model is defined.
- Guardrails and tracing are included for production.
- Tests or evals cover structured output and tool behavior.

## Anti-Patterns

- Mixing SDK abstractions in one thin wrapper without a reason.
- Returning untyped text when callers require structured data.
- Treating handoffs as ordinary conversation without ownership transfer.
- Shipping without tracing for tool and guardrail decisions.
