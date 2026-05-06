---
name: agent-loop-patterns
description: "8 agent loop variants with Python code patterns: ReAct, Plan+Execute, Reflection, Compaction, Code-as-Action, Event-Driven, Graph State Machine, Heartbeat. Use when choosing an agent orchestration pattern, implementing an agent loop, or comparing loop architectures."
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

# Agent Loop Patterns

Eight production-grade agent loop variants with implementation patterns. Each pattern solves a different orchestration problem. Choose based on task complexity, context budget, and human-in-the-loop requirements.

## When to use this skill

- Choosing an agent orchestration pattern for a new agent system
- Implementing a specific agent loop variant in code
- Comparing loop architectures to find the best fit for a use case
- Extending an existing loop with reflection, compaction, or heartbeat
- Debugging agent loops that spiral, stall, or exceed context budgets

## Pattern 1: ReAct

Reason → Act → Observe. The most common and default pattern for most agents. The agent reasons about the current state, selects a tool, executes it, observes the result, and repeats.

When to use: general-purpose agents, research tasks, any scenario where the agent must decide which tool to call next based on observed results.

```python
import json

def react_loop(agent, tools, task, max_steps=10):
    context = [{"role": "user", "content": task}]
    for step in range(max_steps):
        response = agent.call(context)
        if response.finish_reason == "stop":
            return response.content
        tool_call = response.tool_calls[0]
        tool = tools.get(tool_call.name)
        if not tool:
            observation = f"Error: unknown tool {tool_call.name}"
        else:
            observation = json.dumps(tool(**tool_call.arguments))
        context.append({"role": "assistant", "content": response.content, "tool_calls": response.tool_calls})
        context.append({"role": "tool", "name": tool_call.name, "content": observation})
    return "Max steps reached without completion"
```

Key considerations:
- Each turn adds to context — budget management is critical for long tasks
- No planning phase — the agent may repeat failed strategies
- Simple to implement, easy to debug, widely supported by all frameworks

## Pattern 2: Plan+Execute

Plan the entire task first, then execute steps sequentially. The agent decomposes the task into a list of subtasks, then executes each subtask in order without replanning.

When to use: tasks with clear decomposition (Cline pattern), multi-step workflows where replanning is expensive, scenarios where the agent should commit to a plan before acting.

```python
def plan_execute_loop(agent, tools, task, max_steps=10):
    plan = agent.call([{"role": "user", "content": f"Decompose this task into steps:\n{task}"}])
    steps = parse_plan(plan.content)
    results = []
    for i, step in enumerate(steps):
        if i >= max_steps:
            break
        response = agent.call([
            {"role": "user", "content": task},
            {"role": "assistant", "content": plan.content},
            {"role": "user", "content": f"Execute step {i+1}: {step}\nPrevious results: {json.dumps(results)}"},
        ])
        if response.tool_calls:
            tool = tools.get(response.tool_calls[0].name)
            step_result = json.dumps(tool(**response.tool_calls[0].arguments))
        else:
            step_result = response.content
        results.append({"step": step, "result": step_result})
    return results
```

Key considerations:
- Planning cost is a single upfront LLM call — saves tokens on repeated reasoning
- No adaptation — if a step fails, the agent cannot replan without restarting
- Best for deterministic workflows (CI pipelines, deployment steps, data processing)
- Combine with Reflection pattern to validate each step before proceeding

## Pattern 3: Reflection

After each action, reflect on the output and validate before proceeding. The agent produces a result, then reviews it for correctness, completeness, and policy compliance.

When to use: high-stakes decisions, code generation, data transformation, any task where errors are costly and self-correction is feasible.

```python
def reflection_loop(agent, tools, task, max_steps=10, max_reflections=3):
    context = [{"role": "user", "content": task}]
    for step in range(max_steps):
        response = agent.call(context)
        if response.finish_reason == "stop":
            result = response.content
        else:
            tool_call = response.tool_calls[0]
            tool = tools.get(tool_call.name)
            result = json.dumps(tool(**tool_call.arguments))
            context.append({"role": "assistant", "content": response.content, "tool_calls": response.tool_calls})
            context.append({"role": "tool", "name": tool_call.name, "content": result})
        for _ in range(max_reflections):
            reflection = agent.call([
                {"role": "user", "content": f"Review this result for errors, completeness, and policy compliance:\n{result}\nTask: {task}"},
            ])
            if "no issues found" in reflection.content.lower():
                break
            context.append({"role": "assistant", "content": reflection.content})
            context.append({"role": "user", "content": "Fix the identified issues and try again."})
            response = agent.call(context)
            result = response.content if response.finish_reason == "stop" else json.dumps(
                tools[response.tool_calls[0].name](**response.tool_calls[0].arguments)
            )
        return result
    return "Max steps reached"
```

