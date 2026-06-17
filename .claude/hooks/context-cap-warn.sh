#!/usr/bin/env bash
# UserPromptSubmit Hook: 800K-of-1M context cap warning
# Pattern: Cognition/Devin "context anxiety" research, scaled to 1M default
#
# When context usage exceeds 80% of the 1M window, inject a strong reset
# reminder + handoff-artifact prompt. This counters the LLM's tendency to
# prematurely wrap up work as context fills.
#
# Heuristic: Claude Code may pass token usage via env or stdin JSON. We
# try multiple sources in order of reliability:
#   1. CLAUDE_CONTEXT_TOKENS env var (if harness exposes it)
#   2. stdin JSON field .context.tokens / .tokens.total / .usage.input_tokens
#   3. Heuristic from session transcript char count (~4 chars/token)
#
# When no signal is available, no-op (do not fabricate warnings).
#
# Input:  Claude Code UserPromptSubmit JSON via stdin
# Output: JSON {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
#         (additionalContext MUST be nested under hookSpecificOutput or the harness drops it)

set -euo pipefail

THRESHOLD_TOKENS=${LOOM_CONTEXT_CAP_TOKENS:-800000}
WINDOW_TOKENS=${LOOM_CONTEXT_WINDOW:-1000000}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$REPO_ROOT/.docs/governance/audit"
WARN_MARKER="$STATE_DIR/.context-cap-warned-${CLAUDE_SESSION_ID:-default}"

emit_noop() {
    printf '{"hookEventName":"UserPromptSubmit"}\n'
    exit 0
}

# Capture stdin once
input=""
if [ ! -t 0 ]; then
    input=$(cat 2>/dev/null || true)
fi

# Try to extract token count from various known shapes
tokens=""

# 1. Explicit env override
if [ -n "${CLAUDE_CONTEXT_TOKENS:-}" ]; then
    tokens="$CLAUDE_CONTEXT_TOKENS"
fi

# 2. JSON field probing (only if we have jq or node)
if [ -z "$tokens" ] && [ -n "$input" ]; then
    if command -v jq >/dev/null 2>&1; then
        for path in '.context.tokens' '.tokens.total' '.usage.input_tokens' '.usage.total_tokens' '.contextTokens'; do
            val=$(printf '%s' "$input" | jq -r "$path // empty" 2>/dev/null || true)
            if [ -n "$val" ] && [ "$val" != "null" ]; then
                tokens="$val"
                break
            fi
        done
    fi
fi

# 3. Heuristic: char count of input as a coarse proxy (only if explicitly opted in)
if [ -z "$tokens" ] && [ "${LOOM_CONTEXT_CAP_HEURISTIC:-0}" = "1" ] && [ -n "$input" ]; then
    chars=$(printf '%s' "$input" | wc -c | tr -d ' ')
    # ~4 chars/token rule of thumb
    tokens=$((chars / 4))
fi

# Validate tokens is a positive integer
if ! [[ "$tokens" =~ ^[0-9]+$ ]] || [ "$tokens" -le 0 ]; then
    emit_noop
fi

# Below threshold — clear any stale warn marker and exit quietly
if [ "$tokens" -lt "$THRESHOLD_TOKENS" ]; then
    rm -f "$WARN_MARKER" 2>/dev/null || true
    emit_noop
fi

# Suppress repeat warnings within the same session (warn once per crossing)
if [ -f "$WARN_MARKER" ]; then
    emit_noop
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
touch "$WARN_MARKER" 2>/dev/null || true

pct=$((tokens * 100 / WINDOW_TOKENS))

# ── Dependency-preserving handoff (humanlayer ace-fca pattern; Hermes head/tail
# protection). Capture the active plan-as-DAG structure from state files the
# harness already maintains, so a post-reset agent retains "what blocks what /
# what I own" — edges a naive context summary would flatten. Best-effort and
# errexit-safe (every probe guarded); never blocks.
DAG_STATE=""
_marker="$REPO_ROOT/.loom-active-feature"
if [ -f "$_marker" ]; then
    _feat=$(sed -n 's/^feature:[[:space:]]*//p' "$_marker" 2>/dev/null | head -1 || true)
    _task=$(sed -n 's/^task:[[:space:]]*//p' "$_marker" 2>/dev/null | head -1 || true)
    _owns=$(awk '/^owns:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f&&/^[[:space:]]*-/{sub(/^[[:space:]]*-[[:space:]]*/,"");print "     - "$0}' "$_marker" 2>/dev/null || true)
    DAG_STATE="   - Active feature/task: ${_feat:-<none>} / ${_task:-<none>}"
    [ -n "$_owns" ] && DAG_STATE="${DAG_STATE}
   - Owned scope (do NOT lose — the freeze contract for this task):
${_owns}"
    _plan="$REPO_ROOT/features/${_feat}/plan.md"
    if [ -n "$_feat" ] && [ -f "$_plan" ]; then
        _edges=$(grep -nE '^[[:space:]]*-?[[:space:]]*(id|depends_on):' "$_plan" 2>/dev/null | sed 's/^/       /' | head -30 || true)
        [ -n "$_edges" ] && DAG_STATE="${DAG_STATE}
   - DAG edges (task ids + depends_on — preserve the blocking order):
${_edges}"
    fi
fi
[ -n "$DAG_STATE" ] || DAG_STATE="   - (no active plan-as-DAG marker; capture the working goal + next concrete step yourself)"

context=$(cat <<CTX
**CONTEXT CAP WARNING** (${tokens} of ${WINDOW_TOKENS} tokens — ${pct}%):

You have crossed the 80% context threshold (${THRESHOLD_TOKENS}). Long contexts
degrade reasoning and bias the model toward premature wrap-up. Augment native
compaction with a DEPENDENCY-PRESERVING handoff so structure is not flattened.

**Preserve VERBATIM across the reset (head + tail):**
- HEAD: the active goal/objective + the constitution pointer (.logic-loom/memory/constitution.md).
- TAIL: the last few exchanges (most recent decisions + the in-flight step).
The MIDDLE may be summarized — delegate that summary to a cheap model / the memory tier.

**Active plan-as-DAG state to carry forward (so 'what blocks what' survives):**
${DAG_STATE}

**Recommended action**: write the handoff, then start a fresh session.
1. Write .docs/handoffs/handoff-\$(date +%Y%m%d-%H%M).md covering: active feature+task,
   the DAG state above (owned scope + depends_on order), decisions made this session,
   open questions / next concrete step, and file touchpoints (paths only).
2. Inform the user the handoff is ready and recommend /clear or a new session.
3. Do NOT silently rush to finish — quality matters more than closure.
CTX
)

escaped=${context//\\/\\\\}
escaped=${escaped//\"/\\\"}
escaped=${escaped//$'\n'/\\n}

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$escaped"
exit 0
