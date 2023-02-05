targetScope = 'resourceGroup'

// Parameters
param parTags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'talkwithtiles.com'
  location: 'global'
  tags: parTags

  properties: {
    zoneType: 'Public'
  }
}

// TXT Records
resource txt_records 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    TXTRecords: [
      { // M365/AAD - Proof of Ownership
        value: [
          'MS=ms43281192'
        ]
      }
      { // M365 Exchange - SPF
        value: [
          'v=spf1 include:_spf.google.com include:spf.protection.outlook.com ~all'
        ]
      }
      { // Google Analytics
        value: [
          'google-site-verification=1ceB4EmXkNGlYuTPgMd4K9Bj9zD81Jv9XrNFIb5n2S4'
        ]
      }
    ]
  }
}

// MX Records
resource mx_records 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    MXRecords: [
      { // M365 Exchange - MX Record
        exchange: 'talkwithtiles-com.mail.protection.outlook.com'
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

// M365 Skype / Teams
resource m365sip 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'sip'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'sipdir.online.lync.com.'
    }
  }
}

// M365 Skype / Teams
resource m365lyncdiscover 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'lyncdiscover'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'webdir.online.lync.com.'
    }
  }
}

// M365 Skype / Teams
resource m365sipsrv 'Microsoft.Network/dnsZones/SRV@2018-05-01' = {
  name: '_sip._tls'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    SRVRecords: [
      {
        port: 443
        priority: 100
        target: 'sipdir.online.lync.com.'
        weight: 1
      }
    ]
  }
}

// M365 Skype / Teams
resource m365sipfedsrv 'Microsoft.Network/dnsZones/SRV@2018-05-01' = {
  name: '_sipfederationtls._tcp'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    SRVRecords: [
      {
        port: 5061
        priority: 100
        target: 'sipfed.online.lync.com.'
        weight: 1
      }
    ]
  }
}
