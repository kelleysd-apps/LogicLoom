# Environment Promotion Policy

**Version**: 1.0.0
**Effective Date**: 2026-08-22
**Authority**: Constitution v3.3.0 — Principle IV (Idempotency), Principle V (Progressive Enhancement), Principle VI (Git Operation Approval), Principle VII (Observability)
**Review Cycle**: Quarterly

---

## Purpose

This policy records the **methodology** by which work moves from a coding
environment (a branch, a worktree) to a deployed environment (dev, a staging-style
rehearsal, production) — and, just as importantly, what that movement does **not**
establish.

It is a companion to two siblings, and it deliberately does not repeat them:

- `.docs/policies/branching-strategy-policy.md` owns **branch conventions**.
- `.docs/policies/deployment-policy.md` owns **environments as roles** and the
  machine-readable `environments.conf` declaration.

This document owns the **seam between them**: which coding branch feeds which
deployed environment, what may cross an environment boundary in which direction,
how a rehearsal environment is stood up and torn down, and what a green pipeline
run proves.

> **Nothing in this policy is enforced.** No hook reads it. LogicLoom ships **no
> deployment machinery, no pipeline, no seed script, no teardown job, and no CI
> workflow for any of this** — consistent with `deployment-policy.md`, which
> states the same thing for the environment model it defines. This is policy and
> convention; the machinery is yours.

---

## Constitutional Alignment

- **Principle IV (Idempotency)** — migrations and seeds must be safely re-runnable;
  the non-idempotent-migration hazard in § 5.2 is a direct instance.
- **Principle V (Progressive Enhancement)** — do not stand up a three-environment
  promotion chain before one environment is proven in use. One environment, or
  none, is a valid answer.
- **Principle VI (Git Operation Approval)** — every git mutation in a promotion
  path is gated by the git-safety hook. The escalating-confirmation pattern in
  § 4.3 sits *on top of* that gate; it never replaces it.
- **Principle VII (Observability)** — a gate that cannot evaluate itself must say
  *why*, in the log, at the moment it fails (§ 4.2).

---

## Scope

Applies to any repository built with LogicLoom that deploys anywhere at all,
including LogicLoom's own repository (which promotes a sanitized template line
rather than an application — see § 2.2).

A project that deploys nowhere can ignore this policy entirely.

---

## Evidence grading — read the labels

The methodology below is adapted from a generalized handoff of a real, running
pipeline at another team. Every substantive claim carries one of three labels,
and they are not interchangeable:

| Label | Means |
|---|---|
| **VERIFIED** | Observed running in a real pipeline, or observed in this repository. Not aspirational. |
| **RECOMMENDED** | A pattern worth adopting that the source team has **not** fully implemented either. Treat as a target state. |
| **UNSOLVED** | A known gap with no pattern behind it. Do **not** copy it forward as a design choice. See § 7. |

The distinction matters more than the content. A reader who takes an UNSOLVED
gap for a considered design has inherited a defect and a false sense of coverage.

---

## 1. Coding environments → deployed environments

**VERIFIED.** The mapping is **coarse, not one-to-one with branches.**

| Coding environment | Deploys to |
|---|---|
| Feature branch / worktree | **Nowhere.** No deployed environment tracks it. |
| Integration branch | dev |
| Staging branch | the rehearsal environment (§ 4.4) |
| Production branch | the release |

Two things follow from "coarse, not 1:1":

1. **Not every branch earns an environment.** Feature branches deploying nowhere
   is the design, not a gap. Per-branch preview environments are a separate
   capability with a separate cost; do not assume this mapping implies them.
2. **Not every environment is fed by exactly one branch.** A staging branch that
   is periodically rebuilt from production and re-merged with integration is not
   a pure mirror of either — which is precisely what makes the ancestry check in
   § 6.3 non-obvious.

**Worktrees.** Concurrent work happens in isolated git worktrees — each an
independent checkout on its own branch — so several engineers or agents work in
parallel without colliding in a working directory. This is already how LogicLoom
operates (`EnterWorktree` / `ExitWorktree`, plus `worktree-port-namespace.sh` for
per-worktree port and database namespacing).

---

## 2. The default-branch trap

### 2.1 The trap, and the general fix

**VERIFIED — observed in the source pipeline, and independently in this
repository (§ 2.2).**

