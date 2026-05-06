---
name: agent-context-management
description: "Context window management for agents: compression strategies (summary, sliding window, semantic, entity extraction, prompt distillation, hierarchical), trigger mechanisms, re-injection patterns, and sub-agent isolation. Use when building long-running agents or managing context window fill."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Context Management

Context window management for agents. Context quality degrades early, not late. Compression must start before the window fills. This skill covers six compression strategies, trigger mechanisms, re-injection patterns, and sub-agent context isolation.

## When to use this skill

- Building agents that run for more than 10 steps
- Designing a compression strategy for long-running agent sessions
- Implementing re-injection to preserve system prompt influence
- Deciding when to use sub-agents for context isolation
- Choosing between summary, sliding window, semantic, or hierarchical compression
- Setting up compression trigger thresholds

## Context Quality Degradation

Context quality degrades at approximately 25% window fill, not at 100%. Every frontier model tested shows this pattern (Chroma Research, 18 models). As the context window fills, the model's ability to follow instructions, retrieve relevant information, and maintain coherence declines steadily.

The degradation curve is not linear. The first 25% fill causes noticeable quality loss. The last 25% causes catastrophic failure. Plan compression early, not when you are running out of space.

**Instruction centrifugation** — system prompt influence fades as context grows. The model pays more attention to recent messages and less to instructions at the beginning of the window. This is not a bug; it is how attention mechanisms work. The solution is re-injection: repeat key instructions near the end of the context where the model is paying attention.

## Six Compression Strategies

### 1. Summary Compression

Summarize old conversation turns into a condensed narrative. Keep the last N turns in full. Replace everything before that with a summary.

```python
def summary_compress(messages, keep_recent=5):
    if len(messages) <= keep_recent:
        return messages

    old_messages = messages[:-keep_recent]
    recent_messages = messages[-keep_recent:]

    summary = summarize_conversation(old_messages)

    compressed = [
        {"role": "system", "content": f"Conversation summary: {summary}"},
    ] + recent_messages

    return compressed
```

**When to use:** General-purpose compression. Works for most agent sessions. The summary preserves the narrative arc (what was discussed, what was decided) while dropping raw details.

**Tradeoff:** Summaries lose specificity. Fine-grained details from early turns may not survive summarization.

### 2. Sliding Window

Keep the last N messages. Drop everything older than N. No summarization.

```python
def sliding_window_compress(messages, max_messages=20):
    compressed = messages[-max_messages:]

    important_indices = []
    for i, msg in enumerate(messages):
        if is_important(msg):
            important_indices.append(i)

    for idx in important_indices:
        msg = messages[idx]
        if msg not in compressed:
            compressed.insert(0, msg)

    return compressed
```

**When to use:** Simple agents where recent context is sufficient. Fast, no LLM call needed for compression.

**Tradeoff:** Loses all history older than N. No narrative continuity. The `is_important` check preserves critical messages (task instructions, key decisions) that would otherwise be dropped.

### 3. Semantic Compression

Embed each message. Compute relevance to the current task. Drop messages with the lowest relevance scores.

```python
def semantic_compress(messages, current_query, keep_top_k=15):
    embeddings = [embed(msg["content"]) for msg in messages]
    query_embedding = embed(current_query)

    scores = [
        cosine_similarity(emb, query_embedding)
        for emb in embeddings
    ]

    ranked_indices = sorted(
        range(len(scores)),
        key=lambda i: scores[i],
        reverse=True,
    )

    kept_indices = ranked_indices[:keep_top_k]
    kept_indices.sort()

    return [messages[i] for i in kept_indices]
```

**When to use:** RAG-heavy agents where retrieved chunks dominate the context. Semantic compression removes chunks that are no longer relevant to the current query.

**Tradeoff:** Requires an embedding model. Embedding cost adds latency to compression. Not suitable for agents with fast step cycles.

### 4. Entity Extraction

Extract key entities and facts from conversation history. Drop raw messages. Keep extracted facts as structured data.

