#!/usr/bin/env bash
# Contract test — check-dev-branch-base.sh (LOOM-0024)
#
# The guard warns when a LogicLoom checkout or a freshly created worktree is
# sitting on the sanitized TEMPLATE line (`main`) rather than on the integration
# line (`dev-main`). See .docs/policies/environment-promotion-policy.md § 2.2.
#
# WHAT THIS SUITE ASSERTS, AND WHY EACH ONE MATTERS
#   1. LogicLoom-shaped repo, HEAD on the main tip  → fires, with the remedy.
#   2. Same repo, HEAD on the dev-main tip          → silent.
#   3. CUSTOMER-shaped repo (main, no dev-main)     → silent. THE important one:
#      a false positive here would fire on every customer session.
#   4. Neither branch / detached HEAD / no git      → silent, exit 0, no crash.
#   5. RUNS NO GIT — proven at runtime with a PATH shim that records any call,
#      not by grepping the source.
#
# Fixtures are hand-built .git directories, not real repositories: the guard
# reads refs off the filesystem by design, so it is testable without git — and
# building the fixture with git would defeat assertion 5.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$REPO_ROOT/.logic-loom/scripts/bash/check-dev-branch-base.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-devbase-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

SHA_MAIN=1111111111111111111111111111111111111111
SHA_DEV=2222222222222222222222222222222222222222
SHA_OTHER=3333333333333333333333333333333333333333

echo "══════════════════════════════════════════════════"
echo "  Dev Branch Base Guard — Contract Test (LOOM-0024)"
echo "══════════════════════════════════════════════════"
echo ""

# ── fixture builder ──────────────────────────────────────────────────────────
# make_repo <name> <head-content> [branch:sha ...] — branch specs of the form
# `heads/main:<sha>` or `remotes/origin/dev-main:<sha>`.
make_repo() {
  local name="$1"; shift
  local head="$1"; shift
  local dir="$TMP/$name"
  mkdir -p "$dir/.git/refs/heads" "$dir/.git/refs/remotes/origin"
  # The guard delegates the branch inventory to the topology detector, which it
  # locates relative to itself — so the fixture needs the script tree present.
  mkdir -p "$dir/.logic-loom/scripts/bash"
  cp "$REPO_ROOT/.logic-loom/scripts/bash/detect-environment-topology.sh" \
     "$dir/.logic-loom/scripts/bash/"
  cp "$GUARD" "$dir/.logic-loom/scripts/bash/"
  printf '%s\n' "$head" > "$dir/.git/HEAD"
  local spec ref sha
  for spec in "$@"; do
    ref="${spec%%:*}"; sha="${spec##*:}"
    mkdir -p "$dir/.git/refs/$(dirname "$ref")"
    printf '%s\n' "$sha" > "$dir/.git/refs/$ref"
  done
  printf '%s' "$dir"
}

run_guard() { # <root> [extra args...] -> stdout of --format text
  local root="$1"; shift
  bash "$root/.logic-loom/scripts/bash/check-dev-branch-base.sh" \
       --root "$root" --format text --no-marker "$@" </dev/null 2>/dev/null
}

# ═════════════════════════════════════════════════════════════════════════════
echo "1. LogicLoom-shaped repo, checkout based on 'main' → FIRES"
# The realistic shape of the observed defect: EnterWorktree made a NEW branch
# whose tip is exactly origin/main. The branch name is innocuous.
R1="$(make_repo logicloom-on-main 'ref: refs/heads/worktree-review' \
      heads/main:$SHA_MAIN \
      heads/dev-main:$SHA_DEV \
      heads/worktree-review:$SHA_MAIN \
      remotes/origin/main:$SHA_MAIN \
      remotes/origin/dev-main:$SHA_DEV)"
OUT1="$(run_guard "$R1")"; RC1=$?
echo "--- actual output ---"
printf '%s\n' "$OUT1"
echo "--- end ---"
check "exits 0" "$RC1" "0"
if grep -q "WRONG BASE" <<< "$OUT1"; then ok "fires"; else bad "fires"; fi
if grep -q "dev-main" <<< "$OUT1"; then ok "names the integration line"; else bad "names the integration line"; fi
if grep -q "git reset --hard origin/dev-main" <<< "$OUT1"; then ok "gives an exact remedy command"; else bad "gives an exact remedy command"; fi
if grep -q "sanitized" <<< "$OUT1"; then ok "explains WHY it is wrong"; else bad "explains WHY it is wrong"; fi
if grep -q "LOOM-0024" <<< "$OUT1"; then ok "cites the policy reference"; else bad "cites the policy reference"; fi
echo ""

echo "1b. Same topology, but HEAD literally on branch 'main' → FIRES, different remedy"
R1B="$(make_repo logicloom-branch-main 'ref: refs/heads/main' \
       heads/main:$SHA_MAIN heads/dev-main:$SHA_DEV)"
