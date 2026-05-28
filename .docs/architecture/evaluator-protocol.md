# Evaluator Protocol

**Status**: v0.1 (Loom migration, Stage 8)
**Skill**: `plugins/sdd-orchestrator/skills/review-evaluator/SKILL.md`
**Reference**: Anthropic, "How we built our multi-agent harness" — the
generator/grader split (article §Concrete Grading Criteria).

---

## What is the evaluator

The evaluator is an **external grader** that runs in a separate Task context
from the implementor. The article describes this as a GAN-style separation:
the model that produced the code cannot be trusted to grade its own work
(self-praise bias is well documented), so a fresh-context grader is invoked
against the same vision/prd artifacts and the running surface.

`/review-team` already runs three static reviewers in parallel: **security**,
**quality**, **performance**. The evaluator is added as a **4th reviewer**,
distinct from the other three in that it exercises *behavior* — it loads the
running app, takes accessibility-tree snapshots, and grades the rendered
surface against the vision. The static reviewers read source; the evaluator
reads outcomes.

## When it fires

Exactly one window in the feature lifecycle:

- **After** `/swarm implement` finishes a task or sprint.
- **After** any post-implement test-fix passes.
- **Before** `/git-push` opens a PR for that work.

It does NOT fire:

- During plan review — that is `/plan-review`'s scope (plan-stage gate).
- During vision or PRD authoring — no surface exists yet to grade.
- For docs-only or config-only diffs — no behavioral surface.

`/review-team` is the invoker. The team-orchestration skill spawns four Tasks
in parallel; review-evaluator is one of them.

## Inputs

The evaluator reads:

1. **Changed-file inventory** — passed via `--changed-files` or derived from
   `git diff --name-only main...HEAD`. Used to classify UI vs non-UI.
2. **`features/<name>/vision.md`** — the success criteria the surface must
   satisfy. The Functionality rubric maps each criterion to a snapshot or test.
3. **`features/<name>/prd.md`** — the deliverables list and explicit
   acceptance items. The PRD lines are the trace targets in the report.
4. **Running surface URL** — resolved from `--url`, the "Local URL" line in
   `vision.md`, or `http://localhost:3000`.
5. **(Optional) sprint + task ID** — drives the report path.

## Outputs

A single artifact:

`features/<feature-name>/sprints/<NN>/<task-id>/evaluator-report.md`

Schema (full schema lives in the skill SKILL.md; reproduced here for the
protocol record):

- Header: feature, task, date, branch (ui | non-ui), mode (snapshot |
  screenshot | n/a), URL, overall verdict.
- Overall reasoning: 2–4 sentences naming the load-bearing rubric item.
- Rubric table: Design Quality, Originality, Craft, Functionality, each one
  of `pass | concern | fail | n/a` with a one-line justification.
- Vision-criterion trace table: each PRD success criterion paired with a
  snapshot id or test path and a `pass / fail`.
- Artifacts: snapshot id(s), screenshot path(s), console-error summary.
- Required-changes checklist (only if verdict is `fail` or `concern`): each
  item must be concrete and grounded in a named rubric item.

Verdict synthesis rule:

- `pass` only if every applicable rubric item is `pass`.
- `fail` if any item is `fail`, OR if Functionality is `concern` and another
  item is also `concern`.
- `concern` otherwise.
- `pass-with-caveat` is reserved for the non-UI branch in v0.1 only.

## Rubric — concrete grading criteria

Sourced from the Anthropic harness-design article. Items 1–3 apply to UI
branches only; item 4 is the load-bearing item and applies to all branches.

1. **Design Quality (UI)** — coherent whole vs collection of parts.
2. **Originality (UI)** — custom decisions vs template defaults (e.g. shadcn
   or Material defaults shipped unmodified).
3. **Craft (UI)** — typography, spacing, contrast (WCAG AA floor), no console
   errors, no broken layouts at common breakpoints.
