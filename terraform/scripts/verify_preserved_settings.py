import json
import os
import re
import sys
import urllib.error
import urllib.request


class SnapshotMismatch(ValueError):
    pass


def verify(query, token):
    zone_id = query["zone_id"]
    expected = json.loads(query["settings"])
    if not re.fullmatch(r"[0-9a-f]{32}", zone_id) or not token or not expected:
        raise ValueError("Invalid discovery configuration.")
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not payload.get("success"):
        raise ValueError("Cloudflare rejected settings discovery.")
    settings = payload["result"]
    by_id = {}
    for setting in settings:
        if setting["id"] in by_id:
            raise ValueError("Cloudflare returned duplicate settings.")
        by_id[setting["id"]] = setting
    for key, value in expected.items():
        live = by_id[key]
        if (live.get("editable") is not True
                or json.dumps(live["value"], sort_keys=True) != json.dumps(value, sort_keys=True)):
            raise SnapshotMismatch(f"Setting {key} differs from its reviewed preservation snapshot.")
    return {"verified": "true"}


def main():
    try:
        result = verify(json.load(sys.stdin), os.environ.get("TF_VAR_cloudflare_api_token", ""))
    except SnapshotMismatch as error:
        print(str(error), file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, TimeoutError, urllib.error.URLError) as error:
        print(f"Settings discovery failed ({type(error).__name__}); no changes made.", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
