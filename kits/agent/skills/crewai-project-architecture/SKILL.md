---
name: crewai-project-architecture
description: "CrewAI-specific project architecture: optimal directory layout, YAML-first agent/task definitions, Flow+Crew composition patterns, configuration management, and production deployment structure. Use when scaffolding or restructuring a CrewAI project."
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

# CrewAI Project Architecture

Production-ready project architecture specifically for CrewAI projects. Covers the optimal directory layout, YAML-first agent/task definitions, Flow+Crew composition, configuration management, and deployment structure recommended by CrewAI conventions.

## When to use this skill

- Scaffolding a new CrewAI project from scratch
- Restructuring an existing CrewAI project for production readiness
- Deciding how to organize agents, tasks, crews, and flows
- Setting up YAML configuration for agent/task definitions
- Planning the composition of Flows and Crews in a production system

## Architecture Principles for CrewAI

| Principle | CrewAI Implication |
|---|---|
| **YAML-first definitions** | Agent roles, goals, backstories, and task descriptions defined in YAML, not Python code. Separate definition from execution. |
| **Flow wraps Crew** | In production, Flows orchestrate. Crews execute tasks within Flow steps. Never use Crew alone for production systems. |
| **One file per agent** | Each agent role has its own definition. Don't define multiple agents in one YAML section. |
| **One file per task** | Each task has its own definition. Tasks reference agents by name, not by inline definition. |
| **Config-driven composition** | Which agents work together, which tasks they handle, defined in config files. Swap agents without touching orchestration code. |
| **State in Pydantic models** | Flow state uses typed Pydantic BaseModel. Every field is explicit and validated. |

## Standard CrewAI Project Layout

```
crewai-project/
├── src/
│   ├── crewai_project/         → Main package (matches project name)
│   │   ├── agents/             → Agent definition YAML files
│   │   │   ├── researcher.yaml
│   │   │   ├── analyst.yaml
│   │   │   ├── writer.yaml
│   │   │   ├── manager.yaml
│   │   ├── tasks/              → Task definition YAML files
│   │   │   ├── research_task.yaml
│   │   │   ├── analysis_task.yaml
│   │   │   ├── writing_task.yaml
│   │   ├── crews/              → Crew composition classes
│   │   │   ├── research_crew.py    → Loads agents.yaml + tasks.yaml, creates Crew
│   │   │   ├── analysis_crew.py    → Separate crew for analysis
│   │   │   ├── writing_crew.py     → Separate crew for writing
│   │   ├── flows/              → Flow orchestration classes
│   │   │   ├── research_flow.py    → ResearchFlow with @start, @listen, @router
│   │   │   ├── report_flow.py      → Full report generation flow
│   │   ├── tools/              → Custom tool implementations
│   │   │   ├── search_tool.py
│   │   │   ├── database_tool.py
│   │   │   ├── calculator_tool.py
│   │   ├── models/             → Pydantic models for structured outputs
│   │   │   ├── research_result.py
│   │   │   ├── analysis_result.py
│   │   │   ├── report.py
│   │   ├── knowledge/          → Knowledge source configurations
│   │   │   ├── pdf_source.py
│   │   │   ├── web_source.py
│   │   ├── memory/             → Memory configuration
│   │   │   ├── memory_config.py
│   │   ├── mcps/               → MCP server connections
│   │   │   ├── mcp_config.yaml     → MCP server URLs and configs
│   │   ├── guardrails/         → Safety guardrails
│   │   │   ├── input_guardrails.py
│   │   │   ├── output_guardrails.py
│   │   ├── main.py             → Entry point: Flow kickoff, CLI interface
│   │   ├── config.py           → Config loader, environment setup
│   ├── tests/
│   │   ├── unit/               → Unit tests for tools, models
│   │   ├── integration/        → Crew and Flow integration tests
│   │   ├── evals/              → Evaluation datasets
├── .env                        → API keys (NEVER commit)
├── .env.example                → Required env var template
├── pyproject.toml              → Dependencies (crewai, crewai-tools, etc.)
├── Dockerfile                  → Production container
├── README.md                   → Project documentation
```

