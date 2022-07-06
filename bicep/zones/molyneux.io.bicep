targetScope = 'resourceGroup'

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'molyneux.io'
  location: 'global'

  properties: {
    zoneType: 'Public'
  }
}
