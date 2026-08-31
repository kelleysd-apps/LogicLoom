# Plugin Manifest Schema — `.claude-plugin/plugin.json`

**Version**: 1.1.0
**Effective Date**: 2026-08-17 (rev. 2026-08-24 — LOOM-0012: `count` removed, inventory lists verified against disk)
**Authority**: Constitution v3.3.0 — Principle XVI (Plugin-First Architecture)
**Review Cycle**: Quarterly
**Applies to**: LogicLoom v6.6.1, all 8 bundled plugins under `plugins/`

---

## Purpose

The manifest schema already existed as a *de facto* contract — eight manifests
that agree with each other and one CI step that checks three fields. What did
not exist was the written spec, so **a fork could not conform to it**. This
document writes down what is there.

It is descriptive first: every field below is a field currently in use, and each
row states plainly whether CI enforces it or whether it is convention only. Read
the **[Enforcement](#enforcement)** section before assuming any of this is
checked for you — most of it is not.

---

## Location and shape

```
plugins/<plugin-name>/
└── .claude-plugin/
    └── plugin.json      # one JSON object, UTF-8, no comments, no trailing commas
```

Anything under `plugins/` **without** a `.claude-plugin/plugin.json` is skipped
entirely by CI validation — it is not an error, it is simply not a plugin.

---

## Field reference

### Required

Three fields are enforced by CI. Everything else in this document is optional
or convention.

| Field | Type | Notes |
|---|---|---|
| `name` | string | Plugin identifier; **must match the containing directory name**. Convention: `loom-` prefix (`sdd-specification` is the one grandfathered exception — it *is* the SDD workflow). |
| `version` | string | Semantic version `MAJOR.MINOR.PATCH`. Current values in tree: `1.0.0`, `2.0.0`, `3.0.0`. |
| `dependencies` | array of string | Plugin names this plugin requires. Empty array is valid and used (`loom-governance`, `loom-memory`, `loom-orchestrator-hook`). Convention: every non-core plugin lists `"loom-governance"`. |

### Optional — descriptive metadata

| Field | Type | In use by | Notes |
|---|---|---|---|
| `description` | string | all 8 | One-line summary. Present everywhere; not enforced. |
| `author` | string | all 8 | Currently `"kelleysd-apps"` throughout. |
| `license` | string | all 8 | SPDX identifier; currently `"MIT"` throughout. |
| `homepage` | string (URL) | `loom-governance` | Project URL. |
| `keywords` | array of string | 6 of 8 | Discovery hints. Absent from `loom-memory` and `loom-orchestrator-hook` — absence is legal. |
| `category` | string | `loom-memory`, `loom-orchestrator-hook` | Free-form grouping label; only value in use is `"orchestration"`. **No closed vocabulary is defined or checked.** |

### Optional — governance flags

| Field | Type | In use by | Notes |
|---|---|---|---|
| `required` | boolean | `loom-governance` (`true`) | Marks a plugin that cannot be removed from a LogicLoom install. |
| `protected` | boolean | `loom-governance` (`true`) | Marks the governance surface. **Advisory metadata only** — the actual protection is hook-side in `protect-governance-files.sh`, which does not read this field. Setting `protected: true` on your own plugin grants it nothing. |
| `constitutional_principles` | array of string | `loom-memory` (`["VII","XVI"]`), `loom-orchestrator-hook` (`["X","XVI"]`) | Roman-numeral principle IDs the plugin implements. Documentation aid; nothing cross-checks these against `constitution.md`. |

### Optional — content inventory

Three parallel blocks with an identical shape. Each carries a `list` and
**nothing else**:

```json
"agents":   { "list": [ "<name>", ... ] },
"skills":   { "list": [ "<name>", ... ] },
"commands": { "list": [ "<name>", ... ] }
```

| Field | Type | Notes |
|---|---|---|
| `agents` | object | `list` entries are agent filenames **without** the `.md` extension, under `plugins/<name>/agents/`. |
| `skills` | object | `list` entries are skill **directory** names under `plugins/<name>/skills/`, each containing a `SKILL.md`. |
| `commands` | object | `list` entries are command filenames without `.md`, under `plugins/<name>/commands/`. Absent entirely from `loom-governance` (which ships no commands); `{"list":[]}` is also used and equally valid. |

**`list` is verified against disk** by the CI validator — see
[Enforcement](#enforcement). A block may be omitted, but **only** when the
corresponding directory holds nothing; omitting it to silence the check is
itself an error. Order inside `list` is free (it is compared as a set), but
duplicates are not.

> **There is no `count` field.** Blocks used to carry `"count": <int>` alongside
> `list`, verified against neither the list nor disk — and it drifted exactly as
> that guarantees: `loom-orchestrator` declared `commands.count: 8` /
> `skills.count: 10` while disk held **9** and **11**, the `graph` command and
> `project-graph` skill having been added without touching the manifest. The
> field was removed rather than corrected (LOOM-0012): a count is fully derivable
> from the list it sits next to, so it adds no information and one more thing to
> keep true. A manifest that still declares `count` is now **rejected**, not
> ignored.

These blocks remain *documentation* — nothing resolves from them. Command
resolution goes through `.logic-loom/scripts/bash/sync-plugin-commands.sh`,
which walks the filesystem and never reads `commands.list`. The difference since
LOOM-0012 is that the documentation is now checked, so it cannot quietly become
false.

### Optional — path maps

| Field | Type | In use by | Notes |
|---|---|---|---|
| `config` | object (string → string) | `loom-memory`, `loom-orchestrator-hook` | Named config files, **relative to the plugin root** (e.g. `"memory_conf": "config/memory.conf"`). Keys are free-form. |
| `backends` | object (string → string) | `loom-memory` | Named implementation files, relative to the plugin root (e.g. `"vector": "lib/vector-search.sh"`). Keys are free-form. |

Neither map's targets are checked for existence.

### Optional — `eval`

See **[`eval` metadata block](#eval-metadata-block)** below. It is the one
optional field whose *shape* CI validates when present.

---

## Enforcement

### What CI enforces

`.github/workflows/plugin-tests.yml` → **"Validate All Manifests"** step, which
delegates to `.logic-loom/scripts/python/validate-plugin-manifests.py`. It is
the entire automated contract:

1. The file parses as JSON. A `JSONDecodeError` fails the build.
2. `name`, `version`, and `dependencies` are **present**. Presence only — no
   type check, no format check, no semver parse, no directory-name match.
3. If an `eval` block is present, its shape is valid (see below). If absent,
   nothing is checked.
4. The `agents` / `skills` / `commands` inventory blocks match the filesystem:
   each declares `list` and no other key (a leftover `count` is rejected), the
   list equals what the directory holds, and a block may be omitted only when
   that directory is empty or absent.

That is all. Run it locally:

```bash
python3 .logic-loom/scripts/python/validate-plugin-manifests.py
```

### What is convention, not enforced

Everything else. Specifically, **nothing** checks that:

- `name` matches the directory name, or carries the `loom-` prefix
- `version` is valid semver
- `dependencies` names resolve to plugins that exist, or include `loom-governance`
- `config` / `backends` paths exist
- `constitutional_principles` are real principle IDs
- `license` / `author` / `description` are present at all

Contributor-side conventions are stated in
[`plugins/CONTRIBUTING.md`](CONTRIBUTING.md). They are followed, not enforced —
do not read a green CI run as confirmation that a manifest is well-formed
beyond the four checks above.

---

## The absent plugin registry index

**There is no plugin registry index in this repository, and its absence is
undocumented anywhere else.** Stating it here plainly:

- Plugins are discovered by **walking the `plugins/` directory**. There is no
  `marketplace.json`, no `registry.json`, no index file listing the 8 plugins.
- `plugins/CONTRIBUTING.md` § *Distribution* documents that LogicLoom dropped
  its own **marketplace MCP server** and defers third-party discovery to the
  Anthropic Claude Code Plugin Marketplace and the Docker MCP Toolkit. **That is
  a different thing.** Dropping a *server* that discovers third-party plugins
  says nothing about whether this repo carries an *index* of its own bundled
  plugins. It does not, and that was never written down.
- `VISION.md` Thread #8 proposes adding a `marketplace.json`. That thread is
  **unresolved and contested** — see `.docs/reports/backlog-2026-08-13.md` §8.1,
  where the plugin-externalization proposal directly contradicts it. Do not
  treat Thread #8 as a committed direction.

Until that is settled, a fork adding a plugin needs to do exactly one thing:
create the directory with a conforming `plugin.json`. Nothing else registers it.

---

## `eval` metadata block

*(Added per backlog §3.4. Metadata only.)*

### Scope — read this first

`eval` is a **declaration of where a plugin's evaluations live and what they
assert**. It is machine-readable so tooling *outside* this repository can find
them.

**LogicLoom ships no judge, no runner, and no scoring engine, and will not.**
Executing evals would make LogicLoom an evaluation engine, contradicting the
ratified "ride native, don't reimplement" position (v6.2) the same way the
removed dev-loop pack did. The only code this block will ever have in-tree is
the CI shape check described below.

### Shape

```jsonc
"eval": {
  "suites": [                          // required, array, >= 1 entry
    {
      "id": "governance-verdicts",     // required, string, unique within the array
      "path": "tests/eval/verdicts.jsonl",  // required, plugin-relative string
      "description": "…",              // optional, string
      "metric": "accuracy",            // optional, string
      "threshold": 0.9                 // optional, number in [0, 1]
    }
  ]
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `eval` | no | object | Absent is the normal case. Absence is never an error. |
| `eval.suites` | yes, if `eval` present | array | Must be non-empty. An `eval` block declaring nothing is a mistake, not a valid default. |
| `suites[].id` | yes | string | Non-empty; must be unique within the array. |
| `suites[].path` | yes | string | Non-empty, **relative to the plugin root**. Existence is deliberately *not* checked — the suite may be generated, or live in a downstream harness. |
| `suites[].description` | no | string | Human-readable. |
| `suites[].metric` | no | string | Free-form metric name. **No closed vocabulary** — LogicLoom does not compute metrics, so it has no standing to enumerate them. |
| `suites[].threshold` | no | number | Must be within `0`–`1` inclusive if present. A pass bar for an *external* runner; nothing in this repo reads it. |

Unknown keys inside `eval` or inside a suite entry are **rejected**, not
ignored. A typo'd key that silently does nothing is the failure mode this check
exists to prevent.

### Current usage

**No bundled manifest declares `eval`.** None of the 8 plugins has a genuine
evaluation suite today, and adding a fabricated one would misrepresent the
tree. The JSON above is illustrative — it is a schema example, not a live
manifest excerpt.

---

## Worked example

A minimal conforming manifest for a new plugin:

```json
{
  "name": "loom-yourname",
  "version": "1.0.0",
  "description": "One line on what this plugin does.",
  "author": "your-handle",
  "license": "MIT",
  "keywords": ["logic-loom", "yourname"],
  "dependencies": ["loom-governance"],
  "agents":   { "list": ["yourname-specialist"] },
  "skills":   { "list": ["yourname-operations"] },
  "commands": { "list": [] }
}
```

Validate it:

```bash
python3 .logic-loom/scripts/python/validate-plugin-manifests.py
bash tests/contract/test_plugin_manifest_schema.sh
```

---

## References

- Contributor how-to: [`plugins/CONTRIBUTING.md`](CONTRIBUTING.md)
- CI step: `.github/workflows/plugin-tests.yml` → *Validate All Manifests*
- Validator: `.logic-loom/scripts/python/validate-plugin-manifests.py`
- Schema tests: `tests/contract/test_plugin_manifest_schema.sh`
- Constitution v3.3.0 (Principle XVI): `.logic-loom/memory/constitution.md`
- Origin: `.docs/reports/backlog-2026-08-13.md` §3.6 and §3.4

---

**Owner**: Framework maintainers
**Last Reviewed**: 2026-08-24
**Next Review**: 2026-11-17
