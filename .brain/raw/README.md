# `.brain/raw/` — captures

A capture is **evidence**: the output of a command, an investigation, or a
decision-shaped conversation, kept as it was produced.

## Rules

1. **Immutable after capture.** Append or supersede with a new file. Never
   rewrite one, and never edit its body — evidence you can edit isn't. The only
   edits `/distill` makes here are frontmatter: `status`, and one of
   `distilled-into` / `discarded`.
2. **Never deleted.** This tree is stripped at template release, so deleting a
   capture after distilling it would leave the only surviving copy of its
   content as a paragraph in a wiki page. The cost is stated rather than waved
   away: this directory grows without bound, and `status` becomes the only thing
   separating pending from done.
3. **Every capture carries a parseable `status`.** A capture with no status is
   invisible to `/distill` forever. The integrity gate's check 1 exists solely to
   close that.

## Frontmatter

```yaml
---
type: capture
title: "Short descriptive title"
date: YYYY-MM-DD
source: "/research \"the question\""     # the command or act that produced it
status: unprocessed                       # unprocessed | processed
---
```

Once processed, add **exactly one**:

```yaml
distilled-into: .brain/wiki/concepts/<page>.md     # or [[page-slug]]
discarded: "why this was not promoted"
```

Both present is an error. Neither present, on a `processed` capture, is a claim
nothing backs — the gate fails on both.

**Quoted and unquoted YAML both occur** (`status: unprocessed` and
`status: "unprocessed"`). Parse the frontmatter block; never grep for the
literal string. Grepping for one form caused a recorded miss in the system this
convention was ported from.

## Layers

Create one the first time you have a file for it:

| Directory | Holds |
|---|---|
| `research/` | `/research` tribunal output |
| `exploration/` | `/swarm explore` output |
| `reviews/` | `/review-team`, `/cross-check`, `/plan-review` verdicts |
| `reports/` | forensics, one-off investigations |
| `retro/` | `/retro` raw output |
| `archive/` | superseded plans, historical designs |

`README.md` files are conventions documentation, not captures, and are exempt
from every check.

## Naming

`YYYYMMDD-<kebab-slug>.md`. The date prefix sorts the directory chronologically
and survives a slug rename.
