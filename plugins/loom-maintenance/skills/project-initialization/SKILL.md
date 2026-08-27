---
name: project-initialization
description: |
  Post-PRD project initialization — customizes constitution, creates agents,
  and configures workflows based on the completed Product Requirements Document.

  Triggered by: /initialize-project, "initialize project", "set up project",
  "customize framework for project"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
category: maintenance
---

# Project Initialization Skill

## Purpose

Initialize a project after PRD completion: customize constitution, create agents, update docs, and configure MCP servers.

**Workflow**: `/create-prd` → **`/initialize-project`** → MCP Setup → `/specification`

---

## Pre-Initialization Checklist

Before starting, verify:
1. PRD exists at `.docs/prd/prd.md`
2. PRD has all required sections (Executive Summary, Personas, Features, Principles, Constraints, Release Strategy)
3. User has approved initialization

---

## Procedure

### Step 1: Analyze PRD

Read `.docs/prd/prd.md` and extract:

1. **Project metadata** — name, vision, primary focus areas
2. **Target domains** — which domain skills will be needed (frontend, backend, database, etc.)
3. **Principle customizations** — project-specific thresholds, exceptions, constraints
4. **Custom agents** — any agents identified in PRD Principle X section
5. **Tech stack** — database, cloud provider, frameworks (for MCP setup)

### Step 1b: Stamp the Project Identity

File: `.logic-loom/config/project.conf`

This is the ONLY stable per-project identifier in the repo. Before it existed,
nothing could key on "which project is this": the root `package.json` `name` is
framework-owned and identical in every clone, and
`.logic-loom/config/framework-upstream.conf` identifies the UPSTREAM template,
not the project. A cross-project backlog roll-up has nothing to join on without
this file.

The template ships it UNSTAMPED — the three required values are the literal
placeholder `__UNSET__`. That is deliberate: a default that looks real is a
default nobody changes, and the whole value of the slug is that it is unique per
project.

1. **Check first.** Grep for an ACTIVE placeholder line, not the bare string —
   the file's own comments discuss `__UNSET__` by name:
   ```bash
   grep -E '^[[:space:]]*(project_slug|project_name|id_prefix)[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*$' \
     .logic-loom/config/project.conf
   ```
   No match means it is already stamped. **Leave it alone** (Principle IV) and
   move on — re-stamping a slug is not an idempotent operation, it is a rename.
2. **Stamp the three required keys** from the PRD:

   | Key | Format | Mutability |
   |---|---|---|
   | `project_slug` | `[a-z0-9][a-z0-9-]*` | **IMMUTABLE once set** — confirm with the user first |
   | `project_name` | free text, non-empty | change freely; nothing keys on it |
   | `id_prefix` | `[A-Z][A-Z0-9]{1,5}` | mints task ids (`ACME-014`); default = slug alphanumerics, uppercased, first 4 |

   Edit the values in place. Every comment in the file is the schema
   documentation — preserve it.
3. **`repo` is optional and shipped commented out.** Fill it only if the user
   asks. It is the one field already discoverable from `git remote`, and the one
   that silently changes on a fork/rename/transfer; a declared value that
   disagrees with the actual remote is worse than none. Do NOT run git to
   populate it.
4. **Confirm** with the read-only reader — it never writes, never deploys, never
   runs git, and exits 0 on an absent or unstamped file:
   ```bash
   bash .logic-loom/scripts/bash/validate-project-identity.sh
   ```

Nothing enforces this file. No hook reads it. A project that never stamps it
works exactly as before — the validator says so and exits 0.

### Step 1c: Choose the Approval Posture

Write the user's answer to `.logic-loom/config/gate-policy.conf`. Which git/gh
operations INTERRUPT the user is a preference; which ones can never be silenced
is not.

**Ask once, with three named postures — never a per-operation questionnaire.**

| Posture | One line |
|---|---|
| `strict` | Ask before every repository change. Nothing runs silently. |
| `balanced` | Ask before anything consequential or destructive; routine local work runs. **Recommended; shipped default.** |
| `minimal` | Only the five floor operations ask; everything else runs. |

