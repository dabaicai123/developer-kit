---
name: agent-planning-reasoning
description: "Advanced planning and reasoning patterns for agent systems: Tree of Thought, Monte Carlo Tree Search, Hierarchical Task Networks, temporal reasoning, constraint satisfaction, and planning-validation loops. Use when building agents that need complex multi-step planning, explore multiple solution paths, or handle temporal/constraint-based decisions."
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

# Agent Planning & Reasoning

Advanced planning and reasoning patterns beyond simple chain-of-thought. Covers Tree of Thought, Monte Carlo Tree Search, Hierarchical Task Networks, planning-validation loops, and constraint satisfaction for agents that need structured multi-step decision-making.

## When to use this skill

- Building agents that must plan before acting (not just react)
- Implementing Tree of Thought for exploring multiple solution paths
- Adding planning-validation loops where plans are reviewed before execution
- Designing agents that handle temporal reasoning (before/after, deadlines)
- Building agents with constraint satisfaction (budget, time, resource limits)
- Choosing between planning strategies based on task complexity

## Pattern Comparison

| Pattern | Best For | Cost | Complexity | Accuracy |
|---|---|---|---|---|
| Chain-of-Thought (CoT) | Simple reasoning, single path | Low (1 call) | Low | Medium |
| Plan+Execute | Deterministic tasks, fixed steps | Low (1-2 calls) | Low | Medium |
| Self-Consistency | Multiple perspectives, consensus | Medium (3-5 calls) | Medium | High |
| Tree of Thought (ToT) | Creative tasks, exploring alternatives | High (5-15 calls) | High | High |
| Planning-Validation | High-stakes decisions, risk mitigation | Medium (2-3 calls) | Medium | High |
| Hierarchical Task Network (HTN) | Complex decomposition, known methods | Medium (3-5 calls) | Medium | High |
| MCTS | Sequential decisions, trade-off exploration | High (10-20 calls) | High | Very High |
| Constraint Satisfaction | Bounded decisions, feasibility checking | Medium (2-5 calls) | Medium | High |

Start with CoT for simple reasoning. Add Plan+Execute for structured tasks. Use ToT or MCTS only when exploring alternatives is critical.

## Pattern 1: Self-Consistency

Generate multiple reasoning paths, then select the most consistent answer. Useful when the task has multiple valid approaches:

```python
class SelfConsistencyAgent:
    """Generate multiple reasoning paths and select the most consistent answer."""

    def __init__(self, model, num_paths=5):
        self.model = model
        self.num_paths = num_paths

    def run(self, task: str):
        # Generate multiple independent reasoning paths
        paths = []
        for i in range(self.num_paths):
            response = self.model.invoke([
                {"role": "system", "content": f"Reason about this task independently. Path {i+1}."},
                {"role": "user", "content": task},
            ])
            paths.append(response.content)

        # Select the most consistent answer
        consensus = self._find_consensus(paths)
        return consensus

    def _find_consensus(self, paths: list[str]) -> str:
        """Find the answer that appears most frequently across paths."""
        # Use a cheap model to classify answers
        classifications = []
        for path in paths:
            classification = self.classify_model.invoke([
                {"role": "system", "content": "Extract the final answer from this reasoning path. Return ONLY the answer, no explanation."},
                {"role": "user", "content": path},
            ])
            classifications.append(classification.content.strip())

        # Count occurrences of each answer
        answer_counts = {}
        for answer in classifications:
            answer_counts[answer] = answer_counts.get(answer, 0) + 1

        # Return the most frequent answer
        best_answer = max(answer_counts, key=answer_counts.get)
        confidence = answer_counts[best_answer] / len(classifications)
        return f"Answer: {best_answer} (confidence: {confidence:.0%}, {answer_counts[best_answer]}/{len(classifications)} paths agree)"
```

Self-consistency rules:
- Generate 3-5 paths for most tasks — more than 5 rarely improves results
- Use temperature>0 for path diversity — temperature=0 produces identical paths
- Classify answers with a cheap model — Haiku/Mini is sufficient for answer extraction
- Require >60% agreement for confidence — below this, the task is genuinely ambiguous
- Don't use for simple factual questions — one call is enough when the answer is clear

## Pattern 2: Tree of Thought (ToT)

Explore multiple reasoning branches, evaluate each, and select the best path. Useful for creative tasks, puzzle solving, and tasks with many possible approaches:

