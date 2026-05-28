"""
Refinement Engine - Iterative Refinement Loop Controller
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Orchestrates iterative refinement loops with quality gates and early stopping.
    Integrates verification agent, feedback accumulation, and state persistence.
    Enforces max iteration limits and escalates to human when thresholds not met.

Constitutional Compliance:
    - Principle I: Library-First - Engine is standalone library
    - Principle II: Test-First - Contract tests validate behavior
    - Principle IV: Idempotent Operations - Max 20 rounds prevents infinite loops
    - Principle VII: Observability - Complete audit trail of refinement iterations

Configuration:
    Loads settings from .logic-loom/config/refinement.conf:
    - MAX_REFINEMENT_ROUNDS (default: 20)
    - EARLY_STOP_THRESHOLD (default: 0.95)
    - Quality thresholds per phase

Usage:
    from sdd.refinement.engine import RefinementEngine
    from sdd.agents.quality.verifier import VerificationAgent

    engine = RefinementEngine()
    verifier = VerificationAgent()

    # Refine until sufficient quality or max rounds
    final_state = engine.refine_until_sufficient(
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="planning",
        artifact_path="/path/to/plan.md",
        verifier=verifier
    )

    if final_state.should_stop() and final_state.ema_quality >= final_state.quality_threshold:
        print("Quality threshold achieved!")
    else:
        print("Max rounds reached - escalating to human")
"""

import logging
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Dict, Optional
from uuid import UUID

