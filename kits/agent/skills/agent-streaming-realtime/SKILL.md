---
name: agent-streaming-realtime
description: "Streaming and real-time patterns for agent systems: SSE/WebSocket response streaming, progressive result delivery, real-time collaboration, mid-stream interruption, and server-sent events. Use when building agents that stream responses, handle real-time interactions, or support WebSocket connections."
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

# Agent Streaming & Real-time

Patterns for streaming agent responses in real-time to clients, handling mid-stream interruptions, and building WebSocket/SSE-based agent interfaces.

## When to use this skill

- Building an agent that streams responses token-by-token to a frontend
- Setting up WebSocket connections for real-time agent interactions
- Handling user interruptions while the agent is generating a response
- Implementing progressive result delivery for long-running agent tasks
- Choosing between SSE and WebSocket for agent client communication
- Building agents that need real-time state updates (progress bars, step indicators)

## Streaming Architecture

Agent streaming has two layers:

1. **LLM streaming** — tokens arrive incrementally from the model provider
2. **Agent streaming** — steps, tool calls, and final results are streamed to the client as they happen

Most frameworks only handle LLM streaming. Agent streaming requires custom implementation that wraps the LLM stream with step-level events.

## Transport Comparison

| Transport | Direction | Best For | Complexity |
|---|---|---|---|
| SSE (Server-Sent Events) | Server → Client only | Streaming agent responses to frontend | Low |
| WebSocket | Bidirectional | Real-time interaction with interruptions | Medium |
| HTTP polling | Client → Server → Client | Simple status updates for long tasks | Low (but inefficient) |

Use SSE for most agent streaming. Use WebSocket when the client needs to interrupt or send messages during agent execution. Never use polling — it wastes resources and adds latency.

## SSE Streaming Pattern

Stream agent events to a frontend using Server-Sent Events. Each event is a typed JSON payload:

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import json

app = FastAPI()

@app.post("/agent/run")
async def run_agent_stream(task: str):
    """Stream agent execution events via SSE."""
    return StreamingResponse(
        _agent_event_stream(task),
        media_type="text/event-stream",
    )

async def _agent_event_stream(task: str):
    """Yield SSE events as the agent executes."""
    # Event 1: Start
    yield f"event: start\ndata: {json.dumps({'task': task, 'timestamp': now()})}\n\n"

    agent = Agent(model=model, tools=tools)

    for step_result in agent.run_streaming(task):
        # Event 2: LLM token stream
        if step_result.type == "token":
            yield f"event: token\ndata: {json.dumps({'content': step_result.content})}\n\n"

        # Event 3: Tool call started
        elif step_result.type == "tool_start":
            yield f"event: tool_start\ndata: {json.dumps({'tool': step_result.tool_name, 'args': step_result.args})}\n\n"

        # Event 4: Tool result
        elif step_result.type == "tool_result":
            yield f"event: tool_result\ndata: {json.dumps({'tool': step_result.tool_name, 'result': step_result.result})}\n\n"

        # Event 5: Step complete
        elif step_result.type == "step_complete":
            yield f"event: step_complete\ndata: {json.dumps({'step': step_result.step_number, 'summary': step_result.summary})}\n\n"

        # Event 6: Error
        elif step_result.type == "error":
            yield f"event: error\ndata: {json.dumps({'error': step_result.error, 'step': step_result.step_number})}\n\n"

    # Event 7: Done
    yield f"event: done\ndata: {json.dumps({'total_steps': step_count, 'total_cost': total_cost})}\n\n"
```

SSE event types for agents:

| Event | Purpose | Client Action |
|---|---|---|
| `start` | Agent run begins | Show loading spinner, lock input |
| `token` | LLM token arrives | Append to response display |
| `tool_start` | Tool execution begins | Show tool call indicator |
| `tool_result` | Tool returns result | Display tool result or hide indicator |
| `step_complete` | A step finishes | Update progress counter |
| `thought` | Agent reasoning (optional) | Show reasoning in collapsible section |
| `error` | Step or tool error | Display error, allow retry |
| `interrupt` | Agent pauses for human input | Show approval/rejection UI |
| `done` | Agent run completes | Unlock input, show final result |

## WebSocket Streaming Pattern

Bidirectional streaming for interactive agents. Client can interrupt, send new messages, or approve/reject tool calls during execution:

```python
from fastapi import FastAPI, WebSocket

app = FastAPI()

