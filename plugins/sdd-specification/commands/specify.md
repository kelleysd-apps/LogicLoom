---
name: specify
description: Create or update the feature specification from a natural language feature description.
model: opus
---

# /specify Command

**AGENT REQUIREMENT**: This command should be executed by the specification-agent.

**If you are NOT the specification-agent**, delegate immediately:
```
Use the Task tool to invoke specification-agent:
- description: "Execute /specify command"
- prompt: "Execute the /specify command for this feature. Arguments: $ARGUMENTS"
```

## Execution Instructions (for specification-agent)

### Step 1: Branch Management
Ask user: "Would you like to create a new feature branch, or work on the current branch?"
- If new branch: Run `.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS"`
- If current branch: Create spec at `specs/[current-branch]/spec.md`

### Step 2: Load Template
Read: `.specify/templates/spec-template.md`

### Step 3: Write Specification
Fill the template with details from $ARGUMENTS. Maintain all sections.

### Step 4: Domain Detection
Run: `.specify/scripts/bash/detect-phase-domain.sh --file SPEC_FILE`

### Step 5: Validate
Run: `.specify/scripts/bash/validate-spec.sh --file SPEC_FILE`

### Step 6: Report
Show: branch name, spec file path, suggested agents, validation score.

**Note**: Branch creation requires user approval (Principle VI).
