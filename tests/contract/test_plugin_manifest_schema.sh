#!/usr/bin/env bash
# Contract Tests: plugin manifest schema + validator (backlog §3.6 / §3.4)
#
# Two halves:
#
#   1. The WRITTEN SPEC exists and matches the tree. A schema doc that drifts
#      from the manifests is worse than none, so this asserts the doc is present
#      and that its honest claims (three CI-enforced fields; `eval` optional;
#      no registry index) are still true.
#   2. The VALIDATOR behaves. Three proofs demanded of the optional `eval`
#      block: it passes on all real manifests, it REJECTS a malformed block,
#      and it ACCEPTS a manifest with no `eval` at all.
#   3. The INVENTORY blocks tell the truth (§8, LOOM-0012). `count` is gone and
#      rejected on sight; `list` is compared against the filesystem; a block
#      cannot be deleted to duck the check.
#
# Scope guard: the validator checks METADATA SHAPE ONLY. LogicLoom ships no eval
# judge, runner, or scoring engine. This suite asserts that too — if someone
# grows the validator into a runner, these assertions fail.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
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

VALIDATOR="$ROOT/.logic-loom/scripts/python/validate-plugin-manifests.py"
SCHEMA_DOC="$ROOT/plugins/MANIFEST-SCHEMA.md"
CONTRIBUTING="$ROOT/plugins/CONTRIBUTING.md"
WORKFLOW="$ROOT/.github/workflows/plugin-tests.yml"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a throwaway repo root: <fixture>/plugins/<plugin>/.claude-plugin/plugin.json
# $1 = fixture name, $2 = manifest JSON body (heredoc'd by the caller)
make_fixture() {
  local fixture="$1"
  mkdir -p "$TMP/$fixture/plugins/loom-fixture/.claude-plugin"
  cat > "$TMP/$fixture/plugins/loom-fixture/.claude-plugin/plugin.json"
}

