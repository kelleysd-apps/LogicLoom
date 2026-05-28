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

The hook activates only when an **active DAG context** is detected. Two
mechanisms are checked, in order:

1. **Environment variables** (preferred — set by `/swarm implement`):
   - `LOOM_ACTIVE_FEATURE=<feature-name>` (required to activate)
   - `LOOM_ACTIVE_TASK=<task-id>` (optional; if absent, the hook unions
     `owns:` across the whole feature plan — lenient mode)
2. **Marker file** (fallback for human-driven sessions):
   - Path: `<repo>/.loom-active-feature`
   - Format: two lines, forgiving whitespace:
     ```
     feature: <feature-name>
     task: <task-id>
     ```

**If neither is present, the hook default-allows every write.** This is the
critical safety property: ad-hoc / free-form work is never blocked by
plan-DAG machinery.

## 3. When active

When `LOOM_ACTIVE_FEATURE` resolves, the hook reads
`features/<feature>/plan.md` and extracts the active task's `owns:` and
`freeze:` lists from the YAML-ish DAG block (see loom-architecture.md §5).

If `plan.md` is missing, the hook default-allows — it cannot enforce a
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

Decisions are returned as JSON on stdout
(`{"hookEventName":"PreToolUse","decision":"approve|block","reason":"..."}`)
plus a human-readable line on stderr for the deny case.

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

The integration contract is one-sided: `/swarm implement` is responsible
for injecting the env vars; the hook is responsible for reading them.

Per the swarm-implement SKILL.md, before dispatching each worker task,
`/swarm implement`:

1. Resolves the feature name and task id from the plan-DAG it is walking.
2. Injects `LOOM_ACTIVE_FEATURE` and `LOOM_ACTIVE_TASK` into the spawned
   Task's environment.
3. Dispatches the worker.

The hook then reads those env vars on every write attempt and enforces the
scope declared in the plan. Workers spawned for task `T07` therefore can
only write to `T07`'s `owns:` paths, regardless of what the worker tries
to do.

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

The following scenarios were verified in a scratch repo during Stage 11.
Each pair is a positive (allow) and a negative (deny):

- **No marker file, no env vars** → write to arbitrary path **allowed**
  (default-allow safety property).
- **`LOOM_ACTIVE_FEATURE=demo` set, plan.md missing** → write **allowed**
  (can't enforce a contract it can't read).
- **Active feature + task, write target in `owns:`** → **allowed**.
- **Active feature + task, write target outside `owns:`** → **denied**
  with "OUTSIDE owns scope" reason.
- **Active feature + task, write target in `freeze:`** → **denied** with
  "FREEZE list" reason (freeze takes precedence even if a sibling task
  owns the path).
- **Marker file with `feature:` line but no `task:` line** → uses lenient
  union-of-all-tasks mode for `owns:`.
- **Marker file plus env var both set** → env var wins.
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
