#!/bin/sh
# Check: settings.json has an ask list.
set -u
root=${REPO_ROOT:-.}
if grep -F '"ask"' "$root/.claude/settings.json" >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=Your settings file has no ask list yet.\n'
exit 1
