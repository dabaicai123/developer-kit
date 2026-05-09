---
name: mcp-integration
description: "Model Context Protocol integration patterns: tools, resources, prompts primitives; stdio/Streamable HTTP transports; OAuth 2.1 authentication; FastMCP server building; CrewAI and LlamaIndex MCP support; gateway pattern for enterprises. Use when connecting LLM agents to external tools or data via MCP."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MCP Integration Patterns

Production patterns for integrating the Model Context Protocol (MCP) into LLM agent systems. Covers the three primitives, transport options, authentication, server building, framework integration, and the enterprise gateway pattern.

## When to use this skill

- Defining MCP tool servers for agent integration
- Choosing between stdio, Streamable HTTP, and deprecated HTTP+SSE transports
- Implementing OAuth 2.1 authentication for remote MCP servers
- Building MCP servers with FastMCP (Python) or MCP TypeScript SDK
- Connecting MCP servers to CrewAI or LlamaIndex agents
- Designing a gateway architecture for 3+ MCP servers in production
- Understanding tool annotations for consent-driven security

## Protocol Overview

MCP is an open JSON-RPC 2.0 standard for connecting LLM applications with external data sources and tools. Created by Anthropic in November 2024. As of 2026, Microsoft, Google, AWS, Cloudflare, and Figma all ship MCP servers. The protocol is multi-vendor, not Anthropic-specific.

MCP solves a specific problem: every LLM framework had its own tool integration format. MCP provides a single standard so any LLM application can connect to any tool server, regardless of framework.

## Three Primitives

MCP defines three capability types that servers expose to clients:

### Tools

Callable functions with a name, description, and inputSchema. Tools perform actions — they are the "do things" primitive.

```json
{
  "name": "query_database",
  "description": "Execute a SQL query against the analytics database. Returns up to 100 rows.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "sql": {
        "type": "string",
        "description": "SQL query to execute"
      },
      "limit": {
        "type": "integer",
        "description": "Maximum rows to return",
        "default": 100
      }
    },
    "required": ["sql"]
  }
}
```

### Resources

URI-addressed data. Resources provide context — they are the "read things" primitive. Clients read resources by URI, not by calling a function.

```json
{
  "uri": "db://analytics/users",
  "name": "User table",
  "description": "All users in the analytics database",
  "mimeType": "application/json"
}
```

Resource URIs can address files, database tables, API endpoints, or any identifiable data source.

### Prompts

Reusable prompt templates exposed as slash commands. Prompts provide structured interaction patterns — they are the "guide things" primitive.

```json
{
  "name": "code_review",
  "description": "Review code for bugs and style issues",
  "arguments": [
    {
      "name": "code",
      "description": "The code to review",
      "required": true
    },
    {
      "name": "language",
      "description": "Programming language",
      "required": false
    }
  ]
}
```

## Three Transports

| Transport | Use case | Security model | Network |
|---|---|---|---|
| stdio | Local subprocess (same machine) | OS-user identity, no network exposure | None — pipes only |
| Streamable HTTP | Remote servers (modern, 2025+ spec) | OAuth 2.1 with PKCE | HTTPS |
| HTTP+SSE | Deprecated since 2025 spec | Various | HTTPS |

**stdio** — the MCP server runs as a subprocess of the host application. Communication happens through stdin/stdout pipes. No network, no authentication, no CORS. The server inherits the OS user's identity and permissions. Use for local tools (file system, local database, CLI commands).

**Streamable HTTP** — the current standard for remote MCP servers. Single HTTP endpoint supports both regular requests and streaming via Server-Sent Events. OAuth 2.1 with PKCE for authentication. This is the transport for production remote servers.

**HTTP+SSE** — deprecated in the 2025 spec update. Do not use for new implementations. Migrate existing HTTP+SSE servers to Streamable HTTP.

## Authentication

Remote MCP servers require OAuth 2.1 with PKCE (Proof Key for Code Exchange). The authentication flow:

1. Client discovers the server's authorization metadata via Protected Resource Metadata (RFC 9728)
2. Client registers dynamically with the authorization server via Dynamic Client Registration (RFC 7591)
3. Client initiates authorization with PKCE challenge
4. Authorization server returns tokens scoped with Resource Indicators (RFC 8707)

**Key security mechanisms:**

