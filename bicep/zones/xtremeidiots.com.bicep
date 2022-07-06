targetScope = 'resourceGroup'

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'xtremeidiots.com'
  location: 'global'

  properties: {
    zoneType: 'Public'
  }
}
