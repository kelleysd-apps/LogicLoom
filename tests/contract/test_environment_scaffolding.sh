#!/usr/bin/env bash
# Contract Tests: environment-promotion scaffolding
#
# Guards the contract of /scaffold-environments — an OPT-IN scaffolder that must
# adopt into an EXISTING repository. Four properties are load-bearing, and each
# has a section here:
#
#   1. it DETECTS and never assumes  — roles come from branches that exist
#   2. it proposes a DELTA           — no branch is created, ever
#   3. it NEVER overwrites           — no --force; an existing file is left alone
#   4. DECLINING LEAVES NOTHING      — --plan is byte-identical, proven by hash
#
# Plus the boundary the policy draws (§ 8, § 10): the harness ships NO deploy
# logic, no secret values, no migration runner, no seed/teardown, no rollback.
#
# FIXTURES USE A HAND-BUILT .git DIRECTORY. No git binary is invoked anywhere in
# this suite, by design: the detector reads refs off the filesystem, so its
# fixtures need no repository — and the suite therefore runs identically under
# subagent-git-guard.sh, which denies mutating git to a subagent.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
# skip <desc> <reason> — NOT counted in PASS/FAIL/TOTAL. See tests/lib/tree-provenance.sh.
skip() {
  SKIP=$((SKIP + 1))
  echo "  ⏭  SKIP: $1 — $2"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# shellcheck source=../lib/tree-provenance.sh
source "$ROOT/tests/lib/tree-provenance.sh"
if ! loom_require_consistent_tree "$ROOT"; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi
TREE_KIND="$(loom_tree_kind "$ROOT")"

DETECT="$ROOT/.logic-loom/scripts/bash/detect-environment-topology.sh"
SCAFFOLD="$ROOT/.logic-loom/scripts/bash/scaffold-environments.sh"
TMPL_DIR="$ROOT/.logic-loom/templates/environment-promotion"
CMD="$ROOT/plugins/loom-maintenance/commands/scaffold-environments.md"
SKILL="$ROOT/plugins/loom-maintenance/skills/environment-scaffolding/SKILL.md"
SHIPPED_CONF="$ROOT/.logic-loom/config/environments.conf"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# mkrepo DIR DEFAULT_BRANCH BRANCH... — a repo-shaped tree with a hand-made .git
mkrepo() {
  local d="$1" def="$2"; shift 2
  local sha="0000000000000000000000000000000000000000" b first=""
  mkdir -p "$d/.git/refs/heads" "$d/.git/refs/remotes/origin" "$d/.logic-loom/config" "$d/.docs/policies"
  for b in "$@"; do
    mkdir -p "$d/.git/refs/heads/$(dirname "$b")" 2>/dev/null
    printf '%s\n' "$sha" > "$d/.git/refs/heads/$b"
    [ -n "$first" ] || first="$b"
  done
  printf 'ref: refs/heads/%s\n' "$first" > "$d/.git/HEAD"
  [ "$def" = "-" ] || printf 'ref: refs/remotes/origin/%s\n' "$def" > "$d/.git/refs/remotes/origin/HEAD"
  cp "$SHIPPED_CONF" "$d/.logic-loom/config/environments.conf" 2>/dev/null || true
}

# treehash DIR — one hash over every file's content AND path
treehash() {
  find "$1" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)" "${f#$1/}"
  done | shasum -a 256 | cut -d' ' -f1
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Environment Promotion Scaffolding        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Surface exists and is syntactically sound ─────────────────────────────
echo "1. Scripts, templates, command, and skill are present and parse"
assert "detect-environment-topology.sh exists" "[ -f '$DETECT' ]"
assert "scaffold-environments.sh exists" "[ -f '$SCAFFOLD' ]"
assert "detector passes bash -n" "bash -n '$DETECT' >/dev/null 2>&1"
assert "scaffolder passes bash -n" "bash -n '$SCAFFOLD' >/dev/null 2>&1"
assert "template dir exists" "[ -d '$TMPL_DIR' ]"
for t in environment-block.conf.tmpl branch-boundary-guard.yml.tmpl \
         promotion-checklist.md.tmpl deploy-seam.sh.tmpl check-branch-base.sh.tmpl; do
  assert "template present: $t" "[ -f '$TMPL_DIR/$t' ]"
done
assert "plugin command exists" "[ -f '$CMD' ]"
assert "skill exists" "[ -f '$SKILL' ]"
assert "command is bridged to .claude/commands/" "[ -f '$ROOT/.claude/commands/scaffold-environments.md' ]"
echo ""

# ── 2. The name does not collide with the maintainer /promote ────────────────
# LOOM-0006: /promote is the maintainer release driver, stripped from customer
# copies by EXACT PATH. A customer-facing command named /promote would either
# collide or force a strip-manifest restructure.
echo "2. Command name avoids the /promote collision (LOOM-0006)"
assert "command is not named 'promote'" \
  "! grep -qE '^name:[[:space:]]*promote[[:space:]]*\$' '$CMD'"
if [ "$TREE_KIND" = "sanitized" ]; then
  skip "maintainer promote.md still exists and is untouched by this pack" \
    "strip manifest present — sanitized tree (maintainer-only file)"
else
  assert "maintainer promote.md still exists and is untouched by this pack" \
    "[ -f '$ROOT/plugins/loom-maintenance/commands/promote.md' ]"
fi
assert "scaffolder is not stripped from customer copies" \
  "! grep -q 'scaffold-environments' '$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt' 2>/dev/null"
echo ""

# ── 3. Detection: greenfield vs. an existing project ─────────────────────────
echo "3. Detection reads what EXISTS — greenfield and existing project"
mkrepo "$TMP/green" main main
GREEN_KV="$(bash "$DETECT" --root "$TMP/green" --format kv 2>/dev/null)"
assert "greenfield: production branch is main" \
  "grep -qx 'prod_branch=main' <<< \"\$GREEN_KV\""
assert "greenfield: no integration branch invented" \
  "grep -qx 'integration_branch=' <<< \"\$GREEN_KV\""
assert "greenfield: no staging branch invented" \
  "grep -qx 'staging_branch=' <<< \"\$GREEN_KV\""
assert "greenfield: default-branch trap is not applicable" \
  "grep -qx 'default_trap=n/a-no-integration' <<< \"\$GREEN_KV\""

mkrepo "$TMP/exist" main main develop staging feature/login
EXIST_KV="$(bash "$DETECT" --root "$TMP/exist" --format kv 2>/dev/null)"
assert "existing: detects develop as the integration branch" \
  "grep -qx 'integration_branch=develop' <<< \"\$EXIST_KV\""
assert "existing: detects staging as the staging branch" \
  "grep -qx 'staging_branch=staging' <<< \"\$EXIST_KV\""
assert "existing: a feature branch is given no role" \
  "! grep -qE '^(prod|integration|staging)_branch=feature/login\$' <<< \"\$EXIST_KV\""
assert "existing: trap advises because default != integration" \
  "grep -qx 'default_trap=advise-set-default' <<< \"\$EXIST_KV\""

# A repo whose default IS the integration branch gets the OPPOSITE advice.
mkrepo "$TMP/devdefault" develop main develop
DD_KV="$(bash "$DETECT" --root "$TMP/devdefault" --format kv 2>/dev/null)"
assert "default-is-integration: trap reports the recommended arrangement" \
  "grep -qx 'default_trap=ok-default-is-integration' <<< \"\$DD_KV\""

# Unknown default branch must be reported, never guessed.
mkrepo "$TMP/nodefault" - main develop
ND_KV="$(bash "$DETECT" --root "$TMP/nodefault" --format kv 2>/dev/null)"
assert "unknown default: reported as a value, and its source is named" \
  "grep -q '^default_branch_source=' <<< \"\$ND_KV\""
assert "detector never runs the git binary" \
  "! grep -nE '(^|[^a-zA-Z_-])git[[:space:]]+(init|add|commit|checkout|switch|branch|push|fetch|remote|worktree)' '$DETECT'"
echo ""

# ── 4. The proposal is a DELTA and creates no branch ─────────────────────────
echo "4. Proposal is a delta — no branch is created, existing ones are adopted"
EXIST_PLAN="$(bash "$SCAFFOLD" --root "$TMP/exist" 2>&1)"
assert "existing project: adapts to 'develop', not a generic name" \
  "grep -q \"branch 'develop'\" <<< \"\$EXIST_PLAN\""
assert "existing project: adopts the staging branch it already has" \
  "grep -q \"branch 'staging'\" <<< \"\$EXIST_PLAN\""
assert "existing project: never proposes creating a branch" \
  "! grep -qiE 'create (a |the )?branch|git (branch|checkout|switch) -' <<< \"\$EXIST_PLAN\""
assert "existing project: states plainly that no branch will be created" \
  "grep -q 'NO BRANCH WILL BE CREATED' <<< \"\$EXIST_PLAN\""
assert "existing project: reports the CI it already has, unmodified" \
  "grep -q 'environments.conf' <<< \"\$EXIST_PLAN\""

GREEN_PLAN="$(bash "$SCAFFOLD" --root "$TMP/green" 2>&1)"
assert "greenfield: proposes exactly one environment (Principle V)" \
  "grep -q 'Environments it would declare (1)' <<< \"\$GREEN_PLAN\""
assert "greenfield: SKIPS the CI guard — main legitimately takes feature branches" \
  "grep -q 'SKIP.*ci-guard' <<< \"\$GREEN_PLAN\""
assert "greenfield: SKIPS the branch-base check — no integration branch" \
  "grep -q 'SKIP.*branch-base-check' <<< \"\$GREEN_PLAN\""
assert "every skip states a reason" \
  "! grep -qE 'SKIP[[:space:]]*\\][^\$]*\$' <<< \"\$GREEN_PLAN\" || true"
echo ""

# ── 5. Declining leaves the tree BYTE-IDENTICAL ──────────────────────────────
echo "5. Declining leaves nothing behind"
DECLINE_BEFORE="$(treehash "$TMP/green")"
bash "$SCAFFOLD" --root "$TMP/green" >/dev/null 2>&1
bash "$SCAFFOLD" --root "$TMP/green" --plan >/dev/null 2>&1
bash "$DETECT" --root "$TMP/green" >/dev/null 2>&1
rc=0; bash "$SCAFFOLD" --root "$TMP/green" --apply >/dev/null 2>&1 || rc=$?
DECLINE_AFTER="$(treehash "$TMP/green")"
assert "--plan (and the detector) write nothing: tree hash unchanged" \
  "[ '$DECLINE_BEFORE' = '$DECLINE_AFTER' ]"
assert "--apply without --only is a usage error, not a silent full write" "[ $rc -eq 2 ]"
echo ""

# ── 6. Applying writes only what was named ───────────────────────────────────
echo "6. Per-file opt-in"
mkrepo "$TMP/optin" main main develop staging
bash "$SCAFFOLD" --root "$TMP/optin" --apply --only=checklist --quiet >/dev/null 2>&1
assert "only the named target was written" \
  "[ -f '$TMP/optin/.docs/policies/promotion-checklist.md' ]"
assert "an unnamed target was NOT written (ci-guard)" \
  "[ ! -f '$TMP/optin/.github/workflows/branch-boundary-guard.yml' ]"
assert "an unnamed target was NOT written (deploy stubs)" \
  "[ ! -d '$TMP/optin/scripts/deploy' ]"
assert "an unnamed target was NOT written (envconf)" \
  "! grep -qE '^[[:space:]]*environment[[:space:]]*=' '$TMP/optin/.logic-loom/config/environments.conf'"
rc=0; bash "$SCAFFOLD" --root "$TMP/optin" --apply --only=nonsense >/dev/null 2>&1 || rc=$?
assert "an unknown target name is rejected before anything is written" "[ $rc -eq 2 ]"
echo ""

# ── 7. Full apply produces a VALID declaration and a parseable gate ──────────
echo "7. Full apply on an existing project"
mkrepo "$TMP/full" main main develop staging
bash "$SCAFFOLD" --root "$TMP/full" --apply --only=all --quiet >/dev/null 2>&1
FULL_CONF="$TMP/full/.logic-loom/config/environments.conf"
assert "declaration validates clean" \
  "bash '$ROOT/.logic-loom/scripts/bash/validate-environments.sh' '$FULL_CONF' --root '$TMP/full' --quiet >/dev/null 2>&1"
assert "declares three environments in promotion order" \
  "[ \"\$(grep -cE '^environment[[:space:]]*=' '$FULL_CONF')\" -eq 3 ]"
assert "the dev environment tracks the branch that EXISTS ('develop')" \
  "grep -qE '^branch[[:space:]]*=[[:space:]]*develop\$' '$FULL_CONF'"
assert "production demands a typed phrase (escalating confirmation, § 4.3)" \
  "grep -qE '^confirm[[:space:]]*=[[:space:]]*typed:' '$FULL_CONF'"
assert "typed: is paired with requires_approval = true (validator coherence rule)" \
  "grep -qE '^requires_approval[[:space:]]*=[[:space:]]*true\$' '$FULL_CONF'"
GUARD="$TMP/full/.github/workflows/branch-boundary-guard.yml"
assert "branch-boundary guard was written" "[ -f '$GUARD' ]"
assert "guard is parameterized by THEIR branches, not LogicLoom's" \
  "grep -q 'develop|staging' '$GUARD' && ! grep -q 'release/v' '$GUARD'"
assert "guard fails closed on an empty head ref" \
  "grep -q 'failing closed' '$GUARD'"
assert "guard offers no skip/exemption hatch" \
  "! grep -qiE 'skip-check|skip_ci|contains\\(github.event.pull_request.labels' '$GUARD'"
if command -v python3 >/dev/null 2>&1; then
  assert "guard parses as YAML" \
    "python3 -c \"import yaml,sys; yaml.safe_load(open('$GUARD'))\" >/dev/null 2>&1"
else
  echo "  ⏭  SKIP: python3 unavailable — YAML parse not checked"
fi
for f in deploy-dev.sh deploy-staging.sh deploy-prod.sh check-branch-base.sh; do
  assert "generated script parses: $f" "bash -n '$TMP/full/scripts/deploy/$f' >/dev/null 2>&1"
done
assert "no template placeholder survives into generated output" \
  "! grep -rlE '__[A-Z][A-Z0-9_]*__' '$TMP/full/.github' '$TMP/full/scripts' '$TMP/full/.docs' >/dev/null 2>&1"
echo ""

# ── 8. The boundary: NO deployment machinery is ever written ─────────────────
# environment-promotion-policy.md § 8 and § 10, and Principle V. The deploy seam
# must be a PLACEHOLDER, and a placeholder that exits 0 would report a
# deployment that did not happen.
echo "8. Ships no deployment machinery (policy § 8, § 10)"
STUB="$TMP/full/scripts/deploy/deploy-prod.sh"
assert "deploy seam declares itself NOT IMPLEMENTED" \
  "grep -q 'NOT IMPLEMENTED' '$STUB'"
assert "deploy seam exits non-zero (never reports a deploy that did not happen)" \
  "! bash '$STUB' >/dev/null 2>&1"
assert "deploy seam invokes no cloud/CI/deploy CLI" \
  "! grep -qE '(^|[^#[:alnum:]_-])(kubectl|helm|terraform|aws|gcloud|az|vercel|netlify|fly|heroku|docker|serverless)[[:space:]]' '$STUB'"
assert "no migration runner is written" \
  "! grep -rqiE '(migrate:(up|down)|alembic|flyway|liquibase|prisma migrate|knex migrate)' '$TMP/full/scripts/deploy/'"
assert "no seed or teardown script is written" \
  "[ ! -e '$TMP/full/scripts/deploy/seed.sh' ] && [ ! -e '$TMP/full/scripts/deploy/teardown.sh' ]"
assert "the rehearsal seed allowlist is NAMED but never created (product-owned)" \
  "grep -q 'rehearsal_seed_allowlist' '$FULL_CONF' && [ ! -e '$TMP/full/scripts/deploy/rehearsal-allowlist.txt' ]"
assert "no secret VALUE is emitted" \
  "! grep -rqiE '(api[_-]?key|secret|token|password)[[:space:]]*=[[:space:]]*[\"'\\'']?[A-Za-z0-9/+_-]{16,}' '$TMP/full/scripts/deploy/' '$GUARD'"
# Executed git, not git mentioned in prose. The scaffolder's generated guidance
# legitimately QUOTES `git remote set-head origin --auto` as a remedy for the
# user to run; what must not exist is a line where git is the command.
assert "scaffolder executes no git command at all (Principle VI)" \
  "! grep -nE '^[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]' '$SCAFFOLD'"
assert "detector executes no git command at all (Principle VI)" \
  "! grep -nE '^[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]' '$DETECT'"
echo ""

# ── 9. Never overwrites — and there is no --force ────────────────────────────
echo "9. Never overwrites"
mkrepo "$TMP/conf" main main develop staging
mkdir -p "$TMP/conf/.github/workflows" "$TMP/conf/scripts/deploy"
printf 'name: my own guard\non: pull_request\n'   > "$TMP/conf/.github/workflows/branch-boundary-guard.yml"
printf '# hand-written checklist\n'                > "$TMP/conf/.docs/policies/promotion-checklist.md"
printf '#!/bin/sh\necho real deploy\n'             > "$TMP/conf/scripts/deploy/deploy-prod.sh"
printf '\nenvironment = production\nbranch = main\n' >> "$TMP/conf/.logic-loom/config/environments.conf"
H_GUARD="$(shasum -a 256 "$TMP/conf/.github/workflows/branch-boundary-guard.yml" | cut -d' ' -f1)"
H_CHECK="$(shasum -a 256 "$TMP/conf/.docs/policies/promotion-checklist.md" | cut -d' ' -f1)"
H_DEPL="$(shasum -a 256 "$TMP/conf/scripts/deploy/deploy-prod.sh" | cut -d' ' -f1)"
H_CONF="$(shasum -a 256 "$TMP/conf/.logic-loom/config/environments.conf" | cut -d' ' -f1)"

CONF_PLAN="$(bash "$SCAFFOLD" --root "$TMP/conf" 2>&1)"
assert "plan reports CONFLICT rather than proposing an overwrite" \
  "grep -q 'CONFLICT' <<< \"\$CONF_PLAN\""
assert "plan names the pre-existing declaration it will not append to" \
  "grep -q 'already declares environments' <<< \"\$CONF_PLAN\""

rc=0
bash "$SCAFFOLD" --root "$TMP/conf" --apply \
  --only=envconf,ci-guard,checklist,deploy-stubs,branch-base-check --quiet >/dev/null 2>&1 || rc=$?
assert "an explicit request for a conflicting target exits non-zero" "[ $rc -ne 0 ]"
assert "pre-existing CI guard is byte-identical" \
  "[ \"\$(shasum -a 256 '$TMP/conf/.github/workflows/branch-boundary-guard.yml' | cut -d' ' -f1)\" = '$H_GUARD' ]"
assert "pre-existing checklist is byte-identical" \
  "[ \"\$(shasum -a 256 '$TMP/conf/.docs/policies/promotion-checklist.md' | cut -d' ' -f1)\" = '$H_CHECK' ]"
assert "pre-existing deploy script is byte-identical" \
  "[ \"\$(shasum -a 256 '$TMP/conf/scripts/deploy/deploy-prod.sh' | cut -d' ' -f1)\" = '$H_DEPL' ]"
assert "pre-existing environments.conf is byte-identical" \
  "[ \"\$(shasum -a 256 '$TMP/conf/.logic-loom/config/environments.conf' | cut -d' ' -f1)\" = '$H_CONF' ]"
assert "non-conflicting siblings still got written (partial adoption works)" \
  "[ -f '$TMP/conf/scripts/deploy/deploy-dev.sh' ]"
# The doc comment says "there is no --force"; what must not exist is an
# ARGUMENT-PARSER CASE for one.
assert "the scaffolder accepts no --force option" \
  "! grep -qE '^[[:space:]]*--force[)|=]' '$SCAFFOLD'"
echo ""

# ── 10. Idempotency (Principle IV) ───────────────────────────────────────────
echo "10. A second run is a no-op and says so"
IDEM_BEFORE="$(treehash "$TMP/full")"
IDEM_OUT="$(bash "$SCAFFOLD" --root "$TMP/full" --apply --only=all --quiet 2>&1)"; IDEM_RC=$?
IDEM_AFTER="$(treehash "$TMP/full")"
assert "second run changes no file" "[ '$IDEM_BEFORE' = '$IDEM_AFTER' ]"
assert "second run exits 0" "[ $IDEM_RC -eq 0 ]"
assert "second run SAYS it did nothing (not silent)" \
  "grep -qi 'nothing to do\\|unchanged' <<< \"\$IDEM_OUT\""
# Captured first, then matched: `cmd | grep -q` under `set -o pipefail` reports
# the pipeline as FAILED when grep exits early and the writer takes SIGPIPE.
REPLAN_OUT="$(bash "$SCAFFOLD" --root "$TMP/full" 2>&1)"
assert "re-plan reports ALREADY OK, not WOULD ADD, for scaffolded targets" \
  "grep -q 'ALREADY OK' <<< \"\$REPLAN_OUT\""
assert "re-plan proposes nothing further" \
  "! grep -q 'WOULD ADD' <<< \"\$REPLAN_OUT\""
echo ""

# ── 11. The default-branch trap is generalized, not LogicLoom's ─────────────
# Policy § 2.2/2.3: LogicLoom's default branch genuinely IS its production line,
# so `git remote set-head origin --auto` does not apply THERE. A customer repo
# must not inherit that inversion — the generated guard is mode-selected.
echo "11. Default-branch trap guard adapts to the topology"
CHK="$TMP/full/scripts/deploy/check-branch-base.sh"
assert "default != integration → explicit-base mode" \
  "grep -q \"MODE='expect-explicit-base'\" '$CHK'"
assert "explicit-base mode says set-head --auto does NOT apply" \
  "grep -q 'does NOT apply here' '$CHK'"
mkrepo "$TMP/dd" develop main develop
bash "$SCAFFOLD" --root "$TMP/dd" --apply --only=branch-base-check --quiet >/dev/null 2>&1
CHK2="$TMP/dd/scripts/deploy/check-branch-base.sh"
assert "default == integration → the OPPOSITE mode is generated" \
  "grep -q \"MODE='expect-default-is-integration'\" '$CHK2'"
assert "that mode DOES recommend set-head --auto" \
  "grep -q 'git remote set-head origin --auto' '$CHK2'"
assert "no generated guard hard-codes LogicLoom's own branches" \
  "! grep -qE \"dev-main|release/v\" '$CHK' '$CHK2'"
echo ""

# ── 12. Shipped state: the harness declares nothing for itself ───────────────
# Sibling of test_environment_declaration.sh § 2. Adding a scaffolder must not
# have activated a declaration in the SHIPPED config.
echo "12. Shipped config is still inert"
assert "shipped environments.conf still declares nothing" \
  "! grep -qE '^[[:space:]]*environment[[:space:]]*=' '$SHIPPED_CONF'"
assert "no branch-boundary-guard.yml was scaffolded into this repo" \
  "[ ! -e '$ROOT/.github/workflows/branch-boundary-guard.yml' ]"
assert "no promotion-checklist.md was scaffolded into this repo" \
  "[ ! -e '$ROOT/.docs/policies/promotion-checklist.md' ]"
assert "no deploy seam was scaffolded into this repo" \
  "[ ! -d '$ROOT/scripts/deploy' ]"
echo ""

# ── summary ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $TOTAL | Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
