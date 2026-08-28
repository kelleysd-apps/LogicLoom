# Installing LogicLoom — instructions for a coding agent

You are installing LogicLoom into a repository on behalf of a user who is
talking to you, not reading this terminal. Your job is to run the plan, put the
decisions in it to your user in your own words, and then run the apply with the
flags their answers imply.

Print this any time with `npx logicloom init --agent-guide`.

## How you were meant to find this

Four places name it, deliberately, because you may arrive at any one of them
first: this repository's `README.md` and `START_HERE.md`, `init --help`, and the
**first three lines of every plan report** — the pointer leads the report rather
than trailing it, so reading from byte zero reaches it before any plan content.
When stdout is not a terminal the same pointer is printed fuller, with the
decisions and `applyReady` summarised inline, because in that case nobody's
terminal is being spent on the extra lines.

**None of that makes discovery guaranteed, and this file will not pretend
otherwise.** An agent that already believes it knows how to install an npm
package can read none of the four and go straight to `npm i`. There is no
mechanism here that compels a read — a CLI cannot make its caller look. What the
design buys is narrower and worth stating exactly: *at every point where an agent
plausibly looks, the correct path is the hardest thing on the page to miss.* If
you are reading this, that worked. If you got here after guessing, it did not,
and the guess is what you should distrust — not this file.

---

## The shape

`logicloom init` is **non-interactive and has no prompt.** It plans by default
and writes nothing. Flags decide; you do the asking.

```
npx logicloom init <dir> --json          # plan.  writes NOTHING, anywhere, ever
npx logicloom init <dir> --apply --only=<targets> [--claude-md=<mode>]
```

`--apply` re-plans against the tree as it is and applies from that. A plan file
is a review artifact, never an instruction set.

## The four steps

**1. Plan.** Run `npx logicloom init <dir> --json` and parse stdout. Check
`schema` is `logicloom/adopt-plan@1` and refuse a schema you do not know.

**2. Read four fields — you do not need the other thirty.**

| Field | What you do with it |
|---|---|
| `applyReady` | `false` → **stop.** Do not apply. Go to *When it blocks*. |
| `mode.mode` | `new-project` (empty directory) or `existing-project`. Tell the user which, and `mode.reason`. |
| `decisions[]` | **The questions to ask.** One entry per choice. See below. |
| `counts` | `additive` is what would be written; `keep-theirs` is what of ours is dropped because they already have it. Worth reporting; never a question. |

**3. Ask.** Walk `decisions[]`. Each entry is one question:

- `question` — the question, in plain language. Rephrase it for your user.
- `applicable` — **`false` means do not ask it.** `notApplicableReason` says
  why; it is a case the tool has already settled (e.g. there is no `CLAUDE.md`
  here, so how to integrate with it is not a question).
- `options[]` — `value`, `summary`, `consequence` (say this one out loud),
  `inDefault`, and for targets `wouldWrite` / `noOp`. An option with
  `noOp: true` has nothing to do here; mention it, do not ask about it.
- `default` — `value` and `why`. Fine to propose; say what it is.
- `flag` / `flagForm` / `env` — **exactly how the answer is set.** Do not infer
  a flag; use this one.
- `required` — `true` means the flag must appear in the apply command. There is
  no "apply everything by omission".

If your user says "just do the sensible thing", use every `default` — that is
what the defaults are for.

**4. Apply.** Build the command from the answers and run it:

```
npx logicloom init <dir> --apply --only=<answers to the "targets" decision> \
                                 [--claude-md=<answer to the "claude-md" decision>]
```

Exit codes: `0` succeeded or was a no-op · `1` blocked, refused, or the reviewed
plan is stale · `2` usage error · `3` the plan could not be produced · `4`
**partial** — some targets landed and some did not, and the report says which.
On `4`, report exactly what the output says landed. Do not re-run to "finish".

Re-running a successful install is a no-op that says so. That is safe.

---

## The refusals — read these before you try to help

This tool **blocks rather than guessing**, and a block is information, not an
obstacle. Working around one is the single most damaging thing you can do here.

- **It never deletes, truncates, moves, or overwrites anything.** If a file
  exists at a target path, theirs is kept and ours is dropped — visibly, in
  `keep-theirs`. That is the design, not a failure.
- **There is no `--force`, and asking for one is refused by name.** No blocking
  precondition is overridable.
- **It never runs mutating git.** No commit, no stash, no clean, no checkout.
  Every `remedy` in the plan is a command *the human runs*, and none of them is
  ever `git stash`.
- **Without `--apply` it has no write path at all** — not to the repo, not to a
  cache, not to a temp file. Planning a repository you do not own is safe.
- **`hooks` is not in `--only=all`.** It has to be typed. It changes what the
  user's own sessions may do in that repository, so it never installs as a side
  effect of a convenience word.

### When it blocks

`applyReady: false`. Every entry in `preconditions.blocking` has a `code`, the
`path` it is actually about, a `detail`, and a `remedy`.

**Relay the remedy to your user and stop.** Do not run it for them, do not
stash, commit, delete, or move their files to clear the way, and do not retry
the apply. Most blocks mean untracked or uncommitted work sits where the install
would write — work that has no other copy. The remedy is theirs to run because
the consequence of getting it wrong is theirs to bear.

Once they say it is cleared, re-run step 1. The plan is cheap and always safe.

---

## What you should tell the user, unprompted

- `notes[]` — the named limits (no test suite is installed; no CI workflow is
  installed; `replace` is empty by design). Short, and they matter.
- `buckets.obsolete` — findings about **their** repo, never actioned by
  anything. Report them; propose nothing.
- `defers[]` — if non-empty, the maintainer has not decided how something
  installs, and every apply is blocked until they do. Not something the user
  can fix.
- Anything under `errors[]`.

## What you must not do

- Do not edit the plan JSON and feed it back. `--plan <file>` is an *assertion*
  about what was reviewed; a material divergence refuses, by design.
- Do not choose `--claude-md=import` on your user's behalf without saying so.
  It is the one mode that appends to a file they own.
- Do not describe the install as finished until the apply's own report says what
  landed. The plan says what *would* happen.
