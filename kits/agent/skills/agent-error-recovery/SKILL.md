---
name: agent-error-recovery
description: "Error recovery and resilience patterns for agent systems: circuit breakers, retry strategies, degraded operation modes, fallback models/tools, self-healing, and catastrophic failure handling. Use when making agent systems resilient to tool failures, LLM errors, or infrastructure outages."
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

# Agent Error Recovery

Resilience patterns for agent systems that handle tool failures, LLM errors, infrastructure outages, and unexpected conditions. Covers circuit breakers, retry strategies, fallback routing, degraded operation, and self-healing.

## When to use this skill

- Building agent systems that must remain operational despite tool/API failures
- Implementing retry logic for LLM or tool call failures
- Adding fallback models or tools when the primary fails
- Designing degraded operation modes for partial outages
- Handling catastrophic failures gracefully without data loss
- Making multi-agent systems resilient to individual agent failures

## Error Categories

| Category | Examples | Recovery Strategy |
|---|---|---|
| **Transient** | Network timeout, rate limit, temporary service outage | Retry with backoff |
| **Permanent** | Invalid input, permission denied, resource not found | Skip and inform agent |
| **Degradation** | Model API slow, partial data, stale cache | Fallback to cheaper model or tool |
| **Catastrophic** | Total API outage, database corruption, data loss | Graceful shutdown with partial results |
| **Agent logic** | Infinite loop, wrong tool selection, context overflow | Step-level correction and re-routing |

## Strategy 1: Retry with Backoff

Retry transient failures with exponential backoff. Do not retry permanent failures:

```python
import time
import random

class RetryHandler:
    """Retry transient errors with exponential backoff and jitter."""

    TRANSIENT_ERRORS = [
        "timeout", "rate_limit", "connection_error",
        "service_unavailable", "internal_server_error",
    ]
    PERMANENT_ERRORS = [
        "invalid_input", "permission_denied", "not_found",
        "authentication_failed", "invalid_api_key",
    ]

    def __init__(self, max_retries=3, base_delay=1.0, max_delay=30.0):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay

    def execute_with_retry(self, func, *args, **kwargs):
        """Execute a function with retry logic."""
        for attempt in range(self.max_retries + 1):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                error_type = self._classify_error(e)

                if error_type == "permanent":
                    raise  # Don't retry permanent errors

                if error_type == "transient" and attempt < self.max_retries:
                    delay = min(
                        self.base_delay * (2 ** attempt) + random.uniform(0, 1),
                        self.max_delay,
                    )
                    time.sleep(delay)
                    continue

                raise  # Max retries exceeded

    def _classify_error(self, error: Exception) -> str:
        error_message = str(error).lower()
        for pattern in self.PERMANENT_ERRORS:
            if pattern in error_message:
                return "permanent"
        for pattern in self.TRANSIENT_ERRORS:
            if pattern in error_message:
                return "transient"
        return "transient"  # Default: assume transient for unknown errors


class ResilientToolExecutor:
    """Tool executor that wraps each tool call with retry logic."""

    def __init__(self, tools: dict, retry_handler: RetryHandler):
        self.tools = tools
        self.retry = retry_handler

    def execute(self, tool_name: str, args: dict) -> dict:
        tool = self.tools.get(tool_name)
        if not tool:
            return {"error": f"Unknown tool: {tool_name}", "type": "permanent"}

        try:
            result = self.retry.execute_with_retry(tool, **args)
            return {"result": result, "status": "success"}
        except Exception as e:
            return {
                "error": str(e),
                "type": self.retry._classify_error(e),
                "status": "failed",
            }
```

Retry rules:
- Only retry transient errors — permanent errors need different handling
- Use exponential backoff with jitter — prevents thundering herd on recovery
- Set max retries to 2-3 — more retries waste time and tokens
- Cap max delay at 30 seconds — don't wait minutes between retries
- Return the error classification to the agent — it can decide to skip or try a different tool
- Track retry count per tool call — inject "retried 3 times" into context so agent knows

## Strategy 2: Circuit Breaker

Stop calling a failing tool after repeated failures. Reset after a cooldown period:

