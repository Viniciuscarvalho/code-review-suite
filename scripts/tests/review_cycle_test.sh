#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CYCLE="${ROOT}/scripts/review-cycle.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$CYCLE" ]]; then
  echo "FAIL: ${CYCLE} is missing"
  exit 1
fi

field() {
  local key="$1" file="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); found=1 } END { if (!found) exit 1 }' "$file"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

: >"${tmp}/none.txt"
bash "$CYCLE" --comments-file "${tmp}/none.txt" --max 3 >"${tmp}/none.out"
if [[ "$(field stop "${tmp}/none.out")" == "false" && "$(field cycle "${tmp}/none.out")" == "1" && -z "$(field base_sha "${tmp}/none.out")" ]]; then
  pass "first cycle has no base sha"
else
  fail "first cycle output was $(tr '\n' ' ' <"${tmp}/none.out")"
fi

cat >"${tmp}/two.txt" <<'EOF'
hello
<!-- review-suite:cycle=1 sha=aaa111 -->
later text
<!-- review-suite:vote cycle=1 sha=aaa111 -->
<!-- review-suite:cycle=2 sha=bbb222 -->
EOF
bash "$CYCLE" --comments-file "${tmp}/two.txt" --max 3 >"${tmp}/two.out"
if [[ "$(field stop "${tmp}/two.out")" == "false" && "$(field previous "${tmp}/two.out")" == "2" && "$(field cycle "${tmp}/two.out")" == "3" && "$(field base_sha "${tmp}/two.out")" == "bbb222" ]]; then
  pass "later cycle uses the latest review sha and ignores votes"
else
  fail "two-marker output was $(tr '\n' ' ' <"${tmp}/two.out")"
fi

cat >"${tmp}/three.txt" <<'EOF'
<!-- review-suite:cycle=1 sha=aaa111 -->
<!-- review-suite:cycle=2 sha=bbb222 -->
<!-- review-suite:cycle=3 sha=ccc333 -->
EOF
bash "$CYCLE" --comments-file "${tmp}/three.txt" --max 3 >"${tmp}/three.out"
if [[ "$(field stop "${tmp}/three.out")" == "true" && "$(field cycle "${tmp}/three.out")" == "4" ]]; then
  pass "the fourth cycle stops"
else
  fail "cap output was $(tr '\n' ' ' <"${tmp}/three.out")"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "review-cycle: all tests passed"
