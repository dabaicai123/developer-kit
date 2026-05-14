---
name: agent-streaming-realtime
description: "Designs streaming and realtime agent experiences with SSE, WebSockets, incremental events, cancellation, backpressure, and partial results. Use for live agent UX or APIs."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Streaming Realtime

Use this skill when users or clients need incremental agent progress instead of waiting for a final response.

## Scope Boundary

- Use `agent-streaming-realtime` for transport events, partial results, cancellation, and realtime UX.
- Use `agent-loop-patterns` for the underlying execution loop.
- Use `agent-error-recovery` for failed stream steps.

## Transport Choice

| Transport | Use when |
|---|---|
| Server-sent events | One-way progress and token streams over HTTP. |
| WebSocket | Bidirectional collaboration, interruption, or multiplayer state. |
| Webhook | Long-running background jobs with external notification. |
| Polling | Environments where persistent connections are unavailable. |

## Event Contract

```json
{
  "type": "step.started | token | tool.started | tool.finished | partial | final | error",
  "trace_id": "stable trace id",
  "step_id": "stable step id",
  "sequence": 1,
  "payload": {}
}
```

## Implementation Rules

- Every event needs a sequence number so clients can detect gaps.
- Send structured step events separately from text tokens.
- Support cancellation and map it to workflow state.
- Buffer only what the client can accept; apply backpressure or drop noncritical progress events.
- Treat partial outputs as provisional until a final event validates them.
- Persist enough state to resume or explain interrupted streams.

## Output Checklist

- Transport and reason are stated.
- Event schema is defined.
- Cancellation and timeout behavior are specified.
- Backpressure strategy is included.
- Final event contains validated output or explicit failure.

## Anti-Patterns

- Streaming raw model tokens without tool and guardrail events.
- Letting partial text trigger irreversible downstream actions.
- Ignoring client disconnects while tools continue spending money.
- Mixing human approval prompts into a token stream without a distinct event type.
