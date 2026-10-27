import json
import os
import re
import sys
import urllib.error
import urllib.request


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
    matches = [rule for rule in rules if rule["targets"] == targets]
    if len(matches) != 1:
        raise ValueError("Expected exactly one existing redirect.")
    rule = matches[0]
    expected_actions = [{
        "id": "forwarding_url",
        "value": {"url": query["url"], "status_code": int(query["status_code"])},
    }]
    if (rule["actions"] != expected_actions or rule["priority"] != int(query["priority"])
            or rule["status"] not in ("active", "disabled")
            or not re.fullmatch(r"[0-9a-f]{32}", rule["id"])):
        raise ValueError("Existing redirect differs from the reviewed adoption contract.")
    return {"id": rule["id"]}


def main():
    try:
        result = find_rule(json.load(sys.stdin), os.environ.get("TF_VAR_cloudflare_api_token", ""))
    except (KeyError, TypeError, ValueError, TimeoutError, urllib.error.URLError) as error:
        print(f"Legacy redirect discovery failed ({type(error).__name__}); no changes made.",
              file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
