---
name: agent-cost-optimization
description: "Cost optimization strategies for agent systems: token budgeting, model routing, LLM caching, prompt compression, cost forecasting, and usage analytics. Use when reducing agent running costs, configuring model routing, or setting up cost controls."
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

# Agent Cost Optimization

Strategies for minimizing the cost of running agent systems while maintaining quality. Covers token budgeting, model routing, caching, prompt compression, and cost forecasting.

## When to use this skill

- Reducing the running cost of an agent system
- Choosing which model to use for different agent steps
- Setting up caching to eliminate redundant LLM calls
- Compressing prompts to reduce token consumption
- Forecasting and budgeting agent costs before deployment
- Configuring cost guardrails and spend limits

## Cost Model for Agent Systems

Agent costs come from three sources:

| Source | Cost Driver | Typical Share |
|---|---|---|
| LLM calls | Input tokens × input price + output tokens × output price | 70-85% |
| Tool calls | API calls, database queries, compute time | 10-20% |
| Infrastructure | Hosting, storage, network | 5-10% |

LLM calls dominate. Optimize them first. Every strategy in this skill targets LLM cost reduction.

### Token Pricing Reference (2026)

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Best For |
|---|---|---|---|
| claude-haiku-4-5 | $0.80 | $4.00 | Routing, classification, simple extraction |
| claude-sonnet-4-6 | $3.00 | $15.00 | Main agent reasoning, tool selection |
| claude-opus-4-7 | $15.00 | $75.00 | Complex planning, high-stakes decisions |
| gpt-4o-mini | $0.15 | $0.60 | Classification, formatting, simple tasks |
| gpt-4.1 | $2.00 | $8.00 | General agent reasoning |
| gpt-4.1-mini | $0.40 | $1.60 | Routing, simple tool calls |

Cost ratio: Opus vs Haiku input is ~19x. One Opus call costs the same as ~19 Haiku calls. Route aggressively.

## Strategy 1: Model Routing

Use the cheapest model that can handle each step. Route tasks to models based on complexity:

```python
class ModelRouter:
    """Routes tasks to the cheapest capable model based on task classification."""

    ROUTING_TABLE = {
        "classification": "claude-haiku-4-5",   # Simple categorization
        "extraction": "claude-haiku-4-5",        # Structured data extraction
        "formatting": "gpt-4o-mini",             # Text formatting, rewording
        "tool_selection": "claude-sonnet-4-6",    # Needs reasoning about tools
        "research": "claude-sonnet-4-6",          # Multi-step reasoning
        "planning": "claude-opus-4-7",            # Complex decomposition
        "code_generation": "claude-sonnet-4-6",   # Code with tool use
        "review": "claude-haiku-4-5",             # Validation, pass/fail checks
    }

    def route(self, task_type: str) -> str:
        return self.ROUTING_TABLE.get(task_type, "claude-sonnet-4-6")

    def classify_task(self, prompt: str) -> str:
        """Use a cheap model to classify the task, then route to the right model."""
        classification = self._classify_model.invoke([
            {"role": "system", "content": "Classify this task: classification, extraction, formatting, tool_selection, research, planning, code_generation, review"},
            {"role": "user", "content": prompt},
        ])
        return classification.content.strip().lower()


class TieredAgent:
    """Agent that uses different models for different steps."""

    def __init__(self, router: ModelRouter):
        self.router = router
        self.models = {}  # Cached model instances per model name

    def run(self, task: str):
        # Planning step — use expensive model
        plan_model = self.router.route("planning")
        plan = self._call(plan_model, f"Plan steps for: {task}")

        # Execute steps — use mid-tier model
        exec_model = self.router.route("tool_selection")
        for step in parse_plan(plan):
            result = self._call(exec_model, f"Execute: {step}")

        # Review — use cheap model
        review_model = self.router.route("review")
        review = self._call(review_model, f"Review result for correctness")
        return result if "correct" in review.lower() else self._retry(task)
```

Routing rules:
- Classify first with the cheapest model (Haiku or Mini) — classification costs <1% of total
- Route classification, extraction, formatting, and review to cheap models
- Route tool selection and research to mid-tier models
- Route complex planning and high-stakes decisions to expensive models only when necessary
- Never use Opus/GPT-4.1 for tasks a Haiku/Mini can handle

## Strategy 2: Token Budgeting

Allocate token budgets per task type. Track and enforce budgets at runtime:

