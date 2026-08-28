# LogicLoom — file and boundary rules (installed rule)

## Before creating any file or folder

1. **Verify before create** — confirm the parent directory exists first.
2. **Edit over create** — prefer modifying an existing file.
3. **Templates first** — use `.logic-loom/templates/` when one fits.
4. **Absolute paths** — resolve from the repository root, never a guess.
5. **No proactive docs** — never write a README or other documentation file
   unless you were asked for it.

## Harness ↔ project boundary

The harness owns **its own trees, and only those**: `.logic-loom/`, `plugins/`,
and the harness directories under `.claude/` (`hooks/`, `commands/`, `context/`,
`agents/`, `policies/`, `schemas/`). Treat those as harness surface.

**Everything else in this repository is the project's.** The root
`package.json`, the project's test suite, its build config, its source tree, its
CI — the installer neither shipped nor claimed any of them, and neither do you.
Do not move project source to satisfy a harness layout, do not fold project
tests into a harness runner, and do not rewrite root config to match a
convention from LogicLoom's own repository.

If the harness ever needs product code in a separate workspace, that is a
proposal to make, not a migration to perform. The reasoning is in
`.docs/policies/file-structure-policy.md`.

## Harness ↔ user boundary

**Never write to `~/.claude/`.** The harness governs this repository only. Do not
edit the user's global `CLAUDE.md`, `settings.json`, hooks, commands, or agents.
If a change belongs there, say so and let them make it.

User-level and project-level hooks both fire, and decisions combine
most-restrictive. A personal hook can add friction; it cannot weaken the
governance floor.

## Shell

Harness shell — anything under `.logic-loom/` or `.claude/hooks/` — targets the
**bash 3.2** floor (macOS's system bash): no associative arrays, no `mapfile`,
no `[[ -v ]]`, no `${var,,}`. Shell you write for the project is the project's
call. Idioms and the reasoning: `.docs/policies/shell-idiom-policy.md`.

## Where the reference material is

Nothing below is loaded into context. Read it when the question comes up.

| Question | File |
|---|---|
| The full architecture | `.docs/architecture/loom-architecture.md` |
| What the hooks can and cannot enforce | `.docs/architecture/governance-threat-model.md` |
| File and naming conventions | `.docs/policies/file-structure-policy.md` |
| The 16 principles in full | `.logic-loom/memory/constitution.md` |
| The per-feature folder convention | `features/README.md` |
| The agent registry | `.logic-loom/AGENTS.md` |
| Everything else | `.docs/policies/`, `.docs/architecture/`, `.docs/guides/`, `.docs/references/` |

## Two things this installation does not have

- **No harness test suite.** LogicLoom's own `tests/` is not installed. If you
  edit the harness — via `/create-plugin`, say — there is no local regression
  suite; clone LogicLoom itself for harness development.
- **No CI workflows.** None were installed. LogicLoom's own workflows encode
  LogicLoom's branch topology and would fail every pull request opened here.

Say either of these plainly when it is relevant. Do not report a check as passed
when the thing that would have run it is not present.
