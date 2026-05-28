"""
Shared Data Models for DS-STAR Multi-Agent Enhancement
Feature: 001-ds-star-multi

Provides standardized Pydantic models for agent communication:
- AgentInput: Standardized input contract for all agents
- AgentOutput: Standardized output contract for all agents
- AgentContext: Shared context passed between agents
- AgentConfig: Configuration for agent behavior

Constitutional Compliance:
- Principle III: Contract-First Design - All agent interfaces defined by contracts
- Principle IX: Dependency Management - Uses pydantic==2.5.0 (version-pinned)

Usage:
    from sdd.agents.shared.models import AgentInput, AgentOutput, AgentContext

    # Create agent input
    agent_input = AgentInput(
        agent_id="quality.verifier",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="planning",
        input_data={"plan_path": "/path/to/plan.md"},
        context=AgentContext(spec_path="/path/to/spec.md")
    )

    # Serialize to JSON
    json_data = agent_input.model_dump()

    # Deserialize from JSON
    restored = AgentInput.model_validate(json_data)
"""

from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


# ===================================================================
# Enumerations
# ===================================================================

class WorkflowPhase(str, Enum):
    """Valid workflow phases in SDD framework."""
    SPECIFICATION = "specification"
    PLANNING = "planning"
    IMPLEMENTATION = "implementation"
    VALIDATION = "validation"


# ===================================================================
# AgentInput (T018)
# ===================================================================

class AgentInput(BaseModel):
    """
    Standardized input contract for all agents.

    This model defines the common input structure that all agents must accept.
    Ensures consistency across agent invocations and enables context handoff.

    Fields:
        agent_id: Unique identifier for the agent (format: {department}.{agent_name})
        task_id: Unique identifier for the current task (UUID format)
        phase: Workflow phase (specification, planning, implementation, validation)
        input_data: Agent-specific input payload (structure varies by agent)
        context: Shared context from previous agents

    Validation:
        - agent_id must match pattern: {department}.{agent_name}
        - task_id must be valid UUID
        - phase must be one of valid workflow phases

    State Transitions:
        Immutable once created (frozen=True for audit trail integrity)

    Example:
        >>> agent_input = AgentInput(
        ...     agent_id="quality.verifier",
        ...     task_id="550e8400-e29b-41d4-a716-446655440000",
        ...     phase="planning",
        ...     input_data={"plan_path": "/workspaces/logic-loom/specs/001-ds-star-multi/plan.md"},
        ...     context=AgentContext(spec_path="/workspaces/logic-loom/specs/001-ds-star-multi/spec.md")
        ... )
        >>> agent_input.agent_id
        'quality.verifier'
        >>> agent_input.phase
        <WorkflowPhase.PLANNING: 'planning'>
    """

    agent_id: str = Field(
        ...,
        description="Unique identifier for the agent (format: {department}.{agent_name})",
        pattern=r"^[a-z_]+\.[a-z_]+$",
        examples=["quality.verifier", "architecture.router", "engineering.autodebug"]
    )

    task_id: str = Field(
        ...,
        description="Unique identifier for the current task (UUID format)",
        examples=["550e8400-e29b-41d4-a716-446655440000"]
    )

    phase: WorkflowPhase = Field(
        ...,
        description="Workflow phase (specification, planning, implementation, validation)"
    )

    input_data: Dict[str, Any] = Field(
        ...,
        description="Agent-specific input payload (structure varies by agent)"
    )

    context: "AgentContext" = Field(
        ...,
        description="Shared context from previous agents"
    )

    model_config = {
        "frozen": True,  # Immutable after creation (audit trail integrity)
        "json_schema_extra": {
            "examples": [
                {
                    "agent_id": "quality.verifier",
                    "task_id": "550e8400-e29b-41d4-a716-446655440000",
                    "phase": "planning",
                    "input_data": {
                        "plan_path": "/workspaces/logic-loom/specs/001-ds-star-multi/plan.md"
                    },
                    "context": {
                        "spec_path": "/workspaces/logic-loom/specs/001-ds-star-multi/spec.md",
                        "plan_path": None,
                        "previous_outputs": [],
                        "cumulative_feedback": [],
                        "refinement_state": None
                    }
                }
            ]
        }
    }

    @field_validator("task_id")
    @classmethod
    def validate_task_id_uuid(cls, v: str) -> str:
        """Validate that task_id is a valid UUID."""
        try:
            UUID(v)
        except ValueError:
            raise ValueError(f"task_id must be a valid UUID, got: {v}")
        return v


