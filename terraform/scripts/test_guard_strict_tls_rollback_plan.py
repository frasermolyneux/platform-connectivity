import copy
import unittest

from guard_strict_tls_plan import Rejected, validate
from test_guard_strict_tls_plan import valid_plan


def rollback_plan():
    plan = valid_plan()
    change = plan["resource_changes"][0]["change"]
    before = copy.deepcopy(change["after"])
    before["rules"][0]["id"] = "existing-rule"
    before["last_updated"], before["version"] = "earlier", "2"
    change["before"] = before
    change["after"] = {**before, "rules": [], "last_updated": None, "version": None}
    change["after_unknown"] = {"last_updated": True, "version": True, "rules": []}
    return plan


class RollbackGuardTest(unittest.TestCase):
    def test_exact_removal_only(self):
        plan = rollback_plan()
        validate(plan, "existing-zone", "remove")
        with self.assertRaises(Rejected):
            validate(plan, "existing-zone", "add")
        with self.assertRaises(Rejected):
            validate(valid_plan(), "existing-zone", "remove")

    def test_rejects_other_changes_and_uncertainty(self):
        for scenario in (
            "extra-rule", "wrong-host", "wrong-ssl", "wrong-ref", "disabled",
            "missing-id", "enabled-logging", "disabled-logging", "extra-setting",
            "wrong-zone", "target-setting", "unrelated", "unknown-rule", "unknown-target",
            "drift", "import", "move", "replace", "delete", "deferred", "output", "check",
        ):
            with self.subTest(scenario=scenario):
                plan = rollback_plan()
                target = plan["resource_changes"][0]
                change = target["change"]
                rule = change["before"]["rules"][0]
                if scenario == "extra-rule":
                    change["before"]["rules"].append(copy.deepcopy(rule))
                elif scenario == "wrong-host":
                    rule["expression"] = 'http.host eq "other.example"'
                elif scenario == "wrong-ssl":
                    rule["action_parameters"]["ssl"] = "full"
                elif scenario == "wrong-ref":
                    rule["ref"] = "other"
                elif scenario == "disabled":
                    rule["enabled"] = False
                elif scenario == "missing-id":
                    rule["id"] = None
                elif scenario in ("enabled-logging", "disabled-logging"):
                    rule["logging"] = {"enabled": scenario == "enabled-logging"}
                elif scenario == "extra-setting":
                    rule["action_parameters"]["other"] = True
                elif scenario == "wrong-zone":
                    change["before"]["zone_id"] = change["after"]["zone_id"] = "wrong"
                elif scenario == "target-setting":
                    change["after"]["description"] = "changed"
                elif scenario == "unrelated":
                    plan["resource_changes"].append({"address": "other", "change": {"actions": ["update"]}})
                elif scenario == "unknown-rule":
                    change["after_unknown"]["rules"] = True
                elif scenario == "unknown-target":
                    change["after_unknown"]["zone_id"] = True
                elif scenario == "drift":
                    plan["resource_drift"] = [{"address": "other"}]
                elif scenario == "import":
                    change["importing"] = {"id": "id"}
                elif scenario == "move":
                    target["previous_address"] = "previous"
                elif scenario == "replace":
                    change["actions"] = ["delete", "create"]
                elif scenario == "delete":
                    change["actions"] = ["delete"]
                elif scenario == "deferred":
                    plan["deferred_changes"] = [{}]
                elif scenario == "output":
                    plan["output_changes"] = {"x": {"actions": ["update"]}}
                else:
                    plan["checks"] = [{"status": "unknown"}]
                with self.assertRaises(Rejected):
                    validate(plan, "existing-zone", "remove")


if __name__ == "__main__":
    unittest.main()
