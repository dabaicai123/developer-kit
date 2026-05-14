---
name: agent-planning-reasoning
description: "Selects planning and reasoning strategies for complex agents: task decomposition, plan validation, search, constraints, temporal reasoning, and replanning. Use for multi-step decisions."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Planning Reasoning

Use this skill when an agent must choose among multiple paths, maintain constraints, or validate a plan before acting.

## Scope Boundary

- Use `agent-planning-reasoning` for decomposition, search, constraints, and replanning.
- Use `agent-loop-patterns` for the execution loop that runs the plan.
- Use `agent-evaluation` to score planning quality.

## Strategy Selection

| Strategy | Use when | Risk |
|---|---|---|
| Checklist plan | Steps are known and mostly linear | Low. |
| Hierarchical task network | Work has nested subtasks and dependencies | Medium. |
| Candidate plan comparison | Several valid paths exist | Medium. |
| Constraint solver | Hard constraints decide validity | Medium. |
| Tree search | The agent must explore alternatives | High cost. |
| Temporal planning | Dates, deadlines, or ordered events matter | Medium. |

## Implementation Rules

- State assumptions, constraints, dependencies, and stop criteria before executing.
- Validate a plan against tools, permissions, budget, and expected outputs.
- Replan only when a material observation invalidates the current plan.
- Keep plans short enough to execute and verify; split large plans into milestones.
- Record why rejected alternatives were rejected when the decision is high impact.

## Plan Schema

```yaml
goal: concrete outcome
constraints: required limits
assumptions: facts not yet proven
steps:
  - id: step-1
    action: exact action
    owner: agent-or-human
    success: measurable result
    risks: known failure modes
stop: terminal condition
```

## Output Checklist

- Planning strategy is named.
- Assumptions and constraints are explicit.
- Plan steps have success criteria.
- Validation gate runs before side effects.
- Replanning trigger is defined.

## Anti-Patterns

- Producing a long plan with no execution checks.
- Exploring alternatives when the task has one obvious safe path.
- Replanning because of minor wording changes rather than new evidence.
- Hiding assumptions that affect correctness.
