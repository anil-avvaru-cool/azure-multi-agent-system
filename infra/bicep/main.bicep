// infra/bicep/main.bicep — orchestrates modules for whichever phases are
// enabled. See docs/INFRA_DEPLOYMENT_PLAN.md for the phased build order and
// design rationale.
//
// Subscription-scope deployment: Phase 0.1 is "create the resource group",
// which `az deployment group create` cannot do — that command requires the
// target resource group to already exist. This template creates the RG
// itself and scopes every module into it, deployed with `az deployment sub
// create` (see infra/deploy.sh). This is a correction to the plan doc's
// originally-sketched `az deployment group create` command contract.

targetScope = 'subscription'

@description('Environment name, used in resource names and the environment tag.')
param environment_name string

@description('Azure region. Pick one with Azure AI Foundry + Azure AI Search + Azure OpenAI model availability — later phases provision those in this same region.')
param location string

@description('Resource group name — single RG for the whole dev environment, per docs/INFRA_DEPLOYMENT_PLAN.md §2/§3.')
param resource_group_name string

@description('Key Vault name (Phase 0.2). Globally unique across Azure — see modules/key_vault.bicep.')
param key_vault_name string

@description('Base Key Vault name (Phase 0.2). Globally unique across Azure — see modules/key_vault.bicep.')
param base_key_vault_name string

@description('User-assigned managed identity name (Phase 0.3).')
param managed_identity_name string

@description('Toggle for Phase 0 (resource group tags + Key Vault + managed identity). The resource group itself is always created, since every later phase depends on it too.')
param deploy_phase_0 bool = true

@description('Foundry/AI Services account name (Phase 1.1). Microsoft.CognitiveServices/accounts only allows alphanumerics and hyphens — see modules/foundry_account.bicep.')
param foundry_account_name string

@description('Base Foundry/AI Services account name (Phase 1.1). Microsoft.CognitiveServices/accounts only allows alphanumerics and hyphens — see modules/foundry_account.bicep.')
param base_foundry_account_name string

@description('Chat model deployment name (Phase 1.1) — must match AZURE_AI_MODEL_DEPLOYMENT_NAME.')
param chat_model_deployment_name string

@description('Chat model name from the OpenAI model catalog, e.g. gpt-4o.')
param chat_model_name string

@description('Chat model version. Empty string takes the account default.')
param chat_model_version string

@description('Embedding model deployment name (Phase 1.1) — must match AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME.')
param embedding_model_deployment_name string

@description('Embedding model name from the OpenAI model catalog, e.g. text-embedding-3-small.')
param embedding_model_name string

@description('Embedding model version. Empty string takes the account default.')
param embedding_model_version string

@description('Foundry project name (Phase 1.2, child of the account).')
param foundry_project_name string

@description('Azure AI Search service name (Phase 1.3). Microsoft.Search/searchServices only allows lowercase alphanumerics and hyphens — see modules/ai_search.bicep.')
param search_service_name string

@description('Azure AI Search SKU (Phase 1.3) — free or basic, dev-tier only. See modules/ai_search.bicep.')
param search_sku_name string = 'free'

@description('Toggle for Phase 1 (Foundry account + model deployments, Foundry project, Azure AI Search, RBAC). Depends on Phase 0 (Key Vault, managed identity) being deployed first.')
param deploy_phase_1 bool = true

@description('Toggle for the Foundry project module specifically (Phase 1.2), separate from deploy_phase_1. The Cognitive Services RP takes a few seconds to internally propagate the account\'s system-assigned identity after account creation returns Succeeded — creating the project in the same deployment as the account can race that propagation and fail with "you must enable a managed identity on your resource" even though the identity is present (verified live: docs/INFRA_DEPLOYMENT_PLAN.md §6). infra/deploy.sh deploys the account first with this set to false, then retries the project deployment separately. Leave true for a single-shot deploy where the account already exists from a prior run.')
param deploy_foundry_project bool = true

var tags = {
  project: 'redwood-ai-insurance'
  component: 'azure-multi-agent-system'
  environment: environment_name
  'managed-by': 'bicep'
}

resource resource_group 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resource_group_name
  location: location
  tags: tags
}