# ===================================================================
# AgentOutput (T019)
# ===================================================================

class AgentOutput(BaseModel):
    """
    Standardized output contract for all agents.

    This model defines the common output structure that all agents must produce.
    Enables audit trail, context handoff, and refinement loop feedback accumulation.

    Fields:
        agent_id: Agent that produced this output
        task_id: Task identifier (matches input)
        success: Whether agent completed successfully
        output_data: Agent-specific output payload (structure varies by agent)
        reasoning: Human-readable explanation of decision/action
        confidence: Confidence score (0.0 to 1.0)
        next_actions: Suggested next steps
        metadata: Additional structured data
        timestamp: When output was generated (ISO 8601 format)

    Validation:
        - confidence must be between 0.0 and 1.0
        - reasoning must be non-empty string
        - timestamp must not be in future

    State Transitions:
        Immutable once created (frozen=True for audit trail integrity)

    Example:
        >>> agent_output = AgentOutput(
        ...     agent_id="quality.verifier",
        ...     task_id="550e8400-e29b-41d4-a716-446655440000",
        ...     success=False,
        ...     output_data={"decision": "insufficient", "quality_score": 0.72},
        ...     reasoning="Plan lacks contract definitions for 3 endpoints",
        ...     confidence=0.91,
        ...     next_actions=["Generate OpenAPI schemas", "Add validation rules"],
        ...     metadata={"violations": ["missing_contracts"]},
        ...     timestamp=datetime.now()
        ... )
        >>> agent_output.success
        False
        >>> agent_output.confidence
        0.91
    """

    agent_id: str = Field(
        ...,
        description="Agent that produced this output (format: {department}.{agent_name})",
        pattern=r"^[a-z_]+\.[a-z_]+$"
    )

    task_id: str = Field(
        ...,
        description="Task identifier (matches input)"
    )

    success: bool = Field(
        ...,
        description="Whether agent completed successfully (True if executed, False if error)"
    )

    output_data: Dict[str, Any] = Field(
        ...,
        description="Agent-specific output payload (structure varies by agent)"
    )

    reasoning: str = Field(
        ...,
        min_length=1,
        description="Human-readable explanation of decision/action"
    )

    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Confidence score (0.0 to 1.0)"
    )

    next_actions: List[str] = Field(
        ...,
        description="Suggested next steps"
    )

    metadata: Dict[str, Any] = Field(
        default_factory=dict,
        description="Additional structured data"
    )

    timestamp: datetime = Field(
        default_factory=datetime.now,
        description="When output was generated (ISO 8601 format)"
    )

    model_config = {
        "frozen": True,  # Immutable after creation (audit trail integrity)
        "json_schema_extra": {
            "examples": [
                {
                    "agent_id": "quality.verifier",
                    "task_id": "550e8400-e29b-41d4-a716-446655440000",
                    "success": False,
                    "output_data": {
                        "decision": "insufficient",
                        "quality_score": 0.72
                    },
                    "reasoning": "Plan lacks contract definitions for 3 endpoints",
                    "confidence": 0.91,
                    "next_actions": [
                        "Generate OpenAPI schemas",
                        "Add validation rules"
                    ],
                    "metadata": {
                        "violations": ["missing_contracts"]
                    },
                    "timestamp": "2025-11-10T10:30:00Z"
                }
            ]
        }
    }

    @field_validator("task_id")
    @classmethod
    def validate_task_id_uuid(cls, v: str) -> str:
        """Validate that task_id is a valid UUID."""
        try:
            UUID(v)
        except ValueError:
            raise ValueError(f"task_id must be a valid UUID, got: {v}")
        return v

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp_not_future(cls, v: datetime) -> datetime:
        """Validate that timestamp is not in the future."""
        now = datetime.now()
        if v > now:
            raise ValueError(f"timestamp cannot be in the future: {v} > {now}")
        return v


