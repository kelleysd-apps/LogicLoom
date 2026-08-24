#!/usr/bin/env bash
# Contract Tests: user-configurable gate policy (ask vs silent) + its FLOOR
#
# The gate policy (.logic-loom/config/gate-policy.conf) lets a user decide which
# repository-mutating operations interrupt them. This suite pins the whole
# surface, because every failure mode here is silent by nature:
#
#   1. The DEFAULT verdict of every known operation (the shipped `balanced`
#      posture) — the table a reviewer can read against the config file.
#   2. A config that SILENCES a tunable operation is honored.
#   3. A config that tries to silence a FLOOR operation is REFUSED — the verdict
#      stays `ask` AND a typed refusal is emitted, exactly as the protected-path
#      list refuses a removal.
#   4. A MISSING config falls back to the built-in defaults — never to "allow
#      everything".
#   5. A CORRUPT config does the same, per-line, without taking the file down.
#   6. Permission-mode keying: every mode SHIPS as enforce (bypassPermissions
#      included); an explicit `mode.X = relax` relaxes TUNABLE gates only.
#   7. The three onboarding postures produce the configs they claim to.
#   8. The shipped gate-policy.conf is clean and complete (drift guard).
#   9. Subagent behavior is untouched by every one of the above.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
check() { # desc expected actual
  TOTAL=$((TOTAL + 1))
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS + 1))
  else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

LIB="$ROOT/.logic-loom/lib/governance-verdicts.sh"
SHIPPED_CONF="$ROOT/.logic-loom/config/gate-policy.conf"
TMP="$(mktemp -d)"
# Operations-log isolation: the scripts this suite drives source policy.sh /
# logging.sh, which otherwise append to the shared
# .logic-loom/logs/operations/ file. LOOM_LOG_DIR redirects that (same idiom as
# LOOM_CHECKPOINT_DIR in .logic-loom/tests/test-git-safety.sh); exported so
# subprocesses inherit it. Cleaned up by the SAME trap — a second `trap ... EXIT`
# would replace this one rather than add to it.
LOOM_LOG_DIR="$(mktemp -d)"
export LOOM_LOG_DIR
trap 'rm -rf "$TMP" "$LOOM_LOG_DIR"' EXIT

# ── The operation table ──────────────────────────────────────────────────────
# op | representative command | DEFAULT verdict (shipped `balanced` posture) | F
# `ask` = LogicLoom prompts.  `allow` = runs silently.
# A trailing `F` marks a FLOOR operation (never tunable).
TABLE='
git.push|git push origin main|ask|F
git.history-rewrite|git update-ref refs/heads/main HEAD~5|ask|F
git.pull|git pull|ask|
git.merge|git merge feature|ask|
git.rebase|git rebase main|ask|
git.reset.hard|git reset --hard HEAD~1|ask|
git.reset|git reset HEAD~1|ask|
git.clean|git clean -fd|ask|
git.restore|git restore file.ts|ask|
git.rm|git rm file.ts|ask|
git.mv|git mv a.ts b.ts|ask|
git.branch.write|git branch -d feature|ask|
git.worktree.write|git worktree add ../wt br|ask|
git.remote.write|git remote add origin url|ask|
git.stash.drop|git stash drop|ask|
git.commit|git commit -m x|allow|
git.add|git add .|allow|
git.stash|git stash push -m wip|allow|
git.tag.write|git tag v1.0.0|allow|
git.checkout|git checkout main|allow|
git.cherry-pick|git cherry-pick abc123|allow|
git.revert|git revert abc123|allow|
git.am|git am patch.mbox|allow|
git.apply|git apply p.diff|allow|
git.fetch|git fetch origin|allow|
gh.repo.admin|gh repo delete o/r --yes|ask|F
gh.secret.write|gh secret set TOKEN --body v|ask|F
gh.auth|gh auth login|ask|F
gh.pr.create|gh pr create --title t|ask|
gh.pr.merge|gh pr merge 12 --squash|ask|
gh.pr.edit|gh pr review 12 --approve|ask|
gh.workflow.write|gh workflow run ci.yml|ask|
gh.release.write|gh release create v1.0.0|ask|
gh.api.write|gh api -X PUT repos/o/r/pulls/9/merge|ask|
gh.alias.set|gh alias set pm "pr merge"|ask|
gh.issue.delete|gh issue delete 4 --yes|ask|
gh.issue.write|gh issue create --title t|allow|
gh.run.write|gh run cancel 55|allow|
'