module key_vault 'modules/key_vault.bicep' = if (deploy_phase_0) {
  name: 'phase0-key-vault'
  scope: resource_group
  params: {
    key_vault_name: key_vault_name
    location: location
    tags: tags    
  }
}

module managed_identity 'modules/managed_identity.bicep' = if (deploy_phase_0) {
  name: 'phase0-managed-identity'
  scope: resource_group
  params: {
    managed_identity_name: managed_identity_name
    location: location
    tags: tags
  }
}

// Phase 1 depends on Phase 0's Key Vault + managed identity (docs/INFRA_DEPLOYMENT_PLAN.md
// §4's Phase 1 "Depends on" column) — guard on both toggles, not just deploy_phase_1,
// so enabling Phase 1 without Phase 0 fails at param-validation time instead of
// deploying half-wired resources.
var deploy_phase_1_resolved = deploy_phase_1 && deploy_phase_0

module foundry_account 'modules/foundry_account.bicep' = if (deploy_phase_1_resolved) {
  name: 'phase1-foundry-account'
  scope: resource_group
  params: {
    foundry_account_name: foundry_account_name
    location: location
    tags: tags
    chat_model_deployment_name: chat_model_deployment_name
    chat_model_name: chat_model_name
    chat_model_version: chat_model_version
    embedding_model_deployment_name: embedding_model_deployment_name
    embedding_model_name: embedding_model_name
    embedding_model_version: embedding_model_version
  }
}

module foundry_project 'modules/foundry_project.bicep' = if (deploy_phase_1_resolved && deploy_foundry_project) {
  name: 'phase1-foundry-project'
  scope: resource_group
  params: {
    foundry_account_name: foundry_account_name
    foundry_project_name: foundry_project_name
    location: location
    tags: tags
  }
  dependsOn: [
    foundry_account
  ]
}

module ai_search 'modules/ai_search.bicep' = if (deploy_phase_1_resolved) {
  name: 'phase1-ai-search'
  scope: resource_group
  params: {
    search_service_name: search_service_name
    location: location
    tags: tags
    sku_name: search_sku_name
  }
}

module rbac 'modules/rbac.bicep' = if (deploy_phase_1_resolved) {
  name: 'phase1-rbac'
  scope: resource_group
  params: {
    managed_identity_principal_id: managed_identity.outputs.managed_identity_principal_id
    key_vault_name: key_vault_name
    search_service_name: search_service_name
    foundry_account_name: foundry_account_name
  }
  dependsOn: [
    foundry_account
    ai_search
  ]
}

output resource_group_name string = resource_group.name
output key_vault_name string = deploy_phase_0 ? key_vault.outputs.key_vault_name : ''
output key_vault_uri string = deploy_phase_0 ? key_vault.outputs.key_vault_uri : ''
output managed_identity_name string = deploy_phase_0 ? managed_identity.outputs.managed_identity_name : ''
output managed_identity_client_id string = deploy_phase_0 ? managed_identity.outputs.managed_identity_client_id : ''
output managed_identity_principal_id string = deploy_phase_0 ? managed_identity.outputs.managed_identity_principal_id : ''
output foundry_account_name string = deploy_phase_1_resolved ? foundry_account.outputs.foundry_account_name : ''
output azure_openai_endpoint string = deploy_phase_1_resolved ? foundry_account.outputs.azure_openai_endpoint : ''
output chat_model_deployment_name string = deploy_phase_1_resolved ? foundry_account.outputs.chat_model_deployment_name : ''
output embedding_model_deployment_name string = deploy_phase_1_resolved ? foundry_account.outputs.embedding_model_deployment_name : ''
output foundry_project_resource_id string = (deploy_phase_1_resolved && deploy_foundry_project) ? foundry_project.outputs.foundry_project_resource_id : ''
output azure_ai_project_endpoint string = (deploy_phase_1_resolved && deploy_foundry_project) ? foundry_project.outputs.azure_ai_project_endpoint : ''
output search_service_name string = deploy_phase_1_resolved ? ai_search.outputs.search_service_name : ''
output azure_search_endpoint string = deploy_phase_1_resolved ? ai_search.outputs.azure_search_endpoint : ''
