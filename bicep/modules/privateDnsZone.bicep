targetScope = 'resourceGroup'

// Parameters
param dnsZoneName string
param tags object

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags

  properties: {}
}
