---
name: agent-tool-design
description: "Tools are how AI agents interact with the world. A well-designed tool is the difference between an agent that works and one that hallucinates, fails silently, or costs 10x more tokens than necessary. This skill covers tool design from schema to error handling, MCP definitions, and the emerging MCP standard."
version: "1.1.0"
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

Tools are how AI agents interact with the world. A well-designed tool is the difference between an agent that works and one that hallucinates, fails silently, or costs 10x more tokens than necessary.

Key insight: "Tool descriptions are more important than tool implementations. The LLM never sees your code — it only sees the schema and description."

## When to Use This Skill

- Designing new tools for an agent system
- Writing tool descriptions and JSON schemas for agent consumption
- Defining MCP tool definitions for cross-platform agent tools
- Debugging agents that select wrong tools or pass wrong arguments
- Optimizing tool description quality for better agent decision-making
- Implementing tool versioning, filtering, or progressive disclosure
- Setting up idempotency, timeout budgets, or structured error returns

## Principles

- Description quality > implementation quality for LLM accuracy
- Aim for fewer than 20 tools — more causes confusion
- Every tool needs explicit error handling — silent failures poison agents
- Return strings, not objects — LLMs process text
- Validation gates before execution — reject, fix, or escalate, never silent fail
- Test tools with the LLM, not just unit tests
- Every write operation must be idempotent (safely retryable)
- Every tool must have a timeout ceiling — never wait indefinitely

## Capabilities

- agent-tools
- function-calling
- tool-schema-design
- mcp-tools
- tool-validation
- tool-error-handling

## Tooling

### Standards

- JSON Schema — When: All tool definitions Note: The universal format for tool schemas
- MCP (Model Context Protocol) — When: Building reusable, cross-platform tools Note: Anthropic's open standard, widely adopted

### Frameworks

- Anthropic SDK — When: Claude-based agents Note: Beta tool runner handles most complexity
- OpenAI Functions — When: OpenAI-based agents Note: Use strict mode for guaranteed schema compliance
- Vercel AI SDK — When: Multi-provider tool handling Note: Abstracts differences between providers
- LangChain Tools — When: LangChain-based agents Note: Converts MCP tools to LangChain format

## Patterns

### Tool Schema Design

Creating clear, unambiguous JSON Schema for tools. The single biggest determinant of agent performance.

**When to use**: Defining any new tool for an agent

```json
{
  "name": "search_arxiv",
  "description": "Search academic papers on arXiv by topic, author, or keyword. Returns a list of paper titles, abstracts, arXiv IDs, and publication dates. Use this tool when the user asks about academic research, scientific papers, or wants to find literature on a topic. Do not use for general web search or news. Edge cases: very broad queries (e.g., 'AI') return too many results — narrow with domain_filter or increase specificity.",
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
        "description": "Maximum results. 5 for quick lookups, 20 for research. Range: 1-50.",
        "minimum": 1,
        "maximum": 50,
        "default": 10
      }
    },
    "required": ["query"],
    "additionalProperties": false
  }
}
```

Rules for deterministic contracts:
- `additionalProperties: false` — reject unexpected fields. Agents frequently pass extra kwargs.
- Use enums for bounded choices — never accept free-form strings where options are known
- Set `minLength`/`maxLength` on strings — prevent empty or excessively long arguments
- Set `minimum`/`maximum` on integers — bounds prevent degenerate inputs like `max_results=0`
- Every field has a description — the agent reads field descriptions to decide values

### Tool with Input Examples

Using examples to guide LLM tool usage. Anthropic's beta feature that improves accuracy from 72% to 90% on complex operations.

**When to use**: Complex tools with nested objects or format-sensitive inputs

