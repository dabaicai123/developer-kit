---
name: langgraph-patterns
description: "LangGraph framework patterns: StateGraph construction, conditional routing, ToolNode, prebuilt ReAct agent, human-in-the-loop interrupts, sub-graph composition, persistence, multi-agent supervisor/swarm, and memory. Use when building stateful agent workflows or graph-based orchestration with LangGraph."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LangGraph Patterns

Production patterns for building stateful agent workflows with LangGraph. Covers StateGraph construction, conditional routing, prebuilt agents, human-in-the-loop interrupts, sub-graph composition, persistence, and multi-agent orchestration.

## When to use this skill

- Building a StateGraph with nodes, edges, and conditional routing
- Choosing between custom StateGraph and prebuilt `create_react_agent`
- Implementing human-in-the-loop with `interrupt()` and `Command(resume=...)`
- Adding persistence with checkpointer (MemorySaver, SqliteSaver, PostgresSaver)
- Composing sub-graphs for modular agent system design
- Setting up multi-agent supervisor or swarm patterns
- Debugging agent loops that spiral, stall, or exceed context budgets

## Architecture Overview

LangGraph is a low-level orchestration framework for building stateful, multi-step agent workflows as directed graphs. Nodes are functions. Edges define transitions. State is a typed dict that persists across steps.

Three core concepts:

1. **State** — a TypedDict that every node reads and writes. State mutations are merged, not replaced.
2. **Nodes** — Python functions that receive state and return partial state updates.
3. **Edges** — transitions between nodes. Can be fixed (`add_edge`) or conditional (`add_conditional_edges`).

```python
from langgraph.graph import StateGraph, START, END
from typing import TypedDict, Annotated
import operator

class AgentState(TypedDict):
    messages: Annotated[list, operator.add]
    current_tool: str
    retry_count: int

def agent_node(state: AgentState) -> dict:
    response = model.invoke(state["messages"])
    return {"messages": [response]}

def should_continue(state: AgentState) -> str:
    if state["retry_count"] > 3:
        return "end"
    if state["current_tool"] == "search":
        return "process_search"
    return "call_llm"

builder = StateGraph(AgentState)
builder.add_node("call_llm", agent_node)
builder.add_node("process_search", search_node)
builder.add_edge(START, "call_llm")
builder.add_conditional_edges("call_llm", should_continue, {"process_search": "process_search", "end": END})
builder.add_edge("process_search", "call_llm")
graph = builder.compile()
```

## State Design

State is the backbone of every LangGraph workflow. Design it carefully.

### MessagesState (Default)

For most agent workflows, use `MessagesState` which provides a `messages` list with automatic append via `Annotated[list, operator.add]`:

```python
from langgraph.graph import MessagesState

class State(MessagesState):
    classification: str
    research: str
    analysis: str
```

### Custom State with Reducers

Reducers define how state updates merge. Without a reducer, updates replace the existing value. With `operator.add`, updates append to the list:

```python
class ResearchState(TypedDict):
    messages: Annotated[list, operator.add]   # Append new messages
    research_results: Annotated[list, operator.add]  # Append results
    final_report: str                          # Replace on each update
    step_count: int                            # Replace on each update
```

State design rules:

- Use `Annotated[list, operator.add]` for accumulating lists (messages, results, tool outputs)
- Use plain types for values that get replaced each step (current query, retry count, final result)
- Keep state minimal — only what nodes need to read or write
- Never store large objects in state — use artifact storage for big data, keep references in state

## Prebuilt Agents

### create_react_agent

The fastest way to get a working ReAct agent. One function call with model, tools, and optional prompt:

```python
from langgraph.prebuilt import create_react_agent

agent = create_react_agent(
    model=ChatAnthropic(model="claude-sonnet-4-6"),
    tools=[search_tool, calculator_tool, database_tool],
    prompt="You are a research assistant. Use tools to find and analyze information.",
)

result = agent.invoke({"messages": [{"role": "user", "content": "What is the revenue growth rate?"}]})
```

**When to use:** Simple single-agent tasks, prototyping, when you don't need custom routing logic.

**Limitations:** No conditional branching, no multi-step orchestration, no custom state beyond messages. Switch to custom StateGraph when you need any of these.

### ToolNode

Prebuilt node that executes tool calls from the last AI message. Handles tool execution, error catching, and result formatting:

```python
from langgraph.prebuilt import ToolNode

tool_node = ToolNode([search_tool, calculator_tool, database_tool])

builder = StateGraph(MessagesState)
builder.add_node("agent", agent_node)
builder.add_node("tools", tool_node)
builder.add_edge(START, "agent")
builder.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
builder.add_edge("tools", "agent")
```