@app.websocket("/agent/ws")
async def agent_websocket(ws: WebSocket):
    await ws.accept()

    try:
        while True:
            # Receive task from client
            data = await ws.receive_json()

            if data["type"] == "task":
                # Run agent with streaming, sending events back
                for event in agent.run_streaming(data["task"]):
                    await ws.send_json(event.dict())

                    # Check for client interruption
                    try:
                        interrupt = await ws.receive_json(timeout=0)
                        if interrupt["type"] == "cancel":
                            agent.cancel()
                            await ws.send_json({"type": "cancelled"})
                            break
                        if interrupt["type"] == "approve":
                            agent.resume(interrupt["payload"])
                    except TimeoutError:
                        pass  # No interruption, continue

            elif data["type"] == "cancel":
                agent.cancel()

    except WebSocketDisconnect:
        agent.cancel()
```

### Client-Side WebSocket Handler

```javascript
class AgentWebSocket {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      switch (data.type) {
        case "token": appendToResponse(data.content); break;
        case "tool_start": showToolIndicator(data.tool); break;
        case "tool_result": hideToolIndicator(data.tool); break;
        case "interrupt": showApprovalDialog(data); break;
        case "done": finalizeResponse(data); break;
        case "error": showError(data.error); break;
      }
    };
  }

  sendTask(task) {
    this.ws.send(JSON.stringify({ type: "task", task }));
  }

  approveInterrupt(payload) {
    this.ws.send(JSON.stringify({ type: "approve", payload }));
  }

  cancel() {
    this.ws.send(JSON.stringify({ type: "cancel" }));
  }
}
```

## Progressive Result Delivery

For long-running agents, deliver partial results progressively instead of waiting for full completion:

```python
class ProgressiveAgent:
    """Delivers intermediate results as they become available."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run_with_progress(self, task: str, callback: callable):
        """Run agent, calling callback with progressive results."""
        plan = self._plan(task)
        callback(ProgressEvent(type="plan", content=plan))

        results = []
        for i, step in enumerate(plan):
            result = self._execute_step(step, results)
            results.append(result)
            callback(ProgressEvent(
                type="partial_result",
                step=i + 1,
                total_steps=len(plan),
                content=result,
            ))

        final = self._synthesize(results)
        callback(ProgressEvent(type="final_result", content=final))
        return final


# Frontend usage — show partial results as they arrive
async def handle_agent_events():
    for event in agent.run_with_progress(task, lambda e: event_queue.put(e)):
        if event.type == "plan":
            display_plan(event.content)  # Show planned steps
        elif event.type == "partial_result":
            update_progress(event.step, event.total_steps)
            display_partial_result(event.content)  # Show intermediate findings
        elif event.type == "final_result":
            display_final_result(event.content)  # Show synthesized result
```

Progressive delivery rules:
- Send the plan first — clients can show what the agent will do
- Send each step result immediately — don't batch until the end
- Include step number and total steps — clients can show progress bars
- Synthesize a final result at the end — partial results are not the final answer
- For RAG agents, send retrieved documents before the analysis — users can start reading early

## Mid-Stream Interruption

Handle user interruptions during agent execution. The agent must detect, acknowledge, and adjust:

```python
class InterruptibleAgent:
    """Agent that can be interrupted mid-stream."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools
        self._cancelled = False

    def cancel(self):
        self._cancelled = True

    def run(self, task: str, interrupt_check: callable = None):
        context = [{"role": "user", "content": task}]
        for step in range(self.max_steps):
            if self._cancelled:
                return self._graceful_shutdown(context)

            # Check for external interruption (WebSocket message, etc.)
            if interrupt_check and interrupt_check():
                return self._graceful_shutdown(context)

            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                return response.content
            # Process tool calls...

        return "Max steps reached"

    def _graceful_shutdown(self, context):
        """Provide a meaningful partial result when interrupted."""
        last_content = context[-1]["content"] if context else "No results yet"
        return AgentResult(
            status="interrupted",
            partial_result=last_content,
            steps_completed=len(context) // 2,
            message="Agent was interrupted. Partial results available.",
        )
```

Interruption handling rules:
- Never lose work on interruption — always return partial results
- Set a cancellation flag that each step checks — don't rely on exceptions alone
- Provide graceful shutdown: partial result, step count, and interruption reason
- Clean up resources on interruption: close connections, release locks, cancel sub-tasks
- For WebSocket, send a "cancelled" event with partial results before closing
- For SSE, send an "interrupted" event with partial results and close the stream

## Framework-Specific Streaming

### LangGraph Streaming

```python
from langgraph.graph import StateGraph, MessagesState, START, END

graph = builder.compile()

# Stream tokens
for chunk in graph.stream(
    {"messages": [{"role": "user", "content": "Analyze the data"}]},
    stream_mode="values",
):
    print(chunk["messages"][-1].content)

# Stream events (more granular)
for event in graph.stream(
    {"messages": [{"role": "user", "content": "Analyze the data"}]},
    stream_mode="updates",
):
    for node_name, node_output in event.items():
        print(f"Node {node_name}: {node_output}")

