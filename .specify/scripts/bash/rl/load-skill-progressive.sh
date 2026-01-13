#!/bin/bash
# =============================================================================
# load-skill-progressive.sh
# Task: T011
# Purpose: Progressive disclosure loader for token-efficient skill loading
#
# Usage: ./load-skill-progressive.sh <skill-path> [layer]
#
# Arguments:
#   skill-path: Full skill path (e.g., "sdd-workflow/sdd-specification")
#   layer: 1 | 2 | 3 | all (default: 2)
#
# Layers:
#   Layer 1: Metadata + RL metrics (~100 tokens) - Always loaded
#   Layer 2: Instructions + agent-invocations (~500 tokens) - On activation
#   Layer 3: Examples + references (variable) - On demand
#
# Output:
#   JSON with requested layer content
#
# Example:
#   ./load-skill-progressive.sh "sdd-workflow/sdd-specification" 1
#
# Constitutional Compliance: FR-201, FR-203 (Progressive Disclosure)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SKILLS_DIR="$ROOT_DIR/.claude/skills"

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date -Iseconds) - $1" >&2
}

log_error() {
    echo "[ERROR] $(date -Iseconds) - $1" >&2
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") <skill-path> [layer]

Arguments:
  skill-path    Full skill path (e.g., "sdd-workflow/sdd-specification")
  layer         1 | 2 | 3 | all (default: 2)

Layers:
  1     Layer 1: Metadata + RL metrics (~100 tokens)
        Fields: name, description, triggers, category, version, rl_metrics

  2     Layer 2: Instructions + agent-invocations (~500 tokens)
        Fields: Layer 1 + instructions, agent-invocations, composes, allowed-tools

  3     Layer 3: Examples + references (variable tokens)
        Fields: Layer 2 + examples, references content loaded

  all   All layers combined

Examples:
  # Load Layer 1 only (routing decisions)
  $(basename "$0") "sdd-workflow/sdd-specification" 1

  # Load Layer 1 + 2 (skill activation)
  $(basename "$0") "sdd-workflow/sdd-specification" 2

  # Load all layers (full context needed)
  $(basename "$0") "sdd-workflow/sdd-specification" all

Token Budget Targets:
  Layer 1: ~100 tokens (metadata)
  Layer 2: ~500 tokens (instructions)
  Layer 3: variable (examples/references)
  Target reduction: 40-50% vs full loading
EOF
}

