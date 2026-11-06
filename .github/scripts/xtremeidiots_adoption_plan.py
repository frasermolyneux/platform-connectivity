"""Authorize the one-off, exact-head production adoption plan."""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

REPOSITORY = "frasermolyneux/platform-connectivity"
BRANCH = "frasermolyneux-cloudflare-zone-adoption"
LABEL = "rehearse-xtremeidiots-adoption"
APPROVER = "frasermolyneux"
PR_NUMBER = 71
ZONE = "xtremeidiots.com"


def fail(message):
    raise ValueError(message)


def check_pr(pr, sha):
    if (
        pr["number"] != PR_NUMBER
        or pr["state"] != "open"
        or pr["draft"]
        or pr["base"]["ref"] != "main"
        or pr["base"]["repo"]["full_name"] != REPOSITORY
        or pr["head"]["repo"]["full_name"] != REPOSITORY
        or pr["head"]["ref"] != BRANCH
        or pr["head"]["sha"] != sha
        or LABEL not in [label["name"] for label in pr["labels"]]
    ):
        fail("PR does not match the authorized repository, branch, head, or label")


def authorize(event, checkout_sha, live_pr, comments, protected_keys):
    if (
        event["action"] != "labeled"
        or event["label"]["name"] != LABEL
        or event["sender"]["login"] != APPROVER
        or event["repository"]["full_name"] != REPOSITORY
        or event["number"] != PR_NUMBER
        or not re.fullmatch(r"[0-9a-f]{40}", checkout_sha)
    ):
        fail("event is not an authorized opt-in")
    check_pr(event["pull_request"], checkout_sha)
    check_pr(live_pr, checkout_sha)
    if (
        not re.fullmatch(r"[0-9a-f]{40}", event["pull_request"]["base"]["sha"])
        or event["pull_request"]["base"]["sha"] != live_pr["base"]["sha"]
    ):
        fail("PR base changed since the opt-in event")
    approval = f"/approve-xtremeidiots-adoption-plan {checkout_sha}"
    if not any(
        comment["user"]["login"] == APPROVER and comment["body"].strip() == approval
        for comment in comments
    ):
        fail("no exact-head approval comment from the authorized owner")
    try:
        keys = json.loads(protected_keys)
    except json.JSONDecodeError:
        fail("protected adoption keys are not valid JSON")
    if not isinstance(keys, list) or any(
        not isinstance(key, str) or not key or key != key.strip() for key in keys
    ):
        fail("protected adoption keys must be a JSON array of nonempty strings")
    return json.dumps(sorted(set(keys) | {ZONE}), separators=(",", ":"))


def get_json(path, token):
    request = urllib.request.Request(
        os.environ["GITHUB_API_URL"] + path,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as event_file:
        event = json.load(event_file)
    checkout_sha = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip()
    base_sha = event["pull_request"]["base"]["sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
        fail("invalid event base commit")
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", base_sha, checkout_sha], check=False
    ).returncode != 0:
        fail("the event base commit is not an ancestor of the approved head")
    token = os.environ["GH_TOKEN"]
    live_pr = get_json(f"/repos/{REPOSITORY}/pulls/{PR_NUMBER}", token)
    comments = []
    for page in range(1, 101):
        batch = get_json(
            f"/repos/{REPOSITORY}/issues/{PR_NUMBER}/comments?per_page=100&page={page}",
            token,
        )
        if not isinstance(batch, list):
            fail("unexpected approval comment response")
        comments.extend(batch)
        if len(batch) < 100:
            break
    else:
        fail("approval comments exceed the pagination safety limit")
    print(authorize(event, checkout_sha, live_pr, comments, os.environ["TF_VAR_cloudflare_adopted_zone_keys"]))


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        print(f"GitHub API request failed with HTTP {error.code}; no plan was run.", file=sys.stderr)
        sys.exit(1)
    except ValueError as error:
        print(f"Adoption rehearsal rejected: {error}; no plan was run.", file=sys.stderr)
        sys.exit(1)
    except (KeyError, TypeError, OSError, subprocess.SubprocessError, urllib.error.URLError):
        print("Adoption rehearsal could not verify its event, PR, comments, or checkout; no plan was run.", file=sys.stderr)
        sys.exit(1)
