# Migration Guide

What a **release migration** is, how `/update-framework` evaluates one
against your tree, and what to do about each kind of item it finds. This
guide stands alone — read it whether you arrived from `/update-framework`'s
own output, from `KNOWN_ISSUES.md`, or from `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`.

## What a release migration is

A **release migration** is anything a LogicLoom release does that an older
install cannot absorb by taking a file diff alone: a plugin upstream stopped
shipping, a path upstream renamed, or a piece of text a customer's tree
should change by hand even though LogicLoom will never overwrite it.

**The standing principle:** every release is evaluated against *your* tree by
`/update-framework`, and that evaluation produces a **proposal — never an
automatic change** — for every kind of migration, including for files
upstream must never overwrite (a fork's own `.logic-loom/memory/amendments.md`,
or your customised root `CLAUDE.md`). The tool that diffs upstream's history
against your sync point (`extract-proposals.sh`) already never edits a file
without your yes; the release-migration scan holds to exactly the same
promise for the things a file diff cannot express on its own.

## The registry — `.logic-loom/config/release-migrations.conf`

Upstream-owned, line-oriented, `#` comments, blank lines ignored, **exactly 8
pipe-separated fields**, whitespace around each field trimmed:

```
kind | name | fate | replacement | default | first_shipped | release | note
```

| Field | Meaning |
|---|---|
| `kind` | `plugin` \| `mcp-server` \| `path` \| `content` \| `none` |
| `name` | for `plugin`/`mcp-server`/`path`: a directory name or repo-relative path; for `content`: a repo-relative path or shell glob (`*`, `?`); for `none`: `-` |
| `fate` | `renamed` \| `folded` \| `native` \| `removed` (component kinds); `present` \| `absent` (content — propose when the pattern IS / is NOT found); `none` (the `none` kind) |
| `replacement` | `plugin:<name>` \| `path:<repo-relative>` \| `command:/<name>` \| `native:<comma list>` \| `external:<text>` \| `pattern:<POSIX ERE>` (content only) \| `none` |
| `default` | the recommended action when the copy is pristine: `REMOVE` \| `ADOPT-REPLACEMENT` \| `CONVERT-TO-LOCAL` \| `KEEP-AS-IS` \| `MOVE` \| `PROPOSE` \| `PROPOSE-ADVISORY` (content rows only; see § *The advisory row*) |
| `first_shipped` | first release tag that contains it, `never` (alias row), or `-` |
| `release` | for a component row, the first release tag that **lacks** it; for a `content`/`none` row, the release the row belongs to |
| `note` | free text — for a `content` row it **must** contain both `proposal:` and `why:` |

**Escaping.** A raw `|` is the field separator. To put a literal `|` inside a
field — most often needed for a `pattern:` alternation — write `\|`; the
parser decodes it back to `|` after splitting. A raw, unescaped `|` still
counts as a field boundary and an 8-field row that turns into 9 fails `lint`.

**Uniqueness.** `name` is unique **only among the three component kinds**
(`plugin`/`mcp-server`/`path`) — the registry can never carry two rows
claiming to be the authority on the same plugin directory. A `content` row's
identity is `(name, release, pattern)`: two content rows may name the same
file (checking two different things, or the same thing across two releases)
and are two separate items.

**Read upstream-first.** The scan reads this file from the fetched
`refs/loom-upstream/main` ref before falling back to your local copy, so the
registry it evaluates against is current even on a run whose enhancement
proposals were filtered down to nothing (adopted repos — see § *Adopted
installs* below).

### One example row per kind

```
# plugin — real, shipped
plugin | sdd-dev-loop | native | native:/workflow,/loop,/goal | REMOVE | v4.0.0 | v6.2.0 | Autonomous edit-test-debug loop; superseded by native /workflow, /loop, /goal (CHANGELOG 6.2.0 calls it loom-dev-loop)

# mcp-server — real, shipped
mcp-server | sdd-marketplace | removed | external:Anthropic Claude Code Plugin Marketplace + Docker MCP Toolkit | REMOVE | v4.0.0 | v6.2.0 | In-house marketplace MCP; also remove its .mcp.json entry

# path, fate=renamed — hypothetical, illustrates the MOVE action (no shipped row uses it yet)
path | .logic-loom/scripts/bash/old-name.sh | renamed | path:.logic-loom/scripts/bash/new-name.sh | MOVE | v6.0.0 | v7.1.0 | Example only — a real moved-path row reads the same way

# content — real, shipped in v7.0.0
content | .logicloom-adopt-receipt.json | absent | pattern:"generator": "logicloom-update-framework@ | PROPOSE | - | v7.0.0 | proposal: run bash plugins/loom-maintenance/scripts/record-update-writes.sh --reconcile once, so files you accepted through /update-framework before v7.0.0 are recorded as yours and receive upstream updates again; why: before v7.0.0 the adopt receipt was never written after install, so every later upstream edit to an update-added file was silently suppressed (see .docs/guides/MIGRATION_GUIDE.md)

# none — illustrative; a real release with nothing adopter-facing carries exactly one of these and no other row
none | - | none | none | - | - | v6.6.2 | No plugin, mcp-server, or path removed; no content check applies to this release
```

