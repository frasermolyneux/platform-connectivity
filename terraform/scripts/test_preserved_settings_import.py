import json
import subprocess
import unittest

import test_cloudflare_waf_preservation as waf_test


class SettingHandler(waf_test.RulesetHandler):
    def do_GET(self):
        prefix = f"/client/v4/zones/{waf_test.ZONE_ID}/settings/"
        setting = self.path.removeprefix(prefix)
        if not self.path.startswith(prefix) or setting not in self.server.settings:
            self.send_error(404)
            return
        body = json.dumps({
            "success": True, "errors": [], "messages": [],
            "result": {"id": setting, "value": self.server.settings[setting], "editable": True},
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class PreservedSettingsImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        waf_test.CloudflareWafPreservationTests.setUpClass()
        cls.fixture = waf_test.CloudflareWafPreservationTests
        cls.addClassCleanup(cls.fixture.doClassCleanups)
        cls.fixture.server.RequestHandlerClass = SettingHandler
        cls.settings = json.loads(
            (waf_test.ROOT / "zones" / "xtremeidiots.com.json").read_text()
        )["settings"]
        cls.fixture.server.settings = cls.settings
        (cls.fixture.work / "settings.json").write_text(json.dumps(cls.settings))
        source = (waf_test.ROOT / "cloudflare_zones.tf").read_text()
        source = source[source.index('resource "cloudflare_zone_setting" "managed"'):]
        source = source.replace(
            "zone_id    = cloudflare_zone.managed[each.value.zone_key].id",
            f'zone_id    = "{waf_test.ZONE_ID}"',
        ).replace(
            "data.external.preserved_settings[each.value.zone_key].result.verified",
            "local.verified",
        )
        config = f'''terraform {{
  required_providers {{
    cloudflare = {{ source = "cloudflare/cloudflare", version = "~> 5.28.1" }}
  }}
}}
provider "cloudflare" {{ api_token = "unused_placeholder_token_dev_environment" }}
locals {{
  verified = "true"
  managed_cloudflare_zones = {{ example = {{ preserve_settings = true }} }}
  managed_cloudflare_zone_settings = {{
    for key, value in jsondecode(file("settings.json")) : key => {{
      zone_key = "example", setting_id = key, value = value
    }}
  }}
}}
import {{
  for_each = local.managed_cloudflare_zone_settings
  to = cloudflare_zone_setting.managed[each.key]
  id = "{waf_test.ZONE_ID}/${{each.key}}"
}}
''' + source
        (cls.fixture.work / "main.tf").write_text(config)

    def test_imports_without_changes(self):
        plan = subprocess.run(
            [self.fixture.terraform, "plan", "-input=false", "-no-color"],
            cwd=self.fixture.work, env=self.fixture.env, capture_output=True, text=True,
        )
        self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
        self.assertIn(f"{len(self.settings)} to import, 0 to add, 0 to change, 0 to destroy",
                      plan.stdout)

if __name__ == "__main__":
    unittest.main()
