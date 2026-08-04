# LogicLoom — The Unified Architecture

**Status**: exploration synthesis (no code changed) — the culmination doc
**Date**: 2026-07-08
**Feature**: `features/modular-harness/`
**Consolidates**: three research landscapes (surface portability · customization-preservation
layering · thin-core boundary) on top of the two prior designs — do **not** re-read those
for mechanics already settled there:
- `features/modular-harness/exploration/modular-harness-design.md` — core-vs-pack split,
  native `marketplace.json`, the governance-floor seam, per-pack versioning, the `loom-graph`
  pilot. **This doc adds the USER layer + the surface/preservation dimensions on top.**
- `features/code-knowledge-graph/exploration/graph-design.md` — the graph is now mostly
  *adopt* (Understand-Anything) + keep loom-memory as a git-tracked wiki.

---

## 1. Topline

LogicLoom is an **extremely light governed CORE + composable PACKAGES (adopt-existing-first)
+ a never-touched USER layer**, and all three are the **same** thing: Claude Code's native
**layered-config model** (USER `~/.claude/` < PROJECT `.claude/` < PLUGIN `plugins[]`, merged
lowest→highest, arrays concatenate + dedupe, scalars override, `*.local` auto-gitignored). The
core builds *only* the hook-enforced governance **floor**, the constitution, and the
update/bridge **scaffolding**; every capability is a **package** — a bundled plugin or an
**adopted** external plugin/MCP/CLI/skill (e.g. Understand-Anything for code comprehension),
never a bespoke rebuild. The three vision requirements fall out of the one layered model *by
construction, not by a bespoke engine*: **(1) thin core** = the core owns only the PROJECT
layer's floor + scaffolding; **(2) two-tier customization-preserving updates** = the core
updates via `/update-framework` over a declared **core-paths manifest** (never user files),
packages update individually via native `/plugin update` off a `marketplace.json`, and anything
the user adds lives in gitignored/out-of-repo sinks the updater structurally cannot see;
**(3) surface portability** = because the floor is entirely repo-committed `type:"command"`
bash hooks wired in root `.claude/settings.json`, it clones and fires on every Claude Code
surface that clones the repo (CLI, Desktop, VS Code, JetBrains — and, correcting the stale
memory, **cloud/web too**), with three narrow, honestly-disclosed degrade cases. The whole
build is **filters, conventions, and one config file** — zero merge/overlay/package-manager
code.

---

## 2. The Three-Layer Model

The user's KEY INSIGHT is validated: **there is one model, and it is native.** The only seam
the user must internalize is that LogicLoom's *core* physically lives in the **PROJECT** layer —
the same layer a user would naturally drop a custom command into — so core-vs-user is **not**
separated by a native config boundary. Separation is achieved by (a) **steering** user
extensions into natively-separate sinks, and (b) a **core-paths manifest** that tells
`/update-framework` which project-layer paths it owns (§3).

