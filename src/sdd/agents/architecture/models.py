"""
Architecture Agent Data Models
DS-STAR Multi-Agent Enhancement - Feature 001

Provides Pydantic models for Architecture department agents:
- RoutingDecision: Output from Router Agent for orchestration decisions
- ContextSummary: Output from Context Analyzer for codebase analysis

Constitutional Compliance:
- Principle X: Agent Delegation Protocol - Router determines agent selection
- Principle III: Contract-First Design - Context contracts defined before implementation

Usage:
    from sdd.agents.architecture.models import RoutingDecision, ContextSummary

    # Create routing decision
    routing = RoutingDecision(
        selected_agents=["engineering.backend", "engineering.frontend"],
        execution_strategy="dag",
        dependency_graph={
            "engineering.backend": [],
            "engineering.frontend": ["engineering.backend"]
        },
        refinement_strategy="ROUTE_TO_DEBUG",
        reasoning="Feature requires both backend API and frontend UI",
        confidence=0.88
    )

    # Create context summary
    context = ContextSummary(
        task_id="550e8400-e29b-41d4-a716-446655440000",
        relevant_files=["/path/to/file.py"],
        file_summaries={"/path/to/file.py": "Auth handler"},
        existing_patterns=["Library-First Architecture"],
        dependencies={"/path/to/file.py": ["/path/to/dependency.py"]},
        related_specs=["specs/001-auth/spec.md"],
        constitutional_status={"Principle I": True},
        embedding_vector=[0.1, 0.2, ...],  # 384 dimensions
        generated_at=datetime.now()
    )
"""

from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


# ===================================================================
# Enumerations
# ===================================================================

class ExecutionStrategy(str, Enum):
    """Agent execution strategy for parallel/sequential coordination."""
    SEQUENTIAL = "sequential"
    PARALLEL = "parallel"
    DAG = "dag"  # Directed Acyclic Graph (dependency-based)


class RefinementStrategy(str, Enum):
    """Strategy for handling refinement failures."""
    ADD_STEP = "ADD_STEP"
    TRUNCATE_FROM = "TRUNCATE_FROM"
    ROUTE_TO_DEBUG = "ROUTE_TO_DEBUG"
    RETRY_WITH_FEEDBACK = "RETRY_WITH_FEEDBACK"


# ===================================================================
# RoutingDecision (T022)
# ===================================================================

