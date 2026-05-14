---
name: agent-loop-patterns
description: "Chooses and implements agent execution loops: ReAct, plan-execute, reflection, graph state machines, event-driven workflows, code-as-action, and heartbeat agents. Use when designing orchestration."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Loop Patterns

Use this skill to choose the smallest loop that can complete the task with bounded risk.

## Scope Boundary

- Use `agent-loop-patterns` for runtime control flow and step policy.
- Use `langgraph-patterns` for LangGraph-specific StateGraph implementation.
- Use `multi-agent-orchestration` when multiple agents coordinate.

## Pattern Selection

| Pattern | Use when | Stop condition |
|---|---|---|
| ReAct | Tool use depends on observations | Answer produced or max steps reached. |
| Plan-execute | Work has known ordered steps | Plan complete or replanning fails. |
| Reflect-revise | Output quality benefits from critique | Revision passes validator or max revisions reached. |
| Graph state machine | Branching and persistence are required | Terminal node reached. |
| Event-driven workflow | External events or async work drive progress | Stop event emitted. |
| Code-as-action | Computation is easier in code than text | Code output validates. |
| Heartbeat | Agent monitors or schedules work | Alert, task completion, or operator stop. |

## Implementation Rules

- Set max steps, max wall time, max cost, and max consecutive failures.
- Make each step produce a typed state change or an explicit no-op reason.
- Validate tool arguments before execution and outputs before planning the next step.
- Persist state before irreversible side effects.
- Keep reasoning private when policy requires it; expose decisions, evidence, and next actions.

## Default Loop Contract

1. Read task state and constraints.
2. Select next action from allowed actions.
3. Validate action against guardrails and budget.
4. Execute tool or produce artifact.
5. Record observation and state delta.
6. Stop, continue, replan, or escalate.

## Output Checklist

- Loop pattern and reason are named.
- State schema is defined.
- Stop conditions are numeric or otherwise testable.
- Tool validation and guardrail points are included.
- Recovery path is specified for failed steps.

## Anti-Patterns

- Unbounded loops with no cost or step limit.
- Mixing planning, tool execution, and final answer without state records.
- Using multi-agent orchestration when one loop is enough.
- Replanning after every minor observation without a failure signal.