## The project-owned registry — `.logic-loom/config/project-migrations.conf`

**Advisory only, and never LogicLoom's claim.** A row in this file is your
own text, describing your own project's own content — LogicLoom did not
write it, ship it, or assert anything about what it checks. It follows the
same `content` grammar as an upstream row and takes the same single action,
`PROPOSE`: shown to you, and applied by nobody but you (or the main agent, on
your yes) — never the script.

Same 8-field grammar, same parser, same evaluation — but this file is
**yours**: LogicLoom never ships one, and the maintainer-tree registry test
asserts it is absent from LogicLoom's own repository. Every item it produces
carries `source: project` instead of `source: upstream`, and it is evaluated
identically — same proposal shape, same decisions file, same briefing rule.
This is how a fork gets a generic content check without LogicLoom inventing a
row about text it does not own.

### Worked example — the fork-declared row

A fork that ported an escalation-cost mandate into its own
`.logic-loom/memory/amendments.md`, then separately drifted its personal copy
of the same ladder, can declare a row that catches the drift:

```
content | .logic-loom/memory/amendments.md | present | pattern:^- 3 = it changes auth, payment, or customer-data logic | PROPOSE | - | v7.0.0 | proposal: rescale the fourth cost line to "+3 on top of the reversibility score" so the rung matches the ladder this mandate was ported from; why: fork-authored text drifted from its source and nothing upstream can update it
```

`amendments.md` is fork-authored text: upstream never diffs the file (it is
never part of the adopt payload or the template), so the only mechanisms
that ever reach it are a row like the one above, an upstream
`PROPOSE-ADVISORY` row (next section — the shipped v7.0.0 registry carries
exactly one, on this very file), and the fork's own edit. Neither kind of
row ever writes to it.

## The advisory row — `PROPOSE-ADVISORY`

A `content` row whose `default` is `PROPOSE-ADVISORY` is the one kind of
upstream row that points at a file **LogicLoom did not ship this text** for:
a file your fork wrote (`.logic-loom/memory/amendments.md`, `CLAUDE.md`,
`CLAUDE.local.md`, or `AGENTS.md` — the only four basenames the linter
accepts for it; a row naming any other file fails `lint`) that has drifted
from a convention LogicLoom now documents. In plain terms:

- **What it is.** A shipped, upstream-authored *suggestion* about your own
  text — "if your file still says X, consider Y, because Z" — carried in the
  registry so `/update-framework` can surface it once, in context, instead
  of leaving it in a changelog you would have to go and read.
- **What LogicLoom is not claiming.** That it wrote, shipped, or owns the
  text. It did not. The scan says so on the item itself, every time, with
  the line `ADVISORY — LogicLoom did not ship this text (it is your own
  file); this proposal is informational only and is never applied
  automatically`, and the JSON carries `advisory: true`.
- **What it does.** Proposes, exactly like `PROPOSE` — the `proposal:` and
  `why:` text is shown; the script never edits the file; you (or the main
  agent, on your yes, diff shown first) do, or you record
  `keep = <name>@<release>` to acknowledge it without editing. The menu is
  the content menu, `[k]eep [s]kip`.
- **Where it fires.** In **both** a template clone and an adopted install —
  it is never scoped by the adopt receipt, because the harness never wrote
  the file it names. A file that does not exist, or whose text does not
  match the row's `pattern:`, produces no item at all.

The one such row v7.0.0 ships names `.logic-loom/memory/amendments.md` and
matches an escalation-ladder line that a fork ported by hand; a fork that
never wrote that line sees nothing.

## The four actions (plus MOVE for a moved path, PROPOSE for content)

