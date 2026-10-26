#!/usr/bin/env bash
# Classify a diff as low, med, or high. No model, no network.
# Line 1 is the tier. Later lines are key=value for CI.
#
# Risk comes from the change: sensitive paths are always high, config files
# are at least med, and a large non-doc diff moves up a tier. Docs-only
# changes stay low.
set -euo pipefail

MED_LINES=200
HIGH_LINES=800
MED_FILES=15

usage() {
  echo "usage: risk-classify.sh [--paths FILE] [--insertions N] [--deletions N] [--base REF] [--github-output]" >&2
}

paths_file=""
insertions=0
deletions=0
github_output=0
base_ref="${BASE_REF:-}"
tmp_paths=""

cleanup() {
  if [[ -n "$tmp_paths" ]]; then
    rm -f "$tmp_paths"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --paths)
      paths_file="${2:-}"
      shift 2
      ;;
    --insertions)
      insertions="${2:-}"
      shift 2
      ;;
    --deletions)
      deletions="${2:-}"
      shift 2
      ;;
    --base)
      base_ref="${2:-}"
      shift 2
      ;;
    --github-output)
      github_output=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ ! "$insertions" =~ ^[0-9]+$ || ! "$deletions" =~ ^[0-9]+$ ]]; then
  echo "insertions and deletions must be non-negative integers" >&2
  exit 2
fi

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

is_sensitive() {
  local path base rest seg
  path="$(lower "$1")"
  path="${path#./}"
  base="${path##*/}"

  case "$path" in
    .github/workflows|.github/workflows/*|.github/actions|.github/actions/*)
      return 0
      ;;
    .github/codeowners|codeowners)
      return 0
      ;;
  esac

  case "$base" in
    codeowners|.env|.env.*)
      return 0
      ;;
  esac

  rest="$path"
  while [[ -n "$rest" ]]; do
    seg="${rest%%/*}"
    case "$seg" in
      auth|authn|authz|oauth|oauth2|oidc|session|sessions|login|signin|sign-in|sign_in|authentication|authorization)
        return 0
        ;;
      auth-*|*-auth|auth_*|*_auth)
        return 0
        ;;
      billing|payment|payments|stripe|checkout|subscription|subscriptions|invoice|invoices|paypal)
        return 0
        ;;
      migration|migrations|migrate)
        return 0
        ;;
    esac
    if [[ "$rest" == */* ]]; then
      rest="${rest#*/}"
    else
      break
    fi
  done

  case "$base" in
    auth.*|authn.*|authz.*|session.*|sessions.*|login.*|signin.*|authentication.*|authorization.*)
      return 0
      ;;
    billing.*|payment.*|payments.*|invoice.*|invoices.*)
      return 0
      ;;
  esac

  return 1
}

is_config() {
  local path base
  path="$(lower "$1")"
  path="${path#./}"
  base="${path##*/}"
  case "$base" in
    package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lock|bun.lockb)
      return 0
      ;;
    cargo.toml|cargo.lock|go.mod|go.sum|pyproject.toml|poetry.lock|pipfile|pipfile.lock)
      return 0
      ;;
    gemfile|gemfile.lock|composer.json|composer.lock)
      return 0
      ;;
    dockerfile|docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml)
      return 0
      ;;
    tsconfig.json|vercel.json|netlify.toml|fly.toml|render.yaml|requirements.txt)
      return 0
      ;;
    dockerfile.*|docker-compose.*|tsconfig.*.json|requirements-*.txt|requirements.*.txt)
      return 0
      ;;
    *.config.js|*.config.ts|*.config.mjs|*.config.cjs)
      return 0
      ;;
    next.config.*|vite.config.*|webpack.config.*|eslint.config.*|.eslintrc|.eslintrc.*)
      return 0
      ;;
  esac
  return 1
}

