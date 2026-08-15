# Infrastructure Deployment Plan — Bicep
### azure-multi-agent-system — Hand-Authored Platform Infrastructure

> **Planning document, not a build log.** No resource in this plan has been
> provisioned via Bicep yet. Nothing here is implemented until each phase is
> reviewed and approved on its own — per this repo's Enterprise Architect
> Mode posture (`CLAUDE.md`), architecture and sequencing come before code.
> Derived from
> [`redwood-ai-insurance/docs/AZURE_FEATURE_IMPLEMENTATION_GUIDE.md`](../../redwood-ai-insurance/docs/AZURE_FEATURE_IMPLEMENTATION_GUIDE.md)
> and
> [`CLOUD_ARCHITECTURE_AZURE.md`](../../redwood-ai-insurance/docs/CLOUD_ARCHITECTURE_AZURE.md),
> scoped down to what this repo actually needs next, in small iterative
> phases rather than the full 8-phase enterprise build at once.

---

## 1. Purpose and Scope

`AZURE_FEATURE_IMPLEMENTATION_GUIDE.md` sequences the *full* four-agent,
private-networked, multi-service Azure build-out. This plan is the
hand-authored **Bicep subset of that guide for this repo, at this repo's
actual current scope** — one agent (`policy_qa_agent`) shipped, three more
planned. It answers: which pieces of Phase 1's currently-manual `az` CLI
steps become codified IaC now, and in what order do the next phases of
resources get added as later agents land.

**What this plan does *not* cover, on purpose:**

- **The Foundry hosted-agent scaffold** (`hosted_agent/`) — `azd ai agent
  init` / `azd up` generate that project's `azure.yaml`, `agent.yaml`, and
  its own infra-as-code. `hosted_agent/README.md` already states why this is
  intentionally not hand-authored: matching an `azd`/`microsoft.foundry`
  extension version by hand risks drift, which is exactly the kind of
  workaround this platform avoids. This Bicep plan provisions everything
  *around* that scaffold — resource group, Key Vault, Azure OpenAI, Azure AI
  Search — and stops at the Foundry project boundary.
- Private networking, AKS, ingress, Azure Firewall, APIM, ExpressRoute/VPN —
  all deferred, explicitly, to later phases below. Phase 1's own docs
  (`PHASE_1_POLICY_QA_AGENT.md`) already state private endpoints are
  out of scope until private networking is added; this plan keeps that
  posture rather than silently front-loading it.
- Entra ID app registrations — not Bicep-friendly at this scope (interactive
  admin consent, Graph API), tracked as a manual prerequisite, not a module.

---

## 2. Design Decisions

| Decision | Rationale |
|---|---|
| **One resource group**, `rg-redwood-azure-{env}` (`dev` today; `prod` reserved, not built) | "One or few resource groups" per request — keeps blast radius and cost visibility in one place for a portfolio-scale build. Split further only if a future phase needs an isolation boundary (e.g., a second RG for a Regulated/Restricted variant). |
| **Bicep, modules per resource, one param file per environment** | `infra/bicep/main.bicep` orchestrates `infra/bicep/modules/*.bicep`; `infra/bicep/params/dev.bicepparam` holds environment values. Matches the repo's existing `.env`/`config/settings.py` fail-fast pattern — no hardcoded values, secrets resolve through Key Vault. |
| **One `up` command, one `down` command** | `infra/deploy.sh up` runs `az deployment group create` against `main.bicep`; `infra/deploy.sh down` runs `az group delete` on the single resource group. Deleting the whole RG is the simplest correct "down" *because* everything lives in one RG (Decision 1) — no per-resource teardown ordering to get wrong. |
| **Dev-tier SKUs by default, cost tier labeled per phase** | This is a portfolio/demo build, not a live customer — Free/Basic/Serverless SKUs by default. Every phase below is labeled `$`–`$$$$` so a reviewer can see cost before approving a phase, per the request to mark costly resources out as future work. |
| **Public network access by default; private networking is Phase 4, not silently skipped** | Matches Phase 1's already-documented stance (`PHASE_1_POLICY_QA_AGENT.md` §Explicitly out of scope). Flagging it as a numbered future phase — not an omission — keeps it honest the way the source guide's DEC-023 posture demands before any real customer data touches these resources. |
| **Bicep takes over Phase 1's manual `az` steps 1–3** (RG, Azure OpenAI, Azure AI Search) — `azd` keeps steps 4–5 (Foundry scaffold + `azd up`) | Codifies what's currently three manual, undocumented-as-code `az` commands in `PHASE_1_POLICY_QA_AGENT.md` §Provisioning order, without touching the part of the flow that has a stated reason to stay generated. |
| **Naming: underscores where Azure allows, hyphens where it doesn't** | Per repo standard (`CLAUDE.md`) and the source guide's own Phase 0.1 note — Azure forces hyphens/lowercase on some resource types (Storage, AKS, Key Vault, PostgreSQL Flexible Server). Document each exception at the module, don't fight the platform. |

