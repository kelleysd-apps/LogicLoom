#!/bin/bash
# Constitutional Compliance Checker for SDD Framework
# Validates adherence to Constitutional Principles
# Authority: Constitution v3.0.0

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

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Constitutional Compliance Check${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Repository: $REPO_ROOT"
echo "Constitution: v3.0.0"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
ISSUES=()
WARNINGS=()

# Function to record a failure
record_fail() {
    local message="$1"
    ISSUES+=("$message")
    ((FAIL_COUNT++))
}

# Function to record a warning
record_warn() {
    local message="$1"
    WARNINGS+=("$message")
    ((WARN_COUNT++))
}

#
# ============================================
# Principle I: Library-First Architecture
# ============================================
#
echo -e "${BLUE}[1/16] Principle I: Library-First Architecture${NC}"
echo "Checking for library structure..."

# Check if project has a libs or packages directory
if [ -d "$REPO_ROOT/libs" ] || [ -d "$REPO_ROOT/packages" ] || [ -d "$REPO_ROOT/src/libs" ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Library structure exists"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No library structure found (libs/, packages/, or src/libs/)"
    record_warn "Consider creating library structure for reusable components"
fi
echo ""

#
# ============================================
# Principle II: Test-First Development
# ============================================
#
echo -e "${BLUE}[2/16] Principle II: Test-First Development (TDD)${NC}"
echo "Checking for test infrastructure..."

# Check for test directories or files
TEST_FOUND=false
if find "$REPO_ROOT" -type d \( -name "__tests__" -o -name "test" -o -name "tests" -o -name "spec" \) 2>/dev/null | grep -q .; then
    TEST_FOUND=true
fi

# Check for test files
if find "$REPO_ROOT" -type f \( -name "*.test.ts" -o -name "*.test.js" -o -name "*.spec.ts" -o -name "*.spec.js" \) 2>/dev/null | grep -q .; then
    TEST_FOUND=true
fi

if [ "$TEST_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Test infrastructure exists"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No test infrastructure found"
    record_warn "TDD requires test files (*. test.ts, *.spec.js) or test directories (__tests__, tests/)"
fi
echo ""

#
# ============================================
# Principle III: Contract-First Design
# ============================================
#
echo -e "${BLUE}[3/16] Principle III: Contract-First Design${NC}"
echo "Checking for contract definitions..."

# Check for contracts directory in specs
CONTRACT_FOUND=false
if [ -d "$REPO_ROOT/specs" ]; then
    if find "$REPO_ROOT/specs" -type d -name "contracts" 2>/dev/null | grep -q .; then
        CONTRACT_FOUND=true
    fi
fi

# Check for contract/schema files
if find "$REPO_ROOT" -type f \( -name "*contract*.ts" -o -name "*schema*.ts" -o -name "*contract*.json" -o -name "openapi.yaml" -o -name "swagger.json" \) 2>/dev/null | grep -q .; then
    CONTRACT_FOUND=true
fi

if [ "$CONTRACT_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Contract definitions found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No contract definitions found"
    record_warn "Consider defining contracts in specs/*/contracts/ or *contract*.ts files"
fi
echo ""

#
# ============================================
# Principle IV: Idempotent Operations
# ============================================
#
echo -e "${BLUE}[4/16] Principle IV: Idempotent Operations${NC}"
echo "Checking scripts for idempotency patterns..."

# Check if scripts handle "already exists" scenarios
IDEMPOTENT_PATTERNS=false
for script in "$REPO_ROOT/.logic-loom/scripts/bash/"*.sh "$REPO_ROOT/"*.sh; do
    [ -f "$script" ] || continue

    # Look for idempotency patterns
    if grep -q "if.*exist\|mkdir -p\|--skip-existing\|--force" "$script" 2>/dev/null; then
        IDEMPOTENT_PATTERNS=true
        break
    fi
done

if [ "$IDEMPOTENT_PATTERNS" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Idempotency patterns found in scripts"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Limited idempotency patterns in scripts"
    record_warn "Scripts should handle re-execution safely (mkdir -p, check if exists, etc.)"
fi
echo ""

#
# ============================================
# Principle V: Progressive Enhancement
# ============================================
#
echo -e "${BLUE}[5/16] Principle V: Progressive Enhancement${NC}"
echo "Checking for feature flags or gradual rollout..."

# Look for feature flag patterns
FEATURE_FLAGS=false
if grep -r "feature.*flag\|featureFlag\|FEATURE_FLAG\|enabled.*feature" "$REPO_ROOT/src" "$REPO_ROOT/libs" 2>/dev/null | grep -q .; then
    FEATURE_FLAGS=true
fi

if [ "$FEATURE_FLAGS" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Feature flag patterns found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  INFO: No feature flags detected (acceptable for simple projects)"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle VI: Git Operation Approval
# ============================================
#
echo -e "${BLUE}[6/16] Principle VI: Git Operation Approval (CRITICAL)${NC}"
echo "Checking for git approval mechanisms..."

# Check if scripts have git approval
GIT_APPROVAL_FOUND=false
for script in "$REPO_ROOT/.logic-loom/scripts/bash/"*.sh "$REPO_ROOT/"*.sh; do
    [ -f "$script" ] || continue
    [[ "$script" == *"sanitization-audit.sh" ]] && continue
    [[ "$script" == *"constitutional-check.sh" ]] && continue

    # Check if script has git commands
    if grep -q "^\s*git\s\+\(checkout\|commit\|push\|branch\|init\|add\)" "$script" 2>/dev/null; then
        # Check if it has approval mechanism
        if ! grep -q "request_git_approval\|read -p.*[Yy]" "$script" 2>/dev/null; then
            echo -e "   ${RED}❌ FAIL${NC}: Git operations without approval in $script"
            record_fail "Git operations require user approval (Principle VI)"
            GIT_APPROVAL_FOUND=false
            break
        else
            GIT_APPROVAL_FOUND=true
        fi
    fi
done

if [ "$GIT_APPROVAL_FOUND" != false ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Git operations have approval mechanisms"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle VII: Observability & Logging
# ============================================
#
echo -e "${BLUE}[7/16] Principle VII: Observability & Structured Logging${NC}"
echo "Checking for logging infrastructure..."

# Check for logging patterns
LOGGING_FOUND=false
if grep -r "console\.log\|logger\|logging\|log\.info\|log\.error" "$REPO_ROOT/src" "$REPO_ROOT/libs" 2>/dev/null | head -1 | grep -q .; then
    LOGGING_FOUND=true
fi

if [ "$LOGGING_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Logging patterns found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No logging patterns detected"
    record_warn "Operations should emit structured logs for observability"
fi
echo ""

#
# ============================================
# Principle VIII: Documentation Synchronization
# ============================================
#
echo -e "${BLUE}[8/16] Principle VIII: Documentation Synchronization${NC}"
echo "Checking documentation structure..."

# Check for key documentation files
DOC_COUNT=0
[ -f "$REPO_ROOT/README.md" ] && ((DOC_COUNT++))
[ -f "$REPO_ROOT/CLAUDE.md" ] || [ -f "$REPO_ROOT/.claude/CLAUDE.md" ] && ((DOC_COUNT++))
[ -f "$REPO_ROOT/.logic-loom/memory/constitution.md" ] && ((DOC_COUNT++))
[ -f "$REPO_ROOT/.logic-loom/memory/constitution_update_checklist.md" ] && ((DOC_COUNT++))

if [ $DOC_COUNT -ge 3 ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Core documentation files exist ($DOC_COUNT/4)"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Missing core documentation files ($DOC_COUNT/4)"
    record_warn "Should have README.md, CLAUDE.md, constitution.md, and constitution_update_checklist.md"
fi
echo ""

#
# ============================================
# Principle IX: Dependency Management
# ============================================
#
echo -e "${BLUE}[9/16] Principle IX: Dependency Management${NC}"
echo "Checking for dependency declarations..."

# Check for package/dependency files
DEPS_FOUND=false
if [ -f "$REPO_ROOT/package.json" ] || [ -f "$REPO_ROOT/requirements.txt" ] || [ -f "$REPO_ROOT/Gemfile" ] || [ -f "$REPO_ROOT/go.mod" ] || [ -f "$REPO_ROOT/Cargo.toml" ]; then
    DEPS_FOUND=true
fi

if [ "$DEPS_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Dependency declarations found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  INFO: No dependency files found (may be framework-only project)"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle X: Agent Delegation Protocol
# ============================================
#
echo -e "${BLUE}[10/16] Principle X: Agent Delegation Protocol (CRITICAL)${NC}"
echo "Checking for agent infrastructure..."

# Check for agent context files (Plugin-First Architecture v4.0)
AGENT_COUNT=0
if [ -d "$REPO_ROOT/plugins" ]; then
    AGENT_COUNT=$(find "$REPO_ROOT/plugins" -path "*/agents/*.md" -type f 2>/dev/null | wc -l)
fi

# Check for agent collaboration triggers
TRIGGERS_EXIST=false
if [ -f "$REPO_ROOT/.logic-loom/memory/agent-collaboration-triggers.md" ]; then
    TRIGGERS_EXIST=true
fi

if [ $AGENT_COUNT -gt 0 ] && [ "$TRIGGERS_EXIST" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Agent infrastructure exists ($AGENT_COUNT agents, triggers defined)"
    ((PASS_COUNT++))
elif [ $AGENT_COUNT -gt 0 ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Agents exist but no collaboration triggers defined"
    record_warn "Create .logic-loom/memory/agent-collaboration-triggers.md"
elif [ "$TRIGGERS_EXIST" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Triggers defined but no agents created"
    record_warn "Create specialized agents in plugins/*/agents/"
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No agent infrastructure found"
    record_warn "Agent Delegation Protocol requires specialized agents and trigger definitions"
fi
echo ""

#
# ============================================
# Principle XI: Input Validation & Output Sanitization
# ============================================
#
echo -e "${BLUE}[11/16] Principle XI: Input Validation & Output Sanitization${NC}"
echo "Checking for validation patterns..."

# Check for validation patterns in code
VALIDATION_FOUND=false
if grep -r "validate\|sanitize\|escape\|zod\|yup\|joi" "$REPO_ROOT/src" "$REPO_ROOT/libs" 2>/dev/null | head -1 | grep -q .; then
    VALIDATION_FOUND=true
fi

# Check for secrets in .gitignore
GITIGNORE_SECRETS=false
if [ -f "$REPO_ROOT/.gitignore" ]; then
    if grep -q "\.env\|secrets\|credentials" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        GITIGNORE_SECRETS=true
    fi
fi

if [ "$VALIDATION_FOUND" = true ] && [ "$GITIGNORE_SECRETS" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Validation patterns and secret protection found"
    ((PASS_COUNT++))
elif [ "$GITIGNORE_SECRETS" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Secrets protected but no validation patterns found"
    record_warn "Add input validation (zod, yup, joi) to prevent security issues"
elif [ "$VALIDATION_FOUND" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Validation found but check .gitignore for secret protection"
    record_warn "Ensure .env, secrets, and credentials are in .gitignore"
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Limited security patterns detected"
    record_warn "Add input validation and ensure secrets are gitignored"
fi
echo ""

#
# ============================================
# Principle XII: Design System Compliance
# ============================================
#
echo -e "${BLUE}[12/16] Principle XII: Design System Compliance${NC}"
echo "Checking for design system..."

# Check for design system files
DESIGN_SYSTEM=false
if grep -r "theme\|design.*system\|colors.*palette\|typography" "$REPO_ROOT/src" "$REPO_ROOT/libs" 2>/dev/null | head -1 | grep -q .; then
    DESIGN_SYSTEM=true
fi

if [ "$DESIGN_SYSTEM" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Design system patterns found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  INFO: No design system detected (acceptable for non-UI projects)"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle XIII: Feature Access Control
# ============================================
#
echo -e "${BLUE}[13/16] Principle XIII: Feature Access Control${NC}"
echo "Checking for access control patterns..."

# Check for access control patterns
ACCESS_CONTROL=false
if grep -r "access.*control\|authorization\|permission\|role\|tier\|RLS\|row.*level.*security" "$REPO_ROOT/src" "$REPO_ROOT/libs" "$REPO_ROOT/specs" 2>/dev/null | head -1 | grep -q .; then
    ACCESS_CONTROL=true
fi

if [ "$ACCESS_CONTROL" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Access control patterns found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  INFO: No access control patterns detected (acceptable for open projects)"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle XIV: AI Model Selection Protocol
# ============================================
#
echo -e "${BLUE}[14/16] Principle XIV: AI Model Selection Protocol${NC}"
echo "Checking for AI model configuration..."

# Check for model selection documentation or configuration
MODEL_CONFIG=false
if grep -r "claude.*sonnet\|claude.*opus\|model.*selection\|AI.*model" "$REPO_ROOT/.claude" "$REPO_ROOT/.specify" "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/AGENTS.md" 2>/dev/null | head -1 | grep -q .; then
    MODEL_CONFIG=true
fi

if [ "$MODEL_CONFIG" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: AI model configuration found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  INFO: No AI model configuration detected (acceptable)"
    ((PASS_COUNT++))
fi
echo ""

#
# ============================================
# Principle XV: File and Folder Organization
# ============================================
#
echo -e "${BLUE}[15/16] Principle XV: File and Folder Organization${NC}"
echo "Checking for proper file organization..."

# Check spec directory naming convention (###-feature-name)
SPEC_NAMING=true
if [ -d "$REPO_ROOT/specs" ]; then
    for spec_dir in "$REPO_ROOT/specs"/*; do
        [ -d "$spec_dir" ] || continue
        dirname=$(basename "$spec_dir")
        if [[ ! "$dirname" =~ ^[0-9]{3}-[a-z0-9-]+$ ]]; then
            SPEC_NAMING=false
            record_warn "Spec directory '$dirname' doesn't follow ###-feature-name convention"
        fi
    done
fi

# Check agent files live in plugins (Plugin-First Architecture v4.0)
AGENT_ORG=true
if [ -d "$REPO_ROOT/.claude/agents" ]; then
    AGENT_ORG=false
    record_warn "Legacy .claude/agents/ directory exists — agents should be in plugins/*/agents/"
fi

# Check skills live in plugins (Plugin-First Architecture v4.0)
SKILL_ORG=true
if [ -d "$REPO_ROOT/.claude/skills" ]; then
    SKILL_ORG=false
    record_warn "Legacy .claude/skills/ directory exists — skills should be in plugins/*/skills/"
fi

# Overall file organization check
if [ "$SPEC_NAMING" = true ] && [ "$AGENT_ORG" = true ] && [ "$SKILL_ORG" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: File organization follows conventions"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Some file organization issues found"
    # Already recorded specific warnings above
fi
echo ""

#
# ============================================
# Principle XVI: Plugin-First Architecture
# ============================================
#
echo -e "${BLUE}[16/16] Principle XVI: Plugin-First Architecture${NC}"
echo "Checking for plugin-based capability structure..."

# Check for plugins directory with proper structure
PLUGIN_FOUND=false
if [ -d "$REPO_ROOT/plugins" ]; then
    PLUGIN_COUNT=$(find "$REPO_ROOT/plugins" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | xargs)
    if [ "$PLUGIN_COUNT" -gt 0 ]; then
        # Check at least some plugins have plugin.json
        MANIFEST_COUNT=$(find "$REPO_ROOT/plugins" -maxdepth 2 -name "plugin.json" -type f 2>/dev/null | wc -l | xargs)
        if [ "$MANIFEST_COUNT" -gt 0 ]; then
            PLUGIN_FOUND=true
        fi
    fi
fi

if [ "$PLUGIN_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Plugin architecture found ($PLUGIN_COUNT plugins, $MANIFEST_COUNT manifests)"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No plugin architecture found"
    record_warn "Capabilities should be organized as plugins in plugins/ directory"
fi
echo ""

#
# ============================================
# Results Summary
# ============================================
#
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Compliance Results${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${GREEN}✅ Passed:${NC} $PASS_COUNT/16"
echo -e "${RED}❌ Failed:${NC} $FAIL_COUNT/16"
echo -e "${YELLOW}⚠  Warnings:${NC} $WARN_COUNT"
echo ""

# Show failures
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Critical Issues:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "${RED}  •${NC} $issue"
    done
    echo ""
fi

# Show warnings
if [ $WARN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Warnings (recommended fixes):${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}  •${NC} $warning"
    done
    echo ""
fi

# Overall status
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ Constitutional compliance verified!${NC}"
    echo ""
    echo "All critical principles (VI, X) are met."
    if [ $WARN_COUNT -gt 0 ]; then
        echo "Consider addressing warnings to improve compliance."
    fi
    echo ""
    exit 0
else
    echo -e "${RED}❌ Constitutional compliance FAILED${NC}"
    echo ""
    echo "Critical issues must be resolved before proceeding."
    echo "See failures above for details."
    echo ""
    exit 1
fi