```json
{
  "name": "create_calendar_event",
  "description": "Creates a calendar event with optional attendees and reminders",
  "inputSchema": {
    "type": "object",
    "properties": {
      "title": {"type": "string", "description": "Event title"},
      "start_time": {"type": "string", "description": "ISO 8601 datetime, e.g. 2024-03-15T14:00:00Z"},
      "duration_minutes": {"type": "integer", "description": "Event duration"},
      "attendees": {"type": "array", "items": {"type": "string"}, "description": "Email addresses of attendees"}
    },
    "required": ["title", "start_time", "duration_minutes"]
  },
  "input_examples": [
    {
      "title": "Team Standup",
      "start_time": "2024-03-15T09:00:00Z",
      "duration_minutes": 30,
      "attendees": ["alice@company.com", "bob@company.com"]
    },
    {
      "title": "Quick Chat",
      "start_time": "2024-03-15T14:00:00Z",
      "duration_minutes": 15
    }
  ]
}
```

Example design principles: use realistic data, show minimal/partial/full patterns, keep concise (1-5 examples per tool), focus on ambiguous cases.

### Tool Error Handling

Returning errors that help the LLM recover. Every error includes: error_type, message, retryable flag, and suggested_recovery.

**When to use**: Any tool that can fail

```python
from dataclasses import dataclass
from typing import Union

@dataclass
class ToolResult:
    success: bool
    content: str
    error_type: str = None
    retryable: bool = None
    suggested_recovery: str = None

    def to_response(self) -> dict:
        if self.success:
            return {"content": self.content}
        return {
            "content": f"Error ({self.error_type}): {self.content}",
            "is_error": True
        }

# Error categories to handle:
# 1. Input Validation: missing params, invalid format, out of range
# 2. External Service: API unavailable, rate limited, timeout
# 3. Business Logic: not found, permission denied, conflict/duplicate
# 4. Internal: unexpected exceptions, data corruption

def get_weather(location: str) -> ToolResult:
    if not location or len(location) < 2:
        return ToolResult(success=False, content="Location must be at least 2 characters",
            error_type="validation", retryable=False,
            suggested_recovery="Provide a valid city name like 'San Francisco, CA'.")

    try:
        data = weather_api.fetch(location)
        return ToolResult(success=True, content=f"Temperature: {data.temp}°F")
    except LocationNotFound:
        return ToolResult(success=False, content=f"Location '{location}' not found",
            error_type="not_found", retryable=False,
            suggested_recovery="Try a different city name")
    except RateLimitError:
        return ToolResult(success=False, content="Rate limit exceeded. Try again in 60s.",
            error_type="rate_limit", retryable=True)
```

Error return rules:
- Never return null or empty dict on failure — agent can't distinguish "no results" from "tool failed"
- `retryable=True` → agent should retry same call (rate limits, timeouts)
- `retryable=False` → agent must change something (validation, permission, not found)
- `suggested_recovery` → concrete next action, not "try again" but "reduce max_results to 5"

### Idempotency

Write operations must be safely retryable. Use unique request IDs to prevent duplicate execution.

**When to use**: Any tool that performs write operations

```python
import uuid

class WriteToolInput(BaseModel):
    request_id: str = Field(
        description="Unique identifier for this write operation. Generate UUID for new requests. Reuse same request_id for retries to prevent duplicates.",
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
- Every write operation has a `request_id` field — agent generates UUID for new, reuses for retries
- Return `already_executed` on duplicate request IDs — agent knows write succeeded
- Read operations are naturally idempotent — no request ID needed
- DELETE operations should use soft delete — reversible if agent deletes wrong record

### Timeout Budgets

Every tool has a maximum execution time. The agent must not wait indefinitely.

**When to use**: Configuring timeouts for all tools

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
                    "suggested_recovery": f"Retry with simpler query or reduce max_results. Timeout: {timeout}s.",
                }
        return wrapper
    return decorator
```

Timeout rules:
- Set default timeouts per tool type — reads fast (5-30s), writes slower (30-120s)
- Never set timeout to infinity — every tool must have a ceiling
- Return structured timeout errors — tell agent whether to retry and what to change
- Log timeout events — indicate slow tools or degenerate agent queries

### MCP Tool Pattern