```python
class TokenBudget:
    """Per-task token budget with runtime enforcement."""

    BUDGET_TABLE = {
        "classification": {"input": 200, "output": 50},
        "extraction": {"input": 500, "output": 200},
        "tool_call": {"input": 1000, "output": 300},
        "research_step": {"input": 3000, "output": 500},
        "planning": {"input": 5000, "output": 1000},
        "full_run": {"input": 20000, "output": 5000},
    }

    def __init__(self, task_type: str):
        self.budget = self.BUDGET_TABLE[task_type]
        self.used = {"input": 0, "output": 0}

    def check_and_record(self, input_tokens: int, output_tokens: int) -> bool:
        """Record token usage and check if budget is exceeded."""
        self.used["input"] += input_tokens
        self.used["output"] += output_tokens
        return (
            self.used["input"] <= self.budget["input"]
            and self.used["output"] <= self.budget["output"]
        )

    def remaining(self) -> dict:
        return {
            "input": self.budget["input"] - self.used["input"],
            "output": self.budget["output"] - self.used["output"],
        }


class BudgetAwareAgent:
    """Agent that tracks and enforces token budgets per step."""

    def __init__(self, models, tools, max_budget_usd=1.00):
        self.models = models
        self.tools = tools
        self.max_budget = max_budget_usd
        self.total_cost = 0.0

    def run(self, task: str, max_steps=10):
        budget = TokenBudget("full_run")
        context = [{"role": "user", "content": task}]

        for step in range(max_steps):
            response = self._call_model(context)
            if not budget.check_and_record(response.input_tokens, response.output_tokens):
                return self._compact_and_continue(context, task, budget)

            step_cost = self._calculate_cost(response)
            self.total_cost += step_cost
            if self.total_cost > self.max_budget:
                return f"Budget exceeded at step {step}. Partial result: {context[-1]['content']}"

            if response.finish_reason == "stop":
                return response.content
            # Process tool calls...
        return "Max steps reached"
```

Budget rules:
- Set budgets per task type based on historical data from production traces
- Compact context when input budget is 70% consumed — don't wait until overflow
- Terminate when total run budget (USD) is exceeded — return partial results
- Track per-step cost and cumulative cost — both are needed for budget enforcement
- Budget for 2-3x expected usage — agents sometimes need more steps than anticipated

## Strategy 3: LLM Response Caching

Cache LLM responses to eliminate redundant calls. Same prompt + same model = same response (for temperature 0):

```python
import hashlib
import json
from datetime import timedelta

class LLMCache:
    """Semantic cache for LLM responses. Avoids redundant API calls."""

    def __init__(self, backend="redis", ttl=timedelta(hours=24)):
        self.backend = backend
        self.ttl = ttl

    def _cache_key(self, model: str, messages: list[dict], temperature: float) -> str:
        """Generate a deterministic cache key from model + input."""
        normalized = json.dumps([
            model,
            temperature,
            [{"role": m["role"], "content": m["content"]} for m in messages],
        ], sort_keys=True)
        return f"llm_cache:{hashlib.sha256(normalized.encode()).hexdigest()[:16]}"

    def get(self, model, messages, temperature=0) -> dict | None:
        key = self._cache_key(model, messages, temperature)
        cached = self._read_from_backend(key)
        if cached:
            return json.loads(cached)
        return None

    def put(self, model, messages, response, temperature=0):
        key = self._cache_key(model, messages, temperature)
        self._write_to_backend(key, json.dumps(response), ttl=self.ttl)


class CachedAgent:
    """Agent that caches LLM responses for repeated queries."""

    def __init__(self, model, tools, cache: LLMCache):
        self.model = model
        self.tools = tools
        self.cache = cache

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        for step in range(max_steps):
            # Check cache before calling model
            cached = self.cache.get(self.model, context, temperature=0)
            if cached:
                response = MockResponse(**cached)
                cache_hits += 1
            else:
                response = self.model.invoke(context)
                self.cache.put(self.model, context, response.dict(), temperature=0)

            if response.finish_reason == "stop":
                return response.content
            # Process tool calls...
```

Caching rules:
- Only cache temperature=0 responses — temperature>0 produces non-deterministic outputs
- Set TTL based on data freshness: classification results cache 24h, research results cache 1h
- Cache at the message level, not the task level — same sub-steps across different tasks benefit
- Use Redis or similar for production caching — in-memory caches don't survive restarts
- Invalidate cache when prompts or model versions change — stale cache is worse than no cache
- Measure cache hit rate — if <30%, the cache isn't saving enough to justify its overhead

## Strategy 4: Prompt Compression

Reduce prompt token count without losing semantic content:

| Technique | Token Savings | Quality Impact | When to Use |
|---|---|---|---|
| Remove redundant instructions | 10-30% | None | Always — audit prompts for repeated instructions |
| Abbreviate tool descriptions | 15-25% | Low (if descriptions are still clear) | When tool descriptions are verbose |
| Compress conversation history | 40-60% | Medium (loses detail) | When context exceeds budget |
| Use structured formats (JSON/YAML) | 20-40% | None | When prompts contain tabular data |
| Move instructions to system prompt | 5-10% | None (system prompt caches) | Always — system prompts cache with prompt caching |
| Progressive disclosure (tiered loading) | 30-50% | Low (tools loaded as needed) | When agent has many tools |

### Prompt Caching (Anthropic / OpenAI)

Anthropic and OpenAI support prompt caching — reused prompt prefixes are cached and charged at reduced rates:

| Provider | Cache Feature | Input Cost Reduction | Cache TTL |
|---|---|---|---|
| Anthropic | Prompt caching | 90% discount on cached tokens | 5 minutes |
| OpenAI | Cached responses | 50% discount on cached tokens | Varies by model |

