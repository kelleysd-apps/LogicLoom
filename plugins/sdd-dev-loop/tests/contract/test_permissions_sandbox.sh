#!/usr/bin/env bash
# Contract Tests: Permission Enforcement & Sandbox
# TDD tests for permission tier enforcement and sandbox isolation
# Tests: check_permission, request_approval, enforce_sandbox,
#        check_resource_limits, is_operation_blocked
# These tests are written BEFORE implementation (TDD).
#
# Permission Tiers (from config/safety-limits.json):
#   L0 Read-Only:   implicit approval (always permitted)
#   L1 Safe Write:  default_granted (workspace-only writes)
#   L2 Network/VCS: per_session approval required
#   L3 High-Risk:   per_action_always approval required
set -eo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if ( set +eu; eval "$condition" ) 2>/dev/null; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Helper: safely call a function and capture output (returns empty string on failure)
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
}

# ── Setup ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PLUGIN_DIR}/lib"
CONFIG_DIR="${PLUGIN_DIR}/config"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Permission Enforcement & Sandbox Contract Tests ==="
echo ""

# ══════════════════════════════════════════
# Library & Config Existence
# ══════════════════════════════════════════
echo "Library and config existence"
assert "permissions-sandbox.sh exists" "[ -f '${LIB_DIR}/permissions-sandbox.sh' ]"
assert "safety-limits.json config exists" "[ -f '${CONFIG_DIR}/safety-limits.json' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/permissions-sandbox.sh" ]; then
  set +eu
  source "${LIB_DIR}/permissions-sandbox.sh" 2>/dev/null
  set -eu
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "check_permission function exists" "type -t check_permission 2>/dev/null | grep -q function"
assert "request_approval function exists" "type -t request_approval 2>/dev/null | grep -q function"
assert "enforce_sandbox function exists" "type -t enforce_sandbox 2>/dev/null | grep -q function"
assert "check_resource_limits function exists" "type -t check_resource_limits 2>/dev/null | grep -q function"
assert "is_operation_blocked function exists" "type -t is_operation_blocked 2>/dev/null | grep -q function"

# ── Helper: create mock session with permission state ──
create_permission_session() {
  local session_id="$1"
  local session_approvals="${2:-[]}"

  local sess_dir="${TEST_TMPDIR}/.dev-loop/sessions/${session_id}"
  mkdir -p "${sess_dir}"
  cat > "${sess_dir}/state.json" <<EOJSON
{
  "session_id": "${session_id}",
  "status": "running",
  "current_iteration": 1,
  "workdir": "${TEST_TMPDIR}/workspace",
  "permissions": {
    "session_approvals": ${session_approvals},
    "action_approvals": []
  }
}
EOJSON
  mkdir -p "${TEST_TMPDIR}/workspace"
  echo "${sess_dir}"
}

# ══════════════════════════════════════════
# L0 Read-Only Operations — Always Permitted
# ══════════════════════════════════════════
echo ""
echo "--- L0 Read-Only: Always Permitted ---"

L0_OPS=("read_file" "list_directory" "run_linter" "run_type_checker" "run_static_analysis")

if $LIBS_SOURCED; then
  SESS_L0="test-l0-$$"
  create_permission_session "$SESS_L0" "[]" >/dev/null

  for op in "${L0_OPS[@]}"; do
    PERM_RESULT="$(safe_call check_permission --session "$SESS_L0" --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "L0 op '${op}' is permitted (allowed=true)" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"allowed\"] == True, f\"got {d}\"'"
    assert "L0 op '${op}' has tier=L0" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"tier\"] == \"L0\", f\"got {d.get(\\\"tier\\\")}\"'"
    assert "L0 op '${op}' has approval=implicit" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"approval\"] == \"implicit\", f\"got {d.get(\\\"approval\\\")}\"'"
  done

  # L0 ops require no approval even with no session approvals
  PERM_NO_SESS="$(safe_call check_permission --session "$SESS_L0" --operation "read_file" --workdir "$TEST_TMPDIR")"
  assert "L0 op permitted with empty session_approvals" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PERM_NO_SESS}\"\"\"); assert d[\"allowed\"] == True'"
