"""
Constitutional Validator - 14 Principle Compliance Checker
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Validates code, artifacts, and workflows against all 14 constitutional principles.
    Generates compliance reports with violations and remediation suggestions.
    Used by Finalizer agent for pre-commit checks.

Constitutional Compliance:
    - Principle I: Library-First - Validator is standalone library
    - Principle VII: Observability - Complete audit trail of compliance checks
    - Enforces ALL 14 principles from constitution v1.5.0

Principles Validated:
    I. Library-First Architecture (IMMUTABLE)
    II. Test-First Development (IMMUTABLE)
    III. Contract-First Design (IMMUTABLE)
    IV. Idempotent Operations
    V. Progressive Enhancement
    VI. Git Operation Approval (CRITICAL)
    VII. Observability and Structured Logging
    VIII. Documentation Synchronization
    IX. Dependency Management
    X. Agent Delegation Protocol (CRITICAL)
    XI. Input Validation and Output Sanitization
    XII. Design System Compliance
    XIII. Feature Access Control
    XIV. AI Model Selection Protocol

Usage:
    from sdd.validation.constitutional import ConstitutionalValidator

    validator = ConstitutionalValidator()

    # Validate artifact
    report = validator.validate_all_principles(
        artifact_path="/path/to/plan.md",
        artifact_type="plan"
    )

    if report['compliant']:
        print("All principles satisfied!")
    else:
        print(f"Violations found: {len(report['violations'])}")
        for v in report['violations']:
            print(f"- {v['principle']}: {v['description']}")
            print(f"  Remediation: {v['remediation']}")
"""

import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ===================================================================
# Violation Model
# ===================================================================

class Violation:
    """
    Constitutional principle violation.

    Attributes:
        principle: Principle identifier (e.g., "Principle I", "Principle VI")
        description: What was violated
        severity: high | medium | low
        remediation: Suggested fix
        location: File/line where violation occurred (optional)
    """

    def __init__(
        self,
        principle: str,
        description: str,
        severity: str,
        remediation: str,
        location: Optional[str] = None
    ):
        self.principle = principle
        self.description = description
        self.severity = severity
        self.remediation = remediation
        self.location = location

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            'principle': self.principle,
            'description': self.description,
            'severity': self.severity,
            'remediation': self.remediation,
            'location': self.location
        }


# ===================================================================
# ConstitutionalValidator
# ===================================================================

