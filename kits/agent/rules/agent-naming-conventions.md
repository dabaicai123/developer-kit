---
paths:
  - "**/*.py"
---

# Rule: Agent Naming Conventions

Enforce consistent naming conventions across all agentic application components. Names must be descriptive, snake_case for Python, and follow domain-oriented patterns.

## Agent Names

- Format: `{role}_agent` — e.g., `researcher_agent`, `analyst_agent`, `writer_agent`
- Role names: descriptive and domain-specific, not generic ("market_researcher" not "agent_1")
- Crew names: `{purpose}_crew` — e.g., `research_crew`, `content_generation_crew`
- Flow names: `{workflow}_flow` — e.g., `report_generation_flow`, `data_pipeline_flow`

## Tool Names

- Format: `{action}_{target}_tool` — e.g., `search_web_tool`, `query_database_tool`
- Action verbs: specific ("query" not "get", "validate" not "check")
- Avoid generic names: `tool_1`, `helper_tool`, `utility_tool`

## Model/Schema Names

- Pydantic models: PascalCase domain entities — `ResearchReport`, `AnalysisResult`
- Schema fields: snake_case — `query_text`, `result_count`, `confidence_score`
- Enum values: UPPER_SNAKE_CASE — `TOOL_CALL_SUCCESS`, `TOOL_CALL_FAILURE`

## Configuration Keys

- YAML keys: snake_case — `llm_provider`, `max_iterations`, `memory_backend`
- Environment variables: UPPER_SNAKE_CASE — `OPENAI_API_KEY`, `CREWAI_LOG_LEVEL`
- File names: snake_case — `agents.yaml`, `tasks.yaml`, `research_crew.yaml`

## Prompt File Names

- System prompts: `{role}_system_prompt.md` — e.g., `researcher_system_prompt.md`
- Task templates: `{task_name}_task_template.md` — e.g., `analyze_data_task_template.md`
- Skill files: always `SKILL.md` inside skill directory

## MCP Server Names

- Server identifiers: `{domain}_mcp_server` — e.g., `database_mcp_server`, `filesystem_mcp_server`
- Tool names within MCP: `{action}_{resource}` — e.g., `query_orders`, `read_file`

## Anti-Patterns

- Generic numbered names (`agent_1`, `tool_a`) — always use descriptive role/action names
- Mixing naming conventions (PascalCase tools, camelCase models) — stay consistent
- Abbreviations without documentation (`svc_t`, `proc_a`) — use full words
- Name collisions between tools and agents — namespace by role/action