**When to use:** Always use `ToolNode` for tool execution. It handles errors, parallel tool calls, and result formatting correctly. Don't write custom tool execution logic.

## Conditional Routing

Conditional edges enable branching, retry loops, and dynamic workflows. The routing function receives state and returns the name of the next node.

### Simple Conditional Routing

```python
def should_continue(state: AgentState) -> str:
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tools"
    return "end"

builder.add_conditional_edges(
    "agent",
    should_continue,
    {"tools": "tools", "end": END},
)
```

### Structured Output Routing

Use an LLM with structured output to route tasks to specialist nodes:

```python
from pydantic import BaseModel, Field
from typing import Literal

class Route(BaseModel):
    step: Literal["research", "analysis", "writing"] = Field(
        description="The next step in the workflow"
    )

router = llm.with_structured_output(Route)

def route_decision(state: State) -> str:
    decision = router.invoke([
        {"role": "system", "content": "Route the input to research, analysis, or writing."},
        {"role": "user", "content": state["input"]},
    ])
    return decision.step

builder.add_conditional_edges(
    "router",
    route_decision,
    {"research": "research_node", "analysis": "analysis_node", "writing": "writing_node"},
)
```

### Retry Loop Routing

Conditional edges that route back to earlier nodes create retry loops:

```python
def evaluate_and_route(state: AgentState) -> str:
    last_result = state["messages"][-1]
    if state["retry_count"] >= 3:
        return "finalize"
    if "correct" in last_result.content.lower():
        return "next_step"
    return "retry"

builder.add_conditional_edges(
    "evaluate",
    evaluate_and_route,
    {"next_step": "next_step_node", "retry": "agent", "finalize": "finalize_node"},
)
```

Routing rules:

- Always provide a map of possible destinations — LangGraph validates the routing function returns only valid node names
- Include END as a possible destination — every workflow must have an exit condition
- Route to END when retry limits are exceeded, budgets are spent, or the task is complete
- Never create infinite loops — every conditional edge must eventually reach END

## Human-in-the-Loop

LangGraph uses `interrupt()` to pause execution and `Command(resume=...)` to resume with human input.

### Interrupt Pattern

```python
from langgraph.types import interrupt, Command

@tool
def send_email(to: str, subject: str, body: str):
    """Send an email to a recipient."""
    response = interrupt({
        "action": "send_email",
        "to": to,
        "subject": subject,
        "body": body,
        "message": "Approve sending this email?",
    })
    if response.get("action") == "approve":
        return f"Email sent to {response.get('to', to)}"
    return "Email cancelled by user"
```

**How it works:**

1. `interrupt()` pauses the graph and surfaces the payload in `result["__interrupt__"]`
2. The host application displays the interrupt payload to the human reviewer
3. Human provides approval/rejection via `Command(resume=...)`
4. Graph resumes from the exact checkpoint where it paused

### Resuming After Interrupt

```python
# First invoke — pauses at interrupt
result = graph.invoke(
    {"messages": [{"role": "user", "content": "Send email to alice@example.com"}]},
    config={"configurable": {"thread_id": "email-1"}},
)

# Display interrupt payload to human
print(result["__interrupt__"])

# Resume with human decision
resumed = graph.invoke(
    Command(resume={"action": "approve", "subject": "Updated subject"}),
    config={"configurable": {"thread_id": "email-1"}},
)
```

Interrupt rules:

- Use interrupts for irreversible actions (delete, send, deploy, financial transactions)
- Use interrupts for low-confidence outputs (model uncertainty threshold)
- Never skip the resume step — `Command(resume=...)` is mandatory to continue execution
- Persist state with a checkpointer — interrupts require checkpoint persistence to work
- Human can edit arguments in the resume payload — not just approve/reject

## Persistence and Memory

### Checkpointer

Every stateful agent workflow needs a checkpointer for persistence. Checkpointers save state after each step, enabling interrupt/resume, time travel, and crash recovery.

| Checkpointer | Storage | Best For |
|---|---|---|
| `MemorySaver` | In-memory | Development, testing, prototyping |
| `SqliteSaver` | SQLite file | Single-process production, local persistence |
| `PostgresSaver` | PostgreSQL | Production, concurrent access, durable storage |

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver

# Development
checkpointer = MemorySaver()

# Production
import sqlite3
checkpointer = SqliteSaver(sqlite3.connect("agent-state.db"))

# Compile with checkpointer
graph = builder.compile(checkpointer=checkpointer)