# Sets globals OUT (validator output) and RC (exit status). NOT run in a
# command substitution — a subshell would strand RC. This is the §1 idiom from
# .docs/policies/shell-idiom-policy.md: declare, then capture status separately.
OUT=""; RC=0
run_validator() {  # $1 = repo root
  RC=0
  python3 "$VALIDATOR" --root "$1" > "$TMP/validator.out" 2>&1 || RC=$?
  OUT="$(cat "$TMP/validator.out")"
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Plugin Manifest Schema (§3.6 / §3.4)     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 0. Prerequisite ──────────────────────────────────────────────────────────
echo "0. Prerequisites"
assert "python3 is available" "command -v python3 >/dev/null 2>&1"
assert "validator script exists" "[ -f '$VALIDATOR' ]"
assert "validator is syntactically valid Python" \
  "python3 -m py_compile '$VALIDATOR' >/dev/null 2>&1"
echo ""

# ── 1. The written spec (§3.6) ───────────────────────────────────────────────
echo "1. Written schema spec exists and stays honest"
assert "MANIFEST-SCHEMA.md exists where a plugin author looks (plugins/)" \
  "[ -f '$SCHEMA_DOC' ]"
assert "spec names the three CI-enforced fields" \
  "grep -q 'name' '$SCHEMA_DOC' && grep -q 'version' '$SCHEMA_DOC' && grep -q 'dependencies' '$SCHEMA_DOC'"
assert "spec separates enforced from convention" \
  "grep -qi 'What is convention, not enforced' '$SCHEMA_DOC'"
assert "spec documents the absent plugin registry index" \
  "grep -qi 'absent plugin registry index' '$SCHEMA_DOC'"
assert "spec distinguishes the registry index from the dropped marketplace MCP" \
  "grep -qi 'marketplace MCP' '$SCHEMA_DOC'"
assert "CONTRIBUTING.md links the schema doc" \
  "grep -q 'MANIFEST-SCHEMA.md' '$CONTRIBUTING'"
assert "CONTRIBUTING.md states there is no registry index" \
  "grep -qi 'No plugin registry index' '$CONTRIBUTING'"
assert "no registry index file actually exists" \
  "[ ! -f '$ROOT/plugins/marketplace.json' ] && [ ! -f '$ROOT/plugins/registry.json' ]"
echo ""

# ── 2. CI wiring ─────────────────────────────────────────────────────────────
echo "2. CI runs the extracted validator"
assert "workflow invokes the validator script" \
  "grep -q 'validate-plugin-manifests.py' '$WORKFLOW'"
assert "workflow no longer inlines the old python heredoc" \
  "! grep -q \"python3 -c \\\"\" '$WORKFLOW'"
echo ""

# ── 3. Validator passes on all 8 real manifests ──────────────────────────────
echo "3. Accepts every manifest currently in tree"
run_validator "$ROOT"; REAL_RC=$RC; REAL_OUT="$OUT"
echo "     $REAL_OUT"
assert "exit 0 on the real tree" "[ $REAL_RC -eq 0 ]"
assert "reports all manifests valid" \
  "grep -q 'All plugin manifests valid' <<< \"$REAL_OUT\""

# Expected checked count = manifests on disk MINUS registry-listed (legacy,
# pending-migration) plugin dirs — the validator deliberately skips those
# (§ addition 5 in the validator's own docstring).
#
# The validator's success line has TWO shapes (validate-plugin-manifests.py:
# 308 vs 310): "(N checked)" when nothing was skipped, "(N checked, M legacy
# skipped)" when something was. A literal `grep -q '(N checked)'` matches the
# first shape but NOT the second — the ')' the pattern demands never follows
# "checked" once a suffix is present; a comma does. On THIS maintainer tree
# LEGACY_ON_DISK is always 0 so that never bites here, but it bites on any
# sanitized/adopted customer tree that still holds a registry-listed legacy
# plugin directory on disk — exactly the population this release's migration
# feature targets. expected_checked_line() below builds the shape-correct
# string; count_legacy_on_disk() computes LEGACY_ON_DISK for an arbitrary
# root (reused by §3b's dedicated customer-tree fixture further down).
#
# SECOND half of the same finding: what counts as "on disk" must be the
# validator's definition, not a looser one. validate() only ever accounts for
# a name whose `.claude-plugin/plugin.json` EXISTS (it `continue`s past a
# bare directory before the legacy check runs), so a registry-listed legacy
# plugin left on disk WITHOUT a manifest is neither checked nor skipped —
# invisible to the count. A test that counted bare directories (`-d`) would
# expect "(N-1 checked, 1 legacy skipped)" against a real "(N checked)" and
# fail falsely. That is not hypothetical: sdd-memory and sdd-orchestrator-hook
# shipped at v4.1.0 as directories with NO manifest (git cat-file -e
# v4.1.0:plugins/sdd-memory/.claude-plugin/plugin.json fails), so a customer
# tree from that era has exactly this shape. Count manifests, as the
# validator does. §3b plants a manifest-less legacy dir to hold this.
# Registry-listed (legacy, pending-migration) plugin names for a root, one per
# line — the validator's own skip set. Empty when the lib or registry is
# absent, so every sweep below degrades to "inspect everything", exactly what
# it did before the registry existed.
legacy_plugin_names() {  # $1 = root
  local root="$1"
  local lib="$root/.logic-loom/lib/release-migrations.sh"
  local reg="$root/.logic-loom/config/release-migrations.conf"
  if [ -f "$lib" ] && [ -f "$reg" ]; then
    # shellcheck source=/dev/null
    source "$lib"
    loom_deprecation_rows "$reg" 2>/dev/null | awk -F'\t' '$1 == "plugin" { print $2 }'
  fi
  return 0
}
count_legacy_on_disk() {  # $1 = root
  local root="$1" count=0 legacy_name
  for legacy_name in $(legacy_plugin_names "$root"); do
    [ -f "$root/plugins/$legacy_name/.claude-plugin/plugin.json" ] && count=$((count + 1))
  done
  echo "$count"
}
# The looser, WRONG accounting (bare directories), kept only so §3b can prove
# its fixture actually tells the two apart — never used for an expectation.
count_legacy_dirs_naive() {  # $1 = root
  local root="$1" count=0 legacy_name
  for legacy_name in $(legacy_plugin_names "$root"); do
    [ -d "$root/plugins/$legacy_name" ] && count=$((count + 1))
  done
  echo "$count"
}
# Every manifest the validator actually INSPECTS for a root: plugins/*/
# .claude-plugin/plugin.json minus the registry-listed legacy ones. A whole-
# tree `grep -l … plugins/*/.claude-plugin/plugin.json` sweep is NOT that set:
# it also reads the manifest of a customer's leftover legacy plugin, which the
# validator skips on purpose (§ addition 5) precisely because it carries an
# OLD shape — `git show v5.0.0:plugins/sdd-git/.claude-plugin/plugin.json`
# still declares `"count"` three times. A sweep that reads it fails a customer
# tree for a manifest the harness no longer ships and told them to migrate.
# One path per line; space-safe (no word-splitting of paths).
non_legacy_manifests() {  # $1 = root
  local root="$1" m name legacy
  legacy="$(legacy_plugin_names "$root")"
  for m in "$root"/plugins/*/.claude-plugin/plugin.json; do
    [ -f "$m" ] || continue
    name="${m%/.claude-plugin/plugin.json}"; name="${name##*/}"
    grep -qx "$name" <<< "$legacy" && continue
    printf '%s\n' "$m"
  done
  return 0
}
# Manifests among non_legacy_manifests that contain the literal key $2
# (e.g. '"count"'). Prints matching paths, one per line; empty = clean.
manifest_sweep_hits() {  # $1 = root, $2 = literal key incl. quotes
  local m
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    grep -qF -- "$2" "$m" 2>/dev/null && printf '%s\n' "$m"
  done <<< "$(non_legacy_manifests "$1")"
  return 0
}
expected_checked_line() {  # $1 = checked count, $2 = legacy-skipped count
  if [ "$2" -gt 0 ]; then
    echo "($1 checked, $2 legacy skipped)"
  else
    echo "($1 checked)"
  fi
}

