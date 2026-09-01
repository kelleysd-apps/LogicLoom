#!/usr/bin/env bash
# Contract Tests: the three-command promotion lifecycle
#
# Guards /promote-dev, /promote-staging, /promote-prod and the gate beneath
# them. Six properties are load-bearing:
#
#   1. NOTHING DECLARED is a STATE, not a crash — each command explains and
#      points at /scaffold-environments; nothing is written.
#   2. The ESCALATING LADDER holds: prompt at dev and staging, a TYPED EXACT
#      PHRASE at production that rejects a wrong phrase and an empty one.
#   3. The SKIP FLAG works on dev and staging and PROVABLY does not bypass
#      production's typed phrase.
#   4. PROMOTION ORDER is enforced from `promotes_from`, refused with a typed
#      reason naming the missing predecessor.
#   5. A DECLARED `confirm` OVERRIDES the command default — the ladder is
#      configurable, not hardcoded.
#   6. FAIL CLOSED everywhere unevaluable, printing WHY and WHICH override —
#      including a missing deploy seam, which must print the path it looked for.
#
# Plus the hard boundary: the gate contains NO deploy logic, no cloud/CI API
# call, no migration runner, no seed/teardown, no secret handling, no rollback,
# and NO GIT (Principle VI).
#
# NO GIT BINARY IS INVOKED ANYWHERE IN THIS SUITE. Fixtures are plain
# directories, so the suite runs identically under subagent-git-guard.sh.
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
  echo "═══════════════════════════════════════════════════════════"
  echo "  Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
TREE_KIND="$(loom_tree_kind "$ROOT")"

GATE="$ROOT/.logic-loom/scripts/bash/promote-gate.sh"
RECORD="$ROOT/.logic-loom/scripts/bash/promotion-record.sh"
ATT_TMPL="$ROOT/.logic-loom/templates/environment-promotion/rehearsal-attestation.conf.tmpl"
SKILL="$ROOT/plugins/loom-maintenance/skills/promotion-lifecycle/SKILL.md"
CMD_DIR="$ROOT/plugins/loom-maintenance/commands"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# treehash DIR — one hash over every file's content AND path
treehash() {
  find "$1" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)" "${f#$1/}"
  done | shasum -a 256 | cut -d' ' -f1
}

# mkproj DIR — a project-shaped tree with a three-environment declaration and
# executable deploy seams. No .git, no git.
mkproj() {
  local d="$1"
  mkdir -p "$d/.logic-loom/config" "$d/.logic-loom/state" "$d/scripts/deploy"
  cat > "$d/.logic-loom/config/environments.conf" <<'CONF'
environment       = dev
branch            = develop
requires_approval = false
deploy            = scripts/deploy/deploy-dev.sh

environment       = staging
branch            = staging
promotes_from     = dev
requires_approval = false
deploy            = scripts/deploy/deploy-staging.sh

environment       = prod
branch            = main
promotes_from     = staging
requires_approval = true
confirm           = typed:PROMOTE TO PRODUCTION
deploy            = scripts/deploy/deploy-prod.sh
CONF
  local e
  for e in dev staging prod; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "$d/scripts/deploy/deploy-$e.sh"
    chmod +x "$d/scripts/deploy/deploy-$e.sh"
  done
}

# gate ROOTDIR ARGS... — run the gate against a fixture with closed stdin
gate() { local r="$1"; shift; bash "$GATE" --root "$r" --state-dir "$r/.logic-loom/state" "$@" </dev/null 2>&1; }
# gatein INPUT ROOTDIR ARGS... — run the gate feeding INPUT on stdin
gatein() { local i="$1" r="$2"; shift 2; printf '%s\n' "$i" | bash "$GATE" --root "$r" --state-dir "$r/.logic-loom/state" "$@" 2>&1; }

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Promotion Lifecycle (dev/staging/prod)   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Surface exists and parses ─────────────────────────────────────────────
echo "1. Surface: scripts, commands, skill, template"
assert "promote-gate.sh exists" "[ -f '$GATE' ]"
assert "promotion-record.sh exists" "[ -f '$RECORD' ]"
assert "gate passes bash -n" "bash -n '$GATE' >/dev/null 2>&1"
assert "recorder passes bash -n" "bash -n '$RECORD' >/dev/null 2>&1"
assert "rehearsal attestation template exists" "[ -f '$ATT_TMPL' ]"
assert "promotion-lifecycle skill exists" "[ -f '$SKILL' ]"
for c in promote-dev promote-staging promote-prod; do
  assert "command exists: $c.md" "[ -f '$CMD_DIR/$c.md' ]"
  assert "command has frontmatter name: $c" "grep -qE '^name:[[:space:]]*$c[[:space:]]*\$' '$CMD_DIR/$c.md'"
  assert "command is bridged to .claude/commands/: $c" "[ -f '$ROOT/.claude/commands/$c.md' ]"
