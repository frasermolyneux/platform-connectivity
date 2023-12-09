targetScope = 'subscription'

// Parameters
param parEnvironment string
param parLocation string
param parInstance string

param parTags object

// Variables
var varEnvironmentUniqueId = uniqueString('connectivity', parEnvironment, parInstance)
var varDeploymentPrefix = 'platform-${varEnvironmentUniqueId}' //Prevent deployment naming conflicts

var varDnsResourceGroupName = 'rg-platform-dns-${parEnvironment}-${parLocation}-${parInstance}'
var varFrontDoorResourceGroupName = 'rg-platform-frontdoor-${parEnvironment}-${parLocation}-${parInstance}'
var varFrontDoorName = 'fd-platform-${parEnvironment}-${varEnvironmentUniqueId}'

var privateLinkZones = [
  'privatelink.database.windows.net'
  'privatelink.blob.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.web.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.mysql.database.azure.com'
  'privatelink.azurecr.io'
  'privatelink.azconfig.io'
  'privatelink.servicebus.windows.net'
  'privatelink.eventgrid.azure.net'
  'privatelink.azurewebsites.net'
  'scm.privatelink.azurewebsites.net'
  'privatelink.azure-api.net'
]

// Platform
resource dnsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varDnsResourceGroupName
  location: parLocation
  tags: parTags

  properties: {}
}

module privateDnsZones 'modules/privateDnsZone.bicep' = [for zone in privateLinkZones: if (parEnvironment == 'prd') {
  name: '${varDeploymentPrefix}-${zone}'
  scope: dnsResourceGroup

  params: {
    parDnsZoneName: zone
    parTags: parTags
    parLocation: dnsResourceGroup.location
  }
}]

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
