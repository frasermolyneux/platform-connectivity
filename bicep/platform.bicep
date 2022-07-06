targetScope = 'subscription'

// Parameters
param parLocation string
param parEnvironment string
param parTags object

// Variables
var varResourceGroupName = 'rg-dns-${parEnvironment}-${parLocation}'

// Platform
resource defaultResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varResourceGroupName
  location: parLocation
  tags: parTags

  properties: {}
}

// DNS Zones
module molyneuxDev 'zones/molyneux.dev.bicep' = {
  name: 'molyneuxDev'
  scope: resourceGroup(defaultResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module molyneuxIO 'zones/molyneux.io.bicep' = {
  name: 'molyneuxIo'
  scope: resourceGroup(defaultResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsCom 'zones/xtremeidiots.com.bicep' = {
  name: 'xtremeidiotsCom'
  scope: resourceGroup(defaultResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsDev 'zones/xtremeidiots.dev.bicep' = {
  name: 'xtremeidiotsDev'
  scope: resourceGroup(defaultResourceGroup.name)

  params: {
    parTags: parTags
  }
}