done
# The maintainer /promote is a DIFFERENT command and is untouched by this pack.
if [ "$TREE_KIND" = "sanitized" ]; then
  skip "maintainer promote.md still present" \
    "plugins/loom-maintenance/commands/promote.md is stripped — sanitized tree (maintainer-only file)"
  skip "maintainer promote.md is still the only stripped promote command" \
    "strip manifest present — sanitized tree (maintainer-only file)"
else
assert "maintainer promote.md still present" "[ -f '$CMD_DIR/promote.md' ]"
assert "maintainer promote.md is still the only stripped promote command" \
  "grep -qx 'plugins/loom-maintenance/commands/promote.md' '$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt'"
fi
for c in promote-dev promote-staging promote-prod; do
  assert "customer command NOT stripped from the template: $c" \
    "! grep -qE '(^|/)$c\\.md' '$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt'"
done
echo ""

# ── 2. THE HARD BOUNDARY: gate and orchestrate, never deploy ─────────────────
echo "2. Hard boundary — the gate contains no deploy machinery and no git"
# Comments explain the boundary, so scan CODE only: strip full-line comments and
# trailing comments before matching.
CODE="$TMP/gate-code.sh"
sed 's/[[:space:]]*#.*$//' "$GATE" | grep -v '^[[:space:]]*$' > "$CODE"
RCODE="$TMP/record-code.sh"
sed 's/[[:space:]]*#.*$//' "$RECORD" | grep -v '^[[:space:]]*$' > "$RCODE"
# Match git as an INVOKED COMMAND (start of a statement), not the word "git" inside
# a message string — the refusal texts legitimately say "No git command was run."
assert "gate invokes no git" "! grep -qE '(^|[;&|(]|[$][(])[[:space:]]*git[[:space:]]' '$CODE'"
assert "recorder invokes no git" "! grep -qE '(^|[;&|(]|[$][(])[[:space:]]*git[[:space:]]' '$RCODE'"
assert "gate makes no network/provider call" \
  "! grep -qE '(^|[^a-zA-Z0-9_-])(curl|wget|gh|aws|gcloud|az|kubectl|docker|vercel|flyctl|heroku|supabase|terraform)[[:space:]]' '$CODE'"
assert "gate runs no migration/seed/teardown/rollback tooling" \
  "! grep -qiE '(migrate[[:space:]]*(up|down)|db:migrate|prisma|alembic|flyway|liquibase|rollback[[:space:]]+--)' '$CODE'"
assert "gate never executes the declared deploy seam" \
  "! grep -qE '(bash|sh|exec|eval|source|\\.)[[:space:]]+\"?\\\$SEAM' '$CODE'"
assert "gate handles no secrets" \
  "! grep -qiE '(AWS_SECRET|SECRET_KEY|API_KEY|_TOKEN=|PASSWORD)' '$CODE'"
assert "gate writes no file (no redirection into a path)" \
  "! grep -qE '>[[:space:]]*\"?\\\$(ROOT|CONF|SEAM|STATE_DIR|LEDGER|ATT)' '$CODE'"
assert "the ONLY writer is the ledger recorder" "grep -q 'LEDGER' '$RCODE'"
echo ""

