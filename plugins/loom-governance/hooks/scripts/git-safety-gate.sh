#!/usr/bin/env bash
# Git Safety Gate — Principle VI enforcement via PreToolUse hook (Bash matcher)
#
# Forces explicit user approval for git operations that mutate repository state.
# Read-only git commands (status, log, diff, show, branch listing) pass through.
#
# Enforcement is hook-side and model-independent: a mutating git command emits a
# PreToolUse decision of "ask", which makes Claude Code surface the approval
# prompt regardless of any allowlist. This is the teeth behind "NO autonomous
# git operations" — it does not rely on the model reading CLAUDE.md.
#
# Known limitation: this is a STRING gate. It catches `git` behind a path
# prefix (/usr/bin/git, ./git) and global flags before the subcommand
# (git -C /r push, git -c k=v commit). It does NOT see git run through
# interpreter / script / eval indirection (python -c, bash script.sh, eval,
# variable indirection like `G=git; $G push`) — inherent to any string gate.
#
# Input:  Claude Code PreToolUse JSON via stdin, e.g.
#   {"tool_name":"Bash","tool_input":{"command":"git push origin main"}}
# Output: JSON decision (current hookSpecificOutput schema):
#   ask  -> {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#            "permissionDecision":"ask","permissionDecisionReason":"..."}}
#   allow-> {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#            "permissionDecision":"allow"}}
set -euo pipefail

INPUT=$(cat)

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // empty' 2>/dev/null && return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command', d.get('command','')))" \
      2>/dev/null && return
  fi
  printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[^"]*"//; s/"$//'
}

# The session's permission mode, when the host supplies one. OBSERVED PRESENT in
# Claude Code 2.1.200: the common hook-input builder emits `permission_mode`
# alongside session_id/cwd/agent_id/agent_type, PreToolUse spreads it, and it
# appears in real captured payloads. Values:
# default | acceptEdits | auto | dontAsk | bypassPermissions | plan.
#
# Why it matters here: it is the key the gate policy can be tuned against, so a
# user can decide per-mode whether TUNABLE operations still interrupt them. It is
# INFERRED (from host internals, not verified by us) that a hook `ask` is folded
# back into the full permission pipeline — which would make an `ask` redundant
# under bypassPermissions. Because that is unverified, NO mode ships as `relax`;
# every mode enforces the policy as written until the user opts in via
# gate-policy.conf. Empty/absent -> unknown mode -> policy as written.
extract_permission_mode() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null && return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('permission_mode') or '')" \
      2>/dev/null && return
  fi
  printf '%s' "$INPUT" | grep -oE '"permission_mode"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"permission_mode"[^"]*"//; s/"$//'
}

COMMAND="$(extract_command || true)"
PERMISSION_MODE="$(extract_permission_mode || true)"
# A hostile/garbled value must never reach a case pattern as a metacharacter.
case "$PERMISSION_MODE" in *[!a-zA-Z]*) PERMISSION_MODE="" ;; esac

emit_allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
  exit 0
}

emit_ask() {
  local reason="$1" esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0
}

[ -z "$COMMAND" ] && emit_allow

# Decision via the shared verdict lib (the L2 "verdict function" seam — see
# .docs/architecture/governance-threat-model.md). This hook is the Claude Code
# reference ADAPTER for the git-mutation gate; off-host adapters (a git
# pre-push hook, a CI gate) call the SAME loom_verdict_git_mutation function.
# The two-stage detection (git invocation incl. /usr/bin/git, ./git, global
# flags like `git -C /r push`; then a MUTATING subcommand token, branch -d/-m,
# remote write — read-only ops pass through) lives in loom_git_is_mutation.
# Fail OPEN on an infra gap (missing lib), matching guard-dangerous-commands.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT_LIB="$(cd "$SCRIPT_DIR/../../../.." && pwd)/.logic-loom/lib/governance-verdicts.sh"
# shellcheck disable=SC1090
{ [ -f "$VERDICT_LIB" ] && source "$VERDICT_LIB"; } 2>/dev/null || true

