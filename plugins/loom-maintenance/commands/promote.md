---
name: promote
description: "[MAINTAINER] Cut a sanitized template release — bump version, commit/push dev-main, dispatch promote-to-main.yml, open the PR with a user token (Actions never does), verify checks actually reported."
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
2. **The workflow deliberately does not open the PR.** A PR opened with the
   built-in `GITHUB_TOKEN` does **not** trigger `pull_request` workflows (GitHub
   suppresses them to prevent recursion), so `leak-guard.yml` — the one check
   that exists to guard PRs into `main` — would silently never run on it. The PR
   is therefore always opened here, with a **user token**, which does fire
   `pull_request` events. The workflow pushes `release/$TAG` and stops.

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

### 5. Open the PR yourself (approval) — the workflow never does
- **Run fully succeeded** → `release/$TAG` was pushed and **no PR exists**. That is
  correct, not a failure. Open it with the user token (this is a git/PR mutation —
  surface it for approval):
  ```
  gh pr create --base main --head "release/$TAG" \
    --title "Release $TAG: sanitized template" \
    --body "Single-parent promotion from dev-main. The in-workflow sanitization audit (Checks 1-7) already passed — the binding gate. Merge with a MERGE COMMIT (never squash/rebase) to keep .sdd-sync-ref + v* tags reachable for /update-framework. On merge, .github/workflows/release-tag.yml auto-tags $TAG (the sanitized snapshot) — no manual tagging."
  ```
- **Run failed at the AUDIT step** (Checks 1–7) → the snapshot is UNSANITIZED. Report the exact leak/failure from `gh run view <id> --log-failed`; do NOT open a PR. Fix on dev-main and re-run `/promote`.
- **A PR into `main` from `release/$TAG` already exists** (e.g. a re-dispatch) → do
  not open a second one; go to step 6 and verify that one.

### 6. Verify the PR — checks must have REPORTED, not merely "not failed"
The failure mode this guards: a PR whose checks never ran shows **no red**, and
`gh pr checks` does **not** reliably distinguish that from all-green. Do not read
"nothing failed" as "validated".

**6a. Assert checks reported at all.** Count the rollup — this is the reliable
signal, because it returns an empty array when nothing ran:
```
gh pr view <pr> --json statusCheckRollup --jq '.statusCheckRollup | length'
```
- **`0` → FAILURE STATE. Do not hand off.** No `pull_request` event fired for this
  PR (the usual cause: it was opened by Actions/`GITHUB_TOKEN` rather than a user
  token). Remediate by closing and reopening it under the user token, which emits
  a fresh `pull_request` event (approval-gated, like any mutation):
  ```
  gh pr close <pr> && gh pr reopen <pr>
  ```
  Wait ~30s, then **re-run 6a**. If it is still `0` after a reopen, STOP and report
  — do not proceed to a hand-off on an unverified PR.
- **`> 0` → proceed to 6b.**

**6b. Assert the expected checks are present and green.** Both must appear by
name — a rollup with only one of them is still an incomplete verification:
```
gh pr checks <pr>
```
- Required: **`leak-guard`** and **`contract-tests`**, both `pass`.
- Anything `pending` → wait and re-check. Anything `fail` → report and STOP.
- A missing *name* is the same failure class as 6a: the check did not run.
  Remediate the same way (close/reopen), then re-verify.

**6c. Hand off — do NOT merge it.**
- **STOP here. This command never merges to `main`** — that is the deliberate
  human release gate (`main` is branch-protected, review-required). Do **not**
  `--admin`-bypass it, and never merge to "work around" a check that did not run.
- Report: PR URL, the rollup count from 6a, the per-check status from 6b,
  mergeability, and any audit failure. Tell the maintainer to **merge it
  themselves with a MERGE COMMIT** (never squash/rebase — it keeps `.sdd-sync-ref`
  + `v*` tags reachable for `/update-framework`). On merge,
  `.github/workflows/release-tag.yml` **auto-applies the `$TAG` tag** to the
  sanitized snapshot **and creates a DRAFT GitHub Release** from the CHANGELOG
  section — no manual tagging, and the Release is staged but not published.
  Tell them step 7 runs after the merge.

### 7. After the merge — assert the Release exists (same spirit as 6a)

The failure this guards is the one that actually happened: from **v6.2.0 to
v6.5.0 the release path pushed five tags and published zero Releases**
(6.3.0, 6.3.1, 6.4.0, 6.4.1, 6.5.0). Nothing went red — the step did not exist,
and no command asserted it had run. **A tag is not a release.** Treat a missing
Release exactly like a rollup count of `0`: a failure state, not a quiet pass.

Run this once `release-tag.yml` has finished for the merge commit:

```
gh release view "$TAG" --json url,isDraft,name,tagName
```

- **Command fails / no such release → FAILURE STATE. Do not hand off clean.**
  Read the workflow run: `gh run list --workflow=release-tag.yml --limit 1 --json databaseId,conclusion,url`
  then `gh run view <id> --log-failed`. The step names its own cause and remedy
  in the error — a missing `Source-dev-main:` trailer, an unfetchable dev-main
  commit, or no `## [X.Y.Z]` section in the CHANGELOG at that commit. Report
  it verbatim. The remedy is always the same shape: create the Release by hand
  from the CHANGELOG section, then re-run the workflow (it finds the Release and
  no-ops).
- **`isDraft: true` → correct and expected.** CI stages the Release; it never
  publishes one. Report the **URL** and tell the maintainer to proofread the
  rendered notes and hit **Publish** — that is the step that flips "Latest" and
  notifies watchers, and it stays human on purpose.
- **`isDraft: false`** → someone already published it. Report that plainly
  rather than implying this command did it.
- Report in the hand-off: Release **URL**, **`isDraft`** state, and `tagName`
  matching `$TAG`. A hand-off that does not name all three has not verified the
  release, only the tag.

**One-release lag, state it out loud.** `release-tag.yml` is triggered by
`push:`, so GitHub runs the copy of the file **at the pushed commit**. The draft
Release step therefore first runs for **v6.6.0**. For any release whose snapshot
predates it — v6.5.0 included — step 7 will find nothing, and that is expected,
not a fault. v6.5.0 was published by hand; v6.3.0 through v6.4.1 stay
unpublished by decision (writing notes after the fact is guesswork presented as a
record).

## Notes
- **Do not** enable repo Settings → Actions → General → *Allow GitHub Actions to
  create and approve pull requests* in the hope of skipping step 5. Even with it
  ON, a PR opened by `GITHUB_TOKEN` triggers no `pull_request` workflows, so the
  PR lands with **no checks at all** — the success path would silently lose
  `leak-guard`. The workflow has no `pull-requests: write` permission for exactly
  this reason. Step 5 is the only path.
- The `release` GitHub **environment** can carry required reviewers as an
  additional human gate before the bot publishes — configure in Settings → Environments.

## Constitutional compliance
- **Principle VI**: every git mutation + the PR creation surface for approval; nothing autonomous.
- **Maintainer-only / Plugin-First**: this is a `loom-maintenance` command but pure
  release plumbing — it and `bump-version.sh` are stripped at promote so they never
  reach customers.
