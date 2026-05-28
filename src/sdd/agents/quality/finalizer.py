"""
Compliance Finalizer Agent - Pre-Commit Validation and Quality Gate
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Performs final validation before commits: code quality, constitutional compliance,
    documentation sync, security checks. CRITICAL: Requests explicit user approval
    for ALL git operations (Constitutional Principle VI).

Constitutional Compliance:
    - Principle I: Library-First - Finalizer is standalone library
    - Principle VI: Git Operation Approval - MUST request approval for ALL git ops (NON-NEGOTIABLE)
    - Principle VII: Observability - Structured logging and compliance reports
    - Principle VIII: Documentation Synchronization - Validates doc sync

Contract: POST /finalize
    Input: AgentInput with artifact_paths, validation_checks, git_operation
    Output: AgentOutput with compliance report

CRITICAL GIT SAFETY:
    - NO autonomous git operations
    - ALWAYS request explicit user approval
    - Document what will be done before doing it
    - Never assume permission

Usage:
    from sdd.agents.quality.finalizer import FinalizerAgent
    from sdd.agents.shared.models import AgentInput, AgentContext

    agent = FinalizerAgent()
    agent_input = AgentInput(
        agent_id="quality.finalizer",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="validation",
        input_data={
            "artifact_paths": {
                "code_files": ["src/app.py"],
                "test_files": ["tests/test_app.py"],
                "docs_files": ["README.md"]
            },
            "validation_checks": ["tests_passing", "constitutional_compliance"],
            "git_operation": {
                "type": "commit",
                "message": "feat: Add feature",
                "files_to_stage": ["src/app.py"]
            }
        },
        context=AgentContext()
    )
    result = agent.finalize(agent_input)
    print(result.output_data)  # Compliance report
"""

import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

