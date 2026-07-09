<#
.SYNOPSIS
    Exports Cloudflare DNS record IDs for the managed zones into cf/record_ids.json.

.DESCRIPTION
    terraform/cloudflare_dns_imports.tf adopts existing Cloudflare records via import
    blocks keyed by a stable slug. This script queries the Cloudflare API for every
    Cloudflare-managed zone (terraform/zones/*.json with dns_provider == "cloudflare"),
    computes the SAME slug used by terraform/locals.tf, and — for records that this
    stack manages — writes { slug => { zone_id, record_id, type } } to cf/record_ids.json.

    Records that are NOT in the managed JSON (carve-outs owned by other stacks, e.g.
    platform-notifications ACS records) are skipped, so no orphan import is generated.

    Run this once (and again whenever records change in Cloudflare) BEFORE the Terraform
    apply that adopts the records.

.PARAMETER ApiToken
    Cloudflare API token with DNS Read on the target zones. Defaults to the
    CLOUDFLARE_API_TOKEN or CLOUDFLARE_API_KEY environment variable.

.EXAMPLE
    $env:CLOUDFLARE_API_TOKEN = '<token>'
    ./scripts/Export-CloudflareRecordIds.ps1
#>
[CmdletBinding()]
param(
    [string]$ApiToken = ($env:CLOUDFLARE_API_TOKEN ? $env:CLOUDFLARE_API_TOKEN : $env:CLOUDFLARE_API_KEY),
    [string]$ZonesFolder = (Join-Path $PSScriptRoot '..' 'terraform' 'zones'),
    [string]$OutFile = (Join-Path $PSScriptRoot '..' 'cf' 'record_ids.json')
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    throw 'No Cloudflare API token. Set CLOUDFLARE_API_TOKEN (or pass -ApiToken).'
}

$headers = @{ Authorization = "Bearer $ApiToken" }

function ConvertTo-RelativeName {
    param([string]$Fqdn, [string]$Zone)
    $n = $Fqdn.TrimEnd('.')
    if ($n -ieq $Zone) { return '@' }
    if ($n.ToLowerInvariant().EndsWith(".$($Zone.ToLowerInvariant())")) {
        return $n.Substring(0, $n.Length - $Zone.Length - 1)
    }
    return $n
}

function Get-NormalizedTxtContent {
    param([string]$Content)
    # Match Convert-CloudflareZones.ps1/Get-TxtContent: concatenate adjacent quoted
    # segments and strip quotes so long (DKIM) TXT values slug-match the managed JSON.
    $segments = [regex]::Matches($Content, '"([^"]*)"')
    if ($segments.Count -gt 0) {
        return -join ($segments | ForEach-Object { $_.Groups[1].Value })
    }
    return $Content
}

function Get-RecordSlug {
    param([string]$Zone, [pscustomobject]$Record)
    $name = ConvertTo-RelativeName -Fqdn $Record.name -Zone $Zone
    switch ($Record.type) {
        'SRV' {
            $target = ($Record.data.target).ToString().TrimEnd('.')
            return "$Zone|SRV|$name|$($target):$($Record.data.port)"
        }
        'TXT' {
            return "$Zone|TXT|$name|$(Get-NormalizedTxtContent $Record.content)"
        }
        { $_ -in @('CNAME', 'MX') } {
            return "$Zone|$($Record.type)|$name|$(($Record.content).TrimEnd('.'))"
        }
        default {
            return "$Zone|$($Record.type)|$name|$($Record.content)"
        }
    }
}

# Build the set of slugs this stack manages, from the converted zone JSON.
$managedZones = @{}
foreach ($file in Get-ChildItem -LiteralPath $ZonesFolder -Filter '*.json') {
    $zoneObj = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    if ($zoneObj.dns_provider -ne 'cloudflare') { continue }

    $slugs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $zoneObj.records) {
        switch ($r.type) {
            'SRV' { [void]$slugs.Add("$($zoneObj.name)|SRV|$($r.name)|$($r.data.target):$($r.data.port)") }
            default { [void]$slugs.Add("$($zoneObj.name)|$($r.type)|$($r.name)|$($r.content)") }
        }
    }
    $managedZones[$zoneObj.name] = @{ zone_id = $zoneObj.zone_id; slugs = $slugs }
}

$result = [ordered]@{}

foreach ($zoneName in ($managedZones.Keys | Sort-Object)) {
    $zoneId = $managedZones[$zoneName].zone_id
    $managedSlugs = $managedZones[$zoneName].slugs
    $matched = 0

    $page = 1
    do {
        $uri = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?per_page=100&page=$page"
        $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if (-not $resp.success) { throw "Cloudflare API error for ${zoneName}: $($resp.errors | ConvertTo-Json -Compress)" }

        foreach ($apiRecord in $resp.result) {
            $slug = Get-RecordSlug -Zone $zoneName -Record $apiRecord
            if ($managedSlugs.Contains($slug)) {
                $result[$slug] = [ordered]@{ zone_id = $zoneId; record_id = $apiRecord.id; type = $apiRecord.type }
                $matched++
            }
        }
        $totalPages = $resp.result_info.total_pages
        $page++
    } while ($page -le $totalPages)

    $missing = $managedSlugs.Count - $matched
    $colour = $missing -eq 0 ? 'Green' : 'Yellow'
    Write-Host "$zoneName : matched $matched/$($managedSlugs.Count) managed records" -ForegroundColor $colour
    if ($missing -gt 0) {
        foreach ($s in $managedSlugs) {
            if (-not $result.Contains($s)) { Write-Warning "  no Cloudflare record found for managed slug: $s" }
        }
    }
}

$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutFile -Encoding utf8
Write-Host "Wrote $OutFile ($($result.Count) records)" -ForegroundColor Green
