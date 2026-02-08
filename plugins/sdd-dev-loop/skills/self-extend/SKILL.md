---
name: self-extend
version: 0.1.0
description: |
  Self-extension skill for the dev-loop plugin. Detects recurring capability gaps from
  session error logs, scaffolds new tool plugins in quarantine, validates them against
  constitutional requirements (tests, security, all 16 principles), and registers
  validated plugins for immediate use. Enables the dev-loop to autonomously grow its
  own toolset over time.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
triggers:
  - self_extend
  - self-extend
  - detect_gap
  - scaffold_plugin
  - validate_quarantine
  - register_plugin
category: orchestration
constitutional_principles:
  - II   # Test-First: scaffolded plugins must include tests with >= 80% coverage
  - III  # Contract-First: scaffolded plugins define clear input/output contracts
  - VI   # Git Approval: self-extension NEVER performs git operations
  - XI   # Input Validation: all inputs validated before processing
  - XV   # File Organization: plugins follow standard directory structure
  - XVI  # Plugin-First: new capabilities created as installable plugins
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# Self-Extend Skill

## Overview

The self-extend skill enables the dev-loop to autonomously identify missing capabilities
and create new tool plugins to address them. It monitors session error logs for recurring
patterns (errors that appear >= 3 times), classifies the impact, scaffolds a new plugin
in a quarantine directory, validates the plugin against all quality and safety gates, and
registers it for immediate use upon passing validation.

This implements a closed feedback loop where the dev-loop's own failures drive capability
expansion:

```
Session Errors -> Gap Detection -> Plugin Scaffolding -> Quarantine Validation
                                                              |
                                                    [Pass] -> Registration -> Available
                                                    [Fail] -> Remains in Quarantine
```

All self-generated plugins follow the `sdd-tool-{name}` naming convention and are
authored by `devloop-selfgen` for clear provenance tracking.

## Operations

### Operation 1: Detect Gap

Analyze the session event log for recurring error patterns that indicate a missing
capability. Errors that recur >= 3 times across sessions (or within a session) are
candidates for gap detection.

**Inputs**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `session_dir` | string | yes | Path to the session directory containing `events.jsonl` |
| `min_frequency` | integer | no | Minimum error recurrence to trigger detection (default: 3) |
| `error_log_path` | string | no | Override path to the JSONL event log (default: `{session_dir}/events.jsonl`) |

**Procedure**:

1. Validate inputs:
   - `session_dir` must exist and contain an event log (error: `SESSION_NOT_FOUND`)
   - Event log must be non-empty (error: `EMPTY_ERROR_LOG`)

2. Read error events from the JSONL event log:
   ```bash
   source plugins/sdd-dev-loop/lib/event-logger.sh
   init_event_log "$session_id" "$session_dir"
   error_events=$(query_events --type "error")
   ```

3. Group errors by normalized pattern:
   - Extract error messages from `content` and `metadata.error` fields
   - Normalize by stripping timestamps, session IDs, and variable values
   - Group by similarity (exact match on normalized message, or regex clustering)

4. Filter groups by frequency:
   - Count occurrences per pattern group
   - Discard groups with fewer than `min_frequency` occurrences
   - If no patterns meet threshold, return empty result (no gap detected)

5. For each qualifying pattern, compute impact classification:
   - **high**: Error caused session termination or critical quality gate failure
     (`metadata.severity == "critical"` or error in termination event)
   - **medium**: Error caused iteration failure or grade degradation
     (`metadata.severity == "error"` or error correlates with grade drop)
   - **low**: Error was logged but did not block progress
     (`metadata.severity == "warning"` or error was recovered from)

6. Generate suggested plugin name:
   - Extract key nouns from the error pattern (e.g., "eslint", "validator", "linter")
   - Form name as `sdd-tool-{noun1}-{noun2}` (lowercase, hyphen-separated)
   - Validate name does not conflict with existing plugins

7. Compute confidence score:
   ```
   impact_weight = { "low": 0.3, "medium": 0.6, "high": 1.0 }[impact]
   pattern_consistency = unique_messages / total_occurrences  # inverted
   confidence = min(1.0, (frequency / 10) * 0.4 + impact_weight * 0.4 + (1.0 - pattern_consistency) * 0.2)
   ```

