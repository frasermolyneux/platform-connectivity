import copy
import json
import unittest
from unittest import mock

import xtremeidiots_adoption_plan as guard


class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.pr = {
            "number": 71,
            "state": "open",
            "draft": False,
            "base": {"ref": "main", "repo": {"full_name": guard.REPOSITORY}, "sha": "c" * 40},
            "head": {
                "ref": guard.BRANCH,
                "repo": {"full_name": guard.REPOSITORY},
                "sha": self.sha,
            },
            "labels": [{"name": guard.LABEL}],
        }
        self.event = {
            "action": "labeled",
            "label": {"name": guard.LABEL},
            "sender": {"login": guard.APPROVER},
            "repository": {"full_name": guard.REPOSITORY},
            "number": 71,
            "pull_request": copy.deepcopy(self.pr),
        }
        self.comments = [{
            "user": {"login": guard.APPROVER},
            "body": f"/approve-xtremeidiots-adoption-plan {self.sha}",
        }]
        self.keys = '["tripsidekick.app","tripsidekick.net"]'

    def run_guard(self):
        return guard.authorize(self.event, self.sha, self.pr, self.comments, self.keys)

    def test_preserves_existing_keys_and_adds_zone_once(self):
        self.assertEqual(
            json.loads(self.run_guard()),
            ["tripsidekick.app", "tripsidekick.net", "xtremeidiots.com"],
        )
        self.keys = '["xtremeidiots.com","tripsidekick.app","xtremeidiots.com"]'
        self.assertEqual(json.loads(self.run_guard()), ["tripsidekick.app", "xtremeidiots.com"])

    def test_rejects_untrusted_event(self):
        for field, value in (
            ("action", "synchronize"),
            ("label", {"name": "run-prd-plan"}),
            ("sender", {"login": "someone-else"}),
            ("repository", {"full_name": "someone-else/platform-connectivity"}),
            ("number", 72),
        ):
            with self.subTest(field=field):
                event = copy.deepcopy(self.event)
                event[field] = value
                with self.assertRaises((ValueError, KeyError)):
                    guard.authorize(event, self.sha, self.pr, self.comments, self.keys)

    def test_rejects_stale_or_untrusted_pr_and_checkout(self):
        for side in ("event", "live"):
            for mutation in ("sha", "repo", "branch", "base", "base_sha", "closed", "draft", "label"):
                with self.subTest(side=side, mutation=mutation):
                    event, live = copy.deepcopy(self.event), copy.deepcopy(self.pr)
                    pr = event["pull_request"] if side == "event" else live
                    if mutation == "sha":
                        pr["head"]["sha"] = "b" * 40
                    elif mutation == "repo":
                        pr["head"]["repo"]["full_name"] = "fork/platform-connectivity"
                    elif mutation == "branch":
                        pr["head"]["ref"] = "another-branch"
                    elif mutation == "base":
                        pr["base"]["ref"] = "other"
                    elif mutation == "base_sha":
                        pr["base"]["sha"] = "d" * 40
                    elif mutation == "closed":
                        pr["state"] = "closed"
                    elif mutation == "draft":
                        pr["draft"] = True
                    else:
                        pr["labels"] = []
                    with self.assertRaises(ValueError):
                        guard.authorize(event, self.sha, live, self.comments, self.keys)
        with self.assertRaises(ValueError):
            guard.authorize(self.event, "not-a-sha", self.pr, self.comments, self.keys)

    def test_rejects_absent_wrong_author_or_wrong_head_approval(self):
        for comments in (
            [],
            [{"user": {"login": "someone-else"}, "body": self.comments[0]["body"]}],
            [{"user": {"login": guard.APPROVER}, "body": "/approve-xtremeidiots-adoption-plan " + "b" * 40}],
            [{"user": {"login": guard.APPROVER}, "body": self.comments[0]["body"] + "\nextra"}],
        ):
            with self.subTest(comments=comments), self.assertRaises(ValueError):
                guard.authorize(self.event, self.sha, self.pr, comments, self.keys)

    def test_rejects_invalid_protected_key_list(self):
        for keys in ("", "null", "{}", '[""]', '[1]', '[" bad "]', "invalid"):
            with self.subTest(keys=keys), self.assertRaises(ValueError):
                guard.authorize(self.event, self.sha, self.pr, self.comments, keys)

    def test_missing_data_fails_closed(self):
        self.pr["head"]["repo"] = None
        with self.assertRaises(TypeError):
            self.run_guard()

    def test_base_must_be_an_ancestor_before_api_access(self):
        with mock.patch.dict(guard.os.environ, {
            "GITHUB_EVENT_PATH": "unused",
            "GH_TOKEN": "placeholder",
            "TF_VAR_cloudflare_adopted_zone_keys": self.keys,
        }):
            with mock.patch("builtins.open", mock.mock_open(read_data=json.dumps(self.event))):
                with mock.patch.object(guard.subprocess, "check_output", return_value=self.sha):
                    with mock.patch.object(guard.subprocess, "run", return_value=mock.Mock(returncode=1)):
                        with mock.patch.object(guard, "get_json") as get_json:
                            with self.assertRaisesRegex(ValueError, "not an ancestor"):
                                guard.main()
                            get_json.assert_not_called()

    def test_pagination_fetches_all_comments_before_authorizing(self):
        pages = [[{"user": {"login": "other"}, "body": ""}] * 100, self.comments]
        with mock.patch.object(guard, "get_json", side_effect=[self.pr, *pages]) as get_json:
            with mock.patch.dict(guard.os.environ, {
                "GITHUB_EVENT_PATH": "unused",
                "GH_TOKEN": "placeholder",
                "TF_VAR_cloudflare_adopted_zone_keys": self.keys,
            }):
                with mock.patch("builtins.open", mock.mock_open(read_data=json.dumps(self.event))):
                    with mock.patch.object(guard.subprocess, "check_output", return_value=self.sha):
                        with mock.patch.object(guard.subprocess, "run", return_value=mock.Mock(returncode=0)):
                            with mock.patch("builtins.print"):
                                guard.main()
        self.assertEqual(get_json.call_count, 3)
        self.assertIn("page=2", get_json.call_args_list[-1].args[0])


if __name__ == "__main__":
    unittest.main()
