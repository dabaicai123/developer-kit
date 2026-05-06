---
name: agent-human-interaction
description: "Rich human-in-the-loop patterns for agent systems: collaborative workflows, confidence-based escalation, multi-turn clarification, feedback incorporation, and explaining agent reasoning. Use when building agents that work alongside humans, need approval gates, or require clarification dialogs."
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

# Agent Human Interaction

Patterns for building agents that interact meaningfully with humans — beyond simple approve/reject approval gates. Covers collaborative workflows, confidence escalation, multi-turn clarification, feedback loops, and reasoning transparency.

## When to use this skill

- Building agents that need human approval before irreversible actions
- Implementing clarification dialogs when the agent is uncertain
- Creating collaborative workflows where humans and agents work together
- Adding confidence scoring and escalation to high-stakes agent decisions
- Explaining agent reasoning and decisions to human reviewers
- Collecting and incorporating human feedback into agent behavior

## Interaction Patterns Overview

| Pattern | Human Role | When to Use | Complexity |
|---|---|---|---|
| Approval gate | Reviewer | Irreversible actions (delete, deploy, send) | Low |
| Clarification dialog | Provider | Ambiguous inputs, missing context | Medium |
| Collaborative editing | Co-worker | Creative tasks, drafting, design | Medium |
| Confidence escalation | Escalation target | Low-confidence decisions, high stakes | Medium |
| Feedback loop | Teacher | Improving agent behavior over time | High |
| Reasoning explanation | Auditor | Understanding why the agent made a decision | Medium |

## Pattern 1: Approval Gates

The most basic HITL pattern. Agent pauses before executing an irreversible action, presents the action to a human, and waits for approval or rejection.

### Simple Approval

```python
class ApprovalGate:
    """Pause agent execution for human approval on irreversible actions."""

    IRREVERSIBLE_ACTIONS = ["delete", "deploy", "send_email", "financial_transaction"]

    def check(self, tool_name: str, args: dict) -> dict:
        if tool_name in self.IRREVERSIBLE_ACTIONS:
            return {
                "needs_approval": True,
                "action": tool_name,
                "args": args,
                "message": f"Agent wants to {tool_name}. Approve?",
            }
        return {"needs_approval": False}

    def handle_approval(self, response: dict) -> bool:
        return response.get("approved", False)


class ApprovalAwareAgent:
    """Agent that pauses for approval on irreversible actions."""

    def __init__(self, model, tools, approval_handler):
        self.model = model
        self.tools = tools
        self.approval = approval_handler

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        for step in range(max_steps):
            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                return response.content

            for tc in response.tool_calls:
                gate = self.approval.check(tc.name, tc.arguments)
                if gate["needs_approval"]:
                    # Present to human and wait
                    human_decision = self.approval.present_to_human(gate)
                    if not human_decision["approved"]:
                        # Inject rejection back into context
                        context.append({
                            "role": "tool",
                            "name": tc.name,
                            "content": f"Action rejected by human: {human_decision.get('reason', 'No reason provided')}",
                        })
                        continue
                    # Human may modify arguments
                    modified_args = human_decision.get("modified_args", tc.arguments)

                tool = self.tools.get(tc.name)
                result = json.dumps(tool(**modified_args if gate["needs_approval"] else tc.arguments))
                context.append({"role": "tool", "name": tc.name, "content": result})
        return "Max steps reached"
```

Approval rules:
- Only gate irreversible actions — approve/reject is overkill for read-only tool calls
- Allow humans to modify arguments, not just approve/reject — they may correct typos or adjust values
- Include the reason for the action in the approval prompt — "Agent wants to send email to X about Y"
- Inject rejection back into context — the agent can try a different approach
- Log all approval decisions for audit trails

## Pattern 2: Clarification Dialog

When the agent cannot proceed because the input is ambiguous, it asks the human for clarification:

```python
class ClarificationAgent:
    """Agent that asks clarifying questions before proceeding."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run(self, task: str, max_rounds=3):
        context = [{"role": "user", "content": task}]

        for round_num in range(max_rounds):
            # Check if we need clarification
            needs_clarification = self._check_clarity(context)
            if needs_clarification:
                question = self._generate_question(context)
                # Ask human
                human_answer = self._get_human_response(question)
                context.append({"role": "assistant", "content": question})
                context.append({"role": "user", "content": human_answer})
                continue

            # Proceed with task execution
            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                return response.content
            # Process tool calls...
        return "Max clarification rounds reached"

    def _check_clarity(self, context):
        """Use a cheap model to check if the task is clear enough."""
        clarity_check = self.clarity_model.invoke([
            {"role": "system", "content": "Is this task clear enough to proceed, or does it need clarification? Answer: clear or unclear."},
            {"role": "user", "content": json.dumps([m["content"] for m in context])},
        ])
        return "unclear" in clarity_check.content.lower()

    def _generate_question(self, context):
        """Generate a specific clarifying question."""
        question_response = self.model.invoke([
            {"role": "system", "content": "Generate ONE specific clarifying question about the task. Be concise."},
            *context,
        ])
        return question_response.content
```

