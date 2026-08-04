# Modular Harness Design — Cherry-Pickable Packs over a Fixed Governance Core

**Status**: exploration / design proposal (no code changed)
**Date**: 2026-07-05
**Feature**: `features/modular-harness/`
**Pilot**: `loom-graph` (extract the just-built graph Phase 1 into a standalone plugin)

> This doc consolidates a five-slice research landscape on making LogicLoom's
> capabilities cherry-pickable via the **native** Claude Code plugin marketplace,
> without weakening the hook-enforced governance floor and without rebuilding the
> already-cut `sdd-marketplace` MCP.

---

## 1. Topline

Split LogicLoom into a **fixed mandatory CORE** — the hook-enforced governance
floor that ships with the template and can never be uninstalled — and a set of
**cherry-pickable PACKS** that a project adds, removes, and updates individually.
Deliver this with exactly **one native mechanism, one new file**: a
`.claude-plugin/marketplace.json` at the repo root listing the existing
`plugins/*` (the repo becomes *both* a GitHub template *and* its own marketplace),
so every capability is installable via `/plugin install|enable|disable|update` with
per-plugin versions and native auto-update — replacing the all-or-nothing
`/update-framework` *for packs* while `/update-framework` is retained for the
in-tree core it can safely 3-way-merge. Governance stays enforced when packs are
optional because the **floor is HOOKS wired in root `.claude/settings.json`**
(root-anchored, not install-scoped, so `/plugin uninstall` can't reach it); a pack
ships **zero enforcement hooks** and is governed *ambiently* the instant its
tool calls hit the PreToolUse gates, and it declares `dependencies: ["loom-governance"]`
so native resolution blocks disabling the core out from under it. The **graph
feature is the pilot**: it's advisory, fail-open, read-only, never-git, needs no
hooks — so it proves the whole packaging pattern (`${CLAUDE_PLUGIN_ROOT}` for
plugin code, `${CLAUDE_PROJECT_DIR}` for project data, a self-verifying contract
test that travels with the plugin) on the lowest-risk unit before anything
touches the floor.

**The one premise this corrects (load-bearing):** the prior finding "plugins lose
hooks" is scoped to plugin-shipped **AGENTS** only. Plugin **hooks** (`hooks.json`)
execute and can block. Governance *could* technically be a plugin — but it
**must not be**, because any installed plugin is user-disablable and plugin
`settings.json` honors only `agent`/`subagentStatusLine`. So the floor stays a
root-anchored template artifact; packs are the removable plugins.

---

## 2. The core-vs-modular split

Anchored on the **already-declared** dependency graph rooted at `loom-governance`
(`loom-creation/git/maintenance/orchestrator/sdd-specification` all declare
`dependencies: ["loom-governance"]`; `loom-governance/loom-memory` declare `[]`).

### 2a. What is the irreducible MANDATORY CORE (ships in template, never removable)

The core is **not a plugin** — it is a set of **root-anchored files** wired in
`.claude/settings.json`. `/plugin uninstall` cannot reach it because it is not
install-scoped. This is the true meaning of "governance core = a fixed floor."

| Core element | Path (verified) | Why it can't be a removable plugin |
|---|---|---|
| Constitution | `.logic-loom/memory/constitution.md` | The policy the verdicts encode; a followed-only doc if the floor is disablable. |
| Verdict seam | `.logic-loom/lib/governance-verdicts.sh` | Single `allow\|ask\|deny` source; self-protected + fail-safe. The real portability backbone. |
| Git-safety gate | `plugins/loom-governance/hooks/scripts/git-safety-gate.sh` | PreToolUse·Bash; wired by literal path in settings.json:63. Floor cannot have an off-switch. |
| Subagent-git deny | `.../subagent-git-guard.sh` | settings.json:58. Same reason. |
| Governance-file protect | `.../protect-governance-files.sh` | settings.json:38,53. The model can't soften its own rules. |
| Freeze write-scope | `.claude/hooks/freeze-write-scope.sh` | settings.json:43. Plan-as-DAG ownership. |
| Dangerous-command guard | `.claude/hooks/guard-dangerous-commands.sh` | settings.json:68. |
| Preflight (context floor) | `.claude/hooks/user-prompt-submit/governance-preflight.sh` | settings.json:21. Domain + memory injection. |
| The wiring itself | `.claude/settings.json` | Plugin `settings.json` only honors `agent`/`subagentStatusLine` — permissions/hook-wiring is **not** portable into a plugin. |

> **CRITICAL nuance (verified):** the active floor is wired in `settings.json` by
> **literal path** to `plugins/loom-governance/hooks/scripts/*.sh` and
> `.claude/hooks/*.sh`. The `loom-governance` plugin *also* ships its own
> `hooks/hooks.json` (3 hooks via `${CLAUDE_PLUGIN_ROOT}`) — but that is **not the
> load path today**; it is dormant/redundant. **Two wirings, out of sync**
> (settings.json wires 5 PreToolUse hooks; plugin hooks.json wires 3). The split
> forces picking **settings.json as the authoritative always-on floor** and
> de-duplicating the plugin `hooks.json` to avoid double-firing.

### 2b. What becomes a CHERRY-PICKABLE PACK (installable / removable)

| Pack (plugin) | Current version | Decisive reason it's removable |
|---|---|---|
| `loom-orchestrator` | 3.0.0 | Swarm/research/cross-check/plan-review/review-team/retro/teams — pure workflow, no enforcement surface. |
| `sdd-specification` | 2.0.0 | The whole SDD waterfall pack; opt-in (`defaultEnabled:false`). |
| `loom-creation` | 2.0.0 | `/create-*` tooling; not load-bearing for enforcement. |
| `loom-git` | 1.0.0 | `/git-push`, `/finalize` — user-facing; the *git gate* stays in the core, this is just the workflow. |
| `loom-maintenance` | 1.0.0 | `/update-framework`, `/initialize-project`, `/promote` — maintainer tooling. |
| `loom-memory` | 2.0.0 | Memory injection — classify per §8 (is any injection wired in settings.json → core? Today it isn't). |
| **`loom-graph`** (new) | 0.2.0 | **The pilot.** Advisory, fail-open, read-only, never-git, zero hooks. |

**The `loom-governance` PLUGIN** keeps only the **safely-removable ASSISTS**
(domain briefs, `constitutional-compliance`/`governance-preflight` skills, the
`constitutional-check` validator, the `constitutional-governance-agent`). None of
these are load-bearing for *enforcement* — if that plugin were ever disabled, the
**root floor still gates everything**; you'd only lose brief-injection and the
validator. Enforcement never depends on the plugin being enabled.

> **Non-native fields to drop:** `required:true` / `protected:true` in
> `loom-governance/.claude-plugin/plugin.json`, and the count-object
> `agents`/`skills` blocks, are **not recognized by Claude Code** (native manifest
> fields are `name`, `version`, `dependencies`, plus marketplace-only
> `source/category/tags/strict/relevance/defaultEnabled/displayName`). They are
> decorative. Replace their *intent* with the real mechanisms: floor-in-settings.json
> (un-removable) + `dependencies:["loom-governance"]` on every pack (resolver-blocked
> removal).

---

## 3. The governance-floor seam

**How an optional pack gets governed by the core without shipping its own hooks —
three native rules, zero re-shipped enforcement:**

**(a) DEPEND, don't duplicate.** Every pack's `plugin.json` declares
`dependencies: ["loom-governance"]` (LogicLoom already does this for 5 of 8
plugins). Native resolution (v2.1.143+) then (i) auto-installs + transitively
enables the governance plugin with the pack, and (ii) **blocks disabling/uninstalling
governance while any enabled pack still needs it** — the error even prints the
chained-disable command. That is the *entire* "removing a pack cannot weaken the
floor / core survives as packs come and go" guarantee, delivered by Claude Code,
not custom code.

**(b) INHERIT enforcement ambiently.** A pack ships **no PreToolUse hooks**. Its
skills/commands/workers make tool calls (`Write`/`Edit`/`Bash`) that the **root
floor already gates at the tool boundary** — regardless of *which plugin authored
the code*. `subagent-git-guard` fires on `agent_id` (provenance-agnostic);
`freeze-write-scope` confines writes to the DAG `owns:` scope;
`protect-governance-files` denies edits to the governance surface. The seam is
**"plug in by running under the same session," not "plug in by registering
hooks."** A pack is governed the instant it runs, for free.

**(c) The `loom-governance` plugin carries only assists.** (See §2b.) Enforcement
lives in the root floor, not the plugin.

### Resolving "plugin agents lose hooks" honestly

The Claude Code plugins reference states verbatim: *"For security reasons, `hooks`,
`mcpServers`, and `permissionMode` are not supported for plugin-shipped **agents**."*
That sentence is scoped to the **Agents** component. Separately, the **Hooks**
component runs fully: plugin `hooks.json` handlers "respond to the same lifecycle
events as user-defined hooks," and PreToolUse fires "Before a tool call executes.
**Can block it**." So:

- **A plugin *can* ship enforcing PreToolUse hooks.** The prior LogicLoom "governance
  can't be a plugin because it loses hooks" conclusion is **false for hooks** — it's
  true only for the constitutional-governance-**agent** (which is why the
  orchestrator-worker-ladder keeps `deep-reasoner`/`fast-worker` as *project*
  `.claude/agents/`, not plugin agents).
- **But governance still must not be a removable plugin**, for a *different* reason:
  a plugin the user can `/plugin disable` is not a floor. Plus a known live bug
  (`anthropics/claude-code#35575`) where even disabled plugins can mis-register
  hooks — a mandatory floor cannot have an off-switch. **Conclusion: keep the floor
  root-anchored in settings.json; the "plug into the floor" seam for packs is
  dependency declaration + ambient tool-boundary gating.**

Sources: `code.claude.com/docs/en/plugins-reference` (Hooks + Agents restriction);
`code.claude.com/docs/en/plugin-dependencies`; repo `.claude/settings.json`,
`plugins/loom-governance/hooks/hooks.json`, `.logic-loom/lib/governance-verdicts.sh`.

---

## 4. Distribution + update / versioning model

### Add / remove / update a pack — all NATIVE

```
/plugin marketplace add kelleysd-apps/LogicLoom     # clones whole repo → relative sources resolve
/plugin install  loom-graph@logicloom               # auto-installs loom-governance dep, namespaces /loom-graph:graph
/plugin update   loom-graph@logicloom               # skips if resolved version unchanged
/plugin disable  loom-graph@logicloom               # blocked if a dependent needs it
/plugin uninstall loom-graph@logicloom              # clean removal; project data (jsonl) left inert
```

### One repo = template AND marketplace (no split)

`isTemplate:true` and `.claude-plugin/marketplace.json` occupy **different files**
and don't conflict. The marketplace lives at repo root with **relative** sources
(`metadata.pluginRoot: "./plugins"` → each entry is just `"source": "loom-graph"`).
**A git-based add clones the whole repo, so relative paths resolve**; a bare
*URL-to-marketplace.json* add does **not** (only the JSON is fetched) — so the
documented add path is `owner/repo`, never a raw URL. Marketplace state is per-user
(`~/.claude/plugins/known_marketplaces.json`), resolves identically across worktrees.
Team auto-prompt: `extraKnownMarketplaces` + `enabledPlugins` in the shipped
`.claude/settings.json`.

### Reconciliation with dev-main→main promote + `/update-framework`

Keep **both update paths, re-scoped** — they cover different scopes and don't compete:

| Concern | Owner | Why |
|---|---|---|
| Cherry-pickable PACKS | **native `/plugin update`** | Clean install/update/remove; overwrites the cached plugin copy wholesale. |
| In-tree CORE the user customizes | **`/update-framework`** (`extract-proposals.sh` 3-way merge) | `constitution.md`, `settings.json`, `.claude/hooks/*`, governance scripts, framework config/docs — native `/plugin` **can't** safe-merge these. Drive via `.sdd-sync-ref`. |

**`promote-to-main.yml` changes are minimal and mostly additive** (verified):
1. `marketplace.json` + `plugins/*/.claude-plugin/plugin.json` are just tracked
   content — they ride the single-parent sanitized snapshot automatically. **Verified
   the strip manifest does NOT strip `.claude-plugin/` or `plugin.json`** — no change
   needed there, but keep it audited.
2. **ADD a per-pack tag step**: after compose, for each pack whose version changed,
   create `<plugin>--v<version>` and push (analogous to existing `release-tag.yml`).
   Native dependency version-constraints + release channels resolve off these tags.
3. Single-parent + sanitization invariants **unchanged**.

### Per-pack versioning

Version resolves from (1) `plugin.json` `version`, (2) marketplace-entry `version`,
else (3) git commit SHA. LogicLoom's plugin.json files **already carry versions**,
which **pins them** — pushing commits without bumping the string does nothing for
existing users (the documented "stale manifest masks updates" trap). Two models:

- **(B) explicit semver (recommended)** — keep `version`, **bump on every pack
  release** + tag `<plugin>--v<ver>`; enables dependency version constraints
  (`{name:"loom-governance", version:"~1.0.0"}`). Aligns with LogicLoom's deliberate
  `/promote` releases and prevents a governance bump silently breaking packs.
- (A) SHA-tracking — omit `version`; every commit = new version. Simpler but loses
  semver constraints.

> **Do NOT rebuild a lockfile / resolver / catalog service.** Source ref/sha pins
> + semver ranges + `<plugin>--v<ver>` tags **are** the native lock. Container/CI
> pre-seed is native too (`CLAUDE_CODE_PLUGIN_SEED_DIR`). Any proposal that adds a
> resolver or a pack state-file is **`sdd-marketplace` drift — reject on sight.**

---

## 5. Pilot: the `loom-graph` plugin

The graph capability is the **safest possible first extraction**: advisory,
fail-open, read-only, never-git → **zero hooks/mcpServers/permissionMode**, so it
dodges the agent-strip failure entirely. It's currently mis-grouped (its scripts
live under `.logic-loom/scripts/bash/`, its command under `loom-orchestrator` — and
graph is **not even listed** in `loom-orchestrator`'s `commands` manifest, confirming
it's a newer add that never belonged there). Extracting it **removes a mis-grouping**.

### The one load-bearing lesson it proves

Installed plugins are **copied to `~/.claude/plugins/cache`**; **any repo-relative
path (`.logic-loom/scripts/...`) breaks the moment the plugin is cache-installed
instead of bundled in the template.** So split every capability into:

- **Plugin-owned CODE** → addressed via `${CLAUDE_PLUGIN_ROOT}` (travels in the cache).
- **Project-owned DATA** → addressed via `${CLAUDE_PROJECT_DIR}` (git-tracked in the
  consuming repo). *(Not `${CLAUDE_PLUGIN_DATA}` — that survives plugin updates but
  lives in the plugin's private area; the graph manifest is project source and must
  be git-tracked in the project.)*

### Layout

```
plugins/loom-graph/
├── .claude-plugin/plugin.json      # name loom-graph, version 0.2.0, dependencies:["loom-governance"]
├── commands/graph.md               # moved from loom-orchestrator; rewrite 2 call sites (below)
├── skills/project-graph/SKILL.md   # moved; rewrite the "Common paths" block (lines 84-97)
├── scripts/
│   ├── build-graph-bridge.sh       # moved from .logic-loom/scripts/bash/ — UNCHANGED internally
│   └── lint-graph.sh               # moved — UNCHANGED internally
├── templates/obsidian/             # README.md, covers-convention.md, graph.json (moved)
├── docs/project-graph-convention.md# portable convention ships WITH the capability
├── tests/test_graph_bridge.sh      # moved from tests/contract/; retarget to ${CLAUDE_PLUGIN_ROOT}
└── README.md
```

### The exact three call-site rewrites (everything else is a file move)

The scripts are **already parameterized** — `build-graph-bridge.sh` takes
`[CORPUS_ROOT] [--out FILE]`, `lint-graph.sh` takes `[JSONL] [--root REPO_ROOT]`
(verified). Only the **callers** stop hard-coding repo-relative paths:

1. **`commands/graph.md` build** (currently line 30):
   `.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl`
   →
   `"${CLAUDE_PLUGIN_ROOT}"/scripts/build-graph-bridge.sh "${CLAUDE_PROJECT_DIR}" --out "${CLAUDE_PROJECT_DIR}/.logic-loom/graph/graph-bridge.jsonl"`
2. **`commands/graph.md` lint** (line 53) →
   `"${CLAUDE_PLUGIN_ROOT}"/scripts/lint-graph.sh "${CLAUDE_PROJECT_DIR}/.logic-loom/graph/graph-bridge.jsonl" --root "${CLAUDE_PROJECT_DIR}"`
3. **`skills/project-graph/SKILL.md`** "Common paths" block (lines 84-97) — same two
   substitutions; the `SKILL ACTIVATION` path in `graph.md:11-12` becomes
   `plugins/loom-graph/skills/project-graph/SKILL.md`.

> The scripts derive a default `ROOT` from `BASH_SOURCE` (`scripts/bash → .logic-loom
> → repo root`) — **no longer correct in the cache**, so callers **must pass explicit
> `${CLAUDE_PROJECT_DIR}`**. They fail-open if the root is wrong, so this is safe.

### Contract test travels inside the plugin

`tests/contract/test_graph_bridge.sh` currently resolves `BUILDER`/`LINTER` as
repo-relative after `cd $(git toplevel)`. Move it to
`plugins/loom-graph/tests/test_graph_bridge.sh` and point `BUILDER`/`LINTER` at
`${CLAUDE_PLUGIN_ROOT:-<script-relative>}/scripts/`. It already builds a throwaway
corpus in `mktemp -d` (hermetic), so it just stops assuming a repo path — and
`/plugin install loom-graph` then delivers a **self-verifying unit**. Repo-root
`tests/contract/` becomes the CORE's test surface only.

### plugin.json

```json
{
  "name": "loom-graph",
  "version": "0.2.0",
  "description": "Project-wide code+docs knowledge graph — advisory, fail-open, read-only, never-git.",
  "dependencies": ["loom-governance"]
}
```

### Install / remove behavior (clean by construction)

- **ADD**: `/plugin install loom-graph@logicloom` auto-installs `loom-governance`,
  namespaces `/loom-graph:graph`, resolves scripts via `${CLAUDE_PLUGIN_ROOT}`; first
  `/graph build` writes `.logic-loom/graph/graph-bridge.jsonl` into the project.
- **REMOVE**: `/plugin uninstall loom-graph` clears commands/skills/scripts from cache;
  the `.logic-loom/graph/graph-bridge.jsonl` artifact remains as **inert git-tracked
  text** (nothing reads it once `/graph` is gone).
- **Consumer degrades cleanly**: `loom-git`'s `finalize.md` **already guards** with
  `[ -x build-graph-bridge.sh ]` and prints `graph-lint: skipped` (verified
  lines 43-49). A missing `loom-graph` → finalize prints "skipped." **This
  fail-open/test-and-skip consumer pattern is exactly what makes clean removal
  possible** — the one cross-plugin seam to preserve.

### The bridge vs. native discovery

`sync-plugin-commands.sh` generates `.claude/commands/<name>.md` wrappers whose body
is *"read and execute `plugins/loom-graph/commands/graph.md`"* — **intrinsically
repo-relative**, so it works in bundled-template mode but is **redundant AND wrong**
after a marketplace install (native install auto-namespaces `/loom-graph:graph`).
**Keep the bridge only for the bundled-template experience;** it does not survive
marketplace install. The one UX decision: accept namespaced `/loom-graph:graph`
(native default) or keep a thin bridge for flat `/graph` (see §8).

---

## 6. Phased path (each phase small + reversible)

| Phase | Action | Reversible by |
|---|---|---|
| **P0** | Reconcile the double hook wiring: make `.claude/settings.json` the authoritative floor; demote/prune `loom-governance/hooks/hooks.json` enforcement entries to avoid double-firing. *(Governance-file edit — main-agent + user-approval; out of this doc's write scope.)* | Restore hooks.json |
| **P1 — PILOT** | Extract `loom-graph` (§5): move files, rewrite the 3 call sites to `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PROJECT_DIR}`, move the contract test in. No marketplace yet — validate in bundled mode + `claude plugin validate`. | Move files back |
| **P2** | Generalize the packaging pattern into `/create-plugin` (plugin-owned code via `${CLAUDE_PLUGIN_ROOT}`, project data via `${CLAUDE_PROJECT_DIR}`, test-travels-with-plugin) so future packs are born correct. | Docs-only |
| **P3** | Author `.claude-plugin/marketplace.json` (`metadata.pluginRoot:"./plugins"`), list all packs, **omit governance** (floor is invisible template content), `defaultEnabled:false` for SDD/heavier packs. Validate with `claude plugin validate .`. | Delete one file |
| **P4** | Migrate the update model: re-scope `/update-framework` docs + `extract-proposals.sh` to CORE paths only; wire per-pack `<plugin>--v<ver>` tagging into `/promote`; upgrade bare-string deps to semver objects. | Revert scope |
| **P5** *(optional)* | Extract more advisory packs (research/cross-check/retro) the same way; leave hook-enforced core untouched. | Per-pack move-back |

**Sequencing rule:** extract **no-hook advisory** capabilities first (graph → research
/cross-check/retro); never package the hook-enforced core as a removable plugin.

---

## 7. Anti-overbuild guardrails + tripwires

- **DO NOT rebuild the cut `sdd-marketplace` MCP** or any bespoke package manager,
  catalog service, resolver, or pack state-file. Every requirement maps to a native
  primitive (`/plugin`, `marketplace.json`, `dependencies[]`, `<plugin>--v<ver>` tags,
  `extraKnownMarketplaces`, `CLAUDE_CODE_PLUGIN_SEED_DIR`).
- **DO NOT make the enforced floor optional.** The floor stays root-anchored in
  `.claude/settings.json` + `.claude/hooks/` + `constitution.md` + `governance-verdicts.sh`.
  Never list governance in the marketplace `plugins[]`.
- **DO NOT move permissions/settings into a plugin** — plugin `settings.json` honors
  only `agent`/`subagentStatusLine`.
- **Tripwire — bespoke version machinery:** if a proposal adds a lockfile or a
  resolver, stop — source pins + semver ranges + tags are the native lock.
- **Tripwire — floor duplication drift:** the settings.json vs plugin `hooks.json`
  double-wiring must be reconciled to ONE authoritative path (P0), or hooks double-fire
  and drift.
- **Tripwire — repo-relative paths in a pack:** any `../` or `.logic-loom/...` path
  inside a plugin silently breaks on cache-install. Every plugin path must be
  `${CLAUDE_PLUGIN_ROOT}`- or `${CLAUDE_PROJECT_DIR}`-anchored.
- **Tripwire — un-guarded cross-pack calls:** a consumer that hard-calls another pack's
  scripts breaks on removal. Every cross-pack reference must be fail-open test-and-skip
  (as `finalize.md` already is).

---

## 8. Open decisions (need the user's call before building)

1. **Exact core boundary — `loom-memory` + preflight:** is memory injection wired in
   `settings.json` (→ CORE) or purely user-facing (→ cherry-pickable pack)? Today no
   memory hook is in settings.json, suggesting it's a pack — confirm per-plugin
   classification.
2. **Governance visibility in the marketplace:** **omit** governance from `plugins[]`
   (floor is invisible template content — safest against accidental uninstall) vs.
   **list it** with an "install-only, never uninstall" note (more transparent).
   Recommendation: omit.
3. **Command namespacing UX:** accept native `/loom-orchestrator:swarm` /
   `/loom-graph:graph`, or keep the repo-relative bridge for flat `/swarm` / `/graph`?
   Native sheds custom machinery; flat needs the bridge (or top-level command names).
   **This is the main UX decision the migration forces.**
4. **Migrate vs. keep `/update-framework`:** the recommendation is **keep both,
   re-scoped** (native `/plugin` for packs; `/update-framework` for the customizable
   core). Confirm you don't want to fully retire `/update-framework`.
5. **Marketplace-only consumers get no floor:** a user who adds LogicLoom's marketplace
   to an *existing* project gets the packs but **NOT** the root floor (settings.json
   isn't shipped by `/plugin install`). Decide: is LogicLoom **template-for-floor +
   marketplace-for-packs** (hybrid), and how does a marketplace-only consumer get an
   *enforced* floor rather than followed-only policy?
6. **Per-plugin tag discipline in `/promote`:** adding `<plugin>--v<ver>` tags means
   multiple tags per release — confirm it doesn't collide with `release-tag.yml`'s
   single-framework-version tag or the `.sdd-sync-ref` advance.
7. **P0 is a governance-file edit** (settings.json / plugin hooks.json) — main-agent +
   user-approval only; explicitly out of this doc's write scope.

---

## Sources

**Native docs (2026):**
- `https://code.claude.com/docs/en/plugin-marketplaces` — marketplace.json schema,
  `metadata.pluginRoot`, relative-vs-URL source resolution, version resolution +
  release channels, `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}`, cache-copy note,
  `extraKnownMarketplaces`, `CLAUDE_CODE_PLUGIN_SEED_DIR`, `defaultEnabled` (v2.1.154+).
- `https://code.claude.com/docs/en/plugins-reference` — Hooks run + can block;
  "`hooks`/`mcpServers`/`permissionMode` not supported for plugin-shipped **agents**";
  plugin `settings.json` honors only `agent`/`subagentStatusLine`; skills-directory plugins.
- `https://code.claude.com/docs/en/plugin-dependencies` — `dependencies[]` auto-install,
  transitive enable (v2.1.143+), disable-blocked-while-needed, version constraints
  (v2.1.110+), `<plugin>--v<ver>` tags.
- `https://code.claude.com/docs/en/discover-plugins` — `/plugin install|enable|disable|update`, namespacing.
- `https://github.com/anthropics/claude-code/issues/35575` — disabled plugins can mis-register hooks.

**Repo (verified this session):**
- `.claude/settings.json` (floor wired by literal path — 5 PreToolUse hooks)
- `plugins/loom-governance/hooks/hooks.json` (dormant redundant 3-hook wiring)
- `.logic-loom/lib/governance-verdicts.sh` (verdict seam)
- `plugins/*/.claude-plugin/plugin.json` (dep graph rooted at loom-governance; non-native `required`/`protected`)
- `plugins/loom-orchestrator/commands/graph.md` (call sites :30,:53; graph absent from orchestrator `commands`)
- `plugins/loom-orchestrator/skills/project-graph/SKILL.md` (Common-paths :84-97)
- `.logic-loom/scripts/bash/build-graph-bridge.sh` (already `[ROOT] [--out]`)
- `.logic-loom/scripts/bash/lint-graph.sh` (already `[JSONL] [--root]`)
- `plugins/loom-git/commands/finalize.md` (guarded fail-open consumer :43-49)
- `tests/contract/test_graph_bridge.sh` (hermetic tmpdir; repo-relative BUILDER/LINTER)
- `.logic-loom/scripts/bash/sync-plugin-commands.sh` (repo-relative wrappers :82,:94)
- `.github/workflows/promote-to-main.yml` + `template-strip-manifest.txt` (manifests NOT stripped — verified)
- `.logic-loom/graph/graph-bridge.jsonl` (project-data artifact; regenerated per-project)
