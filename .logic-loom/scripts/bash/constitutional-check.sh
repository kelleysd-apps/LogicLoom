#!/bin/bash
# Constitutional Compliance Checker for LogicLoom
# Validates adherence to Constitutional Principles
# Authority: Constitution v3.3.0

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
echo "Constitution: v3.3.0"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
# CHECK_WARN_COUNT counts the principle CHECKS whose verdict was "warning".
# WARN_COUNT counts warning FINDINGS — one check (e.g. XV) can record several.
# Only CHECK_WARN_COUNT is comparable against the 16 principle checks.
CHECK_WARN_COUNT=0
ISSUES=()
WARNINGS=()
SKIPS=()

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

# Function to record a check that was NOT performed (not applicable to this
# repository shape). A skip is not a pass: it must never increment PASS_COUNT,
# because nothing was actually verified.
record_skip() {
    local message="$1"
    SKIPS+=("$message")
    ((SKIP_COUNT++))
}

# Product workspace roots, per CLAUDE.md § "Harness ↔ product boundary":
# the repo root (package.json, tests/, .claude/, .logic-loom/, plugins/) is
# FRAMEWORK-owned, and product application code lives in web/ (single app) or
# apps/<name>/ (monorepo). There is no src/ or libs/ at the root by design, so
# checks that look for product-code patterns must scan these roots — scanning
# src/ or libs/ produces false negatives in a harness-only checkout.
PRODUCT_ROOTS=()
[ -d "$REPO_ROOT/web" ] && PRODUCT_ROOTS+=("$REPO_ROOT/web")
if [ -d "$REPO_ROOT/apps" ]; then
    for app_dir in "$REPO_ROOT/apps"/*; do
        [ -d "$app_dir" ] && PRODUCT_ROOTS+=("$app_dir")
    done
fi

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
    ((CHECK_WARN_COUNT++))
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
    ((CHECK_WARN_COUNT++))
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
    ((CHECK_WARN_COUNT++))
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
    ((CHECK_WARN_COUNT++))
fi
echo ""

#
# ============================================
# Principle V: Progressive Enhancement
# ============================================
#
echo -e "${BLUE}[5/16] Principle V: Progressive Enhancement${NC}"
echo "Checking for feature flags or gradual rollout..."

# Feature flags are PRODUCT code, so scan the product workspace roots (web/,
# apps/*) from CLAUDE.md § "Harness ↔ product boundary" — not src/ or libs/,
# which cannot exist in this framework-owned root.
FEATURE_FLAGS=false
if [ ${#PRODUCT_ROOTS[@]} -gt 0 ]; then
    if grep -r "feature.*flag\|featureFlag\|FEATURE_FLAG\|enabled.*feature" "${PRODUCT_ROOTS[@]}" 2>/dev/null | grep -q .; then
        FEATURE_FLAGS=true
    fi
fi

if [ "$FEATURE_FLAGS" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Feature flag patterns found"
    ((PASS_COUNT++))
else
    # SKIP even when a product workspace DOES exist — deliberately, and unlike
    # XII/XIII below. Feature flags are ONE valid technique for progressive
    # enhancement, not a requirement of it: a product can enhance progressively
    # via capability detection, graceful degradation, or staged deploys and
    # carry no flag at all. So the absence of flag patterns is never evidence of
    # a violation, and this check can only ever be INFORMATIONAL — it can report
    # "flags found" (PASS) or "nothing to evaluate" (SKIP), never WARN or FAIL.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No feature-flag surface to check"
    record_skip "Principle V: no feature-flag / gradual-rollout surface present — not evaluated (flags are one optional technique; absence is not a violation)"
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
# Tracks whether ANY script actually performs git operations. Without this, a
# checkout with no git-using scripts fell through silently: no PASS, no FAIL,
# no line printed at all — the check vanished from the summary entirely.
GIT_SCRIPTS_SEEN=false
for script in "$REPO_ROOT/.logic-loom/scripts/bash/"*.sh "$REPO_ROOT/"*.sh; do
    [ -f "$script" ] || continue
    [[ "$script" == *"constitutional-check.sh" ]] && continue

    # Check if script has git commands
    if grep -q "^\s*git\s\+\(checkout\|commit\|push\|branch\|init\|add\)" "$script" 2>/dev/null; then
        GIT_SCRIPTS_SEEN=true
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

if [ "$GIT_APPROVAL_FOUND" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Git operations have approval mechanisms"
    ((PASS_COUNT++))
elif [ "$GIT_SCRIPTS_SEEN" = false ]; then
    # No script performs git operations, so no approval gate was verified. This
    # is a SKIP, not a pass — the FAIL branch above is untouched and still the
    # only blocking verdict in this script.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No script performs git operations — no approval gate to verify"
    record_skip "Principle VI: no git-performing scripts found — approval gating not evaluated"
fi
echo ""

#
# ============================================
# Principle VII: Observability & Logging
# ============================================
#
echo -e "${BLUE}[7/16] Principle VII: Observability & Structured Logging${NC}"
echo "Checking for logging infrastructure..."

# Scan the PRODUCT workspace roots (web/, apps/*) defined by CLAUDE.md
# § "Harness ↔ product boundary" — not src/ or libs/, which cannot hold product
# code in this layout. With no product workspace present there is no application
# code to instrument, so this is a SKIP (nothing checked), never a warning that
# logging is missing.
if [ ${#PRODUCT_ROOTS[@]} -eq 0 ]; then
    echo -e "   ${BLUE}⊘ SKIP${NC}: No product workspace to check (no web/ or apps/*)"
    record_skip "Principle VII: no product workspace (web/, apps/*) present — logging not evaluated"
else
    LOGGING_FOUND=false
    if grep -r "console\.log\|logger\|logging\|log\.info\|log\.error" "${PRODUCT_ROOTS[@]}" 2>/dev/null | head -1 | grep -q .; then
        LOGGING_FOUND=true
    fi

    if [ "$LOGGING_FOUND" = true ]; then
        echo -e "   ${GREEN}✅ PASS${NC}: Logging patterns found in product workspace"
        ((PASS_COUNT++))
    else
        echo -e "   ${YELLOW}⚠${NC}  WARNING: No logging patterns detected in product workspace"
        record_warn "Operations should emit structured logs for observability"
        ((CHECK_WARN_COUNT++))
    fi
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
    ((CHECK_WARN_COUNT++))
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
    # NOT a pass: with no manifest of any kind there is no dependency surface to
    # evaluate for pinning/hygiene. Nothing was verified.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No dependency manifest to check"
    record_skip "Principle IX: no dependency manifest (package.json/requirements.txt/...) present — not evaluated"
fi
echo ""

#
# ============================================
# Principle X: Agent Delegation Protocol
# ============================================
#
# NOTE: warn-only by design. Constitution v3.1.0 rewrote Principle X as
# "Delegation & Context Isolation" and states plainly that it is "guidance, not
# a mandatory per-message ceremony ... no skills-first gate to 'violate'", with
# real enforcement living in the hooks. Both probes below (does plugins/*/agents/
# contain files; does agent-collaboration-triggers.md exist) are presence
# heuristics for optional infrastructure — a repo can delegate correctly with
# neither. There is no objective violation here to promote to a FAIL, so the
# label is "advisory", not "(CRITICAL)".
echo -e "${BLUE}[10/16] Principle X: Delegation & Context Isolation (advisory)${NC}"
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
    ((CHECK_WARN_COUNT++))
