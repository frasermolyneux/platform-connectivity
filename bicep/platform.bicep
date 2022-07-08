targetScope = 'subscription'

// Parameters
param parLocation string
param parEnvironment string
param parTags object

// Variables
var varDnsResourceGroupName = 'rg-dns-${parEnvironment}-${parLocation}'
var varFrontDoorResourceGroupName = 'rg-frontdoor-${parEnvironment}-${parLocation}'

// Platform
resource dnsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varDnsResourceGroupName
  location: parLocation
  tags: parTags

  properties: {}
}

resource frontDoorResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varFrontDoorResourceGroupName
  location: parLocation
  tags: parTags

  properties: {}
}

// DNS Zones
module molyneuxDev 'zones/molyneux.dev.bicep' = {
  name: 'molyneuxDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module molyneuxIO 'zones/molyneux.io.bicep' = {
  name: 'molyneuxIo'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsCom 'zones/xtremeidiots.com.bicep' = {
  name: 'xtremeidiotsCom'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsDev 'zones/xtremeidiots.dev.bicep' = {
  name: 'xtremeidiotsDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module geolocationNet 'zones/geo-location.net.bicep' = {
  name: 'geolocationNet'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}
