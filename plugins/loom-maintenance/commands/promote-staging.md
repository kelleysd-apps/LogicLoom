---
name: promote-staging
description: The middle rung of the promotion ladder — gate a promotion into the rehearsal environment. Checks the promotion order and that the rehearsal seam exists, confirms, then prints the project-owned seam command that actually stands up staging and runs the smoke pass. Gates and confirms; deploys nothing.
model: sonnet
---

# /promote-staging Command

**The middle rung.** `/promote-dev` → **`/promote-staging`** → `/promote-prod`.

Staging here is not "a smaller production you keep around". It is a
**rehearsal**: the environment whose whole job is to run, in advance, the thing
`/promote-prod` is about to do — and to leave behind an **attestation** that
`/promote-prod` will refuse to proceed without.

## What this command is

A **gate and a confirmation** over the rehearsal seam. It checks that dev has
been promoted, that the rehearsal environment's `deploy` seam exists, asks a
plain yes/no, and prints the seam command.

## What it is not, and never will be

It does not stand up an environment, seed one, tear one down, run a migration,
call a cloud or CI provider, handle a secret, or roll anything back. **All of
that is the rehearsal seam's job** — a product-owned script named by
`deploy` in `.logic-loom/config/environments.conf`, which the harness never
inspects and never runs (policy § 8, § 10).

## Execution Instructions

### Step 1 — Run the gate

```bash
./.logic-loom/scripts/bash/promote-gate.sh \
  --to staging --stage staging --default-confirm prompt \
  --from-ref "<integration-branch>" --commit "<sha>"
```

`--yes` skips the yes/no prompt for automation. It stops working at the next
rung, by construction.

`--default-confirm prompt` is a fallback only — a declared `confirm` in the
staging block wins.

### Step 2 — Exit codes

`0` cleared · `1` **refused, reason printed verbatim — relay it and stop** ·
`2` usage · `3` **nothing declared → point at `/scaffold-environments`**.

The most common refusal here is the promotion order: staging declares
`promotes_from = dev`, and no successful dev promotion is on record. The
refusal names the missing predecessor and the override
(`--allow-out-of-order "<reason>"`, which requires a non-empty reason). Do not
reach for the override on the user's behalf.

### Step 3 — Hand over the rehearsal seam

The user runs it. You do not. What their seam must do — none of it shipped by
LogicLoom, all of it in policy § 4.4:

1. **Fork production with zero data.** Its own database, auth schema, function
   runtime, endpoint. Not a shared slice of production, not a production clone.
2. **Seed in two tiers.** Reference/configuration tables (no personal data) in
   full; per-account tables **only** for accounts on an explicit allowlist —
   a deliberately opted-in set, never a representative sample.
3. **Fail closed on the allowlist.** An empty or missing allowlist **aborts the
   seed**. It must never degrade to "copy everything" — that is how production
   personal data lands in a lesser environment silently. Declare the allowlist's
   path as `rehearsal_seed_allowlist`; the harness records where it lives and
   never opens it.
4. **Reuse, do not recreate.** "Per rehearsal" is the wrong model. Find the
   newest healthy rehearsal environment and reuse it; a fresh one happens on an
   explicit manual reset. "Per cycle, until reset" is the accurate framing, and
   data written in one rehearsal survives into the next.
5. **Migrate before deploy, structurally** (§ 4.1) — a dependency edge in the
   pipeline graph, not step order inside a script.

**The absolute rule:** the rehearsal pipeline **never writes to the production
database**. If it must touch any production resource at all, name that resource
explicitly in your own policy copy and treat a second one as a change requiring
review.

### Step 4 — Write the attestation, then record the outcome

The rehearsal is only worth something to `/promote-prod` if it leaves an
attestation behind. **The seam writes it; the harness never does.**

Path: `.logic-loom/state/rehearsal-<staging-env>.conf` (or
`$LOOM_PROMOTION_STATE_DIR`). Template and full contract:
`.logic-loom/templates/environment-promotion/rehearsal-attestation.conf.tmpl`.

```
environment      = staging
status           = success
completed_at     = 2026-08-24T15:04:00Z
rehearsed_commit = <the commit ACTUALLY rehearsed>
covers_commits   = <shas this rehearsal is asserted to cover>
```

> **The § 6.4 trap — say this to the user.** If the staging branch is rebuilt
> from production and re-merged with integration, the commit actually rehearsed
> is the **merge's second parent**, not the merge head. A seam that writes the
> merge head produces a *plausible wrong answer* that the production gate will
> accept. If the seam cannot identify the rehearsed commit unambiguously, it must
> write `status = failure` — never a guess.

Any git mutation the rehearsal needs — merging integration into the staging
branch, pushing it — is **Principle VI**: surfaced for approval individually,
never run autonomously. The gate runs no git.

Then record:

```bash
./.logic-loom/scripts/bash/promotion-record.sh --env staging --status success --commit "<sha>"
```

### Step 5 — On failure, do not tidy up

Policy § 4.5: **keep the rehearsal environment alive on failure.** Teardown
belongs in the *production release* pipeline, gated on every deploy step
succeeding — so a production failure deliberately **skips** it. The surviving
environment is the diagnostic diff between "the rehearsal passed" and
"production failed". The instinct to clean up the mess destroys the single most
useful artifact the failure produced.

## What a green rehearsal proves — and does not

**Proves** (§ 6.2): migrations apply cleanly against a production-schema
database; the authorization invariant holds before and after migrate+seed
(failing if *any* previously-authorized account loses access **and** if *zero*
accounts end up authorized — the second half is what proves the seed worked);
backend functions deploy and answer a health check; the client artifact builds.

**Does not prove** (§ 6.3): that anything works. Typically **no** automated
end-to-end test drives the built artifact against the live rehearsal
environment, and **no core user flow** — login, the primary feature, billing —
is exercised. Report the rehearsal as "it deployed", never as "it was proven to
work". That distinction is the one this command exists to keep honest.

## Reference

- Skill: `plugins/loom-maintenance/skills/promotion-lifecycle/SKILL.md`
- Methodology: `.docs/policies/environment-promotion-policy.md` (§ 4.4, § 4.5, § 6, § 12)
- Previous rung: `/promote-dev` · Next rung: `/promote-prod`