```bash
# Idempotency (Principle IV): a chosen posture is already recorded.
grep -m1 '^[[:space:]]*# posture:' .logic-loom/config/gate-policy.conf   # present -> skip

# One definition of a posture, shared with init-project.sh and the contract test.
. .logic-loom/lib/governance-verdicts.sh && loom_gate_posture_body balanced

# Rewrite: strip ONLY the active operation lines, keep every comment, append.
grep -vE '^[[:space:]]*(git|gh)\.[a-z0-9.-]+[[:space:]]*=' gate-policy.conf > tmp
# (the hyphen and digits in that class are load-bearing: git.cherry-pick and
#  git.history-rewrite contain a hyphen, and a surviving duplicate WINS)

# Report anything the floor refused, verbatim.
. .logic-loom/lib/governance-verdicts.sh && loom_gate_policy_refusals
```

**Floor, in every posture** — `git.push`, `git.history-rewrite`,
`gh.repo.admin`, `gh.secret.write`, `gh.auth` always ask; a `silent` line for any
of them is refused with a typed reason, not ignored. Not in this file at all, and
equally non-negotiable: governance-file writes (subagent DENY / main ASK) and the
subagent rule (allowlisted read-only git only; all `gh` denied). Never offer to
relax any of these.

`gate-policy.conf` is itself on the protected-file floor, so a subagent cannot
rewrite the approval policy and then act under it — and a human edit to it
prompts once. Say so; it is the reassurance that makes the knob safe to use.

### Step 1d: Memory Backend and the Distillation Routine

Two questions, asked once, in this order.

**Question 1 — "Where should durable cross-session memory be written?"**
Write the answer to `.logic-loom/config/memory-backend.conf`, key `memory_backend`.

| `memory_backend` | One line |
|---|---|
| `repo` | `.brain/memory/` — in-tree and versioned, so lessons travel with the code, survive a machine change, and are readable by any tool with filesystem access. Stripped at template release, so a cloner never inherits anyone's lessons. **Recommended, and the shipped default.** This project's own vault: self-contained, no link to anyone else's. |
| `project` | `$HOME/.claude/projects/<slug>/memory/` — per machine, outside the repo, never committed, invisible to anything that is not Claude Code. Where `/retro` wrote historically. |

The question exists because the destination used to be hardcoded, in prose,
inside the `/retro` skill: a fine default and a bad contract, because nothing
could point it anywhere else without editing the skill, and the store it fed
was per-machine and invisible outside Claude Code. Now it is a setting with
one resolver and one answer.

The shipped `.logic-loom/config/memory-backend.conf` states
`memory_backend = repo` EXPLICITLY, and resolution is a pure function of
`(env, conf)` — the resolver never probes the filesystem to pick a default.
Both of those are deliberate, and were the outcome of rejecting the obvious
alternative: a default that looks for a pre-existing store and quietly holds
there. That would resolve differently in a worktree than in the main checkout
of the same project (the `project` slug is derived from the checkout path), and
it would turn a reviewable one-line config diff into a filesystem side effect
with no diff anywhere.

Migration is therefore DETECTION, not resolution. When memory resolves to
`repo` while `$HOME/.claude/projects/<slug>/memory/` still holds files from
before this change, `check-brain-signals.sh` reports the count and both paths
in the preflight advisory, every session, until the user moves them or sets
`memory_backend = project`. It never blocks and never moves anyone's files.
Answering this question is one of the two things that clears it.

```bash
# Idempotency (Principle IV): an explicit choice is already recorded.
grep -m1 -E '^[[:space:]]*memory_backend[[:space:]]*=' .logic-loom/config/memory-backend.conf

# Set the answer in place. Every comment in the file is its schema — preserve them.

# Confirm. Read-only; never writes, never runs git; exits 0 even on a bad value.
bash .logic-loom/scripts/bash/resolve-memory-backend.sh --explain
```

The resolver is fail-SAFE, not fail-closed: an unrecognised backend warns on
stderr and falls back to the default (`repo`) rather than aborting the write. Losing a
retrospective's lessons to a config typo is worse than writing them to the
default store and saying so out loud.

`memory-backend.conf` and `brain.conf` govern behaviour and are on the
governance guard's protected-path list, added additively via
`protected_paths` in `.logic-loom/config/governance.conf`. A subagent's write
to either file is DENIED; a main-agent edit prompts for approval. Writing the
user's answer into `memory-backend.conf` in this step will therefore prompt —
that is correct and expected, not a case to route around.

