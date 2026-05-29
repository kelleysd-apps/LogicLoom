#!/usr/bin/env bash
# event-logger.sh — Structured event logging for loom-dev-loop plugin
#
# Provides JSONL (JSON Lines) event logging for dev-loop sessions.
# Each event is a single JSON object on one line, supporting efficient
# append-only writes and line-based querying.
#
# Event types: thought, action, observation, decision, tool_invocation, grade, vote, error
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON processing), uuidgen or python3 (UUID generation)
# Constitutional Principle VII: Observability — full event trail for session replay

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Module State
# ==============================================================================

# Current event log file path (set by init_event_log)
_EVENT_LOG_FILE=""

# Current session ID (set by init_event_log)
_EVENT_LOG_SESSION_ID=""

# Event sequence counter for generating event IDs
_EVENT_LOG_SEQ=0

# Valid event types
_VALID_EVENT_TYPES="thought action observation decision tool_invocation grade vote error"

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _generate_uuid — Generate a UUID v4
# Tries uuidgen first, falls back to python3
_generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &>/dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        # Last resort: construct a pseudo-UUID from /dev/urandom
        local hex
        hex=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
        echo "${hex:0:8}-${hex:8:4}-4${hex:13:3}-${hex:16:4}-${hex:20:12}"
    fi
}

# _iso8601_now — Get current UTC timestamp in ISO 8601 format with microseconds
# Uses python3 for sub-second precision, falls back to date(1) for second precision
_iso8601_now() {
    if command -v python3 &>/dev/null; then
        python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ'))"
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# _validate_event_type — Check if event type is valid
# Returns: 0 if valid, 1 if invalid
_validate_event_type() {
    local event_type="$1"
    local valid_type
    for valid_type in $_VALID_EVENT_TYPES; do
        if [[ "$event_type" == "$valid_type" ]]; then
            return 0
        fi
    done
    return 1
}

# _next_event_id — Generate sequential event ID for this session
_next_event_id() {
    _EVENT_LOG_SEQ=$((_EVENT_LOG_SEQ + 1))
    local timestamp
    timestamp=$(date -u +"%Y%m%d-%H%M%S")
    printf "evt-%s-%03d" "$timestamp" "$_EVENT_LOG_SEQ"
}

# ==============================================================================
# init_event_log — Initialize a new JSONL event log for a session
# ==============================================================================
# Usage: init_event_log <session_id> <session_dir>
#
# Creates (or verifies) the events.jsonl file in the session directory.
# Sets module state for subsequent log_event calls.
#
# Arguments:
#   session_id  — Unique session identifier
#   session_dir — Directory where events.jsonl will be created
#
# Outputs: path to the JSONL file
# Returns: 0 on success, 1 on failure
init_event_log() {
    local session_id="$1"
    local session_dir="$2"

    # Create session directory if needed
    if [[ ! -d "$session_dir" ]]; then
        mkdir -p "$session_dir"
    fi

    _EVENT_LOG_SESSION_ID="$session_id"
    _EVENT_LOG_FILE="${session_dir}/events.jsonl"
    _EVENT_LOG_SEQ=0

    # Create the file if it does not exist; touch to update mtime if it does
    touch "$_EVENT_LOG_FILE"

    echo "$_EVENT_LOG_FILE"
    return 0
}

# ==============================================================================
# log_event — Append a structured event to the JSONL log
# ==============================================================================
# Usage: log_event <event_type> <iteration> <content> [metadata_json]
#
# Writes a single JSON line to the event log file. Each event includes:
#   - event_id:   UUID for this event
#   - session_id: Parent session
#   - timestamp:  ISO 8601 UTC
#   - iteration:  Loop iteration number (0 = pre-loop)
#   - event_type: One of the valid event types
#   - content:    Human-readable description
#   - metadata:   Optional structured data (JSON object)
#
# Arguments:
#   event_type    — One of: thought, action, observation, decision, tool_invocation, grade, vote, error
#   iteration     — Integer iteration number (0 for pre-loop events)
#   content       — Human-readable event description string
#   metadata_json — Optional JSON object string (defaults to {})
#
# Outputs: event_id of the logged event
# Returns: 0 on success, 1 on failure
log_event() {
    local event_type="$1"
    local iteration="$2"
    local content="$3"
    local metadata_json="${4:-"{}"}"

    # Validate state
    if [[ -z "$_EVENT_LOG_FILE" ]]; then
        echo "ERROR: Event log not initialized. Call init_event_log first." >&2
        return 1
    fi

    # Validate event type
    if ! _validate_event_type "$event_type"; then
        echo "ERROR: Invalid event type: $event_type. Valid types: $_VALID_EVENT_TYPES" >&2
        return 1
    fi

    # Validate metadata is valid JSON
    if ! echo "$metadata_json" | jq empty 2>/dev/null; then
        echo "ERROR: metadata_json is not valid JSON: $metadata_json" >&2
        return 1
    fi

    # Generate event ID and timestamp
    local event_id timestamp
    event_id=$(_next_event_id)
    timestamp=$(_iso8601_now)

    # Construct and append JSON line
    local json_line
    json_line=$(jq -n -c \
        --arg event_id "$event_id" \
        --arg session_id "$_EVENT_LOG_SESSION_ID" \
        --arg timestamp "$timestamp" \
        --argjson iteration "$iteration" \
        --arg event_type "$event_type" \
        --arg content "$content" \
        --argjson metadata "$metadata_json" \
        '{
            event_id: $event_id,
            session_id: $session_id,
            timestamp: $timestamp,
            iteration: $iteration,
            event_type: $event_type,
            content: $content,
            metadata: $metadata
        }')

    echo "$json_line" >> "$_EVENT_LOG_FILE"

    echo "$event_id"
    return 0
}

# ==============================================================================
# query_events — Filter events by type and/or iteration range
# ==============================================================================
# Usage: query_events [--type <event_type>] [--from <iteration>] [--to <iteration>]
#
# Filters the JSONL event log using jq. Supports filtering by:
#   - event_type: exact match on event type
#   - iteration range: from (inclusive) and to (inclusive)
#
# Options:
#   --type <event_type>  — Filter by event type
#   --from <iteration>   — Minimum iteration (inclusive)
#   --to <iteration>     — Maximum iteration (inclusive)
#
# Outputs: Matching events as JSON lines (JSONL) to stdout
# Returns: 0 on success, 1 if log not initialized
query_events() {
    if [[ -z "$_EVENT_LOG_FILE" || ! -f "$_EVENT_LOG_FILE" ]]; then
        echo "ERROR: Event log not initialized or file missing." >&2
        return 1
    fi

    local filter_type="" filter_from="" filter_to=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                filter_type="$2"
                shift 2
                ;;
            --from)
                filter_from="$2"
                shift 2
                ;;
            --to)
                filter_to="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # Build jq filter expression
    local jq_filter="."

    if [[ -n "$filter_type" ]]; then
        jq_filter="${jq_filter} | select(.event_type == \"${filter_type}\")"
    fi

    if [[ -n "$filter_from" ]]; then
        jq_filter="${jq_filter} | select(.iteration >= ${filter_from})"
    fi

    if [[ -n "$filter_to" ]]; then
        jq_filter="${jq_filter} | select(.iteration <= ${filter_to})"
    fi

    # Process each line through jq
    jq -c "$jq_filter" "$_EVENT_LOG_FILE" 2>/dev/null
    return 0
}

