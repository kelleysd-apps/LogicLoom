#!/usr/bin/env bash
# Contract Tests: backlog collector + backlog linter (the machine contract layer)
#
# Two artifacts under test:
#   .logic-loom/scripts/bash/build-backlog-index.sh  — collects the task SOURCES
#     (.logic-loom/memory/todos.md, .logic-loom/memory/backlog.md,
#     features/*/plan.md, specs/*/tasks.md) into one small JSON index at
#     .logic-loom/backlog-index.json.
#   .logic-loom/scripts/bash/lint-backlog.sh         — lints those same SOURCES.
#
# What this suite guards, and why each one is here:
#
#   * VALID JSON + schema_version — a consumer must be able to version-gate.
#   * DETERMINISM — same inputs, byte-identical output. Without it the index is
#     not comparable across runs and "diff two snapshots to see what changed"
#     (the deliberate substitute for per-item timestamps) does not work.
#     generated_at is frozen with SOURCE_DATE_EPOCH for this proof.
#   * ZERO SOURCES — a fresh clone has no features and no specs. That must
#     produce a valid empty index and exit 0, not an error and not no file.
#   * ALL FOUR STATUSES round-trip — the vocabulary is closed at exactly four;
#     a collector that silently drops one is worse than one that errors.
#   * blocked_on / source.file / source.heading — source is DERIVED, never
#     authored (backlog.md's grammar forbids hand-written source pointers), so
#     the derivation is the contract.
#   * WRITES NOTHING but its output path — verified by shasum-manifest diff of a
#     fixture tree, the same technique the project-identity suite uses.
#   * RUNS NO GIT — verified at runtime with a PATH shim that records any call,
#     not just by reading the source.
#   * THE OUTPUT IS GITIGNORED AND UNTRACKED — the load-bearing decision of this
#     whole layer. A tracked derived artifact diverges from its sources the
#     moment someone edits a source without regenerating (this repo has been bitten
#     by that class three times). Untracked makes staleness structurally
#     impossible instead of merely detectable, so it is asserted, not assumed.
#   * THE LINTER FIRES on every defect class it claims — one fixture per class.
#   * TWO STREAMS, ONE ID SPACE — todos.md and backlog.md are separate files with
#     separate `level` values but ONE id space, because `blocked_on:` references
#     cross between them. Three things are asserted rather than assumed: a
#     cross-stream reference RESOLVES, a colliding id minted in BOTH files is
#     FATAL to the collector, and the linter reports it naming both files.
#
# MODES: the per-defect fixtures run the linter with --strict, because an exit
# code is the only unambiguous proof that a finding fired. The REAL backlog is
# linted in DEFAULT (warn-only) mode and its findings are REPORTED, never
# asserted — real repo content must never gate the test suite.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
# skip <desc> <reason> — NOT counted in PASS/FAIL/TOTAL. See tests/lib/tree-provenance.sh.
skip() {
  SKIP=$((SKIP + 1))
  echo "  ⏭  SKIP: $1 — $2"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# shellcheck source=../lib/tree-provenance.sh
source "$ROOT/tests/lib/tree-provenance.sh"
if ! loom_require_consistent_tree "$ROOT"; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi
TREE_KIND="$(loom_tree_kind "$ROOT")"

COLLECTOR="$ROOT/.logic-loom/scripts/bash/build-backlog-index.sh"
LINTER="$ROOT/.logic-loom/scripts/bash/lint-backlog.sh"
OUT_REL=".logic-loom/backlog-index.json"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t loombix)"
trap 'rm -rf "$TMP"' EXIT

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Backlog Index (collector + linter)       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 0. Present and syntactically sound ───────────────────────────────────────
echo "0. Scripts present and parse"
assert "build-backlog-index.sh exists" "[ -f '$COLLECTOR' ]"
assert "lint-backlog.sh exists" "[ -f '$LINTER' ]"
assert "collector passes bash -n" "bash -n '$COLLECTOR' >/dev/null 2>&1"
assert "linter passes bash -n" "bash -n '$LINTER' >/dev/null 2>&1"
HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1
assert "jq available (required for the collector)" "[ $HAVE_JQ -eq 1 ]"
echo ""

if [ $HAVE_JQ -ne 1 ] || [ ! -f "$COLLECTOR" ]; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

# ── fixture tree: every level, every status, fences, out-of-section items ────
FX="$TMP/fx"
mkdir -p "$FX/.logic-loom/memory" "$FX/.logic-loom/config" "$FX/features/alpha" "$FX/specs/001-auth"

cat > "$FX/.logic-loom/config/project.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = LOOM
repo         = acme/widgets
CONF_EOF

# NOTE: the fenced item and the item under a LATER `## ` heading must NOT be
# collected — those two scope rules are what keep the grammar's own worked
# examples from becoming real work.
cat > "$FX/.logic-loom/memory/backlog.md" <<'BL_EOF'
# Fixture backlog

## Item grammar (normative)

- [ ] LOOM-7777 — above the Items heading, must NOT be collected `status:open`

## Items

### Governance and constitution

- [ ] LOOM-0001 — Open item `status:open`
- [ ] LOOM-0002 — Running item `status:in_progress`

### Dead code and test hygiene

- [ ] LOOM-0003 — Blocked item `status:blocked` `blocked_on:LOOM-0001,LOOM-0002`
- [x] LOOM-0004 — Finished item `status:done`
- [ ] LOOM-0005 — Blocked outside the index `status:blocked` `blocked_on:external:maintainer decision`
- [ ] LOOM-0006 — Blocked both ways `status:blocked` `blocked_on:LOOM-0001,external:upstream release`

```
- [ ] LOOM-9999 — inside a fence, must NOT be collected `status:open`
```

