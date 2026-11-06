import json
import os
import re
import sys
import urllib.error
import urllib.request


def discover(query, token):
    zone_id = query["zone_id"]
    expected = json.loads(query["rules"])
    if not re.fullmatch(r"[0-9a-f]{32}", zone_id) or not token or not expected:
        raise ValueError("Invalid discovery configuration.")

    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/pagerules",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not payload.get("success"):
        raise ValueError("Cloudflare rejected discovery.")
    rules = payload["result"]
    if payload.get("result_info", {}).get("total_count", len(rules)) != len(rules):
        raise ValueError("Page Rule inventory is incomplete.")
    if len(rules) != len(expected):
        raise ValueError("Page Rule inventory differs from the reviewed snapshot.")

    result = {}
    for key, snapshot in expected.items():
        actions = {}
        for action in snapshot["api_actions"]:
            if set(action) - {"id", "value"} or action["id"] in actions:
                raise ValueError("Invalid reviewed Page Rule actions.")
            actions[action["id"]] = action.get("value", True)
        if actions != snapshot["actions"]:
            raise ValueError("Page Rule configuration differs from its reviewed API actions.")
        target = [{
            "target": "url",
            "constraint": {"operator": "matches", "value": snapshot["target"]},
        }]
        matches = [rule for rule in rules if rule["targets"] == target]
        if len(matches) != 1:
            raise ValueError("Expected exactly one matching Page Rule.")
        rule = matches[0]
        if (rule["actions"] != snapshot["api_actions"]
                or rule["priority"] != snapshot["priority"]
                or rule["status"] != snapshot["status"]
                or not re.fullmatch(r"[0-9a-f]{32}", rule["id"])):
            raise ValueError("Page Rule differs from the reviewed snapshot.")
        if rule["id"] in result.values():
            raise ValueError("Page Rule snapshots must match distinct live rules.")
        result[key] = rule["id"]
    return result


def main():
    try:
        result = discover(json.load(sys.stdin), os.environ.get("TF_VAR_cloudflare_api_token", ""))
    except (KeyError, TypeError, ValueError, TimeoutError, urllib.error.URLError) as error:
        print(f"Page Rule discovery failed ({type(error).__name__}); no changes made.",
              file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
