"""Fakes for local agent-wiring tests — no live Azure calls.

Mirrors the fake-client pattern in
fnol-claims-multi-agent-system/tests/fakes (e.g. fake_rag_client.py): a
minimal stand-in that records what it was called with, so tests assert on
*our* wiring logic rather than exercising the real Azure SDK.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class FakeAzureAISearchContextProvider:
    """Stands in for agent_framework.azure.AzureAISearchContextProvider."""

    endpoint: str
    index_name: str
    credential: Any = None
    top_k: int = 5


class FakeFoundryChatClient:
    """Stands in for agent_framework.foundry.FoundryChatClient."""

    def __init__(self) -> None:
        self.created_agents: list[dict[str, Any]] = []


class FakeAgent:
    """Stands in for agent_framework.Agent."""

    def __init__(self, client: FakeFoundryChatClient, *, name: str, instructions: str, context_providers: list) -> None:
        self.client = client
        self.name = name
        self.instructions = instructions
        self.context_providers = context_providers
        client.created_agents.append(
            {
                "name": name,
                "instructions": instructions,
                "context_providers": context_providers,
            }
        )
