---
type: decision
title: "Memory backend: `repo` is the shipped default, and resolution never probes the filesystem"
date-updated: 2026-08-31
sources:
  - .brain/raw/reviews/20260826-153000-memory-backend-default/cross-check-report.md  # in-session adversarial design review, 2026-08-26 (same-lineage — see Provenance caveat)
---

# Memory backend: `repo` default, and a resolver that never probes

## Context

Durable cross-session memory (`/retro` action-items, the loom-memory search
backends) has to live somewhere. Three options were on the table: `repo`
(`<repo>/.brain/memory/`, in-tree and versioned), `project`
(`$HOME/.claude/projects/<slug>/memory/`, per-machine and invisible outside
Claude Code), and a third backend naming an operator-configured absolute
external path.

`project` was the previous default. Flipping it raised a migration question for
projects that already had a store at the old location, and the first answer to
that question was a **legacy-aware default**: with no explicit setting,
`resolve-memory-backend.sh` would probe for a non-empty legacy store, hold the
default there, and print a migration notice.

## Decision

Three changes, two adopted as proposed and one rejected:

1. **Delete the external-absolute-path backend outright** — not deprecate it.
2. **Make `repo` the shipped default**, stated explicitly in
   `.logic-loom/config/memory-backend.conf`.
3. **Reject the legacy-aware probe.** Resolution is a pure function of
   `(env, conf)`; the resolver never touches the filesystem to pick a default.
   Migration became **detection by advisory** instead:
   `check-brain-signals.sh` reports a stranded legacy store — file count and
   both paths — in the preflight advisory, every session, until the user moves
   the files or sets `memory_backend = project`. It never blocks and never
   moves anyone's files.

## Why

The probe was rejected on four independent grounds, the first of which is
fatal on its own:

- **It splits the store across worktrees.** `REPO_ROOT` derives from the
  script's own location, not from git, so the `project` slug is the
  *worktree's* path. The same project resolves `project` in the main checkout
  and `repo` in a worktree — two stores, neither aware of the other. That is
  verbatim the defect a single resolver exists to prevent, and the swarm pack
  is worktree-based, so it is the normal path, not an edge case.
- **It fails silently in exactly the case it exists for.** Move or rename the
  repo and the slug changes; the probe finds nothing, resolves `repo`, and
  orphans the prior store — without firing the notice, because the notice was
  conditioned on the same probe that just failed.
- **It makes the destination unauditable.** An explicit key makes moving
  memory a one-line diff a reviewer sees. A probe lets a single file created
  under a directory Claude Code already owns redirect every future read and
  write, with no diff anywhere.
- **CI and a laptop would disagree by construction** — different `$HOME`,
  different checkout path — so any test asserting a resolved path would have
  two correct answers.

Deleting the external-path backend was challenged as scope reduction rather
than a leak fix, since the shipped value was only a commented placeholder.
That is true about the shipped bytes and beside the point: the objection was
to shipping a *configuration surface* for reaching into one machine's
directory at all. `.brain/` is self-contained and an outside store reads it;
the project never reaches out to someone else's directory. The relationship is
the product decision, not the placeholder.

Keeping `project` as the default was also argued for — let `/initialize-project`
set `repo` for new projects. Declined: the onboarding question only reaches
someone who runs init, and the shipped default is what everyone else gets.

## Consequences

- The BM25 index directory is keyed to the resolved backend. Before the flip it
  was not: `.loom-memory-index/bm25` stored repo-relative document paths and
  recorded nothing about which memory directory produced them, so a backend
  change would have kept serving hits for documents the resolver no longer
  points at. Pre-existing, but the default flip is what activated it — and a
  stale-hit failure in a retrieval layer is the hardest class to notice,
  because the results still look plausible.
- `memory-backend.conf` is on the governance `protected_paths` list, so a
  subagent is denied writes to it and a main-agent edit prompts for approval.
- Memory now travels with the code: in-tree, versioned, readable by any tool
  with filesystem access, and stripped at template release.

## Provenance caveat

The single source behind this page is an **in-session adversarial design
review by a Claude-lineage reviewer**, written in the `/cross-check` capture
shape but explicitly **not** a cross-provider `/cross-check` run. It is
same-lineage and therefore not decorrelated — it shares the author's blind
spots by construction, and must not be cited as a cross-check. The capture
says so itself; this page repeats it so a reader of the page alone cannot
mistake the provenance.

## Related

- `.brain/README.md` — the `.brain/` layer contract, including the two
  memory-backend options
- `.logic-loom/config/memory-backend.conf` — the live setting
- `.logic-loom/scripts/bash/resolve-memory-backend.sh` — the pure resolver
- `.logic-loom/scripts/bash/check-brain-signals.sh` — the stranded-store advisory
