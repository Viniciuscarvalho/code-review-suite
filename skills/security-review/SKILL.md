---
name: security-review
description: Correctness review for auth, billing, migrations, secrets, and CI workflows. Does not approve.
---

# Security review

Run this only when the diff touches auth, billing, payments, migrations, secrets, or CI workflows. It is an extra pass inside a deep review, not a second approval.

Check the changed lines for:

- auth that fails open, including a missing user or session treated as signed in
- a mutation or read that skips an authorization check
- a payment amount, price, or webhook the client can forge
- a migration that drops or rewrites data with no backward path
- a workflow permission change, `pull_request_target`, untrusted input in `run:`, or a secret written to logs
- a committed `.env`, key, or token

Use the same tags, bug class, and `file:line` rule as the quick review. Drop style findings. Do not approve the pull request. A bot approval never counts on these paths.