Key considerations:
- Each reflection doubles the LLM calls — budget impact is significant
- Reflection quality depends on the model's ability to critique its own output
- Best combined with ReAct — reflect after key steps, not every step
- Define explicit reflection criteria (correctness, completeness, policy, style)

## Pattern 4: Compaction

When context exceeds a threshold, compress it before continuing. The agent summarizes the conversation history to free up context budget, then continues with the compressed history.

When to use: long-running tasks (Claude Code pattern), agents that exceed context window limits, scenarios where the task requires many sequential tool calls.

```python
def compaction_loop(agent, tools, task, max_steps=10, context_budget=8000):
    context = [{"role": "user", "content": task}]
    for step in range(max_steps):
        current_tokens = estimate_tokens(context)
        if current_tokens > context_budget:
            summary = agent.call([
                {"role": "system", "content": "Summarize the conversation so far. Preserve: completed steps, key results, pending tasks, tool outputs needed for remaining steps."},
                {"role": "user", "content": json.dumps([m["content"] for m in context])},
            ])
            context = [
                {"role": "system", "content": "This is a compressed summary of prior work."},
                {"role": "assistant", "content": summary.content},
                {"role": "user", "content": f"Continue the task. Original task: {task}"},
            ]
        response = agent.call(context)
        if response.finish_reason == "stop":
            return response.content
        tool_call = response.tool_calls[0]
        tool = tools.get(tool_call.name)
        observation = json.dumps(tool(**tool_call.arguments))
        context.append({"role": "assistant", "content": response.content, "tool_calls": response.tool_calls})
        context.append({"role": "tool", "name": tool_call.name, "content": observation})
    return "Max steps reached"
```

Key considerations:
- Compaction loses detail — the agent may forget specific tool outputs it needs later
- Preserve critical data in the summary: completed steps, key results, pending tasks
- Re-inject task instructions after compaction — they get "centrifuged" away
- Threshold choice matters — compact too early wastes LLM calls, too late exceeds the window

## Pattern 5: Code-as-Action

The agent writes and executes Python code instead of making individual tool calls. Each action is a code block that the runtime executes, returning the output to the agent.

When to use: data analysis, mathematical computation, batch operations, tasks where composing multiple tool calls in code is more efficient than calling them one at a time (CodeAct pattern).

```python
import subprocess
import tempfile

def code_act_loop(agent, task, max_steps=10):
    context = [{"role": "user", "content": task}]
    for step in range(max_steps):
        response = agent.call(context)
        code_blocks = extract_code_blocks(response.content)
        if not code_blocks:
            if "TASK_COMPLETE" in response.content:
                return response.content
            context.append({"role": "user", "content": "Write Python code to solve the next step. Use print() to output results."})
            continue
        execution_results = []
        for code in code_blocks:
            with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False) as f:
                f.write(code)
                f.flush()
                result = subprocess.run(["python", f.name], capture_output=True, text=True, timeout=30)
                output = result.stdout if result.returncode == 0 else f"Error:\n{result.stderr}"
                execution_results.append(output)
        combined_output = "\n".join(execution_results)
        context.append({"role": "assistant", "content": response.content})
        context.append({"role": "user", "content": f"Execution output:\n{combined_output}\nContinue with the next step, or write TASK_COMPLETE if done."})
    return "Max steps reached"

def extract_code_blocks(text):
    blocks = []
    in_block = False
    current = []
    for line in text.split("\n"):
        if line.strip().startswith("```python"):
            in_block = True
            current = []
        elif line.strip() == "```" and in_block:
            in_block = False
            blocks.append("\n".join(current))
        elif in_block:
            current.append(line)
    return blocks
```

Key considerations:
- Sandbox execution — never run agent-generated code without isolation (Docker, restricted interpreter)
- Timeout every execution — agent code may loop infinitely
- Code is more composable than individual tool calls — batch operations, loops, conditional logic
- Risk of arbitrary code execution — security guardrails are mandatory

## Pattern 6: Event-Driven

Async workflow where steps trigger on events rather than following a fixed sequence. Steps are connected by event emissions and subscriptions, not by a hardcoded loop.

When to use: multi-step async workflows (LlamaIndex Workflows, CrewAI Flows), I/O-heavy tasks with variable timing, workflows where steps depend on external triggers.

```python
import asyncio

class EventEmitter:
    def __init__(self):
        self.handlers = {}

    def on(self, event_name, handler):
        self.handlers.setdefault(event_name, []).append(handler)

    def emit(self, event_name, data):
        for handler in self.handlers.get(event_name, []):
            asyncio.create_task(handler(data))

