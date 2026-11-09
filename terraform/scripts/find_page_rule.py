import json
import os
import re
import sys
import urllib.error
import urllib.request


def normalize_actions(actions):
    if isinstance(actions, dict):
        result = []
        for action_id, value in actions.items():
            action = {"id": action_id}
            if not (isinstance(value, bool) and value):
                action["value"] = value
            result.append(action)
    elif isinstance(actions, list):
        result = [
            {"id": action["id"], **({"value": action["value"]} if "value" in action else {})}
            for action in actions
        ]
    else:
        raise ValueError("Invalid Page Rule action configuration.")
    if any(not isinstance(action.get("id"), str) for action in result):
        raise ValueError("Invalid Page Rule action configuration.")
    return sorted(result, key=lambda action: action["id"])


def find_rule(query, token):
    zone = query["zone_id"]
    if not re.fullmatch(r"[0-9a-f]{32}", zone) or not token:
        raise ValueError("Missing or invalid discovery configuration.")
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/zones/{zone}/pagerules",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not payload.get("success"):
        raise ValueError("Cloudflare rejected discovery.")
    rules = payload["result"]
    if payload.get("result_info", {}).get("total_count", len(rules)) != len(rules):
        raise ValueError("Page Rule inventory is incomplete.")
    targets = [{
        "target": "url",
        "constraint": {"operator": "matches", "value": query["target"]},
    }]
    statuses = {status.strip() for status in query["status"].split(",")}
    if not statuses or not statuses.issubset({"active", "disabled"}):
        raise ValueError("Invalid Page Rule status constraint.")
    require_match = query.get("require_match", "false")
    if require_match not in {"true", "false"}:
        raise ValueError("Invalid Page Rule match constraint.")
    candidates = [
        rule for rule in rules
        if rule.get("targets") == targets
    ]
    matches = [
        rule for rule in candidates
        if rule.get("priority") == int(query["priority"])
        and rule.get("status") in statuses
        and normalize_actions(rule.get("actions")) == normalize_actions(
            json.loads(query["actions"])
        )
    ]
    if len(candidates) > 1 or len(matches) > 1:
        raise ValueError("Page Rule discovery found ambiguous candidates.")
    if not candidates and require_match == "false":
        return {"id": ""}
    if len(matches) != 1:
        raise ValueError("Existing Page Rule differs from the reviewed configuration.")
    rule = matches[0]
    if not re.fullmatch(r"[0-9a-f]{32}", rule.get("id", "")):
        raise ValueError("Invalid Page Rule identifier returned by Cloudflare.")
    return {"id": rule["id"]}


def main():
    try:
        result = find_rule(json.load(sys.stdin), os.environ.get("TF_VAR_cloudflare_api_token", ""))
    except (KeyError, TypeError, ValueError, TimeoutError, urllib.error.URLError) as error:
        print(f"Legacy Page Rule discovery failed ({type(error).__name__}); no changes made.",
              file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
