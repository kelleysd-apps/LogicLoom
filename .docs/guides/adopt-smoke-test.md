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
export PLAN=$PWD/.logicloom-plan.json          # per-repo, not a shared /tmp path
npx $LOOM init . --json > "$PLAN"
test -s "$PLAN" || echo "PLAN was not written — stop; every later check reads it"
npx $LOOM init .                      # the human report, for your user
```

`$PLAN` lives beside the repo rather than at `/tmp/plan.json` because a fixed
shared path is one a *previous* run — yours or someone else's — may already have
filled in with a plan for a different repo. Check 5 reads this file; if it reads
a stale one it will reconcile two unrelated runs and print confident nonsense.
The guard in check 5 catches that even if you skip this, but a per-repo path
means there is nothing to catch. Delete it when you are done — it is yours, not
the tool's, and it is not in the receipt.

**Report to your user, in your own words:** the mode it chose and why, the four
bucket counts, anything blocking, and each entry in `decisions[]` — the question,
the options, and what the default would do. Do not paste the raw report at them.

Ask them what they want. Do not choose on their behalf.

## 3. Apply

Assemble the command from their answers. The flags are in `decisions[].flag`.

```bash
export APPLY_LOG=$PWD/.logicloom-apply.log        # per-repo, beside $PLAN — not /tmp
npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer> | tee "$APPLY_LOG"
```

`--only` is mandatory. `hooks` is deliberately not in `--only=all` — if they want
the governance floor, it must be named.

Capture the transcript as it runs — `tee` writes it to `$APPLY_LOG` so it survives
a scrollback loss or a mangled follow-up command. When you report the `WROTE`
count in section 4, quote it from the log (`grep WROTE "$APPLY_LOG"`) rather than
reconstructing it later from the receipt. A reconstructed number can be correct,
but it is weaker evidence than a captured one — label it as reconstructed if
that's what happened to you.

## 4. Verify — this is the actual test

Run each and record the result.

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Their files are untouched | **check 1's block below** | **empty output.** The two merge targets you approved are the only paths permitted to show `M`. Any other `M` line is a failure. `??` lines are expected and fine |
| 2 | The merges did what they said | `git diff .gitignore` and `.claude/settings.json` | a fenced block appended; their existing keys and lines intact and in place |
| 3 | Idempotency | re-run the exact same apply command, **without committing first** | **exit 0**, reports `NO-OP`, writes nothing, and prints a `DISCOUNTED` section naming the blocks its own first run caused |
| 3b | The discount is narrow | **check 3b's block below** | for BOTH merge targets probed — `.gitignore`, and `.claude/settings.json` if `hooks` was applied — first re-run: **exit 1**, `DIRTY-MERGE-TARGET`, a note that the discount was *REFUSED* because the file changed. Nothing written. After restoring each: `NO-OP` once more |
| 4 | The receipt exists and is honest | **check 4's block below** | every path the receipt's `runs[].wrote[]` claims exists on disk as the kind it claims (file / dir / merge-target-still-a-file); nothing claimed is missing; it carries an `uninstall` procedure |
| 4b | The uninstall is safe to run | **check 4b's block below** | **PASS.** The delete list excludes both merge targets (your own files) and the settings sidecar (a later step still reads it), and removes directories child-first and non-recursively. Any `STOP:` here is a data-loss defect — report it verbatim |
| 5 | Plan matched apply | the two commands below | the count matches `WROTE`, and both reconciliation lists are empty |
| 6 | The harness is functional | `bash .logic-loom/scripts/bash/constitutional-check.sh` | runs and reports |

**Check 1's command.** Out of the table on purpose: a markdown table cell has to
escape every `|` as `\|`, and both the shell pipes and the regex alternation here
are pipes. Copied out of a cell, the escapes make the shell treat `\|` as a
literal argument and `grep -E` treat it as a literal `|` character rather than
alternation — so the filter silently excludes nothing and both merge targets get
reported as failures. Run it from here instead:

```bash
git status --porcelain | grep '^ M' | grep -vE '\.gitignore|\.claude/settings\.json'
```

**Four of this run's own outputs never show up in the check above, and that is
expected.** The same run installs `.gitignore` rules that hide them, so no
`git status`-based check can ever see them — not a filtering problem, a design
one. They are still real: they are in the receipt, and check 4 below reconciles
against the receipt, not `git status`, for exactly this reason.

```
.logic-loom/backlog-index.json
plugins/loom-memory/.retention-last-run
plugins/loom-memory/recall/.gitkeep
plugins/loom-memory/working/.gitkeep
```

If check 1 comes back empty, that is a clean pass — do not go looking for these
four to reconcile them here; that is check 4's job.

**Check 3b's commands.** Snapshot the file, add the probe, then restore the
snapshot. You are deliberately modifying a file belonging to your user, so the
undo has to be exact under *any* content — and neither obvious shortcut is:
a blind last-line delete (`sed -i '$d'`) removes whatever happens to be last
rather than what you added, and a content filter (`grep -v '^# probe$'`) removes
*every* matching line, so a `.gitignore` that already contained `# probe` loses
their line too. Both were tested; both corrupt a real file on plausible input.
Restoring a byte copy cannot misfire:

