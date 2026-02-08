---
name: review-team
description: Launch parallel security + quality + performance reviewers for comprehensive code review
model: opus
---

# /review-team Command

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for parallel review.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /review-team parallel review"
- prompt: "Launch parallel security, quality, and performance reviewers for: $ARGUMENTS"
```

## Execution Instructions (for swarm-coordinator)

### Step 1: Initialize Review
```bash
REVIEW_DIR=".docs/teams/review-team-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REVIEW_DIR"
```

### Step 2: Spawn 3 Parallel Reviewers via Task Tool

**Security Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Security analysis"
- prompt: |
    You are the security-specialist agent. Perform security review:
    SCOPE: $ARGUMENTS
    
    Check: XSS, SQL injection, auth vulnerabilities, CORS, CSP, secrets exposure.
    Save to: $REVIEW_DIR/security-review.md
    Rate: PASS/WARN/FAIL per category.
```

**Quality Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Code quality analysis"
- prompt: |
    You are the testing-specialist agent. Perform quality review:
    SCOPE: $ARGUMENTS
    
    Check: test coverage, code duplication, complexity, constitutional compliance.
    Save to: $REVIEW_DIR/quality-review.md
    Rate: Coverage %, complexity score, compliance status.
```

**Performance Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Performance analysis"
- prompt: |
    You are the performance-engineer agent. Perform performance review:
    SCOPE: $ARGUMENTS
    
    Check: N+1 queries, bundle size, caching, lazy loading, memory leaks.
    Save to: $REVIEW_DIR/performance-review.md
    Rate: Performance grade A-F per category.
```

### Step 3: Wait for All Reviewers

### Step 4: Spawn Synthesizer (25% budget)
```
Use the Task tool:
- description: "Review-team: Synthesize findings"
- prompt: |
    Read all three review reports and produce unified assessment:
    Read: $REVIEW_DIR/security-review.md
    Read: $REVIEW_DIR/quality-review.md
    Read: $REVIEW_DIR/performance-review.md
    
    Produce: $REVIEW_DIR/final-review.md
    Include: Priority-ranked issues, overall grade, action items.
```

### Step 5: Report to User

## Budget Allocation
- Each reviewer: 25% | Synthesizer: 25%
- Default total: $10.00

## Usage
```
/review-team "Review the authentication module before merge"
/review-team "Full security and performance audit of the API layer"
```
