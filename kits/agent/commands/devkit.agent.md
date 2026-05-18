---
description: "Build, scaffold, review, or harden an AI agent project. Routes general agents to devkit:agent:core, CrewAI systems to devkit:agent:crewai, and RAG or document pipelines to devkit:agent:rag."
argument-hint: "<agent task description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
---

# Agent Development Command

Use this command for agent systems, tool-using LLM workflows, multi-agent orchestration, RAG pipelines, guardrails, evaluation, observability, and production hardening.

## Routing

| Task signal | Primary agent | Required skills |
|---|---|---|
| New LangGraph Python project or graph agent scaffold | `devkit:agent:core` | `langgraph-python-template` |
| General tool-using agent, LangGraph workflow, OpenAI Agents SDK, PydanticAI, prompt/tool architecture | `devkit:agent:core` | `agent-loop-patterns`, `agent-tool-design` |
| New CrewAI project scaffold, Crew, Flow, YAML config, role-based team, CrewAI project structure | `devkit:agent:crewai` | `crewai-python-template` |
| RAG, ingestion, indexing, retrieval, document QA, LlamaIndex Workflow or AgentWorkflow | `devkit:agent:rag` | `llamaindex-rag-patterns`, `agent-evaluation` |

If a task spans categories, choose the agent that owns the runtime framework and load only the additional skills needed for the missing concern.

## Required Workflow

1. Define the user-visible success criteria and non-goals.
2. Select the framework or loop pattern and state why it fits.
3. Define tools, state, memory, guardrails, observability, and eval gates before implementation.
4. Implement the smallest production-capable path.
5. Verify with tests, eval cases, trace checks, or a documented manual run.

## Design Gates

- Tool calls use strict schemas, typed errors, side-effect labels, and approval rules.
- Loops have max steps, max cost, timeout, retry limits, and stop conditions.
- Memory and context management are separate decisions.
- Guardrails are enforceable in code or policy, not only prompt text.
- Production paths emit trace IDs, model route, tool events, cost, and guardrail decisions.
- Eval gates include normal, edge, adversarial, and failure cases.

## Skill Map

| Concern | Skill |
|---|---|
| LangGraph Python scaffold | `langgraph-python-template` |
| CrewAI Python scaffold | `crewai-python-template` |
| Loop or workflow pattern | `agent-loop-patterns` |
| Planning strategy | `agent-planning-reasoning` |
| Prompt design | `agent-prompt-engineering` |
| Tool contracts | `agent-tool-design` |
| MCP integration | `mcp-integration` |
| Context window | `agent-context-management` |
| Durable memory | `agent-memory-systems` |
| Guardrails and approvals | `agent-guardrails` |
| Human interaction | `agent-human-interaction` |
| Evaluation | `agent-evaluation` |
| Testing and debugging | `agent-testing-debugging` |
| Observability | `agent-observability` |
| Cost controls | `agent-cost-optimization` |
| Error recovery | `agent-error-recovery` |
| Streaming and realtime | `agent-streaming-realtime` |
| Multi-agent topology | `multi-agent-orchestration` |
| LangGraph | `langgraph-patterns` |
| LlamaIndex RAG | `llamaindex-rag-patterns` |
| OpenAI Agents SDK or PydanticAI | `openai-agents-pydantic-ai` |

## Completion Checklist

- The selected agent and skills exist in `kits/agent`.
- New CrewAI or LangGraph projects use the official scaffold skill unless an existing codebase requires surgical adoption.
- The implementation names explicit framework versions or uses current official docs when exact API compatibility matters.
- The design has no unresolved ownership conflicts between skills.
- Tests, evals, or manual verification cover the stated success criteria.