# Run the WHOLE table inside ONE subshell per config state, so the library is
# sourced once per state rather than once per assertion. Emits `op:verdict`
# lines, where the verdict is the real hook-facing one.
run_table() { # conf_path [permission_mode] -> "op:verdict" per line
  ( export LOOM_GATE_POLICY_CONF="$1"
    _mode="${2:-}"
    # shellcheck disable=SC1090
    . "$LIB"
    while IFS='|' read -r _op _cmd _def _floor; do
      [ -n "$_op" ] || continue
      case "$_op" in git.*) _v="$(loom_verdict_git_mutation "$_cmd" "$_mode")" ;;
                     gh.*)  _v="$(loom_verdict_gh_mutation  "$_cmd" "$_mode")" ;;
      esac
      printf '%s:%s\n' "$_op" "$_v"
    done <<< "$TABLE" )
}

verdict_of() { # results op -> verdict
  printf '%s\n' "$1" | grep -m1 "^$2:" | sed 's/^[^:]*://'
}

expected_for() { # op state -> verdict
  local op="$1" state="$2" def floor
  while IFS='|' read -r _o _c def floor; do
    [ "$_o" = "$op" ] || continue
    case "$state" in
      minimal)  [ "$floor" = "F" ] && printf 'ask' || printf 'allow' ;;
      strict)   printf 'ask' ;;
      *)        printf '%s' "$def" ;;
    esac
    return 0
  done <<< "$TABLE"
}

# ── Config fixtures ──────────────────────────────────────────────────────────
MISSING="$TMP/no-such-dir/gate-policy.conf"

# (b)+(c) combined: silence EVERY operation, floor included. Tunable ops must
# comply; floor ops must refuse.
: > "$TMP/allsilent.conf"
while IFS='|' read -r _o _c _d _f; do
  [ -n "$_o" ] || continue
  printf '%s = silent\n' "$_o" >> "$TMP/allsilent.conf"
done <<< "$TABLE"

# (c) A dedicated floor attack: every syntactic shape someone might reach for to
# turn the floor off, plus two injection shapes (the file is DATA — the parser
# never sources or evals it).
{
  echo 'git.push = silent'
  echo 'git.push = allow'
  echo 'git.push=silent'
  echo '  git.push   =   silent'
  echo 'git.history-rewrite = silent'
  echo 'gh.repo.admin = silent'
  echo 'gh.secret.write = silent'
  echo 'gh.auth = silent'
  echo 'git.push = off'
  echo 'git.push = none'
  echo 'git.push = never'
  echo 'git.push_override = silent'
  echo 'git.merge = off'          # tunable op, invalid verdict -> invalid-verdict
  echo 'gate.floor = off'
  echo 'floor = disabled'
  echo 'LOOM_GATE_FLOOR_OPS ='
  printf 'git.push = $(id)\n'
  printf 'git.push = `id`\n'
  echo 'git.push = ;unset -f loom_gate_policy'
  echo '* = silent'
  echo 'all = silent'
} > "$TMP/floorattack.conf"

# (e) Corrupt: truncated lines, control bytes, unbalanced quotes, no key at all.
printf 'git.commit\n= ask\n[section]\n\001\002\003\ngit.push "unterminated\n===\n\n   \n%%%%\n' \
  > "$TMP/corrupt.conf"

# ── 1/4/5. Default, missing, corrupt all give the built-in defaults ──────────
echo "=== Gate Policy: operation table ==="
echo ""
for _state in default missing corrupt; do
  case "$_state" in
    default) _conf="$SHIPPED_CONF" ;;
    missing) _conf="$MISSING" ;;
    corrupt) _conf="$TMP/corrupt.conf" ;;
  esac
  RES="$(run_table "$_conf")"
  echo "-- config state: $_state"
  while IFS='|' read -r _op _cmd _def _floor; do
    [ -n "$_op" ] || continue
    check "[$_state] $_op ($_cmd)" "$(expected_for "$_op" "$_state")" "$(verdict_of "$RES" "$_op")"
  done <<< "$TABLE"
  echo ""
done

# ── 2/3. A config that silences everything ───────────────────────────────────
echo "-- config state: every operation set to silent (tunable complies, FLOOR refuses)"
RES="$(run_table "$TMP/allsilent.conf")"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[allsilent] $_op${_floor:+ [FLOOR]}" "$(expected_for "$_op" minimal)" "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"
echo ""

echo "-- config state: dedicated FLOOR attack (every removal shape)"
RES="$(run_table "$TMP/floorattack.conf")"
for _op in git.push git.history-rewrite gh.repo.admin gh.secret.write gh.auth; do
  check "[floorattack] $_op still asks" ask "$(verdict_of "$RES" "$_op")"
