---
name: agent-project-architecture
description: "Defines production project structure for agent systems: packages, config, prompts, tools, workflows, evals, observability, and deployment. Use when scaffolding or restructuring agents."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Project Architecture

Use this skill to create a maintainable repository layout for agent systems. It owns general structure; framework-specific details stay in framework skills.

## Scope Boundary

- Use `agent-project-architecture` for framework-neutral layout and production boundaries.
- Use `crewai-patterns`, `langgraph-patterns`, `llamaindex-rag-patterns`, or `openai-agents-pydantic-ai` for framework code shapes.
- Use `agent-testing-debugging` and `agent-evaluation` for test and eval implementation.

## Standard Layout

```text
agent-app/
  src/agent_app/
    config/          # environment config, model routes, limits
    prompts/         # versioned system prompts and templates
    tools/           # tool contracts, adapters, validators
    workflows/       # loops, graphs, flows, orchestration
    memory/          # stores, retrieval, retention policy
    guardrails/      # policy checks and approval gates
    observability/   # tracing, logging, metrics
    models/          # Pydantic or typed schemas
    main.py          # CLI/API entry point
  tests/
    unit/
    integration/
    evals/
  evals/             # datasets, rubrics, baselines
  docs/              # operator and architecture notes
```

## Architecture Rules

- Keep prompts, tool schemas, model routing, and workflow logic separately versioned.
- Treat tools as adapters with typed inputs and outputs; keep business logic outside prompts.
- Store environment-specific model names, keys, budgets, and endpoints in config.
- Put eval datasets and baselines under version control unless data policy forbids it.
- Add observability from the first production path, not after incidents.
- Use framework scaffolds when they are current and compatible with the target stack.

## Framework Notes

| Framework | Project rule |
|---|---|
| CrewAI | Keep YAML config and Python orchestration separated; use Flows for stateful production workflows. |
| LangGraph | Put state schema, nodes, routers, and checkpointers in separate modules. |
| LlamaIndex | Separate ingestion, indexing, query engines, agents, and evaluation. |
| OpenAI Agents SDK | Separate agents, tools, handoffs, guardrails, tracing, and run entry points. |
| PydanticAI | Keep agents, dependency types, tools, outputs, and evals explicit. |

## Output Checklist

- Directory layout is shown.
- Config, prompts, tools, workflows, guardrails, evals, and observability have owners.
- Framework-specific conventions are referenced, not duplicated.
- Deployment entry point and environment config are defined.
- Secrets and generated artifacts are excluded from source control.

## Anti-Patterns

- Hardcoding model names and keys inside workflow code.
- Mixing prompt text, tool execution, and persistence in one file.
- Creating framework-specific architecture skills when one framework skill already owns the detail.
- Shipping without eval and trace directories.
