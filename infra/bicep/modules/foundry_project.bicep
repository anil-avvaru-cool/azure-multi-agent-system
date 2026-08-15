// Phase 1.2 — Foundry project, a child `accounts/projects` resource under
// the Phase 1.1 account. Provisioned ahead of time so `azd ai agent init -p
// <project-resource-id>` targets this project instead of creating its own —
// see docs/INFRA_DEPLOYMENT_PLAN.md §4/§6. The `-p` targeting behavior is
// NOT yet verified against this repo's installed azd/microsoft.foundry
// extension version — confirm before pointing hosted_agent/README.md at it.

@description('Foundry account name (Phase 1.1) this project is a child of.')
param foundry_account_name string

@description('Foundry project name. accounts/projects allows underscores (pattern ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$) — no naming-standard exception needed here, unlike the account itself.')
param foundry_project_name string

param location string
param tags object

resource foundry_account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundry_account_name
}

resource foundry_project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry_account
  name: foundry_project_name
  location: location
  tags: tags
  properties: {
    displayName: foundry_project_name
    description: 'azure-multi-agent-system — policy_qa_agent runtime project'
  }
}

output foundry_project_name string = foundry_project.name
output foundry_project_resource_id string = foundry_project.id
@description('Project-scoped Foundry endpoint — feeds AZURE_AI_PROJECT_ENDPOINT.')
output azure_ai_project_endpoint string = '${foundry_account.properties.endpoint}api/projects/${foundry_project.name}'
