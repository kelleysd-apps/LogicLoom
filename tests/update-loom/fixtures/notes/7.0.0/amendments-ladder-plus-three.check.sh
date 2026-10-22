#!/bin/sh
# Check for note amendments-ladder-plus-three. Tests only the defect pattern,
# never conformance to any LogicLoom wording. Contract: REPO_ROOT exported,
# cwd = REPO_ROOT. skip=<reason> with exit 0 = not applicable in this copy;
# non-zero with a last line hint= = the defect is present.
set -u

root=${REPO_ROOT:-.}
file="$root/.logic-loom/memory/amendments.md"
pattern='^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic'

if [ ! -f "$file" ]; then
  printf 'skip=no amendments file in this copy\n'
  exit 0
fi

if grep -E "$pattern" "$file" >/dev/null 2>&1; then
  printf 'hint=Your escalation ladder scores the auth/payment case on the wrong scale; adapt the file and that line moves to a +3 on top.\n'
  exit 1
fi

exit 0
