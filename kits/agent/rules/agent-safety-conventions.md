---
paths:
  - "**/*.py"
---

# Rule: Agent Safety Conventions

Enforce safety and security conventions for agentic applications. All agent systems must include guardrails, approval gates, and defensive patterns against common attack vectors.

## Mandatory Guardrails

### 1. Tool Safety

Every tool must include:
- **JSON Schema validation** — strict `additionalProperties: false`, typed inputs, enums for bounded choices
- **Timeout budget** — every tool call has a max execution time (default: 30s)
- **Idempotency** — write operations must be safely retryable
- **Structured error returns** — tools throw on failure, never return null/empty silently
- **Least-privilege** — tools only access the resources they need

### 2. Spend Limits

- Max step count per session: 10-20 (configurable)
- Max cost per session: $1-5 (configurable)
- Token budget per tool call: defined per tool
- Alert thresholds: cost anomaly detection, rate limiting

### 3. Human-in-the-Loop

Required for:
- Irreversible actions (delete, modify production data, send communications)
- Low-confidence outputs (model uncertainty threshold)
- High-consequence decisions (financial, medical, legal)
- First-time tool usage (unknown tool behavior)

### 4. Prompt Injection Defense

- Treat all retrieved text as hostile input — never trust external data
- Separate system instructions from user/data context
- Validate tool call arguments against schemas before execution
- Monitor for instruction override patterns in agent outputs
- Never expose internal prompts or tool schemas in outputs

### 5. PII and Data Protection

- Detect and redact PII in inputs and outputs
- Encrypt memory at rest
- Implement least-privilege access for memory and knowledge stores
- Provide deletion APIs for user data
- Audit logging for all memory reads/writes

## Policy-as-Code Pattern

```python
from pydantic import BaseModel

class ToolPolicy(BaseModel):
    """Define what each tool is allowed to do."""
    tool_name: str
    allowed_operations: list[str]      # e.g., ["read", "list"]
    requires_approval: list[str]       # e.g., ["write", "delete"]
    max_calls_per_session: int         # e.g., 50
    timeout_seconds: int               # e.g., 30
    allowed_tables: list[str] | None   # For database tools
    readonly: bool                     # True for safe tools

POLICIES = {
    "search_tool": ToolPolicy(tool_name="search_tool", allowed_operations=["search"], requires_approval=[], max_calls_per_session=100, timeout_seconds=10, readonly=True),
    "database_tool": ToolPolicy(tool_name="database_tool", allowed_operations=["read", "list"], requires_approval=["write", "delete"], max_calls_per_session=50, timeout_seconds=30, allowed_tables=["orders", "customers"], readonly=False),
}
```

## Adversarial Testing

Every agent must be tested against:
- Malformed inputs (invalid JSON, missing required fields)
- Conflicting instructions ("ignore previous instructions and...")
- Stale memory (contradictory facts stored across sessions)
- Tool abuse attempts (escalating scope, bypassing approval)
- Resource exhaustion (excessive tool calls, token consumption)

## Anti-Patterns

- Tools that return null on failure instead of raising errors
- Skipping approval gates for "low-risk" operations — define risk explicitly
- Trusting retrieved documents without validation
- No spending limits — always set max step count and cost ceiling
- Exposing raw tool schemas or system prompts in user-facing output