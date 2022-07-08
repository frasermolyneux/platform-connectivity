targetScope = 'resourceGroup'

// Parameters
param parFrontDoorName string
param parTags object

// Module Resources
resource frontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: parFrontDoorName
  location: 'Global'
  tags: parTags

  sku: {
    name: 'Standard_AzureFrontDoor'
  }

  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Outputs
output outFrontDoorId string = frontDoor.properties.frontDoorId
