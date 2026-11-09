import copy
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

from guard_strict_tls_plan import ADDRESS, Rejected, validate as validate_with_zone


def validate(plan):
    return validate_with_zone(plan, "existing-zone")


def valid_plan():
    before = {
        "id": "existing", "zone_id": "existing-zone", "name": "origin-tls-owner",
        "kind": "zone", "phase": "http_config_settings", "description": "existing",
        "last_updated": "earlier", "version": "2", "rules": [],
    }
    after = {**before, "last_updated": None, "version": None, "rules": [{
        "ref": "origin_strict_redirect_xtremeidiots_net",
        "description": "Validate the origin certificate for redirect.xtremeidiots.net",
        "expression": 'http.host eq "redirect.xtremeidiots.net"',
        "action": "set_config", "enabled": True,
        "action_parameters": {"ssl": "strict", "other": None},
    }]}
    return {
        "format_version": "1.2", "complete": True, "applyable": True, "errored": False,
        "resource_changes": [{
            "address": ADDRESS, "mode": "managed", "type": "cloudflare_ruleset",
            "change": {
                "actions": ["update"], "before": before, "after": after,
                "after_unknown": {
                    "last_updated": True, "version": True, "rules": [{"id": True}],
                },
            },
        }],
    }


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.plan = valid_plan()
        self.resource = self.plan["resource_changes"][0]
        self.change = self.resource["change"]

    def reject(self):
        with self.assertRaises(Rejected):
            validate(self.plan)

    def test_exact_change_is_accepted(self):
        validate(self.plan)

    def test_other_resources_and_drift_are_rejected(self):
        for field in ("resource_drift", "deferred_changes"):
            with self.subTest(field=field):
                plan = valid_plan()
                plan[field] = [{"change": {"actions": ["update"]}}]
                with self.assertRaises(Rejected):
                    validate(plan)
        self.plan["resource_changes"].append({"address": "other", "change": {"actions": ["create"]}})
        self.reject()

    def test_unknown_unrelated_resource_is_rejected(self):
        self.plan["resource_changes"].append({
            "address": "other",
            "change": {"actions": ["no-op"], "after_unknown": {"value": True}},
        })
        self.reject()

    def test_import_moves_and_replacements_are_rejected(self):
        for edit in ("import", "move", "replace", "delete"):
            with self.subTest(edit=edit):
                plan = valid_plan()
                resource = plan["resource_changes"][0]
                if edit == "import":
                    resource["change"]["importing"] = {"id": "example"}
                elif edit == "move":
                    resource["previous_address"] = "previous"
                else:
                    resource["change"]["actions"] = ["delete", "create"] if edit == "replace" else ["delete"]
                with self.assertRaises(Rejected):
                    validate(plan)

    def test_only_new_rule_unknown_logging_is_accepted(self):
        self.change["after_unknown"]["rules"][0]["logging"] = True
        validate(self.plan)
        self.change["after"]["rules"][0]["logging"] = {"enabled": False}
        self.reject()

    def test_unknown_critical_and_nested_logging_values_are_rejected(self):
        for unknown in ({"expression": True}, {"logging": {"enabled": True}},
                        {"action_parameters": {"ssl": True}}):
            with self.subTest(unknown=unknown):
                plan = valid_plan()
                plan["resource_changes"][0]["change"]["after_unknown"]["rules"][0].update(unknown)
                with self.assertRaises(Rejected):
                    validate(plan)

    def test_unrelated_rule_and_ruleset_settings_are_rejected(self):
        for enabled in (True, False):
            with self.subTest(enabled=enabled):
                self.change["after"]["rules"][0]["logging"] = {"enabled": enabled}
                self.reject()
        self.plan = valid_plan()
        self.plan["resource_changes"][0]["change"]["after"]["zone_id"] = "different"
        self.reject()

    def test_wrong_zone_binding_is_rejected(self):
        self.change["before"]["zone_id"] = "different"
        self.change["after"]["zone_id"] = "different"
        self.reject()

    def test_missing_or_multiple_rules_are_rejected(self):
        for rules in ([], [self.change["after"]["rules"][0]] * 2):
            self.change["after"]["rules"] = rules
            self.reject()

    def test_wrong_rule_and_output_changes_are_rejected(self):
        self.change["after"]["rules"][0]["action_parameters"]["ssl"] = "full"
        self.reject()
        self.plan = valid_plan()
        self.plan["output_changes"] = {"x": {"actions": ["update"]}}
        self.reject()

    def test_incomplete_plan_or_missing_resource_are_rejected(self):
        for key in ("complete", "applyable"):
            plan = copy.deepcopy(self.plan)
            plan[key] = False
            with self.assertRaises(Rejected):
                validate(plan)
        self.plan["resource_changes"] = []
        self.reject()

    def test_unknown_checks_and_action_invocations_are_rejected(self):
        for field, value in (
            ("checks", [{"status": "unknown"}]),
            ("action_invocations", [{"action": "invoke"}]),
            ("deferred_actions", [{"action": "invoke"}]),
            ("output_changes", {"x": {"actions": ["no-op"], "after_unknown": True}}),
        ):
            with self.subTest(field=field):
                plan = valid_plan()
                plan[field] = value
                with self.assertRaises(Rejected):
                    validate(plan)

    def test_generated_metadata_is_not_a_free_pass(self):
        self.change["after"]["rules"][0]["id"] = "existing-rule"
        self.reject()
        self.plan = valid_plan()
        self.plan["resource_changes"][0]["change"]["after"]["version"] = "unexpected"
        self.reject()