# ==============================================================================
# count_events — Count events by type
# ==============================================================================
# Usage: count_events [event_type]
#
# If event_type is provided, counts only events of that type.
# If omitted, outputs a JSON object with counts per type.
#
# Arguments:
#   event_type — Optional event type to count
#
# Outputs:
#   If event_type given: integer count
#   If no event_type: JSON object {"thought": N, "action": N, ...}
# Returns: 0 on success, 1 if log not initialized
count_events() {
    local event_type="${1:-}"

    if [[ -z "$_EVENT_LOG_FILE" || ! -f "$_EVENT_LOG_FILE" ]]; then
        echo "ERROR: Event log not initialized or file missing." >&2
        return 1
    fi

    if [[ -n "$event_type" ]]; then
        # Count specific type
        jq -c "select(.event_type == \"${event_type}\")" "$_EVENT_LOG_FILE" 2>/dev/null | wc -l | tr -d ' '
    else
        # Count all types, output as JSON object
        jq -s '
            group_by(.event_type) |
            map({key: .[0].event_type, value: length}) |
            from_entries
        ' "$_EVENT_LOG_FILE" 2>/dev/null || echo "{}"
    fi

    return 0
}

# ==============================================================================
# close_log — Finalize and validate the JSONL event log
# ==============================================================================
# Usage: close_log
#
# Validates that every line in the event log is valid JSON.
# Reports any malformed lines. Clears module state so no further
# events can be appended.
#
# Outputs: JSON validation report:
#   {"valid": true/false, "total_lines": N, "invalid_lines": [...], "path": "..."}
# Returns: 0 if all lines valid, 1 if any invalid lines found
close_log() {
    if [[ -z "$_EVENT_LOG_FILE" ]]; then
        echo "ERROR: Event log not initialized." >&2
        return 1
    fi

    local log_path="$_EVENT_LOG_FILE"
    local total_lines=0
    local invalid_lines="[]"
    local all_valid=true
    local line_num=0

    # Check if file is empty
    if [[ ! -s "$log_path" ]]; then
        jq -n \
            --argjson valid true \
            --argjson total_lines 0 \
            --argjson invalid_lines "[]" \
            --arg path "$log_path" \
            '{valid: $valid, total_lines: $total_lines, invalid_lines: $invalid_lines, path: $path}'

        # Clear module state
        _EVENT_LOG_FILE=""
        _EVENT_LOG_SESSION_ID=""
        _EVENT_LOG_SEQ=0
        return 0
    fi

    # Validate each line is valid JSON
    local bad_lines="[]"
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if ! echo "$line" | jq empty 2>/dev/null; then
            all_valid=false
            bad_lines=$(echo "$bad_lines" | jq --argjson ln "$line_num" '. + [$ln]')
        fi
    done < "$log_path"
    total_lines=$line_num

    local valid_bool
    if [[ "$all_valid" == "true" ]]; then
        valid_bool=true
    else
        valid_bool=false
    fi

    jq -n \
        --argjson valid "$valid_bool" \
        --argjson total_lines "$total_lines" \
        --argjson invalid_lines "$bad_lines" \
        --arg path "$log_path" \
        '{valid: $valid, total_lines: $total_lines, invalid_lines: $invalid_lines, path: $path}'

    # Clear module state
    _EVENT_LOG_FILE=""
    _EVENT_LOG_SESSION_ID=""
    _EVENT_LOG_SEQ=0

    if [[ "$all_valid" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# replay_session / reconstruct_state — Reconstruct session state at a point
# ==============================================================================
# Usage: reconstruct_state <session_id> <session_dir> [--at-iteration N | --at-timestamp TS]
#
# Reads the JSONL event log and reconstructs the session state up to a given
# iteration or timestamp. Returns JSON with:
#   current_iteration, last_grade, grade_trajectory, tribunal_ballots,
#   termination_reason, status
#
# Arguments:
#   session_id  — Session identifier
#   session_dir — Directory containing events.jsonl
#   --at-iteration N      — Reconstruct state including events up to iteration N
#   --at-timestamp TS     — Reconstruct state including events up to timestamp TS (ISO 8601)
#
# Outputs: JSON object to stdout
# Returns: 0 on success, 1 on failure
replay_session() {
    reconstruct_state "$@"
}

reconstruct_state() {
    local session_id="$1"
    local session_dir="$2"
    shift 2

    local filter_mode="" filter_value=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --at-iteration)
                filter_mode="iteration"
                filter_value="$2"
                shift 2
                ;;
            --at-timestamp)
                filter_mode="timestamp"
                filter_value="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local log_file="${session_dir}/events.jsonl"

    # Handle missing or empty log file
    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        jq -n '{
            current_iteration: 0,
            last_grade: null,
            grade_trajectory: [],
            tribunal_ballots: [],
            termination_reason: null,
            status: "initial"
        }'
        return 0
    fi

    python3 -c "
import json, sys

log_file = '$log_file'
filter_mode = '$filter_mode'
filter_value = '$filter_value'

events = []
for line in open(log_file):
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except:
        continue

# Filter events based on mode
filtered = []
if filter_mode == 'iteration':
    max_iter = int(filter_value)
    filtered = [e for e in events if e.get('iteration', 0) <= max_iter]
elif filter_mode == 'timestamp':
    cutoff = filter_value
    filtered = [e for e in events if e.get('timestamp', '') <= cutoff]
else:
    filtered = events

# Compute state from filtered events
current_iteration = 0
grade_trajectory = []
tribunal_ballots = []
termination_reason = None
status = 'running'
last_grade = None

# Track grades per iteration to avoid duplicates
grades_by_iter = {}

for e in filtered:
    iteration = e.get('iteration', 0)
    if iteration > current_iteration:
        current_iteration = iteration

    etype = e.get('event_type', '')
    metadata = e.get('metadata', {})

    if etype == 'grade':
        grade_val = metadata.get('composite_grade')
        if grade_val is not None:
            grades_by_iter[iteration] = grade_val
            last_grade = grade_val

    if etype == 'vote':
        tribunal_ballots.append(metadata)

    if etype == 'decision':
        if metadata.get('next_action') == 'terminate':
            termination_reason = metadata.get('reason', 'unknown')
            status = 'terminated'

# Build ordered grade trajectory
for i in sorted(grades_by_iter.keys()):
    grade_trajectory.append(grades_by_iter[i])

result = {
    'current_iteration': current_iteration,
    'last_grade': last_grade,
    'grade_trajectory': grade_trajectory,
    'tribunal_ballots': tribunal_ballots,
    'termination_reason': termination_reason,
    'status': status
}

print(json.dumps(result))
"
}

