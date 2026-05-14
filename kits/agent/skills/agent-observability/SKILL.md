---
name: agent-observability
description: "Instruments agent systems with traces, metrics, logs, cost telemetry, evaluation links, and alerting. Use when debugging or operating production agents."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Observability

Use this skill to make agent behavior explainable from evidence after the run. Prefer OpenTelemetry-compatible traces when the stack supports them.

## Scope Boundary

- Use `agent-observability` for traces, logs, metrics, dashboards, and alerts.
- Use `agent-evaluation` for offline and release-quality scoring.
- Use `agent-error-recovery` for runtime response to failures.

## Required Signals

| Signal | Fields |
|---|---|
| Trace | trace ID, session ID, step ID, parent step, model route. |
| Model call | model, prompt version, token counts, latency, cost, finish reason. |
| Tool call | tool name, schema version, args hash, status, latency, side-effect flag. |
| Retrieval | query, store, document IDs, scores, filters, citations. |
| Guardrail | policy version, decision, reason, approval actor. |
| Error | class, retry count, recovery path, user-visible outcome. |

## Implementation Rules

- Redact secrets and sensitive payloads before logs leave the process.
- Correlate final answers to the model calls, retrieved evidence, and tool calls that produced them.
- Keep high-cardinality payloads in trace details, not metric labels.
- Sample successful low-risk traces only after baseline visibility exists.
- Link production failures back to eval cases when possible.

## Alert Defaults

- Error rate above baseline.
- Cost per session above budget.
- Latency above SLO.
- Tool retry spike.
- Guardrail block spike.
- Eval score regression after deploy.

## Output Checklist

- Trace schema is defined.
- Metrics and alert thresholds are listed.
- Redaction policy is included.
- Dashboard views map to operators' questions.
- Production traces can reproduce or explain a failed run.

## Anti-Patterns

- Logging only final outputs.
- Recording full prompts with secrets or private data.
- Using averages without p95 or failure counts.
- Separating eval results from production traces.