| Layer | What's in it | Owner | How it updates | Native mechanism that keeps it separate |
|---|---|---|---|---|
| **USER** (never touched) | `~/.claude/{settings.json, commands, skills, agents, plugins, CLAUDE.md}`; `.claude/settings.local.json`; `CLAUDE.local.md`; user MCPs + desktop connectors; `.claude/commands/` **static** (non-AUTO-GENERATED) files; `.logic-loom/memory/amendments.md` (constitution amendments); `features/**`, `specs/**`, `/retro` memory writes | The user | **Never** — survives every update by construction | Out-of-repo (`~/.claude`) OR gitignored (`settings.local.json`, `CLAUDE.local.md`) OR concatenated-after-core (CLAUDE.local.md appends AFTER CLAUDE.md → wins with no core edit) OR bridge-marker-protected (static commands) |
| **PROJECT** = the thin CORE | Floor: `.claude/settings.json` hook wiring + `.claude/hooks/**` + `plugins/loom-governance/hooks/**` + `.logic-loom/lib/governance-verdicts.sh` (verdict seam). Constitution **core** (`constitution.md` I–XVI). Scaffolding/bridge/update machinery. `loom-governance` plugin (assists) | LogicLoom | **`/update-framework`** (3-way merge, **core-paths-only**) + dev-main→main promote | It *is* the project layer; separated from user-in-project only by the **core-paths manifest** + steering (§3). The floor stays **root-anchored** so `/plugin disable` cannot reach it |
| **PLUGIN** = PACKAGES | The 8 bundled packs (`loom-orchestrator`, `sdd-specification`, `loom-creation`, `loom-git`, `loom-maintenance`, `loom-memory`, `loom-orchestrator-hook`) + **adopted** external plugins/MCPs/CLIs (Understand-Anything, Codegraph, …) | LogicLoom (bundled) or upstream (adopted) | **Native `/plugin update`** per-pack, off `marketplace.json` | Mandatory `plugin:command` **namespacing** (collision-proof); `dependencies:["loom-governance"]` resolver-blocks disabling the core; installed to `~/.claude/plugins/cache` (address code via `${CLAUDE_PLUGIN_ROOT}`, project data via `${CLAUDE_PROJECT_DIR}`) |

```
USER  ~/.claude + *.local + amendments   ── never touched, merges by precedence
  └── PROJECT  .claude/ + .logic-loom/ + CLAUDE.md   ── the CORE, /update-framework
        └── PLUGIN  plugins[] + adopted externals     ── PACKAGES, /plugin update
```

Precedence (Managed > CLI > Local > Project > User; MCP: local > project > user > plugin >
connectors) means user connectors/commands **coexist** with project + plugin layers via
deterministic resolution and never collide destructively.

---

## 3. Customization Preservation

Every user-editable thing survives updates because `/update-framework` **structurally cannot
see it** (gitignored or out-of-repo) or is **explicitly denied** by the core-paths manifest.

### 3a. The native sinks (per user-editable thing)

| User adds… | Lands in (native sink) | Why the updater never touches it |
|---|---|---|
| Personal settings/permissions | `.claude/settings.local.json` | Gitignored; Local > Project override; permission arrays *concatenate* not overwrite |
| Personal guidance | `CLAUDE.local.md` **or** `@~/.claude/logicloom-local.md` | Gitignored; concatenated AFTER core CLAUDE.md (last-read = highest weight, no core edit). Home-dir import survives across worktrees where `CLAUDE.local.md` does not |
| Custom command/skill/agent | `~/.claude/{commands,skills,agents}/` (PRIMARY) or a user-authored plugin via `/plugin` (colon-namespaced) or `.claude/commands/` **without** the AUTO-GENERATED marker | Out-of-repo, or namespace-isolated, or the bridge already refuses to overwrite static files |
| Custom MCP / desktop connector | user `~/.claude.json` / connector store | User-level MCP; precedence-merged with project `.mcp.json`, never clobbered |
| Constitution change | `.logic-loom/memory/amendments.md` (see §3b) | User-owned; on the manifest USER denylist |
| Feature/spec/retro work | `features/**`, `specs/**`, memory writes | User-owned project content; denylist |

### 3b. Constitution: CORE principles vs USER amendments (the split it doesn't have yet)

Today `constitution.md` is **one monolith**: principles I–XVI **plus** an `## Amendment Process`
(line 260) whose step 4 "**bump the version… sync tandem docs**" mutates the *same file*
`/update-framework` wants to overwrite. `extract-proposals.sh` treats `.logic-loom/memory/*`
as `governance` and so turns **every** constitution bump into a manual conflict-review whenever
the user has amended in place. Fix by **file separation** (native, no merge tool):

- **`constitution.md`** stays **core-only** (I–XVI + the Amendment Process + Version History) —
  LogicLoom-owned, `/update-framework` overwrites/3-way-merges it freely.
- **`.logic-loom/memory/amendments.md`** (new) is **user-owned**, on the manifest USER denylist,
  **never** touched. Effective constitution = **core ∪ amendments** — both injected by
  `governance-preflight.sh` + `load-context.sh load governance` (the one wiring change needed).
