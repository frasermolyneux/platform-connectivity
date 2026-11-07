import re
import unittest
from pathlib import Path


WORKFLOW = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "deploy-prd.yml"
REVISION = "977ddbedf7f5c6e2fae98ff1d6ec6a9c7669d778"


class ProductionWorkflowTest(unittest.TestCase):
    def test_scope_and_evidence_bind_the_applied_plan(self):
        workflow = WORKFLOW.read_text(encoding="utf-8").split("  terraform-plan-and-apply-prd:", 1)[1]
        self.assertNotIn("continue-on-error", workflow)
        self.assertIn(f"ref: {REVISION}", workflow)
        for action in ("terraform-setup", "terraform-plan-storage", "terraform-receipt"):
            self.assertIn(f"frasermolyneux/actions/{action}@{REVISION}", workflow)
        self.assertIn("group: ${{ github.repository }}-prd", workflow)
        sequence = (
            "terraform -chdir=terraform plan -input=false -no-color -var-file=tfvars/prd.tfvars -out=plan.tfplan",
            'digest=$(sha256sum "$plan"',
            'merge_sha=$(gh api "repos/$GITHUB_REPOSITORY/pulls/74"',
            '[[ "$merge_sha" =~ ^[0-9a-f]{40}$ ]]',
            'associated=$(gh api "repos/$GITHUB_REPOSITORY/commits/$merge_sha/pulls"',
            '[[ "$associated" == 1 ]]',
            'comparison=$(gh api "repos/$GITHUB_REPOSITORY/compare/$merge_sha...$GITHUB_SHA"',
            '[[ "$comparison" == "$merge_sha"',
            'if [[ "$GITHUB_SHA" == "$merge_sha" ]]; then',
            'guard_args+=(--require-noop)',
            'terraform -chdir=terraform show -json "$plan" | python3 terraform/scripts/guard_ordinary_prd_plan.py "${guard_args[@]}"',
            'echo "$digest  $plan" | sha256sum --check --status',
            'echo "digest=$digest" >> "$GITHUB_OUTPUT"',
            "context.cjs save-plan",
            "name: Store Terraform plan",
            "name: Verify the saved plan before apply",
            'echo "$PLAN_DIGEST  $plan" | sha256sum --check --status',
            "name: Apply the validated saved plan",
            'terraform -chdir=terraform apply -input=false -auto-approve "$GITHUB_WORKSPACE/terraform/plan.tfplan"',
            "name: Publish Terraform apply execution evidence",
            "name: Remove local saved plan",
        )
        positions = [workflow.index(item) for item in sequence]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(len(re.findall(r"terraform -chdir=terraform (?:plan|apply) -input=false", workflow)), 2)
        self.assertIn("TF_PLAN: plan.tfplan", workflow)
        self.assertIn("plan-file-name: plan.tfplan", workflow)
        self.assertIn("plan-artifact-name: terraform-plan", workflow)
        self.assertIn("PLAN_DIGEST: ${{ steps.plan.outputs.digest }}", workflow)
        self.assertIn("if: always() && (steps.apply.outcome == 'success' || steps.apply.outcome == 'failure' || steps.apply.outcome == 'cancelled')", workflow)
        self.assertIn("outcome: ${{ steps.apply.outcome == 'success' && 'success' || 'failure' }}", workflow)
        self.assertEqual(workflow.count('test "$(gh api "repos/$GITHUB_REPOSITORY/commits/main" --jq .sha)" = "$GITHUB_SHA"'), 2)

    def test_strict_tls_operation_uses_same_saved_plan(self):
        workflow = (WORKFLOW.parent / "deploy-strict-origin-tls.yml").read_text(encoding="utf-8")
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