else
  for op in "${L0_OPS[@]}"; do
    assert "L0 op '${op}' is permitted (allowed=true)" "false"
    assert "L0 op '${op}' has tier=L0" "false"
    assert "L0 op '${op}' has approval=implicit" "false"
  done
  assert "L0 op permitted with empty session_approvals" "false"
fi

# ══════════════════════════════════════════
# L1 Safe Write Operations — Workspace-Only
# ══════════════════════════════════════════
echo ""
echo "--- L1 Safe Write: Workspace-Only ---"

L1_OPS=("create_file" "edit_file" "run_tests" "install_package_venv")

if $LIBS_SOURCED; then
  SESS_L1="test-l1-$$"
  create_permission_session "$SESS_L1" "[]" >/dev/null

  for op in "${L1_OPS[@]}"; do
    PERM_RESULT="$(safe_call check_permission --session "$SESS_L1" --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "L1 op '${op}' is permitted by default (allowed=true)" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"allowed\"] == True, f\"got {d}\"'"
    assert "L1 op '${op}' has tier=L1" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"tier\"] == \"L1\", f\"got {d.get(\\\"tier\\\")}\"'"
    assert "L1 op '${op}' has approval=default_granted" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"approval\"] == \"default_granted\", f\"got {d.get(\\\"approval\\\")}\"'"
  done

  # L1 write ops MUST be within workspace directory
  SANDBOX_IN="$(safe_call enforce_sandbox --session "$SESS_L1" --operation "create_file" \
    --target "${TEST_TMPDIR}/workspace/src/new-file.ts" --workdir "$TEST_TMPDIR")"
  assert "L1 create_file within workspace is allowed" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SANDBOX_IN}\"\"\"); assert d[\"allowed\"] == True'"

  SANDBOX_OUT="$(safe_call enforce_sandbox --session "$SESS_L1" --operation "create_file" \
    --target "/etc/passwd" --workdir "$TEST_TMPDIR")"
  assert "L1 create_file outside workspace is BLOCKED" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SANDBOX_OUT}\"\"\"); assert d[\"allowed\"] == False'"
  assert "L1 outside workspace returns SANDBOX_VIOLATION" \
    "echo '${SANDBOX_OUT}' | grep -q 'SANDBOX_VIOLATION'"

  SANDBOX_EDIT_OUT="$(safe_call enforce_sandbox --session "$SESS_L1" --operation "edit_file" \
    --target "/usr/local/bin/something" --workdir "$TEST_TMPDIR")"
  assert "L1 edit_file outside workspace is BLOCKED" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SANDBOX_EDIT_OUT}\"\"\"); assert d[\"allowed\"] == False'"

  # Path traversal attack: workspace + ../../etc/passwd
  SANDBOX_TRAVERSE="$(safe_call enforce_sandbox --session "$SESS_L1" --operation "edit_file" \
    --target "${TEST_TMPDIR}/workspace/../../etc/passwd" --workdir "$TEST_TMPDIR")"
  assert "L1 path traversal outside workspace is BLOCKED" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SANDBOX_TRAVERSE}\"\"\"); assert d[\"allowed\"] == False'"
else
  for op in "${L1_OPS[@]}"; do
    assert "L1 op '${op}' is permitted by default (allowed=true)" "false"
    assert "L1 op '${op}' has tier=L1" "false"
    assert "L1 op '${op}' has approval=default_granted" "false"
  done
  assert "L1 create_file within workspace is allowed" "false"
  assert "L1 create_file outside workspace is BLOCKED" "false"
  assert "L1 outside workspace returns SANDBOX_VIOLATION" "false"
  assert "L1 edit_file outside workspace is BLOCKED" "false"
  assert "L1 path traversal outside workspace is BLOCKED" "false"
fi

# ══════════════════════════════════════════
# L2 Network/VCS — Session-Level Approval
# ══════════════════════════════════════════
echo ""
echo "--- L2 Network/VCS: Session-Level Approval ---"

L2_OPS=("git_commit" "git_fetch" "api_call_allowlisted")

