targetScope = 'subscription'

// Parameters
param parLocation string
param parEnvironment string
param parTags object

// Variables
var varDnsResourceGroupName = 'rg-platform-dns-${parEnvironment}-${parLocation}'
var varFrontDoorResourceGroupName = 'rg-platform-frontdoor-${parEnvironment}-${parLocation}'
var varFrontDoorName = 'fd-mx-platform-${parEnvironment}'

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

module frontDoor 'platform/frontDoor.bicep' = {
  name: 'frontDoor'
  scope: resourceGroup(frontDoorResourceGroup.name)

  params: {
    parFrontDoorName: varFrontDoorName
    parTags: parTags
  }
}

// DNS Zones
module molyneuxConsultingCoUk 'zones/molyneux-consulting.co.uk.bicep' = {
  name: 'molyneuxConsultingCoUk'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

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

module mxConsultingCoUk 'zones/mx-consulting.co.uk.bicep' = {
  name: 'mxConsultingCoUk'
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
