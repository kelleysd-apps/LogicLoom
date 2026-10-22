#!/bin/sh
# Check: the amendments file has no defect line.
set -u
root=${REPO_ROOT:-.}
file="$root/.logic-loom/memory/amendments.md"
if [ ! -f "$file" ]; then
  printf 'skip=no amendments file in this copy\n'
  exit 0
fi
if grep -E '^bad line' "$file" >/dev/null 2>&1; then
  printf 'hint=A line in your amendments file matches a known defect.\n'
  exit 1
fi
exit 0
