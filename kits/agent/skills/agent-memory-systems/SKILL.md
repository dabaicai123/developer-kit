---
name: agent-memory-systems
description: "Memory is the cornerstone of intelligent agents. Without it, every interaction starts from zero. This skill covers the architecture of agent memory: short-term (context window), long-term (vector stores), and the cognitive architectures that organize them."
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

# Agent Memory Systems

Memory is the cornerstone of intelligent agents. Without it, every interaction starts from zero. This skill covers the architecture of agent memory: short-term (context window), long-term (vector stores), and the cognitive architectures that organize them.

Key insight: Memory isn't just storage — it's retrieval. A million stored facts mean nothing if you can't find the right one. Chunking, embedding, and retrieval strategies determine whether your agent remembers or forgets.

The field is fragmented with inconsistent terminology. We use the CoALA cognitive architecture framework: semantic memory (facts), episodic memory (experiences), and procedural memory (how-to knowledge). We also map these to a practical 5-layer hierarchy for implementation.

## When to Use This Skill

- Designing memory architecture for a new agent system
- Choosing between in-context, file-based, and vector storage for agent data
- Implementing cross-session persistence (preferences, learned patterns)
- Deciding what to keep, compress, and discard as context grows
- Comparing memory implementations across frameworks (CrewAI, LlamaIndex, LangGraph, Agno)
- Selecting vector databases and embedding models for long-term memory
- Implementing chunking strategies and memory decay

## Principles

- Memory quality = retrieval quality, not storage quantity
- Chunk for retrieval, not for storage
- Context isolation is the enemy of memory
- Right memory type for right information
- Decay old memories — not everything should be forever
- Test retrieval accuracy before production
- Background memory formation beats real-time
- Start with conversation history only; add layers when concrete need arises

## Capabilities

- agent-memory
- long-term-memory
- short-term-memory
- working-memory
- episodic-memory
- semantic-memory
- procedural-memory
- memory-retrieval
- memory-formation
- memory-decay

## Scope

- vector-database-operations → data-engineer
- rag-pipeline-architecture → llm-architect
- embedding-model-selection → ml-engineer
- knowledge-graph-design → knowledge-engineer

## Tooling

### Memory Frameworks

- LangMem (LangChain) — When: LangGraph agents with persistent memory Note: Semantic, episodic, procedural memory types
- MemGPT / Letta — When: Virtual context management, OS-style memory Note: Hierarchical memory tiers, automatic paging
- Mem0 — When: User memory layer for personalization Note: Designed for user preferences and history

### Vector Stores

- Pinecone — When: Managed, enterprise-scale (billions of vectors) Note: Best query performance, highest cost
- Qdrant — When: Complex metadata filtering, open-source Note: Rust-based, excellent filtering
- Weaviate — When: Hybrid search, knowledge graph features Note: GraphQL interface, good for relationships
- ChromaDB — When: Prototyping, small/medium apps Note: Developer-friendly, ~20ms p50 at 100K vectors
- pgvector — When: Already using PostgreSQL, simpler setup Note: Good for <1M vectors, familiar tooling

### Embedding Models

- OpenAI text-embedding-3-large — When: Best quality, 3072 dimensions Note: $0.13/1M tokens
- OpenAI text-embedding-3-small — When: Good balance, 1536 dimensions Note: $0.02/1M tokens, 5x cheaper
- nomic-embed-text-v1.5 — When: Open-source, local deployment Note: 768 dimensions, good quality
- all-MiniLM-L6-v2 — When: Lightweight, fast local embedding Note: 384 dimensions, lowest latency

## 5-Layer Memory Hierarchy (Implementation Map)

A practical layered model mapping CoALA concepts to implementation. Start with Layer 0 and 1 only; add layers when concrete need arises.

### Layer 0 — Working Memory (Current Context)

Current conversation in the context window. Ephemeral. Overwrites each turn.

| Attribute | Detail |
|---|---|
| What to store | Current task, recent tool outputs, pending instructions |
| Storage mechanism | LLM context window (in-memory) |
| Retrieval pattern | Always available — part of every LLM call |
| Lifetime | Single session, overwritten each turn |

