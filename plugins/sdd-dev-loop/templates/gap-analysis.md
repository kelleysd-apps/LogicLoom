# GapAnalysis & PluginManifest Entity Model

> Entity template for self-extension gap detection, plugin scaffolding, quarantine validation,
> and plugin registration in the dev-loop plugin. Used when the self-extend skill detects
> recurring capability gaps and autonomously creates new tool plugins.

## Schema Version

`1.0`

## Overview

A GapAnalysis captures a detected capability gap from recurring error patterns in the
dev-loop session event log. When a specific error or missing-tool pattern recurs >= 3
times across sessions, the self-extension system creates a GapAnalysis record, scaffolds
a new plugin in quarantine, validates it against constitutional requirements, and
registers it for use.

The entity combines two related schemas:
- **GapAnalysis**: Detection of missing capabilities from error log analysis
- **PluginManifest**: Metadata for self-generated plugins in quarantine lifecycle

## JSON Schema: GapAnalysis

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "GapAnalysis entity — Detected capability gap from recurring session error patterns",
  "schema_version": "1.0",

  "gap_id": "gap-20260207-153000-missing-linter",
  "_comment_gap_id": "Unique gap identifier (gap-{timestamp}-{slug}). Auto-generated on detection.",

  "session_id": "devloop-20260207-143022-abc123",
  "_comment_session_id": "Session in which the gap was most recently detected.",

  "missing_capability": "ESLint configuration validation",
  "_comment_missing_capability": "Natural language description of the capability that is missing. Derived from error log pattern analysis. MUST be non-empty.",

  "frequency": 5,
  "_comment_frequency": "Number of times this error pattern has been observed across sessions. MUST be >= 3 to trigger gap detection. Integer.",

  "impact": "medium",
  "_comment_impact": "Assessed impact of the missing capability on dev-loop outcomes.",
  "_valid_impact_values": ["low", "medium", "high"],
  "_impact_definitions": {
    "low": "Gap causes minor inconvenience but workarounds exist. Does not block iteration.",
    "medium": "Gap causes iteration failures or quality grade degradation. Workarounds are manual.",
    "high": "Gap causes session termination or critical quality failures. No effective workaround."
  },

  "suggested_plugin_name": "sdd-tool-eslint-validator",
  "_comment_suggested_plugin_name": "Proposed name for the plugin to address the gap. MUST follow the 'sdd-tool-{name}' naming convention. Auto-generated from missing_capability analysis.",
  "_naming_convention": "All self-generated plugins MUST use the 'sdd-tool-' prefix to distinguish them from hand-authored plugins.",

  "confidence": 0.78,
  "_comment_confidence": "Confidence score that this gap is real and addressable by a new plugin. Range: [0.0, 1.0]. Computed from frequency, impact, and pattern consistency.",
  "_confidence_formula": "confidence = min(1.0, (frequency / 10) * 0.4 + impact_weight * 0.4 + pattern_consistency * 0.2)",
  "_confidence_weights": {
    "frequency_weight": "0.4 — Higher frequency increases confidence (capped at frequency=10)",
    "impact_weight": "0.4 — low=0.3, medium=0.6, high=1.0",
    "pattern_consistency": "0.2 — How consistent the error pattern is (0.0=random, 1.0=identical errors)"
  },

  "error_pattern": "TOOL_NOT_FOUND:eslint.*config|eslint.*validate",
  "_comment_error_pattern": "Regex pattern matching the recurring errors in the event log. Used to identify and group related errors.",

  "sample_errors": [
    {
      "session_id": "devloop-20260205-100000-xyz",
      "event_id": "evt-20260205-100500-012",
      "error_message": "TOOL_NOT_FOUND: eslint config validation not available",
      "timestamp": "2026-02-05T10:05:00Z"
    },
    {
      "session_id": "devloop-20260206-090000-def",
      "event_id": "evt-20260206-091200-034",
      "error_message": "TOOL_NOT_FOUND: eslint validate config failed - no handler",
      "timestamp": "2026-02-06T09:12:00Z"
    },
    {
      "session_id": "devloop-20260207-143022-abc123",
      "event_id": "evt-20260207-144500-056",
      "error_message": "TOOL_NOT_FOUND: eslint configuration checker unavailable",
      "timestamp": "2026-02-07T14:45:00Z"
    }
  ],
  "_comment_sample_errors": "Representative sample of the recurring errors (up to 5). Used for human review and pattern verification.",

  "detected_at": "2026-02-07T15:30:00Z",
  "_comment_detected_at": "Timestamp when the gap was first detected (ISO 8601).",

  "status": "detected",
  "_comment_status": "Lifecycle status of the gap analysis.",
  "_valid_status_values": ["detected", "scaffolding", "quarantine", "validated", "registered", "dismissed"],
  "_status_definitions": {
    "detected": "Gap identified from error log analysis. Awaiting scaffold decision.",
    "scaffolding": "Plugin scaffold is being generated in quarantine.",
    "quarantine": "Plugin scaffolded and placed in .devloop/quarantine/. Awaiting validation.",
    "validated": "Plugin passed all quarantine validation checks. Ready for registration.",
    "registered": "Plugin moved from quarantine to plugins/ and available for use.",
    "dismissed": "Gap determined to be false positive or not addressable. No action taken."
  }
}
```

## JSON Schema: PluginManifest (Self-Generated)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "PluginManifest entity — Metadata for a self-generated plugin created by the dev-loop self-extension system",
  "schema_version": "1.0",

  "name": "sdd-tool-eslint-validator",
  "_comment_name": "Plugin name. MUST use the 'sdd-tool-' prefix for all self-generated plugins. Lowercase, hyphen-separated.",
  "_naming_rule": "Pattern: sdd-tool-{descriptive-name}. The sdd-tool- prefix is MANDATORY for self-generated plugins.",

  "version": "0.1.0",
  "_comment_version": "Semantic version. All self-generated plugins start at 0.1.0.",

  "description": "ESLint configuration validation tool for dev-loop iterations",
  "_comment_description": "Human-readable description of the plugin's purpose. MUST be non-empty.",

  "author": "devloop-selfgen",
  "_comment_author": "Author identifier. MUST be 'devloop-selfgen' for all self-generated plugins. This distinguishes machine-created plugins from human-authored ones.",

  "entrypoint": "skills/eslint-validator/SKILL.md",
  "_comment_entrypoint": "Path to the primary skill file within the plugin directory.",

  "parameters": {
    "config_path": {
      "type": "string",
      "required": false,
      "default": ".eslintrc.json",
      "description": "Path to ESLint configuration file"
    }
  },
  "_comment_parameters": "Input parameters the plugin accepts. Defined per-plugin based on the capability gap.",

  "permissions_required": ["Read", "Bash"],
  "_comment_permissions_required": "Minimum permissions the plugin needs to operate. Self-generated plugins default to minimal permissions (Read, Bash). Elevated permissions require explicit constitutional review.",

  "created_by_session": "devloop-20260207-143022-abc123",
  "_comment_created_by_session": "Session ID that triggered the plugin creation. Enables traceability from gap detection to plugin generation.",

  "gap_id": "gap-20260207-153000-missing-linter",
  "_comment_gap_id": "Reference to the GapAnalysis that motivated this plugin.",

  "quarantine_lifecycle": {
    "status": "pending",
    "_comment_status": "Current quarantine status.",
    "_valid_status_values": ["pending", "testing", "passed", "failed"],
    "_status_lifecycle": {
      "pending": "Plugin scaffolded, awaiting validation. Initial state after scaffold_plugin().",
      "testing": "Validation suite running: tests, security scan, constitutional review.",
      "passed": "All validation checks passed. Ready for register_plugin().",
      "failed": "One or more validation checks failed. Plugin remains in quarantine. May be retried or dismissed."
    },

    "validation_results": {
      "test_coverage": {
        "status": "pending",
        "coverage_percent": null,
        "required_percent": 80,
        "_comment": "Test suite must achieve >= 80% coverage (Principle II)."
      },
      "security_scan": {
        "status": "pending",
        "critical_count": null,
        "high_count": null,
        "required": "0 critical, 0 high",
        "_comment": "Security scan must find 0 critical and 0 high severity issues."
      },
      "constitutional_review": {
        "status": "pending",
        "principles_checked": 16,
        "principles_passed": null,
        "required": "all 16 principles must pass",
        "_comment": "Each of the 16 constitutional principles is checked for compliance.",
        "principle_results": {
          "I_library_first": null,
          "II_test_first": null,
          "III_contract_first": null,
          "IV_idempotency": null,
          "V_progressive_enhancement": null,
          "VI_git_approval": null,
          "VII_observability": null,
          "VIII_documentation_sync": null,
          "IX_dependency_management": null,
          "X_agent_delegation": null,
          "XI_input_validation": null,
          "XII_design_system": null,
          "XIII_access_control": null,
          "XIV_ai_model_selection": null,
          "XV_file_organization": null,
          "XVI_plugin_first": null
        },
        "_comment_principle_results": "Each principle maps to true (pass), false (fail), or null (not yet checked)."
      }
    },
    "_comment_validation_results": "Detailed results of each quarantine validation check. All checks must pass for the plugin to achieve 'passed' status."
  },

  "rl_metrics": {
    "success_rate": 0.5,
    "_comment_success_rate": "Initial neutral prior. Updated via EMA after each invocation.",
    "selection_weight": 0.5,
    "_comment_selection_weight": "Initial routing weight. Derived from success_rate via clamp(rate, 0.1, 1.0).",
    "invocation_count": 0,
    "_comment_invocation_count": "Starts at 0. Incremented on each use."
  },
  "_comment_rl_metrics": "Default RL metrics for newly created plugins. Neutral priors allow UCB1 exploration bonus to favor trying the new plugin."
}
```

