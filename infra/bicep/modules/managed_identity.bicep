@description('User-assigned managed identity name. Microsoft.ManagedIdentity/userAssignedIdentities allows underscores, so this follows the repo naming standard (underscores only) rather than needing the hyphen exception.')
param managed_identity_name string

param location string
param tags object

resource managed_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managed_identity_name
  location: location
  tags: tags
}

output managed_identity_name string = managed_identity.name
output managed_identity_resource_id string = managed_identity.id
output managed_identity_principal_id string = managed_identity.properties.principalId
output managed_identity_client_id string = managed_identity.properties.clientId