8. Create GapAnalysis record following the `templates/gap-analysis.md` entity schema:
   ```json
   {
     "gap_id": "gap-{timestamp}-{slug}",
     "session_id": "{current_session}",
     "missing_capability": "{description}",
     "frequency": {count},
     "impact": "{low|medium|high}",
     "suggested_plugin_name": "sdd-tool-{name}",
     "confidence": {score},
     "error_pattern": "{regex}",
     "sample_errors": [{...}],
     "detected_at": "{ISO 8601}",
     "status": "detected"
   }
   ```

9. Log detection event:
   ```bash
   log_event "observation" "$iteration" "Gap detected: $missing_capability" \
     "{\"gap_id\":\"$gap_id\",\"frequency\":$frequency,\"impact\":\"$impact\",\"confidence\":$confidence}"
   ```

**Outputs**: JSON GapAnalysis object if gap detected, or `{"gap_detected": false}` if
no recurring patterns found.

**Error Codes**:

| Code | Trigger | Resolution |
|------|---------|------------|
| `SESSION_NOT_FOUND` | Session directory does not exist | Verify session_dir path |
| `EMPTY_ERROR_LOG` | Event log is empty or contains no error events | Session has no errors to analyze |

### Operation 2: Scaffold Plugin

Generate a new plugin directory structure in quarantine based on a detected gap.
Creates all required files: plugin.json, SKILL.md, agent definition, and test stubs.

**Inputs**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `gap_id` | string | yes | GapAnalysis reference |
| `plugin_name` | string | yes | Plugin name (must start with `sdd-tool-`) |
| `workdir` | string | yes | Working directory (quarantine created under `.devloop/quarantine/`) |
| `gap_analysis` | JSON | yes | Full GapAnalysis object from detect_gap |

**Procedure**:

1. Validate inputs:
   - `plugin_name` must start with `sdd-tool-` (error: `INVALID_NAME`)
   - `plugin_name` must be lowercase with hyphens only
   - `gap_analysis.missing_capability` must be non-empty (error: `CAPABILITY_TOO_VAGUE`)
   - Plugin must not already exist in `plugins/` or quarantine (error: `ALREADY_EXISTS`)

2. Create quarantine directory structure:
   ```
   {workdir}/.devloop/quarantine/{plugin_name}/
     .claude-plugin/
       plugin.json
     skills/
       {tool-name}/
         SKILL.md
     agents/
       {tool-name}-agent.md
     tests/
       contract/
         test_{tool_name}.sh
       integration/
         test_{tool_name}_e2e.sh
     lib/
     config/
   ```

3. Generate `plugin.json` (PluginManifest):
   ```json
   {
     "name": "{plugin_name}",
     "version": "0.1.0",
     "description": "{gap_analysis.missing_capability}",
     "author": "devloop-selfgen",
     "entrypoint": "skills/{tool-name}/SKILL.md",
     "parameters": {},
     "permissions_required": ["Read", "Bash"],
     "created_by_session": "{gap_analysis.session_id}",
     "gap_id": "{gap_id}",
     "category": "tool",
     "rl_metrics": {
       "success_rate": 0.5,
       "selection_weight": 0.5,
       "invocation_count": 0
     }
   }
   ```

4. Generate `SKILL.md` from the gap analysis:
   - Skill name derived from plugin name (strip `sdd-tool-` prefix)
   - Description from `missing_capability`
   - Operations stubbed with input/output contracts
   - Error codes documented

5. Generate test stubs:
   - Contract test: function existence assertions, input validation tests,
     expected error code tests (following `test_permissions_sandbox.sh` pattern)
   - Integration test: end-to-end usage scenario stub

6. Generate agent definition:
   - Agent name: `{tool-name}-agent`
   - Model: `claude-opus-4-6` (default per Principle XIV)
   - Tools: `Read, Bash` (minimal permissions)

7. Set quarantine status to `pending`:
   ```json
   {
     "quarantine_lifecycle": {
       "status": "pending",
       "scaffolded_at": "{ISO 8601}",
       "validation_results": null
     }
   }
   ```

8. Log scaffold event:
   ```bash
   log_event "action" "$iteration" "Plugin scaffolded: $plugin_name" \
     "{\"gap_id\":\"$gap_id\",\"quarantine_path\":\"$quarantine_path\"}"
   ```

