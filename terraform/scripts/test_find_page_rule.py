import copy
import io
import json
import os
import unittest
from unittest.mock import patch
import urllib.error

from find_page_rule import find_rule, main


QUERY = {
    "zone_id": "0" * 32, "target": "https://example.test/*",
    "actions": json.dumps({
        "ssl": "flexible", "automatic_https_rewrites": "on",
        "disable_apps": True, "disable_performance": True,
    }),
    "priority": "1", "status": "active",
    "require_match": "false",
}
RULE = {
    "id": "1" * 32, "priority": 1, "status": "active",
    "targets": [{"target": "url", "constraint": {"operator": "matches", "value": QUERY["target"]}}],
    "actions": [
        {"id": "disable_performance"},
        {"id": "ssl", "value": "flexible"},
        {"id": "automatic_https_rewrites", "value": "on"},
        {"id": "disable_apps"},
    ],
}
LEGACY_QUERY = {
    "zone_id": "0" * 32,
    "target": "https://example.test/*",
    "actions": json.dumps({
        "forwarding_url": {"url": "https://www.example.test/", "status_code": 301},
    }),
    "priority": "1",
    "status": "active,disabled",
    "require_match": "true",
}
LEGACY_RULE = {
    "id": "2" * 32, "priority": 1, "status": "active",
    "targets": [{"target": "url", "constraint": {"operator": "matches", "value": LEGACY_QUERY["target"]}}],
    "actions": [{"id": "forwarding_url", "value": {"url": "https://www.example.test/", "status_code": 301}}],
}


class DiscoveryTests(unittest.TestCase):
    def discover(self, rules, **metadata):
        response = io.BytesIO(json.dumps({"success": True, "result": rules, **metadata}).encode())
        with patch("urllib.request.urlopen", return_value=response) as request:
            result = find_rule(QUERY, "disposable-token")
            self.assertEqual(request.call_args.args[0].get_method(), "GET")
            self.assertEqual(
                request.call_args.args[0].get_header("Authorization"),
                "Bearer disposable-token",
            )
            return result

    def test_exact_rule_can_be_adopted_without_changing_other_rules(self):
        unrelated = {**RULE, "targets": []}
        self.assertEqual(self.discover([unrelated, RULE]), {"id": RULE["id"]})

    def test_legacy_redirect_lookup_accepts_active_or_disabled_status(self):
        for status in ("active", "disabled"):
            query = {**LEGACY_QUERY}
            rule = {**LEGACY_RULE, "status": status}
            response = io.BytesIO(json.dumps({"success": True, "result": [rule]}).encode())
            with self.subTest(status=status), patch("urllib.request.urlopen", return_value=response):
                self.assertEqual(find_rule(query, "disposable-token"), {"id": LEGACY_RULE["id"]})

    def test_missing_generic_rule_is_created_but_ambiguity_and_incomplete_inventory_fail(self):
        self.assertEqual(self.discover([]), {"id": ""})
        for rules, metadata in (
            ([RULE, RULE], {}),
            ([RULE], {"result_info": {"total_count": 2}}),
        ):
            with self.subTest(rules=rules, metadata=metadata), self.assertRaises(ValueError):
                self.discover(rules, **metadata)

    def test_required_legacy_redirect_rejects_missing_rule(self):
        response = io.BytesIO(json.dumps({"success": True, "result": []}).encode())
        with patch("urllib.request.urlopen", return_value=response), \
                self.assertRaises(ValueError):
            find_rule(LEGACY_QUERY, "disposable-token")

    def test_unreviewed_action_priority_or_status_cannot_be_overwritten(self):
        variants = [
            dict(RULE, priority=2),
            dict(RULE, actions=[]),
            dict(RULE, status="disabled"),
        ]
        changed_target = copy.deepcopy(RULE)
        changed_target["actions"][0]["value"] = "flexible"
        variants.append(changed_target)
        for rule in variants:
            with self.subTest(rule=rule), self.assertRaises(ValueError):
                self.discover([rule])

    def test_http_failure_does_not_expose_token_or_response_details(self):
        output, errors = io.StringIO(), io.StringIO()
        failure = urllib.error.HTTPError("https://api.cloudflare.com", 403,
                                        "sensitive-detail", {}, None)
        with patch("sys.stdin", io.StringIO(json.dumps(QUERY))), \
                patch("sys.stdout", output), patch("sys.stderr", errors), \
                patch.dict(os.environ, {"TF_VAR_cloudflare_api_token": "private-token"}), \
                patch("urllib.request.urlopen", side_effect=failure):
            self.assertEqual(main(), 1)
        self.assertEqual(output.getvalue(), "")
        self.assertNotIn("sensitive-detail", errors.getvalue())
        self.assertNotIn("private-token", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