# ==============================================================================
# extract_rl_signals — Extract RL feedback signals from a session event log
# ==============================================================================
# Usage: extract_rl_signals <session_id> <session_dir>
#
# Connects session outcomes to specific skills/models via event log analysis.
# Returns JSON with:
#   outcome (success/failure), skills_used array, models_used array,
#   total_tokens, final_grade
#
# Arguments:
#   session_id  — Session identifier
#   session_dir — Directory containing events.jsonl
#
# Outputs: JSON object to stdout
# Returns: 0 on success, 1 on failure
extract_rl_signals() {
    local session_id="$1"
    local session_dir="$2"

    local log_file="${session_dir}/events.jsonl"

    # Handle missing or empty log file
    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        jq -n '{
            outcome: "failure",
            skills_used: [],
            models_used: [],
            total_tokens: 0,
            final_grade: 0
        }'
        return 0
    fi

    python3 -c "
import json

log_file = '$log_file'

events = []
for line in open(log_file):
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except:
        continue

# Determine outcome from the last decision event with terminate
outcome = 'failure'
final_grade = 0
skills_used = set()
models_used = set()
total_tokens = 0

for e in events:
    etype = e.get('event_type', '')
    metadata = e.get('metadata', {})

    # Extract termination outcome
    if etype == 'decision':
        if metadata.get('next_action') == 'terminate':
            reason = metadata.get('reason', 'unknown')
            if reason in ('success', 'converged'):
                outcome = 'success'
            else:
                outcome = 'failure'

    # Extract grade
    if etype == 'grade':
        grade_val = metadata.get('composite_grade')
        if grade_val is not None:
            final_grade = grade_val

    # Extract models and tokens from tool_invocation events
    if etype == 'tool_invocation':
        model = metadata.get('model')
        if model:
            models_used.add(model)
        tokens = metadata.get('tokens', 0)
        if tokens:
            total_tokens += int(tokens)

    # Extract skills from tool field
    if etype == 'tool_invocation':
        tool = metadata.get('tool')
        if tool:
            skills_used.add(tool)

