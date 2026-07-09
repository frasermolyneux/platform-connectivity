<#
.SYNOPSIS
    Converts Cloudflare BIND zone-file exports (cf/*.txt) into the platform-connectivity
    Cloudflare zone JSON schema (terraform/zones/<domain>.json).

.DESCRIPTION
    Cloudflare's dashboard "Export DNS records" produces BIND-format zone files. This
    script parses those exports and emits the flat, per-record JSON schema consumed by
    the Cloudflare DNS support in this stack.

    Key behaviours:
      - Drops the SOA record and the apex Cloudflare nameserver (NS) records — these are
        zone-owned by Cloudflare and cannot be managed as cloudflare_dns_record.
      - Captures proxy state from the "; cf_tags=cf-proxied:<bool>" comment.
      - Normalises TTL (1 == Cloudflare "automatic").
      - Strips trailing dots from CNAME/MX/SRV targets so record content matches what the
        Cloudflare API returns (avoids spurious diffs and keeps import slugs stable).
      - Relativises record names against the zone apex ("@").
      - Applies the carve-out exclusions in $Exclusions so records owned by other stacks
        (e.g. platform-notifications ACS records) are NOT duplicated here.

    Zone IDs are read from cf/zone_ids.txt (format: "<domain> - <zone_id>" per line).

.NOTES
    Re-runnable. The cf/*.txt exports are archival; terraform/zones/*.json is the managed
    source of truth going forward.
#>
[CmdletBinding()]
param(
    [string]$CfFolder = (Join-Path $PSScriptRoot '..' 'cf'),
    [string]$ZonesFolder = (Join-Path $PSScriptRoot '..' 'terraform' 'zones'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Carve-outs: records that are owned by OTHER Terraform stacks and must not be
# managed here. Keyed by zone name; each entry is a predicate on {Type,Name,Content}.
#
#   xtremeidiots.com — platform-notifications manages the ACS email records:
#     * selector1/selector2 ACS DKIM CNAMEs
#     * the ACS-managed SPF TXT (v=spf1 include:spf.protection.outlook.com -all)
#   These are excluded here so the two stacks do not fight over the same records.
# ---------------------------------------------------------------------------
$Exclusions = @{
    'xtremeidiots.com' = @(
        { param($r) $r.type -eq 'CNAME' -and $r.name -like 'selector1-azurecomm-prod-net._domainkey*' },
        { param($r) $r.type -eq 'CNAME' -and $r.name -like 'selector2-azurecomm-prod-net._domainkey*' },
        { param($r) $r.type -eq 'TXT' -and $r.content -eq 'v=spf1 include:spf.protection.outlook.com -all' }
    )
}

function Get-ZoneIdMap {
    param([string]$Path)
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([A-Za-z0-9\.\-]+)\s*-\s*([0-9a-fA-F]{32})\s*$') {
            $map[$Matches[1].ToLowerInvariant()] = $Matches[2].ToLowerInvariant()
        }
    }
    return $map
}

function ConvertTo-RelativeName {
    param([string]$Fqdn, [string]$Zone)
    $n = $Fqdn.TrimEnd('.')
    if ($n -ieq $Zone) { return '@' }
    if ($n.ToLowerInvariant().EndsWith(".$($Zone.ToLowerInvariant())")) {
        return $n.Substring(0, $n.Length - $Zone.Length - 1)
    }
    return $n
}

function Get-ProxiedFlag {
    param([string]$Line)
    if ($Line -match 'cf-proxied:(true|false)') { return [bool]::Parse($Matches[1]) }
    return $false
}

function Get-TxtContent {
    param([string]$RData)
    # Cloudflare splits long TXT values into multiple adjacent quoted strings.
    $segments = [regex]::Matches($RData, '"([^"]*)"')
    if ($segments.Count -gt 0) {
        return -join ($segments | ForEach-Object { $_.Groups[1].Value })
    }
    return $RData.Trim()
}

$zoneIds = Get-ZoneIdMap -Path (Join-Path $CfFolder 'zone_ids.txt')
$exportFiles = Get-ChildItem -LiteralPath $CfFolder -Filter '*.txt' | Where-Object { $_.Name -ne 'zone_ids.txt' }

foreach ($file in $exportFiles) {
    $zone = [System.IO.Path]::GetFileNameWithoutExtension($file.Name).ToLowerInvariant()
    if (-not $zoneIds.ContainsKey($zone)) {
        Write-Warning "No zone_id for '$zone' in zone_ids.txt — skipping."
        continue
    }

    $records = New-Object System.Collections.Generic.List[object]

    foreach ($raw in Get-Content -LiteralPath $file.FullName) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith(';')) { continue }

        # NAME  TTL  IN  TYPE  RDATA...   (RDATA captured greedily; TXT values legitimately
        # contain ';', so we only strip the trailing "; cf_tags=..." Cloudflare proxy comment.)
        if ($line -notmatch '^(?<name>\S+)\s+(?<ttl>\d+)\s+IN\s+(?<type>[A-Z]+)\s+(?<rdata>.+)$') { continue }

        $type = $Matches['type']
        if ($type -in @('SOA', 'NS')) { continue }  # zone-owned by Cloudflare

        $name = ConvertTo-RelativeName -Fqdn $Matches['name'] -Zone $zone
        $ttl = [int]$Matches['ttl']
        $rdata = ($Matches['rdata'] -replace '\s*;\s*cf_tags=\S+\s*$', '').Trim()

        $record = [ordered]@{ type = $type; name = $name; ttl = $ttl }

        switch ($type) {
            { $_ -in @('A', 'AAAA') } {
                $record.content = $rdata.Trim()
                $record.proxied = Get-ProxiedFlag -Line $raw
            }
            'CNAME' {
                $record.content = $rdata.Trim().TrimEnd('.')
                $record.proxied = Get-ProxiedFlag -Line $raw
            }
            'MX' {
                $parts = $rdata -split '\s+', 2
                $record.priority = [int]$parts[0]
                $record.content = $parts[1].Trim().TrimEnd('.')
            }
            'TXT' {
                $record.content = Get-TxtContent -RData $rdata
            }
            'SRV' {
                $parts = $rdata -split '\s+'
                $record.data = [ordered]@{
                    priority = [int]$parts[0]
                    weight   = [int]$parts[1]
                    port     = [int]$parts[2]
                    target   = $parts[3].Trim().TrimEnd('.')
                }
            }
            default {
                Write-Warning "Unhandled record type '$type' in $zone ($name) — skipping."
                continue
            }
        }

        # Apply carve-out exclusions.
        $excluded = $false
        if ($Exclusions.ContainsKey($zone)) {
            $probe = [pscustomobject]@{ type = $type; name = $name; content = $record.content }
            foreach ($pred in $Exclusions[$zone]) {
                if (& $pred $probe) { $excluded = $true; break }
            }
        }
        if ($excluded) {
            Write-Host "  carve-out: excluded $type $name ($zone)" -ForegroundColor Yellow
            continue
        }

        $records.Add([pscustomobject]$record)
    }

    $sorted = $records | Sort-Object type, name, { $_.content }, { $_.data.target }

    $zoneObject = [ordered]@{
        name            = $zone
        dns_provider    = 'cloudflare'
        zone_id         = $zoneIds[$zone]
        backup_to_azure = $false
        records         = @($sorted)
    }

    $json = $zoneObject | ConvertTo-Json -Depth 6
    $outPath = Join-Path $ZonesFolder "$zone.json"

    if ($WhatIf) {
        Write-Host "WhatIf: would write $outPath ($($records.Count) records)"
    }
    else {
        Set-Content -LiteralPath $outPath -Value $json -Encoding utf8
        Write-Host "Wrote $outPath ($($records.Count) records)" -ForegroundColor Green
    }
}