if $LIBS_SOURCED; then
  # Session WITHOUT L2 approval
  SESS_L2_NO="test-l2-noapproval-$$"
  create_permission_session "$SESS_L2_NO" "[]" >/dev/null

  for op in "${L2_OPS[@]}"; do
    PERM_RESULT="$(safe_call check_permission --session "$SESS_L2_NO" --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "L2 op '${op}' DENIED without session approval" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"allowed\"] == False, f\"got {d}\"'"
    assert "L2 op '${op}' has tier=L2" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"tier\"] == \"L2\", f\"got {d.get(\\\"tier\\\")}\"'"
    assert "L2 op '${op}' requires approval=per_session" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"approval\"] == \"per_session\", f\"got {d.get(\\\"approval\\\")}\"'"
    assert "L2 op '${op}' denied returns APPROVAL_REQUIRED" \
      "echo '${PERM_RESULT}' | grep -q 'APPROVAL_REQUIRED'"
  done

  # Session WITH L2 approval granted
  SESS_L2_YES="test-l2-approved-$$"
  create_permission_session "$SESS_L2_YES" '[\"L2\"]' >/dev/null

  for op in "${L2_OPS[@]}"; do
    PERM_APPROVED="$(safe_call check_permission --session "$SESS_L2_YES" --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "L2 op '${op}' ALLOWED with session approval" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_APPROVED}\"\"\"); assert d[\"allowed\"] == True, f\"got {d}\"'"
  done

  # Request approval for L2 returns approval token
  APPROVAL_RESULT="$(safe_call request_approval --session "$SESS_L2_NO" --tier "L2" --workdir "$TEST_TMPDIR")"
  assert "request_approval for L2 returns pending status" \
    "python3 -c 'import json; d=json.loads(\"\"\"${APPROVAL_RESULT}\"\"\"); assert d[\"status\"] == \"pending\", f\"got {d}\"'"
  assert "request_approval for L2 returns tier=L2" \
    "python3 -c 'import json; d=json.loads(\"\"\"${APPROVAL_RESULT}\"\"\"); assert d[\"tier\"] == \"L2\"'"
  assert "request_approval for L2 returns scope=session" \
    "python3 -c 'import json; d=json.loads(\"\"\"${APPROVAL_RESULT}\"\"\"); assert d[\"scope\"] == \"session\"'"
else
  for op in "${L2_OPS[@]}"; do
    assert "L2 op '${op}' DENIED without session approval" "false"
    assert "L2 op '${op}' has tier=L2" "false"
    assert "L2 op '${op}' requires approval=per_session" "false"
    assert "L2 op '${op}' denied returns APPROVAL_REQUIRED" "false"
  done
  for op in "${L2_OPS[@]}"; do
    assert "L2 op '${op}' ALLOWED with session approval" "false"
  done
  assert "request_approval for L2 returns pending status" "false"
  assert "request_approval for L2 returns tier=L2" "false"
  assert "request_approval for L2 returns scope=session" "false"
fi

# ══════════════════════════════════════════
# L3 High-Risk — Per-Action Approval
# ══════════════════════════════════════════
echo ""
echo "--- L3 High-Risk: Per-Action Approval ---"

L3_OPS=("git_push" "deploy" "access_secrets" "git_branch_create" "git_branch_switch" "git_branch_delete")

