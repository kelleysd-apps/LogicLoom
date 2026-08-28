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

### Set `$LOOM` first — every command below needs it

**Do this before anything else.** Substitute the path to *your* LogicLoom
checkout; there is only this one place to change.

```bash
export LOOM=/path/to/your/LogicLoom/packaging/adopt
test -f "$LOOM/package.json" && echo "LOOM ok" || echo "LOOM path is wrong — fix it before continuing"
```

The package is unpublished, so `npx logicloom` will not resolve. The local path
form is the working one, and it is what every command here uses.

### Try it in a worktree — the reversible way in

The recommended way to run this, and the way to recommend to anyone trying
LogicLoom for the first time: **adopt into a git worktree on a throwaway
branch.** Look at the result there, and only then decide whether to bring it
into a development or production branch.

```bash
cd /path/to/your-repo
git worktree add -b logicloom-trial ../your-repo-logicloom-trial
cd ../your-repo-logicloom-trial

npx $LOOM init .                                   # plan; writes nothing
npx $LOOM init . --apply --only=all --claude-md=rules
npx $LOOM init . --apply --only=hooks              # governance floor, opt-in
```

Your working checkout is never touched, and undoing the whole trial is two
commands:

```bash
cd /path/to/your-repo
git worktree remove --force ../your-repo-logicloom-trial
git branch -D logicloom-trial
```

(Both sequences were run end to end while writing this guide: the adopt exits 0
inside the worktree, and the removal leaves the original checkout clean.)

Worktrees are a pattern you will meet again — this harness's swarm pack is
worktree-based — and the harness ships a `SessionStart` hook,
`.claude/hooks/worktree-port-namespace.sh`, that gives each worktree its own
dev-server and database port range so sibling worktrees do not collide. It
no-ops silently outside a worktree.

### What you are agreeing to

Plainly, so nobody has to guess:

- **What it does not do.** It never deletes, never truncates, never moves your
  source, never overwrites a file it did not create, and never runs a mutating
  git command. Without `--apply` it has no write path at all. There is no
  `--force`. Every one of those is enforced in code — `copyFileNew` opens `'wx'`
  so the kernel refuses an existing path — not merely intended.
- **What it does.** With `--apply` it writes the targets you name, merges
  additively into `.gitignore` and (only if you ask) `.claude/settings.json`
  behind marked fences, and records every path it wrote in
  `.logicloom-adopt-receipt.json` so uninstall is a list you run.
- **What you accept.** This is new software and you run it at your own
  discretion. The properties above are design guarantees backed by tests, not a
  warranty that no defect exists; the software is provided as-is. The first
  real-repository run found no data-safety defect — nothing was deleted,
  dropped, overwritten or corrupted — and the two defects it did find were a
  contract and a documentation defect. The worktree above is the cheap way to
  keep that judgement yours.

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
| 1 | Their files are untouched | `git status --porcelain \| grep '^ M' \| grep -vE '\.gitignore\|\.claude/settings\.json'` | **empty output.** Those two are the only paths permitted to show `M` — they are the merge targets you approved. Any other `M` line is a failure. `??` lines are expected and fine |
| 2 | The merges did what they said | `git diff .gitignore` and `.claude/settings.json` | a fenced block appended; their existing keys and lines intact and in place |
| 3 | Idempotency | re-run the exact same apply command, **without committing first** | **exit 0**, reports `NO-OP`, writes nothing, and prints a `DISCOUNTED` section naming the blocks its own first run caused |
| 3b | The discount is narrow | `echo '# probe' >> .gitignore`, re-run the same apply, then `sed -i '' -e '$d' .gitignore` (GNU: `sed -i -e '$d'`) and re-run again | first re-run: **exit 1**, `DIRTY-MERGE-TARGET`, a note that the discount was *REFUSED* because the file changed. Nothing written. After removing the line: `NO-OP` once more |
| 4 | The receipt exists and is honest | `cat .logicloom-adopt-receipt.json` | lists what landed, and carries an `uninstall` procedure |
| 5 | Plan matched apply | the two commands below | the count matches `WROTE`, and both reconciliation lists are empty |
| 6 | The harness is functional | `bash .logic-loom/scripts/bash/constitutional-check.sh` | runs and reports |

**Check 5's commands.** `runs[].wrote[].path` lives in the receipt the apply
wrote, `.logicloom-adopt-receipt.json`. `python3` rather than `jq`, because
`jq` is not guaranteed present:

```bash
python3 -c "import json;p=json.load(open('/tmp/plan.json'));print('plan wouldWrite:',p['counts']['wouldWrite']['total'])"

python3 - <<'PY'
import json
plan = json.load(open('/tmp/plan.json'))
rec  = json.load(open('.logicloom-adopt-receipt.json'))

# The receipt records the writes, so it is never itself in `wrote`. The plan
# says so via countedInWouldWrite; read the flag rather than hardcoding a name.
promised = {u['targetPath'].rstrip('/') for u in plan['buckets']['additive']
            if 'targetPath' in u} \
         | {b['path'].rstrip('/') for b in plan.get('bookkeeping', [])
            if b.get('countedInWouldWrite', True)}
written  = {w['path'].rstrip('/') for r in rec['runs'] for w in r['wrote']}

# A directory unit is one promise that expands to many written paths, so a
# written path counts as promised if it IS one, or sits under one.
def covered(p, promises):
    return p in promises or any(p.startswith(q + '/') for q in promises)

unpromised = sorted(p for p in written if not covered(p, promised))
# The reverse only counts leaves: a promised directory is satisfied by anything
# written beneath it, and `hooks` you did not install writes nothing.
unwritten = sorted(q for q in promised
                   if q not in written
                   and not any(w.startswith(q + '/') for w in written))

print('written but NOT promised:', unpromised or 'none')
print('promised but NOT written:', unwritten or 'none')
PY
```

