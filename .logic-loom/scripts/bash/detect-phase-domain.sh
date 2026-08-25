#!/bin/bash
# Domain Detection Script for Multi-Agent Workflows
#
# This script analyzes text (from specs, tasks, or user input) and identifies
# which domains/agents should be involved based on trigger keywords from
# .logic-loom/memory/agent-collaboration-triggers.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
JSON_MODE=false
VERBOSE=false
TEXT=""
FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --file|-f)
            FILE="$2"
            shift 2
            ;;
        --text|-t)
            TEXT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --verbose, -v       Verbose output"
            echo "  --file, -f FILE     Analyze file contents"
            echo "  --text, -t TEXT     Analyze text string"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --file specs/001-feature/spec.md"
            echo "  $0 --text \"Create a React component with database integration\""
            echo "  echo \"API endpoint with caching\" | $0"
            exit 0
            ;;
        *)
            TEXT="$TEXT $1"
            shift
            ;;
    esac
done

# Read from stdin if no file or text provided
if [ -z "$TEXT" ] && [ -z "$FILE" ]; then
    if [ -t 0 ]; then
        echo "ERROR: No input provided. Use --file, --text, or pipe text to stdin" >&2
        exit 1
    else
        TEXT=$(cat)
    fi
fi

# Read file if provided
if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
        echo "ERROR: File not found: $FILE" >&2
        exit 1
    fi
    TEXT=$(cat "$FILE")
fi

# Convert text to lowercase for case-insensitive matching
TEXT_LOWER=$(echo "$TEXT" | tr '[:upper:]' '[:lower:]')

# Initialize domain counters.
#
# bash 3.2 (stock macOS `/bin/bash`) has no associative arrays and this repo
# declares 3.2 the floor for `.logic-loom/scripts/` — see
# `.docs/policies/shell-idiom-policy.md`. The domain keys are a fixed, known
# set, so one scalar per domain plus a declared iteration order carries the
# same meaning. DOMAIN_LIST also pins the iteration order, which
# `${!DOMAIN_SCORES[@]}` left to bash's hash function.
DOMAIN_LIST="frontend backend database testing security performance devops specification tasks orchestration agent_creation"

SCORE_frontend=0
SCORE_backend=0
SCORE_database=0
SCORE_testing=0
SCORE_security=0
SCORE_performance=0
SCORE_devops=0
SCORE_specification=0
SCORE_tasks=0
SCORE_orchestration=0
SCORE_agent_creation=0
# Score for a domain name (0 for an unknown one, matching the old read).
domain_score() {
    case "$1" in
        frontend) printf '%s' "$SCORE_frontend" ;;
        backend) printf '%s' "$SCORE_backend" ;;
        database) printf '%s' "$SCORE_database" ;;
        testing) printf '%s' "$SCORE_testing" ;;
        security) printf '%s' "$SCORE_security" ;;
        performance) printf '%s' "$SCORE_performance" ;;
        devops) printf '%s' "$SCORE_devops" ;;
        specification) printf '%s' "$SCORE_specification" ;;
        tasks) printf '%s' "$SCORE_tasks" ;;
        orchestration) printf '%s' "$SCORE_orchestration" ;;
        agent_creation) printf '%s' "$SCORE_agent_creation" ;;
        *) printf '%s' 0 ;;
    esac
}

# Frontend keywords (from agent-collaboration-triggers.md)
FRONTEND_KEYWORDS="ui user.interface component view screen page react next\.js vue angular svelte css styling theme design.system responsive mobile layout button form input modal dialog"
for keyword in $FRONTEND_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_frontend=$((SCORE_frontend + 1))
    fi
done

# Backend keywords
BACKEND_KEYWORDS="api endpoint route controller handler server backend service microservice authentication auth login session jwt oauth business.logic middleware request response"
for keyword in $BACKEND_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_backend=$((SCORE_backend + 1))
    fi
done

# Database keywords
DATABASE_KEYWORDS="database db sql postgresql mysql mongodb schema table collection model entity migration seed fixture query select insert update delete join index rls row.level.security policy"
for keyword in $DATABASE_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_database=$((SCORE_database + 1))
    fi
done

# Testing keywords
TESTING_KEYWORDS="test testing qa quality.assurance unit.test integration.test e2e end.to.end tdd bdd jest vitest playwright cypress mocha chai coverage assertion mock stub"
for keyword in $TESTING_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_testing=$((SCORE_testing + 1))
    fi
