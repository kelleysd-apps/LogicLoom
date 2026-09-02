# Model Selection Policy

**Status**: active · **Since**: 2026-07-02 · **Authority**: Constitution
Principle XIV (AI Model Selection, which also states the provider boundary),
Principle X (Delegation) · **Config**: `.logic-loom/config/models.conf` ·
**See also**: `.docs/architecture/orchestrator-worker-ladder.md`

This is the canonical policy for how LogicLoom selects models. It consolidates a
four-surface audit (frontmatter executables, cross-provider verification layer,
config/scripts/schemas, documentation prose) into one governing document.

---

## 1. Principle

**Every LogicLoom agent, command, and skill selects a model by ROLE/TIER keyword —
never a pinned version string.** The tier keywords are:

| Keyword | Meaning |
|---|---|
| `frontier` | Orchestrator class (any frontier-grade Anthropic model). No frontmatter keyword exists — set via `/model` on the main session. |
| `opus` | Most-capable reasoning tier — default for specialized agents, architecture, security. |
| `sonnet` | Balanced tier — cost optimization, high-volume mechanical work. |
| `haiku` | Cheap/fast tier — memory injection, quick lookups, formatting. |
| `inherit` | Take the invoking context's model. |

Tier keywords are **self-updating**: when a new Anthropic model ships in a class,
the keyword resolves to it at runtime with zero edits to agents/commands/skills.
That is the entire point — it is why the keywords, not pinned ids, are the
functional selection layer.

**Concrete model ids live in EXACTLY ONE canonical place: `.logic-loom/config/models.conf`.**
Every other occurrence of a concrete id is either (a) reference prose that must be
kept in sync, or (b) drift to be removed. models.conf is a *documentary reference
table* — no runtime resolver parses it (verified: zero consumers of
`FLAGSHIP_MODEL`/`FRONTIER_MODEL`/`LOOM_MODEL_*` across scripts, hooks, plugins).
The tier keywords in frontmatter do the actual work; models.conf records the
role→tier→id map for humans and for the bump procedure.

### Audit finding: frontmatter is already 100% tier-based

The executable-surface audit confirms **all 24 `model:` frontmatter fields**
across `.claude/agents/*.md`, `plugins/**/agents/*.md`, and
`plugins/**/commands/*.md` are tier keywords (`opus`/`sonnet`/`haiku`/`inherit`) —
**zero pinned version strings in any frontmatter**. The Task-spawn `model:` fields
inside command bodies (`research.md` lines 154, 174) also use the tier keyword
`opus`. Skills correctly carry no `model:` field (they inherit the invoking
context). This clean state is the invariant the guard in §5 exists to preserve.

Every remaining pinned id is in a **body, config snippet, or doc prose** — not a
selector. Those are the gaps §3 closes.

---

## 2. Single source of truth

`.logic-loom/config/models.conf` is canonical for concrete ids. It already holds
the Anthropic tier→id map (`frontier`/`opus`/`sonnet`/`haiku`). It is **missing**
the cross-provider verification-layer ids, which today are hardcoded inline in
`research.md`. Fix: give models.conf a clearly-marked advisory section so BOTH
`/research` and `/cross-check` read one place.

### Design: add an "Advisory cross-provider models" section to models.conf

Append a section to `.logic-loom/config/models.conf`, fenced with a loud boundary
banner so no reader mistakes it for an orchestration tier:

```conf
# =====================================================================
# ADVISORY CROSS-PROVIDER MODELS  —  VERIFICATION LAYER ONLY
# ---------------------------------------------------------------------
# These are NOT orchestration tiers. They are the non-Claude models the
# delegated verification layer may call. Held strictly ADVISORY +
# READ-ONLY (Principle VI): they emit findings; a governed Claude agent
# triages and decides. They NEVER write repo source, run git, or make a
# control-flow decision. Only two consumers may read this section:
#   - /research    (jury-on-demand tribunal judges)
#   - /cross-check (governed adversarial reviewer)
# Selected by provider ROLE; the id is a refreshable default, overridable
# via the matching .env var. Bumping an id here must NOT change the fact
# that these stay advisory-only.
# =====================================================================

# role -> default id            (.env override var, shared by /research + /cross-check)
XPROVIDER_OPENAI_MODEL = gpt-5.5                         # CROSS_CHECK_OPENAI_MODEL
XPROVIDER_GEMINI_MODEL = gemini-3.1-pro-preview          # CROSS_CHECK_GEMINI_MODEL
XPROVIDER_CODEX_MODEL  = <codex default per plugin>      # CROSS_CHECK_CODEX_MODEL
# No Mistral id is pinned anywhere today; add here only when a consumer needs it.
```

