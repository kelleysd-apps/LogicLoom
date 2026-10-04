#!/bin/sh
# Check: docs/gone.md is absent.
set -u
root=${REPO_ROOT:-.}
if [ ! -e "$root/docs/gone.md" ]; then
  exit 0
fi
printf 'hint=The old guide is still there.\n'
exit 1
