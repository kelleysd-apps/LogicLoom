# Dev-main → sanitized public template: release model + setup runbook

**Audience**: LogicLoom maintainers (harness-dev). This document is itself
harness-dev — it is stripped from the public customer template.

## The model

Two repositories, opposite confidentiality:

| | **dev repo** (PRIVATE) | **template repo** (PUBLIC) |
|---|---|---|
| Branch | `dev-main` (+ feature sub-branches) | `main` |
| Holds | Everything: full `VISION.md`, `.docs/features`, plans, reviews, retros, the release plumbing | Sanitized snapshot only |
| Vision | Our real harness `VISION.md` | A generic **stub** `VISION.md` (becomes the customer's own) |
| Advanced by | Normal PRs (daily work) | `workflow_dispatch` promotion → single-parent sanitized snapshot |

### Load-bearing security invariants (never weaken)

1. **Single-parent snapshots only.** A published commit's *only* git parent is
   the public template's current `main`. `dev-main` is **never** a git parent —
   a second parent makes the entire unsanitized history reachable from the public
   repo (`git show <devsha>:VISION.md` recovers any "stripped" file). Provenance
   is a `Source-dev-main:` trailer string, not an object reference.
2. **dev-main stays in the private repo.** Never `git push` dev-main to the
   public remote. Enforce with branch protection, not discipline.
3. **The `release` environment is the human gate.** The Claude Code git hooks
   (Principle VI) do **not** run in GitHub Actions. Required reviewers on the
   `release` environment are the only thing between the bot and the public main.
   If unconfigured, the bot publishes unattended.

## Sanitization layers (orthogonal)

| Layer | Tool | Concern |
|---|---|---|
| Origin scrub (Checks 1-6) | `sanitization-audit.sh` | original ioun-ai project content + absolute paths |
| Harness-dev strip (Check 7) | `strip-harness-dev.sh` + `leak-guard.sh` + `template-strip-manifest.txt` | OUR dev record (tracked-content model) |
| Per-project | `sanitize-for-template.sh` | generated/per-project artifacts |
| Public backstop | `.github/workflows/leak-guard.yml` | self-contained identity-marker grep on PRs to public main |

The strip + leak-guard operate on **git-tracked content** (`git ls-files`), so a
customer's regenerated runtime state can never trip them and tracked `.gitkeep`
files survive. The manifest's `warn:` entries (currently `src/sdd` / DS-STAR) are
**not** stripped — they surface as non-fatal warnings so nothing silently ships;
decide each, then move it to a strip entry.

## One-time setup

1. **Create the PUBLIC template repo** (e.g. `kelleysd-apps/logic-loom-template`).
   Empty; the first promotion seeds it.
2. **Make the dev repo private** (or create a new private repo and push dev-main
   there). The current `sdd-agentic-framework` repo becomes the private dev repo.
3. In the **dev repo**, set:
   - Variable `PUBLIC_TEMPLATE_REPO` = `<owner>/<public-template-repo>`.
   - Secret `PUBLIC_REPO_TOKEN` = a GitHub App installation token or fine-grained
     PAT with `contents:write` + `pull_requests:write` on the **public** repo only.
   - A `release` **environment** with required reviewers (Settings → Environments).
4. In the **public repo**, set branch protection on `main`: block force-push +
   deletion; require the `leak-guard` check; require a **merge commit** (disable
   squash/rebase so `.sdd-sync-ref` + `v*` tags stay reachable for
   `/update-framework`); restrict who can push to the release identity.
5. Ensure `.github/workflows/leak-guard.yml` exists on the public `main` (it ships
   in the sanitized snapshot, so the first promotion installs it).

## Gated migration (current state → this model)

Run in order. Each step here is the **gated** work that needs explicit approval.

- **Phase 0 — Pre-flight (read-only).** Confirm `origin/main` is still the
  pre-migration baseline (harness-dev was never merged to it — it lives on PR #56),
  and that the committed `.sdd-sync-ref` is an ancestor of `origin/main`
  (`git merge-base --is-ancestor`). Stop if either fails.
- **Phase 1 — Establish dev-main (private).** Push `dev-main` to the **private**
  dev repo at the current baseline and protect it (block force-push + deletion).
  It becomes the canonical harness-dev record.
- **Phase 2 — Retarget in-flight work.** `gh pr edit 56 --base dev-main`; review
  and merge PR #56 into `dev-main` as a **merge commit**.
- **Phase 3 — Bootstrap the first public snapshot.** From a throwaway
  `git worktree add /tmp/loom-build dev-main` (never the live tree): run
  `strip-harness-dev.sh` → `sanitize-for-template.sh` → `sanitization-audit.sh`
  (must be all-pass) → compose a single-parent commit (parent = public `main`, or
  the empty-repo root for the very first one) → push to the public `main` → tag.
  In practice this is the `promote-to-main.yml` workflow with `version: v6.2.x`.
- **Phase 4 — Repoint upstream.** Update the 3 `/update-framework` references
  from the dead `logic-loom.git` to the live upstream via `git remote set-url`
  (not add-if-absent, which strands clones that already added the dead remote).

## Steady-state release loop

Develop on `dev-main`. To ship: run **Promote dev-main → sanitized public
template** (`workflow_dispatch`, give the version) → `gate` (tests + constitutional
check + `--origin-only` audit) → `release` (environment-approved) builds the
sanitized snapshot, re-audits 1-7, composes the single-parent commit, advances
`.sdd-sync-ref`, opens a PR on the public repo → `leak-guard.yml` re-runs there →
a human merges with a **merge commit** → tag the merge commit.

## Residual risks (known, accepted or watched)

- **Embedded-reference leaks** a path manifest can't catch: shipped docs
  (`CLAUDE.md`, `AGENTS.md`) may mention dev-only paths/branch names. The
  identity-marker scan only hard-fails on genuinely-sensitive strings (owner
  email, ioun-ai, `/workspaces/`, the private-repo path); a harmless dead link is
  accepted.
- **Denylist rot**: as the agent tree / docs grow, new runtime artifacts may
  appear under unlisted paths. Re-review the manifest each release.
- **DS-STAR (`src/sdd`)** carries internal `/workspaces/logic-loom` paths; it is a
  `warn:` entry pending the ship-scrubbed-vs-strip decision — do not let it move
  to a silent ship.
