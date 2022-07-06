targetScope = 'resourceGroup'

// Parameters
param parTags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'molyneux.dev'
  location: 'global'
  tags: parTags

  properties: {
    zoneType: 'Public'
  }
}