- **REMOVE** — the component is gone from upstream and your copy is
  pristine: byte-identical to LogicLoom's own record of it, with no
  untracked or git-ignored file under it. An index entry flagged
  `skip-worktree` or `assume-unchanged` (`git update-index`) never counts
  as pristine — `git diff` trusts the index for those and cannot see a
  local edit, so the scan lists the entry under `changed` and keeps the
  item instead of guessing. Five more things are never pristine, because
  git's own listings cannot see them and this tool checks for them itself:
  a path whose **parent directory is a symlink** (the bytes live wherever
  that link points — a `git rm` of such a path would unlink the file at the
  link's target, even outside the repository; listed under `changed`), a
  directory holding a **nested git repository** (a `.git` directory or a
  `.git` gitdir-pointer file — the outer repository's git never lists
  anything under it as untracked, while its history is nobody's but yours;
  listed under `added`), a **subdirectory the scan cannot read** (the
  enumeration itself failed, so nothing under the item counts as verified;
  listed under `added`), a **special file** (a named pipe, socket or device
  node — git's directory walker drops anything that is not a regular file,
  symlink or directory, so no listing ever shows one, and it cannot be
  tracked; listed under `added`), and an **empty directory** (git tracks no
  directories, so it appears in no listing at all; listed under `added`).
  The byte comparison itself is git's own blob compare and nothing else:
  every `git diff` the scan runs passes `--no-ext-diff --no-textconv`, so
  an external diff driver or textconv you have configured —
  `GIT_EXTERNAL_DIFF`, `diff.external`, a `.gitattributes` `diff=<driver>`,
  even one whose exit code git is told to trust — never gets to decide
  whether a file is pristine. A tracked file under the item that carries a
  `filter=<driver>` attribute (git-lfs, nbstripout, git-crypt — any
  `filter.<driver>.clean`) is never pristine either: git runs the clean
  filter when it reads the working-tree file, so `git diff` compares the
  filter's output, not the bytes on disk, and an edit the filter strips
  (a notebook's re-run cell outputs, a redacted value) is invisible to it.
  The scan finds such files with `git check-attr`, lists them under
  `changed` with the driver named, and asks; a `-filter` (explicitly unset)
  attribute does not count. The command per kind:
  - `plugin` → `git rm -r plugins/<name>` (gate policy `git.rm = ask`, so you
    approve it), then `.logic-loom/scripts/bash/sync-plugin-commands.sh prune`
    to drop the bridge wrapper(s) and regenerate the bridge manifest.
  - `mcp-server` → first remove the `"<name>":` entry from `.mcp.json` (the
    main agent edits it on your yes, diff shown first — `.mcp.json` is not a
    protected file), then `git rm -r mcp-servers/<name>`.
  - `path` → `git rm <path>` for a file, `git rm -r <path>` for a directory.

  **REMOVE is blocked** while a `.claude/settings.json` (or
  `settings.local.json`) hook, or a `.github/workflows/` step, still points
  under the item's path — deleting the directory would silently thin the
  governance floor or turn a workflow red. Every other reference (a bridge
  wrapper, a cross-reference from another plugin, a project agent/skill/rule,
  a docs mention) is listed but never blocks; the plan's first step is always
  to repoint or remove the blocking reference, never to run `git rm` through
  it.
- **ADOPT-REPLACEMENT** — the component was renamed or folded and your copy
  is customized: for each changed or added file, the plan shows the
  counterpart under the replacement's path so you can carry your diff by
  hand; a file with no counterpart converts to local instead
  (`convert <name> --apply --customized-only`).
- **CONVERT-TO-LOCAL** — the fate is `folded`/`native`/`removed`, or the
  component was renamed but you customized it and there is no counterpart
  file to carry the diff into. See § *Converting a plugin* below.
- **KEEP-AS-IS** — you decide to hold onto the customer-owned copy as-is.
  Writes `keep = <name>` to `.logic-loom/config/migration-decisions.conf` on
  request. Consequence, stated plainly: no upstream updates to it, ever; the
  harness floor test, manifest validator, and lifecycle suite print an
  informational pending-migration notice on every run (never a failure);
  commands from it keep working only through their bridge wrapper. The
  manual alternative to KEEP-AS-IS: rename the directory out of the
  `loom-*`/`sdd-*` namespace and fix its manifest — it becomes an ordinary
  customer plugin the harness no longer has any opinion about.
- **MOVE** — only for a `path` row with `fate = renamed`
  (`replacement = path:<new>`). Proposed only when upstream does **not**
  ship the new path itself: the main agent runs `git mv <old> <new>` on your
  yes (gate policy `git.mv = ask`). When upstream *does* ship `<new>` as its
  own clean-add, MOVE is not offered — accept that clean-add first, then the
  old copy is simply REMOVEd (blocked, with the reason stated, until `<new>`
  exists on disk). If your copy is customized, the recommendation is
  KEEP-AS-IS with "carry your diff into `<new>`, then re-run" — the tool
  never guesses which half of a rename is the one you edited.
- **PROPOSE** — the only action a `content` row ever takes. The registry
  note's `proposal:` and `why:` text is shown to you; nothing is written by
  the script. You (or the main agent, on your yes, diff shown first) edit
  the file, or you record `keep = <name>@<release>` to acknowledge it
  without editing. `PROPOSE-ADVISORY` is the same action on a file LogicLoom
  never shipped — see § *The advisory row* above.

## Converting a plugin to a project-local skill

**Mapping** (`convert <name> --dry-run` / `--apply`):

| Source | Target |
|---|---|
| `plugins/<p>/skills/<s>/**` | `.claude/skills/<s>/**` |
| `plugins/<p>/commands/<c>.md` | `.claude/skills/<c>/SKILL.md` — a skill, not a `.claude/commands/` file |
| `plugins/<p>/agents/<a>.md` | `.claude/agents/<a>.md` (a strict upgrade: project agents keep `hooks`/`mcpServers`/`permissionMode`, which plugin agents never had) |
| `plugins/<p>/hooks/hooks.json`, `hooks/scripts/*` | `.claude/skills/<p>/hooks/…` — copied, **never wired** |
| every other plugin-root file or directory — `scripts/`, `lib/`, `config/`, `templates/`, `tests/`, `README.md`, a `LICENSE`, a custom asset dir, a dotfile; enumerated generically, never from a fixed list | `.claude/skills/<p>/<same relative path>` |
| a **symlink** anywhere under `plugins/<p>` — a file or directory link at any depth, a symlinked `skills/`, `commands/`, `agents/` or `.claude-plugin/` directory, a symlinked `.claude-plugin/plugin.json` | **never converted** (copying a link's target would turn your wiring into a detached copy) — listed under *Not carried over* and the delete step is withheld until you carry or remove it by hand. `plugins/<p>` **itself** being a symlink is refused up front (a `STOP` line, exit 2, nothing read or written, no decision recorded): replace it with a real directory, or carry its target over by hand |
| a **nested git repository** anywhere under `plugins/<p>` — a `.git` directory, or a `.git` gitdir-pointer file (what `git worktree` writes) | **never converted** (copying repository metadata into `.claude/` would make `.claude/skills/<p>` an embedded repository the outer tree can only ever hold as a gitlink, so the converted skill could never travel with it) — listed under *Not carried over* once, by name, never as its object files; the delete step is withheld until you move or remove it by hand |
| a **special file** anywhere under `plugins/<p>` — a named pipe, a socket, a device node | **never converted, never even opened** (reading a named pipe blocks until something writes to it — an earlier build of this converter hung on one) — listed under *Not carried over*; the delete step is withheld until you remove it by hand |
| `.claude-plugin/plugin.json` | `.claude/skills/<p>/plugin.json.orig` (renamed so nothing mistakes it for a live manifest) |
| (generated) | `.claude/skills/<p>/CONVERTED.md` — the record: registry row, every path written, the hooks-wiring snippet, the follow-ups |

Every copied markdown file gets a provenance marker on the line after the
closing `---` of its frontmatter (or as line 1 when there is none):

```
<!-- converted-from: plugins/<p>/<rel> | logicloom-plugin-deprecations v1 | project-owned: upstream never updates this file -->
```

**The same-named command-and-skill case.** When `plugins/<p>/commands/<c>.md`
would convert into a skill directory that a same-named
`plugins/<p>/skills/<c>/` already occupies, the command's body is **appended**
to that skill's `SKILL.md` instead of creating a second directory — not
merged. The appended section is a `## Command procedure` section delimited
by its own start and end `converted-from:` markers; it carries the command's
original YAML frontmatter verbatim inside a `yaml` fence (labelled "not
merged — this skill's frontmatter governs; carry `allowed-tools`/`model` over
by hand if you need them"), then the command's body. A `NOTE` line calls out
when the command's `allowed-tools:`/`model:`
differ from the skill's own frontmatter, so nothing is silently lost — you
decide whether to carry either value over by hand.

**Why a command becomes a skill, not a `.claude/commands/` file.** In Claude
Code 2.x, `.claude/skills/<name>/SKILL.md` is invocable as `/<name>` and
accepts `description`, `allowed-tools`, and `model` — a converted command
loses nothing (the floor for this conversion is Claude Code >= 2.0).
`.claude/commands/` in this repository is the command bridge's own
territory: `sync-plugin-commands.sh prune` deletes any file there
carrying the bridge marker once its source plugin is gone, and several
shipped invariants assert that no file remains there **without** that
marker. Writing a static file into `.claude/commands/` would require
weakening a shipped guarantee; writing a skill requires nothing.

**Hooks are never wired.** A converted plugin's hook scripts are copied to
`.claude/skills/<p>/hooks/scripts/…` with their executable bit preserved, but
nothing in `.claude/settings.json` is touched — that file is protected, and
this tool never edits it. `CONVERTED.md` carries the ready-to-paste snippet
for each script, for you to add by hand if you want it wired:

```
{"type":"command","command":"bash .claude/skills/<p>/hooks/scripts/<x>"}
```

**Collisions never overwrite.** A target that already exists and is not this
tool's own untouched output stops **that one unit** with `STOP <unit>:
<reason>` and exit code `2` — everything else in the same conversion still
writes. This is normal for a renamed or folded plugin whose command name
collides with an existing one (e.g. `/git-push` provided by both a legacy
plugin and its replacement): the STOP names the counterpart plugin and tells
you to carry your diff there instead. **Always run `--dry-run` first** — a
partial conversion is a normal, expected outcome to read, not a bug.

**The two follow-ups, always:** delete `plugins/<p>` once the converted
command or skill works, then run `sync-plugin-commands.sh prune` to drop the
now-orphaned bridge wrapper. Prune **before** relying on the converted
command — during the short window where both the old bridge wrapper and the
new skill exist, which one Claude Code resolves `/<c>` to first is not
guaranteed.

**…but only when the run said so.** Every `convert` run ends with an
`accounted:` line and a `Next steps:` line. Delete `plugins/<p>` only after
an `--apply` run printed `accounted: every file under plugins/<p> is carried
over …`. A run that printed `DO NOT delete plugins/<p> yet` lists exactly
which files were not carried over — a non-`.md` file under `commands/` or
`agents/`, a symlink, a unit that STOPped, a write that failed, a
directory the tool could not read (the enumeration itself failed, so
nothing under `plugins/<p>` counts as verified) — and those bytes exist
nowhere else. A **`KEEP <target> modified-after-conversion`** line is on
that list too: the target exists but differs from what the plugin source
renders to *now*, so the source's current bytes are provably not there —
the source was edited after conversion, or the target was, or both; the tool
cannot tell which and overwrites nothing, so it says "reconcile by hand,
then decide" instead of "delete". A `--dry-run` never prints the delete step
at all: nothing was written yet. `.claude/skills/<p>/CONVERTED.md`'s own
*Follow-ups* section takes exactly the same gate as the terminal, so reading
the record later never says "delete" where the run that wrote it said "DO
NOT". That record is written once and never rewritten (it may be your own
edit by then): if you edit the plugin afterwards and re-run `convert
--apply`, the file on disk can still say "delete" — the re-run prints a
`NOTE … CONVERTED.md: STALE` line saying so, and `scan --json` carries the
current recommendation. The scan applies the same gate: a `converted = <p>` decision
recommends `REMOVE` only while a fresh `--dry-run` re-render is all-`SKIP`
**and** reports every file accounted for; otherwise the item stays
`KEEP-AS-IS` and names what was left behind. A symlink at a **target** under
`.claude/` (dangling or not), or at any parent directory of one, is never
written through — that unit ERRORs and the conversion counts as failed. The
same refusal applies when the target **already exists** and would only be
read and classified (`SKIP`/`KEEP`): a converted copy that sits on the far
side of a link — say `.claude/skills/<skill>` replaced by a symlink to a
directory outside the repository — is never counted as "carried over", the
delete step is withheld, and the next `scan` reads the item as `KEEP-AS-IS`.

## The decisions file — `.logic-loom/config/migration-decisions.conf`

Project-owned, never shipped upstream, created on first use (like
`amendments.md`). Grammar:

```
# comments allowed
keep = <name>
keep = <name>@<release>
converted = <name>
```

`keep = <name>` acknowledges KEEP-AS-IS for a component row, for every
release. `keep = <name>@<release>` is narrower — it silences every `content`
row for that one file **and** that one release only; nothing else is
affected ("one file, one release, one acknowledgment"). `converted = <name>`
is written by `convert --apply` on success, never by hand — including a run
that converted every unit it knows about but had to leave some files behind
(its output says so). The decision records what was converted; it never by
itself authorizes `REMOVE`: the next scan recommends `REMOVE` only once every
file under `plugins/<name>` is accounted for, and `KEEP-AS-IS`, naming the
leftovers, until then.

**Briefing rule, every run:** whenever this file holds at least one line,
`/update-framework` lists each decision with its consequence — including
under `--check-only`, and even when every migration item reads `none
pending`. The rule stated once: a decision suppresses a proposal, never the
fact that one was suppressed. Commit this file — decisions travel with the
repository, the same way `.sdd-sync-ref` does.

## Adopted installs (`npx logicloom init`)

**The receipt.** `.logicloom-adopt-receipt.json` is the record of what the
npm installer wrote into your repository. `extract-proposals.sh` uses its
`runs[].wrote` list to decide which upstream file changes are yours to see —
a change to a path the receipt never recorded is suppressed, because
offering it would mean proposing an edit to a file that may not even be the
adopter's own.

**Why a file `/update-framework` added before v7.0.0 would stop receiving
updates from v7.0.0 on.** The ownership filter itself is new in v7.0.0 —
every published 6.x `extract-proposals.sh` offered every upstream change,
filter or no filter — so nothing was suppressed *before* v7.0.0. The gap
opens the moment the filter is in place: applying an accepted `clean-add`
before v7.0.0 wrote the file to disk but never touched the receipt (there
was no recorder), so the first filtered run would see a path the receipt
never recorded and suppress its next upstream edit — silently, as a count on
stderr, from then on. It was not a reader defect: nothing ever wrote the
missing entry.

**What `record-update-writes.sh` does, from v7.0.0 on.** After every
`/update-framework` run that writes an accepted `clean-add`/`clean-apply`
file in an adopted repo, `record-update-writes.sh --version <vX.Y.Z> <paths…>`
appends one run to the receipt recording those paths (and their ancestor
directories) as yours — one JSON file, no git, committed together with the
rest of the update.

**What `--reconcile` proposes.** `record-update-writes.sh --reconcile` scans
every tracked file under an already-recorded top-level directory that the
receipt does **not** yet list, and prints two lists: `RECONCILE <path>` for a
file whose bytes are byte-identical to the file at your `.sdd-sync-ref` copy
— treated as upstream's, and offered for recording — and
`DIFFERS <path>` for a file that differs from that copy and is **never**
recorded automatically, because it may be entirely your own. `--reconcile`
alone only prints; `--reconcile --apply` records the `RECONCILE` list. If you
accepted a `DIFFERS` file through `/update-framework` and edited it
afterwards, record it explicitly and by name:
`record-update-writes.sh <path>`. Byte-identity to the sync-ref blob is
corroborating evidence, not proof of authorship — a customer's own file can
coincidentally match one — so "already-recorded top-level directory" only
ever means a directory a receipt run wrote whose own `generator` matches one
of LogicLoom's own two writers (the same check the Trust boundary section
below describes for `release-migrations.sh scan`/`plan`); a hand-added run
with a forged `generator` string never makes its directory a `--reconcile`
candidate. A candidate is an *index* path (`git ls-files`), so a recorded
directory you have since replaced with a symlink — to anywhere — is skipped
with a note on stderr, neither `RECONCILE` nor `DIFFERS`: the bytes at that
path live wherever your link points, and record mode refuses the same path
for the same reason. Replace the link with a real directory (or record the
real location by name) if you want those files recorded. Directory names
reach git as *literal* pathspecs (`:(literal)<name>`), so a name git would
otherwise read as pathspec magic or a glob — one beginning with `:`, say —
is enumerated as the directory it is, both when the recorder decides
whether a directory is fully accounted for and when `--reconcile` sweeps
one.

**The deliberate asymmetry.** Recording a byte-identical copy costs at most
one extra, still user-gated *proposal* later, if upstream ever edits it
again — nothing is ever applied without your yes. Not recording it costs
permanent, silent suppression. When the tool cannot tell provenance for
certain, it errs toward the mistake that costs you one more prompt, never the
one that costs you a file you never hear about again.

**Requirements, and how uninstall sees a recorded path.** The recorder needs
`python3` or `node` to write JSON — every adopted install has `node`,
because `node` wrote the receipt in the first place; it refuses only when
neither is on `PATH`. It appends to `runs[]` only — `runs[]` is the single
source of truth, and `uninstall` is a *view* over it, not a second copy of
the record. `packaging/adopt/lib/apply.js`'s `uninstallProcedure()` (the one
place that derives `uninstall`; `packaging` itself never ships to an
adopted repo) walks **every** run, regardless of which tool wrote it, so a
path this script records is already correctly covered the next time that
procedure runs. Rather than reimplement that derivation a second time in
bash/python/node, `record-update-writes.sh` instead **deletes** any existing
`uninstall` key on every run it appends — a cached list computed before this
run cannot name a path this run just recorded, and a wrong list that looks
authoritative is worse than an absent one. A fresh, complete `uninstall`
comes back the next time the adopter runs
`npx logicloom init . --apply --only=<the targets you installed>` (`--only`
is required with `--apply`; over an installed tree the run is a no-op that
says so — `NO-OP`, `WROTE 0`, exit 0 — and still appends a run, which is
what recomputes `uninstall`); until then, a
recorded path is still visible to `extract-proposals.sh`'s ownership filter
(so it can receive proposals) — it is just not listed under
`uninstall.remove.files` in the interim, rather than wrongly listed as safe
to delete.

**Trust boundary — the adopt receipt.** `.logicloom-adopt-receipt.json` is a
plain, hand-editable JSON file committed in your own repository, exactly
like `.sdd-sync-ref` and `refs/loom-upstream/main` — all three are LOCAL
records this repo's own git history can forge or edit, and none of them is
cryptographically signed. This tool does not invent signing to close that
gap. What `release-migrations.sh scan`/`plan` DOES do before trusting a
receipt-recorded `sha256` as proof that a file is byte-identical to what
LogicLoom shipped (the `receipt-sha256:<hash>` baseline that can lead to a
`REMOVE` recommendation):

1. Restrict it to a run whose `generator` matches one of LogicLoom's own two
   writers (the npm installer's `logicloom@<version>`, or the v7 recorder's
   `logicloom-update-framework@<version>`) and whose `status` is
   `"complete"` — a foreign generator string, or a run that never finished,
   proves nothing.
2. **Corroborate the digest against `refs/loom-upstream/main`'s own
   history.** The recorded digest may authorize `REMOVE` only when that
   EXACT digest also equals the `sha256` of some blob LogicLoom itself
   shipped at that same path, in some commit `refs/loom-upstream/main`
   reaches — not merely the current tip; a file's pristine content moves
   across releases. Forging a receipt entry to pass this now also requires
   forging a matching commit in `refs/loom-upstream/main`, a strictly higher
   bar than editing one JSON file, even though neither step is
   cryptographic proof.

If `refs/loom-upstream/main` does not exist locally, or no commit it reaches
ever shipped a blob at that path hashing to the receipt's recorded digest,
the receipt candidate is treated as if it were never recorded: the item
falls through to the next baseline candidate (`.sdd-sync-ref`, then
`refs/loom-upstream/main` directly), or to `baseline: none` / `state:
unknown` if none resolves — never a REMOVE recommendation from an
uncorroborated claim. Doubt reads as KEEP and ASK, the same governing
principle every other baseline resolution in this tool follows.

**The same trust boundary applies to a `kind:"dir"` entry — corroborated
differently, because a directory has no hash.** `record-update-writes.sh
--reconcile` uses every `kind:"dir"` entry in the receipt to decide which
directories are framework-scoped enough to sweep for unrecorded files
worth reconciling. A `kind:"file"` entry at least carries a `sha256` that
gets verified against a real blob before anything is recorded; a
`kind:"dir"` entry carries no hash to verify. `loom_upstream_ever_had_dir`
(`.logic-loom/lib/release-migrations.sh`) closes that gap the same cheap,
read-only way: a directory claim is trusted only when
`refs/loom-upstream/main`'s own reachable history ever held a TREE at that
exact path — not merely a plausible `generator` string in the same
hand-editable file. An uncorroborated `kind:"dir"` entry is dropped from
the sweep silently (other, corroborated entries in the same receipt still
reconcile normally); nothing under an uncorroborated directory is ever
evaluated, let alone recorded.

## How a 6.x install receives this

Everything above — the registry, its lib, the scan/convert script, the
recorder, **and the ownership filter itself** — is new in v7.0.0. Neither a
6.x template clone nor a 6.x adopted install has a `/update-framework` that
knows Step 3b or Step 7b exist, and neither has an `extract-proposals.sh`
that reads the adopt receipt: every 6.x release tag ships the same
unfiltered extractor, which diffs `sync-ref..refs/loom-upstream/main` in
full and offers every changed or new path. Both kinds of install therefore
receive all of it through their **existing, unmodified** `/update-framework`,
on the first run that fetches past v7.0.0, because every new v7.0.0 file is
an ordinary proposal to that extractor — nothing about receiving them
depends on the new machinery already being in place. What differs is only
what that first run shows alongside them.

**A 6.x template clone.** `.logic-loom/config/release-migrations.conf`,
`.logic-loom/lib/release-migrations.sh`,
`plugins/loom-maintenance/scripts/release-migrations.sh`, and
`plugins/loom-maintenance/scripts/record-update-writes.sh` are new paths
upstream of v7.0.0 — the 6.x extractor offers them as ordinary `clean-add`
proposals (absent downstream), no different from any other new file it has
ever offered. The updated `plugins/loom-maintenance/commands/update-framework.md`,
`plugins/loom-maintenance/skills/framework-updater/SKILL.md` (carrying Step
3b and Step 7b) and `plugins/loom-maintenance/scripts/extract-proposals.sh`
(carrying the ownership filter) are `clean-apply` proposals on files the
clone already has and did not customise (`conflict-review` if it did — never
overwritten). Accept them, and the run's own commit lands the new text; the
**next** invocation of `/update-framework` is the v7.0.0 procedure.

**A 6.x adopted install (`npx logicloom init`).** The payload `npx logicloom
init` installs is assembled from the release tag's tree, so an install made
with `logicloom@6.6.x` runs the 6.6.x `extract-proposals.sh` — the one that
**has no ownership filter**. On the first run that fetches past v7.0.0 it
behaves exactly as the template clone above: the four new v7.0.0 files
arrive as `clean-add`, the updated command, skill and extractor as
`clean-apply`/`conflict-review`. One caution for that single run, stated
because it is true of the 6.x extractor and not of the v7.0.0 one: with no
filter, it also offers upstream paths the payload never installed — new
files under `tests/` and `.github/`, root `README.md`, `package.json`,
`CLAUDE.md`, `AGENTS.md` — as `clean-add` when you have no such file, or
`conflict-review` when you have your own (never overwritten). **Decline
those**; they are LogicLoom's own, not yours. From the next invocation on,
the v7.0.0 extractor reads your receipt and suppresses them itself.

That next, first-v7.0.0 invocation is where the receipt starts to matter.
Every published installer (`logicloom@6.6.0` onward) recorded each
directory it created as a `kind:"dir"` entry in `runs[].wrote` — `plugins/`,
`plugins/loom-maintenance/`, `.logic-loom/`, `.logic-loom/config/`,
`.logic-loom/lib/` and the rest — so the v7.0.0 filter's ancestor rule
(`adopt_offer_added_path`: offer a **new** upstream path once any recorded
ancestor directory exists) keeps offering new upstream files under those
trees with no further action. The four files the 6.x run added, however,
were added by a procedure that had no recorder, so the receipt does not list
them: an upstream **edit** to one of them would now be suppressed
(`adopt_file_recorded` finds nothing). That is precisely the gap the
Step 3b scan's `MG-` item on `.logicloom-adopt-receipt.json` names on that
run — accept it, run `record-update-writes.sh --reconcile` (each such file
lists as `RECONCILE` if it is still byte-identical to its sync-ref copy,
as `DIFFERS` if you edited it since — record those by name), then
`--reconcile --apply`, and Step 7b's re-check offers anything that recording
just unblocked before the sync ref moves.

**What this guide will not claim beyond the code above.** The 6.x behaviour
is read from the extractor at the 6.x release tags (no receipt logic at any
of them); the v7.0.0 behaviour from today's `extract-proposals.sh`
(`adopt_offer_added_path`, `adopt_file_recorded`) and the installer's
`copyTree` at the commits the 6.6.x packages were published from. It is not
a substitute for `tests/contract/test_update_framework_ownership.sh`
actually exercising a pre-v7.0.0-shaped fixture end to end.

## Pre-v6.2 clones

If your install predates v6.2.0, re-baseline first — see "Broken sync
baseline" in `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`. The `.specify/` →
`.logic-loom/` framework-directory rename is a separate migration and is
**not** covered by this registry or by the release-migration scan.

## Principle XVI — why a converted skill is still compliant

Principle XVI requires framework capabilities to be organized as installable
plugins, but its own scope is *framework* capabilities — and a component
upstream has stopped shipping is, by definition, no longer one. The
precedent already stands in this repository: plugin agents never actually
loaded through any plugin marketplace mechanism, so moving them to
`.claude/agents/` (project-owned) was ruled *more* native than what it
replaced, not a Principle XVI exception; a converted `.claude/skills/`
directory, carrying its `converted-from:` marker, is the same move applied to
skills and commands. The manual alternative when you would rather not carry
that marker forever: rename the plugin's directory out of the `loom-*`/
`sdd-*` namespace and fix its manifest — it is then an ordinary customer
plugin, with no special treatment and no notice from this tooling at all.

## For maintainers — shipping a release

A release must declare its migrations: at least one row whose `release`
field names it, or exactly one `none` row (never both — a `none` row sharing
its release with any other row is a contradiction the linter rejects). When
any non-`none` row names the release, the `CHANGELOG.md` entry for it must
carry a `### Migrating from …` subsection. `release-migrations.sh
check-release --since auto` additionally fails a release that dropped a
`plugins/<x>` or `mcp-servers/<x>` directory since the previous tag without a
registry row for it, and — whether or not it fails — prints the
adopter-facing diff-stat followed by this exact line:
`structure verified; whether the declared rows are the right rows for those files is your call`
— the tool can verify that a removal was declared, never that a `content` row's
`proposal:`/`why:` text is the *correct* text for what changed — that
judgment stays yours. `tests/contract/test_release_migrations.sh` runs this
check in the promote gate and on every push.
