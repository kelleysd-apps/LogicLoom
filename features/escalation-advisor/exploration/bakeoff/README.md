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
