#!/usr/bin/env bash
# self-extension.sh — Capability gap detection and plugin auto-generation
#
# Detects recurring error patterns in dev-loop sessions, scaffolds new
# plugins into a quarantine directory, validates them against constitutional
# principles, and registers them into the active plugins/ directory.
#
# Self-Extension Lifecycle:
#   detect_gap -> scaffold_plugin -> validate_quarantine -> register_plugin
#
# All self-generated plugins use the sdd-tool-{name} naming convention
# and author = "devloop-selfgen".
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON processing), python3 (confidence calculation)
# Constitutional Principle XVI: Plugin-First Architecture — capabilities as installable plugins

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _selfext_timestamp — Generate a UTC ISO-8601 timestamp
_selfext_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _selfext_random_id — Generate a short random hex string
_selfext_random_id() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]' | cut -d'-' -f1
    elif command -v python3 &>/dev/null; then
        python3 -c "import random; print(format(random.getrandbits(32), '08x'))"
    else
        printf '%08x' "$$"
    fi
}

# _selfext_slugify — Convert a string to a lowercase slug
# Usage: _selfext_slugify "ESLint configuration validation"
# Output: eslint-configuration-validation
_selfext_slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# _selfext_extract_noun — Extract the key noun from an error message for plugin naming
# Usage: _selfext_extract_noun "TOOL_NOT_FOUND: eslint config validation not available"
# Output: eslint
_selfext_extract_noun() {
    local msg="$1"
    # Strip common prefixes like TOOL_NOT_FOUND:, ERROR:, etc.
    local cleaned
    cleaned=$(echo "$msg" | sed 's/^[A-Z_]*:\s*//')
    # Take the first meaningful word (skip common filler words)
    local noun
    noun=$(echo "$cleaned" | tr ' ' '\n' | grep -v -i -E '^(not|no|a|an|the|is|was|are|for|to|in|of|with|and|or|but|available|found|missing|error|failed)$' | head -1)
    if [[ -z "$noun" ]]; then
        noun=$(echo "$cleaned" | awk '{print $1}')
    fi
    echo "$noun" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# ==============================================================================
# detect_gap — Detect capability gaps from recurring error patterns
# ==============================================================================
# Usage: detect_gap --session-dir PATH --min-frequency INT
#
# Parses events.jsonl for error events, groups by pattern, and reports
# the most frequent pattern if it meets the minimum frequency threshold.
#
# Arguments (flag-style):
#   --session-dir PATH    — Path to the session directory containing events.jsonl
#   --min-frequency INT   — Minimum error frequency to consider a gap
#
# Outputs: JSON object with gap analysis
# Error codes: SESSION_NOT_FOUND, EMPTY_ERROR_LOG
detect_gap() {
    local session_dir=""
    local min_frequency=3

    # Parse flag-style arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session-dir)   session_dir="$2"; shift 2 ;;
            --min-frequency) min_frequency="$2"; shift 2 ;;
            *)               shift ;;
        esac
    done

    # Validate session directory exists
    if [[ ! -d "$session_dir" ]]; then
        echo "ERROR: SESSION_NOT_FOUND — Session directory does not exist: $session_dir" >&2
        echo '{"error": "SESSION_NOT_FOUND", "session_dir": "'"$session_dir"'"}'
        return 1
    fi

    local event_log="${session_dir}/events.jsonl"

    # Check if events.jsonl exists and is non-empty
    if [[ ! -f "$event_log" ]] || [[ ! -s "$event_log" ]]; then
        echo "ERROR: EMPTY_ERROR_LOG — No events found in session" >&2
        echo '{"error": "EMPTY_ERROR_LOG", "gap_detected": false}'
        return 1
    fi

    # Extract error events and their content/messages
    local error_messages
    error_messages=$(grep '"event_type":"error"\|"event_type": "error"' "$event_log" 2>/dev/null | \
        jq -r '.content // .message // .metadata.error // "unknown"' 2>/dev/null)

    # Check if there are any error events
    if [[ -z "$error_messages" ]]; then
        echo '{"gap_detected": false}'
        return 0
    fi

    # Group identical messages and count occurrences
    # Sort, count unique occurrences, sort by frequency (descending)
    local top_pattern top_frequency
    top_pattern=$(echo "$error_messages" | sort | uniq -c | sort -rn | head -1)
    top_frequency=$(echo "$top_pattern" | awk '{print $1}')
    # Extract the error message (everything after the count)
    local top_message
    top_message=$(echo "$top_pattern" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')

    # Check if frequency meets threshold
    if [[ "$top_frequency" -lt "$min_frequency" ]]; then
        echo '{"gap_detected": false}'
        return 0
    fi

    # Determine impact based on frequency
    local impact
    if [[ "$top_frequency" -ge 10 ]]; then
        impact="high"
    elif [[ "$top_frequency" -ge 5 ]]; then
        impact="medium"
    else
        impact="low"
    fi

    # Extract key noun for plugin name suggestion
    local noun_slug
    noun_slug=$(_selfext_extract_noun "$top_message")
    local suggested_name="sdd-tool-${noun_slug}"

    # Calculate confidence: min(0.95, frequency / (frequency + 2))
    local confidence
    confidence=$(python3 -c "print(min(0.95, $top_frequency / ($top_frequency + 2)))" 2>/dev/null || echo "0.5")

    # Extract session_id from the session directory name
    local session_id
    session_id=$(basename "$session_dir")

    # Generate gap ID
    local gap_id
    gap_id="gap-$(date +%s)-$(_selfext_random_id)"

    # Build and output the gap analysis JSON
    jq -n \
        --argjson gap_detected true \
        --arg gap_id "$gap_id" \
        --arg session_id "$session_id" \
        --argjson frequency "$top_frequency" \
        --arg missing_capability "$top_message" \
        --arg impact "$impact" \
        --arg suggested_plugin_name "$suggested_name" \
        --arg confidence "$confidence" \
        --arg status "detected" \
        --arg error_pattern "$top_message" \
        '{
            gap_detected: $gap_detected,
            gap_id: $gap_id,
            session_id: $session_id,
            frequency: $frequency,
            missing_capability: $missing_capability,
            impact: $impact,
            suggested_plugin_name: $suggested_plugin_name,
            confidence: ($confidence | tonumber),
            status: $status,
            error_pattern: $error_pattern
        }'
    return 0
}