```python
class TreeOfThoughtAgent:
    """Explore multiple reasoning branches and select the best path."""

    def __init__(self, model, num_branches=3, max_depth=3):
        self.model = model
        self.num_branches = num_branches
        self.max_depth = max_depth

    def run(self, task: str):
        # Step 1: Generate initial branches
        branches = self._generate_branches(task)
        # Step 2: Evaluate branches at each depth
        for depth in range(self.max_depth):
            # Evaluate each branch
            evaluations = self._evaluate_branches(task, branches, depth)
            # Select the best branches (keep top 2)
            branches = self._select_best(branches, evaluations, keep=2)
            # Expand each surviving branch
            if depth < self.max_depth - 1:
                branches = self._expand_branches(task, branches, depth)

        # Step 3: Select final best branch
        final_evaluations = self._evaluate_branches(task, branches, self.max_depth - 1)
        best_branch = self._select_best(branches, final_evaluations, keep=1)[0]
        return best_branch

    def _generate_branches(self, task: str) -> list[dict]:
        """Generate multiple initial approaches."""
        branches = []
        for i in range(self.num_branches):
            response = self.model.invoke([
                {"role": "system", "content": f"Propose approach {i+1} for this task. Think step-by-step."},
                {"role": "user", "content": task},
            ])
            branches.append({"id": i, "content": response.content, "depth": 0})
        return branches

    def _evaluate_branches(self, task, branches, depth) -> list[float]:
        """Evaluate each branch on a 0-10 scale."""
        evaluations = []
        for branch in branches:
            eval_response = self.model.invoke([
                {"role": "system", "content": "Rate this reasoning approach from 0-10. Consider: correctness, completeness, efficiency, and likelihood of success."},
                {"role": "user", "content": f"Task: {task}\nApproach: {branch['content']}\nRating:"},
            ])
            try:
                rating = float(eval_response.content.strip().split()[0])
            except ValueError:
                rating = 5.0
            evaluations.append(rating)
        return evaluations

    def _select_best(self, branches, evaluations, keep=2):
        """Keep the top-k branches by evaluation score."""
        paired = list(zip(branches, evaluations))
        paired.sort(key=lambda x: x[1], reverse=True)
        return [p[0] for p in paired[:keep]]

    def _expand_branches(self, task, branches, depth):
        """Expand each surviving branch with next reasoning steps."""
        new_branches = []
        for branch in branches:
            for j in range(self.num_branches):
                expansion = self.model.invoke([
                    {"role": "system", "content": f"Continue this reasoning approach with step {j+1}."},
                    {"role": "user", "content": f"Task: {task}\nCurrent approach:\n{branch['content']}\nNext step:"},
                ])
                new_branches.append({
                    "id": f"{branch['id']}-{j}",
                    "content": f"{branch['content']}\n{expansion.content}",
                    "depth": depth + 1,
                })
        return new_branches
```

ToT rules:
- Limit branches to 3 per depth level — more branches exponentially increase cost
- Limit depth to 2-3 — deeper trees rarely improve results enough to justify the cost
- Evaluate with a cheap model (Haiku/Mini) — rating is simpler than generation
- Generate with a capable model (Sonnet/GPT-4.1) — reasoning quality matters for branches
- Keep only 1-2 branches per evaluation round — pruning reduces cost significantly
- Total cost: branches × depth × evaluation + generation — a 3×3 ToT costs ~9-15 LLM calls

## Pattern 3: Planning-Validation Loop

Generate a plan, validate it for correctness and feasibility, then execute. The validation step catches errors before they waste execution resources:

```python
class PlanningValidationAgent:
    """Generate a plan, validate it, then execute validated steps."""

    def __init__(self, planner_model, validator_model, executor_model):
        self.planner = planner_model
        self.validator = validator_model
        self.executor = executor_model

    def run(self, task: str, max_planning_rounds=2):
        # Planning phase
        for round_num in range(max_planning_rounds):
            plan = self._generate_plan(task, round_num)
            validation = self._validate_plan(task, plan)

            if validation["valid"]:
                break  # Plan is good, proceed to execution

            # Revise plan based on validation feedback
            task = f"{task}\n\nPrevious plan had issues: {validation['feedback']}\nPlease revise."

        # Execution phase — execute the validated plan
        results = []
        for i, step in enumerate(plan):
            step_result = self._execute_step(step, i, results)
            results.append(step_result)

        # Post-execution validation
        final_result = self._synthesize(results)
        return final_result

    def _generate_plan(self, task: str, round_num: int) -> list[str]:
        response = self.planner.invoke([
            {"role": "system", "content": "Decompose the task into clear, sequential steps. Each step should be independently executable. Return a numbered list."},
            {"role": "user", "content": task},
        ])
        return parse_numbered_list(response.content)

    def _validate_plan(self, task: str, plan: list[str]) -> dict:
        """Validate the plan for correctness, completeness, and feasibility."""
        validation = self.validator.invoke([
            {"role": "system", "content": """Validate this plan. Check for:
1. Missing steps — are all necessary steps included?
2. Wrong order — are steps in the correct sequence?
3. Infeasible steps — can each step be executed with available tools?
4. Redundant steps — are there unnecessary steps?
Return: valid=true/false, feedback=specific issues to fix"""},
            {"role": "user", "content": f"Task: {task}\nPlan:\n{json.dumps(plan)}"},
        ])
        return parse_validation(validation.content)

    def _execute_step(self, step: str, step_num: int, previous_results: list) -> dict:
        response = self.executor.invoke([
            {"role": "system", "content": f"Execute step {step_num + 1}: {step}"},
            {"role": "user", "content": f"Previous results: {json.dumps(previous_results)}"},
        ])
        return {"step": step, "result": response.content}
```

