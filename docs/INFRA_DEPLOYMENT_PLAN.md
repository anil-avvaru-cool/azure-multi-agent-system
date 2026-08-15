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

- **The hosted-agent runtime deployment** (`hosted_agent/`'s `azd up` /
  `azd deploy` step) — packaging `policy_qa_agent` as a container image,
  pushing to ACR, and Agent Service provisioning compute, a dedicated
  managed identity, and an endpoint for it. This is not an ARM/Bicep
  operation: Foundry hosted agents (Agents v2) are not ARM resources, so
  there is no Bicep resource type for "the agent" itself, and this plan does
  not attempt to hand-author it. `hosted_agent/README.md` covers this step.

  *(Revised 2026-08-15 — narrower than originally scoped. This plan
  previously excluded the Foundry hub/project itself too, on the grounds
  that hand-writing it risked drifting from whatever the installed
  `azd`/`microsoft.foundry` extension version expected. That's no longer the
  strongest argument: the GA `Microsoft.CognitiveServices/accounts` API
  (`allowProjectManagement: true`) with a child `accounts/projects` resource
  collapsed the old hub+workspace model — hub, project, AI Services, Key
  Vault, Storage (5 resources) — down to 2, and `azd ai agent init -p
  <project-resource-id>` accepts an existing project rather than requiring
  `azd` to create one. So the Foundry account + project moves into this
  plan's scope as Phase 1.1–1.2 (§4); only the hosted-agent runtime above
  stays on `azd`, and for a structural reason — it isn't an ARM resource —
  not a drift-avoidance one.)*

  *(Revised again 2026-08-15 — the standalone "Azure OpenAI resource" that
  used to be 1.1 is now folded into the Foundry account itself. Under the
  unified GA model, Azure OpenAI is a capability of
  `Microsoft.CognitiveServices/accounts`, not a separate resource type —
  provisioning a second `accounts` resource for "Azure OpenAI" next to the
  Foundry account would just recreate the pre-GA hub/workspace split this
  revision was meant to eliminate. One account, one set of chat/embedding
  deployments, one child project. See 1.1 in the table below.)*
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
| **Bicep takes over Phase 1's manual `az`/`azd` steps 1–4** (RG, Azure OpenAI, Azure AI Search, Foundry account+project) — `azd` keeps only step 5 (hosted-agent build/push/deploy) | Codifies what's currently four manual, undocumented-as-code provisioning steps in `PHASE_1_POLICY_QA_AGENT.md` §Provisioning order. Narrower hand-off to `azd` than originally planned — see §1's 2026-08-15 revision — since only the hosted-agent runtime itself has a structural reason (not an ARM resource) to stay generated. |
| **Foundry account + project provisioned by Bicep, `azd` targets it via `-p`** | GA API versions (`2025-06-01`+) collapsed the hub/project resource model from 5 resources to 2, removing the version-drift risk that originally justified deferring the whole Foundry boundary to `azd` (§1). `azd ai agent init -p <project-resource-id>` accepts an existing project, so `azd` provisions the hosted-agent runtime against Bicep-owned infra instead of creating its own project — narrows the manual seam in §6 to just that one hand-off. |
| **Azure OpenAI merges into the Foundry account (1.1)** | Under the GA unified model, Azure OpenAI is a capability of `Microsoft.CognitiveServices/accounts`, not its own resource type — a separate "Azure OpenAI resource" next to the Foundry account would just re-split what the unified model merged. One account (chat + embedding deployments) with a child project, instead of two sibling accounts. User-confirmed 2026-08-15 (previously left open in §6). |
| **Naming: underscores where Azure allows, hyphens where it doesn't** | Per repo standard (`CLAUDE.md`) and the source guide's own Phase 0.1 note — Azure forces hyphens/lowercase on some resource types (Storage, AKS, Key Vault, PostgreSQL Flexible Server). Document each exception at the module, don't fight the platform. |

---

## 3. Resource Group

| | |
|---|---|
| Name | `rg-redwood-azure-dev` |
| Region | Single region to start (no multi-region — not needed at this scale); pick the region with Azure AI Foundry + Azure AI Search + Azure OpenAI model availability |
| Tags | `project=redwood-ai-insurance`, `component=azure-multi-agent-system`, `environment=dev`, `managed-by=bicep` (except the hosted-agent runtime's resources — ACR, App Insights, the agent's own managed identity/compute/endpoint — created by `azd` and tagged `managed-by=azd`; the Foundry account (with its model deployments) and project themselves are `managed-by=bicep` as of 1.1/1.2) |

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

### Phase 1 — AI Services Core *(Core — replaces Phase 1's manual `az`/`azd` steps 1–4)*

