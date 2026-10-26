#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${ROOT}/scripts/build-prompt.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$BUILD" ]]; then
  echo "FAIL: ${BUILD} is missing"
  exit 1
fi

quick="$(
  MODE=quick SECURITY=false CYCLE=2 MAX_CYCLES=3 DIFF_BASE=abc123 HEAD_SHA=def456 \
    REPO=acme/app PR_NUMBER=9 bash "$BUILD"
)"
if [[ "$quick" == *"Quick review"* && "$quick" == *"Do not approve"* && "$quick" == *"abc123"* && "$quick" == *"<!-- review-suite:cycle=2 sha=def456 -->"* ]]; then
  pass "quick prompt carries the cycle marker and the diff base"
else
  fail "quick prompt missed required instructions"
fi
if [[ "$quick" == *"Deep review"* || "$quick" == *"pull_request_target"* ]]; then
  fail "quick prompt included a deeper review"
else
  pass "quick prompt stays on the cheap instructions"
fi

deep="$(
  MODE=deep SECURITY=true CYCLE=1 MAX_CYCLES=3 DIFF_BASE='' HEAD_SHA=fff \
    REPO=acme/app PR_NUMBER=9 bash "$BUILD"
)"
if [[ "$deep" == *"Deep review"* && "$deep" == *"pull_request_target"* && "$deep" == *"Do not approve"* ]]; then
  pass "deep sensitive prompt includes the security review"
else
  fail "deep prompt missed security instructions"
fi

vote="$(
  MODE=vote SECURITY=false CYCLE=1 MAX_CYCLES=3 DIFF_BASE='' HEAD_SHA=fff \
    REPO=acme/app PR_NUMBER=9 bash "$BUILD"
)"
if [[ "$vote" == *"Confirmation pass"* && "$vote" == *"review-suite:vote"* && "$vote" != *"review-suite:cycle="* ]]; then
  pass "vote prompt does not consume a review cycle"
else
  fail "vote prompt marker was wrong"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "build-prompt: all tests passed"