```bash
cp .gitignore .gitignore.preprobe          # snapshot — the only reliable undo
echo '# probe' >> .gitignore
npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>   # expect exit 1, DIRTY-MERGE-TARGET

mv .gitignore.preprobe .gitignore          # restore; byte-identical by construction
npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>   # expect exit 0, NO-OP
```

`.claude/settings.json` is the OTHER merge target, and it only exists to probe if
your user asked for `hooks` in section 3 — if they did not, this half has nothing
to touch; skip it and report it as skipped, the same way check 5 reports `hooks`
as correctly-not-written when it was declined. The probe edit has to keep the
file valid JSON: unlike `.gitignore` this is a real settings file the tool
re-parses, and an invalid-JSON probe would exercise a different failure than the
one this check means to test. Same snapshot-and-restore discipline as above — no
`sed -i`, no content filter; both corrupt a real file on plausible input exactly
as described above.

```bash
if [ -f .claude/settings.json ]; then
  cp .claude/settings.json .claude/settings.json.preprobe   # snapshot
  python3 -c "
import json
p = '.claude/settings.json'
d = json.load(open(p))
d['_logicloomProbe'] = True          # harmless top-level key; keeps the file valid JSON
json.dump(d, open(p, 'w'), indent=2)
"
  npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>   # expect exit 1, DIRTY-MERGE-TARGET

  mv .claude/settings.json.preprobe .claude/settings.json   # restore; byte-identical by construction
  npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>   # expect exit 0, NO-OP
else
  echo "hooks was not applied — .claude/settings.json is not a merge target this run; skipping, reported as skipped"
fi
```

If a second apply does not report `NO-OP` for either file, your restore did not
land — say so and stop, rather than editing the file further to make it pass.

**Check 4's command.** `cat .logicloom-adopt-receipt.json` alone cannot fail — it
only proves the file parses. The block below is the real check: it reconciles
the receipt against the filesystem, asserting every `runs[].wrote[]` entry it
claims actually exists, as the kind it claims. `python3`, not `jq` — same reason
as check 5. It fails closed with a `STOP:` line, same style as check 5's guard,
rather than printing misleading counts against a receipt it could not read.

