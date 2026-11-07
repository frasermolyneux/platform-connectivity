"""Fail closed unless a plan is the approved TLS rule addition or removal."""

import json
from pathlib import Path
import sys

ADDRESS = 'cloudflare_ruleset.origin_tls["xtremeidiots.net"]'
HOST = "redirect.xtremeidiots.net"


class Rejected(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def has_unknown(value):
    if isinstance(value, dict):
        return any(has_unknown(item) for item in value.values())
    if isinstance(value, list):
        return any(has_unknown(item) for item in value)
    return value is not False and value is not None


def validate(plan, expected_zone_id, operation="add"):
    require(operation in {"add", "remove"}, "unsupported operation")
    require(plan.get("format_version", "").split(".")[0] == "1", "unsupported plan format")
    require(plan.get("complete") is True and plan.get("applyable") is True
            and plan.get("errored") is False, "plan is incomplete, not applyable, or errored")
    require(not plan.get("resource_drift"), "resource drift detected")
    require(not plan.get("deferred_changes"), "deferred changes detected")
    require(not plan.get("action_invocations") and not plan.get("deferred_actions"),
            "action invocation detected")
    checks = plan.get("checks", [])
    require(isinstance(checks, list) and all(check.get("status") == "pass" for check in checks),
            "unresolved or failed checks detected")
    for change in plan.get("output_changes", {}).values():
        require(change.get("actions") == ["no-op"] and not has_unknown(change.get("after_unknown")),
                "output change or unknown value detected")

    changes = plan.get("resource_changes")
    require(isinstance(changes, list), "resource changes missing")
    targets = []
    for resource in changes:
        change = resource.get("change", {})
        require("previous_address" not in resource and "importing" not in change
                and "generated_config" not in change, "move, import, or generated configuration detected")
        if resource.get("address") == ADDRESS:
            targets.append(resource)
        else:
            require(change.get("actions") == ["no-op"]
                    and not has_unknown(change.get("after_unknown")),
                    "unrelated resource change or unknown value detected")
    require(len(targets) == 1, "expected exactly one target resource")
    target = targets[0]
    require(target.get("mode") == "managed" and target.get("type") == "cloudflare_ruleset",
            "unexpected target resource type")
    change = target["change"]
    require(change.get("actions") == ["update"], "target must be updated in place")
    before, after = change.get("before"), change.get("after")
    require(isinstance(before, dict) and isinstance(after, dict), "target values missing")
    empty, populated = (before, after) if operation == "add" else (after, before)
    require(empty.get("rules") == [] and isinstance(populated.get("rules"), list)
            and len(populated["rules"]) == 1, "expected exactly one rule and one empty ruleset")
    for key in set(before) | set(after):
        if key not in {"rules", "last_updated", "version"}:
            require(key in before and key in after and before[key] == after[key],
                    "unrelated ruleset attribute changed")
    require(isinstance(before.get("id"), str) and bool(before["id"])
            and isinstance(expected_zone_id, str) and bool(expected_zone_id)
            and before.get("zone_id") == expected_zone_id
            and before.get("kind") == "zone"
            and before.get("phase") == "http_config_settings"
            and isinstance(before.get("name"), str)
            and before["name"].startswith("origin-tls-"), "unexpected ruleset identity")

    rule = populated["rules"][0]
    require(isinstance(rule, dict), "rule is not an object")
    expected = {
        "ref": "origin_strict_redirect_xtremeidiots_net",
        "description": f"Validate the origin certificate for {HOST}",
        "expression": f'http.host eq "{HOST}"',
        "action": "set_config",
        "enabled": True,
    }
    for key, value in expected.items():
        require(rule.get(key) == value and type(rule.get(key)) is type(value), f"unexpected rule {key}")
    if operation == "add":
        require(rule.get("id") is None, "new rule id must be provider-generated")
    else:
        require(isinstance(rule.get("id"), str) and bool(rule["id"]),
                "existing rule id missing")
    params = rule.get("action_parameters")
    require(isinstance(params, dict) and params.get("ssl") == "strict"
            and all(key == "ssl" or value is None for key, value in params.items()),
            "unexpected rule action parameters")
    require(all(key in {*expected, "action_parameters", "id"} or value is None
                for key, value in rule.items()), "unexpected additional rule setting")

    unknown = change.get("after_unknown")
    require(isinstance(unknown, dict), "unknown-value map missing")
    unknown = dict(unknown)
    for key in ("last_updated", "version"):
        flag = unknown.pop(key, False)
        require((flag is True and after.get(key) is None)
                or (not has_unknown(flag) and after.get(key) == before.get(key)),
                "unexpected ruleset metadata change")
    require(rule.get("logging") is None, "rule logging must be omitted")
    if operation == "add":
        rule_unknown = unknown.pop("rules", None)
        require(isinstance(rule_unknown, list) and len(rule_unknown) == 1
                and isinstance(rule_unknown[0], dict), "rule unknown-value map missing")
        rule_unknown = dict(rule_unknown[0])
        require(rule_unknown.pop("id", None) is True, "new rule id is not provider-generated")
        logging_unknown = rule_unknown.pop("logging", False)
        require(logging_unknown is True or logging_unknown is False,
                "unexpected rule logging unknown shape")
        require(not has_unknown(rule_unknown), "unknown critical or additional rule value")
    require(not has_unknown(unknown), "unknown critical or additional value")


def main():
    try:
        zone_file = Path(__file__).resolve().parents[1] / "zones" / "xtremeidiots.net.json"
        with zone_file.open(encoding="utf-8") as file:
            expected_zone_id = json.load(file)["zone_id"]
        if len(sys.argv) != 2 or sys.argv[1] not in {"add", "remove"}:
            raise Rejected("invalid arguments")
        validate(json.load(sys.stdin), expected_zone_id, sys.argv[1])
        print("Strict TLS plan scope accepted.")
    except (Rejected, ValueError, TypeError, KeyError) as error:
        print(f"Strict TLS plan rejected: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
