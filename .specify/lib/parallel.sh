#!/usr/bin/env bash
# T020: Parallel Agent Execution Library
# Sprint 3: Enable concurrent task execution for independent agents
# Constitutional Principle VII: Structured logging integrated

# ==============================================================================
# Load Dependencies
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Source logging library
if [[ -f "$REPO_ROOT/.specify/lib/logging.sh" ]]; then
    source "$REPO_ROOT/.specify/lib/logging.sh"
else
    log_error() { echo "[ERROR] $1" >&2; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_info() { echo "[INFO] $1" >&2; }
    log_debug() { echo "[DEBUG] $1" >&2; }
fi

# ==============================================================================
# Parallel Execution State Management
# ==============================================================================

# Directory for storing parallel execution state
PARALLEL_STATE_DIR="${REPO_ROOT}/.specify/logs/parallel-execution"
mkdir -p "$PARALLEL_STATE_DIR"

# ==============================================================================
# Parallel Agent Launching
# ==============================================================================

# Launch agents in parallel
# Usage: launch_agents_parallel "agent1:task1" "agent2:task2" ...
launch_agents_parallel() {
    local agents=("$@")
    local session_id="parallel-$(date +%s)-$$"
    local session_dir="$PARALLEL_STATE_DIR/$session_id"

    mkdir -p "$session_dir"

    log_info "Launching parallel agent execution" "{\"session_id\":\"$session_id\",\"agent_count\":${#agents[@]}}"

    # Track PIDs and agent names
    local -a pids=()
    local -a agent_names=()

    # Launch each agent in background
    for agent_spec in "${agents[@]}"; do
        local agent_name="${agent_spec%%:*}"
        local task_desc="${agent_spec#*:}"

        log_debug "Launching agent" "{\"agent\":\"$agent_name\",\"task\":\"$task_desc\"}"

        # Execute agent in background, redirect output to session file
        (
            local agent_output_file="$session_dir/${agent_name}.out"
            local agent_error_file="$session_dir/${agent_name}.err"
            local agent_status_file="$session_dir/${agent_name}.status"

            # Record start time
            echo "STARTED:$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$agent_status_file"

            # Execute agent task (placeholder - actual implementation would invoke Claude with agent context)
            # For now, simulate with task execution
            echo "Executing: $task_desc" > "$agent_output_file" 2> "$agent_error_file"
            local exit_code=$?

            # Record completion
            echo "COMPLETED:$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$agent_status_file"
            echo "EXIT_CODE:$exit_code" >> "$agent_status_file"

            exit $exit_code
        ) &

        local pid=$!
        pids+=("$pid")
        agent_names+=("$agent_name")

        # Record PID mapping
        echo "$pid:$agent_name" >> "$session_dir/pids.txt"
    done

    # Store session metadata
    cat > "$session_dir/metadata.json" <<EOF
{
  "session_id": "$session_id",
  "start_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "agent_count": ${#agents[@]},
  "pids": [$(printf '"%s",' "${pids[@]}" | sed 's/,$//')],
  "agents": [$(printf '"%s",' "${agent_names[@]}" | sed 's/,$//')]
}
EOF

    log_info "Parallel agents launched" "{\"session_id\":\"$session_id\",\"pids\":[$(printf '"%s",' "${pids[@]}" | sed 's/,$//')]}}"

    # Return session ID for result collection
    echo "$session_id"
}

# ==============================================================================
# Wait for Parallel Completion
# ==============================================================================

# Wait for all parallel agents to complete
# Usage: wait_for_parallel_completion <session_id> [timeout_seconds]
wait_for_parallel_completion() {
    local session_id="$1"
    local timeout="${2:-300}"  # Default 5 minute timeout
    local session_dir="$PARALLEL_STATE_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        log_error "Session not found" "{\"session_id\":\"$session_id\"}"
        return 1
    fi

    log_info "Waiting for parallel completion" "{\"session_id\":\"$session_id\",\"timeout\":$timeout}"

    # Read PIDs from session
    local -a pids=()
    if [[ -f "$session_dir/pids.txt" ]]; then
        while IFS=: read -r pid agent; do
            pids+=("$pid")
        done < "$session_dir/pids.txt"
    else
        log_error "No PIDs found for session" "{\"session_id\":\"$session_id\"}"
        return 1
    fi

    # Wait for all PIDs with timeout
    local start_time=$(date +%s)
    local all_completed=false

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # Check timeout
        if [[ $elapsed -ge $timeout ]]; then
            log_warn "Parallel execution timeout" "{\"session_id\":\"$session_id\",\"elapsed\":$elapsed,\"timeout\":$timeout}"

            # Kill remaining processes
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    log_warn "Killing process due to timeout" "{\"pid\":$pid}"
                    kill -TERM "$pid" 2>/dev/null || true
                fi
            done

            return 124  # Timeout exit code
        fi

        # Check if all processes completed
        local all_done=true
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=false
                break
            fi
        done

        if [[ "$all_done" == "true" ]]; then
            all_completed=true
            break
        fi

        # Sleep briefly before checking again
        sleep 1
    done

    # Collect exit codes
    local -a exit_codes=()
    local failed_count=0

    for pid in "${pids[@]}"; do
        # Wait for specific PID and capture exit code
        wait "$pid" 2>/dev/null
        local exit_code=$?
        exit_codes+=("$exit_code")

        if [[ $exit_code -ne 0 ]]; then
            ((failed_count++))
        fi
    done

    # Update session metadata with completion
    local metadata_file="$session_dir/metadata.json"
    if [[ -f "$metadata_file" ]]; then
        # Parse and update JSON (simple append to file)
        cat >> "$metadata_file" <<EOF

{
  "end_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration_seconds": $elapsed,
  "exit_codes": [$(printf '%s,' "${exit_codes[@]}" | sed 's/,$//')],
  "failed_count": $failed_count,
  "success_count": $((${#pids[@]} - failed_count))
}
EOF
    fi

    log_info "Parallel execution completed" "{\"session_id\":\"$session_id\",\"duration\":$elapsed,\"failed\":$failed_count,\"success\":$((${#pids[@]} - failed_count))}"

    # Return failure if any agent failed
    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# ==============================================================================
# Result Collection
# ==============================================================================

# Collect results from parallel execution
# Usage: collect_parallel_results <session_id>
collect_parallel_results() {
    local session_id="$1"
    local session_dir="$PARALLEL_STATE_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        log_error "Session not found" "{\"session_id\":\"$session_id\"}"
        return 1
    fi

    log_info "Collecting parallel results" "{\"session_id\":\"$session_id\"}"

    echo "=========================================="
    echo "Parallel Execution Results: $session_id"
    echo "=========================================="
    echo ""

    # Read metadata
    if [[ -f "$session_dir/metadata.json" ]]; then
        echo "Session Metadata:"
        cat "$session_dir/metadata.json"
        echo ""
    fi

    # Collect output from each agent
    for output_file in "$session_dir"/*.out; do
        if [[ -f "$output_file" ]]; then
            local agent_name=$(basename "$output_file" .out)
            local status_file="$session_dir/${agent_name}.status"
            local error_file="$session_dir/${agent_name}.err"

            echo "----------------------------------------"
            echo "Agent: $agent_name"
            echo "----------------------------------------"

            if [[ -f "$status_file" ]]; then
                echo "Status:"
                cat "$status_file"
                echo ""
            fi

            echo "Output:"
            cat "$output_file"
            echo ""

            if [[ -f "$error_file" && -s "$error_file" ]]; then
                echo "Errors:"
                cat "$error_file"
                echo ""
            fi
        fi
    done

    echo "=========================================="
}

# ==============================================================================
# Cleanup
# ==============================================================================

# Clean up old parallel execution sessions
# Usage: cleanup_parallel_sessions [days]
cleanup_parallel_sessions() {
    local days="${1:-7}"  # Default: clean sessions older than 7 days

    log_info "Cleaning up parallel sessions" "{\"days\":$days}"

    local deleted_count=0

    find "$PARALLEL_STATE_DIR" -maxdepth 1 -type d -name "parallel-*" -mtime +"$days" | while read -r session_dir; do
        local session_id=$(basename "$session_dir")
        log_debug "Removing old session" "{\"session_id\":\"$session_id\"}"
        rm -rf "$session_dir"
        ((deleted_count++))
    done

    if [[ $deleted_count -eq 0 ]]; then
        echo "No old sessions to clean up"
    else
        echo "Cleaned up $deleted_count session(s)"
    fi

    log_info "Parallel sessions cleaned" "{\"deleted\":$deleted_count}"
}

# ==============================================================================
# Parallel Execution Helpers
# ==============================================================================

# Check if tasks can be executed in parallel
# Usage: can_run_parallel "task1" "task2" ...
can_run_parallel() {
    # Simple heuristic: tasks are parallel if they don't modify the same file
    # This would need more sophisticated logic in real implementation

    local tasks=("$@")

    # For now, assume tasks can run in parallel if they're in different files
    # Real implementation would parse task descriptions for file paths

    log_debug "Checking parallel eligibility" "{\"task_count\":${#tasks[@]}}"

    # Placeholder: return success (can parallelize)
    return 0
}

# ==============================================================================
# Example Usage (commented out)
# ==============================================================================

# # Launch parallel agents
# session_id=$(launch_agents_parallel \
#     "backend-architect:Implement API endpoint" \
#     "frontend-specialist:Build UI component" \
#     "testing-specialist:Write integration tests")
#
# # Wait for completion (5 minute timeout)
# if wait_for_parallel_completion "$session_id" 300; then
#     echo "All agents completed successfully"
#     collect_parallel_results "$session_id"
# else
#     echo "Some agents failed or timed out"
#     collect_parallel_results "$session_id"
#     exit 1
# fi

log_debug "parallel.sh loaded" "{\"state_dir\":\"$PARALLEL_STATE_DIR\"}"
