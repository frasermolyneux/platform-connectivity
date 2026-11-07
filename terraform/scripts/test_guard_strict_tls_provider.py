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

from guard_ordinary_prd_plan import validate as validate_ordinary
from guard_strict_tls_plan import Rejected, validate

ROOT = Path(__file__).resolve().parents[1]
ZONE = "00000000000000000000000000000002"
RULESET = "00000000000000000000000000000003"


class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, result):
        body = json.dumps({"success": True, "errors": [], "messages": [], "result": result}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path != f"/client/v4/zones/{ZONE}/rulesets/{RULESET}":
            self.send_error(404)
            return
        self.reply(self.server.ruleset)

    def do_PUT(self):
        if self.path != f"/client/v4/zones/{ZONE}/rulesets/{RULESET}?dry_run=true":
            self.send_error(404)
            return
        self.server.requests.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
        self.reply(None)

    def log_message(self, *_):
        pass


class ProviderLoggingTest(unittest.TestCase):
    def test_in_place_plan_dry_run_omits_logging(self):
        terraform = shutil.which("terraform")
        if not terraform:
            self.fail("Pinned Terraform CLI is required")
        version = subprocess.run([terraform, "version", "-json"], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(version.stdout)["terraform_version"],
                         (ROOT / ".terraform-version").read_text().strip())
        plugin_dir = ROOT / ".terraform" / "providers"
        self.assertTrue(plugin_dir.is_dir(), "Run backend-disabled readonly Terraform init first")
        lock = (ROOT / ".terraform.lock.hcl").read_text()
        match = re.search(r'(?ms)^provider "registry\.terraform\.io/cloudflare/cloudflare" \{.*?^\}', lock)
        self.assertIsNotNone(match)
        ruleset = {
            "id": RULESET, "zone_id": ZONE, "name": "origin-tls-owner",
            "description": "Strict origin TLS only for explicitly selected proxied hostnames",
            "kind": "zone", "phase": "http_config_settings", "rules": [],
            "version": "2", "last_updated": "2026-01-01T00:00:00Z",
        }
        config = f'''terraform {{
  required_providers {{
    cloudflare = {{ source = "cloudflare/cloudflare", version = "~> 5.28.1" }}
  }}
}}
provider "cloudflare" {{ api_token = "unused_placeholder_token_dev_environment" }}
resource "cloudflare_ruleset" "origin_tls" {{
  for_each = toset(["xtremeidiots.net"])
  zone_id = "{ZONE}"
  name = "origin-tls-owner"
  description = "Strict origin TLS only for explicitly selected proxied hostnames"
  kind = "zone"
  phase = "http_config_settings"
  rules = [{{
    ref = "origin_strict_redirect_xtremeidiots_net"
    description = "Validate the origin certificate for redirect.xtremeidiots.net"
    expression = "http.host eq \\"redirect.xtremeidiots.net\\""
    action = "set_config"
    enabled = true
    action_parameters = {{ ssl = "strict" }}
  }}]
}}
'''
        state = {
            "version": 4, "terraform_version": (ROOT / ".terraform-version").read_text().strip(),
            "serial": 1, "lineage": "00000000-0000-0000-0000-000000000000",
            "outputs": {}, "resources": [{
                "mode": "managed", "type": "cloudflare_ruleset", "name": "origin_tls",
                "provider": 'provider["registry.terraform.io/cloudflare/cloudflare"]',
                "instances": [{"index_key": "xtremeidiots.net", "schema_version": 0, "attributes": ruleset}],
            }],
        }
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / "main.tf").write_text(config)
            (work / ".terraform.lock.hcl").write_text(match.group() + "\n")
            (work / "terraform.tfstate").write_text(json.dumps(state))
            init = subprocess.run([terraform, "init", "-backend=false", "-lockfile=readonly", "-input=false",
                                   "-no-color", f"-plugin-dir={plugin_dir}"],
                                  cwd=work, capture_output=True, text=True)
            self.assertEqual(init.returncode, 0, init.stdout + init.stderr)
            with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
                server.ruleset = ruleset
                server.requests = []
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    env = os.environ.copy()
                    env["CLOUDFLARE_BASE_URL"] = f"http://127.0.0.1:{server.server_address[1]}/client/v4/"
                    plan = subprocess.run([terraform, "plan", "-input=false", "-no-color", "-out=plan.tfplan"],
                                          cwd=work, env=env, capture_output=True, text=True)
                    self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
                    self.assertNotIn("Warning:", plan.stdout + plan.stderr)
                    shown = subprocess.run([terraform, "show", "-json", "plan.tfplan"], cwd=work,
                                           capture_output=True, text=True, check=True)
                    parsed = json.loads(shown.stdout)
                    validate(parsed, ZONE)
                    change = parsed["resource_changes"][0]["change"]
                    self.assertIs(change["after_unknown"]["rules"][0]["logging"], True)
                    self.assertIsNone(change["after"]["rules"][0].get("logging"))
                    self.assertEqual(len(server.requests), 1)
                    self.assertEqual(len(server.requests[0]["rules"]), 1)
                    self.assertNotIn("logging", server.requests[0]["rules"][0])
                    self.assertEqual(server.requests[0]["rules"][0]["action_parameters"], {"ssl": "strict"})
                    with self.assertRaises(Rejected):
                        validate_ordinary(parsed, ZONE)

                    empty_config = config[:config.index("  rules = [{")] + '''  rules = []
}
resource "terraform_data" "unrelated" {
  input = "ordinary change"
}
'''
                    (work / "main.tf").write_text(empty_config)
                    plan = subprocess.run([terraform, "plan", "-input=false", "-no-color", "-out=plan.tfplan"],
                                          cwd=work, env=env, capture_output=True, text=True)
                    self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
                    shown = subprocess.run([terraform, "show", "-json", "plan.tfplan"], cwd=work,
                                           capture_output=True, text=True, check=True)
                    parsed = json.loads(shown.stdout)
                    validate_ordinary(parsed, ZONE)
                    self.assertTrue(any(
                        item["address"] == "terraform_data.unrelated"
                        and item["change"]["actions"] == ["create"]
                        for item in parsed["resource_changes"]
                    ))
                    rule = {
                        "id": "00000000000000000000000000000004",
                        "ref": "origin_strict_redirect_xtremeidiots_net",
                        "description": "Validate the origin certificate for redirect.xtremeidiots.net",
                        "expression": 'http.host eq "redirect.xtremeidiots.net"',
                        "action": "set_config", "enabled": True,
                        "action_parameters": {"ssl": "strict"},
                    }
                    ruleset["rules"] = [rule]
                    (work / "terraform.tfstate").write_text(json.dumps(state))
                    (work / "main.tf").write_text(empty_config.split('resource "terraform_data"')[0])
                    server.requests.clear()
                    plan = subprocess.run([terraform, "plan", "-input=false", "-no-color", "-out=plan.tfplan"],
                                          cwd=work, env=env, capture_output=True, text=True)
                    self.assertEqual(plan.returncode, 0, plan.stdout + plan.stderr)
                    shown = subprocess.run([terraform, "show", "-json", "plan.tfplan"], cwd=work,
                                           capture_output=True, text=True, check=True)
                    parsed = json.loads(shown.stdout)
                    validate(parsed, ZONE, "remove")
                    with self.assertRaises(Rejected):
                        validate(parsed, ZONE, "add")
                    with self.assertRaises(Rejected):
                        validate_ordinary(parsed, ZONE)
                    self.assertEqual(len(server.requests), 1)
                    self.assertEqual(server.requests[0].get("rules"), [])
                finally:
                    server.shutdown()
                    thread.join()


if __name__ == "__main__":
    unittest.main()
