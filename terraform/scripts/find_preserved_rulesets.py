import copy
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


class DiscoveryMismatch(ValueError):
    pass


def discover(query, token):
    zone_id = query["zone_id"]
    snapshots = json.loads(query["rulesets"])
    if not re.fullmatch(r"[0-9a-f]{32}", zone_id) or not token or not snapshots:
        raise DiscoveryMismatch("Invalid discovery configuration.")

    def get(path, operation, params=None):
        url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.load(response)
        except urllib.error.HTTPError as error:
            raise DiscoveryMismatch(
                f"Cloudflare {operation} returned HTTP {error.code}."
            ) from None
        if not payload.get("success"):
            raise DiscoveryMismatch("Cloudflare rejected ruleset discovery.")
        return payload

    listing = get("rulesets", "ruleset listing", {"per_page": 50})
    targets = listing["result"]
    info = listing.get("result_info") or {}
    if not isinstance(info, dict) or not isinstance(info.get("cursors") or {}, dict):
        raise DiscoveryMismatch("Malformed ruleset pagination metadata.")
    if (info.get("total_count", len(targets)) != len(targets)
            or (info.get("cursors") or {}).get("after")):
        raise DiscoveryMismatch("Ruleset inventory is incomplete.")

    expected_phases = set(snapshots) | {"http_request_firewall_custom", "http_config_settings"}
    entrypoints = [target for target in targets if target["kind"] == "zone"]
    if (len(entrypoints) != len(expected_phases)
            or {entry["phase"] for entry in entrypoints} != expected_phases
            or sum(entry["phase"] == "http_config_settings"
                   and entry["name"] == "platform-status-origin-tls" for entry in entrypoints) != 1):
        raise DiscoveryMismatch("Zone entrypoint inventory differs from the reviewed ownership map.")

    result = {}
    for phase, snapshot in snapshots.items():
        if phase not in {"http_request_firewall_managed", "http_ratelimit",
                         "http_request_dynamic_redirect"}:
            raise DiscoveryMismatch("Unreviewed ruleset phase.")
        live = get(f"rulesets/phases/{phase}/entrypoint", f"{phase} entrypoint")["result"]
        if (live["name"] != snapshot["name"] or live.get("description", "") != snapshot["description"]
                or live["phase"] != phase or live["kind"] != "zone"
                or not re.fullmatch(r"[0-9a-f]{32}", live["id"])
                or sum(entry["phase"] == phase and entry["id"] == live["id"]
                       for entry in entrypoints) != 1):
            raise DiscoveryMismatch("Ruleset differs from the reviewed snapshot.")
        normalized = []
        desired = []
        for rule in live["rules"]:
            if not re.fullmatch(r"[0-9a-f]{32}", rule["id"]) or rule["ref"] != rule["id"]:
                raise DiscoveryMismatch("Ruleset rule reference differs from the reviewed snapshot.")
            actual = {k: copy.deepcopy(v) for k, v in rule.items()
                      if k not in {"id", "ref", "version", "last_updated"}}
            target_rule = copy.deepcopy(actual)
            target_rule["ref"] = rule["ref"]
            if actual["action"] == "execute":
                params = actual["action_parameters"]
                matches = [target for target in targets if target["id"] == params["id"]]
                if len(matches) != 1 or sum(target["name"] == matches[0]["name"] for target in targets) != 1:
                    raise DiscoveryMismatch("Managed ruleset target is missing or ambiguous.")
                params["target_name"] = matches[0]["name"]
                del params["id"]
                target_rule["action_parameters"].pop("version", None)
            normalized.append(actual)
            desired.append(target_rule)
        if normalized != snapshot["rules"]:
            raise DiscoveryMismatch("Ruleset rules differ from the reviewed snapshot.")
        result[f"{phase}_id"] = live["id"]
        result[f"{phase}_rules"] = json.dumps(desired, separators=(",", ":"))
    return result


def main():
    try:
        result = discover(json.load(sys.stdin), os.environ.get("TF_VAR_cloudflare_api_token", ""))
    except DiscoveryMismatch as error:
        print(f"Ruleset discovery failed: {error} No changes made.", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, TimeoutError, urllib.error.URLError) as error:
        print(f"Ruleset discovery failed ({type(error).__name__}); no changes made.", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
