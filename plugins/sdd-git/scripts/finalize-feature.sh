#!/usr/bin/env bash
# T046: DS-STAR Multi-Agent Enhancement - Finalizer Integration
# Compliance validation before git operations (NEVER auto-commits per Principle VI)
set -e

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo ""
            echo "DS-STAR Compliance Finalizer - Pre-commit validation"
            echo ""
            echo "Validates implementation against all 14 constitutional principles:"
            echo "  - Tests passing and coverage >80%"
            echo "  - No linting errors"
            echo "  - Code style compliance"
            echo "  - Documentation synchronized"
            echo "  - No secrets in code"
            echo "  - Constitutional compliance"
            echo ""
            echo "IMPORTANT: This command NEVER performs git operations autonomously."
            echo "It provides a compliance report and suggests manual git commands."
            echo ""
            exit 0
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
CURRENT_BRANCH=$(get_current_branch)

echo ""
echo "=========================================="
echo "DS-STAR Compliance Finalizer"
echo "Constitutional Principle VI: NO AUTONOMOUS GIT OPERATIONS"
echo "=========================================="
echo ""
echo "Current Branch: $CURRENT_BRANCH"
echo ""

# Check if Python and DS-STAR components are available
if ! command -v python3 &> /dev/null || [ ! -d "$REPO_ROOT/src/sdd" ]; then
    echo "Note: DS-STAR components not installed"
    echo "Recommendation: Manually verify constitutional compliance before committing"
    echo ""
    exit 0
fi

# Generate task_id for tracking
TASK_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")

# Get feature directory if on feature branch
FEATURE_DIR=""
if [[ "$CURRENT_BRANCH" =~ ^[0-9]{3}- ]]; then
    FEATURE_DIR="$REPO_ROOT/specs/$CURRENT_BRANCH"
fi

# Invoke Compliance Finalizer
# Uses FinalizerAgent from src/sdd/agents/quality/finalizer.py
echo "Running compliance validation..."
echo ""

python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/src')

from sdd.agents.quality.finalizer import FinalizerAgent
from sdd.agents.shared.models import AgentInput, AgentContext

try:
    # Initialize finalizer
    finalizer = FinalizerAgent()

    # Create agent input
    agent_input = AgentInput(
        agent_id='quality.finalizer',
        task_id='$TASK_ID',
        phase='validation',
        input_data={
            'repo_root': '$REPO_ROOT',
            'branch': '$CURRENT_BRANCH',
            'feature_dir': '$FEATURE_DIR' if '$FEATURE_DIR' else None
        },
        context=AgentContext()
    )

    # Run compliance checks
    result = finalizer.validate(agent_input)

    # Display results
    print('=' * 70)
    print('COMPLIANCE REPORT')
    print('=' * 70)
    print('')

    compliance_data = result.output_data
    overall_pass = compliance_data.get('all_checks_passed', False)
    checks = compliance_data.get('checks', {})
    violations = compliance_data.get('violations', [])
    recommendations = compliance_data.get('recommendations', [])

    # Display check results
    print('Constitutional Compliance Checks:')
    print('')
    for check_name, check_result in checks.items():
        status = '✓' if check_result.get('passed', False) else '✗'
        score = check_result.get('score', 0.0)
        print(f'  {status} {check_name}: {score:.0%}')
        if not check_result.get('passed', False) and 'message' in check_result:
            print(f'      {check_result[\"message\"]}')
    print('')

    # Display violations
    if violations:
        print('Constitutional Violations:')
        print('')
        for i, violation in enumerate(violations, 1):
            print(f'  {i}. {violation}')
        print('')

    # Display recommendations
    if recommendations:
        print('Recommendations:')
        print('')
        for i, rec in enumerate(recommendations, 1):
            print(f'  {i}. {rec}')
        print('')

    # Overall result
    print('=' * 70)
    if overall_pass:
        print('✓ ALL CHECKS PASSED - Ready for commit')
        print('=' * 70)
        print('')
        print('Suggested git commands (MANUAL EXECUTION REQUIRED):')
        print('')
        print('  1. Review changes:')
        print('       git status')
        print('       git diff')
        print('')
        print('  2. Stage changes:')
        print('       git add <files>')
        print('')
        print('  3. Commit:')
        print('       git commit -m \"<message>\"')
        print('')
        print('  4. Push to remote:')
        print('       git push origin $CURRENT_BRANCH')
        print('')
        print('IMPORTANT: You must execute these commands manually.')
        print('The framework NEVER performs git operations autonomously (Principle VI).')
    else:
        print('✗ CHECKS FAILED - Do not commit yet')
        print('=' * 70)
        print('')
        print('Action Required: Address violations above before committing.')
        print('Run this command again after fixes to verify compliance.')
    print('')

    sys.exit(0 if overall_pass else 1)

except Exception as e:
    print(f'Error: Compliance validation failed: {e}')
    print('')
    print('Recommendation: Manually verify constitutional compliance')
    sys.exit(2)
" || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 1 ]; then
        echo "=========================================="
        echo ""
        echo "Compliance validation failed. Please address issues above."
        echo ""
        exit 1
    else
        echo "=========================================="
        echo ""
        echo "Validation error. Manual review recommended."
        echo ""
        exit 2
    fi
}

echo "=========================================="
echo ""
