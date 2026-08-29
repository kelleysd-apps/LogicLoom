---
name: promote-prod
description: The full production release cycle — rehearsal contract, promotion order, and a typed exact phrase that no flag can bypass. Gates and confirms; deploys nothing.
model: sonnet
---

# /promote-prod Command

**The top rung.** `/promote-dev` → `/promote-staging` → **`/promote-prod`**.

This is the command with the sharp edge on it. Everything below is the same
gate the other two run, plus two things they do not have: the **rehearsal
contract** (policy § 6.1) and a **typed exact phrase that no flag bypasses**
(§ 4.3).

## What this command is

A **gate and a confirmation**. It does not deploy, migrate, seed, tear down,
roll back, call a cloud or CI provider, or touch a secret. The release itself is
behind the `deploy` seam — a **product-owned** script the harness names and
never inspects (§ 8, § 10). A production release command that could not deploy is the point,
not a limitation: the harness has no business holding your production
credentials.

## The confirmation, and why no flag opens it

| Promoting into | Confirmation | Skippable |
|---|---|---|
| dev | plain yes/no | yes — `--yes` |
| staging | plain yes/no | yes — `--yes` |
| **production** | **typed exact phrase** | **NO. No flag. None.** |

`--yes` is *read* by the gate at this rung and deliberately does nothing but
print a note saying it was ignored. There is no environment variable, no
`--force`, and no non-interactive mode that skips it. The only way past is to
type the phrase.

Where an override is genuinely needed at production scale, it is scoped to one
specific **check** — `--allow-stale-rehearsal "<reason>"` covers the staleness
bound and nothing else — **never** to the confirmation step. That asymmetry is
the pattern; do not offer to work around it.

**The phrase comes from the declaration.** `confirm = typed:<PHRASE>` in the
production block of `.logic-loom/config/environments.conf` is the source of
truth. The command's own default (`typed:PROMOTE TO PRODUCTION`) applies only
when the block declares no `confirm`. The validator already refuses
`confirm = typed:…` alongside `requires_approval = false` — "demand a typed
phrase" and "no approval needed" cannot both be true.

## Execution Instructions

### Step 1 — Run the gate

```bash
./.logic-loom/scripts/bash/promote-gate.sh \
  --to prod --stage prod \
  --default-confirm 'typed:PROMOTE TO PRODUCTION' \
  --require-rehearsal --commit "<sha being released>"
```

`--commit` is **mandatory** here: without it the rehearsal contract cannot be
evaluated, and an unevaluable gate fails closed rather than passing.

Optional: `--max-rehearsal-age-days N` (default 14, or
`$LOOM_REHEARSAL_MAX_AGE_DAYS`).

### Step 2 — Exit codes

`0` cleared · `1` **refused** · `2` usage · `3` nothing declared →
`/scaffold-environments`.

**Relay a refusal verbatim and stop.** Do not re-run with an override, do not
re-run "to see if it was transient", and do not summarize a refusal into
something softer. Every refusal names its own override if one exists; if it says
`OVERRIDE: none`, there is none.

### Step 3 — What the gate checked, and what it took on trust

Say this to the user plainly when the gate clears. The honesty is the feature.

**Verified by the harness:**

- The declaration parses and is coherent (via `validate-environments.sh`).
- `prod`'s predecessor has a **successful promotion on record** in the ledger.
- A rehearsal attestation for that predecessor **exists, is readable, and
  declares `status = success`**.
- Its `completed_at` **parses** and falls inside the staleness bound. An
  unparseable timestamp refuses — it is never treated as recent.
- The commit being released is **either** the attestation's `rehearsed_commit`
  **or** is listed in its `covers_commits`.
- The declared `deploy` seam **exists and is executable**.

**Taken on trust — the harness cannot check these and does not pretend to:**

- That a rehearsal actually ran, and actually passed.
- That `rehearsed_commit` really is an **ancestor** of what is being released.

The harness **runs no git and calls no CI API**. Ancestry is a *declared
contract* the product's rehearsal seam reports; the gate checks that a declaration
exists and matches, not that it is true. Per § 6.4, the commit actually rehearsed
may be a merge's **second parent** — a seam that writes the merge head writes a
plausible wrong answer, and this gate will accept it. If that trust level is not
good enough for your blast radius, strengthen the **seam**, not the harness.

### Step 4 — Hand over the release

The user runs the seam. You do not. Order is structural: **migrate before
deploy** as a dependency edge in the pipeline graph (§ 4.1), never step order
inside a script.