Tooling that creates a branch or worktree "off the default branch" typically
resolves that by reading a local ref equivalent to `origin/HEAD`. That pointer is
set **once, at clone time**, and goes stale silently if the repository's default
branch changes later. Nothing errors. The wrong base is simply checked out, and
every downstream artifact — a diff, a review, a test run — is quietly about the
wrong tree.

The source pipeline's stated resolution is to keep the pointer fresh:

```bash
git remote set-head origin --auto
```

…and to configure the **integration** branch as the repository's default branch,
so that tooling reading "the default branch" gets the integration base rather
than the production base.

**RECOMMENDED for your project.** If you run an integration branch, make it the
repository default, and refresh `origin/HEAD` as above. The failure mode this
prevents is silent, and the fix costs one command.

### 2.2 LogicLoom's exception — the general fix does not apply here

> **Why this section ships to you.** `.docs/policies/` is downstream-facing, and
> `branching-strategy-policy.md` § *A note on LogicLoom's own repository* is right
> that LogicLoom's template topology is **not** a prescription for a product
> repository. This section is here anyway, as a **worked counter-example**: it is
> the clearest available demonstration that "point tooling at the default branch"
> is advice with a precondition, not a law. § 2.3 states what *your* project
> should do, and it is the opposite of what this section describes.

**LogicLoom cannot make its integration branch the default, and its `origin/HEAD`
is not stale.**

LogicLoom's default branch must remain `main`, because `main` is the **public,
sanitized template line** that GitHub's "Use this template" clones from. Making
`dev-main` the default would hand every cloner the unsanitized dev tree — the
exact leak that `branch-topology-guard.yml`, `leak-guard.yml`, and the
promote-time sanitization audit exist to prevent.

So the source doc's fix is inapplicable in two directions at once:

- The pointer is **not stale** — `origin/HEAD` correctly names `main`.
- The default branch **genuinely is** the production line. There is nothing to
  correct.

**VERIFIED consequence, observed in this repository.** `EnterWorktree` bases new
worktrees on `origin/<default-branch>`. A worktree therefore came up on the
v6.4.1 sanitized release merge instead of on `dev-main`, and a review agent then
analyzed the **sanitized template** and produced findings that were artifacts of
the wrong tree — files that exist in dev and are stripped at promote read as
"missing", and stubbed files read as "incomplete".

**The guard LogicLoom needs is therefore the opposite of the source doc's.**

> **Rule (LogicLoom repository).** Any tooling that creates a branch or worktree
> for development work must base it on the **integration branch, named
> explicitly** — `dev-main` — and must never resolve its base from the default
> branch, from `origin/HEAD`, or from an unqualified "main". A worktree that
> comes up on `main` in this repository is a bug, not a preference.

This is **followed, not enforced**: nothing currently checks it. Recorded as
backlog item **LOOM-0024**.

### 2.3 What a customer project should do instead

**A project adopting LogicLoom has no such constraint.** Its `main` is an ordinary
production branch that receives feature branches — `branch-topology-guard.yml` is
maintainer-only in intent and is removed at `/initialize-project` for exactly this
reason. A customer project should follow § 2.1: default branch = integration
branch, and keep `origin/HEAD` fresh.

Do not carry LogicLoom's exception into a product repository. It exists because
LogicLoom is a distributed template, and `branching-strategy-policy.md` § *A note
on LogicLoom's own repository* already says plainly that this topology is not a
prescription for anyone else.

---

## 3. The branch boundary belongs in CI, not in convention

**VERIFIED — in the source pipeline, and in this repository.**

A stated branching convention is not a boundary. The source pipeline enforces its
boundary with a CI check that **hard-fails any pull request whose base is the
production branch unless its head is exactly the integration branch or the staging
branch**. It is a currently-firing check: it has correctly rejected a PR opened
directly against the production branch and forced it back through the intended
path before it could merge.

**LogicLoom independently built the same thing, and it is the reference
implementation:** `.github/workflows/branch-topology-guard.yml` fails any PR into
`main` whose head is not a machine-composed `release/vX.Y.Z` branch.

Three properties of that implementation are the part worth copying, independent of
the regex:

1. **It fails closed.** An empty `github.head_ref` is a failure, not a pass.
2. **It has no exemptions** — no label, no actor allowlist, no skip flag. Every
   escape hatch is a route for exactly the content the gate exists to stop.
3. **It is tamper-proof by placement.** For `pull_request` events GitHub evaluates
   the workflow from the **base** branch, so a PR cannot modify the copy that
   judges it.

