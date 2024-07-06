targetScope = 'resourceGroup'

// Parameters
param parDnsZoneName string
param parTags object

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: parDnsZoneName
  location: 'global'
  tags: parTags

  properties: {}
}
