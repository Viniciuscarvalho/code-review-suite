---
name: pre-pr-verify
description: Run checks, then a clean-context review, before opening a pull request.
---

# Verify before the pull request

Do this before you open a pull request. The author session does not review its own diff.

1. Run lint, typecheck, tests, and build. Use the commands in `CLAUDE.md`, or `scripts/tier0.sh` from this suite. Show the output. If a command fails, fix it and run it again. Do not open the pull request.
2. Run `scripts/risk-classify.sh`. Record `low`, `med`, or `high`, and whether any path is sensitive.
3. Start a reviewer that has not seen this implementation chat. Give it the diff, `CLAUDE.md`, and `REVIEW.md` only.
   - `low`: `review-quick`
   - `med` or `high`: `review-deep`
   - sensitive paths: `review-deep` plus `security-review`
4. Fix `Important` findings. Leave `Pre-existing` findings unless you already touched that code. Ignore style.
5. Open the pull request only after steps 1 and 3 are clean. Fill in Testing, Risk, and How to revert.

Sensitive paths (auth, billing, CI workflows, migrations, secrets) still need a human after the pull request is open. Your own approval does not count as that human.
