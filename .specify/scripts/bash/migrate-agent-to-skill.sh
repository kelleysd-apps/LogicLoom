#!/bin/bash
# Migrate Agent to Skill Script
# Task: T049
# FR: FR-503
# Purpose: Convert legacy agent workflow to skills-first skill definition
# Version: 1.0.0
# Constitutional Compliance: Principle X (Skills-First), I (Library-First)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TEMPLATES_DIR="${ROOT_DIR}/.specify/templates/skill-prototypes"
SKILLS_DIR="${ROOT_DIR}/.claude/skills"
AGENTS_DIR="${ROOT_DIR}/.claude/agents"

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[MIGRATE] [INFO] $(date -Iseconds) $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[MIGRATE] [DEBUG] $(date -Iseconds) $*" >&2
    fi
}

log_warn() {
    echo "[MIGRATE] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[MIGRATE] [ERROR] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Agent Analysis
# ==============================================================================

# Extract frontmatter from agent markdown file
extract_agent_frontmatter() {
    local agent_file="${1:?Agent file required}"

    if [[ ! -f "$agent_file" ]]; then
        log_error "Agent file not found: $agent_file"
        return 1
    fi

    # Extract YAML frontmatter between --- markers
    awk '/^---$/{p=!p;next}p' "$agent_file" | head -100
}

# Parse agent capabilities into skill format
analyze_agent() {
    local agent_file="${1:?Agent file required}"

    log_info "Analyzing agent: $agent_file"

    local frontmatter
    frontmatter=$(extract_agent_frontmatter "$agent_file")

    if [[ -z "$frontmatter" ]]; then
        log_error "Could not extract frontmatter from: $agent_file"
        return 1
    fi

    # Extract key fields
    local name
    name=$(echo "$frontmatter" | grep -E "^name:" | cut -d: -f2- | xargs)

    local purpose
    purpose=$(echo "$frontmatter" | grep -E "^purpose:" | cut -d: -f2- | xargs)

    local department
    department=$(echo "$frontmatter" | grep -E "^department:" | cut -d: -f2- | xargs)

    local tools
    tools=$(echo "$frontmatter" | grep -A10 "^tools:" | grep "^  -" | sed 's/^  - //' | tr '\n' ',' | sed 's/,$//')

    # Determine skill category based on department
    local skill_category
    case "$department" in
        engineering|implementation)
            skill_category="domain"
            ;;
        architecture|design)
            skill_category="domain"
            ;;
        product|specification)
            skill_category="sdd-workflow"
            ;;
        quality|testing|security)
            skill_category="domain"
            ;;
        operations|devops)
            skill_category="domain"
            ;;
        *)
            skill_category="domain"
            ;;
    esac

    # Generate analysis JSON
    jq -n \
        --arg name "$name" \
        --arg purpose "$purpose" \
        --arg department "$department" \
        --arg tools "$tools" \
        --arg category "$skill_category" \
        --arg source_file "$agent_file" \
        '{
            "agent_name": $name,
            "purpose": $purpose,
            "department": $department,
            "tools": ($tools | split(",")),
            "suggested_skill_category": $category,
            "source_file": $source_file
        }'
}

# ==============================================================================
# Skill Generation
# ==============================================================================