**RECOMMENDED.** Adapt the one-line allowed-head regex to your own topology, or
delete the file if your `main` takes feature branches normally.

---

## 4. Portable patterns

These are the patterns the source team explicitly nominated for extraction into a
provider-agnostic harness.

### 4.1 Migrate-before-deploy, enforced structurally

**VERIFIED.** Migration ordering is enforced by **explicit job dependencies in the
pipeline graph** — the migration step gates every deploy step that depends on it —
not by documentation, not by step ordering within a job, and not by convention.

The distinction is the whole point. A documented ordering is followed until
someone reorders steps in a hurry; a dependency edge cannot be skipped without
editing the graph, which is reviewable.

### 4.2 Fail closed, with a typed reason — house style

**VERIFIED as practice; nominated by the source team as "the single most reusable
pattern in the whole system."** It is adopted here as **house style for every gate
LogicLoom ships or advises.**

> **The rule.** A gate that cannot evaluate its own condition — an API outage, an
> unparseable date, an ambiguous ancestry check, an empty input — must **fail**,
> and must print (a) *why* it could not evaluate, and (b) *which* override exists,
> if one does. It must never silently pass, and never fail silently either.

Both halves are load-bearing. Failing closed without a reason produces a red build
nobody can act on; printing a reason while passing optimistically produces a green
build that proves nothing.

This is the sibling of `.docs/policies/shell-idiom-policy.md`, and the two should
be read together. That policy records five shell idioms, each traced to a real
failure; this rule is the same discipline one level up — at the gate rather than
at the statement. Where shell-idiom § 1 keeps a status from being silently lost,
this rule keeps a *verdict* from being silently invented.

Instances already in this repository, cited as the worked examples:

| Gate | Fails closed on |
|---|---|
| `.logic-loom/scripts/bash/check-generated-freshness.sh` | Any tracked generated artifact differing from a fresh regeneration. |
| `.github/workflows/branch-topology-guard.yml` | An empty or non-matching PR head ref. |
| `validate-environments.sh` | A cycle, a duplicate name, an undeclared predecessor, an out-of-block key. |

Note the deliberate counter-example in the same tree: the backlog **dashboard
generator** is fail-**open** by explicit contract, because a viewer must not gate a
workflow — and `check-generated-freshness.sh` documents at length why the
fail-closed check therefore lives in a separate script rather than as a `--check`
mode inside the fail-open tool. Fail-closed is the default, not a universal.

### 4.3 Escalating confirmation strength by blast radius

**VERIFIED.** Confirmation strength scales with what an error costs:

| Promoting into | Confirmation | Skippable? |
|---|---|---|
| dev | none, or a light prompt | yes |
| staging / rehearsal | a plain yes/no prompt | yes, via an automation flag |
| **production** | a **typed exact phrase** | **no — no flag bypasses it** |

The sharp edge is the last cell. An automation flag that suppresses ordinary
prompts must explicitly **not** bypass the production confirmation. Where an
override is genuinely needed at production scale, it should be narrowly scoped to
one specific *check* — for example, a staleness bound — never to the confirmation
step itself.

**Partially implemented in this repository.** `/promote` implements the ladder's
*shape*: every git mutation is surfaced individually for approval under Principle
VI, there is no skip flag anywhere in the procedure, and the sanitization audit is
a hard stop that refuses to open a PR on failure. What it does **not** have is a
literal typed-exact-phrase step; its production-scale confirmation is the
per-mutation Principle VI approval prompt. Stated plainly rather than claimed,
because "it has an approval gate" and "it has a typed-phrase gate" are different
claims.

Declarable per environment as `confirm` in `environments.conf` — see § 9.

### 4.4 The ephemeral rehearsal environment

**VERIFIED.** The shape, in order:

1. **Fork production with zero data.** The rehearsal environment gets its own
   database, its own auth schema, its own function runtime, its own endpoint. It
   is **not** a shared slice of production, and **not** a production clone.
2. **Seed in two tiers.**
   - **Reference / configuration tables — cloned in full, containing no personal
     data.** The rows that define product *behaviour* rather than describe users:
     plan definitions, catalog metadata, feature configuration, evaluation
     baselines.
   - **Per-account tables — copied only for accounts on an explicit allowlist.**
     Not a representative sample. A deliberately opted-in set.
