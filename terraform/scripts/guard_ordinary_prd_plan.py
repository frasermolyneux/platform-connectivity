"""Keep ordinary deployments from applying the guarded TLS ruleset."""

import json
import sys
from pathlib import Path

from guard_strict_tls_plan import ADDRESS, Rejected, has_unknown, require


def validate(plan, expected_zone_id):
    require(plan.get("format_version", "").split(".")[0] == "1"
            and plan.get("complete") is True and plan.get("errored") is False,
            "unsupported, incomplete, or errored plan")
    require(not plan.get("deferred_changes") and not plan.get("deferred_actions")
            and not plan.get("action_invocations"), "deferred change or action")
    changes = plan.get("resource_changes")
    require(isinstance(changes, list), "resource changes missing")
    for resource in changes:
        require(resource.get("previous_address") != ADDRESS,
                "target ruleset moved")
    drift = plan.get("resource_drift", [])
    require(isinstance(drift, list) and all(
        entry.get("address") != ADDRESS and entry.get("previous_address") != ADDRESS
        for entry in drift
    ), "target ruleset drift detected")
    targets = [resource for resource in changes if resource.get("address") == ADDRESS]
    require(len(targets) == 1, "expected exactly one target ruleset")
    target = targets[0]
    change = target.get("change", {})
    before, after = change.get("before"), change.get("after")
    require(target.get("mode") == "managed" and target.get("type") == "cloudflare_ruleset"
            and "previous_address" not in target and "importing" not in change
            and "generated_config" not in change
            and change.get("actions") == ["no-op"]
            and isinstance(before, dict) and before == after
            and isinstance(change.get("after_unknown"), dict)
            and not has_unknown(change.get("after_unknown"))
            and isinstance(expected_zone_id, str) and bool(expected_zone_id)
            and before.get("zone_id") == expected_zone_id,
            "target ruleset is changed, unknown, missing, or has unexpected identity")


def main():
    try:
        zone_file = Path(__file__).resolve().parents[1] / "zones" / "xtremeidiots.net.json"
        with zone_file.open(encoding="utf-8") as file:
            expected_zone_id = json.load(file)["zone_id"]
        require(len(sys.argv) == 1, "invalid arguments")
        validate(json.load(sys.stdin), expected_zone_id)
        print("Ordinary production plan does not change the guarded TLS ruleset.")
    except (Rejected, ValueError, TypeError, KeyError) as error:
        print(f"Ordinary production plan rejected: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
