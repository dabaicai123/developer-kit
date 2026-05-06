---
description: "Scaffold, build, or evaluate an AI agent project. Delegates to agent-development-expert for implementation, crewai-development-expert for CrewAI systems, or llamaindex-rag-expert for RAG pipelines."
argument-hint: "<agent task description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
---

# Agent Development Command

Build, scaffold, or evaluate an AI agent system following production-grade patterns.

## Workflow

### 1. Determine Agent Type

Identify which agent architecture fits the task:

| Signal | Agent Type | Delegate To |
|--------|-----------|-------------|
| Single agent with tools | General-purpose agent | `agent-development-expert` |
| Role-based multi-agent team | CrewAI Crew + Flow | `crewai-development-expert` |
| Document retrieval / RAG pipeline | LlamaIndex Workflow | `llamaindex-rag-expert` |
| State machine with conditional branching | LangGraph graph | `agent-development-expert` |
| Monitoring / scheduled task | Heartbeat agent | `agent-development-expert` |

### 2. Design Checklist

Before implementation, define:

- **Task scope** — inputs, actions, outputs
- **Success criteria** — measurable outcomes, not vague goals
- **Tool selection** — 3-8 tools max, strict JSON schemas
- **Loop pattern** — ReAct (default), Plan+Execute, Reflection, etc.
- **Memory strategy** — which layers (working, summary, artifact, long-term)
- **Guardrails** — policy-as-code, approval gates, spend limits
- **Evaluation set** — 50+ test cases covering happy path, edge cases, adversarial inputs

### 3. Build Order

1. Tool contracts + Pydantic validation
2. Agent loop / workflow orchestration
3. Tracing (OpenTelemetry spans)
4. Small eval dataset (20-50 realistic cases)
5. Policy gating + approval UX
6. Memory layers (summary + artifacts first)

### 4. Production Checklist

- Structured logging with trace IDs
- Cost monitoring dashboard with alert thresholds
- Error alerting with on-call routing
- Performance baseline against golden eval dataset
- System prompt version-controlled and pinned
- Output validation layer
- Guardrails for PII and content policy
- Human-in-the-loop for low-confidence outputs
- Hard limits: max step count (10-20), max cost per session ($1-5)

## Skills Integration

| Step | Skill |
|------|-------|
| Agent loop architecture | `agent-loop-patterns` |
| Memory design | `agent-memory-systems` |
| Tool contracts | `agent-tool-design` |
| Prompt assembly | `agent-prompt-engineering` |
| Observability | `agent-observability` |
| Evaluation | `agent-evaluation` |
| Safety guardrails | `agent-guardrails` |
| Multi-agent patterns | `multi-agent-orchestration` |
| Context management | `agent-context-management` |
| MCP integration | `mcp-integration` |
| CrewAI patterns | `crewai-patterns` |
| LlamaIndex RAG | `llamaindex-rag-patterns` |
| LangGraph patterns | `langgraph-patterns` |