Key rule: keep working memory small. Target 50% or less of the total context window. Reserve the rest for system prompt, tool descriptions, and output generation. When working memory exceeds budget, trigger Layer 1 compression.

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
```

### Layer 1 — Conversation Memory (Summaries)

Compressed history of past turns. Store as summaries, not raw messages. Triggered when working memory exceeds its budget.

| Attribute | Detail |
|---|---|
| What to store | Summaries of completed turns, key decisions, resolved subtasks |
| Storage mechanism | File (JSON/Markdown) or database (SQLite, Redis) |
| Retrieval pattern | Inject relevant summaries into working memory at task start |
| Lifetime | Current session, optional cross-session persistence |

```python
class ConversationMemory:
    def compress(self, working_memory_messages):
        summary_prompt = [
            {"role": "system", "content": "Summarize the conversation. Preserve: completed steps, key results, decisions made, unresolved issues. Discard: tool call details, intermediate reasoning."},
            {"role": "user", "content": json.dumps(working_memory_messages)},
        ]
        return agent.call(summary_prompt).content
```

Practical guidance:
- Compress at 70% context budget, not 100% — leave room for new turns after compaction
- Re-inject task instructions after compression — they get "centrifuged" away from attention
- Store summaries, never raw messages — raw history is too large and noisy for retrieval

### Layer 2 — Task Memory (Artifacts)

Intermediate results, drafts, calculations. File-based or structured store. Survives across turns within a session.

| Attribute | Detail |
|---|---|
| What to store | Drafts, partial results, calculation outputs, intermediate data |
| Storage mechanism | File system (Markdown, JSON, CSV) or structured database |
| Retrieval pattern | Read by agent when resuming a subtask or assembling final output |
| Lifetime | Current session, optionally persisted for audit |

Task artifacts prevent loss of intermediate work across compaction cycles and enable assembling final outputs from stored pieces.

### Layer 3 — Long-term Memory (Preferences & Facts)

Stable facts that persist across sessions: user preferences, learned patterns, key decisions. Vector DB or structured store.

| Attribute | Detail |
|---|---|
| What to store | User preferences, style guides, organizational rules, learned patterns |
| Storage mechanism | Vector database (ChromaDB, Qdrant) for semantic retrieval, or SQLite for exact lookup |
| Retrieval pattern | Semantic search at task start; exact lookup for known keys |
| Lifetime | Permanent, updated when preferences change |

Critical rules:
- Persist stable truth, re-retrieve changing truth — store user preferences (stable), re-query policies/prices (changing)
- Never store guesses as memory — only persist confirmed facts, tag inferences as `confidence: low`
- Tag every entry with source and confidence

### Layer 4 — Episodic Memory (Trajectories)

Past interaction trajectories for learning. Full traces stored, retrieved for similar future tasks.

| Attribute | Detail |
|---|---|
| What to store | Full agent trajectories: task, steps, tool calls, outcomes, evaluations |
| Storage mechanism | PostgreSQL/MongoDB for traces; vector DB for semantic retrieval |
| Retrieval pattern | Semantic search for similar past tasks at planning phase |
| Lifetime | Permanent, used for continuous learning and evaluation |

Episodic memory enables: retrieving successful trajectories for similar tasks, avoiding failed approaches, and continuous evaluation against past performance.

## Patterns

### Memory Type Architecture (CoALA Framework)

Three memory types for different purposes, mapping to our 5-layer hierarchy:

1. **Semantic Memory → Layer 3**: Facts and knowledge. User preferences, domain knowledge. Stored in profiles (structured) or collections (unstructured).

2. **Episodic Memory → Layer 4**: Experiences and events. Past conversations, task outcomes. Used for learning from experience.

3. **Procedural Memory**: How to do things. Rules, skills, workflows. Often implemented as few-shot examples. "How did I solve this before?"

```python
from langmem import MemoryStore

memory = MemoryStore(connection_string=os.environ["POSTGRES_URL"])

# Semantic: user profile
await memory.semantic.upsert(
    namespace="user_profile", key=user_id,
    content={"name": "Alice", "preferences": ["dark mode", "concise responses"]}
)

# Episodic: past interaction
await memory.episodic.add(
    namespace="conversations",
    content={"timestamp": datetime.now(), "summary": "Helped debug auth issue", "outcome": "resolved"}
)

