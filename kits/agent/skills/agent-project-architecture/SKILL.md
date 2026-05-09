---
name: agent-project-architecture
description: "General agent project architecture patterns: directory layout, configuration management, dependency injection, environment isolation, and production-ready structure. Use when scaffolding a new agent project, restructuring an existing one, or setting up project conventions."
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

# Agent Project Architecture

General project architecture patterns for agent systems. Covers directory layout, configuration management, dependency injection, environment isolation, and production-ready structure that works across frameworks (LangGraph, CrewAI, OpenAI Agents SDK, PydanticAI).

## When to use this skill

- Scaffolding a new agent project from scratch
- Restructuring an existing agent project for production readiness
- Setting up project conventions for a team working on agents
- Choosing a directory layout that scales from prototype to production
- Deciding how to manage configuration, secrets, and dependencies

## Architecture Principles

| Principle | What It Means | Why |
|---|---|---|
| **Separate definition from execution** | Agent definitions, prompt templates, and config in separate files from runtime logic | Change prompts without touching code; review definitions independently |
| **Inject dependencies, don't hardcode** | External clients, API keys, and model choices injected at runtime | Test with mock dependencies; swap providers without code changes |
| **Environment-specific config** | Dev/staging/production have different models, limits, and tools | Test cheap, deploy capable; enforce different budgets per environment |
| **One agent, one file** | Each agent role has its own definition file | Clear ownership; easy to review and modify |
| **Config-driven, not code-driven** | Agent compositions, tool assignments, and limits defined in YAML/JSON | Non-developers can adjust; reduces deployment friction |

## Standard Project Layout

```
project/
├── src/
│   ├── agents/                → Agent definitions (one file per role)
│   │   ├── router.py          → Main routing agent
│   │   ├── researcher.py      → Research specialist
│   │   ├── analyst.py         → Analysis specialist
│   │   └── writer.py          → Writing specialist
│   ├── tools/                 → Tool implementations (one file per tool)
│   │   ├── search.py          → Web/database search tool
│   │   ├── database.py        → Database query tool
│   │   ├── calculator.py      → Computation tool
│   │   ├── email.py           → Email sending tool
│   ├── prompts/               → Prompt templates and system prompts
│   │   ├── system/            → System prompts per agent role
│   │   │   ├── router.md
│   │   │   ├── researcher.md
│   │   │   ├── analyst.md
│   │   │   ├── writer.md
│   │   ├── templates/         → Reusable prompt templates
│   │   │   ├── planning.md
│   │   │   ├── reflection.md
│   │   │   ├── clarification.md
│   ├── schemas/               → Pydantic models for structured outputs
│   │   ├── research_result.py
│   │   ├── analysis_result.py
│   │   ├── report.py
│   ├── orchestration/         → Multi-agent orchestration (graphs, flows, handoffs)
│   │   ├── graph.py           → LangGraph StateGraph definition
│   │   ├── flow.py            → CrewAI Flow definition (if using CrewAI)
│   │   ├── handoffs.py        → OpenAI Agents SDK handoff definitions
│   ├── config/                → Configuration files
│   │   ├── agents.yaml        → Agent role definitions
│   │   ├── tools.yaml         → Tool assignment per agent
│   │   ├── limits.yaml        → Budget limits, step limits, retry config
│   │   ├── environments/      → Environment-specific overrides
│   │   │   ├── dev.yaml
│   │   │   ├── staging.yaml
│   │   │   ├── production.yaml
│   ├── deps/                  → Dependency injection providers
│   │   ├── providers.py       → Client factories (HTTP, DB, LLM)
│   │   ├── container.py       → Dependency container setup
│   ├── guardrails/            → Guardrail implementations
│   │   ├── input_guardrails.py
│   │   ├── output_guardrails.py
│   │   ├── safety_policies.yaml
│   ├── observability/         → Tracing and monitoring setup
│   │   ├── tracing.py         → OpenTelemetry / Langfuse setup
│   │   ├── metrics.py         → Custom metrics definitions
│   │   ├── alerts.py          → Alerting configuration
│   ├── memory/                → Memory system configuration
│   │   ├── short_term.py      → In-session memory
│   │   ├── long_term.py       → Cross-session memory store
│   │   ├── episodic.py        → Episode/event memory
│   └── utils/                 → Shared utilities
│       ├── token_budget.py    → Token counting and budget enforcement
│       ├── retry.py           → Retry and circuit breaker logic
│       ├── fallback.py        → Model and tool fallback routing
├── tests/
│   ├── unit/                  → Unit tests (tools, prompts, guardrails)
│   │   ├── tools/
│   │   ├── prompts/
│   │   ├── guardrails/
│   ├── integration/           → Integration tests (agent workflows)
│   │   ├── trajectories/      → Recorded trajectory fixtures
│   ├── evals/                 → End-to-end evaluation datasets
│   │   ├── datasets/          → Eval case JSON files
│   │   ├── runners/           → Eval runner scripts
│   ├── snapshots/             → Snapshot test references
├── scripts/
│   ├── run_agent.py           → CLI entry point for local development
│   ├── run_evals.py           → Evaluation runner
│   ├── seed_memory.py         → Seed long-term memory with initial data
├── data/                      → Raw data files (PDFs, CSVs, knowledge bases)
│   ├── knowledge/             → Knowledge source files
│   ├── eval_datasets/         → Evaluation test data
├── .env                       → Secrets and API keys (NEVER commit)
├── .env.example               → Template for required env vars
├── pyproject.toml             → Project metadata and dependencies
├── Dockerfile                 → Container definition
├── docker-compose.yml         → Local development environment
└── README.md                  → Project documentation
```

