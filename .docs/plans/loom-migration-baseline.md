# Loom Migration — Stage 0 Baseline

**Captured**: 2026-05-22
**Branch**: `loom-migration` (parent: `dev-main` @ `50494f6`, tag: `pre-loom-migration`)
**Framework version**: v5.1.1

## Structural inventory (pre-migration)

| Metric | Count |
|---|---|
| Framework files (plugins/.logic-loom/.claude) | 258 |
| Plugins | 16 (excluding 4 helper files in `plugins/`) |
| Domain plugins (Stage 2 targets) | 7 (frontend, backend, database, testing, security, performance, devops) |
| Slash commands | 15 |
| Test files | 25 (test cases will be greater; npm test output below) |
| Test directories | 7 (contract, contracts, fixtures, integration, unit, validation, __init__) |

## Plugins inventory

- `sdd-creation` — keep
- `sdd-dev-loop` — **DELETE** (Stage 1)
- `sdd-domain-backend` — **DELETE** (Stage 2)
- `sdd-domain-database` — **DELETE** (Stage 2)
- `sdd-domain-devops` — **DELETE** (Stage 2)
- `sdd-domain-frontend` — **DELETE** (Stage 2)
- `sdd-domain-performance` — **DELETE** (Stage 2)
- `sdd-domain-security` — **DELETE** (Stage 2)
- `sdd-domain-testing` — **DELETE** (Stage 2)
- `sdd-git` — keep (drop `/finalize` only)
- `sdd-governance` — keep (drop rl-metrics-capture hook entry only)
- `sdd-maintenance` — keep
- `sdd-memory` — keep
- `sdd-orchestrator` — keep, extend (drop /build-team /fullstack-team, add 4 new skills, modify team-orchestration)
- `sdd-orchestrator-hook` — keep
- `sdd-specification` — **DELETE** (Stage 3)

## Slash commands inventory

| Command | Status |
|---|---|
| `/build-team` | DELETE (Stage 1, fold into /swarm) |
| `/create-agent` | KEEP |
| `/create-plugin` | KEEP |
| `/create-prd` | KEEP (retarget Stage 7) |
| `/create-skill` | KEEP |
| `/dev-loop` | DELETE (Stage 1, fold into /swarm) |
| `/finalize` | DELETE (Stage 1, redundant with /git-push) |
| `/fullstack-team` | DELETE (Stage 1, fold into /swarm) |
| `/git-push` | KEEP |
| `/initialize-project` | KEEP |
| `/research` | KEEP (jury-on-demand at Stage 9) |
| `/review-team` | KEEP (Playwright evaluator at Stage 8) |
| `/specification` | DELETE (Stage 3) |
| `/swarm` | KEEP (explore + implement modes at Stage 6) |
| `/update-framework` | KEEP |

**Net**: 15 → 11 retained commands + 2 new (`/plan-review` Stage 7b, `/retro` Stage 11b) = **13 commands post-migration**.

## Deletion targets present

- `mcp-servers/sdd-marketplace/` — PRESENT (Stage 1 target)
- `.logic-loom/scripts/bash/rl/` — PRESENT, 8 files (Stage 4 target)
- `src/sdd/` — PRESENT (Stages 3, 4 targets within)
- `specs/` — PRESENT, 1 entry (Stage 3 target)

## Constitutional compliance

`constitutional-check.sh` baseline result (run 2026-05-22 on `loom-migration` branch):

- **Passed**: 14/16 principles
- **Failed**: 0/16
- **Warnings**: 2
  - "Consider creating library structure for reusable components"
  - "Consider defining contracts in specs/*/contracts/ or *contract*.ts files" — will become moot after Stage 3 (specs/ deleted)

Critical principles (VI Git Approval, X Agent Delegation) both PASS.

## Test baseline

`npm test` (run 2026-05-22): **cannot execute — `jest: command not found`**.

Pre-existing condition (no migration changes have been applied yet). `npm install` has not been run in this repo state, so test dependencies are missing. Implication for the migration:
- Stages 1–13 do NOT require tests to pass — they can proceed using `constitutional-check.sh` as the verification gate.
- **Stage 14 (test pruning)** is the natural place to also resolve the test runner — run `npm install` as a sub-step, then prune and verify.
- Anything later than Stage 14 must have green `npm test`.

So the pre-migration baseline for tests is "untested due to uninstalled dependencies" — and verification post-migration is "tests installable and green after pruning."

## Rollback reference

If anything in Stages 1–15 goes irrecoverable:

```bash
git checkout dev-main                    # leave loom-migration branch
git checkout pre-loom-migration -- .     # restore pre-migration tree to working dir
# or:
git branch -D loom-migration             # nuke the whole migration (after confirming no useful commits)
```

Tag `pre-loom-migration` always points to the dev-main commit `50494f6` and is never modified.
