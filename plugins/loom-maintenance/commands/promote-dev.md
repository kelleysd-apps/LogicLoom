---
name: promote-dev
description: Promote a feature branch or worktree into the integration branch and the dev environment — the lowest rung of the promotion ladder. Gates and confirms; deploys nothing.
model: sonnet
---

# /promote-dev Command

**The first of three.** `/promote-dev` → `/promote-staging` → `/promote-prod` is
LogicLoom's working development lifecycle, made operable from
`.docs/policies/environment-promotion-policy.md`. It is **guidance you can
adopt and then change** — every strength on the ladder is read from your own
`environments.conf`, not hardcoded here.

**Not `/promote`.** That is the maintainer driver for LogicLoom's own template
line and is stripped from your copy. This command promotes **your project's**
work into **your project's** dev environment.

## What this command is

A **gate and a confirmation**. It reads the declaration, checks the promotion
order, checks the deploy seam exists, asks you a plain yes/no, and then prints
the seam command for you to run.

## What it is not, and never will be

It does not deploy. There is no cloud API call, no CI-provider call, no deploy
command, no migration runner, no seed, no teardown, no secret handling, and no
rollback mechanic anywhere in it. Every one of those is behind the `deploy`
seam declared in `.logic-loom/config/environments.conf` — a **product-owned**
script the harness names and never inspects (policy § 8, § 10).

## Blast radius: lowest on the ladder

| Promoting into | Confirmation | Skippable |
|---|---|---|
| **dev** | **plain yes/no** | **yes — `--yes`** |
| staging | plain yes/no | yes — `--yes` |
| production | typed exact phrase | **no flag bypasses it** |

`--yes` exists for automation that has already made the decision deliberately.
It is honest about what it skips and it stops working one rung up.

## Execution Instructions

### Step 1 — Run the gate

```bash
./.logic-loom/scripts/bash/promote-gate.sh \
  --to dev --stage dev --default-confirm prompt \
  --from-ref "<feature-branch-or-worktree>" --commit "<sha>"
```

Add `--yes` only when the user asked for a non-interactive run.

`--default-confirm prompt` is a **fallback**. If the `dev` block declares
`confirm`, the declaration wins — that is the point of the declaration, and it
is how a project raises or lowers this rung without editing the command.

### Step 2 — Read the exit code, do not interpret past it

| Exit | Meaning | What you do |
|---|---|---|
| `0` | gate cleared | Step 3 |
| `1` | **refused** — a typed reason was printed | Relay the reason **verbatim**. Stop. |
| `2` | usage error | Fix the invocation. |
| `3` | **nothing declared** | Not a failure. See below. |

**Exit 3 — no environments declared.** Say plainly that the project declares no
environments, that this is a normal and valid state (Principle V — one
environment, or none, is a complete answer), and point at
**`/scaffold-environments`**. Do not offer to write a declaration by hand, and
do not guess a topology.

**A refusal is never softened.** Print why it refused and which override exists.
Never re-run with an override the user did not ask for.

### Step 3 — Hand over the deploy

The gate prints the declared seam. **You do not run it.** Show the user the
command and let them run it, exactly as printed.

If the promotion needs a git mutation — merging the feature branch into the
integration branch, pushing it — that is **Principle VI** territory: surface it
for approval individually, never run it autonomously. The gate itself runs no
git at all.

### Step 4 — Record the outcome

Once the user reports the seam's result:

```bash
./.logic-loom/scripts/bash/promotion-record.sh --env dev --status success --commit "<sha>"
./.logic-loom/scripts/bash/promotion-record.sh --env dev --status failure --commit "<sha>" --note "<what broke>"
```

This is what makes `promotes_from` **enforceable** rather than merely declared:
`/promote-staging` refuses until dev has a success on record. Recording a
success you did not see reported is falsifying the gate for the next rung.

## What a green dev promotion proves

That the seam exited zero. Not that the change works (policy § 6.3). Do not
report "deployed" as "verified" — in a status line, a release note, or your own
summary.

## Reference

- Skill: `plugins/loom-maintenance/skills/promotion-lifecycle/SKILL.md`
- Methodology: `.docs/policies/environment-promotion-policy.md` (§ 4.3, § 12)
- Declaration: `.logic-loom/config/environments.conf`
- Next rung: `/promote-staging`
