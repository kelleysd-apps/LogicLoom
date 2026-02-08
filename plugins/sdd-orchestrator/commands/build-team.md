---
name: build-team
description: Launch sequential architect → implementor → reviewer team for feature development
model: opus
---

# /build-team Command

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for team orchestration.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /build-team sequential pipeline"
- prompt: "Run architect → implementor → reviewer sequence for: $ARGUMENTS"
```

## Execution Instructions (for swarm-coordinator)

### Step 1: Parse Request
- Extract feature description from $ARGUMENTS
- Determine scope and affected domains

### Step 2: Spawn Architect (30% budget)
```
Use the Task tool:
- description: "Build-team Phase 1: Architecture design"
- prompt: |
    You are the architect (backend-architect agent). Design the solution for:
    FEATURE: $ARGUMENTS
    
    Produce: Architecture document with data models, API contracts, component diagram.
    Save to: .docs/teams/build-team-$TIMESTAMP/architecture.md
    Follow: Constitutional Principles I (Library-First), III (Contract-First).
```

### Step 3: Spawn Implementor (50% budget)
Wait for architect completion, then:
```
Use the Task tool:
- description: "Build-team Phase 2: Implementation"
- prompt: |
    You are the implementor (full-stack-developer agent). Implement the feature:
    FEATURE: $ARGUMENTS
    ARCHITECTURE: Read .docs/teams/build-team-$TIMESTAMP/architecture.md
    
    Implement following TDD (Principle II): write tests first, then implement.
    Follow the architecture design exactly.
```

### Step 4: Spawn Reviewer (20% budget)
Wait for implementor completion, then:
```
Use the Task tool:
- description: "Build-team Phase 3: Review"
- prompt: |
    You are the reviewer (testing-specialist agent). Review the implementation:
    FEATURE: $ARGUMENTS
    ARCHITECTURE: Read .docs/teams/build-team-$TIMESTAMP/architecture.md
    
    Check: test coverage >80%, constitutional compliance, code quality.
    Produce: Review report with pass/fail and recommendations.
    Save to: .docs/teams/build-team-$TIMESTAMP/review.md
```

### Step 5: Report Results
Merge all outputs and present team execution summary with cost breakdown.

## Budget Allocation
- Architect: 30% | Implementor: 50% | Reviewer: 20%
- Default total: $15.00

## Usage
```
/build-team "Build JWT authentication with refresh tokens"
/build-team "Add real-time notifications via WebSocket" --budget 20.00
```
