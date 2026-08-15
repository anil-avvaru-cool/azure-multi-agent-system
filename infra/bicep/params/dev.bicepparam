using '../main.bicep'

param environment_name = 'dev'
param location = 'eastus2'
param resource_group_name = 'rg-redwood-azure-dev'

// Key Vault names are globally unique across all of Azure (DNS-scoped
// namespace, not just this subscription/tenant). If deployment fails with
// a "vault name already taken" error, change this value.
param key_vault_name = 'kv-redwood-azure-dev'

param managed_identity_name = 'id_redwood_azure_dev'

param deploy_phase_0 = true