## Provenance

- [ ] LOOM-8888 — below a later heading, must NOT be collected `status:open`
BL_EOF

# The ACTIVE half of Level 0. Separate file, separate level, SAME id space —
# LOOM-0007 below is blocked on LOOM-0001, which lives in backlog.md.
cat > "$FX/.logic-loom/memory/todos.md" <<'TD_EOF'
# Fixture todos

## Items

### Being worked

- [ ] LOOM-0007 — Active, blocked on a DEFERRED item in the other file `status:in_progress` `blocked_on:LOOM-0001`

## Provenance

- [ ] LOOM-6666 — below a later heading, must NOT be collected `status:open`
TD_EOF

cat > "$FX/features/alpha/plan.md" <<'PLAN_EOF'
---
feature: alpha
sprints:
  - name: 01-foundations
    tasks:
      - id: t1
        description: Build the thing.
        status: open
        owns:
          - src/a.ts
        depends_on: []
      - id: t2
        description: Wire the thing.
        status: blocked
        depends_on:
          - t1
        blocked_on:
          - t1
      - id: t3
        description: Status key absent on purpose.
        depends_on: []
---

# Plan: alpha
PLAN_EOF

cat > "$FX/specs/001-auth/tasks.md" <<'TASKS_EOF'
# Tasks: auth

## Phase 3.1: Setup
- [x] T001 Create project structure
- [ ] T002 [P] Configure linting
TASKS_EOF

IDX="$FX/.logic-loom/backlog-index.json"

# ── 1. Valid JSON with a schema version ──────────────────────────────────────
echo "1. Emits valid JSON carrying schema_version"
SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$FX" >/dev/null 2>"$TMP/run1.err"; RC1=$?
assert "collector exits 0" "[ $RC1 -eq 0 ]"
assert "wrote the index at the default path" "[ -f '$IDX' ]"
assert "index is valid JSON" "jq -e . '$IDX' >/dev/null 2>&1"
assert "schema_version is the integer 1" "[ \"\$(jq -r '.schema_version' '$IDX')\" = '1' ]"
assert "generated_at is ISO 8601 UTC" \
  "grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\$' <<< \"\$(jq -r '.generated_at' '$IDX')\""
assert "source_digest is a sha256 hex string" \
  "grep -qE '^[0-9a-f]{64}\$' <<< \"\$(jq -r '.source_digest' '$IDX')\""
assert "project carries the declared slug" "[ \"\$(jq -r '.project.slug' '$IDX')\" = 'acme-widgets' ]"
assert "project carries the declared id_prefix" "[ \"\$(jq -r '.project.id_prefix' '$IDX')\" = 'LOOM' ]"
assert "project carries repo when declared" "[ \"\$(jq -r '.project.repo' '$IDX')\" = 'acme/widgets' ]"
echo ""

# ── 2. Schema is small — no re-added field creeps back in ────────────────────
# Every field is a liability once something consumes it. These were considered
# and rejected with stated reasons (see the collector header); this assertion is
# what stops them being quietly re-added.
echo "2. Schema stays minimal (rejected fields stay rejected)"
assert "top level has exactly the five declared keys" \
  "[ \"\$(jq -r '. | keys_unsorted | join(\",\")' '$IDX')\" = 'schema_version,generated_at,source_digest,project,items' ]"
assert "item has exactly the six declared keys" \
  "[ \"\$(jq -r '.items[0] | keys_unsorted | join(\",\")' '$IDX')\" = 'id,title,status,blocked_on,source,level' ]"
for banned in owner estimate points percent priority updated_at created_at; do
  assert "no '$banned' field anywhere in an item" \
    "! jq -e '[.items[] | keys[]] | index(\"$banned\")' '$IDX' >/dev/null 2>&1"
done
assert "no pre-computed rollup/aggregation at top level" \
  "! jq -e 'has(\"counts\") or has(\"summary\") or has(\"totals\")' '$IDX' >/dev/null 2>&1"
# The schema assertions above prove a `title` KEY exists; nothing proved its
# VALUE. That gap hid a real defect for a full release cycle: on a host where
# awk counts CHARACTERS rather than BYTES (gawk in any UTF-8 locale — the
# default on GitHub-hosted Linux runners), the parser sliced the first two
# characters off every Level-0 title while leaving id, status, source and level
# correct. Nothing here noticed; the only assertion that bit was a message
# string on the duplicate-id FATAL path, which is a bizarre place to learn that
# the index's titles are wrong. So the value is pinned EXACTLY, for both Level-0
# streams, on the ordinary success path.
assert "a backlog item's title round-trips EXACTLY (not off by a character)" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .title' '$IDX')\" = 'Open item' ]"
assert "a todos item's title round-trips EXACTLY (same parser, other stream)" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0007\") | .title' '$IDX')\" = 'Active, blocked on a DEFERRED item in the other file' ]"
echo ""

# ── 3. Scope rules: fences and section boundaries ────────────────────────────
echo "3. Collection scope (below ## Items, fences skipped)"
assert "collects 6 backlog items" \
  "[ \"\$(jq -r '[.items[] | select(.level==\"backlog\")] | length' '$IDX')\" = '6' ]"
assert "collects 1 todo item" \
  "[ \"\$(jq -r '[.items[] | select(.level==\"todo\")] | length' '$IDX')\" = '1' ]"
assert "a todo item below a LATER ## heading is not collected either" \
  "! jq -e '.items[] | select(.id==\"LOOM-6666\")' '$IDX' >/dev/null 2>&1"
assert "item ABOVE ## Items is not collected" \
  "! jq -e '.items[] | select(.id==\"LOOM-7777\")' '$IDX' >/dev/null 2>&1"