3. **Fail closed on the allowlist.** An empty or missing allowlist file **aborts
   the seed entirely**. It must never degrade to "copy everything" — that failure
   mode copies production personal data into a lesser environment silently. This
   is § 4.2 applied to the highest-consequence input in the pipeline.
4. **Keep the allowlist small, and audit it.** It is the single biggest lever on
   how *realistic* versus how *safe* a rehearsal is. It will not stay narrow by
   default.

> **A second legitimate model.** `deployment-policy.md` characterizes staging data
> as "production-like data (anonymized)". Anonymization and allowlist-scoping are
> **two different answers to the same question**, with different failure modes:
> anonymization risks an incomplete transform leaking a real identifier;
> allowlist-scoping copies real rows and depends entirely on the allowlist staying
> narrow and fail-closed. Pick one deliberately, and say which in your own copy —
> they are alternatives, not a contradiction, and doing neither is the failure.

**Persistence — the part most likely to surprise you. VERIFIED.** "Per rehearsal"
is the wrong mental model. The pipeline finds the newest healthy rehearsal
environment and **reuses** it; data written during one rehearsal survives into the
next. A fresh environment happens only on an explicit manual reset. "Per cycle,
until reset" is the accurate framing.

**Cadence. VERIFIED.** On-demand only — a push to the staging branch, or a manual
dispatch. No schedule. Runs cluster around active promotion windows.

**The one production resource the rehearsal pipeline writes to. VERIFIED.** In the
source pipeline: production object storage, for an update-channel artifact. The
operating rule is absolute and worth adopting verbatim — **the rehearsal pipeline
never writes to the production database.** If your rehearsal pipeline must touch a
production resource at all, name that resource explicitly in your own copy of this
policy, and treat any second one as a change requiring review.

### 4.5 Keep the rehearsal alive on failure; tear down only on success

**VERIFIED, and nominated as genuinely portable.**

**Teardown lives in the production release pipeline, not the rehearsal pipeline**,
gated on every deploy step of that release succeeding. Two consequences:

- The rehearsal environment is deleted the moment a production release **fully
  succeeds**. Teardown is a side effect of a successful promotion — not a
  scheduled job, not an independent one.
- **On a production failure, teardown is intentionally skipped.** The surviving
  environment is the diagnostic diff between "the rehearsal passed" and
  "production failed."

The instinct to tear down on failure — to clean up the mess — destroys the single
most useful artifact the failure produced.

### 4.6 Secret names that encode environment

**RECOMMENDED — a target state, not an implemented one.** The source team has
diagnosed the need and has not built it.

The anti-pattern it prevents, **VERIFIED as a real incident**: a payment-provider
secret in production turned out to be byte-identical to the corresponding
sandbox/test-mode secret in a lower environment — a test-mode credential silently
serving production traffic. It was found by a human manually comparing key
digests. The root cause was a bare secret name encoding neither environment nor
mode.

Two adjacent facts worth carrying:

- **Platform-level secret scoping is stronger than naming discipline.** Some CI
  platforms support environment-scoped secrets with branch binding, which gives
  platform-*enforced* isolation. Naming gives discipline-*enforced* isolation. Use
  the former where it exists; the latter is the fallback, not the goal.
- **`.gitignore` does not retroactively untrack a file.** Per-environment config
  files (`.env.staging`-style) that were tracked early stay tracked. A credential
  was pasted into one once and caught only by human code review.

### 4.7 Standing risk: vendor-dashboard-only configuration

**VERIFIED as a risk category; unsolved as a control.**

Configuration that lives **only** in a vendor's dashboard or management API — not
in the repository — is never code-reviewed and drifts silently between
environments. The source pipeline confirmed a live instance: one environment's
auth redirect allowlist had noticeably fewer entries than another's, and the auth
service's default behaviour for an unlisted redirect is to **silently fall back**
to the site URL rather than erroring. The misconfiguration fails quietly.

> **Adopt the category, not a solution.** "Vendor-dashboard-only configuration
> drifts silently and evades code review" belongs as a standing checklist item in
> any environment review, independent of which vendor's dashboard it is. Nobody
> has solved it. Naming it is the available control.

---

## 5. Boundary rules — what may cross, and in which direction

### 5.1 Data direction

**VERIFIED. One direction only, and only under an allowlist.**

| Flow | Allowed? |
|---|---|
| production → staging/rehearsal | **Yes — allowlist-scoped only** (§ 4.4). |
| production → dev | **Never.** Dev gets **schema via migrations, never rows.** |
| staging → production | **Never.** |
| dev → production | **Never.** |
| dev → staging | **Never.** |

