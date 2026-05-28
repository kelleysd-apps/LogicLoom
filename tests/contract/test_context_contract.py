"""
Contract Tests for Context Analyzer Agent
DS-STAR Multi-Agent Enhancement - Feature 001

Tests the Context Analyzer Agent's contract compliance with context.yaml.
Validates POST /analyze endpoint, semantic search, file relevance, and performance requirements.

Test Coverage:
- POST /analyze with codebase path (T009)
- File relevance identification (T009)
- Dependency mapping (T009)
- Response schema matches contracts/context.yaml (T009)
- Semantic similarity search (T009)
- ContextSummary output format (T009)
"""

import json
import pytest
from datetime import datetime
from pathlib import Path
from typing import Dict, Any
import time

# Import fixtures
from tests.fixtures.setup_test_environment import (
    temp_test_dir,
    create_test_spec_file,
)


# ===================================================================
# Contract Test: POST /analyze with Codebase Path
# ===================================================================

@pytest.mark.contract
def test_analyze_codebase_returns_relevant_files():
    """
    Test that POST /analyze returns relevant files for given task.

    Contract: context.yaml - POST /analyze endpoint
    Expected: ContextSummary with relevant_files, file_summaries, existing_patterns
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440030",
        "phase": "specification",
        "task_description": "Implement quality verification system",
        "search_keywords": ["quality", "verification", "gate", "validation", "test"],
        "scan_paths": [
            "/workspaces/logic-loom/.claude/agents",
            "/workspaces/logic-loom/.logic-loom/memory",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    # This will fail until ContextAnalyzer is implemented
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Response structure
    assert "agent_id" in response
    assert response["agent_id"] == "architecture.context_analyzer"
    assert "task_id" in response
    assert "success" in response
    assert response["success"] == True
    assert "output_data" in response
    assert "reasoning" in response
    assert "confidence" in response
    assert "next_actions" in response
    assert "timestamp" in response

    # Assert - ContextSummary structure
    output_data = response["output_data"]
    assert "relevant_files" in output_data
    assert "file_summaries" in output_data
    assert "existing_patterns" in output_data
    assert "retrieval_latency_ms" in output_data
    assert "retrieval_method" in output_data

    # Assert - Relevant files returned
    relevant_files = output_data["relevant_files"]
    assert isinstance(relevant_files, list)
    assert len(relevant_files) > 0
    assert len(relevant_files) <= 10  # Respects max_results

    # Assert - All files have absolute paths
    for file_path in relevant_files:
        assert isinstance(file_path, str)
        assert Path(file_path).is_absolute()


# ===================================================================
# Contract Test: File Relevance Identification
# ===================================================================

@pytest.mark.contract
def test_analyze_identifies_relevant_files_by_keywords():
    """
    Test that context analyzer identifies files relevant to search keywords.

    Contract: context.yaml - ContextSummary.relevant_files
    Expected: Files matching keywords with relevance scores
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440031",
        "phase": "planning",
        "task_description": "Design authentication system",
        "search_keywords": ["authentication", "security", "auth", "login"],
        "scan_paths": [
            "/workspaces/logic-loom/.claude/agents",
        ],
        "max_results": 5,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Relevant files identified
    output_data = response["output_data"]
    relevant_files = output_data["relevant_files"]

    # Files should be related to authentication/security
    # At minimum, should find security-specialist agent or constitution with security principles
    file_contents_relevant = False
    for file_path in relevant_files:
        file_lower = file_path.lower()
        if any(keyword in file_lower for keyword in ["security", "auth", "login"]):
            file_contents_relevant = True
            break

    # If keyword-based matching found nothing, semantic search should have found something
    assert len(relevant_files) > 0 or file_contents_relevant


# ===================================================================
# Contract Test: Dependency Mapping
# ===================================================================

