// Phase 1.4 — RBAC role assignments wiring the Phase 0.3 managed identity to
// the Phase 1.1/1.3 resources it needs to reach at runtime. Entra ID
// throughout, no API keys (example.env's stated posture, enforced by
// disableLocalAuth on both the Foundry account and the Search service).
//
// Roles are least-privilege for what the hosted agent actually does at
// runtime (query Search, read Key Vault secrets, call the chat/embedding
// deployments) — not the broader admin-capable roles a human operator would
// use for `search/ingest.py` or Key Vault administration, which run under
// the operator's own `az login` credential instead.

@description('Principal ID of the Phase 0.3 user-assigned managed identity being granted access.')
param managed_identity_principal_id string

param key_vault_name string
param search_service_name string
param foundry_account_name string

resource key_vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: key_vault_name
}

resource search_service 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: search_service_name
}

resource foundry_account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundry_account_name
}

var key_vault_secrets_user_role_id = '4633458b-17de-408a-b874-0445c86b69e6'
var search_index_data_reader_role_id = '1407120a-92aa-4202-b7e9-c0e197c71c8f'
var cognitive_services_openai_user_role_id = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource key_vault_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(key_vault.id, managed_identity_principal_id, key_vault_secrets_user_role_id)
  scope: key_vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', key_vault_secrets_user_role_id)
    principalId: managed_identity_principal_id
    principalType: 'ServicePrincipal'
  }
}

resource search_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search_service.id, managed_identity_principal_id, search_index_data_reader_role_id)
  scope: search_service
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', search_index_data_reader_role_id)
    principalId: managed_identity_principal_id
    principalType: 'ServicePrincipal'
  }
}

resource foundry_account_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry_account.id, managed_identity_principal_id, cognitive_services_openai_user_role_id)
  scope: foundry_account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitive_services_openai_user_role_id)
    principalId: managed_identity_principal_id
    principalType: 'ServicePrincipal'
  }
}
