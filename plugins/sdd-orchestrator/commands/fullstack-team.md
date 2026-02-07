---
name: fullstack-team
description: Launch parallel frontend + backend + database specialists for cross-domain feature development
model: opus
---

# /fullstack-team Command

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for multi-phase team orchestration.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /fullstack-team multi-phase workflow"
- prompt: "Orchestrate fullstack team for: $ARGUMENTS"
```

## Execution Instructions (for swarm-coordinator)

### Step 1: Initialize
```bash
TEAM_DIR=".docs/teams/fullstack-team-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEAM_DIR"
```

### Step 2: Phase 1 — Database (Sequential, 15% budget)
```
Use the Task tool:
- description: "Fullstack-team Phase 1: Database schema"
- prompt: |
    You are the database-specialist agent. Design the data layer:
    FEATURE: $ARGUMENTS
    
    Produce: Schema design, migrations, RLS policies.
    Save to: $TEAM_DIR/database-design.md
    Follow: Principle III (Contract-First).
```

### Step 3: Phase 2 — Backend + Frontend (Parallel, 50% budget)
After database completes, spawn both simultaneously:

**Backend** (25%):
```
Use the Task tool:
- description: "Fullstack-team Phase 2a: Backend API"
- prompt: |
    You are the backend-architect agent. Build the API layer:
    FEATURE: $ARGUMENTS
    DATABASE: Read $TEAM_DIR/database-design.md
    
    Implement: API endpoints, middleware, business logic.
    Follow: TDD (Principle II), Contract-First (Principle III).
```

**Frontend** (25%):
```
Use the Task tool:
- description: "Fullstack-team Phase 2b: Frontend UI"
- prompt: |
    You are the frontend-specialist agent. Build the UI layer:
    FEATURE: $ARGUMENTS
    DATABASE: Read $TEAM_DIR/database-design.md
    
    Implement: React components, state management, API integration stubs.
    Follow: Design System (Principle XII).
```

### Step 4: Phase 3 — Integration (Sequential, 15% budget)
```
Use the Task tool:
- description: "Fullstack-team Phase 3: Integration"
- prompt: |
    You are the full-stack-developer agent. Wire frontend to backend:
    FEATURE: $ARGUMENTS
    
    Connect: API calls, error handling, loading states.
    Verify: End-to-end data flow works.
```

### Step 5: Phase 4 — Testing + Security (Parallel, 20% budget)
```
Use the Task tool (testing-specialist):
- description: "Fullstack-team Phase 4a: E2E tests"
```
```
Use the Task tool (security-specialist):
- description: "Fullstack-team Phase 4b: Security review"
```

### Step 6: Report Results

## Budget Allocation
- Database: 15% | Backend: 25% | Frontend: 25% | Integration: 15% | Testing+Security: 20%
- Default total: $25.00

## Usage
```
/fullstack-team "Build user profile management with avatar upload"
/fullstack-team "Add payment processing with Stripe" --budget 30.00
```