# ===================================================================
# AgentContext (T020)
# ===================================================================

class AgentContext(BaseModel):
    """
    Shared context passed between agents.

    This model enables context handoff between agents in multi-agent workflows.
    Accumulates feedback and outputs as workflow progresses through phases.

    Fields:
        spec_path: Path to feature specification (optional)
        plan_path: Path to implementation plan (optional)
        previous_outputs: History of agent outputs (chronologically ordered)
        cumulative_feedback: Accumulated feedback from verification failures
        refinement_state: Current refinement iteration state (optional)

    Validation:
        - File paths must exist if provided
        - previous_outputs must be chronologically ordered (by timestamp)

    State Transitions:
        Grows with each agent invocation (append-only)
        - Add outputs to previous_outputs (ordered by timestamp)
        - Append feedback to cumulative_feedback
        - Update refinement_state as iterations progress

    Context Handoff Helpers:
        - add_output(output): Append output to previous_outputs
        - add_feedback(feedback): Append feedback to cumulative_feedback
        - get_latest_output(): Retrieve most recent agent output

    Example:
        >>> context = AgentContext(
        ...     spec_path="/workspaces/logic-loom/specs/001-ds-star-multi/spec.md",
        ...     plan_path=None,
        ...     previous_outputs=[],
        ...     cumulative_feedback=[],
        ...     refinement_state=None
        ... )
        >>> # Add output
        >>> output = AgentOutput(...)
        >>> updated_context = context.add_output(output)
        >>> # Add feedback
        >>> updated_context = updated_context.add_feedback("Add contract for POST /api/users")
    """

    spec_path: Optional[str] = Field(
        None,
        description="Path to feature specification (optional)"
    )

    plan_path: Optional[str] = Field(
        None,
        description="Path to implementation plan (optional)"
    )

    previous_outputs: List[AgentOutput] = Field(
        default_factory=list,
        description="History of agent outputs (chronologically ordered)"
    )

    cumulative_feedback: List[str] = Field(
        default_factory=list,
        description="Accumulated feedback from verification failures"
    )

    refinement_state: Optional[Dict[str, Any]] = Field(
        None,
        description="Current refinement iteration state (optional)"
    )

    @field_validator("spec_path", "plan_path")
    @classmethod
    def validate_file_paths_exist(cls, v: Optional[str]) -> Optional[str]:
        """Validate that file paths exist if provided."""
        if v is not None:
            path = Path(v)
            if not path.exists():
                raise ValueError(f"File path does not exist: {v}")
        return v

    @model_validator(mode="after")
    def validate_outputs_chronological(self) -> "AgentContext":
        """Validate that previous_outputs are chronologically ordered."""
        if len(self.previous_outputs) > 1:
            for i in range(len(self.previous_outputs) - 1):
                current = self.previous_outputs[i].timestamp
                next_output = self.previous_outputs[i + 1].timestamp
                if current > next_output:
                    raise ValueError(
                        f"previous_outputs not chronologically ordered: "
                        f"{current} > {next_output}"
                    )
        return self

    def add_output(self, output: AgentOutput) -> "AgentContext":
        """
        Append output to previous_outputs (immutable, returns new context).

        Args:
            output: AgentOutput to append

        Returns:
            New AgentContext with output appended

        Example:
            >>> context = AgentContext()
            >>> output = AgentOutput(...)
            >>> updated = context.add_output(output)
        """
        return self.model_copy(
            update={"previous_outputs": self.previous_outputs + [output]}
        )

    def add_feedback(self, feedback: str) -> "AgentContext":
        """
        Append feedback to cumulative_feedback (immutable, returns new context).

        Args:
            feedback: Feedback string to append

        Returns:
            New AgentContext with feedback appended

        Example:
            >>> context = AgentContext()
            >>> updated = context.add_feedback("Add contract for POST /api/users")
        """
        return self.model_copy(
            update={"cumulative_feedback": self.cumulative_feedback + [feedback]}
        )

    def get_latest_output(self) -> Optional[AgentOutput]:
        """
        Retrieve most recent agent output.

        Returns:
            Most recent AgentOutput or None if no outputs

        Example:
            >>> context = AgentContext(previous_outputs=[output1, output2])
            >>> latest = context.get_latest_output()
            >>> assert latest == output2
        """
        return self.previous_outputs[-1] if self.previous_outputs else None


