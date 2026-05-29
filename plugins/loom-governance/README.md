# loom-governance

Governance core for LogicLoom. This is the constitutional governance plugin — it enforces
the 16 constitutional principles across all installed plugins and hosts the consolidated
domain-brief registry. It is **required** and **protected**: it cannot be disabled.

## Overview

Governance in LogicLoom is **hook-enforced**, not ceremony-based. Two hooks carry the load
automatically on every session:

- **UserPromptSubmit governance hook** — injects constitutional context and surfaces detected
  domains (from `plugins/loom-orchestrator-hook/config/domains.conf`) as worker-brief
  recommendations.
- **git-safety-gate PreToolUse hook** — intercepts git-mutating Bash commands and forces
  explicit user approval (Principle VI). Enforced at the tool boundary; cannot be skipped.

This plugin also owns the **domain-brief registry** (`domain-briefs/<domain>.md`), the
consolidated worker briefs that replaced the former seven `sdd-domain-*` plugins.

## Governance modes (`LOOM_GOVERNANCE_MODE`)

| Mode | Default | Behavior |
|------|---------|----------|
| `lean` | yes | Hooks enforce git approval and inject context silently; no recitation required. |
| `strict` | no | Hook enforcement plus an explicit recited compliance summary, for audit-heavy or training contexts. |

Set via the `LOOM_GOVERNANCE_MODE` environment variable. Absence ⇒ `lean`.

## Features

- **Hook-enforced constitutional governance** — context injection + git approval gate
- **git-safety-gate** requiring explicit user approval for all git mutations (Principle VI)
- **Domain detection → worker-brief routing** via `domains.conf` and `get_domain_brief`
- **Consolidated domain-brief registry** (`domain-briefs/`) — one brief per domain
- **Constitutional compliance** validation (16 principles)

## Domain-brief registry

Domains resolve to a single consolidated worker brief, pulled via `get_domain_brief
<domain>` (defined in `.logic-loom/scripts/bash/common.sh`). This registry replaced the
seven per-domain plugins.

| Domain | Brief |
|--------|-------|
| frontend | `domain-briefs/frontend.md` |
| backend | `domain-briefs/backend.md` |
| database | `domain-briefs/database.md` |
| testing | `domain-briefs/testing.md` |
| security | `domain-briefs/security.md` |
| performance | `domain-briefs/performance.md` |
| devops | `domain-briefs/devops.md` |

```bash
get_domain_brief backend     # emits the consolidated "## Task Brief" for a domain
```

The keyword → domain map lives in `plugins/loom-orchestrator-hook/config/domains.conf`
(`keyword=domain`).

## Installation

```bash
claude plugin install ./plugins/loom-governance
```

## Skills Included

| Skill | Purpose |
|-------|---------|
| message-preflight | Governance reference; documents lean/strict modes + brief routing |
| domain-detection | Keyword → domain detection and worker-brief recommendation |
| governance-preflight | Manual constitutional review for complex scenarios |
| constitutional-compliance | Full 16-principle validation |
| qa-validation | Quality assurance gates |
| file-organization | File structure validation (Principle XV) |

## Agents Included

| Agent | Purpose |
|-------|---------|
| constitutional-governance-agent | Primary governance orchestrator (default main-thread agent) |

## Hooks

| Event | Purpose |
|-------|---------|
| UserPromptSubmit | Inject constitutional context + surface domain/worker-brief recommendations |
| PreToolUse (Bash) | git-safety-gate — explicit approval for git mutations (Principle VI) |

## Constitutional Principles Enforced

All 16 principles (I-XVI) from constitution v3.1.0:
- I: Library-First Architecture
- II: Test-First Development (**IMMUTABLE**)
- III: Contract-First Design
- IV: Idempotent Operations
- V: Progressive Enhancement
- VI: Git Operation Approval (**CRITICAL**, hook-enforced)
- VII: Observability
- VIII: Documentation Synchronization
- IX: Dependency Management
- X: Agent Delegation Protocol (**CRITICAL**)
- XI: Input Validation & Output Sanitization
- XII: Design System Compliance
- XIII: Feature Access Control
- XIV: AI Model Selection (default: Opus 4.8 flagship)
- XV: File Organization
- XVI: Plugin-First Architecture

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-06 | Initial plugin release |
| — | 2026-05 | Reframed as governance core: hook-enforced lean/strict modes; FR-707 ceremony removed; domain-brief registry added (replaced sdd-domain-* plugins); RL metrics removed; constitution v3.1.0 |
