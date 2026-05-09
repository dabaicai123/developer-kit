---
name: multi-agent-orchestration
description: "Multi-agent orchestration patterns: supervisor, swarm, hierarchical, pipeline, parallel fan-out/fan-in, and sub-graph. Use when designing multi-agent systems, choosing orchestration patterns, or implementing agent handoffs."
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

# Multi-Agent Orchestration

Choose the right orchestration pattern for multi-agent systems. Context isolation is the primary reason for sub-agents, not parallelism.

## When to Use This Skill

- Deciding between orchestration patterns for a multi-agent workflow
- Implementing agent handoffs, state passing, or context sharing
- Sizing the number of agents for a task
- Building sub-graph workflows or reusable agent compositions
- Integrating agents across different frameworks

## Why Multi-Agent: Context Isolation First

Anthropic measured a 90.2% improvement when using sub-agents for context isolation versus stuffing everything into a single prompt. The primary reason for sub-agents is giving each agent a fresh context window, preventing interference between tasks.

Single-agent problems that multi-agent solves:

| Problem | Multi-Agent Solution |
|---|---|
| Context window overflow | Each agent gets a dedicated window for its task |
| Instruction interference | Separate system prompts per agent, no cross-contamination |
| Tool scope confusion | Each agent has a focused tool set relevant to its role |
| Task sequencing errors | Orchestrator manages task order, agents handle execution |
| Debugging difficulty | Trace per agent makes failure diagnosis tractable |

More agents do not mean more parallelism. More agents mean more focused context.

## Six Orchestration Patterns

### Pattern 1: Supervisor

A single coordinator agent routes tasks to specialist agents. The supervisor decides which agent handles each step and collects results.

**When to use**: Clear task decomposition, distinct specialist roles, central decision-making needed.

```python
from crewai import Agent, Task, Crew, Process

supervisor = Agent(
    role="Task Router",
    goal="Break down requests and assign them to the right specialist",
    backstory="You coordinate tasks between specialists based on their expertise.",
    tools=[delegate_tool],
)

researcher = Agent(role="Researcher", goal="Find relevant information", tools=[search_tool])
analyst = Agent(role="Analyst", goal="Analyze data and produce insights", tools=[analysis_tool])

crew = Crew(
    agents=[supervisor, researcher, analyst],
    tasks=[routing_task, research_task, analysis_task],
    process=Process.hierarchical,
    manager_agent=supervisor,
)
```

Considerations: Supervisor adds latency for routing decisions. Supervisor can become a bottleneck if task volume is high. Risk of supervisor misrouting tasks to wrong specialists.

### Pattern 2: Swarm

Agents hand off to each other based on expertise. No central coordinator. Each agent decides whether to handle the task or pass it to a more suitable agent.

**When to use**: Fluid task boundaries, agents with overlapping capabilities, minimal orchestration overhead.

```python
from llama_index.core.agent import AgentRunner

research_agent = AgentRunner.from_tools(
    [search_tool, handoff_to_analyst_tool],
    system_prompt="Research information. If analysis is needed, hand off to analyst.",
)

analyst_agent = AgentRunner.from_tools(
    [analysis_tool, handoff_to_writer_tool],
    system_prompt="Analyze data. If writing is needed, hand off to writer.",
)

writer_agent = AgentRunner.from_tools(
    [writing_tool],
    system_prompt="Write final reports. This is the terminal agent.",
)
```

Considerations: No central failure point. Handoff chains can be unpredictable. Harder to audit full trajectory without a coordinator trace. Risk of circular handoffs between agents.

### Pattern 3: Hierarchical

Manager delegates to sub-managers, who delegate to workers. Tree structure with clear authority and scope boundaries.

**When to use**: Large task trees, department-like organization, strict scope boundaries per level.

```python
from crewai import Agent, Task, Crew, Process

project_manager = Agent(
    role="Project Manager",
    goal="Coordinate the overall project and delegate to sub-managers",
)

research_manager = Agent(
    role="Research Manager",
    goal="Coordinate research tasks and delegate to researchers",
)

senior_researcher = Agent(
    role="Senior Researcher",
    goal="Deep-dive research on specific topics",
)

junior_researcher = Agent(
    role="Junior Researcher",
    goal="Gather basic information and preliminary data",
)

crew = Crew(
    agents=[project_manager, research_manager, senior_researcher, junior_researcher],
    tasks=[project_task, research_coordination_task, deep_research_task, preliminary_research_task],
    process=Process.hierarchical,
    manager_agent=project_manager,
)
```

