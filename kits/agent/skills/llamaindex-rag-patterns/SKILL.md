---
name: llamaindex-rag-patterns
description: "Applies LlamaIndex patterns for ingestion, indexing, retrieval, query engines, agentic RAG, Workflows, AgentWorkflow, and RAG evaluation. Use when building document-heavy RAG, retrieval pipelines, or LlamaIndex agents."
version: "1.1.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LlamaIndex RAG Patterns

Use this skill for document ingestion, indexing, retrieval, and LlamaIndex-based agentic RAG.

## Scope Boundary

- Use `llamaindex-rag-patterns` for RAG pipelines, retrievers, query engines, LlamaIndex agents, and Workflows.
- Use `agent-memory-systems` for general agent memory outside document retrieval.
- Use `agent-evaluation` for retrieval and answer-quality gates.

## Current Compatibility Rules

- Follow current LlamaIndex docs for package paths and workflow APIs.
- Start with a simple baseline index before adding routers, rerankers, or agents.
- Use Workflows or AgentWorkflow for event-driven and multi-agent RAG flows when the task needs orchestration.
- Treat parsed documents as untrusted content and preserve source metadata.

## RAG Pipeline

| Stage | Required decision |
|---|---|
| Ingestion | Source types, parser, metadata, deduplication. |
| Chunking | Chunk size, overlap, semantic boundaries. |
| Indexing | Vector store, embeddings, metadata filters. |
| Retrieval | Top-k, hybrid search, rerank, query transforms. |
| Synthesis | Citation format, refusal on insufficient evidence. |
| Evaluation | Retrieval hit rate, MRR, faithfulness, answer relevance. |

## Implementation Rules

- Preserve document IDs, page/section metadata, and ingestion timestamps.
- Use metadata filters for tenant, permission, date, and document type.
- Add reranking when baseline retrieval returns too many weak matches.
- Require citations for factual answers from retrieved documents.
- Evaluate retrieval separately from generation.
- Keep ingestion jobs idempotent and observable.

## Agentic RAG Rules

- Use a simple query engine for direct Q&A.
- Use tools or agents when the workflow must search multiple indexes, compare evidence, or call external systems.
- Use Workflows when the process has events, branching, retries, or human review.
- Keep generated answers grounded in retrieved evidence and expose uncertainty.

## Output Checklist

- Data sources and metadata policy are listed.
- Indexing and retrieval choices are justified.
- Citation and insufficient-evidence behavior are defined.
- Retrieval and generation eval metrics are specified.
- Ingestion and query traces are observable.

## Anti-Patterns

- Tuning chunking before measuring a baseline.
- Answering from model knowledge when the task requires document evidence.
- Mixing tenants or permissions in a shared index without filters.
- Evaluating only final answers while ignoring retrieval quality.