done
REFUSALS="$( export LOOM_GATE_POLICY_CONF="$TMP/floorattack.conf"; . "$LIB"; loom_gate_policy_refusals )"
for _op in git.push git.history-rewrite gh.repo.admin gh.secret.write gh.auth; do
  check "[floorattack] typed refusal names $_op" yes \
    "$(printf '%s\n' "$REFUSALS" | grep -q "^floor-gate-not-tunable: $_op " && echo yes || echo no)"
done
check "[floorattack] unknown keys are reported, not swallowed" yes \
  "$(printf '%s\n' "$REFUSALS" | grep -q '^unknown-operation: ' && echo yes || echo no)"
# NOTE: `git.push = off` reports as floor-gate-not-tunable, not invalid-verdict —
# the floor refusal is checked first and is the more important thing to say. The
# invalid-verdict class is exercised by the TUNABLE `git.merge = off` line.
check "[floorattack] invalid verdicts are reported" yes \
  "$(printf '%s\n' "$REFUSALS" | grep -q '^invalid-verdict: ' && echo yes || echo no)"
check "[floorattack] parser treats the file as DATA (no eval)" yes \
  "$( export LOOM_GATE_POLICY_CONF="$TMP/floorattack.conf"; . "$LIB"; \
      loom_gate_policy git.push >/dev/null; \
      declare -f loom_gate_policy >/dev/null 2>&1 && echo yes || echo no )"
echo ""

# ── 2 (positive). Silencing ONE tunable operation works and is scoped ────────
printf 'git.merge = silent\n' > "$TMP/one.conf"
RES="$(run_table "$TMP/one.conf")"
check "[one] git.merge silenced"          allow "$(verdict_of "$RES" git.merge)"
check "[one] git.rebase unaffected"       ask   "$(verdict_of "$RES" git.rebase)"
check "[one] git.push unaffected (floor)" ask   "$(verdict_of "$RES" git.push)"
check "[one] git.commit still silent"     allow "$(verdict_of "$RES" git.commit)"
# The reverse direction: TIGHTENING a silent operation must work too.
printf 'git.commit = ask\ngit.fetch = ask\n' > "$TMP/tighten.conf"
RES="$(run_table "$TMP/tighten.conf")"
check "[tighten] git.commit raised to ask" ask "$(verdict_of "$RES" git.commit)"
check "[tighten] git.fetch raised to ask"  ask "$(verdict_of "$RES" git.fetch)"
check "[tighten] git.add untouched"        allow "$(verdict_of "$RES" git.add)"
echo ""

# ── 6. Permission-mode keying ────────────────────────────────────────────────
echo "-- permission-mode awareness (PreToolUse payload field permission_mode)"
# SHIPPED DEFAULT: bypassPermissions is `enforce`, exactly like every other mode.
# The relax mechanism exists, but it is opt-in — proven under an explicit config
# further down, never as the default. The redundancy argument for relaxing here
# (the host auto-approves a hook `ask` under this mode) is inferred, not
# verified, and the tunable set contains operations with no undo.
RES="$(run_table "$SHIPPED_CONF" bypassPermissions)"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[bypassPermissions default] $_op == enforce verdict" \
    "$(expected_for "$_op" default)" "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"
# The destructive ones, called out by name so a future weakening is loud.
for _op in git.clean git.reset.hard git.restore git.rm git.mv \
           git.branch.write git.worktree.write git.remote.write; do
  check "[bypassPermissions default] $_op STILL asks (no undo)" ask "$(verdict_of "$RES" "$_op")"
done
check "[bypassPermissions default] git.push STILL asks"  ask "$(verdict_of "$RES" git.push)"
check "[bypassPermissions default] git.commit still silent" allow "$(verdict_of "$RES" git.commit)"
for _m in default acceptEdits plan auto dontAsk bypassPermissions; do
  RES="$(run_table "$SHIPPED_CONF" "$_m")"
  check "[$_m] enforces policy (git.merge asks)"    ask   "$(verdict_of "$RES" git.merge)"
  check "[$_m] enforces policy (git.commit silent)" allow "$(verdict_of "$RES" git.commit)"
done
for _m in "" "not-a-mode" "bypassPermissions;id" "*" "BYPASSPERMISSIONS"; do
  RES="$(run_table "$SHIPPED_CONF" "$_m")"
  check "[mode='${_m}'] unknown mode enforces" ask "$(verdict_of "$RES" git.merge)"