---

## 3. Resource Group

| | |
|---|---|
| Name | `rg-redwood-azure-dev` |
| Region | Single region to start (no multi-region — not needed at this scale); pick the region with Azure AI Foundry + Azure AI Search + Azure OpenAI model availability |
| Tags | `project=redwood-ai-insurance`, `component=azure-multi-agent-system`, `environment=dev`, `managed-by=bicep` (except the Foundry sub-resources, tagged `managed-by=azd`) |

---

## 4. Phased Build Order

Each phase is small on purpose — "don't try too big tasks." A phase is not
started until the previous one is provisioned and smoke-tested. Cost tier is
relative, not a dollar estimate: `$` = free/near-free dev SKU, up to `$$$$` =
resources the source guide itself flags as the ones to gate behind an
explicit customer/engagement decision (Firewall, APIM, ExpressRoute).

### Phase 0 — Foundation *(Core, do first)*

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 0.1 | Resource group + tags | Blast-radius/cost boundary (§3) | $ | — |
| 0.2 | Azure Key Vault (public access for now, per §2) | Secret store for API keys/connection strings — nothing hardcoded, per repo standard | $ | 0.1 |
| 0.3 | User-assigned managed identity | Least-privilege auth from the Foundry hosted agent and any future AKS workload to Key Vault/Search/OpenAI, no shared credentials | $ | 0.1 |

### Phase 1 — AI Services Core *(Core — replaces Phase 1's manual `az` steps 1–3)*

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 1.1 | Azure OpenAI resource + chat + embedding model deployments | LLM inference + `search/ingest.py` embeddings — currently a manual step in `PHASE_1_POLICY_QA_AGENT.md` | $$ | 0.1, 0.2 |
| 1.2 | Azure AI Search service (Free or Basic tier) | `auto_policy_documents` index host — currently a manual step | $ (Free tier) | 0.1, 1.1 |
| 1.3 | RBAC role assignments (Search → managed identity, Key Vault → managed identity) | Entra ID auth throughout, no API keys, matching `example.env`'s stated posture | $ | 0.2, 0.3, 1.2 |

**Boundary with `azd`:** Phase 1 output (Search endpoint, OpenAI endpoint)
feeds `.env` values that `hosted_agent/`'s `azd ai agent init` /
`azd up` consume when scaffolding the Foundry project — this plan provisions
up to here and stops; the Foundry hub/project itself stays on `azd` per §1.

### Phase 2 — Data & State Layer *(Medium priority — needed once a second agent lands)*

Not needed by `policy_qa_agent` (stateless Q&A, no feature-store or
checkpoint dependency, per `PHASE_1_POLICY_QA_AGENT.md` §Explicitly out of
scope). Build this when `fnol-claims-agent` or the Agent Registry (Phase 7 in
the source guide) is actually started, not speculatively ahead of it.

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 2.1 | Azure Database for PostgreSQL (Flexible Server, Burstable SKU) | Agent Registry table — system of record for which agents exist (source guide Phase 7) | $$ | 0.1 |
| 2.2 | Cosmos DB (Gremlin API, serverless) | Graph queries + future `doc-verification-agent`/`subrogation-agent` Invocations session store | $$ | 0.1 |
| 2.3 | Azure Cache for Redis (Basic tier) | Online feature store — only once an agent needs `risk_score_at_issuance` (FNOL/Underwriting agents per Deployment Topologies) | $$ | 0.1 |

### Phase 3 — Observability *(Core, cheap — pull forward once Phase 1 is live)*

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 3.1 | Log Analytics workspace + Azure Monitor | Platform telemetry, drift monitoring hook-in point | $ | 0.1 |

### Phase 4 — Private Networking *(Future — deferred, not silently skipped)*

Gate: before any real/customer-like data touches these resources, per DEC-023
and `PHASE_1_POLICY_QA_AGENT.md`'s stated pre-production gap.

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 4.1 | VNet + subnets (private-endpoint subnet, future AKS/App Gateway subnets) | Address space + isolation | $ | 0.1 |
| 4.2 | Private DNS zones (OpenAI, Search, PostgreSQL, Redis, Cosmos, Storage) | Name resolution for every private endpoint below | $ | 4.1 |
| 4.3 | Private endpoints on 1.1, 1.2, 2.1–2.3 | Disable public network access on all data/AI resources | $$ | 4.1, 4.2, resources being privatized |
| 4.4 | NSGs / route tables | Enforce private-endpoint subnets only accept traffic from approved subnets | $ | 4.1 |

### Phase 5 — Compute for MCP / KServe *(Future — deferred until an agent needs tool calls)*

`policy_qa_agent` has no MCP tool integration
(`PHASE_1_POLICY_QA_AGENT.md`). Build this when a later agent needs it.

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 5.1 | AKS cluster (small/dev node pool, delegated subnet) | Hosts MCP servers + KServe only — no agent Deployments, per DEC-026 | $$$ | 4.1, 0.3 |
| 5.2 | MCP server Deployments (ClusterIP only) | Tool-contract layer | $ | 5.1 |

