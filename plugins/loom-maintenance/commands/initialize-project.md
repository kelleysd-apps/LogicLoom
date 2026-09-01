---
name: initialize-project
description: Post-PRD project initialization — customizes constitution, agents, and workflows based on PRD.
model: opus
---

# /initialize-project Command

**AGENT REQUIREMENT**: This command should be executed by the prd-specialist.

**If you are NOT the prd-specialist**, delegate immediately:
```
Use the Task tool to invoke prd-specialist:
- description: "Execute /initialize-project command"
- prompt: "Initialize project from PRD. Arguments: $ARGUMENTS"
```

## Execution Instructions (for prd-specialist)

### Step 0: Which install is this? — TEMPLATE CLONE or ADOPTED

**Run this first. Several steps below are wrong, and one is destructive, in an
adopted repository.**

This command was written for a **template clone**: a fresh checkout of the
LogicLoom template that becomes the project. It is now also reachable from a
repository that **adopted** LogicLoom via `npx logicloom init` — the adopt
payload ships `plugins/` and `.claude/commands/`, so `/initialize-project` is in
that user's command palette whether or not anyone points them at it. Telling
adopters not to run it is not a control; making it know where it is running is.

Detect, read-only, no git:

```bash
# ADOPTED if this prints the schema line; TEMPLATE CLONE if the file is absent.
grep -l '"schema": *"logicloom/adopt-receipt@1"' .logicloom-adopt-receipt.json 2>/dev/null
```

The receipt is written by the adopt applier and names every path it wrote. Read
it — `runs[].claudeMd.resolved` is where the harness's operating instructions
actually live in this repo, and `uninstall` is the removal procedure.

| Step | TEMPLATE CLONE | ADOPTED |
|---|---|---|
| 1 · Locate PRD | as written | **Usually no PRD.** Do not block and do not ask them to write one; take project facts from the repo they already have |
| 1.5 · VISION.md | as written | **Offer, never create unprompted.** They have their own product direction and no `VISION.md` stub was installed (the payload excludes it) |
| 1.6 · project.conf | as written | as written — **this is the main reason to run the command** |
| 1.7 · gate posture | as written | as written |
| 1.8 · memory + distill | as written | as written |
| 2 · Constitution | as written | **Write mandates to `.logic-loom/memory/amendments.md`, not `constitution.md`.** Editing the shipped constitution makes every later `npx logicloom init` upgrade a conflict against a file it will refuse to overwrite |
| 3 · Agents | as written | as written |
| 4 · MCP / keys / upstream | as written | as written, except: their root `CLAUDE.md` is **theirs**. Do not edit or create it. The harness registry installed as `.logic-loom/AGENTS.md`, not root `AGENTS.md` |
| 4f · Maintainer CI / CI methodology | remove the five maintainer-only workflows, as written | **Never remove anything (nothing there is ours) — instead OFFER the CI methodology templates: install, adapt, or decline** |
| 4g · `.brain/` scaffold | as written | as written |
| 4h · `artifacts/` + dashboard | as written | as written |
| 5–6 · Validate + report | as written | as written; say in the report that this was an adopted repo and which steps were skipped |

**Why 4f no longer skips entirely for an adopted repo, and what stays
unchanged.** The adopt payload excludes `.github/` wholesale, so **nothing
under `.github/workflows/` in an adopted repository came from LogicLoom** —
every file there is the adopter's own CI. That fact is unchanged and it is
still why this tool **never removes, overwrites, or touches** anything under
an adopted repo's `.github/` — `rm -f` against their workflows would delete
work this tool has no claim on, and it would contradict the applier's own
refusal that nothing is ever deleted, truncated or moved. What changed is that
"nothing to remove" used to mean "nothing to do here at all." It now means
"offer the methodology instead" — see Step 4f below for the offer, adapt,
never-install-unprompted shape.

### Step 1: Locate PRD
Find PRD at `specs/prd/PRD.md` or ask user for location.
(ADOPTED: usually absent — do not block. See Step 0.)

### Step 1.5: Scaffold the Project VISION
Ensure the project's **foundational** product north-star exists at repo-root
`VISION.md`, alongside the constitution. This is a distinct artifact class — a
single, living, peer-to-the-constitution document — NOT a per-feature vision
(`features/<name>/vision.md`) and NOT a swarm-pack pre-PRD gate.

1. If `VISION.md` does **not** exist, copy it from
   `.logic-loom/templates/project-vision-template.md` (the template ships as a
   `VISION.md` stub on a fresh clone, so usually it already exists).
