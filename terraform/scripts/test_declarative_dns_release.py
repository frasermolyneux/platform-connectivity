import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DeclarativeDnsReleaseTests(unittest.TestCase):
    def test_move_then_forget_releases_only_delegated_instance_without_deletion(self):
        self._assert_release(historical=False)

    def test_historical_move_chain_also_forgets_without_deletion(self):
        self._assert_release(historical=True)

    def _assert_release(self, historical):
        terraform = shutil.which("terraform")
        self.assertIsNotNone(terraform, "Pinned Terraform is required")
        version = subprocess.run(
            [terraform, "version", "-json"], capture_output=True, text=True, check=True
        )
        self.assertEqual(
            json.loads(version.stdout)["terraform_version"],
            (ROOT / ".terraform-version").read_text().strip(),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            release = (ROOT / "cloudflare_notifications_release.tf").read_text()
            release, substitutions = re.subn(
                r'cloudflare_dns_record\.txt\["[^"]+"\]',
                'terraform_data.records["delegated"]',
                release,
            )
            self.assertEqual(substitutions, 1)
            release = release.replace(
                "cloudflare_dns_record.notification_verification_release",
                "terraform_data.notification_release",
            )
            self.assertNotIn("cloudflare_", release)
            delegated_key = "delegated"
            if historical:
                delegated_key = "historical"
                release += """
moved {
  from = terraform_data.records["historical"]
  to   = terraform_data.records["delegated"]
}
"""
            path.joinpath("main.tf").write_text("""
resource "terraform_data" "records" {
  for_each = toset(["kept"])
  input    = each.key
}
""" + release)
            state = {
                "version": 4, "terraform_version": "1.17.0", "serial": 1,
                "lineage": "00000000-0000-0000-0000-000000000001",
                "outputs": {},
                "resources": [{
                    "mode": "managed", "type": "terraform_data", "name": "records",
                    "provider": 'provider["terraform.io/builtin/terraform"]',
                    "instances": [{
                        "index_key": key, "schema_version": 0,
                        "attributes": {
                            "id": key, "input": {"value": key, "type": "string"},
                            "output": {"value": key, "type": "string"},
                            "triggers_replace": None,
                        },
                        "sensitive_attributes": [],
                    } for key in ["kept", delegated_key]],
                }],
            }
            original = json.dumps(state)
            path.joinpath("terraform.tfstate").write_text(original)
            for arguments in [
                ["init", "-backend=false", "-input=false"],
                ["plan", "-input=false", "-out=synthetic.tfplan"],
            ]:
                subprocess.run(
                    [terraform, f"-chdir={directory}", *arguments],
                    capture_output=True, text=True, check=True,
                )
            result = subprocess.run(
                [terraform, f"-chdir={directory}", "show", "-json", "synthetic.tfplan"],
                capture_output=True, text=True, check=True,
            )
            changes = {
                change["address"]: change for change in json.loads(result.stdout)["resource_changes"]
            }
            release = changes["terraform_data.notification_release"]
            self.assertEqual(release["previous_address"], f'terraform_data.records["{delegated_key}"]')
            self.assertEqual(release["change"]["actions"], ["forget"])
            self.assertEqual(changes['terraform_data.records["kept"]']["change"]["actions"], ["no-op"])
            self.assertEqual(path.joinpath("terraform.tfstate").read_text(), original)


if __name__ == "__main__":
    unittest.main()
