#!/bin/sh
# Runs every Bend test file under this directory; exits non-zero if any fails.
# Needs `bend` (https://bend-lang.com) on PATH.
cd "$(dirname "$0")" || exit 1
status=0
for file in $(find . -name '*.test.bend' | sort); do
  if out=$(BEND_NO_TELEMETRY=1 bend "$file" 2>&1); then
    printf '%-40s %s\n' "$file" "$(printf '%s\n' "$out" | tail -n 1)"
  else
    printf '%-40s FAILED\n' "$file"
    printf '%s\n' "$out" | grep -A2 '^FAIL' | head -n 30
    status=1
  fi
done
exit $status
