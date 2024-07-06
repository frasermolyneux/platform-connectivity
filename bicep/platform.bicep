targetScope = 'subscription'

// Parameters
@description('The environment for the resources')
param environment string

@description('The location to deploy the resources')
param location string
param instance string

param tags object

// Variables
var environmentUniqueId = uniqueString('connectivity', environment, instance)
var varDeploymentPrefix = 'platform-${environmentUniqueId}' //Prevent deployment naming conflicts

var varDnsResourceGroupName = 'rg-platform-dns-${environment}-${location}-${instance}'

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
  location: location
  tags: tags

  properties: {}
}

module privateDnsZones 'modules/privateDnsZone.bicep' = [
  for zone in privateLinkZones: if (environment == 'prd') {
    name: '${varDeploymentPrefix}-${zone}'
    scope: dnsResourceGroup

    params: {
      dnsZoneName: zone
      tags: tags
    }
  }
]

// DNS Zones
module molyneuxConsultingCoUk 'zones/molyneux-consulting.co.uk.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxConsultingCoUk'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module molyneuxDev 'zones/molyneux.dev.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module molyneuxIO 'zones/molyneux.io.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-molyneuxIo'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module mxConsultingCoUk 'zones/mx-consulting.co.uk.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-mxConsultingCoUk'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module xtremeidiotsCom 'zones/xtremeidiots.com.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-xtremeidiotsCom'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module xtremeidiotsDev 'zones/xtremeidiots.dev.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-xtremeidiotsDev'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}

module geolocationNet 'zones/geo-location.net.bicep' = if (environment == 'prd') {
  name: '${varDeploymentPrefix}-geolocationNet'
  scope: resourceGroup(dnsResourceGroup.name)

  params: {
    tags: tags
  }
}
