# Optional: run `/distill` on a schedule

**The harness does not install this. You do.**

Scheduled tasks live in `~/.claude/scheduled-tasks/` — your tree, outside every
repo, one per machine. LogicLoom governs this repository only and never writes
to your user tree, so the most it can do is hand you the prompt. Installing it is
your act, and you can uninstall it the same way.

This is the unenforceable half of the routine, and it is worth saying plainly:
**nothing in this repo can verify the schedule exists.** A scheduled task also
runs only while the app is open, so even installed it is not a guarantee. The
age of the newest `.brain/DISTILL-LOG.md` entry is the only evidence either way,
and the preflight advisory reports it honestly. Pretending otherwise would be a
"looks enforced, isn't" mechanism, which is worse than none.

You lose nothing by skipping this. `/distill` by hand is the supported path;
the load advisory mentions the command when captures pile up.

---

## Install it

Run `/schedule` in Claude Code and give it the prompt below, or paste the same
prompt into your own cron/launchd wrapper. Replace `<ABSOLUTE-REPO-PATH>` with
this repository's absolute path.

**Suggested cadence:** weekly. Daily is what the source system used and it was
zero-op on eight of its last ten runs — a cadence that logs nothing but "nothing
to do" trains you to stop reading the log.

```
Open the repository at <ABSOLUTE-REPO-PATH> and run /distill.

Do not run git in any form — not add, not commit, not push. /distill leaves its
writes in the working tree; a human commits them through the normal approval
path.

Report back in three lines:
  1. how many captures were scanned and how many were unprocessed
  2. what was promoted, extended, discarded, or flagged as a contradiction
  3. the exit status of: bash .logic-loom/scripts/bash/check-brain-record.sh

If /distill reports a zero-op run, that is a healthy result. Say so and stop.
Do not invent work to do.
```

---

## Uninstall it

Delete the task through `/schedule`, or remove its directory from
`~/.claude/scheduled-tasks/`. Nothing in the repo depends on it. The gate stays
green, the advisory keeps working, and `/distill` still runs by hand.