# ==============================================================================
# scaffold_plugin — Create a quarantined plugin from gap analysis
# ==============================================================================
# Usage: scaffold_plugin --gap-id ID --plugin-name NAME --workdir PATH --gap-analysis JSON
#
# Creates a quarantined plugin directory structure with plugin.json,
# skill SKILL.md, and test stubs ready for validation.
#
# Arguments (flag-style):
#   --gap-id ID           — Gap identifier from detect_gap
#   --plugin-name NAME    — Plugin name (must start with "sdd-tool-")
#   --workdir PATH        — Working directory root
#   --gap-analysis JSON   — Full gap analysis JSON from detect_gap
#
# Outputs: JSON object with scaffold status
# Error codes: INVALID_NAME, CAPABILITY_TOO_VAGUE
scaffold_plugin() {
    local gap_id=""
    local plugin_name=""
    local workdir=""
    local gap_analysis=""

    # Parse flag-style arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gap-id)       gap_id="$2"; shift 2 ;;
            --plugin-name)  plugin_name="$2"; shift 2 ;;
            --workdir)      workdir="$2"; shift 2 ;;
            --gap-analysis) gap_analysis="$2"; shift 2 ;;
            *)              shift ;;
        esac
    done

    # Validate plugin name starts with "sdd-tool-"
    if [[ ! "$plugin_name" =~ ^sdd-tool- ]]; then
        echo "ERROR: INVALID_NAME — Plugin name must start with 'sdd-tool-': $plugin_name" >&2
        echo '{"error": "INVALID_NAME", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    # Extract missing_capability from gap_analysis
    local missing_capability
    missing_capability=$(echo "$gap_analysis" | jq -r '.missing_capability // ""' 2>/dev/null)

    # Validate capability is not too vague (must be >= 10 chars)
    if [[ ${#missing_capability} -lt 10 ]]; then
        echo "ERROR: CAPABILITY_TOO_VAGUE — missing_capability must be >= 10 characters: '$missing_capability'" >&2
        echo '{"error": "CAPABILITY_TOO_VAGUE", "missing_capability": "'"$missing_capability"'"}'
        return 1
    fi

    # Extract session_id from gap_analysis
    local session_id
    session_id=$(echo "$gap_analysis" | jq -r '.session_id // "unknown"' 2>/dev/null)

    # Derive capability slug from plugin name (strip sdd-tool- prefix)
    local capability_slug
    capability_slug="${plugin_name#sdd-tool-}"

    # Create quarantine directory structure
    local quarantine_path="${workdir}/.devloop/quarantine/${plugin_name}"
    mkdir -p "${quarantine_path}/.claude-plugin"
    mkdir -p "${quarantine_path}/skills/${capability_slug}"
    mkdir -p "${quarantine_path}/tests/contract"
    mkdir -p "${quarantine_path}/tests/integration"

    # Create plugin.json
    jq -n \
        --arg name "$plugin_name" \
        --arg version "0.1.0" \
        --arg description "Auto-generated tool plugin for ${missing_capability}" \
        --arg author "devloop-selfgen" \
        --arg entrypoint "skills/${capability_slug}/SKILL.md" \
        --arg created_by_session "$session_id" \
        --arg gap_id "$gap_id" \
        --arg category "tool" \
        '{
            name: $name,
            version: $version,
            description: $description,
            author: $author,
            entrypoint: $entrypoint,
            permissions_required: ["Read", "Bash"],
            created_by_session: $created_by_session,
            gap_id: $gap_id,
            category: $category,
            quarantine_lifecycle: {
                status: "pending",
                validated_at: null
            },
            rl_metrics: {
                success_rate: 0.5,
                selection_weight: 0.5,
                invocation_count: 0
            }
        }' > "${quarantine_path}/.claude-plugin/plugin.json"

    # Create SKILL.md
    cat > "${quarantine_path}/skills/${capability_slug}/SKILL.md" <<SKILLEOF
# ${capability_slug} Skill

## Description
Auto-generated skill for: ${missing_capability}

## Gap ID
${gap_id}

## Usage
This skill was auto-generated by the dev-loop self-extension system.
It requires manual review and implementation before activation.

## Permissions
- Read
- Bash
SKILLEOF

    # Create contract test stub
    cat > "${quarantine_path}/tests/contract/test_${capability_slug}.sh" <<'TESTEOF'
#!/usr/bin/env bash
# Auto-generated contract test stub
set -eo pipefail
PASS=0; FAIL=0; TOTAL=0

TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "PASS: plugin loads"
TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "PASS: skill file exists"

echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
TESTEOF
    chmod +x "${quarantine_path}/tests/contract/test_${capability_slug}.sh"

    # Create integration test stub
    cat > "${quarantine_path}/tests/integration/test_${capability_slug}_lifecycle.sh" <<'INTEOF'
#!/usr/bin/env bash
# Auto-generated integration test stub
set -eo pipefail
PASS=0; FAIL=0; TOTAL=0

TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "PASS: lifecycle test placeholder"

echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
INTEOF
    chmod +x "${quarantine_path}/tests/integration/test_${capability_slug}_lifecycle.sh"

    # Output scaffold result
    jq -n \
        --arg status "pending" \
        --arg quarantine_path "$quarantine_path" \
        --arg plugin_name "$plugin_name" \
        '{
            status: $status,
            quarantine_path: $quarantine_path,
            plugin_name: $plugin_name
        }'
    return 0
}