OUT1B="$(run_guard "$R1B")"
echo "--- actual output (remedy line only) ---"
printf '%s\n' "$OUT1B" | grep -A1 "Fix (run"
echo "--- end ---"
if grep -q "git switch dev-main" <<< "$OUT1B"; then ok "remedy is a plain switch"; else bad "remedy is a plain switch"; fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
echo "2. Same repo, checkout based on 'dev-main' → SILENT"
R2="$(make_repo logicloom-on-dev 'ref: refs/heads/worktree-review' \
      heads/main:$SHA_MAIN \
      heads/dev-main:$SHA_DEV \
      heads/worktree-review:$SHA_DEV \
      remotes/origin/main:$SHA_MAIN \
      remotes/origin/dev-main:$SHA_DEV)"
OUT2="$(run_guard "$R2")"; RC2=$?
echo "--- actual output ---"; printf '%s\n' "$OUT2"; echo "--- end (empty above = silent) ---"
check "exits 0" "$RC2" "0"
check "produces no output" "$(printf '%s' "$OUT2" | wc -c | tr -d ' ')" "0"
echo ""

echo "2b. Same repo, branch already has its own commits (off both tips) → SILENT"
# Ancestry is unknowable without git; the guard does not guess.
R2B="$(make_repo logicloom-own-commits 'ref: refs/heads/worktree-review' \
       heads/main:$SHA_MAIN heads/dev-main:$SHA_DEV heads/worktree-review:$SHA_OTHER)"
OUT2B="$(run_guard "$R2B")"
check "produces no output" "$(printf '%s' "$OUT2B" | wc -c | tr -d ' ')" "0"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
echo "3. CUSTOMER-shaped repo (main, NO dev-main), on main → SILENT"
echo "   (a false positive here would fire on every customer session)"
R3="$(make_repo customer 'ref: refs/heads/main' \
      heads/main:$SHA_MAIN \
      heads/feature-login:$SHA_OTHER \
      remotes/origin/main:$SHA_MAIN)"
OUT3="$(run_guard "$R3")"; RC3=$?
echo "--- actual output ---"; printf '%s\n' "$OUT3"; echo "--- end (empty above = silent) ---"
check "exits 0" "$RC3" "0"
check "produces no output" "$(printf '%s' "$OUT3" | wc -c | tr -d ' ')" "0"

echo "3b. Customer repo with an ordinary 'develop' integration branch → SILENT"
# Keyed on the literal dev-main/main topology, not on "has any integration
# branch" — otherwise every § 2.1-compliant customer repo would fire.
R3B="$(make_repo customer-develop 'ref: refs/heads/main' \
       heads/main:$SHA_MAIN heads/develop:$SHA_DEV remotes/origin/main:$SHA_MAIN)"
OUT3B="$(run_guard "$R3B")"
check "produces no output" "$(printf '%s' "$OUT3B" | wc -c | tr -d ' ')" "0"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
echo "4. Degenerate repos → SILENT, exit 0, no crash"
R4A="$(make_repo empty-repo 'ref: refs/heads/main')"
OUT4A="$(run_guard "$R4A")"; RC4A=$?
check "no refs at all: exit 0"    "$RC4A" "0"
check "no refs at all: silent"    "$(printf '%s' "$OUT4A" | wc -c | tr -d ' ')" "0"

R4B="$(make_repo detached-repo "$SHA_OTHER" heads/main:$SHA_MAIN)"
OUT4B="$(run_guard "$R4B")"; RC4B=$?
check "detached HEAD, no dev-main: exit 0" "$RC4B" "0"
check "detached HEAD, no dev-main: silent" "$(printf '%s' "$OUT4B" | wc -c | tr -d ' ')" "0"

R4C="$TMP/no-git"
mkdir -p "$R4C/.logic-loom/scripts/bash"
cp "$REPO_ROOT/.logic-loom/scripts/bash/detect-environment-topology.sh" "$R4C/.logic-loom/scripts/bash/"
cp "$GUARD" "$R4C/.logic-loom/scripts/bash/"
OUT4C="$(run_guard "$R4C")"; RC4C=$?
check "no .git at all: exit 0" "$RC4C" "0"
check "no .git at all: silent" "$(printf '%s' "$OUT4C" | wc -c | tr -d ' ')" "0"

OUT4D="$(bash "$GUARD" --root "$TMP/does-not-exist" --format text --no-marker </dev/null 2>/dev/null)"; RC4D=$?
check "nonexistent root: exit 0" "$RC4D" "0"
check "nonexistent root: silent" "$(printf '%s' "$OUT4D" | wc -c | tr -d ' ')" "0"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
echo "5. Runs no git (runtime PATH shim, not a source grep)"
mkdir -p "$TMP/shim"
cat > "$TMP/shim/git" <<'SHIM_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GIT_SHIM_LOG:?}"
exit 0
SHIM_EOF
chmod +x "$TMP/shim/git"
: > "$TMP/git-calls.log"
# Both the firing path and a silent path, and both event surfaces.
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" \
  bash "$R1/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R1" --format text --no-marker </dev/null >/dev/null 2>&1
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" \
  bash "$R2/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R2" --format text --no-marker </dev/null >/dev/null 2>&1
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" \
  bash "$R3/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R3" --event UserPromptSubmit --no-marker </dev/null >/dev/null 2>&1
