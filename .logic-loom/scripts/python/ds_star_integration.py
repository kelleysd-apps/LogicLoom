#!/usr/bin/env python3
"""
DS-STAR Integration Module
Provides integration points for DS-STAR components with existing workflows.

Usage:
    python -m .specify.scripts.python.ds_star_integration verify_spec <spec_path>
    python -m .specify.scripts.python.ds_star_integration verify_plan <plan_path>
    python -m .specify.scripts.python.ds_star_integration finalize <feature_dir>
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src"))

try:
    from sdd.agents.quality.verifier import VerificationAgent
    from sdd.agents.quality.finalizer import FinalizerAgent
    from sdd.agents.shared.models import AgentInput, AgentContext
    DS_STAR_AVAILABLE = True
except ImportError as e:
    DS_STAR_AVAILABLE = False
    IMPORT_ERROR = str(e)


def verify_spec(spec_path: str) -> int:
    """Verify specification quality."""
    if not DS_STAR_AVAILABLE:
        print(f"⚠️  DS-STAR not available: {IMPORT_ERROR}", file=sys.stderr)
        print("Continuing without verification...", file=sys.stderr)
        return 0  # Don't block workflow

    try:
        agent = VerificationAgent()
        agent_input = {
            "agent_id": "quality.verifier",
            "task_id": Path(spec_path).parent.name,
            "phase": "specification",
            "artifact_type": "spec",
            "artifact_path": spec_path,
        }

        result = agent.verify(agent_input)

        if not result.get("success"):
            print(f"❌ Verification failed: {result.get('reasoning')}", file=sys.stderr)
            return 1

        decision = result["output_data"].get("decision")
        quality_score = result["output_data"].get("quality_score", 0.0)

        print(f"\n{'='*60}")
        print(f"📊 Specification Verification Results")
        print(f"{'='*60}")
        print(f"Decision: {decision.upper()}")
        print(f"Quality Score: {quality_score:.2f}")

        if decision == "insufficient":
            print(f"\n⚠️  Quality Threshold Not Met")
            feedback = result["output_data"].get("feedback", [])
            if feedback:
                print(f"\n📝 Recommendations:")
                for item in feedback:
                    print(f"  • {item}")
            return 0  # Don't block for now, just inform
        else:
            print(f"\n✅ Specification meets quality standards!")
            return 0

    except Exception as e:
        print(f"⚠️  Verification error: {e}", file=sys.stderr)
        return 0  # Don't block workflow on errors


def verify_plan(plan_path: str) -> int:
    """Verify implementation plan quality."""
    if not DS_STAR_AVAILABLE:
        print(f"⚠️  DS-STAR not available: {IMPORT_ERROR}", file=sys.stderr)
        return 0

    try:
        agent = VerificationAgent()
        agent_input = {
            "agent_id": "quality.verifier",
            "task_id": Path(plan_path).parent.name,
            "phase": "planning",
            "artifact_type": "plan",
            "artifact_path": plan_path,
        }

        result = agent.verify(agent_input)

        if not result.get("success"):
            print(f"❌ Verification failed: {result.get('reasoning')}", file=sys.stderr)
            return 1

        decision = result["output_data"].get("decision")
        quality_score = result["output_data"].get("quality_score", 0.0)

        print(f"\n{'='*60}")
        print(f"📊 Plan Verification Results")
        print(f"{'='*60}")
        print(f"Decision: {decision.upper()}")
        print(f"Quality Score: {quality_score:.2f}")

        if decision == "insufficient":
            print(f"\n⚠️  Quality Threshold Not Met")
            feedback = result["output_data"].get("feedback", [])
            if feedback:
                print(f"\n📝 Recommendations:")
                for item in feedback:
                    print(f"  • {item}")
            return 0  # Don't block for now
        else:
            print(f"\n✅ Plan meets quality standards!")
            return 0

    except Exception as e:
        print(f"⚠️  Verification error: {e}", file=sys.stderr)
        return 0


def finalize_feature(feature_dir: str) -> int:
    """Run compliance finalizer on feature."""
    if not DS_STAR_AVAILABLE:
        print(f"⚠️  DS-STAR not available: {IMPORT_ERROR}", file=sys.stderr)
        return 0

    try:
        agent = FinalizerAgent()
        agent_input = {
            "agent_id": "quality.finalizer",
            "task_id": Path(feature_dir).name,
            "phase": "finalization",
            "feature_dir": feature_dir,
        }

        result = agent.finalize(agent_input)

        print(f"\n{'='*60}")
        print(f"📋 Compliance Finalizer Report")
        print(f"{'='*60}")

        report = result["output_data"]
        checks = report.get("checks", {})

        for check_name, check_result in checks.items():
            status = "✅" if check_result else "❌"
            print(f"{status} {check_name.replace('_', ' ').title()}")

        violations = report.get("violations", [])
        if violations:
            print(f"\n⚠️  Violations Found:")
            for v in violations:
                print(f"  • {v}")

        git_ops = report.get("git_operations_needed", [])
        if git_ops:
            print(f"\n🔧 Recommended Git Operations:")
            for op in git_ops:
                print(f"  • {op}")
            print(f"\n⚠️  IMPORTANT: Review and execute git operations manually (Principle VI)")

        if report.get("ready_to_commit"):
            print(f"\n✅ Feature is ready for commit!")
        else:
            print(f"\n⚠️  Feature needs attention before commit")

        return 0

    except Exception as e:
        print(f"⚠️  Finalizer error: {e}", file=sys.stderr)
        return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: ds_star_integration.py <command> [args]")
        print("Commands: verify_spec, verify_plan, finalize")
        return 1

    command = sys.argv[1]

    if command == "verify_spec" and len(sys.argv) >= 3:
        return verify_spec(sys.argv[2])
    elif command == "verify_plan" and len(sys.argv) >= 3:
        return verify_plan(sys.argv[2])
    elif command == "finalize" and len(sys.argv) >= 3:
        return finalize_feature(sys.argv[2])
    else:
        print(f"Unknown command: {command}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
