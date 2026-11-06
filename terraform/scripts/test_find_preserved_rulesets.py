import copy
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.parse import urlparse

from find_preserved_rulesets import discover


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOTS = json.loads((ROOT / "zones" / "xtremeidiots.com.json").read_text())["preserved_rulesets"]
ZONE = "0" * 32
TARGETS = [
    {"id": str(index + 1) * 32, "name": rule["action_parameters"]["target_name"], "kind": "managed"}
    for index, rule in enumerate(SNAPSHOTS["http_request_firewall_managed"]["rules"])
]
ENTRYPOINTS = {}
for index, (phase, snapshot) in enumerate(SNAPSHOTS.items()):
    rules = copy.deepcopy(snapshot["rules"])
    for number, rule in enumerate(rules):
        rule["id"] = f"{number + 10:032x}"
        rule["ref"] = rule["id"]
        rule["version"] = "1"
        rule["last_updated"] = "2026-01-01T00:00:00Z"
        if rule["action"] == "execute":
            name = rule["action_parameters"].pop("target_name")
            rule["action_parameters"]["id"] = next(target["id"] for target in TARGETS if target["name"] == name)
    ENTRYPOINTS[phase] = {
        "id": f"{index + 100:032x}", "name": snapshot["name"],
        "description": snapshot["description"], "kind": "zone", "phase": phase, "rules": rules,
    }
TARGETS += [
    {key: entry[key] for key in ("id", "name", "kind", "phase")}
    for entry in ENTRYPOINTS.values()
]
TARGETS += [
    {"id": "d" * 32, "name": "default", "kind": "zone", "phase": "http_request_firewall_custom"},
    {"id": "e" * 32, "name": "platform-status-origin-tls",
     "kind": "zone", "phase": "http_config_settings"},
]


class PreservedRulesetTests(unittest.TestCase):
    def run_discovery(self, entrypoints, targets=TARGETS, result_info=None):
        def response(request, timeout):
            path = urlparse(request.full_url).path
            self.assertEqual(request.get_method(), "GET")
            if path.endswith("/rulesets"):
                result = targets
            else:
                phase = path.split("/")[-2]
                result = entrypoints[phase]
            return io.BytesIO(json.dumps({
                "success": True, "result": result,
                "result_info": result_info if path.endswith("/rulesets") else None,
            }).encode())

        with patch("urllib.request.urlopen", side_effect=response):
            return discover({"zone_id": ZONE, "rulesets": json.dumps(SNAPSHOTS)}, "disposable-token")

    def test_exact_snapshot_returns_import_ids_and_provider_rules(self):
        result = self.run_discovery(ENTRYPOINTS)
        for phase in SNAPSHOTS:
            self.assertEqual(result[f"{phase}_id"], ENTRYPOINTS[phase]["id"])
            rules = json.loads(result[f"{phase}_rules"])
            self.assertEqual([rule["ref"] for rule in rules],
                             [rule["id"] for rule in ENTRYPOINTS[phase]["rules"]])
        managed = json.loads(result["http_request_firewall_managed_rules"])
        self.assertEqual(managed[0]["action_parameters"], {"id": TARGETS[0]["id"]})

    def test_unreviewed_rule_changes_fail_closed(self):
        variants = []
        for phase, mutate in (
            ("http_ratelimit", lambda r: r["rules"][0]["ratelimit"].update(requests_per_period=20)),
            ("http_ratelimit", lambda r: r["rules"].reverse()),
            ("http_request_dynamic_redirect", lambda r: r["rules"][0].update(expression="true")),
            ("http_request_firewall_managed", lambda r: r["rules"][0]["action_parameters"].update(version="1")),
            ("http_request_firewall_managed", lambda r: r["rules"][0].update(ref="e" * 32)),
            ("http_request_firewall_managed", lambda r: r["rules"][0].update(extra=True)),
        ):
            entrypoints = copy.deepcopy(ENTRYPOINTS)
            mutate(entrypoints[phase])
            variants.append(entrypoints)
        for entrypoints in variants:
            with self.subTest(entrypoints=entrypoints), self.assertRaises(ValueError):
                self.run_discovery(entrypoints)

    def test_incomplete_or_ambiguous_targets_fail_closed(self):
        for targets, info in (
            (TARGETS[:-1], None),
            (TARGETS + [dict(TARGETS[0], id="f" * 32)], None),
            (TARGETS, {"total_count": len(TARGETS) + 1}),
            (TARGETS, {"cursors": {"after": "next"}}),
            (TARGETS, {"cursors": "malformed"}),
            (TARGETS + [{"id": "f" * 32, "name": "new", "kind": "zone", "phase": "http_request_cache_settings"}], None),
        ):
            with self.subTest(targets=targets, info=info), self.assertRaises(ValueError):
                self.run_discovery(ENTRYPOINTS, targets, info)


if __name__ == "__main__":
    unittest.main()