MANIFESTS_ON_DISK=$(ls -d "$ROOT"/plugins/*/.claude-plugin/plugin.json 2>/dev/null | wc -l | tr -d ' ')
LEGACY_ON_DISK=$(count_legacy_on_disk "$ROOT")
MANIFEST_COUNT=$((MANIFESTS_ON_DISK - LEGACY_ON_DISK))
EXPECTED_LINE="$(expected_checked_line "$MANIFEST_COUNT" "$LEGACY_ON_DISK")"
assert "checked count matches manifests on disk minus registry-listed legacy ($MANIFEST_COUNT)" \
  "grep -qF \"\$EXPECTED_LINE\" <<< \"$REAL_OUT\""
# Legacy-aware sweep (non_legacy_manifests): a customer's leftover legacy
# manifest is the validator's blind spot by design, so it is this sweep's too.
EVAL_HITS="$(manifest_sweep_hits "$ROOT" '"eval"')"
[ -n "$EVAL_HITS" ] && printf '%s\n' "$EVAL_HITS" | sed 's/^/     eval declared in: /'
assert "no bundled (non-legacy) manifest declares eval (none has a genuine suite)" \
  "[ -z \"\$EVAL_HITS\" ]"
echo ""

# ── 3b. The checked-count assertion holds on a CUSTOMER tree ────────────────
#
# §3's own real-tree assertion can't exercise the buggy shape above because
# this maintainer repo has zero legacy plugins on disk. Build a fixture that
# actually has one (a registry-listed legacy plugin directory alongside two
# normal ones — the shape a sanitized/adopted customer tree has mid-migration)
# and run the SAME count-matching logic §3 uses. Proof this is a real,
# previously-failing check, not a tautology: with the pre-fix literal pattern
# `grep -q '($COUNT checked)'` (no shape awareness), this fixture's real
# validator output — "(2 checked, 1 legacy skipped)" — does NOT match, because
# no ')' follows "checked" once the suffix is present. That is the false CI
# failure finding #1 reports; expected_checked_line() (§3, above) closes it.
echo "3b. Checked-count assertion holds on a customer tree with a legacy plugin on disk"
CUSTFIX="$TMP/customer-tree-legacy"
mkdir -p "$CUSTFIX/.logic-loom/config" "$CUSTFIX/.logic-loom/lib" \
         "$CUSTFIX/plugins/sdd-legacy-count/.claude-plugin" \
         "$CUSTFIX/plugins/sdd-legacy-nomanifest/scripts" \
         "$CUSTFIX/plugins/loom-normal-a/.claude-plugin" \
         "$CUSTFIX/plugins/loom-normal-b/.claude-plugin"
cp "$ROOT/.logic-loom/lib/release-migrations.sh" "$CUSTFIX/.logic-loom/lib/release-migrations.sh"
{
  echo "plugin | sdd-legacy-count | removed | none | REMOVE | v1.0.0 | v2.0.0 | synthetic legacy row"
  echo "plugin | sdd-legacy-nomanifest | removed | none | REMOVE | v1.0.0 | v2.0.0 | synthetic legacy row, dir with NO manifest (the v4.1.0 sdd-memory shape)"
} > "$CUSTFIX/.logic-loom/config/release-migrations.conf"
# The legacy manifest carries the OLD inventory shape — the one a customer's
# leftover plugin really has (`git show v5.0.0:plugins/sdd-git/.claude-plugin/
# plugin.json` declares "count" three times). The validator must skip it
# (exit 0 below), and §8b holds the test's own whole-tree sweeps to the same
# skip — a sweep that read this file would fail the customer for it.
cat > "$CUSTFIX/plugins/sdd-legacy-count/.claude-plugin/plugin.json" <<'JSON'
{ "name": "sdd-legacy-count", "version": "1.0.0", "dependencies": [],
  "agents": { "count": 0, "list": [] },
  "commands": { "count": 2, "list": ["git-push", "finalize"] } }
JSON
# A second registry-listed legacy plugin that is on disk but has NO
# .claude-plugin/plugin.json — exactly how sdd-memory / sdd-orchestrator-hook
# shipped at v4.1.0. The validator neither checks nor skips it (no manifest to
# open), so it must not be counted on either side of the subtraction.
echo 'echo legacy' > "$CUSTFIX/plugins/sdd-legacy-nomanifest/scripts/x.sh"
cat > "$CUSTFIX/plugins/loom-normal-a/.claude-plugin/plugin.json" <<'JSON'
{ "name": "loom-normal-a", "version": "1.0.0", "dependencies": [] }
JSON
cat > "$CUSTFIX/plugins/loom-normal-b/.claude-plugin/plugin.json" <<'JSON'
{ "name": "loom-normal-b", "version": "1.0.0", "dependencies": [] }
JSON
run_validator "$CUSTFIX"; CUST_RC=$RC; CUST_OUT="$OUT"
echo "     [customer-tree-legacy] rc=$CUST_RC :: $CUST_OUT"
assert "exit 0 on a customer tree with a legacy plugin present" "[ $CUST_RC -eq 0 ]"

CUST_MANIFESTS=$(ls -d "$CUSTFIX"/plugins/*/.claude-plugin/plugin.json 2>/dev/null | wc -l | tr -d ' ')
CUST_LEGACY=$(count_legacy_on_disk "$CUSTFIX")
CUST_LEGACY_NAIVE=$(count_legacy_dirs_naive "$CUSTFIX")
CUST_COUNT=$((CUST_MANIFESTS - CUST_LEGACY))
assert "the customer-tree fixture actually has a legacy plugin on disk (LEGACY_ON_DISK=1)" \
  "[ $CUST_LEGACY -eq 1 ]"
