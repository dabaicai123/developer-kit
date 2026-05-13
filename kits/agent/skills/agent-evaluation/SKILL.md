---
name: agent-evaluation
description: "Testing and benchmarking LLM agents including behavioral testing, capability assessment, reliability metrics, and production monitoring—where even top agents achieve less than 50% on real-world benchmarks"
version: "1.1.0"
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

Testing and benchmarking LLM agents including behavioral testing, capability assessment, reliability metrics, and production monitoring—where even top agents achieve less than 50% on real-world benchmarks.

## When to Use This Skill

- Creating evaluation datasets for an agent system
- Designing CI pipelines that test agent decision-making
- Choosing between LLM-as-judge and deterministic evaluation
- Evaluating prompt changes, retrieval changes, or full agent upgrades
- Setting up continuous evaluation on production traces
- Testing agent behavioral invariants and safety boundaries
- Catching capability degradation on agent updates

## Capabilities

- agent-testing
- benchmark-design
- capability-assessment
- reliability-metrics
- regression-testing

## Prerequisites

- Knowledge: Testing methodologies, Statistical analysis basics, LLM behavior patterns
- Skills recommended: autonomous-agents, multi-agent-orchestration
- Required skills: testing-fundamentals, llm-fundamentals

## Scope

- Does not cover: Model training evaluation (loss, perplexity), Fairness and bias testing, User experience testing
- Boundaries: Focus is agent capability and reliability, Covers functional and behavioral testing
- **Scope boundary vs `agent-testing-debugging`**: This skill covers *evaluating* agent behavior (benchmark design, LLM-as-judge, regression testing, statistical analysis). Use `agent-testing-debugging` for *debugging* failed agent runs (trace analysis, error diagnosis, fixing broken loops). If you're designing an eval suite, use this skill. If you're diagnosing why a specific run failed, use `agent-testing-debugging`.

## Ecosystem

### Primary Tools

- AgentBench — Multi-environment benchmark for LLM agents (ICLR 2024)
- τ-bench (Tau-bench) — Sierra's real-world agent benchmark
- ToolEmu — Risky behavior detection for agent tool use
- Langsmith — LLM tracing and evaluation platform

### Alternatives

- Braintrust — When: Need production monitoring integration
- PromptFoo — When: Focus on prompt-level evaluation
- DeepEval — When: Built-in metrics for agents, RAG, hallucination
- RAGAS — When: Retrieval-focused metrics: faithfulness, relevance, context recall
- Langfuse — When: Score-based evals on traces, LLM-as-judge templates
- PydanticAI — When: Type-safe evaluation with deterministic + LLM judges

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

### Level 2: RAG Experiments

Test retrieval pipeline changes against expected documents. Evaluates retrieval quality, reranking, and chunking strategy.

- Scope: Retrieval + reranking pipeline
- Speed: Seconds per test case
- Use when: Changing embedding model, adjusting chunk size, swapping vector store, tuning reranker

### Level 3: Full-Agent Experiments

Validate end-to-end agent behavior before promoting to production. Most expensive, most comprehensive.

- Scope: Complete agent run with all tools and retrieval
- Speed: Minutes per test case (real API calls)
- Use when: Releasing a new agent version, changing tool definitions, modifying orchestration logic

Never skip Level 3 before production deployment. Levels 1 and 2 are for rapid iteration.

## LLM-as-Judge

LLM-as-judge is useful but biased. Apply these constraints:

- **Bias toward verbose/confident outputs** — longer answers and confident tone score higher regardless of accuracy. Mitigate: normalize output length before scoring, penalize unjustified confidence.
- **Pair with deterministic checks** — never rely on LLM-as-judge alone. Always add schema validation, fact checking, and policy compliance checks that produce binary pass/fail.
- **Provide rubric + examples + edge cases** — the judge needs explicit criteria, reference outputs for each score level, and known failure modes.
- **Make evals binary (pass/fail)** — scored ranges (1-5) produce unreliable inter-run consistency. Binary judgments with clear criteria are reproducible.

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

## Patterns

### Statistical Test Evaluation

Run tests multiple times and analyze result distributions. LLM outputs are stochastic — single runs are unreliable.

**When to use**: Evaluating stochastic agent behavior