Clarification rules:
- Limit to 2-3 rounds — more rounds wastes time and frustrates users
- Ask ONE specific question per round — not "tell me more about everything"
- Use a cheap model for clarity checking — Haiku/Mini is sufficient
- Include the original task context in the clarity check — not just the latest message
- Fall back to best-guess execution after max rounds — don't loop forever asking questions

## Pattern 3: Confidence Escalation

Agent estimates its confidence in a decision. Low-confidence decisions are escalated to humans:

```python
class ConfidenceEscalationAgent:
    """Agent that escalates low-confidence decisions to humans."""

    CONFIDENCE_THRESHOLD = 0.7  # Escalate below 70% confidence

    def __init__(self, model, tools, escalation_handler):
        self.model = model
        self.tools = tools
        self.escalation = escalation_handler

    def run(self, task: str, max_steps=10):
        context = [{"role": "user", "content": task}]
        for step in range(max_steps):
            response = self.model.invoke(context)
            if response.finish_reason == "stop":
                confidence = self._estimate_confidence(response.content, task)
                if confidence < self.CONFIDENCE_THRESHOLD:
                    # Escalate to human
                    human_decision = self.escalation.escalate({
                        "task": task,
                        "agent_output": response.content,
                        "confidence": confidence,
                        "reason": self._get_low_confidence_reason(context),
                    })
                    return human_decision
                return response.content
            # Process tool calls...
        return "Max steps reached"

    def _estimate_confidence(self, output: str, task: str) -> float:
        """Use a model to estimate confidence in the output."""
        confidence_response = self.confidence_model.invoke([
            {"role": "system", "content": "Rate your confidence in this answer from 0.0 to 1.0. Consider: completeness, accuracy, and whether the answer fully addresses the task."},
            {"role": "user", "content": f"Task: {task}\nAnswer: {output}\nConfidence:"},
        ])
        try:
            return float(confidence_response.content.strip())
        except ValueError:
            return 0.5  # Default to medium confidence if parsing fails
```

Escalation rules:
- Set threshold based on task stakes: 0.9 for financial/medical, 0.7 for general, 0.5 for exploratory
- Include the reason for low confidence — not just the score. "I'm uncertain because the data is incomplete"
- Allow humans to override with a direct answer — not just approve/reject
- Track escalation rates — if >30% of decisions are escalated, the agent needs improvement
- Use confidence estimation sparingly — it adds an LLM call per decision. Only for high-stakes steps

## Pattern 4: Collaborative Editing

Human and agent work together on a shared artifact (document, code, design). The agent produces drafts, the human edits, and the agent iterates:

```python
class CollaborativeAgent:
    """Agent and human co-edit a document through iterative drafts."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run(self, task: str, max_iterations=3):
        document = ""
        for iteration in range(max_iterations):
            # Agent produces or revises draft
            draft = self._produce_draft(task, document, iteration)
            # Present to human for editing
            human_edit = self._get_human_edit(draft, iteration)
            if human_edit.get("accepted"):
                document = draft
                break
            # Human provides edits and feedback
            document = human_edit["edited_document"]
            feedback = human_edit["feedback"]
            # Agent revises based on feedback
            revised = self._revise(document, feedback)
            document = revised
        return document

    def _produce_draft(self, task, current_doc, iteration):
        if iteration == 0:
            prompt = f"Create a draft for: {task}"
        else:
            prompt = f"Revise this document based on feedback:\n{current_doc}"
        response = self.model.invoke([{"role": "user", "content": prompt}])
        return response.content

    def _revise(self, document, feedback):
        response = self.model.invoke([
            {"role": "system", "content": "Revise the document based on the human's feedback."},
            {"role": "user", "content": f"Current document:\n{document}\n\nFeedback:\n{feedback}"},
        ])
        return response.content
```

Collaboration rules:
- Limit to 3 iterations — diminishing returns after 3 rounds of revision
- Present the full draft to humans, not just changes — they need to see the context
- Collect structured feedback: what to change, why, and priority level
- Track which feedback items the agent addressed — accountability for iteration
- Allow humans to accept partial drafts — they can continue editing themselves

## Pattern 5: Feedback Loop

Collect human feedback on agent outputs and use it to improve future behavior:

```python
class FeedbackCollector:
    """Collect and store human feedback for agent improvement."""

    def __init__(self, store):
        self.store = store

    def collect(self, run_id: str, task: str, agent_output: str, human_feedback: dict):
        """Store feedback from a single run."""
        self.store.save({
            "run_id": run_id,
            "task": task,
            "agent_output": agent_output,
            "human_rating": human_feedback.get("rating"),  # 1-5 scale
            "human_correction": human_feedback.get("correction"),  # What the agent should have done
            "human_notes": human_feedback.get("notes"),
            "timestamp": now(),
        })

    def get_patterns(self, limit=50):
        """Analyze recent feedback for improvement patterns."""
        recent = self.store.query(limit=limit)
        patterns = []
        # Identify common failure patterns
        low_rated = [f for f in recent if f["human_rating"] <= 2]
        if len(low_rated) > recent.count * 0.2:
            patterns.append({
                "type": "quality",
                "message": "More than 20% of recent runs rated <= 2. Agent needs prompt revision.",
            })
        # Identify specific correction themes
        corrections = [f["human_correction"] for f in low_rated if f["human_correction"]]
        common_themes = self._extract_common_themes(corrections)
        return patterns + common_themes


class FeedbackAwareAgent:
    """Agent that uses past feedback to improve its prompts."""

    def __init__(self, model, tools, feedback_collector):
        self.model = model
        self.tools = tools
        self.feedback = feedback_collector

    def run(self, task: str, max_steps=10):
        # Inject recent feedback patterns into prompt
        recent_feedback = self.feedback.get_patterns(limit=10)
        feedback_instructions = self._format_feedback_as_instructions(recent_feedback)

        context = [
            {"role": "system", "content": f"{SYSTEM_PROMPT}\n\nRecent feedback to learn from:\n{feedback_instructions}"},
            {"role": "user", "content": task},
        ]
        # Execute agent loop...
```

Feedback rules:
- Make feedback collection easy — 1-click rating + optional text, not mandatory essays
- Analyze feedback weekly — patterns emerge over time, not from individual responses
- Inject feedback as instructions, not conversation history — keep it in the system prompt
- Don't over-correct from single feedback items — look for patterns across multiple runs
- Track whether feedback improves outcomes — if ratings don't improve, the feedback loop isn't working

## Pattern 6: Reasoning Explanation

Make agent decisions transparent by explaining reasoning to humans:

```python
class ExplainableAgent:
    """Agent that explains its reasoning at each step."""

    def __init__(self, model, tools):
        self.model = model
        self.tools = tools

    def run_with_explanation(self, task: str):
        context = [{"role": "user", "content": task}]
        explanation_log = []

        for step in range(self.max_steps):
            response = self.model.invoke([
                {"role": "system", "content": "For each action, explain WHY you chose it. Format: REASONING: <why> ACTION: <what>"},
                *context,
            ])

            # Parse reasoning and action
            reasoning, action = self._parse_reasoned_response(response.content)
            explanation_log.append({
                "step": step,
                "reasoning": reasoning,
                "action": action,
                "alternatives": self._get_alternatives(task, context),
            })

            if response.finish_reason == "stop":
                return AgentResult(
                    output=response.content,
                    explanations=explanation_log,
                )
            # Process tool calls...
        return "Max steps reached"
```

Explanation rules:
- Explain WHY, not WHAT — "I chose search because the data isn't in local context" not "I called search"
- Show alternatives considered — "I could have used database_query, but search covers broader sources"
- Keep explanations concise — one sentence per step, not paragraphs
- Store explanations in a structured log — queryable for audit and debugging
- Make explanations available to the client UI — collapsible "Show reasoning" sections

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Approval gates on every tool call | Overwhelming for humans, slows down the agent | Only gate irreversible or high-stakes actions |
| Endless clarification loops | Frustrates users, wastes time | Limit to 2-3 rounds; fall back to best-guess |
| Escalating every low-confidence decision | Humans do all the work, agent is useless | Set threshold based on stakes; only escalate high-stakes |
| No feedback collection | Agent never improves | Make feedback easy (1-click rating) and analyze weekly |
| Explaining WHAT instead of WHY | Doesn't help humans understand or trust | Explain reasoning and alternatives, not actions |
| Rejecting without context | Human doesn't know why the agent wanted the action | Include reason and context in approval prompts |
| Mandatory long-form feedback | Users skip it, feedback is never collected | Use quick ratings + optional text |

## References

- `agent-guardrails` — Policy-as-code and approval gate implementation
- `agent-streaming-realtime` — WebSocket patterns for real-time human interaction
- `agent-evaluation` — Evaluation methodology that feeds into the feedback loop
- `langgraph-patterns` — `interrupt()` for LangGraph human-in-the-loop
- `agent-loop-patterns` — Reflection pattern (Pattern 3) as self-review before escalation

## Keywords

human-in-the-loop, approval gate, clarification dialog, confidence escalation, collaborative editing, feedback loop, reasoning explanation, HITL, explainable agent, human-agent interaction