if $LIBS_SOURCED; then
  # L3 ops always denied without per-action approval
  SESS_L3_NO="test-l3-noapproval-$$"
  create_permission_session "$SESS_L3_NO" "[]" >/dev/null

  for op in "${L3_OPS[@]}"; do
    PERM_RESULT="$(safe_call check_permission --session "$SESS_L3_NO" --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "L3 op '${op}' DENIED without per-action approval" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"allowed\"] == False, f\"got {d}\"'"
    assert "L3 op '${op}' has tier=L3" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"tier\"] == \"L3\", f\"got {d.get(\\\"tier\\\")}\"'"
    assert "L3 op '${op}' requires approval=per_action_always" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_RESULT}\"\"\"); assert d[\"approval\"] == \"per_action_always\", f\"got {d.get(\\\"approval\\\")}\"'"
  done

  # L3 ops denied even if session has L2 approval (session approval is NOT enough)
  SESS_L3_SESS="test-l3-sessapproval-$$"
  create_permission_session "$SESS_L3_SESS" '[\"L2\", \"L3\"]' >/dev/null

  PERM_SESS_ONLY="$(safe_call check_permission --session "$SESS_L3_SESS" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "L3 git_push DENIED even with session-level L3 approval (requires per-action)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PERM_SESS_ONLY}\"\"\"); assert d[\"allowed\"] == False'"

  # request_approval for L3 returns per_action scope
  APPROVAL_L3="$(safe_call request_approval --session "$SESS_L3_NO" --tier "L3" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "request_approval for L3 returns scope=per_action" \
    "python3 -c 'import json; d=json.loads(\"\"\"${APPROVAL_L3}\"\"\"); assert d[\"scope\"] == \"per_action\"'"
  assert "request_approval for L3 includes operation in response" \
    "python3 -c 'import json; d=json.loads(\"\"\"${APPROVAL_L3}\"\"\"); assert d[\"operation\"] == \"git_push\"'"
else
  for op in "${L3_OPS[@]}"; do
    assert "L3 op '${op}' DENIED without per-action approval" "false"
    assert "L3 op '${op}' has tier=L3" "false"
    assert "L3 op '${op}' requires approval=per_action_always" "false"
  done
  assert "L3 git_push DENIED even with session-level L3 approval (requires per-action)" "false"
  assert "request_approval for L3 returns scope=per_action" "false"
  assert "request_approval for L3 includes operation in response" "false"
fi

# ══════════════════════════════════════════
# FR-031: Git Branch Operations ALWAYS Blocked
# ══════════════════════════════════════════
echo ""
echo "--- FR-031: Git Branch Create/Switch/Delete Blocked During Execution ---"

BLOCKED_BRANCH_OPS=("git_branch_create" "git_branch_switch" "git_branch_delete")

if $LIBS_SOURCED; then
  SESS_BLOCKED="test-blocked-branch-$$"
  create_permission_session "$SESS_BLOCKED" "[]" >/dev/null

  for op in "${BLOCKED_BRANCH_OPS[@]}"; do
    # Verify these are in the blocked_operations list
    BLOCKED_RESULT="$(safe_call is_operation_blocked --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "FR-031: '${op}' is in blocked_operations list" \
      "python3 -c 'import json; d=json.loads(\"\"\"${BLOCKED_RESULT}\"\"\"); assert d[\"blocked\"] == True, f\"got {d}\"'"
    assert "FR-031: '${op}' blocked returns reason" \
      "python3 -c 'import json; d=json.loads(\"\"\"${BLOCKED_RESULT}\"\"\"); assert \"reason\" in d and len(d[\"reason\"]) > 0'"

    # Even with explicit per-action approval, blocked ops stay blocked
    PERM_FORCE="$(safe_call check_permission --session "$SESS_BLOCKED" --operation "$op" \
      --force-approve true --workdir "$TEST_TMPDIR")"
    assert "FR-031: '${op}' BLOCKED even with force-approve" \
      "python3 -c 'import json; d=json.loads(\"\"\"${PERM_FORCE}\"\"\"); assert d[\"allowed\"] == False'"
    assert "FR-031: '${op}' with force-approve returns OPERATION_BLOCKED" \
      "echo '${PERM_FORCE}' | grep -q 'OPERATION_BLOCKED'"
  done

  # Non-blocked L3 ops should not be in blocked list
  NON_BLOCKED="$(safe_call is_operation_blocked --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "git_push is NOT in blocked_operations list" \
    "python3 -c 'import json; d=json.loads(\"\"\"${NON_BLOCKED}\"\"\"); assert d[\"blocked\"] == False'"
else
  for op in "${BLOCKED_BRANCH_OPS[@]}"; do
    assert "FR-031: '${op}' is in blocked_operations list" "false"
    assert "FR-031: '${op}' blocked returns reason" "false"
    assert "FR-031: '${op}' BLOCKED even with force-approve" "false"
    assert "FR-031: '${op}' with force-approve returns OPERATION_BLOCKED" "false"
  done
  assert "git_push is NOT in blocked_operations list" "false"
fi

