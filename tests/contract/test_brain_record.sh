#!/usr/bin/env bash
# Contract Tests: the `.brain/` layer — memory-backend resolution, the
# fail-closed record gate, and the advisory's silence rules.
#
# THREE THINGS ARE UNDER TEST, and they have deliberately different strengths:
#
#   1. resolve-memory-backend.sh   — the ONE answer to "where does durable
#      memory go". The regression it prevents is the one that motivated it: a
#      hardcoded path in prose, quietly feeding a second store nobody reads.
#      The load-bearing assertions are the DEFAULT (now `repo`, in-tree, not
#      the old per-machine `project` path) and PURITY: resolution is a
#      function of (env, conf) only, never a filesystem probe — a probe would
#      resolve differently in a worktree than in the main checkout of the same
#      repo, which is the exact defect this resolver exists to kill.
#
#   2. check-brain-record.sh       — FAIL-CLOSED. Every one of its five checks
#      is tested BOTH ways: it passes on a good tree AND it actually fails on a
#      planted violation. A gate nobody has seen fail is a gate nobody knows
#      works. It must also pass VACUOUSLY on an absent `.brain/`, because that
#      is what a cloner who never opts in has, and a permanently red build is
#      the fastest route to the gate being deleted.
#
#   3. check-brain-signals.sh      — ADVISORY. The assertions that matter are
#      the SILENCE ones: silent with no `.brain/`, silent on an unadopted
#      routine, silent when an old log sits over an empty queue. An advisory
#      that nags is an advisory that gets tuned out, and tuning it out is
#      indistinguishable from deleting it.
#
# Every fixture is built in a scratch tree under $TMPDIR. Nothing here writes
# into the repo, and nothing runs git.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${v,,}, no [[ -v ]].

