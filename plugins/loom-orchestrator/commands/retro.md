---
name: retro
description: Sprint retrospective — reads sprints/git/plan-review, writes features/<name>/retro.md, persists action-items into loom-memory
model: opus
---

# /retro Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/retro/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/retro/SKILL.md` and follow its procedure. Synthesis happens sequentially in this single Task context — do NOT spawn parallel sub-Tasks.

### Step 2: Execute Retro
Parse `<feature-name>` (positional or `--feature`). Verify `features/<feature-name>/sprints/` exists, then read sprint outputs, the git log since branch creation, the plan-vs-actual DAG diff, and `plan-review.md` if present. Synthesize wins / misses / action-items and write `features/<feature-name>/retro.md` (overwrite). Then write the action-items section to `$HOME/.claude/projects/<slug>/memory/retro_<feature>_<YYYY-MM-DD>.md` — skip if that file already exists for the same day.

### Step 3: Report
Print three lines: retro path, memory path (or "memory write skipped: already exists for today"), and a tally line (`went-well: N, didn't: N, action-items: N`). Do not echo the full retro — the file is the artifact.

**Usage**:
- `/retro <feature-name>` — write retro + memory entry
- `/retro` (no args) — defaults to the sole feature with a `sprints/` dir, errors if ambiguous

**Lifecycle position**: Run AFTER `/git-push` for a feature has completed; BEFORE starting the next feature's Vision phase. Idempotent — re-runs overwrite retro.md and skip duplicate memory writes for the same day.
