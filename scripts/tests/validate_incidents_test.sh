#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATE="${ROOT}/evals/validate.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$VALIDATE" ]]; then
  echo "FAIL: ${VALIDATE} is missing"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

write_incident() {
  local file="$1"
  cat >"$file"
}

mkdir -p "${tmp}/good"
write_incident "${tmp}/good/one.md" <<'EOF'
# sample

- id: sample-auth
- kind: incident
- synthetic: true
- title: Session check fails open
- bug_class: authz-fail-open
- path: src/auth/session.ts
- line: 18
EOF

if bash "$VALIDATE" "${tmp}/good" >"${tmp}/good.out"; then
  pass "a complete incident is accepted"
else
  fail "valid incident was rejected: $(tr '\n' ' ' <"${tmp}/good.out")"
fi

mkdir -p "${tmp}/bad"
write_incident "${tmp}/bad/one.md" <<'EOF'
- id: missing-class
- kind: incident
- title: No class
- path: src/app.ts
EOF
set +e
bash "$VALIDATE" "${tmp}/bad" >"${tmp}/bad.out" 2>"${tmp}/bad.err"
bad_status=$?
set -e
if [[ "$bad_status" -ne 0 ]]; then
  pass "missing bug_class is rejected"
else
  fail "missing bug_class was accepted"
fi

mkdir -p "${tmp}/revert"
write_incident "${tmp}/revert/one.md" <<'EOF'
- id: needs-revert
- kind: revert
- synthetic: false
- title: Bad migration
- bug_class: migration-destructive
- path: db/migrations/001.sql
EOF
set +e
bash "$VALIDATE" "${tmp}/revert" >/dev/null 2>&1
revert_status=$?
set -e
if [[ "$revert_status" -ne 0 ]]; then
  pass "a real revert requires revert_commit"
else
  fail "revert without revert_commit was accepted"
fi

mkdir -p "${tmp}/dup"
write_incident "${tmp}/dup/a.md" <<'EOF'
- id: same
- kind: incident
- synthetic: true
- title: One
- bug_class: null-deref
- path: src/a.ts
EOF
write_incident "${tmp}/dup/b.md" <<'EOF'
- id: same
- kind: incident
- synthetic: true
- title: Two
- bug_class: null-deref
- path: src/b.ts
EOF
set +e
bash "$VALIDATE" "${tmp}/dup" >/dev/null 2>&1
dup_status=$?
set -e
if [[ "$dup_status" -ne 0 ]]; then
  pass "duplicate ids are rejected"
else
  fail "duplicate ids were accepted"
fi

if bash "$VALIDATE" >"${tmp}/repo.out"; then
  pass "checked-in incidents validate"
else
  fail "repo incidents failed: $(tr '\n' ' ' <"${tmp}/repo.out")"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "validate-incidents: all tests passed"