## Quarantine Lifecycle

```
scaffold_plugin()          validate_quarantine()        register_plugin()
     |                           |                            |
     v                           v                            v
  pending -----> testing -----> passed -----> registered (in plugins/)
                    |
                    v
                  failed (remains in .devloop/quarantine/)
```

### State Transitions

| From | To | Trigger | Condition |
|------|----|---------|-----------|
| *(new)* | `pending` | `scaffold_plugin()` | Plugin scaffolded in `.devloop/quarantine/{name}/` |
| `pending` | `testing` | `validate_quarantine()` starts | Validation suite begins execution |
| `testing` | `passed` | `validate_quarantine()` completes | All checks pass: tests >= 80%, security 0 critical/high, all 16 principles |
| `testing` | `failed` | `validate_quarantine()` completes | Any check fails |
| `passed` | `registered` | `register_plugin()` | Plugin moved from quarantine to `plugins/`, registry updated, RL initialized |
| `detected`/`failed` | `dismissed` | Manual review | Gap determined to be false positive or unfixable |

## Constitutional Review Fields

The constitutional review checks all 16 principles for the self-generated plugin:

| Principle | Check Description |
|-----------|-------------------|
| I (Library-First) | Plugin reuses existing libraries where possible |
| II (Test-First) | Plugin includes test stubs with >= 80% path coverage |
| III (Contract-First) | Plugin defines clear input/output contracts |
| IV (Idempotency) | Plugin operations are idempotent (safe to re-run) |
| V (Progressive Enhancement) | Plugin degrades gracefully if dependencies unavailable |
| VI (Git Approval) | Plugin performs NO autonomous git operations |
| VII (Observability) | Plugin logs events to the session event log |
| VIII (Documentation Sync) | Plugin includes SKILL.md documentation |
| IX (Dependency Management) | Plugin declares all dependencies in plugin.json |
| X (Agent Delegation) | Plugin delegates specialist work to specialist agents |
| XI (Input Validation) | Plugin validates all inputs before processing |
| XII (Design System) | Plugin follows framework design conventions |
| XIII (Access Control) | Plugin declares required permissions in manifest |
| XIV (AI Model Selection) | Plugin specifies model requirements if applicable |
| XV (File Organization) | Plugin follows standard plugin directory structure |
| XVI (Plugin-First) | Plugin is a self-contained installable unit |