## Configuration Management

### Layered Configuration

Configuration is loaded in layers, each overriding the previous:

```
Base config (agents.yaml) → Environment override (production.yaml) → Runtime override (CLI args)
```

```python
from pathlib import Path
import yaml

class ConfigLoader:
    """Load configuration with environment overrides."""

    def __init__(self, base_dir: str = "src/config"):
        self.base_dir = Path(base_dir)

    def load(self, environment: str = "dev") -> dict:
        # Load base configuration
        base = self._load_yaml(self.base_dir / "agents.yaml")
        limits = self._load_yaml(self.base_dir / "limits.yaml")

        # Load environment-specific overrides
        env_override = self._load_yaml(self.base_dir / "environments" / f"{environment}.yaml")

        # Merge: env overrides base
        config = self._deep_merge(base, limits, env_override)
        return config

    def _deep_merge(self, *configs) -> dict:
        result = {}
        for config in configs:
            for key, value in config.items():
                if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                    result[key] = self._deep_merge(result[key], value)
                else:
                    result[key] = value
        return result

    def _load_yaml(self, path: Path) -> dict:
        if path.exists():
            return yaml.safe_load(path.read_text())
        return {}
```

### Environment-Specific Overrides

```yaml
# src/config/environments/dev.yaml
agents:
  router:
    model: gpt-4o-mini            # Cheap model for development
  researcher:
    model: gpt-4o-mini
limits:
  max_steps: 5                     # Shorter runs in dev
  budget_usd: 0.50                 # Low budget in dev
  retry_max: 1                     # Fewer retries in dev
observability:
  tracing_enabled: false            # Disable tracing in dev (save cost)

# src/config/environments/production.yaml
agents:
  router:
    model: gpt-4.1                 # Capable model in production
  researcher:
    model: claude-sonnet-4-6
limits:
  max_steps: 15                     # Longer runs allowed
  budget_usd: 5.00                 # Higher budget
  retry_max: 3                     # More retries for resilience
observability:
  tracing_enabled: true             # Enable tracing in production
  backend: langfuse                 # Use Langfuse for production traces
```

### Secrets Management

```python
# .env.example — document all required secrets
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
DATABASE_URL=postgresql://...
LANGFUSE_PUBLIC_KEY=pk-...
LANGFUSE_SECRET_KEY=sk-...

# Never hardcode secrets in code. Load from environment:
import os

API_KEYS = {
    "openai": os.environ["OPENAI_API_KEY"],
    "anthropic": os.environ["ANTHROPIC_API_KEY"],
}
DATABASE_URL = os.environ["DATABASE_URL"]

# For Docker/K8s, inject secrets via environment or secret mounts
# Never commit .env files — add .env to .gitignore
```

## Dependency Injection

Inject external dependencies (HTTP clients, database connections, LLM providers) at runtime. This enables testing with mocks and swapping providers without code changes:

