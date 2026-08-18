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
  "printf '%s' \"$REAL_OUT\" | grep -q 'All plugin manifests valid'"
MANIFEST_COUNT=$(ls -d "$ROOT"/plugins/*/.claude-plugin/plugin.json 2>/dev/null | wc -l | tr -d ' ')
assert "checked count matches manifests on disk ($MANIFEST_COUNT)" \
  "printf '%s' \"$REAL_OUT\" | grep -q '($MANIFEST_COUNT checked)'"
assert "no bundled manifest declares eval (none has a genuine suite)" \
  "! grep -l '\"eval\"' $ROOT/plugins/*/.claude-plugin/plugin.json >/dev/null 2>&1"
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
  "! printf '%s' \"$NOEVAL_OUT\" | grep -qi 'eval'"
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
    "printf '%s' \"$out\" | grep -q '$want'"
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

# ── 8. Scope guard: metadata only, no engine ─────────────────────────────────
echo "8. Scope guard — metadata only, no judge/runner/scoring engine"
assert "validator never executes a declared eval path" \
  "! grep -nE '(subprocess|os\.system|os\.exec|popen|shutil\.which)' '$VALIDATOR' >/dev/null 2>&1"
assert "validator never checks an eval path for existence (deliberate)" \
  "! grep -n 'suite\[.path.\]' '$VALIDATOR' | grep -q 'exists'"
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