result = {
    'outcome': outcome,
    'skills_used': sorted(list(skills_used)),
    'models_used': sorted(list(models_used)),
    'total_tokens': total_tokens,
    'final_grade': final_grade
}

print(json.dumps(result))
"
}

# ==============================================================================
# generate_audit_trail — Produce chronological audit trail of autonomous actions
# ==============================================================================
# Usage: generate_audit_trail <session_id> <session_dir>
#
# Produces a chronological JSON array of all autonomous actions (action,
# tool_invocation, decision event types) for security review. Each entry has
# timestamp, event_type, and action description.
#
# Arguments:
#   session_id  — Session identifier
#   session_dir — Directory containing events.jsonl
#
# Outputs: JSON array to stdout
# Returns: 0 on success, 1 on failure
generate_audit_trail() {
    local session_id="$1"
    local session_dir="$2"

    local log_file="${session_dir}/events.jsonl"

    # Handle missing or empty log file
    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        echo "[]"
        return 0
    fi

    python3 -c "
import json

log_file = '$log_file'

events = []
for line in open(log_file):
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except:
        continue

# Filter to autonomous action types only
audit_types = {'action', 'tool_invocation', 'decision'}
audit_trail = []

for e in events:
    etype = e.get('event_type', '')
    if etype in audit_types:
        entry = {
            'timestamp': e.get('timestamp', ''),
            'event_type': etype,
            'action': e.get('content', ''),
            'iteration': e.get('iteration', 0),
            'metadata': e.get('metadata', {})
        }
        audit_trail.append(entry)

# Already in chronological order (append-only log)
print(json.dumps(audit_trail))
"
}

