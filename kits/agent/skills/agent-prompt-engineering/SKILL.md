---
name: agent-prompt-engineering
description: "System prompt assembly for agents: SOUL.md/AGENTS.md separation, prompt assembly order, skill catalog injection, progressive 3-tier loading, re-injection near context end, prompt versioning, chain-of-thought prompting, context budget management, and anti-patterns. Use when designing agent system prompts, structuring multi-tool agent instructions, or managing prompt context budgets."
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

# Agent Prompt Engineering

System prompt assembly patterns for production agents. How to structure, order, inject, compress, and version the instructions that drive agent behavior. A well-assembled prompt determines agent performance more than model choice or tool count.

## When to use this skill

- Designing the system prompt for a new agent
- Structuring instructions for a multi-tool agent
- Deciding what goes in SOUL.md vs AGENTS.md
- Managing context budget as the conversation grows
- Debugging agents that forget instructions or lose focus
- Versioning prompts like code with tracked changes
- Implementing progressive skill loading to reduce token cost

## SOUL.md / AGENTS.md Separation

Separate personality (SOUL.md) from operational instructions (AGENTS.md). This pattern converged independently by OpenClaw, Claude Code, and Hermes Agent. Personality is stable; operational instructions change frequently.

### SOUL.md — Personality and Identity

Who the agent is. Tone, values, communication style. Changes rarely — maybe once per quarter.

```markdown
# SOUL.md

You are Atlas, a senior backend engineer specialized in distributed systems.

## Personality
- Direct and concise — no filler phrases, no hedging
- Explain trade-offs, not just solutions — "Option A is simpler but Option B handles edge cases"
- Acknowledge uncertainty — "I'm 80% confident this approach works; the risk is..."
- Prioritize correctness over speed — a wrong answer is worse than a slow correct one

## Values
- Production safety first — never suggest changes that could break existing functionality
- Simplicity over cleverness — prefer straightforward solutions over elegant but obscure ones
- Test evidence over intuition — every claim about behavior should be verifiable by a test

## Communication Style
- Use imperative mood for instructions: "Add rate limiting to the endpoint"
- Use declarative mood for observations: "The current implementation lacks rate limiting"
- Never use motivational language: no "Let's", "Great", "Awesome"
```

### AGENTS.md — Operational Instructions

What the agent does. Rules, workflows, tool usage, decision criteria. Changes frequently — with every sprint, every new tool, every policy update.

```markdown
# AGENTS.md

## Operational Rules

1. Always read existing code before suggesting changes
2. Run tests after every code modification
3. Use the project's existing patterns — do not introduce new patterns without explicit request
4. When multiple solutions exist, list trade-offs and recommend one with justification
5. Never modify files outside the current working directory unless explicitly asked

## Tool Usage
- Use `search_code` before `read_file` when you don't know which file to read
- Use `run_tests` after every edit to verify no regressions
- Use `git_diff` to review changes before committing

## Decision Criteria
- If a change affects 3+ files, propose a plan first and wait for confirmation
- If unsure about a pattern, search for existing examples in the codebase
- If a tool call fails, read the error message carefully and adjust the approach
```

Why separation matters:
- SOUL.md is injected once at conversation start — stable, low token cost
- AGENTS.md is re-injected after compaction — changes preserved even when context is compressed
- Different change cadences — personality rarely changes; operational rules change weekly
- Affects model attention differently — personality sets tone, operational rules set behavior

## System Prompt Assembly Order

The order of sections in the system prompt determines which instructions the model prioritizes. Later sections have stronger influence on immediate behavior.

Assembly order (from top to bottom):

| Position | Section | Token Cost | Change Frequency | Why This Position |
|---|---|---|---|---|
| 1 | Identity/persona (SOUL.md) | ~200 | Rarely | Sets tone for all subsequent instructions |
| 2 | Operational rules (AGENTS.md) | ~500 | Frequently | Behavior constraints that apply to every turn |
| 3 | Tool descriptions | ~100-6000 | Per tool change | The agent needs tools to act — must be present |
| 4 | Context/data | Variable | Per turn | Task-specific data that changes every interaction |
| 5 | Task-specific instructions | ~100 | Per task | Most influential on immediate behavior — put last |