## YAML Agent Definitions

Define agents in YAML for separation from code. Each agent has its own file:

```yaml
# src/crewai_project/agents/researcher.yaml
role: "Senior Research Specialist"
goal: "Find comprehensive and accurate information on any topic using available search tools"
backstory: |
  You spent 10 years at a major research institution, specializing in
  literature review and data gathering. You have deep expertise in
  academic search, web research, and source verification.
  You always cite your sources and distinguish between facts and opinions.
tools:
  - search_tool
  - web_reader_tool
mcps:
  - "https://api.example.com/sse"
skills:
  - "domain-expert"
knowledge_sources:
  - pdf_corpus
verbose: true
allow_delegation: false
max_iter: 5
max_retry_limit: 2
```

```yaml
# src/crewai_project/agents/analyst.yaml
role: "Data Analysis Expert"
goal: "Analyze data, identify trends, and produce quantitative insights"
backstory: |
  Former quantitative analyst at a hedge fund with 8 years of experience
  in statistical modeling and trend identification. You spot patterns
  others miss and always verify your findings with multiple methods.
tools:
  - calculator_tool
  - database_tool
verbose: true
allow_delegation: false
```

```yaml
# src/crewai_project/agents/manager.yaml
role: "Project Manager"
goal: "Coordinate the team to deliver high-quality results on time"
backstory: |
  Experienced project manager who delegates effectively and reviews critically.
  You ensure each team member focuses on their strengths and that deliverables
  meet quality standards.
allow_delegation: true
verbose: true
```

YAML rules:
- Each agent gets its own YAML file — named by role (researcher.yaml, analyst.yaml)
- `role`, `goal`, `backstory` are always present — these define the agent's identity
- `tools`, `mcps`, `skills`, `knowledge_sources` are capability assignments — keep to 3-8 total
- `verbose: true` in development, `false` in production (config override)
- `allow_delegation: true` only for manager agents — workers should not delegate
- `max_iter` and `max_retry_limit` prevent runaway loops

## YAML Task Definitions

Define tasks in YAML separately from agents. Tasks reference agents by role name:

```yaml
# src/crewai_project/tasks/research_task.yaml
description: |
  Research {topic} thoroughly. Find at least 5 credible sources covering:
  1. Current state and recent developments
  2. Key statistics and data points
  3. Expert opinions and analysis
  4. Historical context and trends
  Provide all sources with full citations.
expected_output: |
  A comprehensive research summary with:
  - Key findings (at least 5)
  - Source citations (at least 5)
  - Data points and statistics
  - Areas of uncertainty or conflicting information
agent: "Senior Research Specialist"    → References agent by role name
async_execution: false                  → Sequential: wait for completion
output_file: "research_output.md"       → Save output to file
```

```yaml
# src/crewai_project/tasks/analysis_task.yaml
description: |
  Analyze the research findings on {topic}. Identify:
  1. Key trends and patterns
  2. Statistical significance of data points
  3. Contradictions or gaps in the research
  4. Implications and predictions
expected_output: |
  Structured analysis with:
  - Trend summary
  - Statistical validation
  - Gap analysis
  - Forward-looking implications
agent: "Data Analysis Expert"
async_execution: false
```

Task YAML rules:
- Use `{topic}` placeholders for dynamic inputs — filled at runtime via `crew.kickoff(inputs=...)`
- `agent` references the agent's `role` name — not the YAML filename
- `expected_output` describes what a good result looks like — guides the agent
- `async_execution: true` for tasks that don't depend on previous outputs
- `output_file` saves results to disk — useful for pipeline debugging

## Crew Composition Classes

Crew classes load YAML definitions and compose agents + tasks into a Crew:

```python
# src/crewai_project/crews/research_crew.py
from crewai import Agent, Crew, Process, Task
from pathlib import Path
import yaml

AGENTS_DIR = Path(__file__).parent.parent / "agents"
TASKS_DIR = Path(__file__).parent.parent / "tasks"

class ResearchCrew:
    """Research crew: researcher → analyst → writer."""

    def __init__(self):
        self.agents = self._load_agents()
        self.tasks = self._load_tasks()

    def _load_agents(self) -> dict[str, Agent]:
        """Load agent definitions from YAML."""
        agents = {}
        for yaml_file in AGENTS_DIR.glob("*.yaml"):
            config = yaml.safe_load(yaml_file.read_text())
            agent = Agent(
                role=config["role"],
                goal=config["goal"],
                backstory=config["backstory"],
                tools=self._resolve_tools(config.get("tools", [])),
                mcps=config.get("mcps", []),
                verbose=config.get("verbose", True),
                allow_delegation=config.get("allow_delegation", False),
                max_iter=config.get("max_iter", 5),
            )
            agents[config["role"]] = agent
        return agents

    def _load_tasks(self) -> dict[str, Task]:
        """Load task definitions from YAML."""
        tasks = {}
        for yaml_file in TASKS_DIR.glob("*.yaml"):
            config = yaml.safe_load(yaml_file.read_text())
            task = Task(
                description=config["description"],
                expected_output=config["expected_output"],
                agent=self.agents[config["agent"]],
                async_execution=config.get("async_execution", False),
            )
            tasks[yaml_file.stem] = task
        return tasks

    def create_crew(self) -> Crew:
        """Compose agents and tasks into a Crew."""
        return Crew(
            agents=[self.agents["Senior Research Specialist"],
                    self.agents["Data Analysis Expert"]],
            tasks=[self.tasks["research_task"],
                   self.tasks["analysis_task"]],
            process=Process.sequential,
            memory=True,
            verbose=True,
        )
```

Crew composition rules:
- Load agents and tasks from YAML — don't define inline
- Create one Crew class per workflow — research, analysis, writing are separate crews
- Each crew uses 2-3 agents — don't put all agents in one crew
- Set `process=Process.sequential` by default — use hierarchical only when a manager is needed
- Enable `memory=True` for multi-step crews — agents need context from previous steps

## Flow Orchestration Classes

Flows coordinate multiple crews with state management, routing, and error handling:

```python
# src/crewai_project/flows/research_flow.py
from crewai.flow import Flow, listen, router, start
from pydantic import BaseModel

from crewai_project.crews.research_crew import ResearchCrew
from crewai_project.crews.analysis_crew import AnalysisCrew
from crewai_project.crews.writing_crew import WritingCrew

class ResearchState(BaseModel):
    """Flow state — typed and validated."""
    topic: str = ""
    research_data: str = ""
    analysis_result: str = ""
    final_report: str = ""
    quality_score: float = 0.0
    retry_count: int = 0

class ResearchFlow(Flow[ResearchState]):
    """Orchestrate research → analysis → writing with quality gates."""

    research_crew = ResearchCrew().create_crew()
    analysis_crew = AnalysisCrew().create_crew()
    writing_crew = WritingCrew().create_crew()

    @start()
    def initiate_research(self):
        return self.state.topic

    @listen(initiate_research)
    def gather_data(self, topic: str):
        result = self.research_crew.kickoff(inputs={"topic": topic})
        self.state.research_data = result.raw
        return self.state.research_data

    @router(gather_data)
    def route_analysis(self, data: str):
        if len(data) > 5000:
            return "deep_analysis"
        if self.state.retry_count > 2:
            return "quick_analysis"  # Fallback after retries
        return "quick_analysis"

    @listen("deep_analysis")
    def deep_analysis(self):
        result = self.analysis_crew.kickoff(
            inputs={"data": self.state.research_data, "depth": "deep"}
        )
        self.state.analysis_result = result.raw
        return self.state.analysis_result

    @listen("quick_analysis")
    def quick_analysis(self):
        result = self.analysis_crew.kickoff(
            inputs={"data": self.state.research_data, "depth": "quick"}
        )
        self.state.analysis_result = result.raw
        return self.state.analysis_result

    @listen(route_analysis)
    def compile_report(self):
        report = self.writing_crew.kickoff(
            inputs={
                "analysis": self.state.analysis_result,
                "topic": self.state.topic,
            }
        )
        self.state.final_report = report.raw
        return self.state.final_report
```

