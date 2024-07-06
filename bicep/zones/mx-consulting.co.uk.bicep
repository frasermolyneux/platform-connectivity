targetScope = 'resourceGroup'

// Parameters
param tags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'mx-consulting.co.uk'
  location: 'global'
  tags: tags

  properties: {
    zoneType: 'Public'
  }
}
