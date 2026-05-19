# Agentic AI Conventions & Rules

## Package Layout

Use the official scaffold layout when a framework provides one. For a full FastAPI service that wraps LangGraph, use this structure only when the project has enough API, RAG, memory, observability, and deployment code to justify the extra packages:

```text
src/<service_name>/
  agents/
    graphs/          # StateGraph definitions
    nodes/           # Node functions
    tools/           # @tool definitions
    state.py         # TypedDict state schemas
  rag/
    indexing/        # Document loaders, splitters, indexing
    retrieval/       # Retrievers, rerankers
  memory/
    checkpointing.py # Checkpointer setup
    semantic.py      # Optional vector-store memory
  guardrails/
    input.py         # Input validation
    output.py        # Output validation
  llm/
    providers.py     # LLM factory or router
  core/
    config.py        # pydantic-settings configuration
    logging.py       # structured logging
    exceptions.py    # exception hierarchy
  observability/
    metrics.py       # metrics
    tracing.py       # tracing setup
  models/
    schemas.py       # request/response models
  api/
    routes/
      agent.py       # POST /invoke, POST /stream
      health.py      # GET /health
    middleware/
      request_context.py
  main.py            # FastAPI app with lifespan
  py.typed
```

## LangGraph Rules

1. **Use `TypedDict` for state** instead of `dict[str, Any]` when possible.
2. **Use `Annotated[list[BaseMessage], add_messages]`** for message lists to enable proper message merging.
3. **For looping graphs, include an iteration or progress counter** and check it in routing.
4. **Prefer `Command(goto=...)`** when a node should update state and choose the next destination together.
5. **Set `recursion_limit`** for looping or agentic graphs as a safety net.
6. **Use a persistent checkpointer in production**; in-memory checkpointing is for tests and local development.
7. **Pass `thread_id` when using checkpointing** so state is scoped to the correct conversation or run.

## FastAPI Integration Rules

1. **All endpoints are `async def`**  -  never block the event loop
2. **Use `Depends()` for agent graph injection**  -  configure in lifespan, inject via dependency
3. **Use `StreamingResponse` with `text/event-stream`**  -  for streaming agent responses
4. **Include `/api/v1/health`**  -  ping LLM providers, DB, vector store
5. **Propagate `thread_id`** from request to graph config  -  enables conversation continuity

## LangGraph Agent Implementation Checklist

Pre-ship checklist for LangGraph agents. Run through before marking any agent implementation complete.

```text
[ ] LLM initialized with an explicit model ID from current provider documentation.
[ ] Embeddings configured when RAG is used, with dimensions matching the vector-store schema.
[ ] Tools have docstrings, Pydantic input schemas, error handling, and structured returns.
[ ] Async tools use async client calls instead of blocking sync calls.
[ ] Memory system is chosen deliberately: persistent checkpointer for production, in-memory only for tests/local development.
[ ] thread_id is propagated from request to graph config when checkpointing is used.
[ ] Looping graphs have an iteration or progress limit checked by routing logic.
[ ] Tracing is enabled when operational debugging or quality tracking is required.
[ ] Streaming is implemented when the user experience needs incremental responses.
[ ] Health checks cover the app and required external dependencies.
[ ] Caching has freshness, invalidation, and bypass rules when used.
[ ] Retry logic is bounded and uses backoff for transient provider or network failures.
[ ] Evaluation tests cover tools, routing, and at least one end-to-end behavior.
[ ] API endpoints document thread_id behavior and request/response schemas.
```

## Prompt Selection Quick Reference

When writing prompts for agents, choose a structure based on provider behavior and task requirements. Keep provider-specific examples in `agentic-prompt-engineering.md` or `agentic-prompt-optimization.md`, and verify current provider guidance before adopting model-specific conventions.

For advanced techniques such as self-critique, Tree-of-Thoughts, canary rollout, and prompt versioning, use `agentic-prompt-optimization.md`.
