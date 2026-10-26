#!/usr/bin/env bash
# Tests for scripts/risk-classify.sh. The script prints the tier on line 1.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIFY="${ROOT}/scripts/risk-classify.sh"

failures=0

fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

pass() {
  echo "ok: $*"
}

tier_of() {
  local out
  out="$("$@" 2>/dev/null || true)"
  printf '%s\n' "${out%%$'\n'*}"
}

field_of() {
  local key="$1"
  shift
  local out line
  out="$("$@" 2>/dev/null || true)"
  while IFS= read -r line; do
    case "$line" in
      "$key"=*)
        printf '%s\n' "${line#"$key"=}"
        return 0
        ;;
    esac
  done <<<"$out"
  return 1
}

with_paths() {
  local file="$1"
  shift
  local insertions="${1:-0}"
  local deletions="${2:-0}"
  "$CLASSIFY" --paths "$file" --insertions "$insertions" --deletions "$deletions"
}

expect_tier() {
  local name="$1"
  local expected="$2"
  local file="$3"
  local insertions="${4:-0}"
  local deletions="${5:-0}"
  local got
  got="$(tier_of with_paths "$file" "$insertions" "$deletions")"
  if [[ "$got" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name expected ${expected} got ${got}"
  fi
}

expect_field() {
  local name="$1"
  local key="$2"
  local expected="$3"
  local file="$4"
  local insertions="${5:-0}"
  local deletions="${6:-0}"
  local got
  got="$(field_of "$key" with_paths "$file" "$insertions" "$deletions" || true)"
  if [[ "$got" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name expected ${key}=${expected} got ${key}=${got}"
  fi
}

expect_reason_has() {
  local name="$1"
  local needle="$2"
  local file="$3"
  local insertions="${4:-0}"
  local deletions="${5:-0}"
  local got
  got="$(field_of reasons with_paths "$file" "$insertions" "$deletions" || true)"
  case "$got" in
    *"$needle"*) pass "$name" ;;
    *) fail "$name expected reason containing '${needle}' got '${got}'" ;;
  esac
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

paths() {
  local name="$1"
  shift
  : >"${tmp}/${name}"
  local p
  for p in "$@"; do
    printf '%s\n' "$p" >>"${tmp}/${name}"
  done
  printf '%s\n' "${tmp}/${name}"
}

if [[ ! -x "$CLASSIFY" && ! -f "$CLASSIFY" ]]; then
  echo "FAIL: ${CLASSIFY} is missing"
  exit 1
fi

empty="$(paths empty)"
expect_tier "empty change is low" low "$empty"
expect_reason_has "empty change explains itself" empty "$empty"
expect_field "empty change needs no human" human_required false "$empty"

readme="$(paths readme README.md)"
expect_tier "docs-only stays low even when large" low "$readme" 4000 1000
expect_reason_has "docs-only reason" docs-only "$readme" 4000 1000
expect_field "docs-only is not sensitive" sensitive false "$readme" 10 0

author="$(paths author src/author.ts)"
expect_tier "author.ts is not an auth path" low "$author" 20 0

app="$(paths app src/app.ts)"
expect_tier "small product diff is low" low "$app" 40 10
expect_tier "200 lines is med" med "$app" 200 0
expect_tier "199 lines stays low" low "$app" 199 0
expect_tier "800 lines is high" high "$app" 800 0
expect_field "size high is not sensitive" sensitive false "$app" 800 0
expect_field "size high needs a human" human_required true "$app" 800 0

many="$(paths many src/a.ts src/b.ts src/c.ts src/d.ts src/e.ts src/f.ts src/g.ts src/h.ts src/i.ts src/j.ts src/k.ts src/l.ts src/m.ts src/n.ts src/o.ts)"
expect_tier "15 files is med" med "$many" 30 0
expect_reason_has "file-count reason" files "$many" 30 0

pkg="$(paths pkg package.json)"
expect_tier "package.json is med" med "$pkg" 8 1
expect_reason_has "config reason" config: "$pkg" 8 1
expect_field "config needs a human" human_required true "$pkg" 8 1

auth="$(paths auth src/auth/session.ts)"
expect_tier "auth directory is high" high "$auth" 4 0
expect_field "auth is sensitive" sensitive true "$auth" 4 0
expect_field "auth needs a human" human_required true "$auth" 4 0
expect_reason_has "auth reason names the path" "sensitive:src/auth/session.ts" "$auth" 4 0

login="$(paths login src/Auth/Login.ts)"
expect_tier "auth basename is matched case-insensitively" high "$login" 3 0

billing="$(paths billing apps/web/billing/invoice.ts)"
expect_tier "billing path is high" high "$billing" 12 0

workflow="$(paths workflow .github/workflows/ci.yml)"
expect_tier "workflow file is high" high "$workflow" 15 0

actions="$(paths actions .github/actions/setup/action.yml)"
expect_tier "composite action is high" high "$actions" 15 0

migration="$(paths migration db/migrations/001_init.sql)"
expect_tier "sql migration is high" high "$migration" 40 0

prisma="$(paths prisma prisma/migrations/20260101_init/migration.sql)"
expect_tier "prisma migration is high" high "$prisma" 20 0

dotenv="$(paths dotenv .env.production)"
expect_tier "env file is high" high "$dotenv" 2 0

owners="$(paths owners .github/CODEOWNERS)"
expect_tier "CODEOWNERS is high" high "$owners" 6 0

not_workflow="$(paths notwf docs/workflows/build.md)"
expect_tier "docs about workflows stay low" low "$not_workflow" 30 0

mixed="$(paths mixed README.md src/auth/login.ts)"
expect_tier "sensitive wins over docs" high "$mixed" 10 0

config_and_size="$(paths both package.json src/app.ts)"
expect_tier "config plus a huge diff is high" high "$config_and_size" 900 0
expect_field "config plus size is not automatically sensitive" sensitive false "$config_and_size" 900 0

# Git mode: sensitive file on a feature branch against main.
gitrepo="${tmp}/repo"
mkdir -p "${gitrepo}/src/auth"
git -C "$gitrepo" init -b main >/dev/null
git -C "$gitrepo" config user.email "test@example.com"
git -C "$gitrepo" config user.name "Test"
printf 'ok\n' >"${gitrepo}/README.md"
git -C "$gitrepo" add README.md
git -C "$gitrepo" commit -q -m init
git -C "$gitrepo" checkout -q -b feature
printf 'return user == null\n' >"${gitrepo}/src/auth/session.ts"
git -C "$gitrepo" add src/auth/session.ts
git -C "$gitrepo" commit -q -m "open auth"
git_status=0
git_out="$(cd "$gitrepo" && BASE_REF=main "$CLASSIFY" 2>"${tmp}/git.err")" || git_status=$?
git_tier="${git_out%%$'\n'*}"
if [[ "$git_status" -eq 0 && "$git_tier" == "high" ]]; then
  pass "git mode classifies auth as high"
else
  fail "git mode expected high got ${git_tier} status ${git_status} ($(tr '\n' ' ' <"${tmp}/git.err"))"
fi

# GitHub output is a single tier plus machine-readable keys.
gh_out="${tmp}/gh.out"
(
  cd "$gitrepo" || exit 1
  GITHUB_OUTPUT="$gh_out" BASE_REF=main "$CLASSIFY" --github-output
) >/dev/null
if grep -qx 'risk=high' "$gh_out" && grep -qx 'sensitive=true' "$gh_out"; then
  pass "github-output writes risk and sensitive"
else
  fail "github-output missing expected keys ($(tr '\n' ' ' <"$gh_out"))"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} failure(s)"
  exit 1
fi
echo "risk-classify: all tests passed"
