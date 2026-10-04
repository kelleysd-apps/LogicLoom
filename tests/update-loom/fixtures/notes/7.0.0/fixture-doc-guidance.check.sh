#!/bin/sh
# Check for note fixture-doc-guidance: the guide carries the new sentence.
# Contract: REPO_ROOT exported, cwd = REPO_ROOT. Exit 0 = holds; non-zero with a
# last line hint= = fails.
set -u

root=${REPO_ROOT:-.}
doc="$root/.docs/guides/FIXTURE.md"

if [ -f "$doc" ] && grep -F 'Run /update-loom to take improvements.' "$doc" >/dev/null 2>&1; then
  exit 0
fi

printf 'hint=The guide does not yet tell you to run /update-loom; take this update and it does.\n'
exit 1
