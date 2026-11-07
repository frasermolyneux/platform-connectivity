import unittest
from pathlib import Path


WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"
REVISION = "977ddbedf7f5c6e2fae98ff1d6ec6a9c7669d778"


class ProductionWorkflowTest(unittest.TestCase):
    def test_ordinary_deploy_uses_shared_action_for_both_environments(self):
        workflow = (WORKFLOWS / "deploy-prd.yml").read_text(encoding="utf-8")
        dev, prd = workflow.split("  terraform-plan-and-apply-prd:", 1)
        action = f"frasermolyneux/actions/terraform-plan-and-apply@{REVISION}"
        self.assertIn(
            "on:\n  push:\n    branches:\n      - main\n    paths:\n"
            "      - 'terraform/**'\n      - 'maintenance/**'\n"
            "      - '.github/workflows/deploy-prd.yml'\n"
            '  workflow_dispatch:\n  schedule:\n    - cron: "0 2 * * 5"\n',
            workflow,
        )
        self.assertIn("permissions: {}\n\nconcurrency:\n  group: ${{ github.workflow }}", workflow)
        self.assertEqual(workflow.count("      contents: read\n      id-token: write"), 2)
        self.assertNotIn("pull-requests: read", workflow)
        self.assertEqual(workflow.count(action), 2)
        self.assertIn("if: github.event_name != 'schedule'", dev)
        self.assertIn("environment: Development", dev)
        self.assertIn("group: ${{ github.repository }}-dev", dev)
        self.assertIn("uses: actions/checkout@v7", dev)
        self.assertIn('node-version: "22.x"', dev)
        self.assertIn('terraform-var-file: "tfvars/dev.tfvars"', dev)
        self.assertIn('terraform-backend-file: "backends/dev.backend.hcl"', dev)
        self.assertIn("node --test maintenance/worker.test.mjs", dev)
        self.assertIn("needs: terraform-plan-and-apply-dev", prd)
        self.assertIn("needs.terraform-plan-and-apply-dev.result == 'success' || github.event_name == 'schedule'", prd)
        self.assertIn("environment: Production", prd)
        self.assertIn("group: ${{ github.repository }}-prd", prd)
        self.assertNotIn("cancel-in-progress:", prd)
        self.assertIn('terraform-var-file: "tfvars/prd.tfvars"', prd)
        self.assertIn('terraform-backend-file: "backends/prd.backend.hcl"', prd)
        self.assertNotIn("guard_ordinary_prd_plan.py", workflow)
        self.assertNotIn("steps.preparation", workflow)

    def test_strict_tls_operation_uses_same_saved_plan(self):
        workflow = (WORKFLOWS / "deploy-strict-origin-tls.yml").read_text(encoding="utf-8")
        self.assertIn("operation:\n", workflow)
        self.assertIn("          - add\n          - remove\n", workflow)
        self.assertIn("TLS_OPERATION: ${{ inputs.operation }}", workflow)
        self.assertIn("group: ${{ github.repository }}-prd", workflow)
        sequence = (
            'terraform -chdir=terraform plan -input=false -no-color -var-file=tfvars/prd.tfvars -out="$plan"',
            'digest=$(sha256sum "$plan"',
            'terraform -chdir=terraform show -json "$plan" | python3 terraform/scripts/guard_strict_tls_plan.py "$TLS_OPERATION"',
            'echo "$digest  $plan" | sha256sum --check --status',
            'terraform -chdir=terraform apply -input=false -auto-approve "$plan"',
        )
        positions = [workflow.index(item) for item in sequence]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(workflow.count("git hash-object terraform/cloudflare_origin_tls.tf"), 2)
        self.assertEqual(workflow.count('test "$(gh api "repos/$GITHUB_REPOSITORY/commits/main" --jq .sha)" = "$GITHUB_SHA"'), 2)


if __name__ == "__main__":
    unittest.main()