2. If `VISION.md` is still the **unfilled stub** (contains `<placeholder>` /
   `[PROJECT NAME]` markers), seed its North Star, Strategic Pillars, and Open
   Threads FROM the PRD's goals/constraints, then **prompt the user** to confirm
   the North Star in their own words before continuing.
3. If `VISION.md` is already **author-filled**, do NOT overwrite it (idempotency —
   Principle IV); note it and skip.

This is a STANDING north-star seeded from the PRD. It must precede Step 2 because
the constitution defers product direction to `VISION.md`.

### Step 1.6: Stamp the Project Identity
`.logic-loom/config/project.conf` ships UNSTAMPED — its three required values are
the literal placeholder `__UNSET__`, so a cloner can never inherit a
plausible-looking slug. Stamp it now; nothing else in the repo carries a stable
per-project identifier (`package.json` `name` is the same in every clone until
this step, and `framework-upstream.conf` identifies UPSTREAM, not this project).

1. Read the file. If **no active key line** matches
   `^\s*(project_slug|project_name|id_prefix)\s*=\s*__UNSET__\s*$`, it is already
   stamped — **do not rewrite it** (Principle IV) and skip to Step 2. Grep for the
   active line, not the bare string: the file's own comments discuss `__UNSET__`.
2. Otherwise set the three required values from the PRD:
   - `project_slug` — lowercase kebab (`[a-z0-9][a-z0-9-]*`). **IMMUTABLE ONCE
     SET.** Everything that references this project across repositories keys on
     this string; changing it later orphans that history. Confirm it with the
     user in their own words before writing.
   - `project_name` — the human display name. Free text; safe to change later.
   - `id_prefix` — uppercase, 2-6 chars (`[A-Z][A-Z0-9]{1,5}`). Used to mint
     task ids that stay unambiguous next to another project's backlog
     (`ACME-014`). Default: the slug's alphanumerics, uppercased, first 4.
3. Leave `repo` alone unless the user asks. It is optional and shipped commented
   out — the git remote is the truth, and a stale declared value is worse than
   none. Do NOT run git to populate it.
4. Confirm with the read-only reader (it never writes and never runs git):
   ```bash
   bash .logic-loom/scripts/bash/validate-project-identity.sh
   ```

An unstamped file is a WARNING, never an error — a fresh clone that has not run
this command is a normal state.

### Step 1.7: Choose the Approval Posture

Ask ONCE which repository operations should interrupt the user, and write the
answer to `.logic-loom/config/gate-policy.conf`. This is a preference, not a
constant — before it existed, `git commit -m "wip"` and `git push --force`
produced the same prompt, which is how an approval prompt stops being read.

**Do not ask thirty-eight questions.** Offer three named postures, one line each:

| Posture | What it does |
|---|---|
| `strict` | Ask before every repository change. Nothing runs silently. |
| `balanced` | Ask before anything consequential or destructive; let routine local work (commit, add, stash, tag, checkout, cherry-pick, revert, fetch) run. **Recommended, and the shipped default.** |
| `minimal` | Only the five un-turn-off-able operations ask; everything else runs. |

Steps:

1. **Idempotency check (Principle IV).** If `gate-policy.conf` already contains an
   active `# posture:` line, a posture has been chosen — say so and skip. Do not
   re-prompt and do not overwrite a hand-tuned file.
2. Ask the user, defaulting to `balanced`.
3. Render the body from the verdict library — there is exactly ONE definition of
   what a posture means, shared with `init-project.sh` and
   `tests/contract/test_gate_policy.sh`:
   ```bash
   . .logic-loom/lib/governance-verdicts.sh && loom_gate_posture_body balanced
   ```
4. Rewrite `gate-policy.conf` by **stripping only the active
   `<operation> = <verdict>` lines and appending the rendered body**, keeping all
   commentary — that commentary is where the policy is explained. Strip with
   `^[[:space:]]*(git|gh)\.[a-z0-9.-]+[[:space:]]*=` — the hyphen and digits
   matter, because `git.cherry-pick` and `git.history-rewrite` contain one and a
   surviving duplicate WINS (first occurrence takes precedence).
   Add a `# posture: <name> (chosen at project initialization on <date>)` line so
   step 1 can detect it next time.
5. Surface any refusal, verbatim, and do not try to work around it:
   ```bash
   . .logic-loom/lib/governance-verdicts.sh && loom_gate_policy_refusals
   ```

