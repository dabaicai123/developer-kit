---
name: agent-tool-design
description: "Tool contract design patterns for agents: deterministic contracts, idempotency, timeout budgets, structured errors, description quality, progressive disclosure, MCP definitions, versioning, and anti-patterns. Use when designing agent tools, defining tool schemas, or optimizing tool descriptions for agent performance."
version: "1.0.0"
type: skill
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Agent Tool Design

Tool contract design patterns for production agents. A well-designed tool is a deterministic contract with typed inputs, structured errors, explicit timeouts, and a description that tells the agent exactly when and how to use it. Tool description quality is the single biggest determinant of agent performance.

## When to use this skill

- Designing new tools for an agent system
- Writing tool descriptions and JSON schemas for agent consumption
- Defining MCP tool definitions for cross-platform agent tools
- Debugging agents that select wrong tools or pass wrong arguments
- Optimizing tool description quality for better agent decision-making
- Implementing tool versioning, filtering, or progressive disclosure

## Tool as Deterministic Contract

Every tool must have a strict JSON Schema with `additionalProperties: false`, typed inputs, and enums for bounded choices. The agent receives a contract, not a suggestion.

```python
from pydantic import BaseModel, Field
from typing import Literal
from enum import Enum

class SearchScope(str, Enum):
    recent = "recent"
    all = "all"
    archived = "archived"

class SearchToolInput(BaseModel):
    query: str = Field(
        description="Search query string. Use natural language. Example: 'recent papers on transformer architectures'",
        min_length=1,
        max_length=500,
    )
    scope: SearchScope = Field(
        description="Time scope for search results. 'recent' returns results from the last 30 days. 'all' returns all available results. 'archived' returns results older than 1 year.",
        default=SearchScope.recent,
    )
    max_results: int = Field(
        description="Maximum number of results to return. Use 5 for quick lookups, 20 for comprehensive research.",
        ge=1,
        le=50,
        default=10,
    )
    domain_filter: list[str] | None = Field(
        description="Optional list of domains to restrict results to. Example: ['arxiv.org', 'nature.com']. When null, all domains are included.",
        default=None,
    )

    model_config = {"extra": "forbid"}
```

Rules for deterministic contracts:
- `additionalProperties: false` (Pydantic: `model_config = {"extra": "forbid"}`) — reject unexpected fields. Agents frequently pass extra kwargs that tools should ignore, not silently accept.
- Use enums for bounded choices — never accept free-form strings where the options are known
- Set `min_length` and `max_length` on strings — agents sometimes pass empty or excessively long arguments
- Set `ge` and `le` on integers — bounds prevent degenerate inputs like `max_results=0` or `max_results=999999`
- Every field has a description — the agent reads field descriptions to decide what values to pass

## Idempotency

Write operations must be safely retryable. Use unique request IDs to prevent duplicate execution on retries.

```python
import uuid

class WriteToolInput(BaseModel):
    request_id: str = Field(
        description="Unique identifier for this write operation. Generate a UUID for each new request. Reuse the same request_id for retries of the same operation to prevent duplicates.",
        default_factory=lambda: str(uuid.uuid4()),
    )
    table: str = Field(description="Target table name")
    data: dict = Field(description="Data to write")

    model_config = {"extra": "forbid"}

class IdempotentWriteTool:
    executed_requests = set()

    def execute(self, input: WriteToolInput) -> dict:
        if input.request_id in self.executed_requests:
            return {"status": "already_executed", "request_id": input.request_id}
        result = self._write_to_db(input.table, input.data)
        self.executed_requests.add(input.request_id)
        return {"status": "success", "request_id": input.request_id, "result": result}
```

Idempotency rules:
- Every write operation has a `request_id` field — the agent generates a UUID for new requests and reuses it for retries
- Return `already_executed` on duplicate request IDs — the agent knows the write succeeded, no ambiguity
- Read operations are naturally idempotent — no request ID needed
- DELETE operations should use soft delete — reversible if the agent deletes the wrong record

## Timeout Budgets

Every tool has a maximum execution time. Configurable per tool. The agent must not wait indefinitely for a tool response.

