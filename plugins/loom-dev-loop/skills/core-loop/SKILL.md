---
name: core-loop
version: 0.1.0
description: |
  Main recursive dev-loop skill. Orchestrates the full autonomous edit-test-debug cycle —
  parses arguments, detects scope, initializes session, iterates (implement, test, grade,
  evaluate termination), and produces a final session report with RL feedback.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, TaskCreate, TaskUpdate
triggers:
  - /dev-loop
category: orchestration
constitutional_principles:
  - II   # Test-First: TDD mandatory, tests run every iteration
  - VI   # Git Approval: no autonomous git operations without user consent
  - X    # Agent Delegation: route specialized work to specialist agents
  - XIV  # AI Model Selection: Opus 4.8 default
  - XVI  # Plugin-First: capability organized as installable plugin
---

# Core Loop Skill

## Overview

The core-loop skill implements the recursive autonomous development loop invoked via
`/dev-loop`. It accepts a natural-language task description and optional configuration,
then autonomously researches, plans, implements, tests, grades, and iterates until a
configurable quality threshold is met or a termination condition fires.

The loop follows the cycle defined in the dev-loop-lifecycle contract:

```
Research -> Plan -> Implement -> Test -> Grade -> Evaluate
  -> [Pass: Complete | Fail: Diagnose -> Implement (next iteration)]
```

Each iteration starts with fresh context read from version control and structured state
files, preventing context degradation across long-running sessions.

## Procedure

### Step 1: Parse Arguments

Parse the `/dev-loop` invocation arguments:

| Argument | Type | Default | Range |
|----------|------|---------|-------|
| `description` | string | *(required)* | non-empty task description |
| `--threshold` | float | 0.95 | 0.80 - 0.99 |
| `--budget` | integer | 500000 | positive token count |
| `--max-iterations` | integer | 25 | 10 - 50 |
| `--mode` | enum | auto | `tactic`, `strategy`, `auto` |

Validate all parameters against the ranges defined in `config/thresholds.json` and
`config/safety-limits.json`. Reject with a clear error message if any value is out of
range or the task description is empty.

### Step 2: Run Scope Detection

```bash
source plugins/loom-dev-loop/lib/scope-detector.sh
scope_result=$(analyze_scope "$description")
```

If `--mode` is `auto`, scope detection classifies the task as `tactic` or `strategy`
based on complexity signals (file count, domain count, estimated change surface). If the
user explicitly set `--mode`, skip detection and use the forced mode.

- **tactic**: Small, focused tasks (bug fix, simple refactor, documentation update).
  Streamlined cycle — skip full specification and research phases.
- **strategy**: Large, cross-cutting tasks (new feature, architecture change).
  Full workflow with research, tribunal checkpoints, and specification.

### Step 3: Initialize Session

Create the session workspace:

```
.devloop/sessions/{session_id}/
  session-state.json      # Current session state (status, config, iteration)
  quality-history.json    # Array of composite grades per iteration
  event-log.jsonl         # Append-only structured event stream
  checkpoints/            # Iteration checkpoints for resumption
```

Write `session-state.json` with:
- `session_id`: Generated UUID
- `status`: "running"
- `mode`: Resolved tactic/strategy
- `config`: Merged defaults + user overrides (threshold, budget, max_iterations, weights)
- `started_at`: ISO 8601 timestamp
- `current_iteration`: 0
- `resources_consumed`: `{ tokens: 0, cost: 0.0 }`

Save `checkpoint_0` capturing the initial state.

### Step 4: Initial Research and Planning

Behavior varies by mode:

**Tactic mode**:
- Generate a lightweight plan from the task description.
- Produce a focused task list (typically 1-3 tasks).
- Skip full specification and tribunal.

**Strategy mode**:
- Invoke `/specification` workflow (research, spec, plan, tasks).
- Run tribunal checkpoint on research synthesis (delegate to tribunal-judge agent).
- Produce comprehensive plan and task list.