# Stream custom events
for event in graph.astream_events(
    {"messages": [{"role": "user", "content": "Analyze the data"}]},
    version="v2",
):
    kind = event["event"]
    if kind == "on_chat_model_stream":
        print(event["data"]["chunk"].content, end="")
    elif kind == "on_tool_start":
        print(f"Tool call: {event['data']['input']}")
    elif kind == "on_tool_end":
        print(f"Tool result: {event['data']['output']}")
```

### OpenAI Agents SDK Streaming

```python
from agents import Agent, Runner

agent = Agent(name="Assistant", instructions="...")

result = Runner.run_streamed(agent, messages=[{"role": "user", "content": "Hello"}])

async for event in result.stream_events():
    if event.type == "raw_model_event":
        # Token-level streaming
        print(event.data.content, end="")
    elif event.type == "agent_updated_stream_event":
        # Agent handoff happened
        print(f"Switched to agent: {event.new_agent.name}")
    elif event.type == "run_item_stream_event":
        # Tool call or message produced
        if event.item.type == "tool_call_item":
            print(f"Tool call: {event.item.tool_name}")
        elif event.item.type == "tool_call_output_item":
            print(f"Tool result: {event.item.output}")
```

### PydanticAI Streaming

```python
from pydantic_ai import Agent

agent = Agent("openai:gpt-4.1")

async with agent.run_stream("Analyze the market trends") as stream:
    # Token-level streaming
    async for token in stream.stream_text():
        print(token, end="", flush=True)

    # Or get the full result at the end
    result = await stream.get_result()
    print(result.output)
```

### CrewAI Streaming

```python
from crewai import Crew, Agent, Task

crew = Crew(agents=[researcher, writer], tasks=[research_task, write_task])

# Stream via kickoff
result = crew.kickoff()

# For async streaming
result = await crew.akickoff()

# CrewAI streams via callbacks or integration with Langfuse/LangSmith
# Use the event stream from CrewAI's internal trace for custom SSE output
```

## Real-time Collaboration Patterns

For agents that work alongside humans in real-time:

```python
class CollaborativeAgent:
    """Agent that works alongside a human, streaming partial work for review."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    async def collaborative_run(self, task: str, ws: WebSocket):
        """Stream work to human, accept corrections mid-stream."""
        # Step 1: Stream the plan for review
        plan = await self._plan_async(task)
        await ws.send_json({"type": "plan_proposal", "steps": plan})

        # Wait for human approval or modification
        human_response = await ws.receive_json()
        if human_response["type"] == "plan_modify":
            plan = human_response["modified_plan"]

        # Step 2: Execute steps, streaming each result
        for i, step in enumerate(plan):
            result = await self._execute_step_async(step)
            await ws.send_json({
                "type": "step_result",
                "step": i + 1,
                "result": result,
            })

            # Allow human to correct between steps
            try:
                correction = await asyncio.wait_for(ws.receive_json(), timeout=1.0)
                if correction["type"] == "step_correction":
                    result = correction["correction"]
            except asyncio.TimeoutError:
                pass  # No correction, continue

        # Step 3: Synthesize and stream final result
        final = await self._synthesize_async(plan, results)
        await ws.send_json({"type": "final_result", "result": final})
```

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Waiting for full completion before sending results | Users stare at a spinner for minutes | Send progressive results as they arrive |
| Using HTTP polling for real-time updates | Wasteful, high latency, poor UX | Use SSE or WebSocket |
| No cancellation mechanism | Long agent runs can't be stopped | Add cancel flag and graceful shutdown |
| Losing work on interruption | User cancels and gets nothing | Return partial results on cancellation |
| Streaming raw LLM tokens without structure | Frontend can't distinguish tokens from tool calls | Use typed events (token, tool_start, tool_result, done) |
| WebSocket without reconnect logic | Connection drops, agent state lost | Add reconnect with session resumption |
| No timeout on SSE/WebSocket connections | Connections hang forever | Set server-side timeout (30-60s idle) |
| Streaming all tool results to frontend | Sensitive data exposed, noise for users | Only stream user-relevant events; log internally |

## References

- `agent-human-interaction` — Human-in-the-loop patterns for collaborative agent workflows
- `agent-loop-patterns` — Event-driven loop pattern (Pattern 6) for async streaming
- `agent-error-recovery` — Handling failures during streaming execution
- `agent-observability` — Tracing streamed agent runs for debugging
- `langgraph-patterns` — LangGraph `stream()` and `astream_events()` for streaming
- `openai-agents-pydantic-ai` — Framework-specific streaming APIs

## Keywords

streaming, real-time, SSE, WebSocket, progressive result delivery, mid-stream interruption, token streaming, event streaming, collaborative agent, FastAPI, bidirectional communication