```python
import time

class CircuitBreaker:
    """Prevent calls to a consistently failing tool. Reset after cooldown."""

    STATE_CLOSED = "closed"      # Normal: tool calls pass through
    STATE_OPEN = "open"          # Failing: tool calls are blocked
    STATE_HALF_OPEN = "half_open"  # Testing: one call allowed to check recovery

    def __init__(self, failure_threshold=3, cooldown_seconds=60, success_threshold=2):
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds
        self.success_threshold = success_threshold
        self.circuits = {}  # tool_name -> circuit state

    def _get_circuit(self, tool_name: str) -> dict:
        if tool_name not in self.circuits:
            self.circuits[tool_name] = {
                "state": self.STATE_CLOSED,
                "failure_count": 0,
                "success_count": 0,
                "last_failure_time": None,
            }
        return self.circuits[tool_name]

    def can_call(self, tool_name: str) -> bool:
        circuit = self._get_circuit(tool_name)
        if circuit["state"] == self.STATE_CLOSED:
            return True
        if circuit["state"] == self.STATE_OPEN:
            # Check if cooldown has passed
            if time.time() - circuit["last_failure_time"] > self.cooldown_seconds:
                circuit["state"] = self.STATE_HALF_OPEN
                return True
            return False
        if circuit["state"] == self.STATE_HALF_OPEN:
            return True  # Allow one call to test recovery
        return False

    def record_success(self, tool_name: str):
        circuit = self._get_circuit(tool_name)
        circuit["success_count"] += 1
        if circuit["state"] == self.STATE_HALF_OPEN and circuit["success_count"] >= self.success_threshold:
            circuit["state"] = self.STATE_CLOSED
            circuit["failure_count"] = 0

    def record_failure(self, tool_name: str):
        circuit = self._get_circuit(tool_name)
        circuit["failure_count"] += 1
        circuit["last_failure_time"] = time.time()
        circuit["success_count"] = 0
        if circuit["failure_count"] >= self.failure_threshold:
            circuit["state"] = self.STATE_OPEN


class CircuitBreakerAgent:
    """Agent that skips failing tools via circuit breaker."""

    def __init__(self, model, tools, circuit_breaker: CircuitBreaker):
        self.model = model
        self.tools = tools
        self.cb = circuit_breaker

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        for step in range(max_steps):
            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                return response.content

            for tc in response.tool_calls:
                if not self.cb.can_call(tc.name):
                    # Inject circuit breaker status into context
                    context.append({
                        "role": "tool",
                        "name": tc.name,
                        "content": f"Tool {tc.name} is temporarily unavailable (circuit breaker open). Try an alternative approach.",
                    })
                    continue

                result = self._execute_tool(tc)
                if result["status"] == "success":
                    self.cb.record_success(tc.name)
                    context.append({"role": "tool", "name": tc.name, "content": result["result"]})
                else:
                    self.cb.record_failure(tc.name)
                    context.append({"role": "tool", "name": tc.name, "content": f"Error: {result['error']}"})
```

Circuit breaker rules:
- Set failure threshold to 3-5 consecutive failures — don't trip on one failure
- Set cooldown to 30-60 seconds — don't retry too quickly
- Inform the agent when a tool is blocked — it can switch to an alternative
- Track circuit state per tool — different tools have different reliability profiles
- Reset circuits on successful calls — the tool has recovered
- Log circuit state transitions — needed for debugging and monitoring

## Strategy 3: Fallback Routing

When a model or tool fails, fall back to an alternative:

```python
class FallbackRouter:
    """Route to fallback models or tools when the primary fails."""

    MODEL_FALLBACKS = {
        "claude-opus-4-7": ["claude-sonnet-4-6", "claude-haiku-4-5"],
        "claude-sonnet-4-6": ["gpt-4.1", "claude-haiku-4-5"],
        "gpt-4.1": ["claude-sonnet-4-6", "gpt-4.1-mini"],
    }

    TOOL_FALLBACKS = {
        "premium_search": ["basic_search", "cached_search"],
        "realtime_database": ["cached_database", "static_database"],
        "external_api": ["cached_api_response", "mock_response"],
    }

    def get_model_fallback(self, primary_model: str, error: Exception) -> str:
        """Get a fallback model when the primary fails."""
        fallbacks = self.MODEL_FALLBACKS.get(primary_model, [])
        for fallback in fallbacks:
            try:
                # Quick health check — one small request
                test_response = self._call_model(fallback, "ping")
                return fallback
            except Exception:
                continue
        raise RuntimeError(f"All model fallbacks exhausted for {primary_model}")

    def get_tool_fallback(self, primary_tool: str) -> str | None:
        """Get a fallback tool when the primary fails."""
        return self.TOOL_FALLBACKS.get(primary_tool, [None])[0]


class ResilientAgent:
    """Agent with fallback routing for models and tools."""

    def __init__(self, primary_model, tools, fallback_router: FallbackRouter):
        self.primary_model = primary_model
        self.tools = tools
        self.fallback = fallback_router

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        current_model = self.primary_model

        for step in range(max_steps):
            try:
                response = self._call_model(current_model, context)
            except Exception as e:
                # Model failure — switch to fallback
                fallback_model = self.fallback.get_model_fallback(current_model, e)
                context.append({
                    "role": "system",
                    "content": f"Model {current_model} failed. Switched to {fallback_model}. Continue the task.",
                })
                current_model = fallback_model
                response = self._call_model(current_model, context)

            if response.finish_reason == "stop":
                return response.content

            for tc in response.tool_calls:
                tool = self.tools.get(tc.name)
                if not tool:
                    # Tool not available — try fallback
                    fallback_tool = self.fallback.get_tool_fallback(tc.name)
                    if fallback_tool:
                        tool = self.tools.get(fallback_tool)
                        context.append({
                            "role": "system",
                            "content": f"Tool {tc.name} unavailable. Using fallback {fallback_tool}.",
                        })
                    else:
                        context.append({
                            "role": "tool",
                            "content": f"No tool available for {tc.name}. Try a different approach.",
                        })
                        continue

                try:
                    result = json.dumps(tool(**tc.arguments))
                    context.append({"role": "tool", "name": tc.name, "content": result})
                except Exception as e:
                    context.append({"role": "tool", "name": tc.name, "content": f"Error: {str(e)}"})
```

