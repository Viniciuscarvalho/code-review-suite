#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FETCH="${ROOT}/scripts/fetch-review-comments.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$FETCH" ]]; then
  echo "FAIL: ${FETCH} is missing"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "${tmp}/bin"
cat >"${tmp}/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' '<!-- review-suite:cycle=1 sha=abc123 -->'
EOF
chmod +x "${tmp}/bin/gh"

out="$(PATH="${tmp}/bin:${PATH}" PR_NUMBER=4 GITHUB_REPOSITORY=acme/app bash "$FETCH")"
if [[ "$out" == *"review-suite:cycle=1 sha=abc123"* ]]; then
  pass "fetch prints comment bodies"
else
  fail "fetch output was ${out}"
fi

empty="$(PR_NUMBER='' GITHUB_REPOSITORY=acme/app bash "$FETCH")"
status=$?
if [[ "$status" -eq 0 && -z "$empty" ]]; then
  pass "missing PR number yields an empty cycle list"
else
  fail "missing PR status=${status} output=${empty}"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "fetch-comments: all tests passed"