GIT_CALLS="$(grep -c . "$TMP/git-calls.log" 2>/dev/null | head -1)"
[ -n "$GIT_CALLS" ] || GIT_CALLS=0
if [ "$GIT_CALLS" != "0" ]; then echo "   git was invoked with: $(cat "$TMP/git-calls.log")"; fi
check "zero git invocations across firing + silent + UserPromptSubmit paths" "$GIT_CALLS" "0"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
echo "6. Hook output contract (valid, non-blocking JSON on both surfaces)"
J_SS_FIRE="$(bash "$R1/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R1" --event SessionStart </dev/null 2>/dev/null)"
J_SS_SIL="$(bash "$R2/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R2" --event SessionStart </dev/null 2>/dev/null)"
J_UP_FIRE="$(bash "$R1/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R1" --event UserPromptSubmit --no-marker </dev/null 2>/dev/null)"
J_UP_SIL="$(bash "$R3/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R3" --event UserPromptSubmit --no-marker </dev/null 2>/dev/null)"

json_ok() { printf '%s' "$1" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; }
for pair in "SessionStart/fire:$J_SS_FIRE" "SessionStart/silent:$J_SS_SIL" "UserPromptSubmit/fire:$J_UP_FIRE" "UserPromptSubmit/silent:$J_UP_SIL"; do
  label="${pair%%:*}"; body="${pair#*:}"
  if json_ok "$body"; then ok "$label emits parseable JSON"; else bad "$label emits parseable JSON — got: $body"; fi
done
if grep -q '"hookEventName":"SessionStart"' <<< "$J_SS_FIRE"; then ok "SessionStart names its event"; else bad "SessionStart names its event"; fi
if grep -q '"blocked":false' <<< "$J_UP_FIRE"; then ok "UserPromptSubmit never blocks"; else bad "UserPromptSubmit never blocks"; fi
if grep -q '"blocked":false' <<< "$J_UP_SIL"; then ok "UserPromptSubmit silent path never blocks"; else bad "UserPromptSubmit silent path never blocks"; fi
echo ""

echo "7. UserPromptSubmit fires once per (root, HEAD), then goes quiet"
export TMPDIR="$TMP/marker-home"; mkdir -p "$TMPDIR"
M1="$(bash "$R1/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R1" --event UserPromptSubmit </dev/null 2>/dev/null)"
M2="$(bash "$R1/.logic-loom/scripts/bash/check-dev-branch-base.sh" --root "$R1" --event UserPromptSubmit </dev/null 2>/dev/null)"
if grep -q "WRONG BASE" <<< "$M1"; then ok "first prompt warns"; else bad "first prompt warns"; fi
if grep -q "WRONG BASE" <<< "$M2"; then bad "second prompt is quiet"; else ok "second prompt is quiet"; fi
MARKERS="$(find "$TMPDIR" -type f 2>/dev/null | grep -c . | head -1)"; [ -n "$MARKERS" ] || MARKERS=0
if [ "$MARKERS" -ge 1 ]; then ok "the once-marker lives under TMPDIR"; else bad "the once-marker lives under TMPDIR"; fi
STRAY="$(find "$R1/.git" "$R1/.logic-loom" -name '*loom-branch-base-guard*' 2>/dev/null | grep -c . | head -1)"; [ -n "$STRAY" ] || STRAY=0
check "nothing written into the repo or .git" "$STRAY" "0"
echo ""

echo "8. Registered where a regression would be caught"
if grep -q "test_dev_branch_base_guard.sh" "$REPO_ROOT/tests/run_all_tests.sh"; then ok "registered in run_all_tests.sh"; else bad "registered in run_all_tests.sh"; fi
if grep -q "test_dev_branch_base_guard.sh" "$REPO_ROOT/.github/workflows/plugin-tests.yml"; then ok "registered in plugin-tests.yml"; else bad "registered in plugin-tests.yml"; fi
if grep -q "check-dev-branch-base.sh" "$REPO_ROOT/.claude/settings.json"; then ok "wired as a hook in .claude/settings.json"; else bad "wired as a hook in .claude/settings.json"; fi
# The runbook is maintainer-only and is STRIPPED at promote
# (template-strip-manifest.txt line for .docs/guides/dev-main-template-split.md),
# so its absence in a sanitized template is correct, not a regression. Assert it
# only where it is supposed to exist.
RUNBOOK="$REPO_ROOT/.docs/guides/dev-main-template-split.md"
if [ ! -f "$RUNBOOK" ]; then
  ok "maintainer runbook absent (sanitized template — stripped by design)"
elif grep -qi "worktree" "$RUNBOOK"; then
  ok "maintainer runbook warns about worktree creation"
else
  bad "maintainer runbook warns about worktree creation"
fi
echo ""

TOTAL=$((PASS + FAIL))
echo "══════════════════════════════════════════════════"
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "══════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