**Critical rule: never put task instructions at the start.** As context grows, instructions at the beginning get "centrifuged" away from the model's attention. Instructions near the end of context have the strongest influence on the current response.

```python
def assemble_prompt(soul_md, agents_md, tools, context_data, task_instructions):
    sections = [
        {"role": "system", "content": soul_md},
        {"role": "system", "content": agents_md},
        {"role": "system", "content": format_tool_descriptions(tools)},
    ]
    if context_data:
        sections.append({"role": "system", "content": format_context(context_data)})
    sections.append({"role": "system", "content": task_instructions})
    return sections
```

## Skill Catalog Injection

Skills as markdown files injected into prompts. Each skill is a focused, versioned document that teaches the agent a specific capability. CrewAI uses `skills=[]` parameter; Claude Code injects skill files from a directory.

```python
class SkillCatalog:
    def __init__(self, skills_dir="skills/"):
        self.skills_dir = skills_dir
        self.loaded_skills = {}

    def discover_skills(self):
        skills = []
        for f in os.listdir(self.skills_dir):
            if f.endswith(".md"):
                skill_name = f.replace(".md", "")
                skills.append(skill_name)
        return skills

    def inject_skill(self, skill_name, tier="tier2"):
        if skill_name not in self.loaded_skills:
            path = f"{self.skills_dir}{skill_name}.md"
            with open(path) as f:
                self.loaded_skills[skill_name] = f.read()
        content = self.loaded_skills[skill_name]
        if tier == "tier1":
            lines = content.split("\n")
            for line in lines:
                if line.startswith("description:"):
                    return f"Skill: {skill_name} — {line.split('description:')[1].strip().strip('"')}"
        return content

    def inject_relevant_skills(self, task_description, max_skills=3):
        all_skills = self.discover_skills()
        skill_selection_prompt = [
            {"role": "system", "content": f"Available skills: {', '.join(all_skills)}"},
            {"role": "user", "content": f"Which skills are relevant for this task? Task: {task_description}. Return skill names only, comma-separated."},
        ]
        response = agent.call(skill_selection_prompt)
        selected = [s.strip() for s in response.content.split(",") if s.strip() in all_skills]
        injected = []
        for skill in selected[:max_skills]:
            injected.append({"role": "system", "content": self.inject_skill(skill)})
        return injected
```

Skill injection rules:
- Inject only relevant skills per task — the agent wastes tokens reading unrelated skill documents
- Maximum 3 skills per task — more than 3 dilutes focus and exceeds context budget
- Use Tier 1 for discovery, Tier 2 for injection, Tier 3 for detailed reference on demand
- Skills are versioned markdown files — treat them as code, not ad-hoc text

## Progressive 3-Tier Loading

Three-tier loading strategy for skills, tool descriptions, and instructions. Cuts token cost by 94% compared to loading everything at full detail.

| Tier | Content | Tokens per Skill/Tool | When to Load |
|---|---|---|---|
| Tier 1 | Name + one-line summary | ~20 | Always (every LLM call) |
| Tier 2 | Full description + parameter names | ~100 | When the agent selects this skill/tool |
| Tier 3 | Complete reference + examples + edge cases | ~300 | When the agent is about to execute |

```python
class ProgressiveLoader:
    def __init__(self, registry):
        self.registry = registry

    def get_tier1_injection(self):
        lines = []
        for name, entry in self.registry.items():
            lines.append(f"- {name}: {entry['tier1']['summary']}")
        return "Available capabilities:\n" + "\n".join(lines)

    def get_tier2_injection(self, selected_names):
        sections = []
        for name in selected_names:
            entry = self.registry[name]
            sections.append(f"## {name}\n{entry['tier2']['description']}")
            if "parameters" in entry["tier2"]:
                for param, info in entry["tier2"]["parameters"].items():
                    sections.append(f"- {param}: {info['type']}, {info.get('description', '')}")
        return "\n\n".join(sections)

    def get_tier3_injection(self, name):
        entry = self.registry[name]
        return entry["tier3"]["full_content"]
```