Run this **after** both apply commands. If you ran only the first,
`promised but NOT written` correctly lists the two `hooks` files
(`.claude/settings.json` and `.claude/.logicloom-adopt-settings.json`) — `hooks`
is deliberately not in `--only=all`, so skipping it writes nothing. Once both
have run, **both lists should print `none`**. Anything else is a finding: report
it with its contents rather than judging it yourself.

Two notes on the table, both of which cost an earlier tester time:

- **Check 3 runs on an uncommitted tree, on purpose.** An apply necessarily
  leaves `.gitignore` modified and `.claude/` untracked — its own output — and
  those are the two conditions a blocking precondition names. The applier
  discounts the blocks its own receipt accounts for, so the re-run is a `NO-OP`.
  Do not commit between check 2 and check 3; committing would test something
  easier than the thing that matters. Check 3b is the other half: a file the
  tool *merged into* is cleared only while its recorded content digest matches,
  so your own edit brings the block back.
- **Do not compare `counts.additive` to `WROTE`.** `additive` counts plan
  *units* — a directory is one unit and hundreds of files — so `62` beside
  `WROTE 407` is two correct numbers that are not comparable.
  `counts.wouldWrite.total` is the one to compare, and it should match exactly.

## 5. STOP — this section is not yours to run

**If you are the agent that performed the install, you cannot do this section,
and attempting it produces a worthless result.**

Rules files are read **at session launch**. Your session started before the
install existed, so whatever context you hold was assembled when
`.claude/rules/logicloom-*.md` was not on disk. A negative answer from you
cannot distinguish "project rules do not load" from "they were not there when
this session started." That is exactly what wasted the first attempt.

You cannot relaunch yourself. A subagent will not do — it inherits from you. A
`/clear` will not do. A resumed session will not do.

**What to do instead:** finish sections 1-4, report those results, and tell your
human this, in your own words:

> The last check needs a session that did not exist when I started. Quit Claude
> Code, relaunch it with the working directory set to the adopted repository,
> and paste the two probes below into that new session. I cannot do it and
> neither can a subagent of mine.

Then hand them the probes verbatim. Do not attempt them. Do not report a section
5 result of your own — reporting an inconclusive one is worse than reporting
none, because it looks like data.

---

## 5a. For the human, and the fresh session they launch

`.claude/rules/` is believed to load at launch at `CLAUDE.md` priority. This has
been confirmed from vendor documentation and the CLI's own settings text, but
**never observed end to end in a project scope.** If it does not load, `rules`
mode silently installs three files nobody reads, and `import` mode should be the
default instead.

**This test has been attempted once and came back inconclusive.** The confound
is worth stating, because it is easy to repeat: the testing session had been
launched *before* the install existed, so whatever context it inherited was
assembled when `.claude/rules/logicloom-*.md` was not on disk. A negative result
from that session could not distinguish "project rules do not load" from "they
were not there at launch." One usable datum survived — a **user-scope** rules
file (`~/.claude/rules/...`) demonstrably does load. Project scope is untested.

### The repro — follow it exactly

Three conditions, and skipping any one of them produces another inconclusive
result:

1. **The session must be launched AFTER the install.** Not a subagent of an
   existing session, not a `/clear`, not a resumed session. Quit Claude Code
   entirely and start it fresh, with `cwd` set to the adopted repository. Rules
   files are read at launch; a session that started earlier never saw them.
2. **The probe must be unanswerable from general knowledge.** These facts exist
   only in the installed files, so a correct answer cannot come from training.
3. **The model must not search the filesystem for it.** Say so in the prompt —
   *"answer from what you already have loaded; do not read or search any files"*
   — and if it reads a file anyway, the run is void. Ask again in a new session.

Probe A:

> Answer from context you already have loaded — do not read or search any files.
> How many operations are on the gate-policy floor, and what are they?

Correct answer, from `.claude/rules/logicloom-governance.md`: **five** —
`git.push`, `git.history-rewrite`, `gh.repo.admin`, `gh.secret.write`, `gh.auth`.

Probe B — **grade this one strictly, on the `gh` clause only:**

> Same rule — no file reads. Besides git, is there any other command-line tool
> `subagent-git-guard.sh` restricts for subagents, and how completely?

Correct answer, from `logicloom-governance.md:35`: **`gh` is denied outright for
subagents** — categorically, not partially, and not with a read-only allowance
the way git has.

The rest of that hook's behaviour — "denies mutating git, permits read-only" —
is **guessable from the filename**, so a model with nothing loaded will produce
it and appear to pass. Do not accept it as evidence. Only the `gh` clause is
genuinely unavailable to a model that has not read the file. If it names git
correctly but cannot name `gh`, score Probe B as **failed**.

**Report which probes it answered, and whether it read anything.** If it knew
without searching, `rules` mode is validated and stays the default. If it did
not, `import` should become the default instead. That single answer decides a
shipped default, which is why an inconclusive result is worth less than no
result — it looks like data.

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

**Check 3b is the one exception, and it is not really one.** There you edit
`.gitignore` *deliberately, to induce a block and confirm it fires*, then undo
your own edit. That is testing the refusal, not routing around it — the file you
touch is one you just changed yourself, for the purpose of the test, and you put
it back. The rule above is about blocks you did not cause: never clear one of
those to make an apply proceed.

If any other instruction in this brief looks like it asks you to work around a
refusal, that is a defect in the brief. Report it rather than resolving it.

If you believe a refusal is wrong, that is a finding to report, not an obstacle
to route around.