# ══════════════════════════════════════════
# FR-032: Git Push Blocked Without Per-Action Approval
# ══════════════════════════════════════════
echo ""
echo "--- FR-032: Git Push Requires Per-Action Approval ---"

if $LIBS_SOURCED; then
  SESS_PUSH="test-push-$$"
  create_permission_session "$SESS_PUSH" "[]" >/dev/null

  # git_push without any approval
  PUSH_NO="$(safe_call check_permission --session "$SESS_PUSH" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "FR-032: git_push DENIED without approval" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PUSH_NO}\"\"\"); assert d[\"allowed\"] == False'"

  # git_push with session approval only (not enough for L3)
  SESS_PUSH_SESS="test-push-sess-$$"
  create_permission_session "$SESS_PUSH_SESS" '[\"L2\", \"L3\"]' >/dev/null
  PUSH_SESS="$(safe_call check_permission --session "$SESS_PUSH_SESS" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "FR-032: git_push DENIED with only session approval" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PUSH_SESS}\"\"\"); assert d[\"allowed\"] == False'"

  # git_push is not in blocked_operations (unlike branch ops) -- it CAN be approved per-action
  PUSH_BLOCKED="$(safe_call is_operation_blocked --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "FR-032: git_push is not permanently blocked (can be per-action approved)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PUSH_BLOCKED}\"\"\"); assert d[\"blocked\"] == False'"

  # deploy also requires per-action
  DEPLOY_NO="$(safe_call check_permission --session "$SESS_PUSH" --operation "deploy" --workdir "$TEST_TMPDIR")"
  assert "FR-032: deploy DENIED without per-action approval" \
    "python3 -c 'import json; d=json.loads(\"\"\"${DEPLOY_NO}\"\"\"); assert d[\"allowed\"] == False'"

  # access_secrets also requires per-action
  SECRETS_NO="$(safe_call check_permission --session "$SESS_PUSH" --operation "access_secrets" --workdir "$TEST_TMPDIR")"
  assert "FR-032: access_secrets DENIED without per-action approval" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SECRETS_NO}\"\"\"); assert d[\"allowed\"] == False'"
else
  assert "FR-032: git_push DENIED without approval" "false"
  assert "FR-032: git_push DENIED with only session approval" "false"
  assert "FR-032: git_push is not permanently blocked (can be per-action approved)" "false"
  assert "FR-032: deploy DENIED without per-action approval" "false"
  assert "FR-032: access_secrets DENIED without per-action approval" "false"
fi

# ══════════════════════════════════════════
# Resource Limit Enforcement
# ══════════════════════════════════════════
echo ""
echo "--- Resource Limit Enforcement ---"

