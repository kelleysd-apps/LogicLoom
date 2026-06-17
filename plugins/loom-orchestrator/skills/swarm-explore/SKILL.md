---
name: swarm-explore
version: 0.1.0
description: |
  Read-only multi-agent investigation mode of `/swarm`. Spawns N parallel
  investigators (Task tool, read-only allowed_tools) over slices of a topic
  and synthesizes their findings into a single exploration report.
allowed-tools: Task, Read, Write, Grep, Bash
triggers: ["swarm explore", "/swarm explore"]
category: orchestration
constitutional_principles: [X]
---

# Swarm Explore Skill

## Overview

`swarm-explore` is the investigation mode of `/swarm`. It decomposes a topic
into N independent slices, dispatches one read-only investigator per slice via
the Task tool, and synthesizes their findings into one markdown report. No
investigator may write, edit, or mutate state — the read-only contract is
enforced by restricting each spawned Task's `allowed_tools` to `Read`, `Grep`,
`Glob`, and `WebFetch`.

This skill is the orchestration counterpart to `swarm-implement`. Where
`swarm-implement` parallelizes writes, `swarm-explore` parallelizes reads.

## When to Use

Invoke this skill in two windows of the LogicLoom workflow:

- **Phase 1 (Vision / Research)**: Parallel exploration of an idea space —
  competing approaches, prior art, library landscape, codebase precedents —
  before any `vision.md` or `prd.md` is committed.
- **Phase 3 (Implementation Discovery)**: Parallel reconnaissance over an
  existing codebase prior to drafting `plan.md` — e.g., "find every call site
  of X", "map the auth boundaries", "enumerate the migration touchpoints".

Do NOT use this skill:

- When the question is single-thread and well-scoped (use `Read`/`Grep`
  directly).
- When a write is required (use `/swarm implement` instead).
- For PR review (use `/review-team`) or plan review (use `/plan-review`).

## Task Brief

You are the orchestrator. You will decompose `<topic>` into `N` investigator
slices, dispatch each slice as a separate Task with a read-only tool
restriction, collect their reports, and synthesize one document.

**Slice decomposition rules:**

- Default `N = 3`, max `N = 5`. The user can override with `--agents N`.
- Slices must be **independent** (no shared state, no ordering). If you cannot
  decompose into independent slices, return `N = 1` and explain in the report.
- Each slice gets: a one-paragraph charter, a **`## Repo map (ranked)`**
  section (see below) computed over the slice's entry-point area, and an
  explicit "what to return" rubric. The ranked repo map replaces the old
  free-form "suggested entry points" list — it IS the grounded, ranked set of
  entry points. External URLs that have no repo footprint may still be named
  inline in the charter prose.

**Repo map (ranked) — slice charter grounding:**

For each slice, you (the orchestrator) pre-compute a LIGHT, ranked skeleton over
the slice's entry-point area (its touch-set) and embed it in the slice charter
under a section titled exactly `## Repo map (ranked)`. This grounds each
investigator in the concrete code surface before it starts reading.

- **Contents**: per file in the slice's entry-point area, its key
  symbols/signatures plus the top references (call sites / importers) to those
  symbols. Rank by reference count, then embed the highest-ranked first.
- **Size cap**: the whole section is **<= ~40 lines** — drop the lowest-ranked
  entries to stay under the cap. This is a sketch, not an inventory.
- **How it is built**: native `Grep`/`Read` for symbol and reference discovery;
  IF `command -v ctags` or `command -v tree-sitter` succeeds (checked via
  `Bash`), use that for richer signatures. Gracefully fall back to Grep-only
  when neither is present. This is read-only repo inspection by the
  orchestrator — it writes nothing into the repo.
- **What it is NOT**: not a full PageRank / global-importance index. It is a
  cheap, local, ranked sketch scoped to one slice's entry-point area.
- The map is auto-included in the slice charter; the read-only investigator
  still only reads.

**Dispatch contract (read-only enforcement):**

Each investigator is spawned via the Task tool with:

- `subagent_type`: a general-purpose investigator agent (no write tools in its
  profile).