# ── 3. FIXTURE 1 — nothing declared ──────────────────────────────────────────
echo "3. Fixture 1 — no environments.conf: explains, points at /scaffold-environments, writes nothing"
mkdir -p "$TMP/bare/.logic-loom/config"
BARE_BEFORE="$(treehash "$TMP/bare")"
for pair in "dev:prompt" "staging:prompt" "prod:typed:PROMOTE TO PRODUCTION"; do
  env_name="${pair%%:*}"; dflt="${pair#*:}"
  OUT="$(gate "$TMP/bare" --to "$env_name" --stage "$env_name" --default-confirm "$dflt")"
  RC=$?
  assert "$env_name: exit code is 3 (nothing declared — a state, not a crash)" "[ $RC -eq 3 ]"
  assert "$env_name: says NOTHING DECLARED" "grep -q 'NOTHING DECLARED' <<< \"\$OUT\""
  assert "$env_name: points at /scaffold-environments" "grep -q '/scaffold-environments' <<< \"\$OUT\""
  assert "$env_name: states nothing was deployed" "grep -q 'Nothing was deployed' <<< \"\$OUT\""
done
assert "nothing declared: the tree is byte-identical afterwards" \
  "[ \"\$(treehash '$TMP/bare')\" = '$BARE_BEFORE' ]"

# The SHIPPED declaration is fully commented out — the real customer default.
mkdir -p "$TMP/shipped/.logic-loom/config"
cp "$ROOT/.logic-loom/config/environments.conf" "$TMP/shipped/.logic-loom/config/environments.conf"
OUT="$(gate "$TMP/shipped" --to prod --stage prod --default-confirm 'typed:PROMOTE TO PRODUCTION')"; RC=$?
assert "shipped (all-commented) conf: exit 3, not a refusal" "[ $RC -eq 3 ]"
assert "shipped conf: still points at /scaffold-environments" "grep -q '/scaffold-environments' <<< \"\$OUT\""
echo ""

# ── 4. FIXTURE 2 — the escalating ladder ─────────────────────────────────────
echo "4. Fixture 2 — three-environment declaration: prompt, prompt, TYPED PHRASE"
mkproj "$TMP/p2"
# dev is the start of the chain and needs no predecessor.
OUT="$(gatein "y" "$TMP/p2" --to dev --stage dev --default-confirm prompt --commit abc123)"; RC=$?
assert "dev: a yes/no prompt is offered" "grep -q 'Promote into .dev.? \\[y/N\\]' <<< \"\$OUT\""
assert "dev: answering y clears the gate" "[ $RC -eq 0 ] && grep -q 'GATE CLEARED' <<< \"\$OUT\""
OUT="$(gatein "n" "$TMP/p2" --to dev --stage dev --default-confirm prompt --commit abc123)"; RC=$?
assert "dev: answering n refuses" "[ $RC -eq 1 ] && grep -q 'REFUSED' <<< \"\$OUT\""

# staging needs dev on the ledger first.
bash "$RECORD" --root "$TMP/p2" --state-dir "$TMP/p2/.logic-loom/state" \
  --env dev --status success --commit abc123 >/dev/null 2>&1
OUT="$(gatein "y" "$TMP/p2" --to staging --stage staging --default-confirm prompt --commit abc123)"; RC=$?
assert "staging: a yes/no prompt is offered" "grep -q 'Promote into .staging.? \\[y/N\\]' <<< \"\$OUT\""
assert "staging: answering y clears the gate" "[ $RC -eq 0 ]"

# prod: predecessor + rehearsal attestation, so the run reaches the confirmation.
bash "$RECORD" --root "$TMP/p2" --state-dir "$TMP/p2/.logic-loom/state" \
  --env staging --status success --commit abc123 >/dev/null 2>&1
NOWSTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$TMP/p2/.logic-loom/state/rehearsal-staging.conf" <<ATT
environment      = staging
status           = success
completed_at     = $NOWSTAMP
rehearsed_commit = abc123
ATT
# Functions, not a string: 'typed:PROMOTE TO PRODUCTION' contains spaces, and a
# word-split variable would silently mangle the very phrase under test.
prodgate() { # ROOTDIR [extra args...] — stdin closed
  local r="$1"; shift
  bash "$GATE" --root "$r" --state-dir "$r/.logic-loom/state" \
    --to prod --stage prod --default-confirm 'typed:PROMOTE TO PRODUCTION' \
    --require-rehearsal --commit abc123 "$@" </dev/null 2>&1
}
prodgatein() { # INPUT ROOTDIR [extra args...]
  local i="$1" r="$2"; shift 2
  printf '%s\n' "$i" | bash "$GATE" --root "$r" --state-dir "$r/.logic-loom/state" \
    --to prod --stage prod --default-confirm 'typed:PROMOTE TO PRODUCTION' \
    --require-rehearsal --commit abc123 "$@" 2>&1
}
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/p2")"; RC=$?
assert "prod: demands a TYPED EXACT PHRASE" "grep -q 'TYPED EXACT PHRASE' <<< \"\$OUT\""
assert "prod: the correct phrase clears the gate" "[ $RC -eq 0 ] && grep -q 'GATE CLEARED' <<< \"\$OUT\""
OUT="$(prodgatein "promote to production" "$TMP/p2")"; RC=$?
assert "prod: a WRONG phrase is rejected (case matters)" \
  "[ $RC -eq 1 ] && grep -q 'did not match exactly' <<< \"\$OUT\""
