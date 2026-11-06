import copy
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import socketserver
import subprocess
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZONE_ID = "00000000000000000000000000000002"
RULESET_ID = "00000000000000000000000000000003"


class RulesetHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != f"/client/v4/zones/{ZONE_ID}/rulesets/{RULESET_ID}":
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

    def log_message(self, *_):
        pass


class CloudflareWafPreservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.work = Path(cls.temp.name)
        cls.addClassCleanup(cls.temp.cleanup)
        cls.terraform = shutil.which("terraform")
        if not cls.terraform:
            raise RuntimeError("The pinned Terraform CLI is required for the Cloudflare WAF test.")
        expected = (ROOT / ".terraform-version").read_text().strip()
        version = subprocess.run(
            [cls.terraform, "version", "-json"], capture_output=True, text=True, check=True
        )
        if json.loads(version.stdout)["terraform_version"] != expected:
            raise RuntimeError(f"The Cloudflare WAF test requires Terraform {expected}.")

        zone = json.loads((ROOT / "zones" / "xtremeidiots.com.json").read_text())
        cls.zone = zone
        rules = copy.deepcopy(zone["waf_custom_ruleset"]["rules"])
        for index, rule in enumerate(rules):
            rule["id"] = f"{index + 10:032x}"
            rule.setdefault("ref", rule["id"])
        cls.ruleset = {
            "id": RULESET_ID, "name": "default", "description": "", "kind": "zone",
            "phase": "http_request_firewall_custom", "version": "1",
            "last_updated": "2026-01-01T00:00:00Z", "rules": rules,
        }

        source = (ROOT / "cloudflare_waf.tf").read_text()
        resource = source[source.index('resource "cloudflare_ruleset" "zone_custom_firewall"'):]
        original_zone = "zone_id     = cloudflare_zone.managed[each.key].id"
        if original_zone not in resource:
            raise RuntimeError("Unable to isolate the custom firewall resource for testing.")
        resource = resource.replace(original_zone, f'zone_id     = "{ZONE_ID}"', 1)
        config = f'''terraform {{
  required_providers {{
    cloudflare = {{ source = "cloudflare/cloudflare", version = "~> 5.28.1" }}
  }}
}}
provider "cloudflare" {{ api_token = "unused_placeholder_token_dev_environment" }}
locals {{
  zone = jsondecode(file("zone.json"))
  cf_waf_ruleset_ids = {{ example = ["{RULESET_ID}"] }}
  managed_cloudflare_zones = {{ example = local.zone }}
}}
data "cloudflare_ruleset" "existing_custom_firewall" {{
  for_each = {{ example = local.zone }}
  zone_id = "{ZONE_ID}"
  id = local.cf_waf_ruleset_ids[each.key][0]
}}
''' + resource
        (cls.work / "main.tf").write_text(config)
        lock = (ROOT / ".terraform.lock.hcl").read_text()
        provider_lock = re.search(
            r'(?ms)^provider "registry\.terraform\.io/cloudflare/cloudflare" \{.*?^\}', lock
        )
        if not provider_lock:
            raise RuntimeError("The Cloudflare provider is missing from the Terraform lockfile.")
        (cls.work / ".terraform.lock.hcl").write_text(provider_lock.group() + "\n")
        plugins = ROOT / ".terraform" / "providers"
        if not plugins.is_dir():
            raise RuntimeError("Run Terraform init with -backend=false -lockfile=readonly before this test.")
        init = subprocess.run(
            [cls.terraform, "init", "-backend=false", "-lockfile=readonly", "-input=false",
             "-no-color", f"-plugin-dir={plugins}"],
            cwd=cls.work, capture_output=True, text=True
        )
        if init.returncode:
            raise RuntimeError(init.stdout + init.stderr)

        cls.server = socketserver.TCPServer(("127.0.0.1", 0), RulesetHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.addClassCleanup(cls.stop_server)
        cls.env = os.environ.copy()
        cls.env["CLOUDFLARE_BASE_URL"] = f"http://127.0.0.1:{cls.server.server_address[1]}/client/v4/"

    @classmethod
    def stop_server(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def plan(self, ruleset, zone=None):
        self.server.result = ruleset
        (self.work / "zone.json").write_text(json.dumps(zone or self.zone))
        return subprocess.run(
            [self.terraform, "plan", "-input=false", "-refresh=false", "-no-color"],
            cwd=self.work, env=self.env, capture_output=True, text=True
        )

    def test_exact_snapshot_and_drift(self):
        exact = self.plan(self.ruleset)
        self.assertEqual(exact.returncode, 0, exact.stdout + exact.stderr)

        mutations = {
            "expression": lambda r: r["rules"][0].update(expression="false"),
            "order": lambda r: r["rules"].reverse(),
            "extra action": lambda r: r["rules"][0]["action_parameters"].update(phases=["http_ratelimit"]),
            "reference": lambda r: r["rules"][0].update(ref="changed"),
            "missing rule": lambda r: r["rules"].pop(),
            "response": lambda r: r["rules"][2]["action_parameters"]["response"].update(status_code=429),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                ruleset = copy.deepcopy(self.ruleset)
                mutate(ruleset)
                result = self.plan(ruleset)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Resource precondition failed", result.stderr)

        zone = copy.deepcopy(self.zone)
        zone["waf_custom_ruleset"]["rules"][0]["action_parameters"]["phases"] = ["http_ratelimit"]
        result = self.plan(self.ruleset, zone)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Resource precondition failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
