#!/usr/bin/env bash
# Tests for scripts/tier0.sh. Dry-run prints one tab-separated plan line per step.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIER0="${ROOT}/scripts/tier0.sh"

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

if [[ ! -f "$TIER0" ]]; then
  echo "FAIL: ${TIER0} is missing"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

plan_field() {
  local plan="$1" step="$2"
  awk -F '\t' -v step="$step" '$1 == step { print $2; found=1 } END { if (!found) exit 1 }' <<<"$plan"
}

empty_plan="$(
  cd "$tmp"
  mkdir empty && cd empty
  TIER0_DRY_RUN=1 bash "$TIER0"
)"
if [[ "$(plan_field "$empty_plan" install)" == "skip" && "$(plan_field "$empty_plan" test)" == "skip" ]]; then
  pass "empty repo skips every step"
else
  fail "empty repo plan was: ${empty_plan}"
fi

mkdir -p "${tmp}/pkg"
cat >"${tmp}/pkg/package.json" <<'JSON'
{
  "scripts": {
    "lint": "eslint .",
    "test": "vitest run",
    "build": "tsc -p ."
  }
}
JSON
printf '{}\n' >"${tmp}/pkg/package-lock.json"
pkg_plan="$(
  cd "${tmp}/pkg"
  TIER0_DRY_RUN=1 bash "$TIER0"
)"
if [[ "$(plan_field "$pkg_plan" install)" == "npm ci" ]]; then
  pass "npm lockfile selects npm ci"
else
  fail "install plan was $(plan_field "$pkg_plan" install || true)"
fi
if [[ "$(plan_field "$pkg_plan" lint)" == "npm run lint" && "$(plan_field "$pkg_plan" test)" == "npm test" && "$(plan_field "$pkg_plan" build)" == "npm run build" ]]; then
  pass "package.json scripts are selected"
else
  fail "script plan was: ${pkg_plan}"
fi
if [[ "$(plan_field "$pkg_plan" typecheck)" == "skip" ]]; then
  pass "missing typecheck script is a skip"
else
  fail "typecheck was $(plan_field "$pkg_plan" typecheck || true)"
fi

mkdir -p "${tmp}/make"
cat >"${tmp}/make/Makefile" <<'EOF'
test:
	echo tested
EOF
make_plan="$(
  cd "${tmp}/make"
  TIER0_DRY_RUN=1 bash "$TIER0"
)"
if [[ "$(plan_field "$make_plan" test)" == "make test" && "$(plan_field "$make_plan" lint)" == "skip" ]]; then
  pass "makefile target is used when package.json is absent"
else
  fail "makefile plan was: ${make_plan}"
fi

mkdir -p "${tmp}/env"
printf 'TEST_CMD=pytest -q\n' >"${tmp}/env/.review-suite.env"
env_plan="$(
  cd "${tmp}/env"
  TIER0_DRY_RUN=1 bash "$TIER0"
)"
if [[ "$(plan_field "$env_plan" test)" == "pytest -q" ]]; then
  pass "review-suite.env overrides detection"
else
  fail "env plan test was $(plan_field "$env_plan" test || true)"
fi

explicit_plan="$(
  cd "${tmp}/pkg"
  LINT_CMD='npm run lint:ci' TIER0_DRY_RUN=1 bash "$TIER0"
)"
if [[ "$(plan_field "$explicit_plan" lint)" == "npm run lint:ci" ]]; then
  pass "environment command beats package.json"
else
  fail "explicit lint was $(plan_field "$explicit_plan" lint || true)"
fi

set +e
(
  cd "$tmp/empty"
  LINT_CMD=false TYPECHECK_CMD=skip TEST_CMD=skip BUILD_CMD=skip INSTALL_CMD=skip bash "$TIER0"
) >"${tmp}/fail.out" 2>"${tmp}/fail.err"
fail_status=$?
set -e
if [[ "$fail_status" -ne 0 ]]; then
  pass "failing lint command fails tier 0"
else
  fail "false lint command exited 0"
fi

set +e
(
  cd "$tmp/empty"
  LINT_CMD=true TYPECHECK_CMD=skip TEST_CMD=skip BUILD_CMD=skip INSTALL_CMD=skip bash "$TIER0"
) >"${tmp}/ok.out" 2>"${tmp}/ok.err"
ok_status=$?
set -e
if [[ "$ok_status" -eq 0 ]]; then
  pass "successful explicit commands pass"
else
  fail "true lint command exited ${ok_status}"
fi

set +e
(
  cd "$tmp/empty"
  REQUIRE_CHECKS=1 TIER0_DRY_RUN=1 bash "$TIER0" >"${tmp}/dry-require.out"
)
dry_require=$?
set -e
if [[ "$dry_require" -eq 0 ]]; then
  pass "dry-run does not enforce required checks"
else
  fail "dry-run with REQUIRE_CHECKS exited ${dry_require}"
fi

set +e
(
  cd "$tmp/empty"
  REQUIRE_CHECKS=1 bash "$TIER0"
) >"${tmp}/require.out" 2>"${tmp}/require.err"
require_status=$?
set -e
if [[ "$require_status" -ne 0 ]]; then
  pass "REQUIRE_CHECKS fails when a step is skipped"
else
  fail "REQUIRE_CHECKS exited 0 with every step skipped"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "tier0: all tests passed"
