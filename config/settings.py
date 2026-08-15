"""Runtime configuration. Fail-fast: every required value is read with
os.environ[...] (no defaults) so a missing value raises immediately at import
time instead of surfacing as a confusing error deep in an Azure SDK call.
"""

import os


class Settings:
    def __init__(self) -> None:
        # Azure AI Foundry project (agent runtime + model deployments live here)
        self.azure_ai_project_endpoint = os.environ["AZURE_AI_PROJECT_ENDPOINT"]
        self.azure_ai_model_deployment_name = os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"]

        # Azure OpenAI (used directly by search/ingest.py for embeddings)
        self.azure_openai_endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
        self.azure_openai_embedding_deployment_name = os.environ["AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME"]
        self.azure_openai_embedding_dimensions = int(os.environ["AZURE_OPENAI_EMBEDDING_DIMENSIONS"])
        self.azure_openai_api_version = os.environ["AZURE_OPENAI_API_VERSION"]

        # Azure AI Search — reached directly via AzureAISearchContextProvider
        # (endpoint + credential), no Foundry connection resource required.
        self.azure_search_endpoint = os.environ["AZURE_SEARCH_ENDPOINT"]
        self.azure_search_index_name = os.environ["AZURE_SEARCH_INDEX_NAME"]


settings = Settings()
