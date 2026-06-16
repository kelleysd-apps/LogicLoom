#!/bin/bash
# Comprehensive sanitization audit script for LogicLoom
# Verifies that upstream project-specific elements (the original Ioun AI project
# this framework was extracted from) have been removed — i.e. the framework is generic.

# Don't exit on error - we want to run all checks
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT may be overridden via LOOM_AUDIT_ROOT so the audit can run from a
# PRESERVED copy (outside the tree) against a sanitized tree — the release build
# strips leak-guard.sh + manifest from the tree, so the post-strip audit must run
# from a copy taken before the strip. Inherited by Check 7's leak-guard.sh call.
REPO_ROOT="${LOOM_AUDIT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# --origin-only: run Checks 1-6 (ioun-ai origin scrub) only, skipping the
# harness-dev Check 7. Used by the promotion GATE, which runs on un-stripped
# dev-main where harness-dev artifacts are legitimately still present.
ORIGIN_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --origin-only) ORIGIN_ONLY=1 ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  LogicLoom Sanitization Audit${NC}"
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
    "$REPO_ROOT/.logic-loom/" \
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
for script in "$REPO_ROOT/.logic-loom/scripts/bash/"*.sh "$REPO_ROOT/"*.sh; do
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
    "$REPO_ROOT/.logic-loom/templates/"*.md \
    "$REPO_ROOT/.logic-loom/memory/constitution.md" 2>/dev/null | \
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
    "$REPO_ROOT/.logic-loom/memory/constitution.md" 2>/dev/null | \
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
    "$REPO_ROOT/.logic-loom/memory/constitution.md" \
    "$REPO_ROOT/.logic-loom/templates/"*.md 2>/dev/null | \
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
    "$REPO_ROOT/.logic-loom/memory/constitution.md" 2>/dev/null | \
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

# Check 7: Harness-dev artifact absence (manifest-driven, TRACKED content).
# Asserts OUR harness-development record (VISION content, dev docs, release
# plumbing) is ABSENT from a sanitized template snapshot. Delegates to
# leak-guard.sh. Runs ONLY in the private dev repo during a promotion build
# (post-strip). Skipped with --origin-only (the gate runs on un-stripped
# dev-main) and on the PUBLIC template, where leak-guard.sh + the manifest are
# themselves stripped and so absent.
if [ "$ORIGIN_ONLY" -eq 0 ] && [ -f "$SCRIPT_DIR/leak-guard.sh" ] && [ -f "$SCRIPT_DIR/template-strip-manifest.txt" ]; then
    echo -e "${BLUE}[7] Checking for harness-dev artifacts (manifest)...${NC}"
    if bash "$SCRIPT_DIR/leak-guard.sh"; then
        echo -e "   ${GREEN}✅ PASS${NC}: No harness-dev artifacts present"
        ((PASS_COUNT++))
    else
        echo -e "   ${RED}❌ FAIL${NC}: harness-dev artifacts present (see above)"
        record_fail "Harness-dev artifacts present on template tree (VISION/dev docs/release plumbing)"
    fi
    echo ""
else
    echo -e "${BLUE}[7] Harness-dev artifact check: ${YELLOW}skipped${NC} (origin-only mode, or leak-guard not present on this tree)"
    echo ""
fi

# Results Summary (dynamic denominator: only checks that actually ran)
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Audit Results${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}✅ Passed:${NC} $PASS_COUNT/$TOTAL"
echo -e "${RED}❌ Failed:${NC} $FAIL_COUNT/$TOTAL"
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