done
printf 'mode.auto = relax\n' > "$TMP/moderelax.conf"
RES="$(run_table "$TMP/moderelax.conf" auto)"
check "[mode.auto=relax] git.merge relaxes"   allow "$(verdict_of "$RES" git.merge)"
check "[mode.auto=relax] git.push still asks" ask   "$(verdict_of "$RES" git.push)"
printf 'mode.bypassPermissions = enforce\n' > "$TMP/modestrict.conf"
RES="$(run_table "$TMP/modestrict.conf" bypassPermissions)"
check "[mode.bypassPermissions=enforce] git.merge asks" ask "$(verdict_of "$RES" git.merge)"

# ── 6b. The RELAX MECHANISM, behind an explicit config ───────────────────────
# The shipped default no longer relaxes bypassPermissions, but the capability is
# preserved and must stay proven or it will rot. This is the opt-in a user makes
# by uncommenting one documented line in gate-policy.conf.
echo ""
echo "-- opt-in relax: mode.bypassPermissions = relax (NOT the shipped default)"
printf 'mode.bypassPermissions = relax\n' > "$TMP/moderelaxbp.conf"
RES="$(run_table "$TMP/moderelaxbp.conf" bypassPermissions)"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[opt-in relax] $_op${_floor:+ [FLOOR]}" "$(expected_for "$_op" minimal)" "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"
# Named explicitly: the tunable destructive set really does go silent...
for _op in git.merge git.clean git.reset.hard git.restore gh.pr.merge; do
  check "[opt-in relax] $_op relaxes to allow" allow "$(verdict_of "$RES" "$_op")"
done
# ...and the FLOOR does not, which is the whole point of the split.
for _op in git.push git.history-rewrite gh.repo.admin gh.secret.write gh.auth; do
  check "[opt-in relax] $_op STILL asks (floor)" ask "$(verdict_of "$RES" "$_op")"
done
check "[opt-in relax] config is clean (no refusals)" "" \
  "$( export LOOM_GATE_POLICY_CONF="$TMP/moderelaxbp.conf"; . "$LIB"; loom_gate_policy_refusals )"
# The opt-in is scoped to the mode it names — other modes keep enforcing.
for _m in default auto dontAsk acceptEdits plan; do
  RES="$(run_table "$TMP/moderelaxbp.conf" "$_m")"
  check "[opt-in relax] mode '$_m' unaffected (git.clean asks)" ask "$(verdict_of "$RES" git.clean)"
done
# Subagent floor is untouched by the opt-in too.
check "[opt-in relax] subagent: commit=deny status=allow gh=deny" "deny allow deny" \
  "$( export LOOM_GATE_POLICY_CONF="$TMP/moderelaxbp.conf"; . "$LIB"
      printf '%s %s %s' \
        "$(loom_verdict_subagent_git 'git commit -m x' 'a8e')" \
        "$(loom_verdict_subagent_git 'git status' 'a8e')" \
        "$(loom_verdict_subagent_gh  'gh issue create' 'a8e')" )"
echo ""

# ── 7. Onboarding postures ───────────────────────────────────────────────────
echo "-- onboarding postures"
for _posture in strict balanced minimal; do
  ( . "$LIB"; loom_gate_posture_body "$_posture" ) > "$TMP/posture-$_posture.conf"
  check "posture '$_posture' emits a body" yes \
    "$( [ -s "$TMP/posture-$_posture.conf" ] && echo yes || echo no )"
  check "posture '$_posture' has no refusals" "" \
    "$( export LOOM_GATE_POLICY_CONF="$TMP/posture-$_posture.conf"; . "$LIB"; loom_gate_policy_refusals )"
done
check "posture 'nonsense' is rejected" no \
  "$( . "$LIB"; loom_gate_posture_body nonsense >/dev/null 2>&1 && echo yes || echo no )"

RES="$(run_table "$TMP/posture-strict.conf")"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[posture strict] $_op asks" ask "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"

RES="$(run_table "$TMP/posture-balanced.conf")"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[posture balanced] $_op == shipped default" "$_def" "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"

RES="$(run_table "$TMP/posture-minimal.conf")"
while IFS='|' read -r _op _cmd _def _floor; do
  [ -n "$_op" ] || continue
  check "[posture minimal] $_op${_floor:+ [FLOOR]}" "$(expected_for "$_op" minimal)" "$(verdict_of "$RES" "$_op")"
done <<< "$TABLE"
echo ""

