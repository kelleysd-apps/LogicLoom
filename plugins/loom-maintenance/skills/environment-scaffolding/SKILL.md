---
name: environment-scaffolding
description: |
  Opt-in scaffolding for the environment-promotion methodology — detect what a
  repository already has, propose a delta, and write only the files the user
  names. Never overwrites, never deploys, never runs git.

  Triggered by: /scaffold-environments, "set up environments", "adopt the
  promotion methodology", "add a staging environment declaration", "branch
  boundary CI check", "environments.conf"
allowed-tools: Read, Bash, Glob, Grep
category: maintenance
---

# Environment Scaffolding Skill

## Purpose

`.docs/policies/environment-promotion-policy.md` writes the promotion
methodology down. This skill stands it up in the user's own project — as
**scaffolding**, not as machinery.

**Workflow**: `/scaffold-environments` (plan) → user picks targets → apply →
`validate-environments.sh`

---

## The one thing that makes this hard

**The target is an EXISTING repository.** Greenfield is the easy case and the
rare one. A repo that already has branches, a CI provider, environment-ish
workflows, and possibly an `environments.conf` is the normal case, and
scaffolding that assumes a blank tree will:

- propose creating a `staging` branch to a team that has had one for two years;
- overwrite a hand-written deploy script with a placeholder;
- add a branch-boundary guard that fails every PR the team opens.

Every design decision below exists to prevent one of those three.

---

## The five invariants

1. **Detect, never assume.** `detect-environment-topology.sh` reads the tree.
   Anything it cannot determine is reported `unknown` — never guessed.
2. **Propose a delta, not a layout.** Roles are matched against branches that
   **already exist**. A role with no branch yields no environment. No branch is
   ever created.
3. **Never overwrite.** A file that exists is left alone. There is no `--force`.
   The marker `LOOM-SCAFFOLD-MARKER: environment-promotion` distinguishes *our*
   file (idempotent no-op) from *theirs* (conflict, hands off).
4. **Per-file opt-in.** `--apply` requires `--only=…`. There is no
   apply-everything-by-omission.
5. **Declining costs nothing.** `--plan` writes no file, so backing out leaves
   the tree byte-identical.

---

## Scripts

| Script | Role |
|---|---|
| `.logic-loom/scripts/bash/detect-environment-topology.sh` | Read-only detection. `--format kv` for machines, default report for humans. |
| `.logic-loom/scripts/bash/scaffold-environments.sh` | Plan / apply. `--plan` (default) writes nothing; `--apply --only=…` writes. |
| `.logic-loom/scripts/bash/validate-environments.sh` | Pre-existing reader/validator for the declaration. |

### Why detection does not shell out to git

Refs are read straight off the filesystem — `.git/HEAD`, `.git/refs/**`,
`.git/packed-refs`, and a linked worktree's `gitdir:` pointer. Three reasons,
all load-bearing:

- it is **provably** non-mutating (Principle VI), with no argument surface for a
  mutation to hide in;
- it works under `subagent-git-guard.sh`, which denies mutating git to a
  subagent;
- it is testable against a hand-built `.git` directory, so the fixtures need no
  repository at all.

The cost, stated plainly: it reads git's on-disk format rather than asking git.
Loose refs, packed refs, symbolic and detached HEAD, and linked worktrees are
handled. A bare repo with an unusual layout, `core.worktree` indirection, or a
ref stored elsewhere is not — and reports `unknown` rather than a guess.

---

## Role inference

| Role | Branch aliases matched, in order |
|---|---|
| production | `main` `master` `prod` `production` `release` `live`; else the default branch |
| integration | `dev` `dev-main` `develop` `development` `integration` `next` `trunk` |
| staging | `staging` `stage` `rehearsal` `preprod` `pre-prod` `uat` `qa` |

A branch holds at most one role. **Only existing branches match.**

The resulting chain becomes `dev → staging → prod`, omitting any link with no
branch. Greenfield (`main` only) therefore yields exactly **one** environment,
which is the Principle V answer, not a degraded one.

---

## The five targets