assert "item inside a fenced block is not collected" \
  "! jq -e '.items[] | select(.id==\"LOOM-9999\")' '$IDX' >/dev/null 2>&1"
assert "item below a LATER ## heading is not collected" \
  "! jq -e '.items[] | select(.id==\"LOOM-8888\")' '$IDX' >/dev/null 2>&1"
echo ""

# ── 4. All four status values round-trip ─────────────────────────────────────
echo "4. Every status value in the closed vocabulary round-trips"
assert "open round-trips"        "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .status' '$IDX')\" = 'open' ]"
assert "in_progress round-trips" "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0002\") | .status' '$IDX')\" = 'in_progress' ]"
assert "blocked round-trips"     "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0003\") | .status' '$IDX')\" = 'blocked' ]"
assert "done round-trips"        "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0004\") | .status' '$IDX')\" = 'done' ]"
assert "no item carries a status outside the vocabulary" \
  "[ \"\$(jq -r '[.items[] | select(.status | inside(\"open in_progress blocked done\") | not)] | length' '$IDX')\" = '0' ]"
echo ""

# ── 5. blocked_on ────────────────────────────────────────────────────────────
echo "5. blocked_on is populated, and empty (never null) when absent"
assert "LOOM-0003 lists both blockers, in order" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0003\") | .blocked_on | join(\",\")' '$IDX')\" = 'LOOM-0001,LOOM-0002' ]"
assert "an item with no blockers gets an empty array, not null" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .blocked_on | type' '$IDX')\" = 'array' ] && [ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .blocked_on | length' '$IDX')\" = '0' ]"
assert "every blocked_on entry is an array" \
  "[ \"\$(jq -r '[.items[] | select(.blocked_on | type != \"array\")] | length' '$IDX')\" = '0' ]"
echo ""

# ── 5b. External blockers ────────────────────────────────────────────────────
# A blocker is not always another item. Two live items in this repo are blocked
# on a HUMAN (a maintainer answering a proposal; a maintainer archiving another
# repo). Before the `external:` form those were `status:blocked` with an EMPTY
# blocked_on, so a daily brief could say an item was stuck but never why.
#
# The contract is exactly one distinction — inside the index vs outside it —
# carried by the literal `external:` prefix and nothing else. These assertions
# are what stop that collapsing into either "everything is an id" (a guaranteed
# dangling reference) or a taxonomy of blocker types (the ceremony the grammar's
# Deliberately-excluded section exists to prevent).
echo "5b. blocked_on distinguishes an id reference from an external blocker"
assert "an external blocker survives collection verbatim, spaces included" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0005\") | .blocked_on | join(\",\")' '$IDX')\" = 'external:maintainer decision' ]"
assert "external and id blockers coexist in one list, in order" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0006\") | .blocked_on | join(\",\")' '$IDX')\" = 'LOOM-0001,external:upstream release' ]"
assert "an external blocker is a plain string, not a nested object (no taxonomy)" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0005\") | .blocked_on[0] | type' '$IDX')\" = 'string' ]"
assert "no blocker_type / blocker_kind field was invented" \
  "! jq -e '[.items[] | keys[]] | index(\"blocker_type\") or index(\"blocker_kind\")' '$IDX' >/dev/null 2>&1"
assert "every non-external blocker resolves to an id in the index" \
  "[ \"\$(jq -r '[.items[].id] as \$ids | [.items[] | .blocked_on[] | select(startswith(\"external:\") | not) | select(\$ids | index(.) == null)] | length' '$IDX')\" = '0' ]"
echo ""

# ── 5c. TWO STREAMS, ONE ID SPACE ────────────────────────────────────────────
# todos.md (active) and backlog.md (deferred) are two files holding two halves of
# one stream. They carry different `level` values and share ONE id space, because
# an item moves between them by cut-and-paste KEEPING ITS ID, and `blocked_on:`
# references cross freely — a deferred item blocked on an active decision, an
# active item blocked on something parked. If the ids were per-file, a reference
# would have two answers.
echo "5c. todos.md and backlog.md are two levels over ONE id space"
assert "the todo stream carries level 'todo'" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0007\") | .level' '$IDX')\" = 'todo' ]"
assert "the todo item's source.file is todos.md, derived from the path" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0007\") | .source.file' '$IDX')\" = '.logic-loom/memory/todos.md' ]"
assert "a CROSS-STREAM blocked_on resolves: todo LOOM-0007 -> backlog LOOM-0001" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0007\") | .blocked_on | join(\",\")' '$IDX')\" = 'LOOM-0001' ] && [ \"\$(jq -r '[.items[] | select(.id==\"LOOM-0001\")] | length' '$IDX')\" = '1' ]"
assert "the blocker's target is in the OTHER file (this is genuinely cross-stream)" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .level' '$IDX')\" = 'backlog' ]"
assert "both streams land in ONE flat items array (no per-file nesting)" \
  "[ \"\$(jq -rc '[.items[].level] | unique | join(\",\")' '$IDX')\" = 'backlog,feature,spec,todo' ]"
echo ""

# ── 6. source is DERIVED correctly ───────────────────────────────────────────
echo "6. source.file / source.heading are derived, never authored"
assert "backlog item file is the repo-relative source path" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .source.file' '$IDX')\" = '.logic-loom/memory/backlog.md' ]"
assert "backlog item heading is the nearest preceding heading" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0001\") | .source.heading' '$IDX')\" = 'Governance and constitution' ]"
assert "a later heading is picked up for later items" \
  "[ \"\$(jq -r '.items[] | select(.id==\"LOOM-0004\") | .source.heading' '$IDX')\" = 'Dead code and test hygiene' ]"
