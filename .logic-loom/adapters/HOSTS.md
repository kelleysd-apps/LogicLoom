# Per-host wiring — running LogicLoom on a non-Claude coding agent

LogicLoom's **policy** (the constitution + AGENTS.md Tier 1 + the Cross-Check
Disposition) is provider-neutral and travels to any host as model-followed rules.
Its **enforcement** is host-specific (see
`.docs/architecture/governance-threat-model.md`). This guide wires both for each
host:

- **Policy shim** — point the host's native rules-file at `AGENTS.md` Tier 1 so
  the agent reads the operating principles + disposition every session.
- **Enforcement adapter** — install the off-host git-approval gate
  (`bash .logic-loom/adapters/install.sh`, see `README.md`) so Principle VI is
  enforced, not just followed. `agent_id`-based subagent-deny is Claude-only; off
  Claude Code the PATH `git` wrapper blocks autonomous (non-interactive) mutating
  git as the substitute.

| Host | Native rules file | Policy shim | git-gate enforcement |
|------|-------------------|-------------|----------------------|
| **Claude Code** | `CLAUDE.md` + `AGENTS.md` | native (Tier 1 + Tier 2) | **hooks (always-on)** |
| **OpenAI Codex CLI** | `AGENTS.md` (honors the standard) | **native** — reads AGENTS.md Tier 1 directly | `install.sh` + prepend `bin/` to PATH |
| **Cursor** | `.cursor/rules/*.mdc` (or `.cursorrules`) | add a rule pointing to AGENTS.md Tier 1 (below) | `install.sh` (pre-push) + optional PATH wrapper |
| **Gemini CLI** | `GEMINI.md` | add `GEMINI.md` pointing to AGENTS.md Tier 1 (below) | `install.sh` + prepend `bin/` to PATH |
| **GitHub Copilot** | `.github/copilot-instructions.md` | add the pointer (below) | `install.sh` (pre-push; Copilot has no PATH shim hook) |
| **Aider** | `CONVENTIONS.md` (+ `.aider.conf.yml`) | add `CONVENTIONS.md` pointing to AGENTS.md Tier 1 | native git hooks — `install.sh` pre-push |

## Policy-shim content (copy-paste)

For any host that does NOT natively read `AGENTS.md`, create its rules file with:

```markdown
# Project operating rules

Follow **AGENTS.md Tier 1** (Operating Principles & Disposition) in this repo as
the source of truth: Library/Test/Contract-First, self-enforced Git Approval
(never run a git mutation without explicit human approval — and on this host NO
hook enforces that, so YOU must), Delegation, File Organization, and the
**Cross-Check Disposition** (on a verification-shaped ask, prefer a decorrelated
review from a different-provider model; if you are the only model reachable, say
so — a self-review is not decorrelation).

Enforcement note: the Claude Code hooks do NOT run on this host. Install the
git-approval gate: `bash .logic-loom/adapters/install.sh`.
```

- **Cursor** → put it in `.cursor/rules/logicloom.mdc` (frontmatter `alwaysApply: true`).
- **Gemini CLI** → `GEMINI.md` at repo root.
- **Copilot** → `.github/copilot-instructions.md`.
- **Aider** → `CONVENTIONS.md` (and add `read: CONVENTIONS.md` to `.aider.conf.yml`).
- **Codex CLI** → none needed; it reads `AGENTS.md` directly.

## Honest coverage per host

`adapter†` (git-gate) becomes real **once `install.sh` is run** on that host —
subject to the inherent client-side bypasses (absolute-path `git`, `git push
--no-verify`, the honor-system `LOOM_GIT_APPROVED` token) documented in
`.logic-loom/adapters/README.md` → **Honest limits**. It raises the bar against
*non-adversarial* autonomy; it is not the hard, unavoidable gate Claude Code's
PreToolUse hooks are. Off-host **subagent-git-deny** is only a heuristic (no
`agent_id`; read-only subagent git is not blocked). `governance-file protection`
and `freeze-write-scope` have no off-host adapter yet, so they remain
**followed-only** (model-followed, unenforced) everywhere but Claude Code. Do not represent a host as fully governed until its
adapters pass `tests/contract/test_git_adapter.sh` (and future per-guarantee
conformance tests). This honesty is the point — see the threat-model matrix.
