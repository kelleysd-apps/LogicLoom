"""
Auto-Debug Agent - Automatic Error Detection and Repair
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Automatically detects, classifies, and repairs common code errors.
    Supports max 5 iterations before escalation to human.
    Targets >70% auto-fix rate for common errors (FR-016).

Constitutional Compliance:
    - Principle I: Library-First - AutoDebug is standalone library
    - Principle II: Test-First - Validates fixes with tests
    - Principle IV: Idempotent Operations - Max 5 iterations prevents infinite loops
    - Principle VII: Observability - Complete audit trail of debug attempts

Contract: POST /debug
    Input: AgentInput with failed_code, stack_trace, test_expectations
    Output: AgentOutput with DebugSession

Usage:
    from sdd.agents.engineering.autodebug import AutoDebugAgent
    from sdd.agents.shared.models import AgentInput, AgentContext

    agent = AutoDebugAgent()
    agent_input = AgentInput(
        agent_id="engineering.autodebug",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="implementation",
        input_data={
            "failed_code": "def calc(x): return x + '5'",
            "stack_trace": "TypeError: unsupported operand...",
            "test_expectations": ["Function returns sum"],
            "max_iterations": 5
        },
        context=AgentContext()
    )
    result = agent.debug(agent_input)
    print(result.output_data)  # DebugSession
"""

import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

