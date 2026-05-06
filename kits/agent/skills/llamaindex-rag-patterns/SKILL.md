---
name: llamaindex-rag-patterns
description: "LlamaIndex RAG pipeline patterns: ingestion, indexing strategies, query engines, retrieval optimization, agentic RAG, Workflows, and evaluation. Use when building RAG systems or document-based AI applications with LlamaIndex."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LlamaIndex RAG Patterns

Production patterns for building RAG pipelines with LlamaIndex. Covers ingestion, indexing, query engines, retrieval optimization, agentic RAG, Workflows, and evaluation.

## When to use this skill

- Loading documents with LlamaHub connectors or LlamaParse
- Choosing between VectorStoreIndex, keyword index, or hybrid indexing
- Building query or chat engines for retrieval
- Optimizing retrieval with hybrid search, reranking, or metadata filtering
- Implementing agentic RAG with document agents and a meta-agent
- Building custom Workflows for event-driven orchestration
- Setting up observability or evaluation for a RAG pipeline

## Ingestion Pipeline

Load documents from any source, then index them for retrieval.

**SimpleDirectoryReader** — load files from a local directory:

```python
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex

documents = SimpleDirectoryReader("./data").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()
response = query_engine.query("What are the key findings?")
```

**LlamaHub connectors** — 100+ data connectors for databases, APIs, cloud storage, and more. Use when your data source is not a local directory.

```python
from llama_index.readers.database import DatabaseReader

reader = DatabaseReader(uri="postgresql://user:pass@host/db")
documents = reader.load_data(query="SELECT content FROM articles")
```

**LlamaParse** — for complex documents with nested tables, embedded images, or unusual formatting. LlamaParse handles PDFs that standard readers cannot parse correctly.

```python
from llama_parse import LlamaParse

parser = LlamaParse(
    result_type="markdown",
    api_key="llx-...",
)
documents = parser.load_data("./data/complex_report.pdf")
```

## Indexing Strategies

| Strategy | When to use | Tradeoff |
|---|---|---|
| VectorStoreIndex | Default. Semantic search over embedded chunks | Requires embedding model; semantic similarity only |
| Keyword table index | Exact keyword matching; structured queries | No semantic understanding; misses paraphrases |
| Hybrid (vector + BM25) | Need both semantic and keyword recall | More complex setup; two retrieval passes |

**VectorStoreIndex customization:**

```python
from llama_index.core import VectorStoreIndex, Settings
from llama_index.core.node_parser import SentenceSplitter

Settings.chunk_size = 512
Settings.chunk_overlap = 50
Settings.embed_model = "local:BAAI/bge-small-en-v1.5"

splitter = SentenceSplitter(chunk_size=512, chunk_overlap=50)
nodes = splitter.get_nodes_from_documents(documents)

index = VectorStoreIndex(nodes)
```

**Hybrid index with vector + BM25:**

```python
from llama_index.core import VectorStoreIndex, SummaryIndex
from llama_index.core.retrievers import QueryFusionRetriever

vector_retriever = index.as_retriever(similarity_top_k=5)
keyword_retriever = keyword_index.as_retriever(similarity_top_k=5)

fusion_retriever = QueryFusionRetriever(
    retrievers=[vector_retriever, keyword_retriever],
    num_queries=1,
    similarity_top_k=10,
    mode="reciprocal_rerank",
)
```

**Vector store backend** — swap the default in-memory store to a persistent backend (Postgres, Pinecone, Weaviate, Chroma) for production scale.

```python
from llama_index.vector_stores.chroma import ChromaVectorStore
import chromadb

chroma_client = chromadb.PersistentClient(path="./chroma_db")
chroma_collection = chroma_client.get_or_create_collection("documents")
vector_store = ChromaVectorStore(chroma_collection=chroma_collection)

index = VectorStoreIndex.from_vector_store(vector_store)
```

## Query Engines

| Engine | Use case | Key method |
|---|---|---|
| `as_query_engine()` | Single-turn Q&A | Returns a response for one query |
| `as_chat_engine()` | Multi-turn conversation | Maintains chat history and context |
| Sub-question query engine | Complex queries requiring decomposition | Breaks query into sub-questions, retrieves for each |

```python
query_engine = index.as_query_engine(
    similarity_top_k=5,
    response_mode="tree_summarize",
)

chat_engine = index.as_chat_engine(
    chat_mode="condense_plus_retrieve",
    similarity_top_k=5,
)
```

**Sub-question query engine** — for queries that span multiple aspects or documents:

```python
from llama_index.core.query_engine import SubQuestionQueryEngine

sub_question_engine = SubQuestionQueryEngine.from_defaults(
    query_engine_tools=[
        QueryEngineTool(
            query_engine=finance_index.as_query_engine(),
            tool_name="finance_data",
            tool_description="Financial reports and market data",
        ),
        QueryEngineTool(
            query_engine=tech_index.as_query_engine(),
            tool_name="tech_data",
            tool_description="Technical documentation and specs",
        ),
    ],
)

response = sub_question_engine.query(
    "What is the revenue growth and what technology drives it?"
)
```

## Retrieval Optimization

**Hybrid search** — combine semantic (vector) and keyword (BM25) retrieval. Reciprocal rank fusion merges results from both passes:

```python
from llama_index.core.retrievers import QueryFusionRetriever

fusion_retriever = QueryFusionRetriever(
    retrievers=[vector_retriever, keyword_retriever],
    num_queries=1,
    similarity_top_k=10,
    mode="reciprocal_rerank",
)

nodes = fusion_retriever.retrieve("how to optimize query performance")
```

**Reranking** — after initial retrieval, rerank nodes by relevance. Reduces noise and improves top-k precision.

```python
from llama_index.postprocessor.cohere_rerank import CohereRerank

reranker = CohereRerank(api_key="...", top_n=5)

query_engine = index.as_query_engine(
    similarity_top_k=20,
    node_postprocessors=[reranker],
)
```

**Top-k tuning** — retrieve more nodes initially (top_k=20), then rerank down to 5. This catches borderline-relevant nodes that a low top-k would miss.

**Metadata filtering** — restrict retrieval to nodes matching metadata criteria. Use for partitioned data (by date, category, source).

```python
from llama_index.core.vector_stores import MetadataFilters, MetadataFilter

filters = MetadataFilters(
    filters=[
        MetadataFilter(key="category", value="finance"),
        MetadataFilter(key="year", value=2025, operator=">="),
    ]
)

query_engine = index.as_query_engine(filters=filters)
```

## Agentic RAG

Instead of a single retrieval pass, use agents that can search, summarize, and reason over documents.

**Pattern: Meta-agent over document agents**

Each document gets its own agent (search + summarize capabilities). A top-level meta-agent selects which document agent to query based on the user question, then synthesizes responses.

```python
from llama_index.core.agent import AgentRunner
from llama_index.core.tools import QueryEngineTool, ToolMetadata

document_agents = {}
document_tools = []

for doc_title, doc_index in document_indexes.items():
    doc_query_engine = doc_index.as_query_engine(similarity_top_k=5)
    doc_summary_engine = doc_index.as_query_engine(response_mode="tree_summarize")

    doc_tool = QueryEngineTool(
        query_engine=doc_query_engine,
        metadata=ToolMetadata(
            name=f"{doc_title}_search",
            description=f"Search within {doc_title}",
        ),
    )
    summary_tool = QueryEngineTool(
        query_engine=doc_summary_engine,
        metadata=ToolMetadata(
            name=f"{doc_title}_summary",
            description=f"Summarize {doc_title}",
        ),
    )

    document_agents[doc_title] = AgentRunner.from_tools(
        tools=[doc_tool, summary_tool],
        verbose=True,
    )

    document_tools.append(
        QueryEngineTool(
            query_engine=document_agents[doc_title],
            metadata=ToolMetadata(
                name=doc_title,
                description=f"Agent for querying {doc_title}",
            ),
        )
    )

meta_agent = AgentRunner.from_tools(
    tools=document_tools,
    verbose=True,
)

response = meta_agent.query("Compare the investment strategies across all reports")
```

The meta-agent performs tool retrieval (choosing which document to query) and Chain-of-Thought reasoning (synthesizing across documents). This outperforms flat retrieval for multi-document queries.

## Workflows

Event-driven orchestration for building custom agent pipelines from scratch. Async-first, stateful, composable.

**Core concepts:**

- **Events** — typed messages that flow between steps. `StartEvent` kicks off the workflow; `StopEvent` ends it. Custom events carry data between steps.
- **Steps** — methods decorated with `@step` that receive events and emit new events. Each step is an async function.
- **Context** — stateful data store shared across steps. Pass data via event payloads or context.