class EventDrivenAgent:
    def __init__(self, agent, tools):
        self.agent = agent
        self.tools = tools
        self.emitter = EventEmitter()
        self._register_handlers()

    def _register_handlers(self):
        self.emitter.on("task_received", self._plan)
        self.emitter.on("plan_ready", self._execute_step)
        self.emitter.on("step_completed", self._evaluate)
        self.emitter.on("evaluation_pass", self._next_step)
        self.emitter.on("evaluation_fail", self._retry_step)
        self.emitter.on("all_steps_done", self._finalize)

    async def _plan(self, task):
        plan = await self.agent.call_async([{"role": "user", "content": task}])
        self.steps = parse_plan(plan.content)
        self.current_step = 0
        self.results = []
        self.emitter.emit("plan_ready", {"plan": self.steps})

    async def _execute_step(self, data):
        step = self.steps[self.current_step]
        response = await self.agent.call_async([
            {"role": "user", "content": f"Execute: {step}\nPrevious results: {json.dumps(self.results)}"},
        ])
        result = response.content
        self.emitter.emit("step_completed", {"step": step, "result": result})

    async def _evaluate(self, data):
        reflection = await self.agent.call_async([
            {"role": "user", "content": f"Is this result correct?\nStep: {data['step']}\nResult: {data['result']}"},
        ])
        if "correct" in reflection.content.lower():
            self.results.append(data)
            self.emitter.emit("evaluation_pass", data)
        else:
            self.emitter.emit("evaluation_fail", data)

    async def _next_step(self, data):
        self.current_step += 1
        if self.current_step < len(self.steps):
            self.emitter.emit("plan_ready", {"plan": self.steps})
        else:
            self.emitter.emit("all_steps_done", {"results": self.results})

    async def _retry_step(self, data):
        self.emitter.emit("plan_ready", {"plan": self.steps})

    async def _finalize(self, data):
        return data["results"]

    async def run(self, task):
        self.emitter.emit("task_received", task)
```

Key considerations:
- Steps are decoupled — easy to add, remove, or reorder without changing the core loop
- State must be persisted between events — use a shared state object or external store
- Error handling per event — each handler must catch and emit error events
- Debugging is harder — trace all event emissions and subscriptions for observability

## Pattern 7: Graph State Machine

Nodes as functions, edges as conditional transitions, shared state object. The agent proceeds through a directed graph where each node is a processing step and edges define conditional transitions.

When to use: complex workflows with conditional branching (LangGraph pattern), state machines with well-defined states, workflows that need cycles (retry loops, review loops).

```python
from typing import TypedDict, Annotated
import operator

class AgentState(TypedDict):
    task: str
    plan: list[str]
    current_step: int
    step_results: Annotated[list, operator.add]
    final_result: str
    retry_count: int

def plan_node(state: AgentState) -> AgentState:
    response = agent.call([{"role": "user", "content": f"Plan steps for: {state['task']}"}])
    return {"plan": parse_plan(response.content), "current_step": 0, "step_results": [], "retry_count": 0}

def execute_node(state: AgentState) -> AgentState:
    step = state["plan"][state["current_step"]]
    response = agent.call([
        {"role": "user", "content": f"Execute step {state['current_step']+1}: {step}"},
        {"role": "user", "content": f"Previous results: {json.dumps(state['step_results'])}"},
    ])
    return {"step_results": [{"step": step, "result": response.content}]}

def evaluate_node(state: AgentState) -> AgentState:
    last_result = state["step_results"][-1]
    reflection = agent.call([
        {"role": "user", "content": f"Is this correct? Step: {last_result['step']}, Result: {last_result['result']}"},
    ])
    if "correct" in reflection.content.lower():
        return {"retry_count": 0}
    return {"retry_count": state["retry_count"] + 1}

def route_after_evaluate(state: AgentState) -> str:
    if state["retry_count"] >= 3:
        return "finalize"
    if state["retry_count"] > 0:
        return "execute"
    if state["current_step"] + 1 < len(state["plan"]):
        return "next_step"
    return "finalize"

def next_step_node(state: AgentState) -> AgentState:
    return {"current_step": state["current_step"] + 1}

def finalize_node(state: AgentState) -> AgentState:
    return {"final_result": json.dumps(state["step_results"])}

GRAPH = {
    "plan": {"next": "execute"},
    "execute": {"next": "evaluate"},
    "evaluate": {"route": route_after_evaluate},
    "next_step": {"next": "execute"},
    "finalize": {"next": None},
}

def run_graph(graph, initial_state):
    state = initial_state
    current_node = "plan"
    while current_node:
        node_fn = NODES[current_node]
        updates = node_fn(state)
        state = {**state, **updates}
        node_config = graph[current_node]
        if "route" in node_config:
            current_node = node_config["route"](state)
        else:
            current_node = node_config.get("next")
    return state["final_result"]

