import copy
import unittest

from guard_ordinary_prd_plan import validate, validate_noop
from guard_strict_tls_plan import Rejected
from test_guard_strict_tls_plan import valid_plan


def ordinary_plan():
    plan = valid_plan()
    change = plan["resource_changes"][0]["change"]
    change["actions"] = ["no-op"]
    change["after"] = copy.deepcopy(change["before"])
    change["after_unknown"] = {}
    plan["resource_changes"].append({
        "address": "cloudflare_dns_record.unrelated",
        "change": {"actions": ["update"]},
    })
    return plan


class OrdinaryGuardTest(unittest.TestCase):
    def test_development_noop_without_production_target(self):
        plan = ordinary_plan()
        plan["resource_changes"] = [{
            "address": "azurerm_resource_group.dns",
            "change": {"actions": ["no-op"], "before": {"name": "dev"},
                       "after": {"name": "dev"}, "after_unknown": {}},
        }]
        validate_noop(plan)
        plan["resource_changes"][0]["change"]["actions"] = ["update"]
        with self.assertRaises(Rejected):
            validate_noop(plan)

    def test_unrelated_update_is_allowed(self):
        validate(ordinary_plan(), "existing-zone")

    def test_empty_plan_is_allowed(self):
        plan = ordinary_plan()
        plan["applyable"] = False
        plan["resource_changes"].pop()
        validate(plan, "existing-zone")
        validate(plan, "existing-zone", require_noop=True)

    def test_preparation_merge_rejects_all_unrelated_mutations(self):
        plan = ordinary_plan()
        with self.assertRaises(Rejected):
            validate(plan, "existing-zone", require_noop=True)
        validate(plan, "existing-zone")

    def test_preparation_merge_rejects_uncertain_or_unrelated_changes(self):
        for scenario in ("drift", "resource-update", "resource-read", "resource-unknown",
                         "missing-unknown", "null-unknown", "nested-null-unknown",
                         "different-values", "missing-values",
                         "import", "move", "generated", "output", "output-unknown", "checks",
                         "output-null-unknown",
                         "deferred", "invocation"):
            with self.subTest(scenario=scenario):
                plan = ordinary_plan()
                plan["resource_changes"].pop()
                other = {"address": "other", "change": {
                    "actions": ["no-op"], "before": {"x": 1}, "after": {"x": 1}, "after_unknown": {},
                }}
                plan["resource_changes"].append(other)
                if scenario == "drift":
                    plan["resource_drift"] = [{"address": "other"}]
                elif scenario == "resource-update":
                    other["change"]["actions"] = ["update"]
                elif scenario == "resource-read":
                    other["change"]["actions"] = ["read"]
                elif scenario == "resource-unknown":
                    other["change"]["after_unknown"] = {"x": True}
                elif scenario == "missing-unknown":
                    del other["change"]["after_unknown"]
                elif scenario == "null-unknown":
                    other["change"]["after_unknown"] = None
                elif scenario == "nested-null-unknown":
                    other["change"]["after_unknown"] = {"x": [None]}
                elif scenario == "different-values":
                    other["change"]["after"] = {"x": 2}
                elif scenario == "missing-values":
                    del other["change"]["before"]
                elif scenario == "import":
                    other["change"]["importing"] = {"id": "id"}
                elif scenario == "move":
                    other["previous_address"] = "old"
                elif scenario == "generated":
                    other["change"]["generated_config"] = "config"
                elif scenario == "output":
                    plan["output_changes"] = {"x": {"actions": ["update"]}}
                elif scenario == "output-unknown":
                    plan["output_changes"] = {"x": {"actions": ["no-op"], "before": 1, "after": 1, "after_unknown": True}}
                elif scenario == "output-null-unknown":
                    plan["output_changes"] = {"x": {"actions": ["no-op"], "before": 1, "after": 1, "after_unknown": None}}
                elif scenario == "checks":
                    plan["checks"] = [{"status": "unknown"}]
                elif scenario == "deferred":
                    plan["deferred_changes"] = [{}]
                else:
                    plan["action_invocations"] = [{}]
                with self.assertRaises(Rejected):
                    validate(plan, "existing-zone", require_noop=True)

    def test_target_addition_is_rejected(self):
        with self.assertRaises(Rejected):
            validate(valid_plan(), "existing-zone")

    def test_target_mutations_and_uncertainty_are_rejected(self):
        for scenario in ("missing", "duplicate", "changed", "unknown", "missing-unknown", "wrong-zone",
                         "import", "moved", "moved-away", "target-drift",
                         "deferred", "incomplete", "unsupported"):
            with self.subTest(scenario=scenario):
                plan = ordinary_plan()
                target = plan["resource_changes"][0]
                if scenario == "missing":
                    plan["resource_changes"].pop(0)
                elif scenario == "duplicate":
                    plan["resource_changes"].append(copy.deepcopy(target))
                elif scenario == "changed":
                    target["change"]["after"]["rules"] = [{"enabled": True}]
                elif scenario == "unknown":
                    target["change"]["after_unknown"] = {"rules": True}
                elif scenario == "missing-unknown":
                    del target["change"]["after_unknown"]
                elif scenario == "wrong-zone":
                    target["change"]["before"]["zone_id"] = "other"
                    target["change"]["after"]["zone_id"] = "other"
                elif scenario == "import":
                    target["change"]["importing"] = {"id": "id"}
                elif scenario == "moved":
                    target["previous_address"] = "old"
                elif scenario == "moved-away":
                    plan["resource_changes"][1]["previous_address"] = target["address"]
                elif scenario == "target-drift":
                    plan["resource_drift"] = [{"address": target["address"]}]
                elif scenario == "deferred":
                    plan["deferred_changes"] = [{}]
                elif scenario == "incomplete":
                    plan["complete"] = False
                else:
                    plan["format_version"] = "2.0"
                with self.assertRaises(Rejected):
                    validate(plan, "existing-zone")


if __name__ == "__main__":
    unittest.main()