- Rewrite the Amendment Process: additions/overrides go in `amendments.md`; **immutable I–III
  remain un-overridable there** (a lint **HARD-FAILS** if an amendment relaxes I/II/III).
- **"Edited core in place" WARN lint**: warn if `constitution.md` itself diverged from the
  `.sdd-sync-ref` baseline blob (`git diff --quiet $sync_ref -- constitution.md` — a check
  `extract-proposals.sh` *already computes*) — an in-place core edit is the unsafe path.

### 3c. The CORE-PATHS MANIFEST (turns "never touch user files" from incidental to declared)

Today the boundary is **implicit**: `extract-proposals.sh` diffs only upstream's own history, so
a user file is safe only because upstream *happens* not to ship it — a probabilistic guarantee.
Add **`.logic-loom/config/core-paths.manifest`** (grammar mirroring the existing
`template-strip-manifest.txt`):

- **CORE globs** (may overwrite): `.claude/settings.json`, `.claude/hooks/**`,
  `.claude/commands/**` *where AUTO-GENERATED*, `plugins/**`, `.logic-loom/{scripts,lib,templates,config}/**`,
  `CLAUDE.md`, `AGENTS.md`, `.logic-loom/memory/constitution.md`.
- **USER-OWNED denylist** (never propose/overwrite, even on name-collision):
  `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/commands/**` (static/unmarked),
  `.claude/agents/**`, `.claude/rules/**`, `.mcp.json` (user MCPs),
  `.logic-loom/memory/amendments.md`, `VISION.md`, `features/**`, `specs/**`.
- **One filter** in `extract-proposals.sh`: any proposal matching the denylist is demoted to
  info-only ("upstream also ships X; your local copy is authoritative — not proposed").
- **Ordering rule** (rename safety): explicit CORE globs are evaluated **before** the USER
  denylist, so an upstream rename into a user-looking path can't silently hide a real core update.

### 3d. MANDATORY prerequisite — the `.gitignore` portability bug (verified this session)

The committed `.gitignore` (lines 48–49) has `.local/` and `*.local`, and **`*.local` matches
NEITHER `settings.local.json` NOR `CLAUDE.local.md`** (verified: `case "settings.local.json" in
*.local)` → no match). Those files are ignored on *this* machine only via the maintainer's
personal `~/.config/git/ignore`. **A cloner using the template would COMMIT their local
overrides and break the whole preservation model.** One-line fix (no engine): add committed
`.gitignore` entries `.claude/settings.local.json` and `CLAUDE.local.md` (and optionally
`**/.claude/settings.local.json`). **Highest-value, lowest-cost change in the whole design.**

---

## 4. Surface Portability

"Works in any environment" reduces to one question: **does this surface execute the floor's
`type:"command"` bash hooks in a bash shell, and load the repo-committed `.claude/` config?**
The floor is entirely repo-committed, so the answer is "yes wherever the repo clones and bash
runs." Per current (2026) docs, that is **every surface** — retiring the stale
"cloud floor absent" memory.

### Honest per-surface conformance matrix

| Surface | Project config loads | Floor hooks fire | Git-gate | Gov-protection | guard-dangerous (needs bash 4) | Plugin install |
|---|---|---|---|---|---|---|
| **CLI/terminal** (macOS/Linux) | ✅ | ✅ (reference surface) | ✅ | ✅ | ⚠️ degraded on macOS bash 3.2 | ✅ |
| **Desktop** (local + SSH) | ✅ | ✅ (same engine as CLI) | ✅ | ✅ | ⚠️ bash<4 | ✅ (GUI browser) |
| **VS Code** | ✅ | ✅ (bundles `claude` binary) | ✅ | ✅ | ⚠️ bash<4 | ✅ (`/plugins`) |
| **JetBrains** | ✅ | ✅ (orchestrates the CLI) | ✅ | ✅ | ⚠️ bash<4 | ✅ |
| **Web / Cloud** (claude.ai/code) | ✅ *Part of the clone* | ✅ SessionStart + PreToolUse run on the Ubuntu VM; `$CLAUDE_CODE_REMOTE=true` | ✅ hook fires **+** sandbox proxy already narrows blast radius | ✅ | ⚠️ bash present but check version | ⚠️ **flaky/contradicted** — keep floor independent |

