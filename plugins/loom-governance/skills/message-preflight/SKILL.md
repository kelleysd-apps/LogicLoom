---
name: message-preflight
version: 3.1.0
description: |
  Reference documentation for LogicLoom message pre-flight governance. Governance is
  hook-enforced: the UserPromptSubmit governance hook injects constitutional context and
  the git-safety-gate PreToolUse hook forces explicit approval on git mutations — neither
  depends on a recited ceremony. This skill documents the OPTIONAL strict-mode recitation
  (LOOM_GOVERNANCE_MODE=strict) and the domain-brief routing reference used to recommend
  consolidated worker briefs.
category: validation
triggers:
  - "compliance check"
  - "constitutional compliance"
  - "preflight"
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Message Pre-Flight (Governance Reference)

## Governance is hook-enforced

Pre-flight governance in LogicLoom no longer relies on a mandatory recited ceremony.
Two hooks carry the load automatically:

- **UserPromptSubmit governance hook** — injects constitutional context and domain
  recommendations on every message.
- **git-safety-gate PreToolUse hook** — intercepts git-mutating Bash commands and forces
  explicit user approval (Principle VI). This is enforced at the tool boundary; it cannot
  be skipped by forgetting a checklist.

Because enforcement lives in the hooks, this skill is a **reference**, not a gate. It
documents how to reason about a message and — when running in strict mode — how to recite
the compliance summary.

## Governance modes (`LOOM_GOVERNANCE_MODE`)

| Mode | Default | Behavior |
|------|---------|----------|
| `lean` | yes | Hooks enforce git approval and inject context silently. No recitation required. Reason about domains/git inline and proceed. |
| `strict` | no | In addition to hook enforcement, recite the compliance summary (below) before acting, for audit-heavy or training contexts. |

Set the mode via the environment variable `LOOM_GOVERNANCE_MODE`. Absence ⇒ `lean`.

## How to reason about a message

1. **Constitution** — work under the 16 principles (v3.1.0). The load-bearing ones in
   day-to-day flow: II (Test-First, IMMUTABLE), VI (Git Approval — hook-enforced),
   X (Agent Delegation), XVI (Plugin-First).
2. **Domain(s)** — note any technical domains present (frontend, backend, database,
   testing, security, performance, devops). The governance hook surfaces these from
   `plugins/loom-orchestrator-hook/config/domains.conf` (`keyword=domain`).
3. **Delegation** — pick where the work goes:
   - 0 domains → may execute directly.
   - 1 domain → `/swarm explore` (primary) or a single consolidated worker brief.
   - 2+ domains → `/swarm` (primary) or team orchestration (legacy).
4. **Worker briefs** — when delegating to a swarm/team worker, pull the consolidated
   brief from the domain-brief registry rather than a per-domain plugin:

   ```bash
   # .logic-loom/scripts/bash/common.sh
   get_domain_brief backend     # emits the consolidated Task Brief for a domain
   ```

   Registry source: `plugins/loom-governance/domain-briefs/<domain>.md`. This replaced the
   former seven `sdd-domain-*` plugins; one registry, one brief per domain.

## Optional strict-mode compliance summary

Only required when `LOOM_GOVERNANCE_MODE=strict`. Format:

```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | /swarm <mode> | worker brief: <domain>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

Examples:

```
Constitutional Compliance Check:
- Domain(s): none
- Delegation: direct execution
- Git operations: none planned
- Proceeding with: answering question about file structure
```

```
Constitutional Compliance Check:
- Domain(s): single: database
- Delegation: worker brief: database
- Git operations: none planned
- Proceeding with: schema work via get_domain_brief database
```

```
Constitutional Compliance Check:
- Domain(s): multi: frontend, backend, database
- Delegation: /swarm
- Git operations: will request approval
- Proceeding with: coordinating a full-stack swarm
```

## Git operations (Principle VI)

The git-safety-gate hook intercepts git mutations and requires explicit user approval —
branch create/switch/delete, commit, push, pull, merge, rebase, reset, stash. This holds
in both lean and strict modes; there is nothing to remember, because the hook blocks the
command until you ask.

## References

- Constitution v3.1.0: `.logic-loom/memory/constitution.md`
- Domain-brief registry: `plugins/loom-governance/domain-briefs/`
- Domain keyword map: `plugins/loom-orchestrator-hook/config/domains.conf`
- `get_domain_brief()`: `.logic-loom/scripts/bash/common.sh`
- Domain Detection skill: `plugins/loom-governance/skills/domain-detection/SKILL.md`