```python
import asyncio
from functools import wraps

DEFAULT_TIMEOUTS = {
    "search_tool": 10,
    "database_read": 30,
    "database_write": 60,
    "email_send": 15,
    "file_read": 5,
    "file_write": 10,
    "external_api": 30,
    "code_execution": 120,
}

def with_timeout(timeout_seconds=None):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            tool_name = func.__name__
            timeout = timeout_seconds or DEFAULT_TIMEOUTS.get(tool_name, 30)
            try:
                return await asyncio.wait_for(func(*args, **kwargs), timeout=timeout)
            except asyncio.TimeoutError:
                return {
                    "error_type": "timeout",
                    "message": f"{tool_name} exceeded {timeout}s timeout",
                    "retryable": True,
                    "suggested_recovery": f"Retry with a simpler query or reduce max_results. Current timeout: {timeout}s.",
                }
        return wrapper
    return decorator
```

Timeout rules:
- Set default timeouts per tool type — reads are fast (5-30s), writes are slower (30-120s), external APIs vary
- Never set timeout to infinity — every tool must have a ceiling
- Return structured timeout errors — tell the agent whether to retry and what to change
- Log timeout events — they indicate either slow tools or degenerate agent queries

## Structured Error Returns

Tools throw on failure, never return null silently. Every error surface includes: error_type, message, retryable flag, and suggested_recovery.

```python
class ToolError(BaseModel):
    error_type: str = Field(description="Category of error: timeout, validation, permission, not_found, rate_limit, internal")
    message: str = Field(description="Human-readable error description")
    retryable: bool = Field(description="Whether the agent should retry this operation")
    suggested_recovery: str = Field(description="What the agent should do next: retry, use alternative tool, ask user, abort")

class ToolResult(BaseModel):
    success: bool
    data: dict | None = None
    error: ToolError | None = None

def safe_execute(tool_func, **kwargs) -> ToolResult:
    try:
        result = tool_func(**kwargs)
        return ToolResult(success=True, data=result)
    except ValidationError as e:
        return ToolResult(
            success=False,
            error=ToolError(
                error_type="validation",
                message=str(e),
                retryable=False,
                suggested_recovery="Check input arguments against the tool schema and retry with corrected values.",
            ),
        )
    except PermissionDeniedError as e:
        return ToolResult(
            success=False,
            error=ToolError(
                error_type="permission",
                message=str(e),
                retryable=False,
                suggested_recovery="This operation requires approval. Request human approval before retrying.",
            ),
        )
    except NotFoundError as e:
        return ToolResult(
            success=False,
            error=ToolError(
                error_type="not_found",
                message=str(e),
                retryable=False,
                suggested_recovery="The requested resource does not exist. Try a different ID or search for the resource first.",
            ),
        )
    except RateLimitError as e:
        return ToolResult(
            success=False,
            error=ToolError(
                error_type="rate_limit",
                message=str(e),
                retryable=True,
                suggested_recovery="Wait 60 seconds and retry. Reduce the number of concurrent requests.",
            ),
        )
    except Exception as e:
        return ToolResult(
            success=False,
            error=ToolError(
                error_type="internal",
                message="Internal tool error",
                retryable=True,
                suggested_recovery="Retry once. If the error persists, use an alternative tool or report to the user.",
            ),
        )
```

Error return rules:
- Never return null or empty dict on failure — the agent cannot distinguish "no results" from "tool failed"
- `retryable=True` means the agent should retry the same call — rate limits, timeouts, transient errors
- `retryable=False` means the agent must change something — validation errors, permission denied, not found
- `suggested_recovery` gives the agent a concrete next action — not "try again" but "reduce max_results to 5 and retry"

## Tool Description Quality

The single biggest determinant of agent performance. A tool description must explain: what the tool returns, when to use it, what each parameter means, and edge cases.

### Bad vs Good Tool Descriptions

Bad description:
```json
{
  "name": "search",
  "description": "Search for information",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {"type": "string"},
      "limit": {"type": "integer"}
    }
  }
}
```

Problems: no indication of what "search" covers, no guidance on when to use it, no parameter descriptions, no edge cases.

Good description:
```json
{
  "name": "search_arxiv",
  "description": "Search academic papers on arXiv by topic, author, or keyword. Returns a list of paper titles, abstracts, arXiv IDs, and publication dates. Use this tool when the user asks about academic research, scientific papers, or wants to find literature on a topic. Do not use for general web search or news. Edge cases: very broad queries (e.g., 'AI') return too many results — narrow with domain_filter or increase specificity. Queries with special characters may need escaping.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Natural language search query. Be specific for better results. 'transformer attention mechanisms 2024' works better than 'AI'. Maximum 500 characters.",
        "minLength": 1,
        "maxLength": 500
      },
      "scope": {
        "type": "string",
        "enum": ["recent", "all", "archived"],
        "description": "Time scope. 'recent' = last 30 days, 'all' = everything, 'archived' = older than 1 year. Default: 'recent'."
      },
      "max_results": {
        "type": "integer",
        "description": "Maximum results to return. Use 5 for quick lookups, 20 for comprehensive research. Range: 1-50.",
        "minimum": 1,
        "maximum": 50,
        "default": 10
      },
      "domain_filter": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Optional domains to restrict results to. Example: ['cs.AI', 'cs.CL']. When null, all arXiv categories are included."
      }
    },
    "required": ["query"],
    "additionalProperties": false
  }
}
```