Building tools using Model Context Protocol. Build once, use everywhere.

**When to use**: Creating reusable, cross-platform tools

```typescript
import { Server } from "@modelcontextprotocol/sdk/server";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio";

const server = new Server({ name: "weather-server", version: "1.0.0" });

server.setRequestHandler("tools/list", async () => ({
  tools: [{
    name: "get_weather",
    description: "Get current weather for a location. Returns temperature, conditions, humidity.",
    inputSchema: {
      type: "object",
      properties: {
        location: { type: "string", description: "City and state, e.g. 'San Francisco, CA'" },
        unit: { type: "string", enum: ["celsius", "fahrenheit"], default: "fahrenheit" }
      },
      required: ["location"]
    }
  }]
}));

server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;
  if (name === "get_weather") {
    try {
      const weather = await fetchWeather(args.location, args.unit);
      return { content: [{ type: "text", text: JSON.stringify(weather) }] };
    } catch (error) {
      return { content: [{ type: "text", text: `Error: ${error.message}` }], isError: true };
    }
  }
  throw new Error(`Unknown tool: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

MCP Benefits: Universal compatibility, reusable tool libraries, streaming support, built-in observability, tool access controls.

### Tool Runner Pattern (Anthropic SDK)

Using SDK tool runners for automatic handling of tool call loops.

**When to use**: Building tool loops without manual management

```python
import anthropic
from anthropic import beta_tool

client = anthropic.Anthropic()

@beta_tool
def get_weather(location: str, unit: str = "fahrenheit") -> str:
    '''Get current weather. Args: location: City and state. unit: celsius or fahrenheit.'''
    return json.dumps({"temperature": "72°F", "conditions": "Sunny"})

runner = client.beta.messages.tool_runner(
    model="claude-sonnet-4-6", max_tokens=1024,
    tools=[get_weather],
    messages=[{"role": "user", "content": "What's the weather in Paris?"}]
)

for message in runner:
    print(message.content[0].text)
```

### Parallel Tool Execution

Claude can call multiple tools in one response. This dramatically reduces latency for independent operations.

**When to use**: Independent tool calls that can run in parallel

```python
# Execute in parallel
import asyncio

async def execute_tools_parallel(tool_uses):
    tasks = [execute_tool(t) for t in tool_uses]
    return await asyncio.gather(*tasks)

# Return ALL results in SINGLE user message (critical!)
tool_results = [
    {"type": "tool_result", "tool_use_id": "toolu_01", "content": "72°F, Sunny"},
    {"type": "tool_result", "tool_use_id": "toolu_02", "content": "45°F, Cloudy"},
]
messages.append({"role": "user", "content": tool_results})  # CORRECT: all in one message

# Encourage parallel use in system prompt:
# "Whenever you need multiple independent operations, invoke all relevant tools simultaneously."
```

### Progressive Disclosure

Three-tier loading strategy that cuts token cost by 94%. Agent loads only the detail level it needs.

**When to use**: Agents with many tools (>10) where full schemas would overwhelm context

| Tier | Content | Token Cost | When to Load |
|---|---|---|---|
| Tier 1 | Name + one-line description | ~20 tokens per tool | Always (in every LLM call) |
| Tier 2 | Full description + parameter names and types | ~100 tokens per tool | When agent selects this tool |
| Tier 3 | Full schema + examples + edge cases | ~300 tokens per tool | When agent is about to call this tool |

```python
PROGRESSIVE_TOOL_REGISTRY = {
    "search_arxiv": {
        "tier1": {"name": "search_arxiv", "description": "Search academic papers on arXiv."},
        "tier2": {"name": "search_arxiv", "description": "Search arXiv. Returns titles, abstracts, IDs. For academic research.",
            "parameters": {"query": {"type": "string", "required": True}, "scope": {"type": "string", "enum": ["recent", "all"]}}},
        "tier3": {"name": "search_arxiv", "description": "Search arXiv...",
            "inputSchema": { ... }},  # Full schema
    },
}

# Inject Tier 1 into every LLM call. Load Tier 2 when agent mentions tool.
# Load Tier 3 only when agent constructs a tool call.
# With 20 tools: Tier 1 = 400 tokens, full schema = 6000 tokens. Savings: 94%.
```

