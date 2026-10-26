#!/usr/bin/env bash
# Run install, lint, typecheck, test, and build when this repo defines them.
# No model. A missing command is skipped unless REQUIRE_CHECKS=1.
#
# Overrides, first hit wins:
#   environment variables LINT_CMD, TYPECHECK_CMD, TEST_CMD, BUILD_CMD, INSTALL_CMD
#   .review-suite.env in the repo root (same keys)
#   package.json scripts, then a Makefile target
#
# Set a command to "skip" to force it off. TIER0_DRY_RUN=1 prints the plan.
set -euo pipefail

: "${LINT_CMD:=}"
: "${TYPECHECK_CMD:=}"
: "${TEST_CMD:=}"
: "${BUILD_CMD:=}"
: "${INSTALL_CMD:=}"
: "${REQUIRE_CHECKS:=0}"
: "${TIER0_DRY_RUN:=0}"

load_env_file() {
  local file="$1" line key value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      ''|\#*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      LINT_CMD) [[ -z "$LINT_CMD" ]] && LINT_CMD="$value" ;;
      TYPECHECK_CMD) [[ -z "$TYPECHECK_CMD" ]] && TYPECHECK_CMD="$value" ;;
      TEST_CMD) [[ -z "$TEST_CMD" ]] && TEST_CMD="$value" ;;
      BUILD_CMD) [[ -z "$BUILD_CMD" ]] && BUILD_CMD="$value" ;;
      INSTALL_CMD) [[ -z "$INSTALL_CMD" ]] && INSTALL_CMD="$value" ;;
      REQUIRE_CHECKS) [[ "$REQUIRE_CHECKS" == "0" ]] && REQUIRE_CHECKS="$value" ;;
    esac
  done <"$file"
}

package_has_script() {
  local name="$1"
  python3 - "$name" <<'PY'
import json, sys
name = sys.argv[1]
try:
    with open("package.json", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)
scripts = data.get("scripts") or {}
sys.exit(0 if name in scripts else 1)
PY
}

first_script() {
  local name
  for name in "$@"; do
    if package_has_script "$name"; then
      printf '%s\n' "$name"
      return 0
    fi
  done
  return 1
}

has_make_target() {
  local target="$1" file
  for file in Makefile makefile; do
    [[ -f "$file" ]] || continue
    if grep -Eq "^${target}[[:space:]]*:" "$file"; then
      return 0
    fi
  done
  return 1
}

pm=""
if [[ -f package.json ]]; then
  if [[ -f pnpm-lock.yaml ]]; then
    pm="pnpm"
  elif [[ -f yarn.lock ]]; then
    pm="yarn"
  elif [[ -f bun.lock || -f bun.lockb ]]; then
    pm="bun"
  else
    pm="npm"
  fi
fi

pm_run() {
  local name="$1"
  if [[ "$pm" == "npm" && "$name" == "test" ]]; then
    printf 'npm test'
    return 0
  fi
  printf '%s run %s' "$pm" "$name"
}

fill_from_package_or_make() {
  local var_name="$1"
  shift
  local current script
  current="${!var_name}"
  if [[ -n "$current" ]]; then
    return 0
  fi
  if [[ -n "$pm" ]]; then
    if script="$(first_script "$@")"; then
      printf -v "$var_name" '%s' "$(pm_run "$script")"
      return 0
    fi
  fi
  if has_make_target "$1"; then
    printf -v "$var_name" '%s' "make $1"
    return 0
  fi
  printf -v "$var_name" '%s' "skip"
}

load_env_file ".review-suite.env"

if [[ -z "$INSTALL_CMD" ]]; then
  if [[ -f pnpm-lock.yaml ]]; then
    INSTALL_CMD="pnpm install --frozen-lockfile"
  elif [[ -f yarn.lock ]]; then
    INSTALL_CMD="yarn install --frozen-lockfile"
  elif [[ -f bun.lock || -f bun.lockb ]]; then
    INSTALL_CMD="bun install --frozen-lockfile"
  elif [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
    INSTALL_CMD="npm ci"
  elif [[ -f package.json ]]; then
    INSTALL_CMD="npm install"
  else
    INSTALL_CMD="skip"
  fi
fi

fill_from_package_or_make LINT_CMD lint
fill_from_package_or_make TYPECHECK_CMD typecheck type-check
fill_from_package_or_make TEST_CMD test
fill_from_package_or_make BUILD_CMD build

run_step() {
  local name="$1" cmd="$2"
  if [[ "$TIER0_DRY_RUN" == "1" ]]; then
    printf '%s\t%s\n' "$name" "$cmd"
    return 0
  fi
  if [[ -z "$cmd" || "$cmd" == "skip" ]]; then
    echo "tier0: ${name} skipped"
    if [[ "$name" != "install" && ( "$REQUIRE_CHECKS" == "1" || "$REQUIRE_CHECKS" == "true" ) ]]; then
      echo "tier0: ${name} is required" >&2
      return 1
    fi
    return 0
  fi
  echo "tier0: ${name}: ${cmd}"
  bash -c "$cmd"
}

run_step install "$INSTALL_CMD"
run_step lint "$LINT_CMD"
run_step typecheck "$TYPECHECK_CMD"
run_step test "$TEST_CMD"
run_step build "$BUILD_CMD"