### Step 5: Main Iteration Loop

```
for iteration in 1..max_iterations:
```

#### 5a. Read Fresh Context

Read the current state of the workspace from git and structured files. Do NOT carry
forward stale context from previous iterations.

```bash
source plugins/loom-dev-loop/lib/event-logger.sh
log_event "$session_id" "iteration_start" "iteration=$iteration"
```

#### 5b. Execute Implementation Changes

Apply code changes according to the current plan and task list. Use the TaskCreate tool
to create tasks and TaskUpdate to track active tasks within the iteration.

#### 5c. Run Test Suite

Execute the project test suite. Capture:
- Pass/fail counts
- Coverage report
- Error output for failed tests

This is the primary quality signal per Principle II (Test-First).

#### 5d. Compute Quality Grade

```bash
source plugins/loom-dev-loop/lib/grading-engine.sh
grade_result=$(compute_composite_grade "$metrics" "$weights")
```

Produces a composite 0.0-1.0 grade from normalized metrics (test_pass_rate, coverage,
lint, type_safety, security, build) combined with configured weights from
`config/weights.json`.

#### 5e. Check Termination

```bash
source plugins/loom-dev-loop/lib/termination-engine.sh
termination_result=$(check_all_termination_layers "$session_id")
```

Evaluates all six termination layers in priority order:
1. **Success**: Composite grade >= threshold
2. **Convergence**: Improvement < delta for N consecutive iterations
3. **Budget exhausted**: Token or cost limit reached
4. **Max iterations**: Iteration count limit reached
5. **Stuck/oscillation**: Same failure recurring or code state revisited
6. **User interrupt**: External interrupt signal received

#### 5f. Log Events

```bash
source plugins/loom-dev-loop/lib/event-logger.sh
log_event "$session_id" "iteration_complete" "$iteration_summary"
log_event "$session_id" "quality_grade" "$grade_result"
log_event "$session_id" "termination_check" "$termination_result"
```

#### 5g. If Terminated

If any termination layer triggers:
1. Generate session report (iteration count, grade trajectory, resources consumed,
   termination reason, code changes summary).
2. Record RL feedback for all skills and models used:
   ```bash
   .logic-loom/scripts/bash/rl/collect-feedback.sh core-loop success|failure $tokens
   .logic-loom/scripts/bash/rl/sync-metrics.sh
   ```
3. Save final checkpoint.
4. Exit loop with termination status.

#### 5h. If Not Terminated

If no termination layer triggers:
1. Diagnose failures — delegate to debug-analyst agent for root cause analysis.
2. Update the plan based on diagnosis.
3. Continue to next iteration.

### Step 6: Post-Loop Finalization

After the loop exits (regardless of reason):

1. Save final checkpoint to `.devloop/sessions/{session_id}/checkpoints/`.
2. Generate comprehensive session report:
   - Total iterations executed
   - Quality grade trajectory (array of composite grades)
   - All tribunal decisions (if strategy mode)
   - Resources consumed (tokens by model, cost by model, wall-clock time)
   - Code changes summary
   - Termination reason
3. Sync RL metrics:
   ```bash
   .logic-loom/scripts/bash/rl/sync-metrics.sh
   ```
4. Update session-state.json with `status: "terminated"` and `termination_reason`.

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **II (Test-First)** | Tests run every iteration; test_pass_rate is the heaviest grading weight. |
| **VI (Git Approval)** | No autonomous git push, branch create/switch/delete. All L3 operations require explicit user approval. The loop operates on the current branch only. |
| **X (Agent Delegation)** | Debug diagnosis delegates to debug-analyst. Tribunal decisions delegate to tribunal-judge. Quality assessment delegates to quality-assessor. |
| **XIV (AI Model Selection)** | Opus 4.8 for orchestration and specialist agents. |
| **XVI (Plugin-First)** | Entire capability is an installable plugin at `plugins/loom-dev-loop/`. |

