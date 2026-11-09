#!/usr/bin/env python3
"""Compare explicitly configured Cloudflare zone settings with a reviewed snapshot."""

import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def _without_nulls(value):
    if isinstance(value, dict):
        return {
            key: normalized
            for key, item in value.items()
            if item is not None
            if (normalized := _without_nulls(item)) is not None
        }
    if isinstance(value, list):
        return [_without_nulls(item) for item in value]
    return value


def compare_snapshot(expected, response):
    if not isinstance(expected, dict) or not all(isinstance(key, str) for key in expected):
        raise ValueError("Expected settings snapshot must be a JSON object with string identifiers.")
    if not isinstance(response, dict) or response.get("success") is not True:
        raise ValueError("Cloudflare settings API returned an unsuccessful response.")

    settings = response.get("result")
    if not isinstance(settings, list):
        raise ValueError("Cloudflare settings API response did not contain a settings list.")

    live = {}
    for setting in settings:
        if (
            not isinstance(setting, dict)
            or not isinstance(setting.get("id"), str)
            or not isinstance(setting.get("editable"), bool)
            or "value" not in setting
        ):
            raise ValueError("Cloudflare settings API returned an invalid setting entry.")
        setting_id = setting["id"]
        if setting_id in live:
            raise ValueError("Cloudflare settings API returned duplicate setting identifiers.")
        live[setting_id] = setting.get("value")

    differences = sorted(
        setting_id
        for setting_id, expected_value in expected.items()
        if (
            setting_id not in live
            or json.dumps(_without_nulls(expected_value), sort_keys=True, separators=(",", ":"))
            != json.dumps(_without_nulls(live[setting_id]), sort_keys=True, separators=(",", ":"))
        )
    )
    return differences


def _read_zone_settings(zone_id, token):
    if not re.fullmatch(r"[0-9a-fA-F]{32}", zone_id):
        raise ValueError("Cloudflare settings lookup received an invalid zone identifier.")

    request = Request(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/settings",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        raise ValueError(
            f"Cloudflare settings API request failed with HTTP {error.code}; verify read permissions."
        ) from None
    except URLError:
        raise ValueError("Cloudflare settings API request failed; verify network access.") from None


def main():
    query = json.load(sys.stdin)
    token = os.environ.get("TF_VAR_cloudflare_api_token", "")
    if not token:
        raise ValueError("TF_VAR_cloudflare_api_token is unavailable to the settings snapshot check.")

    expected = json.loads(query["expected"])
    response = _read_zone_settings(query["zone_id"], token)
    differences = compare_snapshot(expected, response)
    print(json.dumps({
        "matches": str(not differences).lower(),
        "differences": json.dumps(differences, separators=(",", ":")),
    }))


if __name__ == "__main__":
    try:
        main()
    except (KeyError, json.JSONDecodeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