if declare -f loom_verdict_git_mutation >/dev/null 2>&1; then
  # Which operations ask, and which run silently, is the USER-CONFIGURABLE gate
  # policy (.logic-loom/config/gate-policy.conf) — not a constant in this hook.
  # A missing/corrupt policy file falls back to the built-in defaults, never to
  # "allow everything"; five FLOOR operations (git.push, git.history-rewrite,
  # gh.repo.admin, gh.secret.write, gh.auth) are not tunable at all.
  GATE_OP=""
  if declare -f loom_gate_asking_op >/dev/null 2>&1; then
    GATE_OP="$(loom_gate_asking_op "$COMMAND" "$PERMISSION_MODE" || true)"
  fi
  if [ "$(loom_verdict_git_mutation "$COMMAND" "$PERMISSION_MODE")" = "ask" ]; then
    emit_ask "Principle VI: git operation requires explicit user approval${GATE_OP:+ [gate: ${GATE_OP}]} — '${COMMAND}'"
  fi
  # Same gate for the GitHub CLI: `gh pr create/merge`, `gh workflow run`,
  # `gh release create`, `gh api -X POST|PUT|PATCH|DELETE` and friends mutate the
  # repository server-side. Read-only gh (pr list/view/checks/diff, run
  # list/view/watch, issue/repo/release/workflow view, `gh api` with no write
  # method) passes through unprompted.
  if declare -f loom_verdict_gh_mutation >/dev/null 2>&1 \
     && [ "$(loom_verdict_gh_mutation "$COMMAND" "$PERMISSION_MODE")" = "ask" ]; then
    emit_ask "Principle VI: GitHub CLI operation mutates the repository and requires explicit user approval${GATE_OP:+ [gate: ${GATE_OP}]} — '${COMMAND}'"
  fi
  emit_allow
fi

# Fail-SAFE fallback (verdict lib unavailable): inline-detect a mutating git and
# still force approval rather than failing open. DELIBERATELY IGNORES the gate
# policy and the permission mode: with the library gone there is nothing to parse
# the policy file with, and a second, simpler copy of the ask/silent split would
# be a second thing to get wrong. The cost is extra prompts during a window in
# which the governance library is missing — a window that should be loud anyway. The lib is normally present and
# self-protected; this last-resort copy keeps Principle VI from silently lapsing.
_GIT_INVOKE='(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'
_GIT_MUT='(^|[^[:alnum:]-])(push|pull|commit|merge|rebase|reset|checkout|switch|tag|stash|cherry-pick|revert|am|apply|clean|rm|mv|restore|update-ref|symbolic-ref|filter-branch|fast-import)([^[:alnum:]-]|$)'
if printf '%s' "$COMMAND" | grep -qE "$_GIT_INVOKE" && printf '%s' "$COMMAND" | grep -qE "$_GIT_MUT"; then
  emit_ask "Principle VI: git operation requires explicit user approval (verdict lib unavailable — failing safe) — '${COMMAND}'"
fi
# Same last-resort copy for the GitHub CLI.
_GH_INVOKE='(^|[^[:alnum:]_])([^[:space:]]*/)?gh([[:space:]]|$)'
_GH_MUT='(pr[[:space:]]+(create|merge|close|reopen|review|edit)|workflow[[:space:]]+(run|enable|disable)|run[[:space:]]+(rerun|cancel)|release[[:space:]]+(create|delete|edit)|repo[[:space:]]+(delete|archive|edit)|issue[[:space:]]+(create|close|edit|delete|pin)|alias[[:space:]]+set|secret[[:space:]]+set|variable[[:space:]]+set|ssh-key[[:space:]]+add|auth[[:space:]]+(login|refresh)|(-X|--method)[[:space:]]*=?[[:space:]]*(POST|PUT|PATCH|DELETE))'
if printf '%s' "$COMMAND" | grep -qE "$_GH_INVOKE" && printf '%s' "$COMMAND" | grep -qE "$_GH_MUT"; then
  emit_ask "Principle VI: GitHub CLI operation requires explicit user approval (verdict lib unavailable — failing safe) — '${COMMAND}'"
fi
emit_allow
