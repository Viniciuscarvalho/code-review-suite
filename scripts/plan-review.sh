#!/usr/bin/env bash
# Pick the next review tier from risk, the API key, and how many cycles already ran.
# Stdout is key=value. The same lines are appended to GITHUB_OUTPUT when it is set.
set -euo pipefail

: "${KEY_PRESENT:=false}"
: "${RISK:=low}"
: "${SENSITIVE:=false}"
: "${EVENT_NAME:=}"
: "${PR_NUMBER:=}"
: "${IS_DRAFT:=false}"
: "${MAX_CYCLES:=3}"
: "${REVIEW_DRAFTS:=false}"
: "${CHEAP_MODEL:=claude-haiku-5-5}"
: "${STRONG_MODEL:=claude-sonnet-5-5}"
: "${COMMENTS_FILE:=}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mode="skip-no-pr"
reason="not-a-pull-request"
model="$CHEAP_MODEL"
max_turns=6
security=false
cycle=0
base_sha=""

write_out() {
  local block
  block="$(
    printf 'mode=%s\n' "$mode"
    printf 'reason=%s\n' "$reason"
    printf 'model=%s\n' "$model"
    printf 'max_turns=%s\n' "$max_turns"
    printf 'security=%s\n' "$security"
    printf 'cycle=%s\n' "$cycle"
    printf 'base_sha=%s\n' "$base_sha"
  )"
  printf '%s\n' "$block"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s\n' "$block" >>"$GITHUB_OUTPUT"
  fi
}

if [[ "$EVENT_NAME" != "pull_request" || -z "$PR_NUMBER" ]]; then
  write_out
  exit 0
fi

comments="$COMMENTS_FILE"
tmp_comments=""
cleanup() {
  if [[ -n "$tmp_comments" ]]; then
    rm -f "$tmp_comments"
  fi
}
trap cleanup EXIT
if [[ -z "$comments" || ! -f "$comments" ]]; then
  tmp_comments="$(mktemp)"
  comments="$tmp_comments"
fi

cycle_out="$("$ROOT/review-cycle.sh" --comments-file "$comments" --max "$MAX_CYCLES")"
stop="$(awk -F= '$1 == "stop" { print $2 }' <<<"$cycle_out")"
cycle="$(awk -F= '$1 == "cycle" { print $2 }' <<<"$cycle_out")"
base_sha="$(awk -F= '$1 == "base_sha" { print substr($0, 10) }' <<<"$cycle_out")"

if [[ "$IS_DRAFT" == "true" && "$REVIEW_DRAFTS" != "true" ]]; then
  mode="skip-draft"
  reason="draft"
elif [[ "$stop" == "true" ]]; then
  mode="skip-cycle-cap"
  reason="cycle-cap"
elif [[ "$KEY_PRESENT" != "true" ]]; then
  mode="skip-no-key"
  reason="no-api-key"
elif [[ "$SENSITIVE" == "true" || "$RISK" != "low" ]]; then
  mode="deep"
  model="$STRONG_MODEL"
  max_turns=10
  reason="risk-${RISK}"
  if [[ "$SENSITIVE" == "true" ]]; then
    security=true
  fi
else
  mode="quick"
  model="$CHEAP_MODEL"
  max_turns=6
  reason="low-risk"
  security=false
fi

write_out