## RL Metrics Defaults

All self-generated plugins start with neutral RL priors:

```json
{
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

These neutral priors ensure:
- The plugin is not disadvantaged compared to established plugins
- UCB1 exploration bonus (`sqrt(2 * ln(total) / 0)` = infinity) ensures the new plugin is tried
- After initial invocations, the EMA converges toward the true performance rate

## Entity Relationships

```
DevLoopSession (1) ----< (N) GapAnalysis
     |                           |
     |                           |--- error_pattern (regex)
     |                           |--- sample_errors[] (evidence)
     |                           |--- suggested_plugin_name
     |                           |
     |                           v
     |                     PluginManifest (1)
     |                           |
     |                           |--- quarantine_lifecycle
     |                           |    |--- validation_results
     |                           |    |    |--- test_coverage
     |                           |    |    |--- security_scan
     |                           |    |    |--- constitutional_review
     |                           |
     |                           |--- rl_metrics (initialized defaults)
     |
     |--- gap_analyses[] references gap_id
```

## Scaffolded Plugin Directory Structure

When `scaffold_plugin()` creates a new plugin in quarantine:

```
.devloop/quarantine/{sdd-tool-name}/
  .claude-plugin/
    plugin.json                # PluginManifest (author: "devloop-selfgen")
  skills/
    {tool-name}/
      SKILL.md                 # Skill definition with operations
  agents/
    {tool-name}-agent.md       # Agent definition (if needed)
  tests/
    contract/
      test_{tool_name}.sh      # Contract test stubs (TDD)
    integration/
      test_{tool_name}_e2e.sh  # Integration test stubs
  lib/                         # Library files (if needed)
  config/                      # Configuration files (if needed)
