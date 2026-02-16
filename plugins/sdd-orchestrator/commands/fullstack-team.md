---
name: fullstack-team
description: Launch parallel frontend + backend + database specialists for cross-domain feature development
model: opus
---

# /fullstack-team Command

## Execution Instructions

### Step 1: Initialize
```bash
TEAM_DIR=".docs/teams/fullstack-team-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEAM_DIR"
```

### Step 2: Load Domain Skill Briefs
Read the relevant domain skill briefs for Task tool injection:
```bash
source .specify/scripts/bash/common.sh
DB_BRIEF=$(extract_skill_brief "sdd-domain-database" "database-operations")
BACKEND_BRIEF=$(extract_skill_brief "sdd-domain-backend" "backend-operations")
FRONTEND_BRIEF=$(extract_skill_brief "sdd-domain-frontend" "frontend-operations")
TESTING_BRIEF=$(extract_skill_brief "sdd-domain-testing" "testing-operations")
SECURITY_BRIEF=$(extract_skill_brief "sdd-domain-security" "security-operations")
```

### Step 3: Phase 1 — Database (Sequential, 15% budget, model: sonnet)
```
Use the Task tool:
- description: "Fullstack-team Phase 1: Database schema"
- model: sonnet
- prompt: |
    $DB_BRIEF

    TASK: Design the data layer for:
    FEATURE: $ARGUMENTS

    Produce: Schema design, migrations, RLS policies.
    Save to: $TEAM_DIR/database-design.md
    Follow: Principle III (Contract-First).

    FILE OWNERSHIP: You own $TEAM_DIR/database-design.md and db/ migration files.
```

### Step 4: Phase 2 — Backend + Frontend (Parallel, 50% budget, model: sonnet)
After database completes, spawn both simultaneously:

**Backend** (25%):
```
Use the Task tool:
- description: "Fullstack-team Phase 2a: Backend API"
- model: sonnet
- prompt: |
    $BACKEND_BRIEF

    TASK: Build the API layer for:
    FEATURE: $ARGUMENTS
    DATABASE: Read $TEAM_DIR/database-design.md

    Implement: API endpoints, middleware, business logic.
    Follow: TDD (Principle II), Contract-First (Principle III).

    FILE OWNERSHIP: You own server/, api/, and backend test files.
```

**Frontend** (25%):
```
Use the Task tool:
- description: "Fullstack-team Phase 2b: Frontend UI"
- model: sonnet
- prompt: |
    $FRONTEND_BRIEF

    TASK: Build the UI layer for:
    FEATURE: $ARGUMENTS
    DATABASE: Read $TEAM_DIR/database-design.md

    Implement: React components, state management, API integration stubs.
    Follow: Design System (Principle XII).

    FILE OWNERSHIP: You own src/components/, src/pages/, and frontend test files.
```

### Step 5: Phase 3 — Integration (Sequential, 15% budget, model: sonnet)
```
Use the Task tool:
- description: "Fullstack-team Phase 3: Integration"
- model: sonnet
- prompt: |
    TASK: Wire frontend to backend for:
    FEATURE: $ARGUMENTS

    Connect: API calls, error handling, loading states.
    Verify: End-to-end data flow works.

    FILE OWNERSHIP: You own integration test files and API client code.
```

### Step 6: Phase 4 — Testing + Security (Parallel, 20% budget, model: sonnet)

**Testing** (10%):
```
Use the Task tool:
- description: "Fullstack-team Phase 4a: E2E tests"
- model: sonnet
- prompt: |
    $TESTING_BRIEF

    TASK: Write E2E tests for: $ARGUMENTS
    Save to: $TEAM_DIR/e2e-results.md

    FILE OWNERSHIP: You own e2e/ test files.
```

**Security** (10%):
```
Use the Task tool:
- description: "Fullstack-team Phase 4b: Security review"
- model: sonnet
- prompt: |
    $SECURITY_BRIEF

    TASK: Security review for: $ARGUMENTS
    Save to: $TEAM_DIR/security-review.md

    FILE OWNERSHIP: You own $TEAM_DIR/security-review.md
```

### Step 7: Report Results

## Model Strategy
- **Coordinator** (you): Opus — orchestrates the multi-phase pipeline
- **Workers** (all domain specialists): Sonnet — domain execution

## Budget Allocation
- Database: 15% | Backend: 25% | Frontend: 25% | Integration: 15% | Testing+Security: 20%
- Default total: $25.00

## Usage
```
/fullstack-team "Build user profile management with avatar upload"
/fullstack-team "Add payment processing with Stripe" --budget 30.00
```
