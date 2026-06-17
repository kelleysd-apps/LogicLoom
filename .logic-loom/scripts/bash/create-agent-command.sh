#!/bin/bash

# Create Agent Command Wrapper
# This script is called when the /create-agent command is used

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_AGENT_SCRIPT="${SCRIPT_DIR}/create-agent.sh"

# Parse command arguments
# Expected format: /create-agent agent-name "description"
# Or just: /create-agent agent-name
# Or interactive: /create-agent

if [[ $# -eq 0 ]]; then
    # Interactive mode
    echo "Starting interactive agent creation..."
    exec "$CREATE_AGENT_SCRIPT"
elif [[ $# -eq 1 ]]; then
    # Just name provided, need to ask for description
    AGENT_NAME="$1"
    echo "Creating agent: $AGENT_NAME"
    echo "Please provide a description for the agent's purpose:"
    read -r DESCRIPTION

    JSON_INPUT="{\"name\": \"$AGENT_NAME\", \"description\": \"$DESCRIPTION\"}"
    echo "$JSON_INPUT" | "$CREATE_AGENT_SCRIPT" --json
elif [[ $# -ge 2 ]]; then
    # Name and description provided
    AGENT_NAME="$1"
    DESCRIPTION="${*:2}"  # Concatenate all remaining arguments as description

    JSON_INPUT="{\"name\": \"$AGENT_NAME\", \"description\": \"$DESCRIPTION\"}"

    # Execute creation
    RESULT=$(echo "$JSON_INPUT" | "$CREATE_AGENT_SCRIPT" --json)

    # Parse and format result
    if echo "$RESULT" | grep -q '"success": true'; then
        AGENT=$(echo "$RESULT" | grep -o '"agent": "[^"]*"' | cut -d'"' -f4)
        DEPT=$(echo "$RESULT" | grep -o '"department": "[^"]*"' | cut -d'"' -f4)
        FILE=$(echo "$RESULT" | grep -o '"file": "[^"]*"' | cut -d'"' -f4)

        echo ""
        echo "✅ Agent Successfully Created!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Agent: $AGENT"
        echo "Department: $DEPT"
        echo "Location: $FILE"
        echo "Memory: .docs/agents/$DEPT/$AGENT/"
        echo ""
        echo "To use this agent, say:"
        echo "  'Please use the $AGENT agent to...'"
        echo ""
    else
        echo "❌ Failed to create agent"
        echo "$RESULT"
        exit 1
    fi
else
    echo "Usage:"
    echo "  /create-agent                           # Interactive mode"
    echo "  /create-agent agent-name                # Prompts for description"
    echo "  /create-agent agent-name \"description\"  # Direct creation"
    exit 1
fi