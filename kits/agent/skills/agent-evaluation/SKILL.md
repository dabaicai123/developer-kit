---
name: agent-evaluation
description: "Agent evaluation strategies: trajectory evaluation, LLM-as-judge, deterministic mocks, and continuous evals. Use when testing agent behavior, building eval datasets, or setting up CI evaluation pipelines."
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

# Agent Evaluation

Evaluate full agent trajectories, not just final answers. Build structured eval datasets, deterministic mocks, and continuous evaluation pipelines.

## When to Use This Skill

- Creating evaluation datasets for an agent system
- Designing CI pipelines that test agent decision-making
- Choosing between LLM-as-judge and deterministic evaluation
- Evaluating prompt changes, retrieval changes, or full agent upgrades
- Setting up continuous evaluation on production traces

## Evaluate Full Trajectories, Not Just Final Answers

Final-answer evaluation misses the most common agent failures:

| What to Evaluate | Why It Matters | How to Measure |
|---|---|---|
| Tool choice correctness | Wrong tool = wrong result regardless of answer quality | Compare selected tool against expected tool per step |
| Argument validity | Correct tool with wrong args still fails | Validate args against expected schema/values |
| Step count | Excessive steps indicate poor planning or looping | Compare against optimal step count for the task |
| Time and cost | Slow or expensive agents are production risks | Track wall-clock time and token cost per run |
| Policy compliance | Agent must follow safety and approval rules | Check each step against policy constraints |
| Error recovery | Agents that crash on errors are fragile | Inject errors, verify graceful handling |

An agent that produces the right answer through wrong steps is unreliable. An agent that produces a slightly wrong answer through correct steps is fixable.

## Three Evaluation Levels

### Level 1: Prompt Experiments

Run a prompt in isolation against known inputs. Fast, cheap, isolates prompt quality from tool/retrieval dependencies.

- Scope: Single LLM call with fixed input
- Speed: Seconds per test case
- Use when: Tweaking system prompts, testing instruction clarity, comparing model choices
- Method: Feed the same input to the prompt, compare output against expected answer

### Level 2: RAG Experiments

Test retrieval pipeline changes against expected documents. Evaluates retrieval quality, reranking, and chunking strategy.

- Scope: Retrieval + reranking pipeline
- Speed: Seconds per test case
- Use when: Changing embedding model, adjusting chunk size, swapping vector store, tuning reranker
- Method: Query the retrieval pipeline, verify returned documents match expected set (recall and precision)

### Level 3: Full-Agent Experiments

Validate end-to-end agent behavior before promoting to production. Most expensive, most comprehensive.

- Scope: Complete agent run with all tools and retrieval
- Speed: Minutes per test case (real API calls)
- Use when: Releasing a new agent version, changing tool definitions, modifying orchestration logic
- Method: Run full agent against test cases, evaluate trajectory and final output

Never skip Level 3 before production deployment. Levels 1 and 2 are for rapid iteration.

## LLM-as-Judge

LLM-as-judge is useful but biased. Apply these constraints:

- **Bias toward verbose/confident outputs** -- longer answers and confident tone score higher regardless of accuracy. Mitigate: normalize output length before scoring, penalize unjustified confidence.
- **Pair with deterministic checks** -- never rely on LLM-as-judge alone. Always add schema validation, fact checking, and policy compliance checks that produce binary pass/fail.
- **Provide rubric + examples + edge cases** -- the judge needs explicit criteria, reference outputs for each score level, and known failure modes.
- **Make evals binary (pass/fail)** -- scored ranges (1-5) produce unreliable inter-run consistency. Binary judgments with clear criteria are reproducible.

```python
EVAL_RUBRIC = {
    "tool_selection": {
        "pass": "Agent selected the correct tool for the task",
        "fail": "Agent selected wrong tool or no tool when one was needed",
    },
    "argument_validity": {
        "pass": "All tool arguments match expected schema and values",
        "fail": "Missing required args, wrong types, or invalid values",
    },
    "policy_compliance": {
        "pass": "Agent followed all safety and approval rules",
        "fail": "Agent bypassed approval gates or violated policy constraints",
    },
    "final_output": {
        "pass": "Output matches expected answer within tolerance",
        "fail": "Output is incorrect, incomplete, or hallucinated",
    },
}
```

## Deterministic Tool Mocks in CI

Mock tool responses to test agent decision-making without real API calls. This makes CI fast, reproducible, and free.

```python
from unittest.mock import MagicMock

MOCK_TOOL_RESPONSES = {
    "search_tool": {
        "query=python testing": [{"title": "pytest docs", "url": "...", "score": 0.95}],
        "query=invalid query": [],
    },
    "database_tool": {
        "action=read, table=orders, id=123": {"id": 123, "status": "shipped"},
        "action=delete, table=orders": "MOCK_APPROVAL_REQUIRED",
    },
}

def create_mock_tool(tool_name: str) -> MagicMock:
    mock = MagicMock()
    mock.name = tool_name
    def side_effect(**kwargs):
        key = f"{tool_name}:" + ",".join(f"{k}={v}" for k, v in kwargs.items())
        return MOCK_TOOL_RESPONSES.get(key, f"mock_response_for_{tool_name}")
    mock.side_effect = side_effect
    return mock
```

