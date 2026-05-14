---
name: agent-human-interaction
description: "Designs human-in-the-loop agent flows: clarification, approval, review, handoff, feedback, and confidence-based escalation. Use when agents collaborate with users or operators."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Human Interaction

Use this skill when the agent must ask, confirm, explain, or hand work to a person without stalling the workflow unnecessarily.

## Scope Boundary

- Use `agent-human-interaction` for UX of clarifications, approvals, feedback, and handoffs.
- Use `agent-guardrails` to decide which actions require approval.
- Use `agent-evaluation` to measure whether human feedback improves outcomes.

## Interaction Types

| Type | Use when | Agent behavior |
|---|---|---|
| Clarification | Required input is missing or ambiguous | Ask the smallest question that unblocks work. |
| Confirmation | The user asked for a reversible but notable action | Restate action and consequence. |
| Approval | Action is irreversible, costly, privileged, or external | Wait for explicit approval. |
| Review | Human quality judgment is required | Provide artifact, criteria, and focused options. |
| Handoff | Agent cannot complete safely or reliably | Transfer context, attempted steps, and blocker. |
| Feedback | Output can improve from preference data | Capture correction as structured signal. |

## Implementation Rules

- Ask at most the minimum number of questions needed to proceed.
- Preserve momentum by continuing safe independent work while waiting when possible.
- State concrete options with tradeoffs; avoid open-ended prompts for operational decisions.
- Include trace, artifact path, and decision point in approval requests.
- Convert feedback into a changed rule, eval case, or memory record only when it is reusable.

## Confidence Gates

| Confidence | Action |
|---|---|
| High and low risk | Proceed and log. |
| Medium or missing noncritical detail | Make a conservative assumption and state it. |
| Low with user-visible impact | Ask clarification. |
| Any confidence with high-risk action | Require approval. |

## Output Checklist

- Interaction type is explicit.
- User question is specific and bounded.
- Approval request states action, target, risk, and rollback path.
- Feedback capture has an owner and storage location.
- Handoff includes current state and next action.

## Anti-Patterns

- Asking users to decide internal implementation details without a reason.
- Blocking on clarification when a safe assumption is available.
- Burying approval requests inside long explanations.
- Treating one user's preference as a global rule without validation.