OUT="$(prodgatein "" "$TMP/p2")"; RC=$?
assert "prod: an EMPTY phrase is rejected" \
  "[ $RC -eq 1 ] && grep -q 'typed confirmation was empty' <<< \"\$OUT\""
OUT="$(prodgate "$TMP/p2")"; RC=$?
assert "prod: closed stdin refuses rather than assuming consent" "[ $RC -eq 1 ]"
assert "prod: the rehearsal-does-not-prove-it-works caveat is printed (§ 6.3)" \
  "grep -q 'different claims' <<< \"\$(prodgatein 'PROMOTE TO PRODUCTION' '$TMP/p2')\""
echo ""

# ── 5. FIXTURE 3 — the skip flag, and where it stops ─────────────────────────
echo "5. Fixture 3 — --yes skips dev and staging, and PROVABLY does not bypass prod"
OUT="$(gate "$TMP/p2" --to dev --stage dev --default-confirm prompt --yes --commit abc123)"; RC=$?
assert "dev: --yes clears with stdin CLOSED (nothing to answer)" "[ $RC -eq 0 ]"
assert "dev: --yes says what it skipped" "grep -q 'skipped by --yes' <<< \"\$OUT\""
OUT="$(gate "$TMP/p2" --to staging --stage staging --default-confirm prompt --yes --commit abc123)"; RC=$?
assert "staging: --yes clears with stdin CLOSED" "[ $RC -eq 0 ]"

# The proof: identical invocation at prod, with --yes, stdin closed. If --yes
# bypassed the typed phrase this would clear. It must refuse.
OUT="$(prodgate "$TMP/p2" --yes)"; RC=$?
assert "prod: --yes with closed stdin REFUSES (the flag does not bypass)" "[ $RC -eq 1 ]"
assert "prod: --yes did not clear the gate" "! grep -q 'GATE CLEARED' <<< \"\$OUT\""
assert "prod: --yes is explicitly reported as IGNORED" "grep -q 'IGNORED' <<< \"\$OUT\""
OUT="$(prodgatein "wrong" "$TMP/p2" --yes)"; RC=$?
assert "prod: --yes plus a wrong phrase still refuses" "[ $RC -eq 1 ]"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/p2" --yes)"; RC=$?
assert "prod: only the typed phrase clears it, --yes or not" "[ $RC -eq 0 ]"
# And no code path anywhere lets a flag/env var short-circuit a typed confirm.
assert "no --force flag exists on the gate" "! grep -q '\\-\\-force' '$CODE'"
echo ""

# ── 6. FIXTURE 4 — out-of-order promotion ────────────────────────────────────
echo "6. Fixture 4 — prod before staging: refused with a typed reason naming the predecessor"
mkproj "$TMP/p4"
cat > "$TMP/p4/.logic-loom/state/rehearsal-staging.conf" <<ATT
environment      = staging
status           = success
completed_at     = $NOWSTAMP
rehearsed_commit = abc123
ATT
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/p4")"; RC=$?
assert "out-of-order: refused" "[ $RC -eq 1 ]"
assert "out-of-order: names the missing predecessor 'staging'" \
  "grep -q \"promotes_from 'staging'\" <<< \"\$OUT\""
assert "out-of-order: says WHY (promotion order violated)" \
  "grep -q 'promotion order violated' <<< \"\$OUT\""
assert "out-of-order: names the override" \
  "grep -q -- '--allow-out-of-order' <<< \"\$OUT\""
assert "out-of-order: never reached the confirmation" \
  "! grep -q 'GATE CLEARED' <<< \"\$OUT\""
