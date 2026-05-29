#!/usr/bin/env bash
# sandbox.sh — Sandbox configuration library for loom-dev-loop plugin
#
# Provides functions to create isolated execution environments for dev-loop
# iterations using Docker containers or OS-level sandboxing (macOS seatbelt
# profiles, Linux bubblewrap with seccomp).
#
# Exported functions:
#   setup_docker_sandbox()        — Create Docker container with security constraints
#   setup_os_sandbox()            — macOS seatbelt profile; Linux bubblewrap + seccomp
#   detect_sandbox_method()       — Check Docker availability, fallback to OS-level
#   enforce_resource_limits()     — Memory/CPU/disk bounds per iteration
#   teardown_sandbox()            — Cleanup container or sandbox profile
#   validate_workspace_boundary() — Verify all file operations within workspace
#
# Docker sandbox constraints:
#   - Non-root UID 1000
#   - Read-only root filesystem
#   - Writable /workspace volume
#   - Network restrictions (--network none)
#   - Resource limits: 2GB RAM, 1 CPU, 10GB disk
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON parsing), permissions-sandbox.sh
# Constitutional Principle VI: Git Approval — sandbox prevents unauthorized operations

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Source the combined implementation if not already loaded
if ! type -t setup_docker_sandbox &>/dev/null; then
    source "${PLUGIN_DIR}/lib/permissions-sandbox.sh"
fi

# ==============================================================================
# All sandbox functions are provided by permissions-sandbox.sh:
#
#   setup_docker_sandbox <workspace_path> [container_name]
#     Creates a Docker container with:
#       - Non-root UID 1000
#       - Read-only root filesystem
#       - Writable /workspace volume
#       - Network restrictions (--network none)
#       - Resource limits from config/safety-limits.json
#
#   setup_os_sandbox <workspace_path>
#     macOS: Generates a sandbox-exec seatbelt profile
#     Linux: Uses bubblewrap (bwrap) with seccomp
#
#   detect_sandbox_method
#     Checks Docker availability first, then falls back to OS-level sandbox.
#     Returns JSON with {"method": "docker"|"seatbelt"|"bubblewrap"|"none"}
#
#   enforce_resource_limits <workspace_path>
#     Auto-detects current memory/CPU/disk usage and checks against config limits.
#     Returns JSON with within_bounds status and any violations.
#
#   teardown_sandbox <method> <identifier>
#     Cleanup: removes Docker container or seatbelt profile file.
#     Bubblewrap is process-scoped and auto-cleans.
#
#   validate_workspace_boundary <target_path> <workspace_path>
#     Quick check if target resolves inside workspace (prevents path traversal).
#     Returns: 0 if within boundary, 1 if outside.
#
#   enforce_sandbox --session <id> --operation <op> --target <path> --workdir <dir>
#     Full sandbox enforcement with JSON result output.
#     Blocks path traversal attacks (../../etc/passwd).
#
#   check_resource_limits [--memory <mb>] [--cpu <cores>] [--disk <gb>] --workdir <dir>
#     Compare provided resource usage against config limits.
#     Returns JSON with within_bounds status, limits, current usage, violations.
# ==============================================================================
