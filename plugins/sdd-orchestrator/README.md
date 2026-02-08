# sdd-orchestrator

Multi-agent orchestration plugin with multi-LLM tribunal research (Claude, OpenAI, Gemini).

## Commands
| Command | Purpose |
|---------|---------|
| `/research` | Multi-LLM triplicate research with tribunal cross-validation |
| `/swarm` | Custom multi-agent swarm with domain detection |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/review-team` | Parallel security + quality + performance reviewers |
| `/fullstack-team` | Parallel frontend + backend + database specialists |

## /research — Multi-LLM Tribunal Research

```
/research "topic"
```

### How It Works

1. **Phase 1 — Multi-LLM Triplicate Research**: Three LLMs independently research the same topic
   - Claude Opus 4.6 (via Perplexity for current citations)
   - OpenAI GPT-4o (via API)
   - Google Gemini 2.5 Pro (via API)

2. **Phase 2 — Claim Extraction**: Claude Haiku extracts 20-40 discrete claims from all 3 reports

3. **Phase 3 — Multi-LLM Tribunal Voting**: Three LLMs vote on each claim
   - Claude Sonnet 4.5 (accuracy focus)
   - OpenAI GPT-4o (sourcing focus)
   - Gemini 2.5 Pro (relevance focus)

4. **Phase 4 — Quality Gate**: If low-confidence claims exist, targeted re-research

5. **Phase 5 — Synthesis**: Claude Opus produces confidence-scored final report

### API Requirements

Requires `OPENAI_API_KEY` and `GEMINI_API_KEY` in `.env`. Run `/initialize-project` for setup.

### Output Files

```
.docs/research/YYYYMMDD-HHMMSS-topic/
  researcher-a-claude.md, researcher-b-openai.md, researcher-c-gemini.md,
  claims.json, tribunal-votes-{1,2,3}-{claude,openai,gemini}.json,
  confidence-table.md, supplementary-research.md (conditional), final-report.md
```

## Agents: swarm-coordinator, team-synthesizer, task-orchestrator, workflow-coordinator
## Skills: multi-skill-workflow, full-stack-feature, migration-workflow, tribunal-review, team-orchestration
