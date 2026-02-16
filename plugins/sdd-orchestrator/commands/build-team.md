---
name: build-team
description: Launch sequential architect → implementor → reviewer team for feature development
model: opus
---

# /build-team Command

## Execution Instructions

### Step 1: Parse Request
- Extract feature description from $ARGUMENTS
- Determine scope and affected domains

### Step 2: Load Domain Skill Briefs
Read the relevant domain skill briefs for Task tool injection:
```bash
# Load skill briefs using extract_skill_brief()
source .specify/scripts/bash/common.sh
BACKEND_BRIEF=$(extract_skill_brief "sdd-domain-backend" "backend-operations")
TESTING_BRIEF=$(extract_skill_brief "sdd-domain-testing" "testing-operations")
```

### Step 3: Spawn Architect (30% budget, model: sonnet)
```
Use the Task tool:
- description: "Build-team Phase 1: Architecture design"
- model: sonnet
- prompt: |
    $BACKEND_BRIEF

    TASK: Design the solution architecture for:
    FEATURE: $ARGUMENTS

    Produce: Architecture document with data models, API contracts, component diagram.
    Save to: .docs/teams/build-team-$TIMESTAMP/architecture.md
    Follow: Constitutional Principles I (Library-First), III (Contract-First).

    FILE OWNERSHIP: You own .docs/teams/build-team-$TIMESTAMP/architecture.md
```

### Step 4: Spawn Implementor (50% budget, model: sonnet)
Wait for architect completion, then:
```
Use the Task tool:
- description: "Build-team Phase 2: Implementation"
- model: sonnet
- prompt: |
    $BACKEND_BRIEF

    TASK: Implement the feature:
    FEATURE: $ARGUMENTS
    ARCHITECTURE: Read .docs/teams/build-team-$TIMESTAMP/architecture.md

    Implement following TDD (Principle II): write tests first, then implement.
    Follow the architecture design exactly.

    FILE OWNERSHIP: You own src/ and tests/ files related to this feature.
```

### Step 5: Spawn Reviewer (20% budget, model: sonnet)
Wait for implementor completion, then:
```
Use the Task tool:
- description: "Build-team Phase 3: Review"
- model: sonnet
- prompt: |
    $TESTING_BRIEF

    TASK: Review the implementation:
    FEATURE: $ARGUMENTS
    ARCHITECTURE: Read .docs/teams/build-team-$TIMESTAMP/architecture.md

    Check: test coverage >80%, constitutional compliance, code quality.
    Produce: Review report with pass/fail and recommendations.
    Save to: .docs/teams/build-team-$TIMESTAMP/review.md

    FILE OWNERSHIP: You own .docs/teams/build-team-$TIMESTAMP/review.md
```

### Step 6: Report Results
Merge all outputs and present team execution summary with cost breakdown.

## Model Strategy
- **Coordinator** (you): Opus — orchestrates the pipeline
- **Workers** (architect, implementor, reviewer): Sonnet — domain execution

## Budget Allocation
- Architect: 30% | Implementor: 50% | Reviewer: 20%
- Default total: $15.00

## Usage
```
/build-team "Build JWT authentication with refresh tokens"
/build-team "Add real-time notifications via WebSocket" --budget 20.00
```
