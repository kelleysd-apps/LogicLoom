#!/usr/bin/env bash
# PreToolUse Hook: Freeze write-scope (gstack-D)
# Constitutional Principle XI: Input Validation at the tool boundary
#
# Enforces plan-as-DAG file ownership during /swarm implement runs.
# When an active feature/task context is set, write tools (Write, Edit,
# MultiEdit, NotebookEdit) may only target files declared in the task's
# `owns:` list. Files in the task's `freeze:` list are rejected.
#
# Default-allow semantics: if no active DAG context is detected, every
# write is permitted — ad-hoc / free-form work is never blocked.
#
# Active-DAG detection (any of):
#   1. Env var:  LOOM_ACTIVE_FEATURE=<feature>  (optionally LOOM_ACTIVE_TASK=<task-id>)
#   2. Marker file: <repo>/.loom-active-feature  with lines:
#        feature: <feature-name>
#        task: <task-id>
#        owns:
#          - <path-or-glob>
#          ...
#        freeze:
#          - <path-or-glob>
#          ...
#
# Scope resolution (owns:/freeze: lists), in priority order:
#   A. If the marker file declares owns:/freeze: lists, those are authoritative.
#      swarm-implement writes the active task's resolved scope here before each
#      worker dispatch (see swarm-implement/SKILL.md §6). This is the primary
#      mechanism — the hook does not have to re-parse the nested-YAML plan.
#   B. Otherwise, fall back to parsing the flat `## task: <id>` blocks in
#      features/<feature>/plan.md (lenient; for human-driven sessions that set
#      only feature:/task: but rely on a flat plan).
#
# Input:  Claude Code PreToolUse JSON via stdin, e.g.:
#   {"tool_name":"Edit","tool_input":{"file_path":"/abs/path/file.ts", ...}}
# Output: Claude Code PreToolUse permission decision JSON on stdout:
#   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow|deny","permissionDecisionReason":"..."}}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICY_LIB="$REPO_ROOT/.logic-loom/lib/policy.sh"
MARKER_FILE="$REPO_ROOT/.loom-active-feature"

allow() {
    # Current Claude Code PreToolUse schema. Emit an explicit allow.
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
    exit 0
}

deny() {
    local reason="$1"
    local esc=${reason//\\/\\\\}
    esc=${esc//\"/\\\"}
    esc=${esc//$'\n'/\\n}
    # Current Claude Code PreToolUse schema: deny with a reason surfaced to the model.
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
    # Also emit a human-readable line on stderr.
    printf '[BLOCKED freeze-write-scope] %s\n' "$reason" >&2
    exit 0
}

# Drain stdin
input=""
if [ ! -t 0 ]; then
    input=$(cat 2>/dev/null || true)
fi

# If no input, nothing to validate
[ -n "$input" ] || allow

# Extract tool_name and target file path. Prefer jq; fall back to grep.
tool_name=""
file_path=""

if command -v jq >/dev/null 2>&1; then
    tool_name=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty' 2>/dev/null || true)
    # Different write tools nest the path differently
    file_path=$(printf '%s' "$input" | jq -r '
        .tool_input.file_path
        // .tool_input.path
        // .tool_input.notebook_path
        // .toolInput.file_path
        // .toolInput.path
        // empty' 2>/dev/null || true)
else
    tool_name=$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    file_path=$(printf '%s' "$input" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [ -n "$file_path" ] || file_path=$(printf '%s' "$input" | grep -oE '"notebook_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi

# Only gate write-class tools
case "$tool_name" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *) allow ;;
esac

# No target file path resolvable -> default allow
[ -n "$file_path" ] || allow

# ============================================================
# Detect active DAG context
# ============================================================
active_feature="${LOOM_ACTIVE_FEATURE:-}"
active_task="${LOOM_ACTIVE_TASK:-}"

# Scope lists sourced directly from the marker file (primary mechanism).
marker_owns=""
marker_freeze=""

if [ -f "$MARKER_FILE" ]; then
    # Parse the marker file. Recognizes:
    #   feature: <name>
    #   task: <id>
    #   owns:        (list header; following "  - <path>" lines belong to it)
    #   freeze:      (list header)
    # Env-provided feature/task win over the marker's feature/task lines.
    _section=""
    _m_feature=""
    _m_task=""
    while IFS= read -r line || [ -n "$line" ]; do
        # List item under the active section?
        case "$line" in
            *-\ *|*-$'\t'*)
                item=$(printf '%s' "$line" | sed -n 's/^[[:space:]]*-[[:space:]]*\(.*\)$/\1/p' | sed 's/[[:space:]]*$//')
                if [ -n "$item" ]; then
                    case "$_section" in
                        owns)   marker_owns="${marker_owns}${item}"$'\n' ;;
                        freeze) marker_freeze="${marker_freeze}${item}"$'\n' ;;
                    esac
                    continue
                fi
                ;;
        esac
        # key: value (or key: with empty value -> list header)
        key=$(printf '%s' "$line" | sed -n 's/^[[:space:]]*\([a-zA-Z_]*\)[[:space:]]*:.*/\1/p')
        val=$(printf '%s' "$line" | sed -n 's/^[^:]*:[[:space:]]*\(.*\)$/\1/p' | sed 's/[[:space:]]*$//')
        case "$key" in
            feature) _m_feature="$val"; _section="" ;;
            task)    _m_task="$val"; _section="" ;;
            owns)    _section="owns" ;;
            freeze)  _section="freeze" ;;
            *)       _section="" ;;
        esac
    done < "$MARKER_FILE"

    [ -n "$active_feature" ] || active_feature="$_m_feature"
    [ -n "$active_task" ]    || active_task="$_m_task"
