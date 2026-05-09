---
name: agent-memory-systems
description: "5-layer memory hierarchy for agents: Working Memory, Conversation Memory, Task Memory, Long-term Memory, Episodic Memory. Storage mechanisms, retrieval patterns, and framework implementations. Use when designing agent memory, choosing persistence strategies, or implementing memory across sessions."
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

# Agent Memory Systems

Five-layer memory hierarchy for production agents. Each layer serves a distinct purpose, has a specific storage mechanism, and a defined retrieval pattern. Start with conversation history only; add layers when concrete need arises.

## When to use this skill

- Designing memory architecture for a new agent system
- Choosing between in-context, file-based, and vector storage for agent data
- Implementing cross-session persistence (preferences, learned patterns)
- Deciding what to keep, compress, and discard as context grows
- Comparing memory implementations across frameworks (CrewAI, LlamaIndex, LangGraph, Agno)

## Layer 0 — Working Memory

Current conversation in the context window. Ephemeral. Overwrites each turn.

| Attribute | Detail |
|---|---|
| What to store | Current task, recent tool outputs, pending instructions |
| Storage mechanism | LLM context window (in-memory) |
| Retrieval pattern | Always available — part of every LLM call |
| When to add | Every turn automatically |
| Lifetime | Single session, overwritten each turn |

Key rule: keep working memory small, explicit, and easy to overwrite. A bloated context window degrades model performance. Target: 50% or less of the total context window for working memory. Reserve the rest for system prompt, tool descriptions, and output generation.

```python
class WorkingMemory:
    def __init__(self, max_messages=20):
        self.messages = []
        self.max_messages = max_messages

    def add(self, role, content, name=None):
        entry = {"role": role, "content": content}
        if name:
            entry["name"] = name
        self.messages.append(entry)
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def get_context(self):
        return self.messages.copy()

    def clear(self):
        self.messages = []
```

When working memory exceeds budget, trigger Layer 1 compression. Never let it grow unbounded.

## Layer 1 — Conversation Memory (Summaries)

Compressed history of past turns. Store as summaries, not raw messages. Triggered when working memory exceeds its budget.

| Attribute | Detail |
|---|---|
| What to store | Summaries of completed conversation turns, key decisions, resolved subtasks |
| Storage mechanism | File (JSON/Markdown) or database (SQLite, Redis) |
| Retrieval pattern | Inject relevant summaries into working memory at task start |
| When to add | When working memory exceeds token budget, at session end |
| Lifetime | Current session, optional cross-session persistence |

```python
class ConversationMemory:
    def __init__(self, storage_path="memory/conversations/"):
        self.storage_path = storage_path

    def compress(self, working_memory_messages):
        summary_prompt = [
            {"role": "system", "content": "Summarize the conversation. Preserve: completed steps, key results, decisions made, unresolved issues. Discard: tool call details, intermediate reasoning, redundant observations."},
            {"role": "user", "content": json.dumps(working_memory_messages)},
        ]
        summary = agent.call(summary_prompt)
        return summary.content

    def save(self, session_id, summary):
        path = f"{self.storage_path}{session_id}.json"
        data = {
            "session_id": session_id,
            "summary": summary,
            "timestamp": datetime.utcnow().isoformat(),
        }
        with open(path, "w") as f:
            json.dump(data, f, indent=2)

    def load(self, session_id):
        path = f"{self.storage_path}{session_id}.json"
        if os.path.exists(path):
            with open(path) as f:
                return json.load(f)["summary"]
        return None
```

Practical guidance:
- Compress at 70% context budget, not 100% — leave room for new turns after compaction
- Re-inject task instructions after compression — they get "centrifuged" away from the model's attention
- Store summaries, never raw messages — raw history is too large and too noisy for retrieval

## Layer 2 — Task Memory (Artifacts)

Intermediate results, drafts, calculations, working documents. File-based or structured store. Survives across turns within a session.

| Attribute | Detail |
|---|---|
| What to store | Drafts, partial results, calculation outputs, intermediate data structures |
| Storage mechanism | File system (Markdown, JSON, CSV) or structured database |
| Retrieval pattern | Read by the agent when resuming a subtask or assembling final output |
| When to add | After each subtask that produces a non-trivial result |
| Lifetime | Current session, optionally persisted for audit |

