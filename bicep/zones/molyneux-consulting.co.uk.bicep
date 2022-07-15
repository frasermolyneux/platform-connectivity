targetScope = 'resourceGroup'

// Parameters
param parTags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'molyneux-consulting.co.uk'
  location: 'global'
  tags: parTags

  properties: {
    zoneType: 'Public'
  }
}

// Microsoft 365
resource autodiscover 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'autodiscover'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'autodiscover.outlook.com'
    }
  }
}

resource enterpriseenrollment 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'enterpriseenrollment'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'enterpriseenrollment.manage.microsoft.com'
    }
  }
}

resource enterpriseregistration 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'enterpriseregistration'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'enterpriseregistration.windows.net'
    }
  }
}

resource lyncdiscover 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'lyncdiscover'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'webdir.online.lync.com'
    }
  }
}

resource sip 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'sip'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'sipdir.online.lync.com'
    }
  }
}

resource mxRoot 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    MXRecords: [
      {
        exchange: 'molyneuxconsulting-co-uk02b.mail.protection.outlook.com'
        preference: 1
      }
    ]
  }
}

resource sipfederationtls 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '_sipfederationtls'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    SRVRecords: [
      {
        port: 5061
        priority: 100
        target: 'sipfed.online.lync.com'
        weight: 1
      }
    ]
  }
}

resource siptls 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '_sip'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    SRVRecords: [
      {
        port: 443
        priority: 100
        target: 'sipdir.online.lync.com'
        weight: 1
      }
    ]
  }
}

// Google Analytics
resource textRecordsRoot 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    TXTRecords: [
      {
        value: [
          'google-site-verification=U1O-XOx3VlyUOjJvCZOiEsS42FcO4SIbFkP6uL-j-oM'
          'v=spf1 include:spf.protection.outlook.com -all'
          'MS=ms78513937'
        ]
      }
    ]
  }
}
