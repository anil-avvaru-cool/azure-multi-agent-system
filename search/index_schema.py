"""Schema for the auto_policy_documents Azure AI Search index.

Namespace follows DEC-021's {lob}_{doc_type} convention
(redwood-ai-insurance/docs/DECISION_LOG.md#dec-021) — this index is Auto P&C
only for Phase 1; a Life/Health index is out of scope until
insurance-data-platform supports a second LOB (per CLOUD_ARCHITECTURE_AZURE.md
§7's Azure-specific note).

Fields (id/title/category/content/embedding) match the shape Foundry's
AzureAISearchTool expects for sensible grounded results.
"""

from azure.search.documents.indexes.models import (
    HnswAlgorithmConfiguration,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    SearchIndex,
    SimpleField,
    VectorSearch,
    VectorSearchProfile,
)

INDEX_NAME = "auto_policy_documents"
VECTOR_SEARCH_PROFILE_NAME = "auto_policy_documents-vector-profile"
VECTOR_SEARCH_ALGORITHM_NAME = "auto_policy_documents-hnsw"


def build_index(embedding_dimensions: int) -> SearchIndex:
    return SearchIndex(
        name=INDEX_NAME,
        fields=[
            SimpleField(name="id", type=SearchFieldDataType.String, key=True),
            SearchableField(name="title", type=SearchFieldDataType.String),
            SimpleField(
                name="category",
                type=SearchFieldDataType.String,
                filterable=True,
                facetable=True,
            ),
            SearchableField(name="content", type=SearchFieldDataType.String),
            SearchField(
                name="embedding",
                type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True,
                vector_search_dimensions=embedding_dimensions,
                vector_search_profile_name=VECTOR_SEARCH_PROFILE_NAME,
            ),
        ],
        vector_search=VectorSearch(
            algorithms=[HnswAlgorithmConfiguration(name=VECTOR_SEARCH_ALGORITHM_NAME)],
            profiles=[
                VectorSearchProfile(
                    name=VECTOR_SEARCH_PROFILE_NAME,
                    algorithm_configuration_name=VECTOR_SEARCH_ALGORITHM_NAME,
                )
            ],
        ),
    )