# ===================================================================
# AgentConfig (T028)
# ===================================================================

class AgentConfig(BaseModel):
    """
    Configuration for agent behavior.

    This model defines configuration parameters for agent execution:
    - Quality thresholds per phase
    - Model selection (Sonnet vs Opus)
    - Tool access permissions
    - Constitutional constraints

    Fields:
        agent_id: Agent identifier
        enabled: Feature flag for gradual rollout
        quality_thresholds: Quality thresholds per dimension (0.0-1.0)
        max_iterations: Maximum iterations before escalation
        timeout_seconds: Maximum execution time
        circuit_breaker_threshold: Failure rate to disable agent (0.0-1.0)
        model_selection: AI model to use ("sonnet-4.5" or "opus-4.1")
        tool_permissions: List of allowed tool names
        constitutional_constraints: Applicable constitutional principles

    Validation:
        - thresholds must be between 0.0 and 1.0
        - max_iterations > 0
        - circuit_breaker_threshold between 0.0 and 1.0
        - model_selection must be valid model name

    Example:
        >>> config = AgentConfig(
        ...     agent_id="quality.verifier",
        ...     enabled=True,
        ...     quality_thresholds={
        ...         "completeness": 0.90,
        ...         "constitutional_compliance": 0.85,
        ...         "test_coverage": 0.80,
        ...         "spec_alignment": 0.90
        ...     },
        ...     max_iterations=3,
        ...     timeout_seconds=120,
        ...     circuit_breaker_threshold=0.30,
        ...     model_selection="sonnet-4.5"
        ... )
    """

    agent_id: str = Field(
        ...,
        description="Agent identifier (format: {department}.{agent_name})",
        pattern=r"^[a-z_]+\.[a-z_]+$"
    )

    enabled: bool = Field(
        True,
        description="Feature flag for gradual rollout"
    )

    quality_thresholds: Dict[str, float] = Field(
        ...,
        description="Quality thresholds per dimension (0.0-1.0)"
    )

    max_iterations: int = Field(
        ...,
        gt=0,
        description="Maximum iterations before escalation"
    )

    timeout_seconds: int = Field(
        ...,
        gt=0,
        description="Maximum execution time in seconds"
    )

    circuit_breaker_threshold: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Failure rate to disable agent (0.0-1.0)"
    )

    ai_model: str = Field(
        "sonnet-4.5",
        pattern=r"^(sonnet-4\.5|opus-4\.1)$",
        description="AI model to use (sonnet-4.5 or opus-4.1)"
    )

    tool_permissions: List[str] = Field(
        default_factory=list,
        description="List of allowed tool names (empty = all tools allowed)"
    )

    constitutional_constraints: List[str] = Field(
        default_factory=list,
        description="Applicable constitutional principles (e.g., ['Principle I', 'Principle II'])"
    )

    @field_validator("quality_thresholds")
    @classmethod
    def validate_threshold_ranges(cls, v: Dict[str, float]) -> Dict[str, float]:
        """Validate that all thresholds are between 0.0 and 1.0."""
        for key, value in v.items():
            if not 0.0 <= value <= 1.0:
                raise ValueError(
                    f"quality_threshold '{key}' must be between 0.0 and 1.0, got: {value}"
                )
        return v


# Update forward references
AgentInput.model_rebuild()
AgentContext.model_rebuild()