Improvements: explicit tool scope, return format description, when-to-use guidance, per-parameter descriptions with examples and bounds, edge case warnings, `additionalProperties: false`.

## Progressive Disclosure

Three-tier loading strategy that cuts token cost by 94%. The agent loads only the detail level it needs.

| Tier | Content | Token Cost | When to Load |
|---|---|---|---|
| Tier 1 | Name + one-line description | ~20 tokens per tool | Always (in every LLM call) |
| Tier 2 | Full description + parameter names and types | ~100 tokens per tool | When the agent selects this tool |
| Tier 3 | Full schema + examples + edge cases | ~300 tokens per tool | When the agent is about to call this tool |

```python
PROGRESSIVE_TOOL_REGISTRY = {
    "search_arxiv": {
        "tier1": {
            "name": "search_arxiv",
            "description": "Search academic papers on arXiv by topic, author, or keyword.",
        },
        "tier2": {
            "name": "search_arxiv",
            "description": "Search academic papers on arXiv by topic, author, or keyword. Returns titles, abstracts, IDs, dates. Use for academic research queries. Do not use for general web search.",
            "parameters": {
                "query": {"type": "string", "required": True},
                "scope": {"type": "string", "enum": ["recent", "all", "archived"]},
                "max_results": {"type": "integer", "range": "1-50"},
                "domain_filter": {"type": "array", "required": False},
            },
        },
        "tier3": {
            "name": "search_arxiv",
            "description": "Search academic papers on arXiv by topic, author, or keyword. Returns a list of paper titles, abstracts, arXiv IDs, and publication dates. Use this tool when the user asks about academic research, scientific papers, or wants to find literature on a topic. Do not use for general web search or news. Edge cases: very broad queries return too many results — narrow with domain_filter or increase specificity.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Natural language search query. Be specific for better results. Maximum 500 characters.", "minLength": 1, "maxLength": 500},
                    "scope": {"type": "string", "enum": ["recent", "all", "archived"], "description": "Time scope. 'recent' = last 30 days, 'all' = everything, 'archived' = older than 1 year. Default: 'recent'."},
                    "max_results": {"type": "integer", "description": "Maximum results. 5 for quick lookups, 20 for research. Range: 1-50.", "minimum": 1, "maximum": 50, "default": 10},
                    "domain_filter": {"type": "array", "items": {"type": "string"}, "description": "Optional domains. Example: ['cs.AI', 'cs.CL']. Null = all categories."},
                },
                "required": ["query"],
                "additionalProperties": False,
            },
        },
    },
}

def get_tier1_descriptions(registry):
    return [t["tier1"] for t in registry.values()]

def get_tier2_description(registry, tool_name):
    return registry[tool_name]["tier2"]

def get_tier3_schema(registry, tool_name):
    return registry[tool_name]["tier3"]
```

Inject Tier 1 into every LLM call. Load Tier 2 when the agent mentions a tool. Load Tier 3 only when the agent is constructing a tool call. With 20 tools: Tier 1 = 400 tokens, full schema = 6000 tokens. Savings: 94%.

## MCP Tool Definition

MCP (Model Context Protocol) tools use a standard format: name, description, inputSchema. Compatible with Claude, OpenAI, and any MCP-compatible agent runtime.

```json
{
  "name": "database_query",
  "description": "Execute a read-only SQL query against the orders database. Returns results as a JSON array of rows. Use this tool when the user asks about order data, customer statistics, or inventory status. Only SELECT queries are allowed — no INSERT, UPDATE, or DELETE. Edge cases: queries without WHERE clauses may return very large result sets — always add LIMIT. Complex JOINs may timeout — simplify the query or use multiple simpler queries.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "sql": {
        "type": "string",
        "description": "SQL SELECT query to execute. Must be read-only (SELECT only). Always include a WHERE clause and LIMIT for large tables. Example: 'SELECT id, status FROM orders WHERE customer_id = 123 LIMIT 10'",
        "minLength": 1,
        "maxLength": 2000
      },
      "timeout_seconds": {
        "type": "integer",
        "description": "Maximum execution time in seconds. Default: 30. Increase for complex aggregation queries.",
        "minimum": 5,
        "maximum": 120,
        "default": 30
      }
    },
    "required": ["sql"],
    "additionalProperties": false
  }
}
```

