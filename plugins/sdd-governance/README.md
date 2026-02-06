# sdd-governance

Constitutional governance enforcement plugin for the SDD Agentic Framework.

## Overview

This plugin enforces 15 constitutional principles across all installed SDD plugins. It is **required** and **protected** — it cannot be disabled.

## Features

- **4-step pre-flight compliance check** on every user message (UserPromptSubmit hook)
- **Git safety gate** requiring explicit user approval for all git operations (PreToolUse hook)
- **Domain detection** for automatic agent delegation routing
- **Per-plugin RL metrics** capture and tracking (PostToolUse hook)
- **Constitutional compliance** validation

## Installation

```bash
claude plugin install ./plugins/sdd-governance
# or from marketplace:
claude plugin install sdd-governance@sdd-marketplace
```

## Skills Included

| Skill | Purpose |
|-------|---------|
| message-preflight | 4-step compliance check on every message |
| constitutional-compliance | Full 15-principle validation |
| domain-detection | Keyword-based domain routing |
| governance-preflight | Pre-flight governance protocol |
| qa-validation | Quality assurance gates |
| file-organization | File structure validation (Principle XV) |

## Agents Included

| Agent | Purpose |
|-------|---------|
| constitutional-governance-agent | Primary governance orchestrator |

## Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| UserPromptSubmit | governance-preflight.cjs | Pre-flight compliance |
| PreToolUse (Bash) | git-safety-gate.sh | Git operation approval |
| PostToolUse | rl-metrics-capture.sh | RL metrics tracking |

## Constitutional Principles Enforced

All 15 principles (I-XV) from constitution v2.0.0:
- I: Library-First Architecture
- II: Test-First Development
- III: Contract-First Design
- IV: Idempotent Operations
- V: Progressive Enhancement
- VI: Git Operation Approval (**CRITICAL**)
- VII: Observability
- VIII: Documentation Synchronization
- IX: Dependency Management
- X: Agent Delegation Protocol (**CRITICAL**)
- XI: Input Validation & Output Sanitization
- XII: Design System Compliance
- XIII: Feature Access Control
- XIV: AI Model Selection
- XV: File Organization

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-06 | Initial plugin release |