Notes on the design:

- **Preserves the boundary.** The banner restates the Principle VI advisory-only
  contract inline, so the section can never be misread as adding a non-Claude
  orchestration tier. Adding these ids does not weaken the boundary — the
  boundary is about *what the model is allowed to do* (advisory, read-only), not
  about *where its id is written down*.
- **`/cross-check` already does this correctly** and is the model to mirror: it
  names providers by lineage (`codex`/`openai`/`gemini`), uses a `<model>`
  placeholder in the endpoint, and defers to `CROSS_CHECK_OPENAI_MODEL` /
  `CROSS_CHECK_GEMINI_MODEL` overrides. Its only weakness is that its default is
  prose-only ("a current coding-grade model") — this section supplies the
  concrete named default it lacks.
- **`/research` is the offender** and must be brought to the same pattern: it
  hardcodes `gpt-4o` (3 load-bearing sites) and the dated preview id
  `gemini-2.5-pro-preview-05-06` (2 load-bearing sites) inline in spawn prompts,
  with no override path at all. It should reference this section, not the literals.
- **Gemini de-preview.** The dated `gemini-2.5-pro-preview-05-06` (which rots fastest)
  was removed; the default is now the undated rolling alias `gemini-3.1-pro-preview`
  (current most-capable reasoning). Undated aliases roll forward; dated snapshots rot.
- **Per-run selection.** `/research` accepts `--openai-model` / `--gemini-model` /
  `--claude-model` flags (precedence **flag → env → default**), so a caller can pick
  any current provider model per invocation without editing config.

The Anthropic tier→id block stays exactly as-is (models.conf lines 30–66); this
is a new, separate, clearly-fenced section.

---

## 3. Change list (prioritized, file-by-file)

Ordered by severity. Path:line citations are from the audit inventories.

### P0 — De-pin cross-provider ids in `/research` (highest drift; one already stale)

1. **`.logic-loom/config/models.conf`** — add the "Advisory cross-provider
   models" section from §2 (new content; the Anthropic block is untouched).
2. **`plugins/loom-orchestrator/commands/research.md:161`** — replace hardcoded
   `gpt-4o` in the Researcher B spawn prompt with an interpolated value sourced
   from `XPROVIDER_OPENAI_MODEL` (override: the shared `CROSS_CHECK_OPENAI_MODEL`).
3. **`plugins/loom-orchestrator/commands/research.md:270`** — same `gpt-4o`
   hardcode in the OpenAI tribunal-judge spawn prompt; one config value should
   feed both 161 and 270 (the duplication is itself the smell).
4. **`plugins/loom-orchestrator/commands/research.md:181`** — replace
   `gemini-2.5-pro-preview-05-06` (dated preview, already stale) baked into the
   Gemini API URL path with an interpolated `XPROVIDER_GEMINI_MODEL` value.
5. **`plugins/loom-orchestrator/commands/research.md:293`** — second occurrence of
   the same dated Gemini id in the Gemini tribunal-judge URL; fed by the same
   config value as 181.
6. **`plugins/loom-orchestrator/commands/research.md:148,168,277,299,484-485`** —
   prose/section-header/output-schema display names (`GPT-4o`, `Gemini 2.5 Pro`).
   Make generic or drive from the same config so produced artifacts don't go
   stale.

### P0 — Fix the pin-propagating scaffolding default

7. **`plugins/loom-creation/skills/create-agent/SKILL.md:48`** — change
   `model (default: claude-opus-4-8)` to `model (default: opus)`. This is the
   worst structural offender: it bakes a pinned id into the generation procedure
   for **every future agent**, directly contradicting Principle XIV. The referenced
   `agent-template.md` already uses `{{AGENT_MODEL}}`, so this SKILL text is the
   sole pin source.

