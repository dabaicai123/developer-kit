# LlamaIndex Query And Retrieval

Query engines combine retrieval and grounded synthesis. Keep the first version simple, then add filters, response modes, or postprocessors based on measured retrieval quality.

This reference is adapted for RAG-only use from the MIT-licensed Orchestra Research LlamaIndex material and omits non-retrieval patterns.

## Baseline Query Engine

```python
from llama_index.core import VectorStoreIndex

index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine(similarity_top_k=3)

response = query_engine.query("What does the policy say about refunds?")
```

## Response Modes

| Mode | Use when |
|---|---|
| `compact` | Default direct Q&A over a small retrieved context. |
| `refine` | The answer needs careful synthesis across multiple chunks. |
| `tree_summarize` | The user asks for a summary across many chunks. |
| `no_text` | You need to inspect retrieved nodes without generation. |

## Metadata Filtering

Use filters for tenant, permissions, dates, and document type before generation.

```python
from llama_index.core.vector_stores import ExactMatchFilter, MetadataFilters

filters = MetadataFilters(
    filters=[
        ExactMatchFilter(key="tenant_id", value=tenant_id),
        ExactMatchFilter(key="document_type", value="policy"),
    ]
)

query_engine = index.as_query_engine(
    similarity_top_k=5,
    filters=filters,
)
```

## Source Citations

Always inspect `source_nodes` when answers need citations.

```python
response = query_engine.query(question)

for node in response.source_nodes:
    print(node.score, node.metadata.get("source_uri"), node.metadata.get("page"))
```

Answer formatting should include source metadata and refuse when retrieved evidence is insufficient.

## Reranking

Add reranking when baseline top-k returns many weak or near-duplicate chunks.

```python
from llama_index.core.postprocessor import SentenceTransformerRerank

reranker = SentenceTransformerRerank(
    model="cross-encoder/ms-marco-MiniLM-L-2-v2",
    top_n=3,
)

query_engine = index.as_query_engine(
    similarity_top_k=10,
    node_postprocessors=[reranker],
)
```

## Query Transforms

Use query transforms after measuring a baseline. HyDE can help vague semantic searches, but it can also introduce drift.

```python
from llama_index.core.query_engine import TransformQueryEngine
from llama_index.core.query_transforms import HyDEQueryTransform

base_query_engine = index.as_query_engine(similarity_top_k=5)
query_engine = TransformQueryEngine(
    query_engine=base_query_engine,
    query_transform=HyDEQueryTransform(include_original=True),
)
```

## Evaluation

Evaluate retrieval and generation separately.

Retrieval checks:

- Hit rate: expected source appears in top-k.
- MRR: expected source appears early.
- Filter correctness: no cross-tenant or unauthorized source appears.
- Source diversity: repeated chunks do not crowd out useful evidence.

Generation checks:

- Faithfulness to retrieved context.
- Citation coverage for factual claims.
- Refusal when context is missing or contradictory.
- Answer relevance to the user question.

## Upstream Links

- Orchestra Research source repository: https://github.com/Orchestra-Research/AI-Research-SKILLs
- LlamaIndex query engines: https://developers.llamaindex.ai/python/framework/module_guides/deploying/query_engine/
- LlamaIndex response modes: https://developers.llamaindex.ai/python/framework/module_guides/deploying/query_engine/response_modes/
