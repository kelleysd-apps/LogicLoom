#!/usr/bin/env bash
# T025: Generate Skill Index
# Sprint 3: Parse all SKILL.md files and generate .claude/skill-index.json
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

# Load JSON parsing utility
if [[ -f "$REPO_ROOT/.specify/lib/json-parse.cjs" ]]; then
    JSON_PARSER="$REPO_ROOT/.specify/lib/json-parse.cjs"
else
    JSON_PARSER=""
fi

# ==============================================================================
# Configuration
# ==============================================================================

SKILLS_DIR="${REPO_ROOT}/.claude/skills"
OUTPUT_INDEX="${REPO_ROOT}/.claude/skill-index.json"

# ==============================================================================
# Skill Parsing Functions
# ==============================================================================

# Parse skill frontmatter using simple regex
parse_skill_frontmatter() {
    local skill_file="$1"
    local key="$2"

    # Extract value for specified key from frontmatter
    awk -v key="$key" '
        BEGIN { in_frontmatter=0; found=0 }
        /^---$/ {
            if (in_frontmatter == 0) {
                in_frontmatter = 1
                next
            } else {
                exit
            }
        }
        in_frontmatter == 1 && $1 == key":" {
            sub(/^[^:]+:[ \t]*/, "")
            print
            found = 1
            exit
        }
        END { if (found == 0) print "" }
    ' "$skill_file"
}

# Generate JSON entry for a skill
generate_skill_entry() {
    local skill_file="$1"
    local rel_path="${skill_file#$REPO_ROOT/}"

    # Parse metadata
    local name=$(parse_skill_frontmatter "$skill_file" "name")
    local description=$(parse_skill_frontmatter "$skill_file" "description")
    local triggers=$(parse_skill_frontmatter "$skill_file" "triggers")
    local category=$(parse_skill_frontmatter "$skill_file" "category")
    local version=$(parse_skill_frontmatter "$skill_file" "version")
    local requires_approval=$(parse_skill_frontmatter "$skill_file" "requires_approval")

    # Extract category from path if not specified
    if [[ -z "$category" ]]; then
        local skill_dir=$(dirname "$skill_file")
        category=$(basename "$(dirname "$skill_dir")")
    fi

    # Set defaults
    name="${name:-$(basename "$(dirname "$skill_file")")}"
    description="${description:-No description available}"
    version="${version:-1.0.0}"
    requires_approval="${requires_approval:-false}"

    # Escape JSON special characters
    name=$(echo "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    description=$(echo "$description" | sed 's/\\/\\\\/g; s/"/\\"/g')
    triggers=$(echo "$triggers" | sed 's/\\/\\\\/g; s/"/\\"/g')
    category=$(echo "$category" | sed 's/\\/\\\\/g; s/"/\\"/g')

    # Generate JSON object
    cat <<EOF
  {
    "name": "$name",
    "description": "$description",
    "triggers": "$triggers",
    "category": "$category",
    "version": "$version",
    "requires_approval": $requires_approval,
    "path": "$rel_path"
  }
EOF
}

# ==============================================================================
# Index Generation
# ==============================================================================

# Generate complete skill index
generate_skill_index() {
    log_info "Generating skill index" "{\"skills_dir\":\"$SKILLS_DIR\",\"output\":\"$OUTPUT_INDEX\"}"

    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "Skills directory not found" "{\"path\":\"$SKILLS_DIR\"}"
        echo "Error: Skills directory not found: $SKILLS_DIR"
        return 1
    fi

    # Start JSON array
    echo "{" > "$OUTPUT_INDEX"
    echo "  \"version\": \"1.0.0\"," >> "$OUTPUT_INDEX"
    echo "  \"generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$OUTPUT_INDEX"
    echo "  \"skills\": [" >> "$OUTPUT_INDEX"

    local skill_count=0
    local first=true

    # Find all SKILL.md files and generate entries
    while IFS= read -r skill_file; do
        log_debug "Processing skill" "{\"file\":\"$skill_file\"}"

        # Add comma separator (except for first entry)
        if [[ "$first" == "false" ]]; then
            echo "," >> "$OUTPUT_INDEX"
        fi
        first=false

        # Generate and append skill entry
        generate_skill_entry "$skill_file" >> "$OUTPUT_INDEX"

        ((skill_count++))
    done < <(find "$SKILLS_DIR" -type f -name "SKILL.md" | sort)

    # Close JSON structure
    echo "" >> "$OUTPUT_INDEX"
    echo "  ]," >> "$OUTPUT_INDEX"
    echo "  \"total\": $skill_count" >> "$OUTPUT_INDEX"
    echo "}" >> "$OUTPUT_INDEX"

    log_info "Skill index generated" "{\"skill_count\":$skill_count,\"output\":\"$OUTPUT_INDEX\"}"

    echo "Generated index with $skill_count skill(s)"
    echo "Output: $OUTPUT_INDEX"

    return 0
}

# ==============================================================================
# Index Validation
# ==============================================================================

# Validate generated index is valid JSON
validate_index() {
    log_info "Validating skill index" "{\"index\":\"$OUTPUT_INDEX\"}"

    if [[ ! -f "$OUTPUT_INDEX" ]]; then
        log_error "Index file not found" "{\"path\":\"$OUTPUT_INDEX\"}"
        return 1
    fi

    # Try to parse with node if available
    if command -v node &> /dev/null; then
        if node -e "JSON.parse(require('fs').readFileSync('$OUTPUT_INDEX', 'utf8'))" 2>/dev/null; then
            log_info "Index validation passed" "{}"
            echo "✓ Index is valid JSON"

            # Pretty print summary
            local total=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$OUTPUT_INDEX', 'utf8')).total)" 2>/dev/null || echo "unknown")
            echo "✓ Total skills indexed: $total"

            return 0
        else
            log_error "Index validation failed - invalid JSON" "{}"
            echo "✗ Index is invalid JSON"
            return 1
        fi
    else
        log_warn "Node.js not available, skipping JSON validation" "{}"
        echo "⚠ Node.js not available, skipping validation"
        return 0
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    local op_id=$(log_operation_start "Generate skill index" "{}")

    echo "=========================================="
    echo "Skill Index Generator"
    echo "=========================================="
    echo ""

    # Generate index
    if generate_skill_index; then
        echo ""

        # Validate index
        if validate_index; then
            log_operation_end "$op_id" "success" "Skill index generated successfully"
            echo ""
            echo "✓ Skill index generation completed"
            return 0
        else
            log_operation_end "$op_id" "failure" "Index validation failed"
            echo ""
            echo "✗ Index validation failed"
            return 1
        fi
    else
        log_operation_end "$op_id" "failure" "Index generation failed"
        echo ""
        echo "✗ Index generation failed"
        return 1
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
