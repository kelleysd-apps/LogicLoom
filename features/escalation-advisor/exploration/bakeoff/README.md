# Worker bake-off — 2026-10-04

Question: can a cheaper non-Claude model be the main worker and build as well?
Two tests, same brief and base commit (991f306) for both builders.

## Test 1 — real package (`p0-engine-plan-classify`, see BRIEF.md)

| | Sonnet 5.5 worker | Codex (GPT, high effort, scratch copy) |
|---|---|---|
| Own tests | 1387 pass | 1232 pass |
| Run against the other's tests | 0 real defects (4 wording) | 12 real defects (17 style) |
| Claude (Fable) blind review, high/med/low | 0 / 0 / 4 | 2 / 6 / 3 |
| Codex blind review, correctness /10 | 6.0 | 4.5 |
| Tests written | 234 | 79 |
| Time | ~55 min | ~34 min, cut off at the limit |

Both blind reviewers chose the Sonnet build as the base. Codex's build deletes
the customer backup directory on every plan (`rm -rf "$state"`), confirmed.
The Codex reviewer also found real medium defects in the Sonnet build that the
Claude reviewer did not report (local mode change dropped on take; failed
reads and merge errors treated as empty/conflict; a lock timing gap in both).
Neither build is applied to the branch. Patches and each builder's tests are here.

## Test 2 — task that turned out to be unsatisfiable under its rules

Fix `test_shipped_path_references.sh` (9/10) without editing the test or the
payload manifest. The flagged lines are functional `adopt-exclude` rows that a
second test requires to equal the manifest. Both Sonnet and Codex tried the
wildcard rewrite, saw it break the second test, reverted, changed nothing, and
reported the conflict with the same options. Neither cheated. Codex: 364 s,
~78k tokens. Sonnet: ~3 min.

## Reading

- On spec-heavy work the Sonnet build was clearly better; the Codex first pass
  needed heavy review. One run each — thin evidence.
- Both behaved honestly on an impossible task.
- A different-provider reviewer caught defects the same-lineage reviewer missed.
- Mechanisms proven separately: `../mods-proof/` (a mod can drive a subagent
  from Codex with project hooks seeing the writes); Codex's own hooks can deny
  commands and edits but need per-user trust (silent when missing).

## Test 3 — Codex as a supervised worker in Orca (2026-10-05)

Claude Code session as Orca coordinator (`orchestration run-create`,
`worker-start --agent codex --worktree new-child --base-branch 991f306`); Codex
built the same package in its own worktree and reported `worker_done` through
the Orca mailbox. First start blocked on Codex's directory-trust prompt;
answered with maintainer approval, then retried the same task on the same terminal.

| | Sonnet | Codex, test 1 (high effort, cut off at 34 min) | Codex in Orca (default effort, 9 min 17 s) |
|---|---|---|---|
| Own tests | 1387 pass | 1232 pass | 1176 pass |
| Failures on Sonnet's tests | — | 30 | 50 |
| Sonnet engine on its tests | — | 5 (wording) | 5 (one helper interface) |
| Engine lines added | 534 | 393 | 227 |
| Test file lines | 574 | 234 | 57 |

- Backup-deletion defect present again (`rm -rf "$state"`); the tracked-ignored
  defect from test 1 is gone.
- Of the 50 failures roughly 20 look like real spec gaps (adopted-install rows,
  settings posture, both-deleted, same-edit, mode keep, adapt.tsv shas); the
  rest are wording/style. Not formally reviewed.
- Leak audit of the full Codex session log: no read of the main checkout's
  answer files. Scope held to the three owned files; no commit.
- Confounds: Orca launched Codex at DEFAULT effort (test 1 used high), and in
  "YOLO mode" (no approvals, no sandbox) per the user's Orca default.
- Not tested: the coordinator sending review findings back for the worker to
  fix (the feedback loop); a high-effort rerun.

Reading: the coordinator/worker plumbing works in Orca. A Codex worker alone,
on a spec-heavy package, produced a build that passes its own thin tests and
misses much of the spec.