### P1 — De-pin the settings.json copy-paste snippet

8. **`plugins/loom-governance/agents/constitutional-governance-agent.md:279`** —
   the copy-paste settings.json snippet pins `"model": "claude-opus-4-8"`. Change
   to `"model": "opus"` or drop the key so the frontmatter tier governs.
   *(Governance-protected path — main-agent + user-approval edit only.)*

### P1 — `/cross-check` default value

9. **`plugins/loom-orchestrator/skills/cross-check/SKILL.md:118`** and
   **`.env.example:32`** — the default is prose-only ("a current coding-grade
   model"); with `CROSS_CHECK_*_MODEL` unset, the model to send is undefined.
   Point the default at the named `XPROVIDER_*_MODEL` values from §2 so there is
   always a concrete resolvable default.

### P2 — Reconcile documentation drift (keep-in-sync, not agnostic-ize)

These docs legitimately name concrete ids for readers; they must be resynced on a
bump (see §4) but are not selectors. Two lines should instead point at a tier:

10. **`.claude/context/governance.md:315`** — "Use Opus 4.8 by default for all
    specialized agents" should read "use the `opus` tier (see models.conf)" — a
    normative rule should reference the tier, not a pinned display name. Line 320
    tier annotation stays but resyncs on bump.
11. **`CLAUDE.md:448`** — the raw `**Model IDs**:` four-id list is the single
    most bump-fragile line. Keep it (readers want it) but add a "(canonical:
    models.conf)" pointer so it's clearly a mirror, not a source. `CLAUDE.md:462`
    likewise mirrors the block.
12. **`.docs/governance/hybrid-architecture.md:206,293`** — settings.json examples
    pin `"model": "claude-opus-4-8"`; change to `"model": "opus"` (these are
    illustrative config, tier keyword is valid and non-stale).
13. Remaining resync-only doc sites are enumerated in the §4 touch-list.

---

## 4. The "model bump" procedure

When a new Anthropic model ships in a class (or a fallback/id changes), edit
**models.conf first**, then the mirror docs. There is deliberately no runtime
resolver to update — tier keywords in frontmatter auto-resolve.

### Step 1 — Edit the source of truth

`.logic-loom/config/models.conf`:
- `FLAGSHIP_MODEL` (line 31), `FRONTIER_MODEL` / `FRONTIER_FALLBACK` (lines 38–39)
- tier→id block (lines 50–54)
- advisory cross-provider ids (§2 section) if a non-Claude model rolled

### Step 2 — Resync the mirror docs (exhaustive touch-list)

Each of these names a concrete Claude id or dated display name and goes stale on a
bump. Edit them together:

| File | Lines |
|---|---|
| `CLAUDE.md` | 439, 443, 444, 446, 448 (4 ids), 462, 463, 467; changelog 527, 538 |
| `AGENTS.md` | 181; changelog 528, 534 |
| `.logic-loom/memory/constitution.md` | 29, 205 — **GOVERNANCE-PROTECTED: main-agent + user approval to edit** |
| `.docs/architecture/orchestrator-worker-ladder.md` | 16, 17, 18, 20 (name + `$10/$50` pricing), 31, 32, 37, 102 (densest doc) |
| `.docs/governance/hybrid-architecture.md` | 206, 293 (settings.json examples) |
| `.claude/context/governance.md` | 315, 320 |
| `.claude/context/agents.md` | 46, 143 |
| `README.md` | 235 says "Opus-class" (tier-shaped, low-risk) |

**Excluded (do NOT touch on a Claude bump)** — cross-provider *family* names
(`Codex`/`GPT`/`Gemini`, `Codex CLI`, `openai/codex-plugin-cc`) at `CLAUDE.md:190`,
`AGENTS.md:224/247/329`, `orchestrator-worker-ladder.md:80/92`,
`governance-threat-model.md:141`. These are provider/host/plugin names, not Claude
version strings, and don't rot on a Claude bump. (They roll on a *cross-provider*
bump — that's Step 1's advisory section.)

### Step 3 — Verify

