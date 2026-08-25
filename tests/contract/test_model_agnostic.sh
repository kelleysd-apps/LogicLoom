#!/usr/bin/env bash
# Contract Tests: model agnosticism (Principle XIV — AI Model Selection)
#
# Durable guard for the harness's model-tier abstraction. Agents/commands/skills
# must select a MODEL TIER (opus/sonnet/haiku/inherit) via frontmatter — never a
# pinned Claude version string (claude-opus-4-8, claude-sonnet-5, ...). Pinning a
# concrete id in a role's frontmatter couples that role to one flagship snapshot
# and defeats the config-driven role→tier convention (models.conf).
#
#   1. NO PINNED MODEL IN FRONTMATTER — every `model:` field in the YAML
#      frontmatter of plugins/**/agents|commands and skills SKILL.md and
#      .claude/agents/*.md must be a tier keyword (opus|sonnet|haiku|inherit),
#      never a `claude-*` pinned id. HARD INVARIANT.
#   2. SCAFFOLDER DEFAULT IS A TIER — the create-agent skill (the "pin
#      propagator": it tells authors what to put in `model:`) must NOT default to
#      a pinned id (`model (default: claude-...`). Regression guard. HARD.
#   3. MODEL-BUMP TOUCH-LIST (informational) — print every concrete Claude id
#      found OUTSIDE .logic-loom/config/models.conf so a flagship-bumper has the
#      list. Docs legitimately name the flagship, so this NEVER fails.
#
# grep-based, no jq dependency; tolerant of missing dirs. Meant for CI + local.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Resolve the repo root so the test runs from anywhere: prefer git, else walk up
# from this script (tests/contract/ → repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# Operations-log isolation: the scripts this suite drives source common.sh /
# logging.sh, which otherwise append to the shared
# .logic-loom/logs/operations/ file. LOOM_LOG_DIR redirects that (same idiom as
# LOOM_CHECKPOINT_DIR in .logic-loom/tests/test-git-safety.sh), exported so
# subprocesses inherit it.
LOOM_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-logs.XXXXXX")"
export LOOM_LOG_DIR
trap 'rm -rf "$LOOM_LOG_DIR"' EXIT

# Tier keywords that a `model:` field is allowed to hold.
TIER_RE='^(opus|sonnet|haiku|inherit)$'
# A concrete pinned Claude id (what we forbid in frontmatter / scaffolder default).
PINNED_RE='claude-(opus|sonnet|haiku)[a-z0-9-]*'

# Extract the `model:` value from a file's leading YAML frontmatter (first '---'
# fenced block only). Strips surrounding quotes/whitespace. Emits nothing if the
# file has no frontmatter or no model: field.
frontmatter_model() {
  awk '
    NR==1 && $0!="---" { exit }            # no frontmatter at all
    NR==1 { infm=1; next }
    infm && $0=="---" { exit }              # end of frontmatter block
    infm && /^[[:space:]]*model[[:space:]]*:/ {
      sub(/^[[:space:]]*model[[:space:]]*:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"'][[:space:]]*$/, "")   # strip wrapping quotes
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "$1"
}

# Gather the target files (agents + commands + skills across plugins, plus
# .claude/agents). Tolerate any missing dir; NUL-delimited for odd paths.
collect_targets() {
  { find plugins -type f \( -path '*/agents/*.md' -o -path '*/commands/*.md' \) -print0 2>/dev/null
    find plugins -type f -path '*/skills/*' -name 'SKILL.md'                    -print0 2>/dev/null
    find .claude/agents -maxdepth 1 -type f -name '*.md'                        -print0 2>/dev/null
  } || true
}

echo "═══ Model Agnosticism (Principle XIV) ═══"
echo ""

# ── 1. NO PINNED MODEL IN FRONTMATTER ────────────────────────────────────────
echo "1. No agent/command/skill frontmatter pins a Claude version string"
SCANNED=0
BAD_FRONTMATTER=""
while IFS= read -r -d '' f; do
  val="$(frontmatter_model "$f" || true)"
  [ -z "$val" ] && continue                 # no model: field → nothing to check
  SCANNED=$((SCANNED + 1))
  if grep -qiE "$TIER_RE" <<< "$val"; then
    :                                        # a valid tier keyword
  else
    BAD_FRONTMATTER="${BAD_FRONTMATTER}${f} => model: ${val}"$'\n'
  fi
done < <(collect_targets)

if [ -n "$BAD_FRONTMATTER" ]; then
  echo "     Offending frontmatter model: fields (must be opus|sonnet|haiku|inherit):"
  printf '%s' "$BAD_FRONTMATTER" | sed 's/^/       - /'
fi
echo "     (scanned $SCANNED frontmatter model: fields)"
assert "every frontmatter model: is a tier keyword (no claude-* pin)" \
  "[ -z \"\$BAD_FRONTMATTER\" ]"

# ── 2. SCAFFOLDER DEFAULT IS A TIER, NOT A PIN ───────────────────────────────
echo ""
echo "2. create-agent scaffolder does not default model: to a pinned Claude id"
CREATE_AGENT_SKILL="plugins/loom-creation/skills/create-agent/SKILL.md"
if [ -f "$CREATE_AGENT_SKILL" ]; then
  # Forbid the pin-propagating phrasing: 'model (default: claude-...'.
  set +e
  grep -InE "model[^A-Za-z0-9]*\(default:[[:space:]]*${PINNED_RE}" "$CREATE_AGENT_SKILL"
  PROPAGATOR_HITS=$?
  set -e
  assert "create-agent SKILL.md does not instruct 'model (default: claude-...)'" \
    "[ \$PROPAGATOR_HITS -ne 0 ]"
else
  assert "create-agent SKILL.md present to check (skipped if absent)" "true"
fi

# ── 3. MODEL-BUMP TOUCH-LIST (informational; never fails) ────────────────────
echo ""
echo "3. Model-bump touch-list — concrete Claude ids OUTSIDE models.conf (info)"
MODELS_CONF=".logic-loom/config/models.conf"
set +e
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TOUCH_LIST="$(git grep -InoE "$PINNED_RE" -- ":!${MODELS_CONF}" 2>/dev/null)"
else
  TOUCH_LIST="$(grep -RInoE "$PINNED_RE" . \
      --exclude-dir=.git --exclude-dir=node_modules \
      2>/dev/null | grep -v "$MODELS_CONF")"
fi
set -e
if [ -n "$TOUCH_LIST" ]; then
  echo "     These files name a concrete flagship id (legitimate in docs; bump here on re-base):"
  printf '%s\n' "$TOUCH_LIST" | sed 's/^/       /'
else
  echo "     (none found outside $MODELS_CONF)"
fi
assert "touch-list printed for the model-bumper (informational, always passes)" "true"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
