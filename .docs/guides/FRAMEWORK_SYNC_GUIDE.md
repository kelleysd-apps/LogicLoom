# Framework Synchronization Guide

How a project built from LogicLoom pulls in upstream framework enhancements —
safely, with one method and no chance of committing to the wrong repo.

## How updates work — read this first

**`/update-framework` is the single method.** It is **fetch-only**,
**proposal-based**, **additive-only**, and **never merges**. Run it from inside
Claude Code:

```
/update-framework
/update-framework --check-only
```

It shows you what *upstream* added since your last sync and lets you adopt each
change independently. The procedure of record is the `framework-updater` skill
(`plugins/loom-maintenance/skills/framework-updater/SKILL.md`).

### Safety invariants (why it can't misfire)

1. **No `upstream` remote — ever.** The upstream is fetched **ad-hoc** into the
   namespaced ref `refs/loom-upstream/main`. LogicLoom never runs
   `git remote add upstream`, so there is nothing to `git push upstream` to. The
   ref is pruned after each run and re-fetched next time.
2. **Your commits only go to `origin`.** Accepted changes are applied to **your
   current branch** and committed there (gated by Principle VI — the
   `git-safety-gate` hook prompts for every commit). Updates never push, pull, or
   merge against upstream.
3. **Upstream history only.** It diffs `sync-ref..refs/loom-upstream/main` —
   upstream's *own* history. It never diffs your work against upstream and never
   produces merge conflicts.
4. **One source of truth for the URL.** See below — never derived from `origin`.

## Where the upstream URL comes from

Resolution precedence (in `extract-proposals.sh`):

1. `LOOM_UPSTREAM_URL` environment variable (per-run override), then
2. `.logic-loom/config/framework-upstream.conf` (`LOOM_UPSTREAM_URL`, else
   `LOOM_UPSTREAM_REPO` → `https://github.com/<repo>.git`).

The config ships with the template and is **stamped at release** with the real
public template repo, so a fresh project already points at the right upstream. It
is **never** derived from `origin` (origin is *your* repo — the wrong direction).
A custom fork can override per run: `export LOOM_UPSTREAM_URL=https://…/your-fork.git`.

## Fresh template instance (Use this template / fork)

A project created from the public template already ships a correct
`.sdd-sync-ref` and `framework-upstream.conf` — just run `/update-framework`. The
first run on a freshly-cut template usually shows little or nothing (you're
current); later releases show their deltas. If `.sdd-sync-ref` is missing (e.g. a
fork deleted it), the first run sets the baseline to the current upstream HEAD,
adopts nothing, and tells you to re-run later.

## Troubleshooting

- **"`.sdd-sync-ref` is NOT reachable from upstream main" / broken sync baseline.**
  An upstream release PR was squash- or rebase-merged, breaking the single-parent
  chain the sync baseline depends on. Re-baseline (adopts nothing, just resets the
  pointer), then re-run:
  ```bash
  git rev-parse refs/loom-upstream/main > .sdd-sync-ref
  ```
- **A stale `upstream` remote from an older clone.** Older versions added a
  pushable `upstream` remote. The current flow ignores it, but it's an unused
  push footgun — remove it (it is safe to do so):
  ```bash
  git remote remove upstream
  ```
- **Upstream URL not configured (custom fork).** Set it once:
  `LOOM_UPSTREAM_REPO="<owner>/<repo>"` in
  `.logic-loom/config/framework-upstream.conf`, or `export LOOM_UPSTREAM_URL=…`.
- **After adopting changes**, run `./.logic-loom/scripts/bash/constitutional-check.sh`
  and your test suite before committing.

> This guide describes the **only** supported update path. There is no merge-based,
> remote-tracking, or `git diff HEAD..upstream` workflow — those would risk merge
> conflicts and wrong-repo confusion, which this design deliberately removes.
