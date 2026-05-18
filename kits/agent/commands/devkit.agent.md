---
description: "Build, scaffold, review, or harden an AI agent project. Routes general agents to devkit:agent:core, CrewAI systems to devkit:agent:crewai, and RAG or document pipelines to devkit:agent:rag."
argument-hint: "<agent task description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
---

# Agent Development Command

Use this command for agent systems, LangGraph workflows, CrewAI scaffolds, RAG pipelines, guardrails, evaluation, memory, and production hardening.

## Routing

| Task signal | Primary agent | Required skills |
|---|---|---|
| New LangGraph Python project or graph agent scaffold | `devkit:agent:core` | `langgraph-python-template` |
| General agent design, LangGraph workflow, memory, guardrails, prompt architecture | `devkit:agent:core` | `agent-prompt-engineering`, `langgraph-persistence`, `mem0` |
| New CrewAI project scaffold, Crew, Flow, YAML config, role-based team, CrewAI project structure | `devkit:agent:crewai` | `crewai-python-template` |
| RAG, ingestion, indexing, retrieval, document QA, LlamaIndex Workflow or AgentWorkflow | `devkit:agent:rag` | `llamaindex-rag-patterns`, `agent-evaluation` |

If a task spans categories, choose the agent that owns the runtime framework and load only the additional skills needed for the missing concern.

## Required Workflow

1. Define the user-visible success criteria and non-goals.
2. Select the framework or runtime pattern and state why it fits.
3. Define state, memory, guardrails, cost controls, and eval gates before implementation.
4. Implement the smallest production-capable path.
5. Verify with tests, eval cases, trace checks, or a documented manual run.

## Design Gates

- Memory and context management are separate decisions.
- Guardrails are enforceable in code or policy, not only prompt text.
- Production paths define model route, cost limits, and guardrail decisions.
- Eval gates include normal, edge, adversarial, and failure cases.

## Skill Map

| Concern | Skill |
|---|---|
| LangGraph Python scaffold | `langgraph-python-template` |
| CrewAI Python scaffold | `crewai-python-template` |
| Prompt design | `agent-prompt-engineering` |
| CrewAI agent design and context window | `design-agent` |
| LangGraph persistence and memory | `langgraph-persistence` |
| Durable memory | `mem0` |
| Guardrails and approvals | `agent-guardrails` |
| Human interaction | `agent-human-interaction` |
| Evaluation | `agent-evaluation` |
| Testing and debugging | `agent-testing-debugging` |
| Cost controls | `agent-cost-optimization` |
| Error recovery | `agent-error-recovery` |
| LlamaIndex RAG | `llamaindex-rag-patterns` |

## Completion Checklist

- The selected agent and skills exist in `kits/agent`.
- New CrewAI or LangGraph projects use the official scaffold skill unless an existing codebase requires surgical adoption.
- The implementation names explicit framework versions or uses current official docs when exact API compatibility matters.
- The design has no unresolved ownership conflicts between skills.
- Tests, evals, or manual verification cover the stated success criteria.
