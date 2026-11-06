import copy
import json
import subprocess
import unittest

import test_cloudflare_waf_preservation as waf_test


SNAPSHOTS = json.loads(
    (waf_test.ROOT / "zones" / "xtremeidiots.com.json").read_text()
)["page_rules"]


class PageRuleHandler(waf_test.RulesetHandler):
    def do_GET(self):
        if not self.path.startswith(f"/client/v4/zones/{waf_test.ZONE_ID}/pagerules/"):
            self.send_error(404)
            return
        body = json.dumps({
            "success": True, "errors": [], "messages": [], "result": self.server.result
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class PreservedPageRuleImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        waf_test.CloudflareWafPreservationTests.setUpClass()
        cls.fixture = waf_test.CloudflareWafPreservationTests
        cls.addClassCleanup(cls.fixture.doClassCleanups)
        cls.fixture.server.RequestHandlerClass = PageRuleHandler
        resource = (waf_test.ROOT / "cloudflare_page_rules.tf").read_text()
        resource = resource[resource.index('resource "cloudflare_page_rule" "preserved"'):]
        resource = resource.replace(
            "zone_id  = cloudflare_zone.managed[each.value.zone_key].id",
            f'zone_id  = "{waf_test.ZONE_ID}"',
        )
        config = f'''terraform {{
  required_providers {{
    cloudflare = {{ source = "cloudflare/cloudflare", version = "~> 5.28.1" }}
  }}
}}
provider "cloudflare" {{ api_token = "unused_placeholder_token_dev_environment" }}
locals {{ preserved_page_rules = {{ example = jsondecode(file("page.json")) }} }}
import {{
  to = cloudflare_page_rule.preserved["example"]
  id = "{waf_test.ZONE_ID}/{waf_test.RULESET_ID}"
}}
''' + resource
        (cls.fixture.work / "main.tf").write_text(config)

    def test_imports_without_changes(self):
        for snapshot in SNAPSHOTS.values():
            with self.subTest(target=snapshot["target"]):
                result = {
                    "id": waf_test.RULESET_ID,
                    "targets": [{"target": "url", "constraint": {
                        "operator": "matches", "value": snapshot["target"],
                    }}],
                    "actions": copy.deepcopy(snapshot["api_actions"]),
                    "priority": snapshot["priority"],
                    "status": snapshot["status"],
                    "created_on": "2020-01-01T00:00:00Z",
                    "modified_on": "2020-01-01T00:00:00Z",
                }
                self.fixture.server.result = result
                (self.fixture.work / "page.json").write_text(json.dumps(snapshot))
                plan = subprocess.run(
                    [self.fixture.terraform, "plan", "-input=false", "-no-color"],
                    cwd=self.fixture.work, env=self.fixture.env, capture_output=True, text=True,
                )
                self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
                self.assertIn("1 to import, 0 to add, 0 to change, 0 to destroy", plan.stdout)


if __name__ == "__main__":
    unittest.main()
