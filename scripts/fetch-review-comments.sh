#!/usr/bin/env bash
# Print pull request comment bodies. Missing context or a failing gh exits 0
# with no output so a review can still run as cycle 1.
set -euo pipefail

if [[ -z "${PR_NUMBER:-}" || -z "${GITHUB_REPOSITORY:-}" ]]; then
  exit 0
fi
if ! command -v gh >/dev/null 2>&1; then
  exit 0
fi

gh api --paginate "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" --jq '.[].body' || true
