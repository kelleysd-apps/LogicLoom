#!/usr/bin/env bash
# Contract Tests: the bash 3.2 floor is REAL, not recited
#
# `.docs/policies/shell-idiom-policy.md` declares bash 3.2 (stock macOS
# /bin/bash) the floor for HARNESS-OWNED shell — see "WHOSE SHELL" below.
# Until this suite existed, nothing checked it: CI runs ubuntu-latest (bash 5),
# eighteen test files recited "# bash 3.2 safe" in a COMMENT, and eight shipped
# scripts used `declare -A` / `[[ -v ]]` / `mapfile`. Four of them are the
# `/specification` quality gates and the documented `load-context.sh` command,
# so the SDD waterfall pack shipped broken for every macOS user.
#
# WHOSE SHELL — the scope, and why it is not "everything in the tree"
#
# This suite SHIPS. It runs in a customer's clone, in their CI, against their
# tree. The floor exists because *the harness's own* scripts must run on stock
# macOS /bin/bash (3.2.57) — a customer's plugin has no such obligation: they
# choose their own runner, and `declare -A` on ubuntu/bash-5 is a perfectly
# ordinary thing for them to write.
#
# So the scan covers harness-owned shell only:
#
#   .logic-loom/ , .claude/hooks/ , tests/    framework-owned wholesale — the
#                                             harness↔product boundary in
#                                             CLAUDE.md puts product code in
#                                             web/ or apps/<name>/, never here
#   plugins/<p>/                              ONLY for plugins DECLARED in
#                                             CLAUDE.md's Plugin Registry table
#
# `plugins/` is the one genuinely mixed namespace: it holds the eight bundled
# harness plugins AND anything a customer builds under Principle XVI /
# `/create-plugin`. The discriminator is the harness's own published inventory —
# the Plugin Registry table in CLAUDE.md — not a name prefix, and not the
# plugin manifest (a `harness_owned` flag would have to be added to eight
# manifests a fork is free to copy). A customer plugin is unlisted, so it is
# not scanned; if a customer deliberately lists their plugin in that table they
# have opted INTO the floor, which is the only reading of that edit.
#
# The failure mode this scoping must NOT create is the gate quietly going
# decorative — a harness plugin dropped from the registry table and therefore
# from the scan. Section 1b is the backstop: any directory under `plugins/`
# named `loom-*` or `sdd-*` that is NOT in the declared set FAILS the suite by
# name. That can only ADD coverage, never remove it. (A customer who names
# their own plugin `loom-something` has taken our namespace and will be told
# so — documented in the shell-idiom policy.)
#
# NOT in scope: `.github/workflows/`. Every workflow in this repo is
# `runs-on: ubuntu-latest` (bash 5) and workflow `run:` blocks execute nowhere
# else — never on a developer's macOS shell. The floor's whole rationale is
# absent there, so the claim was the wrong half, not the coverage. A workflow
# that CALLS a harness script is still covered, because the script is.
#
# WHAT THIS SUITE ASSERTS, AND WHERE
#
#   Section 1  static scan      — runs EVERYWHERE (macOS and CI)
#   Section 1b scope integrity  — runs EVERYWHERE (no harness plugin escapes)
#   Section 2  scanner teeth    — runs EVERYWHERE
#   Section 2b ownership teeth  — runs EVERYWHERE (both directions, on a
#                                 synthetic repo: harness plugin scanned,
#                                 customer plugin not)
#   Section 3  golden output    — runs EVERYWHERE (this is the cross-version
#                                 parity gate: the SAME expected bytes are
#                                 asserted under bash 3.2 locally and bash 5
#                                 on CI, so a data-structure change that
#                                 scores differently fails on one of them)
#   Section 4  execute under real bash 3.2 — macOS ONLY
#   Section 5  planted regression under real bash 3.2 — macOS ONLY
#
# WHAT CI (ubuntu-latest, bash 5, no bash 3.2 available) THEREFORE CANNOT
# CATCH: a bash-4-only construct that is NOT in the scanned pattern list —
# e.g. `${var@Q}`, `wait -n`, negative array subscripts. CI catches every
# reintroduction of the constructs that actually broke, and catches any change
# in the gates' SCORES; it cannot prove a novel construct runs on 3.2. Only a
# macOS run (or a CI runner with bash 3.2 installed) does that. Sections 4-5
# announce themselves as skipped rather than passing silently, and the suite
# still carries real assertions on CI, so it is never a no-op there.
#
# Override the 3.2 interpreter with LOOM_BASH32=/path/to/bash-3.2, or
# LOOM_BASH32=none to exercise the CI (no-3.2) branch from a macOS box.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}. (And unlike
# the eighteen files that only said so, this one is executed under 3.2 by
# section 4 of itself.)
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-bash32.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "═══ bash 3.2 Floor ═══"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Locate a real bash 3.2
# ─────────────────────────────────────────────────────────────────────────────
BASH32=""
# LOOM_BASH32=none forces the "no 3.2 available" branch, so the CI path can be
# exercised from a macOS box. Any other value is used as the interpreter.
if [ "${LOOM_BASH32:-}" != "none" ]; then
for cand in "${LOOM_BASH32:-}" /bin/bash /usr/local/bin/bash-3.2 /opt/bash-3.2/bin/bash; do
  [ -n "$cand" ] || continue
  [ -x "$cand" ] || continue
  case "$("$cand" --version 2>/dev/null | head -1)" in
    *"version 3."*) BASH32="$cand"; break ;;
  esac
