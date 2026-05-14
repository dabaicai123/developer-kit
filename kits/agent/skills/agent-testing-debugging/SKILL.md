---
name: agent-testing-debugging
description: "Tests and debugs agent systems with unit tests, mock models, trajectory replay, state inspection, snapshots, and CI diagnostics. Use when fixing failed runs or adding test coverage."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Testing Debugging

Use this skill to reproduce failures and protect behavior with tests. It owns diagnosis and developer feedback loops.

## Scope Boundary

- Use `agent-testing-debugging` for failing runs, unit tests, mocks, replay, and CI diagnostics.
- Use `agent-evaluation` for broad quality scoring and release gates.
- Use `agent-observability` for production evidence used during debugging.

## Test Layers

| Layer | Tests |
|---|---|
| Unit | Tool schemas, validators, prompt rendering, state transitions. |
| Integration | Tool adapters, retrieval stores, model route wiring, guardrails. |
| Trajectory | Expected sequence of planning, tool calls, and state changes. |
| Snapshot | Stable structured outputs and prompt assembly. |
| Regression | Previously failed runs converted to reproducible cases. |
| CI smoke | Small deterministic subset that runs on every change. |

## Debug Workflow

1. Capture trace ID, input, prompt version, tool schema versions, and model route.
2. Classify failure: validation, tool, retrieval, planning, safety, or model quality.
3. Reproduce with external side effects mocked or sandboxed.
4. Add the smallest failing test.
5. Fix code, prompt, route, or data based on the failure class.
6. Re-run the failing test plus the relevant eval subset.

## Implementation Rules

- Mock model responses for deterministic unit tests.
- Record tool calls as typed events so trajectories can be asserted.
- Avoid snapshotting secrets, timestamps, or nondeterministic IDs.
- Convert production incidents into regression cases when data policy permits it.
- Keep expensive evals out of fast CI; run them as release gates.

## Output Checklist

- Failure class is named.
- Reproduction inputs and versions are captured.
- Test layer and expected assertion are defined.
- Side effects are mocked or isolated.
- Regression coverage is added for the bug.

## Anti-Patterns

- Debugging from final answer text without traces.
- Testing only prompts while leaving tool schemas untested.
- Using live external systems in unit tests.
- Treating nondeterministic model variance as a code fix without evidence.
