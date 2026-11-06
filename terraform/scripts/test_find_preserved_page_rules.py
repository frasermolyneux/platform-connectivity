import copy
import io
import json
import unittest
from unittest.mock import patch

from find_preserved_page_rules import discover


SNAPSHOTS = {
    "first": {
        "target": "*a.example.test/*",
        "priority": 2,
        "status": "active",
        "actions": {"ssl": "flexible", "disable_apps": True},
        "api_actions": [{"id": "ssl", "value": "flexible"}, {"id": "disable_apps"}],
    },
    "second": {
        "target": "https://b.example.test/*",
        "priority": 1,
        "status": "active",
        "actions": {"ssl": "full"},
        "api_actions": [{"id": "ssl", "value": "full"}],
    },
}
QUERY = {"zone_id": "0" * 32, "rules": json.dumps(SNAPSHOTS)}
RULES = [
    {
        "id": str(index + 1) * 32,
        "targets": [{"target": "url", "constraint": {"operator": "matches", "value": rule["target"]}}],
        "actions": rule["api_actions"],
        "priority": rule["priority"],
        "status": rule["status"],
    }
    for index, rule in enumerate(SNAPSHOTS.values())
]


class PreservedPageRuleTests(unittest.TestCase):
    def run_discovery(self, rules, **metadata):
        response = io.BytesIO(json.dumps({"success": True, "result": rules, **metadata}).encode())
        with patch("urllib.request.urlopen", return_value=response) as request:
            result = discover(QUERY, "disposable-token")
            self.assertEqual(request.call_args.args[0].get_method(), "GET")
            return result

    def test_exact_snapshot(self):
        self.assertEqual(self.run_discovery(RULES), {"first": "1" * 32, "second": "2" * 32})

    def test_missing_extra_duplicate_truncated_or_changed_rules_fail_closed(self):
        variants = [RULES[:1], RULES + [RULES[0]], [RULES[0], RULES[0]]]
        for field, value in (("priority", 9), ("status", "disabled"), ("actions", [])):
            changed = copy.deepcopy(RULES)
            changed[0][field] = value
            variants.append(changed)
        for rules in variants:
            with self.subTest(rules=rules), self.assertRaises(ValueError):
                self.run_discovery(rules)
        with self.assertRaises(ValueError):
            self.run_discovery(RULES, result_info={"total_count": 3})

    def test_inconsistent_desired_actions_fail_closed(self):
        expected = copy.deepcopy(SNAPSHOTS)
        expected["first"]["actions"]["ssl"] = "strict"
        response = io.BytesIO(json.dumps({"success": True, "result": RULES}).encode())
        with patch("urllib.request.urlopen", return_value=response), self.assertRaises(ValueError):
            discover({**QUERY, "rules": json.dumps(expected)}, "disposable-token")

    def test_duplicate_snapshot_cannot_claim_same_live_rule_twice(self):
        snapshots = {"first": SNAPSHOTS["first"], "duplicate": SNAPSHOTS["first"]}
        response = io.BytesIO(json.dumps({"success": True, "result": RULES}).encode())
        with patch("urllib.request.urlopen", return_value=response), self.assertRaises(ValueError):
            discover({**QUERY, "rules": json.dumps(snapshots)}, "disposable-token")


if __name__ == "__main__":
    unittest.main()