| # | Resource | Purpose | Cost | Depends on |
|---|---|---|---|---|
| 1.1 | Foundry account (`Microsoft.CognitiveServices/accounts`, kind `AIServices`, `allowProjectManagement: true`) + chat + embedding model deployments | Unified AI Services/Azure OpenAI resource — LLM inference + `search/ingest.py` embeddings, currently a manual step in `PHASE_1_POLICY_QA_AGENT.md`. Replaces what was a standalone "Azure OpenAI resource" — merged in per §2, since Azure OpenAI is a capability of this resource type under the GA model, not a sibling resource. | $$ | 0.1, 0.2 |
| 1.2 | Foundry project (child `accounts/projects` resource) | Provisioned ahead of time so `azd ai agent init -p <project-resource-id>` targets it instead of creating its own — closes the drift gap that originally kept the whole Foundry boundary on `azd` (§1) | $ (consumption-based, no idle charge) | 1.1, 0.3 |
| 1.3 | Azure AI Search service (Free or Basic tier) | `auto_policy_documents` index host — currently a manual step | $ (Free tier) | 0.1, 1.1 |
| 1.4 | RBAC role assignments (Search → managed identity, Key Vault → managed identity, Foundry account → managed identity for `Cognitive Services OpenAI User`) | Entra ID auth throughout, no API keys, matching `example.env`'s stated posture | $ | 0.2, 0.3, 1.1, 1.3 |

