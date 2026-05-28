#!/usr/bin/env python3
"""
T044: DS-STAR Multi-Agent Enhancement - Auto-Debug Wrapper
Automatic error detection and repair wrapper script.

Purpose:
    Provides CLI interface for AutoDebugAgent to be invoked from bash scripts.
    Detects common errors (syntax, type, null, name, import) and attempts automatic repairs.
    Applies fixes and returns success/failure for bash error handling.

Constitutional Compliance:
    - Principle I: Library-First - Uses autodebug agent library
    - Principle II: Test-First - Validates fixes against specs
    - Principle IV: Idempotent - Max 5 iterations prevents infinite loops
    - Principle VII: Observability - Logs all debug attempts

Usage:
    python3 auto_debug_wrapper.py --error-message "NameError: name 'x' not defined" \\
        --stack-trace "$(cat stacktrace.txt)" \\
        --code-file "/path/to/file.py" \\
        --spec-path "/path/to/spec.md" \\
        --task-id "uuid"

Exit Codes:
    0: Successfully fixed and tests pass
    1: Max iterations reached without fix
    2: Error during debug process
"""

import argparse
import json
import logging
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main entry point for auto-debug wrapper."""
    parser = argparse.ArgumentParser(
        description="DS-STAR Auto-Debug Wrapper for automatic error repair"
    )
    parser.add_argument(
        "--error-message",
        required=True,
        help="Error message from test/execution failure"
    )
    parser.add_argument(
        "--stack-trace",
        required=True,
        help="Full stack trace of the error"
    )
    parser.add_argument(
        "--code-file",
        required=True,
        help="Path to code file with error"
    )
    parser.add_argument(
        "--spec-path",
        required=False,
        help="Path to specification for validation"
    )
    parser.add_argument(
        "--task-id",
        required=True,
        help="Task ID for tracking debug session"
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=5,
        help="Maximum debug iterations (default: 5)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON format"
    )

    args = parser.parse_args()

    # Validate inputs
    code_file = Path(args.code_file)
    if not code_file.exists():
        logger.error(f"Code file not found: {args.code_file}")
        sys.exit(2)

    try:
        # Import DS-STAR components
        from sdd.agents.engineering.autodebug import AutoDebugAgent
        from sdd.agents.shared.models import AgentInput, AgentContext

        # Initialize auto-debug agent
        logger.info("Initializing AutoDebugAgent...")
        debug_agent = AutoDebugAgent()

        # Read code content
        code_content = code_file.read_text()

        # Create agent input
        agent_input = AgentInput(
            agent_id="engineering.autodebug",
            task_id=args.task_id,
            phase="implementation",
            input_data={
                "error_message": args.error_message,
                "stack_trace": args.stack_trace,
                "code_file": str(code_file),
                "code_content": code_content,
                "max_iterations": args.max_iterations
            },
            context=AgentContext(
                spec_path=args.spec_path if args.spec_path else None
            )
        )

        # Invoke auto-debug
        logger.info(f"Starting auto-debug session (max {args.max_iterations} iterations)...")
        result = debug_agent.debug(agent_input)

        # Extract results
        success = result.success
        output_data = result.output_data
        fix_applied = output_data.get("fix_applied", False)
        iterations = output_data.get("iterations", 0)
        fixed_code = output_data.get("fixed_code", None)
        escalation = output_data.get("escalation", False)

        # Apply fix if successful
        if fix_applied and fixed_code:
            logger.info(f"Fix successful after {iterations} iteration(s)")
            # Write fixed code back to file
            code_file.write_text(fixed_code)
            logger.info(f"Applied fix to {code_file}")

            if args.json:
                print(json.dumps({
                    "success": True,
                    "fixed": True,
                    "iterations": iterations,
                    "code_file": str(code_file),
                    "reasoning": result.reasoning
                }))
            else:
                print(f"✓ Auto-debug successful ({iterations} iterations)")
                print(f"  Fixed code written to: {code_file}")
                print(f"  Reasoning: {result.reasoning}")

            sys.exit(0)

        elif escalation:
            logger.warning(f"Max iterations ({args.max_iterations}) reached, escalating to human")
            attempted_fixes = output_data.get("attempted_fixes", [])

            if args.json:
                print(json.dumps({
                    "success": False,
                    "escalated": True,
                    "iterations": iterations,
                    "attempted_fixes": attempted_fixes,
                    "reasoning": result.reasoning
                }))
            else:
                print(f"✗ Auto-debug escalation after {iterations} iterations")
                print(f"  Attempted fixes:")
                for i, fix in enumerate(attempted_fixes, 1):
                    print(f"    {i}. {fix}")
                print(f"  Reasoning: {result.reasoning}")
                print(f"  Action required: Manual debugging needed")

            sys.exit(1)

        else:
            logger.error("Auto-debug failed without fix or escalation")
            if args.json:
                print(json.dumps({
                    "success": False,
                    "error": result.reasoning
                }))
            else:
                print(f"✗ Auto-debug failed: {result.reasoning}")

            sys.exit(2)

    except ImportError as e:
        logger.error(f"DS-STAR components not available: {e}")
        if args.json:
            print(json.dumps({
                "success": False,
                "error": "DS-STAR components not installed"
            }))
        else:
            print("Error: DS-STAR components not installed")
            print("Install dependencies: pip install -r requirements.txt")
        sys.exit(2)

    except Exception as e:
        logger.error(f"Auto-debug error: {e}", exc_info=True)
        if args.json:
            print(json.dumps({
                "success": False,
                "error": str(e)
            }))
        else:
            print(f"Error: Auto-debug failed: {e}")
        sys.exit(2)


if __name__ == "__main__":
    main()
