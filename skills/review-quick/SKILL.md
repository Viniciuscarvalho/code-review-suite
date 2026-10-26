---
name: review-quick
description: One cheap pass over a low-risk diff. Correctness only, with file:line on every finding.
---

# Quick review

Use this for a low-risk diff. Spend as little context as possible.

1. Read `REVIEW.md` and `CLAUDE.md` when the repo has them. The repo's `REVIEW.md` wins on the failure definition, the nit cap, and ignored paths.
2. Read the diff for this cycle. Open another file only when one finding is impossible to judge without it. Stop after 3 extra files.
3. On a later cycle, review only the new diff. Do not repeat a finding already posted. Name the bug class so every instance can be fixed, not just one line.
4. Drop style, formatting, and import-order findings. Lint owns those.

## What a failure is

A failure is a change that does the wrong thing: it breaks the pull request's stated behavior, a caller, a migration, or an auth or billing rule, or it makes `CLAUDE.md` lie. A missing test is a failure only when this diff claims to fix a bug and nothing in the diff would catch that bug again.

These are not failures: formatting, naming taste, and drive-by cleanup.

## Findings

Tag every finding `Important`, `Nit`, or `Pre-existing`.

- `Important`: wrong behavior introduced by this diff.
- `Nit`: a real issue that will not break production. At most 3. Drop the rest.
- `Pre-existing`: a bug this diff did not introduce. Do not ask the author to fix it here.

Every finding has a kebab-case bug class and a `file:line`. No line, no finding.

## Summary

Post one summary. It starts with a count of Important and Nit findings this diff introduced, such as `2 findings`, or the exact words `no issues`. List Pre-existing findings after the count. They do not add to the count.

When the same bug class shows up again across pull requests, say `promote: lint`, `promote: skill`, or `promote: docs` in the summary. Do not invent the lint rule in the review.