set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
# skip <desc> <reason> — NOT counted in PASS/FAIL/TOTAL. See tests/lib/tree-provenance.sh.
skip() { SKIP=$((SKIP + 1)); echo "  ⏭  SKIP: $1 — $2"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# THIS SUITE SHIPS, so a cloner's first push runs it on a SANITIZED tree where
# template-strip-manifest.txt is itself stripped (it is maintainer-only release
# plumbing). Asserting on the manifest unconditionally would hand every cloner a
# red build on day one — the exact failure class test_shipped_gates_vs_strip.sh
# exists to catch, and it caught this suite. Named skips, not a silent exit.
# shellcheck source=../lib/tree-provenance.sh
source "$ROOT/tests/lib/tree-provenance.sh"
if ! loom_require_consistent_tree "$ROOT"; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi
TREE_KIND="$(loom_tree_kind "$ROOT")"

RESOLVER="$ROOT/.logic-loom/scripts/bash/resolve-memory-backend.sh"
GATE="$ROOT/.logic-loom/scripts/bash/check-brain-record.sh"
SIGNALS="$ROOT/.logic-loom/scripts/bash/check-brain-signals.sh"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/loom-brain-test.XXXXXX")"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT

# Deterministic "today" so the advisory's day arithmetic is not a flake source.
TODAY="2026-09-01"

echo "════════════════════════════════════════════"
echo "  Brain Layer Contract Tests"
echo "════════════════════════════════════════════"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 1: files exist and parse ───────────────────────────────────────"
for f in "$RESOLVER" "$GATE" "$SIGNALS"; do
  assert "$(basename "$f") exists" "[ -f '$f' ]"
  assert "$(basename "$f") is syntactically valid" "bash -n '$f' 2>/dev/null"
done
assert ".brain/README.md exists (the shipped contract)" "[ -f '$ROOT/.brain/README.md' ]"
assert "brain-readme-template.md exists (the release stub)" \
  "[ -f '$ROOT/.logic-loom/templates/brain-readme-template.md' ]"
assert "distill-schedule-prompt.md exists (printed, never installed)" \
  "[ -f '$ROOT/.logic-loom/templates/distill-schedule-prompt.md' ]"
assert "memory-backend.conf exists" "[ -f '$ROOT/.logic-loom/config/memory-backend.conf' ]"
assert "brain.conf exists" "[ -f '$ROOT/.logic-loom/config/brain.conf' ]"
assert "/distill command exists" \
  "[ -f '$ROOT/plugins/loom-orchestrator/commands/distill.md' ]"
assert "distillation-pass skill exists" \
  "[ -f '$ROOT/plugins/loom-orchestrator/skills/distillation-pass/SKILL.md' ]"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 2: memory backend resolution ───────────────────────────────────"

FAKE_REPO="$TMPROOT/repo"
mkdir -p "$FAKE_REPO"
EXPECTED_PROJECT="$HOME/.claude/projects/$(printf '%s' "$FAKE_REPO" | sed 's|/|-|g')/memory"

# THE load-bearing assertion: absent config resolves to the new DEFAULT
# backend, `repo`, not the old per-machine `project` path.
NO_CONF_OUT="$(LOOM_REPO_ROOT="$FAKE_REPO" LOOM_MEMORY_CONF="$TMPROOT/absent.conf" \
  bash "$RESOLVER" --path 2>/dev/null)"
assert "absent config defaults to backend 'repo'" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/absent.conf' bash '$RESOLVER' --backend 2>/dev/null)\" = 'repo' ]"
assert "absent config resolves to <FAKE_REPO>/.brain/memory" \
  "[ '$NO_CONF_OUT' = '$FAKE_REPO/.brain/memory' ]"
assert "absent config exits 0 (never fails a caller)" \
  "LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/absent.conf' bash '$RESOLVER' >/dev/null 2>&1"

printf 'memory_backend = repo\n' > "$TMPROOT/repo.conf"
assert "memory_backend = repo resolves to <repo>/.brain/memory" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/repo.conf' bash '$RESOLVER' --path)\" = '$FAKE_REPO/.brain/memory' ]"

printf 'memory_backend = project\n' > "$TMPROOT/project.conf"
assert "memory_backend = project resolves to \$HOME/.claude/projects/<slug>/memory" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/project.conf' bash '$RESOLVER' --path)\" = '$EXPECTED_PROJECT' ]"

# There is no third backend any more (see the resolver's header comment for
# why it was DELETED, not merely commented out). The space-in-path coverage
# that used to exercise its configured absolute path still applies to the two
# backends that remain — build the fake repo itself under a directory whose
# name has a space in it, and confirm --path comes back correct and unsplit.
FAKE_REPO_SPACE="$TMPROOT/my repo"
mkdir -p "$FAKE_REPO_SPACE"
assert "a repo path containing a space survives unsplit (memory_backend = repo)" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO_SPACE' LOOM_MEMORY_CONF='$TMPROOT/repo.conf' bash '$RESOLVER' --path)\" = '$FAKE_REPO_SPACE/.brain/memory' ]"

# Fail-SAFE, not fail-closed: losing a retrospective to a config typo is worse
# than writing it to the default store and saying so. The fallback target
# moved with the default — it is now 'repo', not 'project'.
printf 'memory_backend = nonsense\n' > "$TMPROOT/bad.conf"
assert "unrecognised backend falls back to 'repo'" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/bad.conf' bash '$RESOLVER' --backend 2>/dev/null)\" = 'repo' ]"
assert "unrecognised backend still exits 0" \
  "LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/bad.conf' bash '$RESOLVER' >/dev/null 2>&1"
assert "unrecognised backend WARNS on stderr (silent fallback would hide it)" \
  "LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/bad.conf' bash '$RESOLVER' 2>&1 >/dev/null | grep -q 'falling back'"

assert "env LOOM_MEMORY_BACKEND overrides the config file" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/project.conf' LOOM_MEMORY_BACKEND=repo bash '$RESOLVER' --backend)\" = 'repo' ]"

assert "--ensure creates the directory and prints it" \
  "[ \"\$(LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/repo.conf' bash '$RESOLVER' --ensure)\" = '$FAKE_REPO/.brain/memory' ] && [ -d '$FAKE_REPO/.brain/memory' ]"
rm -rf "$FAKE_REPO/.brain"

LOOM_REPO_ROOT="$FAKE_REPO" LOOM_MEMORY_CONF="$TMPROOT/repo.conf" bash "$RESOLVER" --explain > "$TMPROOT/explain.out" 2>&1
assert "--explain names the resolved backend" "grep -q 'resolved  *: repo' '$TMPROOT/explain.out'"
assert "--explain names the memory path" "grep -q 'memory path  *: $FAKE_REPO/.brain/memory' '$TMPROOT/explain.out'"

assert "an inline comment on the value is stripped" \
  "[ \"\$(printf 'memory_backend = repo   # why\n' > '$TMPROOT/c.conf'; LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/c.conf' bash '$RESOLVER' --backend)\" = 'repo' ]"

# A value distinct from the new default ('project') proves the commented-out
# line is truly not read — reading it would give 'project', not 'repo'.
assert "a commented-out key is not read" \
  "[ \"\$(printf '# memory_backend = project\n' > '$TMPROOT/d.conf'; LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/d.conf' bash '$RESOLVER' --backend)\" = 'repo' ]"

no_git_calls() { sed 's/[[:space:]]*#.*$//' "$1" | grep -qE '(^|[;&|(]|\bthen |\bdo )[[:space:]]*git[[:space:]]'; }
assert "the resolver never invokes git (comments stripped, code scanned)" "! no_git_calls '$RESOLVER'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 3: resolution is a PURE function of (env, conf) ────────────────"
# The regression that matters most here: a filesystem-dependent default would
# resolve DIFFERENTLY in a worktree than in the main checkout of the same
# project (same slug logic, same $HOME, different REPO_ROOT) — two stores,
# neither aware of the other, which is verbatim the defect this resolver
# exists to kill. Build a fake $HOME with a POPULATED legacy store and prove
# its mere presence does not move the answer. HOME is passed explicitly on
# every invocation so this suite never depends on the tester's real home.
PURE_HOME="$TMPROOT/pure-home"
PURE_SLUG="$(printf '%s' "$FAKE_REPO" | sed 's|/|-|g')"
PURE_LEGACY_DIR="$PURE_HOME/.claude/projects/$PURE_SLUG/memory"
mkdir -p "$PURE_LEGACY_DIR"
printf 'an old lesson\n' > "$PURE_LEGACY_DIR/lesson.md"

assert "a populated legacy store does NOT change the default (--backend is still 'repo')" \
  "[ \"\$(HOME='$PURE_HOME' LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/absent.conf' bash '$RESOLVER' --backend 2>/dev/null)\" = 'repo' ]"
assert "with the same populated legacy store, memory_backend = project still resolves to 'project'" \
  "[ \"\$(HOME='$PURE_HOME' LOOM_REPO_ROOT='$FAKE_REPO' LOOM_MEMORY_CONF='$TMPROOT/project.conf' bash '$RESOLVER' --backend 2>/dev/null)\" = 'project' ]"

# A simple, honest form of "no filesystem probe wired into default selection":
# the resolver never calls `find` at all. Same style as no_git_calls above —
# comments stripped, code scanned.
no_find_calls() { sed 's/[[:space:]]*#.*$//' "$1" | grep -qE '(^|[^a-zA-Z_-])find[[:space:]]'; }
assert "the resolver contains no filesystem probe (never calls 'find')" "! no_find_calls '$RESOLVER'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 2 (cont.): shipped config ───────────────────────────────────────"
# EXPECTED TO FAIL RIGHT NOW: the shipped memory-backend.conf has not yet been
# updated by the maintainer to declare the new default. That is the point of
# this assertion — it is the gate telling the maintainer the edit is still
# outstanding, not a bug in this suite.
assert "shipped memory-backend.conf declares 'repo'" \
  "grep -qE '^[[:space:]]*memory_backend[[:space:]]*=[[:space:]]*repo[[:space:]]*$' '$ROOT/.logic-loom/config/memory-backend.conf'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 4: nothing still hardcodes a memory path ───────────────────────"

# The actual bug: /retro fed one store while the maintainer's router pointed at
# another. These assertions are what stop it coming back.
assert "/retro SKILL.md resolves the backend instead of hardcoding a path" \
  "grep -q 'resolve-memory-backend.sh' '$ROOT/plugins/loom-orchestrator/skills/retro/SKILL.md'"
assert "/retro command resolves the backend" \
  "grep -q 'resolve-memory-backend.sh' '$ROOT/plugins/loom-orchestrator/commands/retro.md'"
assert "keyword search backend resolves the backend" \
  "grep -q 'resolve-memory-backend.sh' '$ROOT/plugins/loom-memory/lib/keyword-backend.sh'"
assert "bm25 search backend resolves the backend" \
  "grep -q 'resolve-memory-backend.sh' '$ROOT/plugins/loom-memory/lib/bm25-search.sh'"

# A literal `$HOME/.claude/projects/.../memory` in an INSTRUCTION is the defect.
# The fallbacks inside the search backends are deliberate and are excluded by
# checking the two agent-facing files only.
assert "/retro SKILL.md no longer names a literal \$HOME/.claude/projects memory path as the target" \
  "! grep -qE 'HOME/\.claude/projects/\\\$\{?slug' '$ROOT/plugins/loom-orchestrator/skills/retro/SKILL.md'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 5: the gate is VACUOUS on an unadopted tree ────────────────────"

EMPTY_TREE="$TMPROOT/empty"
mkdir -p "$EMPTY_TREE"
assert "no .brain/ at all -> exit 0 (a cloner's day-one CI is green)" \
  "LOOM_REPO_ROOT='$EMPTY_TREE' LOOM_BRAIN_ROOT='$EMPTY_TREE/.brain' bash '$GATE' -q"

README_ONLY="$TMPROOT/readme-only/.brain"
mkdir -p "$README_ONLY"
printf '# brain\n' > "$README_ONLY/README.md"
assert ".brain/ holding only README.md -> exit 0" \
  "LOOM_REPO_ROOT='$TMPROOT/readme-only' LOOM_BRAIN_ROOT='$README_ONLY' bash '$GATE' -q"

mkdir -p "$README_ONLY/raw/research"
printf '# raw\n' > "$README_ONLY/raw/README.md"
assert "empty layer dirs + layer READMEs -> exit 0 (READMEs are not captures)" \
  "LOOM_REPO_ROOT='$TMPROOT/readme-only' LOOM_BRAIN_ROOT='$README_ONLY' bash '$GATE' -q"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 6: the gate PASSES on a well-formed record ─────────────────────"

GOOD="$TMPROOT/good/.brain"
mkdir -p "$GOOD/raw/research" "$GOOD/wiki/concepts"
cat > "$GOOD/raw/research/20260901-alpha.md" <<'EOF'
---
type: capture
title: "Alpha"
date: 2026-09-01
source: "/research alpha"
status: processed
distilled-into: .brain/wiki/concepts/alpha.md
---
body
EOF
cat > "$GOOD/raw/research/20260901-beta.md" <<'EOF'
---
type: capture
title: "Beta"
date: 2026-09-01
source: "/research beta"
status: "unprocessed"
---
body
EOF
cat > "$GOOD/raw/research/20260901-gamma.md" <<'EOF'
---
type: capture
title: "Gamma"
date: 2026-09-01
source: "/cross-check gamma"
status: processed
discarded: "superseded by alpha before it was ever distilled"
---
body
EOF
cat > "$GOOD/wiki/concepts/alpha.md" <<'EOF'
---
type: concept
title: "Alpha"
date-updated: 2026-09-01
sources:
  - .brain/raw/research/20260901-alpha.md
---
body
EOF
cat > "$GOOD/DISTILL-LOG.md" <<'EOF'
# Distillation log

## 2026-09-01

- run: /distill
- scanned: 3 captures under .brain/raw/ (1 unprocessed)
- promoted: .brain/raw/research/20260901-alpha.md -> .brain/wiki/concepts/alpha.md
- discarded: .brain/raw/research/20260901-gamma.md — superseded
- result: 1 promoted, 1 discarded
EOF

assert "well-formed record -> exit 0" \
  "LOOM_REPO_ROOT='$TMPROOT/good' LOOM_BRAIN_ROOT='$GOOD' bash '$GATE' -q"
LOOM_REPO_ROOT="$TMPROOT/good" LOOM_BRAIN_ROOT="$GOOD" bash "$GATE" > "$TMPROOT/good.out" 2>&1
assert "the QUOTED form status: \"unprocessed\" is accepted (a grep for the bare string would have missed it)" \
  "grep -q '3 checked' '$TMPROOT/good.out'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 7: each of the five checks actually FAILS ──────────────────────"
# A gate nobody has seen fail is a gate nobody knows works. One planted
# violation per check, each reverted before the next.

plant() { cp -R "$TMPROOT/good" "$TMPROOT/bad"; }
unplant() { rm -rf "$TMPROOT/bad"; }
# NOTE: no pipes in these helpers. `set -o pipefail` is on, and `grep -q`
# closes the pipe on its first match — the producer then dies on SIGPIPE and the
# whole pipeline reports 141, so a CORRECT assertion reads as a failure. Write
# the output to a file and grep the file.
run_bad() { LOOM_REPO_ROOT="$TMPROOT/bad" LOOM_BRAIN_ROOT="$TMPROOT/bad/.brain" bash "$GATE" -q > "$TMPROOT/gate.out" 2>&1; }
bad_says() { run_bad; grep -q "$1" "$TMPROOT/gate.out"; }
bad_fails() { LOOM_REPO_ROOT="$TMPROOT/bad" LOOM_BRAIN_ROOT="$TMPROOT/bad/.brain" bash "$GATE" -q >/dev/null 2>&1; [ $? -ne 0 ]; }

# Check 1 — a capture with no parseable status is invisible to /distill forever.
plant
printf -- '---\ntype: capture\ntitle: "Orphan"\n---\nbody\n' > "$TMPROOT/bad/.brain/raw/research/orphan.md"
assert "[1] capture with NO status -> exit 1" "bad_fails"
assert "[1] failure message names the file and the check" "bad_says '\[1\].*orphan.md'"
unplant

# Check 1 — a status that is neither of the two legal values.
plant
sed -i.bak 's/^status: "unprocessed"/status: pending/' "$TMPROOT/bad/.brain/raw/research/20260901-beta.md"
rm -f "$TMPROOT/bad/.brain/raw/research/"*.bak
assert "[1] capture with an out-of-vocabulary status -> exit 1" "bad_fails"
unplant

# Check 2 — processed but nothing backs the claim.
plant
sed -i.bak '/^distilled-into:/d' "$TMPROOT/bad/.brain/raw/research/20260901-alpha.md"
rm -f "$TMPROOT/bad/.brain/raw/research/"*.bak
assert "[2] processed with neither distilled-into nor discarded -> exit 1" "bad_fails"
assert "[2] failure says the claim is unbacked" "bad_says 'claim nothing backs'"
unplant

# Check 2 — distilled-into points at a page that does not exist.
plant
rm -f "$TMPROOT/bad/.brain/wiki/concepts/alpha.md"
assert "[2] distilled-into naming a MISSING wiki page -> exit 1" "bad_fails"
unplant

# Check 2 — two answers to one question.
plant
printf 'discarded: "also discarded"\n' >> /dev/null
sed -i.bak 's|^distilled-into: .*|distilled-into: .brain/wiki/concepts/alpha.md\ndiscarded: "both at once"|' \
  "$TMPROOT/bad/.brain/raw/research/20260901-alpha.md"
rm -f "$TMPROOT/bad/.brain/raw/research/"*.bak
assert "[2] BOTH distilled-into and discarded -> exit 1" "bad_fails"
unplant

# Check 3 — a page with no citable origin is an assertion.
plant
sed -i.bak '/^sources:/,+1d' "$TMPROOT/bad/.brain/wiki/concepts/alpha.md"
rm -f "$TMPROOT/bad/.brain/wiki/concepts/"*.bak
assert "[3] wiki page with no sources: -> exit 1" "bad_fails"
assert "[3] failure calls the page an assertion" "bad_says 'assertion'"
unplant

# Check 3 — the key is present but the list under it is empty.
plant
sed -i.bak 's|^  - .brain/raw/research/20260901-alpha.md||' "$TMPROOT/bad/.brain/wiki/concepts/alpha.md"
rm -f "$TMPROOT/bad/.brain/wiki/concepts/"*.bak
assert "[3] wiki page with an EMPTY sources: list -> exit 1" "bad_fails"
unplant

# Check 4 — the log claims a promotion into a page that is not there.
plant
cat >> "$TMPROOT/bad/.brain/DISTILL-LOG.md" <<'EOF'
- promoted: .brain/raw/research/20260901-beta.md -> .brain/wiki/concepts/ghost.md
EOF
assert "[4] log entry naming a MISSING wiki page -> exit 1" "bad_fails"
assert "[4] failure quotes the missing target" "bad_says 'ghost.md'"
unplant

# Check 5 — pages appeared with no record of a run.
plant
rm -f "$TMPROOT/bad/.brain/DISTILL-LOG.md"
assert "[5] non-empty wiki with NO DISTILL-LOG.md -> exit 1" "bad_fails"
assert "[5] failure says pages appeared with no record" "bad_says 'no record of a run'"
unplant

# The portability discipline: the gate must never read a page BODY.
assert "the gate never parses a wiki page body (frontmatter + existence only)" \
  "grep -q 'No script may ever parse' '$GATE' || grep -q 'NO SCRIPT MAY EVER PARSE' '$GATE'"
assert "the gate runs no git (comments stripped, code scanned)" "! no_git_calls '$GATE'"
assert "the gate writes no repo file" "! grep -qE '^[^#]*(mkdir|touch|cp |mv ) ' '$GATE'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 8: the advisory's silence rules ────────────────────────────────"

sig() { # brain-root -> stdout
  LOOM_REPO_ROOT="$1/.." LOOM_BRAIN_ROOT="$1" LOOM_BRAIN_CONF="$ROOT/.logic-loom/config/brain.conf" \
    LOOM_BRAIN_TODAY="$TODAY" bash "$SIGNALS" 2>/dev/null
}
# Same pipefail/SIGPIPE trap as bad_says above — write to a file, grep the file.
sig_says() { # brain-root pattern
  sig "$1" > "$TMPROOT/sig.out" 2>/dev/null
  grep -q "$2" "$TMPROOT/sig.out"
}

assert "no .brain/ at all -> silent" "[ -z \"\$(sig '$TMPROOT/empty/.brain')\" ]"
assert "no .brain/ at all -> exit 0" "sig '$TMPROOT/empty/.brain' >/dev/null 2>&1"

# Unadopted routine: some captures may exist but none unprocessed and no log.
QUIET="$TMPROOT/quiet/.brain"
mkdir -p "$QUIET/raw/research"
cat > "$QUIET/raw/research/done.md" <<'EOF'
---
type: capture
title: "Done"
date: 2026-08-30
status: processed
discarded: "not useful"
---
EOF
assert "no unprocessed captures and no log -> silent (unadopted routine makes no noise)" \
  "[ -z \"\$(sig '$QUIET')\" ]"

# THE CONJUNCTION: an old log over an EMPTY queue is not a fault.
cat > "$QUIET/DISTILL-LOG.md" <<'EOF'
# Distillation log

## 2026-01-01

- run: /distill
- scanned: 1 captures under .brain/raw/ (0 unprocessed)
- result: zero-op
EOF
assert "an 8-month-old log over an EMPTY queue -> silent (the conjunction)" \
  "[ -z \"\$(sig '$QUIET')\" ]"

# Load: over the count threshold.
LOADED="$TMPROOT/loaded/.brain"
mkdir -p "$LOADED/raw/research"
i=1
while [ "$i" -le 7 ]; do
  cat > "$LOADED/raw/research/c$i.md" <<EOF
---
type: capture
title: "C$i"
date: 2026-08-30
status: unprocessed
---
EOF
  i=$((i + 1))
done
assert "7 unprocessed captures (> 5) -> load warning fires" "sig_says '$LOADED' 'Load:'"
assert "the notice is labelled advisory, not a gate" "sig_says '$LOADED' '[Aa]dvisory'"
assert "the notice names /distill" "sig_says '$LOADED' '/distill'"
assert "the advisory always exits 0" "sig '$LOADED' >/dev/null 2>&1"

# Liveness: unprocessed captures exist AND the log is stale.
cat > "$LOADED/DISTILL-LOG.md" <<'EOF'
# Distillation log

## 2026-01-01

- run: /distill
- result: zero-op
EOF
assert "stale log + unprocessed captures -> liveness warning fires" \
  "sig_says '$LOADED' 'Liveness:'"

# Load by AGE, under the count threshold.
AGED="$TMPROOT/aged/.brain"
mkdir -p "$AGED/raw/research"
cat > "$AGED/raw/research/old.md" <<'EOF'
---
type: capture
title: "Old"
date: 2026-06-01
status: unprocessed
---
EOF
assert "1 unprocessed capture 92 days old (> 21) -> load warning fires on AGE" \
  "sig_says '$AGED' 'Load:'"

# The kill switch.
printf 'advisory_enabled = false\n' > "$TMPROOT/off.conf"
assert "advisory_enabled = false -> silent" \
  "[ -z \"\$(LOOM_REPO_ROOT='$TMPROOT/loaded' LOOM_BRAIN_ROOT='$LOADED' LOOM_BRAIN_CONF='$TMPROOT/off.conf' LOOM_BRAIN_TODAY='$TODAY' bash '$SIGNALS' 2>/dev/null)\" ]"

assert "the advisory runs no git (comments stripped, code scanned)" "! no_git_calls '$SIGNALS'"
assert "the advisory reaches the model via the existing memory injection" \
  "grep -q 'check-brain-signals.sh' '$ROOT/plugins/loom-memory/scripts/memory-search.sh'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 9: the migration advisory (a legacy store nothing points at) ───"
# The default backend flip (project -> repo) can strand a project's old
# lessons in $HOME/.claude/projects/<slug>/memory with nothing reading them
# any more. check-brain-signals.sh surfaces that — detection, never
# resolution (the resolver stays pure; see Group 3). Build a scratch repo with
# its own copy of the resolver (the advisory shells out to
# <repo>/.logic-loom/scripts/bash/resolve-memory-backend.sh) and a fake $HOME,
# so this never touches the tester's real legacy store.
MIG_REPO="$TMPROOT/migrepo"
mkdir -p "$MIG_REPO/.brain" "$MIG_REPO/.logic-loom/scripts/bash"
cp "$RESOLVER" "$MIG_REPO/.logic-loom/scripts/bash/resolve-memory-backend.sh"
MIG_HOME="$TMPROOT/mighome"
mkdir -p "$MIG_HOME"
MIG_SLUG="$(printf '%s' "$MIG_REPO" | sed 's|/|-|g')"
MIG_LEGACY_DIR="$MIG_HOME/.claude/projects/$MIG_SLUG/memory"

mig_sig() { # -> stdout+stderr merged, so a crash and a warning both surface
  HOME="$MIG_HOME" LOOM_REPO_ROOT="$MIG_REPO" LOOM_BRAIN_ROOT="$MIG_REPO/.brain" \
    LOOM_BRAIN_TODAY="$TODAY" bash "$SIGNALS" 2>&1
}
mig_sig_says() { mig_sig > "$TMPROOT/mig.out" 2>&1; grep -q "$1" "$TMPROOT/mig.out"; }

assert "no legacy store at all -> silent (nothing to migrate)" "[ -z \"\$(mig_sig)\" ]"
assert "no legacy store at all -> exit 0" "mig_sig >/dev/null 2>&1"

mkdir -p "$MIG_LEGACY_DIR"
assert "legacy store exists but is EMPTY -> silent (an empty directory is not memory)" \
  "[ -z \"\$(mig_sig)\" ]"

printf 'an old lesson\n' > "$MIG_LEGACY_DIR/lesson-1.md"
assert "legacy store holds >= 1 file AND backend resolves to 'repo' -> Migration warning fires" \
  "mig_sig_says 'Migration'"
assert "the warning names the file count" "mig_sig_says '1 file'"
assert "the migration advisory still exits 0 when it fires" "mig_sig >/dev/null 2>&1"

# Setting memory_backend = project answers the question and self-clears the
# notice. LOOM_MEMORY_CONF (not a file literally named memory-backend.conf,
# which the governance guard refuses to let a subagent write) is honoured by
# the resolver AND inherited by the advisory's child call to it.
printf 'memory_backend = project\n' > "$TMPROOT/mig-project.conf"
mig_sig_project() {
  HOME="$MIG_HOME" LOOM_REPO_ROOT="$MIG_REPO" LOOM_BRAIN_ROOT="$MIG_REPO/.brain" \
    LOOM_BRAIN_TODAY="$TODAY" LOOM_MEMORY_CONF="$TMPROOT/mig-project.conf" bash "$SIGNALS" 2>&1
}
assert "memory_backend = project (same legacy store present) -> silent again" \
  "[ -z \"\$(mig_sig_project)\" ]"
assert "memory_backend = project -> still exits 0" "mig_sig_project >/dev/null 2>&1"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 10: the capture wiring is actually wired ───────────────────────"
# A doc claim nothing checks is the defect class this repo removes — assert
# the two capture producers actually name their .brain/raw/ out dirs and
# actually carry the capture frontmatter marker, not just describe them.
assert "cross-check SKILL.md names .brain/raw/reviews/ as the default out dir" \
  "grep -q '.brain/raw/reviews/' '$ROOT/plugins/loom-orchestrator/skills/cross-check/SKILL.md'"
assert "research.md names .brain/raw/research/" \
  "grep -q '.brain/raw/research/' '$ROOT/plugins/loom-orchestrator/commands/research.md'"
assert "cross-check SKILL.md's capture carries 'status: unprocessed'" \
  "grep -q 'status: unprocessed' '$ROOT/plugins/loom-orchestrator/skills/cross-check/SKILL.md'"
assert "research.md's capture carries 'status: unprocessed'" \
  "grep -q 'status: unprocessed' '$ROOT/plugins/loom-orchestrator/commands/research.md'"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 11: no removed-backend reference has crept back ────────────────"
# memory-backend.conf is excluded from this scan: it is the one file this
# suite already gates by name in Group 2's shipped-config assertion, and today
# it still carries the old vault prose pending that same outstanding
# maintainer edit — failing here too would just be a second echo of the one
# open item, not a new finding. test_brain_record.sh itself is excluded
# because this very assertion's pattern text lives inside it.
G_LEFTOVER="$(grep -rliE 'memory_vault_path|memory_backend[[:space:]]*=[[:space:]]*vault' \
    "$ROOT/.logic-loom" "$ROOT/plugins" "$ROOT/tests" "$ROOT/.brain" "$ROOT/CLAUDE.md" "$ROOT/AGENTS.md" \
    2>/dev/null \
  | grep -v '/\.logic-loom/config/memory-backend\.conf$' \
  | grep -v '/tests/contract/test_brain_record\.sh$')"
assert "no removed-backend reference (memory_vault_path / memory_backend = vault) survives elsewhere" \
  "[ -z '$G_LEFTOVER' ]"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Group 12: strip manifest + registration ───────────────────────────────"
MANIFEST="$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt"
if [ "$TREE_KIND" = "sanitized" ] || [ ! -f "$MANIFEST" ]; then
  skip "strip manifest covers the .brain/ layers" \
    "template-strip-manifest.txt is stripped — sanitized tree (maintainer-only file)"
  skip "strip manifest STUBS .brain/README.md" \
    "template-strip-manifest.txt is stripped — sanitized tree (maintainer-only file)"
  skip "the gate itself is NOT stripped" \
    "template-strip-manifest.txt is stripped — sanitized tree (maintainer-only file)"
  # What a SANITIZED tree can still assert, and it is the assertion that matters
  # most for a cloner: the strip actually happened, and the contract survived it.
  assert "sanitized tree: .brain/ holds no captures (the strip took them)" \
    "[ ! -d '$ROOT/.brain/raw' ] || [ -z \"\$(find '$ROOT/.brain/raw' -type f -name '*.md' ! -name 'README.md' 2>/dev/null)\" ]"
  assert "sanitized tree: .brain/README.md survived as the shipped contract" \
    "[ -f '$ROOT/.brain/README.md' ]"
  assert "sanitized tree: the gate is present and green (a live gate, not a dead one)" \
    "[ -x '$GATE' ] || [ -f '$GATE' ]"
else
  for entry in ".brain/raw" ".brain/wiki" ".brain/index" ".brain/memory" ".brain/DISTILL-LOG.md"; do
    assert "strip manifest removes $entry" \
      "grep -qxF '$entry' '$MANIFEST'"
  done
  assert "strip manifest STUBS .brain/README.md (the contract must ship)" \
    "grep -q '^stub: .brain/README.md :: .logic-loom/templates/brain-readme-template.md\$' '$MANIFEST'"
  assert "the gate itself is NOT stripped (it must run green in a cloner's CI)" \
    "! grep -qxF '.logic-loom/scripts/bash/check-brain-record.sh' '$MANIFEST'"
fi

assert "loom-orchestrator manifest lists the distill command" \
  "grep -q '\"distill\"' '$ROOT/plugins/loom-orchestrator/.claude-plugin/plugin.json'"
assert "loom-orchestrator manifest lists the distillation-pass skill" \
  "grep -q '\"distillation-pass\"' '$ROOT/plugins/loom-orchestrator/.claude-plugin/plugin.json'"
assert "the command bridge exposes /distill" \
  "[ -f '$ROOT/.claude/commands/distill.md' ]"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
echo "════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