Cost comparison for 20 skills:
- Full loading: 20 x 300 = 6000 tokens per call
- Tier 1 always + Tier 2 on demand: 20 x 20 + 3 x 100 = 700 tokens per call
- Savings: 94%

## Re-injection Near End of Context

Instruction centrifugation: as context fills with conversation turns, tool outputs, and observations, instructions at the beginning of the system prompt lose influence on the model's current behavior. The model's attention focuses on recent context.

Solution: re-inject critical instructions near the end of the context window after compaction or when context exceeds a threshold.

```python
CRITICAL_INSTRUCTIONS = """
## Reminder — Operational Rules
1. Always read existing code before suggesting changes
2. Run tests after every code modification
3. Never modify files outside the working directory
4. When unsure, search for existing patterns before proposing new ones
"""

def manage_context(messages, context_budget=8000, compaction_threshold=0.7):
    current_tokens = estimate_tokens(messages)
    if current_tokens > context_budget * compaction_threshold:
        messages = compact_messages(messages)
        messages.append({"role": "system", "content": CRITICAL_INSTRUCTIONS})
    return messages
```

Re-injection rules:
- After every compaction, re-inject operational rules and task instructions
- Re-inject task-specific instructions — the original task statement is the most critical context
- Re-inject tool descriptions if the agent will need them for remaining steps
- Never re-inject the entire original system prompt — only the rules and task that matter for the current step

## Prompt Versioning

Treat prompts as code: version number, change date, reason, and performance comparison.

```python
class PromptVersion:
    def __init__(self, version, change_date, reason, content, eval_results=None):
        self.version = version
        self.change_date = change_date
        self.reason = reason
        self.content = content
        self.eval_results = eval_results

PROMPT_HISTORY = [
    PromptVersion(
        version="1.0.0",
        change_date="2024-10-01",
        reason="Initial prompt for research agent",
        content="...",
        eval_results={"pass_rate": 0.72, "avg_steps": 4.2},
    ),
    PromptVersion(
        version="1.1.0",
        change_date="2024-11-15",
        reason="Added explicit tool selection criteria and error recovery rules",
        content="...",
        eval_results={"pass_rate": 0.85, "avg_steps": 3.1},
    ),
    PromptVersion(
        version="1.2.0",
        change_date="2025-01-10",
        reason="Separated SOUL.md from AGENTS.md, added progressive skill loading",
        content="...",
        eval_results={"pass_rate": 0.89, "avg_steps": 2.8},
    ),
]

def get_current_prompt():
    return PROMPT_HISTORY[-1]

def compare_versions(version_a, version_b):
    a = next(v for v in PROMPT_HISTORY if v.version == version_a)
    b = next(v for v in PROMPT_HISTORY if v.version == version_b)
    return {
        "pass_rate_delta": b.eval_results["pass_rate"] - a.eval_results["pass_rate"],
        "steps_delta": b.eval_results["avg_steps"] - a.eval_results["avg_steps"],
        "reason": b.reason,
    }
```

Versioning rules:
- Every prompt change gets a version, date, and reason — never modify prompts without a record
- Run evals before and after changes — compare pass rate and step count to quantify impact
- Breaking changes (different instruction structure, new rules) bump the minor version
- Additive changes (new skill, tool description update) bump the patch version
- Store all versions — rollback is always possible

## Chain-of-Thought Prompting for Agents

Structured reasoning pattern for agents: ANALYZE → CHECK → PLAN → VERIFY. Each step produces explicit output that the next step consumes.

```python
COT_TEMPLATE = """
## Reasoning Framework

Before every action, follow this sequence:

1. ANALYZE — What is the current state? What information do I have? What is missing?
2. CHECK — Are there constraints or rules that apply? Is the action safe and permitted?
3. PLAN — What sequence of actions will achieve the goal? Which tools do I need?
4. VERIFY — After each action, did the result match expectations? If not, adjust the plan.

Output each step explicitly before acting. Never skip a step.
"""

def inject_cot(system_prompt):
    system_prompt.append({"role": "system", "content": COT_TEMPLATE})
    return system_prompt
```