**Outputs**: JSON scaffold result with `plugin_name`, `quarantine_path`, `status: "pending"`,
and list of created files.

**Error Codes**:

| Code | Trigger | Resolution |
|------|---------|------------|
| `INVALID_NAME` | Plugin name does not start with `sdd-tool-` | Use the `sdd-tool-{name}` naming convention |
| `CAPABILITY_TOO_VAGUE` | Missing capability description is empty or too short (< 10 chars) | Provide a clear description of the missing capability |
| `ALREADY_EXISTS` | Plugin name already exists in plugins/ or quarantine | Choose a different name or dismiss the existing gap |

### Operation 3: Validate Quarantine

Run the full validation suite against a quarantined plugin. Checks test coverage,
security scan, and constitutional compliance for all 16 principles.

**Inputs**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `plugin_name` | string | yes | Name of the plugin in quarantine |
| `workdir` | string | yes | Working directory containing `.devloop/quarantine/` |

**Procedure**:

1. Locate plugin in quarantine:
   - Path: `{workdir}/.devloop/quarantine/{plugin_name}/`
   - Must exist (error: `PLUGIN_NOT_FOUND`)
   - Must have `plugin.json` (error: `MANIFEST_INVALID`)

2. Set quarantine status to `testing`:
   ```json
   { "quarantine_lifecycle": { "status": "testing" } }
   ```

3. Run automated test suite:
   ```bash
   cd "{quarantine_path}"
   # Execute all contract tests
   for test_file in tests/contract/test_*.sh; do
     bash "$test_file"
   done
   # Execute all integration tests
   for test_file in tests/integration/test_*.sh; do
     bash "$test_file"
   done
   ```
   - Compute test coverage from pass/fail counts
   - Requirement: >= 80% coverage (Principle II)
   - Record result:
     ```json
     {
       "test_coverage": {
         "status": "passed|failed",
         "coverage_percent": 85,
         "required_percent": 80
       }
     }
     ```

4. Run security scan:
   - Check for hardcoded secrets (API keys, passwords, tokens)
   - Check for command injection vulnerabilities (unsanitized inputs to `eval`, `bash -c`)
   - Check for path traversal patterns (`../`, symlink following)
   - Check for network access without permission declaration
   - Requirement: 0 critical findings, 0 high findings
   - Record result:
     ```json
     {
       "security_scan": {
         "status": "passed|failed",
         "critical_count": 0,
         "high_count": 0,
         "medium_count": 1,
         "findings": [...]
       }
     }
     ```

5. Run constitutional review (all 16 principles):
   - For each principle, perform automated check:

   | Principle | Automated Check |
   |-----------|----------------|
   | I (Library-First) | Verify no reimplementation of existing lib/ functions |
   | II (Test-First) | Verify test files exist and coverage >= 80% |
   | III (Contract-First) | Verify SKILL.md has input/output tables |
   | IV (Idempotency) | Verify no side effects on repeated execution |
   | V (Progressive Enhancement) | Verify graceful degradation stubs |
   | VI (Git Approval) | Verify NO git write commands in any file |
   | VII (Observability) | Verify log_event calls exist |
   | VIII (Documentation Sync) | Verify SKILL.md exists and is non-empty |
   | IX (Dependency Management) | Verify plugin.json lists dependencies |
   | X (Agent Delegation) | Verify agent.md exists if multi-domain |
   | XI (Input Validation) | Verify input validation in skill operations |
   | XII (Design System) | Verify follows plugin directory conventions |
   | XIII (Access Control) | Verify permissions_required in plugin.json |
   | XIV (AI Model Selection) | Verify model specified in agent if applicable |
   | XV (File Organization) | Verify standard directory structure |
   | XVI (Plugin-First) | Verify self-contained plugin structure |

   - Each check produces `true` (pass) or `false` (fail)
   - Requirement: ALL 16 principles must pass
   - Record result:
     ```json
     {
       "constitutional_review": {
         "status": "passed|failed",
         "principles_checked": 16,
         "principles_passed": 16,
         "principle_results": {
           "I_library_first": true,
           "II_test_first": true,
           ...
         }
       }
     }
     ```

6. Determine overall quarantine status:
   - If ALL checks pass: `status = "passed"`
   - If ANY check fails: `status = "failed"`

