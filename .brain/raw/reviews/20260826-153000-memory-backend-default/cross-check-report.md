---
type: capture
title: "Memory-backend default flip: adversarial review of the legacy-aware probe"
date: 2026-08-26
source: "in-session adversarial design review (deep-reasoner, Claude lineage) of the memory_backend default change — NOT a cross-provider /cross-check run; same-lineage, so not decorrelated"
status: processed
distilled-into: .brain/wiki/decisions/memory-backend-default.md
---

# Review — memory backend: delete the external-path backend, flip the default to `repo`

- Date: 2026-08-26
- Reviewer lineage: **same as the author's (Claude).** This is a design review in
  the `/cross-check` capture shape; it is **not** a cross-provider cross-check
  and must not be cited as one. A same-lineage review shares the author's blind
  spots by construction.
- Overall verdict: **concern → changes made**

## Summary

Three changes were proposed: (1) delete the third memory backend, which pointed
at an operator-configured absolute external path; (2) make `repo`
(`.brain/memory/`) the shipped default instead of `project`
(`$HOME/.claude/projects/<slug>/memory/`); (3) migrate existing projects with a
LEGACY-AWARE DEFAULT — when no explicit setting exists, probe for a non-empty
legacy store and hold the default there, printing a migration notice.

(1) and (2) survived review. **(3) was rejected and removed**, and the review is
the reason. The migration moved to detection-by-advisory instead.

## Accepted findings (acted on)

- **A filesystem-dependent default splits the store on worktrees — fatal.**
  `REPO_ROOT` is derived from the script's own location, not from git, so the
  `project` slug is the *worktree's* path. A probe therefore resolves `project`
  in the main checkout and `repo` in a worktree of the same project: two stores,
  neither aware of the other. That is verbatim the defect one resolver exists to
  prevent, and the swarm pack is worktree-based, so it is the normal path rather
  than an edge case.
- **The probe fails silently in the case it exists for.** Move or rename the
  repo and the slug changes, so the probe finds nothing, resolves `repo`, and
  orphans the whole prior store — *without* firing the notice, because the notice
  was conditioned on the same probe that just failed.
- **It makes the destination unauditable.** With an explicit key, moving memory
  is a one-line diff a reviewer sees. With a probe, creating a single file under
  a directory Claude Code already owns redirects every future read and write with
  no diff anywhere.
- **CI and a laptop would disagree by construction** — different `$HOME`,
  different checkout path — so any test asserting a resolved path would have two
  correct answers.
- **The BM25 index was not keyed to the backend.** `.loom-memory-index/bm25`
  stores repo-relative document paths and records nothing about which memory
  directory they came from, so a backend change would keep returning hits for
  documents in a directory the resolver no longer points at. A stale-hit failure
  in a retrieval layer is the hardest class to notice, because the results still
  look plausible. Pre-existing, but the default flip is what activates it.

## Rejected / not acted on (with reasons)

- **"Do not flip the default at all; let `/initialize-project` set `repo` for new
  projects."** Declined. The onboarding question only reaches someone who runs
  init; the shipped default is what everyone else gets, and the direction the
  project brain is meant to work in — self-contained, read by outside tools —
  is not served by a per-machine directory invisible outside Claude Code.
- **"Deleting the external-path backend is scope reduction, not a leak fix,
  because the shipped value is only a commented placeholder."** True as stated
  about the shipped bytes, and beside the point: the objection was to shipping a
  *configuration surface* for reaching into one machine's directory at all. The
  relationship is the product decision, not the placeholder.

## What was built instead

Resolution is a pure function of `(env, conf)`; the default is `repo`, stated
explicitly in the shipped config. A stranded legacy store is surfaced by
`check-brain-signals.sh` in the preflight advisory — file count and both paths,
every session, until the user moves the files or sets `memory_backend =
project`. It never blocks and never moves anyone's files. **Detection, not
resolution.**