```python
def entity_compress(messages):
    entities = extract_entities(messages)

    facts = []
    for entity in entities:
        facts.append(f"{entity.name}: {entity.attributes}")

    compressed = [
        {"role": "system", "content": f"Known entities and facts:\n" + "\n".join(facts)},
    ] + [messages[-1]]

    return compressed
```

**When to use:** Agents tracking specific entities (customers, accounts, tickets). Entity facts are stable and compact — they compress well.

**Tradeoff:** Loses the reasoning process. You know the facts, but not how they were derived. Not suitable for agents where reasoning history matters.

### 5. Prompt Distillation

Compress the system prompt to essentials. Remove verbose explanations, examples, and formatting. Keep only the instructions the model must follow.

```python
def distill_prompt(system_prompt):
    distilled = summarize_instructions(system_prompt)
    return distilled
```

**When to use:** When the system prompt is large (500+ tokens) and the agent needs more room for conversation context. Distillation preserves the behavioral instructions while removing explanatory text the model does not need to follow the instructions.

**Tradeoff:** Over-distillation removes nuance. The model follows the distilled instructions but may miss edge cases that the verbose prompt covered.

### 6. Hierarchical Context

Three tiers of detail. Short summary of everything. Medium detail for recent turns. Full detail for the current turn.

```python
def hierarchical_compress(messages):
    tiers = {
        "full": messages[-2:],
        "medium": summarize(messages[-8:-2]),
        "short": summarize(messages[:-8]),
    }

    compressed = [
        {"role": "system", "content": f"Background: {tiers['short']}"},
        {"role": "system", "content": f"Recent context: {tiers['medium']}"},
    ] + tiers["full"]

    return compressed
```

**When to use:** Long-running agents that need both historical context and recent detail. The best general-purpose strategy for production agents that run for 50+ steps.

**Tradeoff:** Three compression passes (or three summary calls). Higher compression cost. The result is higher quality than any single-pass strategy.

## What Survives Compression

**Always keep:**

1. Current task instruction — what the agent is doing right now
2. Recent tool results — the output from the last 3-5 tool calls
3. Key decisions/outcomes — facts the agent committed to (e.g., "decided to use PostgreSQL")
4. Entity facts — extracted entities and their attributes

**Always drop:**

1. Raw conversation history older than N turns
2. Duplicate information — repeated facts, redundant tool outputs
3. Low-relevance retrieved chunks — RAG chunks no longer relevant to the current query
4. Intermediate reasoning steps — the "thinking out loud" that led to a decision, once the decision is recorded

## Trigger Strategies

Compression must happen before quality degrades. Do not wait until the window is full.

### Token Count Threshold

Trigger compression when the token count exceeds a percentage of the window. Start at 50%.

```python
class CompressionTrigger:
    def __init__(self, max_tokens, threshold_pct=0.50):
        self.max_tokens = max_tokens
        self.threshold_pct = threshold_pct

    def should_compress(self, current_tokens):
        return current_tokens >= self.max_tokens * self.threshold_pct
```

### Step Count Threshold

Trigger compression every N steps, regardless of token count. Use for agents with variable-length tool outputs.

```python
class StepTrigger:
    def __init__(self, compress_every=10):
        self.compress_every = compress_every
        self.step_count = 0

    def should_compress(self):
        self.step_count += 1
        return self.step_count % self.compress_every == 0
```

### Quality Signal

Trigger compression when retrieved chunks no longer seem relevant to the current query. This detects semantic drift before it causes quality loss.

```python
class QualityTrigger:
    def __init__(self, relevance_threshold=0.3):
        self.relevance_threshold = relevance_threshold

    def should_compress(self, retrieved_chunks, current_query):
        if not retrieved_chunks:
            return False
        avg_relevance = mean([
            cosine_similarity(embed(chunk), embed(current_query))
            for chunk in retrieved_chunks
        ])
        return avg_relevance < self.relevance_threshold
```

### Combined Strategy

Use multiple triggers. Compress when any trigger fires. This prevents gaps where a single trigger misses degradation.

```python
class CombinedTrigger:
    def __init__(self, triggers):
        self.triggers = triggers

    def should_compress(self, **kwargs):
        return any(trigger.should_compress(**kwargs) for trigger in self.triggers)

trigger = CombinedTrigger([
    TokenThresholdTrigger(max_tokens=100000, threshold_pct=0.50),
    StepTrigger(compress_every=10),
])
```