- `allowed_tools`: exactly `["Read", "Grep", "Glob", "WebFetch"]`. Do NOT
  include `Write`, `Edit`, `Bash`, `NotebookEdit`, or any MCP tool that mutates
  state. If the available Task-spawning interface does not accept an
  `allowed_tools` restriction, embed an explicit instruction in the prompt:
  "You are read-only. You MUST NOT call Write, Edit, Bash, or any tool that
  mutates filesystem, repo, or remote state. Return findings as markdown."
- prompt: the slice charter (which embeds the `## Repo map (ranked)` section) +
  return rubric.

**Synthesis:**

After all investigators return, you (the orchestrator) consolidate their
findings into one report. Do not paste raw transcripts; extract and dedupe.
Cite files with absolute paths. Preserve disagreements between investigators
as `Open questions` rather than collapsing them.

## Procedure

1. **Parse arguments**: Extract `<topic>` (required, free text) and flags
   `--agents N` (optional, default 3, max 5) and `--out <path>` (optional).
2. **Resolve output destination**:
   - If `--out <path>` was passed, use it.
   - Else if `$LOOM_ACTIVE_FEATURE` env var is set or `.loom-active-feature`
     marker exists in CWD, resolve to
     `features/<active-feature>/exploration/<topic-slug>.md`.
   - Else fall back to `./exploration/<topic-slug>.md` in CWD.
   - `<topic-slug>` is `<topic>` lowercased, non-alphanumerics replaced with
     `-`, trimmed, truncated to 60 chars.
   - Create parent directory if missing.
3. **Decompose topic into N slices**: Produce `N` slice charters per the Task
   Brief. For each slice, compute its `## Repo map (ranked)` section over the
   slice's entry-point area (native `Grep`/`Read`, plus ctags/tree-sitter via
   `Bash` when `command -v` finds them; Grep-only fallback otherwise), cap it at
   ~40 lines, and embed it in the charter. If the topic is genuinely
   single-thread, set `N = 1` and proceed.
4. **Dispatch investigators in parallel**: Make `N` Task tool calls in a
   single batch. Each call carries the read-only `allowed_tools` restriction
   (or the embedded read-only instruction if restriction is not supported).
5. **Collect findings**: Wait for all investigators to return. If any fail,
   record the failure as an `Open question` and continue — do not retry
   automatically.
6. **Synthesize**: Produce one report per the Output format below.
7. **Write artifact**: Write the report to the resolved output path,
   overwriting any prior file at that path.
8. **Print summary**: Echo the output path, the number of investigators run,
   and a one-line topline finding. Do not print the full report.

## Output format

Write the report with exactly this structure:

```markdown
# Exploration — <topic>

- Date: <YYYY-MM-DD>
- Investigators: <N>
- Active feature: <feature-name or "none">

## Topline

<1-3 sentences. The single most decision-relevant finding.>

## Key findings

- <Bulleted, deduped findings. Each ends with one or more `path:line` or URL
  citations.>
- ...

## Per-slice summaries

### Slice 1 — <charter>
<2-5 sentence summary of what investigator 1 returned.>

### Slice 2 — <charter>
<...>

## Open questions

- <Disagreements between investigators, unresolved threads, follow-up
  explorations worth running.>

## Files referenced

- <absolute path>
- ...
```

The `Topline` is the load-bearing field — a reader who only reads the first
section must be able to decide the next move. `Per-slice summaries` exist for
auditing, not for the primary reader.

## Configuration

**Arguments:**

- `<topic>` (required, free text): the question or area to explore.
- `--agents N` (optional, default `3`, max `5`): number of parallel
  investigators. Clamp silently if `N > 5`.
- `--out <path>` (optional): override the output destination.

**Resolution rules for active feature:**

- `LOOM_ACTIVE_FEATURE` env var takes precedence over `.loom-active-feature`
  marker file.
- The marker file is a one-line text file containing the active feature name.
- If neither is present, the skill still runs; the report just lands in the
  CWD-relative path or stdout per the resolution above.

**Read-only contract:**

This skill MUST NOT spawn any Task whose tool surface includes write,
mutation, or shell execution. The contract is enforced via the spawned Task's
`allowed_tools` field (preferred) and reinforced by a read-only instruction in
the prompt. A violation of this contract is a Principle X violation and a
correctness bug — investigators are scouts, not builders.

## Constitutional alignment

- **Principle X (Agent Delegation)**: This skill IS the specialist for
  parallel read-only investigation. `/swarm` must route `explore` invocations
  here rather than performing ad-hoc searches in the main context.
