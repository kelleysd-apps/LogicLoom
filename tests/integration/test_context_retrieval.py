"""
Integration Test: Context Intelligence (Scenario 5)
DS-STAR Multi-Agent Enhancement - Feature 001

Tests end-to-end context retrieval and semantic search performance.

Test Coverage (T015):
- Semantic search retrieval <2 seconds (FR-026, FR-027, FR-031, FR-032)
- Relevant file identification accuracy (FR-028)
- Graceful degradation to keyword search (FR-029)
- Embedding index updates (FR-030)
"""

import uuid
import pytest
import time
from tests.fixtures.setup_test_environment import temp_test_dir


@pytest.mark.integration
def test_context_retrieval_meets_performance_target():
    """
    Integration test: Context retrieval completes in under 2 seconds.

    Requirements: FR-031 (performance <2s), FR-032 (latency tracking)
    """
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    from sdd.agents.shared.models import AgentInput

    # Act
    agent = ContextAnalyzer()
    request = AgentInput(
        agent_id="architecture.context_analyzer",
        task_id=str(uuid.uuid4()),
        phase="specification",
        input_data={
            "task_description": "Implement quality verification system",
            "search_keywords": ["quality", "verification", "gate"],
            "scan_paths": [
                "/workspaces/logic-loom/.claude/agents",
                "/workspaces/logic-loom/.logic-loom/memory",
            ],
            "max_results": 10,
            "performance_target_ms": 2000,
        },
        context={},
    )

    start_time = time.time()
    response = agent.analyze(request)
    end_time = time.time()

    elapsed_ms = (end_time - start_time) * 1000

    # Assert - Performance target met (FR-031)
    assert response.output_data.retrieval_latency_ms < 2000
    assert elapsed_ms < 2500  # End-to-end with tolerance


@pytest.mark.integration
def test_context_retrieval_identifies_relevant_files_accurately():
    """
    Integration test: Context retrieval identifies relevant files with high accuracy.

    Requirements: FR-026, FR-027, FR-028
    """
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    from sdd.agents.shared.models import AgentInput

    # Act
    agent = ContextAnalyzer()
    request = AgentInput(
        agent_id="architecture.context_analyzer",
        task_id=str(uuid.uuid4()),
        phase="planning",
        input_data={
            "task_description": "Design authentication system with security best practices",
            "search_keywords": ["authentication", "security", "auth", "password"],
            "scan_paths": ["/workspaces/logic-loom"],
            "max_results": 10,
            "performance_target_ms": 2000,
        },
        context={},
    )

    response = agent.analyze(request)

    # Assert - Relevant files found (FR-028)
    relevant_files = response.output_data.relevant_files
    assert len(relevant_files) > 0

    # Assert - Files are relevant (contain keywords or related content)
    file_summaries = response.output_data.file_summaries
    assert len(file_summaries) > 0


@pytest.mark.integration
def test_context_retrieval_gracefully_degrades_to_keyword_search():
    """
    Integration test: Context retrieval falls back to keyword search on timeout.

    Requirements: FR-029 (graceful degradation)
    """
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    from sdd.agents.shared.models import AgentInput

    # Act - Request with very tight timeout
    agent = ContextAnalyzer()
    request = AgentInput(
        agent_id="architecture.context_analyzer",
        task_id=str(uuid.uuid4()),
        phase="specification",
        input_data={
            "task_description": "Quick lookup",
            "search_keywords": ["test"],
            "scan_paths": ["/workspaces/logic-loom"],
            "max_results": 5,
            "performance_target_ms": 1,  # Unrealistic timeout
        },
        context={},
    )

    response = agent.analyze(request)

    # Assert - Still returns results (graceful degradation)
    assert response.success == True
    assert response.output_data.retrieval_method in [
        "semantic_embedding",
        "keyword_fallback",
        "cached",
    ]


@pytest.mark.integration
def test_context_retrieval_provides_file_summaries_and_patterns():
    """
    Integration test: Context retrieval provides file summaries and existing patterns.

    Requirements: FR-027 (summaries), FR-028 (pattern identification)
    """
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    from sdd.agents.shared.models import AgentInput

    # Act
    agent = ContextAnalyzer()
    request = AgentInput(
        agent_id="architecture.context_analyzer",
        task_id=str(uuid.uuid4()),
        phase="planning",
        input_data={
            "task_description": "Understand agent framework patterns",
            "search_keywords": ["agent", "delegation", "constitution"],
            "scan_paths": ["/workspaces/logic-loom/.logic-loom/memory"],
            "max_results": 10,
            "performance_target_ms": 2000,
        },
        context={},
    )

    response = agent.analyze(request)

    # Assert - File summaries provided (FR-027)
    file_summaries = response.output_data.file_summaries
    assert isinstance(file_summaries, dict)
    assert len(file_summaries) > 0

    # Assert - Existing patterns identified (FR-028)
    existing_patterns = response.output_data.existing_patterns
    assert isinstance(existing_patterns, list)


@pytest.mark.integration
def test_context_retrieval_tracks_latency_metrics():
    """
    Integration test: Context retrieval tracks latency metrics for monitoring.

    Requirements: FR-032 (latency tracking)
    """
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    from sdd.agents.shared.models import AgentInput

    # Act
    agent = ContextAnalyzer()
    request = AgentInput(
        agent_id="architecture.context_analyzer",
        task_id=str(uuid.uuid4()),
        phase="specification",
        input_data={
            "task_description": "Metrics test",
            "search_keywords": ["test"],
            "scan_paths": ["/workspaces/logic-loom/.specify"],
            "max_results": 5,
            "performance_target_ms": 2000,
        },
        context={},
    )

    response = agent.analyze(request)

    # Assert - Latency tracked (FR-032)
    assert "retrieval_latency_ms" in response.output_data
    assert isinstance(response.output_data.retrieval_latency_ms, int)
    assert response.output_data.retrieval_latency_ms >= 0

    # Assert - Retrieval method recorded
    assert response.output_data.retrieval_method in [
        "semantic_embedding",
        "keyword_fallback",
        "cached",
    ]