## RL Feedback

At session end, the skill records its outcome to the RL feedback system:

- **Success**: Quality threshold met -> `collect-feedback.sh core-loop success $tokens`
- **Converged**: Quality plateaued -> `collect-feedback.sh core-loop success $tokens`
- **Budget/Max/Stuck/Error**: Did not meet threshold -> `collect-feedback.sh core-loop failure $tokens`

The EMA algorithm (alpha=0.1) adjusts the skill's `selection_weight` over time,
influencing future routing decisions.

## Safety Layer

The core loop integrates a multi-layered safety system that enforces permission tiers,
sandbox isolation, and resource limits on every iteration. Safety checks are mandatory
and cannot be bypassed by the loop or any agent.

### Permission Enforcement

Every tool invocation within the loop is checked against the L0-L3 permission tier
system before execution. The permissions library (`lib/permissions-sandbox.sh`) is
sourced at session initialization and consulted on every action.

```bash
source plugins/loom-dev-loop/lib/permissions-sandbox.sh

# Before every tool invocation:
perm_result=$(check_permission --session "$session_id" --operation "$operation" --workdir "$workdir")
allowed=$(echo "$perm_result" | jq -r '.allowed')

if [[ "$allowed" != "true" ]]; then
    error_type=$(echo "$perm_result" | jq -r '.error')
    log_event "$session_id" "decision" "permission_denied" \
        "{\"operation\": \"$operation\", \"error\": \"$error_type\"}"
    # Skip this operation or request approval
fi
```

#### Permission Tiers

| Tier | Name | Approval | Operations |
|------|------|----------|------------|
| **L0** | Read-Only | Implicit (always allowed) | `read_file`, `list_directory`, `run_linter`, `run_type_checker`, `run_static_analysis` |
| **L1** | Safe Write | Default granted (workspace-only) | `create_file`, `edit_file`, `run_tests`, `install_package_venv` |
| **L2** | Network/VCS | Per-session approval | `git_commit`, `git_fetch`, `api_call_allowlisted` |
| **L3** | High-Risk | Per-action approval (always) | `git_push`, `deploy`, `access_secrets`, `git_branch_*` |

#### Blocked Operations (FR-031)

The following operations are **permanently blocked** during loop execution, regardless
of any approval level. They cannot be force-approved:

- `git_branch_create` — No autonomous branch creation
- `git_branch_switch` — No autonomous branch switching
- `git_branch_delete` — No autonomous branch deletion

This enforces Constitutional Principle VI (Git Approval): the loop operates exclusively
on the current branch.

#### Git Push Approval (FR-032)

`git_push` is an L3 operation that requires **per-action** user approval on every
invocation. Session-level approval is not sufficient. The loop must explicitly request
and receive approval before any push operation.

### Sandbox Isolation

Each iteration executes within a sandbox that restricts file system access to the
workspace boundary and enforces resource limits. The sandbox is configured at session
start and verified on each iteration.

```bash
source plugins/loom-dev-loop/lib/permissions-sandbox.sh

# At session initialization: detect and configure sandbox
sandbox_method=$(detect_sandbox_method)
method=$(echo "$sandbox_method" | jq -r '.method')

case "$method" in
    docker)
        sandbox_result=$(setup_docker_sandbox "$workspace_path")
        ;;
    seatbelt|bubblewrap)
        sandbox_result=$(setup_os_sandbox "$workspace_path")
        ;;
    *)
        # Fallback: enforce_sandbox checks on every file operation
        log_event "$session_id" "decision" "sandbox_fallback" \
            '{"method": "boundary_check", "reason": "no_sandbox_runtime_available"}'
        ;;
esac
```

#### Docker Sandbox (Preferred)