**The floor is not negotiable, in any posture.** `git.push`,
`git.history-rewrite`, `gh.repo.admin`, `gh.secret.write` and `gh.auth` always
ask; a config line setting one of them to `silent` is REFUSED with a typed reason
rather than ignored. Separately — and not represented in this file at all —
governance-file writes stay subagent-DENY / main-ASK, and a subagent keeps
read-only git only, with all `gh` denied. Never offer to relax any of that.

Tell the user two things in closing: they can change any SINGLE operation later
by editing one line in `gate-policy.conf`, and editing that file will itself
prompt for approval (it is on the protected-file floor, so a subagent cannot
rewrite the approval policy and then act under it).

### Step 1.8: Memory Backend and the Distillation Routine

Ask two questions, once, in order. Full detail lives in the
`project-initialization` skill; this is the short version.

1. **Where should durable cross-session memory be written?** Offer two named
   backends — `repo` (`.brain/memory/`, in-tree and versioned, so lessons
   travel with the code and survive a machine change; stripped at template
   release, **recommended, and the shipped default**) and `project`
   (`$HOME/.claude/projects/<slug>/memory/`, per machine, outside the repo,
   never committed — where `/retro` wrote historically). Write the choice
   to `.logic-loom/config/memory-backend.conf`, key `memory_backend`.
   Idempotency (Principle IV): if `memory_backend` is already set
   explicitly, skip — that key is exactly what this step writes. With no
   explicit setting the resolver defaults to `repo`; it never probes the
   filesystem to decide. A store left behind at
   `$HOME/.claude/projects/<slug>/memory/` from before this change is
   reported by the preflight advisory (`check-brain-signals.sh`) until the
   user moves it or answers `project` — nothing moves anyone's files.
   Confirm with the read-only resolver, which never writes:
   ```bash
   bash .logic-loom/scripts/bash/resolve-memory-backend.sh --explain
   ```
   `memory-backend.conf` and `brain.conf` are on the governance guard's
   protected-path list — a subagent's write is DENIED and a main-agent edit
   prompts for approval. Writing the answer here will prompt; expect that,
   don't route around it.
2. **Run distillation on a schedule, or by hand?** By hand (or declined):
   scaffold nothing — `.brain/` keeps just its `README.md` until there is
   something to put in it. Schedule: **print**
   `.logic-loom/templates/distill-schedule-prompt.md` and tell the user to
   install it themselves via `/schedule` or their own cron — **do not
   install it**; `~/.claude/scheduled-tasks/` is the user's tree, and the
   harness-user boundary forbids writing there.

This is opt-in at the point of value, not the point of setup — do not turn it
into a workflow decision the user has to make before they have anything to
distill.

### Step 2: Customize Constitution
Read PRD goals and constraints. Update `.logic-loom/memory/constitution.md` principles as needed.

### Step 3: Create Custom Agents
Based on PRD-identified roles, use `/create-agent` for each.

### Step 4: Configure MCP Servers
Based on PRD tech stack, recommend MCP servers via Docker MCP Toolkit.

### Step 4b: Configure Multi-LLM API Keys
The `/research` command requires API keys for multi-LLM tribunal research.
Guide the user to add the following to `.env` (gitignored):

```bash
# Required for /research command — Multi-LLM Tribunal Research
OPENAI_API_KEY=sk-...        # OpenAI GPT-4o for research + tribunal voting
GEMINI_API_KEY=AIza...       # Google Gemini 2.5 Pro for research + tribunal voting
# Perplexity is pre-configured via Docker MCP Toolkit (no key needed here)
```

If the user doesn't have these keys yet, note it as a setup TODO and continue.
The `/research` command will validate keys are present before executing.

### Step 4c: Verify Framework-Update Config
Confirm `.logic-loom/config/framework-upstream.conf` exists with `LOOM_UPSTREAM_REPO`
set (stamped templates already have it). If absent — e.g. a custom fork — ask the
user for the upstream `<owner>/<repo>` (the PUBLIC framework/template repo, NOT
their own origin) and write it:
```bash
printf 'LOOM_UPSTREAM_REPO="%s"\n' "<owner>/<repo>" > .logic-loom/config/framework-upstream.conf
```
Do NOT add a git remote — `/update-framework` fetches fetch-only into a namespaced ref.

### Step 4d: Point at the Harness ↔ User Boundary
Tell the user in one or two lines: LogicLoom governs this repo and never writes to
`~/.claude/` — personal preferences (persona, response shape, their own global
hooks) belong there, not in the project `CLAUDE.md`. Point them at
`START_HERE.md` § *Where do my personal preferences go?* Do not restate the section.