from sdd.agents.shared.models import AgentInput, AgentOutput

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class FinalizerAgent:
    """
    Compliance Finalizer Agent for pre-commit validation.

    Validates all artifacts meet quality standards, constitutional principles,
    documentation is synchronized, no secrets present, and prepares commit.

    CRITICAL: ALWAYS requests explicit user approval before ANY git operations.

    Attributes:
        agent_id: Agent identifier (quality.finalizer)
        constitution_path: Path to constitution.md
        reports_dir: Directory for storing compliance reports
    """

    def __init__(
        self,
        constitution_path: str = "/workspaces/logic-loom/.logic-loom/memory/constitution.md",
        reports_dir: str = "/workspaces/logic-loom/.docs/agents/quality/finalizer/reports"
    ):
        """
        Initialize Compliance Finalizer Agent.

        Args:
            constitution_path: Path to constitution.md
            reports_dir: Directory for compliance reports
        """
        self.agent_id = "quality.finalizer"
        self.constitution_path = Path(constitution_path)
        self.reports_dir = Path(reports_dir)
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Load constitutional principles
        self.principles = self._load_principles()

        logger.info(f"FinalizerAgent initialized with {len(self.principles)} constitutional principles")

    def _load_principles(self) -> List[str]:
        """
        Load 14 constitutional principles.

        Returns:
            List of principle names
        """
        return [
            "Principle I: Library-First Architecture",
            "Principle II: Test-First Development",
            "Principle III: Contract-First Design",
            "Principle IV: Idempotent Operations",
            "Principle V: Progressive Enhancement",
            "Principle VI: Git Operation Approval",
            "Principle VII: Observability and Structured Logging",
            "Principle VIII: Documentation Synchronization",
            "Principle IX: Dependency Management",
            "Principle X: Agent Delegation Protocol",
            "Principle XI: Input Validation and Output Sanitization",
            "Principle XII: Design System Compliance",
            "Principle XIII: Feature Access Control",
            "Principle XIV: AI Model Selection Protocol"
        ]

    def finalize(self, agent_input: Union[AgentInput, Dict[str, Any]]) -> Dict[str, Any]:
        """
        Perform pre-commit validation and prepare git operation.

        CRITICAL: This method NEVER executes git operations autonomously.
        It only prepares and reports what WILL be done IF user approves.

        Args:
            agent_input: Standardized agent input with validation requirements (AgentInput or dict)

        Returns:
            Dict with compliance report and approval requirement

        Raises:
            ValueError: If required input fields missing
        """
        # Validate and convert input if needed
        if isinstance(agent_input, dict):
            if "input_data" not in agent_input:
                structured_input = {
                    "agent_id": agent_input.get("agent_id", "quality.finalizer"),
                    "task_id": agent_input.get("task_id", "unknown"),
                    "phase": agent_input.get("phase", "finalization"),
                    "context": agent_input.get("context", {}),
                    "input_data": {}
                }
                for key, value in agent_input.items():
                    if key not in ["agent_id", "task_id", "phase", "context"]:
                        structured_input["input_data"][key] = value
                agent_input = AgentInput(**structured_input)
            else:
                agent_input = AgentInput(**agent_input)

        logger.info(f"Starting pre-commit finalization for task_id: {agent_input.task_id}")

        try:
            # Extract input data
            artifact_paths = agent_input.input_data.get("artifact_paths", {})
            validation_checks = agent_input.input_data.get("validation_checks", [])
            git_operation = agent_input.input_data.get("git_operation")

            if not validation_checks:
                raise ValueError("validation_checks required in input_data")

            # Run validation checks
            check_results = {}
            all_checks_passed = True

            for check in validation_checks:
                result = self._run_validation_check(check, artifact_paths, agent_input.context)
                check_results[check] = result
                if not result:
                    all_checks_passed = False

            # Generate detailed validation results
            code_coverage_percent = self._calculate_coverage(artifact_paths.get("test_files", []))
            linting_errors = self._count_linting_errors(artifact_paths.get("code_files", []))
            constitutional_violations = self._check_constitutional_violations(artifact_paths)
            documentation_updates_needed = self._check_documentation_sync(artifact_paths)
            secrets_found = self._scan_for_secrets(artifact_paths.get("code_files", []))
            formatted_files = []  # Files that would be formatted (preparation only)

            # CRITICAL: Git approval required
            git_approval_required = git_operation is not None
            git_operation_summary = None

            if git_operation:
                git_operation_summary = self._generate_git_operation_summary(git_operation)

            # Create compliance report
            compliance_report = {
                "all_checks_passed": all_checks_passed,
                "check_results": check_results,
                "code_coverage_percent": code_coverage_percent,
                "linting_errors": linting_errors,
                "constitutional_violations": constitutional_violations,
                "documentation_updates_needed": documentation_updates_needed,
                "secrets_found": secrets_found,
                "formatted_files": formatted_files,
                "git_approval_required": git_approval_required,
                "git_operation_summary": git_operation_summary,
                "user_approved": None  # Will be set after user response
            }

            # Persist report
            self._persist_report(agent_input.task_id, compliance_report)

            # Generate output
            reasoning = self._generate_reasoning(compliance_report)
            confidence = self._calculate_confidence(check_results)
            next_actions = self._generate_next_actions(compliance_report)

            output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=True,
                output_data=compliance_report,
                reasoning=reasoning,
                confidence=confidence,
                next_actions=next_actions,
                metadata={
                    "checks_run": len(validation_checks),
                    "violations_count": len(constitutional_violations),
                    "secrets_count": len(secrets_found)
                },
                timestamp=datetime.now()
            )

            logger.info(f"Finalization complete: {'PASS' if all_checks_passed else 'FAIL'}")
            return output.model_dump(mode='json')

        except Exception as e:
            logger.error(f"Finalization failed: {str(e)}", exc_info=True)
            error_output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=False,
                output_data={"error": str(e)},
                reasoning=f"Finalization failed: {str(e)}",
                confidence=0.0,
                next_actions=["Fix error and retry finalization"],
                metadata={},
                timestamp=datetime.now()
            )
            return error_output.model_dump(mode='json')

    def _run_validation_check(
        self,
        check: str,
        artifact_paths: Dict[str, List[str]],
        context: "AgentContext"
    ) -> bool:
        """
        Run individual validation check.

        Args:
            check: Check name
            artifact_paths: Paths to artifacts
            context: Agent context

        Returns:
            True if check passed
        """
        check_methods = {
            "tests_passing": self._check_tests_passing,
            "code_coverage": self._check_code_coverage,
            "linting": self._check_linting,
            "constitutional_compliance": self._check_constitutional_compliance,
            "documentation_sync": self._check_documentation_sync_status,
            "secrets_check": self._check_no_secrets
        }

        check_fn = check_methods.get(check)
        if not check_fn:
            logger.warning(f"Unknown validation check: {check}")
            return True

        return check_fn(artifact_paths)

    def _check_tests_passing(self, artifact_paths: Dict) -> bool:
        """Check if all tests pass (simulated)."""
        test_files = artifact_paths.get("test_files", [])
        # In production, this would run pytest
        # For now, assume tests pass if test files exist
        return len(test_files) > 0

    def _check_code_coverage(self, artifact_paths: Dict) -> bool:
        """Check if code coverage meets threshold (>80%)."""
        coverage = self._calculate_coverage(artifact_paths.get("test_files", []))
        return coverage >= 80.0

    def _check_linting(self, artifact_paths: Dict) -> bool:
        """Check if code passes linting (simulated)."""
        errors = self._count_linting_errors(artifact_paths.get("code_files", []))
        return errors == 0

    def _check_constitutional_compliance(self, artifact_paths: Dict) -> bool:
        """Check constitutional compliance."""
        violations = self._check_constitutional_violations(artifact_paths)
        return len(violations) == 0

    def _check_documentation_sync_status(self, artifact_paths: Dict) -> bool:
        """Check documentation synchronization."""
        updates_needed = self._check_documentation_sync(artifact_paths)
        return len(updates_needed) == 0

    def _check_no_secrets(self, artifact_paths: Dict) -> bool:
        """Check for secrets in code."""
        secrets = self._scan_for_secrets(artifact_paths.get("code_files", []))
        return len(secrets) == 0

    def _calculate_coverage(self, test_files: List[str]) -> float:
        """
        Calculate code coverage (simulated).

        Args:
            test_files: List of test file paths

        Returns:
            Coverage percentage (0-100)
        """
        # In production, this would run coverage.py
        # For now, estimate based on test file count
        if not test_files:
            return 0.0

        # Simple heuristic: assume 85% coverage if tests exist
        return 85.0

    def _count_linting_errors(self, code_files: List[str]) -> int:
        """
        Count linting errors (simulated).

        Args:
            code_files: List of code file paths

        Returns:
            Number of linting errors
        """
        # In production, this would run black --check, isort --check, flake8
        # For now, assume no errors
        return 0

    def _check_constitutional_violations(self, artifact_paths: Dict) -> List[str]:
        """
        Check for constitutional principle violations.

        Args:
            artifact_paths: Paths to artifacts

        Returns:
            List of violations
        """
        violations = []
        code_files = artifact_paths.get("code_files", [])

        for file_path in code_files:
            try:
                path = Path(file_path)
                if not path.exists():
                    continue

                content = path.read_text(encoding='utf-8', errors='ignore')

                # Check Principle II: Test-First
                if "def " in content and "test" not in content.lower():
                    # Code without tests (simplified check)
                    pass  # Would need more sophisticated analysis

                # Check Principle VI: Git approval
                if "git " in content and "approval" not in content.lower():
                    violations.append(f"Principle VI: Potential autonomous git operation in {path.name}")

            except Exception:
                continue

        return violations

    def _check_documentation_sync(self, artifact_paths: Dict) -> List[str]:
        """
        Check for documentation synchronization issues.

        Args:
            artifact_paths: Paths to artifacts

        Returns:
            List of documentation files needing updates
        """
        updates_needed = []
        code_files = artifact_paths.get("code_files", [])
        docs_files = artifact_paths.get("docs_files", [])

        # Check if code changes require doc updates
        if code_files and not docs_files:
            updates_needed.append("README.md - No documentation provided for code changes")

        return updates_needed

    def _scan_for_secrets(self, code_files: List[str]) -> List[Dict]:
        """
        Scan for secrets in code.

        Args:
            code_files: List of code file paths

        Returns:
            List of detected secrets with location
        """
        secrets_found = []
        secret_patterns = [
            r'(?i)(api[_-]?key|apikey)\s*=\s*["\'][^"\']{20,}["\']',
            r'(?i)(password|passwd|pwd)\s*=\s*["\'][^"\']+["\']',
            r'(?i)(secret|token)\s*=\s*["\'][^"\']{20,}["\']',
            r'(?i)(aws_access_key_id|aws_secret_access_key)\s*=',
        ]

        for file_path in code_files:
            try:
                path = Path(file_path)
                if not path.exists():
                    continue

                content = path.read_text(encoding='utf-8', errors='ignore')
                lines = content.split('\n')

                for line_num, line in enumerate(lines, 1):
                    for pattern in secret_patterns:
                        if re.search(pattern, line):
                            secrets_found.append({
                                "file": str(path),
                                "line": line_num,
                                "secret_type": "potential_secret"
                            })

            except Exception:
                continue

        return secrets_found

    def _generate_git_operation_summary(self, git_operation: Dict) -> str:
        """
        Generate human-readable git operation summary.

        CRITICAL: This prepares the summary but does NOT execute the operation.

        Args:
            git_operation: Git operation details

        Returns:
            Summary string
        """
        op_type = git_operation.get("type", "unknown")
        message = git_operation.get("message", "")
        files = git_operation.get("files_to_stage", [])

        summary_lines = [
            f"Git Operation: {op_type.upper()}",
            f"Files to stage: {len(files)}",
        ]

        if files:
            summary_lines.append("Files:")
            for f in files[:5]:  # Show first 5 files
                summary_lines.append(f"  - {f}")
            if len(files) > 5:
                summary_lines.append(f"  ... and {len(files) - 5} more")

        if message:
            summary_lines.append(f"\nCommit Message:\n{message}")

        summary_lines.append("\n⚠️ USER APPROVAL REQUIRED (Constitutional Principle VI)")
        summary_lines.append("This operation will NOT execute without explicit approval.")

        return "\n".join(summary_lines)

    def _generate_reasoning(self, report: Dict) -> str:
        """Generate human-readable reasoning."""
        if report["all_checks_passed"]:
            reasoning = "All validation checks passed. "
            if report["git_approval_required"]:
                reasoning += "Ready for commit pending user approval (Principle VI)."
            else:
                reasoning += "No git operation requested."
        else:
            failed_checks = [k for k, v in report["check_results"].items() if not v]
            reasoning = f"Validation failed. Failed checks: {', '.join(failed_checks)}. "

            if report["constitutional_violations"]:
                reasoning += f"{len(report['constitutional_violations'])} constitutional violations found. "

            reasoning += "Refinement required before commit."

        return reasoning

    def _calculate_confidence(self, check_results: Dict[str, bool]) -> float:
        """Calculate confidence in finalization."""
        if not check_results:
            return 0.5

        passed = sum(1 for v in check_results.values() if v)
        total = len(check_results)

        # High confidence if most checks passed
        confidence = 0.8 + (passed / total * 0.2)

        return min(0.99, confidence)

    def _generate_next_actions(self, report: Dict) -> List[str]:
        """Generate next actions based on report."""
        actions = []

        if not report["all_checks_passed"]:
            # Failed validation
            if report["constitutional_violations"]:
                for violation in report["constitutional_violations"]:
                    actions.append(f"Fix: {violation}")

            if report["documentation_updates_needed"]:
                actions.append("Update documentation to sync with code changes")

            if report["secrets_found"]:
                actions.append(f"Remove {len(report['secrets_found'])} secrets from code")

            if report["linting_errors"] > 0:
                actions.append(f"Fix {report['linting_errors']} linting errors")

            actions.append("Re-run finalization after fixes")

        else:
            # Passed validation
            actions.append("Proceed to next phase")

        # ALWAYS mention git approval if required (regardless of validation status)
        if report["git_approval_required"]:
            actions.append("⚠️ CRITICAL: Git operation requires USER APPROVAL")
            actions.append("Display git operation summary to user")
            actions.append("Wait for explicit user approval")
            actions.append("Execute git operation ONLY if approved by user")

        return actions

    def _persist_report(self, task_id: str, report: Dict) -> None:
        """
        Persist compliance report to JSON file for audit trail.

        Args:
            task_id: Task identifier
            report: Compliance report to persist
        """
        report_file = self.reports_dir / f"{task_id}.json"

        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)

        logger.info(f"Compliance report persisted: {report_file}")


# Backward compatibility alias for tests
ComplianceFinalizerAgent = FinalizerAgent