if $LIBS_SOURCED; then
  # Check that resource limits are read from config
  LIMITS_RESULT="$(safe_call check_resource_limits --workdir "$TEST_TMPDIR")"
  assert "check_resource_limits returns memory_mb limit" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LIMITS_RESULT}\"\"\"); assert d[\"limits\"][\"memory_mb\"] == 2048'"
  assert "check_resource_limits returns cpu_cores limit" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LIMITS_RESULT}\"\"\"); assert d[\"limits\"][\"cpu_cores\"] == 1'"
  assert "check_resource_limits returns disk_gb limit" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LIMITS_RESULT}\"\"\"); assert d[\"limits\"][\"disk_gb\"] == 10'"

  # Within bounds
  WITHIN="$(safe_call check_resource_limits --memory 1024 --cpu 1 --disk 5 --workdir "$TEST_TMPDIR")"
  assert "Resources within limits returns within_bounds=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"${WITHIN}\"\"\"); assert d[\"within_bounds\"] == True'"

  # Memory exceeds limit
  MEM_OVER="$(safe_call check_resource_limits --memory 4096 --cpu 1 --disk 5 --workdir "$TEST_TMPDIR")"
  assert "Memory 4096MB exceeding 2048MB limit returns within_bounds=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MEM_OVER}\"\"\"); assert d[\"within_bounds\"] == False'"
  assert "Memory exceeded returns violation for memory_mb" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MEM_OVER}\"\"\"); assert \"memory_mb\" in d.get(\"violations\", {})'"

  # CPU exceeds limit
  CPU_OVER="$(safe_call check_resource_limits --memory 1024 --cpu 4 --disk 5 --workdir "$TEST_TMPDIR")"
  assert "CPU 4 cores exceeding 1 core limit returns within_bounds=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"${CPU_OVER}\"\"\"); assert d[\"within_bounds\"] == False'"
  assert "CPU exceeded returns violation for cpu_cores" \
    "python3 -c 'import json; d=json.loads(\"\"\"${CPU_OVER}\"\"\"); assert \"cpu_cores\" in d.get(\"violations\", {})'"

  # Disk exceeds limit
  DISK_OVER="$(safe_call check_resource_limits --memory 1024 --cpu 1 --disk 15 --workdir "$TEST_TMPDIR")"
  assert "Disk 15GB exceeding 10GB limit returns within_bounds=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"${DISK_OVER}\"\"\"); assert d[\"within_bounds\"] == False'"
  assert "Disk exceeded returns violation for disk_gb" \
    "python3 -c 'import json; d=json.loads(\"\"\"${DISK_OVER}\"\"\"); assert \"disk_gb\" in d.get(\"violations\", {})'"

  # Multiple limits exceeded at once
  ALL_OVER="$(safe_call check_resource_limits --memory 4096 --cpu 4 --disk 15 --workdir "$TEST_TMPDIR")"
  assert "All resources exceeded returns within_bounds=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ALL_OVER}\"\"\"); assert d[\"within_bounds\"] == False'"
  assert "All resources exceeded returns 3 violations" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ALL_OVER}\"\"\"); assert len(d.get(\"violations\", {})) == 3'"

  # Boundary: exactly at limit
  AT_LIMIT="$(safe_call check_resource_limits --memory 2048 --cpu 1 --disk 10 --workdir "$TEST_TMPDIR")"
  assert "Resources exactly at limits returns within_bounds=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"${AT_LIMIT}\"\"\"); assert d[\"within_bounds\"] == True'"
else
  assert "check_resource_limits returns memory_mb limit" "false"
  assert "check_resource_limits returns cpu_cores limit" "false"
  assert "check_resource_limits returns disk_gb limit" "false"
  assert "Resources within limits returns within_bounds=true" "false"
  assert "Memory 4096MB exceeding 2048MB limit returns within_bounds=false" "false"
  assert "Memory exceeded returns violation for memory_mb" "false"
  assert "CPU 4 cores exceeding 1 core limit returns within_bounds=false" "false"
  assert "CPU exceeded returns violation for cpu_cores" "false"
  assert "Disk 15GB exceeding 10GB limit returns within_bounds=false" "false"
  assert "Disk exceeded returns violation for disk_gb" "false"
  assert "All resources exceeded returns within_bounds=false" "false"
  assert "All resources exceeded returns 3 violations" "false"
  assert "Resources exactly at limits returns within_bounds=true" "false"
fi

# ══════════════════════════════════════════
# Blocked Operations List
# ══════════════════════════════════════════
echo ""
echo "--- Blocked Operations from Config ---"

if $LIBS_SOURCED; then
  # All blocked_operations from safety-limits.json are truly blocked
  BLOCKED_CONFIG_OPS=("git_branch_create" "git_branch_switch" "git_branch_delete")

  for op in "${BLOCKED_CONFIG_OPS[@]}"; do
    B_RESULT="$(safe_call is_operation_blocked --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "Config blocked op '${op}' returns blocked=true" \
      "python3 -c 'import json; d=json.loads(\"\"\"${B_RESULT}\"\"\"); assert d[\"blocked\"] == True'"
  done

  # Non-blocked operations return blocked=false
  NON_BLOCKED_OPS=("read_file" "create_file" "git_commit" "git_push" "run_tests")
  for op in "${NON_BLOCKED_OPS[@]}"; do
    NB_RESULT="$(safe_call is_operation_blocked --operation "$op" --workdir "$TEST_TMPDIR")"
    assert "Non-blocked op '${op}' returns blocked=false" \
      "python3 -c 'import json; d=json.loads(\"\"\"${NB_RESULT}\"\"\"); assert d[\"blocked\"] == False'"
  done

  # Unknown operation should be treated as blocked (fail-safe)
  UNKNOWN="$(safe_call is_operation_blocked --operation "unknown_dangerous_op" --workdir "$TEST_TMPDIR")"
  assert "Unknown operation treated as blocked (fail-safe)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${UNKNOWN}\"\"\"); assert d[\"blocked\"] == True'"
