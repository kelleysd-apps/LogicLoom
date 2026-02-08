---
name: tasks
description: Generate dependency-ordered tasks.md from implementation plan.
model: opus
---

# /tasks Command

**AGENT REQUIREMENT**: This command should be executed by the tasks-agent.

**If you are NOT the tasks-agent**, delegate immediately:
```
Use the Task tool to invoke tasks-agent:
- description: "Execute /tasks command"
- prompt: "Execute the /tasks command for this feature. Arguments: $ARGUMENTS"
```

## Execution Instructions (for tasks-agent)

### Step 1: Validate Prerequisites
Run: `.specify/scripts/bash/check-task-prerequisites.sh --json`
Ensure spec.md and plan.md exist.

### Step 2: Analyze Plan Artifacts
Read: plan.md, data-model.md, contracts/, research.md

### Step 3: Generate Tasks
Create `tasks.md` with:
- Numbered tasks (T1, T2, T3...)
- Dependency ordering
- Parallel execution markers
- Agent assignments per task
- Acceptance criteria per task

### Step 4: Report
Show: tasks file path, task count, dependency graph, estimated effort.