class RoutingDecision(BaseModel):
    """
    Output from Router Agent.

    This model represents the orchestration decision for multi-agent workflows.
    Determines which agents to invoke, execution strategy, and refinement approach.

    Fields:
        selected_agents: Agent IDs to invoke (list of {department}.{agent_name})
        execution_strategy: How to execute (sequential, parallel, dag)
        dependency_graph: Agent dependencies (required if DAG strategy)
        refinement_strategy: On failure (ADD_STEP, TRUNCATE_FROM, ROUTE_TO_DEBUG, RETRY)
        reasoning: Why these agents were selected
        confidence: Confidence in routing decision (0.0 to 1.0)
        parallel_execution_plan: Detailed plan for parallel execution (optional)
        estimated_duration_seconds: Estimated execution time (optional)

    Execution Strategies:
        - sequential: Execute agents one after another
        - parallel: Execute all agents simultaneously (independent tasks)
        - dag: Execute based on dependency graph (topological order)

    Refinement Strategies:
        - ADD_STEP: Add additional verification/validation step
        - TRUNCATE_FROM: Restart from specific agent in sequence
        - ROUTE_TO_DEBUG: Send to auto-debug agent for error repair
        - RETRY_WITH_FEEDBACK: Re-run same agent with accumulated feedback

    Validation:
        - selected_agents must be non-empty
        - execution_strategy must be valid option
        - dependency_graph required if strategy is "dag"
        - All agents in dependency_graph must exist in selected_agents

    Storage:
        Stored in .docs/agents/architecture/router/decisions/{task_id}.json

    Example:
        >>> routing = RoutingDecision(
        ...     selected_agents=["engineering.backend", "engineering.frontend"],
        ...     execution_strategy="dag",
        ...     dependency_graph={
        ...         "engineering.backend": [],
        ...         "engineering.frontend": ["engineering.backend"]
        ...     },
        ...     refinement_strategy="ROUTE_TO_DEBUG",
        ...     reasoning="Feature requires both backend API and frontend UI",
        ...     confidence=0.88
        ... )
        >>> routing.execution_strategy
        <ExecutionStrategy.DAG: 'dag'>
    """

    selected_agents: List[str] = Field(
        ...,
        min_length=1,
        description="Agent IDs to invoke (format: {department}.{agent_name})"
    )

    execution_strategy: ExecutionStrategy = Field(
        ...,
        description="How to execute (sequential, parallel, dag)"
    )

    dependency_graph: Optional[Dict[str, List[str]]] = Field(
        None,
        description="Agent dependencies (required if DAG strategy)"
    )

    refinement_strategy: Optional[RefinementStrategy] = Field(
        None,
        description="On failure (ADD_STEP, TRUNCATE_FROM, ROUTE_TO_DEBUG, RETRY)"
    )

    reasoning: str = Field(
        ...,
        min_length=10,
        description="Why these agents were selected"
    )

    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Confidence in routing decision (0.0 to 1.0)"
    )

    parallel_execution_plan: Optional[List[Dict[str, List[str]]]] = Field(
        None,
        description="Detailed plan for parallel execution (optional)"
    )

    estimated_duration_seconds: Optional[int] = Field(
        None,
        gt=0,
        description="Estimated execution time in seconds (optional)"
    )

    model_config = {
        "frozen": True,  # Immutable after creation (audit trail)
        "json_schema_extra": {
            "examples": [
                {
                    "selected_agents": ["engineering.backend", "engineering.frontend"],
                    "execution_strategy": "dag",
                    "dependency_graph": {
                        "engineering.backend": [],
                        "engineering.frontend": ["engineering.backend"]
                    },
                    "refinement_strategy": "ROUTE_TO_DEBUG",
                    "reasoning": "Feature requires both backend API and frontend UI. Backend must complete first to define API contract.",
                    "confidence": 0.88,
                    "parallel_execution_plan": None,
                    "estimated_duration_seconds": 3600
                }
            ]
        }
    }

    @field_validator("selected_agents")
    @classmethod
    def validate_agent_id_format(cls, v: List[str]) -> List[str]:
        """Validate that all agent IDs follow {department}.{agent_name} format."""
        import re
        pattern = re.compile(r"^[a-z_]+\.[a-z_]+$")
        for agent_id in v:
            if not pattern.match(agent_id):
                raise ValueError(
                    f"agent_id must match pattern {{department}}.{{agent_name}}, got: {agent_id}"
                )
        return v

    @model_validator(mode="after")
    def validate_dag_requires_dependency_graph(self) -> "RoutingDecision":
        """Validate that dependency_graph is provided if execution_strategy is DAG."""
        if self.execution_strategy == ExecutionStrategy.DAG and not self.dependency_graph:
            raise ValueError(
                "dependency_graph required when execution_strategy is 'dag'"
            )
        return self

    @model_validator(mode="after")
    def validate_dependency_graph_agents_exist(self) -> "RoutingDecision":
        """Validate that all agents in dependency_graph exist in selected_agents."""
        if self.dependency_graph:
            for agent, dependencies in self.dependency_graph.items():
                # Check that agent is in selected_agents
                if agent not in self.selected_agents:
                    raise ValueError(
                        f"Agent '{agent}' in dependency_graph not in selected_agents"
                    )
                # Check that all dependencies are in selected_agents
                for dep in dependencies:
                    if dep not in self.selected_agents:
                        raise ValueError(
                            f"Dependency '{dep}' for agent '{agent}' not in selected_agents"
                        )
        return self

    def get_execution_order(self) -> List[List[str]]:
        """
        Get topological execution order for DAG strategy.

        Returns list of agent batches that can run in parallel.
        Each batch is a list of agents with no dependencies on each other.

        Returns:
            List of agent batches (each batch can execute in parallel)

        Example:
            >>> routing = RoutingDecision(
            ...     selected_agents=["A", "B", "C"],
            ...     execution_strategy="dag",
            ...     dependency_graph={"A": [], "B": ["A"], "C": ["A"]},
            ...     reasoning="...",
            ...     confidence=0.9
            ... )
            >>> routing.get_execution_order()
            [['A'], ['B', 'C']]
        """
        if self.execution_strategy != ExecutionStrategy.DAG:
            return [[agent] for agent in self.selected_agents]

        if not self.dependency_graph:
            return [[agent] for agent in self.selected_agents]

        # Topological sort with batch execution
        in_degree = {agent: 0 for agent in self.selected_agents}
        for agent, deps in self.dependency_graph.items():
            in_degree[agent] = len(deps)

        batches: List[List[str]] = []
        remaining = set(self.selected_agents)

        while remaining:
            # Find all agents with no remaining dependencies
            batch = [
                agent for agent in remaining
                if in_degree[agent] == 0
            ]

            if not batch:
                # Circular dependency detected
                raise ValueError(
                    f"Circular dependency detected in dependency_graph: {remaining}"
                )

            batches.append(batch)
            remaining -= set(batch)

            # Reduce in-degree for dependent agents
            for agent in batch:
                for other_agent, deps in self.dependency_graph.items():
                    if agent in deps:
                        in_degree[other_agent] -= 1

        return batches


