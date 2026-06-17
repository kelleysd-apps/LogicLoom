---
name: review-evaluator
version: 0.1.0
description: |
  External behavioral evaluator invoked as the 4th reviewer by `/review-team`,
  alongside security, quality, and performance. Grades UI changes via
  chrome-devtools accessibility-tree snapshots and emits a verdict + rubric
  scores at features/<name>/sprints/<NN>/<task-id>/evaluator-report.md.
allowed-tools: Read, Write, Bash, mcp__chrome-devtools__*, mcp__ide__getDiagnostics, LSP
triggers: ["evaluator", "behavioral review"]
category: orchestration
constitutional_principles: [II, X]
---

# Review Evaluator Skill

## Overview

This skill is the article-style external grader described in Anthropic's
harness-design write-up: a generator/grader split that avoids self-praise bias
by having a separate context grade the work the implementor produced. It is
invoked by `/review-team` as a 4th parallel reviewer (security + quality +
performance + evaluator) and is the only reviewer that exercises the running
code or behavioral surface — the other three are static analyzers.

The evaluator has two branches:

1. **UI branch (active in v0.1)**: When changed files include any UI surface
   (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html`, `*.css`), the evaluator
   uses chrome-devtools MCP to capture accessibility-tree snapshots of the
   running surface and grades them against the rubric.

2. **Non-UI / diagnostics branch (active in v0.1)**: For pure-function,
   backend, and library changes with no UI surface, the evaluator runs native
   IDE diagnostics / LSP (`mcp__ide__getDiagnostics`, and/or the native `LSP`
   tool) over the *changed files* and fails the **Functionality** rubric item on
   any type/diagnostic error. When no language server / IDE diagnostics are
   connected, it degrades gracefully to a scoped build/typecheck run (the
   project's typecheck or build command, restricted to the changed scope). If
   neither a diagnostics surface nor a toolchain is available, it FAILS OPEN to a
   clearly-labeled caveat ("non-UI functionality UNVERIFIED: no
   diagnostics/toolchain available") — it never becomes a phantom hard gate that
   blocks when verification simply isn't available.

## When to Use

Invoke this skill in exactly one window:

- **By `/review-team`** as the 4th reviewer, parallel to security / quality /
  performance. The team-orchestration integrator wires the spawn; this skill
  itself is the worker.
- **Post-`/swarm implement`** and **post-test-fix**, **before `/git-push`**.

Do NOT use this skill:

- During plan review (use `/plan-review` instead — that is the plan-stage gate).
- During brainstorming or vision drafting.
- For docs-only or config-only changes with no behavioral surface.

## Task Brief

You are the external behavioral evaluator. Your job is to grade the *behavior*
of the changed code, not its style. The static reviewers (security / quality /
performance) read source; you exercise the surface.

**Step 1 — Classify the change.** Read the changed-file list (passed via
`--changed-files` or derived from `git diff --name-only main...HEAD`). If any
file matches the UI globs (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html`,
`*.css`, `*.scss`), branch to UI grading. Otherwise, branch to non-UI grading
(diagnostics/LSP grading; see Step 4).

**Step 2 (UI branch) — Snapshot the surface.** Default mode is `snapshot`
(accessibility tree via `mcp__chrome-devtools__take_snapshot`), which is more
deterministic than visual screenshots and resists CSS drift. Use
`mcp__chrome-devtools__navigate_page` to load the target route, then
`mcp__chrome-devtools__take_snapshot` to capture the accessibility tree, plus
`mcp__chrome-devtools__list_console_messages` to capture any runtime errors.
Only fall back to `mcp__chrome-devtools__take_screenshot` if the user passes
`--mode screenshot` or if the rubric requires visual judgment (Design Quality,
Originality, Craft).

**Step 3 — Grade against the rubric.** Apply the Anthropic harness-design
"Concrete Grading Criteria". For each item, output `pass | concern | fail`
with a one-line justification grounded in the snapshot / screenshot:

- **Design Quality (UI only)**: Is this a coherent whole, or a collection of
  parts that happen to render on the same page? Look for consistent visual
  hierarchy, deliberate use of space, and a unifying composition.
- **Originality (UI only)**: Does this look like a custom design decision was
  made, or like a framework template with content swapped in? Flag obvious
  shadcn / Material defaults that were not adapted.
- **Craft (UI only)**: Typography (line-height, font-pairing), spacing (rhythm
  vs ad-hoc), contrast (WCAG AA at minimum), and technical competence
  (no console errors, no broken layouts at common breakpoints).
- **Functionality (UI or non-UI)**: Does the surface do what vision.md said it
  should do? Map each PRD success criterion to either a passing snapshot/test
  or a failing one. This is the load-bearing item — a beautiful UI that does
  not satisfy the vision is a `fail` here regardless of the other items.

**Step 4 (non-UI branch) — Functionality via diagnostics/LSP.** Grade the
behavior of the changed non-UI surface, in this order:

1. **Diagnostics/LSP first.** Run `mcp__ide__getDiagnostics` (and/or the native
   `LSP` tool) scoped to the changed files. Treat any error-severity diagnostic
   (type errors, unresolved symbols, compile errors) as a **fail** of the
   Functionality rubric item; record the offending `file:line` and message in
   the vision-criterion trace. Warnings alone are a `concern`, not a `fail`.
2. **Build/typecheck fallback.** If no language server / IDE diagnostics are
   connected, degrade gracefully to a scoped build or typecheck run — the
   project's `typecheck`/`build` command restricted to the changed scope (e.g.
   `tsc --noEmit`, `npm run typecheck`, `cargo check`, `go build ./...`, or
   `mypy`/`pyright` over the changed paths). A non-zero exit fails Functionality;
   capture the failing output.
3. **Fail open if nothing is available.** If neither a diagnostics surface nor a
   detectable toolchain exists, do NOT hard-fail. Emit a `pass-with-caveat`
   verdict with the labeled caveat "non-UI functionality UNVERIFIED: no
   diagnostics/toolchain available", and still map each PRD success criterion to
   its corresponding test file by inventory so the gap is visible. This branch
   must never become a phantom hard gate that blocks merely because verification
   tooling is absent.

The UI-only rubric items (Design Quality, Originality, Craft) are `n/a` on this
branch; Functionality is the load-bearing item.

**Step 5 — Synthesize and write the report.** Combine rubric results into one
verdict using this rule:

- Overall = `pass` only if every applicable rubric item is `pass`.
- Overall = `fail` if any item is `fail` OR if Functionality is `concern` and
  any other item is also `concern`.
- Overall = `concern` otherwise.

## Procedure

1. **Parse arguments**: Extract `<feature-name>` and `<task-id>` (positional
   or from `--feature` / `--task`), `--ui-only` (force UI branch even if no UI
   files changed — used for forced re-grading), `--mode {snapshot|screenshot}`
   (default `snapshot`), `--url` (URL to evaluate; if absent, read from
   `features/<name>/vision.md` "Local URL" line or default to
   `http://localhost:3000`).
2. **Resolve artifacts**: Confirm `features/<feature-name>/vision.md` and
   `features/<feature-name>/prd.md` exist. Bail with a clear error if either is
   missing.
3. **Get changed files**: If `--changed-files` was passed, use that list;
   otherwise run `git diff --name-only main...HEAD` via Bash.
4. **Classify**: Apply the UI-glob test to the changed-file list. Honor
   `--ui-only` override.
5. **UI branch** (if applicable):
   a. Call `mcp__chrome-devtools__new_page` (or `select_page`) and
      `mcp__chrome-devtools__navigate_page` with the resolved URL.
   b. `mcp__chrome-devtools__take_snapshot` for the accessibility tree.
   c. `mcp__chrome-devtools__list_console_messages` for runtime errors.
   d. If `--mode screenshot` or rubric requires it,
      `mcp__chrome-devtools__take_screenshot` and store path.
   e. Apply Design Quality / Originality / Craft / Functionality rubric.
