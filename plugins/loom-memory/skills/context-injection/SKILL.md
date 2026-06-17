---
name: context-injection
version: 1.0.0
description: |
  Searches tiered project memory and injects relevant context into Claude Code's
  working context via the preflight hook. Keyword-based retrieval with relevance
  scoring and confidence thresholds.

allowed-tools: Read, Grep, Glob, Bash
triggers:
  - UserPromptSubmit hook (automatic)
  - memory context
  - context injection
category: orchestration
constitutional_principles:
  - VII (Observability)
  - XVI (Plugin-First)
---

# Context Injection Skill

## Overview

This skill is invoked automatically by the preflight hook on every user message.
It searches project memory for relevant context and returns formatted chunks
for injection into Claude Code's additionalContext.

## Search Pipeline

1. **Extract keywords** from user message (remove stop words)
2. **Search working tier** (current branch specs, active tasks)
3. **Search recall tier** (recent session summaries)
4. **Search archival tier** (all project knowledge)
5. **Score and rank** by relevance (keyword match + recency + tier priority)
6. **Filter** by confidence threshold
7. **Truncate** to token budget
8. **Format** as readable context block

## Relevance Scoring

```
score = keyword_match_ratio * 0.6 + recency_score * 0.2 + tier_priority * 0.2
```

## Configuration

See `config/memory.conf` for all configurable parameters.
