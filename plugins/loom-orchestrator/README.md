# loom-orchestrator

The LogicLoom **workflow pack** — multi-agent orchestration, jury-on-demand research,
plan review, swarm execution, and sprint retrospectives. Workers are spawned with
domain briefs injected from the governance-core registry (`get_domain_brief <domain>`,
backed by `plugins/loom-governance/domain-briefs/`). Domain routing uses the model's
native judgment; capability gaps are filled via the Anthropic Claude Code Plugin
Marketplace or the Docker MCP Toolkit.

## Commands
| Command | Purpose |
|---------|---------|
| `/research` | Jury-on-demand research — classifier picks 1-3 judges by query type |
| `/swarm` | Multi-agent swarm — `explore`, `implement`, and `generic` modes |
| `/plan-review` | CEO scope + Eng architecture review of `plan.md` — gates `/swarm implement` |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/review-team` | Parallel security + quality + performance + behavioral evaluator |
| `/fullstack-team` | Parallel frontend + backend + database workers |
| `/retro` | Sprint retrospective — writes `retro.md` and persists action items to loom-memory |

## /research — Jury-on-Demand Research

```
/research "question"
/research "question" --judges all   # legacy fixed 3-LLM panel
```

### How It Works

1. **Query classification**: a lightweight classifier inspects the question and selects
   1-3 judges by query type. **Claude is always present**; OpenAI and Gemini are added
   selectively (e.g. for current-events sourcing or breadth). `--judges all` forces the
   legacy three-LLM panel.

2. **Research**: each selected LLM independently researches the same question (Claude via
   Perplexity for current citations; OpenAI / Gemini via their APIs when enlisted).

3. **Claim extraction**: discrete claims are extracted from the reports.

4. **Tribunal voting**: the selected judges vote on each claim from complementary angles
   (accuracy, sourcing, relevance).

5. **Quality gate**: low-confidence claims trigger targeted re-research.

6. **Synthesis**: Claude produces a confidence-scored final report.

A single-judge run skips the voting/quality-gate phases and synthesizes directly.

### API Requirements

OpenAI / Gemini judges require `OPENAI_API_KEY` and `GEMINI_API_KEY` in `.env` (only
needed when those judges are enlisted or `--judges all` is used). Run `/initialize-project`
for setup.

### Output Files

```
.docs/research/YYYYMMDD-HHMMSS-topic/
  researcher-*.md (one per enlisted judge),
  claims.json, tribunal-votes-*.json (multi-judge runs only),
  confidence-table.md, supplementary-research.md (conditional), final-report.md
```

## Agents: team-synthesizer, tribunal-judge
## Skills: team-orchestration, swarm-explore, swarm-implement, plan-review, retro, review-evaluator, full-stack-feature, multi-skill-workflow, migration-workflow

---
loom-orchestrator v3.1.0
