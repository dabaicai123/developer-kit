---
paths:
  - "**/*.py"
---

# Rule: Agent Project Structure

Enforce consistent project structure for agentic applications. Follow the CrewAI + LlamaIndex conventions for project layout, module separation, and configuration management.

## Standard Project Layout

```
project/
├── src/
│   ├── agents/           → Agent definitions (roles, goals, tools)
│   │   ├── researcher.py
│   │   ├── analyst.py
│   │   └── writer.py
│   ├── crews/            → Crew compositions (agent + task assemblies)
│   │   └── research_crew.py
│   ├── flows/            → Flow definitions (event-driven orchestration)
│   │   ├── research_flow.py
│   ├── tools/            → Custom tool definitions (one file per tool)
│   │   ├── search_tool.py
│   │   ├── database_tool.py
│   ├── models/           → Pydantic models for structured outputs
│   │   ├── report.py
│   │   ├── analysis.py
│   ├── config/           → YAML/JSON configuration files
│   │   ├── agents.yaml
│   │   ├── tasks.yaml
│   │   ├── crews.yaml
│   ├── knowledge/        → Knowledge sources and data connectors
│   │   ├── pdf_source.py
│   │   ├── web_source.py
│   ├── memory/           → Memory configuration (short-term, long-term)
│   │   ├── memory_config.py
│   ├── prompts/          → System prompts and prompt templates
│   │   ├── system_prompts/
│   │   ├── task_templates/
│   └── utils/            → Shared utilities
│       ├── observability.py
│       ├── guardrails.py
│       ├── mcp_client.py
├── tests/
│   ├── evals/            → Evaluation datasets and test harnesses
│   │   ├── test_cases.json
│   │   ├── eval_runner.py
│   ├── unit/             → Unit tests for tools and models
│   ├── integration/      → Integration tests for crews and flows
├── data/                 → Raw data files (PDFs, CSVs, etc.)
├── mcp_servers/          → Local MCP server implementations (if any)
├── .env                  → Environment variables (API keys, model config)
├── .env.example          → Template for required env vars
├── pyproject.toml        → Project metadata and dependencies
├── Dockerfile            → Container definition for production
└── README.md             → Project documentation
```

## Naming Conventions

- Agent files: descriptive role name (`researcher.py`, `analyst.py`)
- Tool files: action-oriented (`search_tool.py`, `database_query_tool.py`)
- Crew files: purpose-based (`research_crew.py`, `content_generation_crew.py`)
- Flow files: workflow name (`research_flow.py`, `report_generation_flow.py`)
- Model files: domain entity (`report.py`, `analysis_result.py`)

## Configuration Management

- Use YAML files for agent/task/crew definitions (CrewAI convention)
- Use `.env` for secrets and model provider keys — never hardcode
- Use `pyproject.toml` for dependency management (prefer `uv` over `pip`)
- Separate dev/staging/production configs with environment-specific overrides

## Anti-Patterns

- Inline agent definitions in flow files — separate into `agents/` directory
- Hardcoded API keys — always use environment variables
- Multiple agent definitions in a single file — one file per agent role
- Skipping `.env.example` — always document required environment variables