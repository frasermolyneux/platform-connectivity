targetScope = 'resourceGroup'

// Parameters
param tags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'molyneux.dev'
  location: 'global'
  tags: tags

  properties: {
    zoneType: 'Public'
  }
}