Chain-of-thought rules for agents:
- Every significant action must go through all 4 steps — skip only for trivial lookups
- ANALYZE output must state what information is available and what is missing
- CHECK must explicitly reference applicable rules and constraints
- PLAN must list the sequence of tool calls before executing them
- VERIFY must compare the actual result against the expected result before proceeding
- The reasoning output is visible in the conversation — it adds to context but improves decision quality

## Context Budget Management

As the conversation grows, manage what stays in context, what gets compressed, and what gets dropped.

| What | Keep | Compress | Drop |
|---|---|---|---|
| System prompt (identity + rules) | Always | Never | Never |
| Task instructions | Always | Summarize | Never — re-inject after compaction |
| Tool descriptions | Relevant only | Tier 1 only | Irrelevant tools |
| Recent conversation turns | Last 3-5 | Older turns | Turns with no decisions |
| Tool outputs | Key results only | Summarize details | Intermediate outputs no longer needed |
| Skill content | Active skill only | Never | Inactive skills |

```python
class ContextBudgetManager:
    def __init__(self, total_budget=128000, reserved_ratio=0.5):
        self.total_budget = total_budget
        self.reserved = int(total_budget * reserved_ratio)
        self.working_limit = total_budget - self.reserved

    def should_compact(self, current_tokens):
        return current_tokens > self.working_limit * 0.7

    def compact(self, messages):
        system_messages = [m for m in messages if m["role"] == "system"]
        recent_turns = [m for m in messages if m["role"] != "system"][-6:]
        older_turns = [m for m in messages if m["role"] != "system"][:-6]
        if older_turns:
            summary = compress_turns(older_turns)
            return system_messages + [
                {"role": "system", "content": f"Compressed history:\n{summary}"},
            ] + recent_turns + [
                {"role": "system", "content": CRITICAL_INSTRUCTIONS},
            ]
        return messages

    def prioritize_tools(self, all_tools, current_task):
        relevant = select_relevant_tools(all_tools, current_task)
        tier1 = [t["tier1"] for t in all_tools]
        tier2 = [t["tier2"] for t in relevant]
        return format_tool_descriptions(tier1, tier2)
```

Budget management rules:
- Reserve 50% of context for output generation — the model needs space to think and respond
- Compact at 70% of working budget — compact early, not when the window is full
- Always preserve system prompt and task instructions — these are never dropped
- Drop irrelevant tools and inactive skills — the agent discovers them when needed
- Re-inject critical instructions after compaction — compaction removes them from context

## Anti-Patterns

- **Mega-prompts** — a single 5000-token system prompt that covers everything. The model cannot prioritize among dozens of instructions. Split into SOUL.md (personality) + AGENTS.md (rules) + skill files (specialized knowledge). Each section is small, focused, and versioned independently.

- **Unversioned prompts** — modifying prompts without tracking changes. When agent behavior degrades, there is no baseline for comparison. Every prompt change gets a version, date, reason, and eval comparison.

- **Task instructions at the start** — instructions placed at the beginning of the system prompt lose influence as context grows. Task-specific instructions must be near the end of context, where the model's attention is strongest.

- **No compaction strategy** — letting context grow until the model truncates it. Truncation is random — it may drop critical instructions. Explicit compaction preserves what matters and removes what does not.

- **Injecting all skills at full detail** — loading every skill document at Tier 3 detail level. With 20 skills at 300 tokens each, that is 6000 tokens wasted on skills the agent may never use. Progressive loading cuts this to 400 tokens at Tier 1.

- **Auto-injecting all memory into every call** — loading the entire conversation history and all long-term memory into every LLM call. The model wastes attention on irrelevant history. Let the agent decide when to retrieve memory.

- **Prompt changes without eval comparison** — changing a prompt and deploying without measuring impact. A "small" wording change can drop pass rate by 10%. Always eval before and after.

## References

- Anthropic Tool Use: https://docs.anthropic.com/en/docs/build-with-claude/tool-use
- OpenAI Function Calling: https://platform.openai.com/docs/guides/function-calling
- MCP Specification: https://modelcontextprotocol.io/specification
- CrewAI Knowledge: https://docs.crewai.com/concepts/knowledge