fi

# No active DAG context -> default allow (this is the critical safety property)
[ -n "$active_feature" ] || allow

# ============================================================
# Resolve owns:/freeze: scope lists
# ============================================================
# Priority A: marker-provided scope (authoritative when present).
owns_list="$marker_owns"
freeze_list="$marker_freeze"

# Priority B: fall back to parsing the feature plan when the marker carried
# no scope. Uses the flat `## task: <id>` block format.
if [ -z "$owns_list" ] && [ -z "$freeze_list" ]; then
    plan_file="$REPO_ROOT/features/${active_feature}/plan.md"
    if [ -f "$plan_file" ]; then
        # plan.md flat DAG task block convention:
        #   ## task: <task-id>
        #   owns:
        #     - path/one
        #     - path/two
        #   freeze:
        #     - path/three
        #
        # If task is unspecified, we union all owns:/freeze: across the plan.
        extract_list() {
            # extract_list <plan_file> <task_id> <key>   key = "owns" | "freeze"
            local pf="$1" task="$2" key="$3"
            awk -v task="$task" -v key="$key" '
                BEGIN { in_task = (task == ""); in_key = 0 }
                /^##[[:space:]]+task:/ {
                    sub(/^##[[:space:]]+task:[[:space:]]*/, "", $0)
                    gsub(/[[:space:]]+$/, "", $0)
                    if (task == "" || $0 == task) { in_task = 1 } else { in_task = 0 }
                    in_key = 0
                    next
                }
                /^##[[:space:]]/ { in_task = (task == "" ? 1 : 0); in_key = 0; next }
                in_task && $0 ~ "^"key":[[:space:]]*$" { in_key = 1; next }
                in_task && in_key && /^[a-zA-Z_]+:[[:space:]]*$/ { in_key = 0 }
                in_task && in_key && /^[[:space:]]*-[[:space:]]+/ {
                    line = $0
                    sub(/^[[:space:]]*-[[:space:]]+/, "", line)
                    gsub(/[[:space:]]+$/, "", line)
                    print line
                }
            ' "$pf"
        }
        owns_list=$(extract_list "$plan_file" "$active_task" "owns")
        freeze_list=$(extract_list "$plan_file" "$active_task" "freeze")
    fi
fi

# If we resolved no scope at all, we cannot enforce -> default allow.
if [ -z "$owns_list" ] && [ -z "$freeze_list" ]; then
    allow
fi

# Source policy.sh for the helper (provides loom_check_freeze_scope).
# policy.sh transitively sources logging.sh which trips `set -u` on unset
# DEBUG, and load_policy may fail benignly. Relax both errexit + nounset
# while sourcing, then restore. Failure to source is non-fatal — we fall
# back to the inline matcher below.
# NOTE: policy.sh re-derives REPO_ROOT for its own use; save+restore ours.
_loom_saved_repo_root="$REPO_ROOT"
if [ -f "$POLICY_LIB" ]; then
    set +eu
    # shellcheck disable=SC1090
    source "$POLICY_LIB" >/dev/null 2>&1 || true
    set -eu
fi
REPO_ROOT="$_loom_saved_repo_root"
unset _loom_saved_repo_root

# Normalize the target to a path relative to repo root for matching.
# bash 3.2 quirk: ${var#"$prefix"} (quoted) does not strip when prefix
# contains '/'. Use unquoted form — REPO_ROOT is a path with no glob chars.
rel_target="$file_path"
prefix="$REPO_ROOT/"
case "$rel_target" in
    "$REPO_ROOT"/*)
        rel_target="${rel_target:${#prefix}}"
        ;;
esac

# ============================================================
# Check freeze: list first (hard reject if matched)
# ============================================================
if [ -n "$freeze_list" ]; then
    while IFS= read -r frozen; do
        [ -z "$frozen" ] && continue
        frozen="${frozen#./}"
        frozen="${frozen%/}"
        [ -z "$frozen" ] && continue
        case "$rel_target" in
            $frozen|$frozen/*)
                deny "Write target '$rel_target' is in FREEZE list for feature '$active_feature' (task: ${active_task:-<all>}). Plan-as-DAG declares this file untouchable for the active task. See features/${active_feature}/plan.md."
                ;;
        esac
    done <<< "$freeze_list"
fi

# ============================================================
# If owns: is declared, target must match. Else default allow.
# ============================================================
if [ -z "$owns_list" ]; then
    allow
fi

# Prefer policy.sh helper when available (centralizes glob logic)
if declare -f loom_check_freeze_scope >/dev/null 2>&1; then
    if loom_check_freeze_scope "$rel_target" "$owns_list"; then
        allow
    else
        deny "Write target '$rel_target' is OUTSIDE the owns: scope for task '${active_task:-<unspecified>}' in feature '$active_feature'. Allowed paths:\n$owns_list\nSee features/${active_feature}/plan.md (plan-as-DAG)."
    fi
fi

# Inline fallback matcher (case-style globbing)
matched=0
while IFS= read -r owned; do
    [ -z "$owned" ] && continue
    owned="${owned#./}"
    owned="${owned%/}"
    [ -z "$owned" ] && continue
    case "$rel_target" in
        $owned|$owned/*)
            matched=1
            break
            ;;
    esac
done <<< "$owns_list"

if [ "$matched" -eq 1 ]; then
    allow
else
    deny "Write target '$rel_target' is OUTSIDE the owns: scope for task '${active_task:-<unspecified>}' in feature '$active_feature'. Allowed paths:\n$owns_list\nSee features/${active_feature}/plan.md (plan-as-DAG)."
fi