# The override works, but only with a reason.
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/p4" --allow-out-of-order "hotfix, dev+staging both green off-ledger")"; RC=$?
assert "override with a reason: clears, and echoes the reason" \
  "[ $RC -eq 0 ] && grep -q 'documented reason: hotfix' <<< \"\$OUT\""
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/p4" --allow-out-of-order "")"; RC=$?
assert "override with an EMPTY reason: refused" \
  "[ $RC -eq 1 ] && grep -q 'empty reason' <<< \"\$OUT\""
echo ""

# ── 7. FIXTURE 5 — a declared `confirm` overrides the command default ────────
echo "7. Fixture 5 — the declaration is the source of truth for confirmation strength"
mkproj "$TMP/p5"
# Raise dev: declare a typed phrase where the command default is only `prompt`.
cat > "$TMP/p5/.logic-loom/config/environments.conf" <<'CONF'
environment       = dev
branch            = develop
requires_approval = true
confirm           = typed:SHIP DEV
deploy            = scripts/deploy/deploy-dev.sh

environment       = prod
branch            = main
promotes_from     = dev
requires_approval = true
confirm           = prompt
deploy            = scripts/deploy/deploy-prod.sh
CONF
OUT="$(gate "$TMP/p5" --to dev --stage dev --default-confirm prompt --yes)"; RC=$?
assert "declared typed: on dev BEATS the command's prompt default" \
  "grep -q 'TYPED EXACT PHRASE' <<< \"\$OUT\""
assert "declared typed: on dev makes --yes stop working there too" "[ $RC -eq 1 ]"
assert "confirm resolution names its source" \
  "grep -q 'declared in environments.conf' <<< \"\$OUT\""
OUT="$(gatein "SHIP DEV" "$TMP/p5" --to dev --stage dev --default-confirm prompt)"; RC=$?
assert "declared phrase 'SHIP DEV' clears dev" "[ $RC -eq 0 ]"

# Lower prod: honoured, but never silently.
bash "$RECORD" --root "$TMP/p5" --state-dir "$TMP/p5/.logic-loom/state" \
  --env dev --status success --commit abc123 >/dev/null 2>&1
OUT="$(gatein "y" "$TMP/p5" --to prod --stage prod --default-confirm 'typed:PROMOTE TO PRODUCTION')"; RC=$?
assert "declared prompt on prod is HONOURED (declaration wins both ways)" "[ $RC -eq 0 ]"
assert "…but the weaker-than-default declaration is called out loudly" \
  "grep -q 'weaker than' <<< \"\$OUT\""
# And the fallback path is exercised: an env with no `confirm` uses the default.
OUT="$(gate "$TMP/p2" --to dev --stage dev --default-confirm prompt --yes)"
assert "no declared confirm → the command default is used, and says so" \
  "grep -q 'command default for stage' <<< \"\$OUT\""
echo ""

# ── 8. FIXTURE 6 — the deploy seam ───────────────────────────────────────────
echo "8. Fixture 6 — missing / unreadable / undeclared deploy seam fails closed with the path"
mkproj "$TMP/p6"
rm -f "$TMP/p6/scripts/deploy/deploy-dev.sh"
OUT="$(gate "$TMP/p6" --to dev --stage dev --default-confirm prompt --yes)"; RC=$?
assert "missing seam: refused" "[ $RC -eq 1 ]"
assert "missing seam: prints the ABSOLUTE PATH it looked for" \
  "grep -q 'LOOKED FOR: $TMP/p6/scripts/deploy/deploy-dev.sh' <<< \"\$OUT\""
assert "missing seam: also prints how it was declared" \
  "grep -q 'DECLARED AS: deploy = scripts/deploy/deploy-dev.sh' <<< \"\$OUT\""
assert "missing seam: never reached the confirmation" \
  "! grep -q 'GATE CLEARED' <<< \"\$OUT\""

mkproj "$TMP/p6b"
chmod -x "$TMP/p6b/scripts/deploy/deploy-dev.sh"
OUT="$(gate "$TMP/p6b" --to dev --stage dev --default-confirm prompt --yes)"; RC=$?
assert "non-executable seam: refused with the chmod fix" \
  "[ $RC -eq 1 ] && grep -q 'chmod +x' <<< \"\$OUT\""

mkproj "$TMP/p6c"
sed '/deploy            = scripts\/deploy\/deploy-dev.sh/d' \
  "$TMP/p6c/.logic-loom/config/environments.conf" > "$TMP/p6c/tmp.conf"
