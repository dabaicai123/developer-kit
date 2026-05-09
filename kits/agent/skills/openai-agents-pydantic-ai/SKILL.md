---
name: openai-agents-pydantic-ai
description: "OpenAI Agents SDK and PydanticAI framework patterns: agent definition, handoffs, tools, guardrails, structured output, streaming, dependencies, and tracing. Use when building agents with OpenAI Agents SDK or PydanticAI."
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

# OpenAI Agents SDK & PydanticAI

Two lightweight, production-oriented agent frameworks. OpenAI Agents SDK provides multi-agent orchestration with handoffs and guardrails. PydanticAI provides type-safe agents with structured output and dependency injection.

## When to use this skill

- Building agents with the OpenAI Agents SDK (handoffs, guardrails, tracing)
- Building agents with PydanticAI (structured output, dependencies, type safety)
- Choosing between OpenAI Agents SDK, PydanticAI, and other frameworks
- Implementing multi-agent handoff patterns
- Using structured output (Pydantic models) as agent result types
- Setting up agent tracing and observability

## Framework Comparison

| Feature | OpenAI Agents SDK | PydanticAI |
|---|---|---|
| **Philosophy** | Minimal primitives for multi-agent orchestration | Type-safe, structured, dependency-injected |
| **Language** | Python + JS/TS | Python only |
| **Models** | OpenAI + Anthropic + others via providers | OpenAI, Anthropic, Gemini, Ollama, Groq, Mistral |
| **Agent definition** | Name, instructions, tools, handoffs, guardrails | Model, instructions, tools, deps_type, output_type |
| **Multi-agent** | Handoffs (native) + agent-as-tool | Delegation via tools (manual) |
| **Structured output** | Via output_type parameter | Via output_type (Pydantic model) — primary feature |
| **Guardrails** | Input + output guardrails (native) | Manual (validate output schema) |
| **Streaming** | Runner.run_streamed() | agent.run_stream() |
| **Tracing** | Built-in (automatic) | Via Logfire integration |
| **Dependencies** | Context dict (flexible but untyped) | deps_type (typed, injected via RunContext) |
| **Persistence** | Sessions (SQLite/PostgreSQL) | Manual (tool-based) |
| **Best for** | Multi-agent systems, customer support, task routing | Structured extraction, typed pipelines, validation-heavy |

Choose OpenAI Agents SDK for multi-agent workflows with handoffs. Choose PydanticAI for single-agent tasks requiring strong type guarantees and structured output.

## OpenAI Agents SDK

### Agent Definition

Agents are defined by name, instructions, tools, handoffs, and optional guardrails:

```python
from agents import Agent, function_tool

@function_tool
def get_weather(city: str) -> str:
    """Get the weather for a given city."""
    return f"The weather in {city} is sunny."

@function_tool
def search_database(query: str) -> str:
    """Search the internal database."""
    return f"Results for: {query}"

agent = Agent(
    name="Assistant",
    instructions="You are a helpful assistant. Use tools to find information.",
    tools=[get_weather, search_database],
    model="gpt-4.1",
)
```

### Handoffs

Handoffs allow agents to delegate to other agents. The main agent decides when to hand off based on the user's request:

```python
from agents import Agent
from agents.extensions.handoff_prompt import prompt_with_handoff_instructions

spanish_agent = Agent(
    name="Spanish",
    handoff_description="Handles Spanish language queries.",
    instructions=prompt_with_handoff_instructions(
        "You're speaking to a human, so be polite and concise. Speak in Spanish.",
    ),
    model="gpt-4.1-mini",
)

research_agent = Agent(
    name="Researcher",
    handoff_description="Handles research and data analysis queries.",
    instructions=prompt_with_handoff_instructions(
        "You research topics thoroughly using available tools.",
    ),
    model="gpt-4.1",
    tools=[search_database],
)

main_agent = Agent(
    name="Router",
    instructions=prompt_with_handoff_instructions(
        "Route the user's request to the appropriate specialist. "
        "If the user speaks Spanish, hand off to the Spanish agent. "
        "If the user needs research, hand off to the Researcher.",
    ),
    model="gpt-4.1",
    handoffs=[spanish_agent, research_agent],
)
```

Handoff rules:
- Use `handoff_description` to tell the routing agent when to hand off
- Use `prompt_with_handoff_instructions` — it adds handoff instructions to the agent's prompt automatically
- Each handoff agent should have a clear scope — don't create overlapping agents
- Limit handoffs to 2-3 per run — more creates confusion and adds latency
- The routing agent is typically a cheap model (Mini) — routing is simple classification

### Agent as Tool

Transform an agent into a tool that another agent can call. Useful when you need a sub-agent to handle a specific subtask:

