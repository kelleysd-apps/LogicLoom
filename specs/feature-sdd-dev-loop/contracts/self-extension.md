# Contract: Self-Extension

## Detect Gap
```
POST /self-extension/detect-gap
Input:  {
  session_id: string,
  error_log: Array<{
    iteration: number,
    error_type: string,
    error_message: string,
    tool_attempted: string,
    failure_reason: string
  }>
}
Output: {
  gap_detected: boolean,
  gap_analysis: {
    missing_capability: string,       // description of what's needed
    frequency: number,                // times this gap was hit
    impact: "low" | "medium" | "high",
    suggested_plugin_name: string,
    confidence: number                // 0.0-1.0
  } | null,
  recurring_patterns: Array<{
    pattern: string,
    occurrence_count: number
  }>
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - EMPTY_ERROR_LOG: No errors provided
Side Effects:
  - Records gap detection in event log
```

## Scaffold Plugin
```
POST /self-extension/scaffold
Input:  {
  capability_description: string,
  suggested_name: string,
  session_id: string
}
Output: {
  plugin_path: string,                // quarantine location
  manifest: PluginManifest,
  files_created: Array<{
    path: string,
    type: "agent" | "skill" | "command" | "test" | "manifest"
  }>,
  scaffold_status: "complete" | "partial",
  warnings: string[]
}
Errors:
  - INVALID_NAME: Plugin name violates naming conventions
  - CAPABILITY_TOO_VAGUE: Cannot generate from description
  - SCAFFOLD_FAILED: Error during file generation
  - DISK_SPACE_INSUFFICIENT: Not enough space for plugin
Side Effects:
  - Creates plugin directory at .dev-loop/quarantine/{plugin_name}/
  - Generates manifest, skill, agent, command, and test files
  - Records scaffolding in event log
```

## Quarantine Validate
```
POST /self-extension/validate
Input:  {
  plugin_path: string
}
Output: {
  validation_passed: boolean,
  validation_results: {
    structure_check: {
      passed: boolean,
      manifest_present: boolean,
      required_files_present: boolean,
      errors: string[]
    },
    security_scan: {
      passed: boolean,
      vulnerabilities: Array<{
        severity: "critical" | "high" | "medium" | "low",
        description: string,
        location: string
      }>,
      suspicious_patterns: string[]
    },
    test_coverage: {
      passed: boolean,
      coverage_percent: number,
      threshold: number               // 80%
    },
    constitutional_review: {
      passed: boolean,
      principles_evaluated: Array<{
        principle: string,
        compliant: boolean,
        notes: string
      }>,
      violations: string[],
      reviewer_model: string
    }
  },
  overall_status: "approved" | "rejected" | "needs_review",
  rejection_reasons: string[]
}
Errors:
  - PLUGIN_NOT_FOUND: Plugin path doesn't exist
  - VALIDATION_TIMEOUT: Validation exceeded time limit
  - SCAN_TOOLS_UNAVAILABLE: Required security tools missing
Side Effects:
  - Runs test suite in isolated container
  - Executes security scanners
  - Queries AI for constitutional review
  - Records validation results in event log
```

## Register Plugin
```
POST /self-extension/register
Input:  {
  plugin_manifest: PluginManifest,
  validation_results: object,         // from Quarantine Validate
  session_id: string
}
Output: {
  registered: boolean,
  plugin_name: string,
  plugin_version: string,
  installation_path: string,          // moved from quarantine to plugins/
  capabilities_available: string[],   // commands, agents, skills
  registration_time: timestamp
}
Errors:
  - VALIDATION_NOT_PASSED: Plugin failed validation
  - ALREADY_REGISTERED: Plugin name already exists
  - MANIFEST_INVALID: Manifest schema validation failed
  - REGISTRATION_FAILED: Error moving from quarantine
Side Effects:
  - Moves plugin from quarantine to plugins/ directory
  - Updates plugin registry
  - Syncs commands to .claude/commands/
  - Records RL metrics for new plugin
  - Triggers plugin-bridge sync
  - Records registration in event log
  - Makes plugin available for immediate use
```