from sdd.agents.quality.models import VerificationDecision
from sdd.agents.quality.verifier import VerificationAgent
from sdd.agents.shared.models import AgentContext, AgentInput
from sdd.refinement.models import IterationRecord, RefinementState

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RefinementEngine:
    """
    Refinement Engine for iterative quality improvement.

    Orchestrates refinement loops with verification agent invocations,
    feedback accumulation, early stopping, and human escalation.

    Attributes:
        config_path: Path to refinement.conf configuration
        state_dir: Directory for refinement state persistence
        config: Loaded configuration dictionary
        max_rounds: Maximum refinement iterations (from config)
        early_stop_threshold: Quality score for early stopping (from config)
    """

    def __init__(
        self,
        config_path: str = "/workspaces/logic-loom/.logic-loom/config/refinement.conf",
        state_dir: str = "/workspaces/logic-loom/.docs/agents/shared/refinement-state"
    ):
        """
        Initialize Refinement Engine.

        Args:
            config_path: Path to refinement.conf
            state_dir: Directory for state persistence
        """
        self.config_path = Path(config_path)
        self.state_dir = Path(state_dir)
        self.state_dir.mkdir(parents=True, exist_ok=True)

        # Load configuration
        self.config = self._load_config()
        self.max_rounds = int(self.config.get("MAX_REFINEMENT_ROUNDS", 20))
        self.early_stop_threshold = float(self.config.get("EARLY_STOP_THRESHOLD", 0.95))

        logger.info(
            f"RefinementEngine initialized: max_rounds={self.max_rounds}, "
            f"early_stop={self.early_stop_threshold}"
        )

    def _load_config(self) -> Dict[str, Any]:
        """
        Load configuration from refinement.conf.

        Returns:
            Dictionary of configuration key-value pairs

        Raises:
            FileNotFoundError: If config file doesn't exist
        """
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")

        config = {}
        with open(self.config_path, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                # Parse key=value pairs
                if '=' in line:
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip().strip('"')

        logger.info(f"Loaded config from {self.config_path}: {len(config)} settings")
        return config

    def _get_quality_threshold(self, phase: str) -> float:
        """
        Get quality threshold for workflow phase.

        Args:
            phase: Workflow phase (specification, planning, implementation, validation)

        Returns:
            Quality threshold for phase (0.0-1.0)
        """
        phase_thresholds = {
            "specification": float(self.config.get("SPEC_COMPLETENESS_THRESHOLD", 0.90)),
            "planning": float(self.config.get("PLAN_QUALITY_THRESHOLD", 0.85)),
            "implementation": float(self.config.get("CODE_QUALITY_THRESHOLD", 0.80)),
            "validation": float(self.config.get("TEST_COVERAGE_THRESHOLD", 0.80)),
        }
        return phase_thresholds.get(phase.lower(), 0.85)

    def refine_until_sufficient(
        self,
        task_id: str,
        phase: str,
        artifact_path: str,
        verifier: VerificationAgent,
        context: Optional[AgentContext] = None,
        input_state_fn: Optional[Callable[[], Dict[str, Any]]] = None,
        output_state_fn: Optional[Callable[[], Dict[str, Any]]] = None,
        refinement_fn: Optional[Callable[[RefinementState], None]] = None
    ) -> RefinementState:
        """
        Refine artifact until quality threshold met or max rounds reached.

        This is the main refinement loop:
        1. Load or initialize refinement state
        2. For each iteration (up to max_rounds):
           a. Invoke verification agent
           b. Check quality score against threshold
           c. If sufficient: return success
           d. If early stopping: return success
           e. Otherwise: accumulate feedback, apply refinement_fn, continue
        3. If max rounds reached without success: escalate to human

        Args:
            task_id: Task identifier (UUID format)
            phase: Workflow phase (specification, planning, implementation, validation)
            artifact_path: Path to artifact being refined
            verifier: VerificationAgent instance for quality checks
            context: Agent context (optional, creates default if None)
            input_state_fn: Function to capture input state snapshot (optional)
            output_state_fn: Function to capture output state snapshot (optional)
            refinement_fn: Function to apply refinement based on feedback (optional)

        Returns:
            Final RefinementState after loop completion

        Raises:
            ValueError: If task_id is not valid UUID format
            FileNotFoundError: If artifact_path doesn't exist

        Example:
            >>> engine = RefinementEngine()
            >>> verifier = VerificationAgent()
            >>>
            >>> def refine_plan(state):
            ...     # Apply accumulated feedback to plan
            ...     feedback = state.cumulative_feedback
            ...     # ... refinement logic ...
            >>>
            >>> final_state = engine.refine_until_sufficient(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000",
            ...     phase="planning",
            ...     artifact_path="/path/to/plan.md",
            ...     verifier=verifier,
            ...     refinement_fn=refine_plan
            ... )
            >>>
            >>> if final_state.ema_quality >= final_state.quality_threshold:
            ...     print("Success!")
            ... else:
            ...     print("Escalate to human")
        """
        # Validate inputs
        try:
            UUID(task_id)
        except ValueError:
            raise ValueError(f"task_id must be valid UUID, got: {task_id}")

        artifact = Path(artifact_path)
        if not artifact.exists():
            raise FileNotFoundError(f"Artifact not found: {artifact_path}")

        # Initialize or load refinement state
        quality_threshold = self._get_quality_threshold(phase)
        state = self._load_or_create_state(
            task_id=task_id,
            phase=phase,
            quality_threshold=quality_threshold
        )

        # Create default context if not provided
        if context is None:
            context = AgentContext(spec_path=artifact_path)

        logger.info(
            f"Starting refinement loop: task_id={task_id}, phase={phase}, "
            f"current_round={state.current_round}, max_rounds={self.max_rounds}"
        )

        # Refinement loop
        while state.can_continue():
            iteration_start = time.time()
            current_round = state.current_round + 1

            logger.info(f"Refinement iteration {current_round}/{self.max_rounds}")

            # Capture input state
            input_state = input_state_fn() if input_state_fn else {"round": current_round}

            # Invoke verification agent
            verification_result = self._verify_artifact(
                task_id=task_id,
                phase=phase,
                artifact_path=artifact_path,
                verifier=verifier,
                context=context,
                quality_threshold=quality_threshold
            )

            # Capture output state
            output_state = output_state_fn() if output_state_fn else {"round": current_round}

            # Create iteration record
            iteration_duration = time.time() - iteration_start
            iteration = IterationRecord(
                round=current_round,
                timestamp=datetime.now(),
                input_state=input_state,
                output_state=output_state,
                verification_result=verification_result.model_dump(),
                quality_score=verification_result.quality_score,
                duration_seconds=iteration_duration,
                agent_invocations=[verifier.agent_id]
            )

            # Update state
            state = state.add_iteration(iteration)
            state.save_to_file(str(self.state_dir))

            logger.info(
                f"Iteration {current_round} complete: "
                f"quality={verification_result.quality_score:.3f}, "
                f"ema_quality={state.ema_quality:.3f}, "
                f"decision={verification_result.decision.value}"
            )

            # Check early stopping (exceptional quality)
            if state.should_early_stop():
                logger.info(
                    f"Early stopping triggered: ema_quality={state.ema_quality:.3f} >= "
                    f"threshold={self.early_stop_threshold}"
                )
                return state

            # Check quality threshold met
            if state.should_stop() and state.ema_quality >= quality_threshold:
                logger.info(
                    f"Quality threshold achieved: ema_quality={state.ema_quality:.3f} >= "
                    f"threshold={quality_threshold}"
                )
                return state

            # Check max rounds reached
            if state.current_round >= self.max_rounds:
                logger.warning(
                    f"Max refinement rounds reached ({self.max_rounds}). "
                    f"Final quality: {state.ema_quality:.3f}, threshold: {quality_threshold}. "
                    f"Escalating to human."
                )
                self._escalate_to_human(state, artifact_path)
                return state

            # Apply refinement if function provided
            if refinement_fn:
                logger.info("Applying refinement based on accumulated feedback")
                refinement_fn(state)

        # If we exit loop, return final state
        return state

    def _load_or_create_state(
        self,
        task_id: str,
        phase: str,
        quality_threshold: float
    ) -> RefinementState:
        """
        Load existing refinement state or create new one.

        Args:
            task_id: Task identifier
            phase: Workflow phase
            quality_threshold: Quality threshold for phase

        Returns:
            RefinementState (loaded or newly created)
        """
        state_file = self.state_dir / f"{task_id}.json"

        if state_file.exists():
            logger.info(f"Loading existing refinement state: {state_file}")
            return RefinementState.load_from_file(task_id, str(self.state_dir))
        else:
            logger.info(f"Creating new refinement state for task_id={task_id}")
            return RefinementState(
                task_id=task_id,
                phase=phase,
                current_round=0,
                max_rounds=self.max_rounds,
                iterations=[],
                cumulative_feedback=[],
                ema_quality=0.0,
                quality_threshold=quality_threshold,
                early_stopping_threshold=self.early_stop_threshold,
                started_at=datetime.now(),
                updated_at=datetime.now()
            )

    def _verify_artifact(
        self,
        task_id: str,
        phase: str,
        artifact_path: str,
        verifier: VerificationAgent,
        context: AgentContext,
        quality_threshold: float
    ) -> VerificationDecision:
        """
        Invoke verification agent to check artifact quality.

        Args:
            task_id: Task identifier
            phase: Workflow phase
            artifact_path: Path to artifact
            verifier: VerificationAgent instance
            context: Agent context
            quality_threshold: Quality threshold

        Returns:
            VerificationDecision from verifier
        """
        # Create agent input
        agent_input = AgentInput(
            agent_id=verifier.agent_id,
            task_id=task_id,
            phase=phase,
            input_data={
                "artifact_path": artifact_path,
                "quality_thresholds": {
                    "completeness": quality_threshold,
                    "constitutional_compliance": quality_threshold,
                    "test_coverage": quality_threshold,
                    "spec_alignment": quality_threshold
                }
            },
            context=context
        )

        # Invoke verifier
        agent_output = verifier.verify(agent_input)

        # Extract verification decision
        decision_data = agent_output.output_data
        return VerificationDecision.model_validate(decision_data)

    def _escalate_to_human(
        self,
        state: RefinementState,
        artifact_path: str
    ) -> None:
        """
        Escalate to human when max rounds reached without achieving quality.

        Logs full context including:
        - All iteration history
        - Cumulative feedback
        - Current quality metrics
        - Artifact path

        Args:
            state: Final refinement state
            artifact_path: Path to artifact that failed to meet quality
        """
        escalation_msg = f"""
================================================================================
HUMAN ESCALATION REQUIRED
================================================================================

Task ID: {state.task_id}
Phase: {state.phase}
Artifact: {artifact_path}

Quality Status:
- Current EMA Quality: {state.ema_quality:.3f}
- Required Threshold: {state.quality_threshold}
- Gap: {state.quality_threshold - state.ema_quality:.3f}

Refinement Summary:
- Total Iterations: {state.current_round}
- Max Rounds: {state.max_rounds}
- Early Stopping Threshold: {state.early_stopping_threshold}

Cumulative Feedback ({len(state.cumulative_feedback)} items):
"""
        for i, feedback in enumerate(state.cumulative_feedback, 1):
            escalation_msg += f"\n  {i}. {feedback}"

        escalation_msg += f"""

Iteration History:
"""
        for iteration in state.iterations:
            escalation_msg += f"""
  Round {iteration.round}:
    Quality: {iteration.quality_score:.3f}
    Duration: {iteration.duration_seconds:.1f}s
    Decision: {iteration.verification_result.get('decision', 'N/A')}
"""

        escalation_msg += """
================================================================================
Please review the artifact and accumulated feedback, then manually refine
or adjust quality thresholds if appropriate.
================================================================================
"""

        logger.error(escalation_msg)

        # Save escalation report
        escalation_file = self.state_dir / f"{state.task_id}_escalation.txt"
        escalation_file.write_text(escalation_msg)
        logger.info(f"Escalation report saved: {escalation_file}")

    def get_state(self, task_id: str) -> Optional[RefinementState]:
        """
        Retrieve refinement state for task.

        Args:
            task_id: Task identifier

        Returns:
            RefinementState if exists, None otherwise
        """
        try:
            return RefinementState.load_from_file(task_id, str(self.state_dir))
        except FileNotFoundError:
            return None

    def reset_state(self, task_id: str) -> bool:
        """
        Delete refinement state for task (start fresh).

        Args:
            task_id: Task identifier

        Returns:
            True if state was deleted, False if didn't exist
        """
        state_file = self.state_dir / f"{task_id}.json"
        if state_file.exists():
            state_file.unlink()
            logger.info(f"Deleted refinement state: {state_file}")
            return True
        return False