### Phase 6 — Ingress *(Future — deferred until a public-facing endpoint is needed)*

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 6.1 | Application Gateway + WAF | Only public surface, routes to Foundry Responses-protocol agents | $$ | 4.1 |

### Phase 7 — Advanced / Explicitly Cost-Gated *(Future — do not build without an engagement decision)*

Marked out per the request to call out costly resources rather than build
them by default. These map to items the source guide itself treats as
evaluated options, not defaults.

| # | Resource | Purpose | Cost |
|---|---|---|---|
| 7.1 | Azure Firewall | Egress control for a Regulated/Restricted posture | $$$$ |
| 7.2 | Azure API Management | Entra ID OBO token validation at the edge (source guide Phase 8, itself flagged "nothing in this phase exists in code today") | $$$ |
| 7.3 | ExpressRoute / VPN Gateway | Regulated/Restricted-only, no public IP anywhere | $$$$ |
| 7.4 | ADLS Gen2 + Synapse workspace | Offline feature store / DOI audit trail | $$$ |
| 7.5 | SharePoint Online connector | Automatic ingestion — SaaS-to-SaaS config, not a Bicep resource, listed here for completeness | — |

---

## 5. Up / Down Command Contract

```
infra/
├── bicep/
│   ├── main.bicep            # orchestrates modules for whichever phases are enabled
│   ├── modules/
│   │   ├── key_vault.bicep
│   │   ├── managed_identity.bicep
│   │   ├── openai.bicep
│   │   ├── ai_search.bicep
│   │   ├── postgresql.bicep      # Phase 2+
│   │   ├── cosmos_db.bicep       # Phase 2+
│   │   ├── redis.bicep           # Phase 2+
│   │   ├── networking.bicep      # Phase 4+
│   │   ├── aks.bicep             # Phase 5+
│   │   └── app_gateway.bicep     # Phase 6+
│   └── params/
│       └── dev.bicepparam
└── deploy.sh                 # up | down
```

- `infra/deploy.sh up` → `az deployment group create --resource-group
  rg-redwood-azure-dev --template-file infra/bicep/main.bicep --parameters
  infra/bicep/params/dev.bicepparam`. A `phase` parameter (or per-phase
  Bicep `module` toggle) controls which phases' modules are included, so a
  phase can be added without re-running everything blind.
- `infra/deploy.sh down` → `az group delete --name rg-redwood-azure-dev
  --yes`. Correct specifically because §2 keeps everything in one resource
  group — no per-resource teardown ordering to encode. Always run with
  explicit confirmation; this is a real, billable, destructive action, same
  posture as `hosted_agent/README.md`'s `azd up`/`azd deploy` note.
- The Foundry hosted-agent resources (via `azd`) have their own lifecycle
  (`azd down`) and are **not** deleted by `infra/deploy.sh down` — call out
  both commands when tearing down a full dev environment.

---

## 6. Risks / Open Items Carried Forward

| Risk | Effect on this plan |
|---|---|
| Microsoft Agent Framework / Foundry Agent Service has no Redwood production track record | Unaffected by this plan — it's Foundry-internal, outside the Bicep boundary (§1) |
| Azure AI Search / feature-store-spine composition is undesigned in code (source guide §3) | Phase 2's Redis (2.3) provisions the resource only; the composition code itself is a separate, unshipped dependency, same caveat as the source guide |
| Private networking deferred to Phase 4 | Do not point Phase 0–3 resources at real/customer-like data until Phase 4 is built — same gate `PHASE_1_POLICY_QA_AGENT.md` already states |
| `azd`/Bicep boundary is a manual seam | Phase 1 output values must be manually carried into `hosted_agent/`'s `.env` today; no automated hand-off between `infra/deploy.sh up` and `azd ai agent init` exists yet — acceptable at this scale, revisit if it becomes error-prone |

---

## 7. Explicitly Out of Scope

- Foundry hub/project/agent resources (owned by `azd`, §1)
- Entra ID app registrations (manual/Graph prerequisite, not a Bicep module)
- Life/Health Azure AI Search indices (no second LOB corpus exists yet, per source guide §7)
- Regulated/Restricted variant (Phase 7.3, gated behind an actual engagement decision)

---

## 8. Next Steps

1. Review this plan (this document).
2. On approval, implement **Phase 0 only** — resource group, Key Vault,
   managed identity — and validate `infra/deploy.sh up` / `down` end to end
   before writing a single module beyond it.
3. Add Phase 1 (Azure OpenAI + Azure AI Search) and re-point Phase 1's
   provisioning steps in `PHASE_1_POLICY_QA_AGENT.md` at
   `infra/deploy.sh up` instead of the current manual `az` commands.
4. Phases 2–7 are built only when the agent or feature that needs them is
   actually started — no phase is provisioned ahead of a concrete consumer,
   matching this repo's stated roadmap posture (`Readme.md` §Roadmap).
