---
name: crewai-patterns
description: "CrewAI framework patterns: Crews for role-based agent teams, Flows for production orchestration, agent definition, tool/MCP/Skill integration, memory, and async execution. Use when building multi-agent systems with CrewAI."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# CrewAI Patterns

Production patterns for building role-based autonomous agent teams with CrewAI. Covers Crews (task execution), Flows (orchestration), agent definition, and integration with MCPs and Skills.

## When to use this skill

- Defining agents with roles, goals, and backstory for CrewAI
- Composing Crews (sequential or hierarchical) for multi-agent task execution
- Building Flows for event-driven production orchestration
- Integrating MCPs, Skills, and external tools into agents
- Configuring memory, planning, or human-in-the-loop for Crews
- Choosing between Crews alone vs Flows + Crews for a production system

## Architecture Overview

CrewAI has two core primitives:

- **Crews** — role-based autonomous teams that execute complex tasks. A Crew is a group of Agents working together through a defined process (sequential or hierarchical).
- **Flows** — event-driven production orchestration that manages state and control flow. Flows coordinate Crews, handle conditional routing, and provide the scaffolding that production systems need.

In production, Flows manage the pipeline. Crews execute the heavy lifting within Flow steps.

| Primitive | Purpose | Use Alone? |
|---|---|---|
| Crew | Execute a multi-agent task | Yes, for simple one-shot tasks |
| Flow | Orchestrate state, routing, error handling | No — Flows typically contain Crews |
| Flow + Crew | Production-ready multi-agent system | Yes — this is the recommended pattern |

## Agent Definition

An Agent is defined by three behavioral properties plus five capability types:

**Behavioral properties:**

- `role` — what the agent does (e.g., "Senior Data Analyst")
- `goal` — what the agent aims to achieve (e.g., "Uncover hidden trends in datasets")
- `backstory` — context that shapes reasoning style (e.g., "10 years at a top firm, specializes in anomaly detection")

**Capability types — distinguish Action vs Context:**

| Type | Category | Purpose | Example |
|---|---|---|---|
| Tools | Action | Functions the agent can call | `search_tool`, `calculator_tool` |
| MCPs | Action | Remote tool servers via MCP protocol | `["https://api.example.com/sse"]` |
| Apps | Action | SaaS integrations (pre-built) | GitHub App, Jira App |
| Skills | Context | Expertise delivered via SKILL.md files | `["domain-expert"]` |
| Knowledge | Context | RAG data sources for retrieval | PDF corpus, vector DB |

Action capabilities let the agent do things. Context capabilities give the agent information to reason better. Keep the distinction clear: too many action capabilities overwhelms the model; too few context capabilities produces shallow reasoning.

```python
from crewai import Agent

analyst = Agent(
    role="Senior Data Analyst",
    goal="Uncover hidden trends and anomalies in datasets",
    backstory="You spent 10 years at a quantitative hedge fund analyzing market data. You spot patterns others miss.",
    tools=[search_tool, calculator_tool],
    mcps=["https://api.example.com/sse"],
    skills=["data-analysis"],
    knowledge_sources=[pdf_corpus],
    verbose=True,
)
```

## Crew Composition

A Crew defines which agents work together and how they coordinate:

**Sequential process** — agents execute tasks in linear order. Each agent completes its task before the next one starts. Simple and predictable.

```yaml
crew:
  name: research_crew
  process: sequential
  agents:
    - researcher
    - analyst
    - writer
  tasks:
    - research_task
    - analysis_task
    - writing_task
```

**Hierarchical process** — a manager agent coordinates the other agents. The manager delegates tasks, reviews outputs, and makes final decisions. Use for complex tasks requiring judgment about which agent should handle which subtask.

```yaml
crew:
  name: research_crew
  process: hierarchical
  manager_agent: project_manager
  agents:
    - researcher
    - analyst
    - writer
  tasks:
    - research_task
    - analysis_task
    - writing_task
```