### Tool Versioning

Version tools like APIs. Breaking changes require a new tool name. Additive changes preserve backward compatibility.

**When to use**: Tools that evolve over time

```python
TOOL_VERSIONS = {
    "search_arxiv": {
        "version": "2.1.0",
        "changes": [
            {"version": "2.0.0", "reason": "Added domain_filter, changed default scope", "breaking": True},
            {"version": "2.1.0", "reason": "Added maxLength on query", "breaking": False},
        ],
    },
}

def register_tool_version(tool_name, version, description, input_schema, breaking=False):
    if breaking and tool_name in active_tools:
        new_name = f"{tool_name}_v{version.split('.')[0]}"
        active_tools[new_name] = {"name": new_name, "description": description, "inputSchema": input_schema}
    else:
        active_tools[tool_name]["description"] = description
        active_tools[tool_name]["inputSchema"] = input_schema
```

Versioning rules:
- Breaking changes = new tool name (`search_arxiv_v2`) — old tool continues working
- Additive changes = same tool name, updated version — new params have defaults
- Every change has a date, reason, and breaking flag
- Never remove parameters — deprecate with warning in description

### Tool Filtering / Allowlist

Restrict which tools an agent can access per session, per user, or per policy. Not every agent needs every tool.

**When to use**: Agents with many tools where not all should be available

```python
class ToolAllowlist:
    def __init__(self):
        self.profiles = {
            "researcher": ["search_arxiv", "search_web", "database_query", "file_read"],
            "analyst": ["database_query", "file_read", "file_write", "chart_generate"],
            "admin": ["database_query", "database_write", "email_send", "user_manage"],
            "readonly": ["search_arxiv", "search_web", "database_query", "file_read"],
        }

    def get_tools_for_profile(self, profile_name):
        return self.profiles.get(profile_name, self.profiles["readonly"])

    def validate_tool_call(self, tool_name, profile_name):
        allowed = self.get_tools_for_profile(profile_name)
        if tool_name not in allowed:
            return ToolResult(success=False, error_type="permission",
                content=f"Tool {tool_name} not available for {profile_name}",
                suggested_recovery=f"Available tools: {', '.join(allowed)}")
```

Filtering rules:
- Every user/session has a tool profile — restrict to what they need
- Default profile is `readonly` — escalate through explicit approval
- Validate before execution — reject unauthorized calls with clear error
- Log unauthorized attempts — may indicate prompt injection

## Validation Checks

### Tool Description Too Short

**Severity: WARNING** — Descriptions should be at least 100 characters. Add details about when to use, parameters, return values.

### Parameter Descriptions Missing

**Severity: WARNING** — Every parameter should have a description. Describe what it is and expected format.

### Schema Missing Required Fields

**Severity: INFO** — Explicitly define which fields are required. Add `required` array.

### Tool Without Error Handling

**Severity: ERROR** — Tool functions should handle exceptions. Add try/except.

### Error Results Missing is_error Flag

**Severity: WARNING** — When returning errors, set `is_error: true`.

### Tools Returning Dict Instead of String

**Severity: WARNING** — Return JSON string, not dict/object. LLMs process text.

### Tool Without Input Validation

**Severity: WARNING** — Validate LLM-provided inputs before execution.

### SQL Queries Using Concatenation

**Severity: ERROR** — Never concatenate user input into SQL. Use parameterized queries.

### External Calls Without Timeouts

**Severity: WARNING** — HTTP requests and external calls should have timeouts.

### MCP Tools Missing Input Schema

**Severity: ERROR** — All MCP tools require inputSchema.

## Sharp Edges

### Agent loops without iteration limits

**Severity: CRITICAL** — Agent runs until 'done' without max iterations. Can run forever, drain API credits, hang application.

