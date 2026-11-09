# Cloudflare estate preservation and ownership

## Reconciled scope

The read-only live inventory on 2026-11-09 contains **one account and 18 active
full zones**: 17 Free and `xtremeidiots.com` Pro. The previous 17 JSON
declarations were not the complete inventory: `mxstatus.io` is included here.
This is preservation, not hardening, a paid-product activation or a zone-plan
change. Configuration keeps existing record content/proxy/TTL, settings,
DNSSEC status, ordered rules, Page Rule priority/status and owner identities.
No live resource or state is changed by the local validation process.

Every listed zone has a full editable-settings snapshot, explicit
`settings_preserve_existing`, zone/DNSSEC discovery and declarative imports.
Previously owned read-only HTTP/2 settings remain declared on both TripSideKick
zones; dropping them would unnecessarily release their existing state bindings.
DNS keys are stable independently of mutable content. The 124 estate DNS moves
preserve the existing bindings; retain the earlier Phase 1 moves as well.
Production move destinations were checked against existing bindings; Dev has
only its resource group and no Cloudflare resources.

## Zone and feature matrix

DNS counts are live / connectivity-owned. All unlisted entrypoints were absent
in the inventoried zone-ruleset list, not inferred from repository declarations.
DNSSEC is disabled except where explicitly active below. A dash means no live
zone-level ruleset or Page Rule, not a request to create default controls.

| Zone | DNS | Connectivity phase entrypoints | Page Rules | Other ownership |
|---|---:|---|---:|---|
| bishopsbees.co.uk | 15 / 14 | `http_request_cache_settings` | 0 | Worker custom-domain AAAA |
| bqba.co.uk | 2 / 2 | - | 0 | - |
| buckfastqueen.co.uk | 9 / 9 | - | 1 | - |
| dm-electricalservices.co.uk | 9 / 9 | - | 0 | - |
| midlr.com | 9 / 9 | - | 1 | - |
| moanclub.com | 11 / 11 | - | 0 | - |
| molyfra.uk | 8 / 8 | - | 0 | - |
| mx-mail.io | 15 / 15 | - | 0 | - |
| mxstatus.io | 10 / 10 | - | 0 | Status edge config phase and load balancing |
| queensforsale.co.uk | 2 / 2 | - | 1 | - |
| talkwithtiles.com | 12 / 12 | `http_config_settings` (existing origin owner) | 1 disabled, existing address | - |
| travellingkermit.com | 7 / 7 | - | 0 | - |
| tripsidekick.app | 2 / 0 | `http_request_firewall_custom`; DNSSEC active | 0 | TripSideKick apex/www A |
| tripsidekick.net | 2 / 0 | `http_request_firewall_custom`; DNSSEC active | 0 | TripSideKick apex/www A |
| xiredirect.com | 9 / 9 | - | 0 | - |
| xtre.co.uk | 7 / 7 | - | 0 | - |
| xtremeidiots.com | 29 / 25 | Custom WAF, managed WAF, rate limit, dynamic redirect | 2 | Notifications DNS and status config phase |
| xtremeidiots.net | 10 / 10 | `http_config_settings` (existing origin owner) | 2 | - |

The abbreviated XtremeIdiots phases are `http_request_firewall_custom`,
`http_request_firewall_managed`, `http_ratelimit` and
`http_request_dynamic_redirect`. Managed-WAF catalog rulesets are referenced by
the existing execute rule, not imported as zone-owned deployments. The only
additional live phase beyond DNS/settings/WAF/rate limits/dynamic redirects/
Page Rules/config settings is BishopsBees cache settings.

## Single-owner boundaries and recovery

Production state IDs were reconciled read-only for connectivity,
`platform-notifications`, `platform-status-web` edge and `trip-side-kick`.
The matching identifiers are operational discovery data, not committed here.

