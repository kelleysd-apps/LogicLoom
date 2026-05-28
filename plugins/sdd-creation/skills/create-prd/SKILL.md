---
name: create-prd
description: Create a Product Requirements Document as Single Source of Truth for project initialization
allowed-tools: Read, Write, Bash, Grep, Glob
---

# create-prd Skill

Create a structured Product Requirements Document (PRD) that serves as the Single Source of Truth bridging vision/research into downstream planning.

The skill operates in **two modes**, auto-detected from inputs:

- **Vision-driven mode** (primary): consumes `features/<feature-name>/vision.md` + optional research/exploration/architecture context and produces a broad PRD anchored on a Forcing Questions section.
- **Legacy mode** (backward-compat): interactive blank-slate PRD generation for callers that don't have a vision file yet.

## Procedure

### Step 1: Resolve Target & Detect Mode

1. If the user passed `<feature-name>` as an argument, set `FEATURE_DIR=features/<feature-name>/`.
   - If no argument provided, ask the user: *project-level PRD, feature-level PRD (which feature?), or product pivot?* Then resolve `FEATURE_DIR` accordingly (or leave unset for project-level).
2. **Auto-detect mode**:
   - If `FEATURE_DIR/vision.md` exists → **vision-driven mode**
   - Else → **legacy mode** (existing blank-slate behavior, preserved for backward compat)

### Step 2: Load Template

Read PRD template from `.logic-loom/templates/prd-template.md`. If missing, fall back to the standard PRD structure documented inline.

### Step 3a: Vision-Driven Mode

If a vision file was detected:

1. **Read inputs** (cite source files inline in the PRD where used):
   - `FEATURE_DIR/vision.md` — required
   - `FEATURE_DIR/exploration/*.md` — optional (read all if present)
   - `FEATURE_DIR/research/*.md` — optional (read all if present)
   - `.docs/architecture/*.md` — optional context (read selectively if relevant)

2. **Populate the Forcing Questions section FIRST** (before any other product detail). The 6 mandatory questions:
   1. Who exactly is this for? (concrete user/persona)
   2. What is the smallest valuable thing we could ship? (MVP scope)
   3. What does "done" look like at the user-visible level?
   4. What are we explicitly NOT doing in this iteration?
   5. What is the riskiest assumption?
   6. What does success look like quantitatively (or qualitatively if metrics aren't tractable)?

   Answer each from vision + research + exploration. Cite source files inline (e.g., *"per vision.md §Goals"*). If any question genuinely cannot be answered from the inputs, write *"UNKNOWN — needs user input"* and surface those gaps in the final report — **do not block**.

3. **Synthesize a broad PRD**. Populate the remaining template sections (product context, deliverables, design language, success criteria, etc.) but **leave reasoning room for downstream agents**. Do NOT specify granular implementation details — per Anthropic's harness-design article, "if the planner tried to specify granular technical details upfront and got something wrong, the errors in the spec would cascade." The PRD declares product context and deliverables, not tight implementation specs.

4. **Write output** to `FEATURE_DIR/prd.md`.

### Step 3b: Legacy Mode

If no vision file detected, preserve existing behavior:

1. Walk through PRD sections interactively with the user:
   - Product Vision & Goals — what problem, desired outcome?
   - Target Users & Personas — who, key characteristics?
   - Feature Requirements — MoSCoW prioritization (Must/Should/Could/Won't)
   - Technical Constraints — stack, platform, performance, integrations
   - Success Metrics & KPIs — how measured, targets?
   - Timeline & Milestones — key delivery dates or phases
2. Populate template with gathered information; add constitutional compliance section.
3. Write to `specs/prd/PRD.md` (project-level) or `specs/{feature}/prd.md` (feature-level).

### Step 4: Report

- Show PRD output path.
- In vision-driven mode: list any Forcing Questions answered with *UNKNOWN* so the user can resolve them, and cite which input files were consumed.
- Suggest next steps:
  - User reviews the PRD before proceeding (the real gate is user review, not an automated block).
  - `/initialize-project` (post-PRD project customization) or downstream planning workflow.

## Gate Philosophy

The Forcing Questions are **section headers the model fills in from vision + research** — not a hard refuse-to-proceed gate. The skill always produces a PRD; if any forcing question cannot be answered from available inputs, the answer is marked *UNKNOWN — needs user input* and surfaced in the final report. **The real quality gate is the user reviewing the PRD output before moving to plan-mode.** This keeps the workflow unblocked while still forcing the model to confront the 6 questions early, before drafting downstream product detail.

## Constitutional Compliance

- **Principle III (Contract-First)**: PRD serves as the initial contract for downstream planning.
- **Principle V (Progressive Enhancement)**: Vision-driven mode is additive — legacy callers keep working unchanged.
- **Principle VIII (Documentation Sync)**: PRD must be kept in sync with implementation.
- **Principle XV (File Organization)**: Outputs land at `features/<feature-name>/prd.md` (vision-driven) or `specs/prd/PRD.md` (legacy).

## Task Brief

When spawning a worker to create a PRD, include this context:

> You are creating a Product Requirements Document using the SDD framework's PRD template. The skill auto-detects mode: if `features/<feature-name>/vision.md` exists, run in vision-driven mode — read vision + optional research/exploration/architecture, populate the Forcing Questions section first (6 mandatory questions, mark UNKNOWN if unanswerable), then synthesize a broad PRD that leaves reasoning room for downstream agents (no granular implementation specs). Otherwise run in legacy interactive mode and output to specs/prd/PRD.md. The user reviews the PRD as the real gate before proceeding.
