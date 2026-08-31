---
name: architecture-v6-2-native-primitives
description: LogicLoom v6.2 — dev-loop cut, governance floor hardened (RFC#45427), orchestration re-based on native /workflow,/loop,/goal+Task, SDD decoupled from agnostic core
metadata:
  node_type: memory
  type: project
  originSessionId: 2604835d-e3d8-4e1f-a18e-127b13f2e9a5
---

On 2026-06-14 (branch `loom-migration`, PR #56) LogicLoom was sharpened into a
**constitutional-governance-focused, framework-agnostic DEVELOPMENT harness that
ENHANCES the flagship model by riding ON Claude Code's native orchestration** —
not a custom orchestration engine. Driver: the user now does much of their work
via native `/workflow`, `/loop`, `/goal`. Supersedes the "dev-loop pack" and the
`tribunal-api.sh` references in [[architecture-v6-1-opus48-rebase]].

**Why (thesis):** a harness should add what does NOT decay with model capability —
governance, safety, observability, cost discipline, file-ownership — and should
NOT reimplement what the model+CLI already do natively (spawning, looping,
synthesis). Cross-checked against external harnesses: OpenClaw (disable-able
guardrails → validates "governance must be an enforced FLOOR") and Hermes/Nous
(true hook-enforcement peer; ahead on lineage-memory compression + hardened
sandbox + tool-registration-vs-exposure separation — noted as future direction).

Five committed phases:
1. **Cut dev-loop** (`plugins/loom-dev-loop`, 37 files) — superseded by native
   `/workflow`,`/loop`,`/goal`; runtime self-extension was a governance liability.
   Now TWO workflow packs (swarm + SDD waterfall), 8 plugins. `/research` is
   self-contained (researchers call OpenAI/Gemini via `.env`), NOT dependent on
   the deleted `tribunal-api.sh`.
2. **Harden governance floor** (RFC#45427 PreToolUse bypasses): NEW
   `protect-governance-files.sh` (subagent→deny / main→ask on hooks, settings,
   constitution, governance.conf, loom-governance plugin) wired into settings.json
   Write/Edit + Bash chains; `freeze-write-scope.sh` got realpath canonicalization
   (fixes macOS $TMPDIR `//` prefix bug AND `..`/symlink escape). New
   `.docs/architecture/governance-threat-model.md` documents residual bypass
   surface. **Governance is a deterministic FLOOR, not a sandbox** — Bash-redirect
   freeze escape on arbitrary DAG paths is a known, documented residual (not fixed,
   to avoid breaking the working linear matcher).
3. **Re-base orchestration on native primitives**: `team-orchestration` SKILL
   rewritten to Task tool (fan-out) + `/workflow` (deterministic control) + plan
   mode; deleted dead `launch-swarm.sh`/`budget-manager.sh`; CLAUDE.md gained an
   "Orchestration primitives (ride native; don't reimplement)" section. Later
   `agent-stop-notification.sh` (SubagentStop) was rewritten to a benign
   observability hook — its old tmux/`.claude/multi-agent-swarm` state-file
   coupling was purged. NO tmux/state-file in any plugin script now.
4. **Decouple SDD from the agnostic core**: dropped the stale `"sdd"` keyword from
   the 5 agnostic `loom-*` manifests (→ `logic-loom`), fixed loom-governance
   description/homepage. NOTE: `check_feature_branch`/`get_feature_dir`/
   `get_feature_paths` in `common.sh` are LIVE SDD-pack helpers (now bracketed by
   a scoping comment) — NOT dead; do not remove (would break the SDD pack).
   `sdd-specification` keeps its SDD identity. `sdd-governance` fallback in
   common.sh is intentional backward-compat for mid-migration clones.
5. **Final verify**: full suite green — 410 assertions / 9 contract suites;
   constitutional-check 0/16 failed (VI, X met); sanitization audit 6/6.

Standing constraints reaffirmed this session: NO autonomous git (Principle VI,
git-safety-gate forces ask); subagents never run git (subagent-git-guard) nor
edit the governance surface (protect-governance-files); per-phase commits were the
agreed strategy after an earlier `/review-team` `git clean` wiped untracked work.
Commits end with the Opus 4.8 (1M context) co-author trailer.
