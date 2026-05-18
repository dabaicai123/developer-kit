# LlamaIndex RAG Data Ingestion

RAG ingestion converts source content into `Document` objects with stable IDs and metadata that retrieval can filter and cite later.

This reference is adapted for RAG-only use from the MIT-licensed Orchestra Research LlamaIndex material and should be checked against current LlamaIndex docs before implementing package-specific imports.

## Baseline Reader

Use `SimpleDirectoryReader` for local files before adding source-specific readers.

```python
from llama_index.core import SimpleDirectoryReader

documents = SimpleDirectoryReader(
    input_dir="./data",
    recursive=True,
    required_exts=[".pdf", ".docx", ".txt", ".md"],
).load_data()
```

## Source-Specific Readers

Choose a reader only when the baseline reader cannot preserve the source structure or metadata you need.

| Source | Typical reader package | Metadata to preserve |
|---|---|---|
| Local files | `llama_index.core.SimpleDirectoryReader` | file path, extension, modified time |
| Web pages | `llama_index.readers.web` | URL, title, crawl time |
| PDFs | `llama_index.readers.file` | file path, page number |
| GitHub | `llama_index.readers.github` | owner, repo, branch, path, commit |
| SaaS/data stores | LlamaHub reader packages | tenant, object ID, permissions |

## Metadata Policy

Every document should carry enough metadata for filtering, citation, and re-ingestion.

Required fields for production RAG:

- `source_id`: stable source-system identifier.
- `source_uri`: URL, file path, or object location.
- `tenant_id`: tenant or workspace boundary when applicable.
- `permission_scope`: access-control boundary when applicable.
- `document_type`: source category such as policy, ticket, page, or code.
- `ingested_at`: ingestion timestamp.

## Document IDs

Use deterministic IDs when re-ingesting the same source.

```python
from llama_index.core import Document

doc = Document(
    id_="policy-handbook:v3:page-12",
    text=page_text,
    metadata={
        "source_id": "policy-handbook:v3",
        "page": 12,
        "document_type": "policy",
    },
)
```

## Ingestion Checks

- Verify document count by source before indexing.
- Sample parsed text before chunking.
- Confirm metadata survives parsing and chunking.
- Deduplicate by stable source ID and content hash.
- Treat parsed content as untrusted user-controlled text.

## Upstream Links

- Orchestra Research source repository: https://github.com/Orchestra-Research/AI-Research-SKILLs
- LlamaIndex data connectors: https://developers.llamaindex.ai/python/framework/module_guides/loading/
- LlamaHub: https://llamahub.ai/
