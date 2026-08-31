---
name: architecture-v6-1-opus48-rebase
description: LogicLoom v6.1 re-base on Opus 4.8 — governance core + interchangeable workflow packs; hook-enforced governance; domain registry; sdd-→loom- rename
metadata: 
  node_type: memory
  type: project
  originSessionId: 2604835d-e3d8-4e1f-a18e-127b13f2e9a5
---

On 2026-05-28 LogicLoom was re-based on Opus 4.8 and made workflow-agnostic
(branch `loom-migration`, framework v6.1.0, constitution v3.1.0). Key shape:

- **Governance is the durable core; workflows are interchangeable packs** (swarm,
  SDD waterfall, dev-loop) — no "primary"/"legacy" path. Reframed in CLAUDE.md,
  AGENTS.md, `.docs/architecture/loom-architecture.md`, `features/README.md`.
- **Governance enforcement is hook-side, not model-recited.** The mandatory
  per-message 4-step FR-707 ceremony was removed. `git-safety-gate.sh` now emits
  `permissionDecision: ask` on git mutations (real Principle VI); wired in
  `.claude/settings.json` PreToolUse·Bash alongside `guard-dangerous-commands.sh`.
  New `LOOM_GOVERNANCE_MODE` (`.logic-loom/config/governance.conf`): `lean`
  default (flagship), `strict` re-injects recitation for weaker models.
- **Domains collapsed**: the 7 `sdd-domain-*` plugins were deleted; their briefs
  live in `plugins/loom-governance/domain-briefs/<domain>.md`, looked up via
  `get_domain_brief()` in `common.sh`. `domains.conf` is now `keyword=domain`.
- **Model config-driven**: `.logic-loom/config/models.conf` (role→tier, flagship
  Opus 4.8). No pinned version strings; agents use tier keywords. Cross-provider
  models only at the delegated research layer (`tribunal-api.sh` + `.env`) — the
  orchestration runtime is Claude-Code-native (Anthropic-only).
- **Plugin naming**: `sdd-*` → `loom-*` for core/tooling/non-SDD packs;
  **`sdd-specification` keeps its prefix** (it *is* the SDD workflow). 9 plugins.
- **Removed**: RL telemetry (`rl_metrics` fields), FR-707 ceremony,
  `sdd-marketplace` MCP, migration scaffolding. (DS-STAR was RETAINED at v6.1 but
  was **fully REMOVED on 2026-06-15** — orphaned/experimental, redundant with
  native `/goal`,`/workflow`,`/loop`; see [[architecture-dev-main-template-split]].
  Do NOT treat src/sdd, refinement.conf, pyproject, or the DS-STAR tests as live.)

RL scope (intentional, 2026-05-28 user decision): RL was removed framework-wide
EXCEPT inside `loom-dev-loop`, which keeps its RL process (self-extension runtime
`rl_metrics` generation + tribunal) **by design, scoped to that workflow only**.
Do NOT "clean it up" as a residual. Committed manifests/skills elsewhere are
rl_metrics-free. Several dev-loop
contract suites fail under the local bash 3.2 (arithmetic/jq) — **pre-existing**,
not from this work (libs verified byte-identical to HEAD). Non-dev-loop contract
suites: 354 assertions green. See [[migration_decision]].
