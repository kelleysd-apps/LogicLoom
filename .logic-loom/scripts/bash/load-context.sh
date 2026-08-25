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
if [[ -f "$REPO_ROOT/.logic-loom/scripts/bash/common.sh" ]]; then
    source "$REPO_ROOT/.logic-loom/scripts/bash/common.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

CONTEXT_DIR="${REPO_ROOT}/.claude/context"
CACHE_DIR="${REPO_ROOT}/.logic-loom/logs/context-cache"
CACHE_TTL=3600  # Cache validity: 1 hour

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# ==============================================================================
# Context Module Registry
# ==============================================================================

# Available context modules.
#
# bash 3.2 (stock macOS `/bin/bash`) has no associative arrays and this repo
# declares 3.2 the floor for `.logic-loom/scripts/` — see
# `.docs/policies/shell-idiom-policy.md`. `case` lookups plus an explicit
# MODULE_LIST carry the same meaning, and MODULE_LIST also pins the listing
# order that `${!CONTEXT_MODULES[@]}` left to bash's hash function.
MODULE_LIST="core agents skills workflows governance"

# File name for a module. Exits non-zero for an unknown module — this is the
# existence test the old `[[ -v CONTEXT_MODULES[$module] ]]` performed.
module_file() {
    case "$1" in
        core)       printf '%s' "core.md" ;;
        agents)     printf '%s' "agents.md" ;;
        skills)     printf '%s' "skills.md" ;;
        workflows)  printf '%s' "workflows.md" ;;
        governance) printf '%s' "governance.md" ;;
        *)          return 1 ;;
    esac
}

# Human description for a module.
module_description() {
    case "$1" in
        core)       printf '%s' "Essential instructions, constitutional principles, project overview" ;;
        agents)     printf '%s' "Available agents, delegation protocol, agent registry" ;;
        skills)     printf '%s' "Skill definitions, triggers, procedural workflows" ;;
        workflows)  printf '%s' "SDD commands, feature workflow, testing approach" ;;
        governance) printf '%s' "Git operations, quality gates, compliance requirements" ;;
        *)          return 1 ;;
    esac
}

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
    local module_name=""
    if ! module_name="$(module_file "$module")"; then
        log_error "Unknown context module" "{\"module\":\"$module\"}"
        echo "Error: Unknown module: $module"
        echo "Available modules: $MODULE_LIST"
        return 1
    fi

    # Try cache first if enabled
    if [[ "$use_cache" == "true" ]]; then
        if read_cache "$module" 2>/dev/null; then
            return 0
        fi
    fi

    # Load from file
    local module_path="${CONTEXT_DIR}/${module_name}"

    if [[ ! -f "$module_path" ]]; then
        log_error "Module file not found" "{\"module\":\"$module\",\"file\":\"$module_path\"}"
        echo "Error: Module file not found: $module_path"
        return 1
    fi

    log_info "Loading context module" "{\"module\":\"$module\",\"file\":\"$module_path\"}"

    # Read and cache content
    local content
    content=$(cat "$module_path")

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
    local modules
    modules=("$@")
    if [[ ${#modules[@]} -eq 0 ]]; then
        return 0
    fi

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

    local -a required_modules
    required_modules=()

    # Always include core
    required_modules[${#required_modules[@]}]="core"

    # Check for agent-related keywords
    if echo "$request" | grep -iE "agent|delegate|specialist|orchestrat" &>/dev/null; then
        required_modules[${#required_modules[@]}]="agents"
    fi

    # Check for workflow keywords
    if echo "$request" | grep -iE "/specification|/plan-review|/finalize|workflow|feature" &>/dev/null; then
        required_modules[${#required_modules[@]}]="workflows"
    fi

    # Check for skill keywords
    if echo "$request" | grep -iE "skill|procedure|/create-" &>/dev/null; then
        required_modules[${#required_modules[@]}]="skills"
    fi

    # Check for governance keywords
    if echo "$request" | grep -iE "git|commit|push|constitutional|principle|compliance" &>/dev/null; then
        required_modules[${#required_modules[@]}]="governance"
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
    # bash 3.2 has no `mapfile`; read the lines into the array by hand.
    local -a modules
    modules=()
    local _line
    while IFS= read -r _line; do
        [[ -n "$_line" ]] || continue
        modules[${#modules[@]}]="$_line"
    done < <(analyze_request "$request")

    if [[ ${#modules[@]} -eq 0 ]]; then
        echo "No context modules required."
        return 0
    fi

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

    for module in $MODULE_LIST; do
        local file
        file="$(module_file "$module")"
        local desc
        desc="$(module_description "$module")"
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
            echo "Available modules: $MODULE_LIST"
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