class ConstitutionalValidator:
    """
    Constitutional Validator for 14-principle compliance.

    Validates artifacts against all constitutional principles and generates
    detailed compliance reports with remediation suggestions.

    Attributes:
        constitution_path: Path to constitution.md
        report_dir: Directory for compliance reports
        principles: List of all 14 principles
    """

    def __init__(
        self,
        constitution_path: str = "/workspaces/logic-loom/.logic-loom/memory/constitution.md",
        report_dir: str = "/workspaces/logic-loom/.docs/agents/shared/compliance-reports"
    ):
        """
        Initialize Constitutional Validator.

        Args:
            constitution_path: Path to constitution.md
            report_dir: Directory for compliance reports
        """
        self.constitution_path = Path(constitution_path)
        self.report_dir = Path(report_dir)
        self.report_dir.mkdir(parents=True, exist_ok=True)

        # All 14 principles
        self.principles = [
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

        logger.info(f"ConstitutionalValidator initialized: {len(self.principles)} principles")

    def validate_all_principles(
        self,
        artifact_path: str,
        artifact_type: str = "code"
    ) -> Dict[str, Any]:
        """
        Validate artifact against all 14 principles.

        Args:
            artifact_path: Path to artifact (file or directory)
            artifact_type: Type of artifact (code, plan, spec, etc.)

        Returns:
            Dictionary with compliance report:
            {
                'compliant': bool,
                'violations': List[Dict],
                'passed_checks': List[str],
                'artifact_path': str,
                'artifact_type': str,
                'checked_at': str
            }

        Example:
            >>> validator = ConstitutionalValidator()
            >>> report = validator.validate_all_principles(
            ...     artifact_path="/path/to/plan.md",
            ...     artifact_type="plan"
            ... )
            >>> if not report['compliant']:
            ...     for v in report['violations']:
            ...         print(f"{v['principle']}: {v['description']}")
        """
        logger.info(f"Validating {artifact_path} against all 14 principles")

        violations: List[Violation] = []
        passed_checks: List[str] = []

        # Read artifact
        artifact = Path(artifact_path)
        if not artifact.exists():
            violations.append(Violation(
                principle="General",
                description=f"Artifact not found: {artifact_path}",
                severity="high",
                remediation="Ensure artifact exists before validation"
            ))
            return self._build_report(violations, passed_checks, artifact_path, artifact_type)

        content = artifact.read_text() if artifact.is_file() else ""

        # Run principle checks
        violations.extend(self._check_principle_i(artifact, artifact_type, passed_checks))
        violations.extend(self._check_principle_ii(artifact, content, artifact_type, passed_checks))
        violations.extend(self._check_principle_iii(artifact, content, artifact_type, passed_checks))
        violations.extend(self._check_principle_iv(content, passed_checks))
        violations.extend(self._check_principle_v(content, passed_checks))
        violations.extend(self._check_principle_vi(content, passed_checks))
        violations.extend(self._check_principle_vii(content, passed_checks))
        violations.extend(self._check_principle_viii(artifact, passed_checks))
        violations.extend(self._check_principle_ix(artifact, passed_checks))
        violations.extend(self._check_principle_x(content, passed_checks))
        violations.extend(self._check_principle_xi(content, passed_checks))
        violations.extend(self._check_principle_xii(content, artifact_type, passed_checks))
        violations.extend(self._check_principle_xiii(content, artifact_type, passed_checks))
        violations.extend(self._check_principle_xiv(content, passed_checks))

        return self._build_report(violations, passed_checks, artifact_path, artifact_type)

    def _check_principle_i(
        self,
        artifact: Path,
        artifact_type: str,
        passed_checks: List[str]
    ) -> List[Violation]:
        """Check Principle I: Library-First Architecture."""
        violations = []

        # For code artifacts, check if they're in src/ directory (library structure)
        if artifact_type == "code" and artifact.is_file():
            if "/src/" not in str(artifact):
                violations.append(Violation(
                    principle="Principle I",
                    description="Code not in library structure (src/ directory)",
                    severity="high",
                    remediation="Move code to src/{package}/ directory as standalone library",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle I: Code in library structure")

        return violations

    def _check_principle_ii(
        self,
        artifact: Path,
        content: str,
        artifact_type: str,
        passed_checks: List[str]
    ) -> List[Violation]:
        """Check Principle II: Test-First Development."""
        violations = []

        # For code artifacts, check for corresponding tests
        if artifact_type == "code" and artifact.is_file() and artifact.suffix == ".py":
            # Check if tests exist
            test_patterns = [
                artifact.parent.parent / "tests" / f"test_{artifact.name}",
                artifact.parent / "tests" / f"test_{artifact.name}",
                Path(str(artifact).replace("/src/", "/tests/").replace(".py", "_test.py"))
            ]

            has_tests = any(p.exists() for p in test_patterns)

            if not has_tests:
                violations.append(Violation(
                    principle="Principle II",
                    description=f"No tests found for {artifact.name}",
                    severity="high",
                    remediation=f"Create test file at tests/test_{artifact.name}",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle II: Tests exist for code")

        return violations

    def _check_principle_iii(
        self,
        artifact: Path,
        content: str,
        artifact_type: str,
        passed_checks: List[str]
    ) -> List[Violation]:
        """Check Principle III: Contract-First Design."""
        violations = []

        # For plans, check if contracts/ directory exists
        if artifact_type == "plan" and artifact.is_file():
            contracts_dir = artifact.parent / "contracts"
            if not contracts_dir.exists():
                violations.append(Violation(
                    principle="Principle III",
                    description="No contracts/ directory found for plan",
                    severity="medium",
                    remediation="Create contracts/ directory with API contract definitions",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle III: Contracts directory exists")

        # For code, check for Pydantic models or type hints
        if artifact_type == "code" and "def " in content:
            if "-> " not in content and "BaseModel" not in content:
                violations.append(Violation(
                    principle="Principle III",
                    description="Functions lack type hints or contracts",
                    severity="low",
                    remediation="Add type hints to function signatures",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle III: Code has type contracts")

        return violations

    def _check_principle_iv(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle IV: Idempotent Operations."""
        violations = []

        # Check for common non-idempotent patterns
        non_idempotent_patterns = [
            (r'\bappend\(', "Use idempotent operations instead of append"),
            (r'\.mkdir\([^)]*exist_ok=False', "Use mkdir(exist_ok=True) for idempotency")
        ]

        for pattern, remediation in non_idempotent_patterns:
            if re.search(pattern, content):
                violations.append(Violation(
                    principle="Principle IV",
                    description=f"Non-idempotent operation detected: {pattern}",
                    severity="low",
                    remediation=remediation
                ))

        if not violations:
            passed_checks.append("Principle IV: No obvious non-idempotent operations")

        return violations

    def _check_principle_v(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle V: Progressive Enhancement."""
        violations = []

        # Check for premature optimization patterns
        if "threading" in content or "multiprocessing" in content:
            if "# Optimization:" not in content and "# Performance:" not in content:
                violations.append(Violation(
                    principle="Principle V",
                    description="Concurrency added without justification",
                    severity="medium",
                    remediation="Document why concurrency is needed with performance measurements"
                ))

        if not violations:
            passed_checks.append("Principle V: No premature optimization detected")

        return violations

    def _check_principle_vi(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle VI: Git Operation Approval (CRITICAL)."""
        violations = []

        # Check for git commands without approval
        git_commands = ["git checkout", "git commit", "git push", "git pull", "git merge"]

        for cmd in git_commands:
            if cmd in content and "request_git_approval" not in content:
                violations.append(Violation(
                    principle="Principle VI (CRITICAL)",
                    description=f"Git command '{cmd}' without user approval",
                    severity="high",
                    remediation="Add request_git_approval() before git command"
                ))

        if not violations:
            passed_checks.append("Principle VI: No unapproved git operations")

        return violations

    def _check_principle_vii(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle VII: Observability and Structured Logging."""
        violations = []

        # Check for logging in code
        if "def " in content and "import logging" not in content and "logger" not in content:
            violations.append(Violation(
                principle="Principle VII",
                description="Code lacks logging infrastructure",
                severity="low",
                remediation="Add structured logging with Python logging module"
            ))
        else:
            passed_checks.append("Principle VII: Logging infrastructure present")

        return violations

    def _check_principle_viii(self, artifact: Path, passed_checks: List[str]) -> List[Violation]:
        """Check Principle VIII: Documentation Synchronization."""
        violations = []

        # Check if README exists for library
        if artifact.is_dir() and (artifact / "__init__.py").exists():
            if not (artifact / "README.md").exists():
                violations.append(Violation(
                    principle="Principle VIII",
                    description=f"Library {artifact.name} lacks README.md",
                    severity="medium",
                    remediation="Create README.md with usage examples",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle VIII: README exists")

        return violations

    def _check_principle_ix(self, artifact: Path, passed_checks: List[str]) -> List[Violation]:
        """Check Principle IX: Dependency Management."""
        violations = []

        # Check for version pinning in imports
        if artifact.is_file() and artifact.name in ["requirements.txt", "pyproject.toml"]:
            content = artifact.read_text()
            if "==" not in content and ">=" in content:
                violations.append(Violation(
                    principle="Principle IX",
                    description="Dependencies not version-pinned (use == not >=)",
                    severity="medium",
                    remediation="Pin exact versions with == instead of >= ranges",
                    location=str(artifact)
                ))
            else:
                passed_checks.append("Principle IX: Dependencies version-pinned")

        return violations

    def _check_principle_x(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle X: Agent Delegation Protocol (CRITICAL)."""
        violations = []

        # Check for agent delegation patterns
        delegation_keywords = ["frontend", "backend", "database", "security", "testing"]
        has_delegation = any(keyword in content.lower() for keyword in delegation_keywords)

        if has_delegation and "delegate" not in content.lower() and "agent" not in content.lower():
            violations.append(Violation(
                principle="Principle X (CRITICAL)",
                description="Domain-specific work without agent delegation",
                severity="high",
                remediation="Delegate specialized work to appropriate domain agents"
            ))
        else:
            passed_checks.append("Principle X: Agent delegation considered")

        return violations

    def _check_principle_xi(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle XI: Input Validation and Output Sanitization."""
        violations = []

        # Check for validation patterns
        if "def " in content and "input" in content.lower():
            if "validate" not in content.lower() and "BaseModel" not in content:
                violations.append(Violation(
                    principle="Principle XI",
                    description="Input handling without validation",
                    severity="high",
                    remediation="Add input validation using Pydantic or explicit checks"
                ))
            else:
                passed_checks.append("Principle XI: Input validation present")

        return violations

    def _check_principle_xii(
        self,
        content: str,
        artifact_type: str,
        passed_checks: List[str]
    ) -> List[Violation]:
        """Check Principle XII: Design System Compliance."""
        violations = []

        # For UI components, check for design system usage
        if artifact_type == "ui" or "component" in content.lower():
            if "theme" not in content.lower() and "design" not in content.lower():
                violations.append(Violation(
                    principle="Principle XII",
                    description="UI component without design system reference",
                    severity="medium",
                    remediation="Use design system tokens/variables for styling"
                ))
            else:
                passed_checks.append("Principle XII: Design system referenced")

        return violations

    def _check_principle_xiii(
        self,
        content: str,
        artifact_type: str,
        passed_checks: List[str]
    ) -> List[Violation]:
        """Check Principle XIII: Feature Access Control."""
        violations = []

        # For features with access control, check dual-layer enforcement
        if "access" in content.lower() or "permission" in content.lower():
            has_backend = "rls" in content.lower() or "policy" in content.lower()
            has_frontend = "ui" in content.lower() or "component" in content.lower()

            if not (has_backend and has_frontend):
                violations.append(Violation(
                    principle="Principle XIII",
                    description="Access control not enforced at both backend and frontend",
                    severity="high",
                    remediation="Implement dual-layer enforcement (RLS + UI indicators)"
                ))
            else:
                passed_checks.append("Principle XIII: Dual-layer access control")

        return violations

    def _check_principle_xiv(self, content: str, passed_checks: List[str]) -> List[Violation]:
        """Check Principle XIV: AI Model Selection Protocol."""
        violations = []

        # Check for model selection documentation
        if "sonnet" in content.lower() or "opus" in content.lower():
            if "escalation" not in content.lower() and "model_selection" not in content.lower():
                violations.append(Violation(
                    principle="Principle XIV",
                    description="AI model usage without selection justification",
                    severity="low",
                    remediation="Document why model was selected (default vs escalation)"
                ))
            else:
                passed_checks.append("Principle XIV: Model selection documented")

        return violations

    def _build_report(
        self,
        violations: List[Violation],
        passed_checks: List[str],
        artifact_path: str,
        artifact_type: str
    ) -> Dict[str, Any]:
        """Build compliance report."""
        report = {
            'compliant': len(violations) == 0,
            'violations': [v.to_dict() for v in violations],
            'passed_checks': passed_checks,
            'artifact_path': artifact_path,
            'artifact_type': artifact_type,
            'checked_at': datetime.now().isoformat(),
            'principle_count': len(self.principles),
            'checks_passed': len(passed_checks),
            'violations_found': len(violations)
        }

        logger.info(
            f"Validation complete: compliant={report['compliant']}, "
            f"violations={len(violations)}, passed={len(passed_checks)}"
        )

        return report

    def save_report(self, report: Dict[str, Any], output_path: Optional[str] = None) -> str:
        """
        Save compliance report to file.

        Args:
            report: Compliance report dictionary
            output_path: Path to save report (default: report_dir/{artifact_name}_report.json)

        Returns:
            Path to saved report

        Example:
            >>> validator = ConstitutionalValidator()
            >>> report = validator.validate_all_principles(...)
            >>> report_path = validator.save_report(report)
        """
        if output_path is None:
            artifact_name = Path(report['artifact_path']).stem
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = str(self.report_dir / f"{artifact_name}_{timestamp}_report.json")

        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(json.dumps(report, indent=2))

        logger.info(f"Compliance report saved: {output_path}")
        return str(output_file)