# Procedural: learned pattern
await memory.procedural.add(
    namespace="skills",
    content={"task_type": "debug_auth", "steps": ["Check token expiry", "Verify refresh flow"]}
)
```

### Vector Store Selection Pattern

Choosing the right vector database for your use case:

| | Pinecone | Qdrant | Weaviate | ChromaDB | pgvector |
|---|---|---|---|---|---|
| Scale | Billions | 100M+ | 100M+ | 1M | 1M |
| Managed | Yes | Both | Both | Self | Self |
| Filtering | Basic | Best | Good | Basic | SQL |
| Hybrid | No | Yes | Best | No | Yes |
| Cost | High | Medium | Medium | Free | Free |
| Latency | 5ms | 7ms | 10ms | 20ms | 15ms |

```python
# Pinecone (Enterprise Scale)
from pinecone import Pinecone
pc = Pinecone(api_key=os.environ["PINECONE_API_KEY"])
index = pc.Index("agent-memory")
index.upsert(vectors=[{"id": f"memory-{uuid4()}", "values": embedding,
    "metadata": {"user_id": user_id, "type": "episodic", "content": memory_text}}],
    namespace=namespace)
results = index.query(vector=query_embedding,
    filter={"user_id": user_id, "type": "episodic"}, top_k=5)

# Qdrant (Complex Filtering)
from qdrant_client import QdrantClient
client = QdrantClient(url="http://localhost:6333")
results = client.search(collection_name="agent_memory", query_vector=query_embedding,
    query_filter=Filter(must=[FieldCondition(key="user_id", match={"value": user_id})]),
    limit=5)

# ChromaDB (Prototyping)
import chromadb
client = chromadb.PersistentClient(path="./memory_db")
collection = client.get_or_create_collection("agent_memory")
collection.add(ids=[str(uuid4())], embeddings=[embedding],
    documents=[memory_text], metadatas=[{"user_id": user_id}])
```

### Chunking Strategy Pattern

Breaking documents into retrievable chunks. The chunking dilemma: too large = vector loses specificity; too small = loses context.

General guidance: 256-512 tokens for most use cases.

```python
# Fixed-Size Chunking (Baseline)
from langchain.text_splitter import RecursiveCharacterTextSplitter
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500, chunk_overlap=50,
    separators=["\n\n", "\n", ". ", " ", ""]
)

# Semantic Chunking (Better Quality)
from langchain_experimental.text_splitter import SemanticChunker
splitter = SemanticChunker(embeddings=OpenAIEmbeddings(),
    breakpoint_threshold_type="percentile", breakpoint_threshold_amount=95)

# Structure-Aware Chunking (Documents with Hierarchy)
from langchain.text_splitter import MarkdownHeaderTextSplitter
splitter = MarkdownHeaderTextSplitter(
    headers_to_split_on=[("#", "Header 1"), ("##", "Header 2"), ("###", "Header 3")]
)

# Contextual Chunking (Anthropic's Approach — reduces retrieval failures by 35%)
def add_context_to_chunk(chunk, document_summary):
    return f"Document summary: {document_summary}\n\nThe following is a chunk from this document:\n{chunk}"
# Embed the contextualized chunk, not raw chunk

# Code-Specific Chunking
from langchain.text_splitter import Language, RecursiveCharacterTextSplitter
python_splitter = RecursiveCharacterTextSplitter.from_language(
    language=Language.PYTHON, chunk_size=1000, chunk_overlap=200
)
```

Size recommendations by content type:

| Content Type | Optimal Chunk Size |
|---|---|
| Documentation | 512 (complete concepts) |
| Code | 1000 (function-level) |
| Conversation | 256 (turn-level) |
| Articles | 768 (paragraph-level) |

### Background Memory Formation

Processing memories asynchronously for better quality. Real-time memory extraction slows conversations. Background processing after conversations yields higher quality memories.

```python
from langgraph.graph import StateGraph
from langgraph.checkpoint.postgres import PostgresSaver

async def background_memory_processor(thread_id: str):
    conversation = await load_conversation(thread_id)
    insights = await llm.invoke(f'''
        Analyze this conversation and extract:
        1. Key facts learned about the user
        2. User preferences revealed
        3. Tasks completed or pending
        4. Patterns in user behavior
        Conversation: {conversation}
    ''')
    for insight in insights:
        await memory.semantic.upsert(
            namespace="user_insights", key=generate_key(insight),
            content=insight, metadata={"source_thread": thread_id}
        )
```

Memory Consolidation (Like Sleep): Periodically consolidate and deduplicate memories. Cluster similar memories (threshold 0.9), merge via LLM, delete originals.

### Memory Decay Pattern

Not all memories should live forever. Implement intelligent decay based on recency, frequency, and importance.

```python
# Time-Based Decay
async def decay_old_memories(namespace: str, max_age_days: int):
    cutoff = datetime.now() - timedelta(days=max_age_days)
    old_memories = await memory.episodic.list(
        namespace=namespace, filter={"last_accessed": {"$lt": cutoff.isoformat()}}
    )
    for mem in old_memories:
        await memory.episodic.update(id=mem.id,
            metadata={"archived": True, "archived_at": datetime.now()})