mv "$TMP/p6c/tmp.conf" "$TMP/p6c/.logic-loom/config/environments.conf"
OUT="$(gate "$TMP/p6c" --to dev --stage dev --default-confirm prompt --yes)"; RC=$?
assert "undeclared seam: refused, with the exact line to add" \
  "[ $RC -eq 1 ] && grep -q 'deploy = <path' <<< \"\$OUT\""
assert "undeclared seam: says the harness ships no deploy logic" \
  "grep -q 'ships no deploy logic' <<< \"\$OUT\""
echo ""

# ── 9. Fail closed everywhere else unevaluable ───────────────────────────────
echo "9. Fail closed with a typed reason — the rest of the unevaluable cases"
mkproj "$TMP/p9"
OUT="$(gate "$TMP/p9" --to nosuchenv --stage dev --default-confirm prompt --yes)"; RC=$?
assert "undeclared target env: refused, listing what IS declared" \
  "[ $RC -eq 1 ] && grep -q 'DECLARED: ' <<< \"\$OUT\""
# An INVALID declaration must not be promoted against at all.
printf 'environment = x\nconfirm = typed:NOPE\nrequires_approval = false\n' \
  > "$TMP/p9/.logic-loom/config/environments.conf"
OUT="$(gate "$TMP/p9" --to x --stage prod --default-confirm prompt --yes)"; RC=$?
assert "invalid declaration (typed: with requires_approval=false): refused" "[ $RC -eq 1 ]"
assert "invalid declaration: relays the validator's own reason" \
  "grep -q 'VALIDATOR SAID' <<< \"\$OUT\""

# Rehearsal contract: absent, failed, stale, unparseable, wrong commit.
mkproj "$TMP/pr"
bash "$RECORD" --root "$TMP/pr" --state-dir "$TMP/pr/.logic-loom/state" --env dev --status success --commit abc123 >/dev/null 2>&1
bash "$RECORD" --root "$TMP/pr" --state-dir "$TMP/pr/.logic-loom/state" --env staging --status success --commit abc123 >/dev/null 2>&1
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr")"; RC=$?
assert "rehearsal ABSENT: refused, printing the path it looked for" \
  "[ $RC -eq 1 ] && grep -q 'LOOKED FOR: $TMP/pr/.logic-loom/state/rehearsal-staging.conf' <<< \"\$OUT\""
assert "rehearsal ABSENT: says the override cannot conjure one" \
  "grep -q 'cannot conjure' <<< \"\$OUT\""

ATT="$TMP/pr/.logic-loom/state/rehearsal-staging.conf"
printf 'status = failure\ncompleted_at = %s\nrehearsed_commit = abc123\n' "$NOWSTAMP" > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr")"; RC=$?
assert "rehearsal FAILED: refused, with no override offered" \
  "[ $RC -eq 1 ] && grep -q 'OVERRIDE: none' <<< \"\$OUT\""
assert "rehearsal FAILED: reminds that the env is kept ALIVE (§ 4.5)" \
  "grep -q 'kept ALIVE' <<< \"\$OUT\""

printf 'status = success\ncompleted_at = not-a-date\nrehearsed_commit = abc123\n' > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr")"; RC=$?
assert "UNPARSEABLE completed_at: refused, never treated as recent" \
  "[ $RC -eq 1 ] && grep -q 'could not be parsed as a date' <<< \"\$OUT\""

printf 'status = success\ncompleted_at = 2020-01-01T00:00:00Z\nrehearsed_commit = abc123\n' > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr")"; RC=$?
assert "STALE rehearsal: refused, naming the staleness override" \
  "[ $RC -eq 1 ] && grep -q -- '--allow-stale-rehearsal' <<< \"\$OUT\""
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr" --allow-stale-rehearsal "cold codebase, no changes since")"; RC=$?
assert "staleness override with a reason: clears" "[ $RC -eq 0 ]"
# The narrowness of that override is the whole point: it must not rescue a FAILED
# rehearsal or a mismatched commit.
printf 'status = failure\ncompleted_at = 2020-01-01T00:00:00Z\nrehearsed_commit = abc123\n' > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr" --allow-stale-rehearsal "reason")"; RC=$?
assert "staleness override does NOT rescue a failed rehearsal" "[ $RC -eq 1 ]"

