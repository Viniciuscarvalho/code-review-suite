#!/usr/bin/env bash
# Split GITHUB_WORKFLOW_REF into the suite repo and the ref to check out.
# Example: acme/suite/.github/workflows/review.yml@refs/heads/main
set -euo pipefail

workflow_ref="${1:-${GITHUB_WORKFLOW_REF:-}}"
if [[ -z "$workflow_ref" || "$workflow_ref" != *@* ]]; then
  echo "locate-suite: expected owner/repo/path@ref" >&2
  exit 2
fi

ref="${workflow_ref##*@}"
rest="${workflow_ref%@*}"
repo="$(printf '%s\n' "$rest" | cut -d/ -f1-2)"
if [[ -z "$repo" || -z "$ref" || "$repo" != */* ]]; then
  echo "locate-suite: could not parse ${workflow_ref}" >&2
  exit 2
fi

printf 'repo=%s\n' "$repo"
printf 'ref=%s\n' "$ref"
