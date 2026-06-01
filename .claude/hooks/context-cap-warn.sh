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

context=$(cat <<CTX
**CONTEXT CAP WARNING** (${tokens} of ${WINDOW_TOKENS} tokens — ${pct}%):

You have crossed the 80% context threshold (${THRESHOLD_TOKENS}). Long contexts
degrade reasoning and bias the model toward premature wrap-up.

**Recommended action**: summarize current progress to a handoff artifact and
start a fresh session.

1. Write a handoff to .docs/handoffs/handoff-\$(date +%Y%m%d-%H%M).md covering:
   - Active feature + task
   - Decisions made this session
   - Open questions / next concrete step
   - File touchpoints (paths only)
2. Inform the user the handoff is ready and recommend /clear or a new session.
3. Do NOT silently rush to finish — quality matters more than closure.
CTX
)

escaped=${context//\\/\\\\}
escaped=${escaped//\"/\\\"}
escaped=${escaped//$'\n'/\\n}

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$escaped"
exit 0
