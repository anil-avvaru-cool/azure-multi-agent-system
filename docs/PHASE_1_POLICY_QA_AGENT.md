# Phase 1 — Policy Q&A Agent

## What this is

The first agent service in `azure-multi-agent-system`: a single Microsoft
Agent Framework agent, `policy_qa_agent`, that answers Auto P&C
coverage/exclusion/claims-procedure questions grounded on a small
`auto_policy_documents` Azure AI Search index, deployed as an Azure AI Foundry
Agent Service hosted agent.

## Why this slice first

Per `redwood-ai-insurance/docs/CLOUD_ARCHITECTURE_AZURE.md` §2 and §11
(DEC-025/026), Azure's orchestration path (Microsoft Agent Framework +
Foundry Agent Service) and RAG path (Azure AI Search) are both flagged as
having **no Redwood production track record**. Phase 1 exercises exactly
those two decisions against a real Azure subscription, at the smallest scope
that still proves something real:

- DEC-025 — can a Microsoft Agent Framework agent actually run as a Foundry
  hosted agent, end to end?
- DEC-026 — does Azure AI Search, wired in as a Foundry-managed tool, return
  usably grounded answers for Redwood's document shape?

Everything else in the full four-agent Azure build-out
(`AZURE_FEATURE_IMPLEMENTATION_GUIDE.md`'s 8 phases) is deliberately deferred
until this slice works.

## Explicitly out of scope for Phase 1

- Private endpoints / VNet (DEC-023) — this phase uses public network access
  on all resources; documented here as a stated pre-production gap, not an
  oversight. Do not point this repo's resources at customer data until
  private networking is added.
- `underwriting-quote-agent`, `doc-verification-agent`, `subrogation-agent`
- Workflows (deterministic HITL gate) — no gate is needed for a stateless Q&A
  agent
- MCP tool integration
- The Redis feature-store-spine join (`risk_score_at_issuance`,
  DEC-010) — this agent has no feature-store dependency
- Agent Registry, Entra ID/APIM OBO auth, multi-LOB indices (Life/Health)

## Corpus

`search/sample_documents/` holds five short, fictitious Auto P&C policy
excerpts (liability, collision/comprehensive, uninsured motorist, general
exclusions, claims-filing procedure) — no real carrier or customer data, no
PII, consistent with the platform's "fictitious company" framing.

## Provisioning order

See `docs/Local_setup.md` for tooling prerequisites. Steps 1–3 are now
codified as Bicep (`docs/INFRA_DEPLOYMENT_PLAN.md` Phase 0/1) — run with
`infra/deploy.sh up`, which prompts for confirmation before creating any
real, billable resource. Steps 4–5 stay on `azd` (not an ARM/Bicep
operation — see the plan's §1).

1. `az login`, then `infra/deploy.sh up` — provisions the resource group,
   Key Vault, managed identity (Phase 0), the Foundry account with its chat
   (`AZURE_AI_MODEL_DEPLOYMENT_NAME`) and embedding
   (`AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME`) model deployments, the Foundry
   project, the Azure AI Search service, and the RBAC role assignments
   wiring the managed identity to all three (Phase 1). Copy the endpoint
   outputs into `.env`.
2. `uv run python -m search.ingest` to create and populate
   `auto_policy_documents` on the Search service `infra/deploy.sh up` just
   provisioned.
3. `hosted_agent/README.md`'s `azd ai agent init -p <project-resource-id>`
   step, targeting the Bicep-provisioned Foundry project from step 1 instead
   of letting `azd` create its own — **unverified**, confirm the `-p` flag's
   behavior against this repo's installed `azd`/`microsoft.foundry`
   extension version before relying on it (`INFRA_DEPLOYMENT_PLAN.md` §6).
4. `azd up` — provisions the remaining hosted-agent runtime (container
   registry, App Insights, the agent's own managed identity/compute/
   endpoint) and deploys the agent. No separate Foundry → Azure AI Search
   connection resource is needed: `AzureAISearchContextProvider` reaches the
   index directly via `AZURE_SEARCH_ENDPOINT` + the deployed agent's managed
   identity.
5. Smoke test: ask the deployed agent a few in-corpus and out-of-corpus
   questions; confirm grounded, cited answers vs. an explicit "I don't have
   that" for the latter

## Package-surface risk, found and resolved during Phase 1 build

The Microsoft Agent Framework Python packages are split across several
separately-versioned PyPI packages (`agent-framework-core`,
`agent-framework-azure-ai`, `agent-framework-foundry`,
`agent-framework-azure-ai-search`, ...), and during this build the versions
that `uv`/`pip` resolve as "latest compatible" were **not actually
compatible with each other** — `agent-framework-azure-ai==1.0.0rc6` failed to
import against `agent-framework-core==1.14.0` (`ImportError: cannot import
name 'BaseContextProvider'`), and the top-level `ChatAgent`/`AzureAIAgentClient`
classes documented in older Microsoft Learn tutorials no longer exist in the
installed core. The working, verified-by-import combination used here is
`agent_framework.Agent` + `agent_framework.foundry.FoundryChatClient` +
`agent_framework.azure.AzureAISearchContextProvider`, from
`agent-framework-core` + `agent-framework-foundry` +
`agent-framework-foundry-hosting` + `agent-framework-azure-ai-search` (see
`pyproject.toml`). Re-verify this combination with `uv sync` before every
`azd up` while the framework is still in public preview — pin exact versions
once a combination is confirmed working end to end against a real deployment.