NODES = {
    "plan": plan_node,
    "execute": execute_node,
    "evaluate": evaluate_node,
    "next_step": next_step_node,
    "finalize": finalize_node,
}
```

Key considerations:
- State is explicit and typed — every node reads and writes to a shared TypedDict
- Conditional routing enables complex workflows: branching, retry loops, parallel paths
- Cycles are natural — retry loops are edges that route back to earlier nodes
- Visual representation — graph structure maps directly to a state diagram for debugging

## Pattern 8: Heartbeat

Periodic agent wake-up for monitoring, scheduled tasks, or continuous operations. The agent is triggered at intervals, checks conditions, performs actions, and returns to sleep.

When to use: monitoring agents, scheduled reports, continuous data processing, health checks, alerting systems.

```python
import time
import schedule

class HeartbeatAgent:
    def __init__(self, agent, tools, interval_seconds=300):
        self.agent = agent
        self.tools = tools
        self.interval = interval_seconds
        self.last_state = None

    def tick(self):
        current_conditions = self._check_conditions()
        prompt = [
            {"role": "system", "content": "You are a monitoring agent. Check conditions, decide if action is needed, and act."},
            {"role": "user", "content": f"Current conditions:\n{json.dumps(current_conditions)}\nPrevious state:\n{json.dumps(self.last_state) if self.last_state else 'None'}"},
        ]
        response = self.agent.call(prompt)
        if response.tool_calls:
            for tc in response.tool_calls:
                tool = self.tools.get(tc.name)
                if tool:
                    result = json.dumps(tool(**tc.arguments))
                    prompt.append({"role": "tool", "name": tc.name, "content": result})
        self.last_state = current_conditions
        self.last_state["last_action"] = response.content
        self.last_state["tick_time"] = time.strftime("%Y-%m-%dT%H:%M:%SZ")

    def _check_conditions(self):
        conditions = {}
        for name, tool in self.tools.items():
            if hasattr(tool, "check"):
                conditions[name] = tool.check()
        return conditions

    def run(self):
        schedule.every(self.interval).seconds.do(self.tick)
        while True:
            schedule.run_pending()
            time.sleep(1)

    def run_once(self):
        self.tick()
```

Key considerations:
- State persistence is mandatory — the agent must compare current vs previous conditions
- Tick interval must match task urgency — too slow misses events, too fast wastes resources
- Heartbeat agents must handle empty conditions gracefully — no action is a valid outcome
- Combine with Event-Driven pattern — heartbeat checks emit events for downstream handlers

## Comparison Table

| Pattern | Best For | Context Strategy | Multi-Step | Human-in-the-Loop |
|---|---|---|---|---|
| ReAct | General-purpose tasks, research, tool selection | Accumulates per turn, compact when budget exceeded | Yes, sequential | Optional (approval gates) |
| Plan+Execute | Deterministic workflows, CI pipelines, deployment | Plan upfront, execute results inline | Yes, pre-planned | Optional (approve plan first) |
| Reflection | High-stakes decisions, code generation, data transformation | Doubles per reflective turn | Yes, with validation loops | Implicit (self-review) |
| Compaction | Long-running tasks, large tool call sequences | Compress when threshold exceeded, re-inject task | Yes, indefinite | Optional |
| Code-as-Action | Data analysis, computation, batch operations | Code + output per step, compact intermediate | Yes, iterative | Mandatory (sandbox approval) |
| Event-Driven | Async workflows, I/O-heavy tasks, external triggers | State persisted between events | Yes, decoupled | Via event handlers |
| Graph State Machine | Complex branching workflows, retry loops, conditional paths | Shared state object, nodes update in place | Yes, with cycles | Via conditional routing |
| Heartbeat | Monitoring, scheduled tasks, continuous operations | Compare current vs previous state per tick | Recurring | Alert-based (notify on anomaly) |

## Selection Guide

Start with ReAct for most agents. Add patterns as concrete needs arise:

1. Long tasks exceed context → add Compaction
2. Errors are costly → add Reflection
3. Task is deterministic → switch to Plan+Execute
4. Workflow has conditional branches → switch to Graph State Machine
5. Steps are async or externally triggered → switch to Event-Driven
6. Agent needs computation → add Code-as-Action
7. Agent runs continuously → use Heartbeat

Never combine more than 2-3 patterns. Each pattern adds complexity and token cost.

## References

- LangGraph State Machine: https://langchain-ai.github.io/langgraph/
- LlamaIndex Workflows: https://docs.llamaindex.ai/en/stable/module_guides/workflow/
- CrewAI Flows: https://docs.crewai.com/concepts/flows
- CodeAct Paper: https://arxiv.org/abs/2402.01030
- ReAct Paper: https://arxiv.org/abs/2210.03629