# ==============================================================================
# generate_session_report — Produce session report JSON from event log
# ==============================================================================
# Usage: generate_session_report <session_id> <session_dir>
#
# Reads the full event log and produces a JSON object with:
#   iteration_count, grade_trajectory, tribunal_decisions,
#   resources_consumed (tokens_by_model, cost_by_model),
#   wall_clock_seconds, code_changes (files_modified, lines_added, lines_removed),
#   termination_reason
#
# Arguments:
#   session_id  — Session identifier
#   session_dir — Directory containing events.jsonl
#
# Outputs: JSON object to stdout
# Returns: 0 on success, 1 on failure
generate_session_report() {
    local session_id="$1"
    local session_dir="$2"

    local log_file="${session_dir}/events.jsonl"

    # Handle missing or empty log file
    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        jq -n \
            --arg session_id "$session_id" \
            '{
                session_id: $session_id,
                iteration_count: 0,
                grade_trajectory: [],
                tribunal_decisions: [],
                resources_consumed: {
                    tokens_by_model: {},
                    cost_by_model: {}
                },
                wall_clock_seconds: 0,
                code_changes: {
                    files_modified: 0,
                    lines_added: 0,
                    lines_removed: 0
                },
                termination_reason: null
            }'
        return 0
    fi

    python3 -c "
import json
from datetime import datetime

log_file = '$log_file'
session_id = '$session_id'

events = []
for line in open(log_file):
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except:
        continue

# Compute iteration count
max_iteration = 0
for e in events:
    iteration = e.get('iteration', 0)
    if iteration > max_iteration:
        max_iteration = iteration

# Grade trajectory: one grade per iteration from grade events
grades_by_iter = {}
for e in events:
    if e.get('event_type') == 'grade':
        meta = e.get('metadata', {})
        grade_val = meta.get('composite_grade')
        iteration = e.get('iteration', 0)
        if grade_val is not None:
            grades_by_iter[iteration] = grade_val

grade_trajectory = [grades_by_iter[i] for i in sorted(grades_by_iter.keys())]

# Tribunal decisions from vote events
tribunal_decisions = []
for e in events:
    if e.get('event_type') == 'vote':
        meta = e.get('metadata', {})
        decision = {
            'iteration': e.get('iteration', 0),
            'ballot': meta.get('ballot', {}),
            'verdict': meta.get('verdict', ''),
            'consensus': meta.get('confidence', meta.get('consensus', '')),
            'weighted_score': meta.get('weighted_score', 0)
        }
        tribunal_decisions.append(decision)

# Resources consumed: tokens and cost by model
tokens_by_model = {}
cost_by_model = {}
for e in events:
    if e.get('event_type') == 'tool_invocation':
        meta = e.get('metadata', {})
        model = meta.get('model', 'unknown')
        tokens = meta.get('tokens', 0)
        cost = meta.get('cost', 0)
        if tokens:
            tokens_by_model[model] = tokens_by_model.get(model, 0) + int(tokens)
        if cost:
            cost_by_model[model] = cost_by_model.get(model, 0) + float(cost)

# Wall-clock time
wall_clock_seconds = 0
if len(events) >= 2:
    try:
        fmt = '%Y-%m-%dT%H:%M:%SZ'
        first_ts = datetime.strptime(events[0]['timestamp'], fmt)
        last_ts = datetime.strptime(events[-1]['timestamp'], fmt)
        wall_clock_seconds = max(0, (last_ts - first_ts).total_seconds())
    except:
        wall_clock_seconds = 0

# Code changes: aggregate from action events
all_files = set()
total_lines_added = 0
total_lines_removed = 0
for e in events:
    if e.get('event_type') == 'action':
        meta = e.get('metadata', {})
        files = meta.get('files_modified', [])
        if isinstance(files, list):
            all_files.update(files)
        lines_added = meta.get('lines_added', 0)
        lines_removed = meta.get('lines_removed', 0)
        if lines_added:
            total_lines_added += int(lines_added)
        if lines_removed:
            total_lines_removed += int(lines_removed)

# Termination reason from last decision event
termination_reason = None
for e in reversed(events):
    if e.get('event_type') == 'decision':
        meta = e.get('metadata', {})
        if meta.get('next_action') == 'terminate':
            termination_reason = meta.get('reason', 'unknown')
            break

result = {
    'session_id': session_id,
    'iteration_count': max_iteration,
    'grade_trajectory': grade_trajectory,
    'tribunal_decisions': tribunal_decisions,
    'resources_consumed': {
        'tokens_by_model': tokens_by_model,
        'cost_by_model': cost_by_model
    },
    'wall_clock_seconds': wall_clock_seconds,
    'code_changes': {
        'files_modified': len(all_files),
        'lines_added': total_lines_added,
        'lines_removed': total_lines_removed
    },
    'termination_reason': termination_reason
}

print(json.dumps(result))
"
}