```python
# Convert an agent into a callable tool
research_tool = research_agent.as_tool(
    tool_name="research",
    tool_description="Research a topic and return findings.",
)

# Use in another agent
supervisor = Agent(
    name="Supervisor",
    instructions="Use the research tool to find information, then synthesize answers.",
    tools=[research_tool],
)
```

### Guardrails

Input and output guardrails validate agent behavior. Input guardrails check the user's request before processing. Output guardrails check the agent's response before returning:

```python
from agents import Agent, InputGuardrail, OutputGuardrail, GuardrailFunctionOutput

def check_pii(context, agent, input):
    """Block requests containing personal information."""
    has_pii = any(pattern in input for pattern in ["@email", "SSN", "phone number"])
    return GuardrailFunctionOutput(
        output_info={"has_pii": has_pii},
        tripwire_triggered=has_pii,
    )

def check_tone(context, agent, output):
    """Ensure output is professional and not harmful."""
    harmful_patterns = ["insult", "threat", "offensive"]
    has_harmful = any(pattern in output.lower() for pattern in harmful_patterns)
    return GuardrailFunctionOutput(
        output_info={"harmful": has_harmful},
        tripwire_triggered=has_harmful,
    )

agent = Agent(
    name="Support",
    instructions="Provide helpful customer support.",
    input_guardrails=[InputGuardrail(guardrail_function=check_pii)],
    output_guardrails=[OutputGuardrail(guardrail_function=check_tone)],
)
```

### Running Agents

```python
from agents import Runner

# Simple run
result = Runner.run(agent, messages=[{"role": "user", "content": "What's the weather in Paris?"}])
print(result.final_output)

# Streaming run
result = Runner.run_streamed(agent, messages=[{"role": "user", "content": "Hello"}])
async for event in result.stream_events():
    if event.type == "raw_model_event":
        print(event.data.content, end="")
    elif event.type == "run_item_stream_event":
        if event.item.type == "tool_call_item":
            print(f"Tool: {event.item.tool_name}")

# With configuration
from agents import RunConfig

config = RunConfig(
    model="gpt-4.1-mini",  # Override model for all agents in this run
    tracing_disabled=False,
    workflow_name="Customer support workflow",
)
result = Runner.run(agent, messages=user_messages, run_config=config)
```

### Tracing

OpenAI Agents SDK provides built-in tracing. Every run generates a trace with spans for each agent step, tool call, and handoff:

```python
from agents import trace

# Tracing is automatic with Runner.run()
# Access traces in the OpenAI dashboard or export to external systems

# Custom trace group for multi-step workflows
with trace("Research workflow", group_id="session-42"):
    result = Runner.run(main_agent, messages=user_messages)
```

### Sessions

Sessions provide persistent memory for multi-turn conversations:

```python
from agents import SQLiteSession

session = SQLiteSession("user-session-42")

# First turn — session stores state
result1 = Runner.run(agent, messages=[{"role": "user", "content": "Hello"}], session=session)

# Second turn — session history is preserved
result2 = Runner.run(agent, messages=[{"role": "user", "content": "What did I ask earlier?"}], session=session)
```

## PydanticAI

### Agent Definition

PydanticAI agents are defined with model, instructions, output type, and dependencies:

```python
from pydantic_ai import Agent

agent = Agent(
    'openai:gpt-4.1',
    system_prompt='Be concise, reply with one sentence.',
)
```

### Structured Output

The primary feature of PydanticAI. Define a Pydantic model as the output type and the agent validates and returns typed responses:

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class AnalysisResult(BaseModel):
    summary: str
    key_findings: list[str]
    confidence: float
    recommendations: list[str]

agent = Agent(
    'openai:gpt-4.1',
    output_type=AnalysisResult,
    instructions='Analyze the provided data and return structured findings.',
)

result = agent.run_sync("Analyze Q3 revenue data: revenue=$10M, growth=15%, margin=22%")
print(result.output)
# AnalysisResult(summary='Q3 shows strong growth', key_findings=['15% YoY growth'], confidence=0.85, recommendations=['Invest in growth channels'])
```

### Tools with Dependencies

Inject typed dependencies into tools via `RunContext`. Dependencies are provided at runtime, not defined statically:

```python
from dataclasses import dataclass
from httpx import AsyncClient
from pydantic_ai import Agent, RunContext

@dataclass
class Deps:
    client: AsyncClient
    api_key: str

agent = Agent(
    'openai:gpt-4.1',
    deps_type=Deps,
    instructions='Use tools to fetch real-time data.',
)

