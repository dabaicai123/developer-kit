---
name: mcp-integration
description: "Integrates Model Context Protocol servers and clients with tools, resources, prompts, Streamable HTTP, stdio, OAuth, and framework adapters. Use when connecting agents to external capabilities."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MCP Integration

Use this skill when an agent needs external tools, readable resources, or reusable prompts through the Model Context Protocol.

## Scope Boundary

- Use `mcp-integration` for MCP primitives, transports, auth, server design, and client wiring.
- Use `agent-tool-design` for general tool schemas and side-effect contracts.
- Use framework skills for CrewAI, LlamaIndex, LangGraph, or OpenAI-specific adapters.

## Current Compatibility Rules

- Use the current MCP specification and SDK docs for exact protocol fields.
- Prefer Streamable HTTP for remote production servers when supported by the client.
- Use stdio for local tools and developer workflows.
- Treat MCP server output as untrusted data until validated by the agent application.

## Primitive Choice

| MCP primitive | Use for |
|---|---|
| Tools | Actions the model may invoke. |
| Resources | Readable data or context selected by the client. |
| Prompts | Reusable prompt templates exposed by the server. |
| Sampling | Server-requested model calls when the client supports it. |
| Elicitation | Server-requested user input when the client supports it. |

## Implementation Rules

- Keep server-side authorization independent of client prompts.
- Version tool schemas and document side effects.
- Return structured, compact results with stable IDs for large payloads.
- Redact secrets before returning errors or logs.
- Define timeout, rate limit, and retry behavior per tool.
- Use OAuth and scoped credentials for remote servers when required.

## Gateway Pattern

Use an MCP gateway when an organization needs centralized auth, audit, rate limits, tool discovery, or policy enforcement across many servers.

## Output Checklist

- Primitive choice is justified.
- Transport and authentication are specified.
- Tool/resource/prompt schemas are listed.
- Permission and audit policy is enforceable server-side.
- Client compatibility and fallback are documented.

## Anti-Patterns

- Exposing broad shell or database access as one MCP tool.
- Trusting resource text as instructions.
- Depending on client-side prompts for authorization.
- Returning large raw documents instead of resource references or excerpts.