# ===================================================================
# ContextSummary (T024)
# ===================================================================

class ContextSummary(BaseModel):
    """
    Codebase analysis result from Context Analyzer.

    This model represents the structured analysis of the codebase relevant to
    a specific task. Includes relevant files, patterns, dependencies, and
    constitutional compliance status.

    Fields:
        task_id: Task identifier (UUID format)
        relevant_files: File paths relevant to task
        file_summaries: Brief description per file
        existing_patterns: Architectural patterns found
        dependencies: File dependency graph
        related_specs: Similar past feature specifications
        constitutional_status: Principle compliance per area
        embedding_vector: Semantic embedding (384-dim, optional)
        generated_at: When analysis was performed

    Validation:
        - relevant_files must all exist
        - constitutional_status must include all 14 principles
        - embedding_vector must be 384 dimensions if provided

    Storage:
        Stored in .docs/agents/architecture/context_analyzer/summaries/{task_id}.json

    Example:
        >>> from datetime import datetime
        >>> context = ContextSummary(
        ...     task_id="550e8400-e29b-41d4-a716-446655440000",
        ...     relevant_files=["/path/to/file.py"],
        ...     file_summaries={"/path/to/file.py": "Auth handler"},
        ...     existing_patterns=["Library-First Architecture"],
        ...     dependencies={"/path/to/file.py": []},
        ...     related_specs=["specs/001-auth/spec.md"],
        ...     constitutional_status={"Principle I": True},
        ...     embedding_vector=None,
        ...     generated_at=datetime.now()
        ... )
        >>> context.task_id
        '550e8400-e29b-41d4-a716-446655440000'
    """

    task_id: str = Field(
        ...,
        description="Task identifier (UUID format)"
    )

    relevant_files: List[str] = Field(
        ...,
        description="File paths relevant to task"
    )

    file_summaries: Dict[str, str] = Field(
        ...,
        description="Brief description per file"
    )

    existing_patterns: List[str] = Field(
        default_factory=list,
        description="Architectural patterns found"
    )

    dependencies: Dict[str, List[str]] = Field(
        default_factory=dict,
        description="File dependency graph"
    )

    related_specs: List[str] = Field(
        default_factory=list,
        description="Similar past feature specifications"
    )

    constitutional_status: Dict[str, bool] = Field(
        ...,
        description="Principle compliance per area"
    )

    embedding_vector: Optional[List[float]] = Field(
        None,
        description="Semantic embedding (384-dim, optional)"
    )

    generated_at: datetime = Field(
        default_factory=datetime.now,
        description="When analysis was performed"
    )

    model_config = {
        "frozen": True,  # Immutable after creation
        "json_schema_extra": {
            "examples": [
                {
                    "task_id": "550e8400-e29b-41d4-a716-446655440000",
                    "relevant_files": [
                        "/workspaces/logic-loom/.claude/agents/product/planning-agent.md",
                        "/workspaces/logic-loom/.logic-loom/memory/constitution.md"
                    ],
                    "file_summaries": {
                        "planning-agent.md": "Implementation planning specialist",
                        "constitution.md": "14 enforceable principles"
                    },
                    "existing_patterns": [
                        "Library-First Architecture",
                        "Agent Delegation Protocol"
                    ],
                    "dependencies": {
                        "planning-agent.md": ["constitution.md"]
                    },
                    "related_specs": ["specs/000-agent-framework/spec.md"],
                    "constitutional_status": {"Principle I": True},
                    "embedding_vector": None,
                    "generated_at": "2025-11-10T10:30:00Z"
                }
            ]
        }
    }

    @field_validator("task_id")
    @classmethod
    def validate_task_id_uuid(cls, v: str) -> str:
        """Validate that task_id is a valid UUID."""
        from uuid import UUID
        try:
            UUID(v)
        except ValueError:
            raise ValueError(f"task_id must be a valid UUID, got: {v}")
        return v

    @field_validator("relevant_files")
    @classmethod
    def validate_files_exist(cls, v: List[str]) -> List[str]:
        """Validate that all relevant files exist."""
        for file_path in v:
            path = Path(file_path)
            if not path.exists():
                raise ValueError(f"File does not exist: {file_path}")
        return v

    @field_validator("constitutional_status")
    @classmethod
    def validate_all_principles_present(cls, v: Dict[str, bool]) -> Dict[str, bool]:
        """Validate that all 14 constitutional principles are present."""
        expected_principles = [
            "Principle I", "Principle II", "Principle III",
            "Principle IV", "Principle V", "Principle VI",
            "Principle VII", "Principle VIII", "Principle IX",
            "Principle X", "Principle XI", "Principle XII",
            "Principle XIII", "Principle XIV"
        ]
        for principle in expected_principles:
            if principle not in v:
                raise ValueError(f"Missing constitutional principle: {principle}")
        return v

    @field_validator("embedding_vector")
    @classmethod
    def validate_embedding_dimensions(cls, v: Optional[List[float]]) -> Optional[List[float]]:
        """Validate that embedding vector is 384 dimensions if provided."""
        if v is not None and len(v) != 384:
            raise ValueError(
                f"embedding_vector must be 384 dimensions (all-MiniLM-L6-v2), got: {len(v)}"
            )
        return v

    def calculate_similarity(self, other: "ContextSummary") -> float:
        """
        Calculate semantic similarity to another ContextSummary.

        Uses cosine similarity of embedding vectors if both have embeddings.
        Falls back to simple overlap metrics if embeddings not available.

        Args:
            other: Another ContextSummary to compare

        Returns:
            Similarity score (0.0 to 1.0)

        Example:
            >>> context1 = ContextSummary(...)
            >>> context2 = ContextSummary(...)
            >>> similarity = context1.calculate_similarity(context2)
            >>> assert 0.0 <= similarity <= 1.0
        """
        # If both have embeddings, use cosine similarity
        if self.embedding_vector and other.embedding_vector:
            import numpy as np
            vec1 = np.array(self.embedding_vector)
            vec2 = np.array(other.embedding_vector)
            cosine_sim = np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2))
            return float(cosine_sim)

        # Fallback: Use file overlap as similarity metric
        files1 = set(self.relevant_files)
        files2 = set(other.relevant_files)
        if not files1 or not files2:
            return 0.0
        overlap = len(files1 & files2)
        union = len(files1 | files2)
        return overlap / union if union > 0 else 0.0
