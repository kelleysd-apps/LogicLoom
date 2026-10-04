#!/bin/sh
# Check for note hooks-guard-dangerous: some PreToolUse hook command in
# .claude/settings.json runs the guard script, and the script exists.
# Contract: REPO_ROOT and UPDATE_TOOLS exported, cwd = REPO_ROOT. Reads JSON only
# through json-flat.sh. Exit 0 = holds; non-zero with a last line hint= = fails.
set -u

root=${REPO_ROOT:-.}
tools=${UPDATE_TOOLS:-$root/plugins/loom-maintenance/scripts}
settings="$root/.claude/settings.json"
guard=".claude/hooks/guard-dangerous-commands.sh"

if [ -f "$settings" ] && [ -f "$root/$guard" ]; then
  if sh "$tools/json-flat.sh" "$settings" 2>/dev/null | awk -F '\t' -v g="$guard" '
    $1 ~ "^/hooks/PreToolUse/[0-9]+/hooks/[0-9]+/command$" && index($2, g) > 0 { found = 1 }
    END { exit (found ? 0 : 1) }
  '; then
    exit 0
  fi
fi

printf 'hint=The dangerous-command guard is not wired into .claude/settings.json; take this update and it is.\n'
exit 1
