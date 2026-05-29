---
name: review-team
description: Launch parallel security + quality + performance + behavioral evaluator for comprehensive code + behavior review
model: opus
---

# /review-team Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **parallel review** mode. The review team now has **4 reviewers** (was 3 in v5.x):
1. **Security** — auth/encryption/secrets/OWASP audit
2. **Quality** — code quality, maintainability, test coverage
3. **Performance** — bottlenecks, query patterns, caching
4. **Evaluator (NEW)** — behavioral verification via `chrome-devtools` MCP (for UI changes) and pure-function quality checks (placeholder for property-based testing, deferred to v6.1)

### Step 2: Execute Review
Use the Task tool to spawn 4 parallel review workers with skill briefs from `extract_skill_brief()` in `.logic-loom/scripts/bash/common.sh`. The behavioral evaluator's brief comes from `plugins/loom-orchestrator/skills/review-evaluator/SKILL.md`. Synthesize findings after all complete.

**Synthesis rule**: Evaluator's Functionality rubric item is load-bearing — a `fail` on Functionality blocks the entire review-team verdict regardless of the other three reviewers' scores. ("Beautiful-but-broken cannot pass.")

See `.docs/architecture/evaluator-protocol.md` for the evaluator's full contract.

**Usage**: `/review-team` (reviews current branch changes)