# The fixture genuinely exercises the manifest-less shape: counting bare
# directories would see TWO legacy plugins, the validator only ever sees one.
assert "…and a second, manifest-less legacy dir is present (naive dir count = 2) yet NOT counted (validator-consistent count = 1)" \
  "[ $CUST_LEGACY_NAIVE -eq 2 ] && [ $CUST_LEGACY -eq 1 ]"
assert "the validator itself reports exactly 1 legacy skipped (it cannot skip a manifest it cannot open)" \
  "grep -qF ', 1 legacy skipped)' <<< \"$CUST_OUT\" && ! grep -qF 'sdd-legacy-nomanifest' <<< \"$CUST_OUT\""
CUST_EXPECTED="$(expected_checked_line "$CUST_COUNT" "$CUST_LEGACY")"
CUST_EXPECTED_NAIVE="$(expected_checked_line "$((CUST_MANIFESTS - CUST_LEGACY_NAIVE))" "$CUST_LEGACY_NAIVE")"
assert "the bare-directory accounting would have falsely failed here (expects '$CUST_EXPECTED_NAIVE', validator prints '$CUST_EXPECTED')" \
  "! grep -qF \"\$CUST_EXPECTED_NAIVE\" <<< \"$CUST_OUT\""
# Sanity: the naive pre-fix pattern (no shape awareness) genuinely fails here —
# proves this fixture exercises the bug, not a no-op.
assert "pre-fix literal pattern would have falsely failed on this customer tree" \
  "! grep -q '($CUST_COUNT checked)' <<< \"$CUST_OUT\""