Cloud carry-over table marks `.claude/settings.json` hooks, `.mcp.json`, and
`.claude/{skills,agents,commands}` as **"Yes (Part of the clone)"**; SessionStart hooks
"run in both local and cloud." So the floor **travels** for anything repo-committed — which is
all of it.

### The gaps, handled by DEGRADE-HONESTLY (not new machinery)

1. **Windows without Git Bash** — hook `command` strings fall through to PowerShell, which
   cannot run `bash x.sh`; the floor is **silently absent with an identical UI**. Handle:
   document Git Bash as a prerequisite (Desktop-on-Windows already requires Git for Windows) +
   a SessionStart assertion that the hook shell is bash, warning loudly if not.
2. **macOS bash 3.2** — `guard-dangerous-commands.sh` fails **open** below bash 4 (git +
   governance-protection guards are unaffected). Handle: re-exec into a bash-4+ if present, else
   mark this **one** guard "degraded" in the matrix.
3. **Cloud plugin-install** is contradicted across Anthropic docs (cloud doc "Yes / requires
   network" vs desktop doc "Plugins are not available for cloud sessions"; open bug #18088).
   Handle: **keep the floor ROOT-ANCHORED** in `.claude/settings.json` + in-repo `plugins/` so
   it clones and fires **without a marketplace round-trip** — a user-disablable,
   marketplace-installed plugin is not a floor.

### The one deliverable that makes "silently absent" → "visibly absent"

A **`/governance-health`** command (or SessionStart self-test) that, on any surface, actually
triggers each floor hook and reports which fired — the honest conformance check the matrix
promises. Pair with the matrix in `.docs/architecture/governance-threat-model.md`.

### Two hard boundaries the harness cannot cross (record, don't paper over)

- Cloud sessions are **unusable under org IP-allowlisting** (API called from Anthropic infra).
- Cloud **cannot push to non-GitHub remotes** (GitLab/Bitbucket/local bundle read-only).

### Native connectors coexist without collision

Desktop **connectors are MCP servers with a GUI**, stored at the **user** level; project
`.mcp.json` and plugin-provided MCPs resolve against them by the precedence chain
(**local > project > user > plugin > connectors**) — same-name = precedence, not clash. User
`~/.claude/` commands/skills/agents and user `enabledPlugins` **do not** carry to cloud (they're
your machine's, not the repo's) — exactly the intended never-touched boundary. **One override
vector to note**: project/user `.claude/agents/` **override same-named plugin agents**, so a
user could *shadow* a plugin agent — mitigated by keeping the FLOOR as hooks (not
user-shadowable) and namespacing plugin agents.

---

## 5. The Thin Core

**The core is ~20 files + the `loom-governance` plugin. Nothing else.** Everything not on this
list is a PACKAGE or the USER layer. (Full extraction *mechanics* — `${CLAUDE_PLUGIN_ROOT}`
vs `${CLAUDE_PROJECT_DIR}`, dependency-seam, versioning — are in `modular-harness-design.md`;
not repeated here.)

### Definitive irreducible-core file list

**FLOOR (enforcement, root-anchored):**
- `.claude/settings.json` (the hook wiring — plugin `settings.json` honors only
  `agent`/`subagentStatusLine`, so wiring **cannot** move into a plugin)
- `.claude/hooks/{guard-dangerous-commands.sh, freeze-write-scope.sh, worktree-port-namespace.sh,
  context-cap-warn.sh, user-prompt-submit/governance-preflight.sh}`
- `plugins/loom-governance/hooks/scripts/{protect-governance-files.sh, subagent-git-guard.sh,
  git-safety-gate.sh}` + `hooks.json`
- `.logic-loom/lib/{governance-verdicts.sh (the L2 verdict seam), policy.sh, logging.sh, json-parse.cjs}`
- `tests/contract/test_governance_verdicts.sh` (golden fixtures pinning floor behavior)

**CONSTITUTION CORE:** `.logic-loom/memory/constitution.md` (I–XVI) +
`constitution_update_checklist.md` + `.logic-loom/config/governance.conf`
(now **plus** the split: user amendments in `.logic-loom/memory/amendments.md` — §3b)

**SCAFFOLDING / BRIDGE / UPDATE:** `.logic-loom/scripts/bash/{sync-plugin-commands.sh,
constitutional-check.sh, common.sh, load-context.sh}`; `loom-maintenance`'s
`extract-proposals.sh` + `/update-framework`; `.sdd-sync-ref` +
`.logic-loom/config/framework-upstream.conf`; **the `marketplace.json` to be ADDED** (§6).

The `loom-governance` **plugin** itself keeps only **safely-removable assists** (domain briefs,
compliance skills, the `constitutional-check` validator) — enforcement never depends on the
plugin being enabled, because the root floor gates everything ambiently.

### Extract / adopt plan (build almost nothing)

| Capability | Verdict | Why |
|---|---|---|
| The just-built **project-graph** (`build-graph-bridge.sh`, `lint-graph.sh`, `/graph` skill+command) | **EXTRACT to `loom-graph` pack; point at Understand-Anything + Codegraph** | Clearest "adopt-existing" correction: bespoke harvester duplicates a maintained Claude Code plugin (Understand-Anything v2.5.0). The graph's own design already concedes the code half should be an opt-in external MCP. Keep loom-memory's `[[wikilink]]`/`SUPERSEDES` edges as a **git-tracked Karpathy-style wiki** (formalize in place, no DB/daemon/LLM extraction — per `graph-design.md`) |
| Code comprehension | **ADOPT Understand-Anything** (external plugin) | Maintained, multi-tool; don't grow a bespoke code-graph |
| Workflow packs (`loom-orchestrator`, `sdd-specification`) + tooling (`loom-creation`, `loom-git`, `loom-maintenance` command surface, `loom-memory`, `loom-orchestrator-hook` skill) | **KEEP as packs** | LogicLoom-specific; already plugins; clean star-graph rooted at `loom-governance` |
| `loom-memory` backends (BM25/vector/hybrid) | **Candidate to lean on an existing memory tool later** (open, not now) | Next extract candidate after graph; today keep the wiki |

---

## 6. Two-Tier Updates

Two update paths, **different scopes, no competition** — composed cleanly:

| Concern | Owner | Mechanism | Customization safety |
|---|---|---|---|
| The **CORE** the user may 3-way customize (`settings.json`, hooks, constitution core, scaffolding) | **`/update-framework`** | `extract-proposals.sh` 3-way merge, driven by `.sdd-sync-ref`, **scoped by `core-paths.manifest`** (§3c) | Writes **only** CORE globs; denylist demotes user paths to info-only; gitignored sinks are invisible |
| Cherry-pickable **PACKAGES** | **native `/plugin update`** | Per-pack, off root **`marketplace.json`** (currently **MISSING** — the single biggest gap; no `marketplace.json` exists anywhere, verified) with per-plugin `version` pins + `dependencies` | Overwrites only the cached plugin copy; never repo source; namespacing prevents collision |
| **USER** layer | — | Nothing | Survives both by construction |

`marketplace.json` (one file, `metadata.pluginRoot:"./plugins"`, relative sources; the repo
becomes template **and** its own marketplace) delivers the two-tier model for free — packs
update via `/plugin update`, core via `/update-framework`, user untouched. **Omit
`loom-governance` from `plugins[]`** (the floor is invisible template content, safest against
accidental uninstall). Per-pack `<plugin>--v<ver>` tags ride the existing `/promote` flow.

**How a project stays customization-safe across a core bump:** `/update-framework` reads
`core-paths.manifest` → proposes only CORE globs → the constitution split keeps amendments out
of the overwritten file → gitignored `settings.local.json`/`CLAUDE.local.md` are never in the
diff → user plugins/commands in `~/.claude` are out-of-repo. Nothing the user authored is on
the table.

---

## 7. Phased Path (each step small + reversible)

| Phase | Action | Reversible by |
|---|---|---|
| **P0** | **`.gitignore` fix** (§3d): add `.claude/settings.local.json` + `CLAUDE.local.md`. Pure prerequisite, unblocks the whole preservation model | Delete two lines |
| **P1** | **Constitution split** (§3b): add `amendments.md` (empty user file), rewrite Amendment Process to route additions there, wire `governance-preflight`/`load-context` to inject core ∪ amendments, add the two lints (I–III hard-fail; in-place-edit warn) | Re-merge one file |
| **P2** | **`core-paths.manifest`** (§3c) + one `extract-proposals.sh` filter (demote denylist to info-only). Turns the update boundary declared+strict | Delete manifest + filter |
| **P3** | **Add `marketplace.json`** (§6) listing the packs, omit governance, `defaultEnabled:false` for heavier packs; validate `claude plugin validate .` | Delete one file |
| **P4** | **Adopt the first existing pack** — extract `loom-graph`, point it at Understand-Anything/Codegraph (the `modular-harness-design.md` pilot); prove "adopt-existing" end-to-end on the lowest-risk unit | Move files back |
| **P5** | **`/governance-health` self-check + per-surface matrix** in `governance-threat-model.md`; retire the stale "cloud floor absent" memory note | Docs-only |

Sequencing rule: **preservation prerequisites first** (P0–P2, cheap + high-value), *then*
the modular/adopt work (P3–P4), *then* the honesty surface (P5). Never package the
hook-enforced floor as a removable plugin.

---

## 8. Anti-Overbuild Guardrails + Open Decisions

### Guardrails (native-only)

- **No bespoke merge / overlay / package-manager / resolver / lockfile / pack state-file.** Every
  requirement maps to a native primitive: layered `settings.json`/`settings.local.json`,
  `CLAUDE.md` imports + `CLAUDE.local.md`, `/plugin`, `marketplace.json`, `dependencies[]`,
  `<plugin>--v<ver>` tags, `.gitignore`. The customization model is **filters + conventions**.
- **Do NOT rebuild the cut `sdd-marketplace` MCP.** Do NOT rebuild the graph — **adopt**
  Understand-Anything; keep loom-memory as a git-tracked wiki (no DB/daemon/LLM extraction).
- **The floor stays root-anchored.** A plugin can be `/plugin disable`d; a root hook cannot.
  Keep the deliberate dual-wiring; never list governance in `plugins[]`.
- **Tripwires:** a resolver/lockfile appears → stop (source pins + tags *are* the lock); a
  running process/port/daemon/file-watcher appears → stop (template-distribution bar); a
  proposal writes into a USER-denylist path → the filter is broken; repo-relative paths inside
  a plugin → breaks on cache-install (use `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PROJECT_DIR}`); an
  LLM enters the graph extraction path → GraphRAG overbuild.

### Open decisions (need the user's call)

1. **Effective-constitution wiring**: confirm `governance-preflight.sh` + `load-context.sh`
   are the two loaders to inject `constitution.md ∪ amendments.md` (needs a one-file read of
   where the constitution is sourced into context today).
2. **`amendments.md` protection**: should `protect-governance-files.sh` add `amendments.md` to
   its ask/deny surface (user-owned but governance-adjacent), and should the I–III lint
   **hard-fail** vs warn?
3. **Where amendments physically live**: `.logic-loom/memory/amendments.md` **tracked** (travels
   with the repo, shared with a team, on the manifest denylist) vs a gitignored per-machine file
   (private). Tracked+denylisted is recommended (team-shared, still never overwritten).
4. **Cloud floor — empirical confirm**: the docs say repo hooks clone+fire in cloud; run one
   trivial PreToolUse `deny` hook in a cloud session to *prove* it before advertising uniform
   enforcement, and check whether managed-settings `allowManagedHooksOnly` silently de-authorizes
   a cloned repo's hooks under an org policy.
5. **`guard-dangerous-commands.sh` degrade**: read the script to state exactly whether it
   re-execs into bash-4+ or just fails open — the matrix cell depends on it.
6. **Governance visibility in `marketplace.json`**: omit (recommended, safest) vs list with an
   "install-only" note.
7. **`loom-memory` backends**: keep the wiki now; is the BM25/vector backend the next
   adopt-existing candidate, or does it stay bundled?

---

## Sources

**Native docs (2026):**
- `code.claude.com/docs/en/settings` — 5-layer precedence (Managed>CLI>Local>Project>User),
  arrays concatenate + dedupe, `settings.local.json` auto-gitignore + workspace-trust skip,
  `--setting-sources`.
- `code.claude.com/docs/en/memory` — CLAUDE.md concatenation (root→cwd, CLAUDE.local.md appended
  AFTER), `@`-imports (relative/`@~`, depth 4, skips code spans), CLAUDE.local.md worktree caveat
  + `@~/.claude/...` pattern, managed-policy CLAUDE.md.
- `code.claude.com/docs/en/claude-code-on-the-web` — cloud carry-over table (settings.json hooks
  / `.mcp.json` / skills+agents+commands = "Part of the clone"), SessionStart-in-cloud,
  git-creds-outside-sandbox + proxy, IP-allowlist breaks cloud, non-GitHub can't push.
- `code.claude.com/docs/en/hooks` — shell contract (`sh -c` mac/linux, Git Bash on Windows,
  PowerShell when absent), exit-code contract, `permissionDecision`, `$CLAUDE_CODE_REMOTE`.
- `code.claude.com/docs/en/desktop` — CLI↔Desktop parity (hooks/skills/MCP apply to both),
  connectors = MCP-with-GUI, Windows needs Git for Windows, worktree isolation, managed settings.
- `code.claude.com/docs/en/plugins(-reference)` — plugin hooks run + **can block**;
  `hooks`/`mcpServers`/`permissionMode` unsupported for plugin **agents**; project/user agents
  override plugin agents; `marketplace.json`; `version`/`dependencies`/`defaultEnabled`.
- `code.claude.com/docs/en/vs-code` — extension bundles the `claude` binary, same engine/hooks.
- `code.claude.com/docs/en/mcp` — MCP precedence local>project>user>plugin>connectors.
- `github.com/anthropics/claude-code` #18088 (cloud plugin-install flaky), #35575 (disabled
  plugins can mis-register hooks).