assert "no source pointer was authored in the fixture (it is fully derived)" \
  "! grep -q 'source:' '$FX/.logic-loom/memory/backlog.md'"
echo ""

# ── 7. Feature plans and SDD specs ───────────────────────────────────────────
echo "7. features/*/plan.md and specs/*/tasks.md collect at their own levels"
assert "plan tasks are qualified <feature>:<task-id>" \
  "jq -e '.items[] | select(.id==\"alpha:t1\")' '$IDX' >/dev/null 2>&1"
assert "plan task level is 'feature'" \
  "[ \"\$(jq -r '.items[] | select(.id==\"alpha:t1\") | .level' '$IDX')\" = 'feature' ]"
assert "plan task heading is the enclosing sprint" \
  "[ \"\$(jq -r '.items[] | select(.id==\"alpha:t1\") | .source.heading' '$IDX')\" = '01-foundations' ]"
assert "absent plan status defaults to open" \
  "[ \"\$(jq -r '.items[] | select(.id==\"alpha:t3\") | .status' '$IDX')\" = 'open' ]"
assert "plan blocked_on refs are qualified so they resolve inside the index" \
  "[ \"\$(jq -r '.items[] | select(.id==\"alpha:t2\") | .blocked_on | join(\",\")' '$IDX')\" = 'alpha:t1' ]"
assert "spec checkbox [x] maps to done" \
  "[ \"\$(jq -r '.items[] | select(.id==\"001-auth:T001\") | .status' '$IDX')\" = 'done' ]"
assert "spec checkbox [ ] maps to open" \
  "[ \"\$(jq -r '.items[] | select(.id==\"001-auth:T002\") | .status' '$IDX')\" = 'open' ]"
assert "spec [P] marker is stripped from the title" \
  "[ \"\$(jq -r '.items[] | select(.id==\"001-auth:T002\") | .title' '$IDX')\" = 'Configure linting' ]"
assert "spec task level is 'spec'" \
  "[ \"\$(jq -r '.items[] | select(.id==\"001-auth:T002\") | .level' '$IDX')\" = 'spec' ]"
echo ""

# ── 8. Determinism ───────────────────────────────────────────────────────────
echo "8. Deterministic: same inputs -> byte-identical output"
SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$FX" --out "$TMP/det-a.json" >/dev/null 2>&1
SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$FX" --out "$TMP/det-b.json" >/dev/null 2>&1
assert "two runs are byte-identical" "cmp -s '$TMP/det-a.json' '$TMP/det-b.json'"
assert "items are sorted by id (LC_ALL=C)" \
  "[ \"\$(jq -r '.items[].id' '$IDX')\" = \"\$(jq -r '.items[].id' '$IDX' | LC_ALL=C sort)\" ]"
echo ""

# ── 9. Zero sources ──────────────────────────────────────────────────────────
echo "9. Zero sources produces a valid EMPTY index, exit 0"
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
bash "$COLLECTOR" "$EMPTY" --out "$TMP/empty.json" >/dev/null 2>&1; RCE=$?
assert "exits 0 with no sources at all" "[ $RCE -eq 0 ]"
assert "still emits valid JSON" "jq -e . '$TMP/empty.json' >/dev/null 2>&1"
assert "items is an empty array" "[ \"\$(jq -r '.items | length' '$TMP/empty.json')\" = '0' ]"
assert "schema_version still present" "[ \"\$(jq -r '.schema_version' '$TMP/empty.json')\" = '1' ]"
assert "unstamped/absent project reads as empty strings, not missing keys" \
  "jq -e '.project | has(\"slug\") and has(\"name\") and has(\"id_prefix\")' '$TMP/empty.json' >/dev/null 2>&1"
assert "repo is omitted when undeclared" \
  "! jq -e '.project | has(\"repo\")' '$TMP/empty.json' >/dev/null 2>&1"
echo ""

# ── 10. Writes nothing outside its output path ───────────────────────────────
# Same technique the project-identity suite uses: shasum manifest of the whole
# fixture tree before and after, with the output path itself excluded.
echo "10. Writes nothing but its output path"
# THE PRECONDITION IS ASSERTED, NOT ASSUMED. This manifest is only evidence if
# the hashes are real. With a bare `shasum ... 2>/dev/null` and no fallback, a
# host that ships only `sha256sum` (common on slim Linux images) produced an
# EMPTY hash for every file — before and after matched trivially and the
# assertion below passed while proving nothing. Mirror the collector's own
# shasum -> sha256sum fallback, and fail loudly if neither exists.
SHATOOL=""
if command -v shasum >/dev/null 2>&1; then SHATOOL="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then SHATOOL="sha256sum"; fi
assert "a sha256 tool exists (without one, the manifest below proves nothing)" \
  "[ -n \"\$SHATOOL\" ]"
manifest() { # $1 = dir  $2 = repo-relative path to exclude
  ( cd "$1" && find . -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      case "${f#./}" in "$2") continue ;; esac
      printf '%s  ' "$f"; $SHATOOL "$f" 2>/dev/null | awk '{print $1}'
    done )
}
FX2="$TMP/fx2"
rm -rf "$FX2"; cp -R "$FX" "$FX2"; rm -f "$FX2/$OUT_REL"
manifest "$FX2" "$OUT_REL" > "$TMP/before.txt"
SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$FX2" >/dev/null 2>&1
manifest "$FX2" "$OUT_REL" > "$TMP/after.txt"
assert "no file in the fixture tree changed except the output" \
  "diff -q '$TMP/before.txt' '$TMP/after.txt' >/dev/null 2>&1"
assert "the output itself WAS written" "[ -f '$FX2/$OUT_REL' ]"
echo ""