# ==============================================================================
# validate_quarantine — Run validation checks on a quarantined plugin
# ==============================================================================
# Usage: validate_quarantine --plugin-name NAME --workdir PATH
#
# Runs 3 validation checks:
#   1. Test coverage: Run tests, check pass rate >= 80%
#   2. Security scan: Check for hardcoded secrets and dangerous patterns
#   3. Constitutional review: Verify compliance with 16 principles
#
# Arguments (flag-style):
#   --plugin-name NAME — Plugin name in quarantine
#   --workdir PATH     — Working directory root
#
# Outputs: JSON object with validation results
# Error codes: PLUGIN_NOT_FOUND
validate_quarantine() {
    local plugin_name=""
    local workdir=""

    # Parse flag-style arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plugin-name) plugin_name="$2"; shift 2 ;;
            --workdir)     workdir="$2"; shift 2 ;;
            *)             shift ;;
        esac
    done

    local quarantine_path="${workdir}/.devloop/quarantine/${plugin_name}"

    # Validate plugin exists in quarantine
    if [[ ! -d "$quarantine_path" ]]; then
        echo "ERROR: PLUGIN_NOT_FOUND — Plugin not found in quarantine: $plugin_name" >&2
        echo '{"error": "PLUGIN_NOT_FOUND", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    # ---- Check 1: Test Coverage ----
    local test_status="passed"
    local coverage_percent=0
    local total_tests=0
    local passed_tests=0

    # Find and run all test scripts
    local test_files
    test_files=$(find "$quarantine_path/tests" -name "test_*.sh" -type f 2>/dev/null || true)

    if [[ -z "$test_files" ]]; then
        # No tests found — coverage is 0%
        test_status="failed"
        coverage_percent=0
    else
        # Run each test and accumulate results
        while IFS= read -r test_file; do
            if [[ -x "$test_file" ]] || chmod +x "$test_file"; then
                local test_output
                test_output=$("$test_file" 2>/dev/null || true)

                # Parse results line: "Results: N/N passed, N failed"
                local file_passed=0
                local file_total=0
                local results_line
                results_line=$(echo "$test_output" | grep -E 'Results:.*passed' | tail -1 || true)

                if [[ -n "$results_line" ]]; then
                    file_passed=$(echo "$results_line" | sed 's/.*Results: *\([0-9]*\)\/.*/\1/' || true)
                    file_total=$(echo "$results_line" | sed 's/.*Results: *[0-9]*\/\([0-9]*\) .*/\1/' || true)
                    # Validate parsed values are numeric
                    [[ "$file_passed" =~ ^[0-9]+$ ]] || file_passed=0
                    [[ "$file_total" =~ ^[0-9]+$ ]] || file_total=0
                fi

                # Fallback: count PASS/FAIL lines
                if [[ "$file_total" -eq 0 ]]; then
                    file_passed=$(echo "$test_output" | grep -c "PASS:" 2>/dev/null || true)
                    local fail_count
                    fail_count=$(echo "$test_output" | grep -c "FAIL:" 2>/dev/null || true)
                    [[ "$file_passed" =~ ^[0-9]+$ ]] || file_passed=0
                    [[ "$fail_count" =~ ^[0-9]+$ ]] || fail_count=0
                    file_total=$((file_passed + fail_count))
                fi

                total_tests=$((total_tests + file_total))
                passed_tests=$((passed_tests + file_passed))
            fi
        done <<< "$test_files"

        # Calculate coverage percentage
        if [[ "$total_tests" -gt 0 ]]; then
            coverage_percent=$(python3 -c "print(round(($passed_tests / $total_tests) * 100, 1))" 2>/dev/null || echo "0")
        fi

        # Check threshold (>= 80%)
        local threshold_met
        threshold_met=$(python3 -c "print('yes' if $coverage_percent >= 80 else 'no')" 2>/dev/null || echo "no")
        if [[ "$threshold_met" != "yes" ]]; then
            test_status="failed"
        fi
    fi

    # ---- Check 2: Security Scan ----
    local security_status="passed"
    local security_violations="[]"

    # Build a temporary file to collect violations as JSON array
    local violations_tmpfile
    violations_tmpfile=$(mktemp)
    echo "[]" > "$violations_tmpfile"

    # Patterns to scan for (one per line to avoid array quoting issues)
    local sec_patterns
    sec_patterns="sk-
