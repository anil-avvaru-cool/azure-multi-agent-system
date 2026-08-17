using '../main.bicep'

param environment_name = 'dev'
//param location = 'eastus2'
//param location = 'northcentralus'
param location = 'westus3'
param resource_group_name = 'rg-redwood-azure-dev'

// Key Vault names are globally unique across all of Azure (DNS-scoped
// namespace, not just this subscription/tenant). If deployment fails with
// a "vault name already taken" error, change this value.
//param key_vault_name = 'kv-redwood-azure-dev'

// Define the base name
param base_key_vault_name = 'kv-rw-d'

param managed_identity_name = 'id-rw-d'

param deploy_phase_0 = true

// Foundry account name is also a global DNS-scoped namespace
// (customSubDomainName resolves under *.services.ai.azure.com /
// *.openai.azure.com) — change if deployment fails with "already taken".
param base_foundry_account_name = 'aif-rw-d'

// Must match AZURE_AI_MODEL_DEPLOYMENT_NAME / AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME
// in .env once Phase 1 replaces the manual provisioning steps in
// docs/PHASE_1_POLICY_QA_AGENT.md (see docs/INFRA_DEPLOYMENT_PLAN.md §4 Next Steps).
param chat_model_deployment_name = 'gpt-4o'
param chat_model_name = 'gpt-4o'
param chat_model_version = ''

param embedding_model_deployment_name = 'text-embedding-3-small'
//param embedding_model_name = 'text-embedding-3-small'
param embedding_model_name = 'text-embedding-ada-002'
param embedding_model_version = ''

param foundry_project_name = 'policy_qa_project'

// Search service name is also a global DNS-scoped namespace
// (*.search.windows.net) — change if deployment fails with "already taken".
param search_service_name = 'srch-redwood-azure-dev'

// Free tier is one per subscription per region — if this subscription
// already has one, change to 'basic' here (see modules/ai_search.bicep).
param search_sku_name = 'free'

param deploy_phase_1 = true