4. **Functionality (all branches)** — does the surface do what vision.md
   said? Each PRD success criterion is traced to a pass/fail snapshot or test.

## Tool dependencies

**chrome-devtools MCP** — already declared in `.mcp.json` at the repo root:

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": ["chrome-devtools-mcp@latest"]
}
```

The evaluator uses these chrome-devtools MCP tools:

- `mcp__chrome-devtools__new_page` / `select_page` — open or attach to a page.
- `mcp__chrome-devtools__navigate_page` — load the resolved URL.
- `mcp__chrome-devtools__take_snapshot` — accessibility-tree snapshot
  (default; deterministic; resists CSS drift).
- `mcp__chrome-devtools__list_console_messages` — capture runtime errors that
  flow into the Craft rubric item.
- `mcp__chrome-devtools__take_screenshot` — only when `--mode screenshot` is
  passed or a rubric item requires visual judgment.

**Default mode is `snapshot`**. Accessibility-tree snapshots are deterministic
and stable across cosmetic CSS changes; screenshots flicker on every theme
tweak. Use screenshots sparingly.

If chrome-devtools MCP is not connected, the evaluator must bail with an
actionable error and not write a report.

## Snapshot vs screenshot mode

| Aspect | Snapshot (default) | Screenshot |
|--------|--------------------|------------|
| Output | Accessibility tree (text) | PNG |
| Determinism | High | Low (CSS / font drift) |
| Diffable | Yes (textual) | No |
| Use for | Functionality, structural rubric items | Design Quality, Originality, Craft when visual judgment is load-bearing |
| Cost | Low | Higher (image bytes through context) |

Rule: start with snapshot. Promote to screenshot only when the rubric item
requires it.

## Branching: UI vs non-UI

Classification is glob-based on the changed-file list:

- **UI globs**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html`, `*.css`,
  `*.scss`.
- Any match → UI branch.
- No match → non-UI branch (v0.1 placeholder).

The `--ui-only` flag forces the UI branch even with no matching files (used
for forced re-grades after refactors).

## Failure modes the evaluator catches

- **Spec drift**: implementation built something different from vision.md.
  Surfaces as a Functionality `fail` with the failing criterion named.
- **Template defaults shipped as design**: shadcn/Material defaults left
  unadapted. Surfaces as Originality `concern` or `fail`.
- **Runtime errors hidden by passing tests**: tests mock the failing
  dependency. Surfaces in `list_console_messages`, flows into Craft.
- **Beautiful-but-broken**: surface looks good but does not do what was
  asked. Caught by the synthesis rule — Functionality `fail` overrides all
  other passes.

## Future work (deferred from v0.1)

These items are explicitly out of scope for v0.1 and tracked for v6.0+:

1. **Property-based testing branch** — the non-UI branch in v0.1 is a
   placeholder. v6.0 will generate fast-check (JS/TS) or Hypothesis (Python)
   property tests against pure functions and contracts. The rubric for this
   branch will be coverage / property-test depth / regression detection.
2. **Screen-recording on failure** — Devin 2.2 pattern. When the evaluator
   returns `fail`, capture a short video of the interaction that produced the
   failure to accelerate human triage. Requires chrome-devtools MCP support
   for recording, which is not yet exposed.
3. **Multi-route walkthrough** — v0.1 evaluates a single URL. v0.2+ will read
   a route list from the PRD and walk each in turn.

## Reference

- Anthropic, "How we built our multi-agent harness" — load-bearing source
  for the generator/grader split and the Concrete Grading Criteria rubric.
  See `.logic-loom/memory/MEMORY.md` →
  `reference_anthropic_harness_design.md` for the indexed notes.
- `plugins/sdd-orchestrator/skills/review-evaluator/SKILL.md` — the
  procedural implementation of this protocol.
- `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` — the
  `/review-team` integrator that spawns the evaluator as the 4th reviewer
  (wired by the Stage 8 integrator, not this worker).