- **Dynamic Client Registration (RFC 7591)** — clients register at runtime, no pre-shared credentials
- **Protected Resource Metadata (RFC 9728)** — clients discover auth requirements from the server itself
- **Resource Indicators (RFC 8707)** — tokens are bound to the specific MCP server, preventing token mis-redemption across different servers

```python
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

server_params = StdioServerParameters(
    command="python",
    args=["-m", "my_mcp_server"],
    env={"API_KEY": "..."},
)

async with stdio_client(server_params) as (read, write):
    async with ClientSession(read, write) as session:
        await session.initialize()
        tools = await session.list_tools()
        result = await session.call_tool("query_database", arguments={"sql": "SELECT 1"})
```

For Streamable HTTP servers, the client handles OAuth 2.1 flow automatically when connecting to a remote endpoint.

## Security Model

MCP treats tools as arbitrary code execution. Every tool call could modify data, access resources, or perform irreversible actions. The security model requires explicit user consent before any tool invocation.

**Tool annotations** drive consent UI. Servers declare behavioral hints that clients use to decide whether to auto-approve or require explicit user confirmation:

| Annotation | Meaning | Consent behavior |
|---|---|---|
| `readOnlyHint: true` | Tool only reads data, never modifies | Lower friction; may auto-approve |
| `destructiveHint: true` | Tool can destroy data irreversibly | Must require explicit confirmation |
| `idempotentHint: true` | Repeated calls produce the same result | Lower friction; safe to retry |
| `openWorldHint: true` | Tool interacts with external entities | Requires confirmation; network access risk |

```json
{
  "name": "delete_user",
  "description": "Permanently delete a user account and all associated data",
  "inputSchema": {
    "type": "object",
    "properties": {
      "user_id": {"type": "string"}
    },
    "required": ["user_id"]
  },
  "annotations": {
    "readOnlyHint": false,
    "destructiveHint": true,
    "idempotentHint": true,
    "openWorldHint": false
  }
}
```

Host applications must obtain explicit consent before invoking any tool that does not have `readOnlyHint: true` and `idempotentHint: true`. Annotations are hints, not guarantees — a tool marked `readOnlyHint: true` might still have side effects the server developer did not anticipate.

## Building MCP Servers

### FastMCP (Python)

FastMCP provides a decorator-based API for defining MCP servers. Each decorated function becomes a tool with automatic schema inference from type hints.

```python
from fastmcp import FastMCP

mcp = FastMCP("analytics-server", version="1.0.0")

@mcp.tool()
def query_database(sql: str, limit: int = 100) -> str:
    """Execute a SQL query against the analytics database.
    Returns up to 100 rows as JSON."""
    conn = get_connection()
    results = conn.execute(sql, max_rows=limit)
    return json.dumps(results)

@mcp.tool()
def list_tables() -> list[str]:
    """List all tables in the analytics database."""
    conn = get_connection()
    return conn.list_tables()

@mcp.resource("db://analytics/{table_name}")
def get_table_data(table_name: str) -> str:
    """Read all rows from a specified table."""
    conn = get_connection()
    results = conn.execute(f"SELECT * FROM {table_name} LIMIT 1000")
    return json.dumps(results)

@mcp.prompt()
def code_review(code: str, language: str = "python") -> str:
    """Generate a code review prompt."""
    return f"Review this {language} code for bugs, style issues, and security vulnerabilities:\n\n{code}"

if __name__ == "__main__":
    mcp.run()
```

FastMCP supports stdio (default) and Streamable HTTP transports. Switch transport with configuration:

```python
mcp.run(transport="streamable-http", host="0.0.0.0", port=8080)
```

### MCP TypeScript SDK

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({ name: "analytics-server", version: "1.0.0" });