# Generate skill definition from agent analysis
generate_skill() {
    local agent_file="${1:?Agent file required}"
    local skill_category="${2:-domain}"
    local output_dir="${3:-}"

    log_info "Generating skill from agent: $agent_file"

    # Analyze agent
    local analysis
    analysis=$(analyze_agent "$agent_file")

    if [[ $? -ne 0 ]]; then
        log_error "Agent analysis failed"
        return 1
    fi

    # Extract analysis fields
    local agent_name
    agent_name=$(echo "$analysis" | jq -r '.agent_name')

    local purpose
    purpose=$(echo "$analysis" | jq -r '.purpose')

    local department
    department=$(echo "$analysis" | jq -r '.department')

    # Generate skill name from agent name
    local skill_name
    skill_name=$(echo "$agent_name" | sed 's/-agent$//' | sed 's/-specialist$//' | sed 's/$/-operations/')

    # Determine skill category
    if [[ -z "$skill_category" || "$skill_category" == "auto" ]]; then
        skill_category=$(echo "$analysis" | jq -r '.suggested_skill_category')
    fi

    # Determine output directory
    if [[ -z "$output_dir" ]]; then
        output_dir="${SKILLS_DIR}/${skill_category}/${skill_name}"
    fi

    # Create output directory
    mkdir -p "$output_dir"

    local output_file="${output_dir}/SKILL.md"

    log_info "Creating skill: $output_file"

    # Generate triggers from agent name and purpose
    local triggers
    triggers=$(generate_triggers "$agent_name" "$purpose")

    # Determine consolidated agent for invocation
    local consolidated_agent
    consolidated_agent=$(map_to_consolidated_agent "$agent_name" "$department")

    # Generate skill file
    cat > "$output_file" << EOF
---
name: ${skill_name}
version: 3.0.0
category: ${skill_category}
description: ${purpose}
triggers:
${triggers}
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "${purpose}"
    triggers: [$(echo "$triggers" | tr '\n' ',' | sed 's/^  - //g' | sed 's/,  - /, /g' | sed 's/,$//' | tr -d '\n')]
    primary-agent: ${consolidated_agent}
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: ${consolidated_agent}
    context-subset:
      - task_description
      - relevant_files
      - constraints
    expected-output: implementation
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# ${skill_name} Skill

## Purpose

${purpose}

This skill was migrated from the ${agent_name} agent to follow the skills-first architecture.

## Migration Source

- **Original Agent**: ${agent_name}
- **Department**: ${department}
- **Migrated**: $(date -Iseconds)
- **Migration Tool**: migrate-agent-to-skill.sh v1.0.0

## Constitutional Compliance

- **Principle X (Skills-First)**: Skill orchestrates, ${consolidated_agent} executes
- **Principle II (Test-First)**: TDD required for implementations
- **Principle VI (Git Approval)**: NEVER execute git commands autonomously

## Instructions

### Prerequisites

- FR-707 compliance check must pass
- Required context must be provided

### Execution Steps

1. **Validate Input**: Check required context fields
2. **Invoke Agent**: Delegate to ${consolidated_agent}
3. **Validate Output**: Run verifier checks
4. **Return Result**: Format and return output

## Agent Invocation

\`\`\`yaml
invoke: ${consolidated_agent}
context:
  task_description: <from user request>
  relevant_files: <identified files>
  constraints: <domain constraints>
expected:
  format: implementation
  validation: verifier_check
\`\`\`

## DS-STAR Integration

- **Pre-execution**: FR-707 compliance check required
- **Post-verification**: Verifier validates output quality
- **Auto-debug**: Triggered on quality failure

## Examples

### Example 1: Basic Usage

**Request**: [Migrated from agent usage]

**Skill Action**:
1. Detect relevant trigger
2. Activate skill
3. Invoke ${consolidated_agent}

**Output**: [Implementation based on agent capabilities]

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Missing context | Validation | Request missing fields |
| Agent failure | Error response | Trigger auto-debug |
| Quality failure | Verifier | Retry with improvements |

## RL Metrics

- **Success Criteria**: Task completion verified
- **Token Efficiency**: Track against baseline
- **Learning**: EMA weight updates

## Related Skills

- **Compliance**: validation/message-preflight
- **Orchestration**: orchestration/multi-skill-workflow

---

*Migrated from: ${agent_name}*
*Skills-first architecture: v3.0.0*
EOF

    log_info "Skill generated: $output_file"

    # Generate migration report
    local report
    report=$(jq -n \
        --arg source "$agent_file" \
        --arg target "$output_file" \
        --arg agent "$agent_name" \
        --arg skill "$skill_name" \
        --arg category "$skill_category" \
        --arg consolidated "$consolidated_agent" \
        '{
            "migration": {
                "source_agent": $agent,
                "source_file": $source,
                "target_skill": $skill,
                "target_file": $target,
                "category": $category,
                "consolidated_agent": $consolidated,
                "timestamp": (now | todate),
                "status": "completed"
            }
        }')

    echo "$report"
}

# ==============================================================================
# Helper Functions
# ==============================================================================

# Generate triggers from agent name and purpose
generate_triggers() {
    local agent_name="${1:?Agent name required}"
    local purpose="${2:-}"

    # Extract keywords from agent name
    local keywords
    keywords=$(echo "$agent_name" | tr '-' '\n' | grep -v "agent" | grep -v "specialist" | grep -v "engineer")

    # Extract keywords from purpose
    local purpose_keywords
    purpose_keywords=$(echo "$purpose" | tr ' ' '\n' | grep -E "^[a-z]{4,}$" | head -5)

    # Combine and format as YAML list
    {
        echo "$keywords"
        echo "$purpose_keywords"
    } | sort -u | head -5 | while read -r kw; do
        if [[ -n "$kw" ]]; then
            echo "  - $kw"
        fi
    done
}

# Map legacy agent to consolidated agent
map_to_consolidated_agent() {
    local agent_name="${1:?Agent name required}"
    local department="${2:-}"

    # Consolidation mapping (from agent-index.json)
    case "$agent_name" in
        frontend-specialist|full-stack-developer)
            echo "implementation-specialist"
            ;;
        devops-engineer|performance-engineer)
            echo "operations-specialist"
            ;;
        specification-agent|planning-agent|tasks-agent|prd-specialist)
            echo "specification-orchestrator"
            ;;
        testing-specialist|security-specialist)
            echo "quality-specialist"
            ;;
        subagent-architect)
            echo "system-architect"
            ;;
        task-orchestrator)
            echo "workflow-coordinator"
            ;;
        backend-architect)
            echo "backend-architect"
            ;;
        database-specialist)
            echo "database-specialist"
            ;;
        *)
            # Fallback based on department
            case "$department" in
                engineering)
                    echo "implementation-specialist"
                    ;;
                architecture)
                    echo "backend-architect"
                    ;;
                quality)
                    echo "quality-specialist"
                    ;;
                operations)
                    echo "operations-specialist"
                    ;;
                product)
                    echo "specification-orchestrator"
                    ;;
                *)
                    echo "implementation-specialist"
                    ;;
            esac
            ;;
    esac
}

# ==============================================================================
# Batch Migration
# ==============================================================================

# Migrate all agents in a directory
migrate_directory() {
    local source_dir="${1:?Source directory required}"
    local output_base="${2:-$SKILLS_DIR}"

    log_info "Migrating agents from: $source_dir"

    local count=0
    local success=0
    local failed=0

    find "$source_dir" -name "*.md" -type f | while read -r agent_file; do
        count=$((count + 1))
        log_info "Processing [$count]: $agent_file"

        if generate_skill "$agent_file" "auto" ""; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            log_error "Failed to migrate: $agent_file"
        fi
    done

    log_info "Migration complete: $success succeeded, $failed failed"
}

# ==============================================================================
# Validation
# ==============================================================================

# Validate generated skill against contract
validate_skill() {
    local skill_file="${1:?Skill file required}"

    log_info "Validating skill: $skill_file"

    if [[ ! -f "$skill_file" ]]; then
        log_error "Skill file not found: $skill_file"
        return 1
    fi

    # Check frontmatter exists
    if ! grep -q "^---$" "$skill_file"; then
        log_error "Missing YAML frontmatter"
        return 1
    fi

    # Check required fields
    local required_fields=("name" "version" "category" "triggers" "rl_metrics" "progressive-disclosure" "agent-invocations")
    local missing=()

    for field in "${required_fields[@]}"; do
        if ! grep -q "^${field}:" "$skill_file"; then
            missing+=("$field")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required fields: ${missing[*]}"
        return 1
    fi

    # Check rl_metrics subfields
    local rl_fields=("success_rate" "selection_weight" "invocation_count" "avg_tokens")
    for field in "${rl_fields[@]}"; do
        if ! grep -q "${field}:" "$skill_file"; then
            log_warn "Missing rl_metrics field: $field"
        fi
    done

    log_info "Validation passed: $skill_file"
    return 0
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
Agent to Skill Migration Tool

Usage: $(basename "$0") <command> [options]

Commands:
  analyze <agent_file>                    Analyze agent without migration
  migrate <agent_file> [category] [dir]   Migrate single agent to skill
  batch <source_dir> [output_dir]         Migrate all agents in directory
  validate <skill_file>                   Validate generated skill
  map <agent_name>                        Show consolidated agent mapping

Options:
  --help          Show this help message
  --debug         Enable debug logging

Examples:
  # Analyze an agent
  $(basename "$0") analyze plugins/sdd-domain-frontend/agents/frontend-specialist.md

  # Migrate to skill
  $(basename "$0") migrate plugins/sdd-domain-frontend/agents/frontend-specialist.md domain

  # Batch migrate
  $(basename "$0") batch plugins/sdd-domain-frontend/agents/

  # Validate result
  $(basename "$0") validate plugins/sdd-domain-frontend/skills/frontend-operations/SKILL.md

Migration Notes:
  - Skills use v3.0.0 format with RL metrics
  - Agent invocations reference consolidated agents (8 domain + 5 DS-STAR)
  - Progressive disclosure layers generated automatically
  - DS-STAR integration includes pre-execution check

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        analyze)
            shift
            analyze_agent "$@"
            ;;
        migrate)
            shift
            generate_skill "$@"
            ;;
        batch)
            shift
            migrate_directory "$@"
            ;;
        validate)
            shift
            validate_skill "$@"
            ;;
        map)
            shift
            local agent="${1:?Agent name required}"
            local department="${2:-}"
            echo "$(map_to_consolidated_agent "$agent" "$department")"
            ;;
        --help|-h|help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -n "$command" ]]; then
                log_error "Unknown command: $command"
            fi
            show_usage
            exit 1
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