There is no exception and no override. "Just this once, to reproduce a bug" is the
request this rule exists to refuse.

**A structural hazard worth naming. VERIFIED.** In the source implementation the
underlying database infrastructure was **shared with an unrelated application
team** with no project-level isolation, so a schema mistake by either team was
live in both teams' blast radius simultaneously. Cross-team notification was the
only mitigation; no technical guard existed. If your environments share
infrastructure with anyone, write that down here — the boundary rules above assume
the blast radius is yours alone.

### 5.2 Migrations are forward-only

**VERIFIED.** There is **no rollback mechanism in any pipeline** — dev, staging, or
production. Migrations go forward.

> **Note the divergence from `deployment-policy.md`.** That policy's *Rollback
> Capability* section requires that "database migrations reversible" and documents
> a `migration:down` step. That is the **generic template** it offers a project
> adopting LogicLoom, and it remains a legitimate model. **This section describes a
> forward-only pipeline, which is a different, equally legitimate model** — and the
> one the source methodology actually runs. The two are alternatives, not a
> contradiction: a project picks one and records the choice. If you pick
> forward-only, say so in your copy of `deployment-policy.md` § *Rollback
> Procedures*, because the rollback timeline in that section will otherwise
> describe a capability you do not have.

Two hazards, both **VERIFIED**, both tracing to the same root cause — **migrations
applied out-of-band, desynchronizing what different environments believe they have
already applied**:

1. **Version recorded as apply-time, not declared version.** A migration tool
   recorded its own apply-time timestamp instead of the migration file's declared
   version, producing "remote migration version not found" when the same
   migrations were later replayed in order elsewhere. Recoverable, but only via a
   manual repair step.
2. **A non-idempotent conditional alteration.** A schema-alteration statement
   aborted outright when its target object did not already exist. Some migrations
   had been applied out-of-band in a different order than the files replay in, so
   a later migration's "alter this object" step assumed something an
   earlier-numbered-but-later-applied migration had already removed. Fixed with a
   small idempotent guard that no-ops instead of raising.

Both are Principle IV (Idempotency) failures. The generalizable rule: **every
migration must be safely re-runnable, and no migration may ever be applied
out-of-band.**

### 5.3 Build-time environment binding, and its sharp edge

**VERIFIED.** In the source implementation the client selects its backend target at
**compile time**, via build-time environment variables — not at runtime. Every
knob (database/API base URL and key, a staging-mode flag, the update-channel base
URL, the proxy endpoint) **falls back to its production value when unset**.

That has a defensible logic: a build with none of the knobs set is byte-identical
to a production build, so forgetting a variable cannot accidentally point a build
at a *lesser* environment.

**But it cuts the other way, and this is the part to carry forward.** A staging or
dev binary shipped without its knobs set **silently talks to production** instead
of erroring. Nothing fails. Nothing warns.

> **The portable rule is not "fall back to production."** It is: **decide up front
> which direction counts as safe for your stack, and write the decision down.** For
> a read-heavy client, falling back toward production may be safe. For anything
> that writes, that same default is how a test run mutates production data. For
> many stacks the correct answer is a third option — **fail to start on an unset
> binding at all**, which is § 4.2 applied to configuration.

---

## 6. What a green rehearsal proves — and what it does not

### 6.1 The rehearsal contract

**VERIFIED.** A gate script runs before every production promotion, **fails closed**
on anything it cannot evaluate (an API outage during the check aborts the
promotion rather than proceeding optimistically), and requires **all three**:

1. The latest rehearsal run on the staging branch concluded successfully.
2. That run is no older than a configurable staleness bound — a couple of weeks is
   a reasonable default.
3. The commit that run actually rehearsed is an **ancestor** of the commit being
   promoted.

### 6.2 What a green run proves

**VERIFIED.** Exactly four things:

- Migrations apply cleanly against a production-schema database.
- **The authorization invariant holds.** The actual access predicate is re-run
  against the seeded allowlist accounts **before and after** migrate+seed. It fails
  if **any** previously-authorized account would lose access, **and** it fails if
  **zero** accounts end up authorized. The second condition is the clever half: it
  proves the seed actually worked, rather than merely that nothing regressed
  against an empty set.
- Backend functions deploy and answer a basic health/preflight check.
- The client artifact builds, signs, and notarizes.