```typescript
interface TestResult {
    testId: string;
    runId: string;
    passed: boolean;
    score: number;  // 0-1 for partial credit
    latencyMs: number;
    tokensUsed: number;
    output: string;
    expectedBehaviors: string[];
    actualBehaviors: string[];
}

interface StatisticalAnalysis {
    passRate: number;
    confidence95: [number, number];
    meanScore: number;
    stdDevScore: number;
    meanLatency: number;
    p95Latency: number;
    behaviorConsistency: number;
}
```

Key metrics:
- **passRate** — fraction of runs that passed. Below 0.8 is concerning, below 0.5 is critical.
- **confidence95** — 95% confidence interval for pass rate. Narrow interval = reliable estimate.
- **behaviorConsistency** — Jaccard similarity of behaviors across runs. Below 0.7 indicates unstable agent.
- **stdDevScore** — high variance (>0.3) suggests unpredictable quality.

Minimum 10 runs per test for statistical significance. Use chi-squared test to compare pass rates between versions.

### Behavioral Contract Testing

Define and test agent behavioral invariants — what the agent must do and must not do.

**When to use**: Need to ensure agent stays within behavioral bounds

```typescript
interface BehavioralContract {
    name: string;
    description: string;
    mustBehaviors: BehaviorAssertion[];
    mustNotBehaviors: BehaviorAssertion[];
    contextual?: ConditionalBehavior[];
}

interface BehaviorAssertion {
    behavior: string;
    detector: (output: AgentOutput) => boolean;
    severity: 'critical' | 'high' | 'medium' | 'low';
}
```

Contract categories:
- **mustBehaviors** — behaviors the agent must exhibit (e.g., respond politely, stay on topic)
- **mustNotBehaviors** — behaviors the agent must never exhibit (e.g., reveal internal info, make unauthorized promises)
- **contextual** — behaviors required only in specific contexts (e.g., refer to policy when handling refunds)

Critical violations = deployment blocked. High violations = investigation required. Medium/Low = tracked but not blocking.

### Adversarial Testing

Actively try to break agent behavior through prompt injection, role confusion, boundary testing, and output manipulation.

**When to use**: Need to find edge cases and failure modes before deployment

Attack categories:
1. **Prompt injection** — direct override ("Ignore all instructions"), system prompt extraction, encoded injection (base64)
2. **Role confusion** — pretend different role, enable developer mode
3. **Boundary testing** — extreme length input (100K chars), unicode edge cases, recursive tasks
4. **Output manipulation** — format forcing, data exfiltration through output
5. **Tool abuse** — calling tools in unexpected ways, chaining tools for unauthorized actions

Each adversarial test has: input, expected behavior (should_not_comply, should_maintain_role, etc.), and a detector function that checks whether the agent handled it correctly.

### Regression Testing Pipeline

Catch capability degradation on agent model or code changes. Establish baseline, compare new version against it.

**When to use**: Agent model or code changes

```typescript
class AgentRegressionTester {
    private baselineResults: Map<string, TestResult[]> = new Map();

    async establishBaseline(agent: Agent, testSuite: TestCase[]): Promise<void> {
        for (const test of testSuite) {
            const results: TestResult[] = [];
            for (let i = 0; i < 10; i++) {
                results.push(await this.runTest(agent, test, i));
            }
            this.baselineResults.set(test.id, results);
        }
    }

    async testForRegression(newAgent: Agent, testSuite: TestCase[]): Promise<RegressionReport> {
        // Compare new results against baseline using chi-squared test
        // 5% tolerance: currentPassRate < baselinePassRate * 0.95 = regression
        // pValue < 0.05 = statistically significant regression
    }
}
```

Regression criteria:
- Pass rate drops more than 5% from baseline = regression
- Statistical significance via chi-squared test (p < 0.05)
- Result: "DO NOT DEPLOY" if regressions detected, "OK to deploy" otherwise

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

## Framework Support

| Framework | Type | Strengths |
|---|---|---|
| DeepEval | Open-source | Built-in metrics for agents, RAG, hallucination, bias |
| RAGAS | Open-source | Retrieval-focused metrics: faithfulness, relevance, context recall |
| PromptFoo | Open-source | Prompt comparison, red teaming, config-driven evals |
| LangSmith evals | Commercial | Integrated with LangGraph, dataset management, annotation UI |
| Langfuse evals | Open-source | Score-based evals on traces, LLM-as-judge templates |
| PydanticAI evals | Open-source | Type-safe evaluation with Pydantic models, deterministic + LLM judges |

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