7. Update quarantine metadata:
   ```json
   {
     "quarantine_lifecycle": {
       "status": "passed|failed",
       "validated_at": "{ISO 8601}",
       "validation_results": { ... }
     }
   }
   ```

8. Log validation event:
   ```bash
   log_event "observation" "$iteration" "Quarantine validation: $status" \
     "{\"plugin_name\":\"$plugin_name\",\"test_coverage\":$coverage,\"security\":\"$sec_status\",\"constitutional\":\"$const_status\"}"
   ```

**Outputs**: JSON validation result with per-check status, overall pass/fail, and
detailed findings.

**Error Codes**:

| Code | Trigger | Resolution |
|------|---------|------------|
| `PLUGIN_NOT_FOUND` | Plugin directory not found in quarantine | Verify plugin_name and workdir path |
| `MANIFEST_INVALID` | plugin.json missing or invalid | Ensure scaffold_plugin was run successfully |
| `TEST_COVERAGE_BELOW_THRESHOLD` | Test coverage < 80% | Add more tests to meet Principle II |
| `SECURITY_SCAN_FAILED` | Critical or high security findings | Fix security issues and re-validate |
| `CONSTITUTIONAL_REVIEW_FAILED` | One or more principles failed | Fix compliance issues per principle |

### Operation 4: Register Plugin

Move a validated plugin from quarantine to the `plugins/` directory, update the
plugin registry, sync commands via the plugin command bridge, initialize RL metrics,
and make the plugin immediately available for use.

**Inputs**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `plugin_name` | string | yes | Name of the plugin to register |
| `workdir` | string | yes | Working directory (repo root) |

**Procedure**:

1. Validate prerequisites:
   - Plugin must exist in quarantine at `{workdir}/.devloop/quarantine/{plugin_name}/`
     (error: `PLUGIN_NOT_FOUND`)
   - Plugin must have quarantine status `passed`
     (error: `VALIDATION_NOT_PASSED`)
   - Plugin must not already exist in `{workdir}/plugins/{plugin_name}/`
     (error: `ALREADY_REGISTERED`)
   - Plugin must have a valid `plugin.json`
     (error: `MANIFEST_INVALID`)

2. Move plugin from quarantine to plugins:
   ```bash
   mv "{workdir}/.devloop/quarantine/{plugin_name}" "{workdir}/plugins/{plugin_name}"
   ```

3. Update plugin registry:
   - If a registry file exists at `{workdir}/plugins/registry.json`, append the new plugin
   - Otherwise, the plugin is discoverable by directory presence

4. Sync commands via plugin command bridge:
   ```bash
   "{workdir}/.specify/scripts/bash/sync-plugin-commands.sh" sync
   ```
   This ensures any commands defined by the new plugin are available as slash commands.

5. Initialize RL metrics for the new plugin:
   ```json
   {
     "skill_name": "{plugin_name}",
     "model_name": "claude-opus-4-6",
     "success_rate": 0.5,
     "selection_weight": 0.5,
     "invocation_count": 0,
     "avg_tokens": 0,
     "avg_duration_ms": 0,
     "last_feedback": null,
     "ema_alpha": 0.1,
     "history": []
   }
   ```
   Write to `{workdir}/.docs/rl-metrics/skill-performance.json` (append or create entry).

6. Record registration in event log:
   ```bash
   source plugins/sdd-dev-loop/lib/event-logger.sh
   log_event "action" "$iteration" "Plugin registered: $plugin_name" \
     "{\"plugin_name\":\"$plugin_name\",\"source\":\"quarantine\",\"rl_metrics\":{\"success_rate\":0.5,\"selection_weight\":0.5}}"
   ```

7. Verify the plugin is immediately usable:
   - Check that `{workdir}/plugins/{plugin_name}/.claude-plugin/plugin.json` exists
   - Check that the skill entrypoint file exists
   - Check that test files are in place

8. Clean up quarantine remnants:
   - Remove the quarantine entry from `.devloop/quarantine/` (already moved)
   - Update any gap analysis records to status `registered`

**Outputs**: JSON registration result with `plugin_name`, `registered_at`,
`plugins_path`, `rl_metrics_initialized`, `commands_synced`.

**Error Codes**:

| Code | Trigger | Resolution |
|------|---------|------------|
| `PLUGIN_NOT_FOUND` | Plugin not found in quarantine | Run scaffold_plugin first |
| `VALIDATION_NOT_PASSED` | Plugin quarantine status is not "passed" | Run validate_quarantine and fix failures |
| `ALREADY_REGISTERED` | Plugin already exists in plugins/ directory | Plugin was already registered |
| `MANIFEST_INVALID` | plugin.json is missing or malformed | Fix plugin.json in quarantine and re-validate |

## Full Self-Extension Lifecycle

The complete lifecycle from gap detection through registration:

```
1. Gap Detection (detect_gap)
   - Read session error log
   - Group errors by pattern
   - Filter by frequency >= 3
   - Classify impact (low/medium/high)
   - Compute confidence score
   -> GapAnalysis { status: "detected" }

2. Plugin Scaffolding (scaffold_plugin)
   - Create quarantine directory structure
   - Generate plugin.json (author: "devloop-selfgen")
   - Generate SKILL.md with stubbed operations
   - Generate test stubs (contract + integration)
   - Generate agent definition
   -> PluginManifest { quarantine: "pending" }

3. Quarantine Validation (validate_quarantine)
   - Run test suite (>= 80% coverage required)
   - Run security scan (0 critical/high)
   - Run constitutional review (all 16 principles)
   -> quarantine: "passed" or "failed"

4. Plugin Registration (register_plugin)
   - Move from .devloop/quarantine/ to plugins/
   - Update plugin registry
   - Sync commands via bridge
   - Initialize RL metrics (success_rate: 0.5)
   - Record in event log
   -> Plugin available for immediate use
```

## Integration Points

### event-logger.sh (Error Analysis)

```bash
source plugins/sdd-dev-loop/lib/event-logger.sh
init_event_log "$session_id" "$session_dir"

# Read error events for gap detection
error_events=$(query_events --type "error")
error_count=$(count_events "error")

# Log self-extension events
log_event "observation" 0 "Gap detected: missing linter" '{"gap_id":"gap-123"}'
log_event "action" 0 "Plugin scaffolded: sdd-tool-linter" '{"quarantine":"pending"}'
log_event "action" 0 "Plugin registered: sdd-tool-linter" '{"status":"registered"}'
```

### rl-feedback-engine.sh (RL Initialization)

```bash
source plugins/sdd-dev-loop/lib/rl-feedback-engine.sh

# Initialize metrics for newly registered plugin
metrics_file="{workdir}/.docs/rl-metrics/{plugin_name}.json"
save_metrics '{
  "skill_name": "sdd-tool-linter",
  "success_rate": 0.5,
  "selection_weight": 0.5,
  "invocation_count": 0,
  "ema_alpha": 0.1,
  "history": []
}' "$metrics_file"
```

### sync-plugin-commands.sh (Command Bridge)

```bash
# After registration, sync commands so the new plugin is discoverable
.specify/scripts/bash/sync-plugin-commands.sh sync
```

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **II (Test-First)** | Scaffolded plugins include test stubs. Quarantine validation requires >= 80% test coverage. |
| **III (Contract-First)** | Generated SKILL.md includes input/output contract tables for every operation. |
| **VI (Git Approval)** | Self-extension NEVER performs any git operations. All work is file creation in quarantine and plugins/. |
| **XI (Input Validation)** | All inputs validated: plugin name format, gap analysis completeness, quarantine status. |
| **XV (File Organization)** | Generated plugins follow the standard plugin directory structure. |
| **XVI (Plugin-First)** | New capabilities are always created as self-contained installable plugins. |

## RL Feedback

At operation completion, the skill records its outcome:

- **Gap detected + scaffold successful** -> `collect-feedback.sh self-extend success $tokens`
- **Gap detected but no recurring pattern** -> `collect-feedback.sh self-extend success $tokens` (correct negative)
- **Scaffold or validation error** -> `collect-feedback.sh self-extend failure $tokens`
- **Registered plugin fails in subsequent use** -> `collect-feedback.sh self-extend failure $tokens` (delayed feedback)

The EMA algorithm (alpha=0.1) adjusts the skill's `selection_weight` over time:
```
selection_weight = clamp(0.9 * old_weight + 0.1 * outcome, 0.1, 1.0)
```
