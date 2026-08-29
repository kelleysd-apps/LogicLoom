#!/usr/bin/env bash
# Protect Governance Files — PreToolUse hook (Write/Edit + Bash), Principle VI/governance.
#
# The model has Write/Edit/Bash access to the very files that govern it — the
# hook scripts, settings.json, the constitution, governance.conf. Left open, a
# model (or a subagent) can soften or delete its own guardrails (observed in the
# wild — Claude Code RFC #45427). This hook makes the governance surface
# self-protecting:
#   - a SUBAGENT (agent_id present) editing a protected path  -> DENY (hard)
#   - the MAIN agent editing a protected path                 -> ASK (human approval,
#                                                                like git mutations)
#   - anything else                                           -> ALLOW
#
# It is NOT airtight (a string gate can't see interpreter/eval indirection — see
# subagent-git-guard's note); it is one layer of defense-in-depth, not a sandbox.
#
# Input:  PreToolUse JSON via stdin (Write/Edit/MultiEdit/NotebookEdit or Bash).
# Output: hookSpecificOutput decision (deny / ask / allow).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# plugins/loom-governance/hooks/scripts -> repo root is 4 up
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Shared verdict lib (the L2 "verdict function" seam — see
# .docs/architecture/governance-threat-model.md). Fail OPEN if absent
# (infra-gap posture, matching guard-dangerous-commands).
VERDICT_LIB="$REPO_ROOT/.logic-loom/lib/governance-verdicts.sh"
# shellcheck disable=SC1090
{ [ -f "$VERDICT_LIB" ] && source "$VERDICT_LIB"; } 2>/dev/null || true

INPUT=$(cat)

# jq -> python3 -> grep. The third rung was missing here, exactly as it was in
# subagent-git-guard.sh: on a machine with NEITHER jq nor python3 every json_get
# returned empty, the empty .agent_id read as "main agent", and a SUBAGENT write
# to .claude/settings.json came back ALLOW where it is denied on any normal
# machine. Verified: deny -> allow. That is the hook whose whole job is stopping
# the model from rewriting its own rules, so it failing open is the worst of the
# set. `git-safety-gate.sh` already had this rung and survived the same test.
have_structured_parser() {
  command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1
}

json_get() { # jq-path
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null && return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      "import sys,json
d=json.load(sys.stdin)
keys='${1//[.\"]/ }'.split()
v=d
for k in keys:
    v=v.get(k) if isinstance(v,dict) else None
print(v if v is not None else '')" 2>/dev/null && return
  fi
  # Last rung: the raw payload as text. A string gate on JSON, so it cannot see
  # through escaping or nesting — hence the degraded-parse branch below.
  leaf=${1##*.}
  printf '%s' "$INPUT" \
    | grep -oE "\"$leaf\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed "s/.*\"$leaf\"[^\"]*\"//; s/\"$//"
}

allow() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'; exit 0; }
decide() { # deny|ask  reason
  local d="$1" reason="$2" esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$d" "$esc"
  exit 0
}

AGENT_ID="$(json_get '.agent_id' || true)"

# FAIL CLOSED ON A DEGRADED PARSE. With no structured parser we are reading JSON
# with grep, so an empty agent_id is not evidence of the main agent — it is
# evidence we cannot tell. Being wrong this way costs the main agent an approval
# prompt on a governance file, which it already gets. Being wrong the other way
# lets a subagent silently rewrite the rules that constrain it.
if [ -z "$AGENT_ID" ] && ! have_structured_parser; then
  # Keyed on `agent_id` ONLY. `agent_type` was in this list and came out on
  # external review: it can be present for a TOP-LEVEL session, so matching it
  # would classify a main agent as a subagent and deny its legitimate git —
  # trading a silent hole for a silent blockage. `agent_id` is the documented
  # discriminator this hook uses everywhere else, so it is the only honest
  # degraded-mode signal.
  case "$INPUT" in
    *'"agent_id"'*) AGENT_ID="unknown-degraded-parse" ;;
  esac
fi
TOOL="$(json_get '.tool_name' || true)"

# Protected governance surface (repo-root-relative path prefixes). Delegates to
# the shared verdict lib (single, conformance-tested source of the protected
# set); the inline case below is the fail-open fallback when the lib is absent.
#
# The lib's set is the built-in FLOOR plus any ADDITIVE `protected_paths` entries
# in governance.conf (see the invariant block in governance-verdicts.sh: config
# can only add, the floor can never be removed). The inline fallback below
# reproduces only the floor — it is a last resort for a missing lib, and by
# construction it can be a SUBSET of the real set, never a superset. That is
# consistent with this hook's documented fail-open-on-infra-gap posture: a fork
# whose extra paths matter should notice the lib is gone, not rely on a duplicate
# config parser here.
is_protected() { # rel_path -> 0 if protected
  if declare -f loom_path_is_protected >/dev/null 2>&1; then
    loom_path_is_protected "$1"; return
  fi
  case "$1" in
    .claude/hooks/*|.claude/hooks \
    |.claude/settings.json|.claude/settings.local.json \
    |.logic-loom/config/governance.conf \
    |.logic-loom/memory/constitution.md \
    |.logic-loom/lib/governance-verdicts.sh|.logic-loom/lib/policy.sh \
    |plugins/loom-governance/hooks/*|plugins/loom-governance/hooks \
    |plugins/loom-governance/.claude-plugin/plugin.json) return 0 ;;
  esac
  return 1
}

# The same set as TOKENS for the Bash branch, which substring-matches command
# text rather than asking a yes/no about one path. Same sourcing rule: the lib
# when present (floor + config additions), the floor-only fallback otherwise.
protected_tokens() { # -> one protected path/prefix per line
  if declare -f loom_protected_path_tokens >/dev/null 2>&1; then
    loom_protected_path_tokens; return
  fi
  printf '%s\n' \
    '.claude/hooks' '.claude/settings.json' '.claude/settings.local.json' \
    '.logic-loom/config/governance.conf' '.logic-loom/memory/constitution.md' \
    '.logic-loom/lib/governance-verdicts.sh' '.logic-loom/lib/policy.sh' \
    'plugins/loom-governance/hooks' \
    'plugins/loom-governance/.claude-plugin/plugin.json'
}

# Canonicalize a path and make it repo-root-relative for matching.
rel_of() { # raw_path -> relative path (or raw if outside repo)
  local p="$1" canon
  if command -v python3 >/dev/null 2>&1; then
    canon=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null)
  fi
  [ -n "${canon:-}" ] || canon=$(printf '%s' "$p" | sed 's://*:/:g')
  case "$canon" in
    "$REPO_ROOT"/*) printf '%s' "${canon:${#REPO_ROOT}+1}" ;;
    /*)             printf '%s' "$canon" ;;   # absolute, outside repo
    *)              printf '%s' "$canon" ;;   # already relative
  esac
}

gate() { # rel_path  verb-desc
  is_protected "$1" || return 0
  if [ -n "$AGENT_ID" ]; then
    decide deny "Governance file '$1' may NOT be modified by a subagent ('$(json_get '.agent_type')'). The hooks/constitution/settings that enforce governance are main-agent + explicit-user-approval only. Return the proposed change to the main agent."
  else
    decide ask "About to modify a GOVERNANCE file: '$1'. This changes the rules that enforce the constitution (hooks/settings/constitution/governance.conf). Approve only if you intend to change governance itself."
  fi
}

case "$TOOL" in
  Write|Edit|MultiEdit|NotebookEdit)
    FP="$(json_get '.tool_input.file_path' || true)"
    [ -z "$FP" ] && FP="$(json_get '.tool_input.notebook_path' || true)"
    [ -z "$FP" ] && allow
    gate "$(rel_of "$FP")" "write"
    ;;
  Bash)
    CMD="$(json_get '.tool_input.command' || true)"
    [ -z "$CMD" ] && allow
    # Only MUTATING bash that TARGETS a protected path is gated. A read-only
    # command that merely MENTIONS a governance path (ls / find / cat / head /
    # grep / wc / stat / file …) must pass — an adversarial reviewer had a plain
    # `find plugins/loom-governance/hooks` denied because the old matcher looked
    # for a mutation shape ANYWHERE in the line (a bare ">" matched the
    # `2>/dev/null` of a read; "chmod"/"truncate" matched unanchored).
    #
    # Two anchored signals now, evaluated per shell segment (segments start at a
    # command position, so the command WORD is identifiable):
    #   1. the segment's command word is a mutator (tee/dd of=/sed -i/rm/mv/
    #      truncate/chmod/chown/install) AND the segment mentions a protected path
    #   2. a REDIRECTION TARGET (> / >>) in the segment is a protected path
    # The gated set is unchanged; only the false positives are gone.
    gate_bash() { # protected-token
      if [ -n "$AGENT_ID" ]; then
        decide deny "Subagent ('$(json_get '.agent_type')') may not modify governance file '$1' via Bash. Governance changes are main-agent + user-approval only."
      else
        decide ask "Bash command appears to MODIFY a governance path ('$1'). Approve only if you intend to change governance itself. Command: $CMD"
      fi
    }

    # Command word of a segment, path-stripped; skips VAR=value assignments and
    # sudo/env-style prefix words.
    seg_cmd_word() { # segment -> command word (may be empty)
      local s="$1" tok
      while :; do
        s="${s#"${s%%[![:space:]]*}"}"
        [ -n "$s" ] || { printf ''; return 0; }
        tok="${s%%[[:space:]]*}"
        case "${tok##*/}" in
          *=*|sudo|env|command|nohup|nice|time|exec|xargs|stdbuf|ionice) ;;
          -*) ;;
          *) printf '%s' "${tok##*/}"; return 0 ;;
        esac
        s="${s#"$tok"}"
      done
    }

    seg_is_mutator() { # segment -> 0 if its command word writes files
      case "$(seg_cmd_word "$1")" in
        tee|truncate|chmod|chown|install|rm|mv) return 0 ;;
        dd)  printf '%s' "$1" | grep -qE '(^|[[:space:]])of=' && return 0 ;;
        sed) printf '%s' "$1" | grep -qE '(^|[[:space:]])-i' && return 0 ;;
      esac
      return 1
    }

    seg_redirect_targets() { # segment -> one redirection target per line
      printf '%s' "$1" \
        | grep -oE '>>?[[:space:]]*[^[:space:]<>|;&]+' \
        | sed -e 's/^>>*//' -e 's/^[[:space:]]*//'
    }

    # Token list comes from the verdict lib so the Bash branch and the Write/Edit
    # branch protect the SAME set — including any additive governance.conf
    # entries. Computed once, outside the segment loop.
    PROT_TOKENS="$(protected_tokens || true)"

    while IFS= read -r SEG; do
      [ -n "$SEG" ] || continue
      SEG_MUTATES=0
      seg_is_mutator "$SEG" && SEG_MUTATES=1
      RTARGETS="$(seg_redirect_targets "$SEG" || true)"
      [ "$SEG_MUTATES" = 0 ] && [ -z "$RTARGETS" ] && continue
      while IFS= read -r prot; do
        [ -n "$prot" ] || continue
        if [ "$SEG_MUTATES" = 1 ] && printf '%s' "$SEG" | grep -qF "$prot"; then
          gate_bash "$prot"
        fi
        if [ -n "$RTARGETS" ] && printf '%s' "$RTARGETS" | grep -qF "$prot"; then
          gate_bash "$prot"
        fi
      done <<< "$PROT_TOKENS"
    done <<< "$(printf '%s' "$CMD" | tr ';|&(){}`' '\n\n\n\n\n\n\n\n')"
    ;;
esac

allow
