---
name: phase4_orchestration_portability_deepdive
description: "2026-06-24 deep-dive verdict on Phase 4 (make orchestration model/provider-agnostic). HELD for a future feature run. DON'T build the runtime rewrite; scope = L0 docs + freeze adapter (~2.5d, zero runner)."
metadata: 
  node_type: memory
  type: project
  originSessionId: be0c4ebf-f1e9-4cfb-9f5b-cb9602622023
---

Phase 4 = make LogicLoom ORCHESTRATION model/provider-agnostic (Phases 1-3 already
made POLICY + verification portable — see [[architecture_v7_provider_portable_pivot]]).
A 9-agent deep-dive (2026-06-24, workflow wz4pja6o3) reached a decisive verdict; the
user chose to **HOLD it for a SEPARATE feature run after current work is promoted.**

**VERDICT: do NOT build the full orchestration-runtime rewrite** (the "custom runner"
the framework deliberately refuses). All 3 adversarial lenses converged. Decisive
fact: **context-isolation (Principle X — the whole reason /swarm exists) is
non-portable BY CONSTRUCTION** — `agent_id` is a Claude-internal signal no host
emits; off-host "workers" share the orchestrator's single context window. So per-host
parallel adapters chase a guarantee that cannot cross the host boundary. Off-host,
"swarm" = a sequential single-context prompt loop (no parallelism, no isolation). The
"agnostic to model+provider" goal is already ~80% met by Phases 1-3.

**RECOMMENDED SCOPE for the future feature run (~2.5 days, low risk, ZERO runner):**
- **L0 (docs/identity honesty, ~0.5d):** make `models.conf` tier-semantics NORMATIVE
  (not just the neutral-reading comment); reframe CLAUDE.md / VISION.md /
  governance-threat-model.md identity prose from absolute "Claude-Code-native, no
  runner" → "portable orchestration SPEC + reference Claude Code adapter; isolation +
  per-worker enforcement do NOT travel off-host — PERMANENTLY (by construction), not
  a temp gap"; document the **AgentSpec** field set (id/role/prompt/brief/model/tools/
  owns/isolation + honesty fields isolation_delivered/tools_enforced/ownership_checked)
  in loom-architecture.md as the neutral CONTRACT (documentation, NOT code); caveat
  that off-host `/swarm` is "a governed sequential task-walk," not parallel multi-agent.
- **Freeze adapter (L2 slice, ~2d):** new `.logic-loom/adapters/freeze-scope-gate.sh`
  + `githooks/pre-commit` diffing git-staged paths vs the `.loom-active-feature`
  marker via the ALREADY-SHIPPED `loom_verdict_freeze_scope` in
  `.logic-loom/lib/governance-verdicts.sh`; fail-closed; wire into the adapters
  `install.sh`; add `tests/contract/test_freeze_adapter.sh` golden fixtures mirroring
  `test_git_adapter.sh`. Flips freeze-scope followed-only → **ENFORCED AT THE COMMIT
  BOUNDARY** off-host — STRONGER than the on-host PreToolUse hook (catches cat>/tee/
  heredoc Bash-redirects the Write/Edit hook misses, threat-model residual #2). Honest
  wording REQUIRED: "enforced at commit boundary; followed-only within an uncommitted
  swarm" (a serial worker can overwrite before commit; gate rejects the commit but
  cannot undo the write).

**DEFER L1** (spawn-worker seam — renames ~8 working prose "Task tool" sites, changes
nothing enforced; document AgentSpec instead). **REJECT L3** (per-host parallel
adapters + identity-runner rewrite). **DON'T build** `model-resolve.sh` Part B (no
consumer; gate behind ">=1 real off-host spawn adapter") or `dag-order.sh` (the
plan.md DAG walk-prose is already followable).

**PREREQUISITE / independent finding (resolve with or before this feature run):**
`.logic-loom/lib/parallel.sh` defines `PARALLEL_STATE_DIR`
(`.logic-loom/logs/parallel-execution`) — a shared swarm-state file the v6.2 "no
shared swarm-state" invariant supposedly BANNED. Unreconciled on disk: either dead
code (delete) or the "no runner / no shared state" identity claim is already FALSE.
Also: a dangling swarm-coordinator ref in research.md (trivial).

WORDING CAUTIONS for whoever builds it: never claim "file-ownership ENFORCED off-host"
unqualified (commit-boundary only); off-host `/swarm` is neither parallel nor
isolated — caveat the verb; frame the Claude-Code reference-host boundary as
PERMANENT, not "coming soon."
