---
name: agent-observability
description: "OpenTelemetry-based observability for agent systems. Use when building, deploying, or debugging agent tracing, logging, cost tracking, or alerting."
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

# Agent Observability

Instrument agent systems with structured tracing, cost tracking, and alerting from day one.

## When to Use This Skill

- Setting up tracing and logging for a new agent project
- Adding cost tracking or token accounting to an existing agent
- Debugging agent failures by replaying trace data
- Building dashboards for agent performance and reliability
- Configuring alerting for cost anomalies or error spikes

## Minimum Viable Observability

Every agent system must emit these signals before leaving development:

| Signal | What to Capture | Why |
|---|---|---|
| Trace ID | Unique ID per agent run | Correlate all steps of one invocation |
| LLM input/output | Full prompt text and completion per step | Debug incorrect reasoning or hallucinations |
| Tool call log | Tool name, full input args, full output | Audit tool usage and detect misuse |
| Token count + cost | Input tokens, output tokens, dollar cost per call | Track spending and enforce budgets |
| Latency per step | Wall-clock time for each LLM/tool call | Identify bottlenecks and degradation |
| Structured error log | Exception type, message, step context | Fast root-cause analysis |

If any of these are missing, the agent is not ready for production.

## OpenTelemetry GenAI Conventions

Use the OpenTelemetry GenAI semantic conventions to produce standard-compliant traces:

| Span Type | Span Name | Key Attributes |
|---|---|---|
| LLM call | `llm_call` | `gen_ai.system`, `gen_ai.request.model`, `gen_ai.response.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` |
| Tool call | `tool_call` | `tool.name`, `tool.args`, `tool.result`, `tool.status` |
| Retrieval | `retrieval` | `retrieval.source`, `retrieval.query`, `retrieval.document_count` |
| Rerank | `rerank` | `rerank.model`, `rerank.top_k`, `rerank.score_threshold` |
| Generate | `generate` | `gen_ai.system`, `gen_ai.request.model`, `gen_ai.output_type` |

Group all spans under a single trace per agent run. Add a `session.id` attribute to correlate multi-turn conversations. Mask sensitive attributes (API keys, user PII) before export.

### Setting Up OpenTelemetry Spans for an Agent Run

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPGrpcExporter

tracer_provider = TracerProvider()
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPGrpcExporter(endpoint="localhost:4317"))
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer("agent-system", "1.0.0")

def run_agent(task: str, session_id: str):
    trace_id = str(uuid.uuid4())
    with tracer.start_as_current_span(
        "agent_run",
        attributes={
            "session.id": session_id,
            "trace.id": trace_id,
            "task.input": task,
        },
    ) as run_span:
        for step in agent_steps(task):
            with tracer.start_as_current_span(
                step.span_type,
                attributes=step.otel_attributes(),
            ) as step_span:
                result = step.execute()
                step_span.set_attribute("step.status", "success")
                step_span.set_attribute("step.latency_ms", step.latency_ms)
                step_span.set_attribute(
                    "gen_ai.usage.input_tokens", step.input_tokens
                )
                step_span.set_attribute(
                    "gen_ai.usage.output_tokens", step.output_tokens
                )
                step_span.set_attribute("step.cost_usd", step.cost_usd)
                run_span.set_attribute("task.output", result)
                run_span.set_attribute("run.total_cost_usd", total_cost)
    return result
```

## Integration Patterns

| Platform | Type | Integration Method | Best For |
|---|---|---|---|
| LangSmith | Commercial | Native LangGraph tracing, SDK for others | LangGraph projects, prompt playground |
| Langfuse | Open-source | SDK or OTel export, self-hostable | Cost control, open-source requirement, GenAI OTel compliance |
| Arize Phoenix | Open-source | Local UI, LlamaIndex one-click, OTel export | Local debugging, quick setup, no external dependency |
| Helicone | Commercial | Drop-in proxy (replace API base URL) | Minimal code change, proxy-based capture |
| MLflow | Open-source | LlamaIndex integration, tracing plugin | Existing MLflow infrastructure, LlamaIndex projects |

### CrewAI Tracing

CrewAI has built-in trace support for local crews and flows:

```python
from crewai import Crew, Process

crew = Crew(
    agents=[researcher, analyst, writer],
    tasks=[research_task, analysis_task, writing_task],
    process=Process.sequential,
)

result = crew.kickoff()
# Traces are available in the CrewAI local trace viewer
# For external backends, use the Langfuse or Arize Phoenix integrations
```

### LlamaIndex One-Click Instrumentation

```python
import llama_index.core

# Arize Phoenix (local)
llama_index.core.global_handler = "arize_phoenix"

# Langfuse (self-hostable or cloud)
llama_index.core.global_handler = "langfuse"

# Simple observability (local console)
llama_index.core.global_handler = "simple"
```

## Dashboard Essentials

Build dashboards that answer these questions first:

| Metric | Question It Answers | Aggregation |
|---|---|---|
| Task success rate | Is the agent completing its intended purpose? | Percentage of runs with successful final output |
| Tool-call accuracy | Is the agent choosing and using tools correctly? | Percentage of tool calls with correct args and valid results |
| Retrieval faithfulness | Is retrieved content actually used in the answer? | Compare retrieved docs against cited content |
| Latency (p50, p95, p99) | How fast is the agent, and how slow at worst? | Per-step and per-run timing distribution |
| Cost per task | How much does each completed task cost? | Total USD per successful run |
| Token consumption trends | Is usage growing, spiking, or stable? | Daily/weekly sum of input + output tokens |

## Alerting

Configure alerts before the agent reaches production users:

| Alert | Trigger | Action |
|---|---|---|
| Cost anomaly | Daily spend exceeds 2x rolling 7-day average | Notify ops team, investigate recent traces |
| Latency spike | p95 latency exceeds 2x baseline over 1 hour | Check model provider status, review recent spans |
| Error rate threshold | Error rate exceeds 5% over 15-minute window | Alert engineering, pause non-critical runs |
| Token budget exhaustion | Session token count exceeds configured max | Terminate run, log event, surface to user |
| Step count exceeded | Run exceeds max step count (10-20) | Terminate run, log partial output, alert |

## Anti-Patterns

- Skipping observability until production -- you will debug blind when failures happen
- Only logging final outputs -- you cannot diagnose which step failed or why
- No trace IDs -- you cannot correlate steps across a multi-step run
- Cost tracking after deployment -- budget overruns happen silently without per-call accounting
- Unstructured text logs -- searchable, filterable structured data is mandatory for production systems

## References

- OpenTelemetry GenAI Semantic Conventions: https://opentelemetry.io/docs/concepts/semantic-conventions/gen-ai/
- Langfuse OTel Integration: https://langfuse.com/docs/opentelemetry
- Arize Phoenix Quickstart: https://docs.arize.com/phoenix