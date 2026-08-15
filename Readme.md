# Azure Multi-Agent System

> Redwood AI Insurance's Azure substrate agent services — Microsoft Agent
> Framework, hosted as Azure AI Foundry Agent Service hosted agents, per
> [DEC-025/026](https://github.com/anil-avvaru-cool/redwood-ai-insurance/blob/main/docs/DECISION_LOG.md).

**[Local setup →](docs/Local_setup.md)** | **Prerequisites:** Python 3.11+, UV, Azure CLI, Azure Developer CLI

---

## What this is

The platform-wide [Readme](https://github.com/anil-avvaru-cool/redwood-ai-insurance)
documents Azure as a substrate where all four Redwood agent services —
`fnol-claims-agent`, `underwriting-quote-agent`, `doc-verification-agent`,
`subrogation-agent` — move to **Microsoft Agent Framework**, hosted as
**Azure AI Foundry Agent Service** hosted agents, with **Azure AI Search** as
the default RAG index for Auto P&C. This repo is where that gets built, one
agent at a time, against a real Azure subscription — not the LangGraph +
Anthropic stack the other substrates (and `fnol-claims-multi-agent-system`)
use.

It's a separate repo from `fnol-claims-multi-agent-system` because it's a
genuinely different SDK stack, matching how the platform already separates
concerns by repo.

## Platform Status

| Component | Status |
|---|---|
| Phase 1 — `policy_qa_agent` (Azure AI Search RAG, Foundry hosted agent) | 🚧 In progress |
| `fnol-claims-agent` (Responses protocol) | 📋 Planned |
| `underwriting-quote-agent` (Responses protocol) | 📋 Planned |
| `doc-verification-agent` (Invocations protocol) | 📋 Planned |
| `subrogation-agent` (Invocations protocol) | 📋 Planned |
| Private networking (DEC-023) | 📋 Planned — Phase 1 runs on public network access |

## Phase 1 — Policy Q&A Agent

One agent, `policy_qa_agent`, answers Auto P&C coverage/exclusion/claims-
procedure questions grounded on a small `auto_policy_documents` Azure AI
Search index. See [docs/PHASE_1_POLICY_QA_AGENT.md](docs/PHASE_1_POLICY_QA_AGENT.md)
for scope, rationale, and the provisioning order.

```
azure-multi-agent-system/
├── agents/policy_qa_agent/   # Microsoft Agent Framework agent + instructions
├── search/                   # auto_policy_documents index schema, ingestion, sample corpus
├── hosted_agent/             # azd-scaffolded Foundry hosted-agent project (generated, not hand-authored)
├── config/                   # fail-fast settings (os.environ[...], no defaults)
├── tests/                    # local wiring tests against fakes, no live Azure calls
└── docs/
```

## Roadmap

Later phases extend this repo toward the full Azure build-out in
`redwood-ai-insurance/docs/AZURE_FEATURE_IMPLEMENTATION_GUIDE.md`: the
remaining three agent services, private endpoints (DEC-023), the Azure AI
Search / Redis feature-store-spine composition needed for
`risk_score_at_issuance`-aware retrieval, and the Agent Registry entry for
each service — each taken on once the prior phase is validated against a real
deployment, not designed speculatively ahead of that.

## About This Project

Part of [Redwood AI Insurance](https://github.com/anil-avvaru-cool/redwood-ai-insurance),
a fictitious-company architecture and systems-design portfolio project — no
real carrier or customer data exists behind it.