## Tool Versioning

Version tools like APIs. Breaking changes require a new tool name. Additive changes preserve backward compatibility.

```python
TOOL_VERSIONS = {
    "search_arxiv": {
        "version": "2.1.0",
        "change_date": "2025-01-15",
        "changes": [
            {"version": "2.0.0", "date": "2024-11-01", "reason": "Added domain_filter parameter, changed default scope from 'all' to 'recent'", "breaking": True},
            {"version": "2.1.0", "date": "2025-01-15", "reason": "Added maxLength constraint on query parameter", "breaking": False},
        ],
    },
}

def register_tool_version(tool_name, version, description, input_schema, breaking=False):
    if breaking and tool_name in active_tools:
        new_name = f"{tool_name}_v{version.split('.')[0]}"
        active_tools[new_name] = {
            "name": new_name,
            "description": description,
            "inputSchema": input_schema,
            "version": version,
        }
    else:
        active_tools[tool_name]["description"] = description
        active_tools[tool_name]["inputSchema"] = input_schema
        active_tools[tool_name]["version"] = version
```

Versioning rules:
- Breaking changes = new tool name (`search_arxiv_v2`) — old tool continues to work for existing workflows
- Additive changes = same tool name, updated version — new parameters have defaults, existing behavior unchanged
- Every change has a date, reason, and breaking flag — track tool evolution for debugging
- Never remove parameters — deprecate them with a warning in the description instead

## Tool Filtering / Allowlist

Restrict which tools an agent can access per session, per user, or per policy. Not every agent needs every tool.

```python
class ToolAllowlist:
    def __init__(self):
        self.profiles = {
            "researcher": ["search_arxiv", "search_web", "database_query", "file_read"],
            "analyst": ["database_query", "file_read", "file_write", "chart_generate"],
            "admin": ["database_query", "database_write", "email_send", "file_read", "file_write", "user_manage"],
            "readonly": ["search_arxiv", "search_web", "database_query", "file_read"],
        }

    def get_tools_for_profile(self, profile_name):
        return self.profiles.get(profile_name, self.profiles["readonly"])

    def filter_registry(self, registry, profile_name):
        allowed = self.get_tools_for_profile(profile_name)
        return {name: registry[name] for name in allowed if name in registry}

    def validate_tool_call(self, tool_name, profile_name):
        allowed = self.get_tools_for_profile(profile_name)
        if tool_name not in allowed:
            return ToolResult(
                success=False,
                error=ToolError(
                    error_type="permission",
                    message=f"Tool {tool_name} is not available for profile {profile_name}",
                    retryable=False,
                    suggested_recovery=f"Available tools for your profile: {', '.join(allowed)}",
                ),
            )
        return None
```

Filtering rules:
- Every user/session has a tool profile — restrict access to what they need
- Default profile is `readonly` — escalate access through explicit approval
- Validate before execution — reject unauthorized tool calls with a clear error listing available alternatives
- Log unauthorized attempts — they may indicate prompt injection or scope escalation

## Anti-Patterns

- **Vague descriptions** — "Search for information" tells the agent nothing about scope, return format, or edge cases. Every description must specify: what the tool returns, when to use it, what each parameter means.
- **Silent failures** — returning null, empty dict, or empty string on error. The agent cannot distinguish success-with-no-results from failure. Always return structured ToolResult with success=True/False.
- **50+ tools per agent** — the agent spends more tokens reading tool descriptions than executing tasks. Use progressive disclosure and allowlists to keep visible tools under 20. Store additional tools in a registry the agent can discover when needed.
- **No timeout** — tools that hang indefinitely block the entire agent loop. Every tool must have a max execution time.
- **Mutable global state in tools** — tools that modify shared state without idempotency keys create race conditions on retries. Every write operation must include a `request_id`.
- **Free-form string parameters** — when options are known, use enums. Free-form strings let the agent pass invalid values that the tool must validate and reject.
- **Unversioned tools** — changing a tool's behavior without versioning breaks existing agent workflows silently. Every tool has a version, and breaking changes get a new name.

## References

- MCP Specification: https://modelcontextprotocol.io/specification
- Pydantic Models: https://docs.pydantic.dev/
- OpenAI Function Calling: https://platform.openai.com/docs/guides/function-calling
- Anthropic Tool Use: https://docs.anthropic.com/en/docs/build-with-claude/tool-use