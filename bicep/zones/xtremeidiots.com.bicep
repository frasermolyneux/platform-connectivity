targetScope = 'resourceGroup'

// Parameters
param parTags object

// Resources
resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'xtremeidiots.com'
  location: 'global'
  tags: parTags

  properties: {
    zoneType: 'Public'
  }
}

// Minecraft
resource minecraft112 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: '112'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '192.99.235.196'
      }
    ]
  }
}

resource minecraftModMc 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'sf3'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '192.95.38.141'
      }
    ]
  }
}

resource minecraftSf3 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'mod-mc'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '192.95.22.174'
      }
    ]
  }
}

// Forums
resource forums 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: '@'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '144.217.22.232'
      }
    ]
  }
}

resource forumsWww 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'www'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '144.217.22.232'
      }
    ]
  }
}

resource forumsCdn 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'cdn'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '144.217.22.232'
      }
    ]
  }
}

resource test 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'test'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '144.217.22.232'
      }
    ]
  }
}

// Other Websites
resource stats 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'stats'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '144.217.22.232'
      }
    ]
  }
}

resource tcadmin 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'tcadmin'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '51.79.83.13'
      }
    ]
  }
}

resource portal 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'portal'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    CNAMERecord: {
      cname: 'webapp-admin-portal-prd-uksouth.azurewebsites.net'
    }
  }
}

// Teamspeak
resource teamspeak 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: 'ts'
  parent: zone

  properties: {
    TTL: 3600
    metadata: parTags
    ARecords: [
      {
        ipv4Address: '192.95.39.66'
      }
    ]
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
