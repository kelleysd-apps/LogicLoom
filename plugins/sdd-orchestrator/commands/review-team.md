---
name: review-team
description: Launch parallel security + quality + performance reviewers for comprehensive code review
model: opus
---

# /review-team Command

## Execution Instructions

### Step 1: Initialize Review
```bash
REVIEW_DIR=".docs/teams/review-team-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REVIEW_DIR"
```

### Step 2: Load Domain Skill Briefs
```bash
source .specify/scripts/bash/common.sh
SECURITY_BRIEF=$(extract_skill_brief "sdd-domain-security" "security-operations")
TESTING_BRIEF=$(extract_skill_brief "sdd-domain-testing" "testing-operations")
PERF_BRIEF=$(extract_skill_brief "sdd-domain-performance" "performance-operations")
```

### Step 3: Spawn 3 Parallel Reviewers (model: sonnet)

**Security Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Security analysis"
- model: sonnet
- prompt: |
    $SECURITY_BRIEF

    TASK: Perform security review for:
    SCOPE: $ARGUMENTS

    Check: XSS, SQL injection, auth vulnerabilities, CORS, CSP, secrets exposure.
    Save to: $REVIEW_DIR/security-review.md
    Rate: PASS/WARN/FAIL per category.

    FILE OWNERSHIP: You own $REVIEW_DIR/security-review.md
```

**Quality Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Code quality analysis"
- model: sonnet
- prompt: |
    $TESTING_BRIEF

    TASK: Perform quality review for:
    SCOPE: $ARGUMENTS

    Check: test coverage, code duplication, complexity, constitutional compliance.
    Save to: $REVIEW_DIR/quality-review.md
    Rate: Coverage %, complexity score, compliance status.

    FILE OWNERSHIP: You own $REVIEW_DIR/quality-review.md
```

**Performance Reviewer** (25% budget):
```
Use the Task tool:
- description: "Review-team: Performance analysis"
- model: sonnet
- prompt: |
    $PERF_BRIEF

    TASK: Perform performance review for:
    SCOPE: $ARGUMENTS

    Check: N+1 queries, bundle size, caching, lazy loading, memory leaks.
    Save to: $REVIEW_DIR/performance-review.md
    Rate: Performance grade A-F per category.

    FILE OWNERSHIP: You own $REVIEW_DIR/performance-review.md
```

### Step 4: Wait for All Reviewers

### Step 5: Synthesize Findings (25% budget, model: sonnet)
```
Use the Task tool:
- description: "Review-team: Synthesize findings"
- model: sonnet
- prompt: |
    Read all three review reports and produce unified assessment:
    Read: $REVIEW_DIR/security-review.md
    Read: $REVIEW_DIR/quality-review.md
    Read: $REVIEW_DIR/performance-review.md

    Produce: $REVIEW_DIR/final-review.md
    Include: Priority-ranked issues, overall grade, action items.
```

### Step 6: Report to User

## Model Strategy
- **Coordinator** (you): Opus — orchestrates and sequences
- **Reviewers** (security, quality, performance): Sonnet — domain analysis
- **Synthesizer**: Sonnet — report consolidation

## Budget Allocation
- Each reviewer: 25% | Synthesizer: 25%
- Default total: $10.00

## Usage
```
/review-team "Review the authentication module before merge"
/review-team "Full security and performance audit of the API layer"
```
