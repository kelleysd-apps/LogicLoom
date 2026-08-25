---
name: scaffold-environments
description: Opt-in scaffolding for the environment-promotion methodology — detects what your repo already has, proposes a delta, writes only what you name.
model: sonnet
---

# /scaffold-environments Command

Stands up the **environment-promotion methodology**
(`.docs/policies/environment-promotion-policy.md`) in the user's own project:
the environment declaration, a branch-boundary CI check adapted to their branch
names, a promotion checklist carrying the portable patterns, a product-owned
deploy seam per environment, and the default-branch-trap guard for their
topology.

**Not `/promote`.** `/promote` is the maintainer release driver for the
LogicLoom template line and is stripped from customer copies by exact path
(backlog LOOM-0006). This command scaffolds; it promotes nothing, deploys
nothing, and runs no git.

## The two hard constraints

1. **It is OPT-IN scaffolding, not rails.** The harness ships no deployment
   machinery, and Principle V says do not stand up a three-environment chain
   before one environment is proven in use. One environment — or none — is a
   valid answer, and the tool says so rather than upselling.
2. **It adopts into an EXISTING project.** A repository that already has
   branches, CI, and a deployed environment is the normal case. The tool
   detects, proposes a **delta**, and never overwrites. A project that already
   has a `staging` branch is never told to create one.

## Execution Instructions

### Step 1 — Plan (read-only, always first)

```bash
./.logic-loom/scripts/bash/scaffold-environments.sh
```

This writes **nothing**. It prints what the repository already has, the
environments it would declare, and a per-target table of `WOULD ADD` /
`ALREADY OK` / `CONFLICT` / `SKIP` with a reason on every line.

Optional, if the user wants the raw detection first:

```bash
./.logic-loom/scripts/bash/detect-environment-topology.sh
```

### Step 2 — Show the user the proposal, verbatim

Show the target table and the environment list **as printed**. Do not summarize
away a `SKIP` or a `CONFLICT` — those lines are the whole point. In particular
surface, in plain language:

- which branches were **found** (and that none will be created);
- anything marked `CONFLICT` — a file they already own that will not be touched;
- anything marked `SKIP` — and why the tool declined to propose it. A skip is
  usually the correct answer, not a limitation. A repository whose `main`
  legitimately takes feature branches gets no branch-boundary guard, because a
  guard there would fail every PR they open.

### Step 3 — Ask which targets to adopt. Per file.

Do **not** default to `all`. Ask. The five targets:

| Target | Writes |
|---|---|
| `envconf` | environment blocks appended to `.logic-loom/config/environments.conf` |
| `ci-guard` | `.github/workflows/branch-boundary-guard.yml`, parameterized by their branches |
| `checklist` | `.docs/policies/promotion-checklist.md` — the portable patterns |
| `deploy-stubs` | `<deploy-dir>/deploy-<env>.sh` — commented placeholders the product owns |
| `branch-base-check` | `<deploy-dir>/check-branch-base.sh` — the default-branch-trap guard |

**If the user declines, stop.** `--plan` wrote nothing, so backing out here
leaves the tree byte-identical. Say that plainly; do not re-pitch.

### Step 4 — Apply only what they named

```bash
./.logic-loom/scripts/bash/scaffold-environments.sh --apply --only=envconf,checklist
```

`--only` is mandatory with `--apply`; there is no "apply everything by
omission". `--only=all` accepts every **proposed** target and still never
touches a conflicting or already-scaffolded file. `--deploy-dir DIR` moves the
product-owned seams (default `scripts/deploy`).

There is **no `--force`**, deliberately. If a file already exists, it stays.
Tell the user to move it aside themselves and re-run if they want the
scaffolded version — never offer to overwrite it for them.

### Step 5 — Validate and hand over

```bash
./.logic-loom/scripts/bash/validate-environments.sh
```

Then tell the user, in this order:

1. **The CI guard only fires once it exists on the production branch.** For
   `pull_request` events GitHub evaluates the workflow from the **base** branch.
   Unmerged, it never runs. This is the single most likely way the scaffolding
   silently does nothing.
2. **Every `deploy` seam is an unimplemented placeholder that exits 1.** That is
   deliberate — a placeholder exiting 0 would report a deployment that did not
   happen. Nothing has been deployed.
3. **The rehearsal seed allowlist was not created**, if a staging environment
   was declared. It is theirs, and their seed must **abort** on an empty or
   missing allowlist rather than widen to "copy everything".
4. **Nothing scaffolded is enforced.** No hook reads any of it.

## What this command will never write

Cloud or CI-provider deploy logic, secret values, a migration runner, a seed or
teardown script, or a rollback mechanism. Those are the product's
(`environment-promotion-policy.md` § 8 and § 10). If a request pushes toward
building any of them, say no and point at the seam — the seam exists precisely
so the harness does not have to have an opinion about the vendor.

## Constitutional notes

- **Principle IV (Idempotency)** — a second run is a no-op and says so.
- **Principle V (Progressive Enhancement)** — proposes only what the detected
  topology supports; one environment is a complete answer.
- **Principle VI (Git Approval)** — runs no git at all. Branch detection reads
  `.git` refs off the filesystem, and no branch is ever created.

## Reference

- Skill: `plugins/loom-maintenance/skills/environment-scaffolding/SKILL.md`
- Methodology: `.docs/policies/environment-promotion-policy.md`
- Declaration schema: `.logic-loom/config/environments.conf`