Considerations: Clear scope per level. Adds latency through management layers. Overhead increases with depth -- 3+ levels is rarely justified. Risk of sub-managers making decisions that conflict with top-level goals.

### Pattern 4: Pipeline

Sequential chain where each agent processes the output of the previous one. A produces output, B transforms it, C finalizes it.

**When to use**: Linear workflows with clear transformation stages, deterministic processing order.

```python
from crewai import Agent, Task, Crew, Process

extractor = Agent(
    role="Data Extractor",
    goal="Extract raw data from sources",
    tools=[database_tool, file_reader_tool],
)

transformer = Agent(
    role="Data Transformer",
    goal="Clean, normalize, and structure extracted data",
    tools=[processing_tool],
)

reporter = Agent(
    role="Report Generator",
    goal="Produce final report from processed data",
    tools=[writing_tool, chart_tool],
)

crew = Crew(
    agents=[extractor, transformer, reporter],
    tasks=[extraction_task, transformation_task, reporting_task],
    process=Process.sequential,
)
```

Considerations: Simple and predictable. Each agent has a focused, well-defined input/output contract. Failure at any stage stops the entire pipeline. No parallelism or dynamic routing. Best for deterministic, linear workflows.

### Pattern 5: Parallel Fan-out/Fan-in

Send the same task to multiple agents simultaneously, then collect and merge results.

**When to use**: Multiple perspectives needed on the same input, independent verification, speed through parallelism.

```python
from crewai import Agent, Task, Crew

perspective_agents = [
    Agent(role="Legal Analyst", goal="Assess legal implications", tools=[legal_search_tool]),
    Agent(role="Financial Analyst", goal="Assess financial implications", tools=[financial_data_tool]),
    Agent(role="Technical Analyst", goal="Assess technical feasibility", tools=[tech_search_tool]),
]

parallel_tasks = [
    Task(description=f"Analyze {input_data} from {agent.role} perspective", agent=agent)
    for agent in perspective_agents
]

synthesizer = Agent(
    role="Synthesizer",
    goal="Merge all analysis perspectives into a unified report",
    tools=[merge_tool],
)

synthesis_task = Task(
    description="Merge the legal, financial, and technical analyses",
    agent=synthesizer,
)

crew = Crew(
    agents=perspective_agents + [synthesizer],
    tasks=parallel_tasks + [synthesis_task],
    process=Process.parallel_then_consolidate,
)
```

Considerations: Fast for independent tasks. Synthesis agent must handle conflicting perspectives. All parallel agents must complete before fan-in proceeds. Cost scales linearly with agent count. Best for review, verification, and multi-perspective analysis.

### Pattern 6: Sub-graph

Reusable graph workflows embedded as nodes in a larger agent graph. A sub-graph is a complete workflow that can be invoked as a single step.

**When to use**: Reusable workflow components, complex nested workflows, modular agent system design.

```python
from langgraph.graph import StateGraph, END

def build_research_subgraph():
    graph = StateGraph(ResearchState)
    graph.add_node("search", search_step)
    graph.add_node("evaluate", evaluate_sources_step)
    graph.add_node("synthesize", synthesize_step)
    graph.add_edge("search", "evaluate")
    graph.add_conditional_edges("evaluate", should_continue, {"continue": "search", "done": "synthesize"})
    graph.add_edge("synthesize", END)
    return graph.compile()

def build_main_graph():
    graph = StateGraph(MainState)
    graph.add_node("router", route_task)
    graph.add_node("research_subgraph", build_research_subgraph())
    graph.add_node("writer", writing_step)
    graph.add_edge("router", "research_subgraph")
    graph.add_edge("research_subgraph", "writer")
    graph.add_edge("writer", END)
    return graph.compile()
```

Considerations: Maximum modularity and reuse. Sub-graphs can be tested independently. Adds complexity to state management between sub-graph and main graph. Best for systems with recurring workflow patterns.

## Pattern Comparison

