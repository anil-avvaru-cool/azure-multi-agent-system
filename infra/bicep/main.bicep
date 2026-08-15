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

@description('User-assigned managed identity name (Phase 0.3).')
param managed_identity_name string

@description('Toggle for Phase 0 (resource group tags + Key Vault + managed identity). The resource group itself is always created, since every later phase depends on it too.')
param deploy_phase_0 bool = true

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

output resource_group_name string = resource_group.name
output key_vault_name string = deploy_phase_0 ? key_vault.outputs.key_vault_name : ''
output key_vault_uri string = deploy_phase_0 ? key_vault.outputs.key_vault_uri : ''
output managed_identity_name string = deploy_phase_0 ? managed_identity.outputs.managed_identity_name : ''
output managed_identity_client_id string = deploy_phase_0 ? managed_identity.outputs.managed_identity_client_id : ''
output managed_identity_principal_id string = deploy_phase_0 ? managed_identity.outputs.managed_identity_principal_id : ''
