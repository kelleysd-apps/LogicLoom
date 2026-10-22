#!/bin/sh
# Check for note fixture-doc-followup: the follow-up page exists and has its
# section. Contract: REPO_ROOT exported, cwd = REPO_ROOT. Exit 0 = holds;
# non-zero with a last line hint= = fails.
set -u

root=${REPO_ROOT:-.}
doc="$root/.docs/guides/FIXTURE-2.md"

if [ -f "$doc" ] && grep -F '## After the guide' "$doc" >/dev/null 2>&1; then
  exit 0
fi

printf 'hint=The follow-up page is missing from your guides; take this update and it is added.\n'
exit 1
