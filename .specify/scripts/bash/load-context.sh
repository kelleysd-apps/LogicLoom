#!/usr/bin/env bash
# T029: Context Loader Utility
# Sprint 3: On-demand context module loading with caching
# Constitutional Principle VII: Structured logging integrated

set -euo pipefail

# ==============================================================================
# Load Dependencies
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Source logging and common functions
if [[ -f "$REPO_ROOT/.specify/scripts/bash/common.sh" ]]; then
    source "$REPO_ROOT/.specify/scripts/bash/common.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

CONTEXT_DIR="${REPO_ROOT}/.claude/context"
CACHE_DIR="${REPO_ROOT}/.specify/logs/context-cache"
CACHE_TTL=3600  # Cache validity: 1 hour

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# ==============================================================================
# Context Module Registry
# ==============================================================================

# Available context modules
declare -A CONTEXT_MODULES=(
    ["core"]="core.md"
    ["agents"]="agents.md"
    ["skills"]="skills.md"
    ["workflows"]="workflows.md"
    ["governance"]="governance.md"
)

# Module descriptions
declare -A MODULE_DESCRIPTIONS=(
    ["core"]="Essential instructions, constitutional principles, project overview"
    ["agents"]="Available agents, delegation protocol, agent registry"
    ["skills"]="Skill definitions, triggers, procedural workflows"
    ["workflows"]="SDD commands, feature workflow, testing approach"
    ["governance"]="Git operations, quality gates, compliance requirements"
)

# ==============================================================================
# Cache Management
# ==============================================================================

# Get cache file path for a module
get_cache_file() {
    local module="$1"
    echo "$CACHE_DIR/${module}.cache"
}

# Check if cache is valid
is_cache_valid() {
    local module="$1"
    local cache_file=$(get_cache_file "$module")

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    # Check cache age
    local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [[ $age -lt $CACHE_TTL ]]; then
        log_debug "Cache valid" "{\"module\":\"$module\",\"age\":$age}"
        return 0
    else
        log_debug "Cache expired" "{\"module\":\"$module\",\"age\":$age,\"ttl\":$CACHE_TTL}"
        return 1
    fi
}

# Read from cache
read_cache() {
    local module="$1"
    local cache_file=$(get_cache_file "$module")

    if is_cache_valid "$module"; then
        cat "$cache_file"
        log_debug "Cache hit" "{\"module\":\"$module\"}"
        return 0
    else
        log_debug "Cache miss" "{\"module\":\"$module\"}"
        return 1
    fi
}

# Write to cache
write_cache() {
    local module="$1"
    local content="$2"
    local cache_file=$(get_cache_file "$module")

    echo "$content" > "$cache_file"
    log_debug "Cache written" "{\"module\":\"$module\",\"size\":${#content}}"
}

