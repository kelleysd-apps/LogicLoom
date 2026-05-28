"""
Metrics Collector - Performance Tracking and KPI Validation
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Tracks task completion metrics and calculates improvement over baseline.
    Validates 3.5x improvement target (FR-047).
    Exports structured metrics for analysis and monitoring.

Constitutional Compliance:
    - Principle I: Library-First - Collector is standalone library
    - Principle VII: Observability - Structured metrics logging
    - FR-047: Achieve 3.5x improvement in task completion accuracy

Metrics Tracked:
    - Task completion accuracy (% without manual intervention)
    - Average refinement rounds per task
    - Debug success rate (% auto-resolved)
    - Context retrieval accuracy
    - Constitutional compliance rate (% passing finalizer first time)

Storage:
    Metrics stored at: .docs/agents/shared/metrics/{phase}/{task_id}.json
    Baseline stored at: .docs/agents/shared/metrics/baseline.json

Usage:
    from sdd.metrics.collector import MetricsCollector
    from sdd.metrics.models import TaskMetrics

    collector = MetricsCollector()

    # Record task metrics
    metrics = TaskMetrics(
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="planning",
        started_at=datetime.now(),
        completed_at=datetime.now(),
        duration_seconds=120.5,
        refinement_rounds=3,
        completed_without_intervention=True
    )
    collector.record_task(metrics)

    # Calculate improvement over baseline
    improvement = collector.calculate_improvement()
    print(f"Improvement: {improvement:.2f}x")
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from sdd.metrics.models import TaskMetrics

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ===================================================================
# Baseline Metrics Model
# ===================================================================

class BaselineMetrics:
    """
    Baseline performance metrics (pre-enhancement).

    Attributes:
        task_completion_accuracy: Baseline completion accuracy (0.0-100.0)
        avg_refinement_rounds: Baseline refinement rounds
        debug_success_rate: Baseline debug success rate (0.0-100.0)
        constitutional_compliance_rate: Baseline compliance rate (0.0-100.0)
        measured_at: When baseline was measured
        task_count: Number of tasks in baseline
    """

    def __init__(
        self,
        task_completion_accuracy: float = 0.0,
        avg_refinement_rounds: float = 0.0,
        debug_success_rate: float = 0.0,
        constitutional_compliance_rate: float = 0.0,
        measured_at: Optional[datetime] = None,
        task_count: int = 0
    ):
        self.task_completion_accuracy = task_completion_accuracy
        self.avg_refinement_rounds = avg_refinement_rounds
        self.debug_success_rate = debug_success_rate
        self.constitutional_compliance_rate = constitutional_compliance_rate
        self.measured_at = measured_at or datetime.now()
        self.task_count = task_count

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            'task_completion_accuracy': self.task_completion_accuracy,
            'avg_refinement_rounds': self.avg_refinement_rounds,
            'debug_success_rate': self.debug_success_rate,
            'constitutional_compliance_rate': self.constitutional_compliance_rate,
            'measured_at': self.measured_at.isoformat(),
            'task_count': self.task_count
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'BaselineMetrics':
        """Create from dictionary."""
        return cls(
            task_completion_accuracy=data.get('task_completion_accuracy', 0.0),
            avg_refinement_rounds=data.get('avg_refinement_rounds', 0.0),
            debug_success_rate=data.get('debug_success_rate', 0.0),
            constitutional_compliance_rate=data.get('constitutional_compliance_rate', 0.0),
            measured_at=datetime.fromisoformat(data['measured_at']),
            task_count=data.get('task_count', 0)
        )


# ===================================================================
# MetricsCollector
# ===================================================================

class MetricsCollector:
    """
    Metrics Collector for performance tracking.

    Records task metrics, calculates KPIs, and validates improvement targets.

    Attributes:
        metrics_dir: Directory for metrics storage
        baseline_file: Path to baseline metrics file
        baseline: Baseline metrics (pre-enhancement)
    """

    def __init__(
        self,
        metrics_dir: str = "/workspaces/logic-loom/.docs/agents/shared/metrics",
        baseline_file: str = "/workspaces/logic-loom/.docs/agents/shared/metrics/baseline.json"
    ):
        """
        Initialize Metrics Collector.

        Args:
            metrics_dir: Directory for metrics storage
            baseline_file: Path to baseline metrics file
        """
        self.metrics_dir = Path(metrics_dir)
        self.baseline_file = Path(baseline_file)

        # Create directories
        self.metrics_dir.mkdir(parents=True, exist_ok=True)

        # Load or create baseline
        self.baseline = self._load_baseline()

        logger.info(
            f"MetricsCollector initialized: baseline_accuracy={self.baseline.task_completion_accuracy:.1f}%, "
            f"task_count={self.baseline.task_count}"
        )

    def record_task(self, metrics: TaskMetrics) -> None:
        """
        Record task metrics.

        Args:
            metrics: TaskMetrics instance to record

        Example:
            >>> collector = MetricsCollector()
            >>> metrics = TaskMetrics(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000",
            ...     phase="planning",
            ...     completed_without_intervention=True,
            ...     ...
            ... )
            >>> collector.record_task(metrics)
        """
        # Save metrics to file
        metrics.save_to_file(str(self.metrics_dir))

        logger.info(
            f"Recorded metrics: task_id={metrics.task_id}, phase={metrics.phase}, "
            f"completed_without_intervention={metrics.completed_without_intervention}"
        )

        # Log structured metrics (Principle VII)
        self._log_structured_metrics(metrics)

    def calculate_improvement(
        self,
        phase: Optional[str] = None,
        since: Optional[datetime] = None
    ) -> float:
        """
        Calculate improvement over baseline.

        Computes task completion accuracy improvement ratio.
        FR-047 target: 3.5x improvement.

        Args:
            phase: Filter to specific phase (None = all phases)
            since: Filter to metrics since timestamp (None = all time)

        Returns:
            Improvement ratio (current / baseline)

        Example:
            >>> collector = MetricsCollector()
            >>> improvement = collector.calculate_improvement()
            >>> if improvement >= 3.5:
            ...     print("Target achieved!")
            >>> else:
            ...     print(f"Current: {improvement:.2f}x, Target: 3.5x")
        """
        # Load all task metrics
        all_metrics = self._load_all_metrics(phase=phase, since=since)

        if not all_metrics:
            logger.warning("No metrics available for improvement calculation")
            return 0.0

        # Calculate current task completion accuracy
        current_accuracy = TaskMetrics.calculate_task_completion_accuracy(all_metrics)

        # Calculate improvement ratio
        if self.baseline.task_completion_accuracy > 0:
            improvement = current_accuracy / self.baseline.task_completion_accuracy
        else:
            # No baseline or zero baseline - treat current as improvement
            improvement = float('inf') if current_accuracy > 0 else 0.0

        logger.info(
            f"Improvement calculation: current={current_accuracy:.1f}%, "
            f"baseline={self.baseline.task_completion_accuracy:.1f}%, "
            f"improvement={improvement:.2f}x"
        )

        return improvement

    def get_aggregate_metrics(
        self,
        phase: Optional[str] = None,
        since: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """
        Get aggregate metrics across all tasks.

        Args:
            phase: Filter to specific phase (None = all phases)
            since: Filter to metrics since timestamp (None = all time)

        Returns:
            Dictionary with aggregate metrics

        Example:
            >>> collector = MetricsCollector()
            >>> agg = collector.get_aggregate_metrics(phase="planning")
            >>> print(f"Avg refinement rounds: {agg['avg_refinement_rounds']:.1f}")
        """
        all_metrics = self._load_all_metrics(phase=phase, since=since)

        if not all_metrics:
            return {
                'task_count': 0,
                'task_completion_accuracy': 0.0,
                'avg_refinement_rounds': 0.0,
                'avg_debug_success_rate': 0.0,
                'avg_constitutional_compliance_rate': 0.0,
                'avg_context_latency_ms': 0.0,
                'improvement_ratio': 0.0
            }

        # Calculate aggregates
        task_completion_accuracy = TaskMetrics.calculate_task_completion_accuracy(all_metrics)

        avg_refinement_rounds = sum(m.refinement_rounds for m in all_metrics) / len(all_metrics)

        debug_success_rates = [m.calculate_debug_success_rate() for m in all_metrics]
        avg_debug_success_rate = sum(debug_success_rates) / len(debug_success_rates)

        compliance_rates = [m.calculate_constitutional_compliance_rate() for m in all_metrics]
        avg_compliance_rate = sum(compliance_rates) / len(compliance_rates)

        latencies = [m.avg_context_latency_ms for m in all_metrics if m.avg_context_latency_ms > 0]
        avg_context_latency = sum(latencies) / len(latencies) if latencies else 0.0

        improvement_ratio = (
            task_completion_accuracy / self.baseline.task_completion_accuracy
            if self.baseline.task_completion_accuracy > 0 else 0.0
        )

        return {
            'task_count': len(all_metrics),
            'task_completion_accuracy': task_completion_accuracy,
            'avg_refinement_rounds': avg_refinement_rounds,
            'avg_debug_success_rate': avg_debug_success_rate,
            'avg_constitutional_compliance_rate': avg_compliance_rate,
            'avg_context_latency_ms': avg_context_latency,
            'improvement_ratio': improvement_ratio,
            'baseline': self.baseline.to_dict()
        }

    def export_metrics_report(
        self,
        output_path: Optional[str] = None
    ) -> str:
        """
        Export comprehensive metrics report.

        Args:
            output_path: Path to save report (default: metrics_dir/report_{timestamp}.json)

        Returns:
            Path to exported report

        Example:
            >>> collector = MetricsCollector()
            >>> report_path = collector.export_metrics_report()
            >>> print(f"Report saved: {report_path}")
        """
        if output_path is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = str(self.metrics_dir / f"report_{timestamp}.json")

        # Gather all metrics
        all_metrics = self._load_all_metrics()

        # Build report
        report = {
            'generated_at': datetime.now().isoformat(),
            'baseline': self.baseline.to_dict(),
            'aggregate': self.get_aggregate_metrics(),
            'by_phase': {},
            'tasks': []
        }

        # Aggregate by phase
        for phase in ['specification', 'planning', 'implementation', 'validation']:
            phase_metrics = self.get_aggregate_metrics(phase=phase)
            if phase_metrics['task_count'] > 0:
                report['by_phase'][phase] = phase_metrics

        # Individual task metrics
        for metrics in all_metrics:
            report['tasks'].append(metrics.export_for_analysis())

        # Save report
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(json.dumps(report, indent=2))

        logger.info(f"Metrics report exported: {output_path}")
        return str(output_file)

    def set_baseline(
        self,
        task_completion_accuracy: float,
        avg_refinement_rounds: float = 0.0,
        debug_success_rate: float = 0.0,
        constitutional_compliance_rate: float = 0.0,
        task_count: int = 0
    ) -> None:
        """
        Set baseline metrics (pre-enhancement performance).

        Args:
            task_completion_accuracy: Baseline completion accuracy (0.0-100.0)
            avg_refinement_rounds: Baseline refinement rounds
            debug_success_rate: Baseline debug success rate (0.0-100.0)
            constitutional_compliance_rate: Baseline compliance rate (0.0-100.0)
            task_count: Number of tasks in baseline

        Example:
            >>> collector = MetricsCollector()
            >>> # Measure current performance before enhancement
            >>> collector.set_baseline(
            ...     task_completion_accuracy=20.0,  # 20% without intervention
            ...     avg_refinement_rounds=5.0,
            ...     debug_success_rate=30.0,  # 30% auto-resolved
            ...     constitutional_compliance_rate=60.0,  # 60% pass first time
            ...     task_count=50
            ... )
        """
        self.baseline = BaselineMetrics(
            task_completion_accuracy=task_completion_accuracy,
            avg_refinement_rounds=avg_refinement_rounds,
            debug_success_rate=debug_success_rate,
            constitutional_compliance_rate=constitutional_compliance_rate,
            measured_at=datetime.now(),
            task_count=task_count
        )

        # Save baseline
        self._save_baseline()

        logger.info(
            f"Baseline set: accuracy={task_completion_accuracy:.1f}%, "
            f"refinement_rounds={avg_refinement_rounds:.1f}, "
            f"task_count={task_count}"
        )

    def _load_baseline(self) -> BaselineMetrics:
        """Load baseline metrics from file."""
        if not self.baseline_file.exists():
            logger.info("No baseline found. Creating default (0.0).")
            return BaselineMetrics()

        try:
            with open(self.baseline_file, 'r') as f:
                data = json.load(f)
            return BaselineMetrics.from_dict(data)
        except Exception as e:
            logger.warning(f"Failed to load baseline: {e}. Using default.")
            return BaselineMetrics()

    def _save_baseline(self) -> None:
        """Save baseline metrics to file."""
        self.baseline_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.baseline_file, 'w') as f:
            json.dump(self.baseline.to_dict(), f, indent=2)
        logger.info(f"Baseline saved: {self.baseline_file}")

    def _load_all_metrics(
        self,
        phase: Optional[str] = None,
        since: Optional[datetime] = None
    ) -> List[TaskMetrics]:
        """Load all task metrics from storage."""
        all_metrics = []

        # Determine which phase directories to scan
        if phase:
            phase_dirs = [self.metrics_dir / phase]
        else:
            phase_dirs = [
                d for d in self.metrics_dir.iterdir()
                if d.is_dir() and d.name != 'archive'
            ]

        # Load metrics from each phase directory
        for phase_dir in phase_dirs:
            if not phase_dir.exists():
                continue

            for metrics_file in phase_dir.glob("*.json"):
                try:
                    metrics = TaskMetrics.model_validate_json(metrics_file.read_text())

                    # Filter by timestamp if requested
                    if since and metrics.started_at < since:
                        continue

                    all_metrics.append(metrics)
                except Exception as e:
                    logger.warning(f"Failed to load metrics from {metrics_file}: {e}")

        return all_metrics

    def _log_structured_metrics(self, metrics: TaskMetrics) -> None:
        """Log structured metrics (Principle VII)."""
        log_data = {
            'timestamp': datetime.now().isoformat(),
            'level': 'INFO',
            'operation': 'record_task_metrics',
            'task_id': metrics.task_id,
            'phase': metrics.phase,
            'duration_seconds': metrics.duration_seconds,
            'refinement_rounds': metrics.refinement_rounds,
            'debug_success_rate': metrics.calculate_debug_success_rate(),
            'constitutional_compliance_rate': metrics.calculate_constitutional_compliance_rate(),
            'completed_without_intervention': metrics.completed_without_intervention,
            'escalated_to_human': metrics.escalated_to_human
        }

        logger.info(f"STRUCTURED_METRICS: {json.dumps(log_data)}")
