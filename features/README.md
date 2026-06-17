# `features/` — Vision / Swarm workflow pack

This directory holds **per-feature working folders** for the vision/swarm
workflow pack: vision → exploration/research → PRD → plan → swarm implement →
review → retro.

LogicLoom is a durable **governance core** (constitution, hooks, memory, plugin
chassis) with **interchangeable workflow packs** layered on top. The
vision/swarm pack documented here is one peer; the SDD-waterfall pack
(`specs/###-feature/`, see `.logic-loom/templates/spec-template.md`) is its
equal — neither is privileged. Each subdirectory under
`features/` is one feature, owned end-to-end through this pack's loop. Pick the
pack that matches the problem shape.

---

## Philosophy

Per Anthropic's [harness-design article](https://www.anthropic.com/engineering):
broad specs leave room for the agent to reason; narrow specs cascade upstream
errors. This pack's layout enforces this by separating concerns across files:

- `vision.md` declares **what we want to achieve** — deliberately broad.
- `exploration/` and `research/` resolve unknowns **before** committing to a PRD.
- `prd.md` is a **broad** product brief, not a tight implementation spec.
- `plan.md` introduces structure (sprints, file-ownership DAG) only once enough
  is known to commit safely.
- `sprints/` capture the actual work, scoped per wave to prevent worker collision.
- `retro.md` closes the loop with explicit learnings.

If the planner tried to specify granular technical details upfront and got
something wrong, the errors in the spec would cascade. This pack's layout
makes that mistake hard to commit by accident.

---

## Per-feature layout

```
features/<feature-name>/
├── vision.md          # north star — WHAT we want to achieve
├── exploration/       # /swarm explore outputs (read-only investigations)
├── research/          # /research tribunal outputs (multi-LLM cross-validation)
├── prd.md             # broad PRD — HOW (at the product level) to achieve it
├── plan.md            # sprint/wave-structured plan with file-ownership DAG
├── plan-review.md     # /plan-review verdict — CEO + Eng reviewers
├── sprints/           # per-sprint /swarm implement artifacts
│   └── 01-foundations/
│       └── ...        # per-sprint outputs (workers, evaluator, integration notes)
└── retro.md           # /retro learnings — what worked, what to change
```

### Artifact purposes

| File / Dir | Purpose | Created by |
|------------|---------|------------|
| `vision.md` | One-sentence north star + persona + success shape + non-goals | Human (template at `.logic-loom/templates/vision-template.md`) |
| `exploration/` | Read-only investigations into the existing codebase / surfaces | `/swarm explore <topic>` |
| `research/` | External cross-validated research (libraries, prior art, tradeoffs) | `/research <question>` |
| `prd.md` | Broad PRD — product context, deliverables, design language, forcing-question answers | `/create-prd <feature-name>` |
| `plan.md` | Sprint/wave-structured plan with file-ownership boundaries per worker | Human in plan mode, or planning skill |
| `plan-review.md` | CEO + Eng review verdict on the plan (gates implementation) | `/plan-review` |
| `sprints/NN-name/` | Per-sprint worker outputs, evaluator findings, integration notes | `/swarm implement [sprint-name]` |
| `retro.md` | Post-feature learnings: what worked, what to change next time | `/retro` |

---

## The vision / swarm pack loop

```
EnterWorktree
  → /swarm explore  (optional — investigate existing surfaces)
  → /research       (optional — resolve external unknowns)
  → vision.md       (lock the north star)
  → /swarm explore + /research  (fill remaining gaps surfaced by vision)
  → /create-prd     (broad PRD with forcing-questions gate)
  → plan mode       (sprint-structured plan with file-ownership DAG)
  → /plan-review    (CEO + Eng verdict — gates implementation)
  → /swarm implement  (per-sprint, scope-bounded workers)
  → test / fix      (direct debug loop on failures)
  → /review-team    (security + quality + performance + evaluator)
  → /git-push       (commit + PR with explicit approval)
  → /code-review    (PR-level review)
  → /retro          (capture learnings)
ExitWorktree
```

Steps marked optional may be skipped when the feature is well-understood, but
within this pack `vision.md` and `plan-review.md` are not optional — they are
the **pack-internal gates** that prevent broad-spec cascade and worker-collision
respectively. (These gates are specific to the vision/swarm pack; other packs
have their own controls — e.g. the SDD-waterfall pack gates on its spec and
`/finalize`.)

---

## Conventions

- **Folder name**: kebab-case, descriptive, no numeric prefix
  (e.g. `features/auth-cookie-rotation/`, not `features/001-auth/`).
  Numeric ordering belongs in `sprints/`, not at the feature level.
- **Sprint naming**: `NN-name/` where `NN` is zero-padded (`01-foundations`,
  `02-api-surface`, etc.). Names match the plan.md sprint declarations.
- **File ownership**: every sprint declares which files each worker may
  touch. The `freeze-write-scope.sh` hook rejects writes outside declared scope.
- **No code in vision/PRD**: implementation details live in `plan.md` and
  sprint outputs. Vision and PRD declare intent and boundaries only.

---

## Relationship to `specs/`

`features/` and `specs/` are the workspaces for two peer workflow packs over the
same governance core:

| Aspect | `features/` (vision / swarm pack) | `specs/` (SDD-waterfall pack) |
|--------|-----------------------------------|-------------------------------|
| Entry point | `vision.md` (broad north star) | `spec.md` (functional requirements) |
| Workflow | Iterative explore → PRD → plan → swarm | Linear spec → plan → tasks → implement |
| Worker model | Sprint-bounded swarm with file-ownership | Sequential task execution |
| When to use | Exploratory problems, behavioral quality bar | Contract-first features with stable requirements |

Both packs are first-class. Pick the one that matches the problem shape.

---

## Templates

- Vision: `.logic-loom/templates/vision-template.md`
- PRD: `.logic-loom/templates/prd-template.md` (retargeted in Stage 7)
- Plan / sprints / retro: documented in their respective skill SKILL.md files
  (created in Stages 6, 7b, 10, 11b)

---

*This convention is a Stage-5 addition to LogicLoom. No existing functionality
is affected. See `.docs/plans/loom-migration.md` for the full migration plan.*