```python
from llama_index.core.workflow import (
    Workflow, StartEvent, StopEvent, Context, step
)

class RetrieveEvent(Event):
    query: str

class RerankEvent(Event):
    query: str
    nodes: list

class RAGWorkflow(Workflow):
    @step(pass_context=True)
    async def retrieve(self, ctx: Context, ev: StartEvent) -> RetrieveEvent:
        query = ev.query
        ctx.data["query"] = query
        nodes = await self.retriever.aretrieve(query)
        return RetrieveEvent(query=query)

    @step(pass_context=True)
    async def rerank(self, ctx: Context, ev: RetrieveEvent) -> RerankEvent:
        reranked_nodes = self.reranker.postprocess_nodes(
            ev.nodes, query_str=ev.query
        )
        ctx.data["nodes"] = reranked_nodes
        return RerankEvent(query=ev.query, nodes=reranked_nodes)

    @step(pass_context=True)
    async def synthesize(self, ctx: Context, ev: RerankEvent) -> StopEvent:
        response = self.synthesizer.synthesize(
            ev.query, nodes=ev.nodes
        )
        ctx.data["response"] = response
        return StopEvent(result=response)

workflow = RAGWorkflow(timeout=60, verbose=True)
result = await workflow.run(query="What are the key findings?")
```

**AgentWorkflow** — multi-agent collaboration with handoffs. Agents can transfer work to other agents:

```python
from llama_index.core.agent.workflow import (
    AgentWorkflow, FunctionAgent, ReActAgent, CodeActAgent
)

researcher = FunctionAgent(
    name="Researcher",
    description="Searches for information and gathers data",
    tools=[search_tool, web_reader_tool],
    system_prompt="You research topics thoroughly and return findings.",
)

analyst = ReActAgent(
    name="Analyst",
    description="Analyzes data and produces insights",
    tools=[calculator_tool, chart_tool],
    system_prompt="You analyze data and produce visualizations.",
)

workflow = AgentWorkflow(
    agents=[researcher, analyst],
    root_agent=researcher,
)

response = await workflow.run(user_msg="Analyze the AI market trends")
```

## Observability

One-click instrumentation for tracing and debugging. Connects to Arize Phoenix, Langfuse, MLflow, and other observability platforms.

```python
import llama_index.core
from llama_index.core.callbacks import CallbackManager

llama_index.core.global_handler = "arize_phoenix"
```

Each retrieval, synthesis, and tool call becomes a trace span. Inspect latency, token counts, and retrieval quality in the observability dashboard. Instrument before you optimize.

## Evaluation

| Metric | Measures | When to use |
|---|---|---|
| Hit Rate | Fraction of queries where the correct document appears in top-k | Retrieval quality |
| MRR (Mean Reciprocal Rank) | Average rank position of the first correct document | Retrieval ranking quality |
| Faithfulness | Whether the response is grounded in retrieved context | Response accuracy |
| Relevancy | Whether the response addresses the query | Response relevance |

```python
from llama_index.core.evaluation import (
    RetrieverEvaluator, ResponseEvaluator,
)

retriever_evaluator = RetrieverEvaluator.from_defaults(
    retriever=index.as_retriever(similarity_top_k=5),
)

eval_result = await retriever_evaluator.aevaluate(
    query="What is the revenue growth?",
    expected_ids=["doc_42"],
)

print(f"Hit Rate: {eval_result.hit_rate}")
print(f"MRR: {eval_result.mrr}")
```

Build a golden evaluation dataset with 50+ test cases covering happy path, edge cases, and adversarial inputs. Evaluate retrieval and response separately.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Default chunk size for all documents | Different document types need different chunking | Tune chunk_size per document type (512 for dense text, 1024 for sparse) |
| Single-pass retrieval without reranking | Top-k returns noisy results | Retrieve wide (top_k=20), rerank narrow (top_n=5) |
| Flat retrieval for multi-document queries | Single index cannot distinguish document boundaries | Agentic RAG with document agents |
| Skipping evaluation until production | Cannot measure quality improvements | Build eval dataset from day one |
| In-memory vector store for production | Data lost on restart; cannot scale | Use persistent vector store (Chroma, Postgres, Pinecone) |
| No observability | Cannot debug retrieval failures or latency issues | Instrument with Phoenix or Langfuse before tuning |

## References

- LlamaIndex documentation: https://docs.llamaindex.ai
- LlamaHub connectors: https://llamahub.ai
- LlamaParse: https://docs.llamaindex.ai/en/latest/llama_parse/

## Related Skills

- `mcp-integration` — Connecting MCP tool servers to LlamaIndex agents
- `agent-context-management` — Context window management for long RAG sessions
- `multi-agent-orchestration` — General multi-agent patterns beyond LlamaIndex

## Keywords

llamaindex, rag, ingestion, vector store index, hybrid search, bm25, reranking, query engine, chat engine, sub-question query, agentic rag, workflows, agent workflow, evaluation, hit rate, mrr, faithfulness, observability, llamaparse, llamahub