Any git mutation the release needs — a tag, a merge into the production branch,
a push — is **Principle VI**: surfaced for approval individually, never run
autonomously. The gate runs no git.

### Step 5 — Record the outcome

```bash
./.logic-loom/scripts/bash/promotion-record.sh --env prod --status success --commit "<sha>"
./.logic-loom/scripts/bash/promotion-record.sh --env prod --status failure --commit "<sha>" --note "<what broke>"
```

**On failure, teardown is intentionally skipped** (§ 4.5). Teardown of the
rehearsal environment lives in this release pipeline, gated on every deploy step
succeeding. A failed release leaves the rehearsal environment standing on
purpose — it is the diagnostic diff between "the rehearsal passed" and
"production failed". Do not tear it down to tidy up, and do not suggest it.

### Step 6 — GitHub Release: verify it exists, and say who published it

**Read the scope line first, because it is the honest part: this command cannot
drive a LogicLoom template release today.** The harness release path is
`/promote` → merge → `.github/workflows/release-tag.yml`, and `/promote` is
maintainer-only and stripped from a customer's clone. `/promote-prod` ships to
customers and has no route into it. **LOOM-0035** — consolidating the two into a
single `/promote-prod` — is the work that makes this step something this command
*drives* rather than something it *checks*. Until then, do not claim otherwise.

**Live now** (any project whose release cuts a GitHub Release, harness included):
verify the Release exists, and report it. A tag is not a release.

```bash
gh release view "<tag>" --json url,isDraft,name,tagName
```

- **No such release → report it as a gap, not a pass.** This is the failure that
  actually happened here: from **v6.2.0 to v6.5.0 the harness release path
  pushed five tags and published zero Releases** (6.3.0, 6.3.1, 6.4.0, 6.4.1,
  6.5.0), and the Releases page showed v6.2.0 as "Latest" the whole time.
  Nothing went red, because nothing was asserting it.
- **`isDraft: true` → correct.** CI stages a draft; it never publishes. A human
  proofreads the notes and hits Publish — the act that flips "Latest" and
  notifies watchers stays human, deliberately.
- Report **URL**, **`isDraft`**, and `tagName`. Naming only the tag is not a
  verification of the release.
- **Creating or publishing the Release is not this command's job.** Like every
  other outward act here, it is surfaced and handed over.

**Lands with LOOM-0035**: the consolidated `/promote-prod` owns GitHub Release
publication end to end — dispatching the release workflow, verifying the draft
appeared, and handing the maintainer the Publish gate — under the same typed
exact phrase this rung already requires.

**One-release lag, for the harness path.** `release-tag.yml` is triggered by
`push:`, so GitHub runs the copy of the file **at the pushed commit**. The draft
Release step first runs for **v6.6.0**; it did not and cannot run for v6.5.0,
which was published by hand.

### Step 7 — Report what happened, not what you hope happened

A successful release means the seam exited zero. It does not mean the release
works. There is typically no automated end-to-end test driving the artifact
against a live environment and no core user flow gated by CI (§ 6.3).
**"It deployed successfully" and "it was proven to work" are different claims,**
and reporting the first as the second — in a status update, a release note, or
your own summary of your own work — is the failure this step exists to prevent.

## Standing hazards worth naming at release time

- **Migrations are forward-only** unless you built a reverse path. Every
  migration must be safely re-runnable, and none may ever be applied
  out-of-band (§ 5.2, Principle IV).
- **Data crosses one way only**: production → rehearsal, allowlist-scoped.
  Never production → dev, never staging → production. No exception, no override;
  "just this once, to reproduce a bug" is the request this rule refuses (§ 5.1).
- **Secrets that encode neither environment nor mode** are how a test-mode
  payment credential ends up silently serving production traffic — a real
  incident, caught only by a human diffing key digests (§ 4.6).
- **Vendor-dashboard-only configuration** is never code-reviewed and drifts
  silently between environments. Nobody has solved this; naming it is the
  available control (§ 4.7).
- **No schema-drift detection and no secret-parity checking exist** — here, in
  the source methodology, or anywhere in LogicLoom (§ 7). Their absence is a
  gap, not a design decision. Do not present it as coverage.

## Reference

- Skill: `plugins/loom-maintenance/skills/promotion-lifecycle/SKILL.md`
- Methodology: `.docs/policies/environment-promotion-policy.md` (§ 4.3, § 6, § 12)
- Attestation contract: `.logic-loom/templates/environment-promotion/rehearsal-attestation.conf.tmpl`
- Previous rung: `/promote-staging`