assert "checked count matches manifests on disk minus registry-listed legacy on a customer tree" \
  "grep -qF \"\$CUST_EXPECTED\" <<< \"$CUST_OUT\""
echo ""

# ── 4. eval ABSENT is accepted ───────────────────────────────────────────────
echo "4. Accepts a manifest with NO eval block"
make_fixture no-eval <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": ["loom-governance"] }
JSON
run_validator "$TMP/no-eval"; NOEVAL_RC=$RC; NOEVAL_OUT="$OUT"
echo "     $NOEVAL_OUT"
assert "exit 0 with eval absent" "[ $NOEVAL_RC -eq 0 ]"
assert "says nothing about eval when absent" \
  "! grep -qi 'eval' <<< \"$NOEVAL_OUT\""
echo ""

# ── 5. eval PRESENT and well-formed is accepted ──────────────────────────────
echo "5. Accepts a well-formed eval block"
make_fixture good-eval <<'JSON'
{
  "name": "loom-fixture",
  "version": "1.0.0",
  "dependencies": ["loom-governance"],
  "eval": {
    "suites": [
      { "id": "a", "path": "tests/eval/a.jsonl" },
      { "id": "b", "path": "tests/eval/b.jsonl",
        "description": "second", "metric": "accuracy", "threshold": 0.9 }
    ]
  }
}
JSON
run_validator "$TMP/good-eval"; GOOD_RC=$RC; GOOD_OUT="$OUT"
echo "     $GOOD_OUT"
assert "exit 0 on a well-formed eval block" "[ $GOOD_RC -eq 0 ]"
echo ""

# ── 6. Malformed eval blocks are REJECTED ────────────────────────────────────
echo "6. Rejects malformed eval blocks"

reject_case() {  # $1 = fixture name, $2 = description, $3 = expected substring
  local fixture="$1" desc="$2" want="$3" rc out
  run_validator "$TMP/$fixture"; rc=$RC; out="$OUT"
  echo "     [$fixture] rc=$rc :: $out"
  assert "REJECT: $desc (exit 1)" "[ $rc -eq 1 ]"
  assert "REJECT: $desc (message names the defect)" \
    "grep -q '$want' <<< \"$out\""
}

