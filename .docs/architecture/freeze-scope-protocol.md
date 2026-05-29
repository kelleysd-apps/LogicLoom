# Freeze-Scope Protocol

**Status**: v0.1 (Loom migration, Stage 11)
**Hook**: `.claude/hooks/freeze-write-scope.sh`
**Pattern source**: gstack `/freeze`.
**Constitutional principle**: XI (Input Validation at the tool boundary).

---

## 1. What

`freeze-write-scope.sh` is a Claude Code **PreToolUse** hook bound to the
four write-class tools — `Write`, `Edit`, `MultiEdit`, `NotebookEdit`. It
enforces the plan-as-DAG file-ownership contract at **write time**, not at
prompt time.

Hook-level enforcement was a locked decision (Q4 of the Stage 11 design
review): a prompt-level reminder is bypassable by any worker that ignores
the system reminder, while a hook is a deterministic veto at the tool
boundary. This is the same trust model that gates dangerous bash commands.

Other tool calls (Read, Bash, Grep, Glob, Task, MCP tools) are not affected.

## 2. Active DAG context detection

The hook activates only when an **active DAG context** is detected. The
context comes from two sources, which compose:

1. **Marker file** (primary — written by `/swarm implement` before each
   dispatch; see §6):
   - Path: `<repo>/.loom-active-feature`
   - Format (forgiving whitespace), carries both identity AND the resolved
     ownership scope for the active task:
     ```
     feature: <feature-name>
     task: <task-id>
     owns:
       - <path-or-glob>
       - ...
     freeze:
       - <path-or-glob>
       - ...
     ```
   - When the marker declares `owns:`/`freeze:`, **those lists are
     authoritative** — the hook does not re-parse the nested-YAML plan.
2. **Environment variables** (override for env-aware runners):
   - `LOOM_ACTIVE_FEATURE=<feature-name>` — overrides the marker's `feature:`.
   - `LOOM_ACTIVE_TASK=<task-id>` — overrides the marker's `task:`.
   - Env vars only set identity; they do not carry scope. When env identity is
     used without marker scope, the hook falls back to parsing `plan.md`
     (see §3). `LOOM_ACTIVE_FEATURE` alone (no task) unions `owns:` across the
     whole flat plan — lenient mode.

A context is "active" once a `feature` is resolved from either source.

**If no feature resolves from either source, the hook default-allows every
write.** This is the critical safety property: ad-hoc / free-form work is
never blocked by plan-DAG machinery.

## 3. When active