# Utility-Based Decay (MIRIX Approach)
def calculate_memory_utility(memory):
    hours_since_access = (datetime.now() - memory.last_accessed).total_seconds() / 3600
    recency_score = 0.5 ** (hours_since_access / 72)  # 72h half-life
    frequency_score = min(memory.access_count / 10, 1.0)
    importance = memory.metadata.get("importance", 0.5)
    return 0.4 * recency_score + 0.3 * frequency_score + 0.3 * importance

async def prune_low_utility_memories(threshold=0.2):
    for mem in await memory.list_all():
        if calculate_memory_utility(mem) < threshold:
            await memory.archive(mem.id)
```

## Framework Comparison

| Feature | CrewAI | LlamaIndex | LangGraph | Agno |
|---|---|---|---|---|
| Working Memory | In-context, automatic | In-context, automatic | State dict per graph run | In-context, automatic |
| Conversation Memory | Short-term memory per agent | Chat memory buffer | Not built-in (custom state) | Session memory per agent |
| Task Memory | Not built-in (file tools) | Not built-in (custom tools) | State dict supports artifacts | Not built-in (custom tools) |
| Long-term Memory | Long-term memory via vector DB | Vector store integration | Not built-in (custom store) | Agent memory with storage backend |
| Episodic Memory | Not built-in | Not built-in | Not built-in | Not built-in |
| Storage Backends | ChromaDB, custom | ChromaDB, Pinecone, Qdrant | Custom (PostgreSQL, SQLite) | PostgreSQL, SQLite, custom |
| Compression | Not built-in | Summary memory buffer | Custom (human-in-the-loop) | Not built-in |
| Cross-session | Long-term memory class | Memory modules | Checkpoint persistence | Storage backend persistence |

All frameworks implement Layer 0 and partial Layer 1 by default. Layers 2-4 require custom implementation in every framework. Design memory as standalone modules, not framework-dependent classes, so you can migrate without rewriting.

## Practical Guidance

1. **Start with conversation history only, add layers when concrete need arises** — Layer 0 and Layer 1 cover 80% of agent memory needs. Add Layer 2 when tasks produce intermediate artifacts. Add Layer 3 when users have persistent preferences. Add Layer 4 only for agents that need to learn from past behavior.

2. **Persist stable truth, re-retrieve changing truth** — user preferences are stable (store them); pricing, availability, and policies change (re-query at runtime). Never cache changing data in long-term memory.

3. **Never store guesses as memory** — if the agent infers a preference without user confirmation, tag it as `confidence: low` and validate it before relying on it. Only confirmed facts belong in long-term memory.

4. **Compression before storage, expansion on retrieval** — store summaries and embeddings, not raw data. Expand summaries into working memory context only when the agent needs them.

5. **Memory retrieval is a tool call** — the agent should decide when to access memory, not have it injected automatically. Automatic injection wastes context budget on irrelevant memories.

## Sharp Edges

### Chunking Isolates Information From Its Context

**Severity: CRITICAL**

Retrieval finds chunks but they don't make sense alone. "The function returns X" without knowing which function. References to "this" without knowing what "this" refers to.

**Fix**: Contextual Chunking (Anthropic's approach). Add document context to each chunk before embedding. Reduces retrieval failures by 35%. Also use hierarchical chunking: store at multiple granularities (256, 512, 1024) and retrieve at the appropriate level.

### Chunk Size Mismatched to Query Patterns

**Severity: HIGH**

Optimal chunk size depends on query patterns. Factual queries need small, specific chunks. Conceptual queries need larger context. Default 1000 characters works for nothing specific.

**Fix**: Test different chunk sizes against real queries. Use overlap (10-20%) to prevent boundary issues. Match chunk size to content type (see table above).

### Semantic Search Returns Irrelevant Results

**Severity: HIGH**

Semantic similarity isn't relevance. "The user likes Python" and "Python is a programming language" are semantically similar but very different types of information.

**Fix**: Always filter by metadata first. Use hybrid search (semantic + keyword). Rerank results with cross-encoder for precision.

```python
# Good: Filter then search
results = index.query(vector=query_embedding,
    filter={"user_id": current_user.id, "type": "preference"}, top_k=5)

# Hybrid search with fusion (Qdrant)
results = client.search(collection_name="memories",
    query_vector=semantic_embedding, query_text=query,
    fusion={"method": "rrf"})