# ── 7b. Applying a posture ON TOP of the shipped file (what onboarding does) ──
# REGRESSION: onboarding rewrites gate-policy.conf by stripping the active
# `<op> = <verdict>` lines and appending the posture body, keeping the
# commentary. The first strip regex used `[a-z.]+`, which does not match a
# hyphen — so `git.cherry-pick` and `git.history-rewrite` survived, and because
# FIRST occurrence wins they silently overrode the posture the user just chose.
# This fixture is the shape of that bug.
echo "-- posture applied on top of the shipped file (onboarding rewrite)"
for _posture in strict balanced minimal; do
  _applied="$TMP/applied-$_posture.conf"
  grep -vE '^[[:space:]]*(git|gh)\.[a-z0-9.-]+[[:space:]]*=' "$SHIPPED_CONF" > "$_applied"
  ( . "$LIB"; loom_gate_posture_body "$_posture" ) >> "$_applied"
  check "[apply $_posture] exactly one active line per operation" \
    "$(printf '%s\n' "$TABLE" | grep -c '^[a-z]')" \
    "$(grep -cE '^[[:space:]]*(git|gh)\.[a-z0-9.-]+[[:space:]]*=' "$_applied")"
  check "[apply $_posture] commentary survived" yes \
    "$( [ "$(grep -c '^#' "$_applied")" -gt 50 ] && echo yes || echo no )"
  RES="$(run_table "$_applied")"
  while IFS='|' read -r _op _cmd _def _floor; do
    [ -n "$_op" ] || continue
    check "[apply $_posture] $_op" "$(expected_for "$_op" "$_posture")" "$(verdict_of "$RES" "$_op")"
  done <<< "$TABLE"
done
echo ""

# ── 8. The shipped file is clean and complete (drift guard) ──────────────────
echo "-- shipped gate-policy.conf coherence"
check "shipped gate-policy.conf exists" yes "$( [ -f "$SHIPPED_CONF" ] && echo yes || echo no )"
check "shipped gate-policy.conf has NO refusals" "" \
  "$( export LOOM_GATE_POLICY_CONF="$SHIPPED_CONF"; . "$LIB"; loom_gate_policy_refusals )"
KNOWN="$( . "$LIB"; loom_gate_known_ops )"
_miss=""
while IFS= read -r _op; do
  [ -n "$_op" ] || continue
  grep -qE "^[[:space:]]*$(printf '%s' "$_op" | sed 's/\./\\./g')[[:space:]]*=" "$SHIPPED_CONF" || _miss="$_miss $_op"
done <<< "$KNOWN"
check "every known operation is written ACTIVE in the shipped file" "" "$_miss"
_miss=""
while IFS= read -r _op; do
  [ -n "$_op" ] || continue
  printf '%s\n' "$TABLE" | grep -q "^$(printf '%s' "$_op" | sed 's/\./\\./g')|" || _miss="$_miss $_op"
done <<< "$KNOWN"
check "every known operation has a fixture in this suite" "" "$_miss"
check "known-operation count matches the table" \
  "$(printf '%s\n' "$KNOWN" | grep -c .)" \
  "$(printf '%s\n' "$TABLE" | grep -c '^[a-z]')"
check "floor list is exactly the five documented operations" \
  "git.push git.history-rewrite gh.repo.admin gh.secret.write gh.auth" \
  "$( export LOOM_GATE_POLICY_CONF="$TMP/floorattack.conf"; . "$LIB"; printf '%s' "$LOOM_GATE_FLOOR_OPS" )"
# gate-policy.conf must itself be on the protected-file floor: otherwise a
# subagent could rewrite the approval policy and then act under it.
check "gate-policy.conf is protected (subagent -> deny)" deny \
  "$( . "$LIB"; loom_verdict_protected_path '.logic-loom/config/gate-policy.conf' 'a8e' )"
check "gate-policy.conf is protected (main -> ask)" ask \
  "$( . "$LIB"; loom_verdict_protected_path '.logic-loom/config/gate-policy.conf' '' )"
echo ""

# ── 9. Subagent behavior is UNTOUCHED by any gate policy ─────────────────────
echo "-- subagent floor is not policy (unchanged under every config and mode)"
for _cf in "$SHIPPED_CONF" "$TMP/allsilent.conf" "$TMP/floorattack.conf" "$MISSING" "$TMP/corrupt.conf"; do
  _n="$(basename "$_cf")"
  _out="$( export LOOM_GATE_POLICY_CONF="$_cf"; . "$LIB"
           printf '%s %s %s %s' \
             "$(loom_verdict_subagent_git 'git commit -m x' 'a8e')" \
             "$(loom_verdict_subagent_git 'git status' 'a8e')" \
             "$(loom_verdict_subagent_git 'git fetch' 'a8e')" \
             "$(loom_verdict_subagent_gh  'gh issue create' 'a8e')" )"
  check "[$_n] subagent: commit=deny status=allow fetch=deny gh=deny" \
    "deny allow deny deny" "$_out"
done
echo ""

echo "================================"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