- `github.com/Lum1104/Understand-Anything` — v2.5.0 (May 2026), the adopt-existing
  code-comprehension pack.

**Repo (verified this session):**
- `.gitignore` lines 48–49 (`.local/`, `*.local`) — glob test confirms **neither**
  `settings.local.json` **nor** `CLAUDE.local.md` matches (portability bug, §3d).
- No `marketplace.json` and no root `.claude-plugin/` exist anywhere (verified — §6 gap).
- `.logic-loom/memory/` = `constitution.md`, `constitution_update_checklist.md`,
  `agent-governance.md`, `agent-collaboration-triggers.md`, `skill-activation-triggers.md` —
  **no `amendments.md`** (split doesn't exist yet, §3b).
- `constitution.md` — Amendment Process at line 260 (step 4 mutates the same file); "Immutable
  principles (I–III) cannot be amended or overridden"; line 251 marks `loom-governance`
  "Never (protected)".
- `.logic-loom/scripts/bash/template-strip-manifest.txt` present (grammar template for
  `core-paths.manifest`).
- `.logic-loom/config/` = `architecture.conf`, `framework-upstream.conf`, `governance.conf`,
  `models.conf` (no `core-paths.manifest` yet).
- Prior designs: `features/modular-harness/exploration/modular-harness-design.md`;
  `features/code-knowledge-graph/exploration/graph-design.md`.