Fallback rules:
- Always define fallback chains — primary → mid-tier → cheap model
- Inform the agent when switching — it may need to adjust its approach
- Quality degrades with each fallback — acknowledge this to the user
- Fallback tools should cover the same capability with less data/freshness
- Test fallback paths in CI — they are rarely used but critical when needed
- Never fallback to a model that cannot handle tool calls — Haiku can, some older models cannot

## Strategy 4: Degraded Operation

When some capabilities are unavailable, continue operating with reduced functionality:

```python
class DegradedOperationAgent:
    """Agent that operates in degraded mode when tools are unavailable."""

    CAPABILITY_LEVELS = {
        "full": ["search", "database", "calculate", "write", "review"],
        "partial": ["cached_search", "cached_database", "calculate", "write"],
        "minimal": ["calculate", "write"],
        "offline": ["write"],  # Only generate text, no external data
    }

    def __init__(self, model, tools, health_checker):
        self.model = model
        self.tools = tools
        self.health = health_checker

    def run(self, task: str):
        # Check current capability level based on tool availability
        level = self._assess_capability_level()
        available_tools = self.CAPABILITY_LEVELS[level]

        # Adjust prompt based on capability level
        prompt = self._build_degraded_prompt(task, level, available_tools)

        response = self.model.invoke([
            {"role": "system", "content": prompt},
            {"role": "user", "content": task},
        ])
        return DegradedResult(
            output=response.content,
            capability_level=level,
            limitations=self._get_limitations(level),
        )

    def _assess_capability_level(self) -> str:
        available = self.health.check_all()
        if all(t in available for t in self.CAPABILITY_LEVELS["full"]):
            return "full"
        if all(t in available for t in self.CAPABILITY_LEVELS["partial"]):
            return "partial"
        if all(t in available for t in self.CAPABILITY_LEVELS["minimal"]):
            return "minimal"
        return "offline"

    def _build_degraded_prompt(self, task, level, available_tools):
        base = SYSTEM_PROMPT
        if level != "full":
            base += f"\n\nWARNING: Operating in degraded mode ({level}). Available tools: {available_tools}. Work within these limitations. Do not attempt to call unavailable tools."
        if level == "offline":
            base += "\nYou have no external data access. Provide your best answer from training knowledge. Acknowledge limitations explicitly."
        return base
```

Degraded operation rules:
- Define capability levels explicitly — full, partial, minimal, offline
- Adjust the agent prompt to reflect available capabilities — prevent it from calling unavailable tools
- Acknowledge limitations in the output — tell the user what the agent couldn't do
- Log capability level per run — track degradation patterns over time
- Notify operations when degradation lasts >15 minutes — it may indicate an infrastructure issue
- Restore full capability automatically when tools recover — don't require manual intervention

## Strategy 5: Self-Healing

Agent detects its own failures and adjusts strategy mid-run:

```python
class SelfHealingAgent:
    """Agent that detects and corrects its own failures mid-run."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        consecutive_failures = 0

        for step in range(max_steps):
            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                return response.content

            for tc in response.tool_calls:
                tool = self.tools.get(tc.name)
                if not tool:
                    consecutive_failures += 1
                    context.append({"role": "tool", "content": f"Tool {tc.name} not found."})

                    if consecutive_failures >= 2:
                        # Self-healing: ask agent to try a different approach
                        healing_prompt = "Your last 2 tool calls failed. List available tools and choose a different approach."
                        context.append({"role": "system", "content": healing_prompt})
                        consecutive_failures = 0
                    continue

                try:
                    result = json.dumps(tool(**tc.arguments))
                    consecutive_failures = 0
                    context.append({"role": "tool", "name": tc.name, "content": result})
                except Exception as e:
                    consecutive_failures += 1
                    context.append({"role": "tool", "name": tc.name, "content": f"Error: {str(e)}"})

                    if consecutive_failures >= 3:
                        # Escalate: too many failures
                        context.append({
                            "role": "system",
                            "content": "Multiple consecutive failures detected. Simplify your approach. Use fewer, more reliable tools.",
                        })
                        consecutive_failures = 0
```

