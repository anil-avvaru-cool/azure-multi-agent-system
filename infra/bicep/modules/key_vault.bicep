@description('Key Vault name. Microsoft.KeyVault/vaults only allows alphanumerics and hyphens, not underscores — naming-standard exception per docs/INFRA_DEPLOYMENT_PLAN.md §2/§4.')
param key_vault_name string

param location string
param tags object

@description('Vault name is a global DNS-scoped namespace across all of Azure, not just this subscription — deployment fails fast with a clear "already taken" error if key_vault_name collides with another tenant\'s vault. Pick a new name in params/dev.bicepparam if that happens.')
resource key_vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: key_vault_name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    // Purge protection intentionally off: this is a dev/portfolio resource
    // torn down and rebuilt via infra/deploy.sh down/up, and purge
    // protection would strand the name for the retention window after
    // every teardown.
    // Commented enablePurgeProtection to disable and avoid validation error.
    //enablePurgeProtection: null
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output key_vault_name string = key_vault.name
output key_vault_uri string = key_vault.properties.vaultUri
output key_vault_resource_id string = key_vault.id
