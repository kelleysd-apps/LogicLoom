---
description: Monitor and apply updates from Claude Code releases and upstream sdd-agentic-framework repository
---

Execute the framework-updater skill to keep your project synchronized with the latest framework improvements.

## What This Does

Invokes the `/update-framework` skill located at `.claude/skills/integration/framework-updater/SKILL.md` which provides:

- Automated checks for Claude Code CLI updates
- Upstream framework synchronization from sdd-agentic-framework
- Constitutional version tracking and updates
- Safe merge of framework improvements
- Backup and rollback capabilities
- Impact assessment and validation

## When to Use

Use `/update-framework` when:
- Monthly maintenance (recommended: first Monday of each month)
- Security patches are announced
- New constitutional principles are published
- You need bug fixes from upstream framework
- You want to adopt new agent patterns or skills
- Experiencing issues that may be fixed in newer versions

## Trigger Keywords

This command is automatically invoked when you mention:
- "update framework", "sync framework", "upgrade framework"
- "check for updates", "latest claude code", "new framework version"
- "upstream changes", "sdd-agentic-framework updates"
- "constitution update", "new principles"

## Usage

```bash
/update-framework
```

The skill will guide you through:

1. **Pre-Update Assessment** - Document current state, identify active work
2. **Check Claude Code CLI** - Query GitHub for latest releases
3. **Check SDD Framework** - Fetch upstream changes from sdd-agentic-framework
4. **Impact Analysis** - Assess breaking changes, compatibility, benefits
5. **User Approval Gate** - Present findings, request explicit approval (Principle VI)
6. **Backup Current State** - Create safety backup branch
7. **Apply CLI Updates** - Upgrade Claude Code to latest version
8. **Apply Framework Updates** - Selective merge of upstream changes
9. **Reconcile Customizations** - Ensure project-specific files still work
10. **Validation Suite** - Run constitutional-check.sh and other validators
11. **Test Updates** - Isolated environment testing
12. **Update Documentation** - CHANGELOG, version references, migration notes
13. **Commit Changes** - Git commit with detailed message (requires approval)
14. **Post-Update Verification** - Final production testing
15. **Cleanup** - Remove temp files, document rollback path

## Constitutional Compliance

This skill complies with:
- **Principle VI (Git Operations)**: NEVER commits without explicit user approval
- **Principle VII (Observability)**: Detailed logging and reporting at each step
- **Principle VIII (Documentation Sync)**: Updates docs to match framework changes
- **Principle IX (Dependency Management)**: Explicitly manages CLI and framework versions
- **Principle X (Agent Delegation)**: Delegates to framework-sync-agent for execution

## Related Commands

- `/create-agent` - May use updated templates after framework sync
- `/create-skill` - May use updated templates after framework sync
- `/specify`, `/plan`, `/tasks` - Behavior may change if constitution updated

## Skill Reference

Full documentation: `.claude/skills/integration/framework-updater/SKILL.md`

---

**Agent**: framework-sync-agent
**Category**: Integration
**Status**: Active
