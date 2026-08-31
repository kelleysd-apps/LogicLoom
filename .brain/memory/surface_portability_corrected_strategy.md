---
name: surface_portability_corrected_strategy
description: "2026-06-24 CORRECTS the Phase 4 framing. User's real axis = Claude Code across SURFACES (terminal/desktop/cloud/VM/cowork/monorepo), NOT cross-host (Codex/Cursor). No regression verified. Re-scopes Phase 4 to surface-consistency + a governance-health-check command."
metadata: 
  node_type: memory
  type: project
  originSessionId: be0c4ebf-f1e9-4cfb-9f5b-cb9602622023
---

A 4-agent review (2026-06-24, workflow wwad0knfy) corrected the Phase 4 framing
(see [[phase4_orchestration_portability_deepdive]]). The user heavily uses Claude
Code TERMINAL (primary), is adding DESKTOP, will test CLOUD + Azure/GCP/AWS VMs +
Cowork + monorepos, and wants "same governance result everywhere, Claude Code
primary, NO regression."

**TWO DISTINCT AXES (never conflate):**
- **Axis A — Claude Code SURFACE-portability (the user's PRIORITY):** same engine
  = same hooks. The floor IS the hooks and they travel WITH the engine. NOT a
  runtime-rewrite problem; a governance-WIRING / environment-assumption problem.
- **Axis B — cross-HOST policy-portability (best-effort, already shipped):**
  Codex/Cursor/Aider — policy travels, enforcement followed-only. Stays as
  Phases 1-3 / v6.3.x left it.

**NO REGRESSION — verified live:** verdict-function refactor is conformance-tested
(test_governance_verdicts.sh 36/36); git-safety-gate has an inline fail-SAFE
fallback (still emits `ask` if the lib is absent); token set expanded
(restore/update-ref/… — closes false-ALLOWs, only over-asks→safe direction); the
matrix keeps Claude Code = ENFORCED. The work RAISED the ceiling, did NOT lower
the floor. North star ~80% ALREADY MET for CC surfaces.

**SURFACE CONSISTENCY MAP:**
- **SAME (byte-identical, nothing to port):** terminal CLI, Desktop LOCAL session,
  Claude Code CLI on a remote Azure/GCP/AWS VM via SSH, VS Code extension,
  JetBrains plugin — all the same engine off the same `.claude/settings.json`.
- **GAPS (real):** (1) ~~**CLOUD surfaces do NOT load project hooks — floor
  absent**~~ **← CORRECTED 2026-07-09, see [[unified_architecture_thin_core]].**
  Current (2026) cloud docs mark `.claude/settings.json` hooks, `.mcp.json`, and
  skills/agents/commands as **"Yes — part of the clone"**; SessionStart runs in
  cloud; `$CLAUDE_CODE_REMOTE=true` lets hooks detect it. The floor is entirely
  repo-committed, so it CLONES AND FIRES in cloud. Docs-verified, **live proof
  still pending** (user decision: prove before advertising). The real
  silently-absent surface is **Windows without Git Bash** (hook `command` falls
  through to PowerShell, cannot run `bash x.sh`). (2) **bash 3.2 / minimal VM:** guard-dangerous-commands FAILS
  OPEN below bash 4 (the git gate fails SAFE — asymmetry). (3) **monorepo /
  non-repo-root cwd:** settings load from launch dir only (no parent traversal);
  freeze owns:/realpath assume repo root.
- **EMPIRICAL MUST-CHECK:** does Cowork/Dispatch route to LOCAL (hooks fire) or
  CLOUD (bypassed)? Read the Environment badge (Local vs Remote).

**RE-SCOPED "PHASE 4" (Axis A; zero runner; ~2.5-3.5d):**
- **P0b (HIGHEST LEVERAGE, new):** a **governance health-check** command
  (`/governance-health` or `.logic-loom/scripts/bash/governance-selftest.sh`) —
  on ANY surface, asserts each hook is wired, mutating-git→`ask`, out-of-scope
  freeze→`deny`, BASH_VERSINFO>=4, and whether the surface runs hooks at all.
  Turns silent cloud/bash gaps into a LOUD, user-runnable signal.
- **P1:** split the threat-model "Claude Code = ENFORCED" row PER-SURFACE
  (local=ENFORCED; cloud/headless=NOT-WIRED; bash-3.2=guard-dangerous-fails-open).
- **P2:** DELETE `.logic-loom/lib/parallel.sh` — confirmed dead (no consumer),
  contradicts the "no shared swarm-state / no runner" invariant.
- **L0** retargeted at surfaces. **Freeze commit-boundary adapter STILL STANDS,
  better-justified:** it's the enforcement for cloud/headless CC where PreToolUse
  can't gate (no human approver) — commit-boundary, needs no human.

**The deep-dive's "DON'T build the runner" verdict STILL HOLDS + is STRENGTHENED**
(a runner buys ZERO on Axis A — every local CC surface is already the same engine).

**KEY DESIGN PROBLEM for the user's cloud/CI ambitions:** headless surfaces —
git-safety-gate emits `ask` with no human to answer → either blocks all git
(breaks surface) or auto-allows (silently removes Principle VI). The freeze
commit-boundary adapter mitigates owned-scope; ad-hoc git needs an explicit policy.
**RISK — conflation drift:** never let a CC cloud surface inherit the cross-host
"followed-only" posture when it could be ENFORCED; protect the CC ceiling.
