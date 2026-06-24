---
name: review-team
description: Launch parallel security + quality + performance + behavioral evaluator + cross-provider adversary for comprehensive code + behavior review
model: opus
---

# /review-team Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **parallel review** mode. The review team has **4 Claude reviewers plus 1 key-gated cross-provider adversary**:
1. **Security** — auth/encryption/secrets/OWASP audit
2. **Quality** — code quality, maintainability, test coverage
3. **Performance** — bottlenecks, query patterns, caching
4. **Evaluator** — behavioral verification via `chrome-devtools` MCP (for UI changes) and diagnostics/LSP for non-UI changes
5. **Cross-provider adversary (key-gated)** — a non-Claude lineage (Codex/GPT by default) adversarially reviews the diff via the `cross-check` skill. The first four reviewers are Claude reviewing Claude (shared blind spots); this slot decorrelates the lineage. Skipped silently when no provider key is configured.

### Step 2: Execute Review
Use the Task tool to spawn the 4 Claude review workers in parallel. Inject each reviewer's domain brief via `get_domain_brief <domain>` (e.g. `get_domain_brief security`, `get_domain_brief performance`, `get_domain_brief testing` for quality) from `.logic-loom/scripts/bash/common.sh`, which reads the domain-brief registry at `plugins/loom-governance/domain-briefs/<domain>.md`. The behavioral evaluator's brief comes from `plugins/loom-orchestrator/skills/review-evaluator/SKILL.md`.

**Cross-provider adversary slot**: in the same parallel batch, run the `cross-check` skill (`plugins/loom-orchestrator/skills/cross-check/SKILL.md`) over the current diff — default provider `codex`, Mode A (API). If no provider key is present in `.env`, the slot fails open to `unavailable` and is omitted from synthesis (never blocks the run). Pass `--deep` only if the reviewed change needs repo-wide exploration. Synthesize all findings after completion.

**Synthesis rules**:
- Evaluator's Functionality rubric item is load-bearing — a `fail` on Functionality blocks the entire review-team verdict regardless of the other reviewers' scores. ("Beautiful-but-broken cannot pass.")
- The cross-provider adversary is a **peer signal, not a hard gate** — a cross-provider opinion is probabilistic and can false-positive, so it does NOT unilaterally block the verdict. The main agent triages its findings (`accept | reject | needs-investigation`); only `accept`ed critical/high findings carry weight into the verdict. This keeps decision authority with the governed Claude runtime (the orchestration boundary) and stops an external false positive from halting the pipeline.

See `.docs/architecture/evaluator-protocol.md` for the evaluator's full contract and `plugins/loom-orchestrator/skills/cross-check/SKILL.md` for the adversary contract.

**Usage**:
- `/review-team` — reviews current branch changes (4 Claude reviewers + Codex adversary if `OPENAI_API_KEY` set)
- `/review-team --no-adversary` — skip the cross-provider slot (Claude-only review)
- `/review-team --adversary-deep` — let the adversary explore the repo under a read-only sandbox
