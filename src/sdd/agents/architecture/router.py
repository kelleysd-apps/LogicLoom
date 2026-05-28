"""
Router Agent - Intelligent Task Routing and Orchestration
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Analyzes task complexity and determines optimal agent selection,
    execution strategy (sequential/parallel/DAG), and refinement approach.
    Uses agent-collaboration-triggers.md for domain keyword matching.

Constitutional Compliance:
    - Principle I: Library-First - Router is standalone library
    - Principle X: Agent Delegation Protocol - Implements delegation logic
    - Principle III: Contract-First - Follows router.yaml contract
    - Principle VII: Observability - Structured logging and decision persistence

Contract: POST /route
    Input: AgentInput with task_description, domains_detected, current_state
    Output: AgentOutput with RoutingDecision

Usage:
    from sdd.agents.architecture.router import RouterAgent
    from sdd.agents.shared.models import AgentInput, AgentContext

    agent = RouterAgent()
    agent_input = AgentInput(
        agent_id="architecture.router",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="implementation",
        input_data={
            "task_description": "Implement user authentication",
            "domains_detected": ["frontend", "backend", "security"],
            "current_state": {"completed_agents": [], "failed_agents": []}
        },
        context=AgentContext()
    )
    result = agent.route(agent_input)
    print(result.output_data)  # RoutingDecision
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union

from sdd.agents.architecture.models import (
    ExecutionStrategy,
    RefinementStrategy,
    RoutingDecision
)
from sdd.agents.shared.models import AgentInput, AgentOutput

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RouterAgent:
    """
    Router Agent for intelligent task routing and orchestration.

    Analyzes tasks to determine which agents to invoke, execution order,
    and refinement strategy on failures.

    Attributes:
        agent_id: Agent identifier (architecture.router)
        triggers_path: Path to agent-collaboration-triggers.md
        decisions_dir: Directory for storing routing decisions
        domain_agent_map: Mapping of domains to specialized agents
    """

    def __init__(
        self,
        triggers_path: str = "/workspaces/logic-loom/.logic-loom/memory/agent-collaboration-triggers.md",
        decisions_dir: str = "/workspaces/logic-loom/.docs/agents/architecture/router/decisions"
    ):
        """
        Initialize Router Agent.

        Args:
            triggers_path: Path to agent-collaboration-triggers.md
            decisions_dir: Directory for decision logs
        """
        self.agent_id = "architecture.router"
        self.triggers_path = Path(triggers_path)
        self.decisions_dir = Path(decisions_dir)
        self.decisions_dir.mkdir(parents=True, exist_ok=True)

        # Load domain-to-agent mappings
        self.domain_agent_map = self._load_domain_mappings()

        logger.info(f"RouterAgent initialized with {len(self.domain_agent_map)} domain mappings")

    def _load_domain_mappings(self) -> Dict[str, str]:
        """
        Load domain-to-agent mappings from agent-collaboration-triggers.md.

        Returns:
            Dictionary mapping domains to agent IDs

        Example:
            {
                "frontend": "engineering.frontend_specialist",
                "backend": "architecture.backend_architect",
                "database": "data.database_specialist",
                ...
            }
        """
        # Default mappings (from agent-collaboration-triggers.md)
        mappings = {
            "frontend": "engineering.frontend_specialist",
            "backend": "architecture.backend_architect",
            "database": "data.database_specialist",
            "testing": "quality.testing_specialist",
            "security": "quality.security_specialist",
            "performance": "operations.performance_engineer",
            "devops": "operations.devops_engineer",
            "specification": "product.specification_agent",
            "planning": "product.planning_agent",
            "tasks": "product.tasks_agent",
            "orchestration": "product.task_orchestrator"
        }

        return mappings

    def route(self, agent_input: Union[AgentInput, Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze task and determine routing strategy.

        Args:
            agent_input: Standardized agent input with task details (AgentInput or dict)

        Returns:
            Dict with RoutingDecision

        Raises:
            ValueError: If required input fields missing
        """
        # Validate and convert input if needed
        if isinstance(agent_input, dict):
            # Restructure flat dict to AgentInput format if needed
            if "input_data" not in agent_input:
                structured_input = {
                    "agent_id": agent_input.get("agent_id", "architecture.router"),
                    "task_id": agent_input.get("task_id", "unknown"),
                    "phase": agent_input.get("phase", "routing"),
                    "context": agent_input.get("context", {}),
                    "input_data": {}
                }
                for key, value in agent_input.items():
                    if key not in ["agent_id", "task_id", "phase", "context"]:
                        structured_input["input_data"][key] = value
                agent_input = AgentInput(**structured_input)
            else:
                agent_input = AgentInput(**agent_input)

        logger.info(f"Starting routing analysis for task_id: {agent_input.task_id}")

        try:
            # Extract input data
            task_description = agent_input.input_data.get("task_description", "")
            domains_detected = agent_input.input_data.get("domains_detected", [])
            current_state = agent_input.input_data.get("current_state", {})

            if not task_description:
                raise ValueError("task_description required in input_data")

            # Analyze task complexity
            complexity_score = self._analyze_complexity(task_description, domains_detected)

            # Select agents based on domains
            selected_agents = self._select_agents(domains_detected, current_state)

            # Determine execution strategy
            execution_strategy = self._determine_execution_strategy(
                selected_agents, task_description, complexity_score
            )

            # Build dependency graph if DAG strategy
            dependency_graph = None
            if execution_strategy == ExecutionStrategy.DAG:
                dependency_graph = self._build_dependency_graph(selected_agents, domains_detected)

            # Determine refinement strategy
            refinement_strategy = self._determine_refinement_strategy(
                current_state, complexity_score
            )

            # Calculate parallel execution opportunities
            parallel_opportunities = self._identify_parallel_opportunities(
                selected_agents, dependency_graph
            )

            # Generate reasoning
            reasoning = self._generate_reasoning(
                selected_agents, execution_strategy, domains_detected, complexity_score, current_state
            )

            # Calculate confidence
            confidence = self._calculate_confidence(complexity_score, len(domains_detected))

            # Create routing decision
            routing_decision = RoutingDecision(
                selected_agents=selected_agents,
                execution_strategy=execution_strategy,
                dependency_graph=dependency_graph,
                refinement_strategy=refinement_strategy,
                reasoning=reasoning,
                confidence=confidence,
                parallel_execution_plan=None,  # Optional, could be added later
                estimated_duration_seconds=None  # Optional, could be added later
            )

            # Persist decision
            self._persist_decision(agent_input.task_id, routing_decision)

            # Generate output
            next_actions = self._generate_next_actions(routing_decision)

            output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=True,
                output_data=routing_decision.model_dump(mode='json'),
                reasoning=reasoning,
                confidence=confidence,
                next_actions=next_actions,
                metadata={
                    "complexity_score": complexity_score,
                    "domains_count": len(domains_detected),
                    "parallel_opportunities": parallel_opportunities
                },
                timestamp=datetime.now()
            )

            logger.info(f"Routing complete: {len(selected_agents)} agents, {execution_strategy.value} strategy")
            return output.model_dump(mode='json')

        except Exception as e:
            logger.error(f"Routing failed: {str(e)}", exc_info=True)
            error_output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=False,
                output_data={"error": str(e)},
                reasoning=f"Routing failed: {str(e)}",
                confidence=0.0,
                next_actions=["Fix error and retry routing"],
                metadata={},
                timestamp=datetime.now()
            )
            return error_output.model_dump(mode='json')

    def _analyze_complexity(self, task_description: str, domains: List[str]) -> float:
        """
        Analyze task complexity.

        Args:
            task_description: Task description
            domains: Detected domains

        Returns:
            Complexity score (0.0 to 1.0, higher = more complex)
        """
        complexity = 0.0

        # Factor 1: Number of domains (more domains = more complex)
        complexity += min(0.4, len(domains) * 0.1)

        # Factor 2: Length of description (longer = more complex)
        word_count = len(task_description.split())
        complexity += min(0.3, word_count / 100 * 0.3)

        # Factor 3: Keywords indicating complexity
        complex_keywords = ["integration", "multi", "complex", "system", "architecture", "workflow"]
        complexity += sum(0.05 for kw in complex_keywords if kw in task_description.lower())

        return min(1.0, complexity)

    def _select_agents(self, domains: List[str], current_state: Dict) -> List[str]:
        """
        Select agents based on detected domains.

        Args:
            domains: Detected domains
            current_state: Current state with completed/failed agents

        Returns:
            List of agent IDs to invoke
        """
        selected = []
        completed = set(current_state.get("completed_agents", []))
        failed_agents_list = current_state.get("failed_agents", [])
        # Extract agent_id from failed agents (can be dict or string)
        failed = set(
            fa["agent_id"] if isinstance(fa, dict) else fa
            for fa in failed_agents_list
        )

        # Map domains to agents
        for domain in domains:
            agent_id = self.domain_agent_map.get(domain)
            if agent_id and agent_id not in completed:
                selected.append(agent_id)

        # Handle multi-domain scenarios (use orchestrator)
        if len(domains) >= 3 and "product.task_orchestrator" not in selected:
            selected.insert(0, "product.task_orchestrator")

        # Remove duplicates while preserving order
        seen = set()
        unique_selected = []
        for agent in selected:
            if agent not in seen:
                seen.add(agent)
                unique_selected.append(agent)

        return unique_selected

    def _determine_execution_strategy(
        self,
        selected_agents: List[str],
        task_description: str,
        complexity_score: float
    ) -> ExecutionStrategy:
        """
        Determine optimal execution strategy.

        Args:
            selected_agents: Selected agents
            task_description: Task description
            complexity_score: Complexity score

        Returns:
            Execution strategy (sequential, parallel, dag)
        """
        # Single agent = sequential
        if len(selected_agents) <= 1:
            return ExecutionStrategy.SEQUENTIAL

        # High complexity or dependencies = DAG
        if complexity_score > 0.6 or self._has_dependencies(task_description):
            return ExecutionStrategy.DAG

        # Multiple independent agents = parallel
        if len(selected_agents) >= 2 and complexity_score < 0.4:
            return ExecutionStrategy.PARALLEL

        # Default: DAG for safety
        return ExecutionStrategy.DAG

    def _has_dependencies(self, task_description: str) -> bool:
        """
        Check if task description implies dependencies.

        Args:
            task_description: Task description

        Returns:
            True if dependencies detected
        """
        dependency_keywords = [
            "after", "before", "depends on", "requires", "first", "then",
            "prerequisite", "following", "once", "when"
        ]
        return any(kw in task_description.lower() for kw in dependency_keywords)

    def _build_dependency_graph(
        self,
        selected_agents: List[str],
        domains: List[str]
    ) -> Dict[str, List[str]]:
        """
        Build dependency graph for DAG execution.

        Args:
            selected_agents: Selected agents
            domains: Detected domains

        Returns:
            Dependency graph {agent_id: [dependency_ids]}
        """
        graph = {agent: [] for agent in selected_agents}

        # Define common dependency patterns
        dependency_rules = {
            "engineering.frontend_specialist": ["architecture.backend_architect", "data.database_specialist"],
            "quality.testing_specialist": ["engineering.frontend_specialist", "architecture.backend_architect"],
            "quality.security_specialist": ["architecture.backend_architect"],
            "operations.devops_engineer": ["quality.testing_specialist"]
        }

        # Apply dependency rules
        for agent in selected_agents:
            potential_deps = dependency_rules.get(agent, [])
            # Only add dependencies if those agents are selected
            graph[agent] = [dep for dep in potential_deps if dep in selected_agents]

        return graph

    def _determine_refinement_strategy(
        self,
        current_state: Dict,
        complexity_score: float
    ) -> Optional[RefinementStrategy]:
        """
        Determine refinement strategy on failure.

        Args:
            current_state: Current state with failed agents
            complexity_score: Complexity score

        Returns:
            Refinement strategy or None
        """
        failed_agents = current_state.get("failed_agents", [])

        if not failed_agents:
            return RefinementStrategy.RETRY_WITH_FEEDBACK

        # If multiple failures, use auto-debug
        if len(failed_agents) > 1:
            return RefinementStrategy.ROUTE_TO_DEBUG

        # High complexity = add validation step
        if complexity_score > 0.7:
            return RefinementStrategy.ADD_STEP

        # Default: retry with feedback
        return RefinementStrategy.RETRY_WITH_FEEDBACK

    def _identify_parallel_opportunities(
        self,
        selected_agents: List[str],
        dependency_graph: Optional[Dict[str, List[str]]]
    ) -> List[str]:
        """
        Identify agents that can execute in parallel.

        Args:
            selected_agents: Selected agents
            dependency_graph: Dependency graph (if DAG)

        Returns:
            List of agents that can run in parallel
        """
        if not dependency_graph:
            return selected_agents  # All can run in parallel if no dependencies

        # Find agents with no dependencies
        parallel = [
            agent for agent, deps in dependency_graph.items()
            if not deps
        ]

        return parallel

    def _generate_reasoning(
        self,
        selected_agents: List[str],
        execution_strategy: ExecutionStrategy,
        domains: List[str],
        complexity_score: float,
        current_state: Dict
    ) -> str:
        """
        Generate human-readable reasoning.

        Args:
            selected_agents: Selected agents
            execution_strategy: Execution strategy
            domains: Detected domains
            complexity_score: Complexity score
            current_state: Current state with failed/completed agents

        Returns:
            Reasoning string
        """
        agent_list = ", ".join(selected_agents)
        domain_list = ", ".join(domains)

        reasoning = (
            f"Task requires {len(domains)} domains ({domain_list}). "
            f"Selected {len(selected_agents)} agents: {agent_list}. "
            f"Complexity: {complexity_score:.2f}. "
            f"Execution strategy: {execution_strategy.value}."
        )

        # Mention failed agents if any
        failed_agents = current_state.get("failed_agents", [])
        if failed_agents:
            failed_count = len(failed_agents)
            reasoning += f" Note: {failed_count} agent(s) previously failed - applying refinement strategy."

        return reasoning

    def _calculate_confidence(self, complexity_score: float, domain_count: int) -> float:
        """
        Calculate confidence in routing decision.

        Args:
            complexity_score: Task complexity
            domain_count: Number of domains

        Returns:
            Confidence score (0.0 to 1.0)
        """
        # Higher confidence for simpler, well-defined tasks
        base_confidence = 0.95

        # Reduce confidence for complex tasks
        complexity_penalty = complexity_score * 0.15

        # Reduce confidence for many domains
        domain_penalty = max(0, (domain_count - 2) * 0.05)

        confidence = max(0.7, base_confidence - complexity_penalty - domain_penalty)

        return confidence

    def _generate_next_actions(self, routing_decision: RoutingDecision) -> List[str]:
        """
        Generate next actions based on routing decision.

        Args:
            routing_decision: Routing decision

        Returns:
            List of next actions
        """
        actions = []

        if routing_decision.execution_strategy == ExecutionStrategy.SEQUENTIAL:
            actions.append(f"Invoke {routing_decision.selected_agents[0]} agent")
            if len(routing_decision.selected_agents) > 1:
                actions.append("Wait for completion before invoking next agent")
        elif routing_decision.execution_strategy == ExecutionStrategy.PARALLEL:
            actions.append(f"Invoke all {len(routing_decision.selected_agents)} agents in parallel")
        elif routing_decision.execution_strategy == ExecutionStrategy.DAG:
            batches = routing_decision.get_execution_order()
            actions.append(f"Execute {len(batches)} batches in topological order")
            for i, batch in enumerate(batches, 1):
                batch_str = ", ".join(batch)
                actions.append(f"Batch {i}: {batch_str}")

        return actions

    def _persist_decision(self, task_id: str, decision: RoutingDecision) -> None:
        """
        Persist routing decision to JSON file for audit trail.

        Args:
            task_id: Task identifier
            decision: Routing decision to persist
        """
        decision_file = self.decisions_dir / f"{task_id}.json"
        decision_data = decision.model_dump()

        with open(decision_file, 'w') as f:
            json.dump(decision_data, f, indent=2, default=str)

        logger.info(f"Routing decision persisted: {decision_file}")