make_fixture eval-not-object <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [], "eval": "yes" }
JSON
reject_case eval-not-object "eval is a string, not an object" "must be an object"

make_fixture eval-no-suites <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [], "eval": {} }
JSON
reject_case eval-no-suites "eval missing suites" "eval missing required key"

make_fixture eval-empty-suites <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [] } }
JSON
reject_case eval-empty-suites "suites is empty" "must not be empty"

make_fixture eval-suite-missing-path <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a" } ] } }
JSON
reject_case eval-suite-missing-path "suite missing path" "suites.0. missing required key"

make_fixture eval-suite-empty-id <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "  ", "path": "p" } ] } }
JSON
reject_case eval-suite-empty-id "suite id is blank" "non-empty string"

make_fixture eval-dup-id <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a", "path": "p" }, { "id": "a", "path": "q" } ] } }
JSON
reject_case eval-dup-id "duplicate suite id" "duplicates an earlier suite id"

make_fixture eval-bad-threshold <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a", "path": "p", "threshold": 2 } ] } }
JSON
reject_case eval-bad-threshold "threshold out of 0-1 range" "between 0 and 1"

make_fixture eval-threshold-bool <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a", "path": "p", "threshold": true } ] } }
JSON
reject_case eval-threshold-bool "threshold is a boolean" "must be a number"

make_fixture eval-unknown-key <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a", "path": "p", "thresold": 0.9 } ] } }
JSON
reject_case eval-unknown-key "typo'd suite key is not silently ignored" "unknown key"

make_fixture eval-unknown-top <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "eval": { "suites": [ { "id": "a", "path": "p" } ], "runner": "./run.sh" } }
JSON
reject_case eval-unknown-top "a 'runner' key is rejected, not honoured" "unknown key"
echo ""

# ── 7. The pre-existing contract still holds ─────────────────────────────────
echo "7. Original three-field contract is unchanged"
make_fixture missing-version <<'JSON'
{ "name": "loom-fixture", "dependencies": [] }
JSON
reject_case missing-version "missing version field" "missing version"

mkdir -p "$TMP/bad-json/plugins/loom-fixture/.claude-plugin"
printf '{ "name": "x", ' > "$TMP/bad-json/plugins/loom-fixture/.claude-plugin/plugin.json"
reject_case bad-json "unparseable JSON" "invalid JSON"

mkdir -p "$TMP/not-a-plugin/plugins/some-dir"
run_validator "$TMP/not-a-plugin"; NOPLUG_RC=$RC
assert "a plugins/ subdir with no manifest is skipped, not an error" \
  "[ $NOPLUG_RC -eq 0 ]"
echo ""

# ── 8. Inventory blocks must match disk (LOOM-0012) ──────────────────────────
#
# The agents/skills/commands blocks used to be decorative: `count` was verified
# against neither `list` nor disk, and loom-orchestrator drifted to 8/10 declared
# vs 9/11 actual. `count` is gone (a number nothing derives is a number that
# drifts) and `list` is now checked against the filesystem. These assertions are
# what stops it drifting back.
echo "8. Inventory blocks (agents/skills/commands) are verified against disk"

COUNT_HITS="$(manifest_sweep_hits "$ROOT" '"count"')"
[ -n "$COUNT_HITS" ] && printf '%s\n' "$COUNT_HITS" | sed 's/^/     count field in: /'
assert "no shipped (non-legacy) manifest in tree still declares a count field" \
  "[ -z \"\$COUNT_HITS\" ]"
assert "the drift that started this is declared: loom-orchestrator ships graph" \
  "grep -q '\"graph\"' '$ROOT/plugins/loom-orchestrator/.claude-plugin/plugin.json'"
assert "…and project-graph" \
  "grep -q '\"project-graph\"' '$ROOT/plugins/loom-orchestrator/.claude-plugin/plugin.json'"