else
  for op in "git_branch_create" "git_branch_switch" "git_branch_delete"; do
    assert "Config blocked op '${op}' returns blocked=true" "false"
  done
  for op in "read_file" "create_file" "git_commit" "git_push" "run_tests"; do
    assert "Non-blocked op '${op}' returns blocked=false" "false"
  done
  assert "Unknown operation treated as blocked (fail-safe)" "false"
fi

# ══════════════════════════════════════════
# Permission Escalation Rejection
# ══════════════════════════════════════════
echo ""
echo "--- Permission Escalation Attempts Rejected ---"

if $LIBS_SOURCED; then
  # L1-approved session trying L3 operation
  SESS_ESC="test-escalation-$$"
  create_permission_session "$SESS_ESC" "[]" >/dev/null

  ESC_RESULT="$(safe_call check_permission --session "$SESS_ESC" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "L1 session cannot perform L3 git_push (escalation rejected)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ESC_RESULT}\"\"\"); assert d[\"allowed\"] == False'"

  # L2-approved session trying L3 operation
  SESS_ESC_L2="test-escalation-l2-$$"
  create_permission_session "$SESS_ESC_L2" '[\"L2\"]' >/dev/null

  ESC_L2_RESULT="$(safe_call check_permission --session "$SESS_ESC_L2" --operation "deploy" --workdir "$TEST_TMPDIR")"
  assert "L2-approved session cannot perform L3 deploy (escalation rejected)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ESC_L2_RESULT}\"\"\"); assert d[\"allowed\"] == False'"

  ESC_L2_SECRETS="$(safe_call check_permission --session "$SESS_ESC_L2" --operation "access_secrets" --workdir "$TEST_TMPDIR")"
  assert "L2-approved session cannot access_secrets (L3, escalation rejected)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ESC_L2_SECRETS}\"\"\"); assert d[\"allowed\"] == False'"

  # L0 session cannot perform L2 operation without session approval
  ESC_L0_TO_L2="$(safe_call check_permission --session "$SESS_ESC" --operation "git_commit" --workdir "$TEST_TMPDIR")"
  assert "No-approval session cannot perform L2 git_commit (escalation rejected)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ESC_L0_TO_L2}\"\"\"); assert d[\"allowed\"] == False'"

  # L2 session approval does NOT grant L3 access
  ESC_L2_TO_L3="$(safe_call check_permission --session "$SESS_ESC_L2" --operation "git_push" --workdir "$TEST_TMPDIR")"
  assert "L2 session approval does NOT grant L3 git_push access" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ESC_L2_TO_L3}\"\"\"); assert d[\"allowed\"] == False'"

  # Verify escalation returns descriptive error
  assert "Escalation attempt returns APPROVAL_REQUIRED error" \
    "echo '${ESC_L2_TO_L3}' | grep -q 'APPROVAL_REQUIRED'"
else
  assert "L1 session cannot perform L3 git_push (escalation rejected)" "false"
  assert "L2-approved session cannot perform L3 deploy (escalation rejected)" "false"
  assert "L2-approved session cannot access_secrets (L3, escalation rejected)" "false"
  assert "No-approval session cannot perform L2 git_commit (escalation rejected)" "false"
  assert "L2 session approval does NOT grant L3 git_push access" "false"
  assert "Escalation attempt returns APPROVAL_REQUIRED error" "false"
fi

# ══════════════════════════════════════════
# Error Handling
# ══════════════════════════════════════════
echo ""
echo "--- Error Handling ---"