server.tool(
  "query_database",
  "Execute a SQL query against the analytics database",
  { sql: z.string(), limit: z.number().default(100) },
  async ({ sql, limit }) => {
    const results = await executeQuery(sql, limit);
    return { content: [{ type: "text", text: JSON.stringify(results) }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

## Framework Integration

### CrewAI MCP Support

CrewAI agents connect to MCP servers via the `mcps` parameter. Specify server URLs for remote servers or configuration for local stdio servers.

```python
from crewai import Agent

researcher = Agent(
    role="Research Analyst",
    goal="Gather data from multiple sources",
    backstory="Analyst who queries databases and APIs to find insights.",
    tools=[local_search_tool],
    mcps=["https://analytics.example.com/mcp"],
)

analyst = Agent(
    role="Data Analyst",
    goal="Analyze data and produce reports",
    backstory="Quantitative analyst with database expertise.",
    mcps=[
        {
            "url": "https://db.example.com/mcp",
            "tools": ["query_database", "list_tables"],
        }
    ],
)
```

Filter specific tools from an MCP server with the `tools` parameter. This prevents agents from accessing tools they do not need, reducing the tool selection burden on the model.

### LlamaIndex MCP Support

LlamaIndex integrates MCP servers as agent tools via MCPToolSpec. This converts MCP tool definitions into LlamaIndex-compatible tool objects.

```python
from llama_index.tools.mcp import MCPToolSpec
from llama_index.core.agent import FunctionAgent

mcp_tool_spec = MCPToolSpec(
    url="https://analytics.example.com/mcp",
)

tools = await mcp_tool_spec.to_tool_list()

agent = FunctionAgent(
    tools=tools,
    system_prompt="You are a data analyst. Use the available tools to query databases.",
)

response = await agent.run("What are the top 10 products by revenue?")
```

For stdio-based MCP servers, configure the subprocess parameters:

```python
mcp_tool_spec = MCPToolSpec(
    command="python",
    args=["-m", "my_mcp_server"],
    env={"DB_URL": "postgresql://..."},
)
```

## Gateway Pattern

For enterprises running 3+ MCP servers, build or buy a gateway that centralizes authorization, observability, rate limiting, and audit logging.

**Gateway responsibilities:**

1. **Authorization** — single OAuth 2.1 entry point; gateway handles token management for all downstream servers
2. **Observability** — centralized tracing for all tool calls across all servers
3. **Rate limiting** — per-client, per-tool, per-server rate limits at a single point
4. **Audit logging** — every tool invocation logged with caller identity, tool name, arguments, and result
5. **Tool discovery** — clients connect to the gateway instead of individual servers; gateway aggregates tool lists

**Gateway implementations available in 2026:**

- AWS AgentCore — managed MCP gateway with authorization and observability
- Cloudflare MCP Portals — edge-deployed gateway with rate limiting and caching
- Self-hosted — build with FastMCP as the gateway server, proxying to downstream servers

```python
from fastmcp import FastMCP

gateway = FastMCP("enterprise-gateway")

gateway.add_proxy_server("https://analytics.example.com/mcp")
gateway.add_proxy_server("https://crm.example.com/mcp")
gateway.add_proxy_server("https://docs.example.com/mcp")

gateway.run(transport="streamable-http", host="0.0.0.0", port=8080)
```

Clients connect to the gateway's single endpoint. The gateway routes tool calls to the appropriate downstream server, handles authentication, and logs everything.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| HTTP+SSE for new servers | Deprecated in 2025 spec | Use Streamable HTTP |
| No OAuth for remote servers | Unauthenticated access; token theft risk | OAuth 2.1 with PKCE for all remote servers |
| Skipping tool annotations | Host cannot make informed consent decisions | Declare annotations for every tool |
| Direct connection to 3+ MCP servers per client | No centralized auth, logging, or rate limiting | Use a gateway |
| Exposing all MCP tools to every agent | Model overwhelmed by tool choice | Filter tools per agent with `tools` parameter |
| Stdio for remote access | Not designed for network communication | Use Streamable HTTP for remote servers |

## References

- MCP specification: https://spec.modelcontextprotocol.io
- FastMCP documentation: https://gofastmcp.com
- MCP TypeScript SDK: https://github.com/modelcontextprotocol/typescript-sdk
- OAuth 2.1 for MCP: https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization

## Related Skills

- `crewai-patterns` — CrewAI agent definition with MCP integration
- `llamaindex-rag-patterns` — LlamaIndex agent tools via MCPToolSpec
- `agent-tool-design` — General tool contract patterns (schemas, validation, idempotency)

## Keywords

mcp, model context protocol, tools, resources, prompts, stdio, streamable http, oauth 2.1, pkce, fastmcp, tool annotations, gateway pattern, crewai mcp, llamaindex mcp, mcp tool spec, dynamic client registration, protected resource metadata