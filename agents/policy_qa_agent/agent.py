"""policy_qa_agent — Microsoft Agent Framework agent, Foundry-hosted (Responses
protocol), grounded on the auto_policy_documents Azure AI Search index.

Phase 1 of the Azure substrate build-out (see
redwood-ai-insurance/docs/AZURE_FEATURE_IMPLEMENTATION_GUIDE.md). Exercises
DEC-025 (Microsoft Agent Framework + Foundry Agent Service as Azure's
orchestration path) and DEC-026 (Azure AI Search as Azure's default RAG index)
end to end, at the smallest useful scope.

API surface verified against the installed package versions (agent-framework-
core 1.14.0, agent-framework-foundry 1.x, agent-framework-azure-ai-search
1.0.0b260813) — this is a fast-moving public preview; re-check these imports
against whatever versions are actually installed before relying on this code,
since even minor versions of the split agent-framework-* packages have broken
compatibility with each other during this build (agent-framework-azure-ai was
dropped in favor of agent_framework.foundry + agent_framework.azure for
exactly this reason — see docs/PHASE_1_POLICY_QA_AGENT.md).

`build_agent`'s wiring has been construction-verified against the real SDK
classes (not just the fakes below): `instructions=` lands in the resulting
`Agent.default_options["instructions"]`, and `context_providers=` holds the
real `AzureAISearchContextProvider` instance. What's still unverified is
runtime behavior against a live Foundry deployment and live index — object
construction succeeding is necessary, not sufficient.

`build_search_context_provider`/`build_agent` are split from `run` so tests
can construct and inspect the wiring (context provider attached, instructions
set, index name correct) without needing live Azure credentials — see
tests/test_agent_local.py.
"""

from __future__ import annotations

from typing import Any

from agent_framework import Agent
from agent_framework.azure import AzureAISearchContextProvider
from agent_framework.foundry import FoundryChatClient

from agents.policy_qa_agent.instructions import POLICY_QA_INSTRUCTIONS

AGENT_NAME = "policy_qa_agent"


def build_search_context_provider(
    search_endpoint: str, search_index_name: str, credential: Any, top_k: int = 5
) -> AzureAISearchContextProvider:
    """Azure AI Search wired in as an agent-framework ContextProvider (DEC-026)
    — talks to the index directly via `search_endpoint`/`credential`, no
    Foundry connection resource required.
    """
    return AzureAISearchContextProvider(
        endpoint=search_endpoint,
        index_name=search_index_name,
        credential=credential,
        top_k=top_k,
    )


def build_agent(client: Any, search_context_provider: Any, agent_cls: type = Agent) -> Any:
    """Assemble the agent. `client` is a FoundryChatClient in production and a
    fake in tests (see tests/fakes/fake_search_client.py).
    """
    return agent_cls(
        client,
        name=AGENT_NAME,
        instructions=POLICY_QA_INSTRUCTIONS,
        context_providers=[search_context_provider],
    )


async def run(question: str) -> str:
    """Production entry point — builds real Azure clients from config.settings
    and asks a single question. Used for manual smoke testing; the hosted
    agent runtime (hosted_agent/, ResponsesHostServer) builds and serves the
    same `build_agent(...)` result instead of calling this function directly.
    """
    from azure.identity.aio import DefaultAzureCredential

    from config.settings import settings

    async with DefaultAzureCredential() as credential:
        client = FoundryChatClient(
            project_endpoint=settings.azure_ai_project_endpoint,
            model=settings.azure_ai_model_deployment_name,
            credential=credential,
        )
        search_context_provider = build_search_context_provider(
            search_endpoint=settings.azure_search_endpoint,
            search_index_name=settings.azure_search_index_name,
            credential=credential,
        )
        agent = build_agent(client=client, search_context_provider=search_context_provider)
        result = await agent.run(question)
        return str(result)
