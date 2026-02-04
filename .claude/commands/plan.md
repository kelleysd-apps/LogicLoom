---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
deprecated: true
deprecated-by: /specification
---

> ⚠️ **DEPRECATION NOTICE**: This command is deprecated and will be removed in v4.0.0.
> 
> **Use instead**: `/specification <feature-description>`
> 
> The new `/specification` command provides a unified workflow that generates all SDD artifacts (spec, plan, tasks) in a single execution.


**AGENT REQUIREMENT**: This command should be executed by the planning-agent.

**If you are NOT the planning-agent**, delegate this work immediately:
```
Use the Task tool to invoke planning-agent:
- subagent_type: "planning-agent"
- description: "Execute /plan command"
- prompt: "Execute the /plan command for this feature. Arguments: $ARGUMENTS"
```

The planning-agent is specialized for:
- Phase 0: Technical research and library evaluation
- Phase 1: API contract design and data modeling
- Constitutional compliance validation
- Implementation plan creation

---

## Execution Instructions (for planning-agent)

Given the implementation details provided as an argument, do this:

1. Run `.specify/scripts/bash/setup-plan.sh --json` from the repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. All future file paths must be absolute.

2. Read and analyze the feature specification to understand:
   - The feature requirements and user stories
   - Functional and non-functional requirements
   - Success criteria and acceptance criteria
   - Any technical constraints or dependencies mentioned

3. Read the constitution at `.specify/memory/constitution.md` to understand constitutional requirements.

4. Execute the implementation plan template:
   - Load `.specify/templates/plan-template.md` (already copied to IMPL_PLAN path)
   - Set Input path to FEATURE_SPEC
   - Run the Execution Flow (main) function steps 1-9
   - The template is self-contained and executable
   - Follow error handling and gate checks as specified
   - Let the template guide artifact generation in $SPECS_DIR:
     * Phase 0 generates research.md
     * Phase 1 generates data-model.md, contracts/, quickstart.md
     * Phase 2 describes task generation (DO NOT create tasks.md)
   - Incorporate user-provided details from arguments into Technical Context: $ARGUMENTS
   - Update Progress Tracking as you complete each phase

5. Verify execution completed:
   - Check Progress Tracking shows Phases 0-1 complete
   - Ensure all required artifacts were generated
   - Confirm no ERROR states in execution

6. Validate implementation plan: `.specify/scripts/bash/validate-plan.sh --file IMPL_PLAN`
   - Check for constitutional principle compliance (Library-First, Test-First, Contract-First)
   - Verify required artifacts exist (research.md, data-model.md, contracts/, quickstart.md)
   - Report validation score and recommendations

7. Run domain detection on plan: `.specify/scripts/bash/detect-phase-domain.sh --file IMPL_PLAN`
   - Confirm domains match those identified in specification
   - Identify any additional domains/agents needed for implementation

8. Report results with:
   - Branch name
   - File paths and generated artifacts
   - Validation score
   - Suggested agents for task execution
   - Readiness for the next phase (/tasks)

Use absolute paths with the repository root for all file operations to avoid path issues.

**IMPORTANT**: The /plan command stops after Phase 1. Phase 2 (tasks.md generation) is handled by the /tasks command with tasks-agent.
