---
name: agent-cost-optimization
description: "Controls agent cost through token budgets, model routing, caching, batching, evaluation-based routing, and spend alerts. Use when reducing LLM spend, setting model tiers, or adding budget gates."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Cost Optimization

Use this skill to reduce agent operating cost without hiding quality regressions. It owns budget policy and cost measurement.

## Scope Boundary

- Use `agent-cost-optimization` for spend limits, routing, caching, and cost telemetry.
- Use `agent-evaluation` to prove cheaper routes keep acceptable quality.
- Use framework-specific runtime context controls to reduce prompt size safely.

## Required Decisions

1. Define the unit of cost: request, session, workflow, tenant, or month.
2. Set hard and soft budget limits with owner-approved override rules.
3. Route models by task class, risk, context size, and required output quality.
4. Decide what can be cached and for how long.
5. Emit metrics for input tokens, output tokens, tool calls, retries, cache hit rate, and cost.

## Routing Matrix

| Work type | Default route | Escalate when |
|---|---|---|
| Extraction and formatting | Small fast model | Validation fails or schema confidence is low. |
| Tool planning | Mid-tier model | Tool choice affects money, data deletion, or security. |
| Final synthesis | Mid-tier model | Source conflict, legal risk, or high business impact. |
| Safety decisions | Strong policy-capable model plus rules | User asks for restricted or ambiguous action. |
| Embeddings and retrieval | Dedicated embedding/rerank model | Recall or precision eval drops below target. |

## Implementation Rules

- Price-based routing must be backed by an eval set, not preference.
- Cache deterministic prompts, retrieval results, and tool metadata; do not cache private user data unless policy allows it.
- Cap retry count and retry only after classifying the failure.
- Collapse repeated tool schemas with progressive disclosure when the platform supports it.
- Alert on budget burn rate, route drift, retry spikes, and cache hit-rate collapse.

## Output Checklist

- Cost budget is numeric and scoped.
- Routing policy lists inputs, target model class, and escalation rules.
- Cache policy lists keys, TTL, privacy constraints, and invalidation.
- Metrics and alert thresholds are defined.
- Eval gate protects quality before cheaper routing ships.

## Anti-Patterns

- Picking a cheaper model without an eval comparison.
- Retrying blindly after tool or validation failures.
- Optimizing prompt size by removing safety, task, or output constraints.
- Reporting aggregate spend without trace-level attribution.
