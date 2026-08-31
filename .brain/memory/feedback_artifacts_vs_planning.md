---
name: feedback_artifacts_vs_planning
description: "Standing convention (2026-07-09): artifacts capture who/what/why/where (vision, research, forensics, documentation). Planning — how/when/sequencing — must NEVER be hardwired into an artifact; it belongs to a triggered planning phase or to workflow agents."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d838fa68-7c8c-404d-9432-92c0df7b8891
---

**Artifacts = who / what / why / where. Planning = how / when — and it does not
live in the artifact.**

Artifacts are for **vision, research, forensics, and documentation**. They are
the thing agents (and humans) **plan FROM**. A Statement of Work, phase list,
sequencing, or work order must NOT be baked into one. Planning instead lives in:
- a **triggered planning phase** (plan mode / the plan tool), or
- **left to the agent** inside a `/workflow` to construct as it sees fit.

Artifacts live in the repo-root **`artifacts/`** folder (created 2026-07-09).

**Why:** hardwiring a plan into an artifact **confines the agent**. The user
wants flexibility — the agent decides how and when to execute, based on the
who/what/why/where the artifact establishes. A phased path baked into a vision
doc pre-commits decisions that belong to planning time, when more is known.

**How to apply:**
- When asked to produce an artifact, include: the vision/thesis, the model, the
  verified problems + evidence, locked decisions/constraints, and explicit
  non-goals. **Omit** phase tables, "P0→P5" sequencing, effort estimates, and
  ordering language ("first… then…").
- State the boundary inside the artifact itself so downstream readers/agents know
  the plan is theirs to make.
- If a design doc already carries a phased path (e.g.
  `features/modular-harness/exploration/unified-architecture.md` §7), that path
  is *advisory input to planning*, not a mandate — and should not be copied into
  an artifact.
- Related: [[feedback_improve_harness_not_user_skills]],
  [[unified_architecture_thin_core]].
