#!/bin/bash
# Comprehensive sanitization audit script for SDD Framework
# Verifies that all Ioun AI project-specific elements have been removed

# Don't exit on error - we want to run all checks
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  SDD Framework Sanitization Audit${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Repository Root: $REPO_ROOT"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
ISSUES=()

# Function to record a failure
record_fail() {
    local message="$1"
    ISSUES+=("$message")
    ((FAIL_COUNT++))
}

# Check 1: Hardcoded paths
echo -e "${BLUE}[1/6] Checking for hardcoded project paths...${NC}"
HARDCODED_PATHS=$(grep -r "/workspaces/ioun-ai" \
    "$REPO_ROOT/.claude/" \
    "$REPO_ROOT/.specify/" \
    "$REPO_ROOT/.docs/" 2>/dev/null | \
    grep -v "sdd-framework-enhancements-prd.md" | \
    grep -v "sdd-framework-enhancements-sow.md" | \
    grep -v "sanitization-checklist.md" | \
    grep -v "sanitization-sign-off.md" | \
    grep -v "sanitization-audit.sh" | \
    grep -v "case-studies/ioun-ai.md" || true)

if [ -n "$HARDCODED_PATHS" ]; then
    echo -e "   ${RED}❌ FAIL${NC}: Hardcoded paths found"
    echo "$HARDCODED_PATHS" | head -5
    record_fail "Hardcoded /workspaces/ioun-ai paths in agent files or scripts"
else
    echo -e "   ${GREEN}✅ PASS${NC}: No hardcoded paths"
    ((PASS_COUNT++))
fi
echo ""

# Check 2: Unapproved git operations
echo -e "${BLUE}[2/6] Checking for unapproved git operations...${NC}"

# Check each script file for git operations
UNAPPROVED_FOUND=false
for script in "$REPO_ROOT/.specify/scripts/bash/"*.sh "$REPO_ROOT/"*.sh; do
    [ -f "$script" ] || continue
    [[ "$script" == *"sanitization-audit.sh" ]] && continue

    # Look for git commands that are NOT preceded by request_git_approval or read -p within 10 lines
    if grep -q "^\s*git\s\+\(checkout\|commit\|push\|branch\|init\|add\)" "$script" 2>/dev/null; then
        # Check if the script sources common.sh or has request_git_approval
        if ! grep -q "request_git_approval\|read -p.*[Yy]" "$script" 2>/dev/null; then
            echo -e "   ${RED}❌ FAIL${NC}: No approval mechanism in $script"
            UNAPPROVED_FOUND=true
        fi
    fi
done

if [ "$UNAPPROVED_FOUND" = true ]; then
    record_fail "Git operations without approval mechanism in scripts"
else
    echo -e "   ${GREEN}✅ PASS${NC}: All scripts have git approval mechanisms"
    ((PASS_COUNT++))
fi
echo ""

# Check 3: Specific design system
echo -e "${BLUE}[3/6] Checking for specific design system requirements...${NC}"
DESIGN_SYSTEM=$(grep -i "neumorphism\|neomorphism" \
    "$REPO_ROOT/.specify/templates/"*.md \
    "$REPO_ROOT/.specify/memory/constitution.md" 2>/dev/null | \
    grep -v "example" | \
    grep -v "case study" | \
    grep -v "Case Study" || true)

if [ -n "$DESIGN_SYSTEM" ]; then
    echo -e "   ${RED}❌ FAIL${NC}: Specific design system in framework core"
    echo "$DESIGN_SYSTEM" | head -3
    record_fail "Design system specifics should be in examples, not requirements"
else
    echo -e "   ${GREEN}✅ PASS${NC}: Design system is generic"
    ((PASS_COUNT++))
fi
echo ""

# Check 4: Specific tier names
echo -e "${BLUE}[4/6] Checking for specific tier names in constitution...${NC}"
TIER_NAMES=$(grep -i "player tier\|dm tier\|prestige" \
    "$REPO_ROOT/.specify/memory/constitution.md" 2>/dev/null | \
    grep -v "example" | \
    grep -v "case study" | \
    grep -v "Case Study" || true)

if [ -n "$TIER_NAMES" ]; then
    echo -e "   ${RED}❌ FAIL${NC}: Specific tiers in constitution"
    echo "$TIER_NAMES" | head -3
    record_fail "Tier names should be generic (free/premium/enterprise), not project-specific"
else
    echo -e "   ${GREEN}✅ PASS${NC}: Tier enforcement is generic"
    ((PASS_COUNT++))
fi
echo ""

# Check 5: Domain-specific terms
echo -e "${BLUE}[5/6] Checking for domain-specific terminology...${NC}"
DOMAIN_TERMS=$(grep -iE "\bcampaign[s]?\b|\bcharacter[s]?\b|\bnpc[s]?\b|\bdm\b" \
    "$REPO_ROOT/.specify/memory/constitution.md" \
    "$REPO_ROOT/.specify/templates/"*.md 2>/dev/null | \
    grep -v "example" | \
    grep -v "case study" | \
    grep -v "Case Study" | \
    grep -v "user session" | \
    grep -v "http session" | \
    grep -v "session management" | \
    grep -v "character encoding" | \
    grep -v "special character" | \
    grep -v "characters\." | \
    grep -v "max.*characters" | \
    grep -v "[0-9].*characters" || true)

if [ -n "$DOMAIN_TERMS" ]; then
    echo -e "   ${RED}❌ FAIL${NC}: Domain-specific terms in framework"
    echo "$DOMAIN_TERMS" | head -3
    record_fail "D&D-specific terminology in framework core (should be in case studies)"
else
    echo -e "   ${GREEN}✅ PASS${NC}: Framework uses generic terminology"
    ((PASS_COUNT++))
fi
echo ""

# Check 6: Tech stack requirements
echo -e "${BLUE}[6/6] Checking for specific tech stack requirements...${NC}"
TECH_STACK=$(grep -iE "\bexpo\b|\breact native\b|\beas build\b" \
    "$REPO_ROOT/.specify/memory/constitution.md" 2>/dev/null | \
    grep -v "example" | \
    grep -v "optional" | \
    grep -v "case study" | \
    grep -v "Case Study" || true)

if [ -n "$TECH_STACK" ]; then
    echo -e "   ${RED}❌ FAIL${NC}: Specific tech stack required in constitution"
    echo "$TECH_STACK" | head -3
    record_fail "Tech stack should not be prescribed in constitution"
else
    echo -e "   ${GREEN}✅ PASS${NC}: Tech stack is not prescribed"
    ((PASS_COUNT++))
fi
echo ""

# Results Summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Audit Results${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}✅ Passed:${NC} $PASS_COUNT/6"
echo -e "${RED}❌ Failed:${NC} $FAIL_COUNT/6"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All checks passed! Framework is sanitized.${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️  Sanitization incomplete. Issues found:${NC}"
    echo ""
    for issue in "${ISSUES[@]}"; do
        echo -e "${YELLOW}  •${NC} $issue"
    done
    echo ""
    echo -e "${YELLOW}Review the failures above and fix before proceeding.${NC}"
    echo ""
    exit 1
fi
