# LogicLoom — governance (installed rule)

You are working in a repository where the LogicLoom harness is installed. This
file states the obligations that hold here. It was installed by
`logicloom init`; it is not this project's own rule file, and it never speaks
for the project's product requirements — those stay wherever the project keeps
them.

## Read the constitution before you start work

`.logic-loom/memory/constitution.md` holds **16 enforceable principles**
(3 immutable: Library-First, Test-First, Contract-First; 6 quality & safety;
7 workflow & delegation). Read it. The four that most often decide what you do:

| Principle | Requirement |
|---|---|
| **II Test-First** | TDD by default — tests before implementation |
| **VI Git Approval** | Never run a git mutation autonomously |
| **X Agent Delegation** | Specialized or parallel work goes to subagents |
| **XVI Plugin-First** | New harness capabilities ship as installable plugins |

If `.logic-loom/memory/amendments.md` exists, read it too and treat its named
mandates as binding alongside the principles. Mandates add obligations; they
never relax one, and where a mandate would weaken a principle it is void in that
respect. Nothing in the harness loads or validates that file — it works only
because this rule tells you to read it.

## Hooks are the enforcement floor — check whether they are registered

LogicLoom's governance guarantees are hook-side, not model-recited. Six hooks
carry them:

| Script | Enforces |
|---|---|
| `plugins/loom-governance/hooks/scripts/subagent-git-guard.sh` | denies MUTATING git from a subagent; allowlisted read-only git is permitted; `gh` is denied outright for subagents |
| `plugins/loom-governance/hooks/scripts/git-safety-gate.sh` | forces an approval prompt on main-agent git mutations |
| `plugins/loom-governance/hooks/scripts/protect-governance-files.sh` | writes to the governance surface (hooks, `settings.json`, constitution, `governance.conf`) → subagent deny / main-agent ask |
| `.claude/hooks/guard-dangerous-commands.sh` | policy-based dangerous-command blocking (enforces on bash 3.2+, i.e. stock macOS; prefers bash 4 when present) |
| `.claude/hooks/freeze-write-scope.sh` | plan-as-DAG file ownership during `/swarm implement` |
| `.claude/hooks/user-prompt-submit/governance-preflight.sh` | injects domain guidance and memory context |

**A hook runs only because `.claude/settings.json` invokes it by path.** The
scripts existing on disk is not registration. Confirm before you rely on one:

```bash
grep -c 'loom-governance/hooks/scripts' .claude/settings.json
```

If that returns `0`, the hooks were **not** registered here (the installer's
`hooks` target is opt-in and is never installed as a side effect). Everything
below is then **followed, not enforced** — say so plainly rather than claiming a
guarantee the repository does not have. Do not register them yourself; that is
the repository owner's decision.

Hooks are a deterministic floor, not a sandbox. They make the high-impact
failures hard; a string gate cannot see interpreter indirection or every Bash
write path. Residual bypasses: `.docs/architecture/governance-threat-model.md`.

## Standing policies — respect these without being asked

- **VI Git Approval** — never run git mutations autonomously, and never route
  around the gate. If the hooks are not registered, this is still the rule; you
  are simply the only thing enforcing it.
- **II Test-First** — tests before implementation.
- **I / III Library-First and Contract-First** — how features are shaped.
- **X Delegation & Context Isolation** — delegate specialized or parallel work
  to subagents for isolation and parallelism, not because the base model lacks
  capability.
- Cross-Check Disposition — when output correctness materially matters AND the ask invites scrutiny (double-check, cross-check, red-team, peer-review, second opinion, sanity-check, 'are you sure', 'poke holes', 'prove me wrong'), default to a decorrelated second look from a DIFFERENT-PROVIDER model rather than reviewing your own output in-lineage — a same-lineage self-review shares your blind spots. HOST-GATED: On the Claude Code host, this is surfaced as /cross-check (or the cross-provider slot in /review-team / --adversary on /plan-review), which hands a bounded artifact to a non-Claude model; advisory, read-only, key-gated and fail-open. On any host where you are the ONLY model reachable, a self-review is NOT decorrelation — say so plainly, do not label it a cross-check, and proceed. It never blocks and never touches git. Skip it for trivial asks.

## Governance mode

`.logic-loom/config/governance.conf` carries `mode = lean` (the default) or
`strict`. Hook enforcement is identical in both; only the model-side assist
differs — `strict` re-injects a pre-flight recitation on every message and is
the degradation path for non-flagship models. `LOOM_GOVERNANCE_MODE` overrides
the file.

## Gate policy — and the floor that cannot be turned off

`.logic-loom/config/gate-policy.conf` answers "is this change worth interrupting
the user?", per operation: `ask` (an approval prompt) or `silent` (runs without
an extra LogicLoom prompt — still logged, still subject to the host's permission
mode). Shipped posture is `balanced`.

**Five operations refuse a `silent` setting**, marked `[FLOOR]` in the file:
`git.push`, `git.history-rewrite`, `gh.repo.admin`, `gh.secret.write`,
`gh.auth`. The test is one sentence: a wrong answer leaves the repository, or a
credential, somewhere a revert cannot reach. Three more are not config keys at
all — protected-file writes, the dangerous-shell guard, and subagent git/gh.
There is no wildcard and no "silence everything" line.

## Compliance check

`bash .logic-loom/scripts/bash/constitutional-check.sh` validates the 16
principles. It executes no git. LogicLoom's own test suite is **not** installed
here, so `/finalize` will report `harness-tests: NOT RUN` and record Principle II
as NOT VERIFIED — that is correct reporting, not a failure.
