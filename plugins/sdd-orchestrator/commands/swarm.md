---
name: swarm
description: Spawn coordinated multi-agent swarm for complex tasks. Analyzes domains, creates execution plan, and launches workers with budget controls.
model: opus
---

# /swarm Command

## Execution Instructions

### Step 1: Analyze Task
- Parse $ARGUMENTS for domain keywords
- Detect required domains: frontend, backend, database, security, testing, performance, devops
- Determine complexity and scope

### Step 2: Load Relevant Skill Briefs
For each detected domain, load the corresponding skill brief:
```bash
source .specify/scripts/bash/common.sh

# Load briefs for detected domains (only load what's needed)
# Example for detected backend + database domains:
BACKEND_BRIEF=$(extract_skill_brief "sdd-domain-backend" "backend-operations")
DATABASE_BRIEF=$(extract_skill_brief "sdd-domain-database" "database-operations")
# ... repeat for each detected domain
```

Available domain skill mappings:
| Domain | Plugin | Skill |
|--------|--------|-------|
| frontend | sdd-domain-frontend | frontend-operations |
| backend | sdd-domain-backend | backend-operations |
| database | sdd-domain-database | database-operations |
| security | sdd-domain-security | security-operations |
| testing | sdd-domain-testing | testing-operations |
| performance | sdd-domain-performance | performance-operations |
| devops | sdd-domain-devops | devops-operations |

### Step 3: Create Execution Plan
Build dependency graph:
```
Identify:
  - Which domain skills are needed (based on detected domains)
  - Dependency ordering (database before backend, backend before frontend)
  - Parallel opportunities (independent domains)
  - Budget allocation per worker
```

### Step 4: Allocate Budget
```bash
TOTAL_BUDGET=${BUDGET:-10.00}
WORKER_COUNT=<detected domains>
PER_WORKER_BUDGET=$(echo "$TOTAL_BUDGET / $WORKER_COUNT" | bc -l)
```

### Step 5: Spawn Workers via Task Tool (model: sonnet)
For each domain in the execution plan:
```
Use the Task tool:
- description: "Swarm worker: [domain] specialist"
- model: sonnet
- prompt: |
    $DOMAIN_BRIEF

    TASK: $ARGUMENTS
    YOUR ROLE: [domain-specific instructions]
    DEPENDENCIES: [outputs from previous workers]

    Save results to: .docs/teams/swarm-$TIMESTAMP/[domain]-output.md

    FILE OWNERSHIP: You own .docs/teams/swarm-$TIMESTAMP/[domain]-output.md
```

### Step 6: Coordinate Dependencies
- Monitor Task tool completions
- Feed outputs from completed workers to dependent workers
- Handle failures: retry once, then report to user

### Step 7: Merge Results
After all workers complete, consolidate outputs into unified report.

### Step 8: Report
Present: task summary, domains used, cost breakdown, outputs produced.

## Model Strategy
- **Coordinator** (you): Opus — analyzes, plans, orchestrates
- **Workers** (all domain specialists): Sonnet — domain execution

## Cost Controls
- **Team budget**: Total spend limit across all swarm workers
- **Per-worker allocation**: Budget / worker count (or priority-weighted)
- **Kill switch**: Terminate workers exceeding individual budget

## Usage
```
/swarm "Build user authentication with React UI, Express API, PostgreSQL"
/swarm "Optimize database queries and add caching layer" --budget 10.00
/swarm "Full code review for security and performance" --team review-team
```
