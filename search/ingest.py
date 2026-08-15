"""Create (or update) auto_policy_documents and push the sample Auto P&C
corpus into it, embedding each document via the Azure OpenAI deployment
configured in config.settings.

Run once against a real Azure AI Search + Azure OpenAI resource during
provisioning (AZURE_FEATURE_IMPLEMENTATION_GUIDE.md Phase 3 step, scoped down
to this repo's single index):

    uv run python -m search.ingest

Phase 1 simplification, stated explicitly: each sample document is embedded
and indexed as a single chunk. A production ingestion path would chunk long
documents — not needed at this corpus's size (a handful of short policy
excerpts).
"""

from __future__ import annotations

import re
from pathlib import Path

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from openai import AzureOpenAI

from config.settings import settings
from search.index_schema import INDEX_NAME, build_index

SAMPLE_DOCUMENTS_DIR = Path(__file__).parent / "sample_documents"


def _load_documents() -> list[dict]:
    documents = []
    for path in sorted(SAMPLE_DOCUMENTS_DIR.glob("*.md")):
        text = path.read_text(encoding="utf-8").strip()
        title_match = re.match(r"^#\s+(.+)$", text.splitlines()[0])
        title = title_match.group(1) if title_match else path.stem
        category = path.stem.split("_")[0]
        documents.append(
            {
                "id": path.stem,
                "title": title,
                "category": category,
                "content": text,
            }
        )
    return documents


def _embed(client: AzureOpenAI, texts: list[str]) -> list[list[float]]:
    response = client.embeddings.create(
        model=settings.azure_openai_embedding_deployment_name,
        input=texts,
    )
    return [item.embedding for item in response.data]


def main() -> None:
    documents = _load_documents()
    if not documents:
        raise RuntimeError(f"No sample documents found in {SAMPLE_DOCUMENTS_DIR}")

    credential = DefaultAzureCredential()

    index_client = SearchIndexClient(endpoint=settings.azure_search_endpoint, credential=credential)
    index_client.create_or_update_index(build_index(settings.azure_openai_embedding_dimensions))

    # Entra ID auth throughout (DefaultAzureCredential/managed identity), no API
    # keys — consistent with DEC-023's identity-based access posture.
    token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")
    openai_client = AzureOpenAI(
        azure_endpoint=settings.azure_openai_endpoint,
        api_version=settings.azure_openai_api_version,
        azure_ad_token_provider=token_provider,
    )
    embeddings = _embed(openai_client, [doc["content"] for doc in documents])
    for doc, embedding in zip(documents, embeddings):
        doc["embedding"] = embedding

    search_client = SearchClient(
        endpoint=settings.azure_search_endpoint,
        index_name=INDEX_NAME,
        credential=credential,
    )
    result = search_client.upload_documents(documents=documents)
    failed = [r for r in result if not r.succeeded]
    if failed:
        raise RuntimeError(f"{len(failed)}/{len(documents)} documents failed to index: {failed}")

    print(f"Indexed {len(documents)} documents into '{INDEX_NAME}'.")


if __name__ == "__main__":
    main()
