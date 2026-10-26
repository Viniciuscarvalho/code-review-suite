#!/usr/bin/env bash
# Assemble one review prompt from the checked-in skills plus this run's facts.
set -euo pipefail

: "${MODE:=quick}"
: "${SECURITY:=false}"
: "${CYCLE:=1}"
: "${MAX_CYCLES:=3}"
: "${DIFF_BASE:=}"
: "${HEAD_SHA:=}"
: "${REPO:=}"
: "${PR_NUMBER:=}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat <<EOF
REPO: ${REPO}
PR NUMBER: ${PR_NUMBER}
MODE: ${MODE}
CYCLE: ${CYCLE} of ${MAX_CYCLES}
DIFF_BASE: ${DIFF_BASE}
HEAD_SHA: ${HEAD_SHA}

The pull request branch is checked out in the current directory.
Do not approve the pull request. Do not push commits. Do not edit files.
A bot approval never counts as a human review.

EOF

case "$MODE" in
  quick)
    cat "${ROOT}/skills/review-quick/SKILL.md"
    ;;
  deep)
    cat "${ROOT}/skills/review-quick/SKILL.md"
    printf '\n'
    cat "${ROOT}/skills/review-deep/SKILL.md"
    ;;
  vote)
    cat <<EOF
# Confirmation pass

You are a second reviewer. Read the latest review comment on this pull request. Do not look for new bugs.

For each finding, reply confirmed or rejected. Reject style, rejected guesses, and anything without file:line. Do not add findings.

Post one summary comment and no inline comments. Include this marker:

<!-- review-suite:vote sha=${HEAD_SHA} -->

Do not include the ordinary review cycle marker in that comment.
End with the count of confirmed findings, or \`no issues\` when none survive.
EOF
    ;;
  *)
    echo "build-prompt: unknown mode ${MODE}" >&2
    exit 2
    ;;
esac

if [[ "$MODE" != "vote" && "$SECURITY" == "true" ]]; then
  printf '\n'
  cat "${ROOT}/skills/security-review/SKILL.md"
fi

if [[ "$MODE" != "vote" ]]; then
  cat <<EOF

## This run

If DIFF_BASE is non-empty, review only \`git diff DIFF_BASE...HEAD\`. Do not repeat a finding already posted on this pull request.
If DIFF_BASE is empty, review the pull request diff.

Post each finding with \`mcp__github_inline_comment__create_inline_comment\` and \`confirmed: true\`.
Post exactly one summary with \`gh pr comment\` and include this marker on its own line:

<!-- review-suite:cycle=${CYCLE} sha=${HEAD_SHA} -->

The summary starts with a count of Important and Nit findings introduced by this diff, for example \`2 findings\`, or the exact words \`no issues\`.
EOF
fi