**Question 2 — "Run the distillation routine on a schedule, or invoke `/distill` by hand?"**
This question does two things, and neither is scaffolding.

- **By hand** (or declines entirely): scaffold NOTHING. `.brain/` keeps its
  single `README.md`, no `raw/`, `wiki/`, `index/` or `memory/` directory is
  created, `check-brain-record.sh` runs in CI and passes vacuously, and the
  preflight advisory stays silent. A layer is created the first time there is
  something to put in it — the same treatment `web/` and `artifacts/` already
  get.
- **Schedule**: **print** the contents of
  `.logic-loom/templates/distill-schedule-prompt.md` and tell the user to
  install it themselves via `/schedule` or their own cron. **Do not install
  it.** `~/.claude/scheduled-tasks/` is the USER'S tree, and the harness ↔
  user boundary in CLAUDE.md forbids the harness writing there —
  `init-project.sh`'s existing footprint discipline (it creates `web/`,
  removes maintainer CI, and touches nothing user-level) is the precedent.
  ```bash
  cat .logic-loom/templates/distill-schedule-prompt.md
  ```

The routine is opt-in at the point of value, not at the point of setup. A
customer with no distillation habit adopts it the first time captures pile up
and one line of advisory text mentions the command exists — not because
initialization made them answer a question about a workflow they have not
started yet. Honest limit: nothing in the repo can verify a schedule exists;
the age of the newest `.brain/DISTILL-LOG.md` entry is the only evidence, and
the advisory reports it honestly.

### Step 2: Customize Constitution

File: `.logic-loom/memory/constitution.md`

1. Create a backup: `cp constitution.md constitution.md.backup`
2. Add project metadata header (name, date, PRD reference)
3. For each principle with PRD customizations, add a `**Project Customization**` subsection
4. Increment patch version and update "Last Amended" date
5. Run `.logic-loom/scripts/bash/constitutional-check.sh` to validate

For customization templates, read `references/constitution-customization.md`.

### Step 3: Create Custom Agents

For each agent identified in the PRD:

1. **Get user approval** for each agent before creating
2. Use `/create-agent [name] "[purpose]"` to scaffold
3. Configure tools, model, and project-specific instructions
4. Create agent context at `.docs/agents/[dept]/[agent]/context.md`
5. Update AGENTS.md (tandem update with CLAUDE.md)

### Step 4: Update Framework Documents

1. **CLAUDE.md** — Add project overview section with name, vision, primary domains, custom workflows
2. **AGENTS.md** — Register new agents, update counts
3. **Agent collaboration triggers** — Add new domain→agent mappings to `.logic-loom/memory/agent-collaboration-triggers.md`
4. **Cross-Check Disposition (preserve — do NOT strip)** — the provider-neutral Cross-Check Disposition in **AGENTS.md Tier 1** and **CLAUDE.md** standing-policies, the `plugins/loom-orchestrator-hook/config/verification-intent.conf` trigger phrases, and the governance-preflight verification-intent nudge are shipped harness policy. Append project customizations around them; keep the disposition intact. To **activate** cross-provider review, the customer adds `OPENAI_API_KEY` (or `GEMINI_API_KEY`) to `.env`; without a key `/cross-check` cleanly reports "unavailable" and the nudge says so.

### Step 5: Configure MCP Servers

Delegate to the MCP server setup skill:
1. Read `plugins/loom-maintenance/skills/mcp-server-setup/SKILL.md`
2. Follow its procedure to analyze PRD requirements and install MCP servers

### Step 6: Optional Configuration

If PRD specifies:
- **Design system** (Principle XII): Create `src/design-system/` directory with README
- **Access tiers** (Principle XIII): Create `.docs/access-control.md` documenting tiers

> `.logic-loom/config/project.conf` is **identity only** — slug, display name, id
> prefix (Step 1b). It is not a grab-bag for project thresholds; those belong with
> the principle they qualify, in the constitution or in `amendments.md`. An
> unknown key there is warned about and ignored.

### Step 6b: gh telemetry — detect and inform (never write)

GitHub CLI telemetry is **opt-out** (on by default since gh v2.91.0) and LogicLoom
uses `gh` heavily, so surface it once during initialization:

```bash
bash .logic-loom/scripts/bash/check-gh-telemetry.sh
```