# Invoke with thread_id for per-conversation persistence
config = {"configurable": {"thread_id": "user-session-42"}}
result = graph.invoke({"messages": [user_message]}, config=config)
```

### Multi-turn Conversation Memory

With a checkpointer, each `thread_id` maintains its own conversation history across invocations:

```python
# First turn
result1 = graph.invoke(
    {"messages": [{"role": "user", "content": "What is the revenue growth?"}]},
    config={"configurable": {"thread_id": "session-1"}},
)

# Second turn — same thread_id, state persists
result2 = graph.invoke(
    {"messages": [{"role": "user", "content": "Compare that to last quarter"}]},
    config={"configurable": {"thread_id": "session-1"}},
)
```

### Cross-session Long-term Memory

LangGraph supports long-term memory that persists across different thread_ids using `InMemoryStore` or external stores:

```python
from langgraph.store.memory import InMemoryStore

store = InMemoryStore()

# Store a user preference
store.put(("user", "alice"), "preferences", {"language": "en", "style": "concise"})

# Retrieve in any session
prefs = store.get(("user", "alice"), "preferences")
```

For production, use a persistent store (Postgres, Redis). Long-term memory stores stable facts (user preferences, learned patterns). Never store changing data (prices, inventory) in long-term memory — re-query at runtime.

### Time Travel

With checkpointers, you can replay, fork, and debug past executions:

```python
# Get state history
history = list(graph.get_state_history(config))

# Replay from a specific checkpoint
earlier_state = [s for s in history if s.next == ("agent",)][-1]
graph.invoke(None, earlier_state.config)

# Fork from a checkpoint with modified state
fork_config = graph.update_state(earlier_state.config, {"messages": [modified_message]})
graph.invoke(None, fork_config)
```

## Sub-graph Composition

Embed reusable sub-graphs as nodes in a parent graph. Sub-graphs are tested independently, composed modularly.

### Basic Sub-graph

```python
# Build sub-graph
def research_step_a(state):
    return {"research": search(state["input"])}

def research_step_b(state):
    return {"analysis": analyze(state["research"])}

research_subgraph = (
    StateGraph(State)
    .add_node("step_a", research_step_a)
    .add_node("step_b", research_step_b)
    .add_edge(START, "step_a")
    .add_edge("step_a", "step_b")
    .compile()  # No checkpointer — inherits from parent
)

# Embed in parent graph
builder = StateGraph(State)
builder.add_node("router", route_node)
builder.add_node("research", research_subgraph)
builder.add_node("writer", writing_node)
builder.add_edge(START, "router")
builder.add_conditional_edges("router", route_decision, {"research": "research", "writing": "writing"})
builder.add_edge("research", "writer")
builder.add_edge("writer", END)

graph = builder.compile(checkpointer=MemorySaver())
```

Sub-graph rules:

- Sub-graphs inherit the parent's checkpointer by default — don't set a separate checkpointer
- Sub-graph state must match the parent's state schema at the interface boundary
- Test sub-graphs independently before composing — each sub-graph is a standalone workflow
- Sub-graphs with `checkpointer=True` get their own checkpoint history — enables granular time travel

## Multi-Agent Patterns

### Supervisor Pattern

A supervisor agent routes tasks to specialist sub-agents:

```python
from langgraph.prebuilt import create_react_agent

researcher = create_react_agent(
    model=model,
    tools=[search_tool, web_reader_tool],
    prompt="You are a research specialist. Find and gather information.",
)

analyst = create_react_agent(
    model=model,
    tools=[calculator_tool, chart_tool],
    prompt="You are a data analyst. Analyze data and produce insights.",
)

writer = create_react_agent(
    model=model,
    tools=[writing_tool],
    prompt="You are a technical writer. Produce clear, structured reports.",
)

def supervisor_node(state: State) -> dict:
    decision = router.invoke([
        {"role": "system", "content": "Route to: researcher, analyst, or writer."},
        {"role": "user", "content": state["input"]},
    ])
    return {"decision": decision.step}

builder = StateGraph(State)
builder.add_node("supervisor", supervisor_node)
builder.add_node("researcher", researcher)
builder.add_node("analyst", analyst)
builder.add_node("writer", writer)
builder.add_conditional_edges("supervisor", route_decision, {
    "researcher": "researcher",
    "analyst": "analyst",
    "writer": "writer",
})
builder.add_edge("researcher", END)
builder.add_edge("analyst", END)
builder.add_edge("writer", END)
```

### Swarm Pattern

Agents hand off to each other based on expertise. Each agent decides whether to handle or delegate:

```python
def handoff_node(state: State) -> dict:
    last_result = state["messages"][-1].content
    if "needs analysis" in last_result.lower():
        return {"next_agent": "analyst"}
    if "needs writing" in last_result.lower():
        return {"next_agent": "writer"}
    return {"next_agent": "end"}