```python
class TaskMemory:
    def __init__(self, workspace_path="memory/task_artifacts/"):
        self.workspace_path = workspace_path

    def store_artifact(self, task_id, artifact_name, content, format="json"):
        path = f"{self.workspace_path}{task_id}/{artifact_name}.{format}"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if format == "json":
            with open(path, "w") as f:
                json.dump(content, f, indent=2)
        elif format == "md":
            with open(path, "w") as f:
                f.write(content)
        return path

    def load_artifact(self, task_id, artifact_name, format="json"):
        path = f"{self.workspace_path}{task_id}/{artifact_name}.{format}"
        if not os.path.exists(path):
            return None
        if format == "json":
            with open(path) as f:
                return json.load(f)
        elif format == "md":
            with open(path) as f:
                return f.read()

    def list_artifacts(self, task_id):
        dir_path = f"{self.workspace_path}{task_id}/"
        if not os.path.exists(dir_path):
            return []
        return [f for f in os.listdir(dir_path) if not f.startswith(".")]
```

Task artifacts are the agent's workspace. They prevent loss of intermediate work across compaction cycles and enable the agent to assemble final outputs from stored pieces.

## Layer 3 — Long-term Memory (Preferences)

Stable facts that persist across sessions: user preferences, learned patterns, key decisions, organizational policies. Vector DB or structured store.

| Attribute | Detail |
|---|---|
| What to store | User preferences, style guides, organizational rules, learned patterns, key decisions |
| Storage mechanism | Vector database (ChromaDB, Qdrant) for semantic retrieval, or structured store (SQLite, JSON) for exact lookup |
| Retrieval pattern | Semantic search at task start; exact lookup for known keys |
| When to add | When user explicitly states a preference, when agent learns a stable pattern |
| Lifetime | Permanent, updated when preferences change |

```python
class LongTermMemory:
    def __init__(self, db_path="memory/long_term/"):
        self.exact_store = SQLiteStore(f"{db_path}preferences.db")
        self.vector_store = ChromaDBStore(f"{db_path}vectors/")

    def store_preference(self, user_id, key, value, category="general"):
        self.exact_store.upsert(
            table="preferences",
            data={"user_id": user_id, "key": key, "value": value, "category": category},
            key_columns=["user_id", "key"],
        )

    def store_pattern(self, user_id, pattern_description, context_embedding):
        self.vector_store.add(
            collection="learned_patterns",
            documents=[pattern_description],
            embeddings=[context_embedding],
            metadata={"user_id": user_id},
        )

    def retrieve_preferences(self, user_id):
        return self.exact_store.query(
            table="preferences",
            filter={"user_id": user_id},
        )

    def retrieve_patterns(self, user_id, query_embedding, top_k=5):
        return self.vector_store.search(
            collection="learned_patterns",
            query_embedding=query_embedding,
            filter={"user_id": user_id},
            top_k=top_k,
        )
```

Critical rules for long-term memory:
- **Persist stable truth, re-retrieve changing truth** — store user preferences (stable), but re-query policies, prices, inventory status (changing) at runtime
- **Never store guesses as memory** — only persist facts the user has confirmed or patterns validated across multiple interactions
- **Tag every entry with source and confidence** — agent-learned patterns have lower confidence than user-stated preferences

## Layer 4 — Episodic Memory

Past interaction trajectories for learning. Full traces stored, retrieved for similar future tasks. Enables the agent to learn from past successes and failures.

| Attribute | Detail |
|---|---|
| What to store | Full agent trajectories: task, steps taken, tool calls, outcomes, evaluations, user feedback |
| Storage mechanism | Database (PostgreSQL, MongoDB) for structured traces; vector DB for semantic retrieval of similar past tasks |
| Retrieval pattern | Semantic search for similar past tasks at planning phase; exact lookup for known task patterns |
| When to add | After every completed agent run, with evaluation scores |
| Lifetime | Permanent, used for continuous learning and evaluation |