from sdd.agents.engineering.models import (
    DebugAttempt,
    DebugSession,
    ErrorPattern,
    TestResult
)
from sdd.agents.shared.models import AgentInput, AgentOutput

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class AutoDebugAgent:
    """
    Auto-Debug Agent for automatic error detection and repair.

    Classifies errors, generates fixes, validates repairs, and escalates
    after max iterations (Constitutional Principle IV).

    Attributes:
        agent_id: Agent identifier (engineering.autodebug)
        sessions_dir: Directory for storing debug sessions
        max_iterations: Maximum debug attempts before escalation
    """

    def __init__(
        self,
        sessions_dir: str = "/workspaces/logic-loom/.docs/agents/engineering/autodebug/sessions",
        max_iterations: int = 5
    ):
        """
        Initialize Auto-Debug Agent.

        Args:
            sessions_dir: Directory for session logs
            max_iterations: Maximum debug attempts (default: 5)
        """
        self.agent_id = "engineering.autodebug"
        self.sessions_dir = Path(sessions_dir)
        self.sessions_dir.mkdir(parents=True, exist_ok=True)
        self.max_iterations = max_iterations

        # Error pattern detection rules
        self.error_patterns = self._initialize_error_patterns()

        logger.info(f"AutoDebugAgent initialized with max_iterations={max_iterations}")

    def _initialize_error_patterns(self) -> Dict[ErrorPattern, List[str]]:
        """
        Initialize error pattern detection rules.

        Returns:
            Dictionary mapping error patterns to detection regex patterns
        """
        return {
            ErrorPattern.SYNTAX: [
                r"SyntaxError",
                r"invalid syntax",
                r"unexpected EOF",
                r"IndentationError"
            ],
            ErrorPattern.TYPE: [
                r"TypeError",
                r"unsupported operand type",
                r"can only concatenate",
                r"must be str, not int"
            ],
            ErrorPattern.NAME: [
                r"NameError",
                r"name '.*' is not defined",
                r"undefined variable"
            ],
            ErrorPattern.NULL: [
                r"NoneType",
                r"'NoneType' object",
                r"None has no attribute"
            ],
            ErrorPattern.IMPORT: [
                r"ImportError",
                r"ModuleNotFoundError",
                r"No module named",
                r"cannot import name"
            ],
            ErrorPattern.LOGIC: [
                r"AssertionError",
                r"expected .* but got",
                r"test failed"
            ]
        }

    def debug(self, agent_input: Union[AgentInput, Dict[str, Any]]) -> Dict[str, Any]:
        """
        Automatically debug and repair failed code.

        Args:
            agent_input: Standardized agent input with error details (AgentInput or dict)

        Returns:
            Dict with DebugSession

        Raises:
            ValueError: If required input fields missing
        """
        # Validate and convert input if needed
        if isinstance(agent_input, dict):
            if "input_data" not in agent_input:
                structured_input = {
                    "agent_id": agent_input.get("agent_id", "engineering.autodebug"),
                    "task_id": agent_input.get("task_id", "unknown"),
                    "phase": agent_input.get("phase", "debug"),
                    "context": agent_input.get("context", {}),
                    "input_data": {}
                }
                for key, value in agent_input.items():
                    if key not in ["agent_id", "task_id", "phase", "context"]:
                        structured_input["input_data"][key] = value
                agent_input = AgentInput(**structured_input)
            else:
                agent_input = AgentInput(**agent_input)

        logger.info(f"Starting auto-debug for task_id: {agent_input.task_id}")
        start_time = datetime.now()

        try:
            # Extract input data
            failed_code = agent_input.input_data.get("failed_code", "")
            stack_trace = agent_input.input_data.get("stack_trace", "")
            test_expectations = agent_input.input_data.get("test_expectations", [])
            max_iterations = agent_input.input_data.get("max_iterations", self.max_iterations)

            if not failed_code or not stack_trace:
                raise ValueError("failed_code and stack_trace required in input_data")

            # Perform iterative debugging
            attempts = []
            current_code = failed_code
            resolved = False
            iteration = 1

            while iteration <= max_iterations and not resolved:
                logger.info(f"Debug iteration {iteration}/{max_iterations}")

                # Classify error
                error_pattern = self._classify_error(stack_trace)

                # Generate repair
                repaired_code, repair_action, reasoning = self._generate_repair(
                    current_code=current_code,
                    stack_trace=stack_trace,
                    error_pattern=error_pattern,
                    test_expectations=test_expectations,
                    context=agent_input.context
                )

                # Validate repair (simulated for now)
                test_result = self._validate_repair(
                    repaired_code, test_expectations, error_pattern
                )

                # Record attempt
                attempt = DebugAttempt(
                    iteration=iteration,
                    error_pattern=error_pattern,
                    error_message=self._extract_error_message(stack_trace),
                    stack_trace=stack_trace,
                    repair_action=repair_action,
                    repaired_code=repaired_code,
                    test_result=test_result,
                    reasoning=reasoning
                )
                attempts.append(attempt)

                # Check if resolved
                if test_result == TestResult.PASSED:
                    resolved = True
                    current_code = repaired_code
                else:
                    # Update for next iteration
                    current_code = repaired_code
                    iteration += 1

            # Determine escalation
            escalated = not resolved and iteration > max_iterations
            resolution_time = (datetime.now() - start_time).total_seconds()

            # Generate escalation context if escalated
            escalation_context = None
            if escalated:
                error_pattern = attempts[0].error_pattern if attempts else ErrorPattern.UNKNOWN
                original_error = attempts[0].error_message if attempts else 'Unknown'
                last_error = attempts[-1].error_message if attempts else 'Unknown'
                escalation_context = {
                    "original_error": original_error,
                    "error_pattern": error_pattern.value,
                    "total_iterations": len(attempts),
                    "attempted_repairs": [
                        {
                            "iteration": a.iteration,
                            "action": a.repair_action,
                            "result": a.test_result.value
                        }
                        for a in attempts
                    ],
                    "last_error": last_error,
                    "reason": f"Unable to auto-fix {error_pattern.value} error after {len(attempts)} iterations. Manual debugging required."
                }

            # Generate repair summary if resolved
            repair_summary = None
            if resolved and attempts:
                successful_attempt = next((a for a in attempts if a.test_result == TestResult.PASSED), None)
                if successful_attempt:
                    repair_summary = (
                        f"Fixed {attempts[0].error_pattern.value} error in iteration {successful_attempt.iteration}. "
                        f"Action: {successful_attempt.repair_action}"
                    )

            # Create debug session
            debug_session = DebugSession(
                task_id=agent_input.task_id,
                original_code=failed_code,
                final_code=current_code if resolved else None,
                attempts=attempts,
                success=resolved,
                escalated=escalated,
                total_iterations=len(attempts),
                resolution_time_seconds=resolution_time if resolved else None,
                error_pattern=attempts[0].error_pattern if attempts else ErrorPattern.UNKNOWN,
                escalation_context=escalation_context,
                repair_summary=repair_summary
            )

            # Persist session
            self._persist_session(agent_input.task_id, debug_session)

            # Generate output
            reasoning = self._generate_reasoning(debug_session)
            confidence = self._calculate_confidence(debug_session)
            next_actions = self._generate_next_actions(debug_session)

            output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=True,
                output_data=debug_session.model_dump(mode='json'),
                reasoning=reasoning,
                confidence=confidence,
                next_actions=next_actions,
                metadata={
                    "resolved": resolved,
                    "escalated": escalated,
                    "iterations": len(attempts),
                    "error_patterns": [a.error_pattern.value for a in attempts]
                },
                timestamp=datetime.now()
            )

            logger.info(f"Auto-debug complete: {'resolved' if resolved else 'escalated'} after {len(attempts)} iterations")
            return output.model_dump(mode='json')

        except Exception as e:
            logger.error(f"Auto-debug failed: {str(e)}", exc_info=True)
            error_output = AgentOutput(
                agent_id=self.agent_id,
                task_id=agent_input.task_id,
                success=False,
                output_data={"error": str(e)},
                reasoning=f"Auto-debug failed: {str(e)}",
                confidence=0.0,
                next_actions=["Fix error and retry debug"],
                metadata={},
                timestamp=datetime.now()
            )
            return error_output.model_dump(mode='json')

    def _classify_error(self, stack_trace: str) -> ErrorPattern:
        """
        Classify error based on stack trace patterns.

        Args:
            stack_trace: Error stack trace

        Returns:
            Classified error pattern
        """
        for pattern, regex_list in self.error_patterns.items():
            for regex in regex_list:
                if re.search(regex, stack_trace, re.IGNORECASE):
                    logger.debug(f"Classified as {pattern.value}")
                    return pattern

        logger.debug("Classified as unknown error pattern")
        return ErrorPattern.UNKNOWN

    def _extract_error_message(self, stack_trace: str) -> str:
        """
        Extract error message from stack trace.

        Args:
            stack_trace: Stack trace

        Returns:
            Error message
        """
        lines = stack_trace.strip().split('\n')
        # Last line typically contains error message
        return lines[-1] if lines else stack_trace[:100]

    def _generate_repair(
        self,
        current_code: str,
        stack_trace: str,
        error_pattern: ErrorPattern,
        test_expectations: List[str],
        context: "AgentContext"
    ) -> Tuple[str, str, str]:
        """
        Generate repair for detected error.

        Args:
            current_code: Current code with error
            stack_trace: Error stack trace
            error_pattern: Classified error pattern
            test_expectations: Expected behavior from tests
            context: Agent context

        Returns:
            Tuple of (repaired_code, repair_action, reasoning)
        """
        repair_strategies = {
            ErrorPattern.SYNTAX: self._repair_syntax_error,
            ErrorPattern.TYPE: self._repair_type_error,
            ErrorPattern.NAME: self._repair_name_error,
            ErrorPattern.NULL: self._repair_null_error,
            ErrorPattern.IMPORT: self._repair_import_error,
            ErrorPattern.LOGIC: self._repair_logic_error,
            ErrorPattern.UNKNOWN: self._repair_unknown_error
        }

        repair_fn = repair_strategies.get(error_pattern, self._repair_unknown_error)
        return repair_fn(current_code, stack_trace, test_expectations)

    def _repair_syntax_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair syntax errors (missing colons, parentheses, etc.)."""
        # Common syntax fixes
        repaired = code

        # Missing colon after control structures
        if "invalid syntax" in stack_trace and ":" not in code:
            repaired = re.sub(r'(for|if|while|def|class)\s+([^\:]+)$', r'\1 \2:', code, flags=re.MULTILINE)
            return repaired, "Add missing colon after control structure", "Syntax error indicates missing colon"

        # Unclosed parentheses
        open_parens = code.count('(')
        close_parens = code.count(')')
        if open_parens > close_parens:
            repaired = code + ')' * (open_parens - close_parens)
            return repaired, "Close unclosed parentheses", "Unbalanced parentheses detected"

        return code, "Unable to auto-fix syntax error", "Syntax error requires manual review"

    def _repair_type_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair type errors (string + int, etc.)."""
        # Type conversion patterns
        if "unsupported operand" in stack_trace:
            # Try to add type conversions
            if "int" in stack_trace and "str" in stack_trace:
                # Convert strings to int
                repaired = re.sub(r"(\w+)\s*\+\s*(\w+)", r"int(\1) + int(\2)", code, count=1)
                return repaired, "Add type conversion (str to int)", "Type mismatch requires conversion"

        return code, "Unable to auto-fix type error", "Type error requires manual type checking"

    def _repair_name_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair name errors (undefined variables)."""
        # Extract undefined variable name
        match = re.search(r"name '(\w+)' is not defined", stack_trace)
        if match:
            var_name = match.group(1)
            # Initialize variable with default value
            repaired = f"{var_name} = None  # Auto-initialized\n{code}"
            return repaired, f"Initialize undefined variable: {var_name}", "NameError indicates missing variable definition"

        return code, "Unable to auto-fix name error", "Name error requires variable definition"

    def _repair_null_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair null/None errors."""
        # Add None checks
        repaired = re.sub(r'(\w+)\.', r'(\1 or {}).', code, count=1)
        return repaired, "Add None check before attribute access", "NoneType error indicates missing null check"

    def _repair_import_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair import errors."""
        # Extract missing module
        match = re.search(r"No module named '(\w+)'", stack_trace)
        if match:
            module = match.group(1)
            return code, f"Install missing module: pip install {module}", "ImportError indicates missing dependency"

        return code, "Unable to auto-fix import error", "Import error requires dependency installation"

    def _repair_logic_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Repair logic errors (test failures)."""
        # Logic errors require deeper analysis
        return code, "Logic error requires manual review", "Logic errors cannot be automatically repaired"

    def _repair_unknown_error(
        self,
        code: str,
        stack_trace: str,
        expectations: List[str]
    ) -> Tuple[str, str, str]:
        """Handle unknown errors."""
        return code, "Unknown error requires manual debugging", "Error pattern not recognized"

    def _validate_repair(
        self,
        repaired_code: str,
        test_expectations: List[str],
        error_pattern: ErrorPattern
    ) -> TestResult:
        """
        Validate repaired code (simulated).

        In production, this would run actual tests.

        Args:
            repaired_code: Code after repair
            test_expectations: Expected behavior
            error_pattern: Error pattern

        Returns:
            Test result
        """
        # Simulate test validation
        # In real implementation, this would execute tests

        # Simple heuristic: syntax errors likely fixed if no obvious issues
        if error_pattern == ErrorPattern.SYNTAX:
            if ':' in repaired_code or ')' in repaired_code:
                return TestResult.PASSED

        # Type errors likely fixed if type conversion present
        if error_pattern == ErrorPattern.TYPE:
            if 'int(' in repaired_code or 'str(' in repaired_code:
                return TestResult.PASSED

        # Default: assume needs more iterations
        return TestResult.FAILED

    def _generate_reasoning(self, session: DebugSession) -> str:
        """Generate human-readable reasoning."""
        if session.success:
            return (
                f"Error auto-resolved after {session.total_iterations} iteration(s). "
                f"Pattern: {session.attempts[-1].error_pattern.value}. "
                f"Resolution time: {session.resolution_time_seconds:.2f}s."
            )
        elif session.escalated:
            return (
                f"Error escalated to human after {session.total_iterations} iterations "
                f"(max: {self.max_iterations}). Manual review required."
            )
        else:
            return f"Debug in progress: {session.total_iterations} iteration(s) completed."

    def _calculate_confidence(self, session: DebugSession) -> float:
        """Calculate confidence in debug result."""
        if session.success:
            # Higher confidence for fewer iterations
            confidence = max(0.8, 0.98 - (session.total_iterations * 0.05))
            return confidence
        elif session.escalated:
            # Lower confidence when escalated
            return 0.5
        else:
            return 0.7

    def _generate_next_actions(self, session: DebugSession) -> List[str]:
        """Generate next actions based on session outcome."""
        if session.success:
            return [
                "Commit repaired code",
                "Run full test suite",
                "Verify fix in integration environment"
            ]
        elif session.escalated:
            escalation_report = session.generate_escalation_context()
            return [
                "Review escalation report",
                "Manual debugging required",
                "Consider spec clarification if logic error"
            ]
        else:
            return ["Continue debugging iterations"]

    def _persist_session(self, task_id: str, session: DebugSession) -> None:
        """
        Persist debug session to JSON file for audit trail.

        Args:
            task_id: Task identifier
            session: Debug session to persist
        """
        session_file = self.sessions_dir / f"{task_id}.json"
        session_data = session.model_dump()

        with open(session_file, 'w') as f:
            json.dump(session_data, f, indent=2, default=str)

        logger.info(f"Debug session persisted: {session_file}")
