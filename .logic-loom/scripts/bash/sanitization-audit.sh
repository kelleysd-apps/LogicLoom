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

# ── TWO MODES, BOTH EXPLICIT. THERE IS NO THIRD, SILENT ONE. ────────────────
#
#   DEFAULT (release-gate mode) — scope is Checks 1-7. Check 7 is REQUIRED.
#       If leak-guard.sh or template-strip-manifest.txt is not beside this
#       script, Check 7 cannot run, and that is a HARD FAILURE — not a skip.
#
#   --origin-only — scope is Checks 1-6 (the ioun-ai origin scrub). Check 7 is
#       declared OUT OF SCOPE, not skipped. Used by the promotion GATE, which
#       runs on un-stripped dev-main where harness-dev artifacts are legitimately
#       still present, so a harness-dev absence assertion is meaningless there.
#
# WHY A MODE AND NOT A `--require-all` FLAG (2026-08-25 — do not "simplify"):
# Check 7 is the ONLY check that asserts the strip actually happened; Checks 1-6
# are about the ORIGINAL project's content and pass on a completely un-stripped
# tree. Until this change, Check 7 self-disabled whenever leak-guard.sh was not
# beside the audit, the denominator shrank to match, and the run printed
# "Passed: 6/6 … 🎉 All checks passed! Framework is sanitized." with EXIT 0 —
# having never looked at whether it was. It ran at all only because
# promote-to-main.yml happens to `cp -R` the whole scripts directory; narrowing
# that copy, or running the audit by hand, silently voided the binding gate.
#
# The fix is to REFUSE TO SKIP in the default mode rather than to add an opt-in
# strictness flag. A `--require-all` flag has to be remembered at every call
# site, and the one call site that matters is the release path — forgetting it
# there reproduces exactly the hole being closed. Strictness therefore rides the
# DEFAULT, which the release invocation already uses unmodified; the only way to
# get the reduced scope is to ASK for it, in writing, on the command line.
ORIGIN_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --origin-only) ORIGIN_ONLY=1 ;;
    esac
done

# The number of checks IN SCOPE for this invocation. FIXED per mode, declared up
# front, and asserted against the number that actually ran (see the summary). A
# check that fails to run can no longer shrink the denominator to hide itself.
if [ "$ORIGIN_ONLY" -eq 1 ]; then
    SCOPE_TOTAL=6
    MODE_LABEL="origin-only (Checks 1-6; Check 7 out of scope)"
else
    SCOPE_TOTAL=7
    MODE_LABEL="release gate (Checks 1-7; Check 7 required)"
fi

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
echo -e "${BLUE}[1/${SCOPE_TOTAL}] Checking for hardcoded project paths...${NC}"
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
echo -e "${BLUE}[2/${SCOPE_TOTAL}] Checking for unapproved git operations...${NC}"

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
echo -e "${BLUE}[3/${SCOPE_TOTAL}] Checking for specific design system requirements...${NC}"
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
echo -e "${BLUE}[4/${SCOPE_TOTAL}] Checking for specific tier names in constitution...${NC}"
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
#
# ── WHY `character` IS NO LONGER A TERM (2026-08-25) ─────────────────────────
# This check screens for vocabulary from the ORIGINAL project this framework was
# extracted from (a D&D product) leaking into a general-purpose harness. A bare
# `\bcharacter[s]?\b` stopped being evidence of that. It is ordinary software
# English — "character encoding", "1024 characters", "any character except a
# tab" — and the check had already accreted FIVE exclusions for that one term
# (character encoding / special character / characters\. / max.*characters /
# [0-9].*characters), each added after a false positive blocked something.
#
# It then blocked a release anyway: `project-backlog-template.md` documents a
# grammar and says "may contain any character except a tab", which no exclusion
# covered. The gate job failed, so the release could not start — on correct,
# accurate prose. That is how a gate dies: the next person's cheapest move is to
# reword true documentation to appease a grep, or to add a sixth exclusion.
#
# So the term was NARROWED rather than excluded: `character` now only trips in
# PHRASES that are actually domain vocabulary (player character, character
# sheet/creation/class/build/level). The five `character` exclusions are deleted
# with it — an exclusion for a term that is no longer screened is dead weight of
# exactly the kind this repo has been clearing.
#
# SIGNAL GIVEN UP, stated plainly: a bare singular D&D-sense use that avoids all
# of those phrasings — e.g. "the character's inventory" — is no longer caught.
# `campaign`, `npc`, and `dm` are unchanged and still carry the check, and any
# realistic leak of that vocabulary brings one of them along. Do NOT restore the
# bare term; if a new leak shape appears, add the PHRASE, not an exclusion.
echo -e "${BLUE}[5/${SCOPE_TOTAL}] Checking for domain-specific terminology...${NC}"
DOMAIN_TERMS=$(grep -iE "\bcampaign[s]?\b|\bnpc[s]?\b|\bdm\b|\b(player|non-player) character[s]?\b|\bcharacter (sheet|creation|class|build|level)[s]?\b" \
    "$REPO_ROOT/.logic-loom/memory/constitution.md" \
    "$REPO_ROOT/.logic-loom/templates/"*.md 2>/dev/null | \
    grep -v "example" | \
    grep -v "case study" | \
    grep -v "Case Study" | \
    grep -v "user session" | \
    grep -v "http session" | \
    grep -v "session management" || true)

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
echo -e "${BLUE}[6/${SCOPE_TOTAL}] Checking for specific tech stack requirements...${NC}"
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
# leak-guard.sh. THE ONLY CHECK THAT ASSERTS THE STRIP HAPPENED — Checks 1-6 are
# about the ORIGINAL project's content and pass fine on an un-stripped tree.
#
# It runs in the private dev repo during a promotion build (post-strip), from the
# PRESERVED tooling copy. It is OUT OF SCOPE (never merely "skipped") under
# --origin-only. In default mode its tooling MUST be present: leak-guard.sh and
# template-strip-manifest.txt are stripped by the SAME manifest entry that strips
# this audit script, so on a real public template none of the three exist and
# nothing can invoke this. A default-mode run that cannot find them is therefore
# a broken invocation, not a supported configuration — and it fails.
if [ "$ORIGIN_ONLY" -eq 1 ]; then
    echo -e "${BLUE}[7] Harness-dev artifact check: ${YELLOW}OUT OF SCOPE${NC} (--origin-only was requested)"
    echo -e "   ${YELLOW}This run does NOT assert the strip happened. It is not a release-gate verdict.${NC}"
    echo ""
