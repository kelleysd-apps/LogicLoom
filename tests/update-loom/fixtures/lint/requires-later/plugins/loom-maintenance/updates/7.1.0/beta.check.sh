#!/bin/sh
# Check: docs/b.md mentions beta.
set -u
root=${REPO_ROOT:-.}
if grep -F 'beta' "$root/docs/b.md" >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=The second guide does not mention beta yet.\n'
exit 1
