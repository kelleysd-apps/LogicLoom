#!/bin/sh
# Check for note settings-ask-restore: permissions.ask lists Bash(git restore:*).
# Contract: REPO_ROOT and UPDATE_TOOLS exported, cwd = REPO_ROOT. Reads JSON only
# through json-flat.sh. Exit 0 = holds; non-zero with a last line hint= = fails.
set -u

root=${REPO_ROOT:-.}
tools=${UPDATE_TOOLS:-$root/plugins/loom-maintenance/scripts}
settings="$root/.claude/settings.json"

if [ -f "$settings" ]; then
  if sh "$tools/json-flat.sh" "$settings" 2>/dev/null | awk -F '\t' '
    $1 ~ "^/permissions/ask/[0-9]+$" && $2 == "Bash(git restore:*)" { found = 1 }
    END { exit (found ? 0 : 1) }
  '; then
    exit 0
  fi
fi

printf 'hint=Restoring files from git does not ask you first yet; take this update and it does.\n'
exit 1