```

## Validation Rules

```json
[
  "gap_id MUST be non-empty string matching pattern gap-{timestamp}-{slug}",
  "session_id MUST reference a valid DevLoopSession",
  "missing_capability MUST be non-empty string",
  "frequency MUST be integer >= 3 (detection threshold)",
  "impact MUST be one of: low, medium, high",
  "suggested_plugin_name MUST match pattern sdd-tool-{name}",
  "suggested_plugin_name MUST be lowercase with hyphens only",
  "confidence MUST be in range [0.0, 1.0]",
  "error_pattern MUST be a valid regex",
  "sample_errors MUST contain at least 1 entry",
  "sample_errors[*].error_message MUST be non-empty string",
  "detected_at MUST be valid ISO 8601",
  "status MUST be one of: detected, scaffolding, quarantine, validated, registered, dismissed",

  "PluginManifest.name MUST start with 'sdd-tool-'",
  "PluginManifest.version MUST be '0.1.0' for new self-generated plugins",
  "PluginManifest.author MUST be 'devloop-selfgen'",
  "PluginManifest.entrypoint MUST point to an existing SKILL.md file",
  "PluginManifest.permissions_required MUST be a non-empty array",
  "PluginManifest.created_by_session MUST reference a valid session",
  "PluginManifest.gap_id MUST reference a valid GapAnalysis",

  "quarantine_lifecycle.status MUST be one of: pending, testing, passed, failed",
  "quarantine_lifecycle.validation_results.test_coverage.required_percent MUST be 80",
  "quarantine_lifecycle.validation_results.security_scan.required MUST be '0 critical, 0 high'",
  "quarantine_lifecycle.validation_results.constitutional_review.principles_checked MUST be 16",

  "rl_metrics.success_rate MUST be 0.5 for new plugins",
  "rl_metrics.selection_weight MUST be 0.5 for new plugins",
  "rl_metrics.invocation_count MUST be 0 for new plugins"
]
```

## Usage

### Detecting a Gap

```bash
# Invoked by self-extend skill when session errors are analyzed
detect_gap \
  --session-dir "$SESSION_DIR" \
  --min-frequency 3
# Returns: GapAnalysis JSON if gap found, empty if no recurring pattern
```

### Scaffolding a Plugin

```bash
# Generate plugin in quarantine
scaffold_plugin \
  --gap-id "$GAP_ID" \
  --plugin-name "sdd-tool-eslint-validator" \
  --workdir "$WORKDIR"
# Creates: .devloop/quarantine/sdd-tool-eslint-validator/
```

### Validating in Quarantine

```bash
# Run full validation suite
validate_quarantine \
  --plugin-name "sdd-tool-eslint-validator" \
  --workdir "$WORKDIR"
# Returns: validation results JSON with pass/fail per check
```

### Registering a Plugin

```bash
# Move validated plugin to plugins/
register_plugin \
  --plugin-name "sdd-tool-eslint-validator" \
  --workdir "$WORKDIR"
# Moves to: plugins/sdd-tool-eslint-validator/
# Updates: plugin registry, syncs commands, initializes RL metrics
```