class GuardCliTest(unittest.TestCase):
    root = Path(__file__).resolve().parents[2]

    def cli(self, plan, operation="add"):
        return subprocess.run(
            [sys.executable, str(self.root / "terraform" / "scripts" / "guard_strict_tls_plan.py"),
             operation],
            input=json.dumps(plan), capture_output=True, text=True,
        )

    def plan(self, operation="add"):
        plan = valid_plan()
        plan["planned_values"] = {"root_module": {"resources": [
            {
                "address": 'cloudflare_zone.managed["xtremeidiots.net"]',
                "mode": "managed", "type": "cloudflare_zone",
                "values": {"name": "xtremeidiots.net", "id": "existing-zone"},
            },
            {
                "address": 'data.cloudflare_zone.adopt["xtremeidiots.net"]',
                "mode": "data", "type": "cloudflare_zone",
                "values": {"name": "xtremeidiots.net", "zone_id": "existing-zone"},
            },
        ]}}
        if operation == "remove":
            change = plan["resource_changes"][0]["change"]
            empty, populated = change["before"], change["after"]
            populated["rules"][0]["id"] = "synthetic-existing-rule"
            change["before"] = {**populated, "last_updated": "earlier", "version": "2"}
            change["after"] = {**empty, "last_updated": None, "version": None}
            change["after_unknown"] = {"last_updated": True, "version": True}
        return plan

    def test_cli_accepts_add_and_remove_without_a_committed_zone_identifier(self):
        for operation in ("add", "remove"):
            with self.subTest(operation=operation):
                result = self.cli(self.plan(operation), operation)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("scope accepted", result.stdout)

    def test_cli_rejects_missing_ambiguous_mismatched_and_unknown_discovery(self):
        for case in ("missing", "ambiguous", "wrong_id", "wrong_name", "unknown"):
            with self.subTest(case=case):
                plan = self.plan()
                resources = plan["planned_values"]["root_module"]["resources"]
                if case == "missing":
                    resources.pop()
                elif case == "ambiguous":
                    resources.append(copy.deepcopy(resources[-1]))
                elif case == "wrong_name":
                    resources[-1]["values"]["name"] = "unrelated.invalid"
                else:
                    resources[-1]["values"]["zone_id"] = None if case == "unknown" else "other-zone"
                self.assertNotEqual(self.cli(plan).returncode, 0)

    def test_cli_rejects_target_bound_to_a_different_zone(self):
        plan = self.plan()
        change = plan["resource_changes"][0]["change"]
        for key in ("before", "after"):
            change[key]["zone_id"] = "other-zone"
        self.assertNotEqual(self.cli(plan).returncode, 0)

    def test_workflow_binds_both_checks_to_the_current_origin_tls_source(self):
        workflow = (self.root / ".github" / "workflows" / "deploy-strict-origin-tls.yml").read_text()
        bindings = re.findall(
            r'git hash-object terraform/cloudflare_origin_tls.tf\)" = "([0-9a-f]{40})"',
            workflow,
        )
        current = subprocess.check_output(
            ["git", "hash-object", "terraform/cloudflare_origin_tls.tf"],
            cwd=self.root, text=True,
        ).strip()
        self.assertEqual(bindings, [current, current])


if __name__ == "__main__":
    unittest.main()
