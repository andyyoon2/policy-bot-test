# policy-bot-test

Prototype for the **CODEOWNERS App** design: replace GitHub's "require review
from code owners" rule with a self-hosted
[palantir/policy-bot](https://github.com/palantir/policy-bot), so that a bot
can approve on behalf of a code owner for specific paths.

Design doc: *CODEOWNERS App: bot approvals on behalf of code owners*
(Notion, Core Engineering / Design Documents).

## Layout

| Path | Purpose |
|---|---|
| `.policy.yml` | policy-bot rules. Read from the base branch of each PR. |
| `.github/CODEOWNERS` | Same ownership, kept for GitHub's native review requests. |
| `.github/workflows/lint.yaml` | Stub CI job; the bot rule requires it to pass. Add the `break-lint` label to a PR to make it fail. |
| `backend/`, `frontend/`, `infra/`, `.github/` | Stub trees, each a different ownership rule. |
| `infra/policy-bot/` | Terraform for the policy-bot deployment in `xyla-development-2`. |
| `scripts/set-secrets.sh` | Loads the GitHub App secrets into Secret Manager. |
| `scripts/approve-as-bot.sh` | Approves a PR as a GitHub App, standing in for the auto-approver service. |

## Rules under test

| Changed paths | Satisfied by |
|---|---|
| `backend/` only | `@andyyoon2`, **or** the approver App when `Lint` passed on the head commit |
| `backend/` plus anything else | `@andyyoon2` for backend, plus whatever else applies. The bot never counts. |
| `frontend/` | `@andyyoon2` |
| `infra/`, `.github/`, `.policy.yml` | `@andyyoon2`, humans only |
| none of the above | always approved |
| co-sign (commented out) | one approval from any collaborator with write, never the author |

## Setup order

1. `infra/policy-bot/README.md` steps 1 to 6: deploy policy-bot and create its GitHub App.
2. Create a second GitHub App named `policy-bot-test-approver` (no webhook, permissions: Pull requests read & write, Metadata read). Install it on this repo. Its reviews appear as `policy-bot-test-approver[bot]`, which `.policy.yml` already lists.
3. Add a second collaborator with write access, or a second personal account. GitHub does not let an author approve their own PR, so human-approval cases need someone other than the PR author.
4. Ruleset on `main` (Settings, Rules, Rulesets):
   - Require a pull request before merging. Required approvals 0, so only policy-bot gates. Set 1 later to confirm a bot review counts toward GitHub's native count.
   - Require status checks to pass: add `policy-bot: main`, source = the policy-bot App. Leave "require review from code owners" **off**. Leave "dismiss stale approvals" off.
   - Merge queue needs a public repo or an org on a paid plan. Skip on a private personal repo and test it when the prototype moves to the org.

## Test matrix

| # | Scenario | Expected `policy-bot: main` |
|---|---|---|
| 1 | PR changes only `README.md` | success (catch-all rule) |
| 2 | PR changes `frontend/foo.txt` | pending until a non-author owner approves, then success |
| 3 | PR changes `backend/foo.txt`, Lint green, run `approve-as-bot.sh` | success with no human approval |
| 4 | Same as 3, then push another commit | pending (approval invalidated), success again after re-running the script |
| 5 | Same as 3 with the `break-lint` label | pending (workflow condition unmet) |
| 6 | PR changes `backend/` and `infra/`, bot approves | pending until a human approves infra |
| 7 | PR edits `.policy.yml` to add the bot to the infra rule, bot approves | pending: the base-branch policy applies, not the PR's |
| 8 | Post a status named `policy-bot: main` with a personal token | ruleset still blocks: the required check is pinned to the App |
| 9 | Uncomment `human co-sign`; redo 3 | pending until a second human approves |
| 10 | Merge queue, where available | success posted on the merge-group commit without re-evaluation |