- Notifications owns the XtremeIdiots ACS verification TXT, SPF TXT and two
  AzureComm DKIM CNAMEs. The verification TXT was already bound in **both**
  notifications and connectivity. `cloudflare_notifications_release.tf` moves
  only connectivity's duplicate instance to a retired singleton, then forgets
  it with `destroy = false`. Notifications keeps its binding and the live TXT
  remains unchanged. It is intentionally absent from connectivity `records`.
- TripSideKick owns apex/www A records in `.app` and `.net`; none are imported
  here. Connectivity retains its pre-existing zone/settings/firewall ownership.
- Status edge owns `http_config_settings` in `mxstatus.io` and
  `xtremeidiots.com`, plus the mxstatus load balancer/pool/monitor. Connectivity
  must not import or compete with those entrypoints or load-balancing resources.
- The Worker custom-domain controller owns the generated
  `maintenance-check.bishopsbees.co.uk` AAAA. It is not a direct DNS declaration.
  Active maintenance routes remain runtime-owned; no live routes were present
  at inventory time.
- Talk's disabled legacy Page Rule and Talk/XtremeIdiots.net origin TLS
  entrypoints retain their existing resource addresses and ownership identities.
  `origin_tls_preserve_existing` permits this continuity after zone adoption.

The release is state-only, not an atomic transfer: notifications already owns
the record, so there is no ownership gap to bridge. Do not recover by importing
it back into connectivity or deleting either the live record or notifications'
binding. Any rollback must retain these exclusions and receive separate review;
reverting the release alone can reintroduce duplicate ownership. The isolated
release regression proves `forget` for the delegated instance, `no-op` for a
retained instance and byte-identical input state. The locked Production plan is
the evidence for the actual Cloudflare binding and historical move chain.

## Permissions and deployment order

Deploy [frasermolyneux/platform-workloads#281](https://github.com/frasermolyneux/platform-workloads/pull/281)
**before connectivity**. Its uniform policy covers all 18 zones: DNS Write,
Zone Read/Write, Zone Settings Write, Zone WAF Write, Config Settings Write,
Dynamic URL Redirects Write, Page Rules Write and Cache Settings Write; account
Workers Scripts permission is retained. Runtime alone needs Workers Routes
Write. Broad zone scope is a capability grant, not permission for connectivity
to adopt another controller's resources.

`mxstatus.io` needs the same policy despite status-owned config/DNS serving:
connectivity owns its zone/settings/DNSSEC and ten mail/verification DNS records;
status owns its service entrypoint and load-balancing resources. Do not remove
that zone from permissions or duplicate its status-owned phase.

After permissions deploy, review an authoritative Production CI plan against
current state before connectivity deployment. Expected resource behavior is
imports, DNS address moves and one non-destructive ownership release only,
plus nameserver output enrichment. Stop on any create/update/delete, snapshot
drift or unexpected ownership action. Local read-only token success does not
prove the CI write token has the required scope.

## Coverage limits and regression evidence

Zone list, DNS, settings, DNSSEC, all zone-level rulesets, Page Rules and Worker
routes were read for every zone. Found DNS types A/AAAA/CNAME/MX/SRV/TXT are
supported; unsupported types fail closed rather than disappearing.

Tiered caching reads **off, editable=false** on all 18 zones and is not adopted
as an editable product. Argo smart routing is inaccessible on all 18 zones:
HTTP 401/code 1015 with both the local token and MCP settings read path. Its
state is **unknown**, not assumed disabled. No paid product is enabled to work
around that limitation. This inventory does not claim exhaustive coverage of
Access, certificates, account-wide products or every Cloudflare API surface.
Those are outside the DNS/zone-control adoption and require separate inventory
and ownership review before management is added.

Tests use reserved `.test`/`.invalid` names, documentation addresses and fake
IDs, rather than copying the production estate into fixtures. Coverage includes
new/existing/external and multiple zones, missing/ambiguous/error paths,
stable record identity and distinct SRV matching, ordered ruleset/settings/WAF
drift checks, managed-zone origin-owner continuity, and isolated move/forget.
Mocks do not prove live provider normalization or permissions; the normally
locked Production plan covers those for the declared snapshot at plan time,
not subsequent drift, deployment success or live traffic health.