When Docker is available, iterations execute in containers with:
- **Non-root user**: UID 1000 (no privilege escalation)
- **Read-only root filesystem**: Only `/workspace` is writable
- **Network isolation**: `--network none` (no internet access)
- **Resource caps**: 2GB RAM, 1 CPU, 256 PID limit
- **Security**: `no-new-privileges` enforced

#### OS-Level Sandbox (Fallback)

When Docker is unavailable:
- **macOS**: `sandbox-exec` seatbelt profile restricting file and network access
- **Linux**: `bubblewrap` with network and PID namespace isolation

#### Workspace Boundary Enforcement

All file operations (L1 tier: `create_file`, `edit_file`) are validated against the
workspace boundary before execution. Path traversal attacks (`../../etc/passwd`) are
blocked by resolving canonical paths.

```bash
# Before any file write operation:
sandbox_result=$(enforce_sandbox --session "$session_id" \
    --operation "$operation" --target "$file_path" --workdir "$workdir")
allowed=$(echo "$sandbox_result" | jq -r '.allowed')

if [[ "$allowed" != "true" ]]; then
    log_event "$session_id" "error" "sandbox_violation" \
        "{\"target\": \"$file_path\", \"error\": \"SANDBOX_VIOLATION\"}"
    # Block this operation — do not proceed
fi
```

### Resource Limits Per Iteration

Resource consumption is checked at the start of each iteration against the limits
defined in `config/safety-limits.json`:

| Resource | Limit | Source |
|----------|-------|--------|
| Memory | 2048 MB | `resource_limits.memory_mb` |
| CPU | 1 core | `resource_limits.cpu_cores` |
| Disk | 10 GB | `resource_limits.disk_gb` |

```bash
# At the start of each iteration:
limits_result=$(check_resource_limits --memory "$current_mem" \
    --cpu "$current_cpu" --disk "$current_disk" --workdir "$workdir")
within_bounds=$(echo "$limits_result" | jq -r '.within_bounds')

if [[ "$within_bounds" != "true" ]]; then
    violations=$(echo "$limits_result" | jq -c '.violations')
    log_event "$session_id" "error" "resource_limit_exceeded" "$violations"
    # Trigger termination or request cleanup before continuing
fi
```

If any resource limit is exceeded, the iteration is blocked and the termination
engine is consulted. This prevents runaway loops from consuming unbounded resources.

### Event Logging for Safety

All permission checks, sandbox validations, and resource limit evaluations are logged
to the session's event stream for full auditability:

```bash
# Permission check events
log_event "$session_id" "decision" "permission_check" \
    "{\"operation\": \"$op\", \"tier\": \"$tier\", \"allowed\": $allowed}"

# Sandbox violation events
log_event "$session_id" "error" "sandbox_violation" \
    "{\"target\": \"$path\", \"workspace\": \"$workspace\"}"

# Resource limit events
log_event "$session_id" "observation" "resource_check" \
    "{\"within_bounds\": $within_bounds, \"memory_mb\": $mem, \"cpu\": $cpu, \"disk_gb\": $disk}"
```

This ensures that every safety decision is traceable in the event log for post-session
review and debugging.

### Safety Integration Points in the Loop

The safety layer integrates at these specific points in the main iteration loop:

| Loop Step | Safety Check | Library Function |
|-----------|-------------|------------------|
| **Session Init (Step 3)** | Configure sandbox, load permissions | `detect_sandbox_method()`, `setup_docker_sandbox()` or `setup_os_sandbox()` |
| **Before Tool Invocation (Step 5b)** | Check permission tier | `check_permission()` |
| **Before File Write (Step 5b)** | Validate workspace boundary | `enforce_sandbox()` |
| **Iteration Start (Step 5a)** | Check resource limits | `check_resource_limits()` |
| **L3 Operation Attempt** | Block or request per-action approval | `is_operation_blocked()`, `request_approval()` |
| **Session End (Step 6)** | Teardown sandbox | `teardown_sandbox()` |
| **Every Safety Event** | Log to event stream | `log_event()` |
