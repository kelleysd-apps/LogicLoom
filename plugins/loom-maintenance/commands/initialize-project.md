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
| 4f · Remove maintainer CI | as written | **SKIP ENTIRELY — see below** |
| 5–6 · Validate + report | as written | as written; say in the report that this was an adopted repo and which steps were skipped |

**Why 4f is skipped, and why this is not a softening.** The adopt payload
excludes `.github/` wholesale, so **nothing under `.github/workflows/` in an
adopted repository came from LogicLoom** — every file there is the adopter's CI.
`rm -f` against their workflows would delete work this tool has no claim on, and
it would contradict the applier's own refusal that nothing is ever deleted,
truncated or moved. The removal step exists because a *template clone* inherits
the maintainer-only release workflows; an adopted repo inherits none, so there is
nothing to remove and the step has no work to do. Skipping it removes no
protection — it declines to act on files that were never ours.

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

### Step 4f: Remove Maintainer-Only Template-Release CI

**ADOPTED repositories: SKIP THIS STEP ENTIRELY. Run nothing here.** The adopt
payload excludes `.github/` wholesale, so nothing under `.github/workflows/` in
an adopted repo came from LogicLoom — it is all the adopter's own CI, and the
`rm -f` lines below would delete it. See Step 0 for the detection and the full
argument. The rest of this step applies to a TEMPLATE CLONE only.

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

This step is the SAME removal performed by `init-project.sh` (the shell path) and
documented in the `project-initialization` skill. All three paths must list the
same set of workflows — `tests/contract/test_shipped_gates_vs_strip.sh` derives
that set from `.github/workflows/` (default: maintainer-only) and asserts all
three agree, so a sixth workflow turns it red until every path names it.

State in the Step 6 report which files were removed and why.

### Step 5: Validate Compliance
Run `.logic-loom/scripts/bash/constitutional-check.sh`

### Step 6: Report
Show: VISION.md scaffolded/seeded (or skipped if author-filled), the approval
posture chosen (and any refused lines), the memory backend chosen and whether
distillation is by hand or a schedule prompt was printed, the maintainer-only
CI workflows removed, customizations applied, agents created, MCP servers
recommended, next steps.
