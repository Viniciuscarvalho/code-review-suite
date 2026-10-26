#!/usr/bin/env bash
# Check incident fixtures. This does not call a model.
# With no arguments, validates the examples and corpus shipped in this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -eq 0 ]]; then
  set -- "${ROOT}/evals/incidents/examples" "${ROOT}/evals/incidents/corpus"
fi

errors=0
declare -A seen_ids=()

note() {
  echo "$*" >&2
  errors=$((errors + 1))
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

validate_file() {
  local file="$1"
  local id="" kind="" title="" bug_class="" path="" synthetic="false" revert_commit=""
  local line in_header=1

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$in_header" -eq 1 && "$line" == "## diff" ]]; then
      break
    fi
    case "$line" in
      "- id: "*) id="$(trim "${line#- id: }")" ;;
      "- kind: "*) kind="$(trim "${line#- kind: }")" ;;
      "- title: "*) title="$(trim "${line#- title: }")" ;;
      "- bug_class: "*) bug_class="$(trim "${line#- bug_class: }")" ;;
      "- path: "*) path="$(trim "${line#- path: }")" ;;
      "- synthetic: "*) synthetic="$(trim "${line#- synthetic: }")" ;;
      "- revert_commit: "*) revert_commit="$(trim "${line#- revert_commit: }")" ;;
    esac
  done <"$file"

  if [[ -z "$id" ]]; then
    note "${file}: missing id"
    return 0
  fi
  if [[ -n "${seen_ids[$id]:-}" ]]; then
    note "${file}: duplicate id ${id} (also ${seen_ids[$id]})"
  else
    seen_ids["$id"]="$file"
  fi
  case "$kind" in
    revert|incident) ;;
    *) note "${file}: kind must be revert or incident" ;;
  esac
  if [[ -z "$title" ]]; then
    note "${file}: missing title"
  fi
  if [[ ! "$bug_class" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    note "${file}: bug_class must be kebab-case"
  fi
  if [[ -z "$path" ]]; then
    note "${file}: missing path"
  fi
  if [[ "$kind" == "revert" && "$synthetic" != "true" && -z "$revert_commit" ]]; then
    note "${file}: revert fixtures need revert_commit unless synthetic: true"
  fi
}

shopt -s nullglob
files=()
for dir in "$@"; do
  if [[ ! -d "$dir" ]]; then
    note "not a directory: ${dir}"
    continue
  fi
  for file in "$dir"/*.md; do
    files+=("$file")
  done
done

if ((${#files[@]} == 0)); then
  echo "no incident files"
  exit 0
fi

for file in "${files[@]}"; do
  validate_file "$file"
done

if ((errors > 0)); then
  echo "${errors} incident error(s)" >&2
  exit 1
fi

echo "${#files[@]} incident file(s) ok"