## Sharp Edges

### Agent scores well on benchmarks but fails in production

**Severity: HIGH**

Benchmarks have known answer patterns. Production has long-tail edge cases. User inputs are messier than test data. High benchmark scores don't predict real-world performance.

**Fix**: Bridge benchmark and production evaluation:
1. Test on real production samples (anonymized) — production accuracy below 80% of benchmark accuracy = gap
2. Test adversarial variants of benchmark — pass rate below 70% = robustness gap
3. Test edge cases from production logs — failure rate above 20% = coverage gap
4. Test latency under production load — p95 above 5s = performance gap

### Same test passes sometimes, fails other times

**Severity: HIGH**

LLM outputs are stochastic. Tests expect deterministic behavior. No retry or statistical handling. CI randomly fails. Tests pass locally, fail in CI.

**Fix**: Handle flaky tests:
- Minimum 5 runs per test, require 80% pass rate
- Calculate flakiness = probability of different result on rerun
- Flaky tests (<20% flakiness): run multiple times in CI
- Failing tests (>50% flakiness): investigate and improve
- Aggregate: 90% of tests must pass for merge approval

### Agent optimized for metric, not actual task

**Severity: MEDIUM**

Metrics are proxies for quality. Agents can game specific metrics. Overfitting to evaluation criteria.

**Fix**: Multi-dimensional evaluation:
- Correctness (0.3 weight), helpfulness (0.2), safety (0.25), efficiency (0.15), user preference (0.1)
- Detect gaming: high variance across dimensions (>0.15) = likely gaming one metric
- Human evaluation for dimensions that can be gamed

### Test data accidentally used in training or prompts

**Severity: CRITICAL**

Test data in fine-tuning dataset, examples in system prompt, or RAG retrieves test documents. Perfect scores on specific tests that drop on new versions. Agent "knows" answers it shouldn't.

**Fix**: Prevent data leakage:
1. Check for exact matches in training data (similarity > 0.95)
2. Check system prompt for test examples
3. Memorization test: give partial input, check if agent completes exactly (similarity > 0.8 = leak)
4. Check if RAG retrieves documents containing expected answers (similarity > 0.7 = leak)
5. If leaks found: remove leaked tests and create new ones

## Anti-Patterns

- Only evaluating final answer quality — trajectory failures are invisible without step-by-step eval
- LLM-as-judge without rubric — unguided judges produce inconsistent and biased scores
- No CI integration — evals that only run manually are never run when they matter most
- 10 test cases for production — insufficient coverage misses edge cases and adversarial inputs
- Scored ranges instead of binary pass/fail — ranges (1-5) lack reproducibility
- Evaluating in isolation only — production traces reveal failures that test datasets miss
- Same evaluation for all agent types — customer service agents need behavioral contracts; research agents need trajectory accuracy

## Collaboration

### Delegation Triggers

- implement|fix|improve → autonomous-agents (Need to fix issues found in evaluation)
- orchestration|coordination → multi-agent-orchestration (Need to evaluate orchestration patterns)

### Complete Agent Development Cycle

Skills: agent-evaluation, autonomous-agents, multi-agent-orchestration

Workflow:
1. Design agent with testability in mind
2. Create evaluation suite before implementation
3. Implement agent
4. Evaluate against suite
5. Iterate based on results

### Production Agent Monitoring

Skills: agent-evaluation, llm-security-audit

Workflow:
1. Establish baseline metrics
2. Deploy with monitoring
3. Continuous evaluation in production
4. Alert on regression

### Multi-Agent System Evaluation

Skills: agent-evaluation, multi-agent-orchestration, agent-communication

Workflow:
1. Evaluate individual agents
2. Evaluate communication reliability
3. Evaluate end-to-end system
4. Load testing for scalability

## Related Skills

Works well with: `multi-agent-orchestration`, `agent-communication`, `autonomous-agents`

## When to Use (Trigger Keywords)

- User mentions or implies: agent testing, agent evaluation, benchmark agents, agent reliability, test agent

## References

- DeepEval: https://docs.deepeval.com/
- RAGAS: https://docs.ragas.io/
- PromptFoo: https://promptfoo.com/docs/
- LangSmith Evaluation: https://docs.smith.langchain.com/
- AgentBench: https://github.com/THUDM/AgentBench