### Step 4e: gh Telemetry — Inform, Never Change
Run the read-only detector and relay its output verbatim if it prints anything:
```bash
bash .logic-loom/scripts/bash/check-gh-telemetry.sh
```
It is silent when `gh` is absent or telemetry is already opted out, and prints a
short notice plus the exact one-line opt-out when telemetry is on.

**Do NOT run `gh config set`, do NOT edit `~/.config/gh/config.yml`, and do NOT
touch any shell rc file — not even if the user asks in passing.** That setting is
the user's, on their machine, outside this repo. Report it and let them run the
command themselves.

### Step 4f: Maintainer CI (TEMPLATE CLONE) / CI Methodology (ADOPTED)

**Branch on Step 0's detection.** The two repository kinds get different
treatment here, and neither branch touches the other's files.

#### TEMPLATE CLONE

The template ships five workflows that release + guard **the LogicLoom template
itself**, not the customer's project. Remove all five now:

```bash
rm -f .github/workflows/promote-to-main.yml        # maintainer release workflow (not for your project)
rm -f .github/workflows/release-tag.yml            # maintainer auto-tag-on-release-merge (not for your project)
rm -f .github/workflows/publish-adopt.yml          # maintainer npm publish of the adopt package (not for your project)
rm -f .github/workflows/leak-guard.yml             # maintainer identity-marker backstop (not for your project)
rm -f .github/workflows/branch-topology-guard.yml  # maintainer release-branch-only gate on main (your main takes feature branches)
```

**Keep `.github/workflows/plugin-tests.yml`** — it validates the harness the
customer is actually using.

`branch-topology-guard.yml` is the one that BITES if it is left behind. It fails
**every** pull request into `main` whose head branch is not `release/vX.Y.Z`. In
this repo's release topology that is correct; in a normal project, where `main`
receives ordinary feature branches, it rejects every PR the customer opens. The
other four merely no-op or fail harmlessly. Removing it is not optional cleanup.

`publish-adopt.yml` publishes LogicLoom's own npm adopt package on
`release: published`. Left behind it would fire on the customer's first GitHub
Release and fail — it looks for a `Source-dev-main:` trailer and a `packaging/`
tree that only the LogicLoom maintainer repo has. Noise, not damage, but it is
maintainer plumbing that is meaningless in an adopter's repo.

Idempotent (Principle IV): `rm -f` on an already-removed file is a no-op, so
re-running this command is safe.

This removal is the SAME one performed by `init-project.sh` (the shell path) and
documented in the `project-initialization` skill. All three paths must list the
same set of workflows — `tests/contract/test_shipped_gates_vs_strip.sh` derives
that set from `.github/workflows/` (default: maintainer-only) and asserts all
three agree, so a sixth workflow turns it red until every path names it.

State in the Step 6 report which files were removed and why.

#### ADOPTED — offer, adapt, never install unprompted

**Never remove, overwrite, or otherwise touch anything under an adopted
repo's `.github/`.** The adopt payload excludes `.github/` wholesale, so
everything there is the adopter's own CI — there is nothing of ours to
remove, and there never was (this is unchanged from before this step
existed).

What's new: **offer** the CI methodology instead of doing nothing. Ask once:

> "LogicLoom ships three CI gate templates — a test-suite runner, a
> content leak guard, and a branch-provenance guard — plus a guide on the
> release-line pattern they come from. Want to see them?"

If yes:

1. Point them at `.docs/guides/release-loop-methodology.md` for the prose
   methodology (what the templates assume, and the two-line release pattern
   LogicLoom itself uses that the third template only makes sense for).
2. Walk through `.logic-loom/templates/workflows/*.yml.template` one at a
   time. Each opens with a header comment stating what it does, what it
   assumes, and every `⟨PLACEHOLDER⟩` to fill in — read that header with
   them rather than installing blind.
3. For each template they want, **write the adapted result** to
   `.github/workflows/<name>.yml` (drop the `.template` suffix) only after
   the placeholders are resolved with the user — never copy a template
   verbatim with its placeholders still in it.
4. `branch-topology-guard.yml.template` is conditional on actually having a
   release process the branch name is supposed to prove was followed — say
   so before offering it, and skip it by default if they don't have one.

If declined, or if the question is never reached: **write nothing to
`.github/`.** This is not a fallback state to apologize for — a plain "no CI
methodology installed" is the correct, complete outcome for a repo that
doesn't want it.

