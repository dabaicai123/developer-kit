---
name: crewai-patterns
description: "Applies CrewAI patterns for Crews, Flows, YAML config, tools, memory, planning, human input, MCP, and project layout. Use when building or restructuring CrewAI systems."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# CrewAI Patterns

Use this skill for CrewAI-specific implementation. It now owns CrewAI project architecture as well; do not use a separate CrewAI architecture skill.

## Scope Boundary

- Use `crewai-patterns` for CrewAI Crews, Flows, YAML config, project layout, and framework APIs.
- Use `multi-agent-orchestration` for framework-neutral multi-agent strategy.
- Use `agent-project-architecture` for general repository boundaries.

## Current Compatibility Rules

- Prefer official CrewAI project scaffolding and current docs over hardcoded historical version assumptions.
- Use Crews for role-based task execution.
- Use Flows for stateful, event-driven production orchestration.
- Keep agent and task definitions in YAML or current CrewAI project config patterns when practical.
- Treat MCP and Skills as capabilities; tools perform actions, skills add context.

## Project Layout

```text
crewai-app/
  src/crewai_app/
    config/agents.yaml
    config/tasks.yaml
    crews/          # Crew classes or @CrewBase definitions
    flows/          # Flow classes and typed state
    tools/          # custom BaseTool or @tool implementations
    guardrails/
    memory/
    main.py
  tests/
  evals/
```

## Implementation Rules

- Start production systems with a Flow when state, branching, retries, or auditability matter.
- Use a Crew alone only for simple one-shot task execution.
- Keep role, goal, backstory, task description, and expected output explicit.
- Limit each agent to the smallest useful set of tools.
- Use typed state models for Flow state when available.
- Put retries, routing, and persistence in Flows rather than inside agent backstories.
- Use async kickoff methods only in async application contexts.

## Crew Decision Matrix

| Need | CrewAI construct |
|---|---|
| Ordered specialist work | Sequential Crew. |
| Delegation by manager | Hierarchical Crew with explicit manager. |
| Branching workflow | Flow with routers/listeners. |
| Human approval | Agent human input or Flow approval step. |
| External tool servers | MCP integration plus server-side guardrails. |
| Durable production run | Flow state plus observability. |

## Output Checklist

- Crew vs Flow choice is justified.
- Agent roles, tasks, tools, and expected outputs are explicit.
- YAML/config and Python orchestration are separated.
- Flow state and routing are defined for production workflows.
- Tests and evals cover agent behavior and tool contracts.

## Anti-Patterns

- Using a Crew alone for a stateful production workflow.
- Embedding tool credentials or model routes in YAML definitions.
- Giving one agent many unrelated tools.
- Duplicating CrewAI architecture guidance in another skill.
