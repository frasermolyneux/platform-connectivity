#!/usr/bin/env python3
"""Compare a live Cloudflare ruleset with its reviewed Terraform snapshot."""

import json
import sys


def _without_nulls(value):
    if isinstance(value, dict):
        cleaned = {}
        for key, item in value.items():
            if item is None or (key == "requests_to_origin" and item is False):
                continue
            normalized = _without_nulls(item)
            if normalized is not None:
                cleaned[key] = normalized
        return cleaned or None
    if isinstance(value, list):
        return [_without_nulls(item) for item in value]
    return value


def _effective_snapshot(snapshot):
    effective = json.loads(json.dumps(snapshot))
    for rule in effective["rules"]:
        rule.setdefault("enabled", True)
        rule.setdefault("description", "")
    return effective


def _differences(expected, actual, path=""):
    expected = _without_nulls(expected)
    actual = _without_nulls(actual)
    if path.endswith(".action_parameters.version") and expected == "latest" and isinstance(actual, str):
        return []
    if isinstance(expected, dict) and isinstance(actual, dict):
        differences = []
        for key in sorted(set(expected) | set(actual)):
            child_path = f"{path}.{key}" if path else key
            if (
                key == "action_parameters"
                and child_path.endswith(".action_parameters")
                and isinstance(expected.get(key), dict)
                and expected[key].get("version") == "latest"
            ):
                expected_parameters = dict(expected[key])
                actual_parameters = dict(actual.get(key, {}))
                expected_parameters.pop("version")
                if isinstance(actual_parameters.get("version"), str):
                    actual_parameters.pop("version")
                differences.extend(_differences(expected_parameters, actual_parameters, child_path))
                continue
            if (
                child_path.endswith(".action_parameters.version")
                and expected.get(key) == "latest"
                and key not in actual
            ):
                continue
            if key not in expected or key not in actual:
                differences.append(child_path)
            else:
                differences.extend(_differences(expected[key], actual[key], child_path))
        return differences
    if isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            return [f"{path}.length"]
        differences = []
        for index, (expected_item, actual_item) in enumerate(zip(expected, actual)):
            differences.extend(_differences(expected_item, actual_item, f"{path}[{index}]"))
        return differences
    return [] if expected == actual else [path]


def main():
    query = json.load(sys.stdin)
    expected = _effective_snapshot(json.loads(query["expected"]))
    actual = json.loads(query["actual"])
    expected["rules"] = [
        {key: value for key, value in rule.items() if key not in {"id", "categories"}}
        for rule in expected["rules"]
    ]
    actual["rules"] = [
        {key: value for key, value in rule.items() if key not in {"id", "categories"}}
        for rule in actual["rules"]
    ]
    differences = _differences(expected, actual)
    print(json.dumps({
        "matches": str(not differences).lower(),
        "differences": json.dumps(differences, separators=(",", ":")),
    }))


if __name__ == "__main__":
    main()