# ── 8a. The count-field sweep is legacy-aware on a CUSTOMER tree ────────────
#
# Same customer-tree fixture as §3b: its registry-listed legacy manifest
# carries the v5.0.0 sdd-git shape ("count" declared). The validator skips it
# (§3b: exit 0; §8b below holds that skip for the validator itself). The
# sweep above must skip it too — the pre-fix bare-glob sweep
# `grep -l '"count"' plugins/*/.claude-plugin/plugin.json` read it and failed
# the customer for a manifest the harness no longer ships. Proof this is a
# real, previously-failing check: the bare-glob form is asserted to hit.
echo ""
echo "8a. Count-field sweep ignores a registry-listed legacy manifest on a customer tree"
assert "pre-fix bare-glob sweep DOES read the legacy manifest's count field (bug reproduced)" \
  "grep -l '\"count\"' \"\$CUSTFIX\"/plugins/*/.claude-plugin/plugin.json >/dev/null 2>&1"
CUST_COUNT_HITS="$(manifest_sweep_hits "$CUSTFIX" '"count"')"
assert "legacy-aware sweep reports NO count field on the customer tree (legacy manifest skipped, as the validator does)" \
  "[ -z \"\$CUST_COUNT_HITS\" ]"
# …and it is a skip of the LEGACY manifest only, not a blanket blind spot: a
# count field in a shipped (non-legacy) manifest on the same tree is still
# caught. Planted AFTER §3b's validator run, so that run's exit-0 assertion
# stays a statement about the legacy skip alone.
cat > "$CUSTFIX/plugins/loom-normal-b/.claude-plugin/plugin.json" <<'JSON'
{ "name": "loom-normal-b", "version": "1.0.0", "dependencies": [],
  "agents": { "count": 1, "list": [] } }
JSON
CUST_COUNT_HITS2="$(manifest_sweep_hits "$CUSTFIX" '"count"')"
assert "…while a count field in a NON-legacy manifest on the same customer tree IS still caught" \
  "grep -q 'loom-normal-b' <<< \"\$CUST_COUNT_HITS2\" && ! grep -q 'sdd-legacy-count' <<< \"\$CUST_COUNT_HITS2\""

# Fixture with a real commands/ directory holding two commands.
inv_fixture() {  # $1 = fixture name; manifest body on stdin
  local fixture="$1"
  mkdir -p "$TMP/$fixture/plugins/loom-fixture/.claude-plugin"
  mkdir -p "$TMP/$fixture/plugins/loom-fixture/commands"
  : > "$TMP/$fixture/plugins/loom-fixture/commands/alpha.md"
  : > "$TMP/$fixture/plugins/loom-fixture/commands/beta.md"
  cat > "$TMP/$fixture/plugins/loom-fixture/.claude-plugin/plugin.json"
}

inv_fixture inv-good <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "list": ["alpha", "beta"] } }
JSON
run_validator "$TMP/inv-good"
echo "     [inv-good] rc=$RC :: $OUT"
assert "ACCEPT: list that matches disk exactly" "[ $RC -eq 0 ]"

inv_fixture inv-count <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "count": 2, "list": ["alpha", "beta"] } }
JSON
reject_case inv-count "a count field is rejected, not ignored" "count., which was removed"

inv_fixture inv-wrong-count <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "count": 8, "list": ["alpha", "beta"] } }
JSON
reject_case inv-wrong-count "a deliberately WRONG count is rejected too" "count., which was removed"

inv_fixture inv-undeclared <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "list": ["alpha"] } }
JSON
reject_case inv-undeclared "a command on disk but not in list" "on disk but undeclared: beta"

inv_fixture inv-phantom <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "list": ["alpha", "beta", "gamma"] } }
JSON
reject_case inv-phantom "a command in list but not on disk" "declared but absent from disk: gamma"

inv_fixture inv-omitted <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [] }
JSON
reject_case inv-omitted "deleting the block to silence the check" "block is missing but commands/ holds"