Rules for deterministic mocks:

- Return realistic data shapes -- the agent must process real-looking outputs
- Include error cases -- empty results, permission denied, timeout
- Cover approval gates -- mock the approval workflow, not just the happy path
- Never mock the agent's decision logic -- only mock external dependencies

## Eval Set Requirements

| Category | Proportion | Content |
|---|---|---|
| Happy path | 60% | Standard tasks the agent should handle reliably |
| Edge cases | 25% | Unusual inputs, ambiguous requests, partial data |
| Adversarial | 15% | Prompt injection attempts, scope escalation, resource exhaustion |

Minimum 50 test cases. Production agents need 100+. Each test case specifies:

```json
{
  "id": "eval-001",
  "category": "happy_path",
  "input": "Search for recent papers on transformer architectures",
  "expected_tools": ["search_tool"],
  "expected_tool_args": {"search_tool": {"query": "transformer architectures recent papers"}},
  "expected_steps": 2,
  "expected_output_contains": ["transformer", "attention mechanism"],
  "policy_constraints": ["no_write_operations", "max_cost_0.50"],
  "adversarial_patterns": null
}
```

Coverage must include: tool selection, argument passing, error recovery, safety compliance, multi-step reasoning.

## Continuous Evals

Run unsupervised evaluation on production traces to catch degradation early:

- **Binary pass/fail** -- each trace gets a clear pass or fail, not a fuzzy score
- **Specific, not generic** -- evaluate "did the agent call the correct tool" not "was the agent good"
- **Automated replay** -- sample production traces, replay them against updated agent, compare trajectories
- **Drift detection** -- track pass rate over time; a drop of 5% or more triggers investigation

```python
CONTINUOUS_EVAL_CONFIG = {
    "sample_rate": 0.1,
    "eval_dimensions": [
        "tool_selection_accuracy",
        "argument_schema_compliance",
        "policy_compliance",
        "output_factuality",
    ],
    "pass_threshold": 0.85,
    "drift_alert_threshold": 0.05,
    "replay_on_version_change": True,
}
```

## Framework Support

| Framework | Type | Strengths |
|---|---|---|
| DeepEval | Open-source | Built-in metrics for agents, RAG, hallucination, bias |
| RAGAS | Open-source | Retrieval-focused metrics: faithfulness, relevance, context recall |
| Promptfoo | Open-source | Prompt comparison, red teaming, config-driven evals |
| LangSmith evals | Commercial | Integrated with LangGraph, dataset management, annotation UI |
| Langfuse evals | Open-source | Score-based evals on traces, LLM-as-judge templates |
| PydanticAI built-in evals | Open-source | Type-safe evaluation with Pydantic models, deterministic + LLM judges |

## Test Harness: Replay Traces

Build a harness that replays recorded traces against the current agent version to detect behavioral changes:

```python
class EvalHarness:
    def __init__(self, eval_dataset_path: str, agent_runner: callable):
        self.cases = load_eval_dataset(eval_dataset_path)
        self.agent_runner = agent_runner

    def run_case(self, case: dict) -> dict:
        result = self.agent_runner(case["input"], mock_tools=True)
        return {
            "tool_selection": binary_eval(result.tools, case["expected_tools"]),
            "argument_validity": schema_eval(result.tool_args, case["expected_tool_args"]),
            "step_count": len(result.steps) <= case["expected_steps"] + 1,
            "policy_compliance": policy_eval(result.trace, case["policy_constraints"]),
            "output_quality": contains_eval(result.output, case["expected_output_contains"]),
        }

    def run_all(self) -> dict:
        results = [self.run_case(c) for c in self.cases]
        return {
            "total": len(results),
            "pass_rate": sum(1 for r in results if all(r.values())) / len(results),
            "failures": [r for r in results if not all(r.values())],
        }
```

## Eval Dataset Structure

```
tests/
├── evals/
│   ├── eval_dataset.json       → All test cases (50+ minimum)
│   ├── eval_runner.py          → Harness that replays traces
│   ├── mock_responses.json     → Deterministic tool mock data
│   ├── rubrics/
│   │   ├── tool_selection.py   → Binary rubric for tool choice
│   │   ├── policy_compliance.py → Binary rubric for safety rules
│   │   ├── output_quality.py   → Binary rubric for final answer
│   ├── results/                → Eval run output logs
│   │   ├── baseline.json       → Reference results from known-good version
│   │   ├── latest.json         → Results from current version
```

## Anti-Patterns

- Only evaluating final answer quality -- trajectory failures are invisible without step-by-step eval
- LLM-as-judge without rubric -- unguided judges produce inconsistent and biased scores
- No CI integration -- evals that only run manually are never run when they matter most
- 10 test cases for production -- insufficient coverage misses edge cases and adversarial inputs
- Scored ranges instead of binary pass/fail -- ranges (1-5) lack reproducibility; binary judgments with clear criteria are actionable
- Evaluating in isolation only -- production traces reveal failures that test datasets miss

## References

- DeepEval: https://docs.deepeval.com/
- RAGAS: https://docs.ragas.io/
- Promptfoo: https://promptfoo.com/docs/
- LangSmith Evaluation: https://docs.smith.langchain.com/