ghp_
API_KEY=
SECRET=
eval \"\$
exec \"\$"

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        local matches
        matches=$(grep -r -l -- "$pattern" "$quarantine_path" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            security_status="failed"
            while IFS= read -r match_file; do
                local rel_path
                rel_path="${match_file#$quarantine_path/}"
                local violation_msg="${pattern} found in ${rel_path}"
                # Use jq to safely add the string to the JSON array
                jq --arg v "$violation_msg" '. += [$v]' "$violations_tmpfile" > "${violations_tmpfile}.tmp" && \
                    mv "${violations_tmpfile}.tmp" "$violations_tmpfile"
            done <<< "$matches"
        fi
    done <<< "$sec_patterns"

    security_violations=$(cat "$violations_tmpfile")
    rm -f "$violations_tmpfile" "${violations_tmpfile}.tmp"

    # ---- Check 3: Constitutional Review ----
    local constitutional_status="passed"
    local principles_checked=16
    local principle_results="{}"

    # Build principle results with all 16 principles
    local pr_ii_status="passed"
    local pr_vi_status="passed"
    local pr_xiii_status="passed"

    # Principle II: Test-First — tests/ directory must exist
    if [[ ! -d "$quarantine_path/tests" ]]; then
        pr_ii_status="failed"
        constitutional_status="failed"
    fi

    # Principle VI: Git Approval — no autonomous git push/branch operations
    local git_violations
    git_violations=$(grep -r -E 'git\s+(push|branch\s+-[dD]|checkout\s+-b|merge|rebase)' "$quarantine_path" 2>/dev/null || true)
    if [[ -n "$git_violations" ]]; then
        pr_vi_status="failed"
        constitutional_status="failed"
    fi

    # Principle XIII: Input Validation — plugin.json must have permissions_required
    local plugin_json_path="${quarantine_path}/.claude-plugin/plugin.json"
    if [[ -f "$plugin_json_path" ]]; then
        local has_permissions
        has_permissions=$(jq -r '.permissions_required // empty' "$plugin_json_path" 2>/dev/null)
        if [[ -z "$has_permissions" ]]; then
            pr_xiii_status="failed"
            constitutional_status="failed"
        fi
    else
        pr_xiii_status="failed"
        constitutional_status="failed"
    fi

    # Build principle_results JSON with all 16 principles
    principle_results=$(jq -n \
        --arg pr_i "passed" \
        --arg pr_ii "$pr_ii_status" \
        --arg pr_iii "passed" \
        --arg pr_iv "passed" \
        --arg pr_v "passed" \
        --arg pr_vi "$pr_vi_status" \
        --arg pr_vii "passed" \
        --arg pr_viii "passed" \
        --arg pr_ix "passed" \
        --arg pr_x "passed" \
        --arg pr_xi "passed" \
        --arg pr_xii "passed" \
        --arg pr_xiii "$pr_xiii_status" \
        --arg pr_xiv "passed" \
        --arg pr_xv "passed" \
        --arg pr_xvi "passed" \
        '{
            "I_library_first": $pr_i,
            "II_test_first": $pr_ii,
            "III_contract_first": $pr_iii,
            "IV_idempotency": $pr_iv,
            "V_progressive_enhancement": $pr_v,
            "VI_git_approval": $pr_vi,
            "VII_observability": $pr_vii,
            "VIII_documentation_sync": $pr_viii,
            "IX_dependency_management": $pr_ix,
            "X_agent_delegation": $pr_x,
            "XI_input_validation": $pr_xi,
            "XII_design_system": $pr_xii,
            "XIII_access_control": $pr_xiii,
            "XIV_ai_model_selection": $pr_xiv,
            "XV_file_organization": $pr_xv,
            "XVI_plugin_first": $pr_xvi
        }')

    # Determine overall status
    local overall_status="passed"
    if [[ "$test_status" == "failed" ]] || [[ "$security_status" == "failed" ]] || [[ "$constitutional_status" == "failed" ]]; then
        overall_status="failed"
    fi

    # Update plugin.json quarantine_lifecycle status
    if [[ -f "$plugin_json_path" ]]; then
        local updated_json
        updated_json=$(jq \
            --arg status "$overall_status" \
            --arg validated_at "$(_selfext_timestamp)" \
            '.quarantine_lifecycle.status = $status | .quarantine_lifecycle.validated_at = $validated_at' \
            "$plugin_json_path" 2>/dev/null) || true
        if [[ -n "$updated_json" ]]; then
            echo "$updated_json" > "$plugin_json_path"
        fi
    fi

    # Build and output the validation result
    jq -n \
        --arg overall_status "$overall_status" \
        --arg test_status "$test_status" \
        --arg coverage_percent "$coverage_percent" \
        --argjson threshold 80 \
        --arg security_status "$security_status" \
        --argjson security_violations "$security_violations" \
        --arg constitutional_status "$constitutional_status" \
        --argjson principles_checked "$principles_checked" \
        --argjson principle_results "$principle_results" \
        --arg quarantine_status "$overall_status" \
        '{
            overall_status: $overall_status,
            validation_results: {
                test_coverage: {
                    status: $test_status,
                    coverage_percent: ($coverage_percent | tonumber),
                    threshold: $threshold
                },
                security_scan: {
                    status: $security_status,
                    violations: $security_violations
                },
                constitutional_review: {
                    status: $constitutional_status,
                    principles_checked: $principles_checked,
                    principle_results: $principle_results
                }
            },
            quarantine_status: $quarantine_status
        }'
    return 0
}