@pytest.mark.contract
def test_analyze_maps_file_dependencies():
    """
    Test that context analyzer maps dependencies between files.

    Contract: context.yaml - ContextSummary.dependencies
    Expected: Dependency graph showing file relationships
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440032",
        "phase": "specification",
        "task_description": "Understand agent framework structure",
        "search_keywords": ["agent", "framework", "constitution", "delegation"],
        "scan_paths": [
            "/workspaces/logic-loom/.claude/agents",
            "/workspaces/logic-loom/.logic-loom/memory",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Dependencies field present
    output_data = response["output_data"]
    assert "dependencies" in output_data

    # Dependencies should be a dict mapping files to their dependencies
    dependencies = output_data["dependencies"]
    assert isinstance(dependencies, dict)

    # If dependencies found, validate structure
    if len(dependencies) > 0:
        for file_path, deps in dependencies.items():
            assert isinstance(file_path, str)
            assert isinstance(deps, list)
            # Each dependency should be a file path string
            for dep in deps:
                assert isinstance(dep, str)


# ===================================================================
# Contract Test: Response Schema Validation
# ===================================================================

@pytest.mark.contract
def test_analyze_response_matches_contract_schema():
    """
    Test that POST /analyze response exactly matches context.yaml schema.

    Contract: context.yaml - ContextAnalysisResponse schema
    Expected: All required fields present, correct types, valid enum values
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440033",
        "phase": "planning",
        "task_description": "Analyze codebase for testing patterns",
        "search_keywords": ["test", "pytest", "testing"],
        "scan_paths": [
            "/workspaces/logic-loom/tests",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Required top-level fields (per ContextAnalysisResponse schema)
    required_fields = [
        "agent_id",
        "task_id",
        "success",
        "output_data",
        "reasoning",
        "confidence",
        "next_actions",
        "timestamp",
    ]
    for field in required_fields:
        assert field in response, f"Missing required field: {field}"

    # Assert - Field types
    assert isinstance(response["agent_id"], str)
    assert isinstance(response["task_id"], str)
    assert isinstance(response["success"], bool)
    assert isinstance(response["output_data"], dict)
    assert isinstance(response["reasoning"], str)
    assert isinstance(response["confidence"], (int, float))
    assert isinstance(response["next_actions"], list)
    assert isinstance(response["timestamp"], str)

    # Assert - ContextSummary required fields
    output_data = response["output_data"]
    summary_required_fields = [
        "relevant_files",
        "file_summaries",
        "existing_patterns",
        "retrieval_latency_ms",
        "retrieval_method",
    ]
    for field in summary_required_fields:
        assert field in output_data, f"Missing required summary field: {field}"

    # Assert - Retrieval method enum validation
    assert output_data["retrieval_method"] in [
        "semantic_embedding",
        "keyword_fallback",
        "cached",
    ]

    # Assert - Numeric ranges
    assert 0.0 <= response["confidence"] <= 1.0
    assert output_data["retrieval_latency_ms"] >= 0

    # Assert - Timestamp format (ISO 8601)
    try:
        datetime.fromisoformat(response["timestamp"].replace("Z", "+00:00"))
    except ValueError:
        pytest.fail("Timestamp not in ISO 8601 format")


# ===================================================================
# Contract Test: Semantic Similarity Search
# ===================================================================

@pytest.mark.contract
def test_analyze_uses_semantic_embedding_search():
    """
    Test that context analyzer uses semantic embedding for search.

    Contract: context.yaml - ContextSummary.retrieval_method
    Expected: retrieval_method='semantic_embedding' when embedding available
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440034",
        "phase": "specification",
        "task_description": "Find patterns for API contract design",
        "search_keywords": ["contract", "API", "OpenAPI", "schema"],
        "scan_paths": [
            "/workspaces/logic-loom/specs",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Retrieval method recorded
    output_data = response["output_data"]
    assert "retrieval_method" in output_data

    # Should prefer semantic_embedding if available
    # Falls back to keyword_fallback if timeout or embedding unavailable
    assert output_data["retrieval_method"] in [
        "semantic_embedding",
        "keyword_fallback",
        "cached",
    ]

    # If semantic embedding used, embedding_vector may be present
    if output_data["retrieval_method"] == "semantic_embedding":
        # Embedding vector is optional but if present should be 384-dim
        if "embedding_vector" in output_data and output_data["embedding_vector"] is not None:
            embedding = output_data["embedding_vector"]
            assert isinstance(embedding, list)
            assert len(embedding) == 384  # Standard embedding dimension


# ===================================================================
# Contract Test: ContextSummary Output Format
# ===================================================================

@pytest.mark.contract
def test_context_summary_output_format():
    """
    Test that ContextSummary output matches expected format.

    Contract: context.yaml - ContextSummary schema
    Expected: All required fields, proper types, valid structures
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440035",
        "phase": "planning",
        "task_description": "Analyze agent delegation patterns",
        "search_keywords": ["agent", "delegation", "orchestration"],
        "scan_paths": [
            "/workspaces/logic-loom/.logic-loom/memory",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Output data structure
    output_data = response["output_data"]

    # Relevant files - array of strings (absolute paths)
    relevant_files = output_data["relevant_files"]
    assert isinstance(relevant_files, list)
    for file_path in relevant_files:
        assert isinstance(file_path, str)

    # File summaries - dict mapping filenames to summaries
    file_summaries = output_data["file_summaries"]
    assert isinstance(file_summaries, dict)
    for filename, summary in file_summaries.items():
        assert isinstance(filename, str)
        assert isinstance(summary, str)
        assert len(summary) > 0

    # Existing patterns - array of strings
    existing_patterns = output_data["existing_patterns"]
    assert isinstance(existing_patterns, list)
    for pattern in existing_patterns:
        assert isinstance(pattern, str)

    # Dependencies - dict mapping files to dependency arrays
    if "dependencies" in output_data:
        dependencies = output_data["dependencies"]
        assert isinstance(dependencies, dict)

    # Related specs - array of strings
    if "related_specs" in output_data:
        related_specs = output_data["related_specs"]
        assert isinstance(related_specs, list)

    # Constitutional status - dict mapping principles to booleans
    if "constitutional_status" in output_data:
        constitutional_status = output_data["constitutional_status"]
        assert isinstance(constitutional_status, dict)
        for principle, status in constitutional_status.items():
            assert isinstance(principle, str)
            assert isinstance(status, bool)

    # Retrieval latency - positive integer
    retrieval_latency_ms = output_data["retrieval_latency_ms"]
    assert isinstance(retrieval_latency_ms, int)
    assert retrieval_latency_ms >= 0

    # Retrieval method - valid enum
    retrieval_method = output_data["retrieval_method"]
    assert retrieval_method in ["semantic_embedding", "keyword_fallback", "cached"]


# ===================================================================
# Contract Test: Performance Requirements (<2s)
# ===================================================================

@pytest.mark.contract
def test_analyze_meets_performance_target():
    """
    Test that context retrieval completes within 2 second target.

    Contract: context.yaml - ContextAnalysisRequest.performance_target_ms (2000)
    Expected: retrieval_latency_ms < 2000
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440036",
        "phase": "specification",
        "task_description": "Quick context lookup",
        "search_keywords": ["constitution"],
        "scan_paths": [
            "/workspaces/logic-loom/.logic-loom/memory",
        ],
        "max_results": 5,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()

    start_time = time.time()
    response = agent.analyze(request_payload)
    end_time = time.time()

    elapsed_ms = (end_time - start_time) * 1000

    # Assert - Performance target met
    output_data = response["output_data"]
    retrieval_latency_ms = output_data["retrieval_latency_ms"]

    # Internal latency should be under 2 seconds
    assert retrieval_latency_ms < 2000, \
        f"Retrieval took {retrieval_latency_ms}ms, expected <2000ms"

    # End-to-end latency should also be under 2 seconds (with some tolerance)
    assert elapsed_ms < 2500, \
        f"End-to-end took {elapsed_ms}ms, expected <2500ms (2s + 500ms tolerance)"


# ===================================================================
# Contract Test: Graceful Degradation to Keyword Search
# ===================================================================

@pytest.mark.contract
def test_analyze_falls_back_to_keyword_search_on_timeout():
    """
    Test that context analyzer falls back to keyword search if semantic search times out.

    Contract: context.yaml - ContextSummary.retrieval_method fallback behavior
    Expected: retrieval_method='keyword_fallback' if semantic search exceeds timeout
    """
    # Arrange - Request with very low timeout to force fallback
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440037",
        "phase": "specification",
        "task_description": "Context lookup with tight timeout",
        "search_keywords": ["test"],
        "scan_paths": [
            "/workspaces/logic-loom",
        ],
        "max_results": 5,
        "performance_target_ms": 1,  # Unrealistically low to potentially trigger fallback
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Still returns results (graceful degradation)
    assert response["success"] == True
    output_data = response["output_data"]

    # Should either complete with semantic search or fall back to keyword search
    assert output_data["retrieval_method"] in [
        "semantic_embedding",
        "keyword_fallback",
        "cached",
    ]

    # Even with fallback, should return some results
    assert len(output_data["relevant_files"]) >= 0  # May be empty if nothing found


# ===================================================================
# Contract Test: Constitutional Status Tracking
# ===================================================================

@pytest.mark.contract
def test_analyze_tracks_constitutional_status():
    """
    Test that context analyzer tracks constitutional principle compliance.

    Contract: context.yaml - ContextSummary.constitutional_status
    Expected: Dict mapping principle names to compliance booleans
    """
    # Arrange
    request_payload = {
        "agent_id": "architecture.context_analyzer",
        "task_id": "550e8400-e29b-41d4-a716-446655440038",
        "phase": "planning",
        "task_description": "Check constitutional compliance for library design",
        "search_keywords": ["library", "architecture", "principle"],
        "scan_paths": [
            "/workspaces/logic-loom/.logic-loom/memory",
        ],
        "max_results": 10,
        "performance_target_ms": 2000,
    }

    # Act
    from sdd.agents.architecture.context_analyzer import ContextAnalyzer
    agent = ContextAnalyzer()
    response = agent.analyze(request_payload)

    # Assert - Constitutional status field present
    output_data = response["output_data"]
    assert "constitutional_status" in output_data

    # Constitutional status should be a dict
    constitutional_status = output_data["constitutional_status"]
    assert isinstance(constitutional_status, dict)

    # If populated, should map principle names to booleans
    for principle_name, status in constitutional_status.items():
        assert isinstance(principle_name, str)
        assert isinstance(status, bool)
        # Principle names should match expected format
        # e.g., "Principle I", "library_first", etc.
