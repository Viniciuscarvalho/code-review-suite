#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

failures=0
for test_file in scripts/tests/*_test.sh; do
  echo "== ${test_file}"
  if bash "$test_file"; then
    :
  else
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test file(s) failed"
  exit 1
fi
echo "all test files passed"
