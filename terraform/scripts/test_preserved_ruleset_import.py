import copy
import json
import subprocess
import unittest

import test_cloudflare_waf_preservation as waf_test
from test_find_preserved_rulesets import ENTRYPOINTS


ROOT = waf_test.ROOT
RULESET_ID = waf_test.RULESET_ID
ZONE_ID = waf_test.ZONE_ID


class PreservedRulesetImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        waf_test.CloudflareWafPreservationTests.setUpClass()
        cls.fixture = waf_test.CloudflareWafPreservationTests
        cls.addClassCleanup(cls.fixture.doClassCleanups)
        resource = (ROOT / "cloudflare_preserved_rulesets.tf").read_text()
        resource = resource[resource.index('resource "cloudflare_ruleset" "preserved"'):]
        resource = resource.replace(
            "zone_id     = cloudflare_zone.managed[each.value.zone_key].id",
            f'zone_id     = "{ZONE_ID}"',
        ).replace(
            'jsondecode(data.external.preserved_rulesets[each.value.zone_key].result["${each.value.phase}_rules"])',
            'jsondecode(file("rules.json"))',
        )
        config = f'''terraform {{
  required_providers {{
    cloudflare = {{ source = "cloudflare/cloudflare", version = "~> 5.28.1" }}
  }}
}}
provider "cloudflare" {{ api_token = "unused_placeholder_token_dev_environment" }}
locals {{
  preserved_rulesets = {{
    example = {{
      zone_key = "example"
      phase = jsondecode(file("phase.json"))
      snapshot = {{ name = "default", description = "" }}
    }}
  }}
}}
import {{
  to = cloudflare_ruleset.preserved["example"]
  id = "zones/{ZONE_ID}/{RULESET_ID}"
}}
''' + resource
        (cls.fixture.work / "main.tf").write_text(config)

    def test_imports_without_changes(self):
        for phase, entrypoint in ENTRYPOINTS.items():
            with self.subTest(phase=phase):
                result = copy.deepcopy(entrypoint)
                result["id"] = RULESET_ID
                result["version"] = "1"
                result["last_updated"] = "2026-01-01T00:00:00Z"
                desired = []
                for rule in result["rules"]:
                    configured = {key: copy.deepcopy(value) for key, value in rule.items()
                                  if key not in {"id", "version", "last_updated"}}
                    if configured["action"] == "execute":
                        configured["action_parameters"].pop("version", None)
                    desired.append(configured)
                self.fixture.server.result = result
                (self.fixture.work / "phase.json").write_text(json.dumps(phase))
                (self.fixture.work / "rules.json").write_text(json.dumps(desired))
                plan = subprocess.run(
                    [self.fixture.terraform, "plan", "-input=false", "-no-color"],
                    cwd=self.fixture.work, env=self.fixture.env, capture_output=True, text=True,
                )
                self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
                self.assertIn("1 to import, 0 to add, 0 to change, 0 to destroy", plan.stdout)


if __name__ == "__main__":
    unittest.main()
