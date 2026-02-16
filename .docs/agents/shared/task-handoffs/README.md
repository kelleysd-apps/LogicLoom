# Task Handoffs - Shared Agent Context

This directory contains task handoff records for multi-agent coordination.

## Purpose

When tasks are transferred between agents, context must be preserved. This directory serves as the shared space for:

1. **Context Transfers** - State and context passed between agents
2. **Handoff Records** - Audit trail of task delegation
3. **Coordination Notes** - Multi-agent synchronization data

## Structure

```
task-handoffs/
├── README.md                    # This file
├── context-transfers.md         # Active context transfers
└── handoff-log.md              # Historical handoff records
```

## Handoff Protocol

When transferring a task to another agent:

1. **Document Current State**
   - What has been completed
   - What remains to be done
   - Any blockers or context needed

2. **Record in context-transfers.md**
   ```markdown
   ## Transfer: [Task ID]
   - **From**: [source-agent]
   - **To**: [target-agent]
   - **Date**: [timestamp]
   - **Context**: [relevant context]
   - **Remaining Work**: [what's left]
   ```

3. **Update via TaskUpdate**
   - Mark your task as completed (if your part is done)
   - Note the handoff in the task description

4. **Notify Target Agent**
   - Target agent should read this file when resuming

## Integration with SSOT

This directory is part of the SSOT Task Architecture:

- **Level 1**: `specs/###-feature/tasks.md` (Project SSOT)
- **Level 2**: Task Tools (Session SSOT)
- **Level 3**: `.docs/agents/*/decisions/tasks/` (Agent history)
- **Shared**: This directory (Cross-agent coordination)

## References

- Policy: `.docs/policies/todo-architecture-policy.md`
- Constitution: Task Management (SSOT Architecture) section
- Tasks Agent: `.claude/agents/product/tasks-agent.md`
