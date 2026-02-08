#!/usr/bin/env bash
# T023: Skill Auto-Discovery Script
# Sprint 3: Automatically discover and index skills from plugins/*/skills/
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

SKILLS_DIR="${REPO_ROOT}/.claude/skills"
OUTPUT_INDEX="${REPO_ROOT}/.claude/skill-index.json"
TEMP_INDEX="${OUTPUT_INDEX}.tmp"

# ==============================================================================
# Skill Metadata Parsing
# ==============================================================================

# Parse SKILL.md frontmatter for metadata
# Usage: parse_skill_metadata <skill_file_path>
parse_skill_metadata() {
    local skill_file="$1"

    if [[ ! -f "$skill_file" ]]; then
        log_error "Skill file not found" "{\"path\":\"$skill_file\"}"
        return 1
    fi

    # Extract frontmatter between --- markers
    local in_frontmatter=false
    local name=""
    local description=""
    local triggers=""
    local category=""
    local version=""
    local requires_approval=""

    while IFS= read -r line; do
        # Detect frontmatter boundaries
        if [[ "$line" == "---" ]]; then
            if [[ "$in_frontmatter" == "false" ]]; then
                in_frontmatter=true
                continue
            else
                # End of frontmatter
                break
            fi
        fi

        if [[ "$in_frontmatter" == "true" ]]; then
            # Parse key-value pairs
            if [[ "$line" =~ ^name:\ *(.+)$ ]]; then
                name="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^description:\ *(.+)$ ]]; then
                description="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^triggers:\ *(.+)$ ]]; then
                triggers="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^category:\ *(.+)$ ]]; then
                category="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^version:\ *(.+)$ ]]; then
                version="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^requires_approval:\ *(.+)$ ]]; then
                requires_approval="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$skill_file"

    # Generate relative path
    local rel_path="${skill_file#$REPO_ROOT/}"

    # Extract category from directory path if not in frontmatter
    if [[ -z "$category" ]]; then
        # Extract directory name before skill name
        local dir_path=$(dirname "$rel_path")
        category=$(basename "$(dirname "$dir_path")")
    fi

    # Output as JSON
    cat <<EOF
{
  "name": "${name:-unknown}",
  "description": "${description:-No description}",
  "triggers": "${triggers:-}",
  "category": "${category:-general}",
  "version": "${version:-1.0.0}",
  "requires_approval": ${requires_approval:-false},
  "path": "$rel_path"
}
EOF
}

# ==============================================================================
# Skill Discovery
# ==============================================================================

# Discover all skills in plugins/*/skills/
discover_skills() {
    log_info "Starting skill discovery" "{\"skills_dir\":\"$SKILLS_DIR\"}"

    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "Skills directory not found" "{\"path\":\"$SKILLS_DIR\"}"
        return 1
    fi

    # Initialize JSON array
    echo "[" > "$TEMP_INDEX"

    local skill_count=0
    local first_skill=true

    # Find all SKILL.md files
    find "$SKILLS_DIR" -type f -name "SKILL.md" | sort | while read -r skill_file; do
        log_debug "Processing skill" "{\"file\":\"$skill_file\"}"

        # Add comma separator for JSON array (except first item)
        if [[ "$first_skill" == "false" ]]; then
            echo "," >> "$TEMP_INDEX"
        fi
        first_skill=false

        # Parse and append skill metadata
        parse_skill_metadata "$skill_file" >> "$TEMP_INDEX"

        ((skill_count++))
    done

    # Close JSON array
    echo "]" >> "$TEMP_INDEX"

    # Move temp file to final location
    mv "$TEMP_INDEX" "$OUTPUT_INDEX"

    log_info "Skill discovery completed" "{\"skill_count\":$skill_count,\"output\":\"$OUTPUT_INDEX\"}"

    echo "Discovered $skill_count skill(s)"
    echo "Index saved to: $OUTPUT_INDEX"

    return 0
}

# ==============================================================================
# Skill Index Validation
# ==============================================================================

# Validate generated skill index
validate_skill_index() {
    log_info "Validating skill index" "{\"index\":\"$OUTPUT_INDEX\"}"

    if [[ ! -f "$OUTPUT_INDEX" ]]; then
        log_error "Skill index not found" "{\"path\":\"$OUTPUT_INDEX\"}"
        return 1
    fi

    # Check if file is valid JSON using node (if available)
    if command -v node &> /dev/null; then
        if node -e "JSON.parse(require('fs').readFileSync('$OUTPUT_INDEX', 'utf8'))" 2>/dev/null; then
            log_info "Skill index is valid JSON" "{}"
            echo "✓ Skill index is valid JSON"
            return 0
        else
            log_error "Skill index is invalid JSON" "{}"
            echo "✗ Skill index is invalid JSON"
            return 1
        fi
    else
        log_warn "Node.js not available, skipping JSON validation" "{}"
        echo "⚠ Node.js not available, skipping JSON validation"
        return 0
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    local op_id=$(log_operation_start "Skill discovery" "{}")

    echo "=========================================="
    echo "Skill Auto-Discovery"
    echo "=========================================="
    echo ""

    # Discover skills
    if discover_skills; then
        echo ""

        # Validate index
        if validate_skill_index; then
            log_operation_end "$op_id" "success" "Skill discovery completed successfully"
            echo ""
            echo "✓ Skill discovery completed successfully"
            return 0
        else
            log_operation_end "$op_id" "failure" "Skill index validation failed"
            echo ""
            echo "✗ Skill index validation failed"
            return 1
        fi
    else
        log_operation_end "$op_id" "failure" "Skill discovery failed"
        echo ""
        echo "✗ Skill discovery failed"
        return 1
    fi
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
