---
name: cross-check
description: Governed cross-provider adversarial review. A non-Claude model (Codex/GPT default; Gemini pluggable) tears apart a diff/plan/claims/file scope and returns structured findings — advisory, read-only, never touches git. The canonical path for all cross-check reviews.
model: opus
---

# /cross-check Command — Governed Cross-Provider Adversarial Review

**SKILL ACTIVATION**: Read and execute
`plugins/loom-orchestrator/skills/cross-check/SKILL.md`.

This is the **canonical entry point** for adversarial / cross-check review by an
outside model lineage. `/review-team` and `/plan-review` route through the *same*
skill as a reviewer slot — `/cross-check` is the ad-hoc standalone form.

## Why a non-Claude reviewer

By default LogicLoom's reviewers are Claude reviewing Claude — shared lineage,
shared blind spots. A different lineage (Codex/GPT, Gemini) catches the defects
correlated reviewers structurally miss. The external model stays strictly
**advisory and read-only**: it emits findings, the governed Claude agent triages
and decides. It never edits code and never touches git (Principle VI; keeps
cross-provider use inside the verification-layer boundary).

## Execution Instructions

### Step 1: Load skill
Read `plugins/loom-orchestrator/skills/cross-check/SKILL.md` and follow its
Procedure.

### Step 2: Parse arguments
- `<target>` (positional, default `diff` = current branch vs `main`): also
  accepts a file/glob, a `plan.md` path, or a `claims.json` path.
- `--provider {codex|openai|gemini}` (default `codex`).
- `--mode {api|cli}` (default `api`) or `--deep` (alias for `--mode cli`): API is
  artifact-scoped (cleanest governance); `--deep` lets the provider explore the
  repo under a read-only sandbox (new trust assumption — see the skill).
- `--focus <area>` (optional): bias the adversary (e.g. `security`,
  `concurrency`).
- `--out <path>` (optional): override the default
  `.docs/cross-check/...` artifact location.

### Step 3: Gate (fail-open)
If the provider's key (`OPENAI_API_KEY` / `GEMINI_API_KEY`) is missing in `.env`
(Mode A), or its CLI is absent (Mode B), do **not** error — write an
`unavailable` report with the labeled caveat and stop. Reference
`/initialize-project` for key setup. An external adversary that cannot run must
never block work.

### Step 4: Run + adjudicate
Spawn one Task subagent to run the external model (per the skill), then — as the
governed main agent — triage each finding `accept | reject | needs-investigation`.
The external opinion is never auto-truth.

### Step 5: Report
Print the overall verdict (`pass | concern | fail | unavailable`) and the
artifact path. The report file is the deliverable — do not echo it in full.

## Usage

```
/cross-check                                  # Codex API-reviews the current diff vs main
/cross-check --deep                           # Codex explores the repo read-only, then reviews
/cross-check --provider gemini --focus security
/cross-check features/auth/plan.md            # adversarial review of a plan
/cross-check src/payments/**.ts --deep        # repo-aware review of a file scope
/cross-check .docs/research/.../claims.json   # external challenge of a claim set
```

## Constitutional Compliance

- **Principle VI (Git Approval)**: never invokes git; the external model is
  structurally barred from it (advisory + read-only).
- **Principle X (Agent Delegation)**: the external call is delegated to a Task
  subagent for context isolation and key hygiene; this command coordinates and
  adjudicates only.
- **Principle XIV (Provider Boundary)**: cross-provider use stays at the
  verification layer, held advisory — never orchestration.