6. **Non-UI branch**: Run diagnostics/LSP (`mcp__ide__getDiagnostics` / `LSP`)
   over the changed files and fail Functionality on any error-severity
   diagnostic; if no language server is connected, fall back to a scoped
   build/typecheck run; if no toolchain is detectable either, fail open to the
   labeled "non-UI functionality UNVERIFIED" caveat — per Step 4 of the Task
   Brief.
7. **Write report** to
   `features/<feature-name>/sprints/<NN>/<task-id>/evaluator-report.md`
   using the schema below. Create the sprint directory via `mkdir -p` if it
   does not exist (Principle XV: verify before create — confirm
   `features/<feature-name>/` exists first).
8. **Print summary**: Echo overall verdict + path of the written artifact. Do
   not print the full report — the file is the artifact.

## Output format

Write `features/<feature-name>/sprints/<NN>/<task-id>/evaluator-report.md`:

```markdown
# Evaluator Report — <feature-name> / <task-id>

- Date: <YYYY-MM-DD>
- Branch: ui | non-ui
- Mode: snapshot | screenshot | n/a
- URL evaluated: <url or n/a>
- Overall verdict: pass | concern | fail | pass-with-caveat

## Overall reasoning

<2-4 sentences. Name the load-bearing rubric item driving the verdict.>

## Rubric

| Item | Result | Justification |
|------|--------|---------------|
| Design Quality | pass / concern / fail / n/a | ... |
| Originality | pass / concern / fail / n/a | ... |
| Craft | pass / concern / fail / n/a | ... |
| Functionality | pass / concern / fail | ... |

## Vision-criterion trace

| PRD success criterion | Snapshot/test reference | Result |
|-----------------------|-------------------------|--------|
| <quoted criterion> | <snapshot id or test path> | pass / fail |

## Artifacts

- Accessibility snapshot: <inline snapshot id or path>
- Screenshot (if captured): <path>
- Console errors: <count + summary, or "none">

## Required changes (if verdict is fail or concern)

- [ ] <concrete change grounded in a rubric item above>
- [ ] ...
```

## Configuration

**Arguments:**

- `<feature-name>` (required, positional or `--feature`): directory under
  `features/`.
- `<task-id>` (required, positional or `--task`): the task within the sprint
  being graded. Drives the report path.
- `--ui-only` (optional): force UI branch even when no UI files changed. Used
  for forced re-grades after refactors.
- `--mode {snapshot|screenshot}` (optional, default `snapshot`): controls
  chrome-devtools capture mode. `snapshot` (accessibility tree) is preferred
  because it is deterministic; `screenshot` is for visual-judgment items only.
- `--url <url>` (optional): URL to evaluate. Resolution order: flag → "Local
  URL" line in `vision.md` → `http://localhost:3000`.
- `--changed-files <comma-list>` (optional): override the changed-file
  inventory used for UI-glob classification.

**Tool dependencies:**

- `mcp__chrome-devtools__*` (already declared in `.mcp.json`). If the MCP
  server is not connected, bail with an actionable error: "chrome-devtools MCP
  not connected; verify .mcp.json and restart Claude Code."

**Promotion criteria (v0.1 → v0.2):**

The non-UI branch now grades Functionality via diagnostics/LSP with a scoped
build/typecheck fallback (and a fail-open labeled caveat when no toolchain is
available). A future enhancement layers property-based runs (fast-check /
Hypothesis) on top of the diagnostics pass for deeper behavioral coverage. Also
defer-tracked: screen-recording on failure (Devin 2.2 pattern) for the UI
branch.

## Constitutional alignment

- **Principle II (Test-First)**: The evaluator is the runtime test against the
  vision. The Functionality rubric is a behavioral test, not a style check —
  failing it means the implementation does not satisfy the spec.
- **Principle X (Agent Delegation)**: This skill is the specialist for
  behavioral grading. `/review-team` must delegate the 4th-reviewer slot here
  rather than inlining ad-hoc UI checks in the synthesizer.
