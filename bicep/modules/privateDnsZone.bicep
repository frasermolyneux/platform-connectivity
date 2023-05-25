targetScope = 'resourceGroup'

// Parameters
param parDnsZoneName string
param parTags object
param parLocation string = resourceGroup().location

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: parDnsZoneName
  location: parLocation
  tags: parTags

  properties: {}
}
