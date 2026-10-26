#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN="${ROOT}/scripts/plan-review.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$PLAN" ]]; then
  echo "FAIL: ${PLAN} is missing"
  exit 1
fi

field() {
  local key="$1" text="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); found=1 } END { if (!found) exit 1 }' <<<"$text"
}

run_plan() {
  env -u GITHUB_OUTPUT \
    KEY_PRESENT="${KEY_PRESENT:-false}" \
    RISK="${RISK:-low}" \
    SENSITIVE="${SENSITIVE:-false}" \
    EVENT_NAME="${EVENT_NAME:-pull_request}" \
    PR_NUMBER="${PR_NUMBER:-12}" \
    IS_DRAFT="${IS_DRAFT:-false}" \
    MAX_CYCLES="${MAX_CYCLES:-3}" \
    REVIEW_DRAFTS="${REVIEW_DRAFTS:-false}" \
    CHEAP_MODEL="${CHEAP_MODEL:-claude-haiku-5-5}" \
    STRONG_MODEL="${STRONG_MODEL:-claude-sonnet-5-5}" \
    COMMENTS_FILE="${COMMENTS_FILE:-}" \
    bash "$PLAN"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
: >"${tmp}/empty.txt"

out="$(EVENT_NAME=push PR_NUMBER='' KEY_PRESENT=true COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "skip-no-pr" ]]; then
  pass "non-PR events skip the model"
else
  fail "push mode was $(field mode "$out" || true)"
fi

out="$(IS_DRAFT=true KEY_PRESENT=true RISK=low COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "skip-draft" ]]; then
  pass "drafts skip the model"
else
  fail "draft mode was $(field mode "$out" || true)"
fi

out="$(IS_DRAFT=true REVIEW_DRAFTS=true KEY_PRESENT=true RISK=low COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "quick" ]]; then
  pass "review_drafts allows a draft"
else
  fail "forced draft mode was $(field mode "$out" || true)"
fi

out="$(KEY_PRESENT=false RISK=low COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "skip-no-key" ]]; then
  pass "missing API key skips the model"
else
  fail "no-key mode was $(field mode "$out" || true)"
fi

out="$(KEY_PRESENT=true RISK=low SENSITIVE=false COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "quick" && "$(field model "$out")" == "claude-haiku-5-5" && "$(field security "$out")" == "false" && "$(field cycle "$out")" == "1" ]]; then
  pass "low risk uses the cheap model"
else
  fail "quick plan was $(tr '\n' ' ' <<<"$out")"
fi

out="$(KEY_PRESENT=true RISK=med SENSITIVE=false COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "deep" && "$(field model "$out")" == "claude-sonnet-5-5" && "$(field security "$out")" == "false" ]]; then
  pass "med risk uses the strong model"
else
  fail "med plan was $(tr '\n' ' ' <<<"$out")"
fi

out="$(KEY_PRESENT=true RISK=high SENSITIVE=true COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "deep" && "$(field security "$out")" == "true" ]]; then
  pass "sensitive paths add a security review"
else
  fail "sensitive plan was $(tr '\n' ' ' <<<"$out")"
fi

out="$(KEY_PRESENT=true RISK=low SENSITIVE=true COMMENTS_FILE="${tmp}/empty.txt" run_plan)"
if [[ "$(field mode "$out")" == "deep" && "$(field security "$out")" == "true" ]]; then
  pass "sensitive flag beats a low tier"
else
  fail "sensitive-low plan was $(tr '\n' ' ' <<<"$out")"
fi

cat >"${tmp}/capped.txt" <<'EOF'
<!-- review-suite:cycle=1 sha=aaa111 -->
<!-- review-suite:cycle=2 sha=bbb222 -->
<!-- review-suite:cycle=3 sha=ccc333 -->
EOF
out="$(KEY_PRESENT=true RISK=high COMMENTS_FILE="${tmp}/capped.txt" run_plan)"
if [[ "$(field mode "$out")" == "skip-cycle-cap" && "$(field cycle "$out")" == "4" ]]; then
  pass "a capped PR does not call the model"
else
  fail "cap plan was $(tr '\n' ' ' <<<"$out")"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "plan-review: all tests passed"