# ── 11. Runs no git ──────────────────────────────────────────────────────────
# A PATH shim records any invocation. Stronger than reading the source: it
# catches a git call reached through a variable or a helper.
echo "11. Runs no git (runtime PATH shim, not a source grep)"
mkdir -p "$TMP/shim"
cat > "$TMP/shim/git" <<'SHIM_EOF'
#!/bin/sh
echo "$@" >> "$GIT_SHIM_LOG"
exit 1
SHIM_EOF
chmod +x "$TMP/shim/git"
: > "$TMP/git-calls.log"
FX3="$TMP/fx3"; rm -rf "$FX3"; cp -R "$FX" "$FX3"
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" \
  SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$FX3" >/dev/null 2>&1
assert "collector invoked git zero times" "[ ! -s '$TMP/git-calls.log' ]"
: > "$TMP/git-calls.log"
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" \
  bash "$LINTER" "$FX3" >/dev/null 2>&1
assert "linter invoked git zero times" "[ ! -s '$TMP/git-calls.log' ]"
echo ""

# ── 12. The output path is gitignored and untracked ──────────────────────────
# THE load-bearing decision. Checked three ways: the ignore rule is declared,
# git does not track the path, and — functionally, in a throwaway repo built from
# THIS repo's .gitignore — an existing index is invisible to `git status`.
echo "12. The index is gitignored and NOT tracked"
assert ".gitignore declares the index path" \
  "grep -qxF '.logic-loom/backlog-index.json' '$ROOT/.gitignore'"