else
    echo -e "${BLUE}[7/${SCOPE_TOTAL}] Checking for harness-dev artifacts (manifest)...${NC}"
    MISSING_TOOLING=""
    [ -f "$SCRIPT_DIR/leak-guard.sh" ] || MISSING_TOOLING="$MISSING_TOOLING leak-guard.sh"
    [ -f "$SCRIPT_DIR/template-strip-manifest.txt" ] || MISSING_TOOLING="$MISSING_TOOLING template-strip-manifest.txt"

    if [ -n "$MISSING_TOOLING" ]; then
        echo -e "   ${RED}❌ FAIL${NC}: Check 7 CANNOT RUN — missing beside this script ($SCRIPT_DIR):$MISSING_TOOLING"
        echo -e "   ${YELLOW}Check 7 is the only check that asserts the strip actually happened.${NC}"
        echo -e "   ${YELLOW}Run the audit from the PRESERVED tooling copy, e.g.${NC}"
        echo -e "   ${YELLOW}  LOOM_AUDIT_ROOT=\"\$PWD\" bash /tmp/loom-audit-tools/sanitization-audit.sh${NC}"
        echo -e "   ${YELLOW}or pass --origin-only if you genuinely only want Checks 1-6.${NC}"
        record_fail "Check 7 could not run (missing:$MISSING_TOOLING) — the strip was NEVER verified. This is a broken audit invocation, not a sanitized tree."
    elif bash "$SCRIPT_DIR/leak-guard.sh"; then
        echo -e "   ${GREEN}✅ PASS${NC}: No harness-dev artifacts present"
        ((PASS_COUNT++))
    else
        echo -e "   ${RED}❌ FAIL${NC}: harness-dev artifacts present (see above)"
        record_fail "Harness-dev artifacts present on template tree (VISION/dev docs/release plumbing)"
    fi
    echo ""
fi

# ── Results Summary ─────────────────────────────────────────────────────────
# The denominator is SCOPE_TOTAL — fixed by the mode, decided before any check
# ran. It was previously PASS+FAIL, i.e. derived from whatever happened to
# execute, so a check that silently declined to run also silently removed itself
# from the score and "6/6 passed" was printed for a 7-check audit. RAN is now
# reconciled against SCOPE_TOTAL and any shortfall is itself a failure, so this
# class of hole cannot come back through a different door.
RAN=$((PASS_COUNT + FAIL_COUNT))
if [ "$RAN" -ne "$SCOPE_TOTAL" ]; then
    record_fail "AUDIT INVARIANT BREACH: $RAN of $SCOPE_TOTAL in-scope checks reported a verdict. An in-scope check did not run; treat this run as having proven nothing."
fi

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Audit Results${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "Mode: $MODE_LABEL"
echo -e "${GREEN}✅ Passed:${NC} $PASS_COUNT/$SCOPE_TOTAL"
echo -e "${RED}❌ Failed:${NC} $FAIL_COUNT/$SCOPE_TOTAL"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    if [ "$ORIGIN_ONLY" -eq 1 ]; then
        echo -e "${GREEN}✅ Origin checks (1-6) passed.${NC} ${YELLOW}Check 7 was out of scope — the strip is NOT asserted by this run.${NC}"
    else
        echo -e "${GREEN}🎉 All checks passed! Framework is sanitized.${NC}"
    fi
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