done

# Security keywords
SECURITY_KEYWORDS="security vulnerability exploit xss csrf sql.injection injection.attack encryption hashing bcrypt crypto sanitization validation authorization permission role"
for keyword in $SECURITY_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_security=$((SCORE_security + 1))
    fi
done

# Performance keywords
PERFORMANCE_KEYWORDS="performance optimization speed latency throughput caching cache redis memcached cdn benchmark profiling bottleneck scaling horizontal.scaling load.balancing"
for keyword in $PERFORMANCE_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_performance=$((SCORE_performance + 1))
    fi
done

# DevOps keywords
DEVOPS_KEYWORDS="deploy deployment release rollout ci cd continuous.integration pipeline docker dockerfile container kubernetes helm terraform infrastructure monitoring logging prometheus grafana aws gcp azure"
for keyword in $DEVOPS_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_devops=$((SCORE_devops + 1))
    fi
done

# Specification keywords
SPECIFICATION_KEYWORDS="spec specification requirement requirements user.story acceptance.criteria functional.requirement non.functional epic feature.description prd product.requirement"
for keyword in $SPECIFICATION_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_specification=$((SCORE_specification + 1))
    fi
done

# Task management keywords
TASK_KEYWORDS="task tasks task.list dependency dependencies breakdown implementation.plan subtask milestone deliverable work.item todo"
for keyword in $TASK_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_tasks=$((SCORE_tasks + 1))
    fi
done

# Orchestration keywords (multi-domain indicators)
ORCHESTRATION_KEYWORDS="orchestration coordination workflow multi.agent complex.workflow end.to.end full.stack integration"
for keyword in $ORCHESTRATION_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_orchestration=$((SCORE_orchestration + 1))
    fi
done

# Agent creation keywords
AGENT_KEYWORDS="agent subagent create.agent new.agent agent.creation specialized.agent"
for keyword in $AGENT_KEYWORDS; do
    if echo "$TEXT_LOWER" | grep -qE "\b$keyword\b"; then
        SCORE_agent_creation=$((SCORE_agent_creation + 1))
    fi
done

# Calculate total matches and determine primary domains
TOTAL_MATCHES=0
DETECTED_DOMAINS=()
SUGGESTED_AGENTS=()

for domain in $DOMAIN_LIST; do
    score=$(domain_score "$domain")
    TOTAL_MATCHES=$((TOTAL_MATCHES + score))

    if [ $score -gt 0 ]; then
        DETECTED_DOMAINS+=("$domain:$score")
    fi
done

# Sort domains by score (descending)
IFS=$'\n' SORTED_DOMAINS=($(sort -t: -k2 -nr <<<"${DETECTED_DOMAINS[*]}"))
unset IFS

# Map domains to skills (or remaining agents)
map_domain_to_skill() {
    case "$1" in
        frontend) echo "frontend-operations skill" ;;
        backend) echo "api-design / service-architecture skills" ;;
        database) echo "schema-design skill" ;;
        testing) echo "testing-operations skill" ;;
        security) echo "security-operations skill" ;;
        performance) echo "performance-operations skill" ;;
        devops) echo "monitoring skill" ;;
        specification) echo "unified-specification skill" ;;
        tasks) echo "unified-specification skill" ;;
        orchestration) echo "team-orchestration skill" ;;
        agent_creation) echo "subagent-architect" ;;
        *) echo "unknown" ;;
    esac
}

