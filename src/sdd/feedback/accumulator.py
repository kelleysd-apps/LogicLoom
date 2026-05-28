"""
Feedback Accumulator - Progressive Learning System
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Stores and retrieves feedback records across refinement iterations.
    Enables progressive improvement by providing cumulative learnings.
    Implements archival strategy for old feedback (>1000 iterations).

Constitutional Compliance:
    - Principle I: Library-First - Accumulator is standalone library
    - Principle VII: Observability - Complete feedback history for audit trail
    - Principle IV: Idempotent Operations - Safe to call add() multiple times

Storage:
    Feedback stored at: .docs/agents/shared/feedback/{task_id}.json

Usage:
    from sdd.feedback.accumulator import FeedbackAccumulator

    accumulator = FeedbackAccumulator()

    # Add feedback from verification failure
    accumulator.add(
        task_id="550e8400-e29b-41d4-a716-446655440000",
        feedback="Add contract for POST /api/users endpoint",
        iteration=1,
        quality_score=0.72,
        agent_id="quality.verifier"
    )

    # Retrieve cumulative learnings
    learnings = accumulator.get_cumulative(
        task_id="550e8400-e29b-41d4-a716-446655440000"
    )
    print(f"Total feedback items: {len(learnings)}")
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ===================================================================
# FeedbackRecord Model
# ===================================================================

class FeedbackRecord(BaseModel):
    """
    Single feedback record from verification failure.

    Fields:
        iteration: Iteration number when feedback generated
        timestamp: When feedback was recorded
        feedback: Actionable feedback text
        quality_score: Quality score that triggered feedback (0.0-1.0)
        agent_id: Agent that provided feedback
        metadata: Additional context (optional)
    """

    iteration: int = Field(
        ...,
        ge=1,
        description="Iteration number when feedback generated"
    )

    timestamp: datetime = Field(
        default_factory=datetime.now,
        description="When feedback was recorded"
    )

    feedback: str = Field(
        ...,
        min_length=1,
        description="Actionable feedback text"
    )

    quality_score: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Quality score that triggered feedback (0.0-1.0)"
    )

    agent_id: str = Field(
        ...,
        pattern=r"^[a-z_]+\.[a-z_]+$",
        description="Agent that provided feedback (format: {department}.{agent_name})"
    )

    metadata: Dict[str, Any] = Field(
        default_factory=dict,
        description="Additional context (optional)"
    )

    model_config = {
        "frozen": True  # Immutable after creation (audit trail)
    }


class FeedbackHistory(BaseModel):
    """
    Complete feedback history for a task.

    Fields:
        task_id: Task identifier (UUID format)
        records: List of feedback records (chronologically ordered)
        created_at: When history was created
        updated_at: Last update timestamp
        archived: Whether history has been archived
    """

    task_id: str = Field(
        ...,
        description="Task identifier (UUID format)"
    )

    records: List[FeedbackRecord] = Field(
        default_factory=list,
        description="List of feedback records (chronologically ordered)"
    )

    created_at: datetime = Field(
        default_factory=datetime.now,
        description="When history was created"
    )

    updated_at: datetime = Field(
        default_factory=datetime.now,
        description="Last update timestamp"
    )

    archived: bool = Field(
        default=False,
        description="Whether history has been archived"
    )

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
# FeedbackAccumulator
# ===================================================================

class FeedbackAccumulator:
    """
    Feedback Accumulator for progressive learning.

    Stores feedback records and provides cumulative learnings across iterations.
    Implements archival strategy when record count exceeds threshold.

    Attributes:
        feedback_dir: Directory for feedback storage
        archive_dir: Directory for archived feedback
        archive_threshold: Record count to trigger archival (default: 1000)
    """

    def __init__(
        self,
        feedback_dir: str = "/workspaces/logic-loom/.docs/agents/shared/feedback",
        archive_dir: str = "/workspaces/logic-loom/.docs/agents/shared/feedback/archive",
        archive_threshold: int = 1000
    ):
        """
        Initialize Feedback Accumulator.

        Args:
            feedback_dir: Directory for feedback storage
            archive_dir: Directory for archived feedback
            archive_threshold: Record count to trigger archival
        """
        self.feedback_dir = Path(feedback_dir)
        self.archive_dir = Path(archive_dir)
        self.archive_threshold = archive_threshold

        # Create directories
        self.feedback_dir.mkdir(parents=True, exist_ok=True)
        self.archive_dir.mkdir(parents=True, exist_ok=True)

        logger.info(
            f"FeedbackAccumulator initialized: dir={self.feedback_dir}, "
            f"archive_threshold={self.archive_threshold}"
        )

    def add(
        self,
        task_id: str,
        feedback: str,
        iteration: int,
        quality_score: float,
        agent_id: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> FeedbackHistory:
        """
        Add feedback record for task.

        Args:
            task_id: Task identifier (UUID format)
            feedback: Actionable feedback text
            iteration: Iteration number
            quality_score: Quality score (0.0-1.0)
            agent_id: Agent that provided feedback
            metadata: Additional context (optional)

        Returns:
            Updated FeedbackHistory

        Raises:
            ValueError: If task_id is not valid UUID or quality_score out of range

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> history = accumulator.add(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000",
            ...     feedback="Add contract for POST /api/users",
            ...     iteration=1,
            ...     quality_score=0.72,
            ...     agent_id="quality.verifier"
            ... )
            >>> len(history.records)
            1
        """
        # Validate task_id
        try:
            UUID(task_id)
        except ValueError:
            raise ValueError(f"task_id must be valid UUID, got: {task_id}")

        # Load or create history
        history = self._load_or_create_history(task_id)

        # Create feedback record
        record = FeedbackRecord(
            iteration=iteration,
            timestamp=datetime.now(),
            feedback=feedback,
            quality_score=quality_score,
            agent_id=agent_id,
            metadata=metadata or {}
        )

        # Add record to history
        updated_history = FeedbackHistory(
            task_id=history.task_id,
            records=history.records + [record],
            created_at=history.created_at,
            updated_at=datetime.now(),
            archived=history.archived
        )

        # Save updated history
        self._save_history(updated_history)

        logger.info(
            f"Added feedback for task_id={task_id}, iteration={iteration}, "
            f"total_records={len(updated_history.records)}"
        )

        # Check if archival needed
        if len(updated_history.records) >= self.archive_threshold:
            logger.warning(
                f"Feedback record count ({len(updated_history.records)}) >= "
                f"threshold ({self.archive_threshold}). Consider archiving."
            )

        return updated_history

    def get_cumulative(
        self,
        task_id: str,
        max_records: Optional[int] = None
    ) -> List[str]:
        """
        Get cumulative feedback learnings for task.

        Returns list of feedback text in chronological order.

        Args:
            task_id: Task identifier
            max_records: Maximum number of recent records to return (None = all)

        Returns:
            List of feedback text strings

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> learnings = accumulator.get_cumulative(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
            >>> for feedback in learnings:
            ...     print(f"- {feedback}")
        """
        try:
            history = self._load_history(task_id)
        except FileNotFoundError:
            logger.info(f"No feedback history found for task_id={task_id}")
            return []

        records = history.records
        if max_records is not None:
            records = records[-max_records:]  # Get most recent N records

        return [record.feedback for record in records]

    def get_history(self, task_id: str) -> Optional[FeedbackHistory]:
        """
        Get complete feedback history for task.

        Args:
            task_id: Task identifier

        Returns:
            FeedbackHistory if exists, None otherwise

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> history = accumulator.get_history(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
            >>> if history:
            ...     print(f"Total records: {len(history.records)}")
        """
        try:
            return self._load_history(task_id)
        except FileNotFoundError:
            return None

    def get_quality_progression(self, task_id: str) -> List[float]:
        """
        Get quality score progression across iterations.

        Args:
            task_id: Task identifier

        Returns:
            List of quality scores in iteration order

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> scores = accumulator.get_quality_progression(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
            >>> print(f"Quality trend: {scores}")
        """
        try:
            history = self._load_history(task_id)
        except FileNotFoundError:
            return []

        return [record.quality_score for record in history.records]

    def archive(self, task_id: str) -> bool:
        """
        Archive feedback history for task.

        Moves feedback file to archive directory and marks as archived.

        Args:
            task_id: Task identifier

        Returns:
            True if archived, False if not found

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> archived = accumulator.archive(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
            >>> if archived:
            ...     print("History archived successfully")
        """
        feedback_file = self.feedback_dir / f"{task_id}.json"
        if not feedback_file.exists():
            logger.warning(f"No feedback history to archive for task_id={task_id}")
            return False

        # Load history
        history = self._load_history(task_id)

        # Mark as archived
        archived_history = FeedbackHistory(
            task_id=history.task_id,
            records=history.records,
            created_at=history.created_at,
            updated_at=datetime.now(),
            archived=True
        )

        # Save to archive directory
        archive_file = self.archive_dir / f"{task_id}.json"
        archive_file.write_text(archived_history.model_dump_json(indent=2))

        # Delete from active directory
        feedback_file.unlink()

        logger.info(
            f"Archived feedback history for task_id={task_id}: "
            f"{len(history.records)} records"
        )
        return True

    def clear(self, task_id: str) -> bool:
        """
        Delete feedback history for task.

        Args:
            task_id: Task identifier

        Returns:
            True if deleted, False if not found

        Example:
            >>> accumulator = FeedbackAccumulator()
            >>> deleted = accumulator.clear(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
        """
        feedback_file = self.feedback_dir / f"{task_id}.json"
        if feedback_file.exists():
            feedback_file.unlink()
            logger.info(f"Deleted feedback history for task_id={task_id}")
            return True
        return False

    def _load_or_create_history(self, task_id: str) -> FeedbackHistory:
        """
        Load existing feedback history or create new one.

        Args:
            task_id: Task identifier

        Returns:
            FeedbackHistory (loaded or newly created)
        """
        try:
            return self._load_history(task_id)
        except FileNotFoundError:
            logger.info(f"Creating new feedback history for task_id={task_id}")
            return FeedbackHistory(
                task_id=task_id,
                records=[],
                created_at=datetime.now(),
                updated_at=datetime.now(),
                archived=False
            )

    def _load_history(self, task_id: str) -> FeedbackHistory:
        """
        Load feedback history from file.

        Args:
            task_id: Task identifier

        Returns:
            FeedbackHistory loaded from file

        Raises:
            FileNotFoundError: If history file doesn't exist
        """
        feedback_file = self.feedback_dir / f"{task_id}.json"
        if not feedback_file.exists():
            raise FileNotFoundError(f"Feedback history not found: {feedback_file}")

        return FeedbackHistory.model_validate_json(feedback_file.read_text())

    def _save_history(self, history: FeedbackHistory) -> None:
        """
        Save feedback history to file.

        Args:
            history: FeedbackHistory to save
        """
        feedback_file = self.feedback_dir / f"{history.task_id}.json"
        feedback_file.write_text(history.model_dump_json(indent=2))
        logger.debug(f"Saved feedback history: {feedback_file}")
