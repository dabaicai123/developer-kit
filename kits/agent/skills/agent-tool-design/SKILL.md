---
name: agent-tool-design
description: "Designs agent tools with strict schemas, descriptions, validation, idempotency, permission checks, error contracts, and MCP compatibility. Use when exposing actions to agents."
version: "1.2.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Tool Design

Use this skill when an agent needs to call code, APIs, files, databases, or MCP tools. Good tools reduce reasoning burden and failure rate.

## Scope Boundary

- Use `agent-tool-design` for tool contracts, schemas, validation, and side-effect rules.
- Use `mcp-integration` for MCP server/client implementation details.
- Use `agent-guardrails` for policy and approval enforcement.

## Tool Contract

Each tool must define:

- Name: verb-noun, stable, and specific.
- Description: when to use it and when not to use it.
- Input schema: required fields, enums, bounds, formats, and examples.
- Output schema: success shape and error shape.
- Side effects: read-only, write, delete, external, or monetary.
- Idempotency: key or reason it is not idempotent.
- Permissions: caller, scope, and approval requirement.
- Observability: trace fields and redaction rules.

## Design Rules

- Prefer a few precise tools over one broad tool with free-form instructions.
- Validate before executing and return typed errors after failures.
- Use enums and bounded strings instead of open text when the action space is known.
- Make destructive or external side effects explicit in the schema and approval policy.
- Keep tool output compact; return IDs or summaries for large payloads.
- Version schemas when changing required fields or semantics.

## MCP Compatibility

- Map tools to MCP tools when the agent needs actions.
- Use MCP resources for readable context and prompts for reusable prompt templates.
- Keep server-side permission checks even if the client prompt says the action is allowed.
- Support Streamable HTTP for remote MCP servers when compatible with the target client.

## Output Checklist

- Tool name, description, input schema, and output schema are present.
- Side effects and idempotency are explicit.
- Permissions and approvals are enforceable before execution.
- Errors are typed and actionable.
- Trace fields and redaction rules are included.

## Anti-Patterns

- A generic `run_command` or `call_api` tool without strict constraints.
- Tool descriptions that only repeat the name.
- Returning huge raw payloads directly to the model.
- Assuming prompt instructions are enough to prevent unsafe tool calls.
