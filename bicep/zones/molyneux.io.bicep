targetScope = 'resourceGroup'

// Parameters
param parTags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'molyneux.io'
  location: 'global'
  tags: parTags

  properties: {
    zoneType: 'Public'
  }
}

// TXT Records
resource textRecordsRoot 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    TXTRecords: [
      {
        value: [
          'MS=ms70605256' // M365/AAD - Proof of Ownership
        ]
      }
      {
        value: [
          'v=spf1 include:spf.protection.outlook.com -all' // M365 Exchange - SPF
        ]
      }
    ]
  }
}

// M365 Exchange - MX Record
resource m365mx 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    MXRecords: [
      {
        exchange: 'molyneux-io.mail.protection.outlook.com.'
        preference: 0
      }
    ]
  }
}

// M365 Exchange - CNAME Record
resource m365autodiscover 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'autodiscover'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'autodiscover.outlook.com.'
    }
  }
}

// M365 MDM/Intune
resource m365enterpriseregistration 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'enterpriseregistration'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'enterpriseregistration.windows.net.'
    }
  }
}

// M365 MDM/Intune
resource m365enterpriseenrollment 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'enterpriseenrollment'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'enterpriseenrollment.manage.microsoft.com.'
    }
  }
}
