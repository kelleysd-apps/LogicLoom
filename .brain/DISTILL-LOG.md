# Distillation log

Append-only. **One dated entry per `/distill` run, including a zero-op run.**
Newest first, directly under this heading.

A one-line healthy entry is what makes a later break visible by contrast. The
age of the newest entry — not queue depth — is what says the pass is alive: a
pass that ran and cleared the queue and a pass nobody ever installed over an
empty repo both read zero captures.

Grammar and the four promotion outcomes: `.brain/README.md` and
`plugins/loom-orchestrator/skills/distillation-pass/SKILL.md`.

## 2026-08-31

- run: /distill
- scanned: 1 captures under .brain/raw/ (1 unprocessed)
- promoted: .brain/raw/reviews/20260826-153000-memory-backend-default/cross-check-report.md -> .brain/wiki/decisions/memory-backend-default.md
- result: first promotion. `.brain/wiki/` created. The capture self-declares that
  it is a same-lineage design review in `/cross-check` shape and not a
  cross-provider run; that caveat is carried onto the page rather than dropped.

## 2026-08-26

- run: /distill
- scanned: 0 captures under .brain/raw/ (0 unprocessed)
- result: zero-op
- note: first run. `.brain/raw/` holds only its README; no command redirects
  output here yet, so a capture arrives only when a human puts one here. This
  entry exists precisely because it is boring — it is the liveness mark.