TRACKED="$(git ls-files 2>/dev/null | grep -xF "$OUT_REL" || true)"
assert "git does not track the index" "[ -z \"\$TRACKED\" ]"
GR="$TMP/gitignore-probe"
mkdir -p "$GR/.logic-loom"
cp "$ROOT/.gitignore" "$GR/.gitignore"
( cd "$GR" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '{}' > "$GR/$OUT_REL"
PROBE="$(cd "$GR" && git status --porcelain 2>/dev/null | grep -F 'backlog-index.json' || true)"
assert "an index file is invisible to git status under this .gitignore" "[ -z \"\$PROBE\" ]"
echo ""

# ── 13. Linter: every defect class fires ─────────────────────────────────────
# One fixture per class, run with --strict so the exit code is the proof.
echo "13. Linter fires on each defect class it claims"
mkfx() { # $1 = name, rest = item lines
  local n="$1"; shift
  mkdir -p "$TMP/lint/$n/.logic-loom/memory"
  { echo "# fixture"; echo; echo "## Items"; echo
    for l in "$@"; do printf '%s\n' "$l"; done; } \
    > "$TMP/lint/$n/.logic-loom/memory/backlog.md"
}
# `|| true` matters: --strict exits 1 on a finding, and `set -o pipefail` would
# otherwise fail the whole `lint_out X | grep` pipeline no matter what grep found.
lint_out() { bash "$LINTER" "$TMP/lint/$1" --strict --quiet 2>&1 || true; }
lint_rc()  { bash "$LINTER" "$TMP/lint/$1" --strict --quiet >/dev/null 2>&1; echo $?; }

mkfx clean '- [ ] LOOM-0001 — Fine `status:open`' '- [x] LOOM-0002 — Also fine `status:done`'
assert "a clean backlog produces no findings (--strict exits 0)" "[ \"\$(lint_rc clean)\" = '0' ]"

mkfx unparseable '- [ ] LOOM-0001 - hyphen, not an em dash `status:open`'
assert "unparseable: --strict exits 1" "[ \"\$(lint_rc unparseable)\" = '1' ]"
assert "unparseable: names the class" "grep -q '^unparseable:' <<< \"\$(lint_out unparseable)\""

mkfx duplicate '- [ ] LOOM-0001 — First `status:open`' '- [ ] LOOM-0001 — Second `status:open`'
assert "duplicate-id: --strict exits 1" "[ \"\$(lint_rc duplicate)\" = '1' ]"
assert "duplicate-id: names the class and the id" \
  "grep -q \"^duplicate-id:.*LOOM-0001\" <<< \"\$(lint_out duplicate)\""

mkfx badstatus '- [ ] LOOM-0001 — Bad vocabulary `status:wip`'
assert "bad-status: --strict exits 1" "[ \"\$(lint_rc badstatus)\" = '1' ]"
assert "bad-status: names the class and the offending value" \
  "grep -q \"^bad-status:.*'wip'\" <<< \"\$(lint_out badstatus)\""

mkfx unknownblocker '- [ ] LOOM-0001 — Dangling blocker `status:blocked` `blocked_on:LOOM-0099`'
assert "unknown-blocker: --strict exits 1" "[ \"\$(lint_rc unknownblocker)\" = '1' ]"
assert "unknown-blocker: names the class and the missing id" \
  "grep -q \"^unknown-blocker:.*LOOM-0099\" <<< \"\$(lint_out unknownblocker)\""

mkfx boxmismatch '- [x] LOOM-0001 — Box says done, tag says open `status:open`' \
                 '- [ ] LOOM-0002 — Tag says done, box says open `status:done`'
assert "checkbox-mismatch: --strict exits 1" "[ \"\$(lint_rc boxmismatch)\" = '1' ]"
assert "checkbox-mismatch: fires in BOTH directions" \
  "[ \"\$(lint_out boxmismatch | grep -c '^checkbox-mismatch:')\" = '2' ]"

mkfx prefixmismatch '- [ ] WRONG-0001 — Not the declared prefix `status:open`'
mkdir -p "$TMP/lint/prefixmismatch/.logic-loom/config"
printf 'project_slug = acme\nproject_name = ACME\nid_prefix    = LOOM\n' \
  > "$TMP/lint/prefixmismatch/.logic-loom/config/project.conf"
assert "prefix-mismatch: --strict exits 1" "[ \"\$(lint_rc prefixmismatch)\" = '1' ]"
assert "prefix-mismatch: names the class and the declared prefix" \
  "grep -q \"^prefix-mismatch:.*'LOOM'\" <<< \"\$(lint_out prefixmismatch)\""

# Unstamped project: nothing to compare against, so the class must go quiet
# rather than telling a fresh clone its backlog is wrong.
mkfx unstamped '- [ ] WHATEVER-0001 — Any prefix `status:open`'
mkdir -p "$TMP/lint/unstamped/.logic-loom/config"
printf 'project_slug = __UNSET__\nproject_name = __UNSET__\nid_prefix    = __UNSET__\n' \
  > "$TMP/lint/unstamped/.logic-loom/config/project.conf"
assert "prefix-mismatch is SKIPPED on an unstamped project" "[ \"\$(lint_rc unstamped)\" = '0' ]"
echo ""

# ── 14. Linter default mode never blocks ─────────────────────────────────────
# .docs/architecture/project-graph-convention.md names a blocking linter as an
# explicit tripwire; lint-graph.sh always exits 0 for the same reason.
echo "14. Default mode is warn-and-exit-0 (--strict is opt-in for CI)"
assert "a defective backlog still exits 0 without --strict" \
  "bash '$LINTER' '$TMP/lint/duplicate' --quiet >/dev/null 2>&1"
assert "an absent backlog exits 0" "bash '$LINTER' '$TMP/empty-root' --quiet >/dev/null 2>&1"
echo ""

# ── 14b. Linter is aware of the external-blocker distinction ─────────────────
echo "14b. Linter: external blockers exempt from unknown-blocker, bare ones flagged"
mkfx extblocker '- [ ] LOOM-0001 — Blocked outside the index `status:blocked` `blocked_on:external:maintainer decision`'
assert "an external blocker does NOT trip unknown-blocker (--strict exits 0)" \
  "[ \"\$(lint_rc extblocker)\" = '0' ]"

mkfx extmixed '- [ ] LOOM-0001 — Anchor `status:open`' \
              '- [ ] LOOM-0002 — Mixed blockers `status:blocked` `blocked_on:LOOM-0001,external:upstream release`'
assert "an id blocker still resolves alongside an external one" \
  "[ \"\$(lint_rc extmixed)\" = '0' ]"

mkfx extdangling '- [ ] LOOM-0001 — Real dangling ref `status:blocked` `blocked_on:LOOM-0099`' \
                 '- [ ] LOOM-0002 — External, fine `status:blocked` `blocked_on:external:a person`'
assert "the external form does not suppress a genuine dangling id" \
  "[ \"\$(lint_rc extdangling)\" = '1' ]"
assert "exactly one unknown-blocker fires, and it names the dangling id" \
  "[ \"\$(lint_out extdangling | grep -c '^unknown-blocker:')\" = '1' ] && grep -q 'LOOM-0099' <<< \"\$(lint_out extdangling)\""

mkfx extbare '- [ ] LOOM-0001 — Reason withheld `status:blocked` `blocked_on:external:`'
assert "a bare 'external:' with no reason is a finding" "[ \"\$(lint_rc extbare)\" = '1' ]"
echo ""

# ── 14c. THE COLLECTOR REFUSES TO PUBLISH SOMETHING WRONG ────────────────────
# The load-bearing split: lint-backlog.sh advises the AUTHOR and exits 0; the
# collector produces an artifact something CONSUMES and must never drop an item
# quietly, because a consumer cannot tell "this item does not exist" from "the
# collector dropped it". A stale-but-true index beats a fresh-but-lying one — the
# consumer can detect staleness (that is what source_digest is for) and cannot
# detect a silent drop.
#
# So each fixture asserts THREE things, not one: non-zero exit, a message naming
# the defect, and — the part that actually protects a consumer — that a
# PRE-EXISTING index is left byte-for-byte untouched.
echo "14c. Collector FAILS on a fatal source defect and writes nothing"
fatalfx() { # $1 = name, rest = item lines below ## Items
  local n="$1"; shift
  mkdir -p "$TMP/fatal/$n/.logic-loom/memory"
  { echo "# fixture"; echo; echo "## Items"; echo
    for l in "$@"; do printf '%s\n' "$l"; done; } \
    > "$TMP/fatal/$n/.logic-loom/memory/backlog.md"
  # A previous, GOOD index that must survive the failed run intact.
  printf '{"schema_version":1,"items":["PREVIOUS"]}' \
    > "$TMP/fatal/$n/.logic-loom/backlog-index.json"
}
fatal_rc() { SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$TMP/fatal/$1" >/dev/null 2>&1; echo $?; }
fatal_err() { SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$TMP/fatal/$1" 2>&1 >/dev/null || true; }
prev_intact() { grep -q 'PREVIOUS' "$TMP/fatal/$1/.logic-loom/backlog-index.json" 2>/dev/null; }

fatalfx dupid '- [ ] LOOM-0001 — First copy `status:open`' \
              '- [ ] LOOM-0001 — Second copy `status:blocked`'
assert "duplicate id: collector exits non-zero" "[ \"\$(fatal_rc dupid)\" != '0' ]"
assert "duplicate id: exit code is the documented 3" "[ \"\$(fatal_rc dupid)\" = '3' ]"
assert "duplicate id: message names the defect and the id" \
  "grep -q \"duplicate id 'LOOM-0001'\" <<< \"\$(fatal_err dupid)\""
assert "duplicate id: message points at BOTH occurrences" \
  "grep -q 'First copy' <<< \"\$(fatal_err dupid)\" && grep -q 'Second copy' <<< \"\$(fatal_err dupid)\""
assert "duplicate id: the previous index is left UNTOUCHED" "prev_intact dupid"

fatalfx malformed '- [ ] LOOM-0001 — Fine `status:open`' \
                  '- [ ] LOOM-0002 - hyphen instead of an em dash `status:open`'
assert "malformed item line: collector exits 3" "[ \"\$(fatal_rc malformed)\" = '3' ]"
assert "malformed item line: message names the line and the reason" \
  "grep -q 'separator' <<< \"\$(fatal_err malformed)\""
assert "malformed item line: the previous index is left UNTOUCHED" "prev_intact malformed"

fatalfx badid '- [ ] loom-1 — lowercase, too few digits `status:open`'
assert "malformed id: collector exits 3" "[ \"\$(fatal_rc badid)\" = '3' ]"
assert "malformed id: the previous index is left UNTOUCHED" "prev_intact badid"

fatalfx nostatus '- [ ] LOOM-0001 — No status tag at all'
assert "missing status tag: collector exits 3" "[ \"\$(fatal_rc nostatus)\" = '3' ]"
assert "missing status tag: the previous index is left UNTOUCHED" "prev_intact nostatus"

fatalfx badstatus '- [ ] LOOM-0001 — Outside the vocabulary `status:wip`'
assert "out-of-vocabulary status: collector exits 3" "[ \"\$(fatal_rc badstatus)\" = '3' ]"
assert "out-of-vocabulary status: message names the offending value" \
  "grep -q \"'wip'\" <<< \"\$(fatal_err badstatus)\""
assert "out-of-vocabulary status: the previous index is left UNTOUCHED" "prev_intact badstatus"

# The scope rules still win: a malformed line that is NOT an item is not fatal.
fatalfx outofscope '- [ ] LOOM-0001 — Fine `status:open`'
cat >> "$TMP/fatal/outofscope/.logic-loom/memory/backlog.md" <<'OOS_EOF'

```
- [ ] BROKEN - inside a fence, not an item
```

## Provenance

- [ ] ALSO-BROKEN - below a later heading, not an item
OOS_EOF
assert "a malformed line inside a fence is NOT fatal (scope rules win)" \
  "[ \"\$(fatal_rc outofscope)\" = '0' ]"
assert "a malformed line below a later ## heading is NOT fatal" \
  "jq -e '.items | length == 1' \"\$TMP/fatal/outofscope/.logic-loom/backlog-index.json\" >/dev/null 2>&1"

# A clean run must still overwrite the previous index — the refusal is targeted,
# not a general reluctance to write.
fatalfx cleanrun '- [ ] LOOM-0001 — Fine `status:open`'
assert "a CLEAN run exits 0 and does replace the previous index" \
  "[ \"\$(fatal_rc cleanrun)\" = '0' ] && ! prev_intact cleanrun"
echo ""

# ── 14d. A COLLIDING ID ACROSS THE TWO STREAMS ───────────────────────────────
# The one failure mode the split introduces. Each file alone is clean — the same
# id minted once in todos.md and once in backlog.md is only wrong when you look
# at both, which is exactly why the linter and the collector both look at both.
#
# Proved on the real machinery in a throwaway tree, from both ends:
#   * the LINTER reports duplicate-id and names BOTH files (author-facing);
#   * the COLLECTOR treats it as fatal — exit 3, nothing written (consumer-facing).
echo "14d. A colliding id minted in BOTH todos.md and backlog.md is caught"
COL="$TMP/collide"
mkdir -p "$COL/.logic-loom/memory"
{ echo "# todos"; echo; echo "## Items"; echo
  printf -- '- [ ] LOOM-0030 — Minted in todos.md `status:open`\n'; } \
  > "$COL/.logic-loom/memory/todos.md"
{ echo "# backlog"; echo; echo "## Items"; echo
  printf -- '- [ ] LOOM-0030 — Minted AGAIN in backlog.md `status:open`\n'; } \
  > "$COL/.logic-loom/memory/backlog.md"
# A previous, good index that must survive the refusal untouched.
printf '{"schema_version":1,"items":["PREVIOUS"]}' > "$COL/.logic-loom/backlog-index.json"

COL_LINT="$(bash "$LINTER" "$COL" --strict --quiet 2>&1 || true)"
COL_LINT_RC=0; bash "$LINTER" "$COL" --strict --quiet >/dev/null 2>&1 || COL_LINT_RC=$?
assert "linter: --strict exits 1 on the cross-file collision" "[ \"\$COL_LINT_RC\" = '1' ]"
assert "linter: reports it as duplicate-id and names the id" \
  "grep -q '^duplicate-id:.*LOOM-0030' <<< \"\$COL_LINT\""
assert "linter: names BOTH files, so the author knows where to look" \
  "grep -q 'todos.md' <<< \"\$COL_LINT\" && grep -q 'backlog.md' <<< \"\$COL_LINT\""

COL_RC=0; SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$COL" >/dev/null 2>&1 || COL_RC=$?
COL_ERR="$(SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$COL" 2>&1 >/dev/null || true)"
assert "collector: the collision is FATAL (documented exit 3)" "[ \"\$COL_RC\" = '3' ]"
assert "collector: the error names the duplicated id" \
  "grep -q \"duplicate id 'LOOM-0030'\" <<< \"\$COL_ERR\""
assert "collector: the error points at BOTH source files" \
  "grep -q 'todos.md' <<< \"\$COL_ERR\" && grep -q 'backlog.md' <<< \"\$COL_ERR\""
assert "collector: nothing was written — the previous index is UNTOUCHED" \
  "grep -q 'PREVIOUS' '$COL/.logic-loom/backlog-index.json'"

# The control: the SAME two files with distinct ids are clean end to end. Without
# this, the assertions above would also pass if the split had simply broken
# collection of one of the files.
sed -i.bak 's/LOOM-0030 — Minted AGAIN/LOOM-0031 — Minted once/' "$COL/.logic-loom/memory/backlog.md"
rm -f "$COL/.logic-loom/memory/backlog.md.bak"
OK_RC=0; SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$COL" >/dev/null 2>&1 || OK_RC=$?
assert "control: distinct ids across the two files collect cleanly (exit 0)" "[ \"\$OK_RC\" = '0' ]"
assert "control: both items are in the index, one per level" \
  "[ \"\$(jq -rc '[.items[] | {(.level): .id}] | add | [.todo, .backlog] | join(\",\")' '$COL/.logic-loom/backlog-index.json')\" = 'LOOM-0030,LOOM-0031' ]"
assert "control: the linter is silent on it (--strict exits 0)" \
  "bash '$LINTER' '$COL' --strict --quiet >/dev/null 2>&1"
echo ""

# ── 14e. --next-id derives the counter from BOTH files ───────────────────────
# The counter is DERIVED, not stored. A stored "next id" would live in one of the
# two files and be silently wrong the moment an item was appended to the other,
# which is the exact drift the split would otherwise have introduced.
echo "14e. --next-id is derived across both streams, never stored"
assert "next id is (highest across BOTH files) + 1" \
  "[ \"\$(bash '$LINTER' '$COL' --next-id 2>/dev/null)\" = 'LOOM-0032' ]"
printf -- '- [ ] LOOM-0099 — A much later id, in the TODOS half `status:open`\n' \
  >> "$COL/.logic-loom/memory/todos.md"
assert "it follows the highest id wherever it lives (todos this time)" \
  "[ \"\$(bash '$LINTER' '$COL' --next-id 2>/dev/null)\" = 'LOOM-0100' ]"
assert "no file in the repo stores a literal 'Next id to mint: LOOM-NNNN'" \
  "! grep -rEq 'Next id to mint: [A-Z]+-[0-9]{4}' '$ROOT/.logic-loom/memory/' 2>/dev/null"
assert "--next-id writes nothing (the two source files are unchanged)" \
  "[ \"\$(bash '$LINTER' '$COL' --next-id 2>/dev/null)\" = 'LOOM-0100' ]"
echo ""

# ── 15. Live check against the REAL repo ─────────────────────────────────────
# Guards a vacuous pass: if the parser broke, the real backlog would collect zero
# items and every fixture assertion above could still be green.
# Linter findings on real content are REPORTED, not asserted.
echo "15. Live: the real backlog collects, and lints in warn-only mode"
SOURCE_DATE_EPOCH=1700000000 bash "$COLLECTOR" "$ROOT" --out "$TMP/real.json" >/dev/null 2>"$TMP/real.err"; REAL_RC=$?
assert "real repo collects with no fatal defect (exit 0)" "[ $REAL_RC -eq 0 ]"
assert "real repo produces valid JSON" "jq -e . '$TMP/real.json' >/dev/null 2>&1"
REAL_N="$(jq -r '.items | length' "$TMP/real.json" 2>/dev/null || echo 0)"
echo "     (collected $REAL_N item(s) from the real repo)"
if [ "$TREE_KIND" = "sanitized" ]; then
  # The shipped .logic-loom/memory/todos.md and backlog.md are EMPTY STUBS by
  # design (template-strip-manifest.txt `stub:` entries) — a fresh sanitized
  # clone has no items in either stream until a customer starts using it. That
  # is the whole point of the stub, not a defect, so "at least one" and "both
  # streams populated" cannot hold here.
  skip "real backlog collects at least one item" \
    "todos.md/backlog.md are empty stubs by design — sanitized tree"
  skip "the real repo collects items from BOTH Level 0 streams" \
    "todos.md/backlog.md are empty stubs by design — sanitized tree"
else
assert "real backlog collects at least one item" "[ \"$REAL_N\" -ge 1 ]"
# Both halves of Level 0 must actually be reached in THIS repo. A parser that
# silently stopped reading one of the two files would leave every fixture above
# green while half the real work vanished from every consumer.
assert "the real repo collects items from BOTH Level 0 streams" \
  "[ \"\$(jq -r '[.items[] | select(.level==\"todo\")] | length' '$TMP/real.json')\" -ge 1 ] && [ \"\$(jq -r '[.items[] | select(.level==\"backlog\")] | length' '$TMP/real.json')\" -ge 1 ]"
fi
assert "every real cross-stream blocker resolves inside the index" \
  "[ \"\$(jq -r '[.items[].id] as \$ids | [.items[] | .blocked_on[] | select(startswith(\"external:\") | not) | select(\$ids | index(.) == null)] | length' '$TMP/real.json')\" = '0' ]"
assert "collector emitted no parse warnings on real sources" \
  "! grep -q '^WARN:' '$TMP/real.err'"
bash "$LINTER" "$ROOT" > "$TMP/lint-real.out" 2>&1; REAL_LINT_RC=$?
assert "linting the real repo in default mode exits 0" "[ $REAL_LINT_RC -eq 0 ]"
REAL_FINDINGS="$(grep -cE '^(unparseable|duplicate-id|prefix-mismatch|unknown-blocker|bad-status|checkbox-mismatch):' "$TMP/lint-real.out" 2>/dev/null || true)"
echo "     (linter findings on the real backlog: ${REAL_FINDINGS:-0} — reported, not asserted)"
[ "${REAL_FINDINGS:-0}" != "0" ] && sed -n '1,20p' "$TMP/lint-real.out" | sed 's/^/       /'
echo ""

echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
