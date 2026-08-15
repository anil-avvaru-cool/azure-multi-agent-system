"""Local wiring tests for policy_qa_agent — no live Azure calls. Confirms the
agent is assembled the way build_agent/build_search_context_provider intend:
instructions set, search context provider attached with the right index, no
accidental drift.
"""

from agents.policy_qa_agent.agent import AGENT_NAME, build_agent
from agents.policy_qa_agent.instructions import POLICY_QA_INSTRUCTIONS
from tests.fakes.fake_search_client import FakeAgent, FakeAzureAISearchContextProvider, FakeFoundryChatClient


def test_build_agent_wires_instructions_and_name():
    client = FakeFoundryChatClient()
    search_context_provider = FakeAzureAISearchContextProvider(
        endpoint="https://fake.search.windows.net", index_name="auto_policy_documents"
    )

    agent = build_agent(client=client, search_context_provider=search_context_provider, agent_cls=FakeAgent)

    assert agent.name == AGENT_NAME
    assert agent.instructions == POLICY_QA_INSTRUCTIONS


def test_build_agent_attaches_search_context_provider():
    client = FakeFoundryChatClient()
    search_context_provider = FakeAzureAISearchContextProvider(
        endpoint="https://fake.search.windows.net", index_name="auto_policy_documents"
    )

    agent = build_agent(client=client, search_context_provider=search_context_provider, agent_cls=FakeAgent)

    assert agent.context_providers == [search_context_provider]


def test_build_agent_registers_itself_on_the_chat_client():
    client = FakeFoundryChatClient()
    search_context_provider = FakeAzureAISearchContextProvider(
        endpoint="https://fake.search.windows.net", index_name="auto_policy_documents"
    )

    build_agent(client=client, search_context_provider=search_context_provider, agent_cls=FakeAgent)

    assert len(client.created_agents) == 1
    assert client.created_agents[0]["name"] == AGENT_NAME