```python
class EpisodicMemory:
    def __init__(self, trace_db_path, vector_db_path):
        self.trace_store = PostgreSQLStore(trace_db_path)
        self.vector_store = ChromaDBStore(vector_db_path)

    def store_trajectory(self, trajectory):
        self.trace_store.insert(
            table="trajectories",
            data={
                "task_id": trajectory.task_id,
                "task_description": trajectory.task,
                "steps": json.dumps(trajectory.steps),
                "tools_called": json.dumps(trajectory.tool_calls),
                "outcome": trajectory.outcome,
                "evaluation_score": trajectory.eval_score,
                "user_feedback": trajectory.user_feedback,
                "timestamp": datetime.utcnow(),
            },
        )
        self.vector_store.add(
            collection="trajectories",
            documents=[trajectory.task],
            embeddings=[trajectory.task_embedding],
            metadata={"task_id": trajectory.task_id, "score": trajectory.eval_score},
        )

    def retrieve_similar_tasks(self, current_task_embedding, top_k=3, min_score=0.7):
        results = self.vector_store.search(
            collection="trajectories",
            query_embedding=current_task_embedding,
            top_k=top_k,
        )
        successful = [r for r in results if r["metadata"]["score"] >= min_score]
        trajectories = []
        for r in successful:
            trace = self.trace_store.query(
                table="trajectories",
                filter={"task_id": r["metadata"]["task_id"]},
            )
            trajectories.append(trace)
        return trajectories
```

Episodic memory enables:
- Retrieving successful trajectories for similar tasks — the agent can reuse proven approaches
- Avoiding failed trajectories — the agent can skip approaches that previously failed
- Continuous evaluation — compare new trajectories against past performance to detect degradation

## Practical Guidance

1. **Start with conversation history only, add layers when concrete need arises** — Layer 0 and Layer 1 cover 80% of agent memory needs. Add Layer 2 when tasks produce intermediate artifacts. Add Layer 3 when users have persistent preferences. Add Layer 4 only for agents that need to learn from past behavior.

2. **Persist stable truth, re-retrieve changing truth** — user preferences are stable (store them); pricing, availability, and policies change (re-query at runtime). Never cache changing data in long-term memory.

3. **Never store guesses as memory** — if the agent infers a preference without user confirmation, tag it as `confidence: low` and validate it before relying on it. Only confirmed facts belong in long-term memory.

4. **Compression before storage, expansion on retrieval** — store summaries and embeddings, not raw data. Expand summaries into working memory context only when the agent needs them.

5. **Memory retrieval is a tool call** — the agent should decide when to access memory, not have it injected automatically. Automatic injection wastes context budget on irrelevant memories.

## Framework Comparison

| Feature | CrewAI | LlamaIndex | LangGraph | Agno |
|---|---|---|---|---|
| Working Memory | In-context, automatic | In-context, automatic | State dict per graph run | In-context, automatic |
| Conversation Memory | Short-term memory per agent | Chat memory buffer | Not built-in (custom state) | Session memory per agent |
| Task Memory | Not built-in (file tools) | Not built-in (custom tools) | State dict supports artifacts | Not built-in (custom tools) |
| Long-term Memory | Long-term memory via vector DB | Vector store integration | Not built-in (custom store) | Agent memory with storage backend |
| Episodic Memory | Not built-in | Not built-in | Not built-in | Not built-in |
| Storage Backdrop | ChromaDB, custom | ChromaDB, Pinecone, Qdrant | Custom (PostgreSQL, SQLite) | PostgreSQL, SQLite, custom |
| Compression | Not built-in | Summary memory buffer | Custom (human-in-the-loop) | Not built-in |
| Cross-session | Long-term memory class | Memory modules | Checkpoint persistence | Storage backend persistence |

All frameworks implement Layer 0 and partial Layer 1 by default. Layers 2-4 require custom implementation in every framework. Design memory as standalone modules, not framework-dependent classes, so you can migrate without rewriting.

## Anti-Patterns

- Storing raw conversation messages instead of summaries — raw messages are too large for retrieval and too noisy for the agent to use effectively
- Injecting all memory into every LLM call — the agent wastes context budget on irrelevant history. Let the agent decide when to retrieve.
- Caching changing data in long-term memory — prices, availability, and policies change. Re-query at runtime, never cache in persistent memory.
- Storing agent guesses as confirmed preferences — tag low-confidence inferences and validate before relying on them.
- No compaction strategy — unbounded working memory degrades model performance and eventually exceeds the context window.
- Framework-locked memory implementations — memory logic should be standalone modules that work with any framework. Framework memory classes are convenient but create migration risk.

## References

- ChromaDB: https://docs.trychroma.com/
- Qdrant: https://qdrant.tech/documentation/
- LangGraph Persistence: https://langchain-ai.github.io/langgraph/concepts/persistence/
- CrewAI Memory: https://docs.crewai.com/concepts/memory
- Agno Memory: https://docs.agno.com/concepts/memory