done
fi

RUNNING_BASH="$(bash --version 2>/dev/null | head -1)"
echo "Host bash:      $RUNNING_BASH"
if [ -n "$BASH32" ]; then
  echo "bash 3.2 found: $BASH32 — sections 4-5 WILL run (execution floor verified here)"
else
  echo "bash 3.2 found: NONE"
  echo "                sections 4-5 SKIPPED. The execution floor is NOT verified"
  echo "                on this host; only the static scan and the golden-output"
  echo "                parity gate run. This is the expected state on CI."
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# The constructs that are bash 4+ only. Each one is here because it shipped.
# ─────────────────────────────────────────────────────────────────────────────
# declare/local/typeset -A  → the seven scripts (validate-{spec,plan,tasks},
#                             detect-phase-domain, load-context, create-agent,
#                             governance-metrics)
# [[ -v NAME ]]             → load-context.sh's module existence test
# mapfile / readarray       → load-context.sh's analyze_request
# ${v^^} / ${v,,}           → case conversion; use tr
BASH4_PATTERN='(^|[^#[:alnum:]_])(declare|local|typeset)[[:space:]]+-[A-Za-z]*A[A-Za-z]*([[:space:]]|$)|\[\[[[:space:]]+-v[[:space:]]|(^|[^[:alnum:]_])(mapfile|readarray)([[:space:]]|$)|\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(\^\^|,,)'

# THIS FILE is the one documented exclusion: it contains every forbidden
# construct on purpose, as the planted-regression strings in section 2 and the
# sed in section 5. Nothing else may be added here. Section 6 compensates by
# asserting this file itself parses under bash 3.2, so the exclusion cannot
# hide a real 3.2 breakage in the suite.
SELF_EXCLUDE='tests/contract/test_bash32_floor.sh'

# Scan one tree for bash-4-only constructs, ignoring whole-line comments.
# Prints "path:line:text" for each hit. Exits 0 always.
scan_tree() {
  local target="$1"
  grep -rnE "$BASH4_PATTERN" --include='*.sh' "$target" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    | grep -vF "$SELF_EXCLUDE" || true
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Ownership: which shell is HARNESS-owned (see "WHOSE SHELL" in the header).
# Every function takes the repo root as an argument so section 2b can point them
# at a synthetic tree and prove both directions.
# ─────────────────────────────────────────────────────────────────────────────

# The harness's published plugin inventory: the first (backticked) cell of every
# row in CLAUDE.md's "## Plugin Registry" table. One line per plugin name.
declared_harness_plugins() {
  local r="$1"
  [ -f "$r/CLAUDE.md" ] || return 0
  sed -n '/^## Plugin Registry/,/^## /p' "$r/CLAUDE.md" \
    | grep -E '^\|[[:space:]]*`[A-Za-z0-9_.-]+`[[:space:]]*\|' \
    | sed -e 's/^|[[:space:]]*`//' -e 's/`.*$//'
  return 0
}

# Framework-owned wholesale + one root per declared harness plugin.
floor_scan_roots() {
  local r="$1" d p
  for d in .logic-loom .claude/hooks tests; do
    [ -d "$r/$d" ] && printf '%s\n' "$r/$d"
  done
  for p in $(declared_harness_plugins "$r"); do
    [ -d "$r/plugins/$p" ] && printf '%s\n' "$r/plugins/$p"
  done
  return 0
}

# The anti-decorative backstop: a plugin directory carrying OUR namespace that
# the registry table does not declare. Such a plugin would be silently unscanned.
undeclared_harness_shaped() {
  local r="$1" d name declared
  declared="$(declared_harness_plugins "$r")"
  for d in "$r"/plugins/*/; do
    [ -d "$d" ] || continue
    name="${d%/}"; name="${name##*/}"
    case "$name" in loom-*|sdd-*) ;; *) continue ;; esac
    # here-string, not a pipe: `grep -q` exits early and pipefail would score a
    # MATCH as a pipeline failure (shell-idiom-policy §6).
    grep -qx "$name" <<< "$declared" || printf '%s\n' "$name"
  done
  return 0
}

SCAN_ROOTS="$(floor_scan_roots "$ROOT" | sed "s#^$ROOT/##" | tr '\n' ' ')"