```bash
python3 - <<'PY'
import json, os, sys

REC = '.logicloom-adopt-receipt.json'
try:
    rec = json.load(open(REC))
except Exception as e:
    sys.exit('STOP: cannot read %s (%s). Was step 3 run in this directory?' % (REC, e))

missing_files, missing_dirs, missing_merges = [], [], []
n_file = n_dir = n_merge = 0

for run in rec.get('runs', []):
    for w in run.get('wrote', []):
        kind = w.get('kind')
        p = w['path']
        if kind == 'file':
            n_file += 1
            if not os.path.isfile(p):
                missing_files.append(p)
        elif kind == 'dir':
            n_dir += 1
            if not os.path.isdir(p.rstrip('/')):
                missing_dirs.append(p)
        elif kind == 'merge':
            # A merge target is the ADOPTER'S OWN pre-existing file — the tool
            # appended to it, it did not create it. The claim here is "still
            # there, still a file", not "this tool created it".
            n_merge += 1
            if not os.path.isfile(p):
                missing_merges.append(p)
        else:
            sys.exit("STOP: unrecognized wrote[].kind %r for %r — the receipt "
                      "schema changed; do not guess, report it." % (kind, p))

print('receipt runs:', len(rec.get('runs', [])))
print('claimed files:  %d (missing: %s)' % (n_file, missing_files or 'none'))
print('claimed dirs:   %d (missing: %s)' % (n_dir, missing_dirs or 'none'))
print('claimed merges: %d (missing: %s)' % (n_merge, missing_merges or 'none'))

if missing_files or missing_dirs or missing_merges:
    sys.exit('STOP: the receipt claims paths that are not on disk — this is a '
              'real finding, report it with the lists above rather than re-running.')

print('PASS: every path the receipt claims (file, dir, and merge target) exists on disk.')
PY
```

**Check 4b — is the uninstall procedure safe to execute?** Existence is not the
only thing the receipt owes you. Its `uninstall` object is the ONLY reversal
path this tool ships, and a real run found it telling the reader to delete files
it must not: the merge targets are the adopter's OWN files, and the settings
sidecar is the record a later step still needs. Both are fixed; this asserts
they stay fixed in YOUR install, because a wrong answer here destroys files the
whole tool exists not to touch.

```bash
python3 - <<'PY'
import json, sys

try:
    rec = json.load(open('.logicloom-adopt-receipt.json'))
except Exception as e:
    sys.exit('STOP: cannot read the receipt (%s). Was step 3 run in this directory?' % e)

u = rec.get('uninstall') or sys.exit('STOP: the receipt carries no uninstall procedure.')
rm = u.get('remove') or sys.exit('STOP: uninstall has no remove list.')
files, dirs = rm.get('files', []), rm.get('dirsIfEmpty', [])
wrote = [w for r in rec['runs'] for w in r.get('wrote', [])]
bad = []

# 1. A merge target is the adopter's own file, appended to behind a fence.
#    Deleting one by path destroys a file that predates this tool.
for m in [w['path'] for w in wrote if w.get('kind') == 'merge']:
    if m in files: bad.append('MERGE TARGET in delete list: ' + m)

# 2. The settings sidecar names which hook groups are ours. A later step reads
#    it; if step 1 deletes it first, that step can only guess -- and guessing
#    wrong strips the adopter's own hooks.
sc = '.claude/.logicloom-adopt-settings.json'
if any(w['path'] == sc for w in wrote) and sc in files:
    bad.append('SIDECAR in delete list (a later step still needs it): ' + sc)

# 3. Directories must be removed non-recursively, children first, so anything
#    you added inside one of ours survives because rmdir refuses a full dir.
for p in files:
    if p.endswith('/'): bad.append('directory in the FILES list: ' + p)
for i, d in enumerate(dirs):
    for later in dirs[i+1:]:
        if later.startswith(d): bad.append('parent before child: %s before %s' % (d, later))
if 'rm -rf' in u['steps'][0]: bad.append('step 1 instructs a recursive delete')

if bad:
    for b in bad: print('  ' + b)
    sys.exit('STOP: the uninstall procedure would destroy files it must not. '
             'This is the highest-value finding available -- report it verbatim.')
print('PASS: uninstall keeps %d files + %d dirs, excludes every merge target and '
      'the sidecar, and removes directories child-first, non-recursively.'
      % (len(files), len(dirs)))
PY
```

**Check 5's commands.** `runs[].wrote[].path` lives in the receipt the apply
wrote, `.logicloom-adopt-receipt.json`. `python3` rather than `jq`, because
`jq` is not guaranteed present.

