#!/usr/bin/env bash
# scope-detector.sh — Scope detection library for loom-dev-loop plugin
#
# Classifies task descriptions as "tactic" (small, focused) or "strategy"
# (large, cross-cutting) using keyword scoring, file count heuristics,
# and cross-cutting concern detection.
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON processing)
# Constitutional Principle X: Agent Delegation — scope determines workflow routing
# Constitutional Principle XVI: Plugin-First — capability as installable plugin

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Keyword Lists
# ==============================================================================

# Tactic keywords: each match contributes -1.0 to total_score
_SCOPE_TACTIC_KEYWORDS="fix typo rename bump patch tweak adjust update correct hotfix"

# Strategy keywords: each match contributes +1.0 to total_score
_SCOPE_STRATEGY_KEYWORDS="implement architect design migrate redesign integrate overhaul refactor system infrastructure"

# Domain keywords for cross-cutting concern detection
_SCOPE_DOMAIN_KEYWORDS="frontend backend database security api authentication authorization testing performance deployment ui css server endpoint schema migration query"

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _scope_iso8601_now — Get current UTC timestamp in ISO 8601 format
_scope_iso8601_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _scope_generate_id — Generate a scope analysis ID
_scope_generate_id() {
    local timestamp
    timestamp=$(date -u +"%Y%m%d-%H%M%S")
    local hash
    if command -v md5 &>/dev/null; then
        hash=$(echo -n "$1" | md5 | cut -c1-6)
    elif command -v md5sum &>/dev/null; then
        hash=$(echo -n "$1" | md5sum | cut -c1-6)
    else
        hash=$(printf '%06x' $((RANDOM * RANDOM)))
    fi
    echo "scope-${timestamp}-${hash}"
}