is_docs() {
  local path base
  path="$(lower "$1")"
  path="${path#./}"
  base="${path##*/}"
  case "$path" in
    docs/*|.github/issue_template/*|.github/pull_request_template/*)
      return 0
      ;;
  esac
  case "$base" in
    license|changelog|changelog.md|code_of_conduct.md|contributing.md|readme|readme.md)
      return 0
      ;;
    *.md|*.mdx|*.rst|*.adoc|*.txt)
      return 0
      ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.ico)
      return 0
      ;;
  esac
  return 1
}

collect_git() {
  local base="$1" added deleted path ins=0 del=0
  tmp_paths="$(mktemp)"
  git diff --name-only --diff-filter=ACDMRTUXB "${base}...HEAD" >"$tmp_paths"
  while IFS=$'\t' read -r added deleted path || [[ -n "${path:-}" ]]; do
    [[ -z "${path:-}" ]] && continue
    [[ "$added" == "-" ]] && added=0
    [[ "$deleted" == "-" ]] && deleted=0
    ins=$((ins + added))
    del=$((del + deleted))
  done < <(git diff --numstat "${base}...HEAD")
  insertions=$ins
  deletions=$del
  paths_file="$tmp_paths"
}

resolve_base() {
  if [[ -n "$base_ref" ]]; then
    printf '%s\n' "$base_ref"
    return 0
  fi
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    if git rev-parse --verify --quiet "origin/${GITHUB_BASE_REF}" >/dev/null; then
      printf 'origin/%s\n' "$GITHUB_BASE_REF"
      return 0
    fi
    if git rev-parse --verify --quiet "${GITHUB_BASE_REF}" >/dev/null; then
      printf '%s\n' "$GITHUB_BASE_REF"
      return 0
    fi
  fi
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    git merge-base HEAD origin/main
    return 0
  fi
  if git rev-parse --verify --quiet main >/dev/null; then
    git merge-base HEAD main
    return 0
  fi
  echo "risk-classify: could not resolve a base ref. Set BASE_REF or --base." >&2
  return 2
}

if [[ -z "$paths_file" ]]; then
  base_ref="$(resolve_base)"
  collect_git "$base_ref"
fi

if [[ ! -f "$paths_file" ]]; then
  echo "paths file not found: $paths_file" >&2
  exit 2
fi

paths=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  case "$line" in
    ''|\#*) continue ;;
  esac
  paths+=("$line")
done <"$paths_file"

lines=$((insertions + deletions))
files_count="${#paths[@]}"
sensitive=false
tier=low
reasons=""

reason_list=()
sensitive_list=()
config_list=()
code_count=0
docs_count=0

if ((files_count == 0)); then
  reasons="empty"
else
  for path in "${paths[@]}"; do
    if is_sensitive "$path"; then
      sensitive_list+=("$path")
    elif is_config "$path"; then
      config_list+=("$path")
    elif is_docs "$path"; then
      docs_count=$((docs_count + 1))
    else
      code_count=$((code_count + 1))
    fi
  done

  if ((${#sensitive_list[@]} > 0)); then
    sensitive=true
    tier=high
    for path in "${sensitive_list[@]}"; do
      reason_list+=("sensitive:${path}")
    done
  elif ((code_count == 0 && docs_count > 0 && ${#config_list[@]} == 0)); then
    tier=low
    reason_list+=("docs-only")
  else
    for path in "${config_list[@]}"; do
      reason_list+=("config:${path}")
    done
    if ((lines >= HIGH_LINES)); then
      tier=high
      reason_list+=("size")
    elif ((${#config_list[@]} > 0)); then
      tier=med
    elif ((lines >= MED_LINES)); then
      tier=med
      reason_list+=("size")
    elif ((files_count >= MED_FILES)); then
      tier=med
      reason_list+=("files")
    else
      tier=low
      reason_list+=("routine")
    fi
  fi

  if ((${#reason_list[@]} > 0)); then
    reasons="$(IFS=,; printf '%s' "${reason_list[*]}")"
  fi
fi

if [[ "$tier" == "low" ]]; then
  human_required=false
else
  human_required=true
fi

printf '%s\n' "$tier"
printf 'sensitive=%s\n' "$sensitive"
printf 'files=%s\n' "$files_count"
printf 'lines=%s\n' "$lines"
printf 'human_required=%s\n' "$human_required"
printf 'reasons=%s\n' "$reasons"

github_escape() {
  local value="$1"
  value="${value//%/%25}"
  value="${value//$'\n'/%0A}"
  value="${value//$'\r'/%0D}"
  printf '%s' "$value"
}

if ((github_output == 1)); then
  if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "GITHUB_OUTPUT is not set" >&2
    exit 2
  fi
  {
    printf 'risk=%s\n' "$(github_escape "$tier")"
    printf 'sensitive=%s\n' "$(github_escape "$sensitive")"
    printf 'files=%s\n' "$(github_escape "$files_count")"
    printf 'lines=%s\n' "$(github_escape "$lines")"
    printf 'human_required=%s\n' "$(github_escape "$human_required")"
    printf 'reasons=%s\n' "$(github_escape "$reasons")"
  } >>"$GITHUB_OUTPUT"
fi