**Both blocks start by asserting the plan is for THIS repo.** A plan from
another repository reconciles against this receipt perfectly happily — no
exception, no warning, just a long list of confident wrong paths. That is the
worst failure available here, because it looks exactly like a real finding. If
you see a `STOP:` line, the numbers below it were never printed: re-run step 2
and start check 5 again. Do not edit the guard out to get past it.

```bash
python3 - <<'PY'
import json, os, sys
# The plan says which repo it was made for. Assert it is THIS one before
# trusting a single number out of it: a plan for another repo reconciles
# against this receipt without erroring and prints authoritative garbage.
# realpath both sides — on macOS /tmp is a symlink to /private/tmp, and the
# tool records the resolved path.
if not os.environ.get('PLAN'):
    sys.exit('STOP: $PLAN is not set. Re-run step 2.')
try:
    plan = json.load(open(os.environ['PLAN']))
except Exception as e:
    sys.exit('STOP: cannot read $PLAN (%s). Re-run step 2.' % e)
root = plan.get('target', {}).get('root')
if not root or os.path.realpath(root) != os.path.realpath(os.getcwd()):
    sys.exit('STOP: plan targets %r, cwd is %r. Re-run step 2 before check 5.'
             % (root, os.getcwd()))
print('plan target ok:', root)
print('plan wouldWrite:', plan['counts']['wouldWrite']['total'])
PY

python3 - <<'PY'
import json, os, sys
if not os.environ.get('PLAN'):
    sys.exit('STOP: $PLAN is not set. Re-run step 2.')
try:
    plan = json.load(open(os.environ['PLAN']))
except Exception as e:
    sys.exit('STOP: cannot read $PLAN (%s). Re-run step 2.' % e)
root = plan.get('target', {}).get('root')
if not root or os.path.realpath(root) != os.path.realpath(os.getcwd()):
    sys.exit('STOP: plan targets %r, cwd is %r. Re-run step 2 before check 5.'
             % (root, os.getcwd()))
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

**Both lists should print `none` — but only if your user asked for `hooks`.**
That is their decision from section 3, not a step you can order around: `hooks`
is deliberately not in `--only=all`, so if they declined it, nothing is written
for it and `promised but NOT written` correctly lists its two files
(`.claude/settings.json` and `.claude/.logicloom-adopt-settings.json`). That is a
pass, not a finding — say which they chose when you report it. If they did ask
for `hooks`, run this after that apply, and both lists should be empty. Anything else is a finding: report
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

Four conditions, and skipping any one of them produces another inconclusive
result:

1. **The session must be launched AFTER the install.** Not a subagent of an
   existing session, not a `/clear`, not a resumed session. Quit Claude Code
   entirely and start it fresh, with `cwd` set to the adopted repository. Rules
   files are read at launch; a session that started earlier never saw them.
2. **The probe must be unanswerable from general knowledge.** These facts exist
   only in the installed files, so a correct answer cannot come from training.
3. **This brief must not be inside the test project.** It states the correct
   answer below, and anything under `.docs/` in the adopted repo is inside the
   scope the governance preflight hook searches and injects on every prompt. A
   copy of this file sitting in the test project can hand the fresh session the
   answer key, and you would read that as "rules loaded" when nothing loaded at
   all — a false PASS on the one question this probe exists to settle. The
   payload no longer ships it (`exclude: .docs/guides/adopt-smoke-test.md`, and
   a contract test pins that), but if you SAVED a copy into the test project
   yourself, move it out first. Confirm before you launch the fresh session:

   ```bash
   grep -rl 'gh.secret.write' .docs 2>/dev/null || echo "clean — no answer key in preflight scope"
   ```

4. **The model must not search the filesystem for it.** Say so in the prompt —
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
4. **Confirmation that you handed section 5 off and did not attempt it.** State
   that you stopped at the STOP, and paste the hand-off block you gave your
   user. There is no `.claude/rules/` result for you to report — that probe
   belongs to the fresh session in 5a, and a result invented here is worse
   than none, because it is the one claim nobody would think to re-check.
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