Maximize cache hits by:
- Putting stable content in the system prompt (always the prefix)
- Keeping system prompts identical across calls within a session
- Putting dynamic content (user messages, tool results) at the end
- Not modifying the system prompt between steps — changes break the cache

```python
# Optimize for Anthropic prompt caching
CACHED_SYSTEM_PROMPT = """
You are a research assistant. Use the provided tools to find and analyze information.

Tools available:
- search: Search the web for information
- calculate: Perform mathematical calculations
- database: Query the internal database

Rules:
- Always cite sources
- Be concise and factual
- Only use provided data, do not fabricate information
"""

# System prompt stays stable — cached across all calls in a 5-minute window
# Only user messages and tool results change — they go at the end
def cached_agent_call(system_prompt, user_messages):
    messages = [
        {"role": "system", "content": system_prompt},  # Cached prefix
        *user_messages,  # Dynamic suffix (not cached)
    ]
    return client.messages.create(
        model="claude-sonnet-4-6",
        messages=messages,
        max_tokens=1024,
    )
```

## Strategy 5: Cost Forecasting

Forecast agent costs before deployment based on expected usage patterns:

```python
class CostForecaster:
    """Forecast daily/monthly agent costs based on usage patterns."""

    def __init__(self, pricing: dict):
        self.pricing = pricing  # model -> {input_per_1m, output_per_1m}

    def forecast(self, usage_profile: dict) -> dict:
        """
        usage_profile = {
            "daily_runs": 1000,
            "avg_input_tokens_per_run": 5000,
            "avg_output_tokens_per_run": 1000,
            "avg_steps_per_run": 5,
            "model": "claude-sonnet-4-6",
        }
        """
        model = usage_profile["model"]
        pricing = self.pricing[model]

        daily_input_tokens = usage_profile["daily_runs"] * usage_profile["avg_input_tokens_per_run"] * usage_profile["avg_steps_per_run"]
        daily_output_tokens = usage_profile["daily_runs"] * usage_profile["avg_output_tokens_per_run"] * usage_profile["avg_steps_per_run"]

        daily_cost = (
            daily_input_tokens / 1_000_000 * pricing["input_per_1m"]
            + daily_output_tokens / 1_000_000 * pricing["output_per_1m"]
        )

        return {
            "daily_cost_usd": daily_cost,
            "monthly_cost_usd": daily_cost * 30,
            "daily_input_tokens": daily_input_tokens,
            "daily_output_tokens": daily_output_tokens,
        }
```

Forecasting rules:
- Measure real usage for 1-2 weeks before forecasting — estimates are always wrong
- Forecast for peak usage, not average — costs spike when traffic spikes
- Include a 30% buffer for unexpected usage growth
- Track actual vs forecasted weekly — adjust forecasts when they diverge by >20%
- Set alerts at 80% of budget — don't wait until 100%

## Cost Optimization Checklist

| Action | Impact | Effort |
|---|---|---|
| Route simple tasks to cheap models (Haiku/Mini) | 10-50x cost reduction on those tasks | Low |
| Set token budgets per task type | Prevents runaway costs | Low |
| Cache temperature=0 responses | 30-50% reduction on repeated queries | Medium |
| Maximize prompt caching (stable system prompts) | 50-90% reduction on cached tokens | Low |
| Compress prompts (remove redundancy, abbreviate) | 10-30% reduction per call | Medium |
| Use progressive disclosure (tiered tool loading) | 30-50% reduction per call | Medium |
| Track cost per task in production | Enables all other optimizations | Low |
| Set spend limits and alerts | Prevents budget overruns | Low |
| Forecast costs before deployment | Prevents surprise invoices | Medium |

Start with model routing and spend limits — they have the highest impact with the lowest effort.

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Using the most expensive model for every step | Opus/GPT-4.1 for classification costs 19x more than necessary | Route based on task complexity |
| No token budget per run | Runaway agents can cost $50+ per task | Set and enforce token budgets |
| Caching temperature>0 responses | Non-deterministic outputs cached incorrectly | Only cache temperature=0 |
| Modifying system prompt between steps | Breaks prompt caching, re-pays full input cost | Keep system prompts stable within a session |
| Skipping cost tracking in development | Surprise invoices in production | Track cost per task from day one |
| No spend limit alerting | Budget overruns happen silently | Set alerts at 80% of budget |
| Ignoring cache hit rate | Cache overhead exceeds savings when hit rate is low | Measure hit rate; disable cache if <30% |
| Forecasting from estimates instead of real data | Estimates are always too low | Measure real usage for 1-2 weeks first |

## References

- `agent-observability` — Cost tracking infrastructure, dashboards, and alerts
- `agent-context-management` — Context compression strategies that also reduce token cost
- `agent-tool-design` — Progressive disclosure (tiered tool loading) to reduce prompt size
- `agent-loop-patterns` — Compaction pattern reduces context and cost for long runs
- `agent-guardrails` — Spend limit guardrails to prevent budget overruns

## Keywords

cost optimization, model routing, token budgeting, LLM caching, prompt compression, cost forecasting, spend limits, prompt caching, progressive disclosure, budget control