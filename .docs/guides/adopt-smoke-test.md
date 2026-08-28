# Adopt e2e smoke test — brief for a coding agent

**Give this file to an agent working in the TEST PROJECT, not in LogicLoom.**
Paste the whole thing, or point the agent at this path in a LogicLoom checkout.

This is the first end-to-end exercise of `npx logicloom init` against a real
repository. Everything before it was fixtures. The point is to find what
fixtures could not.

---

## Before you start

**The test project must be on a scratch branch with a clean tree.** The tool
refuses to touch a dirty tree, and that refusal is deliberate — but you want to
get past it to test the interesting parts. Confirm with `git status` and stop if
it is not clean.

**Do not run this against a repository whose loss would matter.** Nothing here
deletes, but this is the first real run and you are the test.

`LOOM=/Users/bkelley/kelleysd-apps/LogicLoom/packaging/adopt` for the commands
below. The package is unpublished, so `npx logicloom` will not resolve — the
local path form is the working one.

---

## 1. The agent path

```
npx $LOOM init --agent-guide
```

Read it. It is the procedure. If anything below contradicts it, the guide wins
and that contradiction is itself a finding worth reporting.

## 2. Plan

```
cd /path/to/test-project
npx $LOOM init . --json > /tmp/plan.json
npx $LOOM init .                      # the human report, for your user
```

**Report to your user, in your own words:** the mode it chose and why, the four
bucket counts, anything blocking, and each entry in `decisions[]` — the question,
the options, and what the default would do. Do not paste the raw report at them.

Ask them what they want. Do not choose on their behalf.

## 3. Apply

Assemble the command from their answers. The flags are in `decisions[].flag`.

```
npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>
```

`--only` is mandatory. `hooks` is deliberately not in `--only=all` — if they want
the governance floor, it must be named.

## 4. Verify — this is the actual test

Run each and record the result.

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Their files are untouched | `git status --porcelain` | only additions; nothing of theirs modified except the merge targets they approved |
| 2 | The merges did what they said | `git diff .gitignore` and `.claude/settings.json` | a fenced block appended; their existing keys and lines intact and in place |
| 3 | Idempotency | re-run the same apply | reports `NO-OP`, writes nothing |
| 4 | The receipt exists and is honest | `cat .logicloom-adopt-receipt.json` | lists what landed, and carries an `uninstall` procedure |
| 5 | Plan matched apply | compare the plan's counts to what was written | no path written that the plan did not promise, and none promised that was not written |
| 6 | The harness is functional | `bash .logic-loom/scripts/bash/constitutional-check.sh` | runs and reports |

## 5. The unverified assumption — the most valuable thing you can test

`.claude/rules/` is believed to load at launch at `CLAUDE.md` priority. This has
been confirmed from vendor documentation and the CLI's own settings text, but
**never observed end to end in a project scope.** If it does not load, `rules`
mode silently installs three files nobody reads, and `import` mode should be the
default instead.

**Test it.** Open a fresh Claude Code session in the adopted repository and ask
something only the installed rules would answer — for example, what the five
operations on the gate-policy floor are, or what `subagent-git-guard.sh`
enforces. Do not ask a question the model could answer from general knowledge.

Report whether it knew. That single answer decides a default.

---

## What to report back

1. Every check above, pass or fail, with the actual output for anything that failed.
2. **Anything the plan said that turned out not to be true.** This is the highest-value finding available and the whole reason for a real-repo test.
3. Whether the decisions list was enough to guide your user without you inferring anything.
4. The `.claude/rules/` result from section 5.
5. Anything you wanted to do that the tool refused, and whether the refusal was right.

## Refusals — do not work around these

The tool never deletes, never truncates, never moves source, never runs a
mutating git command, and never stashes. There is no `--force`.

**If it blocks: relay the remedy to your user and stop.** Do not clear the way
yourself, do not retry with different flags to get past it, and do not commit or
stash on their behalf to make a precondition pass. A block is the tool working.

If you believe a refusal is wrong, that is a finding to report, not an obstacle
to route around.
