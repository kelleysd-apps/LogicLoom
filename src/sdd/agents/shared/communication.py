"""
Agent Communication Channel - Message Passing and Context Handoff
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Provides structured communication between agents with validation.
    Implements context handoff protocol for multi-agent workflows.
    Maintains audit trail of agent invocations.

Constitutional Compliance:
    - Principle I: Library-First - AgentChannel is standalone library
    - Principle III: Contract-First - Uses Pydantic models for contracts
    - Principle VII: Observability - Complete audit trail of communications

Usage:
    from sdd.agents.shared.communication import AgentChannel
    from sdd.agents.shared.models import AgentInput, AgentContext

    channel = AgentChannel()

    # Send message to agent
    agent_input = AgentInput(
        agent_id="quality.verifier",
        task_id="550e8400-e29b-41d4-a716-446655440000",
        phase="planning",
        input_data={"artifact_path": "/path/to/plan.md"},
        context=AgentContext()
    )
    channel.send(agent_input)

    # Receive response
    output = channel.receive()
    print(f"Agent response: {output.reasoning}")

    # Hand off context to next agent
    channel.handoff(
        from_agent="quality.verifier",
        to_agent="architecture.router",
        context=updated_context
    )
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4

from pydantic import ValidationError

from sdd.agents.shared.models import AgentContext, AgentInput, AgentOutput

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ===================================================================
# Communication Models
# ===================================================================

class MessageEnvelope:
    """
    Message envelope for agent communication.

    Wraps AgentInput/AgentOutput with metadata for routing and audit.

    Attributes:
        message_id: Unique identifier for message
        timestamp: When message was created
        sender: Sender agent ID (optional)
        receiver: Receiver agent ID
        payload: AgentInput or AgentOutput
        metadata: Additional metadata
    """

    def __init__(
        self,
        receiver: str,
        payload: AgentInput | AgentOutput,
        sender: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        self.message_id = str(uuid4())
        self.timestamp = datetime.now()
        self.sender = sender
        self.receiver = receiver
        self.payload = payload
        self.metadata = metadata or {}

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            'message_id': self.message_id,
            'timestamp': self.timestamp.isoformat(),
            'sender': self.sender,
            'receiver': self.receiver,
            'payload_type': type(self.payload).__name__,
            'payload': self.payload.model_dump(),
            'metadata': self.metadata
        }


class HandoffRecord:
    """
    Record of context handoff between agents.

    Attributes:
        handoff_id: Unique identifier
        timestamp: When handoff occurred
        from_agent: Source agent ID
        to_agent: Destination agent ID
        context: AgentContext being handed off
        reason: Reason for handoff (optional)
    """

    def __init__(
        self,
        from_agent: str,
        to_agent: str,
        context: AgentContext,
        reason: Optional[str] = None
    ):
        self.handoff_id = str(uuid4())
        self.timestamp = datetime.now()
        self.from_agent = from_agent
        self.to_agent = to_agent
        self.context = context
        self.reason = reason

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            'handoff_id': self.handoff_id,
            'timestamp': self.timestamp.isoformat(),
            'from_agent': self.from_agent,
            'to_agent': self.to_agent,
            'context': self.context.model_dump(),
            'reason': self.reason
        }


# ===================================================================
# AgentChannel
# ===================================================================

class AgentChannel:
    """
    Agent Communication Channel.

    Manages message passing, context handoffs, and audit trail for agent-to-agent
    communication in multi-agent workflows.

    Attributes:
        audit_dir: Directory for communication audit trail
        message_queue: In-memory message queue (FIFO)
        invocation_chain: List of agent invocations in current workflow
        handoff_history: List of context handoffs
    """

    def __init__(
        self,
        audit_dir: str = "/workspaces/logic-loom/.docs/agents/shared/communication"
    ):
        """
        Initialize Agent Channel.

        Args:
            audit_dir: Directory for audit trail storage
        """
        self.audit_dir = Path(audit_dir)
        self.audit_dir.mkdir(parents=True, exist_ok=True)

        # Message queue
        self.message_queue: List[MessageEnvelope] = []

        # Invocation tracking
        self.invocation_chain: List[str] = []
        self.handoff_history: List[HandoffRecord] = []

        logger.info(f"AgentChannel initialized: audit_dir={self.audit_dir}")

    def send(
        self,
        agent_input: AgentInput,
        sender: Optional[str] = None,
        timeout_seconds: int = 300
    ) -> str:
        """
        Send message to agent.

        Validates message contract and adds to queue.

        Args:
            agent_input: AgentInput message to send
            sender: Sender agent ID (optional)
            timeout_seconds: Message timeout (unused currently, for future)

        Returns:
            Message ID

        Raises:
            ValidationError: If agent_input fails validation

        Example:
            >>> channel = AgentChannel()
            >>> agent_input = AgentInput(
            ...     agent_id="quality.verifier",
            ...     task_id="550e8400-e29b-41d4-a716-446655440000",
            ...     phase="planning",
            ...     input_data={},
            ...     context=AgentContext()
            ... )
            >>> message_id = channel.send(agent_input)
            >>> print(f"Message sent: {message_id}")
        """
        # Validate input (Pydantic already validates in constructor)
        try:
            # Re-validate to ensure contract compliance
            AgentInput.model_validate(agent_input.model_dump())
        except ValidationError as e:
            logger.error(f"AgentInput validation failed: {e}")
            raise

        # Create message envelope
        envelope = MessageEnvelope(
            receiver=agent_input.agent_id,
            payload=agent_input,
            sender=sender,
            metadata={'timeout_seconds': timeout_seconds}
        )

        # Add to queue
        self.message_queue.append(envelope)

        # Track invocation
        self.invocation_chain.append(agent_input.agent_id)

        # Log communication
        logger.info(
            f"Message sent: id={envelope.message_id}, "
            f"sender={sender}, receiver={agent_input.agent_id}, "
            f"task_id={agent_input.task_id}"
        )

        # Audit trail
        self._audit_message(envelope)

        return envelope.message_id

    def receive(
        self,
        agent_id: Optional[str] = None,
        timeout_seconds: int = 300
    ) -> Optional[AgentInput]:
        """
        Receive message from queue.

        Args:
            agent_id: Filter to messages for specific agent (None = any)
            timeout_seconds: Receive timeout (unused currently, for future)

        Returns:
            AgentInput if message available, None otherwise

        Example:
            >>> channel = AgentChannel()
            >>> agent_input = channel.receive(agent_id="quality.verifier")
            >>> if agent_input:
            ...     print(f"Received message for task: {agent_input.task_id}")
        """
        # Find matching message
        for i, envelope in enumerate(self.message_queue):
            if agent_id is None or envelope.receiver == agent_id:
                # Remove from queue
                self.message_queue.pop(i)

                logger.info(
                    f"Message received: id={envelope.message_id}, "
                    f"receiver={envelope.receiver}"
                )

                return envelope.payload

        return None

    def respond(
        self,
        agent_output: AgentOutput,
        receiver: Optional[str] = None
    ) -> str:
        """
        Send response from agent.

        Args:
            agent_output: AgentOutput response
            receiver: Receiver agent ID (optional)

        Returns:
            Message ID

        Raises:
            ValidationError: If agent_output fails validation

        Example:
            >>> channel = AgentChannel()
            >>> agent_output = AgentOutput(
            ...     agent_id="quality.verifier",
            ...     task_id="550e8400-e29b-41d4-a716-446655440000",
            ...     success=True,
            ...     output_data={},
            ...     reasoning="...",
            ...     confidence=0.9,
            ...     next_actions=[]
            ... )
            >>> message_id = channel.respond(agent_output)
        """
        # Validate output
        try:
            AgentOutput.model_validate(agent_output.model_dump())
        except ValidationError as e:
            logger.error(f"AgentOutput validation failed: {e}")
            raise

        # Create message envelope
        envelope = MessageEnvelope(
            receiver=receiver or "orchestrator",
            payload=agent_output,
            sender=agent_output.agent_id
        )

        # Log communication
        logger.info(
            f"Response sent: id={envelope.message_id}, "
            f"sender={agent_output.agent_id}, success={agent_output.success}"
        )

        # Audit trail
        self._audit_message(envelope)

        return envelope.message_id

    def handoff(
        self,
        from_agent: str,
        to_agent: str,
        context: AgentContext,
        reason: Optional[str] = None
    ) -> str:
        """
        Hand off context from one agent to another.

        Args:
            from_agent: Source agent ID
            to_agent: Destination agent ID
            context: AgentContext to hand off
            reason: Reason for handoff (optional)

        Returns:
            Handoff ID

        Example:
            >>> channel = AgentChannel()
            >>> context = AgentContext(spec_path="/path/to/spec.md")
            >>> # Verifier completed, hand off to router
            >>> handoff_id = channel.handoff(
            ...     from_agent="quality.verifier",
            ...     to_agent="architecture.router",
            ...     context=context,
            ...     reason="Quality insufficient, need routing decision"
            ... )
        """
        # Create handoff record
        handoff = HandoffRecord(
            from_agent=from_agent,
            to_agent=to_agent,
            context=context,
            reason=reason
        )

        # Add to history
        self.handoff_history.append(handoff)

        logger.info(
            f"Context handoff: id={handoff.handoff_id}, "
            f"from={from_agent}, to={to_agent}, reason={reason}"
        )

        # Audit trail
        self._audit_handoff(handoff)

        return handoff.handoff_id

    def get_invocation_chain(self) -> List[str]:
        """
        Get agent invocation chain for current workflow.

        Returns:
            List of agent IDs in invocation order

        Example:
            >>> channel = AgentChannel()
            >>> # ... agents invoked ...
            >>> chain = channel.get_invocation_chain()
            >>> print(" -> ".join(chain))
        """
        return self.invocation_chain.copy()

    def get_handoff_history(self) -> List[HandoffRecord]:
        """
        Get context handoff history.

        Returns:
            List of HandoffRecord instances

        Example:
            >>> channel = AgentChannel()
            >>> # ... handoffs occurred ...
            >>> history = channel.get_handoff_history()
            >>> for h in history:
            ...     print(f"{h.from_agent} -> {h.to_agent}: {h.reason}")
        """
        return self.handoff_history.copy()

    def clear(self) -> None:
        """
        Clear message queue and history (start fresh workflow).

        Example:
            >>> channel = AgentChannel()
            >>> # ... workflow complete ...
            >>> channel.clear()
        """
        self.message_queue.clear()
        self.invocation_chain.clear()
        self.handoff_history.clear()
        logger.info("AgentChannel cleared")

    def export_audit_trail(
        self,
        task_id: str,
        output_path: Optional[str] = None
    ) -> str:
        """
        Export complete audit trail for task.

        Args:
            task_id: Task identifier
            output_path: Path to save audit trail (default: audit_dir/{task_id}_audit.json)

        Returns:
            Path to exported audit trail

        Example:
            >>> channel = AgentChannel()
            >>> # ... workflow complete ...
            >>> audit_path = channel.export_audit_trail(
            ...     task_id="550e8400-e29b-41d4-a716-446655440000"
            ... )
            >>> print(f"Audit trail saved: {audit_path}")
        """
        if output_path is None:
            output_path = str(self.audit_dir / f"{task_id}_audit.json")

        audit_data = {
            'task_id': task_id,
            'generated_at': datetime.now().isoformat(),
            'invocation_chain': self.invocation_chain,
            'handoff_history': [h.to_dict() for h in self.handoff_history],
            'message_count': len(self.message_queue)
        }

        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(json.dumps(audit_data, indent=2))

        logger.info(f"Audit trail exported: {output_path}")
        return str(output_file)

    def _audit_message(self, envelope: MessageEnvelope) -> None:
        """Write message to audit trail."""
        audit_file = self.audit_dir / "messages.jsonl"
        with open(audit_file, 'a') as f:
            f.write(json.dumps(envelope.to_dict()) + '\n')

    def _audit_handoff(self, handoff: HandoffRecord) -> None:
        """Write handoff to audit trail."""
        audit_file = self.audit_dir / "handoffs.jsonl"
        with open(audit_file, 'a') as f:
            f.write(json.dumps(handoff.to_dict()) + '\n')


# ===================================================================
# Utility Functions
# ===================================================================

def validate_agent_communication_contract(
    agent_input: AgentInput,
    agent_output: AgentOutput
) -> bool:
    """
    Validate that agent output matches input contract.

    Args:
        agent_input: Input sent to agent
        agent_output: Output received from agent

    Returns:
        True if contract satisfied, False otherwise

    Example:
        >>> agent_input = AgentInput(...)
        >>> agent_output = AgentOutput(...)
        >>> if validate_agent_communication_contract(agent_input, agent_output):
        ...     print("Contract satisfied")
    """
    # Check that agent IDs match
    if agent_input.agent_id != agent_output.agent_id:
        logger.error(
            f"Agent ID mismatch: input={agent_input.agent_id}, "
            f"output={agent_output.agent_id}"
        )
        return False

    # Check that task IDs match
    if agent_input.task_id != agent_output.task_id:
        logger.error(
            f"Task ID mismatch: input={agent_input.task_id}, "
            f"output={agent_output.task_id}"
        )
        return False

    logger.debug("Agent communication contract validated successfully")
    return True


def serialize_agent_message(message: AgentInput | AgentOutput) -> str:
    """
    Serialize agent message to JSON.

    Args:
        message: AgentInput or AgentOutput

    Returns:
        JSON string

    Example:
        >>> agent_input = AgentInput(...)
        >>> json_str = serialize_agent_message(agent_input)
    """
    return message.model_dump_json(indent=2)


def deserialize_agent_message(
    json_str: str,
    message_type: type
) -> AgentInput | AgentOutput:
    """
    Deserialize agent message from JSON.

    Args:
        json_str: JSON string
        message_type: AgentInput or AgentOutput class

    Returns:
        Deserialized message

    Raises:
        ValidationError: If JSON doesn't match schema

    Example:
        >>> json_str = '{"agent_id": "quality.verifier", ...}'
        >>> agent_input = deserialize_agent_message(json_str, AgentInput)
    """
    return message_type.model_validate_json(json_str)
