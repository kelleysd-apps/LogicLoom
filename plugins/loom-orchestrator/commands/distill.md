---
name: distill
description: Distillation pass — promotes .brain/raw/ captures into .brain/wiki/ pages, appends one dated entry to .brain/DISTILL-LOG.md every run
model: opus
---

# /distill Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/distillation-pass/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/distillation-pass/SKILL.md` and follow
its procedure exactly. This is a prompt, not an engine — there is no script to
invoke and no runner to spawn; the judgment happens in this single context.

### Step 2: Preflight
Read `.brain/README.md`. If it does not exist, `.brain/` is not set up on this
repo — say so and stop without writing anything.

### Step 3: Run the pass
Enumerate `.brain/raw/**/*.md` (skip any `README.md`) and parse each file's
frontmatter block to read `status` — never grep for the literal string
`status: unprocessed` (quoted and unquoted YAML both occur; the skill explains
why this matters). For every `status: unprocessed` capture, choose exactly one
outcome: extend an existing wiki page, create a new one, discard with a
reason, or flag a contradiction and touch neither page. Write provenance into
the wiki page's `sources:` before marking the capture `processed`. Never edit
a capture's body. Never delete a capture. Never run git.

### Step 4: Log and verify
Append one dated entry to `.brain/DISTILL-LOG.md` — always, including a
zero-op run. Then run
`bash .logic-loom/scripts/bash/check-brain-record.sh` to confirm the record
still holds, and print its result.

### Step 5: Report
Print a short summary: captures scanned, captures still unprocessed, pages
promoted/extended, captures discarded, contradictions flagged, and the
`check-brain-record.sh` result. Do not echo full wiki pages or full captures —
the files are the artifact.

**Arguments**:
- `/distill` — run the pass and write
- `/distill --dry-run` — report what the pass would do (captures found, the
  outcome it would choose for each, the log line it would append) and write
  nothing: no wiki edit, no frontmatter change, no log append

**Usage**:
- `/distill` — one-shot, invoked by hand or by a user-installed scheduled
  task (see `.logic-loom/templates/distill-schedule-prompt.md`, which the
  harness ships but never installs — `~/.claude/scheduled-tasks/` is the
  user's tree)
- `/distill --dry-run` — preview before committing to a run

**Lifecycle position**: Independent of the swarm/SDD workflow loops. Runs
whenever `.brain/raw/` has unprocessed captures — most often after
`/research`, `/swarm explore`, `/review-team`, or `/cross-check`, all of which
redirect their outputs there. Idempotent — re-running over already-`processed`
captures is a no-op.
