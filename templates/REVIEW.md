# Review

The change sets the risk, not the author. A bot approval never counts as a human review. Auth, billing, CI workflows, migrations, and secrets always need a human.

## What a failure is

A failure is a change that does the wrong thing: it breaks the behavior this pull request claims, a caller, a migration, or an auth or billing rule, or it makes `CLAUDE.md` lie.

A missing test is a failure only when the diff claims to fix a bug and nothing in the diff would catch that bug again.

Style, formatting, and import order are not failures. Lint owns them. Do not comment on them.

## Findings

Tag each finding `Important`, `Nit`, or `Pre-existing`.

- `Important`: wrong behavior this diff introduced.
- `Nit`: a real issue that will not break production. At most 3 per review. Drop the rest.
- `Pre-existing`: a bug this diff did not introduce. Report it, and do not block the author on it.

Every finding has a kebab-case bug class and a `file:line`. If you cannot name the line, do not post the finding.

## Ignored paths

Do not comment on:

- lockfiles
- `dist/`, `build/`, `coverage/`, `vendor/`
- generated files and `*.min.js`

Those paths can still raise risk. A lockfile change is not low risk just because you do not comment on it.

## Summary

Start with a count of Important and Nit findings this diff introduced, such as `2 findings`, or the exact words `no issues`.

List Pre-existing findings after that count. They do not add to it.

Name the bug class in the summary so a later pass fixes every instance, not one line.

## Convergence

At most 3 review cycles. After the first cycle, review only the new diff. Do not repeat a finding already posted. After the third cycle, stop and ask the author to reconsider the approach.

## When a finding recurs

Promote it. Say `promote: lint`, `promote: skill`, or `promote: docs` in the summary, and add the revert or incident to the review eval set. Do not keep catching the same bug in prose.
