// Phase 1.1 — Foundry account (Microsoft.CognitiveServices/accounts, kind
// AIServices) + chat/embedding model deployments. Under the GA unified model
// this one account IS "Azure OpenAI" (a capability of the account, not a
// sibling resource) — see docs/INFRA_DEPLOYMENT_PLAN.md §2/§4 for why the
// standalone "Azure OpenAI resource" originally sketched in Phase 1.1 was
// folded in here instead of provisioned separately.

@description('Foundry/AI Services account name. Microsoft.CognitiveServices/accounts only allows alphanumerics and hyphens, not underscores — naming-standard exception per docs/INFRA_DEPLOYMENT_PLAN.md §2.')
param foundry_account_name string

param location string
param tags object

@description('Chat model deployment name — must match AZURE_AI_MODEL_DEPLOYMENT_NAME in .env/example.env so the hosted agent finds it without a manual rename.')
param chat_model_deployment_name string

@description('Chat model name (OpenAI model catalog), e.g. gpt-4o.')
param chat_model_name string

@description('Chat model version. Leave empty to take the account\'s default version for chat_model_name.')
param chat_model_version string

@description('Embedding model deployment name — must match AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME in .env/example.env so search/ingest.py finds it without a manual rename.')
param embedding_model_deployment_name string

@description('Embedding model name (OpenAI model catalog), e.g. text-embedding-3-small.')
param embedding_model_name string

@description('Embedding model version. Leave empty to take the account\'s default version for embedding_model_name.')
param embedding_model_version string

@description('Deployment SKU for both model deployments. Verified against this subscription\'s actual quota in eastus2 (az cognitiveservices usage list) before writing this module: GlobalStandard has a 0 quota limit for gpt-4o here, while Standard has 50 — so Standard is the default, not the higher-throughput GlobalStandard tier some Microsoft samples default to. Confirm quota again with az cognitiveservices usage list --location <region> if changing region or model.')
param model_deployment_sku_name string = 'Standard'

@description('Deployment capacity (thousands of tokens/minute for Standard). Low dev-tier default — raise only if smoke-testing hits rate limits.')
param model_deployment_capacity int = 10

resource foundry_account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundry_account_name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Collapses hub+project+AI-Services+Key-Vault+Storage (pre-GA, 5
    // resources) into this one account + a child project (foundry_project.bicep)
    // — see docs/INFRA_DEPLOYMENT_PLAN.md §1's 2026-08-15 revision.
    allowProjectManagement: true
    customSubDomainName: foundry_account_name
    // No API keys anywhere in this repo's config (example.env's stated
    // posture) — Entra ID / managed identity only, enforced at the resource.
    // disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource chat_deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry_account
  name: chat_model_deployment_name
  sku: {
    name: model_deployment_sku_name
    capacity: model_deployment_capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chat_model_name
      version: empty(chat_model_version) ? null : chat_model_version
    }
  }
}

// Deployments on the same account provision serially in Azure OpenAI — an
// explicit dependsOn keeps this from racing chat_deployment even though
// Bicep can't infer the ordering from a shared `parent` alone.
resource embedding_deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry_account
  name: embedding_model_deployment_name
  sku: {
    name: model_deployment_sku_name
    capacity: model_deployment_capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embedding_model_name
      version: empty(embedding_model_version) ? null : embedding_model_version
    }
  }
  dependsOn: [
    chat_deployment
  ]
}

output foundry_account_name string = foundry_account.name
output foundry_account_resource_id string = foundry_account.id
@description('OpenAI-compatible endpoint — feeds AZURE_OPENAI_ENDPOINT.')
output azure_openai_endpoint string = foundry_account.properties.endpoint
@description('Account-level Foundry endpoint — the project endpoint (AZURE_AI_PROJECT_ENDPOINT) is the project-scoped variant, surfaced by foundry_project.bicep instead.')
output foundry_account_endpoint string = foundry_account.properties.endpoint
output chat_model_deployment_name string = chat_deployment.name
output embedding_model_deployment_name string = embedding_deployment.name