### 6.3 What it does not prove — say this plainly

**VERIFIED.** There is **no automated end-to-end test** driving the built, signed
artifact against the live rehearsal environment. **No core user flow** — login,
the primary feature, billing, whatever your critical path is — is exercised by CI.
A human may install the build and try it, but that is manual and optional, not
gated.

> **"It deployed successfully" and "it was proven to work" are different claims.**
> A pipeline shaped like this gives you the former. Reporting the former as the
> latter is the failure this paragraph exists to prevent — in a status update, in
> a release note, and in an agent's summary of its own work.

### 6.4 The ancestry detail — the rehearsed commit is the merge's *second* parent

**VERIFIED, and the non-obvious part of § 6.1's third condition.**

The staging branch is periodically rebuilt from production and then merged with
the integration branch. It is therefore **never a pure mirror** of the integration
branch. The commit that was actually rehearsed is the **merge's second parent**,
not the merge's head commit.

A naive "is HEAD an ancestor of what I am promoting?" check looks at the wrong
commit entirely — and, being an ancestry check, it will usually return a plausible
answer rather than an error. Under § 4.2, an ancestry check that cannot
unambiguously identify the rehearsed commit must **fail closed and say so**, not
guess at a parent.

---

## 7. Explicitly unsolved — do not present these as patterns

Two problems have **no solution here, in the source implementation, or in
LogicLoom.** They are listed so that nobody mistakes their absence for a design
decision.

### 7.1 Schema-drift detection between deployed environments

**There is none. Full stop.**

The closest available check resets a fresh **local** database from the migration
files and validates invariants against *that*. It never diffs any environment's
actually-deployed schema against another's. The one real drift known about — a
security-relevant setting on a database view that differed between two
environments — was found by a **human doing manual cross-environment inspection**,
not by any automated check.

Do not copy "no drift detection" forward as though it were considered.

### 7.2 Cross-environment secret-value parity checking

**There is none.** The payment-secret incident in § 4.6 was caught by a human
manually diffing key digests. § 4.6's naming recommendation is a *diagnosis of why
this is needed* — it is not an implementation, and it does not detect a parity
violation that has already happened.

---

## 8. Vendor boundary — adapter concerns, not harness concerns

The following are **capability categories**, named because the capability is
genuinely vendor-defined. They are named, not required. LogicLoom ships no adapter
for any of them, and a project needing none of them is not missing anything.

| Capability category | What the vendor provides |
|---|---|
| **Managed-Postgres branching** | The ephemeral fork-a-database mechanism behind § 4.4. The *shape* — fork data-less, seed selectively, tear down on success — is portable; the branching API calls are not. Also the CLI mechanics of pushing schema changes and repairing migration history, and the DDL semantics behind § 5.2's hazards. |
| **CI environment-scoped secrets** | Environment scoping with branch binding, versus repository-wide secrets (§ 4.6). Also a CI-status CLI as the polling surface throughout every promotion script. |
| **Edge-worker secret stores** | The edge/proxy platform's own secret-management CLI. |

**A correction the source document makes about itself, and which must be carried
forward:** its stack ships a **compiled desktop client, not a web app**, and uses
**no web-hosting or preview-deployment platform anywhere** in the promotion path.
Its entire vendor surface is managed Postgres, a CI runner, and an edge-worker
platform.

> **Therefore: do not infer a web-hosting/preview-deployment adapter from this
> methodology.** Rebuild-required environment-variable semantics and
> preview-deployment models are a real capability category worth its own adapter
> *if your stack uses one* — but that pattern must be sourced from a codebase that
> actually deploys to such a platform, not from this document.

**A structural constraint worth naming, VERIFIED.** Self-hosted CI runners that
code-sign and notarize a desktop build typically need an **interactively
logged-in GUI session**; a background service account cannot do it. An unattended
trigger can queue or silently fail until a human restarts that session. That is a
genuine human-in-the-loop dependency that has nothing to do with pipeline logic,
and it limits how honestly such a pipeline can be called "CD."

---

## 9. Declaring this in `environments.conf`

`.logic-loom/config/environments.conf` is the one machine-readable part of the
environment model (`deployment-policy.md` § *Environment Declaration* owns the
schema). Two keys carry patterns from this policy:

| Key | Pattern | Meaning |
|---|---|---|
| `rehearsal_seed_allowlist` | § 4.4 | Path to the **fail-closed** seed allowlist for this environment. Names a product-owned file; the harness never reads it, never seeds, and never validates its contents. |
| `confirm` | § 4.3 | Confirmation strength for promoting **into** this environment: `none`, `prompt`, or `typed:<PHRASE>`. |

`confirm = typed:<PHRASE>` requires `requires_approval = true` in the same block —
the validator errors otherwise, with a typed reason (§ 4.2), because "demand a
typed phrase" and "no approval needed" cannot both be true.

The reverse pairing is **not** an error: `requires_approval = true` with
`confirm = none` is the normal shape for an environment whose gate is a CI
approval (a reviewer on a protected environment) rather than a terminal prompt.

Both keys ship **commented out**, like every other declaration in that file, and
neither is enforced by anything. They give the pattern a name a human and an agent
can both read; the machinery stays yours.

---

## 10. What LogicLoom ships, and what it does not

| Ships | Yours to provide |
|---|---|
| This methodology, as policy | Every pipeline, workflow, and script in it |
| The `environments.conf` declaration + read-only validator | The rehearsal environment, its seed, its teardown |
| `branch-topology-guard.yml` as a **reference implementation** of § 3 | Your own topology's regex, or its deletion |
| Fail-closed-with-a-typed-reason as house style (§ 4.2) | The gates that follow it |
| The named risk categories in § 4.7 and § 7 | Any control over them — none exists |

**No adapter, seed script, teardown job, promotion command, or CI workflow for
environment promotion ships with LogicLoom**, and none was added by the change that
wrote this policy. Principle V: the methodology is written down before any
machinery is built for it, precisely so the machinery can be built against a stated
contract rather than inferred from one implementation.

---

## 11. The opt-in scaffolding (amends § 10)

**Added after this policy's v1.0.0.** § 10 stated that no promotion command or CI
workflow for environment promotion ships with LogicLoom, "and none was added by
the change that wrote this policy." That was true of *that* change. It is no
longer the whole picture, and § 10's table is amended here rather than rewritten,
so the sequence stays legible: **the methodology was written down first, and the
machinery was then built against a stated contract** — which is exactly what
Principle V asked for.

### What now ships

`/scaffold-environments` (plugin `loom-maintenance`), over two scripts and five
templates:

| Ships | What it is |
|---|---|
| `.logic-loom/scripts/bash/detect-environment-topology.sh` | Read-only detection of branches, roles, default branch, CI provider, and existing declarations. Runs no git. |
| `.logic-loom/scripts/bash/scaffold-environments.sh` | Plan / apply. `--plan` writes nothing; `--apply` requires `--only=…`. |
| `.logic-loom/templates/environment-promotion/` | The five things it can write, as templates. |
| `plugins/loom-maintenance/commands/scaffold-environments.md` + `skills/environment-scaffolding/` | The command and its skill. |
| `tests/contract/test_environment_scaffolding.sh` | The contract, including the boundary below. |

### What it writes into a project, all opt-in, all named before writing

1. A filled-in `environments.conf` reflecting the branches the project **actually
   has** (§ 9).
2. A branch-boundary CI check for the project's production branch (§ 3),
   generalized from `branch-topology-guard.yml` and parameterized by **their**
   branch names. Fails closed, no exemptions, and the workflow itself states that
   it only fires once merged to the base branch.
3. A promotion checklist doc carrying the portable patterns of § 4 — fail-closed
   with a typed reason, escalating confirmation by blast radius,
   migrate-before-deploy, keep-the-rehearsal-alive-on-failure, secret names that
   encode environment, and the vendor-dashboard-drift category — written against
   the project's own branches, plus the § 7 unsolved problems restated as
   unsolved.
4. A **commented placeholder** deploy seam per environment, which the product
   owns and the harness never invokes. It exits **non-zero**: a placeholder
   exiting 0 would report a deployment that did not happen, which is § 4.2's
   failure mode exactly.
5. A default-branch-trap guard for the project's topology (§ 2), mode-selected —
   see below.

### The boundary is unchanged, and is now test-enforced

Still **not** shipped, and now asserted by the contract suite rather than only
promised here: cloud or CI-provider deploy logic, secret values, migration
runners, seed scripts, teardown jobs, and rollback mechanisms. § 8 and the
"Yours to provide" column of § 10 stand exactly as written.

The scaffolder is a **planner and a file writer**. It runs no deployment, and it
runs **no git at all** — branch detection reads refs off the filesystem, and no
branch is ever created for an unfilled role.