```

### Old Memories Override Current Information

**Severity: HIGH**

Vector stores don't have temporal awareness. A memory from a year ago has the same weight as one from today. User changed preferences but old ones still retrieved.

**Fix**: Add temporal scoring. Apply time decay (72h half-life for recency). Update preferences instead of appending. Explicit versioning for facts.

```python
def time_decay_score(memory, half_life_days=30):
    age = (datetime.now() - memory.created_at).days
    return 0.5 ** (age / half_life_days)

def retrieve_with_recency(query, user_id):
    candidates = index.query(vector=embed(query), filter={"user_id": user_id}, top_k=20)
    for c in candidates:
        c.final_score = c.similarity * 0.7 + time_decay_score(c) * 0.3
    return sorted(candidates, key=lambda x: x.final_score, reverse=True)[:5]
```

### Contradictory Memories Retrieved Together

**Severity: MEDIUM**

Agent retrieves "user prefers dark mode" and "user prefers light mode" in same context. Gives inconsistent answers.

**Fix**: Detect conflicts on storage. Use LLM to check if new content contradicts existing memory. Replace or version on conflict. Periodic consolidation to merge similar memories.

### Retrieved Memories Exceed Context Window

**Severity: MEDIUM**

Retrieval returns too many memories, overwhelming the context. Critical information gets pushed out.

**Fix**: Budget tokens for different memory types. Allocate specific token budgets: system_prompt (500), user_profile (200), recent_messages (2000), retrieved_memories (1000), buffer (300). Dynamic k based on remaining budget.

### Query and Document Embeddings From Different Models

**Severity: MEDIUM**

Mixing embedding models creates garbage similarity scores. Works for new documents, fails for old.

**Fix**: Track embedding model in metadata. Filter by model version on retrieval. Migration strategy: re-embed all documents with new model in a separate collection, switch over when complete.

## Validation Checks

### In-Memory Store in Production Code

**Severity: ERROR** — In-memory stores lose data on restart. Use persistent storage (Postgres, Qdrant, Pinecone) for production.

### Vector Upsert Without Metadata

**Severity: WARNING** — Vectors should have metadata for filtering. Add user_id, type, timestamp.

### Query Without User Filtering

**Severity: ERROR** — Queries should filter by user to prevent data leakage. Always filter by user_id.

### Chunking Without Overlap

**Severity: WARNING** — Add chunk_overlap (10-20%) to prevent boundary issues.

### Semantic Search Without Filters

**Severity: WARNING** — Pure semantic search often returns irrelevant results. Add metadata filters.

### Different Models for Document and Query Embedding

**Severity: ERROR** — Documents and queries must use same embedding model. Track model version in metadata.

## Collaboration

### Delegation Triggers

- user needs vector database at scale → data-engineer (Production vector store operations)
- user needs embedding model optimization → ml-engineer (Custom embeddings, fine-tuning)
- user needs RAG pipeline → llm-architect (End-to-end retrieval augmented generation)
- user needs multi-agent shared memory → multi-agent-orchestration (Memory sharing between agents)

## Anti-Patterns

- Storing raw conversation messages instead of summaries — too large for retrieval and too noisy
- Injecting all memory into every LLM call — wastes context budget on irrelevant history. Let the agent decide when to retrieve.
- Caching changing data in long-term memory — prices, availability, policies change. Re-query at runtime.
- Storing agent guesses as confirmed preferences — tag low-confidence inferences and validate first
- No compaction strategy — unbounded working memory degrades performance and exceeds context window
- Framework-locked memory implementations — design standalone modules that work with any framework
- Chunking without context — isolated chunks lose meaning without document-level context

## Related Skills

Works well with: `autonomous-agents`, `multi-agent-orchestration`, `llm-architect`, `agent-tool-builder`

## When to Use (Trigger Keywords)

- User mentions or implies: agent memory, long-term memory, memory systems, remember across sessions, memory retrieval, episodic memory, semantic memory, vector store, RAG, langmem, memgpt, conversation history

## References

- ChromaDB: https://docs.trychroma.com/
- Qdrant: https://qdrant.tech/documentation/
- LangGraph Persistence: https://langchain-ai.github.io/langgraph/concepts/persistence/
- CrewAI Memory: https://docs.crewai.com/concepts/memory
- Agno Memory: https://docs.agno.com/concepts/memory
- Pinecone: https://docs.pinecone.io/
- LangMem: https://github.com/langchain-ai/langmem