if $LIBS_SOURCED; then
  # SESSION_NOT_FOUND for check_permission
  NO_SESS_PERM="$(safe_call check_permission --session "nonexistent-id" --operation "read_file" --workdir "$TEST_TMPDIR")"
  assert "check_permission with nonexistent session returns SESSION_NOT_FOUND" \
    "echo '${NO_SESS_PERM}' | grep -q 'SESSION_NOT_FOUND'"

  # Missing operation parameter
  NO_OP="$(safe_call check_permission --session "test" --workdir "$TEST_TMPDIR")"
  assert "check_permission without operation returns INVALID_OPERATION" \
    "echo '${NO_OP}' | grep -q 'INVALID_OPERATION'"

  # enforce_sandbox without target
  NO_TARGET="$(safe_call enforce_sandbox --session "test" --operation "create_file" --workdir "$TEST_TMPDIR")"
  assert "enforce_sandbox without target returns INVALID_TARGET" \
    "echo '${NO_TARGET}' | grep -q 'INVALID_TARGET'"

  # request_approval without tier
  NO_TIER="$(safe_call request_approval --session "test" --workdir "$TEST_TMPDIR")"
  assert "request_approval without tier returns INVALID_TIER" \
    "echo '${NO_TIER}' | grep -q 'INVALID_TIER'"

  # request_approval with invalid tier
  BAD_TIER="$(safe_call request_approval --session "test" --tier "L5" --workdir "$TEST_TMPDIR")"
  assert "request_approval with invalid tier L5 returns INVALID_TIER" \
    "echo '${BAD_TIER}' | grep -q 'INVALID_TIER'"
else
  assert "check_permission with nonexistent session returns SESSION_NOT_FOUND" "false"
  assert "check_permission without operation returns INVALID_OPERATION" "false"
  assert "enforce_sandbox without target returns INVALID_TARGET" "false"
  assert "request_approval without tier returns INVALID_TIER" "false"
  assert "request_approval with invalid tier L5 returns INVALID_TIER" "false"
fi

# ══════════════════════════════════════════
# Config Loading Verification
# ══════════════════════════════════════════
echo ""
echo "--- Config Loading Verification ---"

if $LIBS_SOURCED; then
  # Verify permission tiers loaded from safety-limits.json match expected structure
  TIERS_RESULT="$(safe_call check_permission --session "any" --operation "read_file" --list-tiers --workdir "$TEST_TMPDIR")"
  assert "Config has 4 permission tiers (L0-L3)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TIERS_RESULT}\"\"\"); assert len(d.get(\"tiers\", {})) == 4' 2>/dev/null || \
     python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"permission_tiers\"]) == 4'"

  # Verify L0 operations list
  assert "L0 has 5 operations in config" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"permission_tiers\"][\"L0\"][\"operations\"]) == 5'"

  # Verify L1 operations list
  assert "L1 has 4 operations in config" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"permission_tiers\"][\"L1\"][\"operations\"]) == 4'"

  # Verify L2 operations list
  assert "L2 has 3 operations in config" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"permission_tiers\"][\"L2\"][\"operations\"]) == 3'"

  # Verify L3 operations list
  assert "L3 has 6 operations in config" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"permission_tiers\"][\"L3\"][\"operations\"]) == 6'"

  # Verify blocked_operations list
  assert "Config has 3 blocked operations" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert len(d[\"blocked_operations\"]) == 3'"

  # Verify resource limits
  assert "Config resource_limits has memory_mb=2048" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert d[\"resource_limits\"][\"memory_mb\"] == 2048'"
  assert "Config resource_limits has cpu_cores=1" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert d[\"resource_limits\"][\"cpu_cores\"] == 1'"
  assert "Config resource_limits has disk_gb=10" \
    "python3 -c 'import json; f=open(\"${CONFIG_DIR}/safety-limits.json\"); d=json.load(f); assert d[\"resource_limits\"][\"disk_gb\"] == 10'"
else
  assert "Config has 4 permission tiers (L0-L3)" "false"
  assert "L0 has 5 operations in config" "false"
  assert "L1 has 4 operations in config" "false"
  assert "L2 has 3 operations in config" "false"
  assert "L3 has 6 operations in config" "false"
  assert "Config has 3 blocked operations" "false"
  assert "Config resource_limits has memory_mb=2048" "false"
  assert "Config resource_limits has cpu_cores=1" "false"
  assert "Config resource_limits has disk_gb=10" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