Planning-validation rules:
- Use a strong model for planning (Sonnet/Opus) — plan quality determines execution quality
- Use a cheap model for validation (Haiku/Mini) — validation is simpler than generation
- Limit to 2 planning rounds — more rounds rarely improve the plan enough
- Validate for feasibility — check that each step can be executed with available tools
- Validate for completeness — check that the plan covers all aspects of the task
- Validate for order — check that prerequisite steps come before dependent steps

## Pattern 4: Hierarchical Task Network (HTN)

Decompose complex tasks into known methods (pre-defined decomposition patterns). HTN uses domain knowledge to choose the right decomposition strategy:

```python
class HTNAgent:
    """Hierarchical Task Network — decompose tasks using known methods."""

    # Pre-defined decomposition methods
    METHODS = {
        "research_report": {
            "subtasks": ["gather_data", "analyze_data", "write_report"],
            "ordering": "sequential",
        },
        "bug_fix": {
            "subtasks": ["reproduce_bug", "identify_root_cause", "implement_fix", "verify_fix"],
            "ordering": "sequential",
        },
        "data_pipeline": {
            "subtasks": ["extract_data", "transform_data", "validate_data", "load_data"],
            "ordering": "sequential",
        },
        "customer_support": {
            "subtasks": ["classify_issue", "find_solution", "verify_solution", "respond"],
            "ordering": "sequential",
        },
        "market_analysis": {
            "subtasks": ["gather_market_data", "analyze_trends", "assess_competitors", "synthesize_findings"],
            "ordering": "sequential",
        },
    }

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run(self, task: str):
        # Step 1: Classify the task into a known method
        method_name = self._classify_task(task)
        method = self.METHODS.get(method_name)

        if not method:
            # Unknown task — fall back to Plan+Execute
            return self._fallback_plan_execute(task)

        # Step 2: Decompose using the known method
        subtasks = method["subtasks"]

        # Step 3: Execute subtasks in order
        results = {}
        for subtask_name in subtasks:
            specific_task = self._specialize_subtask(task, subtask_name, results)
            result = self._execute_subtask(specific_task)
            results[subtask_name] = result

        return self._synthesize(task, results)

    def _classify_task(self, task: str) -> str:
        """Classify the task into a known method category."""
        response = self.classify_model.invoke([
            {"role": "system", "content": f"Classify this task into one of: {list(self.METHODS.keys())}. Return ONLY the category name."},
            {"role": "user", "content": task},
        ])
        return response.content.strip().lower()

    def _specialize_subtask(self, original_task, subtask_name, previous_results):
        """Specialize a generic subtask for the specific task context."""
        context = f"Original task: {original_task}\nSubtask: {subtask_name}"
        if previous_results:
            context += f"\nPrevious results: {json.dumps(previous_results)}"
        return context
```

HTN rules:
- Define methods for your domain's common task patterns — don't try to cover every possible task
- Fall back to Plan+Execute for unknown tasks — HTN can't decompose what it doesn't know
- Use a cheap model for classification — Haiku/Mini is sufficient for "which method?"
- Specialize subtasks with the original task context — generic subtasks need task-specific details
- Keep methods simple (3-5 subtasks) — complex methods defeat the purpose of structured decomposition

## Pattern 5: Temporal Reasoning

Agents that reason about time — before/after relationships, deadlines, scheduling:

```python
class TemporalReasoningAgent:
    """Agent that reasons about temporal constraints and deadlines."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run(self, task: str):
        # Step 1: Extract temporal constraints
        constraints = self._extract_temporal_constraints(task)

        # Step 2: Build a temporal plan respecting constraints
        plan = self._plan_with_constraints(task, constraints)

        # Step 3: Execute in order respecting temporal dependencies
        results = {}
        for step in plan:
            if self._prerequisites_met(step, results, constraints):
                result = self._execute_step(step)
                results[step["name"]] = result
            else:
                # Prerequisite not met — defer this step
                results[step["name"]] = "Deferred: prerequisites not met"

        return self._synthesize(task, results)

    def _extract_temporal_constraints(self, task: str) -> dict:
        """Extract temporal constraints from the task description."""
        response = self.model.invoke([
            {"role": "system", "content": """Extract temporal constraints from the task. Return JSON with:
- deadlines: list of {task, deadline, priority}
- dependencies: list of {before_task, after_task}
- time_budgets: list of {task, max_duration_minutes}"""},
            {"role": "user", "content": task},
        ])
        return json.loads(response.content)

    def _prerequisites_met(self, step, results, constraints):
        """Check if all prerequisites for a step are completed."""
        for dep in constraints.get("dependencies", []):
            if dep["after_task"] == step["name"] and dep["before_task"] not in results:
                return False
        return True
```

## Pattern 6: Constraint Satisfaction

Agents that reason within bounded constraints — budget limits, resource availability, policy rules:

```python
class ConstraintSatisfactionAgent:
    """Agent that checks feasibility against constraints before each action."""

    def __init__(self, model, tools, constraints: dict):
        self.model = model
        self.tools = tools
        self.constraints = constraints  # e.g., {"budget_usd": 5.0, "max_steps": 10, "allowed_tools": [...]}

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        spent = {"cost_usd": 0.0, "steps": 0}

        for step in range(max_steps):
            # Inject current constraints into the prompt
            constraint_prompt = self._build_constraint_prompt(spent)
            context_with_constraints = [
                {"role": "system", "content": f"{SYSTEM_PROMPT}\n{constraint_prompt}"},
                *context,
            ]

            response = self.model.invoke(context_with_constraints)

            # Check if proposed action satisfies constraints
            if response.tool_calls:
                for tc in response.tool_calls:
                    if not self._satisfies_constraints(tc, spent):
                        context.append({
                            "role": "tool",
                            "content": f"Action {tc.name} violates constraints. Choose a different approach.",
                        })
                        continue

                    tool = self.tools.get(tc.name)
                    result = json.dumps(tool(**tc.arguments))
                    spent["cost_usd"] += self._estimate_call_cost(tc)
                    spent["steps"] += 1
                    context.append({"role": "tool", "name": tc.name, "content": result})

            if response.finish_reason == "stop":
                return response.content
        return "Max steps reached"

    def _build_constraint_prompt(self, spent: dict) -> str:
        remaining_budget = self.constraints["budget_usd"] - spent["cost_usd"]
        remaining_steps = self.constraints["max_steps"] - spent["steps"]
        return f"""Current constraints:
- Budget remaining: ${remaining_budget:.2f} (total: ${self.constraints['budget_usd']})
- Steps remaining: {remaining_steps} (max: {self.constraints['max_steps']})
- Allowed tools: {self.constraints['allowed_tools']}
Work within these constraints. Do not exceed budget or step limits."""

    def _satisfies_constraints(self, tool_call, spent) -> bool:
        if tool_call.name not in self.constraints.get("allowed_tools", []):
            return False
        estimated_cost = self._estimate_call_cost(tool_call)
        if spent["cost_usd"] + estimated_cost > self.constraints["budget_usd"]:
            return False
        return True
```

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Using ToT for simple factual questions | 10+ LLM calls for a one-call answer | Use CoT for simple reasoning, ToT only for creative/exploratory tasks |
| No validation on generated plans | Flawed plans waste execution resources | Always validate plans before execution |
| HTN with too many methods | Classification becomes unreliable, agent can't choose | Keep 5-10 methods; fall back to Plan+Execute for unknowns |
| Self-consistency with temperature=0 | All paths produce identical answers | Use temperature>0 for diversity |
| Ignoring temporal dependencies | Steps execute out of order, produce wrong results | Extract and enforce before/after constraints |
| No constraint enforcement during execution | Agent exceeds budget or calls forbidden tools | Inject constraints into each step's prompt; validate before execution |

## References

- `agent-loop-patterns` — ReAct (Pattern 1) and Plan+Execute (Pattern 2) are the foundation for all planning
- `agent-guardrails` — Constraint satisfaction is a form of guardrail enforcement
- `agent-cost-optimization` — Budget constraints are a primary constraint in agent planning
- `agent-evaluation` — Evaluate planning quality as part of agent assessment

## Keywords

planning, reasoning, tree of thought, self-consistency, planning validation, hierarchical task network, HTN, temporal reasoning, constraint satisfaction, multi-step planning