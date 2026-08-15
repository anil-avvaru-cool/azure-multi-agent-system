// Phase 1.3 — Azure AI Search service, host for the `auto_policy_documents`
// index. Index creation/population itself stays a manual step
// (`uv run python -m search.ingest`, per docs/PHASE_1_POLICY_QA_AGENT.md) —
// this module only provisions the service.

@description('Search service name. Microsoft.Search/searchServices only allows lowercase alphanumerics and hyphens, not underscores — naming-standard exception per docs/INFRA_DEPLOYMENT_PLAN.md §2.')
param search_service_name string

param location string
param tags object

@description('free (shared, one per subscription per tenant — deployment fails with a clear quota error if this subscription already has one elsewhere) or basic (dedicated, up to 3 replicas). Dev-tier default per docs/INFRA_DEPLOYMENT_PLAN.md §4\'s Phase 1.3 cost tier. Switch to basic in params/dev.bicepparam if a free-tier service already exists in this subscription.')
@allowed([
  'free'
  'basic'
])
param sku_name string = 'free'

resource search_service 'Microsoft.Search/searchServices@2025-05-01' = {
  name: search_service_name
  location: location
  tags: tags
  sku: {
    name: sku_name
  }
  properties: {
    // No API keys anywhere in this repo's config (example.env's stated
    // posture) — Entra ID / managed identity only, enforced at the resource.
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    // replicaCount/partitionCount intentionally omitted — default to 1/1,
    // the only values the free tier supports and a sane dev default for basic.
  }
}

output search_service_name string = search_service.name
output search_service_resource_id string = search_service.id
@description('Feeds AZURE_SEARCH_ENDPOINT — reached directly by AzureAISearchContextProvider, no Foundry connection resource required.')
output azure_search_endpoint string = 'https://${search_service.name}.search.windows.net'
