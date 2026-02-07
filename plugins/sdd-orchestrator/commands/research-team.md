---
name: research-team
description: Launch 3 parallel research agents + 1 synthesizer for comprehensive technology evaluation
model: opus
---

# /research-team Command

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for parallel agent spawning.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /research-team command with parallel researchers"
- prompt: "Spawn 3 parallel research subagents and 1 synthesizer for: $ARGUMENTS"
```

## Execution Instructions (for swarm-coordinator)

### Step 1: Initialize Research Directory
```bash
RESEARCH_ID=$(date +%Y%m%d-%H%M%S)
RESEARCH_DIR=".docs/research/${RESEARCH_ID}"
mkdir -p "$RESEARCH_DIR"
```

### Step 2: Spawn 3 Parallel Researchers via Task Tool

Launch all 3 simultaneously using the Task tool:

**Researcher 1 — Primary Sources** (20% budget):
```
Use the Task tool:
- description: "Research-team: Primary source research"
- prompt: |
    You are Researcher 1 (Primary Sources). Research the following topic using
    official documentation, specifications, and authoritative sources:
    
    TOPIC: $ARGUMENTS
    
    Focus on: official docs, RFCs, library documentation, API references.
    Save findings to: $RESEARCH_DIR/pass-1-primary-sources.md
    Include: key concepts, best practices, official recommendations, version info.
```

**Researcher 2 — Community Perspective** (20% budget):
```
Use the Task tool:
- description: "Research-team: Community perspective research"
- prompt: |
    You are Researcher 2 (Community). Research the following topic from
    community perspective — real-world usage, blog posts, forum discussions:
    
    TOPIC: $ARGUMENTS
    
    Focus on: Stack Overflow patterns, blog posts, real-world experiences, gotchas.
    Save findings to: $RESEARCH_DIR/pass-2-community.md
    Include: common pitfalls, real-world trade-offs, community consensus.
```

**Researcher 3 — Comparative Analysis** (20% budget):
```
Use the Task tool:
- description: "Research-team: Comparative analysis"
- prompt: |
    You are Researcher 3 (Comparative). Research alternatives and benchmarks
    for the following topic:
    
    TOPIC: $ARGUMENTS
    
    Focus on: competing approaches, benchmarks, pros/cons matrices, cost analysis.
    Save findings to: $RESEARCH_DIR/pass-3-comparative.md
    Include: comparison tables, benchmark data, decision criteria.
```

### Step 3: Wait for All Researchers to Complete

Monitor Task tool completion for all 3 researchers.

### Step 4: Spawn Synthesizer (40% budget)
```
Use the Task tool:
- description: "Research-team: Synthesize findings"
- prompt: |
    You are the Research Synthesizer. Read ALL three researcher outputs and
    produce a unified final report:
    
    Read: $RESEARCH_DIR/pass-1-primary-sources.md
    Read: $RESEARCH_DIR/pass-2-community.md
    Read: $RESEARCH_DIR/pass-3-comparative.md
    
    Produce: $RESEARCH_DIR/final-report.md
    
    Report must include:
    - Executive summary
    - Key findings with confidence levels (✅ Confirmed, ⚠️ Conflicting, ❌ Refuted)
    - Cross-referenced recommendations
    - Dissenting opinions preserved
    - 10+ source references
    - Actionable next steps
```

### Step 5: Report Completion
```
Report to user:
- Research directory path
- Number of sources cross-referenced
- Key recommendations
- Confidence levels
```

## Budget Allocation
- Each researcher: 20% of total budget
- Synthesizer: 40% of total budget
- Default total: $10.00

## Usage
```
/research-team "Evaluate GraphQL vs REST for our API layer"
/research-team "Compare React, Vue, and Svelte for our frontend" --budget 15.00
```
