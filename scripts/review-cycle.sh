#!/usr/bin/env bash
# Count prior review-suite cycles and decide whether another one may run.
# Vote comments use a different marker and do not count.
set -euo pipefail

comments_file=""
max_cycles=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --comments-file)
      comments_file="${2:-}"
      shift 2
      ;;
    --max)
      max_cycles="${2:-}"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$comments_file" || ! -f "$comments_file" ]]; then
  echo "review-cycle: comments file is required" >&2
  exit 2
fi
if [[ ! "$max_cycles" =~ ^[0-9]+$ ]]; then
  echo "review-cycle: --max must be an integer" >&2
  exit 2
fi

previous=0
base_sha=""
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ review-suite:cycle=([0-9]+)\ sha=([^[:space:]]+) ]]; then
    previous="${BASH_REMATCH[1]}"
    base_sha="${BASH_REMATCH[2]}"
  fi
done <"$comments_file"

# The marker's cycle number is authoritative when present. A file with two
# markers still reports previous=2 because the last marker says so. Count
# markers as well and take the larger value, so a missing number cannot hide.
marker_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ review-suite:cycle=[0-9]+[[:space:]]sha=[^[:space:]]+ ]]; then
    marker_count=$((marker_count + 1))
  fi
done <"$comments_file"
if ((marker_count > previous)); then
  previous=$marker_count
fi

cycle=$((previous + 1))
if ((previous >= max_cycles)); then
  stop=true
else
  stop=false
fi

printf 'stop=%s\n' "$stop"
printf 'cycle=%s\n' "$cycle"
printf 'previous=%s\n' "$previous"
printf 'base_sha=%s\n' "$base_sha"