**Fix**: Always set limits: max_iterations, max_tokens per turn, timeout on runs, cost caps, circuit breakers for tool failures.

### Vague or incomplete tool descriptions

**Severity: HIGH** — Agent picks wrong tools, parameter errors, says it can't do things it can. Tool descriptions are how agents choose tools — vague descriptions lead to wrong selection.

**Fix**: Write complete specs: clear one-sentence purpose, when to use (and when not to), parameter descriptions with types, example inputs/outputs, error cases.

### Tool errors not surfaced to agent

**Severity: HIGH** — Catching tool exceptions silently. Agent continues with bad data, compounding errors. Can't recover from what it can't see.

**Fix**: Return error messages to agent. Include error type and recovery hints. Let agent retry or choose alternative.

### Storing everything in agent memory

**Severity: MEDIUM** — Memory fills with irrelevant details, old information, noise. Bloats context, increases costs, causes model to lose focus.

**Fix**: Summarize rather than store verbatim. Filter by relevance before storing. Use RAG for long-term memory. Clear working memory between tasks.

### Agent has too many tools

**Severity: MEDIUM** — Giving agent 20+ tools causes wrong selection, overwhelming options, slow responses.

**Fix**: 5-10 tools maximum per agent. Use tool selection layer for large sets. Specialized agents with focused tools. Dynamic loading based on task.

### Using multiple agents when one would work

**Severity: MEDIUM** — Starting with multi-agent for simple tasks. Duplication, communication overhead, hard to debug.

**Fix**: Justify multi-agent: can one agent solve this? Is coordination overhead worth it? Start with single agent, add agents when proven necessary.

### Agent internals not logged or traceable

**Severity: MEDIUM** — Running agents without logging thoughts/actions. Can't explain failures, no visibility into reasoning.

**Fix**: Log each thought/action/observation. Track tool calls with inputs/outputs. Trace token usage and latency. Use structured logging.

### Fragile parsing of agent outputs

**Severity: MEDIUM** — Regex or exact string matching on LLM output. Minor format variations break parsers.

**Fix**: Use structured output (JSON mode, function calling). Fuzzy matching. Retry with format instructions. Handle multiple formats.

## Anti-Patterns

- **Vague descriptions** — "Search for information" tells agent nothing about scope, returns, or edge cases
- **Silent failures** — returning null/empty dict on error. Agent can't distinguish success-with-no-results from failure
- **50+ tools per agent** — agent spends more tokens reading descriptions than executing. Use progressive disclosure and allowlists to keep under 20
- **No timeout** — tools that hang indefinitely block entire agent loop. Every tool must have max execution time
- **Mutable global state in tools** — modifying shared state without idempotency keys creates race conditions on retries
- **Free-form string parameters** — when options are known, use enums. Free-form strings let agents pass invalid values
- **Unversioned tools** — changing behavior without versioning breaks workflows silently. Every tool has a version; breaking changes get a new name
- **No retryability** — every tool must indicate whether errors are retryable and what to change on retry

## Collaboration

### Delegation Triggers

- user needs to coordinate multiple tools → multi-agent-orchestration (Tool orchestration across agents)
- user needs persistent memory between tool calls → agent-memory-systems (State management for tools)
- user wants to test their tools → agent-evaluation (Tool testing and evaluation)

## Related Skills

Works well with: `multi-agent-orchestration`, `api-designer`, `llm-architect`, `agent-memory-systems`, `agent-evaluation`

## When to Use (Trigger Keywords)

- User mentions or implies: agent tool, function calling, tool schema, tool design, MCP server, MCP tool, tool use, build tool for agent, define function, input_schema, tool_use, tool_result

## References

- MCP Specification: https://modelcontextprotocol.io/specification
- Pydantic Models: https://docs.pydantic.dev/
- OpenAI Function Calling: https://platform.openai.com/docs/guides/function-calling
- Anthropic Tool Use: https://docs.anthropic.com/en/docs/build-with-claude/tool-use