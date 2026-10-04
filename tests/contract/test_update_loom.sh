#!/bin/sh
# Contract Tests: the /update-loom engine family (POSIX sh).
#
# One registered suite that runs every tests/update-loom/cases-*.sh file under
# ${LOOM_TEST_SH:-/bin/sh} (CI's /bin/sh is dash; /bin/dash exists on current
# macOS too, so `LOOM_TEST_SH=/bin/dash sh tests/contract/test_update_loom.sh`
# is the local proof). Case files live outside tests/contract/ on purpose:
# test_suite_registration.sh requires every tests/contract/**/*.sh to be
# registered in the runner and in CI, and the case files are not suites.
#
# Output contract: every case file prints `PASS  <name>` / `FAIL  <name>`
# lines. This file counts them and ends with one `Results: <p> passed, <f>
# failed` line, which tests/run_all_tests.sh parse_results reads.
set -u

if top=$(git rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ]; then
  root=$top
else
  root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fi
cd "$root" || exit 1

SH=${LOOM_TEST_SH:-/bin/sh}
printf 'Interpreter: %s (%s)\n' "$SH" "$("$SH" -c 'echo ${BASH_VERSION:-posix}')"

work=$(mktemp "${TMPDIR:-/tmp}/loom-update-suite.XXXXXX") || {
  echo "error could not create a temp file under ${TMPDIR:-/tmp}" >&2
  exit 1
}
trap 'rm -f "$work"' EXIT INT TERM

total_pass=0
total_fail=0
bad_exit=0
ran=0

for f in tests/update-loom/cases-*.sh; do
  [ -f "$f" ] || continue
  ran=$((ran + 1))
  printf '== %s\n' "$f"
  "$SH" "$f" > "$work" 2>&1
  rc=$?
  cat "$work"
  p=$(grep -c '^PASS ' "$work")
  x=$(grep -c '^FAIL ' "$work")
  total_pass=$((total_pass + p))
  total_fail=$((total_fail + x))
  if [ "$rc" -ne 0 ]; then
    bad_exit=$((bad_exit + 1))
    printf 'FAIL  %s exited %s\n' "$f" "$rc"
    total_fail=$((total_fail + 1))
  fi
done

if [ "$ran" -eq 0 ]; then
  echo "FAIL  no tests/update-loom/cases-*.sh files found"
  total_fail=$((total_fail + 1))
fi

printf 'Results: %s passed, %s failed\n' "$total_pass" "$total_fail"
if [ "$total_fail" -ne 0 ] || [ "$bad_exit" -ne 0 ]; then
  exit 1
fi
exit 0