# Find SKILL.md file for a skill path
find_skill_file() {
    local skill_path="$1"

    # Try common patterns
    local possible_paths=(
        "$SKILLS_DIR/$skill_path/SKILL.md"
        "$SKILLS_DIR/$(dirname "$skill_path")/$(basename "$skill_path")/SKILL.md"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return
        fi
    done

    # Search recursively
    local found
    found=$(find "$SKILLS_DIR" -type f -name "SKILL.md" -path "*$(basename "$skill_path")*" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return
    fi

    log_error "Skill file not found for: $skill_path"
    return 1
}

# Parse YAML frontmatter from SKILL.md
parse_frontmatter() {
    local file="$1"

    # Extract content between --- markers
    awk '/^---$/{p=!p;next} p' "$file" | head -100
}

# Extract specific YAML field
extract_yaml_field() {
    local yaml="$1"
    local field="$2"

    echo "$yaml" | grep -E "^$field:" | sed "s/^$field:\s*//" | head -1
}

# Extract YAML array field
extract_yaml_array() {
    local yaml="$1"
    local field="$2"

    echo "$yaml" | awk -v field="$field:" '
        $0 ~ field {found=1; next}
        found && /^[^ ]/ {exit}
        found && /^  - / {gsub(/^  - /, ""); print}
    '
}

# Load Layer 1: Metadata + RL metrics
load_layer1() {
    local skill_file="$1"

    local frontmatter
    frontmatter=$(parse_frontmatter "$skill_file")

    # Extract Layer 1 fields
    local name description category version triggers rl_metrics

    name=$(extract_yaml_field "$frontmatter" "name")
    description=$(echo "$frontmatter" | awk '/^description:/{p=1;next} p && /^[^ ]/{exit} p{print}' | head -5)
    category=$(extract_yaml_field "$frontmatter" "category")
    version=$(extract_yaml_field "$frontmatter" "version")

    # Extract triggers as JSON array
    triggers=$(extract_yaml_array "$frontmatter" "triggers" | jq -R . | jq -s .)

    # Extract rl_metrics as JSON object
    rl_metrics=$(echo "$frontmatter" | awk '
        /^rl_metrics:/{found=1; next}
        found && /^[^ ]/ {exit}
        found {gsub(/^  /, ""); print}
    ' | sed 's/: /": "/g; s/$/",/; s/^/"/; s/""/"/g' | tr -d '\n' | sed 's/,$//' | sed 's/^/{/; s/$/}/')

    # Build Layer 1 JSON
    cat << EOF
{
  "layer": 1,
  "skill_path": "$(dirname "$(dirname "$skill_file")" | xargs basename)/$(basename "$(dirname "$skill_file")")",
  "name": "$name",
  "description": $(echo "$description" | jq -Rs .),
  "category": "$category",
  "version": "$version",
  "triggers": $triggers,
  "rl_metrics": $rl_metrics,
  "token_estimate": 100
}
EOF
}

# Load Layer 2: Instructions + agent-invocations
load_layer2() {
    local skill_file="$1"

    # Get Layer 1 first
    local layer1
    layer1=$(load_layer1 "$skill_file")

    # Read full file content (after frontmatter)
    local content
    content=$(awk '/^---$/{p++} p==2{print}' "$skill_file" | tail -n +2)

    local frontmatter
    frontmatter=$(parse_frontmatter "$skill_file")

    # Extract allowed-tools
    local allowed_tools
    allowed_tools=$(extract_yaml_array "$frontmatter" "allowed-tools" | jq -R . | jq -s .)
    if [[ -z "$allowed_tools" ]] || [[ "$allowed_tools" == "[]" ]]; then
        allowed_tools="[]"
    fi

    # Extract agent-invocations (simplified)
    local agent_invocations
    agent_invocations=$(echo "$frontmatter" | awk '
        /^agent-invocations:/{found=1; next}
        found && /^[^ ]/ {exit}
        found {print}
    ' | head -20)

    if [[ -z "$agent_invocations" ]]; then
        agent_invocations="[]"
    else
        agent_invocations="[\"see SKILL.md for details\"]"
    fi

    # Extract composes
    local composes
    composes=$(extract_yaml_array "$frontmatter" "composes" | jq -R . | jq -s .)
    if [[ -z "$composes" ]] || [[ "$composes" == "[]" ]]; then
        composes="[]"
    fi

    # Extract instructions (markdown content, first 2000 chars)
    local instructions
    instructions=$(echo "$content" | head -100 | jq -Rs .)

    # Combine into Layer 2
    cat << EOF
{
  "layer": 2,
  "skill_path": $(echo "$layer1" | jq '.skill_path'),
  "name": $(echo "$layer1" | jq '.name'),
  "description": $(echo "$layer1" | jq '.description'),
  "category": $(echo "$layer1" | jq '.category'),
  "version": $(echo "$layer1" | jq '.version'),
  "triggers": $(echo "$layer1" | jq '.triggers'),
  "rl_metrics": $(echo "$layer1" | jq '.rl_metrics'),
  "allowed_tools": $allowed_tools,
  "agent_invocations": $agent_invocations,
  "composes": $composes,
  "instructions": $instructions,
  "token_estimate": 500
}
EOF
}

# Load Layer 3: Examples + references
load_layer3() {
    local skill_file="$1"

    # Get Layer 2 first
    local layer2
    layer2=$(load_layer2 "$skill_file")

    local skill_dir
    skill_dir=$(dirname "$skill_file")

    # Try to load examples file
    local examples_content="null"
    if [[ -f "$skill_dir/examples.md" ]]; then
        examples_content=$(cat "$skill_dir/examples.md" | jq -Rs .)
    fi

    # Try to load reference file
    local reference_content="null"
    if [[ -f "$skill_dir/reference.md" ]]; then
        reference_content=$(cat "$skill_dir/reference.md" | jq -Rs .)
    fi

    # Combine into Layer 3
    cat << EOF
{
  "layer": 3,
  "skill_path": $(echo "$layer2" | jq '.skill_path'),
  "name": $(echo "$layer2" | jq '.name'),
  "description": $(echo "$layer2" | jq '.description'),
  "category": $(echo "$layer2" | jq '.category'),
  "version": $(echo "$layer2" | jq '.version'),
  "triggers": $(echo "$layer2" | jq '.triggers'),
  "rl_metrics": $(echo "$layer2" | jq '.rl_metrics'),
  "allowed_tools": $(echo "$layer2" | jq '.allowed_tools'),
  "agent_invocations": $(echo "$layer2" | jq '.agent_invocations'),
  "composes": $(echo "$layer2" | jq '.composes'),
  "instructions": $(echo "$layer2" | jq '.instructions'),
  "examples": $examples_content,
  "reference": $reference_content,
  "token_estimate": "variable"
}
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local skill_path="${1:-}"
    local layer="${2:-2}"

    if [[ -z "$skill_path" ]]; then
        show_usage
        exit 1
    fi

    # Find skill file
    local skill_file
    skill_file=$(find_skill_file "$skill_path") || exit 1

    log_info "Loading skill: $skill_path (layer: $layer)"
    log_info "File: $skill_file"

    case "$layer" in
        1)
            load_layer1 "$skill_file"
            ;;
        2)
            load_layer2 "$skill_file"
            ;;
        3|all)
            load_layer3 "$skill_file"
            ;;
        *)
            log_error "Invalid layer: $layer. Must be 1, 2, 3, or all"
            exit 1
            ;;
    esac
}

main "$@"
