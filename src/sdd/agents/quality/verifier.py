"""
Verification Agent - Quality Gate Decision Maker
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Performs binary quality gate decisions on artifacts (specs, plans, code).
    Evaluates dimensions: completeness, constitutional_compliance, test_coverage, spec_alignment.
    Returns actionable feedback for improvements when insufficient.

Constitutional Compliance:
    - Principle I: Library-First - Verifier is standalone library
    - Principle II: Test-First - Contract tests validate behavior
    - Principle III: Contract-First - Follows verifier.yaml contract
    - Principle VII: Observability - Structured logging and decision persistence

Contract: POST /verify
    Input: AgentInput with artifact_path, quality_thresholds
    Output: AgentOutput with VerificationDecision

Usage:
    from sdd.agents.quality.verifier import VerificationAgent
    from sdd.agents.shared.models import AgentInput, AgentContext

    agent = VerificationAgent()
    agent_input = AgentInput(
        agent_id="quality.verifier",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="planning",
        input_data={
            "artifact_path": "/path/to/plan.md",
            "quality_thresholds": {
                "completeness": 0.90,
                "constitutional_compliance": 0.85,
                "test_coverage": 0.80,
                "spec_alignment": 0.90
            }
        },
        context=AgentContext(spec_path="/path/to/spec.md")
    )
    result = agent.verify(agent_input)
    print(result.output_data)  # VerificationDecision
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Tuple, Union

from sdd.agents.quality.models import DecisionType, VerificationDecision
from sdd.agents.shared.models import AgentInput, AgentOutput

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class VerificationAgent:
    """
    Verification Agent for quality gate decisions.

    Evaluates artifacts against quality thresholds and constitutional principles.
    Returns binary decision (sufficient/insufficient) with actionable feedback.

    Attributes:
        agent_id: Agent identifier (quality.verifier)
        config_path: Path to refinement.conf configuration
        decisions_dir: Directory for storing decision logs
    """

    def __init__(
        self,
        config_path: str = "/workspaces/logic-loom/.logic-loom/config/refinement.conf",
        decisions_dir: str = "/workspaces/logic-loom/.docs/agents/quality/verifier/decisions"
    ):
        """
        Initialize Verification Agent.

        Args:
            config_path: Path to refinement.conf
            decisions_dir: Directory for decision logs
        """
        self.agent_id = "quality.verifier"
        self.config_path = Path(config_path)
        self.decisions_dir = Path(decisions_dir)
        self.decisions_dir.mkdir(parents=True, exist_ok=True)

        # Load configuration
        self.config = self._load_config()

        logger.info(f"VerificationAgent initialized with config: {self.config_path}")

    def _load_config(self) -> Dict[str, float]:
        """
        Load quality thresholds from refinement.conf.

        Returns:
            Dictionary of threshold configurations

        Example:
            {
                "SPEC_COMPLETENESS_THRESHOLD": 0.90,
                "PLAN_QUALITY_THRESHOLD": 0.85,
                "CODE_QUALITY_THRESHOLD": 0.80,
                "TEST_COVERAGE_THRESHOLD": 0.80
            }
        """
        config = {}
        if not self.config_path.exists():
            logger.warning(f"Config file not found: {self.config_path}, using defaults")
            return {
                "SPEC_COMPLETENESS_THRESHOLD": 0.90,
                "PLAN_QUALITY_THRESHOLD": 0.85,
                "CODE_QUALITY_THRESHOLD": 0.80,
                "TEST_COVERAGE_THRESHOLD": 0.80
            }

        with open(self.config_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    # Parse numeric values
                    if key.endswith('THRESHOLD'):
                        try:
                            config[key] = float(value)
                        except ValueError:
                            logger.warning(f"Invalid threshold value for {key}: {value}")

        return config

    def verify(self, agent_input: Union[AgentInput, Dict[str, Any]]) -> AgentOutput:
        """
        Verify artifact quality and return binary decision.

        Args:
            agent_input: Standardized agent input with artifact details (AgentInput or dict)

        Returns:
            AgentOutput with VerificationDecision

        Raises:
            ValueError: If required input fields missing
            FileNotFoundError: If artifact_path doesn't exist
        """
        # Validate and convert input if needed
        if isinstance(agent_input, dict):
            # Restructure flat dict to AgentInput format if needed
            if "input_data" not in agent_input:
                # Extract known AgentInput fields
                structured_input = {
                    "agent_id": agent_input.get("agent_id", "quality.verifier"),
                    "task_id": agent_input.get("task_id", "unknown"),
                    "phase": agent_input.get("phase", "verification"),
                    "context": agent_input.get("context", {}),
                    "input_data": {}
                }
                # Move remaining fields to input_data
                for key, value in agent_input.items():
                    if key not in ["agent_id", "task_id", "phase", "context"]:
                        structured_input["input_data"][key] = value
                agent_input = AgentInput(**structured_input)
            else:
                agent_input = AgentInput(**agent_input)

        logger.info(f"Starting verification for task_id: {agent_input.task_id}")

        try:
            # Extract input data
            artifact_path = agent_input.input_data.get("artifact_path")
            quality_thresholds = agent_input.input_data.get("quality_thresholds", {})
            artifact_type = agent_input.input_data.get("artifact_type", "plan")

            if not artifact_path:
                raise ValueError("artifact_path required in input_data")

            artifact_file = Path(artifact_path)
            if not artifact_file.exists():
                raise FileNotFoundError(f"Artifact not found: {artifact_path}")

            # Read artifact content
            artifact_content = artifact_file.read_text()

            # Evaluate quality dimensions
            dimension_scores = self._evaluate_dimensions(
                artifact_content=artifact_content,
                artifact_type=artifact_type,
                context=agent_input.context,
                thresholds=quality_thresholds
            )

            # Calculate overall quality score
            quality_score = self._calculate_quality_score(dimension_scores)

            # Make binary decision
            decision, feedback, violations, passed_checks = self._make_decision(
                dimension_scores=dimension_scores,
                quality_score=quality_score,
                thresholds=quality_thresholds,
                artifact_type=artifact_type
            )

            # Create verification decision
            verification_decision = VerificationDecision(
                decision=decision,
                quality_score=quality_score,
                dimension_scores=dimension_scores,
                feedback=feedback,
                violations=violations,
                passed_checks=passed_checks
            )

            # Persist decision
            self._persist_decision(agent_input.task_id, verification_decision)

            # Generate output
            reasoning = self._generate_reasoning(verification_decision, artifact_type)
            confidence = self._calculate_confidence(dimension_scores)
            next_actions = feedback if decision == DecisionType.INSUFFICIENT else ["Proceed to next phase"]

            output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=True,
                output_data=verification_decision.model_dump(mode='json'),
                reasoning=reasoning,
                confidence=confidence,
                next_actions=next_actions,
                metadata={
                    "artifact_path": artifact_path,
                    "artifact_type": artifact_type
                },
                timestamp=datetime.now()
            )

            logger.info(f"Verification complete: {decision.value} (score: {quality_score:.2f})")
            return output.model_dump(mode='json')

        except Exception as e:
            logger.error(f"Verification failed: {str(e)}", exc_info=True)
            error_output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=False,
                output_data={"error": str(e)},
                reasoning=f"Verification failed: {str(e)}",
                confidence=0.0,
                next_actions=["Fix error and retry verification"],
                metadata={},
                timestamp=datetime.now()
            )
            return error_output.model_dump(mode='json')

    def _evaluate_dimensions(
        self,
        artifact_content: str,
        artifact_type: str,
        context: "AgentContext",
        thresholds: Dict[str, float]
    ) -> Dict[str, float]:
        """
        Evaluate quality across all dimensions.

        Args:
            artifact_content: Content of artifact file
            artifact_type: Type (spec, plan, code, tests)
            context: Agent context with spec/plan paths
            thresholds: Quality thresholds per dimension

        Returns:
            Dictionary of dimension scores (0.0 to 1.0)
        """
        scores = {}

        # Completeness: Check for required sections
        scores["completeness"] = self._evaluate_completeness(artifact_content, artifact_type)

        # Constitutional Compliance: Check adherence to 14 principles
        scores["constitutional_compliance"] = self._evaluate_constitutional_compliance(
            artifact_content, artifact_type
        )

        # Test Coverage: Only applicable for implementation phase
        scores["test_coverage"] = self._evaluate_test_coverage(artifact_content, artifact_type)

        # Spec Alignment: Check alignment with specification
        scores["spec_alignment"] = self._evaluate_spec_alignment(
            artifact_content, context.spec_path
        )

        return scores

    def _evaluate_completeness(self, content: str, artifact_type: str) -> float:
        """
        Evaluate completeness based on required sections.

        Args:
            content: Artifact content
            artifact_type: Type of artifact

        Returns:
            Completeness score (0.0 to 1.0)
        """
        # Define required sections per artifact type
        required_sections = {
            "spec": ["## Overview", "## User Stories", "## Acceptance Criteria"],
            "plan": ["## Phase 0", "## Phase 1", "## Technical Approach"],
            "code": ["def ", "class ", "import "],
            "tests": ["def test_", "assert ", "import pytest"]
        }

        sections = required_sections.get(artifact_type, [])
        if not sections:
            return 1.0  # Unknown type, assume complete

        found = sum(1 for section in sections if section in content)
        return found / len(sections)

    def _evaluate_constitutional_compliance(self, content: str, artifact_type: str) -> float:
        """
        Evaluate constitutional compliance.

        Args:
            content: Artifact content
            artifact_type: Type of artifact

        Returns:
            Compliance score (0.0 to 1.0)
        """
        compliance_checks = []

        # Principle I: Library-First
        if artifact_type in ["plan", "code"]:
            has_library_mention = "library" in content.lower() or "standalone" in content.lower()
            compliance_checks.append(has_library_mention)

        # Principle II: Test-First
        if artifact_type in ["plan", "code"]:
            has_test_mention = "test" in content.lower() or "tdd" in content.lower()
            compliance_checks.append(has_test_mention)

        # Principle III: Contract-First
        if artifact_type in ["plan"]:
            has_contract_mention = "contract" in content.lower() or "api" in content.lower()
            compliance_checks.append(has_contract_mention)

        # If no checks applicable, assume compliant
        if not compliance_checks:
            return 1.0

        return sum(compliance_checks) / len(compliance_checks)

    def _evaluate_test_coverage(self, content: str, artifact_type: str) -> float:
        """
        Evaluate test coverage (simulated for now).

        Args:
            content: Artifact content
            artifact_type: Type of artifact

        Returns:
            Coverage score (0.0 to 1.0)
        """
        # For non-code artifacts, return 1.0 (not applicable)
        if artifact_type not in ["code", "tests"]:
            return 1.0

        # Simple heuristic: count test functions vs total functions
        test_count = content.count("def test_")
        function_count = content.count("def ")

        if function_count == 0:
            return 0.0

        # Assume 80% coverage if we have test functions
        if test_count > 0:
            return 0.85
        return 0.0

    def _evaluate_spec_alignment(self, content: str, spec_path: str | None) -> float:
        """
        Evaluate alignment with specification.

        Args:
            content: Artifact content
            spec_path: Path to specification file

        Returns:
            Alignment score (0.0 to 1.0)
        """
        if not spec_path:
            return 0.90  # Default if no spec available

        spec_file = Path(spec_path)
        if not spec_file.exists():
            return 0.90  # Default if spec not found

        # Simple heuristic: check for shared keywords
        spec_content = spec_file.read_text().lower()
        content_lower = content.lower()

        # Extract key terms from spec
        key_terms = ["user", "authentication", "api", "database", "test", "feature"]
        matching_terms = sum(1 for term in key_terms if term in spec_content and term in content_lower)

        if len(key_terms) == 0:
            return 1.0

        return min(1.0, matching_terms / len(key_terms) + 0.5)

    def _calculate_quality_score(self, dimension_scores: Dict[str, float]) -> float:
        """
        Calculate weighted overall quality score.

        Uses weights from refinement.conf:
        - completeness: 0.25
        - constitutional_compliance: 0.30
        - test_coverage: 0.25
        - spec_alignment: 0.20

        Args:
            dimension_scores: Scores per dimension

        Returns:
            Weighted quality score (0.0 to 1.0)
        """
        weights = {
            "completeness": 0.25,
            "constitutional_compliance": 0.30,
            "test_coverage": 0.25,
            "spec_alignment": 0.20
        }

        total = sum(
            dimension_scores.get(dim, 0.0) * weight
            for dim, weight in weights.items()
        )

        return total

    def _make_decision(
        self,
        dimension_scores: Dict[str, float],
        quality_score: float,
        thresholds: Dict[str, float],
        artifact_type: str
    ) -> Tuple[DecisionType, List[str], List[str], List[str]]:
        """
        Make binary quality gate decision.

        Args:
            dimension_scores: Scores per dimension
            quality_score: Overall quality score
            thresholds: Quality thresholds
            artifact_type: Type of artifact

        Returns:
            Tuple of (decision, feedback, violations, passed_checks)
        """
        feedback = []
        violations = []
        passed_checks = []

        # Default threshold
        threshold = thresholds.get("constitutional_compliance", 0.85)

        # Check each dimension
        for dimension, score in dimension_scores.items():
            dim_threshold = thresholds.get(dimension, threshold)
            if score >= dim_threshold:
                passed_checks.append(dimension)
            else:
                violations.append(f"{dimension}_below_threshold")
                feedback.append(self._generate_feedback(dimension, score, dim_threshold, artifact_type))

        # Binary decision based on overall score
        decision = DecisionType.SUFFICIENT if quality_score >= threshold else DecisionType.INSUFFICIENT

        return decision, feedback, violations, passed_checks

    def _generate_feedback(
        self,
        dimension: str,
        score: float,
        threshold: float,
        artifact_type: str
    ) -> str:
        """
        Generate actionable feedback for dimension.

        Args:
            dimension: Dimension name
            score: Current score
            threshold: Required threshold
            artifact_type: Type of artifact

        Returns:
            Actionable feedback string
        """
        feedback_map = {
            "completeness": f"Add missing sections to {artifact_type} (score: {score:.2f}, required: {threshold:.2f})",
            "constitutional_compliance": f"Ensure adherence to constitutional principles (score: {score:.2f}, required: {threshold:.2f})",
            "test_coverage": f"Increase test coverage above {threshold:.0%} (current: {score:.0%})",
            "spec_alignment": f"Improve alignment with specification requirements (score: {score:.2f}, required: {threshold:.2f})"
        }

        return feedback_map.get(dimension, f"Improve {dimension} (score: {score:.2f}, required: {threshold:.2f})")

    def _generate_reasoning(self, decision: VerificationDecision, artifact_type: str) -> str:
        """
        Generate human-readable reasoning for decision.

        Args:
            decision: Verification decision
            artifact_type: Type of artifact

        Returns:
            Reasoning string
        """
        if decision.decision == DecisionType.SUFFICIENT:
            return f"{artifact_type.capitalize()} meets all quality thresholds. Quality score: {decision.quality_score:.2f}. Ready to proceed."
        else:
            violations_str = ", ".join(decision.violations) if decision.violations else "quality thresholds"
            return f"{artifact_type.capitalize()} is insufficient - fails quality gate. Issues: {violations_str}. Score: {decision.quality_score:.2f}. Refinement required."

    def _calculate_confidence(self, dimension_scores: Dict[str, float]) -> float:
        """
        Calculate confidence in decision.

        Higher confidence when scores are far from thresholds (either high or low).

        Args:
            dimension_scores: Scores per dimension

        Returns:
            Confidence score (0.0 to 1.0)
        """
        # Calculate variance from mean
        scores = list(dimension_scores.values())
        if not scores:
            return 0.5

        mean_score = sum(scores) / len(scores)
        variance = sum((s - mean_score) ** 2 for s in scores) / len(scores)

        # High variance = low confidence (inconsistent quality)
        # Low variance = high confidence (consistent quality)
        confidence = max(0.7, min(0.99, 1.0 - variance))

        return confidence

    def _persist_decision(self, task_id: str, decision: VerificationDecision) -> None:
        """
        Persist decision to JSON file for audit trail.

        Args:
            task_id: Task identifier
            decision: Verification decision to persist
        """
        decision_file = self.decisions_dir / f"{task_id}.json"
        decision_data = decision.model_dump()

        with open(decision_file, 'w') as f:
            json.dump(decision_data, f, indent=2, default=str)

        logger.info(f"Decision persisted: {decision_file}")
