---
name: agent-error-recovery
description: "Designs resilience for agent systems with typed failures, retries, circuit breakers, fallbacks, compensation, and degraded modes. Use when tools, models, networks, or workflow steps can fail."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Error Recovery

Use this skill to make agent failures explicit, bounded, and recoverable. It owns runtime resilience after a request has started.

## Scope Boundary

- Use `agent-error-recovery` for retries, fallback paths, compensation, and degraded operation.
- Use `agent-testing-debugging` to reproduce and fix failing runs.
- Use `agent-guardrails` for policy blocks and approval gates.

## Failure Taxonomy

| Class | Examples | Recovery |
|---|---|---|
| Validation | Bad JSON, missing fields, schema mismatch | Re-ask with schema diff, then fail closed. |
| Tool transient | Timeout, rate limit, 5xx | Retry with exponential backoff and jitter. |
| Tool permanent | 4xx, missing permission, unsupported action | Stop that path and ask for a valid input or approval. |
| Model quality | Hallucination, low confidence, contradiction | Run verifier, retrieve evidence, or escalate model. |
| Workflow state | Lost checkpoint, duplicate step, partial write | Resume from checkpoint or run compensation. |
| Safety | PII, prompt injection, unsafe action | Hand to `agent-guardrails`; do not retry as ordinary error. |

## Implementation Rules

- Classify errors before retrying.
- Retry only idempotent operations unless a compensation step exists.
- Attach trace ID, step ID, input hash, and failure class to every error event.
- Use circuit breakers for unstable tools and expose a degraded mode when possible.
- Persist checkpoints before side effects and after irreversible external calls.
- Give the user a clear next action when recovery requires human input.

## Recovery Patterns

1. Retry transient failures with capped exponential backoff.
2. Fall back to a read-only or lower-capability path when the main tool is down.
3. Re-plan around unavailable tools if the task can still succeed.
4. Escalate to a human for irreversible, costly, or policy-sensitive actions.
5. Abort with a durable error record when success criteria cannot be met.

## Output Checklist

- Failure classes and retry rules are specified.
- Idempotency and compensation are addressed for side effects.
- Checkpoint and resume points are defined.
- Degraded mode is defined or explicitly unavailable.
- Observability fields are included.

## Anti-Patterns

- Retrying policy blocks, malformed user intent, or permission failures.
- Treating every exception as model failure.
- Continuing after partial external writes without reconciliation.
- Hiding failure details that the operator needs to debug safely.