Run the guard (§5): `bash tests/contract/test_model_agnostic.sh`. It asserts no
frontmatter regressed to a pinned id and warns on any concrete id outside
models.conf that isn't on the accepted touch-list.

### Optional convenience

LogicLoom's own `bump-version.sh` stamps only the framework VERSION; models.conf
is not among its stamp sites. (The authoritative list is the `SITES` table in
`.logic-loom/scripts/bash/bump-version.sh` — deliberately not restated here as a
count, because a count in prose is a claim nothing verifies and this one has
already rotted once.) It is **maintainer release
tooling and is stripped from the template**, so it is not present in a cloned
project; nothing in this policy depends on it. A `bump-model.sh <tier> <new-id>`
helper that edits models.conf and the touch-list in one pass would be a
convenience — **not required by this policy**; the manual 3-step above is the
contract. (Do not fold model refresh into the version bump; they are decoupled by
design.)

---

## 5. Guard — `tests/contract/test_model_agnostic.sh` (spec, not implemented here)

A bash contract test that locks in the already-clean state and warns on drift.

**FAIL conditions (exit non-zero) — the hard invariant:**

1. For every `*.md` under `plugins/**/agents/`, `plugins/**/commands/`, and
   `.claude/agents/`, parse the YAML frontmatter (between the leading `---`
   fences only). If a `model:` key's value matches a pinned Claude version string
   — regex roughly `claude-[a-z]+-[0-9]` (e.g. `claude-opus-4-8`,
   `claude-sonnet-5`, `claude-haiku-4-5-20251001`) — **FAIL**, naming file+line.
2. Allowed frontmatter `model:` values are exactly `opus`, `sonnet`, `haiku`,
   `frontier`, `inherit`. Any other value (including a bare id) → **FAIL**.
3. Scope is FRONTMATTER ONLY for the fail path — body text and config snippets are
   the warn path, so the test enforces the invariant without false-positiving on
   legitimate reference prose.

**WARN conditions (exit 0, print advisory) — drift radar:**

4. Any concrete Claude id (`claude-[a-z]+-[0-9]…`) found **outside**
   `.logic-loom/config/models.conf` and outside the accepted §4 touch-list →
   WARN. This catches new undocumented pins without blocking on the known,
   intentional mirror sites.
5. In `plugins/loom-orchestrator/commands/research.md`, any inline
   `gpt-4o` / `gemini-…-preview-…` literal (i.e. a cross-provider id NOT sourced
   from the models.conf advisory section / an `.env` override) → WARN, so a
   regression to inline hardcoding is visible.

**Assertions to encode:**

- Count of frontmatter `model:` fields scanned > 0 (guard didn't silently no-op).
- Zero frontmatter pins (assertion 1+2). This is the test's reason to exist.
- The four `claude-*` ids in models.conf are the *only* fail-exempt id source.

The test is pure bash + `grep`/`awk`, no deps, fail-closed on parse of frontmatter,
runnable in CI and by the bump procedure Step 3. **Do not implement it in this
doc** — this is its specification.

---

## 6. Explicitly out of scope

- **No runtime resolver.** models.conf stays a documentary reference table. Tier
  keywords in frontmatter do the auto-updating; that IS LogicLoom's stated stance
  (models.conf lines 4–6). Building a parser that resolves `LOOM_MODEL_*` at
  runtime is explicitly rejected — it adds a moving part the tier keywords already
  make unnecessary.
- **No governance / constitution change.** This policy documents and tidies;
  it does not alter Principle XIV, the hook floor, or any governance surface. The
  constitution.md and constitutional-governance-agent.md edits in §3 are
  in-place resyncs under the existing approval gate, not policy changes.
- **Non-Claude stays advisory-only.** The cross-provider section added to
  models.conf is ids-for-reference at the verification layer; it does not, and
  must not, introduce a non-Claude orchestration tier or a non-Claude worker. The
  Principle XIV advisory + read-only boundary is unchanged.
- **Scope is the harness's own runtime, not the adopter's product.** Everything
  in this policy governs the agents, commands, and workers LogicLoom itself
  dispatches. It says nothing about what models the project being built may
  call — an application that legitimately calls OpenAI, Gemini, Mistral, or a
  local model is fully compliant.
