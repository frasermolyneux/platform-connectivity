targetScope = 'resourceGroup'

// Parameters
param parDnsZoneName string
param parRecordValue string
param parTags object

// Existing In-Scope Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: parDnsZoneName
}

// Module Resources
resource textRecordsRoot 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    TXTRecords: [
      {
        value: [
          parRecordValue
        ]
      }
    ]
  }
}