printf 'status = success\ncompleted_at = %s\nrehearsed_commit = deadbee\n' "$NOWSTAMP" > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr" --allow-stale-rehearsal "reason")"; RC=$?
assert "commit NOT covered by the attestation: refused" "[ $RC -eq 1 ]"
assert "…and the refusal cites § 6.4 (the merge's SECOND parent)" \
  "grep -qi 'second parent' <<< \"\$OUT\""
assert "…and states the harness runs no git / cannot compute ancestry" \
  "grep -q 'runs no git' <<< \"\$OUT\""
printf 'status = success\ncompleted_at = %s\nrehearsed_commit = deadbee\ncovers_commits = cafe01 abc123\n' "$NOWSTAMP" > "$ATT"
OUT="$(prodgatein "PROMOTE TO PRODUCTION" "$TMP/pr")"; RC=$?
assert "covers_commits lets the seam DECLARE the ancestry answer" "[ $RC -eq 0 ]"
OUT="$(gate "$TMP/pr" --to prod --stage prod --default-confirm 'typed:PROMOTE TO PRODUCTION' --require-rehearsal)"; RC=$?
assert "--require-rehearsal with no --commit: refused as unevaluable" \
  "[ $RC -eq 1 ] && grep -q 'no --commit was supplied' <<< \"\$OUT\""
echo ""

# ── 10. The ledger recorder ──────────────────────────────────────────────────
echo "10. Promotion ledger — the only thing these commands write"
mkproj "$TMP/pl"
bash "$RECORD" --root "$TMP/pl" --state-dir "$TMP/pl/.logic-loom/state" --env dev --status success --commit abc123 >/dev/null 2>&1
assert "a success is appended to promotion-ledger.tsv" \
  "[ -f '$TMP/pl/.logic-loom/state/promotion-ledger.tsv' ]"
assert "the ledger line is tab-separated with the environment in column 2" \
  "grep -qx 'dev' <<< \"\$(cut -f2 '$TMP/pl/.logic-loom/state/promotion-ledger.tsv')\""
OUT="$(bash "$RECORD" --root "$TMP/pl" --state-dir "$TMP/pl/.logic-loom/state" --env dev --status failure --commit abc123 2>&1)"; RC=$?
assert "a failure with no --note is REFUSED (no mute red lines)" "[ $RC -eq 1 ]"
OUT="$(bash "$RECORD" --root "$TMP/pl" --state-dir "$TMP/pl/.logic-loom/state" --env dev --status maybe 2>&1)"; RC=$?
assert "there is no third status: 'maybe' is refused" "[ $RC -eq 1 ]"
OUT="$(bash "$RECORD" --root "$TMP/pl" --state-dir "$TMP/pl/.logic-loom/state" --env dev --status success --commit abc123 2>&1)"
assert "recording says plainly that the outcome was REPORTED, not observed" \
  "grep -q 'did not observe it' <<< \"\$OUT\""
echo ""

# ── 11. Documentation carries the boundary and the honesty ───────────────────
echo "11. Commands and skill state the boundary, the ladder, and the trust split"
for c in promote-dev promote-staging promote-prod; do
  assert "$c: says it does not deploy" "grep -qi 'do not deploy\\|does not deploy\\|deploys nothing' '$CMD_DIR/$c.md'"
  assert "$c: names the deploy seam as product-owned" "grep -qi 'product-owned' '$CMD_DIR/$c.md'"
  assert "$c: cites Principle VI on git" "grep -q 'Principle VI' '$CMD_DIR/$c.md'"
  assert "$c: documents the exit-3 / nothing-declared path" "grep -q 'scaffold-environments' '$CMD_DIR/$c.md'"
done
assert "promote-prod: states no flag bypasses the typed phrase" \
  "grep -qi 'no flag' '$CMD_DIR/promote-prod.md'"
assert "promote-prod: separates VERIFIED from TAKEN ON TRUST" \
  "grep -q 'Taken on trust' '$CMD_DIR/promote-prod.md'"
assert "promote-prod: carries the §6.3 deployed-vs-proven distinction" \
  "grep -q 'different claims' '$CMD_DIR/promote-prod.md'"