@agent.tool
async def fetch_stock_price(ctx: RunContext[Deps], symbol: str) -> str:
    """Get the current stock price for a symbol."""
    response = await ctx.deps.client.get(
        f"https://api.example.com/stocks/{symbol}",
        headers={"Authorization": f"Bearer {ctx.deps.api_key}"},
    )
    return response.json()["price"]

# Run with injected dependencies
async with AsyncClient() as client:
    deps = Deps(client=client, api_key="sk-...")
    result = await agent.run("What is AAPL price?", deps=deps)
```

Dependency injection rules:
- Use `@dataclass` for dependencies — simple, typed, no Pydantic validation overhead
- Inject external clients (HTTP, DB) as dependencies — don't create them inside tools
- Pass secrets (API keys) via dependencies — never hardcode in tools
- Use `RunContext[Deps]` as the first argument in every tool — PydanticAI injects it automatically
- Dependencies are per-run, not per-agent — different runs can use different dependency instances

### Dynamic System Prompts

```python
from pydantic_ai import Agent, RunContext

@dataclass
class Deps:
    user_name: str
    user_role: str

agent = Agent('openai:gpt-4.1', deps_type=Deps)

@agent.system_prompt
async def add_user_context(ctx: RunContext[Deps]) -> str:
    return f"You are assisting {ctx.deps.user_name}, who is a {ctx.deps.user_role}."

@agent.system_prompt
def add_instructions() -> str:
    return "Be concise and professional."
```

### Streaming

```python
# Token-level streaming
async with agent.run_stream("Analyze the market") as stream:
    async for token in stream.stream_text():
        print(token, end="", flush=True)

# Structured streaming (stream partial output as it builds)
async with agent.run_stream("Analyze the market") as stream:
    async for partial in stream.stream_text(debounce_by=0.1):
        print(partial)

# Get full result at the end
    result = await stream.get_result()
    print(result.output)  # Full AnalysisResult object
```

### Retry and Error Handling

```python
agent = Agent(
    'openai:gpt-4.1',
    retries=2,  # Retry on model errors
    output_type=AnalysisResult,
)

# Custom model settings per run
result = await agent.run(
    "Analyze the data",
    model_settings={"temperature": 0, "max_tokens": 1024},
)
```

### Observability with Logfire

```python
import logfire
from pydantic_ai import Agent

logfire.configure(service_name='my-agent')
logfire.instrument_pydantic_ai()

agent = Agent('openai:gpt-4.1')
# All agent calls are automatically traced in Logfire
result = agent.run_sync("Hello")
```

## Selection Guide

| Use Case | Recommended Framework | Why |
|---|---|---|
| Multi-agent routing (customer support, triage) | OpenAI Agents SDK | Native handoffs, built-in guardrails |
| Structured data extraction | PydanticAI | Pydantic output_type, type validation |
| Type-safe pipeline (extraction → validation → transform) | PydanticAI | Dependency injection, typed deps |
| Simple chat agent | Either | Both handle basic chat equally well |
| Agent with multiple handoff targets | OpenAI Agents SDK | Handoff is a core primitive |
| Agent that needs strict output schema | PydanticAI | Output validation is the primary feature |
| Production monitoring and tracing | OpenAI Agents SDK | Built-in tracing, no extra setup |
| Custom observability (Logfire, Phoenix) | PydanticAI | Logfire integration is native |

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Using OpenAI Agents SDK for simple extraction | No structured output validation, more overhead than needed | Use PydanticAI with output_type for extraction tasks |
| Using PydanticAI for multi-agent routing | No native handoff mechanism, must build manually | Use OpenAI Agents SDK with handoffs for routing |
| More than 3 handoff targets per agent | Agent can't route effectively, latency increases | Use 2-3 clear handoff targets; add more via agent-as-tool |
| Untyped dependencies in PydanticAI | Lose type safety, the framework's main benefit | Always use deps_type and RunContext[Deps] |
| Skipping guardrails on production agents | Unsafe outputs reach users | Add input/output guardrails for production |
| Not using sessions for multi-turn conversations | Agent has no context across turns | Use SQLiteSession or custom session store |
| Hardcoding API keys in tools | Security vulnerability | Inject via dependencies (PydanticAI) or environment variables |

## References

- OpenAI Agents SDK documentation: https://openai.github.io/openai-agents-python/
- PydanticAI documentation: https://ai.pydantic.dev/
- `agent-guardrails` — General guardrail patterns (both frameworks implement these)
- `agent-observability` — Tracing and monitoring patterns
- `multi-agent-orchestration` — General multi-agent patterns (OpenAI Agents SDK handoffs implement supervisor/swarm)
- `agent-cost-optimization` — Model routing strategies applicable to both frameworks

## Keywords

openai agents sdk, pydanticai, handoffs, guardrails, structured output, dependency injection, run context, agent as tool, sessions, tracing, logfire, model providers