# Determine delegation strategy
DELEGATION_STRATEGY="none"
DOMAIN_COUNT=${#SORTED_DOMAINS[@]}

if [ $DOMAIN_COUNT -eq 0 ]; then
    DELEGATION_STRATEGY="none"
elif [ $DOMAIN_COUNT -eq 1 ]; then
    DELEGATION_STRATEGY="single-agent"
    PRIMARY_DOMAIN=$(echo "${SORTED_DOMAINS[0]}" | cut -d: -f1)
    SUGGESTED_AGENTS+=("$(map_domain_to_skill "$PRIMARY_DOMAIN")")
elif [ $DOMAIN_COUNT -ge 2 ]; then
    # Check if orchestration is needed (2+ domains with significant scores)
    SIGNIFICANT_DOMAINS=0
    for domain_score in "${SORTED_DOMAINS[@]}"; do
        score=$(echo "$domain_score" | cut -d: -f2)
        if [ $score -ge 2 ]; then
            SIGNIFICANT_DOMAINS=$((SIGNIFICANT_DOMAINS + 1))
        fi
    done

    if [ $SIGNIFICANT_DOMAINS -ge 2 ]; then
        DELEGATION_STRATEGY="multi-skill"
        SUGGESTED_AGENTS+=("team-orchestration skill")

        # Add top 3 specialist skills
        for i in {0..2}; do
            if [ $i -lt ${#SORTED_DOMAINS[@]} ]; then
                domain=$(echo "${SORTED_DOMAINS[$i]}" | cut -d: -f1)
                score=$(echo "${SORTED_DOMAINS[$i]}" | cut -d: -f2)
                if [ $score -gt 0 ] && [ "$domain" != "orchestration" ]; then
                    skill=$(map_domain_to_skill "$domain")
                    if [ "$skill" != "unknown" ]; then
                        # Several domains can map to the same skill (the
                        # specification and tasks domains are both phases of
                        # unified-specification). Don't suggest it twice.
                        already=false
                        for existing in "${SUGGESTED_AGENTS[@]}"; do
                            if [ "$existing" = "$skill" ]; then already=true; break; fi
                        done
                        if [ "$already" = false ]; then
                            SUGGESTED_AGENTS+=("$skill")
                        fi
                    fi
                fi
            fi
        done
    else
        DELEGATION_STRATEGY="single-skill"
        PRIMARY_DOMAIN=$(echo "${SORTED_DOMAINS[0]}" | cut -d: -f1)
        SUGGESTED_AGENTS+=("$(map_domain_to_skill "$PRIMARY_DOMAIN")")
    fi
fi

# Output results
if $JSON_MODE; then
    # JSON output
    echo "{"
    echo "  \"strategy\": \"$DELEGATION_STRATEGY\","
    echo "  \"total_matches\": $TOTAL_MATCHES,"
    echo "  \"domain_count\": $DOMAIN_COUNT,"
    echo "  \"domains\": ["

    first=true
    for domain_score in "${SORTED_DOMAINS[@]}"; do
        domain=$(echo "$domain_score" | cut -d: -f1)
        score=$(echo "$domain_score" | cut -d: -f2)
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "    {\"domain\": \"$domain\", \"score\": $score, \"skill\": \"$(map_domain_to_skill "$domain")\"}"
    done
    echo ""
    echo "  ],"

    echo "  \"suggested_agents\": ["
    first=true
    for agent in "${SUGGESTED_AGENTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "    \"$agent\""
    done
    echo ""
    echo "  ]"
    echo "}"
else
    # Human-readable output
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Domain Detection Results${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    echo -e "${GREEN}Delegation Strategy:${NC} $DELEGATION_STRATEGY"
    echo -e "${GREEN}Total Keyword Matches:${NC} $TOTAL_MATCHES"
    echo -e "${GREEN}Domains Detected:${NC} $DOMAIN_COUNT"
    echo ""

    if [ $DOMAIN_COUNT -gt 0 ]; then
        echo -e "${YELLOW}Domain Breakdown:${NC}"
        for domain_score in "${SORTED_DOMAINS[@]}"; do
            domain=$(echo "$domain_score" | cut -d: -f1)
            score=$(echo "$domain_score" | cut -d: -f2)
            skill=$(map_domain_to_skill "$domain")
            echo "  • $domain: $score matches → $skill"
        done
        echo ""
    fi

    if [ ${#SUGGESTED_AGENTS[@]} -gt 0 ]; then
        echo -e "${GREEN}Suggested Skills/Agents:${NC}"
        for agent in "${SUGGESTED_AGENTS[@]}"; do
            echo "  • $agent"
        done
    else
        echo -e "${YELLOW}No specific skill delegation needed${NC}"
    fi

    if $VERBOSE; then
        echo ""
        echo -e "${BLUE}All Domain Scores:${NC}"
        for domain in $DOMAIN_LIST; do
            score=$(domain_score "$domain")
            echo "  $domain: $score"
        done
    fi
fi

# Exit with appropriate code
if [ $TOTAL_MATCHES -gt 0 ]; then
    exit 0
else
    exit 1
fi
