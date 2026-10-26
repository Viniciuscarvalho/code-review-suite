# Incident evals

Past reverts and incidents are the test set for the reviewer. When a prompt, tool, or model changes, run the reviewer against this set again. CI only checks that the files are well formed. It does not call a model.

## Layout

- `examples/` is the format sample. The synthetic fixture stays here.
- `corpus/` is the real set. Add one Markdown file per revert or incident.

`evals/validate.sh` checks both directories.

## Format

One file per incident. Fields are a list of `- key: value` lines. A `## diff` heading, when present, ends the header. The diff is the bug as it landed, not the fix.

Required:

- `id`: stable kebab-case id, unique across examples and corpus
- `kind`: `revert` or `incident`
- `title`: one line
- `bug_class`: kebab-case class the reviewer must name, such as `authz-fail-open` or `migration-destructive`
- `path`: file the finding has to point at

Optional:

- `line`: line in that file
- `synthetic`: `true` for a made-up fixture. A real `revert` must set `revert_commit`
- `pr`, `bad_commit`, `revert_commit`
- `notes`: what a pass looks like
- a `## diff` section with a unified diff

## What a pass is

A pass names the expected `bug_class` and the expected `path` (and `line`, when the fixture has one). A style comment, a different class, or no finding is a miss. Extra Important findings are noise; record them, and do not treat noise as a pass.

## When to rescore

Rescore the whole corpus after any of these:

- a change to `skills/review-quick`, `skills/review-deep`, or `skills/security-review`
- a change to the tools the workflow allows
- a change to `cheap_model` or `strong_model`

Do this before trusting the new reviewer on a consumer repo. Add the new revert or incident to `corpus/` in the same change that promotes the lesson into a lint rule, a skill, or `REVIEW.md`.