inv_fixture inv-not-list <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [],
  "commands": { "list": "alpha" } }
JSON
reject_case inv-not-list "list is a string, not an array" "must be an array of strings"

# Omitting a block when the directory does not exist stays legal — loom-governance
# ships no commands/ and declares no commands block.
make_fixture inv-legal-omission <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [] }
JSON
run_validator "$TMP/inv-legal-omission"
echo "     [inv-legal-omission] rc=$RC :: $OUT"
assert "ACCEPT: block omitted when the directory does not exist" "[ $RC -eq 0 ]"
assert "loom-governance really does omit commands (the case above is real)" \
  "! grep -q '\"commands\"' '$ROOT/plugins/loom-governance/.claude-plugin/plugin.json'"

assert "schema doc records that lists are verified against disk" \
  "grep -qi 'verified against disk' '$SCHEMA_DOC'"
assert "schema doc declares the count field gone" \
  "grep -q 'There is no .count. field' '$SCHEMA_DOC'"
assert "schema doc worked example declares no count" \
  "! grep -q '\"count\": 0' '$SCHEMA_DOC'"
echo ""

# ── 8b. Registry-listed legacy plugins are SKIPPED, not validated ────────────
echo "8b. A registry-listed legacy plugin's manifest is skipped, not rejected"
LEGACY_FIX="$TMP/legacy-fixture"
mkdir -p "$LEGACY_FIX/.logic-loom/config" "$LEGACY_FIX/.logic-loom/lib" \
         "$LEGACY_FIX/plugins/sdd-legacy/.claude-plugin" \
         "$LEGACY_FIX/plugins/loom-fixture/.claude-plugin"
cp "$ROOT/.logic-loom/lib/release-migrations.sh" "$LEGACY_FIX/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-legacy | removed | none | REMOVE | v1.0.0 | v2.0.0 | synthetic legacy row" \
  > "$LEGACY_FIX/.logic-loom/config/release-migrations.conf"
cat > "$LEGACY_FIX/plugins/sdd-legacy/.claude-plugin/plugin.json" <<'JSON'
{ "name": "sdd-legacy", "version": "1.0.0", "dependencies": [],
  "agents": { "count": 1, "list": [] } }
JSON
cat > "$LEGACY_FIX/plugins/loom-fixture/.claude-plugin/plugin.json" <<'JSON'
{ "name": "loom-fixture", "version": "1.0.0", "dependencies": [] }
JSON
run_validator "$LEGACY_FIX"
echo "     [legacy-fixture] rc=$RC :: $OUT"
assert "a legacy manifest with a pre-v6.1 'count' key does NOT fail validation" "[ $RC -eq 0 ]"
assert "the legacy plugin is reported SKIPPED, not validated" \
  "grep -q 'SKIPPED legacy (pending migration): plugins/sdd-legacy' <<< \"$OUT\""
assert "the non-legacy plugin is still checked (1 checked, 1 legacy skipped)" \
  "grep -q '(1 checked, 1 legacy skipped)' <<< \"$OUT\""
echo ""

# ── 9. Scope guard: metadata only, no engine ─────────────────────────────────
echo "9. Scope guard — metadata only, no judge/runner/scoring engine"
assert "validator never executes a declared eval path" \
  "! grep -nE '(subprocess|os\.system|os\.exec|popen|shutil\.which)' '$VALIDATOR' >/dev/null 2>&1"
assert "validator never checks an eval path for existence (deliberate)" \
  "! grep -q 'exists' <<< \"\$(grep -n 'suite\[.path.\]' '$VALIDATOR')\""
assert "validator declares the no-engine scope in its header" \
  "grep -qi 'no eval judge' '$VALIDATOR'"
assert "schema doc states no judge/runner ships" \
  "grep -qi 'no judge, no runner' '$SCHEMA_DOC'"
assert "schema doc marks the eval example as illustrative" \
  "grep -qi 'illustrative' '$SCHEMA_DOC'"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