```python
from crewai import Agent, Crew, Process

manager = Agent(
    role="Project Manager",
    goal="Coordinate the team to deliver high-quality research reports",
    backstory="Expert project manager who delegates effectively and reviews critically.",
    allow_delegation=True,
)

researcher = Agent(
    role="Research Specialist",
    goal="Find comprehensive and accurate information",
    backstory="Seasoned researcher with deep web search expertise.",
    tools=[search_tool],
)

analyst = Agent(
    role="Data Analyst",
    goal="Analyze data and identify trends",
    backstory="Quantitative analyst with statistical modeling skills.",
    tools=[calculator_tool, database_tool],
)

writer = Agent(
    role="Technical Writer",
    goal="Transform analysis into clear, structured reports",
    backstory="Published author who excels at making complex topics accessible.",
)

crew = Crew(
    agents=[manager, researcher, analyst, writer],
    process=Process.hierarchical,
    manager_agent=manager,
)
```

**YAML configuration is preferred over inline Python.** YAML separates definition from code, making it easier to modify agent composition without touching logic. Define agents and tasks in `config/agents.yaml` and `config/tasks.yaml`, then load them in Python.

## Flow Design

Flows provide event-driven orchestration for production systems. They manage state transitions, conditional routing, and error handling that Crews alone cannot provide.

**Core decorators:**

- `@start` — marks the entry point of a Flow. The decorated method runs first.
- `@listen` — connects a method to listen for events from another method. Runs when the source method emits an event.
- `@router` — conditional branching. Returns a method name to route to, enabling dynamic paths based on intermediate results.

```python
from crewai.flow import Flow, listen, router, start
from pydantic import BaseModel

class ResearchState(BaseModel):
    topic: str = ""
    research_data: str = ""
    analysis_result: str = ""
    final_report: str = ""

class ResearchFlow(Flow[ResearchState]):
    @start()
    def initiate_research(self):
        self.state.topic = "AI market trends 2026"
        return self.state.topic

    @listen(initiate_research)
    def gather_data(self, topic):
        result = research_crew.kickoff(inputs={"topic": topic})
        self.state.research_data = result.raw
        return self.state.research_data

    @router(gather_data)
    def route_analysis(self, data):
        if len(data) > 5000:
            return "deep_analysis"
        return "quick_analysis"

    @listen("deep_analysis")
    def deep_analysis(self):
        result = analysis_crew.kickoff(inputs={"data": self.state.research_data})
        self.state.analysis_result = result.raw
        return self.state.analysis_result

    @listen("quick_analysis")
    def quick_analysis(self):
        result = quick_analysis_crew.kickoff(inputs={"data": self.state.research_data})
        self.state.analysis_result = result.raw
        return self.state.analysis_result

    @listen(route_analysis)
    def compile_report(self):
        report = writer_crew.kickoff(inputs={
            "analysis": self.state.analysis_result,
            "topic": self.state.topic,
        })
        self.state.final_report = report.raw
        return self.state.final_report

flow = ResearchFlow()
result = flow.kickoff()
```

**Logical operators for combining listeners:**

- `or_(method_a, method_b)` — listen to either event
- `and_(method_a, method_b)` — listen to both events (waits for both to complete)

```python
from crewai.flow import Flow, listen, or_, and_, start

class ParallelFlow(Flow):
    @start()
    def trigger(self):
        return "start"

    @listen(trigger)
    def fetch_a(self):
        return "data_a"

    @listen(trigger)
    def fetch_b(self):
        return "data_b"

    @listen(and_(fetch_a, fetch_b))
    def combine_results(self, results):
        return f"{results[0]} + {results[1]}"
```

## Memory

CrewAI provides four memory types. Enable with `memory=True` on the Crew:

| Type | What it stores | When to enable |
|---|---|---|
| Short-term | Recent conversation context within a task | Default (always on with `memory=True`) |
| Long-term | Facts and learnings persisted across runs | When agents need knowledge from past executions |
| Entity | Key entities (people, organizations, concepts) | When tracking specific entities across tasks |
| Contextual | Semantic summaries of past interactions | When agents need distilled context, not raw history |

```python
crew = Crew(
    agents=[researcher, analyst, writer],
    tasks=[research_task, analysis_task, writing_task],
    memory=True,
)
```

For production, configure a persistent embedder for long-term memory. Default uses OpenAI embeddings; swap to local models for cost control.

## Planning

AgentPlanner creates a step-by-step execution plan before the agent starts working. Useful for complex tasks where ordering matters. Enable with `planning=True` on the Crew.

```python
crew = Crew(
    agents=[researcher, analyst],
    tasks=[complex_task],
    planning=True,
)
```

The planner generates a plan, then each agent follows the planned steps instead of improvising. Use for tasks with known dependencies. Skip for simple or creative tasks where improvisation is better.

## Human-in-the-Loop

CrewAI supports human oversight through callbacks and delegation:

```python
from crewai import Agent, Crew

def human_review_callback(task_output):
    approved = input(f"Review this output:\n{task_output}\nApprove? (y/n): ")
    return approved.lower() == "y"

writer = Agent(
    role="Writer",
    goal="Draft content for review",
    backstory="Content creator who submits drafts for approval.",
    human_input=True,
)

crew = Crew(
    agents=[writer],
    tasks=[writing_task],
    full_output=True,
)
```

For hierarchical Crews, the manager agent can delegate to human agents for approval gates.

## Async Execution

Two async modes for different contexts:

```python
result = await crew.akickoff(inputs={"topic": "AI trends"})
```

- `akickoff()` — native async. Use when your application is already async (FastAPI, asyncio event loop).
- `kickoff_async()` — thread-based async. Use when mixing sync and async, or in frameworks that do not support native async.

For Flows:

```python
result = await flow.akickoff()
```

## Crews Alone vs Flows + Crews

| Scenario | Recommendation | Reason |
|---|---|---|
| One-shot task, no state management | Crew alone | Simpler, no overhead |
| Linear pipeline with no branching | Crew alone | Sequential process handles this |
| Multi-step pipeline with conditional routing | Flow + Crew | Router handles branching |
| Parallel execution with result merging | Flow + Crew | `or_`/`and_` listeners coordinate |
| Error handling and retry logic | Flow + Crew | Flow methods can catch and retry |
| Production deployment with audit trail | Flow + Crew | Flow state persists, tracks execution |
| Any system that needs to run more than once | Flow + Crew | State management, reproducibility |

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Crew without Flow for production | No state persistence, no error handling, no routing | Wrap Crews in Flows for production |
| 10+ tools on a single agent | Model cannot choose effectively; tool selection degrades | 3-8 tools max; use sub-agents for tool isolation |
| Skipping `reasoning` for complex tasks | Agent improvises instead of planning | Enable `planning=True` for complex tasks |
| YAML definitions mixed with Python logic | Hard to maintain, unclear boundaries | YAML for definition, Python for orchestration |
| Ignoring memory configuration | Agents lose context, repeat work | Enable memory and choose the right type for your use case |
| Running `kickoff()` in async frameworks | Blocks the event loop | Use `akickoff()` for native async contexts |

## References

- CrewAI documentation: https://docs.crewai.com
- Agent YAML configuration: `config/agents.yaml` pattern from `agent-project-structure` rule
- MCP integration: `mcp-integration` skill for connecting remote tool servers

## Related Skills

- `mcp-integration` — Connecting MCP tool servers to CrewAI agents
- `agent-context-management` — Context window compression strategies for long-running Crews
- `multi-agent-orchestration` — General multi-agent patterns beyond CrewAI

## Keywords

crewai, crews, flows, agent definition, role goal backstory, sequential process, hierarchical process, mcp integration, skills, memory, planning, human-in-the-loop, async execution, router, listener