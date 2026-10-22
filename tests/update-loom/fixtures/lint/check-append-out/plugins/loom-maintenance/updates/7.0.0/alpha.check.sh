#!/bin/sh
# Check: docs/a.md mentions alpha.
set -u
root=${REPO_ROOT:-.}
echo x >> out.log
if grep -F 'alpha' "$root/docs/a.md" >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=The guide does not mention alpha yet.\n'
exit 1