| Pattern | Coordination | Best For | Complexity | Context Strategy |
|---|---|---|---|---|
| Supervisor | Central coordinator | Clear task routing, distinct specialists | Low-Medium | Supervisor holds overview, specialists hold task context |
| Swarm | Self-organizing handoff | Fluid tasks, overlapping capabilities | Low | Each agent holds own context, handoff carries summary |
| Hierarchical | Tree of managers | Large task trees, strict scope | Medium-High | Per-level context scope, top holds global, bottom holds detail |
| Pipeline | Sequential chain | Linear transformation workflows | Low | Each agent processes previous output, fresh context per stage |
| Parallel Fan-out/Fan-in | Fork + merge | Multi-perspective analysis, verification | Medium | Each parallel agent holds own perspective, synthesizer holds all |
| Sub-graph | Nested workflows | Reusable components, modular systems | High | Sub-graph has internal state, main graph passes inputs/outputs |

## State Passing Patterns

### 1. Shared State Object (LangGraph)

All agents read and write to a shared state object. State is typed and versioned.

```python
from typing import TypedDict, Annotated
from langgraph.graph import StateGraph

class AgentState(TypedDict):
    task: str
    research_results: list[str]
    analysis_result: str
    final_output: str

def research_step(state: AgentState) -> AgentState:
    results = search_tool(state["task"])
    return {"research_results": results}

def analysis_step(state: AgentState) -> AgentState:
    analysis = analyze(state["research_results"])
    return {"analysis_result": analysis}
```

Best for: LangGraph workflows, state that accumulates across steps, strongly typed state transitions.

### 2. Message Passing (CrewAI Delegation)

Agents communicate through explicit delegation messages with task descriptions and context.

```python
from crewai import Agent

researcher = Agent(
    role="Researcher",
    tools=[search_tool, delegate_tool],
    backstory="Research information and delegate analysis tasks when needed.",
)
```

Best for: CrewAI flows, task-oriented communication, clear delegation semantics.

### 3. Artifact Passing (Task Outputs as Next Task Inputs)

Each task produces an artifact (document, data structure) that becomes the input for the next task. No shared state; pure data flow.

Best for: Pipeline patterns, deterministic data transformations, audit-friendly workflows.

### 4. Handoff with Context Summary (OpenAI Agents SDK)

When an agent hands off to another, it provides a summary of its work and the current context. The receiving agent starts with a fresh context window plus the summary.

Best for: Swarm patterns, long-running conversations, context window management across handoffs.

## A2A Protocol

Google's Agent-to-Agent (A2A) protocol v0.3 enables inter-agent communication across different frameworks. Key concepts:

- **Agent Card**: JSON descriptor published by each agent declaring its capabilities, skills, and authentication requirements
- **Task lifecycle**: Create task, send message, get task status, receive artifacts
- **Message format**: Structured message with text parts, data parts, and file parts
- **Artifact delivery**: Final outputs delivered as structured artifacts with metadata

A2A enables agents built with different frameworks (CrewAI, LangGraph, LlamaIndex, custom) to communicate through a standard protocol rather than framework-specific APIs.

## Sizing Guidance

| Task Complexity | Recommended Agent Count | Examples |
|---|---|---|
| Simple, focused | 1-2 agents | Single researcher, data extractor |
| Standard workflow | 2-4 agents | Researcher + analyst + writer, supervisor + 2 specialists |
| Complex multi-stage | 5-8 agents | Hierarchical team, pipeline with parallel review |
| Enterprise system | 10+ agents (rare) | Department-scale automation, multi-domain processing |

More agents means more coordination overhead, more latency, more cost, and more failure modes. Start with fewer agents and add sub-agents only when context isolation demonstrably improves results.

## Anti-Patterns

- 20+ agents for a single task -- coordination overhead exceeds task complexity; redesign into fewer, more focused agents
- Shared mutable state without locks -- concurrent agent writes to the same state cause race conditions; use typed state transitions or artifact passing
- No handoff protocol between agents -- undefined handoff semantics lead to dropped context and failed transitions
- Adding agents for parallelism when context isolation is not needed -- use a single agent with a longer context window instead
- Every agent has every tool -- defeats the purpose of specialization; give each agent only the tools it needs
- Orchestration agent doing substantive work -- the coordinator should route, not execute; mixing roles creates confusion

## References

- LangGraph Multi-Agent: https://langchain-ai.github.io/langgraph/concepts/multi_agent/
- CrewAI Flows: https://docs.crewai.com/concepts/flows
- OpenAI Agents SDK: https://openai.github.io/openai-agents-python/
- A2A Protocol: https://github.com/google/A2A
- Anthropic Multi-Agent Blog: https://www.anthropic.com/engineering/building-effective-agents