---
name: research
description: Multi-pass deep research with cross-referencing validation. Three passes exploratory → validation → synthesis.
model: opus
---

# /research Command

**SKILL ACTIVATION**: Activate the deep-research skill at `plugins/sdd-orchestrator/skills/deep-research/SKILL.md`.

## Execution Instructions

### Step 1: Initialize Research
```bash
RESEARCH_ID=$(date +%Y%m%d-%H%M%S)
RESEARCH_DIR=".docs/research/${RESEARCH_ID}"
mkdir -p "$RESEARCH_DIR"
```

### Step 2: Pass 1 — Exploratory Research
Search broadly for the topic using available tools (Perplexity MCP, web search, codebase analysis):
- Extract key concepts, technologies, and approaches
- Identify claims that need validation
- Save to: `$RESEARCH_DIR/pass-1-exploratory.md`

### Step 3: Pass 2 — Validation
Cross-reference findings from Pass 1:
- Create contrarian queries to find conflicting viewpoints
- Mark each finding: ✅ Confirmed, ⚠️ Conflicting, ❌ Refuted
- Save to: `$RESEARCH_DIR/pass-2-validation.md`

### Step 4: Pass 3 — Expert Synthesis
Delegate to appropriate domain agent via Task tool:

| Topic Keywords | Delegate To |
|---------------|-------------|
| React, UI, frontend | frontend-specialist |
| API, backend, server | backend-architect |
| database, SQL, schema | database-specialist |
| security, auth | security-specialist |
| performance, optimization | performance-engineer |
| deploy, CI/CD | devops-engineer |

```
Use the Task tool:
- description: "Research Pass 3: Expert synthesis"
- prompt: |
    You are the [domain]-specialist agent. Provide expert analysis on:
    TOPIC: $ARGUMENTS
    FINDINGS: Read $RESEARCH_DIR/pass-1-exploratory.md and pass-2-validation.md
    
    Produce expert assessment with recommendations.
    Save to: $RESEARCH_DIR/pass-3-synthesis.md
```

### Step 5: Generate Final Report
Compile all passes into `$RESEARCH_DIR/final-report.md`:
- Executive summary
- Key findings with confidence levels
- Validated best practices
- Prioritized recommendations
- 10+ source references

### Step 6: Report Completion
Show user: research directory path, key recommendations, confidence levels.

## Output
```
.docs/research/YYYYMMDD-HHMMSS/
├── pass-1-exploratory.md
├── pass-2-validation.md
├── pass-3-synthesis.md
└── final-report.md  ⭐
```

## Usage
```
/research "Should we use GraphQL or REST for our API?"
/research "Compare authentication strategies for SaaS"
```

Duration: 15-25 minutes