State in the Step 6 report which templates (if any) were installed, and if
none, that the offer was declined or not asked.

### Step 4g: Scaffold `.brain/` (offer, never create unprompted)

The adopted/cloned repo ships `.brain/` holding only `README.md` — the
project-knowledge-layer contract, no content. Ask once, the same shape as
Step 1.5's VISION.md offer:

> "Create the working layers now — `.brain/raw/`, `wiki/`, `index/`,
> `memory/` — or keep `.brain/` README-only until you have something to put
> in it?"

Idempotency (Principle IV): if any of `.brain/raw/`, `.brain/wiki/`,
`.brain/index/` already exist, the layer is already scaffolded — say so and
skip; do not overwrite or re-ask.

If yes, create the structure `.brain/README.md` itself documents (§ "The
layers"):

```bash
mkdir -p .brain/raw/{research,exploration,reviews,reports,retro,archive}
mkdir -p .brain/wiki/{concepts,decisions}
mkdir -p .brain/index
# memory/ only if memory_backend = repo (Step 1.8's answer) — project backend
# keeps memory outside the repo entirely, so an empty in-repo memory/ would
# be dead structure nothing ever writes to.
```

Do **not** create `.brain/memory/` when Step 1.8 resolved `memory_backend` to
`project` — that backend's whole point is memory living outside the repo, at
`$HOME/.claude/projects/<slug>/memory/`; an unused sibling directory in the
repo would just be confusing. Do not create `DISTILL-LOG.md` here either —
`/distill` creates it on its own first run, and an empty log with no entries
would misstate "a pass has run" before one ever has.

If declined: leave `.brain/` exactly as shipped — `README.md` only. This is
the documented default state, not a partial setup.

### Step 4h: Build the First Backlog Dashboard (offer, never create unprompted)

The repo ships `artifacts/` holding only `README.md` and `.gitkeep` — the
convention, no content. Ask once:

> "Build the first backlog dashboard from your `todos.md` / `backlog.md` now?"

If yes:

1. Run the two generators, in order:
   ```bash
   bash .logic-loom/scripts/bash/build-backlog-index.sh
   bash .logic-loom/scripts/bash/build-backlog-dashboard.sh
   ```
   This writes `artifacts/backlog-dashboard.html` — open it directly in a
   browser, no server needed.
2. **Mention, do not silently derive:** the dashboard's issues panel reads
   `.logic-loom/config/project.conf`'s `repo` key (`owner/repo`) to know
   which GitHub repository to fetch open issues from at view time. That key
   ships commented out (Step 1.6 leaves it alone unless asked). Offer to set
   it now:
   ```bash
   # only if the user confirms the owner/repo string themselves —
   # NEVER derive it from `git remote`. build-backlog-dashboard.sh's own
   # header records why: an earlier version resolved it from `git remote
   # get-url origin` inside the freshness-gate regeneration path, and that
   # path regenerates WITHOUT the override — so the committed artifact
   # carried the real repo while the gate's copy carried null, and the
   # tracked file was permanently stale. The `repo` key in project.conf is
   # the one place this value is allowed to come from, precisely because it
   # is a value a human confirmed once rather than a value re-derived
   # differently in different contexts.
   sed -i.bak 's/^# *repo *= .*/repo         = <owner\/repo>/' \
     .logic-loom/config/project.conf   # or edit the line by hand
   ```
   Without this key the issues panel renders a stated reason ("no repo
   declared") rather than failing silently or showing nothing unexplained.
3. If they run `SessionStart` regeneration (LOOM-0049 § 3.5) mention it here
   too — the markdown half stays current on its own; the `repo` key and the
   generated page's issues panel do not need re-running for that.

If declined: leave `artifacts/` as shipped — `README.md` and `.gitkeep` only.
This step depends on nothing else in this command; it can be answered "later"
without blocking Step 5.

### Step 5: Validate Compliance
Run `.logic-loom/scripts/bash/constitutional-check.sh`

### Step 6: Report
Show: VISION.md scaffolded/seeded (or skipped if author-filled), the approval
posture chosen (and any refused lines), the memory backend chosen and whether
distillation is by hand or a schedule prompt was printed, the maintainer-only
CI workflows removed (TEMPLATE CLONE) or which CI methodology templates were
installed if any (ADOPTED), whether `.brain/` was scaffolded beyond its
README, whether the first backlog dashboard was built and whether `repo` was
set in `project.conf`, customizations applied, agents created, MCP servers
recommended, next steps.
