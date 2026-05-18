---
name: multi-agent-orchestration
description: "Designs multi-agent coordination with supervisor, swarm, hierarchy, pipeline, parallel fan-out/fan-in, handoffs, and shared state. Use when one agent is insufficient."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Multi-Agent Orchestration

Use this skill only when multiple agents materially improve capability, isolation, throughput, or reliability.

## Scope Boundary

- Use `multi-agent-orchestration` for framework-neutral topology, handoffs, and coordination policy.
- Use `crewai-python-template` for CrewAI scaffold generation and `langgraph-patterns` for LangGraph-specific multi-agent implementation.
- Use `agent-context-management` for delegation packets and sub-agent context isolation.

## Pattern Selection

| Pattern | Use when |
|---|---|
| Supervisor | One coordinator assigns work and validates outputs. |
| Hierarchy | Work naturally decomposes into managers and specialists. |
| Pipeline | Output of one specialist becomes input to the next. |
| Parallel fan-out/fan-in | Independent subtasks can run concurrently. |
| Swarm | Agents share state and choose next actor dynamically. |
| Debate/review | Independent critique improves high-stakes decisions. |

## Implementation Rules

- Start with one agent unless a concrete bottleneck requires more.
- Give each agent a bounded role, owned tools, and output contract.
- Define handoff payloads: objective, context, constraints, artifacts, and expected return.
- Use a shared state store or message log; do not rely on hidden conversation context.
- Assign final accountability to one coordinator or deterministic reducer.
- Add loop, cost, and failure limits per agent and for the whole system.

## Handoff Contract

```yaml
from: agent-id
to: agent-id
objective: concrete subtask
context: minimal facts required
owned_artifacts: paths or IDs
constraints: limits and policies
expected_output: schema or checklist
deadline: step, time, or budget limit
```

## Output Checklist

- Reason for multiple agents is stated.
- Topology and final decision owner are named.
- Agent roles and owned tools are non-overlapping.
- Handoff contract is defined.
- Failure and timeout behavior are specified.

## Anti-Patterns

- Creating agents for job titles rather than separable work.
- Letting agents edit the same files or external records without ownership.
- Circular handoffs with no stop condition.
- Using debate to mask missing evidence or unclear criteria.
