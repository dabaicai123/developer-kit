---
name: agent-evaluation
description: "Builds agent evaluation systems: golden datasets, trajectory checks, rubric judges, regression gates, reliability metrics, and production monitoring. Use when measuring agent quality or release readiness."
version: "1.2.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Evaluation

Use this skill to decide whether an agent is good enough to ship or whether a change regressed behavior.

## Scope Boundary

- Use `agent-evaluation` for benchmarks, rubrics, scorecards, and release gates.
- Use `agent-testing-debugging` for diagnosing a specific failed run.
- Use `agent-observability` for production traces and metrics feeding evals.

## Required Decisions

1. Define task-level success criteria before selecting metrics.
2. Build a golden set with normal, edge, adversarial, and policy-sensitive cases.
3. Decide which artifacts are graded: final answer, tool trajectory, citations, latency, and cost.
4. Use deterministic checks before LLM judges.
5. Set pass, warn, and fail thresholds for release gates.

## Metric Map

| Quality area | Metric |
|---|---|
| Task success | Exact match, rubric score, or human acceptance. |
| Grounding | Citation validity, retrieval hit rate, contradiction rate. |
| Tool use | Correct tool, valid args, idempotency, unnecessary call count. |
| Safety | Policy violation rate, prompt-injection resistance, PII leakage. |
| Reliability | Pass rate over repeated runs, timeout rate, retry rate. |
| Operations | Latency, cost, token usage, cache hit rate. |

## Evaluation Workflow

1. Freeze the prompt, tool schemas, model route, and dependency versions for the run.
2. Run deterministic validators for schema, citations, and required fields.
3. Run rubric or pairwise judges only for subjective quality.
4. Compare against the previous accepted baseline.
5. Save inputs, outputs, traces, scores, and grader versions together.
6. Block release when critical safety, correctness, or regression thresholds fail.

## Output Checklist

- Dataset source and case categories are listed.
- Metrics map to success criteria.
- Judge prompts or rubrics are versioned.
- Baseline comparison is present.
- Release gate thresholds are numeric.

## Anti-Patterns

- Using only happy-path examples.
- Letting an LLM judge replace deterministic validation.
- Changing prompts or model routes during an eval run.
- Reporting averages without critical failure counts.
