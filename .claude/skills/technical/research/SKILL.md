---
name: research
description: |
  Multi-pass recursive research skill with cross-referencing validation.
  Performs initial research using Perplexity/Brave, then validates findings
  with 2+ additional passes using different approaches and sources.
  
  Use when comprehensive, validated research is required for critical decisions,
  technology evaluation, or complex feature planning.

  **Trigger**: /research command or "deep research" request
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Deep Research Skill

The `/research` skill provides comprehensive multi-pass research with validation.

## Key Features

- Three-pass validation (Perplexity → Brave → Domain Agent)
- Cross-referencing and conflict resolution
- Automatic domain agent delegation
- Confidence level assessment

## When to Use

Use the `/research` command when you need:

- **Technology Evaluation**: GraphQL vs REST, React vs Vue, etc.
- **Architecture Decisions**: Monorepo vs polyrepo, microservices patterns
- **Security Assessments**: Auth strategies, vulnerability analysis
- **Performance Optimization**: Core Web Vitals, bundle analysis
- **Best Practice Discovery**: Testing, deployment, design patterns

## Procedure

### Step 1: Initialize Research

Create research directory:
```bash
RESEARCH_ID=$(date +%Y%m%d-%H%M%S)
mkdir -p ".docs/research/${RESEARCH_ID}"
```

### Step 2: Pass 1 - Exploratory (Perplexity)

Use Perplexity for broad understanding:
- Search with comprehensive query
- Extract key concepts and technologies
- Identify claims to validate
- Save to pass-1-exploratory.md

### Step 3: Pass 2 - Validation (Brave)

Use Brave for cross-reference:
- Create contrarian queries
- Search for conflicting viewpoints
- Mark: ✅ Confirmed, ⚠️ Conflicting, ❌ Refuted
- Save to pass-2-validation.md

### Step 4: Pass 3 - Expert Synthesis

Delegate to domain agent:

| Keywords | Agent |
|----------|-------|
| React, UI | frontend-specialist |
| API, backend | backend-architect |
| database, SQL | database-specialist |
| security | security-specialist |
| performance | performance-engineer |
| deploy, CI/CD | devops-engineer |

### Step 5: Generate Final Report

Create comprehensive report with:
- Executive summary
- Key findings with confidence levels
- Validated best practices
- Prioritized recommendations
- 10+ source references

## Output

```
.docs/research/YYYYMMDD-HHMMSS/
├── pass-1-exploratory.md
├── pass-2-validation.md
├── pass-3-synthesis.md
└── final-report.md  ⭐
```

## Example

```
/research "Should we use GraphQL or REST for our API?"
```

Duration: 15-25 minutes