| Target | Path | Condition for proposing it |
|---|---|---|
| `envconf` | `.logic-loom/config/environments.conf` | at least one role matched |
| `ci-guard` | `.github/workflows/branch-boundary-guard.yml` | GitHub Actions **and** an integration or staging branch exists |
| `checklist` | `.docs/policies/promotion-checklist.md` | always |
| `deploy-stubs` | `<deploy-dir>/deploy-<env>.sh` | one per planned environment |
| `branch-base-check` | `<deploy-dir>/check-branch-base.sh` | an integration branch exists **and** the default branch is known |

The conditions are the interesting part — each one is a case where scaffolding
the file would be actively wrong:

- **No integration or staging branch → no CI guard.** Their `main` legitimately
  takes feature branches. A boundary guard would fail every PR.
- **Non-GitHub CI → no CI guard.** The pattern is in the policy § 3; porting it
  by hand beats this tool guessing at another provider's syntax.
- **No integration branch → no branch-base check.** The default-branch trap does
  not arise until there is a second long-lived branch to get wrong.
- **Unknown default branch → no branch-base check.** A guard generated against a
  guessed arrangement is worse than none. Fail closed (§ 4.2).

---

## The default-branch trap — generalize it, do not copy LogicLoom's

Policy § 2. Tooling that bases a branch on "the default branch" reads a pointer
written once at clone time; it goes stale silently, and nothing errors.

**The fix is topology-dependent, and this is the trap for the scaffolder
itself.** LogicLoom's own arrangement is the *counter-example*: its default
branch (`main`) genuinely **is** its production line, because `main` is the
sanitized template that "Use this template" clones. `git remote set-head origin
--auto` does not apply there, and a customer project must not inherit that
inversion.

So the generated check is parameterized by a detected **mode**:

| Detected | Mode | Generated remedy |
|---|---|---|
| default branch **is** the integration branch | `expect-default-is-integration` | keep `origin/HEAD` fresh: `git remote set-head origin --auto` |
| default branch is **not** the integration branch | `expect-explicit-base` | name the base explicitly; `set-head --auto` will not help and the script says so |
| no integration branch | *(not scaffolded)* | the trap does not arise yet |
| default branch unknown | *(not scaffolded)* | fail closed rather than guess |

The generated script also **notices when its own assumption has gone stale** —
if `origin/HEAD` no longer matches the arrangement it was generated for, it says
so and tells the user to re-run `/scaffold-environments`.

---

## Hard boundary — what is never written

Cloud or CI-provider deploy logic, secret values, migration runners, seed
scripts, teardown jobs, rollback mechanisms.

The `deploy` seam is a **commented placeholder that exits 1**. A placeholder
exiting 0 would report a deployment that did not happen — the exact failure
§ 4.2 exists to prevent.

> **If you find yourself writing a deploy runner, stop.** Principle V, and
> policy § 10: no adapter, seed script, teardown job, promotion command, or CI
> deployment workflow ships with LogicLoom.

---

## After applying — say these four things

1. **The CI guard only fires once it is merged to the production branch.** For
   `pull_request` events GitHub evaluates the workflow from the base branch.
   This is the most likely way the scaffolding silently does nothing.
2. **Every deploy seam is unimplemented and exits 1.** Nothing was deployed.
3. **The rehearsal seed allowlist was not created.** Their seed must **abort**
   on an empty or missing allowlist, never widen to "copy everything" — that
   degradation is how production personal data reaches a lesser environment
   silently.
4. **Nothing scaffolded is enforced.** No hook reads any of it.

---

## Anti-patterns

| Do not | Because |
|---|---|
| Default to `--only=all` without asking | Per-file opt-in is the design, not a formality |
| Offer to overwrite a conflicting file | There is no `--force`; the user moves it aside themselves |
| Summarize away a `SKIP` line | A skip is usually the correct answer and the user needs the reason |
| Report a green apply as "environments are set up" | Nothing is enforced and nothing is deployed — "it scaffolded" and "it works" are different claims |
| Create a branch to fill an empty role | The tool reads branches; it never creates one |
| Add a deploy runner "just to get them started" | Policy § 8, § 10, Principle V |