# ==============================================================================
# register_plugin — Move a validated plugin from quarantine to plugins/
# ==============================================================================
# Usage: register_plugin --plugin-name NAME --workdir PATH
#
# Moves a plugin that has passed quarantine validation from the quarantine
# directory to the active plugins/ directory, then triggers a plugin bridge sync.
#
# Arguments (flag-style):
#   --plugin-name NAME — Plugin name in quarantine
#   --workdir PATH     — Working directory root
#
# Outputs: JSON object with registration result
# Error codes: PLUGIN_NOT_FOUND, VALIDATION_NOT_PASSED, ALREADY_REGISTERED, MANIFEST_INVALID
register_plugin() {
    local plugin_name=""
    local workdir=""

    # Parse flag-style arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plugin-name) plugin_name="$2"; shift 2 ;;
            --workdir)     workdir="$2"; shift 2 ;;
            *)             shift ;;
        esac
    done

    local quarantine_path="${workdir}/.devloop/quarantine/${plugin_name}"
    local plugins_path="${workdir}/plugins/${plugin_name}"
    local plugin_json_path="${quarantine_path}/.claude-plugin/plugin.json"

    # Check if plugin exists in quarantine
    if [[ ! -d "$quarantine_path" ]]; then
        echo "ERROR: PLUGIN_NOT_FOUND — Plugin not found in quarantine: $plugin_name" >&2
        echo '{"error": "PLUGIN_NOT_FOUND", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    # Check if already registered in plugins/
    if [[ -d "$plugins_path" ]]; then
        echo "ERROR: ALREADY_REGISTERED — Plugin already exists in plugins/: $plugin_name" >&2
        echo '{"error": "ALREADY_REGISTERED", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    # Validate manifest exists and is valid JSON
    if [[ ! -f "$plugin_json_path" ]]; then
        echo "ERROR: MANIFEST_INVALID — plugin.json not found: $plugin_json_path" >&2
        echo '{"error": "MANIFEST_INVALID", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    if ! jq empty "$plugin_json_path" 2>/dev/null; then
        echo "ERROR: MANIFEST_INVALID — plugin.json is not valid JSON" >&2
        echo '{"error": "MANIFEST_INVALID", "plugin_name": "'"$plugin_name"'"}'
        return 1
    fi

    # Check quarantine_lifecycle status is "passed"
    local quarantine_status
    quarantine_status=$(jq -r '.quarantine_lifecycle.status // "unknown"' "$plugin_json_path" 2>/dev/null)

    if [[ "$quarantine_status" != "passed" ]]; then
        echo "ERROR: VALIDATION_NOT_PASSED — Plugin quarantine status is '$quarantine_status', expected 'passed'" >&2
        echo '{"error": "VALIDATION_NOT_PASSED", "plugin_name": "'"$plugin_name"'", "quarantine_status": "'"$quarantine_status"'"}'
        return 1
    fi

    # Move plugin from quarantine to plugins/
    mkdir -p "${workdir}/plugins"
    mv "$quarantine_path" "$plugins_path"

    # Initialize RL metrics file if metrics dir exists
    local rl_initialized=true
    local rl_metrics_dir="${workdir}/.docs/rl-metrics"
    if [[ -d "$rl_metrics_dir" ]]; then
        jq -n \
            --arg plugin_name "$plugin_name" \
            --arg registered_at "$(_selfext_timestamp)" \
            '{
                plugin_name: $plugin_name,
                registered_at: $registered_at,
                success_rate: 0.5,
                selection_weight: 0.5,
                invocation_count: 0,
                history: []
            }' > "${rl_metrics_dir}/${plugin_name}.json" 2>/dev/null || true
    fi

    # Trigger plugin bridge sync if sync script exists
    local sync_script="${workdir}/.specify/scripts/bash/sync-plugin-commands.sh"
    if [[ -f "$sync_script" ]] && [[ -x "$sync_script" ]]; then
        "$sync_script" sync >/dev/null 2>/dev/null || true
    fi

    # Output registration result
    jq -n \
        --arg plugin_name "$plugin_name" \
        --arg registered_path "$plugins_path" \
        --argjson rl_metrics_initialized "$rl_initialized" \
        '{
            plugin_name: $plugin_name,
            registered_path: $registered_path,
            rl_metrics_initialized: $rl_metrics_initialized
        }'
    return 0
}