# ─────────────────────────────────────────────────────────────────────────────
echo "1. No bash-4-only construct in HARNESS-OWNED shell covered by the 3.2 floor"
HITS=""
SCANNED=0
for d in $SCAN_ROOTS; do
  [ -d "$d" ] || continue
  SCANNED=$((SCANNED + $(find "$d" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')))
  found="$(scan_tree "$d")"
  [ -n "$found" ] && HITS="${HITS}${found}"$'\n'
done
if [ -n "$HITS" ]; then
  echo "     BASH 4+ CONSTRUCTS (these do not run on stock macOS /bin/bash):"
  printf '%s' "$HITS" | sed 's/^/       - /'
fi
echo "     (scanned $SCANNED shell files across: $SCAN_ROOTS)"
assert "no declare/local/typeset -A, [[ -v ]], mapfile, or \${v,,} under the floor" \
       "[ -z \"\$HITS\" ]"
assert "the scan actually looked at files (not an empty glob)" "[ \"\$SCANNED\" -gt 50 ]"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "1b. Scope integrity — no harness plugin escapes the scan"
DECLARED="$(declared_harness_plugins "$ROOT")"
DECLARED_N="$(printf '%s\n' "$DECLARED" | grep -c . || true)"
echo "     declared harness plugins ($DECLARED_N): $(printf '%s' "$DECLARED" | tr '\n' ' ')"
assert "CLAUDE.md's Plugin Registry table parses (>= 8 plugins declared)" \
       "[ \"\$DECLARED_N\" -ge 8 ]"
MISSING_DIR=""
for p in $DECLARED; do
  [ -d "$ROOT/plugins/$p" ] || MISSING_DIR="${MISSING_DIR}$p "
done
assert "every declared plugin is a real directory under plugins/ (${MISSING_DIR:-none missing})" \
       "[ -z \"\$MISSING_DIR\" ]"
ORPHANS="$(undeclared_harness_shaped "$ROOT" | tr '\n' ' ')"
assert "no loom-*/sdd-* plugin on disk is missing from the registry (${ORPHANS:-none})" \
       "[ -z \"\$(printf '%s' \"\$ORPHANS\" | tr -d ' ')\" ]"
# The three wholesale roots must actually be in the computed set, or the scoping
# change quietly narrowed the floor to plugins alone.
for d in .logic-loom .claude/hooks tests; do
  assert "wholesale framework root '$d' is in the scan set" \
         "grep -q -- \"$d\" <<< \"\$SCAN_ROOTS\""
done

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "2. The scanner has teeth (planted regressions are caught)"
mkdir -p "$TMP/planted"
PLANT_N=0
plant() {
  PLANT_N=$((PLANT_N + 1))
  local label="$1" body="$2"
  local d="$TMP/planted/case$PLANT_N"
  mkdir -p "$d"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$d/planted.sh"
  local got
  got="$(scan_tree "$d")"
  assert "planted regression caught: $label" "[ -n \"\$got\" ]"
}
plant "declare -A"        'declare -A MAP'
plant "local -A"          'f() { local -A m; }'
plant "typeset -A"        'typeset -A m'
plant "[[ -v NAME ]]"     'if [[ -v FOO ]]; then :; fi'
plant "mapfile -t"        'mapfile -t arr < f'
plant "readarray"         'readarray arr < f'
plant '${v,,}'            'x="${NAME,,}"'

# A commented-out construct must NOT trip the scan — that distinction is the
# whole reason this suite executes things instead of only grepping.
mkdir -p "$TMP/planted/comment"
printf '#!/usr/bin/env bash\n# declare -A MAP  <- only a comment\n' > "$TMP/planted/comment/c.sh"
COMMENT_HIT="$(scan_tree "$TMP/planted/comment")"
assert "a construct inside a comment does NOT trip the scan" "[ -z \"\$COMMENT_HIT\" ]"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "2b. Ownership has teeth in BOTH directions (synthetic repo)"
# A scoping change is worth nothing unless it still catches OUR violations, and
# worth nothing if it still breaks a CUSTOMER for something legitimate. Both are
# asserted here against a purpose-built tree, so neither direction rests on the
# current contents of this repo.
SR="$TMP/synthrepo"
mkdir -p "$SR/plugins/loom-example/scripts" "$SR/plugins/acme-billing/scripts" "$SR/.logic-loom"
{
  echo "## Plugin Registry"
  echo ""
  echo "| Plugin | Layer | Notes |"
  echo "|---|---|---|"
  echo "| \`loom-example\` | core | a bundled harness plugin |"
  echo ""
  echo "## Something Else"
} > "$SR/CLAUDE.md"
printf '#!/usr/bin/env bash\ndeclare -A OURS\n' > "$SR/plugins/loom-example/scripts/ours.sh"
printf '#!/usr/bin/env bash\ndeclare -A RATES\n' > "$SR/plugins/acme-billing/scripts/rates.sh"

SR_ROOTS="$(floor_scan_roots "$SR" | tr '\n' ' ')"
SR_HITS=""
for d in $SR_ROOTS; do
  found="$(scan_tree "$d")"
  [ -n "$found" ] && SR_HITS="${SR_HITS}${found}"$'\n'
done
echo "     synthetic scan roots: $(printf '%s' "$SR_ROOTS" | sed "s#$SR/##g")"
echo "     synthetic hits:       $(printf '%s' "$SR_HITS" | tr '\n' ' ' | sed "s#$SR/##g")"
assert "a HARNESS plugin's 'declare -A' IS caught (gate is not decorative)" \
       "grep -q 'loom-example/scripts/ours.sh' <<< \"\$SR_HITS\""
assert "a CUSTOMER plugin's 'declare -A' is NOT caught (their runner, their call)" \
       "! grep -q 'acme-billing' <<< \"\$SR_HITS\""
assert "a customer-named plugin is not reported as an undeclared harness plugin" \
       "[ -z \"\$(undeclared_harness_shaped \"\$SR\")\" ]"
# …and dropping a harness plugin from the registry table must FAIL loudly rather
# than silently un-scan it.
mkdir -p "$SR/plugins/loom-orphan/scripts"
printf '#!/usr/bin/env bash\ndeclare -A ORPHAN\n' > "$SR/plugins/loom-orphan/scripts/o.sh"
assert "an UNDECLARED loom-* plugin is flagged by name (registry drift is loud)" \
       "[ \"\$(undeclared_harness_shaped \"\$SR\")\" = 'loom-orphan' ]"

# ─────────────────────────────────────────────────────────────────────────────
# Fixtures for the /specification quality gates. Written here rather than
# pointed at repo templates so the expected scores cannot drift when a template
# is edited for unrelated reasons.
# ─────────────────────────────────────────────────────────────────────────────
FX="$TMP/fx"
mkdir -p "$FX/feat/contracts"

{
  echo "# Feature Specification: Session Token Rotation"
  echo ""
  echo "## Overview"
  echo "Rotate session tokens on privilege change so a stolen cookie stops working."
  echo ""
  echo "## Scope"
  echo "In scope: token issuance and rotation. Out of scope: password reset."
  echo ""
  echo "## Requirements"
  echo "- FR-001: The system MUST issue a new token on role change."
  echo "- FR-002: The system MUST invalidate the prior token."
  echo ""
  echo "## User Stories"
  echo "As a signed-in user, I want my session to stay valid, so that I stay logged in."
  echo ""
  echo "## Acceptance Criteria"
  echo "- A role change produces a new token within one request."
  echo ""
  echo "## Non-Functional Requirements"
  echo "- Rotation adds no more than 20ms to the request."
  echo ""
  echo "## Dependencies"
  echo "- Existing session store."
  echo ""
  echo "## Notes"
  i=1
  while [ "$i" -le 34 ]; do
    echo "- Detail line $i covering rotation behaviour."
    i=$((i + 1))
  done
} > "$FX/spec.md"

{
  echo "# Implementation Plan: Session Token Rotation"
  echo ""
  echo "## Architecture"
  echo "A rotation service sits between the auth handler and the session store."
  echo ""
  echo "## Tech Stack"
  echo "TypeScript, Node.js, PostgreSQL."
  echo ""
  echo "## Implementation"
  echo "1. Add the rotation library."
  echo "2. Wire it into the auth handler."
  echo ""
  echo "## Dependencies"
  echo "- Session store client library"
  echo "- Contract tests for the API schema"
  echo ""
  echo "## Testing"
  echo "TDD: contract tests for the rotation interface land before implementation."
  echo ""
  echo "## Security"
  echo "Authorization is re-checked on every rotation; input validation on the token."
} > "$FX/feat/plan.md"
echo "# Research"   > "$FX/feat/research.md"
echo "# Data Model" > "$FX/feat/data-model.md"
echo "# Quickstart" > "$FX/feat/quickstart.md"
echo "# Rotation contract" > "$FX/feat/contracts/rotation.md"

{
  echo "# Tasks: Session Token Rotation"
  echo ""
  echo "## Setup"
  echo "- [ ] T001 [P] Scaffold the rotation library in src/lib/rotation/"
  echo ""
  echo "## Tests First"
  echo "- [ ] T002 [P] Contract test for the rotation API schema"
  echo "- [ ] T003 [P] Unit test for token invalidation"
  echo ""
  echo "## Implementation"
  echo "- [ ] T004 Implement rotation (depends on T002)"
  echo "- [ ] T005 Wire into the auth handler (after T004)"
  echo ""
  echo "## Polish"
  echo "- [ ] T006 [P] Update the interface documentation"
} > "$FX/feat/tasks.md"

# governance-metrics.sh derives its audit dir from its own location and the
# real one is untracked, so give it a throwaway repo of its own.
GM="$TMP/gmrepo"
mkdir -p "$GM/.logic-loom/scripts/bash" "$GM/.docs/governance/audit/2026-01-01"
cp "$ROOT/.logic-loom/scripts/bash/governance-metrics.sh" "$GM/.logic-loom/scripts/bash/"
printf '{"event_type":"git_operation","decision_type":"approved","layer":"hook"}\n' \
  > "$GM/.docs/governance/audit/2026-01-01/session-a.json"
printf '{"event_type":"orchestration_guidance","decision_type":"approved","layer":"hook"}\n' \
  > "$GM/.docs/governance/audit/2026-01-01/session-b.json"

# ─────────────────────────────────────────────────────────────────────────────
# The covered scripts, each with a REALISTIC invocation — the ones
# plugins/sdd-specification/skills/unified-specification/SKILL.md and CLAUDE.md
# actually document. `|||` separates label, command, expected exit.
# ─────────────────────────────────────────────────────────────────────────────
invocations() {
  cat <<INV
validate-spec.sh (SKILL.md 1d)|||$ROOT/.logic-loom/scripts/bash/validate-spec.sh --file $FX/spec.md --json|||0
validate-plan.sh (SKILL.md 2e)|||$ROOT/.logic-loom/scripts/bash/validate-plan.sh --file $FX/feat/plan.md --json|||0
validate-tasks.sh (SKILL.md 3g)|||$ROOT/.logic-loom/scripts/bash/validate-tasks.sh --file $FX/feat/tasks.md --json|||0
detect-phase-domain.sh (SKILL.md 1e, text)|||$ROOT/.logic-loom/scripts/bash/detect-phase-domain.sh "add a login form with API auth and database schema"|||0
detect-phase-domain.sh (SKILL.md 1e, --file --json)|||$ROOT/.logic-loom/scripts/bash/detect-phase-domain.sh --file $FX/spec.md --json|||0
load-context.sh load agents (CLAUDE.md)|||$ROOT/.logic-loom/scripts/bash/load-context.sh load agents|||0
load-context.sh load governance (CLAUDE.md)|||$ROOT/.logic-loom/scripts/bash/load-context.sh load governance|||0
load-context.sh list|||$ROOT/.logic-loom/scripts/bash/load-context.sh list|||0
load-context.sh analyze (exercises the ex-mapfile path)|||$ROOT/.logic-loom/scripts/bash/load-context.sh analyze "commit the agent workflow skill"|||0
create-agent.sh --help|||$ROOT/.logic-loom/scripts/bash/create-agent.sh --help|||0
governance-metrics.sh (text)|||$GM/.logic-loom/scripts/bash/governance-metrics.sh|||0
governance-metrics.sh (markdown)|||$GM/.logic-loom/scripts/bash/governance-metrics.sh --format markdown|||0
lib/logging.sh (sourced)|||source $ROOT/.logic-loom/lib/logging.sh; log_info bash32 '{}'; log_warn bash32 '{}'; log_error bash32 '{}'|||0
INV
}

# Run every invocation under $1 and report each exit code. Sets RUN_BAD.
run_all_under() {
  local interp="$1" label="$2"
  RUN_BAD=""
  local line name cmd want rc
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="${line%%|||*}"
    cmd="${line#*|||}"; want="${cmd##*|||}"; cmd="${cmd%|||*}"
    rc=0
    "$interp" -c "cd '$ROOT' || exit 99; $cmd" >"$TMP/out.txt" 2>"$TMP/err.txt" || rc=$?
    if [ "$rc" = "$want" ]; then
      printf '     %-52s exit=%s ok\n' "$name" "$rc"
    else
      printf '     %-52s exit=%s (expected %s)\n' "$name" "$rc" "$want"
      echo "         stderr: $(head -2 "$TMP/err.txt" | tr '\n' ' ')"
      RUN_BAD="${RUN_BAD}${name}; "
    fi
  done < <(invocations)
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "3. Golden output — the gates score the same bytes on every bash"
echo "   (asserted under bash 3.2 locally AND bash 5 on CI, so a"
echo "    'compatible' rewrite that scores differently fails on one of them)"

golden_json() {
  bash -c "cd '$ROOT' && $1" 2>/dev/null
}

SPEC_JSON="$(golden_json "$ROOT/.logic-loom/scripts/bash/validate-spec.sh --file $FX/spec.md --json")"
PLAN_JSON="$(golden_json "$ROOT/.logic-loom/scripts/bash/validate-plan.sh --file $FX/feat/plan.md --json")"
TASK_JSON="$(golden_json "$ROOT/.logic-loom/scripts/bash/validate-tasks.sh --file $FX/feat/tasks.md --json")"

assert "validate-spec: score 100"        "grep -q '\"score\": 100' <<< \"\$SPEC_JSON\""
assert "validate-spec: 10/10 passed"     "grep -q '\"total_checks\": 10' <<< \"\$SPEC_JSON\" && grep -q '\"passed\": 10' <<< \"\$SPEC_JSON\""
assert "validate-spec: status PASS"      "grep -q '\"status\": \"PASS\"' <<< \"\$SPEC_JSON\""
assert "validate-plan: score 100"        "grep -q '\"score\": 100' <<< \"\$PLAN_JSON\""
assert "validate-plan: 16/16 passed"     "grep -q '\"total_checks\": 16' <<< \"\$PLAN_JSON\" && grep -q '\"passed\": 16' <<< \"\$PLAN_JSON\""
assert "validate-tasks: score 100"       "grep -q '\"score\": 100' <<< \"\$TASK_JSON\""
assert "validate-tasks: 12/12 passed"    "grep -q '\"total_checks\": 12' <<< \"\$TASK_JSON\" && grep -q '\"passed\": 12' <<< \"\$TASK_JSON\""
assert "validate-tasks: task counts (6 total, 4 parallel)" \
       "grep -q '\"total\": 6' <<< \"\$TASK_JSON\" && grep -q '\"parallel\": 4' <<< \"\$TASK_JSON\""

# Check names must come back in DECLARED order on every bash. The old
# associative arrays iterated in hash order, so this is stricter than what it
# replaced — and it is the assertion that catches a parallel-array rewrite
# that silently drops or reorders a check.
SPEC_ORDER="$(printf '%s\n' "$SPEC_JSON" | grep '"result":' | grep -oE '^ *"[a-z_]+"' | tr -d ' "' | tr '\n' ' ')"
assert "validate-spec: checks in declared order" \
       "[ \"\$SPEC_ORDER\" = 'file_not_empty has_title has_overview has_requirements has_acceptance_criteria has_user_stories has_non_functional has_scope reasonable_length no_todos ' ]"
TASK_ORDER="$(printf '%s\n' "$TASK_JSON" | grep '"result":' | grep -oE '^ *"[a-z_]+"' | tr -d ' "' | tr '\n' ' ')"
assert "validate-tasks: checks in declared order" \
       "[ \"\$TASK_ORDER\" = 'file_not_empty has_title has_tasks has_checkboxes sufficient_tasks has_test_tasks has_contract_tasks has_dependencies has_parallel_markers not_all_completed reasonable_count has_sections ' ]"

# ── A FAILING document must still be scored, out loud ────────────────────────
# The gates ran `run_check` bare at top level under `set -e`, and run_check
# returned 1 when a REQUIRED check failed. So the script died mid-run and
# produced ZERO bytes for exactly the documents the gate exists to catch:
# a passing doc got a score, a failing doc got silence, and SKILL.md steps
# 1d/2e compared an empty string against a numeric threshold. These assertions
# pin the shape the fix guarantees — full JSON, a real score, non-zero exit —
# and they are additions: no pre-existing pin above was changed.
BADDOC="$FX/failing.md"
printf '# Not Really A Spec\n\nOne line, no sections.\n' > "$BADDOC"

bad_run() {  # $1 = script name; sets BAD_JSON, BAD_RC
  BAD_RC=0
  BAD_JSON="$(bash -c "cd '$ROOT' && '$ROOT/.logic-loom/scripts/bash/$1' --file '$BADDOC' --json" 2>/dev/null)" \
    || BAD_RC=$?
}
for g in validate-spec validate-plan validate-tasks; do
  bad_run "$g.sh"
  assert "$g: a FAILING document still emits JSON (not zero bytes)" \
         "[ -n \"\$BAD_JSON\" ]"
  assert "$g: a FAILING document reports status FAIL and a real score" \
         "grep -q '\"status\": \"FAIL\"' <<< \"\$BAD_JSON\" && grep -qE '\"score\": [0-9]+' <<< \"\$BAD_JSON\""
  assert "$g: a FAILING document names at least one failed check" \
         "grep -q '\"result\": \"FAIL\"' <<< \"\$BAD_JSON\""
  assert "$g: a FAILING document exits 1 (validated-and-failed)" \
         "[ \"\$BAD_RC\" -eq 1 ]"
done

# ── …and a SCRIPT ERROR must stay distinguishable from a failed document ─────
# Exit 3 = the gate never ran. Conflating it with 1 would let "file missing"
# read as "document is bad", which is the same defect pointing the other way.
for g in validate-spec validate-plan validate-tasks; do
  ERR_RC=0
  ERR_OUT="$(bash -c "cd '$ROOT' && '$ROOT/.logic-loom/scripts/bash/$g.sh' --file '$TMP/does-not-exist.md' --json" 2>/dev/null)" \
    || ERR_RC=$?
  assert "$g: missing file exits 3 (script error), not 1" "[ \"\$ERR_RC\" -eq 3 ]"
  assert "$g: missing file emits no JSON on stdout"       "[ -z \"\$ERR_OUT\" ]"
  ERR_RC=0
  bash -c "cd '$ROOT' && '$ROOT/.logic-loom/scripts/bash/$g.sh' --nosuchflag" >/dev/null 2>&1 || ERR_RC=$?
  assert "$g: unknown option exits 3 (script error)"      "[ \"\$ERR_RC\" -eq 3 ]"
done

# ── The SHIPPED templates must pass the gate the shipped skill runs on them ──
assert "spec-template.md passes validate-spec.sh (the documented first step)" \
       "bash '$ROOT/.logic-loom/scripts/bash/validate-spec.sh' --file '$ROOT/.logic-loom/templates/spec-template.md' --json >/dev/null 2>&1"
assert "tasks-template.md passes validate-tasks.sh" \
       "bash '$ROOT/.logic-loom/scripts/bash/validate-tasks.sh' --file '$ROOT/.logic-loom/templates/tasks-template.md' --json >/dev/null 2>&1"

# plan-template.md is the one shipped template that CANNOT reach the threshold
# standing alone, and that is correct rather than a defect. validate-plan.sh
# has four checks that test the FILESYSTEM beside the plan — research.md,
# data-model.md, contracts/, quickstart.md — and a template living in
# `.logic-loom/templates/` has no companion artifacts by construction. They are
# `recommended`, so they WARN; the gate still exits 0.
#
# So what is asserted here is the thing that is actually true and actually
# load-bearing: every REQUIRED check passes, no check fails, and the ONLY
# non-passing checks are those four artifact-existence warnings — named, so a
# future regression that swaps one warning for another cannot hide inside a
# count. The score (75) is DERIVED and re-derived here from passed/total rather
# than pinned as a literal, so adding a check to the gate moves the number
# without a spurious failure; what would fail is a content check regressing.
# SKILL.md step 2e's threshold of 85 is a bar for a real plan IN SITU, where
# those four artifacts exist — not for the template in the templates directory.
PLAN_TPL_RC=0
PLAN_TPL_JSON="$(bash -c "cd '$ROOT' && '$ROOT/.logic-loom/scripts/bash/validate-plan.sh' --file '$ROOT/.logic-loom/templates/plan-template.md' --json" 2>/dev/null)" \
  || PLAN_TPL_RC=$?
assert "plan-template.md passes validate-plan.sh (exit 0, status PASS)" \
       "[ \"\$PLAN_TPL_RC\" -eq 0 ] && grep -q '\"status\": \"PASS\"' <<< \"\$PLAN_TPL_JSON\""
assert "plan-template.md: zero failed checks" \
       "grep -q '\"failed\": 0' <<< \"\$PLAN_TPL_JSON\""
# The three REQUIRED heading checks that this template used to fail outright
# (score 37, exit 1) because it said '## Architectural notes' and had no
# tech-stack or implementation section at all.
for c in has_architecture has_tech_stack has_implementation_steps; do
  assert "plan-template.md: required check '$c' passes" \
         "grep -q '\"$c\": {\"result\": \"PASS\"' <<< \"\$PLAN_TPL_JSON\""
done
# The shortfall is EXACTLY the four artifact-existence checks — no more, no
# fewer, and no other check hiding among them.
assert "plan-template.md: exactly 4 warnings" \
       "grep -q '\"warnings\": 4' <<< \"\$PLAN_TPL_JSON\""
for c in research_exists data_model_exists contracts_exist quickstart_exists; do
  assert "plan-template.md: '$c' warns (no companion artifact beside a template)" \
         "grep -q '\"$c\": {\"result\": \"WARN\"' <<< \"\$PLAN_TPL_JSON\""
done
PLAN_TPL_WARNS="$(printf '%s\n' "$PLAN_TPL_JSON" | grep -c '"result": "WARN"')"
assert "plan-template.md: the 4 named artifact checks are the ONLY warnings" \
       "[ \"\$PLAN_TPL_WARNS\" -eq 4 ]"
# Score is consistent with the check tally rather than a magic constant.
PLAN_TPL_PASSED="$(printf '%s\n' "$PLAN_TPL_JSON" | grep -oE '\"passed\": [0-9]+' | grep -oE '[0-9]+')"
PLAN_TPL_TOTAL="$(printf '%s\n' "$PLAN_TPL_JSON" | grep -oE '\"total_checks\": [0-9]+' | grep -oE '[0-9]+')"
PLAN_TPL_SCORE="$(printf '%s\n' "$PLAN_TPL_JSON" | grep -oE '\"score\": [0-9]+' | grep -oE '[0-9]+')"
assert "plan-template.md: score equals passed*100/total (derived, not pinned)" \
       "[ \"\$PLAN_TPL_SCORE\" -eq \$(( PLAN_TPL_PASSED * 100 / PLAN_TPL_TOTAL )) ]"
assert "plan-template.md: every non-artifact check passes (12 of 16)" \
       "[ \"\$PLAN_TPL_PASSED\" -eq \$(( PLAN_TPL_TOTAL - 4 )) ]"
# --strict must not turn the four expected warnings into exit 2.
PLAN_TPL_SRC=0
bash -c "cd '$ROOT' && '$ROOT/.logic-loom/scripts/bash/validate-plan.sh' --file '$ROOT/.logic-loom/templates/plan-template.md' --strict --json" >/dev/null 2>&1 \
  || PLAN_TPL_SRC=$?
assert "plan-template.md: --strict still exits 0 (4 warnings is under the >5 bar)" \
       "[ \"\$PLAN_TPL_SRC\" -eq 0 ]"
# The template must stay a TEMPLATE, not become a worked example that happens
# to score well: the placeholder grammar and the DAG frontmatter survive.
assert "plan-template.md is still a template (placeholders + DAG frontmatter intact)" \
       "grep -q '^# Plan: <feature-name>' '$ROOT/.logic-loom/templates/plan-template.md' && grep -q '^feature: <feature-name>' '$ROOT/.logic-loom/templates/plan-template.md' && grep -q '^sprints:' '$ROOT/.logic-loom/templates/plan-template.md'"

DOMAIN_JSON="$(golden_json "$ROOT/.logic-loom/scripts/bash/detect-phase-domain.sh 'add a login form with API auth and database schema'")"
assert "detect-phase-domain: ranks backend > database > frontend" \
       "printf '%s' \"\$DOMAIN_JSON\" | grep -q 'backend: 3 matches' && printf '%s' \"\$DOMAIN_JSON\" | grep -q 'database: 2 matches' && printf '%s' \"\$DOMAIN_JSON\" | grep -q 'frontend: 1 matches'"

GM_OUT="$(bash "$GM/.logic-loom/scripts/bash/governance-metrics.sh" 2>/dev/null || true)"
assert "governance-metrics: counts both audit events" \
       "printf '%s' \"\$GM_OUT\" | grep -q 'Total Events: 2'"
assert "governance-metrics: keeps per-key counts" \
       "printf '%s' \"\$GM_OUT\" | grep -q 'git_operation' && printf '%s' \"\$GM_OUT\" | grep -q 'orchestration_guidance'"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "4. Every covered script EXECUTES under real bash 3.2"
if [ -n "$BASH32" ]; then
  run_all_under "$BASH32" "bash 3.2"
  assert "all covered scripts run clean under $($BASH32 --version | head -1 | sed 's/.*version //;s/ .*//')" \
         "[ -z \"\$RUN_BAD\" ]"
else
  echo "     ⏭  SKIPPED — no bash 3.2 on this host."
  echo "        NOT VERIFIED HERE: that these scripts execute on stock macOS."
  echo "        Section 1 still guarantees no KNOWN bash-4-only construct is"
  echo "        present, and section 3 still guarantees the scores are stable."
  echo "        A novel bash-4-only construct would pass this host and break macOS."
  # Not an assertion — a skip that lies about itself is the failure mode this
  # suite exists to end. But the run must not be assertion-free here, so the
  # host bash still executes every invocation as a smoke test:
  run_all_under "$(command -v bash)" "host bash"
  assert "all covered scripts run clean under the host bash (smoke only)" \
         "[ -z \"\$RUN_BAD\" ]"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "5. A reintroduced 'declare -A' actually FAILS under bash 3.2"
if [ -n "$BASH32" ]; then
  REG="$TMP/regress"
  mkdir -p "$REG"
  cp "$ROOT/.logic-loom/scripts/bash/validate-spec.sh" "$REG/validate-spec.sh"
  cp "$ROOT/.logic-loom/scripts/bash/common.sh" "$REG/common.sh"
  # Put the bash-4-only declaration back, exactly as it shipped.
  sed -i.bak 's/^CHECK_NAMES=()$/declare -A CHECKS\nCHECK_NAMES=()/' "$REG/validate-spec.sh"
  rm -f "$REG/validate-spec.sh.bak"
  assert "the scratch copy really got the construct back" \
         "grep -q 'declare -A CHECKS' \"\$REG/validate-spec.sh\""
  RC=0
  "$BASH32" "$REG/validate-spec.sh" --file "$FX/spec.md" --json >"$TMP/reg.out" 2>"$TMP/reg.err" || RC=$?
  echo "     planted copy under bash 3.2: exit=$RC — $(grep -m1 'declare' "$TMP/reg.err" || head -1 "$TMP/reg.err")"
  assert "planted 'declare -A' fails under bash 3.2 (exit != 0)" "[ \"\$RC\" -ne 0 ]"
  assert "…and the scanner flags the planted copy too" "[ -n \"\$(scan_tree \"\$REG\")\" ]"
else
  echo "     ⏭  SKIPPED — no bash 3.2 on this host. Section 2 proves the"
  echo "        SCANNER catches a planted construct; proving the INTERPRETER"
  echo "        rejects it needs a 3.2 binary, which CI does not have."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "6. This suite is itself bash 3.2 safe (it is the one scan exclusion)"
if [ -n "$BASH32" ]; then
  assert "test_bash32_floor.sh parses under bash 3.2" \
         "\"\$BASH32\" -n \"\$ROOT/$SELF_EXCLUDE\""
else
  echo "     ⏭  SKIPPED — no bash 3.2 on this host."
fi
# Everywhere: the exclusion must not be a blanket one.
EXCL_COUNT="$(printf '%s\n' "$SELF_EXCLUDE" | grep -c . )"
assert "exactly one file is excluded from the scan" "[ \"\$EXCL_COUNT\" -eq 1 ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