Flow rules:
- Use `Pydantic BaseModel` for state — every field is typed and validated
- Each Flow step delegates to a Crew — don't embed agent logic in Flow methods
- Use `@router` for conditional branching — don't hardcode paths
- Create separate Crew instances per Flow — don't reuse Crew objects between steps
- Include retry/fallback logic in routing — `retry_count` in state enables fallback paths
- Flows handle orchestration; Crews handle execution — never mix both in one class

## Environment Configuration

```yaml
# src/crewai_project/config/environments/dev.yaml
crews:
  memory: false                    → Disable memory in dev (faster, cheaper)
  verbose: true
agents:
  default_model: gpt-4o-mini       → Cheap model for development
  max_iter: 3                      → Shorter loops in dev
limits:
  budget_usd: 0.50                 → Low budget in dev
  max_steps: 5                     → Fewer steps allowed

# src/crewai_project/config/environments/production.yaml
crews:
  memory: true                     → Enable memory in production
  verbose: false                   → Quieter logs in production
agents:
  default_model: claude-sonnet-4-6 → Capable model in production
  max_iter: 10                     → Longer loops allowed
limits:
  budget_usd: 5.00                 → Higher budget
  max_steps: 15                    → More steps allowed
observability:
  tracing: true                    → Enable tracing in production
  backend: langfuse
```

## Deployment Structure

```dockerfile
# Dockerfile for CrewAI production deployment
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml .
RUN pip install -e .

# Copy source code
COPY src/ src/

# Copy config and data
COPY data/ data/

# Set environment
ENV PYTHONPATH=/app/src
ENV CREWAI_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
  CMD python -c "from crewai_project.main import health_check; health_check()"

# Run the flow
CMD ["python", "-m", "crewai_project.main"]
```

```yaml
# docker-compose.yml for local development
services:
  agent:
    build: .
    environment:
      - CREWAI_ENV=dev
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - ./src:/app/src     → Live code reload
      - ./data:/app/data   → Data access
    ports:
      - "8000:8000"        → API endpoint

  langfuse:
    image: langfuse/langfuse:latest
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://langfuse:langfuse@db:5432/langfuse

  db:
    image: postgres:16
    environment:
      - POSTGRES_DB=langfuse
      - POSTGRES_USER=langfuse
      - POSTGRES_PASSWORD=langfuse
```

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Defining agents inline in Crew Python code | Can't modify agents without touching execution code | Use YAML files in agents/ directory |
| Defining tasks inline in Crew Python code | Can't adjust task descriptions without code changes | Use YAML files in tasks/ directory |
| Using Crew alone for production | No state persistence, no routing, no error handling | Wrap Crews in Flows for production systems |
| Mixing Flow logic with agent definitions | Orchestration and execution become tangled | Separate flows/ from agents/ and crews/ |
| No Pydantic state model for Flows | Untyped state, no validation, runtime errors | Use `Flow[BaseModel]` with typed state |
| Hardcoded model in agent YAML | Can't switch models per environment | Override model in environment config |
| Reusing Crew instances across Flow steps | Crew state leaks between steps | Create fresh Crew per Flow step |
| All agents in one Crew | Manager overloaded, workers can't specialize | 2-3 agents per Crew; use Flows for coordination |

## References

- `agent-project-architecture` — General project architecture principles
- `crewai-patterns` — CrewAI framework patterns (Crews, Flows, agents, tools)
- `agent-observability` — Observability setup for CrewAI projects
- `agent-testing-debugging` — Testing structure for CrewAI projects
- `agent-cost-optimization` — Budget limits configuration for CrewAI

## Keywords

crewai project, directory layout, YAML definitions, agent YAML, task YAML, crew composition, flow orchestration, Pydantic state, environment config, production deployment