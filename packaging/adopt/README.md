# logicloom

**A governed multi-agent harness for Claude Code, installed into a repository you already have.**

`logicloom init` plans its own installation, shows you the plan, and applies only
the parts you name. It is built to be safe to point at a repository you care
about: without `--apply` it has no write path at all.

```bash
cd /path/to/your/project
npx logicloom init .
```

That plans and writes nothing. Read what it proposes, then install what you want.

## The two phases

**Plan** — the default, on every invocation. Reports the mode it chose and why,
what it would write, what it would merge, anything blocking, and the decisions it
needs from you. No write path exists in this phase.

**Apply** — requires `--apply` *and* `--only`. There is no "install everything by
omission."

```bash
npx logicloom init . --apply --only=all --claude-md=rules
npx logicloom init . --apply --only=hooks        # the governance floor, opt-in
```

## What `--only` installs

| Target | What lands |
|---|---|
| `harness` | the harness tree — `.logic-loom/`, `plugins/`, `.claude/{hooks,commands,context,agents}`, `.docs/` |
| `gitignore` | the harness ignore block, appended to your `.gitignore` inside a marked fence |
| `rules` | the operating instructions — `.claude/rules/logicloom-*.md` |
| `hooks` | registers the governance hooks in `.claude/settings.json` |
| `all` | `harness` + `gitignore` + `rules` |

**`hooks` is deliberately not in `all`.** It changes what your Claude Code
sessions are allowed to do in this repository, and nothing installs a governance
floor as a side effect. Name it if you want it.

## What it will not do

These are enforced in code, not merely intended:

- **Never deletes, truncates, or moves your files.**
- **Never overwrites a file it did not create.** `copyFileNew` opens with `'wx'`,
  so the kernel refuses an existing path.
- **Never runs a mutating git command.**
- **There is no `--force`.** If a file is already there, it stays. Move it aside
  yourself if you want ours.

The only files of yours it ever edits are merge targets you approve —
`.gitignore`, and `.claude/settings.json` if you asked for `hooks` — and both are
appended to behind marked fences, never rewritten.

## Uninstalling

Every path written is recorded in `.logicloom-adopt-receipt.json`, whose
`uninstall` object is the reversal procedure for *your* install specifically.

It is a list you run rather than a command this package ships, because a tool
that refuses to delete should not carry a delete path. The procedure distinguishes
files it created from files it merely merged into, removes directories
non-recursively so anything you added inside one survives, and records a `sha256`
per file so it can tell a file you never touched from one you have since made
your own — a mismatch means the file is yours now, and it says to keep it.

## Requirements

- **Node.js ≥ 20**
- **git**
- **bash** — for the `.gitignore` merge. Any version ≥ 3.2, including the one
  macOS ships.
- **python3** — only for the `.claude/settings.json` merge, so only if you install
  `hooks`.
- **`jq` or `python3` on PATH at session time** if you install `hooks`. The
  governance hooks parse Claude Code's payload and fall back between them; without
  either, some guards cannot read what they are guarding.

The plan reports what it actually found on your machine, so you see any of these
missing before you install rather than partway through.

## Driving this from a coding agent

```bash
npx logicloom init --agent-guide     # the procedure, written for an agent
npx logicloom init . --json          # the plan as data
```

`--agent-guide` prints the install procedure written for an agent acting on a
user's behalf: which plan fields to read, which questions to put to the user, how
to assemble the apply command, and what the refusals mean. It writes nothing and
reads no repository.

## Notes

- Run it from the **repository root**. Installing into a subdirectory of a repo is
  refused — Claude Code loads `.claude/` from the session root, so a nested
  install would be non-functional.
- Re-running an apply is a no-op. The tool recognises its own footprint and
  refuses to double-write; if you edit one of the merge targets afterwards, it
  refuses rather than silently reconciling.
- POSIX only today. On native Windows the merges need bash and python3, and the
  installed hooks are shell scripts.

## Links

- **Repository**: https://github.com/kelleysd-apps/LogicLoom
- **Issues**: https://github.com/kelleysd-apps/LogicLoom/issues

MIT licensed.
