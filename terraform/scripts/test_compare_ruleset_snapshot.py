import json
import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("compare_ruleset_snapshot.py")


def compare(expected, actual):
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps({"expected": json.dumps(expected), "actual": json.dumps(actual)}),
        capture_output=True,
        check=True,
        text=True,
    )
    return json.loads(result.stdout)["matches"] == "true"


class RulesetSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.expected = {
            "name": "Synthetic rate limit",
            "description": "Test-only ruleset",
            "kind": "zone",
            "phase": "http_ratelimit",
            "rules": [{
                "ref": "synthetic-rate-limit",
                "action": "managed_challenge",
                "description": "Synthetic challenge",
                "enabled": True,
                "expression": '(http.host eq "api.example.test")',
                "ratelimit": {
                    "characteristics": ["ip.src"],
                    "mitigation_timeout": 60,
                    "period": 60,
                    "requests_per_period": 10,
                },
            }],
        }

    def test_exact_snapshot_ignores_only_provider_metadata_and_nulls(self):
        actual = json.loads(json.dumps(self.expected))
        actual["rules"][0]["id"] = "fake-rule-id"
        actual["rules"][0]["categories"] = []
        actual["rules"][0]["logging"] = None
        actual["rules"][0]["action_parameters"] = {}
        actual["rules"][0]["ratelimit"] = dict(
            actual["rules"][0]["ratelimit"],
            requests_to_origin=False,
        )

        self.assertTrue(compare(self.expected, actual))

    def test_extra_live_rule_is_rejected(self):
        actual = json.loads(json.dumps(self.expected))
        actual["rules"].append(dict(actual["rules"][0], id="another-id"))

        self.assertFalse(compare(self.expected, actual))

    def test_rule_expression_or_order_drift_is_rejected(self):
        changed = json.loads(json.dumps(self.expected))
        changed["rules"][0]["expression"] = "true"
        self.assertFalse(compare(self.expected, changed))

        second = dict(changed["rules"][0], ref="second-rule")
        multiple = json.loads(json.dumps(self.expected))
        multiple["rules"].append(second)
        multiple["rules"].reverse()
        self.assertFalse(compare(self.expected, multiple))

    def test_nested_action_parameter_drift_is_rejected(self):
        expected = json.loads(json.dumps(self.expected))
        expected["rules"][0]["action_parameters"] = {"id": "managed-rule-set"}
        actual = json.loads(json.dumps(expected))
        actual["rules"][0]["action_parameters"]["id"] = "different-rule-set"

        self.assertFalse(compare(expected, actual))

    def test_latest_managed_rules_version_accepts_provider_resolved_version(self):
        expected = json.loads(json.dumps(self.expected))
        expected["rules"][0]["action_parameters"] = {"version": "latest"}
        actual = json.loads(json.dumps(expected))
        actual["rules"][0]["action_parameters"]["version"] = "2026-10-01"

        self.assertTrue(compare(expected, actual))

        actual["rules"][0]["action_parameters"].pop("version")
        self.assertTrue(compare(expected, actual))

        expected["rules"][0]["action_parameters"]["version"] = "2026-09-01"
        actual["rules"][0]["action_parameters"]["version"] = "2026-10-01"
        self.assertFalse(compare(expected, actual))

    def test_computed_rule_ids_are_ignored_but_nested_ids_are_not(self):
        expected = json.loads(json.dumps(self.expected))
        expected["rules"][0]["action_parameters"] = {"id": "managed-rule-set"}
        actual = json.loads(json.dumps(self.expected))
        actual["rules"][0]["id"] = "provider-rule-id"
        actual["rules"][0]["action_parameters"] = {"id": "managed-rule-set"}
        self.assertTrue(compare(expected, actual))

        actual["rules"][0]["action_parameters"]["id"] = "different-rule-set"
        self.assertFalse(compare(self.expected, actual))


if __name__ == "__main__":
    unittest.main()