builder.add_conditional_edges("researcher", handoff_node, {
    "analyst": "analyst",
    "writer": "writer",
    "end": END,
})
builder.add_conditional_edges("analyst", handoff_node, {
    "writer": "writer",
    "end": END,
})
builder.add_edge("writer", END)
```

Swarm considerations: no central coordinator, harder to audit full trajectory. Prevent circular handoffs by limiting delegation chains to 3-4 hops.

## Pattern Comparison

| Pattern | LangGraph Mechanism | Best For | Complexity |
|---|---|---|---|
| Single ReAct agent | `create_react_agent` | Simple tool-calling tasks | Low |
| Custom StateGraph | `StateGraph` + nodes + edges | Multi-step workflows with routing | Medium |
| Retry loops | Conditional edges back to earlier nodes | Error recovery, self-correction | Medium |
| Human-in-the-loop | `interrupt()` + `Command(resume=...)` | Approval gates, review workflows | Medium |
| Supervisor multi-agent | Supervisor node + specialist sub-agents | Task routing to specialists | Medium-High |
| Sub-graph composition | Sub-graphs as nodes in parent graph | Modular, reusable workflows | High |
| Swarm handoff | Conditional edges between agents | Fluid delegation, overlapping roles | Medium |

## Production Checklist

- Checkpointer configured (not MemorySaver for production — use PostgresSaver or SqliteSaver)
- Thread_id per user session — state isolation between conversations
- Max step count enforced — terminate loops that exceed 10-20 iterations
- Structured error handling in every node — nodes must catch exceptions and return error state
- Interrupts configured for irreversible actions — send_email, delete, deploy require human approval
- Observability via LangSmith or Langfuse tracing — every node execution logged
- Long-term memory for cross-session preferences — `InMemoryStore` or Postgres store
- State schema minimal — only what nodes need, not the entire conversation history
- Graph visualized for debugging — `graph.get_graph().draw_mermaid_png()` shows the workflow

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| No checkpointer for production agent | State lost on crash, no interrupt/resume, no time travel | Use PostgresSaver or SqliteSaver |
| MemorySaver in production | In-memory only, lost on restart, no concurrent access | Development only; switch to durable storage for production |
| Infinite loop without step limit | Conditional edges route back to earlier nodes without a termination condition | Add retry_count to state, route to END when exceeded |
| Custom tool execution instead of ToolNode | Missing error handling, parallel call support, result formatting | Always use prebuilt `ToolNode` |
| Skipping thread_id in checkpointer invocations | All sessions share state, no isolation between users | Always set `thread_id` in config |
| Monolithic state with every field | State grows unbounded, model attention dilutes across irrelevant fields | Keep state minimal; use artifacts for large data |
| No interrupt for destructive operations | Agent executes irreversible actions without human oversight | Wrap destructive tools with `interrupt()` |
| Sub-graph with mismatched state schema | State keys don't align at boundary, data lost on transitions | Ensure sub-graph state matches parent state at the interface |

## References

- LangGraph documentation: https://langchain-ai.github.io/langgraph/
- LangGraph prebuilt agents: https://langchain-ai.github.io/langgraph/concepts/agents/
- LangGraph persistence: https://langchain-ai.github.io/langgraph/concepts/persistence/
- LangGraph interrupts: https://langchain-ai.github.io/langgraph/concepts/interrupts/
- LangGraph multi-agent: https://langchain-ai.github.io/langgraph/concepts/multi_agent/

## Related Skills

- `agent-loop-patterns` — Graph State Machine pattern (Pattern 7) is the conceptual basis for LangGraph
- `agent-memory-systems` — Memory layers for agent systems; LangGraph persistence implements Layer 0-1
- `multi-agent-orchestration` — General multi-agent patterns; LangGraph supervisor/swarm are specific implementations
- `mcp-integration` — MCP tool integration for LangGraph agents
- `agent-guardrails` — Policy-as-code and approval gates; LangGraph interrupts implement approval pattern

## Keywords

langgraph, stategraph, nodes, edges, conditional routing, create_react_agent, toolnode, interrupt, command resume, checkpointer, memorysaver, sqlitesaver, postgresaver, persistence, time travel, sub-graph, supervisor, swarm, multi-agent, long-term memory, inmemorystore