```python
from dataclasses import dataclass
from httpx import AsyncClient

@dataclass
class AgentDeps:
    """Typed dependencies for the agent system."""
    http_client: AsyncClient
    db_connection: DatabaseConnection
    model_provider: ModelProvider
    api_keys: dict[str, str]

class DependencyContainer:
    """Container that creates and manages agent dependencies."""

    def __init__(self, config: dict):
        self.config = config

    def create_deps(self, environment: str = "dev") -> AgentDeps:
        return AgentDeps(
            http_client=AsyncClient(timeout=30),
            db_connection=self._create_db_connection(),
            model_provider=self._create_model_provider(),
            api_keys=self._load_api_keys(),
        )

    def create_test_deps(self) -> AgentDeps:
        """Create deps with mock clients for testing."""
        return AgentDeps(
            http_client=MockAsyncClient(),
            db_connection=MockDatabase(),
            model_provider=MockModelProvider(),
            api_keys={"openai": "mock-key"},
        )

    def _create_model_provider(self) -> ModelProvider:
        model = self.config["agents"]["default_model"]
        return ModelProvider(model=model, api_key=self._load_api_keys()[model.split(":")[0]])
```

Dependency injection rules:
- Use `@dataclass` for dependency types — simple, typed, easy to construct
- Create test dependencies with mock clients — don't use real APIs in unit tests
- Create production dependencies with real clients — don't mock in production
- Inject at the application boundary — main.py or container.py, not in agent code
- Never create clients inside agent functions — inject them from the container

## Framework-Specific Layout Variations

### LangGraph Project

```
src/
  orchestration/
    graph.py          → StateGraph definition, nodes, edges, routing
    state.py          → State TypedDict definitions
    nodes/            → One file per node function
      planner.py
      executor.py
      evaluator.py
    checkpointer.py   → Checkpointer setup (MemorySaver, SqliteSaver, PostgresSaver)
```

### CrewAI Project

```
src/
  config/
    agents.yaml       → Agent role/goal/backstory definitions
    tasks.yaml        → Task description/expected_output definitions
  orchestration/
    flow.py           → Flow class with @start, @listen, @router
    crews/            → Crew compositions
      research_crew.py
      analysis_crew.py
```

### OpenAI Agents SDK Project

```
src/
  agents/
    router.py         → Main routing agent with handoffs
    specialist_a.py   → Specialist agent definition
    specialist_b.py   → Specialist agent definition
  orchestration/
    handoffs.py       → Handoff definitions and input filters
  guardrails/
    input.py          → Input guardrail functions
    output.py         → Output guardrail functions
  sessions/
    session_store.py  → SQLite/PostgreSQL session management
```

### PydanticAI Project

```
src/
  agents/
    extractor.py      → Agent with structured output_type
    analyzer.py       → Agent with deps_type and tools
  schemas/            → Output Pydantic models (the main feature)
    extraction.py
    analysis.py
  deps/
    providers.py      → Dependency provider factories
    types.py          → @dataclass dependency definitions
```

## Production Readiness Checklist

| Item | Dev | Staging | Production |
|---|---|---|---|
| Config separated by environment | Optional | Required | Required |
| Secrets in environment variables | Optional | Required | Required |
| .env.example committed | Required | Required | Required |
| Dependency injection | Optional | Required | Required |
| Observability (tracing) | Optional | Required | Required |
| Cost tracking and limits | Optional | Required | Required |
| Guardrails (input/output) | Optional | Required | Required |
| Circuit breaker on external tools | Optional | Optional | Required |
| Health check endpoint | Optional | Required | Required |
| Dockerfile | Optional | Required | Required |
| Unit tests | Required | Required | Required |
| Integration tests | Optional | Required | Required |
| End-to-end evals | Optional | Optional | Required |

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Inline agent definitions in orchestration files | Cannot modify agents without touching orchestration | Separate into agents/ directory |
| Hardcoded API keys in source code | Security vulnerability, can't change per environment | Load from .env, inject via dependencies |
| No environment-specific config | Dev uses expensive production models, production uses dev limits | Layered config with environment overrides |
| All config in one monolithic file | Hard to review, hard to override per environment | Separate agents.yaml, limits.yaml, environments/*.yaml |
| Creating HTTP/DB clients inside agent functions | Can't test with mocks, can't swap providers | Inject via dependency container |
| No .env.example | Team members can't set up the project | Always document required environment variables |
| Mixing prompt templates with agent code | Can't review prompts independently, can't iterate quickly | Separate prompts/ directory |
| No separation between orchestration and agent logic | Changes to routing break agent definitions | Separate orchestration/ from agents/ |

## References

- `crewai-project-architecture` — CrewAI-specific project layout and conventions
- `agent-testing-debugging` — Test directory structure and CI setup
- `agent-guardrails` — Guardrail directory structure and safety policies
- `agent-observability` — Observability setup in the project structure
- `agent-cost-optimization` — Budget limits configuration in limits.yaml

## Keywords

project architecture, directory layout, configuration management, dependency injection, environment isolation, layered config, secrets management, production readiness