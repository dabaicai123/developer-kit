---
description: "Build, scaffold, review, or harden an AI agent project. Routes LangGraph systems to devkit:agent:langgraph and CrewAI systems to devkit:agent:crewai, with RAG handled inside the selected framework agent."
argument-hint: "<agent task description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
---

# Agent Development Command

Use this command for LangGraph workflows, CrewAI scaffolds, RAG pipelines, context engineering, human approval, evaluation, memory, and production hardening.

## Routing

| Task signal | Primary agent | Required skills |
|---|---|---|
| Production Python agent service, FastAPI wrapper, deployment hardening | `devkit:agent:langgraph` | `agentic-ai-dev` |
| New LangGraph Python project or graph scaffold | `devkit:agent:langgraph` | `langgraph-python-template`, `langgraph-fundamentals` |
| LangGraph graph code, state, streaming, routing, errors | `devkit:agent:langgraph` | `langgraph-fundamentals` |
| LangGraph persistence, memory, time travel, checkpointers | `devkit:agent:langgraph` | `langgraph-persistence` |
| LangGraph human approval or interrupts | `devkit:agent:langgraph` | `langgraph-human-in-the-loop` |
| LangGraph RAG, document QA, retrieval graph, LlamaIndex query engines | `devkit:agent:langgraph` | `llamaindex-rag-patterns`, `langgraph-fundamentals` |
| General agent architecture, context management, tool design | `devkit:agent:langgraph` | `agent-context-engineering` |
| Prompt improvement or prompt architecture | `devkit:agent:langgraph` | `agent-prompt-engineering` |
| Python LLM app evals, QA, benchmarks, quality gates | `devkit:agent:langgraph` | `eval-driven-dev`, `agentic-eval` |
| New CrewAI project scaffold, Crew, Flow, YAML config, role-based team, CrewAI project structure | `devkit:agent:crewai` | `getting-started`, `crewai-python-template` |
| CrewAI agent or task design | `devkit:agent:crewai` | `design-agent`, `design-task` |
| CrewAI RAG, document QA task, retrieval inside Flow or Crew | `devkit:agent:crewai` | `llamaindex-rag-patterns`, `design-task` |

If a task spans categories, choose the agent that owns the runtime framework and load only the additional skills needed for the missing concern. If no framework is named, use `devkit:agent:langgraph` for explicit graph/state/control needs and `devkit:agent:crewai` for role/task/team-oriented systems.

## Required Workflow

1. Define the user-visible success criteria and non-goals.
2. Select the framework or runtime pattern and state why it fits.
3. Define state, memory, approval rules, cost controls, and eval gates before implementation.
4. Implement the smallest production-capable path.
5. Verify with tests, eval cases, trace checks, or a documented manual run.

## Design Gates

- Memory and context management are separate decisions.
- Approval, validation, and refusal rules are enforceable in code or policy, not only prompt text.
- Production paths define model route, cost limits, approval rules, refusal behavior, and eval gates.
- Eval gates include normal, edge, adversarial, and failure cases.

## Skill Map

| Concern | Skill |
|---|---|
| Production Python agent service patterns | `agentic-ai-dev` |
| Agent architecture and context engineering | `agent-context-engineering` |
| LangGraph agent and workflow owner | `devkit:agent:langgraph` |
| LangGraph Python scaffold | `langgraph-python-template` |
| LangGraph graph implementation | `langgraph-fundamentals` |
| LangGraph human-in-the-loop | `langgraph-human-in-the-loop` |
| CrewAI agent and workflow owner | `devkit:agent:crewai` |
| CrewAI Python scaffold | `crewai-python-template` |
| CrewAI architecture and project setup | `getting-started` |
| Prompt design | `agent-prompt-engineering` |
| CrewAI agent design and context window | `design-agent` |
| CrewAI task design and structured output | `design-task` |
| LangGraph persistence and memory | `langgraph-persistence` |
| Durable memory | `mem0` |
| Agentic self-evaluation and refinement | `agentic-eval` |
| Python LLM app eval-driven development | `eval-driven-dev` |
| LlamaIndex RAG | `llamaindex-rag-patterns` |

## Completion Checklist

- The selected agent and skills exist in `kits/agent`.
- New CrewAI or LangGraph projects use the official scaffold skill unless an existing codebase requires surgical adoption.
- The implementation names explicit framework versions or uses current official docs when exact API compatibility matters.
- The design has no unresolved ownership conflicts between skills.
- Tests, evals, or manual verification cover the stated success criteria.
