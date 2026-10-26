#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCATE="${ROOT}/scripts/locate-suite.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$LOCATE" ]]; then
  echo "FAIL: ${LOCATE} is missing"
  exit 1
fi

out="$(bash "$LOCATE" 'acme/suite/.github/workflows/review.yml@refs/heads/main')"
repo="$(awk -F= '$1 == "repo" { print $2 }' <<<"$out")"
ref="$(awk -F= '$1 == "ref" { print $2 }' <<<"$out")"
if [[ "$repo" == "acme/suite" && "$ref" == "refs/heads/main" ]]; then
  pass "workflow ref splits into repo and ref"
else
  fail "parsed repo=${repo} ref=${ref}"
fi

set +e
bash "$LOCATE" 'not-a-workflow-ref' >/dev/null 2>&1
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  pass "a ref without @ is rejected"
else
  fail "bad ref exited 0"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "locate-suite: all tests passed"
