---
name: agent-prompt-engineering
description: "Designs agent prompts: instruction hierarchy, system/developer separation, prompt assembly, tool guidance, versioning, and context budgets. Use when writing or refactoring agent instructions."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Prompt Engineering

Use this skill to make agent instructions precise, scoped, and maintainable.

## Scope Boundary

- Use `agent-prompt-engineering` for instruction text, hierarchy, assembly, and prompt versioning.
- Use `agent-context-management` for runtime compression and reinjection.
- Use `agent-tool-design` for tool schema wording and descriptions.

## Prompt Layers

| Layer | Purpose |
|---|---|
| System | Non-negotiable role, safety, and platform constraints. |
| Developer | Product behavior, engineering standards, workflows, and tool policy. |
| Skill | Task-specific procedures loaded only when relevant. |
| User | Current objective and preferences. |
| Runtime state | Files, traces, retrieved evidence, and pending decisions. |

## Implementation Rules

- Write instructions as concrete rules with observable behavior.
- Remove vague verbs such as "try" and "consider" unless uncertainty is intentional.
- Put volatile framework facts behind references or versioned notes.
- Keep examples short and directly tied to expected behavior.
- State conflict resolution rules when multiple instructions can apply.
- Version prompts and record prompt version in traces and evals.

## Prompt Review Checklist

- Trigger condition is clear.
- Required behavior is testable.
- Forbidden behavior is explicit where risk exists.
- Tool usage policy names allowed and approval-required actions.
- Output format is specified when downstream code depends on it.
- No redundant instruction repeats another active skill.

## Assembly Order

1. Stable system and developer rules.
2. Active skill instructions.
3. Current user objective.
4. Relevant memory and retrieved context.
5. Current task ledger and tool results.
6. Output contract.

## Anti-Patterns

- Encoding business logic only in prose when code can enforce it.
- Asking for hidden chain-of-thought instead of concise reasoning summaries or evidence.
- Repeating the same policy across many skills with different wording.
- Including old examples that contradict current APIs.
