# code-review-suite

A small, reusable code review pipeline. Most of the cost stays in checks that do not call a model. A model runs only after those checks pass, and only at the size the diff deserves.

The shape comes from [How the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/) ([thread](https://x.com/addyosmani/status/2114604912520921136)): verify before the pull request, keep `CLAUDE.md` and `REVIEW.md` short, tag findings, cap review rounds, and turn reverts into evals.

The first consumer is a code bot that opens pull requests on [FitToday-cms](https://github.com/Viniciuscarvalho/FitToday-cms). This repo does not depend on that codebase.

## Cost tiers

Each tier runs only when the one before it passed.

| Tier | When | What runs | Model |
| --- | --- | --- | --- |
| 0 | Every pull request | Lint, typecheck, tests, build, and `scripts/risk-classify.sh` | None |
| 1 | Risk is `low` and `ANTHROPIC_API_KEY` is set | One quick review of the diff | `claude-haiku-5-5` by default, 6 turns |
| 2 | Risk is `med` or `high` and the key is set | A deeper review. Sensitive paths also get a security pass in the same call | `claude-sonnet-5-5` by default, 10 turns |
| 3 | Sensitive paths, and any med or high diff | A human, via `CODEOWNERS` and branch protection | None |

Sensitive paths are always `high`: auth, billing, payments, checkout, CI workflows, migrations, `.env` files, and `CODEOWNERS`. A directory or file name has to match. `author.ts` does not. A bot approval never fills the human slot.

Multi-agent voting is off. Set `voting: true` to pay for a second call that only confirms or rejects the findings just posted.

Drafts skip the model until they are marked ready. Pass `review_drafts: true` to review them anyway.

If `ANTHROPIC_API_KEY` is missing, tier 0 still runs and the model is skipped. The check stays green so a repo can adopt the workflow before it has a key. The job summary says the model did not run. It does not approve the pull request.

## Adopt it

Copy `templates/review-caller.yml` to `.github/workflows/review.yml` in the consumer repo, or add this job:

```yaml
jobs:
  review:
    uses: Viniciuscarvalho/code-review-suite/.github/workflows/review.yml@main
    secrets: inherit
```

`secrets: inherit` passes `ANTHROPIC_API_KEY` when the repo has that secret. The workflow also needs the [Claude GitHub App](https://github.com/apps/claude) on the repo so review comments can be posted. Install and key setup are in the [Claude Code GitHub Action docs](https://code.claude.com/docs/en/github-actions).

Leave the caller's `permissions` unset so this workflow can read the repo, read comments, and write pull request comments. If the caller already sets `permissions`, include `contents: read`, `pull-requests: write`, `issues: read`, and `id-token: write`.

Optional inputs:

- `cheap_model`, `strong_model`
- `allowed_bots`: the code bot's login, for example `your-code-bot[bot]`. Empty means humans only. The action ignores bot actors unless they are listed. Do not use `*`.
- `lint_command`, `typecheck_command`, `test_command`, `build_command`, `install_command`
- `require_checks`: fail tier 0 when a check was skipped instead of run
- `max_cycles` (default 3), `voting`, `review_drafts`

Commands can also live in `.review-suite.env` at the consumer repo root:

```
LINT_CMD=npm run lint
TYPECHECK_CMD=npm run typecheck
TEST_CMD=npm test
BUILD_CMD=npm run build
```

With no override, tier 0 looks at `package.json` scripts and then a Makefile. A step it cannot find is skipped. That skip is not a successful check. Set the command, or set `require_checks: true`, once the repo has the script.

Copy the templates into the consumer repo:

- `templates/CLAUDE.md` to `CLAUDE.md`
- `templates/REVIEW.md` to `REVIEW.md`
- `templates/CODEOWNERS` to `.github/CODEOWNERS` (replace `@org/owners`)
- `templates/pull_request_template.md` to `.github/PULL_REQUEST_TEMPLATE.md`

Do not trigger the caller with `pull_request_target`. Fork pull requests on a public repo do not receive secrets, so the model is skipped and tier 0 still runs.

## Before a bot opens a pull request

Run the checks first, then a reviewer that did not write the code. The `pre-pr-verify` skill is the short version. From the consumer repo:

```bash
git clone --depth 1 https://github.com/Viniciuscarvalho/code-review-suite.git /tmp/code-review-suite
bash /tmp/code-review-suite/scripts/tier0.sh
bash /tmp/code-review-suite/scripts/risk-classify.sh
```

Open the pull request only if tier 0 exits 0 and the clean-context review has no open `Important` finding. Fill in Testing, Risk, and How to revert. The workflow reviews the pull request again.

If that bot's GitHub login opens the pull request, set `allowed_bots` to that login or the model step will refuse to start.

## Risk

`scripts/risk-classify.sh` prints `low`, `med`, or `high` on the first line. It does not call a model.

- Any sensitive path is `high`.
- A config or lockfile change is at least `med` (`package.json`, Dockerfiles, `*.config.*`, lockfiles, and the other names in the script).
- Otherwise a diff of 800 lines or more is `high`, 200 lines or 15 files is `med`, and a smaller diff is `low`.
- A docs-only or asset-only diff stays `low`.
- `med` and `high` set `human_required=true`.

## Humans

Branch protection is the third tier:

- Require the nested check `<caller job> / tier0` (with the caller template, that is `review / tier0`). Do not require the `llm` job. A model outage should not be the only gate.
- Require a review from code owners.
- Put humans or a human team in `CODEOWNERS`. Do not put the bot there.
- Dismiss approvals when new commits are pushed.
- Require conversation resolution before merge.
- Do not let a bot approval satisfy a required review. An approval covers one commit; a later push needs a new human approval.

`low` can merge on a green tier 0 plus a clean model review, once you have decided that is enough. Start stricter and loosen it only if reverts stay flat.

## Convergence

The workflow counts comments that contain `<!-- review-suite:cycle=N sha=... -->`. At 3, it stops calling the model and asks the author to reconsider the approach. A later cycle is told to diff only from the previous sha and not to repeat a finding. The summary has to name the bug class.

The confirmation pass, when voting is on, uses a different marker so it does not consume a cycle.

## Evals

`evals/incidents/` holds reverts and incidents. `evals/validate.sh` checks the files and does not call a model. Rescore the corpus when a review skill, the allowed tools, or a model id changes. The format and the pass rule are in `evals/incidents/README.md`.

A recurring finding becomes a lint rule, a skill, or a line in `REVIEW.md`, and the incident stays in the corpus so the reviewer does not forget it.

## Layout

- `skills/review-quick`, `skills/review-deep`, `skills/security-review`, `skills/pre-pr-verify`
- `templates/` for `CLAUDE.md`, `REVIEW.md`, `CODEOWNERS`, the pull request template, and the caller workflow
- `scripts/risk-classify.sh`, `scripts/tier0.sh`, and the small scripts the workflow uses
- `.github/workflows/review.yml`, the reusable workflow
- `evals/incidents/`

## License

[MIT](LICENSE)