Scope (the active task's `owns:`/`freeze:` lists) resolves in priority order:

1. **Marker-provided scope** (primary): if `.loom-active-feature` declares
   `owns:`/`freeze:`, the hook uses them directly. `/swarm implement` resolves
   each task's scope from the nested-YAML plan once (at plan-parse time) and
   writes the concrete lists into the marker before dispatch. The hook never
   has to parse the nested YAML.
2. **plan.md fallback** (only when the marker carried no scope): the hook
   reads `features/<feature>/plan.md` and extracts the active task's `owns:`
   and `freeze:` lists from the **flat** `## task: <id>` blocks:
   ```
   ## task: <id>
   owns:
     - path/one
   freeze:
     - path/two
   ```
   This flat form is what the hook's `extract_list` awk parser consumes. It is
   distinct from the nested-YAML frontmatter that `/swarm implement` parses
   (loom-architecture.md §5): the nested plan is the model-side SSOT; this
   flat block is an optional hook-readable mirror for human-driven sessions
   that set only `feature:`/`task:` and want the hook to self-serve scope.

If neither source yields any `owns:`/`freeze:` scope (e.g. `plan.md` missing
and marker had no lists), the hook default-allows — it cannot enforce a
contract it cannot read. This is intentional: a partially-set marker file
should not brick writes.

## 4. Decision rule

For a given write target (resolved from `tool_input.file_path`,
`tool_input.path`, or `tool_input.notebook_path`):

1. **Freeze deny first**: if the target matches any path in `freeze:`,
   reject with a `BLOCKED freeze-write-scope` reason and exit nonzero.
2. **Owns deny after**: if `owns:` is non-empty and the target matches
   nothing in it, reject with an "OUTSIDE owns scope" reason.
3. **Owns allow**: if the target matches at least one entry in `owns:`,
   allow.
4. **No owns declared**: default-allow (lenient — a task that forgot to
   declare ownership is treated as ad-hoc).

Decisions are returned as JSON on stdout using the current Claude Code
PreToolUse permission-decision schema (the same schema the sibling hooks
`git-safety-gate.sh` / `guard-dangerous-commands.sh` use):

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
```
```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
```

A human-readable `[BLOCKED freeze-write-scope] ...` line is also emitted on
stderr for the deny case. The hook exits `0` in both cases — the decision is
carried by the JSON body, not the exit code (the legacy
`{"decision":"approve|block"}` schema and the nonzero-exit-to-block convention
are no longer used).

## 5. Glob behavior

**v0.1 uses literal string equality plus directory-prefix matching.** For
each declared path `P`, the target matches if:

- target == P, or
- target startswith `P/`.

No real glob expansion. A glob pattern like `src/**/*.ts` will not match;
v0.1 treats it as a literal path that almost never matches. This is
intentional — overzealous glob matching can over-allow.

**Deferred to v0.2**: full glob-aware overlap detection (used both for the
write-time check here and for the one-task-one-owner plan validator).

## 6. Integration with /swarm implement

The integration contract is one-sided: `/swarm implement` is responsible for
**establishing the active-task context**; the hook is responsible for reading
it. The context must exist before the worker runs or the guarantee is a no-op.

Per the swarm-implement SKILL.md (Task Brief step 6), before dispatching each
worker task, `/swarm implement`:

1. Resolves the feature name, task id, and the task's `owns:`/`freeze:` lists
   from the plan-DAG it parsed at load time.
2. **Writes the marker file** `<repo>/.loom-active-feature` with
   `feature:`/`task:` plus the resolved `owns:`/`freeze:` lists inline. This
   is the primary, reliable mechanism — the marker is read on every write
   attempt regardless of how the worker process was spawned.
3. Optionally also injects `LOOM_ACTIVE_FEATURE` / `LOOM_ACTIVE_TASK` env vars
   (override for env-aware runners).
4. Dispatches the worker.
5. After the worker returns, **tears down the marker** (delete it, or
   overwrite it with the next task's scope) so stale ownership never
   constrains subsequent ad-hoc or next-task writes.

The hook then reads the marker on every write attempt and enforces the scope
it declares. Workers dispatched for task `T07` can therefore only write to
`T07`'s `owns:` paths, regardless of what the worker tries to do.

## 7. Pre-existing latent bug note

`.logic-loom/lib/logging.sh` references `$DEBUG` without a default. Under
`set -u` (which the hook uses), sourcing logging.sh trips an unset-variable
exit before the hook can run its own logic.

The hook works around this by relaxing both errexit and nounset around the
`source` call for `.logic-loom/lib/policy.sh` (which transitively sources
logging.sh), then restoring strict mode:

```bash
_loom_saved_repo_root="$REPO_ROOT"
if [ -f "$POLICY_LIB" ]; then
    set +eu
    # shellcheck disable=SC1090
    source "$POLICY_LIB" >/dev/null 2>&1 || true
    set -eu
fi
REPO_ROOT="$_loom_saved_repo_root"
```

The workaround is local to the hook. The fix — adding `: "${DEBUG:=0}"` (or
equivalent) at the top of `logging.sh` — is tracked as cleanup for a future
stage. Until then, any other strict-mode caller of logging.sh will hit the
same issue and need the same workaround.

## 8. Sidecar file

`worktree-port-namespace.sh` (Stage 11, separate hook) writes a sidecar
file at the repo root:

- Path: `<repo>/.loom-worktree-env`
- Contents: per-worktree port offsets so parallel dev servers do not
  collide across feature worktrees.

This file should be added to `.gitignore`. The gitignore edit is **deferred
— outside Stage 11 file ownership**. Track as a Stage 13+ cleanup item.

## 9. Testing

Automated contract test: `tests/contract/test_freeze_scope.sh`. It builds an
isolated fake repo, copies the hook in, and drives it with synthetic
PreToolUse Write/Edit payloads. Run it directly (`bash
tests/contract/test_freeze_scope.sh`); it is bash-3.2 safe and needs no deps
beyond awk/sed/grep (jq optional). It covers both the marker-scope path and
the plan.md flat-format fallback, and asserts the output uses the current
`permissionDecision` schema. The scenarios:

- **No marker file, no env vars** → write to arbitrary path **allowed**
  (default-allow safety property).
- **Marker carries `owns:`/`freeze:`, target in `owns:`** → **allowed**.
- **Marker carries `owns:`, target outside it** → **denied** with "OUTSIDE
  owns scope" reason.
- **Marker carries `freeze:`, target in it** → **denied** with "FREEZE list"
  reason (freeze takes precedence even if a sibling task owns the path).
- **Marker with `feature:`/`task:` only (no scope), plan.md present** → hook
  falls back to the flat `## task:` block in plan.md for `owns:`/`freeze:`.
- **`LOOM_ACTIVE_FEATURE`/`LOOM_ACTIVE_TASK` env set, plan.md present, no
  marker scope** → env identity + plan.md fallback enforce the task scope.
- **Marker plus env var both set** → env var wins for identity; marker scope
  (if any) still authoritative for `owns:`/`freeze:`.
- **Non-write tool (Bash, Read)** → not gated; default-allow.
- **Strict-mode sourcing of logging.sh** → does not trip the hook
  (workaround in §7 holds).

Add new scenarios when the v0.2 glob-aware matcher lands.

## 10. References

- gstack `/freeze` pattern — original inspiration. See
  `.logic-loom/memory/MEMORY.md` → `reference_gstack_research.md`.
- Constitutional Principle XI (Input Validation) —
  `.logic-loom/memory/constitution.md`.
- `.docs/architecture/loom-architecture.md` §5 (plan-as-DAG contract) and
  §6 (hook architecture).
- Plan template — `.logic-loom/templates/plan-template.md` (definitive
  schema for `owns:` / `freeze:` / `depends_on:` / `rubric:`).
