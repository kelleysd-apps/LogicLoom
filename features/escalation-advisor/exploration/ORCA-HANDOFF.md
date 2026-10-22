# Handoff — continue in Orca (written 2026-10-05)

Branch: `feature/v7-update-migrations` (pushed). Nothing merged, no PR, no release.

## What to test in Orca
Claude Code as coordinator, Codex sessions as workers, each in its own
Orca-managed worktree. Questions to answer:
1. Does a Codex worker build well when it keeps its full loop (edit, run tests,
   retry) with no 30-minute cut-off? Re-run the real package: brief in
   `exploration/bakeoff/BRIEF.md`, base commit `991f306`. Compare against
   `bakeoff/sonnet-plan-classify.patch` using each builder's tests on the other.
2. A solvable mechanical task for Codex vs Sonnet (the first attempt was
   unsatisfiable — see `bakeoff/README.md`, Test 2).
3. Do LogicLoom's hooks fire for a Claude session inside Orca (expected yes)
   and what governs a Codex session there (only Codex's own hooks; no adapter
   exists yet — feasibility notes below).

## Where things are
- Results so far: `exploration/bakeoff/README.md`
- Mods proof (Codex drives a Claude Code worker; hooks see writes): `exploration/mods-proof/`
- Escalation design + addenda (mods, Orca): `exploration/design.md`
- Paused update-loom build (4 of 10 Phase-0 packages; known red in
  `test_shipped_path_references.sh`): `features/update-loom/exploration/design.md`, bottom

## Facts to carry
- Codex CLI: `codex exec -s workspace-write|read-only --skip-git-repo-check -C <dir> -c model_reasoning_effort=<level> "<prompt>" < /dev/null`
- Codex hooks: `.codex/hooks.json` in the repo; `PreToolUse` can deny shell and
  `apply_patch`; edits arrive as patch text (no file_path); hooks do NOT run
  until the user trusts them, and that failure is silent.
- LogicLoom's guard denies subagents all mutating git — the coordinator (main
  session) must create worktrees/baselines itself.
- Open maintainer decisions: worker/reviewer roles (recommendation: Sonnet
  builds, Codex reviews once per phase); which rule gives for the failing
  path-reference check; the held escalation-design decisions.