# _scope_to_lower — Convert string to lowercase
_scope_to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ==============================================================================
# score_keywords — Score a description against tactic and strategy keywords
# ==============================================================================
# Usage: score_keywords <description>
#
# Tokenizes the description and matches against tactic and strategy keyword lists.
# Tactic keywords contribute -1.0 each, strategy keywords contribute +1.0 each.
#
# Outputs: JSON object with scoring details:
#   {"tactic_total": N, "strategy_total": N, "matched_tactic": [...], "matched_strategy": [...]}
# Returns: 0 on success
score_keywords() {
    local description="$1"
    local lower_desc
    lower_desc=$(_scope_to_lower "$description")

    local tactic_total=0
    local strategy_total=0
    local matched_tactic=()
    local matched_strategy=()

    # Match tactic keywords
    for keyword in $_SCOPE_TACTIC_KEYWORDS; do
        if echo "$lower_desc" | grep -qw "$keyword"; then
            tactic_total=$((tactic_total - 1))
            matched_tactic+=("$keyword")
        fi
    done

    # Match strategy keywords
    for keyword in $_SCOPE_STRATEGY_KEYWORDS; do
        if echo "$lower_desc" | grep -qw "$keyword"; then
            strategy_total=$((strategy_total + 1))
            matched_strategy+=("$keyword")
        fi
    done

    # Build JSON arrays for matched keywords
    local tactic_json="[]"
    if [[ ${#matched_tactic[@]} -gt 0 ]]; then
        tactic_json=$(printf '%s\n' "${matched_tactic[@]}" | jq -R . | jq -s .)
    fi
    local strategy_json="[]"
    if [[ ${#matched_strategy[@]} -gt 0 ]]; then
        strategy_json=$(printf '%s\n' "${matched_strategy[@]}" | jq -R . | jq -s .)
    fi

    jq -n \
        --argjson tactic_total "$tactic_total" \
        --argjson strategy_total "$strategy_total" \
        --argjson matched_tactic "$tactic_json" \
        --argjson matched_strategy "$strategy_json" \
        '{
            tactic_total: $tactic_total,
            strategy_total: $strategy_total,
            matched_tactic: $matched_tactic,
            matched_strategy: $matched_strategy
        }'
}

# ==============================================================================
# estimate_file_count — Estimate the number of files affected by a task
# ==============================================================================
# Usage: estimate_file_count <description>
#
# Uses heuristic analysis of the description to estimate file count:
#   - References to "all", "every", "across", "entire", "complete" -> 6+ files
#   - References to specific counts ("three", "3 files") -> that count
#   - Mentions of multiple file types or areas -> 3-5 files
#   - Simple single-item tasks -> 1-2 files
#
# Outputs: integer file count estimate
# Returns: 0 on success
estimate_file_count() {
    local description="$1"
    local lower_desc
    lower_desc=$(_scope_to_lower "$description")

    # Check for indicators of many files
    if echo "$lower_desc" | grep -qE '(all |every |across |entire |complete |whole |comprehensive|infrastructure|microservice)'; then
        echo "8"
        return 0
    fi

    # Check for indicators of moderate file count
    if echo "$lower_desc" | grep -qE '(several |multiple |few |some |configuration files|test files|documentation)'; then
        echo "4"
        return 0
    fi

    # UI/styling changes typically touch 3+ files (component, style, test)
    if echo "$lower_desc" | grep -qE '\b(color|style|theme|font|padding|margin|layout|responsive)\b'; then
        echo "3"
        return 0
    fi

    # Check for explicit numeric mentions
    if echo "$lower_desc" | grep -qE '(three|3) (file|config)'; then
        echo "3"
        return 0
    fi

    # Check for cross-domain indicators (implies multiple files)
    local domain_count=0
    for keyword in $_SCOPE_DOMAIN_KEYWORDS; do
        if echo "$lower_desc" | grep -qw "$keyword"; then
            domain_count=$((domain_count + 1))
        fi
    done

    if [[ "$domain_count" -ge 3 ]]; then
        echo "6"
        return 0
    elif [[ "$domain_count" -ge 2 ]]; then
        echo "4"
        return 0
    fi

    # Default: simple task, 1-2 files
    echo "1"
    return 0
}

# ==============================================================================
# detect_cross_cutting — Detect cross-cutting concerns in a description
# ==============================================================================
# Usage: detect_cross_cutting <description>
#
# Scans for domain keywords that indicate multiple areas of the codebase
# are affected. Groups related keywords into domain categories.
#
# Outputs: JSON object:
#   {"concerns": [...], "score": 0.0|1.0}
#   score is 1.0 if 2+ distinct domain areas detected, 0.0 otherwise
# Returns: 0 on success
detect_cross_cutting() {
    local description="$1"
    local lower_desc
    lower_desc=$(_scope_to_lower "$description")

    # Define domain categories with their trigger keywords
    local -a detected_domains=()

    # Frontend domain
    if echo "$lower_desc" | grep -qE '\b(frontend|ui|css|component|dashboard|button|form|page|layout)\b'; then
        detected_domains+=("frontend")
    fi

    # Backend domain
    if echo "$lower_desc" | grep -qE '\b(backend|server|api|endpoint|service|controller|route|webhook|workflow)\b'; then
        detected_domains+=("backend")
    fi

    # Database domain
    if echo "$lower_desc" | grep -qE '\b(database|schema|migration|query|sql|table|rls|model|tenant)\b'; then
        detected_domains+=("database")
    fi

    # Security domain
    if echo "$lower_desc" | grep -qE '\b(security|authentication|authorization|auth|oauth|rbac|encrypt|secret|permission|role)\b'; then
        detected_domains+=("security")
    fi

    # Testing domain
    if echo "$lower_desc" | grep -qE '\b(testing|test files|test suite|coverage|e2e|unit test)\b'; then
        detected_domains+=("testing")
    fi

    # Performance domain
    if echo "$lower_desc" | grep -qE '\b(performance|optimize|cache|benchmark|latency|speed)\b'; then
        detected_domains+=("performance")
    fi

    # DevOps domain
    if echo "$lower_desc" | grep -qE '\b(deploy|ci\/cd|docker|pipeline|infrastructure|kubernetes)\b'; then
        detected_domains+=("devops")
    fi

    # Build concerns JSON
    local concerns_json="[]"
    if [[ ${#detected_domains[@]} -gt 0 ]]; then
        concerns_json=$(printf '%s\n' "${detected_domains[@]}" | jq -R . | jq -s .)
    fi

    local score="0.0"
    if [[ ${#detected_domains[@]} -ge 2 ]]; then
        score="1.0"
    fi

    jq -n \
        --argjson concerns "$concerns_json" \
        --arg score "$score" \
        '{concerns: $concerns, score: ($score | tonumber)}'
}

# ==============================================================================
# classify_scope — Classify total_score into tactic or strategy
# ==============================================================================
# Usage: classify_scope <total_score>
#
# Classification rules:
#   total_score <= -0.5  -> "tactic"
#   total_score >= 0.5   -> "strategy"
#   otherwise            -> "tactic" (default for ambiguous cases)
#
# Outputs: "tactic" or "strategy"
# Returns: 0 on success
classify_scope() {
    local total_score="$1"

    # Use bc for floating-point comparison
    local is_tactic is_strategy
    is_tactic=$(echo "$total_score <= -0.5" | bc -l 2>/dev/null || echo "0")
    is_strategy=$(echo "$total_score >= 0.5" | bc -l 2>/dev/null || echo "0")

    if [[ "$is_tactic" == "1" ]]; then
        echo "tactic"
    elif [[ "$is_strategy" == "1" ]]; then
        echo "strategy"
    else
        # Ambiguous: default to tactic
        echo "tactic"
    fi
}

# ==============================================================================
# compute_confidence — Compute classification confidence from total_score
# ==============================================================================
# Usage: compute_confidence <total_score>
#
# Formula: confidence = min(1.0, abs(total_score) / 3.0)
# A score of 0 yields 0.0 confidence; a score of +/-3 or more yields 1.0.
#
# Outputs: float in [0.0, 1.0]
# Returns: 0 on success
compute_confidence() {
    local total_score="$1"

    # Get absolute value
    local abs_score
    abs_score=$(echo "$total_score" | tr -d '-')

    # Handle empty or zero case
    if [[ -z "$abs_score" || "$abs_score" == "0" ]]; then
        echo "0"
        return 0
    fi

    # Compute confidence = min(1.0, abs(total_score) / 3.0)
    local confidence
    confidence=$(echo "scale=6; $abs_score / 3.0" | bc -l 2>/dev/null || echo "0")

    # Clamp to max 1.0
    local capped
    capped=$(echo "$confidence > 1.0" | bc -l 2>/dev/null || echo "0")
    if [[ "$capped" == "1" ]]; then
        echo "1"
    else
        echo "$confidence"
    fi
}

# ==============================================================================
# apply_override — Apply user override to scope classification
# ==============================================================================
# Usage: apply_override <detected_scope> <override_value>
#
# If override_value is "tactic" or "strategy", returns that value.
# Otherwise returns detected_scope unchanged.
#
# Outputs: "tactic" or "strategy"
# Returns: 0 on success
apply_override() {
    local detected_scope="$1"
    local override_value="${2:-}"

    if [[ "$override_value" == "tactic" || "$override_value" == "strategy" ]]; then
        echo "$override_value"
    else
        echo "$detected_scope"
    fi
}

# ==============================================================================
# analyze_scope — Full scope analysis pipeline
# ==============================================================================
# Usage: analyze_scope <description> [--override tactic|strategy]
#
# Accepts a task description and optional override flag, then runs the full
# scope detection pipeline:
#   1. Score keywords (tactic vs strategy)
#   2. Estimate file count
#   3. Detect cross-cutting concerns
#   4. Compute total score
#   5. Classify scope
#   6. Compute confidence
#   7. Apply override if provided
#
# Outputs: JSON ScopeAnalysis entity
# Returns: 0 on success
analyze_scope() {
    local description="$1"
    shift

    # Parse optional flags
    local override_value=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --override)
                override_value="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Step 1: Score keywords
    local keyword_result
    keyword_result=$(score_keywords "$description")

    local tactic_total strategy_total matched_tactic_json matched_strategy_json
    tactic_total=$(echo "$keyword_result" | jq -r '.tactic_total')
    strategy_total=$(echo "$keyword_result" | jq -r '.strategy_total')
    matched_tactic_json=$(echo "$keyword_result" | jq -c '.matched_tactic')
    matched_strategy_json=$(echo "$keyword_result" | jq -c '.matched_strategy')

    # Step 2: Estimate file count
    local file_count_estimate
    file_count_estimate=$(estimate_file_count "$description")

    # Compute file_count_score: 1-2 -> -0.5, 3-5 -> 0.0, 6+ -> +0.5
    local file_count_score
    if [[ "$file_count_estimate" -le 2 ]]; then
        file_count_score="-0.5"
    elif [[ "$file_count_estimate" -le 5 ]]; then
        file_count_score="0.0"
    else
        file_count_score="0.5"
    fi

    # Step 3: Detect cross-cutting concerns
    local cross_cut_result
    cross_cut_result=$(detect_cross_cutting "$description")

    local cross_cutting_score cross_cutting_concerns_json
    cross_cutting_score=$(echo "$cross_cut_result" | jq -r '.score')
    cross_cutting_concerns_json=$(echo "$cross_cut_result" | jq -c '.concerns')

    # Step 4: Compute total score
    local total_score
    total_score=$(echo "scale=6; $tactic_total + $strategy_total + $file_count_score + $cross_cutting_score" | bc -l 2>/dev/null || echo "0")

    # Step 5: Classify scope
    local detected_scope
    detected_scope=$(classify_scope "$total_score")

    # Step 6: Compute confidence
    local confidence
    confidence=$(compute_confidence "$total_score")

    # Step 7: Apply override
    local final_scope
    final_scope=$(apply_override "$detected_scope" "$override_value")

    # Build override_by_user field
    local override_json="null"
    if [[ -n "$override_value" && ("$override_value" == "tactic" || "$override_value" == "strategy") ]]; then
        override_json="\"$override_value\""
    fi

    # Generate analysis ID and timestamp
    local analysis_id timestamp
    analysis_id=$(_scope_generate_id "$description")
    timestamp=$(_scope_iso8601_now)

    # Build the tactic/strategy keyword reference arrays
    local tactic_keywords_json strategy_keywords_json
    tactic_keywords_json=$(echo "$_SCOPE_TACTIC_KEYWORDS" | tr ' ' '\n' | jq -R . | jq -s .)
    strategy_keywords_json=$(echo "$_SCOPE_STRATEGY_KEYWORDS" | tr ' ' '\n' | jq -R . | jq -s .)

    # Output the complete ScopeAnalysis entity
    jq -n \
        --arg analysis_id "$analysis_id" \
        --arg input_description "$description" \
        --arg detected_scope "$detected_scope" \
        --argjson tactic_total "$tactic_total" \
        --arg strategy_total "$strategy_total" \
        --arg file_count_score "$file_count_score" \
        --arg cross_cutting_score "$cross_cutting_score" \
        --arg total_score "$total_score" \
        --argjson tactic_keywords "$tactic_keywords_json" \
        --argjson strategy_keywords "$strategy_keywords_json" \
        --argjson matched_tactic_keywords "$matched_tactic_json" \
        --argjson matched_strategy_keywords "$matched_strategy_json" \
        --argjson file_count_estimate "$file_count_estimate" \
        --argjson cross_cutting_concerns "$cross_cutting_concerns_json" \
        --arg confidence "$confidence" \
        --argjson override_by_user "$override_json" \
        --arg final_scope "$final_scope" \
        --arg timestamp "$timestamp" \
        '{
            analysis_id: $analysis_id,
            input_description: $input_description,
            detected_scope: $detected_scope,
            keyword_scores: {
                tactic_total: ($tactic_total | tonumber),
                strategy_total: ($strategy_total | tonumber),
                file_count_score: ($file_count_score | tonumber),
                cross_cutting_score: ($cross_cutting_score | tonumber),
                total_score: ($total_score | tonumber)
            },
            signals: {
                tactic_keywords: $tactic_keywords,
                strategy_keywords: $strategy_keywords,
                matched_tactic_keywords: $matched_tactic_keywords,
                matched_strategy_keywords: $matched_strategy_keywords,
                file_count_estimate: $file_count_estimate,
                cross_cutting_concerns: $cross_cutting_concerns
            },
            confidence: ($confidence | tonumber),
            override_by_user: $override_by_user,
            final_scope: $final_scope,
            timestamp: $timestamp
        }'
}
