---
name: promote
description: "[MAINTAINER] Cut a sanitized template release — bump version, commit/push dev-main, dispatch promote-to-main.yml, open the PR (Actions can't), monitor checks."
model: opus
---

# /promote — LogicLoom maintainer release driver

**MAINTAINER-ONLY.** Promotes `dev-main` to the sanitized public `main` template
line as a versioned release. This command and `.logic-loom/scripts/bash/bump-version.sh`
are in the **template strip manifest** — they never ship to customer copies (you
do not promote LogicLoom's template from your own project). It drives
`.github/workflows/promote-to-main.yml`.

**Usage**: `/promote <version>`   (e.g. `/promote v6.3.0` or `/promote 6.3.0`)

## Why a command (not just a PR)

`main` is an orphan / single-parent template line built by the promote workflow —
**not a normal merge target**. A raw `dev-main → main` PR would re-add stripped
harness-dev content and fail leak-guard. Two frictions the workflow alone can't
smooth, which this command absorbs:
1. **Version stamps must be bumped on dev-main first** — the workflow keeps
   "version identity intact" and will NOT bump `6.x → 6.y`.
2. **The workflow's own `gh pr create` fails** when the repo setting *"Allow
   GitHub Actions to create and approve pull requests"* is OFF — so the PR is
   opened with a user token instead (which also lets `leak-guard.yml` run on it).

## Procedure

All git mutations are gated by **Principle VI** — surface each for approval; run
nothing autonomously.

### 1. Preconditions
- `git rev-parse --abbrev-ref HEAD` must be `dev-main`; `git status --porcelain` must be empty. Else stop and report.
- Parse `<version>` from `$ARGUMENTS`. Derive `TAG=vX.Y.Z` and `VER=X.Y.Z`. If absent/malformed (`X.Y.Z`), stop.
- Sanity-check it is a forward bump: compare `VER` to the current `main` release (`git fetch origin main -q` then read the `release:` subject of `origin/main` or `.sdd-sync-ref`). If `VER` is ≤ the current main version, ASK before continuing (re-releasing the same version is usually a mistake).

### 2. Bump + finalize release markers
- `bash .logic-loom/scripts/bash/bump-version.sh "$VER"` — coherently sets every framework stamp site.
- Roll the CHANGELOG: change the top `## [Unreleased]` heading to `## [X.Y.Z] - <YYYY-MM-DD>` (today). If there is no `[Unreleased]`, add a new `## [X.Y.Z]` section summarizing the release.
- Add a Version-History row for `X.Y.Z` near the top of AGENTS.md's history table (skip if one already exists).
- Verify: `bash .logic-loom/scripts/bash/bump-version.sh --check "$VER"` (must exit 0).
- Run the contract suite + `bash .logic-loom/scripts/bash/constitutional-check.sh`. If anything is red, STOP — do not release.

### 3. Commit + push the release stamp (approval)
- `git add -A && git commit -m "chore(release): stamp v$VER"` (Co-Authored-By trailer).
- `git push origin dev-main`.

### 4. Dispatch the promote workflow
- `gh workflow run promote-to-main.yml -f version="$TAG" -f publish_mode=pr`.
- Locate the run: `gh run list --workflow=promote-to-main.yml --limit 1 --json databaseId,status,url`.
- Watch it: `gh run watch <id> --exit-status`. The `release` job strips → scrubs →
  runs the **binding audit (Checks 1–7)** → composes the single-parent snapshot →
  advances `.sdd-sync-ref` → pushes `release/$TAG`.

### 5. Resolve the publish step
- **Run fully succeeded** → the workflow opened the PR. Capture its URL (`gh pr list --base main --head "release/$TAG"`).
- **Run failed ONLY at "Publish via PR to main"** with *"GitHub Actions is not permitted to create or approve pull requests"* → the `release/$TAG` branch was still pushed. Open the PR yourself:
  ```
  gh pr create --base main --head "release/$TAG" \
    --title "Release $TAG: sanitized template" \
    --body "Single-parent promotion from dev-main. The in-workflow sanitization audit (Checks 1-7) already passed — the binding gate. Merge with a MERGE COMMIT (never squash/rebase) to keep .sdd-sync-ref + v* tags reachable for /update-framework. Tag $TAG is applied to the merge commit AFTER merge."
  ```
- **Run failed at the AUDIT step** (Checks 1–7) → the snapshot is UNSANITIZED. Report the exact leak/failure from `gh run view <id> --log-failed`; do NOT open a PR. Fix on dev-main and re-run `/promote`.

### 6. Monitor + report
- `gh pr checks <pr>` — `leak-guard` + `contract-tests` should pass on the sanitized snapshot.
- Report: PR URL, check status, mergeability, and any audit failure.
- **REMIND the maintainer**, prominently: merge with a **MERGE COMMIT** (never
  squash/rebase) — it keeps `.sdd-sync-ref` + `v*` tags reachable; the `$TAG` tag
  is applied to the merge commit AFTER merge. `main` is branch-protected, so a
  human review/merge is required (the intended release gate).

## Notes
- To make the workflow open its own PR (skip step 5's fallback), enable repo
  Settings → Actions → General → *Allow GitHub Actions to create and approve pull requests*.
- The `release` GitHub **environment** can carry required reviewers as an
  additional human gate before the bot publishes — configure in Settings → Environments.

## Constitutional compliance
- **Principle VI**: every git mutation + the PR creation surface for approval; nothing autonomous.
- **Maintainer-only / Plugin-First exception**: this is release plumbing, not a
  shipped capability — it and `bump-version.sh` are stripped at promote so they
  never reach customers.
