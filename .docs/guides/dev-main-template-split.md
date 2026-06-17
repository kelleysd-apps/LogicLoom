# dev-main → sanitized `main`: release model + setup runbook

**Audience**: LogicLoom maintainers (harness-dev). This document is itself
harness-dev — it is stripped from the public customer template.

## The model — ONE public repo, two branches

This repository is **public**. There is no separate template repo. The same
repo serves both roles, split by branch:

| | `dev-main` (+ feature sub-branches) | `main` |
|---|---|---|
| Role | The dev mainline (publicly visible) | The clean, customer-facing template |
| Holds | Everything: full `VISION.md`, `.docs/features`, plans, reviews, retros, the release plumbing, full dev history | Sanitized single-parent snapshots only |
| Vision | Our real harness `VISION.md` | A generic **stub** `VISION.md` (becomes the customer's own) |
| Advanced by | Normal PRs (daily work) | `workflow_dispatch` promotion → single-parent sanitized snapshot |

Customers consume `main` via GitHub **"Use this template"** (a clean,
single-commit copy with no history) or a fork. `dev-main` is publicly visible —
its history and any markers are readable by anyone who clones or forks. We
accept that: the cleanliness guarantee is for **what a "Use this template" copy
contains** (the sanitized `main` tree), not for hiding the dev branch.

### Load-bearing security invariant (never weaken)

**Single-parent snapshots only.** A published commit's *only* git parent is the
current `main`. `dev-main` is **never** a git parent. In a single repo this is
*more* important, not less: the dev tree already lives here, so the only thing
keeping it out of a "Use this template" copy is that `main`'s history never
reaches a `dev-main` commit. A second parent (or merging `dev-main` itself into
`main`) would make the full unsanitized tree reachable from `main`
(`git show <devsha>:VISION.md` recovers any "stripped" file in a template copy).
Provenance is a `Source-dev-main:` trailer string, not an object reference.

The release branch chain is `main ← C1(snapshot) ← C2(sync-ref)`. Merging that
branch into `main` — even with a merge commit — keeps `dev-main` unreachable,
because `C1`'s parent is `main`, never `dev-main`.

> **The release-environment gate.** The Claude Code git hooks (Principle VI) do
> **not** run in GitHub Actions. Required reviewers on the `release` environment
> are the only thing between the bot and `main`. If unconfigured, the bot
> publishes unattended.

## Sanitization layers (orthogonal)

| Layer | Tool | Concern |
|---|---|---|
| Origin scrub (Checks 1-6) | `sanitization-audit.sh` | original ioun-ai project content + absolute paths |
| Harness-dev strip (Check 7) | `strip-harness-dev.sh` + `leak-guard.sh` + `template-strip-manifest.txt` | OUR dev record (tracked-content model) |
| Dev-history scrub | `history-scrub.sh` + `history-scrub-rules.json` | dev-history *narrative* embedded in shipped files (changelogs, migration provenance, dated stamps, build-stage refs) |
| Per-project | `sanitize-for-template.sh` | generated/per-project artifacts |
| Public backstop | `.github/workflows/leak-guard.yml` | self-contained identity-marker grep on PRs to `main` |

The strip + leak-guard operate on **git-tracked content** (`git ls-files`), so a
customer's regenerated runtime state can never trip them and tracked `.gitkeep`
files survive.

**The binding sanitization gate is in-workflow.** The promotion's `release` job
runs the full audit (Checks 1-7, where Check 7 *is* `leak-guard.sh`) on the
sanitized tree *before* composing the release commit. The PR's `leak-guard.yml`
is a customer-visible backstop only — a PR opened by the built-in `GITHUB_TOKEN`
does **not** trigger `pull_request` workflows, so it may not auto-run on the
promotion PR. Never rely on it; the in-workflow audit is what blocks an
unsanitized snapshot.

## One-time setup

1. **Keep this repo public.** No second repo to create.
2. **Establish `dev-main`.** Push `dev-main` to `origin` at the current dev tip
   (it is publicly visible — accepted). It is the canonical harness-dev record;
   daily work flows into it by PR.
3. **Branch protection on `main`** (Settings → Branches): block force-push +
   deletion; require the `leak-guard` check; require a **merge commit** (disable
   squash/rebase so `.sdd-sync-ref` + `v*` tags stay reachable for
   `/update-framework`); restrict who can push (the release bot only, or no one —
   PR-merge only).
4. **`release` environment with required reviewers** (Settings → Environments).
   This is the human gate that substitutes for Principle VI in CI.
5. No PAT or cross-repo token is needed — the promotion uses the built-in
   `GITHUB_TOKEN` (it pushes a release branch and opens the PR within this repo).

## Gated migration (current state → this model)

Run in order. Each step here is the **gated** work that needs explicit approval.

- **Phase 0 — Pre-flight (read-only).** Confirm `origin/main` is still the
  pre-migration baseline (harness-dev was never merged to it — it lives on PR #56),
  and that the committed `.sdd-sync-ref` is an ancestor of `origin/main`
  (`git merge-base --is-ancestor`). Stop if either fails.
- **Phase 1 — Establish dev-main.** Push `dev-main` to `origin` at the current
  baseline and protect it (block force-push + deletion). It becomes the canonical
  harness-dev record.
- **Phase 2 — Retarget in-flight work.** `gh pr edit 56 --base dev-main`; review
  and merge PR #56 into `dev-main` as a **merge commit**.
- **Phase 3 — Bootstrap the first `main` snapshot.** Run the
  `promote-to-main.yml` workflow (`workflow_dispatch`, `version: v6.2.x`). It
  builds the sanitized snapshot from `dev-main` in a throwaway CI runner,
  composes a single-parent commit (parent = current `main`), and opens a PR to
  `main`. A human merges with a merge commit, then tags.
- **Phase 4 — Upstream config is auto-stamped (nothing to repoint).**
  `/update-framework` is config-driven and remote-free: `promote-to-main.yml`
  stamps `.logic-loom/config/framework-upstream.conf` from `github.repository`
  (this repo) at each release, and the flow fetches that URL ad-hoc into
  `refs/loom-upstream/main` — it NEVER creates an `upstream` git remote. The dev
  default in `framework-upstream.conf` is already this repo. (Legacy clones with
  a stale pushable `upstream` remote are ignored by the new flow; users can
  `git remote remove upstream`.)

## Steady-state release loop

Develop on `dev-main`. To ship: run **Promote dev-main → sanitized main**
(`workflow_dispatch`, give the version) → `gate` (tests + constitutional check +
`--origin-only` audit) → `release` (environment-approved) builds the sanitized
snapshot, re-audits 1-7, stamps the upstream config, composes the single-parent
commit, advances `.sdd-sync-ref`, opens a PR to `main` → a human merges with a
**merge commit** → tag the merge commit.

## Residual risks (known, accepted or watched)

- **`dev-main` is public.** By choosing a single public repo, the dev branch's
  history and any markers are readable by anyone who clones/forks. Only the
  sanitized `main` (and "Use this template" copies of it) is clean. This is an
  accepted trade-off, not a defect.
- **`main`'s deep history retains the pre-LogicLoom baseline.** Because the first
  single-parent release commits onto the existing `main` (the old SDD baseline),
  `git log main` shows that baseline beneath the release commit. That baseline is
  already-public, pre-LogicLoom content carrying none of the dev-journey
  narrative we scrub — the *tree* a customer receives is fully sanitized, and the
  `dev-main` migration commits remain unreachable. Accepted.
- **Embedded-reference leaks** a path manifest can't catch: shipped docs
  (`CLAUDE.md`, `AGENTS.md`) may mention dev-only paths/branch names. The
  identity-marker scan only hard-fails on genuinely-sensitive strings (owner
  email, ioun-ai, `/workspaces/`, the private-repo path); a harmless dead link is
  accepted.
- **Denylist rot**: as the agent tree / docs grow, new runtime artifacts may
  appear under unlisted paths. Re-review the manifest each release.