## Re-injection Pattern

Repeat key instructions at the end of the context where the model pays the most attention. This counters instruction centrifugation.

```python
def re_inject(messages, key_instructions):
    last_user_msg_idx = None
    for i in range(len(messages) - 1, -1, -1):
        if messages[i]["role"] == "user":
            last_user_msg_idx = i
            break

    if last_user_msg_idx is not None:
        re_injection_msg = {
            "role": "system",
            "content": "REMINDER — critical instructions that must be followed:\n"
                       + "\n".join(f"- {inst}" for inst in key_instructions),
        }
        messages.insert(last_user_msg_idx + 1, re_injection_msg)

    return messages
```

**What to re-inject:**

- Output format requirements
- Safety guardrails and policy constraints
- Current task scope (what the agent should and should not do)
- Key entity constraints (e.g., "only modify records for user X")

**What NOT to re-inject:**

- Background information the model already uses correctly
- Formatting details the model follows by default
- Instructions that conflict with recent context (the model will follow the recent context over the re-injected instruction)

Combine re-injection with compression. After compressing, re-inject key instructions before sending the compressed context to the model.

## Sub-agent Context Isolation

The primary reason for sub-agents is context isolation, not task delegation. Anthropic measured a 90.2% improvement in task success when using sub-agents for context isolation.

Each sub-agent starts with a fresh context window. No interference from the parent agent's accumulated history, retrieved chunks, or intermediate reasoning. The sub-agent focuses on one task with one set of instructions.

```python
async def run_sub_agent(task, tools, system_prompt):
    sub_agent = Agent(
        system_prompt=system_prompt,
        tools=tools,
    )

    result = await sub_agent.run(task)

    return result
```

**Pattern: Delegate to sub-agent, return result, discard sub-agent context.**

The parent agent keeps only the sub-agent's final result. The sub-agent's entire context (tool calls, intermediate reasoning, retrieved chunks) is discarded. This prevents the parent's context from filling with sub-agent noise.

**When to use sub-agents:**

- When a task requires many tool calls that would fill the parent's context
- When a task requires a different set of tools than the parent normally uses
- When a task requires focused reasoning without interference from accumulated context
- When the parent agent's context is already 25%+ full and the next task is complex

**When NOT to use sub-agents:**

- When the task is simple and requires few tool calls
- When the parent agent has plenty of context space
- When the sub-agent needs access to the parent's accumulated context (the isolation defeats this)

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Waiting until 100% fill to compress | Quality already degraded catastrophically | Compress at 50% fill or every 10 steps |
| Keeping all raw history | Context fills with noise; model cannot focus | Compress old history; keep summaries and recent turns |
| No compression strategy at all | Context quality degrades silently until failure | Define a compression strategy and trigger before building the agent |
| Single mega-prompt that fills entire window | No room for conversation; every turn adds to an already-full context | Distill the prompt; keep behavioral instructions only |
| Re-injecting everything | Redundant instructions compete with useful context | Re-inject only the instructions that centrifuge away |
| Sub-agents for simple tasks | Overhead of agent setup and context transfer exceeds benefit | Use sub-agents for complex tasks that need isolation |
| Compressing but not re-injecting | Compression removes instructions; no mechanism restores them | Combine compression with re-injection of key instructions |

## References

- Chroma Research on context quality degradation: https://www.trychroma.com/blog/context-quality
- Anthropic sub-agent context isolation measurement: https://www.anthropic.com/research/building-effective-agents

## Related Skills

- `agent-loop-patterns` — Agent execution loops that integrate compression between steps
- `agent-memory-systems` — Memory persistence across sessions (complementary to in-session compression)
- `multi-agent-orchestration` — Sub-agent delegation patterns for context isolation

## Keywords

context management, context window, compression, summary compression, sliding window, semantic compression, entity extraction, prompt distillation, hierarchical context, instruction centrifugation, re-injection, sub-agent isolation, compression trigger, token threshold, step threshold, quality signal