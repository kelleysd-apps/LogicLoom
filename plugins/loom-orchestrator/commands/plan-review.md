---
name: plan-review
description: Multi-perspective plan.md review (CEO scope + Eng architecture, optional Design) — gates /swarm implement
model: opus
---

# /plan-review Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/plan-review/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/plan-review/SKILL.md` and follow its procedure. Reviewers (CEO, Eng, optional Design) run sequentially within this single Task context — do NOT spawn parallel sub-Tasks.

### Step 2: Execute Review
Parse `<feature-name>` (positional or `--feature`), optional `--design` flag, and optional `--adversary` flag. Verify `features/<feature-name>/{vision.md, prd.md, plan.md}` exist, then run the CEO and Eng reviewers (and Design if flagged), synthesize verdicts, and write `features/<feature-name>/plan-review.md`.

**Optional cross-provider adversary (`--adversary`)**: run the `cross-check` skill (`plugins/loom-orchestrator/skills/cross-check/SKILL.md`) over `features/<feature-name>/plan.md` with `--out features/<feature-name>/` — a non-Claude lineage (Codex/GPT default) adversarially challenges the plan's architecture and DAG. Like the CEO/Eng reviewers it is **advisory**: its findings feed the synthesized verdict, but a cross-provider opinion never unilaterally forces `no-go` (the governed agent triages). Key-gated — fails open to `unavailable` and is omitted if no provider key is set.

### Step 3: Report
Print the overall verdict (`go | no-go | conditional`) and the artifact path. The artifact is the deliverable — do not echo the full review to the user.

**Usage**:
- `/plan-review <feature-name>` — CEO + Eng review
- `/plan-review <feature-name> --design` — also run Design reviewer
- `/plan-review <feature-name> --adversary` — also run the cross-provider (Codex) adversary on the plan
- `/plan-review` (no args) — defaults to the sole feature with a plan.md, errors if ambiguous

**Gate contract**: `/swarm implement <feature>` refuses to proceed unless `features/<feature>/plan-review.md` exists with `Overall verdict: go`.
