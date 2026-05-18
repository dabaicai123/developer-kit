---
name: llamaindex-rag-patterns
description: "Applies LlamaIndex RAG patterns for document ingestion, indexing, retrieval, query engines, vector stores, citations, and evaluation. Use for document Q&A, knowledge retrieval, private-data search, or RAG pipelines."
version: "1.1.0"
license: MIT
metadata:
  author: "Orchestra Research, adapted for developer-kit"
  source: "https://github.com/Orchestra-Research/AI-Research-SKILLs"
  tags: [llamaindex, rag, document-ingestion, vector-indices, query-engines, knowledge-retrieval]
  dependencies: [llama-index]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LlamaIndex RAG Patterns

LlamaIndex is a data framework for connecting LLMs with private or domain-specific data. This skill applies the RAG-focused parts of the Orchestra Research LlamaIndex skill: ingestion, indexing, retrieval, query engines, vector stores, grounded synthesis, and evaluation.

## When To Use

Use this skill when:

- Building RAG applications.
- Building document Q&A over private data.
- Ingesting data from multiple sources through LlamaHub or LlamaIndex readers.
- Creating searchable knowledge bases.
- Building retrieval over enterprise, product, code, policy, support, or research data.
- Needing structured extraction or grounded synthesis from documents.

Use another skill when the task is mainly:

- General non-retrieval memory.
- Tool calling or process orchestration outside a retrieval pipeline.
- A vector database setup with no LlamaIndex integration.
- A generic LLM app where RAG is not the central behavior.

## Quick Start

Install the starter package for the simplest path:

```bash
pip install llama-index
```

Use a minimal RAG baseline before adding extra routing, reranking, or custom prompts:

```python
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex

documents = SimpleDirectoryReader("data").load_data()
index = VectorStoreIndex.from_documents(documents)

query_engine = index.as_query_engine()
response = query_engine.query("What did the author do growing up?")
print(response)
```

## Core Concepts

### Data Connectors

Load documents from files, web pages, databases, SaaS systems, APIs, or custom sources.

```python
from llama_index.core import Document, SimpleDirectoryReader

documents = SimpleDirectoryReader("./data").load_data()

doc = Document(
    text="This is the document content",
    metadata={"source": "manual", "date": "2025-01-01"},
)
```

Preserve source metadata needed for filtering and citations:

- Stable source ID.
- Source URI or file path.
- Page, section, row, or object ID.
- Tenant and permission scope.
- Ingestion timestamp.

Load `references/data-ingestion.md` when choosing readers, metadata, document IDs, or ingestion boundaries.

### Indices

Use `VectorStoreIndex` as the default RAG index for semantic retrieval.

```python
from llama_index.core import StorageContext, VectorStoreIndex, load_index_from_storage

index = VectorStoreIndex.from_documents(documents)
index.storage_context.persist(persist_dir="./storage")

storage_context = StorageContext.from_defaults(persist_dir="./storage")
index = load_index_from_storage(storage_context)
```

Prefer a simple persisted index first. Add advanced index structures only when evaluation shows the baseline is insufficient.

### Retrievers

Retrievers find relevant chunks before generation.

```python
retriever = index.as_retriever(similarity_top_k=5)
nodes = retriever.retrieve("machine learning")
```

Use metadata filters for tenant, permission, document type, time range, and other hard constraints before synthesis.

### Query Engines

Query engines combine retrieval and response generation.

```python
query_engine = index.as_query_engine(
    similarity_top_k=3,
    response_mode="compact",
    verbose=True,
)

response = query_engine.query("What is the main topic?")
print(response)
```

Load `references/query-retrieval.md` when configuring query engines, response modes, metadata filters, reranking, query transforms, or source citations.

## RAG Pipeline

| Stage | Required decision |
|---|---|
| Ingestion | Source types, reader, metadata, deduplication. |
| Chunking | Chunk size, overlap, semantic boundaries. |
| Indexing | Index type, vector store, embeddings, persistence. |
| Retrieval | Top-k, metadata filters, hybrid search, rerank. |
| Synthesis | Response mode, prompt, citation format, refusal behavior. |
| Evaluation | Retrieval hit rate, MRR, faithfulness, answer relevance. |

## Data Ingestion Patterns

For mixed local files:

```python
documents = SimpleDirectoryReader(
    "./data",
    recursive=True,
    required_exts=[".pdf", ".docx", ".txt", ".md"],
).load_data()
```

For source-specific readers, install only the reader packages needed by the project. Keep ingestion idempotent and observable.

## Vector Store Integrations

Choose the vector store based on deployment constraints:

- Chroma for local development and small persistent stores.
- FAISS for local fast similarity search.
- Pinecone, Qdrant, Weaviate, Milvus, or Postgres/pgvector for managed or production storage.

Pattern:

```python
from llama_index.core import StorageContext, VectorStoreIndex

storage_context = StorageContext.from_defaults(vector_store=vector_store)
index = VectorStoreIndex.from_documents(
    documents,
    storage_context=storage_context,
)
```

Do not mix tenants or permission scopes in a shared index unless retrieval filters are enforced.

## Customization

Set project-specific LLMs and embeddings explicitly when defaults are not acceptable.

```python
from llama_index.core import Settings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

Settings.embed_model = HuggingFaceEmbedding(
    model_name="sentence-transformers/all-mpnet-base-v2"
)
```

Use prompts that force grounded answers and refusals when evidence is missing.

```python
from llama_index.core import PromptTemplate

qa_prompt = PromptTemplate(
    "Context: {context_str}\n"
    "Question: {query_str}\n"
    "Answer using only the context. "
    "If the answer is not in the context, say you do not know.\n"
    "Answer: "
)

query_engine = index.as_query_engine(text_qa_template=qa_prompt)
```

## Evaluation

Evaluate retrieval separately from generation.

Retrieval checks:

- Expected source appears in top-k.
- Expected source appears early enough for the synthesis step.
- Filters prevent cross-tenant or unauthorized sources.
- Retrieved chunks are diverse enough to answer the question.

Generation checks:

- Answer is faithful to retrieved context.
- Factual claims have source citations.
- Missing or contradictory evidence causes a refusal or uncertainty.
- Answer addresses the user question without relying on model-only knowledge.

## Best Practices

1. Use vector indices for most RAG baselines.
2. Persist indices to avoid unnecessary re-indexing.
3. Preserve metadata for filtering, tracing, and citations.
4. Tune chunking only after measuring baseline retrieval.
5. Start with `similarity_top_k` in the 2-5 range.
6. Add reranking when baseline retrieval returns weak matches.
7. Use streaming for long generated answers.
8. Enable verbose tracing during development.
9. Track source nodes for every factual answer.
10. Monitor embedding and generation costs.

## Common Pattern

```python
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex

documents = SimpleDirectoryReader("docs").load_data()
index = VectorStoreIndex.from_documents(documents)
index.storage_context.persist(persist_dir="./storage")

query_engine = index.as_query_engine(
    similarity_top_k=3,
    response_mode="compact",
    verbose=True,
)

response = query_engine.query("What is the main topic?")
print(response)
print([node.metadata for node in response.source_nodes])
```

## References

- `references/data-ingestion.md`: readers, metadata, document IDs, and ingestion checks.
- `references/query-retrieval.md`: query engines, response modes, filters, citations, reranking, and evaluation.

## Resources

- LlamaIndex docs: https://developers.llamaindex.ai/python/framework/
- LlamaIndex GitHub: https://github.com/run-llama/llama_index
- LlamaHub: https://llamahub.ai
- Orchestra Research source: https://github.com/Orchestra-Research/AI-Research-SKILLs
