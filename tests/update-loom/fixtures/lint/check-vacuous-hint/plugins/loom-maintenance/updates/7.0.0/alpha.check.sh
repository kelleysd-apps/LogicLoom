#!/bin/sh
# Check: the guide mentions alpha.
set -u
if grep -F 'alpha' README.md >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=docs/a.md does not mention alpha yet.\n'
exit 1