### § 2 generalized — and LogicLoom's inversion deliberately not exported

§ 2.2 is the worked counter-example: LogicLoom's `origin/HEAD` is not stale and
its default branch genuinely **is** its production line, so `git remote set-head
origin --auto` does not apply *there*. § 2.3 says a customer project should do
the opposite. The scaffolder implements that split rather than picking a side:

| Detected arrangement | Generated guard |
|---|---|
| default branch **is** the integration branch | mode `expect-default-is-integration` — recommends keeping `origin/HEAD` fresh (§ 2.1) |
| default branch is **not** the integration branch | mode `expect-explicit-base` — states that `set-head --auto` does **not** apply and requires the base to be named explicitly (§ 2.2's shape, § 2.3's decision) |
| no integration branch | **not generated** — the trap does not arise yet |
| default branch could not be determined | **not generated** — fail closed rather than guess (§ 4.2) |

The generated script also detects that its own assumption has gone stale — if
`origin/HEAD` no longer matches the arrangement it was built for, it says so and
asks to be regenerated.

### Adoption posture

Four properties, each contract-tested:

- **Detects, never assumes.** Roles match only branches that exist. Where the
  scaffolder must assume something — writing a GitHub Actions workflow into a
  repository with no CI at all — it says so in the proposal line rather than
  silently.
- **Proposes a delta.** A project that already has a `staging` branch is never
  told to create one.
- **Never overwrites.** No `--force`. An existing file is left byte-identical and
  reported as a conflict; a file carrying the scaffolder's own marker is an
  idempotent no-op (Principle IV).
- **Declining leaves nothing behind.** `--plan` writes no file.

### Naming

`/scaffold-environments`, **not** `/promote` and not `/deploy-promote`. `/promote`
is the maintainer release driver, stripped from customer copies by exact path
(**LOOM-0006**). `/deploy-promote` was LOOM-0006's suggested name for a
customer-facing *promotion* command — a thing that promotes. This command
promotes nothing, so taking that name would have described the wrong verb and
consumed the name the actual promotion command should have. LOOM-0006 remains
open and its suggested resolution remains available.

---

## References

- Constitution v3.3.0: `.logic-loom/memory/constitution.md`
- Deployment Policy: `.docs/policies/deployment-policy.md` (environments as roles; `environments.conf`)
- Branching Strategy Policy: `.docs/policies/branching-strategy-policy.md` (branch conventions; LogicLoom's template topology)
- Shell Idiom Policy: `.docs/policies/shell-idiom-policy.md` (§ 4.2's sibling)
- Release Management Policy: `.docs/policies/release-management-policy.md`
- Governance threat model (enforced vs. followed): `.docs/architecture/governance-threat-model.md`
- Reference implementation, § 3: `.github/workflows/branch-topology-guard.yml`
- Reference implementation, § 4.2: `.logic-loom/scripts/bash/check-generated-freshness.sh`
- Backlog: `.logic-loom/memory/backlog.md` (LOOM-0024 … LOOM-0027)

---

## Version History

| Version | Change |
|---|---|
| 1.0.0 | Initial policy. Records the coding→deployed mapping, the default-branch trap **with LogicLoom's inverted exception** (its default branch genuinely *is* the production line, so `git remote set-head --auto` does not apply and worktrees must name the integration branch explicitly), the CI-enforced branch boundary, seven portable patterns, the one-directional data boundary, forward-only migrations, build-time binding, what a green rehearsal proves and does not, two explicitly unsolved problems, and the vendor adapter categories. Adds `rehearsal_seed_allowlist` and `confirm` to the `environments.conf` schema — commented out, declaration-only, no engine. No pipeline machinery was built. |

---

> **Amendment (§ 11).** After v1.0.0, the opt-in scaffolding that LOOM-0025
> called for was built: `/scaffold-environments`, its detector, and its
> templates. § 10's "no promotion command or CI workflow ships" claim is amended
> by § 11 — a **generated, opt-in** branch-boundary workflow and a set of
> placeholder seams now ship as templates. The "Yours to provide" column is
> unchanged: no deploy logic, no seed, no teardown, no migration runner, and no
> rollback mechanism ships, and that boundary is now enforced by
> `tests/contract/test_environment_scaffolding.sh` rather than only promised.

**Policy Owner**: Architecture Department
**Last Reviewed**: 2026-08-22
**Next Review**: TBD
