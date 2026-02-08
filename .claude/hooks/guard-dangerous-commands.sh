#!/usr/bin/env bash
# Guard hook: validates commands against tool restriction policies
# Sources policy.sh and blocks dangerous commands per policy rules
#
# Usage: echo "<command>" | ./guard-dangerous-commands.sh
#   or:  ./guard-dangerous-commands.sh "<command>"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the policy validation library
POLICY_LIB="$REPO_ROOT/.specify/lib/policy.sh"
if [[ ! -f "$POLICY_LIB" ]]; then
    echo "[ERROR] Policy library not found: $POLICY_LIB" >&2
    exit 1
fi
source "$POLICY_LIB"

# Get command from argument or stdin
if [[ $# -gt 0 ]]; then
    COMMAND="$1"
elif [[ ! -t 0 ]]; then
    read -r COMMAND
else
    echo "Usage: $0 <command>" >&2
    exit 1
fi

# Validate the command against policies
result=$(validate_tool_call "$COMMAND" 2>/dev/null)
exit_code=$?

if [[ $exit_code -eq 2 ]]; then
    # Command blocked
    echo "[BLOCKED] $COMMAND" >&2
    display_policy_violation "$result" >&2
    exit 1
elif [[ $exit_code -eq 3 ]]; then
    # Requires approval
    echo "[APPROVAL REQUIRED] $COMMAND" >&2
    exit 1
elif [[ $exit_code -eq 4 ]]; then
    # Warning
    echo "[WARNING] $COMMAND" >&2
fi

# Command allowed (or warning)
exit 0