# Clear cache for a module
clear_cache() {
    local module="${1:-all}"

    if [[ "$module" == "all" ]]; then
        log_info "Clearing all context cache" "{}"
        rm -f "$CACHE_DIR"/*.cache
        echo "✓ All context cache cleared"
    else
        log_info "Clearing context cache" "{\"module\":\"$module\"}"
        local cache_file=$(get_cache_file "$module")
        rm -f "$cache_file"
        echo "✓ Cache cleared for module: $module"
    fi
}

# ==============================================================================
# Module Loading
# ==============================================================================

# Load a specific context module
load_module() {
    local module="$1"
    local use_cache="${2:-true}"

    # Check if module exists
    if [[ ! -v "CONTEXT_MODULES[$module]" ]]; then
        log_error "Unknown context module" "{\"module\":\"$module\"}"
        echo "Error: Unknown module: $module"
        echo "Available modules: ${!CONTEXT_MODULES[@]}"
        return 1
    fi

    # Try cache first if enabled
    if [[ "$use_cache" == "true" ]]; then
        if read_cache "$module" 2>/dev/null; then
            return 0
        fi
    fi

    # Load from file
    local module_file="${CONTEXT_DIR}/${CONTEXT_MODULES[$module]}"

    if [[ ! -f "$module_file" ]]; then
        log_error "Module file not found" "{\"module\":\"$module\",\"file\":\"$module_file\"}"
        echo "Error: Module file not found: $module_file"
        return 1
    fi

    log_info "Loading context module" "{\"module\":\"$module\",\"file\":\"$module_file\"}"

    # Read and cache content
    local content
    content=$(cat "$module_file")

    # Write to cache
    if [[ "$use_cache" == "true" ]]; then
        write_cache "$module" "$content"
    fi

    # Output content
    echo "$content"

    return 0
}

# Load multiple modules
load_modules() {
    local modules=("$@")

    log_info "Loading multiple context modules" "{\"modules\":[$(printf '"%s",' "${modules[@]}" | sed 's/,$//')]}"

    for module in "${modules[@]}"; do
        echo "## Context Module: $module"
        echo ""
        load_module "$module" || return 1
        echo ""
        echo "---"
        echo ""
    done
}

# ==============================================================================
# Progressive Disclosure
# ==============================================================================

# Analyze request and determine required modules
# Usage: analyze_request <request_text>
analyze_request() {
    local request="$1"

    log_debug "Analyzing request for context needs" "{\"request_length\":${#request}}"

    local -a required_modules=()

    # Always include core
    required_modules+=("core")

    # Check for agent-related keywords
    if echo "$request" | grep -iE "agent|delegate|specialist|orchestrat" &>/dev/null; then
        required_modules+=("agents")
    fi

    # Check for workflow keywords
    if echo "$request" | grep -iE "/specify|/plan|/tasks|/finalize|workflow|feature" &>/dev/null; then
        required_modules+=("workflows")
    fi

    # Check for skill keywords
    if echo "$request" | grep -iE "skill|procedure|/debug|/create-" &>/dev/null; then
        required_modules+=("skills")
    fi

    # Check for governance keywords
    if echo "$request" | grep -iE "git|commit|push|constitutional|principle|compliance" &>/dev/null; then
        required_modules+=("governance")
    fi

    # Return unique modules
    printf "%s\n" "${required_modules[@]}" | sort -u
}

# Load context based on request analysis
load_context_for_request() {
    local request="$1"

    log_info "Loading context for request" "{\"request_length\":${#request}}"

    echo "## Progressive Context Loading"
    echo ""
    echo "Analyzing request to determine required context..."
    echo ""

    # Analyze and load required modules
    local -a modules
    mapfile -t modules < <(analyze_request "$request")

    echo "Required modules: ${modules[*]}"
    echo ""
    echo "=========================================="
    echo ""

    # Load each required module
    load_modules "${modules[@]}"

    log_info "Context loaded" "{\"modules\":[$(printf '"%s",' "${modules[@]}" | sed 's/,$//')]}"
}

# ==============================================================================
# Module Information
# ==============================================================================

# List available modules
list_modules() {
    echo "=========================================="
    echo "Available Context Modules"
    echo "=========================================="
    echo ""

    for module in "${!CONTEXT_MODULES[@]}"; do
        local file="${CONTEXT_MODULES[$module]}"
        local desc="${MODULE_DESCRIPTIONS[$module]}"
        local module_path="$CONTEXT_DIR/$file"
        local size="N/A"

        if [[ -f "$module_path" ]]; then
            size=$(wc -l < "$module_path" 2>/dev/null || echo "N/A")
            size="${size} lines"
        fi

        echo "Module: $module"
        echo "  File: $file"
        echo "  Description: $desc"
        echo "  Size: $size"
        echo ""
    done

    echo "=========================================="
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        load)
            if [[ $# -eq 0 ]]; then
                echo "Error: Module name required"
                echo "Usage: $0 load <module>"
                return 1
            fi
            load_module "$1"
            ;;
        load-multiple)
            if [[ $# -eq 0 ]]; then
                echo "Error: At least one module name required"
                echo "Usage: $0 load-multiple <module1> [module2 ...]"
                return 1
            fi
            load_modules "$@"
            ;;
        analyze)
            if [[ $# -eq 0 ]]; then
                echo "Error: Request text required"
                echo "Usage: $0 analyze <request_text>"
                return 1
            fi
            load_context_for_request "$*"
            ;;
        list)
            list_modules
            ;;
        clear-cache)
            clear_cache "${1:-all}"
            ;;
        help|*)
            echo "Context Loader Utility"
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  load <module>              Load a specific context module"
            echo "  load-multiple <modules...> Load multiple context modules"
            echo "  analyze <request>          Analyze request and load required context"
            echo "  list                       List available context modules"
            echo "  clear-cache [module]       Clear cache (all or specific module)"
            echo "  help                       Show this help message"
            echo ""
            echo "Available modules: ${!CONTEXT_MODULES[@]}"
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