Self-healing rules:
- Track consecutive failures — 2 tool failures triggers strategy adjustment
- Inject correction prompts into context — tell the agent what went wrong and suggest alternatives
- List available tools in correction prompts — the agent may not know which tools are working
- Limit self-healing attempts — don't let the agent spiral trying different approaches
- Escalate to human after 3 consecutive self-healing attempts — the agent can't fix itself

## Strategy 6: Graceful Shutdown

When catastrophic failure occurs, preserve partial results and state:

```python
class GracefulShutdownAgent:
    """Agent that preserves partial results on catastrophic failure."""

    def __init__(self, model, tools, state_store):
        self.model = model
        self.tools = tools
        self.state_store = state_store

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        completed_steps = []
        total_cost = 0.0

        try:
            for step in range(max_steps):
                response = self.model.invoke(context)
                total_cost += self._calculate_cost(response)

                if response.finish_reason == "stop":
                    return AgentResult(
                        status="success",
                        output=response.content,
                        completed_steps=completed_steps,
                        total_cost=total_cost,
                    )

                for tc in response.tool_calls:
                    result = self._execute_tool_safely(tc)
                    completed_steps.append({
                        "step": step,
                        "tool": tc.name,
                        "result_summary": str(result)[:100],
                    })
                    context.append({"role": "tool", "name": tc.name, "content": result})

        except KeyboardInterrupt:
            return self._shutdown("interrupted", context, completed_steps, total_cost)
        except Exception as e:
            # Save state for resumption
            self.state_store.save({
                "task": task,
                "context": context,
                "completed_steps": completed_steps,
                "total_cost": total_cost,
                "error": str(e),
            })
            return self._shutdown("error", context, completed_steps, total_cost, str(e))

    def _shutdown(self, reason, context, completed_steps, total_cost, error=None):
        partial_output = context[-1]["content"] if context else "No results"
        return AgentResult(
            status=reason,
            output=partial_output,
            completed_steps=completed_steps,
            total_cost=total_cost,
            error=error,
            resumable=True,  # State was saved, can be resumed
        )

    def resume(self, run_id: str):
        """Resume a previously interrupted run."""
        saved = self.state_store.load(run_id)
        # Continue from saved context and completed steps
        return self.run(saved["task"], max_steps=self.max_steps - len(saved["completed_steps"]))
```

Shutdown rules:
- Always save state before shutting down — enables resumption
- Return partial results — they are valuable even if incomplete
- Mark results as partial — users must know they're not final
- Log the failure reason and step number — needed for debugging
- Support resumption — load saved state and continue from where it stopped
- Set a cost budget limit — catastrophic runaway costs are a failure too

## Resilience Checklist

| Action | Impact | Effort |
|---|---|---|
| Add retry with backoff on transient errors | Recovers from temporary outages | Low |
| Add circuit breaker per tool | Prevents cascading failures | Medium |
| Define model fallback chains | Continues operation when model API fails | Low |
| Define tool fallbacks | Continues with reduced capability | Medium |
| Define degraded operation levels | Provides partial service during outages | Medium |
| Add self-healing prompts for consecutive failures | Agent adapts strategy automatically | Medium |
| Save state for resumption on catastrophic failure | Preserves work, enables restart | Medium |
| Set cost budget limit per run | Prevents cost runaway | Low |
| Track and alert on degradation patterns | Early detection of infrastructure issues | Low |

Start with retry and circuit breaker — they handle 90% of production failures with minimal effort.

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Retrying permanent errors | Wastes time and tokens on unfixable problems | Classify errors; only retry transient |
| No circuit breaker on external tools | Cascading failures: one broken tool breaks the agent | Add circuit breaker per external tool |
| No fallback model | Agent stops completely when model API fails | Define primary → mid-tier → cheap fallback chain |
| Not informing agent about failures | Agent repeats the same failing strategy | Inject failure context; suggest alternatives |
| Losing state on interruption | Work is lost, must restart from scratch | Save state; support resumption |
| Infinite retry without limit | Agent retries forever on persistent failures | Set max retries and circuit breaker thresholds |
| Not acknowledging degraded output | User thinks the output is complete and reliable | Mark partial results; state limitations |

## References

- `agent-guardrails` — Spend limit guardrails that prevent cost runaway
- `agent-observability` — Track error rates and failure patterns in production
- `agent-testing-debugging` — Test error recovery paths in CI
- `agent-loop-patterns` — Reflection pattern for self-correction
- `agent-cost-optimization` — Budget limits as catastrophic failure prevention

## Keywords

error recovery, resilience, circuit breaker, retry backoff, fallback routing, degraded operation, self-healing, graceful shutdown, resumption, catastrophic failure