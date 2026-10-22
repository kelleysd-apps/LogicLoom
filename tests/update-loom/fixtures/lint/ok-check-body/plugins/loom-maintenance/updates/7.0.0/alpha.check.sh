#!/bin/sh
# Check: docs/a.md mentions alpha. This comment names curl, eval, git commit and rm -rf
# and a redirect > elsewhere; none of it is code.
set -u
root=${REPO_ROOT:-.}
tmp=${TMPDIR:-/tmp}
. "$TMPDIR/lib-none.sh" 2>/dev/null # eval and wget in a trailing comment
git show HEAD:docs/a.md > "$TMPDIR/out.txt" 2>/dev/null
git rev-parse --git-dir >/dev/null 2>&1
printf 'a > b; git commit; curl\n' > /dev/null
echo "x > y" >/dev/null
awk 'BEGIN { if (2 > 1) print "ok" }' > "${TMPDIR:-/tmp}/o"
echo done >&2
awk 'BEGIN { print "e" > "/dev/stderr"; if ("a" > "b") print "cmp" }' 2>/dev/null
y="$(printf '%s' a)"
z="$(cat "$root/docs/a.md" > "$TMPDIR/copy.txt" 2>/dev/null; printf ok)"
: "$y" "$z"
if grep -F 'alpha' "$root/docs/a.md" >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=The guide does not mention alpha yet.\n'
exit 1