The detector is read-only: it probes `command -v gh`, the `DO_NOT_TRACK` /
`GH_TELEMETRY` environment variables, and the `telemetry:` key in the gh config
file. It never invokes a `gh` subcommand (`gh config get` can materialize a
default config file — that would be a write outside the repo), always exits 0,
and prints nothing when `gh` is absent or telemetry is already off.

Relay its output verbatim when it prints. **Never remediate on the user's behalf**
— no `gh config set`, no edit to `~/.config/gh/config.yml`, no append to
`~/.zshrc` / `~/.bashrc`. The harness↔user boundary is absolute: LogicLoom writes
nothing outside this repository, and a per-machine telemetry preference is the
user's call to make with their own hands. This is the settled disposition of
GitHub issue #55, whose original "write it for them during setup" proposal was
rejected precisely because a silent bootstrap write to a shell rc is the
unapproved action Principle VI exists to prevent.

### Step 7: Remove maintainer-only template-release CI

The template ships with CI that releases + guards the **LogicLoom template itself**,
not the customer's project. Remove it from the new project (keep `plugin-tests.yml`
— it validates the harness the customer is using):

```bash
rm -f .github/workflows/promote-to-main.yml   # maintainer release workflow (not for your project)
rm -f .github/workflows/release-tag.yml       # maintainer auto-tag-on-release-merge (not for your project)
rm -f .github/workflows/leak-guard.yml        # maintainer identity-marker backstop (not for your project)
rm -f .github/workflows/branch-topology-guard.yml  # maintainer release-branch-only gate on main (your main takes feature branches)
```

`branch-topology-guard.yml` is the one that actively BREAKS the project: it fails
**every** PR into `main` whose head branch is not `release/vX.Y.Z`. The other
three no-op or fail harmlessly. Removing it is not optional cleanup.

State clearly in the report that these were removed and why (they would otherwise
run — and fail/no-op — in the customer's CI and reference a release model the
customer is not operating).

This list is a TANDEM with two other paths that must stay identical:
`init-project.sh` (the shell path) and
`plugins/loom-maintenance/commands/initialize-project.md` (the command an agent
executes). `tests/contract/test_shipped_gates_vs_strip.sh` § 4 fails if the three
diverge. A project that adopted LogicLoom via `/update-framework` never ran any
of them and keeps the guard — `branch-topology-guard.yml`'s own header, and
`/update-framework` step 4, tell that user how to delete it.

### Step 8: Validate and Report

1. Run constitutional compliance check and sanitization audit
2. Verify document sync (constitution version matches CLAUDE.md references, agent counts match)
3. Generate initialization report:

```
Project Initialization Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project: [name]
Constitution: [old] → [new version]
Principles customized: [count]
Agents created: [count]
Approval posture: [strict|balanced|minimal]  (refused lines: [none|list])
Memory backend: [repo|project]
Distillation: [by hand|schedule prompt printed]
Files modified: [list]
Validation: PASS/FAIL

Next Steps:
1. Review constitution customizations
2. Run /specification "[MVP Feature 1]"
3. Begin TDD implementation cycle
```

---

## Critical Rules

1. **Principle VI**: NO automatic git operations. Which operations prompt is the
   user's `gate-policy.conf` choice; the five FLOOR operations (`git.push`,
   `git.history-rewrite`, `gh.repo.admin`, `gh.secret.write`, `gh.auth`), the
   governance-file guard, and the subagent git/gh rules are NOT tunable and must
   never be offered as tunable
2. **Principle VIII**: Every document update must keep CLAUDE.md and AGENTS.md synchronized
3. **Principle XV**: All files created in correct directories per convention

## References

- **Customization patterns**: `references/constitution-customization.md` — templates for each principle
- **MCP setup**: `plugins/loom-maintenance/skills/mcp-server-setup/SKILL.md`
- **Constitution**: `.logic-loom/memory/constitution.md`
- **Gate policy**: `.logic-loom/config/gate-policy.conf` — the ask/silent split, its floor, and the permission-mode keying
- **Memory backend**: `.logic-loom/config/memory-backend.conf` — where `/retro` writes durable cross-session memory (`repo`/`project`)
- **Brain config**: `.logic-loom/config/brain.conf` — the distillation routine's settings