elif [ "$TRIGGERS_EXIST" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Triggers defined but no agents created"
    record_warn "Create specialized agents in plugins/*/agents/"
    ((CHECK_WARN_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: No agent infrastructure found"
    record_warn "Agent Delegation Protocol requires specialized agents and trigger definitions"
    ((CHECK_WARN_COUNT++))
fi
echo ""

#
# ============================================
# Principle XI: Input Validation & Output Sanitization
# ============================================
#
echo -e "${BLUE}[11/16] Principle XI: Input Validation & Output Sanitization${NC}"
echo "Checking for validation patterns..."

# Input-validation patterns are a PRODUCT-code concern, so scan the product
# workspace roots (web/, apps/*) from CLAUDE.md § "Harness ↔ product boundary"
# rather than src/ or libs/, which cannot exist in this framework-owned root.
VALIDATION_FOUND=false
if [ ${#PRODUCT_ROOTS[@]} -gt 0 ]; then
    if grep -r "validate\|sanitize\|escape\|zod\|yup\|joi" "${PRODUCT_ROOTS[@]}" 2>/dev/null | head -1 | grep -q .; then
        VALIDATION_FOUND=true
    fi
fi

# Secret protection is repo-wide, NOT product-specific — it stays checkable even
# when no product workspace exists, so it is never skipped away.
GITIGNORE_SECRETS=false
if [ -f "$REPO_ROOT/.gitignore" ]; then
    if grep -q "\.env\|secrets\|credentials" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        GITIGNORE_SECRETS=true
    fi
fi

if [ ${#PRODUCT_ROOTS[@]} -eq 0 ]; then
    # No application code exists to validate its inputs. Report the honest
    # partial result: the validation half is unchecked (SKIP), but a missing
    # secret-protection rule is still a real finding and still warns.
    if [ "$GITIGNORE_SECRETS" = true ]; then
        echo -e "   ${BLUE}⊘ SKIP${NC}: No product workspace to check (no web/ or apps/*); secrets are gitignored"
        record_skip "Principle XI: no product workspace (web/, apps/*) present — input validation not evaluated (.gitignore secret protection verified)"
    else
        echo -e "   ${YELLOW}⚠${NC}  WARNING: No secret protection in .gitignore (input validation not evaluated — no product workspace)"
        record_warn "Ensure .env, secrets, and credentials are in .gitignore"
        ((CHECK_WARN_COUNT++))
    fi
elif [ "$VALIDATION_FOUND" = true ] && [ "$GITIGNORE_SECRETS" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Validation patterns and secret protection found"
    ((PASS_COUNT++))
elif [ "$GITIGNORE_SECRETS" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Secrets protected but no validation patterns found in product workspace"
    record_warn "Add input validation (zod, yup, joi) to prevent security issues"
    ((CHECK_WARN_COUNT++))
elif [ "$VALIDATION_FOUND" = true ]; then
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Validation found but check .gitignore for secret protection"
    record_warn "Ensure .env, secrets, and credentials are in .gitignore"
    ((CHECK_WARN_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Limited security patterns detected"
    record_warn "Add input validation and ensure secrets are gitignored"
    ((CHECK_WARN_COUNT++))
fi
echo ""

#
# ============================================
# Principle XII: Design System Compliance
# ============================================
#
echo -e "${BLUE}[12/16] Principle XII: Design System Compliance${NC}"
echo "Checking for design system..."

# Design-system compliance is a PRODUCT-UI concern, so scan the product
# workspace roots (web/, apps/*) from CLAUDE.md § "Harness ↔ product boundary"
# rather than src/ or libs/, which cannot exist in this framework-owned root.
#
# The verdict is CONDITIONAL on there being UI at all. A design system is only
# meaningful where something renders, so the gate is "are there UI files", not
# "is there a product workspace": a backend-only web/ has no design system to
# comply with (SKIP, nothing verified), but a workspace that ships components
# and stylesheets with no tokens/theme is a real gap worth flagging (WARN).
UI_FILES_FOUND=false
DESIGN_SYSTEM=false
if [ ${#PRODUCT_ROOTS[@]} -gt 0 ]; then
    if find "${PRODUCT_ROOTS[@]}" -type f \( -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" -o -name "*.css" -o -name "*.scss" \) 2>/dev/null | head -1 | grep -q .; then
        UI_FILES_FOUND=true
    fi
    # Detection signals unchanged from the original check — only the scan root
    # and the meaning of an empty result have changed.
    if grep -r "theme\|design.*system\|colors.*palette\|typography" "${PRODUCT_ROOTS[@]}" 2>/dev/null | head -1 | grep -q .; then
        DESIGN_SYSTEM=true
    fi
fi

if [ "$UI_FILES_FOUND" = false ]; then
    # No UI anywhere in the product workspace (or no workspace at all): nothing
    # was verified, and that is not a finding.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No UI surface to check (no *.jsx/tsx/vue/svelte/css/scss in a product workspace)"
    record_skip "Principle XII: no UI surface present — design system not evaluated"
elif [ "$DESIGN_SYSTEM" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Design system patterns found"
    ((PASS_COUNT++))
else
    echo -e "   ${YELLOW}⚠${NC}  WARNING: UI files exist but no design-system patterns detected"
    record_warn "Product workspace ships UI but no design tokens/theme/palette/typography definitions — add a design system"
    ((CHECK_WARN_COUNT++))
fi
echo ""

#
# ============================================
# Principle XIII: Feature Access Control
# ============================================
#
echo -e "${BLUE}[13/16] Principle XIII: Feature Access Control${NC}"
echo "Checking for access control patterns..."

# Access control is enforced in PRODUCT code, so scan the product workspace
# roots (web/, apps/*) from CLAUDE.md § "Harness ↔ product boundary" rather than
# src/ or libs/. specs/ is kept as an additional signal source (unchanged from
# the original check) — a spec can document the authz model — but the check is
# gated on a product workspace existing, since that is where authz must live.
ACCESS_CONTROL=false
if [ ${#PRODUCT_ROOTS[@]} -gt 0 ]; then
    if grep -r "access.*control\|authorization\|permission\|role\|tier\|RLS\|row.*level.*security" "${PRODUCT_ROOTS[@]}" "$REPO_ROOT/specs" 2>/dev/null | head -1 | grep -q .; then
        ACCESS_CONTROL=true
    fi
fi

if [ ${#PRODUCT_ROOTS[@]} -eq 0 ]; then
    # Nothing was verified about access control — there is no application to
    # gate. Not a finding.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No product workspace to check (no web/ or apps/*)"
    record_skip "Principle XIII: no product workspace (web/, apps/*) present — access control not evaluated"
elif [ "$ACCESS_CONTROL" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: Access control patterns found"
    ((PASS_COUNT++))
else
    # WARN, not SKIP — unlike XII, whose absence may just mean "no UI here".
    # A shipping product workspace with NO authorization signal anywhere is a
    # security-relevant finding: either the app genuinely has no access control,
    # or it has one that is undiscoverable. Both deserve a look.
    echo -e "   ${YELLOW}⚠${NC}  WARNING: Product workspace exists but no access-control patterns found"
    record_warn "No authorization/permission/role/RLS patterns in the product workspace — verify feature access control (Principle XIII)"
    ((CHECK_WARN_COUNT++))
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
if grep -r "claude.*sonnet\|claude.*opus\|model.*selection\|AI.*model" "$REPO_ROOT/.claude" "$REPO_ROOT/.logic-loom" "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/AGENTS.md" 2>/dev/null | head -1 | grep -q .; then
    MODEL_CONFIG=true
fi

if [ "$MODEL_CONFIG" = true ]; then
    echo -e "   ${GREEN}✅ PASS${NC}: AI model configuration found"
    ((PASS_COUNT++))
else
    # NOT a pass (same family as V/IX/XII/XIII): no model-selection surface was
    # found, so the selection protocol was not evaluated at all.
    echo -e "   ${BLUE}⊘ SKIP${NC}: No AI model configuration to check"
    record_skip "Principle XIV: no AI model selection configuration present — not evaluated"
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
#
# EXCEPTION (ratified v6.3.1 — do NOT "fix" this back):
# The orchestrator/worker ladder agents `deep-reasoner` and `fast-worker` MUST
# stay as PROJECT agents in .claude/agents/. Plugin agents lose the `hooks`,
# `mcpServers`, and `permissionMode` frontmatter keys, which those two rely on.
# See CLAUDE.md § "Orchestrator + worker ladder". Only agent files OUTSIDE this
# sanctioned set are flagged as legacy strays.
SANCTIONED_PROJECT_AGENTS=("deep-reasoner.md" "fast-worker.md")
AGENT_ORG=true
if [ -d "$REPO_ROOT/.claude/agents" ]; then
    STRAY_AGENTS=()
    for agent_file in "$REPO_ROOT/.claude/agents"/*.md; do
        [ -f "$agent_file" ] || continue
        agent_base=$(basename "$agent_file")
        is_sanctioned=false
        for sanctioned in "${SANCTIONED_PROJECT_AGENTS[@]}"; do
            if [ "$agent_base" = "$sanctioned" ]; then
                is_sanctioned=true
                break
            fi
        done
        [ "$is_sanctioned" = true ] || STRAY_AGENTS+=("$agent_base")
    done

    if [ ${#STRAY_AGENTS[@]} -gt 0 ]; then
        AGENT_ORG=false
        record_warn "Legacy agent file(s) in .claude/agents/ (${STRAY_AGENTS[*]}) — agents should be in plugins/*/agents/ (only deep-reasoner.md / fast-worker.md are sanctioned project agents)"
    fi
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
    # Specific warning findings already recorded above; this counts the CHECK.
    ((CHECK_WARN_COUNT++))
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
        # Check at least some plugins have a manifest. Claude Code plugin
        # manifests live at plugins/<name>/.claude-plugin/plugin.json (depth 3
        # under plugins/) — match that exact shape rather than a loose depth, so
        # a stray plugin.json elsewhere in the tree can't satisfy the check.
        MANIFEST_COUNT=$(find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -path "*/.claude-plugin/plugin.json" -type f 2>/dev/null | wc -l | xargs)
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
    ((CHECK_WARN_COUNT++))
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
echo -e "${YELLOW}⚠  Warned:${NC} $CHECK_WARN_COUNT/16"
echo -e "${BLUE}⊘  Skipped:${NC} $SKIP_COUNT/16 (not applicable — nothing checked)"
echo ""
echo "Warning findings: $WARN_COUNT (a single check can raise more than one)"
echo ""

# Accounting self-check: every one of the 16 principle checks must land in
# exactly one bucket. If this ever trips, the summary is lying about coverage.
ACCOUNTED=$((PASS_COUNT + FAIL_COUNT + CHECK_WARN_COUNT + SKIP_COUNT))
if [ "$ACCOUNTED" -ne 16 ]; then
    echo -e "${RED}⚠ INTERNAL: verdict accounting is off — $ACCOUNTED of 16 checks accounted for.${NC}"
    echo -e "${RED}  This summary understates or overstates coverage; fix the checker.${NC}"
    echo ""
fi

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

# Show skipped checks — these were NOT verified, and saying so is the point.
if [ $SKIP_COUNT -gt 0 ]; then
    echo -e "${BLUE}Skipped (not applicable — NOT verified):${NC}"
    for skip in "${SKIPS[@]}"; do
        echo -e "${BLUE}  •${NC} $skip"
    done
    echo ""
fi

# Overall status
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ No blocking constitutional violations found${NC}"
    echo ""
    # Deliberately does NOT name principles: only a subset of the 16 checks can
    # produce a FAIL, and that subset changes as checks are hardened. Naming a
    # principle here (as the old "All critical principles (VI, X) are met."
    # wording did) claims verification the script may not actually perform.
    echo "Every check that can fail passed. Most of the 16 principle checks are"
    echo "advisory (warn-only), so a clean run is not proof of full compliance."
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
