#!/usr/bin/env bash
# Contract Tests: shipped skill commands must be runnable, not just plausible
#
# Two shipped defects this guards against:
#
#   1. /cross-check's Mode B codex invocation (cross-check/SKILL.md) never
#      passed a model flag, even though the same section documents a
#      resolution order (CROSS_CHECK_OPENAI_MODEL env override, else the
#      models.conf documented default) for exactly this call. The shipped
#      command silently ran whatever `codex exec` defaults to.
#   2. project-graph's SKILL.md and its /graph command named an npm package,
#      `@optave/ops-codegraph-tool`, that 404s on the registry. The published
#      package is `@optave/codegraph`.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.

set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  PASS: $desc"; PASS=$((PASS + 1))
  else echo "  FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

CROSS_CHECK_SKILL="plugins/loom-orchestrator/skills/cross-check/SKILL.md"
GRAPH_SKILL="plugins/loom-orchestrator/skills/project-graph/SKILL.md"
GRAPH_CMD="plugins/loom-orchestrator/commands/graph.md"

echo "== Defect 1: /cross-check Mode B codex invocation carries a model flag =="

if [ -f "$CROSS_CHECK_SKILL" ]; then
  # Pull every fenced ```bash ... ``` block whose content shells `codex exec`,
  # and require every such line to carry -m/--model.
  CODEX_LINES=$(grep -n "codex exec" "$CROSS_CHECK_SKILL" | grep -v "^\s*#" || true)
  assert "SKILL.md still documents a codex exec Mode B invocation" \
    '[ -n "$CODEX_LINES" ]'

  # Every actual invocation line (not prose mentioning "codex exec" in a
  # sentence) must carry a model flag. We identify invocation lines as those
  # starting the shell command (i.e. containing --sandbox read-only).
  INVOCATION_LINES=$(grep -n "codex exec --sandbox read-only" "$CROSS_CHECK_SKILL" || true)
  assert "found at least one real codex exec --sandbox read-only invocation line" \
    '[ -n "$INVOCATION_LINES" ]'

  # Grab the shell fence block(s) containing that invocation and confirm a
  # -m / --model flag appears within the same fenced command (it may be on a
  # continuation line via backslash, so scan the whole fenced bash block as a
  # single unit rather than line-by-line). Comment lines are dropped first so
  # a `#` explanation mentioning the flag cannot satisfy the check.
  MISSING_MODEL=$(awk '
    /^```bash/ { inblock=1; buf=""; next }
    /^```/ {
      if (inblock && buf ~ /codex exec --sandbox read-only/ && buf !~ /(-m |--model)/) missing=1
      inblock=0; buf=""; next
    }
    inblock && !/^[[:space:]]*#/ { buf = buf $0 "\n" }
    END { print (missing ? 1 : 0) }
  ' "$CROSS_CHECK_SKILL")

  assert "every codex exec --sandbox read-only fenced block carries -m/--model" \
    '[ "$MISSING_MODEL" -eq 0 ]'

  # The env override must be wired into the invocation itself, not merely
  # mentioned in prose elsewhere in the skill (it was documented before the
  # fix; only the command was missing it). Same comment-stripping as above.
  BLOCK_LACKS_ENV=$(awk '
    /^```bash/ { inblock=1; buf=""; next }
    /^```/ {
      if (inblock && buf ~ /codex exec --sandbox read-only/ && buf !~ /CROSS_CHECK_OPENAI_MODEL/) lacks=1
      inblock=0; buf=""; next
    }
    inblock && !/^[[:space:]]*#/ { buf = buf $0 "\n" }
    END { print (lacks ? 1 : 0) }
  ' "$CROSS_CHECK_SKILL")

  assert "the codex invocation's -m value reads CROSS_CHECK_OPENAI_MODEL (env override honored)" \
    '[ "$BLOCK_LACKS_ENV" -eq 0 ]'

  # Drift guard: the shell fallback literal in the invocation must equal the
  # documented OpenAI default in models.conf ("Advisory cross-provider models").
  # models.conf is documentation-only (nothing parses it at runtime), so the
  # literal restated in the command is the only thing that actually runs — if
  # the two diverge, the skill documents one model and executes another.
  MODELS_CONF=".logic-loom/config/models.conf"
  CONF_DEFAULT=$(sed -n 's/^#[[:space:]]*OpenAI[[:space:]]*->[[:space:]]*\([^[:space:]]*\).*/\1/p' "$MODELS_CONF" | head -1)
  SKILL_DEFAULT=$(sed -n 's/.*\${CROSS_CHECK_OPENAI_MODEL:-\([^}]*\)}.*/\1/p' "$CROSS_CHECK_SKILL" | head -1)
  assert "models.conf documents an OpenAI advisory default (parsed: '$CONF_DEFAULT')" \
    '[ -n "$CONF_DEFAULT" ]'
  assert "codex invocation fallback ('$SKILL_DEFAULT') matches models.conf OpenAI default ('$CONF_DEFAULT')" \
    '[ -n "$SKILL_DEFAULT" ] && [ "$SKILL_DEFAULT" = "$CONF_DEFAULT" ]'
else
  assert "cross-check SKILL.md exists" 'false'
fi

echo "== Defect 2: no live file names the 404ing npm package =="

BAD_PKG_HITS=$(grep -rl "ops-codegraph-tool" \
  --include="*.md" --include="*.sh" \
  plugins/loom-orchestrator/skills/project-graph \
  plugins/loom-orchestrator/commands/graph.md \
  2>/dev/null || true)
assert "no ops-codegraph-tool references remain in project-graph skill/command (owned scope)" \
  '[ -z "$BAD_PKG_HITS" ]'

assert "project-graph SKILL.md references the real package @optave/codegraph" \
  'grep -q "@optave/codegraph" "$GRAPH_SKILL"'
assert "/graph command references the real package @optave/codegraph" \
  'grep -q "@optave/codegraph" "$GRAPH_CMD"'

# Wider guard: scan .docs/ for the same dead npm-scoped spelling too. A dated
# historical record (features/*/exploration/) is allowed to still say the old
# name, and worktrees are excluded outright — everything else in .docs/ must
# not name the 404ing package.
DOCS_BAD_PKG_RAW=$(grep -rl "ops-codegraph-tool" \
  --include="*.md" --include="*.sh" \
  --exclude-dir=".claude" \
  .docs \
  2>/dev/null || true)
DOCS_BAD_PKG_HITS=""
if [ -n "$DOCS_BAD_PKG_RAW" ]; then
  DOCS_BAD_PKG_HITS=$(printf '%s\n' "$DOCS_BAD_PKG_RAW" | grep -v '/exploration/' || true)
fi
assert "no ops-codegraph-tool references remain under .docs/ (excluding features/*/exploration/ and .claude/worktrees/)" \
  '[ -z "$DOCS_BAD_PKG_HITS" ]'

echo ""
echo "═══ Results: $PASS/$TOTAL passed, $FAIL failed ═══"
[ "$FAIL" -eq 0 ]
