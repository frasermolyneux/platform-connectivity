targetScope = 'subscription'

// Parameters
param parLocation string
param parEnvironment string
param parTags object

// Variables
var varDeploymentPrefix = 'platformConnectivity' //Prevent deployment naming conflicts
var varDnsResourceGroupName = 'rg-platform-dns-${uniqueString(subscription().id)}-${parEnvironment}-${parLocation}'
var varFrontDoorResourceGroupName = 'rg-platform-${uniqueString(subscription().id)}-frontdoor-${parEnvironment}-${parLocation}'
var varFrontDoorName = 'fd-platform-${uniqueString(subscription().id)}-${parEnvironment}'

// Platform
resource dnsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = if (parEnvironment == 'prd') {
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
  name: '${varDeploymentPrefix}-frontDoor'
  scope: resourceGroup(frontDoorResourceGroup.name)

  params: {
    parFrontDoorName: varFrontDoorName
    parTags: parTags
  }
}

// DNS Zones
module molyneuxConsultingCoUk 'zones/molyneux-consulting.co.uk.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxConsultingCoUk'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module molyneuxDev 'zones/molyneux.dev.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module molyneuxIO 'zones/molyneux.io.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxIo'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module mxConsultingCoUk 'zones/mx-consulting.co.uk.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-mxConsultingCoUk'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsCom 'zones/xtremeidiots.com.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-xtremeidiotsCom'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module xtremeidiotsDev 'zones/xtremeidiots.dev.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-xtremeidiotsDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}

module geolocationNet 'zones/geo-location.net.bicep' = if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-geolocationNet'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    parTags: parTags
  }
}