assert "promote-staging: carries the fail-closed seed allowlist rule" \
  "grep -qi 'aborts the seed\\|ABORT' '$CMD_DIR/promote-staging.md'"
assert "promote-staging: carries keep-alive-on-failure (§ 4.5)" \
  "grep -qi 'alive on failure' '$CMD_DIR/promote-staging.md'"
assert "skill documents the confirm resolution order" "grep -q 'source of truth' '$SKILL'"
assert "skill documents the exit codes" "grep -q 'exit 3' '$SKILL' || grep -q '\`3\` nothing declared' '$SKILL'"
assert "attestation template names who writes it" "grep -q 'WHO WRITES THIS FILE' '$ATT_TMPL'"
assert "attestation template carries the § 6.4 trap" "grep -q 'SECOND PARENT' '$ATT_TMPL'"
echo ""

# ── 12. LOOM-0050 / LOOM-0051 — CI methodology templates + init-project parity
echo "12. CI methodology templates ship, and /initialize-project offers them"
WF_TMPL_DIR="$ROOT/.logic-loom/templates/workflows"
GUIDE="$ROOT/.docs/guides/release-loop-methodology.md"
PAYLOAD_MANIFEST="$ROOT/packaging/adopt/payload-manifest.txt"
INIT_CMD="$ROOT/plugins/loom-maintenance/commands/initialize-project.md"

for tmpl in plugin-tests leak-guard branch-topology-guard; do
  f="$WF_TMPL_DIR/$tmpl.yml.template"
  assert "$tmpl.yml.template exists" "[ -f '$f' ]"
  assert "$tmpl.yml.template carries an adaptation header (says it was adapted from LogicLoom's own CI)" \
    "grep -qi 'adapted from' '$f'"
  # None of our own topology strings may survive into a template an adopter
  # would install verbatim into their own .github/.
  for marker in 'dev-main' 'sdd-sync-ref' 'kelleysd-apps' 'promote-to-main'; do
    assert "$tmpl.yml.template does not contain topology string '$marker'" \
      "! grep -qi -- '$marker' '$f'"
  done
done

assert "release-loop-methodology.md guide exists" "[ -f '$GUIDE' ]"
assert "the guide is honest that LogicLoom ships no machinery for this pattern" \
  "grep -qi 'ships none of this as reusable machinery\\|Nothing in this document is enforced' '$GUIDE'"
# The guide ships via .docs/guides' EXISTING wholesale include — asserting no
# NEW include/exclude line was added for it, and no exclude was added either
# (the two mistakes this brief explicitly warned against).
# packaging/ (and therefore this manifest) is a template-strip-manifest entry
# — absent on a stripped/customer tree by design, same guard test_adopt_
# entrypoints.sh uses for the identical file. Skip rather than fail there.
if [ -f "$PAYLOAD_MANIFEST" ]; then
  assert "payload manifest still wholesale-includes .docs/guides (the guide needs no new include line)" \
    "grep -qE '^include:[[:space:]]+\\.docs/guides[[:space:]]*\$' '$PAYLOAD_MANIFEST'"
  assert "payload manifest does not exclude the release-loop guide" \
    "! grep -qE '^exclude:.*release-loop-methodology\\.md' '$PAYLOAD_MANIFEST'"
  assert "payload manifest does not add a redundant include for the guide (would double-count in plan/apply reconciliation)" \
    "! grep -qE '^include:.*release-loop-methodology\\.md' '$PAYLOAD_MANIFEST'"
else
  skip "payload manifest assertions (guide include/exclude)" "packaging/ is stripped on this tree (maintainer-only)"
fi

assert "initialize-project.md names the .brain/ scaffold step" \
  "grep -qi 'Scaffold .\\.brain/.' '$INIT_CMD'"
assert "initialize-project.md names the artifacts/ + dashboard step" \
  "grep -qi 'Build the First Backlog Dashboard' '$INIT_CMD'"
assert "initialize-project.md names the CI methodology offer step" \
  "grep -qi 'CI Methodology' '$INIT_CMD'"
assert "initialize-project.md step 4f no longer tells an adopted repo to SKIP ENTIRELY" \
  "! grep -qiE 'skip (this step )?entirely' '$INIT_CMD'"
assert "initialize-project.md still never removes an adopter's own .github/ content" \
  "grep -qiE 'never remove|never .* touch' '$INIT_CMD'"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
