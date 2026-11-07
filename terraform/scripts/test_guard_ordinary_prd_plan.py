import copy
import unittest

from guard_ordinary_prd_plan import validate
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
    def test_unrelated_update_is_allowed(self):
        validate(ordinary_plan(), "existing-zone")

    def test_empty_plan_is_allowed(self):
        plan = ordinary_plan()
        plan["applyable"] = False
        plan["resource_changes"].pop()
        validate(plan, "existing-zone")

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
