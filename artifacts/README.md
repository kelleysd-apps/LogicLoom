# `artifacts/` — standalone deliverables

This directory holds **standalone deliverables**: a vision page, a research
write-up, a forensic record of an incident, a rendered doc. The test is
*who / what / why / where* — an artifact **states something**. It is **never a
plan** — sequencing belongs to `features/<name>/plan.md` or
`specs/###-name/tasks.md`. Hardwiring a plan into an artifact confines the
agent that should be deciding it.

This directory does not ship with content — only this README and a `.gitkeep`
travel with the harness. What you put here is yours: LogicLoom's own artifacts
are stripped before this project reaches you, so you inherit the convention
and none of our pages.

## What belongs here

- A single self-contained HTML page (inline CSS/JS, no external network
  requests) or a plain Markdown document.
- Flat by default — add subdirectories only when the file count warrants it.
- An HTML artifact must be **self-contained**: no CDN, no webfont, no remote
  image. It is meant to be opened directly from disk over `file://`, where
  cross-origin requests — including `fetch()` of a sibling file — are blocked
  by the browser. Inline everything a page needs at generation time.

## Hand-authored vs. generated

Most artifacts are hand-authored and committed as-is. A **generated**
deliverable that passes the who/what/why/where test belongs here too, and is
tracked like its neighbours — on one condition:

1. **Track only what a human opens.** The generated page is committed. A
   machine-readable intermediate with no standalone reader stays out of this
   directory, and stays out of git — nothing is lost by regenerating it.
2. **Pay the staleness cost with a gate, not a warning.** A tracked derived
   file drifts from its sources the moment one is edited without
   regenerating. The license to track a generated file here is a fail-closed
   freshness check that regenerates it and fails the build if the committed
   copy differs —
   `.logic-loom/scripts/bash/check-generated-freshness.sh` is the harness's
   own example, covering `artifacts/backlog-dashboard.html`. Add a tracked
   generated file, add it to that gate (or your own equivalent) in the same
   change. Remove the gate and the file goes back to being ignored.

## The backlog dashboard, if you build one

The harness ships two small, repo-neutral generator scripts:

```
.logic-loom/scripts/bash/build-backlog-index.sh       # reads todos.md / backlog.md
                                                        # (and feature/spec task lists)
                                                        # into a machine-readable index
.logic-loom/scripts/bash/build-backlog-dashboard.sh    # renders that index as one
                                                        # self-contained HTML page,
                                                        # here, at
                                                        # artifacts/backlog-dashboard.html
```

Both are plain shell + `jq`, have no reference to any specific project, and
read only your own `.logic-loom/memory/todos.md` and
`.logic-loom/memory/backlog.md`. Run them once to produce a first dashboard:

```bash
.logic-loom/scripts/bash/build-backlog-index.sh
.logic-loom/scripts/bash/build-backlog-dashboard.sh
```

Open `artifacts/backlog-dashboard.html` directly in a browser — no server
needed. The page also fetches your repository's **open GitHub issues** when
you open it (not at generation time — see the page itself for how it derives
your repo and what it does when there is no remote, no network, or no
token). Regenerating the page never runs a network call; only opening it
does.

If you commit the result, keep it current the way this harness does: either
regenerate it as part of your own workflow, or wire a freshness gate like
`check-generated-freshness.sh` into your CI so a stale copy fails the build
instead of quietly drifting.
