---
name: session-report
version: 0.1.0
description: |
  Session report generator skill — produces comprehensive post-session reports from the
  JSONL event log. Aggregates iteration data, quality grade trajectory, tribunal decisions,
  resource consumption per model, code changes, and RL feedback into a structured markdown
  report for human review and audit.
allowed-tools: Read, Write, Bash, Grep, Glob
triggers:
  - session-complete
  - session-report-generate
category: analytics
constitutional_principles:
  - VII   # Observability: full session transparency via structured reports
  - VIII  # Documentation Sync: report reflects actual session data from event log
  - XIV   # AI Model Selection: per-model resource tracking in reports
  - XVI   # Plugin-First: capability organized as installable plugin
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# Session Report Skill

## Overview

The session-report skill generates comprehensive post-session reports from the structured
JSONL event log produced during a dev-loop session. It is invoked by the dev-loop-orchestrator
at session end (after termination), and transforms raw event data into a human-readable
markdown report suitable for review, audit, and retrospective analysis.

The report provides a complete picture of what happened during the autonomous development
session: how many iterations ran, how quality evolved, what the tribunal decided, how much
each model cost, what code changed, why the loop terminated, and what RL feedback was recorded.

## Invocation

Called by the dev-loop-orchestrator during post-loop finalization (Step 6 of core-loop),
after the termination reason is determined:

```
Session Terminated -> dev-loop-orchestrator -> session-report skill -> markdown report
```

The skill is invoked exactly once per session, after all events have been logged and the
event log has been finalized via `close_log()`.

## Inputs

| Input | Type | Source | Description |
|-------|------|--------|-------------|
| `session_id` | string | Session state | Unique session identifier (e.g., `devloop-20260207-143022-abc123`) |
| `event_log_path` | string | Session directory | Path to the `events.jsonl` file for this session |

The skill reads all data from the event log. No additional inputs are required because
the event log is the single source of truth for the session (event sourcing pattern).

## Outputs

| Output | Type | Destination | Description |
|--------|------|-------------|-------------|
| Session report | markdown | `{session_dir}/session-report.md` | Formatted report using `templates/session-report.md` |
| Report JSON | JSON | stdout | Structured data used to populate the template |

## Procedure

### Step 1: Load Event Log

Read the JSONL event log from `event_log_path`. Parse all events into memory.
If the file is empty, produce a minimal report with zero values.

```bash
source plugins/sdd-dev-loop/lib/event-logger.sh
report_json=$(generate_session_report "$session_id" "$session_dir")
```

### Step 2: Extract Report Data

From the event log, extract and aggregate:

1. **Summary**: session_id, feature description (from first thought event), branch name
2. **Iteration count**: Maximum iteration number across all events
3. **Quality grade trajectory**: Array of composite grades from `grade` events, one per iteration
4. **Tribunal decisions**: Array of ballot details from `vote` events, including verdict and consensus
5. **Resource consumption per model**: Aggregate tokens and cost from `tool_invocation` event metadata
6. **Wall-clock time**: Difference between first and last event timestamps
7. **Code changes summary**: Aggregate files_modified, lines_added, lines_removed from `action` event metadata
8. **Termination reason**: Extracted from the final `decision` event with `next_action=terminate`
9. **RL feedback**: Skills and models used, final outcome encoding

### Step 3: Populate Template

Load the session report template from `templates/session-report.md` and replace all
placeholders with the extracted data.

### Step 4: Write Report

Write the populated markdown report to `{session_dir}/session-report.md`.

## Report Sections

The generated report includes the following sections:

| Section | Content | Data Source |
|---------|---------|-------------|
| **Summary** | Session ID, feature description, branch | Event log metadata |
| **Iteration Count** | Total iterations executed | Max iteration from events |
| **Grade Trajectory** | Per-iteration quality scores with pass/fail and delta | `grade` events |
| **Tribunal Decisions** | Per-round verdict, consensus level, weighted score | `vote` events |
| **Resource Consumption** | Tokens and cost broken down by model | `tool_invocation` events |
| **Code Changes** | Files modified, lines added/removed | `action` events |
| **Wall-Clock Time** | Total session duration | First/last event timestamps |
| **Termination Reason** | Why the loop stopped | Final `decision` event |
| **RL Feedback** | Skills updated, outcome, metric changes | Session outcome + event analysis |

## Integration

### With Event Logger

The session-report skill depends on the event-logger library for data extraction:

| Function | Purpose |
|----------|---------|
| `generate_session_report()` | Primary data extraction from event log |
| `extract_rl_signals()` | RL feedback data for the report |
| `generate_audit_trail()` | Optional audit appendix |

### With Templates

The report is rendered using `plugins/sdd-dev-loop/templates/session-report.md`,
which provides the markdown structure with placeholders.

### With Core Loop

The core-loop skill triggers session-report generation in its Step 6 (Post-Loop Finalization).

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **VII (Observability)** | Report provides complete transparency into autonomous session behavior. Every iteration, grade, decision, and resource expenditure is documented. |
| **VIII (Documentation Sync)** | Report is generated from the authoritative event log, ensuring documentation matches actual session behavior. |
| **XIV (AI Model Selection)** | Per-model resource consumption is tracked and reported, enabling cost-aware model selection decisions. |
| **XVI (Plugin-First)** | Session reporting is a discrete, installable skill within the sdd-dev-loop plugin. |