**Boundary with `azd`:** Phase 1 output — Search endpoint, the Foundry
account's OpenAI-compatible endpoint, and the Foundry project resource ID
from 1.2 — feeds `hosted_agent/`'s `azd ai agent init -p
<project-resource-id>` / `azd up`. This plan provisions the account and
project themselves; `azd` does only what it structurally must — build/push
the container image and let Agent Service provision the hosted-agent
runtime (compute, dedicated identity, endpoint), none of which is an ARM
resource. See §1 for why this boundary narrowed from "Foundry project" to
"hosted-agent runtime only." **Not yet verified end-to-end** against this
repo's installed `azd`/`microsoft.foundry` extension version — confirm the
`-p` flag's behavior when implementing 1.2, before relying on it (§6).

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
│   │   ├── foundry_account.bicep # Phase 1.1 — account + model deployments
│   │   ├── foundry_project.bicep # Phase 1.2 — child project resource
│   │   ├── ai_search.bicep       # Phase 1.3
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

- `infra/deploy.sh up` → `az deployment sub create --location eastus2
  --template-file infra/bicep/main.bicep --parameters
  infra/bicep/params/dev.bicepparam`. **Corrected from an earlier
  resource-group-scope sketch** (`az deployment group create --resource-group
  rg-redwood-azure-dev ...`) — that command requires the target resource
  group to already exist, which is circular for Phase 0.1 ("create the
  resource group"). `main.bicep` now has `targetScope = 'subscription'`,
  creates the resource group itself, and scopes every module into it —
  see its header comment. A per-phase Bicep `module` toggle (`deploy_phase_0`,
  implemented; later phases add their own) controls which phases' modules
  are included, so a phase can be added without re-running everything blind.
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
| `azd`/Bicep boundary is a manual seam, narrowed but not closed by 1.1–1.2 | Before this revision: all of Phase 1's output values had to be manually carried into `hosted_agent/`'s `.env`. Now: only passing the Foundry project's resource ID into `azd ai agent init -p <project-resource-id>` remains manual, plus any Search/OpenAI values not already resolvable from the project's own connections. Acceptable at this scale; revisit if it becomes error-prone. |
| `-p <project-resource-id>` behavior unverified against this repo's `azd` version | 1.2's design depends on `azd ai agent init` correctly targeting a pre-existing Foundry project instead of creating one. Confirm this against the currently installed `azd`/`microsoft.foundry` extension version as part of implementing 1.2 — the whole point of moving the project to Bicep is defeated if `azd` silently creates a second project anyway. |
| Merged account (1.1) widens the blast radius of a single resource | Before the merge, "Azure OpenAI" and "Foundry account" would have been two separate resources — deleting/recreating one for any reason wouldn't touch the other. Merged, a change to 1.1 (e.g. a bad model-deployment update) risks the one account that the project (1.2) and Search RBAC (1.4) both depend on. Acceptable at this scale (single dev RG, single agent) — revisit if a second agent's blast-radius needs diverge from `policy_qa_agent`'s. |
| **Foundry account → project creation race (found live, 2026-08-15)** | First `infra/deploy.sh up` run: `phase1-foundry-account` succeeded, `phase1-foundry-project` failed 1.3s later with `BadRequest: "Unsupported configuration. To create projects, you must enable a managed identity on your resource."` — despite the account's `identity.type: SystemAssigned` and a valid `identity.principalId` being confirmed present via `az cognitiveservices account show` immediately after. Root cause: the Cognitive Services RP propagates the account's identity into its internal project-creation validation path asynchronously, a few seconds *after* the account's ARM PUT already reports `Succeeded` — no documented SLA, no readiness attribute to poll (principalId was already populated when the race still hit, so it isn't a valid readiness signal either). Bicep's `dependsOn` (already present, `main.bicep`) only sequences the two ARM PUT calls; it can't see or wait on that internal RP step. **Fix**: `main.bicep` gained a `deploy_foundry_project` toggle (default `true`) so the project module can be excluded from a deployment; `infra/deploy.sh up` now deploys in two stages — stage 1 with `deploy_foundry_project=false` (account + search + RBAC), then stage 2 retries the full deployment (project included) up to 6 times with a 10s delay, matching only on this specific error text so unrelated failures still fail fast. Retrying the actual operation, not sleeping a guessed duration or polling a proxy attribute, per this repo's root-cause-over-workarounds posture (`CLAUDE.md`). |

---

## 7. Explicitly Out of Scope

- Hosted-agent runtime deployment (container build/push + Agent Service compute/identity/endpoint provisioning — owned by `azd`, §1). The Foundry account (merged with what was a standalone Azure OpenAI resource) and project themselves are now in scope — see Phase 1.1–1.2 (§4).
- Entra ID app registrations (manual/Graph prerequisite, not a Bicep module)
- Life/Health Azure AI Search indices (no second LOB corpus exists yet, per source guide §7)
- Regulated/Restricted variant (Phase 7.3, gated behind an actual engagement decision)

---

## 8. Next Steps

1. Review this plan (this document).
2. On approval, implement **Phase 0 only** — resource group, Key Vault,
   managed identity — and validate `infra/deploy.sh up` / `down` end to end
   before writing a single module beyond it. **Code written 2026-08-15**
   (`infra/bicep/main.bicep`, `modules/key_vault.bicep`,
   `modules/managed_identity.bicep`, `params/dev.bicepparam`,
   `infra/deploy.sh`) and compiles cleanly (`az bicep build`). **Not yet
   run against a live subscription** — `infra/deploy.sh up`/`down` end-to-end
   validation is still outstanding; do that before starting Phase 1.
3. Add Phase 1 (Foundry account + model deployments, Foundry project, Azure
   AI Search, RBAC — 1.1–1.4) and re-point Phase 1's provisioning steps in
   `PHASE_1_POLICY_QA_AGENT.md` at `infra/deploy.sh up` instead of the
   current manual `az` commands. **Code written 2026-08-15**
   (`infra/bicep/modules/foundry_account.bicep`, `foundry_project.bicep`,
   `ai_search.bicep`, `rbac.bicep`, wired into `main.bicep` behind
   `deploy_phase_1`) and compiles cleanly (`az bicep build` /
   `build-params` against `params/dev.bicepparam`, only BCP081
   "type cache" warnings from this box's Bicep CLI version — not errors).
   `PHASE_1_POLICY_QA_AGENT.md` §Provisioning order updated to point at
   `infra/deploy.sh up` for steps 1–3. **Not yet run against a live
   subscription** — validate `infra/deploy.sh up`/`down` end to end before
   moving on to 1.2's `azd` hand-off (next item) or a real agent smoke test.
   One live-subscription finding folded into `modules/foundry_account.bicep`
   already: `az cognitiveservices usage list --location eastus2` against
   this repo's actual subscription showed `OpenAI.GlobalStandard.gpt-4o` at
   0 quota (vs. 50 for `OpenAI.Standard.gpt-4o`) — the module defaults both
   model deployments to the `Standard` SKU, not the `GlobalStandard` several
   Microsoft samples default to. Re-check quota with the same command before
   changing region or model.
4. When implementing 1.2, verify `azd ai agent init -p
   <project-resource-id>` actually targets the Bicep-provisioned project
   against this repo's installed `azd`/`microsoft.foundry` extension version
   before updating `hosted_agent/README.md`'s provisioning step 4 to use it
   (§6). **Still outstanding** — blocked on 1.2 having actually run against
   a live subscription first (previous item).
5. Phases 2–7 are built only when the agent or feature that needs them is
   actually started — no phase is provisioned ahead of a concrete consumer,
   matching this repo's stated roadmap posture (`Readme.md` §Roadmap).
