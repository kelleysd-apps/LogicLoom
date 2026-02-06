---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
deprecated: true
deprecated-by: /specification
---

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-specification/commands/tasks.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


> ⚠️ **DEPRECATION NOTICE**: This command is deprecated and will be removed in v4.0.0.
> 
> **Use instead**: `/specification <feature-description>`
> 
> The new `/specification` command provides a unified workflow that generates all SDD artifacts (spec, plan, tasks) in a single execution.


**AGENT REQUIREMENT**: This command should be executed by the tasks-agent.

**If you are NOT the tasks-agent**, delegate this work immediately:
```
Use the Task tool to invoke tasks-agent:
- subagent_type: "tasks-agent"
- description: "Execute /tasks command"
- prompt: "Execute the /tasks command for this feature. Arguments: $ARGUMENTS"
```

The tasks-agent is specialized for:
- Task decomposition and dependency management
- TDD and Library-First task ordering
- Parallel execution optimization
- AI-optimized task creation
- Constitutional compliance in task structure

---

## Execution Instructions (for tasks-agent)

Given the context provided as an argument, do this:

1. Run `.specify/scripts/bash/check-task-prerequisites.sh --json` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.
2. Load and analyze available design documents:
   - Always read plan.md for tech stack and libraries
   - IF EXISTS: Read data-model.md for entities
   - IF EXISTS: Read contracts/ for API endpoints
   - IF EXISTS: Read research.md for technical decisions
   - IF EXISTS: Read quickstart.md for test scenarios

   Note: Not all projects have all documents. For example:
   - CLI tools might not have contracts/
   - Simple libraries might not need data-model.md
   - Generate tasks based on what's available

3. Generate tasks following the template:
   - Use `.specify/templates/tasks-template.md` as the base
   - Replace example tasks with actual tasks based on:
     * **Setup tasks**: Project init, dependencies, linting
     * **Test tasks [P]**: One per contract, one per integration scenario
     * **Core tasks**: One per entity, service, CLI command, endpoint
     * **Integration tasks**: DB connections, middleware, logging
     * **Polish tasks [P]**: Unit tests, performance, docs

4. Task generation rules:
   - Each contract file → contract test task marked [P]
   - Each entity in data-model → model creation task marked [P]
   - Each endpoint → implementation task (not parallel if shared files)
   - Each user story → integration test marked [P]
   - Different files = can be parallel [P]
   - Same file = sequential (no [P])

5. Order tasks by dependencies:
   - Setup before everything
   - Tests before implementation (TDD)
   - Models before services
   - Services before endpoints
   - Core before integration
   - Everything before polish

6. Include parallel execution examples:
   - Group [P] tasks that can run together
   - Show actual Task agent commands

7. Create FEATURE_DIR/tasks.md with:
   - Correct feature name from implementation plan
   - Numbered tasks (T001, T002, etc.)
   - Clear file paths for each task
   - Dependency notes
   - Parallel execution guidance

8. Validate task list: `.specify/scripts/bash/validate-tasks.sh --file FEATURE_DIR/tasks.md`
   - Verify tasks follow constitutional principles (test-first, contract-first)
   - Check for sufficient granularity and dependencies
   - Report validation score and task statistics

9. Run domain detection on tasks: `.specify/scripts/bash/detect-phase-domain.sh --file FEATURE_DIR/tasks.md`
   - Identify specialized agents needed for task execution
   - Determine if multi-agent orchestration is required

10. Report completion with:
    - Task file path
    - Total task count and parallel task count
    - Validation score
    - Suggested agents for execution
    - Ready for implementation

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.
