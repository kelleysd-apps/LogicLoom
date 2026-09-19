#!/usr/bin/env bash
# Contract Tests: the release-migration registry (.logic-loom/config/release-migrations.conf),
# its parser lib (.logic-loom/lib/release-migrations.sh), its script
# (plugins/loom-maintenance/scripts/release-migrations.sh — scan/plan/convert/lint/
# check-release), and the command/SKILL prose that wires it into /update-framework.
#
# Design: /private/tmp/.../scratchpad/deprecated-plugin-migration-design.md
# (§1-13 base; §14 supersedes; §15 "v7 critique disposition" supersedes both and
# is the final word — this suite follows the ACTUAL shipped WP1/WP2 behaviour,
# verified against the live tree, wherever the design's prose and the code differ
# in wording only).
#
# House rules: assert() below; every SKIP prints a reason and counts as a skip,
# never a pass; final line is "Results: N/M passed, F failed, S skipped";
# mktemp -d + trap cleanup; python3 for JSON; provenance via
# tests/lib/tree-provenance.sh. bash 3.2 safe: no associative arrays, no
# mapfile/readarray, no [[ -v ]], no ${v,,}, no `sort -V`.
#
# A NOTE ON A "PROSE PIN PROVES THE INSTRUCTION IS PRESENT IN THE RIGHT STEP,
# NOT THAT IT IS OBEYED" — this suite's §F below is exactly that kind of pin.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip() { SKIP=$((SKIP + 1)); echo "  ⏭️  SKIP: $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/tests/lib/tree-provenance.sh"

REG="$ROOT/.logic-loom/config/release-migrations.conf"
LIB="$ROOT/.logic-loom/lib/release-migrations.sh"
RM="$ROOT/plugins/loom-maintenance/scripts/release-migrations.sh"
RECORDER="$ROOT/plugins/loom-maintenance/scripts/record-update-writes.sh"
CMD_MD="$ROOT/plugins/loom-maintenance/commands/update-framework.md"
SKILL_MD="$ROOT/plugins/loom-maintenance/skills/framework-updater/SKILL.md"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-relmig-test.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

TREE_KIND="$(loom_tree_kind "$ROOT")"

echo "═══════════════════════════════════════════════════════════"
echo "  CONTRACT: release-migration registry / lib / script / prose pins"
echo "  tree kind: $TREE_KIND"
echo "═══════════════════════════════════════════════════════════"

if [ "$TREE_KIND" = "inconsistent" ]; then
  loom_require_consistent_tree "$ROOT" || true
  echo "── refusing to guess: tree provenance is inconsistent ──"
  echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# SECTION A — registry integrity (real tree)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "A. Registry integrity (real tree)"

assert "registry file exists" "[ -f '$REG' ]"
assert "lib file exists" "[ -f '$LIB' ]"
assert "script file exists" "[ -f '$RM' ]"

if [ -f "$LIB" ]; then
  # shellcheck source=/dev/null
  source "$LIB"
fi

assert "'lint' exits 0 on the real registry" \
  "bash '$RM' lint --root '$ROOT' >'$TMP/a-lint.out' 2>&1"
assert "'lint' reports clean" "grep -q 'lint: clean' '$TMP/a-lint.out'"

DEP_N="$(loom_deprecation_rows "$REG" 2>/dev/null | grep -c . || true)"
MIG_N="$(loom_migration_rows "$REG" 2>/dev/null | grep -c . || true)"
assert "exactly 23 deprecation-kind rows (found $DEP_N)" "[ '$DEP_N' -eq 23 ]"
assert "exactly 25 total rows: 23 deprecation + 2 v7.0.0 content (receipt + KORI-CLASS ladder) (found $MIG_N)" "[ '$MIG_N' -eq 25 ]"

# named fates
assert "sdd-dev-loop is native" \
  "[ \"\$(loom_deprecation_row sdd-dev-loop '$REG' | awk -F'\t' '{print \$3}')\" = native ]"
assert "loom-dev-loop (alias row) is native" \
  "[ \"\$(loom_deprecation_row loom-dev-loop '$REG' | awk -F'\t' '{print \$3}')\" = native ]"
for d in backend database devops frontend performance security testing; do
  assert "sdd-domain-$d is folded" \
    "[ \"\$(loom_deprecation_row sdd-domain-$d '$REG' | awk -F'\t' '{print \$3}')\" = folded ]"
done
for r in sdd-creation sdd-git sdd-maintenance sdd-memory sdd-orchestrator sdd-orchestrator-hook sdd-governance; do
  assert "$r is renamed" \
    "[ \"\$(loom_deprecation_row $r '$REG' | awk -F'\t' '{print \$3}')\" = renamed ]"
done
assert "sdd-debug is removed" \
  "[ \"\$(loom_deprecation_row sdd-debug '$REG' | awk -F'\t' '{print \$3}')\" = removed ]"
assert "sdd-domain-template is removed" \
  "[ \"\$(loom_deprecation_row sdd-domain-template '$REG' | awk -F'\t' '{print \$3}')\" = removed ]"
assert "sdd-marketplace is kind mcp-server" \
  "[ \"\$(loom_deprecation_row sdd-marketplace '$REG' | awk -F'\t' '{print \$1}')\" = mcp-server ]"

# path rows
for p in "src/sdd/__init__.py" ".specify/config/refinement.conf" "plugins/migrate-to-plugins.sh" "plugins/create-domain-plugin.sh"; do
  assert "path row exists: $p" \
    "loom_deprecation_row \"$p\" '$REG' >/dev/null 2>&1"
done
assert "the src/sdd row's name is the FILE, not the directory" \
  "[ \"\$(loom_deprecation_row 'src/sdd/__init__.py' '$REG' | awk -F'\t' '{print \$2}')\" = 'src/sdd/__init__.py' ]"

# v7.0.0 content row
V7ROW="$(loom_migration_row .logicloom-adopt-receipt.json "$REG" 2>/dev/null)" || V7ROW=""
assert "v7.0.0 content row exists (name .logicloom-adopt-receipt.json)" "[ -n \"\$V7ROW\" ]"
V7_KIND="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $1}')"
V7_FATE="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $3}')"
V7_REPL="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $4}')"
V7_DEF="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $5}')"
V7_REL="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $7}')"
V7_NOTE="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $8}')"
assert "v7.0.0 row kind: content" "[ \"\$V7_KIND\" = content ]"
assert "v7.0.0 row fate: absent" "[ \"\$V7_FATE\" = absent ]"
assert "v7.0.0 row replacement starts with pattern:" "case \"\$V7_REPL\" in pattern:*) true;; *) false;; esac"
assert "v7.0.0 row default: PROPOSE" "[ \"\$V7_DEF\" = PROPOSE ]"
assert "v7.0.0 row release: v7.0.0" "[ \"\$V7_REL\" = v7.0.0 ]"
assert "v7.0.0 row note contains proposal:" "case \"\$V7_NOTE\" in *proposal:*) true;; *) false;; esac"
assert "v7.0.0 row note contains why:" "case \"\$V7_NOTE\" in *why:*) true;; *) false;; esac"
V7REL_N="$(loom_migration_rows_for_release v7.0.0 "$REG" 2>/dev/null | grep -c . || true)"
assert "loom_migration_rows_for_release v7.0.0 = 2 rows (receipt + KORI-CLASS ladder)" "[ '$V7REL_N' -eq 2 ]"

# finding 6: the KORI-CLASS row itself
KORIROW="$(loom_migration_row .logic-loom/memory/amendments.md "$REG" 2>/dev/null)" || KORIROW=""
assert "the KORI-CLASS row exists (name .logic-loom/memory/amendments.md)" "[ -n \"\$KORIROW\" ]"
KORI_DEF="$(printf '%s' "$KORIROW" | awk -F'\t' '{print $5}')"
assert "its default is PROPOSE-ADVISORY" "[ \"\$KORI_DEF\" = PROPOSE-ADVISORY ]"

# every plugin:/path: replacement resolves
BAD_REPL="$(bash -c "
  source '$LIB'
  loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
    case \"\$repl\" in
      plugin:*) p=\"\${repl#plugin:}\"; [ -d '$ROOT'/\"plugins/\$p\" ] || echo \"plugins/\$p\" ;;
      path:*) p=\"\${repl#path:}\"; [ -e '$ROOT'/\"\$p\" ] || echo \"\$p\" ;;
    esac
  done
")"
assert "every plugin:/path: replacement exists on disk (missing: ${BAD_REPL:-none})" "[ -z \"\$BAD_REPL\" ]"

# no duplicate deprecation names
DUP_NAMES="$(loom_deprecation_rows "$REG" 2>/dev/null | awk -F'\t' '{print $2}' | sort | uniq -d)"
assert "no duplicate names among deprecation rows (dup: ${DUP_NAMES:-none})" "[ -z \"\$DUP_NAMES\" ]"

echo ""
echo "A. lint failures via temporary registries"

mk_reg() { printf '%s\n' "$1" > "$TMP/$2"; }

mk_reg "plugin | x | removed | none | REMOVE | v1.0.0 | v2.0.0" "bad7field.conf"
assert "a 7-field row fails lint, message names 'LINT: line'" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/bad7field.conf' >'$TMP/l1.out' 2>&1; grep -q 'LINT: line' '$TMP/l1.out'"

mk_reg "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | no markers here" "badcontent.conf"
assert "a content row without 'why:' fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badcontent.conf' >/dev/null 2>&1"

{
  echo "none | - | none | none | - | - | v9.9.9 | nothing changed"
  echo "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b"
} > "$TMP/badnonesib.conf"
assert "a 'none' row plus a sibling row for the same release fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badnonesib.conf' >/dev/null 2>&1"

mk_reg "plugin | x | removed | pattern:foo | REMOVE | v1.0.0 | v2.0.0 | bad replacement kind" "badpluginpattern.conf"
assert "a plugin row using 'pattern:' fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badpluginpattern.conf' >/dev/null 2>&1"

{
  echo "plugin | dup-x | removed | none | REMOVE | v1.0.0 | v2.0.0 | first"
  echo "plugin | dup-x | removed | none | REMOVE | v1.0.0 | v2.0.0 | second"
} > "$TMP/baddup.conf"
assert "two plugin rows with the same name fail lint (duplicate deprecation name)" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/baddup.conf' >'$TMP/l5.out' 2>&1; grep -q 'duplicate deprecation name' '$TMP/l5.out'"

mk_reg 'content | x.md | present | pattern:foo\|bar | PROPOSE | - | v9.9.9 | proposal: a; why: b' "escaped.conf"
assert "a content row with an escaped \\| alternation lints CLEAN" \
  "bash '$RM' lint --root '$ROOT' --registry '$TMP/escaped.conf' >/dev/null 2>&1"
ESC_REPL="$(loom_migration_rows "$TMP/escaped.conf" 2>/dev/null | awk -F'\t' '{print $4}')"
assert "the parsed replacement carries a literal | (got: $ESC_REPL)" \
  "[ \"\$ESC_REPL\" = 'pattern:foo|bar' ]"

echo ""
echo "A. Maintainer-tree-only assertions (release-removal guard, tag consistency)"

case "$TREE_KIND" in
  maintainer)
    BAD_PATHS="$(bash -c "
      source '$LIB'
      loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
        path=\"\$(loom_deprecation_dir \"\$kind\" \"\$name\")\"
        [ -e '$ROOT'/\"\$path\" ] && echo \"\$path\"
      done
    ")"
    assert "on a maintainer tree, no deprecation row's path exists on disk (found: ${BAD_PATHS:-none})" \
      "[ -z \"\$BAD_PATHS\" ]"
    assert "migration-decisions.conf does not exist on a maintainer tree" \
      "[ ! -f '$ROOT/.logic-loom/config/migration-decisions.conf' ]"
    assert "project-migrations.conf does not exist on a maintainer tree" \
      "[ ! -f '$ROOT/.logic-loom/config/project-migrations.conf' ]"

    bash "$RM" check-release --since auto --root "$ROOT" > "$TMP/a-removal-guard.out" 2>&1
    RG_RC=$?
    echo "     $(head -1 "$TMP/a-removal-guard.out")"
    assert "'check-release --since auto' exits 0 on the maintainer tree" "[ $RG_RC -eq 0 ]"
    assert "output names the resolved floor branch ('previous release:')" \
      "grep -q 'previous release:' '$TMP/a-removal-guard.out'"

    echo "  tag consistency:"
    bash -c "
      source '$LIB'
      loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
        case \"\$first\" in v[0-9]*) : ;; *) continue ;; esac
        path=\"\$(loom_deprecation_dir \"\$kind\" \"\$name\")\"
        if ! git -C '$ROOT' rev-parse -q --verify \"refs/tags/\$first\" >/dev/null 2>&1; then
          echo \"SKIP \$name: tag \$first absent\"; continue
        fi
        if ! git -C '$ROOT' cat-file -e \"\$first:\$path\" 2>/dev/null; then
          echo \"FAIL \$name: \$path absent at \$first (should be present)\"; continue
        fi
        if [ \"\$release\" != '-' ] && git -C '$ROOT' rev-parse -q --verify \"refs/tags/\$release\" >/dev/null 2>&1; then
          if git -C '$ROOT' cat-file -e \"\$release:\$path\" 2>/dev/null; then
            echo \"FAIL \$name: \$path still present at \$release (should be gone)\"
          else
            echo \"OK \$name\"
          fi
        else
          echo \"SKIP \$name: tag \$release absent\"
        fi
      done
    " > "$TMP/a-tagcheck.out"
    cat "$TMP/a-tagcheck.out" | sed 's/^/    /'
    # A row whose tag is absent locally (shallow clone, private remote without
    # the pre-v6.2 tags) is a SKIP with the tag named — counted, never a pass.
    while IFS= read -r skline; do
      [ -n "$skline" ] && skip "tag consistency: ${skline#SKIP }"
    done <<< "$(grep '^SKIP' "$TMP/a-tagcheck.out" || true)"
    TAG_FAILS="$(grep -c '^FAIL' "$TMP/a-tagcheck.out" || true)"
    assert "tag consistency: no row's path violates first_shipped/release tag facts" "[ '$TAG_FAILS' -eq 0 ]"
    ;;
  sanitized)
    skip "release-removal guard is a maintainer check — sanitized tree (release tags are not shipped)"
    skip "maintainer-tree absence (no deprecation path on disk; no decisions/project registry) is a maintainer check — sanitized tree"
    skip "tag consistency is a maintainer check — sanitized tree (release tags are not shipped)"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# SECTION B — fixture: a throwaway git repo shaped like §7-B of the design
# ═══════════════════════════════════════════════════════════════════════════
#
# Every sub-test below gets its OWN repo via fixture_repo() (cheap: local git,
# a handful of small files). The main worker's own Bash lines never run git —
# only this SCRIPT does, on the throwaway fixture path it creates, exactly the
# precedent tests/contract/test_release_sync_ref.sh sets.
export GIT_AUTHOR_NAME=loom-test GIT_AUTHOR_EMAIL=loom@test
export GIT_COMMITTER_NAME=loom-test GIT_COMMITTER_EMAIL=loom@test

# fixture_repo <dir> — builds commit A (the full §7-B shape), tags v9.0.0 at
# A, a commit A2 touching one file, tags v9.1.0 at A2, then leaves three
# UNCOMMITTED edits in the working tree. Returns via stdout: "A A2".
fixture_repo() {
  local F="$1"
  mkdir -p "$F"
  git init -q "$F"

  mkdir -p "$F/plugins/sdd-dev-loop/.claude-plugin" \
           "$F/plugins/sdd-dev-loop/commands" \
           "$F/plugins/sdd-dev-loop/skills/core-loop" \
           "$F/plugins/sdd-dev-loop/skills/dev-loop" \
           "$F/plugins/sdd-dev-loop/config" \
           "$F/.claude/commands" \
           "$F/plugins/sdd-debug/commands" \
           "$F/plugins/sdd-debug/agents" \
           "$F/plugins/sdd-debug/skills/sdd-debug" \
           "$F/plugins/sdd-debug/hooks/scripts" \
           "$F/plugins/sdd-git/commands" \
           "$F/plugins/loom-git/commands" \
           "$F/.logic-loom/config" \
           "$F/.logic-loom/lib" \
           "$F/.claude"

  cat > "$F/plugins/sdd-dev-loop/.claude-plugin/plugin.json" <<'JSON'
{ "name": "sdd-dev-loop", "version": "1.0.0", "dependencies": ["loom-governance"],
  "agents": { "count": 0, "list": [] } }
JSON
  cat > "$F/plugins/sdd-dev-loop/commands/dev-loop.md" <<'MD'
---
name: dev-loop
description: Autonomous edit-test-debug loop
allowed-tools: Bash
model: opus
---

# /dev-loop

Runs an edit-test-debug cycle.
MD
  cat > "$F/plugins/sdd-dev-loop/skills/core-loop/SKILL.md" <<'MD'
---
name: core-loop
description: Core loop internals
---

Core loop body.
MD
  cat > "$F/plugins/sdd-dev-loop/skills/dev-loop/SKILL.md" <<'MD'
---
name: dev-loop
description: The dev-loop skill (same name as the command, for the append path)
---

Existing skill body.
MD
  echo '{"threshold": 1}' > "$F/plugins/sdd-dev-loop/config/thresholds.json"

  cat > "$F/.claude/commands/dev-loop.md" <<'MD'
<!-- 🔌 AUTO-GENERATED by plugin-bridge | source: sdd-dev-loop | DO NOT EDIT -->
<!-- To modify this command, edit: plugins/sdd-dev-loop/commands/dev-loop.md -->
<!-- Run .specify/scripts/bash/sync-plugin-commands.sh sync to refresh -->

Read and execute the full command procedure from: plugins/sdd-dev-loop/commands/dev-loop.md
MD

  cat > "$F/plugins/sdd-debug/commands/debug.md" <<'MD'
---
name: debug
description: 10-step debugging workflow
allowed-tools: Bash, Read
---

# /debug
MD
  cat > "$F/plugins/sdd-debug/agents/auto-debug-agent.md" <<'MD'
---
name: auto-debug-agent
description: Automated debugging agent
model: claude-opus-4-6-20260205
---

Agent body.
MD
  cat > "$F/plugins/sdd-debug/skills/sdd-debug/SKILL.md" <<'MD'
---
name: sdd-debug
description: sdd-debug skill
---

Skill body.
MD
  cat > "$F/plugins/sdd-debug/hooks/hooks.json" <<'JSON'
{ "hooks": {} }
JSON
  cat > "$F/plugins/sdd-debug/hooks/scripts/debug-capture.sh" <<'SH'
#!/usr/bin/env bash
source "${CLAUDE_PLUGIN_ROOT}/lib/x.sh"
cat "plugins/sdd-debug/config/y.json"
SH
  chmod +x "$F/plugins/sdd-debug/hooks/scripts/debug-capture.sh"

  cat > "$F/plugins/sdd-git/commands/git-push.md" <<'MD'
---
name: git-push
description: sdd-git's git-push command
---

sdd-git body.
MD
  cat > "$F/plugins/loom-git/commands/git-push.md" <<'MD'
---
name: git-push
description: loom-git's git-push command
---

loom-git body.
MD

  cat > "$F/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "bash plugins/sdd-debug/hooks/scripts/debug-capture.sh" },
        { "type": "command", "command": "bash plugins/sdd-governance/hooks/scripts/git-safety-gate.sh" }
      ]}
    ]
  }
}
JSON

  cp "$REG" "$F/.logic-loom/config/release-migrations.conf"
  cp "$LIB" "$F/.logic-loom/lib/release-migrations.sh"
  echo "FRAMEWORK_VERSION=7.0.0" > "$F/.logic-loom/config/architecture.conf"

  # finding 1: a tag NEVER establishes a baseline (fix BY DESIGN — see
  # resolve_baseline). These two tags (v9.0.0, v9.1.0) are stamped with
  # LogicLoom's own package.json name+version purely so the "does a tag ever
  # leak into the baseline, even a convincing one" assertions below have
  # something convincing to reject — resolve_baseline must ignore them
  # regardless of how genuine they look.
  cat > "$F/package.json" <<'JSON'
{ "name": "logic-loom", "version": "9.0.0" }
JSON

  cat > "$F/CLAUDE.md" <<'MD'
# CLAUDE.md — fixture

## Plugin Registry

| Plugin | Layer | Notes |
|---|---|---|
| `loom-git` | core tooling | git-push/finalize |

## Something Else

Nothing here.
MD

  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A" )
  local A; A="$(git -C "$F" rev-parse HEAD)"
  printf '%s\n' "$A" > "$F/.sdd-sync-ref"
  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A: stamp sync-ref" --allow-empty )
  A="$(git -C "$F" rev-parse HEAD)"
  git -C "$F" update-ref refs/tags/v9.0.0 "$A"

  echo "touched" > "$F/UNRELATED.txt"
  cat > "$F/package.json" <<'JSON'
{ "name": "logic-loom", "version": "9.1.0" }
JSON
  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A2" )
  local A2; A2="$(git -C "$F" rev-parse HEAD)"
  git -C "$F" update-ref refs/tags/v9.1.0 "$A2"
  # Round-2 finding 1: a sync-ref is only a baseline when refs/loom-upstream/
  # main exists locally AND reaches it. A2 is a descendant of A (the
  # sync-ref commit), so this keeps every existing sync-ref-baseline
  # assertion below true under the tightened rule instead of silently
  # flipping them all to "no baseline" — FIX2 (below) deletes this ref
  # again for the fixtures that specifically want "no baseline at all".
  git -C "$F" update-ref refs/loom-upstream/main "$A2"

  # Uncommitted edits (§7-B): sdd-debug customized (1 changed, 1 added),
  # sdd-git customized (1 changed).
  echo "-- locally edited --" >> "$F/plugins/sdd-debug/commands/debug.md"
  echo "local notes" > "$F/plugins/sdd-debug/skills/sdd-debug/notes.md"
  echo "-- locally edited --" >> "$F/plugins/sdd-git/commands/git-push.md"

  printf '%s %s' "$A" "$A2"
}

echo ""
echo "B. Building the §7-B fixture (throwaway git repo)"
FIX1="$TMP/fixture1"
FIX1_AB="$(fixture_repo "$FIX1")"
FIX1_A="$(printf '%s' "$FIX1_AB" | awk '{print $1}')"
FIX1_A2="$(printf '%s' "$FIX1_AB" | awk '{print $2}')"
assert "fixture repo built (commit A resolves)" "[ -n '$FIX1_A' ]"
assert "fixture repo has two tags (v9.0.0, v9.1.0)" \
  "git -C '$FIX1' rev-parse -q --verify refs/tags/v9.0.0 >/dev/null 2>&1 && git -C '$FIX1' rev-parse -q --verify refs/tags/v9.1.0 >/dev/null 2>&1"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION C — scan
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "C. scan --json parses; per-item shape and the three headline items"

bash "$RM" scan --json --root "$FIX1" > "$TMP/c1.json" 2>"$TMP/c1.err"
C1_RC=$?
assert "scan --json exits 0" "[ $C1_RC -eq 0 ]"
assert "scan --json output parses as JSON" "python3 -c 'import json; json.load(open(\"$TMP/c1.json\"))'"
assert "scan --json parses as ONE OBJECT with the fixed key set" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert isinstance(d, dict), \"not an object\"
want = {\"registry\",\"rows\",\"project_rows\",\"release\",\"orphan_check\",\"items\",\"dangling_hooks\",\"dangling_mcp\",\"decisions\",\"summary\"}
assert want <= set(d.keys()), sorted(d.keys())
'"
assert "every item id matches MG-NNN" \
  "python3 -c '
import json, re
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    assert re.match(r\"^MG-[0-9]{3}\$\", it[\"id\"]), it
'"
assert "every item has blocked (bool), blocked_by (list), remove_command, move_command" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    assert isinstance(it[\"blocked\"], bool), it[\"id\"]
    assert isinstance(it[\"blocked_by\"], list), it[\"id\"]
    assert \"remove_command\" in it and \"move_command\" in it, it[\"id\"]
'"
assert "every deprecation reference carries a class" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    for r in it.get(\"references\", []):
        assert \"class\" in r, it[\"id\"]
'"

assert "sdd-dev-loop: pristine, baseline sync-ref:<A>, recommended REMOVE, not blocked" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"state\"] == \"pristine\", it
assert it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"recommended\"] == \"REMOVE\", it
assert it[\"blocked\"] is False, it
assert it[\"remove_command\"] == \"git rm -r plugins/sdd-dev-loop\", it
'"
assert "sdd-dev-loop references include the bridge wrapper, class bridge-wrapper" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert any(r[\"file\"] == \".claude/commands/dev-loop.md\" and r[\"class\"] == \"bridge-wrapper\" for r in it[\"references\"]), it[\"references\"]
'"

assert "sdd-debug: customized (1 changed, 1 added), CONVERT-TO-LOCAL, wired_hooks has debug-capture.sh" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert it[\"state\"] == \"customized\", it
assert len(it[\"changed_files\"]) == 1 and len(it[\"added_files\"]) == 1, it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
assert any(\"debug-capture.sh\" in w[\"text\"] for w in it[\"wired_hooks\"]), it[\"wired_hooks\"]
'"

assert "sdd-git: customized, ADOPT-REPLACEMENT, counterpart loom-git/commands/git-push.md exists=true" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"ADOPT-REPLACEMENT\", it
cp = it[\"counterparts\"]
assert any(c[\"counterpart\"] == \"plugins/loom-git/commands/git-push.md\" and c[\"exists\"] is True for c in cp), cp
'"

assert "sdd-governance is NOT an item (dir absent)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert not any(i.get(\"path\") == \"plugins/sdd-governance\" for i in d[\"items\"])
'"
assert "…but appears in dangling_hooks (the settings.json line will dangle)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert any(\"sdd-governance\" in h[\"text\"] for h in d[\"dangling_hooks\"]), d[\"dangling_hooks\"]
'"

assert "the v7.0.0 receipt content row yields NO item in this fixture (TEMPLATE, no receipt)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert not any(i.get(\"kind\") == \"content\" for i in d[\"items\"])
'"

echo ""
echo "C. baseline resolution (finding 1): sync-ref removed -> NEVER falls back to a tag, even two"
echo "   LogicLoom-stamped ones (v9.0.0, v9.1.0) sitting right there — baseline none, state unknown"
FIX2="$TMP/fixture2"; cp -R "$FIX1" "$FIX2"
rm -f "$FIX2/.sdd-sync-ref"
# Also drop the upstream-history ref FIX1 now carries (finding 1, above) —
# this fixture's whole point is "no baseline candidate resolves at all",
# and leaving refs/loom-upstream/main behind would let resolve_baseline's
# OWN upstream fallback (a real, different baseline route) resolve one,
# which is not what this section tests.
git -C "$FIX2" update-ref -d refs/loom-upstream/main
bash "$RM" scan --json --root "$FIX2" > "$TMP/c2.json" 2>"$TMP/c2.err"
assert "with .sdd-sync-ref removed, sdd-dev-loop baseline is none (a tag is never consulted, stamped or not)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c2.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it[\"baseline\"]
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. baseline resolution: no sync-ref AND no tags -> baseline none, state unknown, CONVERT-TO-LOCAL"
FIX3="$TMP/fixture3"; cp -R "$FIX2" "$FIX3"
# update-ref -d, not `git tag -d`: the fixture verbs stay within init/add/
# commit/update-ref (+ read-only), the set the design sanctions for a
# throwaway repo built inside a suite.
git -C "$FIX3" update-ref -d refs/tags/v9.0.0
git -C "$FIX3" update-ref -d refs/tags/v9.1.0
assert "fixture3 really has no tags" "[ -z \"\$(git -C '$FIX3' for-each-ref refs/tags/)\" ]"
bash "$RM" scan --json --root "$FIX3" > "$TMP/c3.json" 2>"$TMP/c3.err"
assert "with no sync-ref and no tags, sdd-dev-loop baseline is none, state unknown, CONVERT-TO-LOCAL" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c3.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it[\"baseline\"]
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
'"

echo ""
echo "C. decisions: keep = sdd-dev-loop"
FIX4="$TMP/fixture4"; cp -R "$FIX1" "$FIX4"
mkdir -p "$FIX4/.logic-loom/config"
echo "keep = sdd-dev-loop" > "$FIX4/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX4" > "$TMP/c4.json" 2>"$TMP/c4.err"
bash "$RM" scan --root "$FIX4" > "$TMP/c4.human.out" 2>"$TMP/c4.human.err"
assert "decision keep -> item recommended KEEP-AS-IS, summary.kept 1" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c4.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"decision\"] == \"keep\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert d[\"summary\"][\"kept\"] == 1, d[\"summary\"]
'"
assert "decisions[] carries one entry, verb keep, consequence mentions 'floor test'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c4.json\"))
assert len(d[\"decisions\"]) == 1, d[\"decisions\"]
dec = d[\"decisions\"][0]
assert dec[\"verb\"] == \"keep\" and dec[\"name\"] == \"sdd-dev-loop\", dec
assert \"floor test\" in dec[\"consequence\"], dec
'"
assert "human output contains 'Decisions in force'" \
  "grep -q 'Decisions in force' '$TMP/c4.human.out'"

echo ""
echo "C. decisions: keep = sdd-nonexistent -> stale"
FIX5="$TMP/fixture5"; cp -R "$FIX1" "$FIX5"
mkdir -p "$FIX5/.logic-loom/config"
echo "keep = sdd-nonexistent" > "$FIX5/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX5" > "$TMP/c5.json" 2>"$TMP/c5.err"
assert "a decision naming nothing on disk is reported stale" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c5.json\"))
dec = d[\"decisions\"][0]
assert dec[\"name\"] == \"sdd-nonexistent\" and dec[\"stale\"] is True, dec
'"

echo ""
echo "C. empty fixture: no items at all"
FIX_EMPTY="$TMP/fixture-empty"
mkdir -p "$FIX_EMPTY/.logic-loom/config" "$FIX_EMPTY/.logic-loom/lib"
git init -q "$FIX_EMPTY"
cp "$REG" "$FIX_EMPTY/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FIX_EMPTY/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_EMPTY/.logic-loom/config/architecture.conf"
( cd "$FIX_EMPTY" && git add -A >/dev/null && git commit -q -m init )
bash "$RM" scan --root "$FIX_EMPTY" > "$TMP/cempty.human.out" 2>"$TMP/cempty.human.err"
bash "$RM" scan --json --root "$FIX_EMPTY" > "$TMP/cempty.json" 2>"$TMP/cempty.json.err"
assert "empty fixture human output contains 'Release migrations: none pending.'" \
  "grep -qF 'Release migrations: none pending.' '$TMP/cempty.human.out'"
assert "empty fixture --json has items: []" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cempty.json\"))
assert d[\"items\"] == [], d[\"items\"]
'"
assert "empty fixture without decisions prints no MG- line and no 'Decisions in force' block (just the header lines + none pending)" \
  "! grep -q '^MG-' '$TMP/cempty.human.out' && ! grep -q 'Decisions in force' '$TMP/cempty.human.out'"

echo ""
echo "C. empty fixture WITH a keep line: both lines present"
FIX_EMPTY_KEEP="$TMP/fixture-empty-keep"; cp -R "$FIX_EMPTY" "$FIX_EMPTY_KEEP"
echo "keep = sdd-dev-loop" > "$FIX_EMPTY_KEEP/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --root "$FIX_EMPTY_KEEP" > "$TMP/cek.out" 2>&1
assert "'none pending' AND 'Decisions in force' both present" \
  "grep -qF 'Release migrations: none pending.' '$TMP/cek.out' && grep -q 'Decisions in force' '$TMP/cek.out'"

echo ""
echo "C. orphan pass: skipped without a Plugin Registry table, run (and catches) with one"
FIX_ORPHAN="$TMP/fixture-orphan"; cp -R "$FIX1" "$FIX_ORPHAN"
mkdir -p "$FIX_ORPHAN/plugins/loom-stray"
: > "$FIX_ORPHAN/plugins/loom-stray/README.md"
bash "$RM" scan --json --root "$FIX_ORPHAN" > "$TMP/corphan.json" 2>&1
assert "loom-stray (undeclared, unregistered) IS reported as kind orphan" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/corphan.json\"))
assert any(i.get(\"kind\") == \"orphan\" and i[\"path\"] == \"plugins/loom-stray\" for i in d[\"items\"]), d[\"items\"]
'"
rm "$FIX_ORPHAN/CLAUDE.md"
bash "$RM" scan --json --root "$FIX_ORPHAN" > "$TMP/corphan2.json" 2>&1
bash "$RM" scan --root "$FIX_ORPHAN" > "$TMP/corphan2.human.out" 2>&1
assert "with CLAUDE.md removed, orphan_check is 'skipped' and no orphan items appear" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/corphan2.json\"))
assert d[\"orphan_check\"] == \"skipped\", d[\"orphan_check\"]
assert not any(i.get(\"kind\") == \"orphan\" for i in d[\"items\"])
'"
assert "human output says 'orphan check: skipped'" \
  "grep -q 'orphan check: skipped' '$TMP/corphan2.human.out'"

echo ""
echo "C. .github/workflows blocks REMOVE (ci-workflow reference)"
FIX_CI="$TMP/fixture-ci"; cp -R "$FIX1" "$FIX_CI"
mkdir -p "$FIX_CI/.github/workflows"
echo "run: bash plugins/sdd-dev-loop/scripts/run.sh" > "$FIX_CI/.github/workflows/ci.yml"
bash "$RM" scan --json --root "$FIX_CI" > "$TMP/cci.json" 2>&1
assert "sdd-dev-loop is now blocked, blocked_by names the workflow file, class ci-workflow" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert it[\"blocked_by\"][0][\"file\"] == \".github/workflows/ci.yml\", it[\"blocked_by\"]
assert any(r[\"class\"] == \"ci-workflow\" for r in it[\"references\"]), it[\"references\"]
'"

mkdir -p "$FIX_CI/.claude/agents"
echo "see plugins/sdd-debug/skills for the old flow" > "$FIX_CI/.claude/agents/helper.md"
bash "$RM" scan --json --root "$FIX_CI" > "$TMP/cci2.json" 2>&1
assert "sdd-debug references include .claude/agents/helper.md with class project-agent-or-skill (listed, never a block)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cci2.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert any(r[\"file\"] == \".claude/agents/helper.md\" and r[\"class\"] == \"project-agent-or-skill\" for r in it[\"references\"]), it[\"references\"]
assert not any(b[\"file\"] == \".claude/agents/helper.md\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
'"
bash "$RM" plan sdd-dev-loop --root "$FIX_CI" > "$TMP/cci.plan.out" 2>&1
assert "human 'plan sdd-dev-loop' prints 'BLOCKED until:' naming the workflow" \
  "grep -q 'BLOCKED until: .*\\.github/workflows/ci\\.yml' '$TMP/cci.plan.out'"

echo ""
echo "C. mcp-server kind: dangling_mcp and remove text never name plugins/"
FIX_MCP="$TMP/fixture-mcp"; cp -R "$FIX1" "$FIX_MCP"
mkdir -p "$FIX_MCP/mcp-servers/sdd-marketplace"
: > "$FIX_MCP/mcp-servers/sdd-marketplace/index.js"
cat > "$FIX_MCP/.mcp.json" <<'JSON'
{ "mcpServers": { "sdd-marketplace": { "command": "node", "args": ["mcp-servers/sdd-marketplace/src/index.js"] } } }
JSON
( cd "$FIX_MCP" && git add -A >/dev/null && git commit -q -m "add sdd-marketplace" )
MCP_REF="$(git -C "$FIX_MCP" rev-parse HEAD)"
printf '%s\n' "$MCP_REF" > "$FIX_MCP/.sdd-sync-ref"
( cd "$FIX_MCP" && git add -A >/dev/null && git commit -q -m "advance sync-ref" )
# Round-2 finding 1: the sync-ref just advanced PAST FIX1's frozen
# refs/loom-upstream/main (still A2) — advance it too, so it still REACHES
# the new sync-ref commit (finding 1's ancestor rule).
git -C "$FIX_MCP" update-ref refs/loom-upstream/main "$(git -C "$FIX_MCP" rev-parse HEAD)"
bash "$RM" scan --json --root "$FIX_MCP" > "$TMP/cmcp.json" 2>&1
assert "sdd-marketplace is an item, kind mcp-server, remove_command git rm -r mcp-servers/sdd-marketplace" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cmcp.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"mcp-servers/sdd-marketplace\")
assert it[\"kind\"] == \"mcp-server\", it
assert it[\"remove_command\"] == \"git rm -r mcp-servers/sdd-marketplace\", it
assert any(r[\"class\"] == \"mcp-config\" for r in it[\"references\"]), it[\"references\"]
'"
bash "$RM" plan sdd-marketplace --root "$FIX_MCP" > "$TMP/cmcp.plan.out" 2>&1
assert "plan text mentions removing the .mcp.json entry and git rm -r mcp-servers/..." \
  "grep -q 'sdd-marketplace\": entry from .mcp.json' '$TMP/cmcp.plan.out' && grep -q 'git rm -r mcp-servers/sdd-marketplace' '$TMP/cmcp.plan.out'"
assert "plan text never names plugins/sdd-marketplace" \
  "! grep -q 'plugins/sdd-marketplace' '$TMP/cmcp.plan.out'"
rm -rf "$FIX_MCP/mcp-servers/sdd-marketplace"
bash "$RM" scan --json --root "$FIX_MCP" > "$TMP/cmcp2.json" 2>&1
assert "removing the dir: no item, dangling_mcp length 1" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cmcp2.json\"))
assert not any(i.get(\"path\") == \"mcp-servers/sdd-marketplace\" for i in d[\"items\"])
assert len(d[\"dangling_mcp\"]) == 1, d[\"dangling_mcp\"]
'"

echo ""
echo "C. project-owned content rows (project-migrations.conf) — bypass ownership scoping"
FIX_PROJ="$TMP/fixture-proj"; cp -R "$FIX1" "$FIX_PROJ"
echo 'content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:notes | PROPOSE | - | v7.0.0 | proposal: x; why: y' \
  > "$FIX_PROJ/.logic-loom/config/project-migrations.conf"
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj.json" 2>&1
assert "the project row yields a content item, source project, matches non-empty" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\")
assert it[\"source\"] == \"project\", it
assert it[\"matches\"], it
'"
cat >> "$FIX_PROJ/.logic-loom/config/project-migrations.conf" <<'EOF'
content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:local | PROPOSE | - | v7.0.0 | proposal: x2; why: y2
EOF
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj2.json" 2>&1
assert "a second project row on the same file yields a second MG- item" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj2.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 2, items
'"

echo "keep = plugins/sdd-debug/skills/sdd-debug/notes.md@v7.0.0" > "$FIX_PROJ/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj3.json" 2>&1
assert "keep = <file>@v7.0.0 silences BOTH content rows on that file (one file, one release, one acknowledgment); summary.kept counts both" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj3.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 2 and all(i[\"recommended\"] == \"KEEP-AS-IS\" for i in items), items
assert d[\"summary\"][\"kept\"] == 2, d[\"summary\"]
'"
# §15.2-I: `\|` inside a field decodes to a literal `|`, so a pattern may carry
# an ERE alternation. `notes\|zzz` must still match the file's "local notes".
cat >> "$FIX_PROJ/.logic-loom/config/project-migrations.conf" <<'EOF'
content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:notes\|zzz | PROPOSE | - | v7.0.0 | proposal: x3; why: y3
EOF
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj4.json" 2>&1
assert "a project row with an escaped alternation (pattern:notes\\|zzz) is decoded and matches (matches non-empty)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj4.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 3, items
assert all(i[\"matches\"] for i in items), items
'"

echo ""
echo "C. upstream-first registry: refs/loom-upstream/main wins over the local file"
# Commit a registry carrying one extra synthetic row, point refs/loom-upstream/main
# at that commit, then put the ORIGINAL registry back locally (a second commit) —
# so the row exists only upstream. Verbs used: add, commit, update-ref, show.
FIX_UP="$TMP/fixture-upstream"; cp -R "$FIX1" "$FIX_UP"
echo "plugin | sdd-synthetic | removed | none | REMOVE | v9.0.0 | v9.1.0 | test" >> "$FIX_UP/.logic-loom/config/release-migrations.conf"
( cd "$FIX_UP" && git add -A >/dev/null && git commit -q -m "upstream registry with sdd-synthetic" )
git -C "$FIX_UP" update-ref refs/loom-upstream/main HEAD
git -C "$FIX_UP" show "HEAD~1:.logic-loom/config/release-migrations.conf" > "$FIX_UP/.logic-loom/config/release-migrations.conf"
( cd "$FIX_UP" && git add -A >/dev/null && git commit -q -m "local registry without the row" )
assert "the local registry really lacks the synthetic row" \
  "! grep -q 'sdd-synthetic' '$FIX_UP/.logic-loom/config/release-migrations.conf'"
mkdir -p "$FIX_UP/plugins/sdd-synthetic"
echo "x" > "$FIX_UP/plugins/sdd-synthetic/x.md"
bash "$RM" scan --root "$FIX_UP" > "$TMP/cup.human.out" 2>&1
bash "$RM" scan --json --root "$FIX_UP" > "$TMP/cup.json" 2>&1
assert "human header says 'registry: upstream'" "grep -q '^registry: upstream' '$TMP/cup.human.out'"
assert "the upstream-only row yields an MG- item for plugins/sdd-synthetic" \
  "python3 -c '
import json, re
d = json.load(open(\"$TMP/cup.json\"))
assert d[\"registry\"] == \"upstream\", d[\"registry\"]
it = next((i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-synthetic\"), None)
assert it is not None, d[\"items\"]
assert re.match(r\"^MG-[0-9]{3}\$\", it[\"id\"]) and it[\"kind\"] == \"plugin\", it
'"

echo ""
echo "C. ADOPTED fixture: the v7.0.0 receipt content row"
FIX_ADOPT="$TMP/fixture-adopt"; cp -R "$FIX1" "$FIX_ADOPT"
cat > "$FIX_ADOPT/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    { "at": "2026-01-01T00:00:00Z", "status": "complete",
      "generator": "logicloom@6.6.1",
      "wrote": [
        { "kind": "dir", "path": "plugins/" },
        { "kind": "file", "path": "plugins/sdd-debug/commands/debug.md" }
      ], "skipped": [], "failed": [], "notAttempted": [] }
  ]
}
JSON
( cd "$FIX_ADOPT" && git add -A >/dev/null && git commit -q -m "adopt receipt" )
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt.json" 2>&1
assert "the v7.0.0 row yields a content item, kind content, path .logicloom-adopt-receipt.json, PROPOSE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logicloom-adopt-receipt.json\"), None)
assert it is not None, d[\"items\"]
assert it[\"recommended\"] == \"PROPOSE\", it
assert \"record-update-writes.sh --reconcile\" in it[\"proposal\"], it[\"proposal\"]
'"
echo "keep = .logicloom-adopt-receipt.json@v7.0.0" >> "$FIX_ADOPT/.logic-loom/config/migration-decisions.conf" 2>/dev/null \
  || { mkdir -p "$FIX_ADOPT/.logic-loom/config"; echo "keep = .logicloom-adopt-receipt.json@v7.0.0" > "$FIX_ADOPT/.logic-loom/config/migration-decisions.conf"; }
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt2.json" 2>&1
assert "keep = .logicloom-adopt-receipt.json@v7.0.0 -> KEEP-AS-IS, counted kept" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt2.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logicloom-adopt-receipt.json\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert d[\"summary\"][\"kept\"] >= 1, d[\"summary\"]
'"
assert "the project notes.md row still yields an item in the ADOPTED fixture (project rows bypass scoping)" \
  "cp '$FIX_PROJ/.logic-loom/config/project-migrations.conf' '$FIX_ADOPT/.logic-loom/config/project-migrations.conf' \
   && bash '$RM' scan --json --root '$FIX_ADOPT' > '$TMP/cadopt-proj.json' 2>&1 \
   && python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-proj.json\"))
assert any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\" and i[\"source\"] == \"project\" for i in d[\"items\"]), d[\"items\"]
'"

# Ownership scoping (§14.1.3): an UPSTREAM content row on a file the receipt
# does not record is NOT evaluated in an ADOPTED repo — LogicLoom never claims
# text it did not ship. The same row IS evaluated once the receipt records the
# file, and always in a TEMPLATE clone. The temp registry is the real one plus
# one row, so the plugin items keep their normal shape.
ADOPT_UP_REG="$TMP/adopt-up-reg.conf"
cat "$REG" > "$ADOPT_UP_REG"
echo 'content | plugins/sdd-debug/skills/sdd-debug/SKILL.md | present | pattern:. | PROPOSE | - | v7.0.0 | proposal: p; why: w' >> "$ADOPT_UP_REG"
bash "$RM" scan --json --root "$FIX_ADOPT" --registry "$ADOPT_UP_REG" > "$TMP/cadopt-up1.json" 2>&1
assert "an UNRECORDED upstream content row on the SKILL.md is NOT an item in ADOPTED mode" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-up1.json\"))
assert not any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\" for i in d[\"items\"]), d[\"items\"]
'"
python3 - "$FIX_ADOPT/.logicloom-adopt-receipt.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["runs"][0]["wrote"].append({"kind": "file", "path": "plugins/sdd-debug/skills/sdd-debug/SKILL.md"})
json.dump(d, open(p, "w"), indent=2)
PY
bash "$RM" scan --json --root "$FIX_ADOPT" --registry "$ADOPT_UP_REG" > "$TMP/cadopt-up2.json" 2>&1
assert "…but IS an item once the receipt records that file" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-up2.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"source\"] == \"upstream\" and it[\"matches\"], it
'"
bash "$RM" scan --json --root "$FIX1" --registry "$ADOPT_UP_REG" > "$TMP/ctmpl-up.json" 2>&1
assert "…and is an item in a TEMPLATE clone (no receipt: every matched file is evaluated)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ctmpl-up.json\"))
assert any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\" for i in d[\"items\"]), d[\"items\"]
'"

# finding 2 (fixed): .github/ is SCANNED in ADOPTED mode too — an adopter's
# own CI referencing a retired plugin's path must block REMOVE and be
# reported as theirs (this script still never proposes or writes a change
# under .github/ — it only reads it, same as every other reference class).
mkdir -p "$FIX_ADOPT/.github/workflows"
echo "run: bash plugins/sdd-dev-loop/scripts/run.sh" > "$FIX_ADOPT/.github/workflows/ci.yml"
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt-ci.json" 2>&1
assert "ADOPTED + ci.yml naming the plugin: sdd-dev-loop IS blocked, blocked_by names ci.yml, class ci-workflow" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-ci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert any(b[\"file\"] == \".github/workflows/ci.yml\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
assert any(r[\"class\"] == \"ci-workflow\" for r in it[\"references\"]), it[\"references\"]
'"
bash "$RM" plan sdd-dev-loop --root "$FIX_ADOPT" > "$TMP/cadopt-ci.plan.out" 2>&1
assert "ADOPTED plan text also names the workflow as BLOCKED until:" \
  "grep -q 'BLOCKED until: .*\\.github/workflows/ci\\.yml' '$TMP/cadopt-ci.plan.out'"
assert "…and the remove_command it prints still targets only the plugin, never a .github path" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-ci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"remove_command\"] == \"git rm -r plugins/sdd-dev-loop\", it
'"

echo ""
echo "C. finding 3: a gitignored .claude/settings.local.json hook is scanned explicitly"
FIX_LOCAL="$TMP/fixture-local"; cp -R "$FIX1" "$FIX_LOCAL"
LOCAL_SETTINGS_NAME=".claude/settings.local.json"
printf '{\n  \"hooks\": { \"PreToolUse\": [ { \"matcher\": \"Bash\", \"hooks\": [\n    { \"type\": \"command\", \"command\": \"bash plugins/sdd-dev-loop/hooks/scripts/local.sh\" }\n  ]}]}\n}\n' > "$FIX_LOCAL/$LOCAL_SETTINGS_NAME"
echo "$LOCAL_SETTINGS_NAME" > "$FIX_LOCAL/.gitignore"
( cd "$FIX_LOCAL" && git add -A >/dev/null && git commit -q -m "gitignore local settings" )
assert "the fixture's local settings file really is gitignored (git grep --untracked would miss it)" \
  "git -C '$FIX_LOCAL' check-ignore -q '$LOCAL_SETTINGS_NAME'"
bash "$RM" scan --json --root "$FIX_LOCAL" > "$TMP/clocal.json" 2>&1
assert "sdd-dev-loop is blocked by the gitignored settings.local.json hook, class wired-hook" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/clocal.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert any(b[\"file\"] == \".claude/settings.local.json\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
assert any(w[\"file\"] == \".claude/settings.local.json\" for w in it[\"wired_hooks\"]), it[\"wired_hooks\"]
'"

echo ""
echo "C. finding 1 (fix BY DESIGN): a tag can NEVER establish a baseline that leads to REMOVE"
FIX_FAKETAG="$TMP/fixture-faketag"
mkdir -p "$FIX_FAKETAG/.logic-loom/config" "$FIX_FAKETAG/.logic-loom/lib" "$FIX_FAKETAG/plugins/sdd-dev-loop"
git init -q "$FIX_FAKETAG"
cp "$REG" "$FIX_FAKETAG/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FIX_FAKETAG/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=6.6.2" > "$FIX_FAKETAG/.logic-loom/config/architecture.conf"
echo "pristine plugin body" > "$FIX_FAKETAG/plugins/sdd-dev-loop/marker.txt"
# an ADOPTER'S OWN product, tagged v2.3.1 — the vX.Y.Z shape a customer's own
# semver release tag is very likely to have, and NOT a LogicLoom release.
cat > "$FIX_FAKETAG/package.json" <<'JSON'
{ "name": "acme-widgets", "version": "2.3.1" }
JSON
( cd "$FIX_FAKETAG" && git add -A >/dev/null && git commit -q -m "customer release 2.3.1" )
git -C "$FIX_FAKETAG" update-ref refs/tags/v2.3.1 HEAD
bash "$RM" scan --json --root "$FIX_FAKETAG" > "$TMP/cfaketag.json" 2>&1
assert "an adopter's own v2.3.1 product tag is NEVER accepted as a baseline: baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cfaketag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# The adversarial case the review demanded: a tag CRAFTED to satisfy EVERY
# heuristic the old code checked — package.json name+version stamp (the
# TEMPLATE route) AND a matching architecture.conf FRAMEWORK_VERSION (the
# ADOPTED route) BOTH present on the same tagged commit — on a genuinely
# CUSTOMIZED retired plugin, in a repo that also carries the ADOPTED marker
# (.logic-loom/AGENTS.md). The old heuristic would have accepted this tag as
# a "genuine LogicLoom release" and recommended REMOVE on a customer's own
# customized content. The fix is structural (tags are never consulted for a
# baseline at all, ADOPTED or not), so this must stay baseline none / state
# unknown / never REMOVE no matter how convincing the forged tag is.
cat > "$FIX_FAKETAG/package.json" <<'JSON'
{ "name": "logic-loom", "version": "2.3.1" }
JSON
echo "FRAMEWORK_VERSION=2.3.1" > "$FIX_FAKETAG/.logic-loom/config/architecture.conf"
mkdir -p "$FIX_FAKETAG/.logic-loom"
: > "$FIX_FAKETAG/.logic-loom/AGENTS.md"
echo "a customer's own hand-edited body, NOT LogicLoom's shipped content" > "$FIX_FAKETAG/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_FAKETAG" && git add -A >/dev/null && git commit -q -m "forged tag: every old heuristic satisfied, on customized content" )
git -C "$FIX_FAKETAG" update-ref refs/tags/v2.3.1 HEAD
bash "$RM" scan --json --root "$FIX_FAKETAG" > "$TMP/crealtag.json" 2>&1
assert "…even a tag crafted to satisfy EVERY old heuristic (package.json stamp + architecture.conf stamp + ADOPTED marker) on customized content is NEVER accepted: baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/crealtag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. finding 1: the adopt receipt's recorded sha256 for ONE file IS a valid baseline (ADOPTED-only, file-kind rows only)"
FIX_RECEIPT="$TMP/fixture-receipt"
mkdir -p "$FIX_RECEIPT/.logic-loom/config" "$FIX_RECEIPT/.logic-loom/lib" "$FIX_RECEIPT/docs"
git init -q "$FIX_RECEIPT"
cp "$LIB" "$FIX_RECEIPT/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | test fixture for the receipt-sha256 baseline route" \
  > "$FIX_RECEIPT/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT/docs/old-note.md"
RECEIPT_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT"'/docs/old-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_RECEIPT/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$RECEIPT_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$FIX_RECEIPT" && git add -A >/dev/null && git commit -q -m "adopted install" )
bash "$RM" scan --json --root "$FIX_RECEIPT" > "$TMP/creceipt-pristine.json" 2>&1
assert "byte-identical to what the receipt recorded: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-pristine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "a customer edit, after the receipt was written" >> "$FIX_RECEIPT/docs/old-note.md"
bash "$RM" scan --json --root "$FIX_RECEIPT" > "$TMP/creceipt-customized.json" 2>&1
assert "…customized since: same baseline, state customized, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-customized.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT_SHA\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. the receipt route must read the digest the REAL writers store: \"sha256:<hex>\""
echo "   (packaging/adopt fsops.js sha256File and record-update-writes.sh's JSON helper both prefix it)"
# The fixture above fabricated a bare-hex digest; no shipped writer produces
# that. Against a real receipt the comparison must still work, and a digest
# that is not a sha256 at all must prove nothing.
FIX_RECEIPT2="$TMP/fixture-receipt-realformat"
mkdir -p "$FIX_RECEIPT2/.logic-loom/config" "$FIX_RECEIPT2/.logic-loom/lib" "$FIX_RECEIPT2/docs"
git init -q "$FIX_RECEIPT2"
cp "$LIB" "$FIX_RECEIPT2/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT2/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | real-format receipt digest" \
  > "$FIX_RECEIPT2/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT2/docs/old-note.md"
RECEIPT2_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT2"'/docs/old-note.md", "rb").read()).hexdigest())
')"
mk_receipt2() {  # $1 = the "sha256" field value, recorded verbatim
  cat > "$FIX_RECEIPT2/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$1" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
}
mk_receipt2 "sha256:$RECEIPT2_SHA"
( cd "$FIX_RECEIPT2" && git add -A >/dev/null && git commit -q -m "adopted install, real-format receipt" )
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-pristine.json" 2>&1
assert "a real-format digest (\"sha256:<hex>\") on byte-identical content: baseline receipt-sha256:<bare hex>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-pristine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "a customer edit, after the receipt was written" >> "$FIX_RECEIPT2/docs/old-note.md"
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-customized.json" 2>&1
assert "…customized since: state customized, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-customized.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# a recorded digest that is not a 64-hex sha256 at all (an older or
# placeholder entry — test_adopt_applier.sh's receipts carry "sha256:aaaa")
# proves nothing about the bytes on disk: no baseline, never REMOVE, even
# though the file is byte-identical to what LogicLoom wrote.
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT2/docs/old-note.md"
mk_receipt2 "sha256:aaaa"
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-malformed.json" 2>&1
assert "a malformed recorded digest (\"sha256:aaaa\") is unusable: baseline none, state unknown, never REMOVE — even on byte-identical content" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-malformed.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# Round-2 finding 4: the assertion above is NOT discriminating on its own —
# a script with NO malformed-digest check at all (one that never reads the
# receipt route in the first place) produces the exact same "none"/"unknown"
# result on THIS fixture, for a completely different reason (there is no
# other baseline candidate here either way). Proving the REJECTION
# mechanism actually fired — not merely that the receipt route is absent —
# needs a DELTA: the SAME path, SAME fixture, differing ONLY in whether the
# recorded digest is well-formed, must resolve to a DIFFERENT baseline. A
# script that cannot parse/validate receipts at all would give "none" for
# BOTH runs (no delta); this fails closed only when the well-formed run
# resolves through the receipt route and the malformed run does not.
assert "…and the malformed digest actually MATTERS: baseline differs from the well-formed run on the identical fixture/path (proves the mechanism fired, not merely 'no receipt route')" \
  "python3 -c '
import json
well = json.load(open(\"$TMP/creceipt2-pristine.json\"))
mal = json.load(open(\"$TMP/creceipt2-malformed.json\"))
wit = next(i for i in well[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
mit = next(i for i in mal[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert wit[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", wit
assert mit[\"baseline\"] == \"none\", mit
assert wit[\"baseline\"] != mit[\"baseline\"], (wit[\"baseline\"], mit[\"baseline\"])
'"

echo ""
echo "C. cross-file finding: a receipt-sha256 candidate that MATCHES DISK must win over a"
echo "   sync-ref candidate that merely EXISTS but does not — the mid-run clean-apply case"
echo "   (.sdd-sync-ref advances at Step 6/8, AFTER record-update-writes.sh runs at Step"
echo "   5/7b), which otherwise makes the receipt-sha256 route (finding 1's ADOPTED fix)"
echo "   a dead branch for the common case: a MODIFIED path, present at both the stale"
echo "   sync-ref commit and in the receipt"
# Two upstream commits (U0 old, U1 new) on disjoint lines, exactly like the
# .sdd-sync-ref forgery fixture above: U0 is what .sdd-sync-ref still names
# (not yet advanced); U1 is what refs/loom-upstream/main holds (what a
# clean-apply just wrote to disk) and record-update-writes.sh's real
# two-candidate resolver records into the receipt. Verbs (throwaway repo
# only): init, add, commit, branch, checkout, update-ref.
FIX_DEADBRANCH="$TMP/fixture-receipt-vs-stale-syncref"
mkdir -p "$FIX_DEADBRANCH/.logic-loom/config" "$FIX_DEADBRANCH/.logic-loom/lib" "$FIX_DEADBRANCH/docs"
git init -q "$FIX_DEADBRANCH"
cp "$LIB" "$FIX_DEADBRANCH/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_DEADBRANCH/.logic-loom/config/architecture.conf"
echo "path | docs/note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | dead-branch fixture" \
  > "$FIX_DEADBRANCH/.logic-loom/config/release-migrations.conf"
printf 'content v1 (old)\n' > "$FIX_DEADBRANCH/docs/note.md"
( cd "$FIX_DEADBRANCH" && git add -A >/dev/null && git commit -q -m "U0: old content" )
DB_U0="$(git -C "$FIX_DEADBRANCH" rev-parse HEAD)"
echo "$DB_U0" > "$FIX_DEADBRANCH/.sdd-sync-ref"
( cd "$FIX_DEADBRANCH" && git add .sdd-sync-ref >/dev/null && git commit -q -m "record sync ref" )
cat > "$FIX_DEADBRANCH/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    { "at": "2026-01-01T00:00:00.000Z", "generator": "logicloom-adopt@1.0.0",
      "status": "complete", "only": [], "wrote": [], "skipped": [], "failed": [], "notAttempted": [] }
  ]
}
JSON
( cd "$FIX_DEADBRANCH" && git add -A >/dev/null && git commit -q -m "adopt receipt (pre-existing, no docs/note.md entry yet)" )
( cd "$FIX_DEADBRANCH" && git branch upstream-scratch "$DB_U0" >/dev/null )
( cd "$FIX_DEADBRANCH" && git checkout -q upstream-scratch )
printf 'content v2 (new upstream bytes)\n' > "$FIX_DEADBRANCH/docs/note.md"
( cd "$FIX_DEADBRANCH" && git commit -q -am "U1: upstream modifies docs/note.md" )
DB_U1="$(git -C "$FIX_DEADBRANCH" rev-parse HEAD)"
( cd "$FIX_DEADBRANCH" && git update-ref refs/loom-upstream/main "$DB_U1" )
( cd "$FIX_DEADBRANCH" && git checkout -q - )
# Simulate a clean-apply having just written the new bytes to disk,
# uncommitted, BEFORE .sdd-sync-ref is advanced — record-update-writes.sh's
# real two-candidate resolver records the digest that matches disk (U1's).
printf 'content v2 (new upstream bytes)\n' > "$FIX_DEADBRANCH/docs/note.md"
bash "$RECORDER" docs/note.md --version 9.0.0 --root "$FIX_DEADBRANCH" >/dev/null
DB_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_DEADBRANCH"'/docs/note.md", "rb").read()).hexdigest())
')"
bash "$RM" scan --json --root "$FIX_DEADBRANCH" > "$TMP/cdeadbranch.json" 2>&1
assert "receipt-sha256 (matches disk) wins over a stale-but-present sync-ref: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cdeadbranch.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$DB_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
# A genuine customer edit on top of the clean-apply content matches NEITHER
# candidate: falls back to the (stale) sync-ref, as before this fix —
# customized, never REMOVE. The ordering change must never widen who reads
# as pristine, only who does among candidates that ALREADY prove it.
printf 'content v2 (new upstream bytes)\ncustomer edit on top\n' > "$FIX_DEADBRANCH/docs/note.md"
bash "$RM" scan --json --root "$FIX_DEADBRANCH" > "$TMP/cdeadbranch-customized.json" 2>&1
# Round-2 finding 4: on its own, this assertion is NOT discriminating — a
# script with no two-candidate ordering logic at all (one that only ever
# consults sync-ref, never the receipt) reaches the IDENTICAL sync-ref
# fallback for the identical reason, since the receipt route was never in
# play for it either. What actually proves the ordering fix exists is that
# THIS SAME item, on THIS SAME fixture, resolved through the RECEIPT route a
# moment ago (the assertion right above) and now resolves through the
# SYNC-REF route once disk no longer matches either upstream candidate — a
# script lacking the two-candidate mechanism cannot produce that first half
# at all (it would show sync-ref there too), so bundling both halves into
# one assertion is what makes this fail against such a script.
assert "…and once the adopter edits on top of that: neither candidate matches disk, falls back to the stale sync-ref, customized, never REMOVE — proven against the SAME two-candidate mechanism that resolved receipt-sha256 a moment ago, not a coincidence of sync-ref being the only route this script has" \
  "python3 -c '
import json
pristine = json.load(open(\"$TMP/cdeadbranch.json\"))
d = json.load(open(\"$TMP/cdeadbranch-customized.json\"))
pit = next(i for i in pristine[\"items\"] if i[\"path\"] == \"docs/note.md\")
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/note.md\")
assert pit[\"baseline\"].startswith(\"receipt-sha256:\"), pit
assert it[\"baseline\"] == \"sync-ref:$DB_U0\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. .sdd-sync-ref is a baseline ONLY in the shape LogicLoom writes it (a hex object name)"
echo "   AND, when upstream history is present, only if upstream main reaches it — a customer's"
echo "   own commit written there must never read their customized bytes as pristine"
# Two disjoint lines in one throwaway repo: the upstream line U1 (ships
# sdd-dev-loop) -> U2 (retires it), with refs/loom-upstream/main = U2; and
# the customer line C1, branched from U1, where the customer customized the
# plugin. C1 is not reachable from upstream main — it is not LogicLoom's
# commit — yet before this fix, writing it into .sdd-sync-ref made the
# scanner diff the customized plugin against ITSELF: pristine, REMOVE.
# Verbs (throwaway repo only): init, add, commit, rm, checkout, update-ref.
FIX_SYNC="$TMP/fixture-syncref-forged"
mkdir -p "$FIX_SYNC/.logic-loom/config" "$FIX_SYNC/.logic-loom/lib" "$FIX_SYNC/plugins/sdd-dev-loop"
git init -q "$FIX_SYNC"
cp "$LIB" "$FIX_SYNC/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_SYNC/.logic-loom/config/architecture.conf"
echo "plugin | sdd-dev-loop | native | native:/workflow,/loop,/goal | REMOVE | v4.0.0 | v6.2.0 | x" > "$FIX_SYNC/.logic-loom/config/release-migrations.conf"
echo "LogicLoom's shipped body" > "$FIX_SYNC/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_SYNC" && git add -A >/dev/null && git commit -q -m "U1: upstream ships sdd-dev-loop" )
SYNC_U1="$(git -C "$FIX_SYNC" rev-parse HEAD)"
( cd "$FIX_SYNC" && git rm -rq plugins/sdd-dev-loop >/dev/null && git commit -q -m "U2: upstream retires it" )
git -C "$FIX_SYNC" update-ref refs/loom-upstream/main HEAD
( cd "$FIX_SYNC" && git checkout -q "$SYNC_U1" && git checkout -q -b customer )
echo "the CUSTOMER's own edit — not LogicLoom's bytes" >> "$FIX_SYNC/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_SYNC" && git add -A >/dev/null && git commit -q -m "C1: customer customizes sdd-dev-loop" )
SYNC_C1="$(git -C "$FIX_SYNC" rev-parse HEAD)"
assert "fixture: the customer's commit is NOT reachable from refs/loom-upstream/main" \
  "! git -C '$FIX_SYNC' merge-base --is-ancestor '$SYNC_C1' refs/loom-upstream/main"
sync_scan() {  # $1 = .sdd-sync-ref content, $2 = json output path
  printf '%s\n' "$1" > "$FIX_SYNC/.sdd-sync-ref"
  bash "$RM" scan --json --root "$FIX_SYNC" > "$2" 2>&1
}
sync_scan "$SYNC_C1" "$TMP/csync-own.json"
assert "the customer's OWN commit sha in .sdd-sync-ref (upstream history present, commit not reachable from it): never a sync-ref baseline, never pristine, never REMOVE, no remove command" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-own.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert not it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
'"
sync_scan "HEAD" "$TMP/csync-head.json"
assert "a symbolic name (HEAD) in .sdd-sync-ref is not the shape LogicLoom writes: never a sync-ref baseline, never pristine, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-head.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert not it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
sync_scan "$SYNC_U1" "$TMP/csync-genuine.json"
assert "positive control: the genuine upstream commit (reachable from upstream main) IS the sync-ref baseline, and the customized plugin reads customized -> CONVERT-TO-LOCAL" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-genuine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"sync-ref:$SYNC_U1\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
'"
# Round-2 finding 1 (fix BY DESIGN, reversing round-1's permissive
# fallback): with no upstream history at all there is NO BASELINE, full
# stop — hex shape alone is NEVER enough, because there is nothing to check
# reachability against and a customer's own commit sha is indistinguishable
# from LogicLoom's record by shape. A symbolic name still never qualifies
# either (that part was already correct).
git -C "$FIX_SYNC" update-ref -d refs/loom-upstream/main
sync_scan "HEAD" "$TMP/csync-head-noup.json"
assert "…and with no upstream history, HEAD in .sdd-sync-ref is still rejected on shape: baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-head-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# The regression this fix closes: a GENUINELY hex, GENUINELY real upstream
# commit sha (SYNC_U1 — the very commit the positive control above accepted
# a moment ago, while refs/loom-upstream/main still existed) must now be
# rejected the instant that history is gone. Before this fix, hex shape
# alone would have re-admitted it as a baseline, silently reading the
# customized plugin as pristine again the moment refs/loom-upstream/main
# went missing (extract-proposals.sh --dry-run prunes it — see
# upstream_blob_sha's own comment on that in record-update-writes.sh).
sync_scan "$SYNC_U1" "$TMP/csync-genuine-noup.json"
assert "…and even a hex sha that WAS a genuine upstream commit is rejected once refs/loom-upstream/main is gone (no baseline to prove it against): baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-genuine-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# And the forged (customer) commit specifically, without upstream history —
# the task's own two-by-two matrix (forged sync-ref, with AND without
# refs/loom-upstream/main present) completed for the scanner half.
sync_scan "$SYNC_C1" "$TMP/csync-own-noup.json"
assert "…and the customer's OWN forged commit, now with no upstream history either: still baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-own-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. finding 4 (formerly 5a): the printed/apply MOVE command re-checks the destination ITSELF and refuses rather than relying on a bare git mv's own failure"
# background reproduction: a bare git mv onto an existing destination already
# fails cleanly (non-destructive) — that was never the gap. The gap the
# reviewers flagged is that the RECOMMENDATION is computed at scan/plan time
# and never re-checked when it is actually run later; the fix below makes the
# printed/apply command re-check immediately before it acts, every time.
MVTEST="$TMP/movetest"
mkdir -p "$MVTEST"; git init -q "$MVTEST"
echo old > "$MVTEST/old.txt"; ( cd "$MVTEST" && git add -A >/dev/null && git commit -qm init )
echo new > "$MVTEST/new.txt"; ( cd "$MVTEST" && git add -A >/dev/null && git commit -qm addnew )
( cd "$MVTEST" && git mv old.txt new.txt >/dev/null 2>"$TMP/mv.err" )
MV_RC=$?
assert "a bare git mv onto an existing destination fails (non-zero), not silently" "[ $MV_RC -ne 0 ]"
assert "…and the freshly-added destination's content is untouched (no overwrite)" \
  "[ \"\$(cat '$MVTEST/new.txt')\" = new ]"

# the actual fix: build a MOVE fixture, capture the real move_command scan
# computes, then let a clean-add land at the destination AFTER that — exactly
# the same-run race the finding describes — and run the CAPTURED command
# for real.
MVFIX="$TMP/movefix"
mkdir -p "$MVFIX/.logic-loom/config" "$MVFIX/.logic-loom/lib" "$MVFIX/old"
git init -q "$MVFIX"
cp "$LIB" "$MVFIX/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$MVFIX/.logic-loom/config/architecture.conf"
echo "thing" > "$MVFIX/old/thing.md"
( cd "$MVFIX" && git add -A >/dev/null && git commit -q -m "old/thing.md present" )
git -C "$MVFIX" rev-parse HEAD > "$MVFIX/.sdd-sync-ref"
( cd "$MVFIX" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
# Round-2 finding 1: the sync-ref is only a baseline when refs/loom-upstream/
# main exists and reaches it.
git -C "$MVFIX" update-ref refs/loom-upstream/main HEAD
MVFIX_REG="$TMP/movefix-reg.conf"
echo 'path | old/thing.md | renamed | path:new/thing.md | MOVE | v6.0.0 | v9.0.0 | moved' > "$MVFIX_REG"

bash "$RM" scan --json --root "$MVFIX" --registry "$MVFIX_REG" > "$TMP/mvfix.json" 2>&1
MVFIX_CMD="$(python3 -c '
import json
d = json.load(open("'"$TMP"'/mvfix.json"))
it = next(i for i in d["items"] if i["path"] == "old/thing.md")
print(it["move_command"])
')"
assert "the computed move_command is non-empty" "[ -n \"\$MVFIX_CMD\" ]"

mkdir -p "$MVFIX/new"
echo "freshly added, must survive" > "$MVFIX/new/thing.md"
( cd "$MVFIX" && bash -c "$MVFIX_CMD" >"$TMP/mvfix-run.out" 2>"$TMP/mvfix-run.err" )
MVFIX_RUN_RC=$?
assert "running the CAPTURED move_command against a since-appeared destination: refuses (non-zero), never overwrites" \
  "[ $MVFIX_RUN_RC -ne 0 ]"
assert "…the refusal names the destination and tells the agent to re-run plan" \
  "grep -q 'new/thing.md already exists on disk' '$TMP/mvfix-run.err' && grep -q 're-run: release-migrations.sh plan old/thing.md' '$TMP/mvfix-run.err'"
assert "…and neither file was touched: destination content unchanged, source still present" \
  "[ \"\$(cat '$MVFIX/new/thing.md')\" = 'freshly added, must survive' ] && [ -f '$MVFIX/old/thing.md' ]"

# positive control: with no destination in the way, the SAME captured command
# performs the move.
rm -rf "$MVFIX/new"
( cd "$MVFIX" && bash -c "$MVFIX_CMD" >"$TMP/mvfix-run2.out" 2>"$TMP/mvfix-run2.err" )
MVFIX_RUN2_RC=$?
assert "…and with no destination in the way, the same captured command succeeds and actually moves the file" \
  "[ $MVFIX_RUN2_RC -eq 0 ] && [ ! -e '$MVFIX/old/thing.md' ] && [ -f '$MVFIX/new/thing.md' ]"

echo ""
echo "C. finding 5b (investigated, refuted as a live exploit): the removal guard's"
echo "   has_row check matches on (kind,name) only, not the row's release field —"
echo "   but the registry lint enforces AT MOST ONE row per (kind,name) globally,"
echo "   so within a single linted registry file there is no 'wrong release' row"
echo "   to collide with; check-release's has_row only ever reads REGISTRY_FILE"
echo "   (never project-migrations.conf), so a project-side collision cannot"
echo "   reach it either. Reproduced: lint rejects a duplicate (kind,name) pair."
DUPREG="$TMP/dup-registry.conf"
printf 'plugin | sdd-dup | removed | none | REMOVE | v4.0.0 | v5.0.0 | first\nplugin | sdd-dup | removed | none | REMOVE | v4.0.0 | v9.0.0 | second, different release\n' > "$DUPREG"
bash "$RM" lint --registry "$DUPREG" --root "$ROOT" > "$TMP/duplint.out" 2>&1
DUP_RC=$?
assert "a second row for the same (kind,name) at a different release: lint fails, 'duplicate deprecation name'" \
  "[ $DUP_RC -eq 1 ] && grep -q 'duplicate deprecation name sdd-dup' '$TMP/duplint.out'"

echo ""
echo "C. finding 6 (KORI CLASS): PROPOSE-ADVISORY content row on a fork-owned file"
FIX_KORI="$TMP/fixture-kori"; cp -R "$FIX1" "$FIX_KORI"
mkdir -p "$FIX_KORI/.logic-loom/memory"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before" "$FIX_KORI/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_KORI" > "$TMP/ckori-old.json" 2>&1
assert "old alternative-line wording: fires, kind content, advisory true, recommended PROPOSE-ADVISORY" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-old.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"advisory\"] is True, it
assert it[\"recommended\"] == \"PROPOSE-ADVISORY\", it
assert \"LogicLoom did not ship this text\" in it[\"reason\"], it[\"reason\"]
'"
bash "$RM" scan --root "$FIX_KORI" > "$TMP/ckori-old.human" 2>&1
assert "human output states plainly LogicLoom did not ship this text (advisory banner)" \
  "grep -q 'ADVISORY .*LogicLoom did not ship this text' '$TMP/ckori-old.human'"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after" "$FIX_KORI/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_KORI" > "$TMP/ckori-new.json" 2>&1
assert "new additive '+3' wording: does NOT fire" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-new.json\"))
assert not any(i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\" for i in d[\"items\"]), d[\"items\"]
'"
# fires the same way in ADOPTED mode, with NO adopt-receipt entry for
# amendments.md — the ownership-scoping rule the receipt-based rows use does
# not apply to an advisory row (the harness never wrote this file).
mkdir -p "$FIX_ADOPT/.logic-loom/memory"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before" "$FIX_ADOPT/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/ckori-adopted.json" 2>&1
assert "fires the same way in ADOPTED mode with no receipt entry for amendments.md (never ownership-scoped)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-adopted.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"advisory\"] is True, it
'"
assert "lint rejects PROPOSE-ADVISORY on a non-fork-owned target" \
  "printf 'content | some/random/file.md | present | pattern:x | PROPOSE-ADVISORY | - | v9.9.9 | proposal: a; why: b\n' > '$TMP/kori-bad.conf' \
   && ! bash '$RM' lint --registry '$TMP/kori-bad.conf' --root '$ROOT' >/dev/null 2>&1"
assert "…and accepts it on CLAUDE.local.md (an allowed fork-owned basename)" \
  "printf 'content | CLAUDE.local.md | present | pattern:x | PROPOSE-ADVISORY | - | v9.9.9 | proposal: a; why: b\n' > '$TMP/kori-ok.conf' \
   && bash '$RM' lint --registry '$TMP/kori-ok.conf' --root '$ROOT' >/dev/null 2>&1"
# reviewer (finding 6): the fork's REAL line is a markdown list item —
# `- 3 = it changes auth, payment, or customer-data logic` (kori-beta
# amendments.md:148; design §14.3 shows the same bulleted form). A pattern
# anchored `^[[:space:]]*3` never matched it. These assert the SHIPPED
# pattern (read back through the lib, so `\|` decoding is exercised too)
# against the real forms, and that no `+3` spelling fires.
KORI_PAT="$(printf '%s' "$KORIROW" | awk -F'\t' '{print $4}')"; KORI_PAT="${KORI_PAT#pattern:}"
kori_pat_hits() { printf '%s\n' "$1" | grep -qE -- "$KORI_PAT"; }
assert "KORI pattern matches the real fork form: '- 3 = it changes auth, payment, or customer-data logic' (bulleted)" \
  "kori_pat_hits '- 3 = it changes auth, payment, or customer-data logic'"
assert "…and the master doc's indented bare form: '  3 = it changes …'" \
  "kori_pat_hits '  3 = it changes auth, payment, or customer-data logic'"
assert "…and an em-dash separator: '  3 — it changes …'" \
  "kori_pat_hits '  3 — it changes auth, payment, or customer-data logic'"
assert "…and an asterisk bullet: '* 3 = it changes …'" \
  "kori_pat_hits '* 3 = it changes auth, payment, or customer-data logic'"
assert "…but NOT the new additive form: '  +3 — it changes …'" \
  "! kori_pat_hits '  +3 — it changes auth, payment, or customer-data logic'"
assert "…nor its bulleted spelling: '- +3 = it changes …'" \
  "! kori_pat_hits '- +3 = it changes auth, payment, or customer-data logic'"
assert "…nor a different score on the same line: '- 1 = it changes …'" \
  "! kori_pat_hits '- 1 = it changes auth, payment, or customer-data logic'"
assert "the .before fixture carries the real bulleted form (so check-release's fixture proof is of the real form, not a reconstruction)" \
  "grep -qF -- '- 3 = it changes auth, payment, or customer-data logic' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before'"
assert "the .after fixture carries the new form in BOTH spellings and neither fires" \
  "grep -qF -- '+3 — it changes auth' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after' \
   && grep -qF -- '- +3 = it changes auth' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after' \
   && ! grep -qE -- \"\$KORI_PAT\" '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after'"
# the human/JSON output reports the REAL matched line (bullet included)
assert "scan on the real bulleted form reports the matched line verbatim, bullet and all" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-old.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\")
assert any(m[\"text\"].startswith(\"- 3 = it changes auth\") for m in it[\"matches\"]), it[\"matches\"]
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION D — convert
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "D. convert sdd-debug: dry-run, apply, idempotency"

snapshot() { find "$1" -type f ! -path '*/.git/*' | sort | xargs cksum 2>/dev/null; }

FD1="$TMP/fixtureD1"; cp -R "$FIX1" "$FD1"
SNAP_BEFORE="$(snapshot "$FD1")"
bash "$RM" convert sdd-debug --dry-run --root "$FD1" > "$TMP/d1.dry.out" 2>&1
D1_DRY_RC=$?
SNAP_AFTER_DRY="$(snapshot "$FD1")"
assert "dry-run exits 0" "[ $D1_DRY_RC -eq 0 ]"
assert "dry-run writes nothing (snapshot identical)" "[ \"\$SNAP_BEFORE\" = \"\$SNAP_AFTER_DRY\" ]"
assert "dry-run lists WRITE for the skill SKILL.md" \
  "grep -q 'WRITE .claude/skills/sdd-debug/SKILL.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the converted command-as-skill" \
  "grep -q 'WRITE .claude/skills/debug/SKILL.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the converted agent" \
  "grep -q 'WRITE .claude/agents/auto-debug-agent.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the hook script under .claude/skills/" \
  "grep -q 'WRITE .claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' '$TMP/d1.dry.out'"
assert "dry-run prints the 'Hooks (NOT wired)' section" \
  "grep -q 'Hooks (NOT wired)' '$TMP/d1.dry.out'"

bash "$RM" convert sdd-debug --apply --root "$FD1" > "$TMP/d1.apply.out" 2>&1
D1_APPLY_RC=$?
assert "apply exits 0" "[ $D1_APPLY_RC -eq 0 ]"
assert "apply wrote .claude/skills/sdd-debug/SKILL.md" "[ -f '$FD1/.claude/skills/sdd-debug/SKILL.md' ]"
assert "apply wrote .claude/skills/debug/SKILL.md" "[ -f '$FD1/.claude/skills/debug/SKILL.md' ]"
assert "apply wrote .claude/agents/auto-debug-agent.md" "[ -f '$FD1/.claude/agents/auto-debug-agent.md' ]"
assert "apply wrote the hook script" "[ -f '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' ]"
assert "the three markdown files carry the converted-from marker" \
  "grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/skills/sdd-debug/SKILL.md' \
   && grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/skills/debug/SKILL.md' \
   && grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/agents/auto-debug-agent.md'"
assert "the pinned agent model was rewritten to opus" \
  "grep -q '^model: opus\$' '$FD1/.claude/agents/auto-debug-agent.md'"
assert "the hook script is executable" "[ -x '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' ]"
assert "the hook script's paths were rewritten under .claude/skills/sdd-debug/" \
  "grep -q '.claude/skills/sdd-debug/lib/x.sh' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' \
   && grep -q '.claude/skills/sdd-debug/config/y.json' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh'"
assert "no CLAUDE_PLUGIN_ROOT survives in the converted hook script" \
  "! grep -q 'CLAUDE_PLUGIN_ROOT' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh'"
CONV_MD="$FD1/.claude/skills/sdd-debug/CONVERTED.md"
assert "CONVERTED.md exists and lists EVERY written path (target <- source)" \
  "[ -f '$CONV_MD' ] \
   && grep -qF '.claude/skills/sdd-debug/SKILL.md <- plugins/sdd-debug/skills/sdd-debug/SKILL.md' '$CONV_MD' \
   && grep -qF '.claude/skills/debug/SKILL.md <- plugins/sdd-debug/commands/debug.md' '$CONV_MD' \
   && grep -qF '.claude/agents/auto-debug-agent.md <- plugins/sdd-debug/agents/auto-debug-agent.md' '$CONV_MD' \
   && grep -qF '.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh <- plugins/sdd-debug/hooks/scripts/debug-capture.sh' '$CONV_MD'"
assert "CONVERTED.md carries the settings snippet (Hooks NOT wired) pointing at the converted hook script" \
  "grep -q 'Hooks (NOT wired)' '$CONV_MD' \
   && grep -qF '\"command\":\"bash .claude/skills/sdd-debug/hooks/scripts/debug-capture.sh\"' '$CONV_MD'"
assert "CONVERTED.md carries the dangling line (.claude/settings.json still wires plugins/sdd-debug/...)" \
  "grep -q 'dangle' '$CONV_MD' \
   && grep -qF '.claude/settings.json:' '$CONV_MD' \
   && grep -qF 'plugins/sdd-debug/hooks/scripts/debug-capture.sh' '$CONV_MD'"
assert ".claude/settings.json is byte-identical to before the convert" \
  "cksum '$FD1/.claude/settings.json' | awk '{print \$1,\$2}' > '$TMP/d1.settings.after'; \
   cksum '$FIX1/.claude/settings.json' | awk '{print \$1,\$2}' > '$TMP/d1.settings.before'; \
   diff -q '$TMP/d1.settings.before' '$TMP/d1.settings.after' >/dev/null"
assert "plugins/sdd-debug is byte-identical to before the convert" \
  "diff -rq '$FIX1/plugins/sdd-debug' '$FD1/plugins/sdd-debug' >/dev/null"
assert "migration-decisions.conf contains 'converted = sdd-debug' exactly once" \
  "[ \"\$(grep -c '^converted = sdd-debug\$' '$FD1/.logic-loom/config/migration-decisions.conf')\" -eq 1 ]"

SNAP_AFTER_APPLY="$(snapshot "$FD1")"
bash "$RM" convert sdd-debug --apply --root "$FD1" > "$TMP/d1.apply2.out" 2>&1
D1_APPLY2_RC=$?
SNAP_AFTER_APPLY2="$(snapshot "$FD1")"
assert "second --apply exits 0" "[ $D1_APPLY2_RC -eq 0 ]"
assert "second --apply writes nothing new (snapshot identical)" "[ \"\$SNAP_AFTER_APPLY\" = \"\$SNAP_AFTER_APPLY2\" ]"
assert "second --apply reports SKIP for every unit (no WRITE/WROTE)" \
  "! grep -qE '^(WRITE|WROTE) ' '$TMP/d1.apply2.out'"

bash "$RM" scan --json --root "$FD1" > "$TMP/d1.postscan.json" 2>&1
assert "after conversion, scan shows sdd-debug's decision as converted" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d1.postscan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert it[\"decision\"] == \"converted\", it
'"

echo ""
echo "D. round-2 finding 2: decision=converted must NOT force REMOVE regardless of state"
# A plugin converted and COMMITTED (both CONVERTED.md and the 'converted =' line
# land in a real commit) stays REMOVE as long as it is untouched since — but
# once it is edited AFTER that committed decision, the recommendation must
# flip to KEEP-AS-IS (never silently discard a customer's post-conversion
# edit). A third fixture proves the "decision recorded but never committed"
# case is ALSO never a REMOVE (Governing principle: doubt -> KEEP and ASK).
FIX_CONV2="$TMP/fixture-converted-edited"
mkdir -p "$FIX_CONV2/.logic-loom/config" "$FIX_CONV2/.logic-loom/lib" "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2"
git init -q "$FIX_CONV2"
cp "$LIB" "$FIX_CONV2/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV2/.logic-loom/config/architecture.conf"
echo "plugin | sdd-conv2 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 finding 2 fixture" \
  > "$FIX_CONV2/.logic-loom/config/release-migrations.conf"
cat > "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2/SKILL.md" <<'MD'
---
name: sdd-conv2
description: round-2 finding 2 fixture
---

Body.
MD
( cd "$FIX_CONV2" && git add -A >/dev/null && git commit -q -m "plugin present" )
bash "$RM" convert sdd-conv2 --apply --root "$FIX_CONV2" >/dev/null 2>&1
( cd "$FIX_CONV2" && git add -A >/dev/null && git commit -q -m "convert sdd-conv2" )
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-clean.json" 2>&1
assert "decision=converted, plugin UNCHANGED since the (committed) conversion decision -> REMOVE, as before" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-clean.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "-- edited after conversion --" >> "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2/SKILL.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-edited.json" 2>&1
assert "…but once plugins/sdd-conv2 is edited AFTER that committed decision: KEEP-AS-IS, reason names 'edited after conversion', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-edited.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"edited after conversion\" in it[\"reason\"], it
'"
# An UNTRACKED file the customer dropped into plugins/sdd-conv2 after the
# committed decision is their bytes too — no commit vouches for it, and a
# REMOVE plan line on the directory recommends deleting it. A tracked-only
# diff (`git diff <decision-commit> -- plugins/sdd-conv2`) is blind to it and
# would say "unchanged" -> REMOVE. Restore the tracked edit first so the ONLY
# change is the untracked file.
( cd "$FIX_CONV2" && git checkout -q -- plugins/sdd-conv2/skills/sdd-conv2/SKILL.md )
echo "customer notes, never git-added" > "$FIX_CONV2/plugins/sdd-conv2/customer-notes.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-untracked.json" 2>&1
assert "…and an UNTRACKED file added under plugins/sdd-conv2 after the committed decision (tracked files byte-identical to it): KEEP-AS-IS, reason names 'edited after conversion', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-untracked.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"edited after conversion\" in it[\"reason\"], it
assert it[\"remove_command\"] == \"\", it
'"
rm -f "$FIX_CONV2/plugins/sdd-conv2/customer-notes.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-restored.json" 2>&1
assert "…and with the untracked file gone and the tracked edit reverted, the same plugin is back to REMOVE (the untracked check is what flipped it, nothing else)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-restored.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"recommended\"] == \"REMOVE\", it
'"

FIX_CONV3="$TMP/fixture-converted-uncommitted"
mkdir -p "$FIX_CONV3/.logic-loom/config" "$FIX_CONV3/.logic-loom/lib" "$FIX_CONV3/plugins/sdd-conv3/skills/sdd-conv3"
git init -q "$FIX_CONV3"
cp "$LIB" "$FIX_CONV3/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV3/.logic-loom/config/architecture.conf"
echo "plugin | sdd-conv3 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 finding 2 fixture (uncommitted decision)" \
  > "$FIX_CONV3/.logic-loom/config/release-migrations.conf"
cat > "$FIX_CONV3/plugins/sdd-conv3/skills/sdd-conv3/SKILL.md" <<'MD'
---
name: sdd-conv3
description: round-2 finding 2 fixture
---

Body.
MD
( cd "$FIX_CONV3" && git add -A >/dev/null && git commit -q -m "plugin present" )
bash "$RM" convert sdd-conv3 --apply --root "$FIX_CONV3" >/dev/null 2>&1
# Deliberately NOT committed: CONVERTED.md and 'converted =' both sit only
# in the working tree, exactly like FD1 above.
bash "$RM" scan --json --root "$FIX_CONV3" > "$TMP/conv3.json" 2>&1
assert "decision=converted but the decision has no committed record at all (CONVERTED.md/migration-decisions.conf uncommitted): KEEP-AS-IS, reason names 'no committed record', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv3.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv3\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"no committed record\" in it[\"reason\"], it
'"

# The decision-line route must date the decision to the commit that added
# THAT plugin's line, matched as a whole line — `git log -S"converted = foo"`
# is a substring count and also fires on "converted = foobar", so a
# same-prefix plugin converted EARLIER would date foo's decision to the
# wrong, older commit and diff the plugin against the wrong tree. Here:
# sdd-conv4-more is converted and committed first (C1), plugins/sdd-conv4 is
# then edited and committed (a PRE-conversion edit), and only then is
# sdd-conv4 converted, with just the decisions line committed (C2) and its
# CONVERTED.md left uncommitted so the decision-line route is the one in
# play. plugins/sdd-conv4 is untouched since C2, so the honest answer is
# REMOVE; dating the decision to C1 instead would see the pre-conversion
# edit and flip it to KEEP for a reason that is simply false.
FIX_CONV4="$TMP/fixture-converted-prefix-collision"
mkdir -p "$FIX_CONV4/.logic-loom/config" "$FIX_CONV4/.logic-loom/lib" \
  "$FIX_CONV4/plugins/sdd-conv4/skills/sdd-conv4" "$FIX_CONV4/plugins/sdd-conv4-more/skills/sdd-conv4-more"
git init -q "$FIX_CONV4"
cp "$LIB" "$FIX_CONV4/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV4/.logic-loom/config/architecture.conf"
{
  echo "plugin | sdd-conv4 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | prefix-collision fixture"
  echo "plugin | sdd-conv4-more | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | prefix-collision fixture (the longer name)"
} > "$FIX_CONV4/.logic-loom/config/release-migrations.conf"
for cp4 in sdd-conv4 sdd-conv4-more; do
  cat > "$FIX_CONV4/plugins/$cp4/skills/$cp4/SKILL.md" <<MD
---
name: $cp4
description: prefix-collision fixture
---

Body.
MD
done
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C0: both plugins present" )
bash "$RM" convert sdd-conv4-more --apply --root "$FIX_CONV4" >/dev/null 2>&1
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C1: convert sdd-conv4-more (decision line: converted = sdd-conv4-more)" )
echo "-- edited BEFORE sdd-conv4 was converted --" >> "$FIX_CONV4/plugins/sdd-conv4/skills/sdd-conv4/SKILL.md"
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C1.5: pre-conversion edit to plugins/sdd-conv4" )
bash "$RM" convert sdd-conv4 --apply --root "$FIX_CONV4" >/dev/null 2>&1
( cd "$FIX_CONV4" && git add .logic-loom/config/migration-decisions.conf >/dev/null && git commit -q -m "C2: decision line only (converted = sdd-conv4); CONVERTED.md left uncommitted" )
assert "prefix-collision fixture sanity: sdd-conv4's CONVERTED.md is uncommitted (decision-line route in play), and the decisions file holds both whole lines" \
  "[ -z \"\$(git -C '$FIX_CONV4' log --format=%H -- .claude/skills/sdd-conv4/CONVERTED.md)\" ] && grep -qxF 'converted = sdd-conv4' '$FIX_CONV4/.logic-loom/config/migration-decisions.conf' && grep -qxF 'converted = sdd-conv4-more' '$FIX_CONV4/.logic-loom/config/migration-decisions.conf'"
bash "$RM" scan --json --root "$FIX_CONV4" > "$TMP/conv4.json" 2>&1
assert "decision-line route, same-prefix plugin converted earlier: sdd-conv4's decision is dated to ITS OWN line's commit (whole-line match), the plugin is unchanged since -> REMOVE, not a false 'edited after conversion' from a substring match on 'converted = sdd-conv4-more'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv4.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv4\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"REMOVE\", it
more = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv4-more\")
assert more[\"decision\"] == \"converted\" and more[\"recommended\"] == \"REMOVE\", more
'"

echo ""
echo "D. finding 4: convert preserves the executable bit on a rewritten skill file"
FD_EXE="$TMP/fixtureD-exe"
mkdir -p "$FD_EXE/.logic-loom/config" "$FD_EXE/.logic-loom/lib" "$FD_EXE/plugins/sdd-exe/skills/sdd-exe" "$FD_EXE/.claude"
cp "$REG" "$FD_EXE/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FD_EXE/.logic-loom/lib/release-migrations.sh"
cat >> "$FD_EXE/.logic-loom/config/release-migrations.conf" <<'EOF'
plugin | sdd-exe | removed | none | REMOVE | v4.0.0 | v6.2.0 | test fixture for the +x preservation defect
EOF
echo "FRAMEWORK_VERSION=6.6.2" > "$FD_EXE/.logic-loom/config/architecture.conf"
cat > "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/SKILL.md" <<'MD'
---
name: sdd-exe
description: fixture for the write_text_target +x defect
---
Body.
MD
cat > "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/run.sh" <<'SH'
#!/usr/bin/env bash
echo hi
SH
chmod +x "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/run.sh"
bash "$RM" convert sdd-exe --apply --root "$FD_EXE" > "$TMP/dexe.apply.out" 2>&1
assert "convert --apply exits 0" "[ $? -eq 0 ]"
assert "the converted run.sh under .claude/skills/ is still executable (the source's +x bit survived the rewrite)" \
  "[ -x '$FD_EXE/.claude/skills/sdd-exe/run.sh' ]"
assert "…and its content still went through the (no-op) path-rewrite pass — not a plain byte copy" \
  "grep -q 'echo hi' '$FD_EXE/.claude/skills/sdd-exe/run.sh'"

echo ""
echo "D. convert sdd-dev-loop: the append path (command into an existing same-named skill)"

FD2="$TMP/fixtureD2"; cp -R "$FIX1" "$FD2"
SNAP2_BEFORE="$(snapshot "$FD2")"
bash "$RM" convert sdd-dev-loop --dry-run --root "$FD2" > "$TMP/d2.dry.out" 2>&1
assert "dry-run prints an APPEND line naming the section source" \
  "grep -q 'APPEND .claude/skills/dev-loop/SKILL.md' '$TMP/d2.dry.out'"
assert "dry-run notes the command frontmatter is kept in section, not merged" \
  "grep -q 'frontmatter: kept in section, not merged' '$TMP/d2.dry.out'"
assert "dry-run prints a NOTE that command frontmatter differs" \
  "grep -q 'NOTE .claude/skills/dev-loop/SKILL.md: command frontmatter differs' '$TMP/d2.dry.out'"
SNAP2_DRY="$(snapshot "$FD2")"
assert "dry-run writes nothing" "[ \"\$SNAP2_DRY\" = \"\$SNAP2_BEFORE\" ]"

bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply.out" 2>&1
assert "apply exits 0" "[ $? -eq 0 ]"
assert "the appended section carries start/end markers" \
  "grep -qF '<!-- converted-from: plugins/sdd-dev-loop/commands/dev-loop.md | logicloom-plugin-deprecations v1 | appended section -->' '$FD2/.claude/skills/dev-loop/SKILL.md' \
   && grep -qF '<!-- end converted-from: plugins/sdd-dev-loop/commands/dev-loop.md -->' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "the appended section carries the 'Command procedure' heading" \
  "grep -q '## Command procedure (converted from commands/dev-loop.md)' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "the appended section carries a yaml fence with the command frontmatter" \
  "grep -q '\`\`\`yaml' '$FD2/.claude/skills/dev-loop/SKILL.md' && grep -q 'allowed-tools: Bash' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "CONVERTED.md lists it as an appended section" \
  "grep -q '(appended section)' '$FD2/.claude/skills/sdd-dev-loop/CONVERTED.md'"

bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply2.out" 2>&1
D2_APPLY2_RC=$?
assert "second apply reports SKIP up-to-date for the appended skill" \
  "grep -q 'SKIP .claude/skills/dev-loop/SKILL.md up-to-date' '$TMP/d2.apply2.out'"
assert "second apply exits 0" "[ $D2_APPLY2_RC -eq 0 ]"
SNAP2_AFTER_APPLY="$(snapshot "$FD2")"
bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply2b.out" 2>&1
SNAP2_AFTER_APPLY2="$(snapshot "$FD2")"
assert "second apply writes nothing new" "[ \"\$SNAP2_AFTER_APPLY\" = \"\$SNAP2_AFTER_APPLY2\" ]"

python3 -c "
import re
p = '$FD2/.claude/skills/dev-loop/SKILL.md'
s = open(p).read()
s = s.replace('## Command procedure (converted from commands/dev-loop.md)',
              'EDITED BY USER\n## Command procedure (converted from commands/dev-loop.md)')
open(p, 'w').write(s)
"
bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply3.out" 2>&1
assert "a line inserted between the markers -> third apply prints KEEP modified-after-conversion" \
  "grep -q 'KEEP .claude/skills/dev-loop/SKILL.md modified-after-conversion' '$TMP/d2.apply3.out'"
assert "the modified file is left unchanged by that apply" \
  "grep -q 'EDITED BY USER' '$FD2/.claude/skills/dev-loop/SKILL.md'"

echo ""
echo "D. Collision: a pre-existing markerless agent file stops that unit only"

FD3="$TMP/fixtureD3"; cp -R "$FIX1" "$FD3"
mkdir -p "$FD3/.claude/agents"
echo "pre-existing, not ours" > "$FD3/.claude/agents/auto-debug-agent.md"
bash "$RM" convert sdd-debug --apply --root "$FD3" > "$TMP/d3.apply.out" 2>&1
D3_RC=$?
assert "convert exits 2 on a collision" "[ $D3_RC -eq 2 ]"
assert "the pre-existing file is left untouched" \
  "[ \"\$(cat '$FD3/.claude/agents/auto-debug-agent.md')\" = 'pre-existing, not ours' ]"
assert "the skill units were still written despite the agent collision" \
  "[ -f '$FD3/.claude/skills/sdd-debug/SKILL.md' ] && [ -f '$FD3/.claude/skills/debug/SKILL.md' ]"

echo ""
echo "D. ADOPT-REPLACEMENT: convert sdd-git --customized-only stops at the counterpart"

FD4="$TMP/fixtureD4"; cp -R "$FIX1" "$FD4"
SNAP4_BEFORE="$(snapshot "$FD4")"
bash "$RM" convert sdd-git --dry-run --customized-only --root "$FD4" > "$TMP/d4.out" 2>&1
D4_RC=$?
SNAP4_AFTER="$(snapshot "$FD4")"
assert "exits 2" "[ $D4_RC -eq 2 ]"
assert "STOP names the counterpart plugin (loom-git)" \
  "grep -q 'STOP' '$TMP/d4.out' && grep -q 'loom-git' '$TMP/d4.out'"
assert "nothing was written (snapshot identical)" "[ \"\$SNAP4_BEFORE\" = \"\$SNAP4_AFTER\" ]"

echo ""
echo "D. Renamed-pristine: sdd-git without local edits recommends REMOVE naming loom-git;"
echo "   removing loom-git flips it to KEEP-AS-IS 'not installed yet'"

FD5="$TMP/fixtureD5"; cp -R "$FIX1" "$FD5"
# restore the committed copy with `git show` (read-only), not `git checkout`
git -C "$FD5" show HEAD:plugins/sdd-git/commands/git-push.md > "$FD5/plugins/sdd-git/commands/git-push.md"
bash "$RM" scan --json --root "$FD5" > "$TMP/d5.json" 2>&1
assert "sdd-git pristine now recommends REMOVE naming plugin:loom-git" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d5.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
assert \"loom-git\" in it[\"reason\"], it
'"
rm -rf "$FD5/plugins/loom-git"
bash "$RM" scan --json --root "$FD5" > "$TMP/d5b.json" 2>&1
assert "with loom-git removed, sdd-git falls back to KEEP-AS-IS 'not installed yet'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d5b.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"not installed yet\" in it[\"reason\"], it
'"

echo ""
echo "D. Moved path (§15.2-F): MOVE, then REMOVE-blocked when upstream ships the new path,"
echo "   REMOVE once it is on disk, KEEP-AS-IS when the old copy is customized"

# A minimal throwaway repo: old/thing.md committed, sync-ref stamped, no tags.
# The row comes from a temp registry (--registry), so the upstream-registry
# resolution never interferes; refs/loom-upstream/main is used ONLY to answer
# "does upstream ship <new>". Verbs: init, add, commit, update-ref, rev-parse.
FD6="$TMP/fixtureD6"
mkdir -p "$FD6/.logic-loom/config" "$FD6/.logic-loom/lib" "$FD6/old"
git init -q "$FD6"
cp "$LIB" "$FD6/.logic-loom/lib/release-migrations.sh"
cp "$REG" "$FD6/.logic-loom/config/release-migrations.conf"
echo "FRAMEWORK_VERSION=7.0.0" > "$FD6/.logic-loom/config/architecture.conf"
echo "thing" > "$FD6/old/thing.md"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "old/thing.md present" )
git -C "$FD6" rev-parse HEAD > "$FD6/.sdd-sync-ref"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
# Round-2 finding 1: the sync-ref is only a baseline when refs/loom-upstream/
# main exists and reaches it.
git -C "$FD6" update-ref refs/loom-upstream/main HEAD
MOVE_REG="$TMP/move-reg.conf"
echo 'path | old/thing.md | renamed | path:new/thing.md | MOVE | v6.0.0 | v9.0.0 | moved' > "$MOVE_REG"

bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6a.json" 2>&1
assert "pristine + new path absent everywhere -> MOVE, not blocked, move_command is a self-guarding git mv (finding 4)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6a.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"kind\"] == \"path\" and it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"MOVE\" and it[\"blocked\"] is False, it
mc = it[\"move_command\"]
assert mc.startswith(\"if [ -e \"), mc
assert \"new/thing.md\" in mc, mc
assert \"git mv old/thing.md new/thing.md\" in mc, mc
assert \"re-run: release-migrations.sh plan old/thing.md\" in mc, mc
assert it[\"remove_command\"] == \"\", it
'"
bash "$RM" plan old/thing.md --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6a.plan.out" 2>&1
assert "plan text carries the guarded git mv line and the [m]ove menu" \
  "grep -qF 'git mv old/thing.md new/thing.md' '$TMP/d6a.plan.out' && grep -qF '[m]ove' '$TMP/d6a.plan.out'"
assert "…and names re-run plan when the destination now exists (finding 4)" \
  "grep -qF 're-run plan old/thing.md to get a fresh recommendation' '$TMP/d6a.plan.out'"

# new/thing.md committed and reachable at refs/loom-upstream/main, then removed
# from the working tree again (a further commit) — upstream ships it, disk lacks it.
mkdir -p "$FD6/new"; echo "new" > "$FD6/new/thing.md"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "upstream ships new/thing.md" )
git -C "$FD6" update-ref refs/loom-upstream/main HEAD
rm -rf "$FD6/new"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "local tree without new/thing.md" )
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6b.json" 2>&1
assert "pristine + new path absent on disk but present at refs/loom-upstream/main -> REMOVE, blocked, 'accept its clean-add proposal first'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6b.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"recommended\"] == \"REMOVE\" and it[\"blocked\"] is True, it
assert \"accept its clean-add proposal first\" in it[\"reason\"], it[\"reason\"]
assert it[\"move_command\"] == \"\", it
assert it[\"blocked_by\"] and \"new/thing.md\" in it[\"blocked_by\"][0][\"file\"], it[\"blocked_by\"]
'"

mkdir -p "$FD6/new"; echo "new" > "$FD6/new/thing.md"
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6c.json" 2>&1
assert "pristine + new path on disk -> REMOVE, not blocked, remove_command 'git rm old/thing.md' (file, not -r)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6c.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"recommended\"] == \"REMOVE\" and it[\"blocked\"] is False, it
assert it[\"remove_command\"] == \"git rm old/thing.md\", it
'"

echo "extra" >> "$FD6/old/thing.md"
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6d.json" 2>&1
assert "customized old copy -> KEEP-AS-IS 'carry your diff into new/thing.md'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6d.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"carry your diff into new/thing.md\" in it[\"reason\"], it[\"reason\"]
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION E — release gate (check-release)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "E. check-release — real tree, and the row-declaration gate on temp roots"

case "$TREE_KIND" in
  maintainer)
    bash "$RM" check-release --root "$ROOT" > "$TMP/e0.out" 2>&1
    E0_RC=$?
    echo "     $(head -1 "$TMP/e0.out")"
    assert "check-release (no --since) exits 0 on the maintainer tree today (predates the floor)" \
      "[ $E0_RC -eq 0 ]"
    ;;
  sanitized)
    skip "release gate is a maintainer check — sanitized tree (CHANGELOG.md is stripped; the gate runs in the promote job)"
    ;;
esac

# Temp root builder: architecture.conf + a registry copy at the same relative
# path the script expects, no git needed (framework_version/loom_migration_rows
# are pure filesystem reads).
mk_temp_root() {  # $1 = dir, $2 = FRAMEWORK_VERSION, $3 = registry body (or "" to skip)
  local d="$1"
  mkdir -p "$d/.logic-loom/config" "$d/.logic-loom/lib"
  echo "FRAMEWORK_VERSION=$2" > "$d/.logic-loom/config/architecture.conf"
  cp "$LIB" "$d/.logic-loom/lib/release-migrations.sh"
  if [ -n "$3" ]; then
    printf '%s\n' "$3" > "$d/.logic-loom/config/release-migrations.conf"
  else
    : > "$d/.logic-loom/config/release-migrations.conf"
  fi
}

E1="$TMP/e-predates"
mk_temp_root "$E1" "6.6.2" ""
bash "$RM" check-release --root "$E1" > "$TMP/e1.out" 2>&1
assert "below the v7.0.0 floor: exit 0, 'predates'" \
  "[ $? -eq 0 ] && grep -q predates '$TMP/e1.out'"

E2="$TMP/e-norows"
mk_temp_root "$E2" "9.9.9" ""
bash "$RM" check-release --root "$E2" > "$TMP/e2.out" 2>&1
assert "9.9.9 with zero rows: exit 1, 'declares no migration'" \
  "[ $? -eq 1 ] && grep -q 'declares no migration' '$TMP/e2.out'"

E3="$TMP/e-nonesibling"
mk_temp_root "$E3" "9.9.9" "$(printf 'none | - | none | none | - | - | v9.9.9 | nothing\ncontent | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b')"
echo "x foo" > "$E3/x.md"
bash "$RM" check-release --root "$E3" > "$TMP/e3.out" 2>&1
assert "9.9.9 with a none row plus a sibling row: exit 1, 'contradiction'" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e3.out'"

E4="$TMP/e-nonenolog"
mk_temp_root "$E4" "9.9.9" "none | - | none | none | - | - | v9.9.9 | nothing changed"
bash "$RM" check-release --root "$E4" > "$TMP/e4.out" 2>&1
assert "the none-only row with no CHANGELOG.md: exit 0 (nothing to roll)" "[ $? -eq 0 ]"
assert "…and it says 'changelog: not present' (the sanitized-tree branch)" \
  "grep -q 'changelog: not present' '$TMP/e4.out'"
echo "not a changelog heading" > "$E4/CHANGELOG.md"
bash "$RM" check-release --root "$E4" > "$TMP/e4b.out" 2>&1
assert "the none-only row with a CHANGELOG.md lacking '## [9.9.9]': exit 1, 'roll the CHANGELOG'" \
  "[ $? -eq 1 ] && grep -q 'roll the CHANGELOG' '$TMP/e4b.out'"
echo "## [9.9.9] - 2099-01-01" > "$E4/CHANGELOG.md"
bash "$RM" check-release --root "$E4" > "$TMP/e4c.out" 2>&1
assert "…with the heading present: exit 0" "[ $? -eq 0 ]"

E5="$TMP/e-contentrow"
mk_temp_root "$E5" "9.9.9" "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e5xfix"
echo "x foo" > "$E5/x.md"
mkdir -p "$E5/tests/fixtures/release-migrations"
printf 'has foo (the problem state)\n' > "$E5/tests/fixtures/release-migrations/e5xfix.before"
printf 'no longer has it (fixed)\n' > "$E5/tests/fixtures/release-migrations/e5xfix.after"
echo "## [9.9.9]" > "$E5/CHANGELOG.md"
bash "$RM" check-release --root "$E5" > "$TMP/e5.out" 2>&1
assert "a content row + CHANGELOG heading with no ### Migrat subsection: exit 1" "[ $? -eq 1 ]"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E5/CHANGELOG.md"
bash "$RM" check-release --root "$E5" > "$TMP/e5b.out" 2>&1
assert "…with the ### Migrating subsection present: exit 0" "[ $? -eq 0 ]"

echo ""
echo "E. finding 7: check-release EXECUTES every content row of the release it checks"

E8="$TMP/e-execute-noproof"
mk_temp_root "$E8" "9.9.9" "content | y.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b"
echo "y foo" > "$E8/y.md"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E8/CHANGELOG.md"
bash "$RM" check-release --root "$E8" > "$TMP/e8.out" 2>&1
assert "a content row with NO fixture: and NO git history at all: fails closed with a precise message" \
  "[ $? -eq 1 ] && grep -q 'content row y.md@v9.9.9: cannot verify' '$TMP/e8.out'"
assert "…and it ALSO reports the current shipped copy still shows the un-fixed state (both proofs run)" \
  "grep -q 'content row y.md@v9.9.9: current tree.*still exhibits the pattern' '$TMP/e8.out'"

E9="$TMP/e-execute-fixture-ok"
mk_temp_root "$E9" "9.9.9" "content | z.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9zfix"
mkdir -p "$E9/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9/tests/fixtures/release-migrations/e9zfix.before"
printf 'fixed, no longer has it\n' > "$E9/tests/fixtures/release-migrations/e9zfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9/CHANGELOG.md"
bash "$RM" check-release --root "$E9" > "$TMP/e9.out" 2>&1
assert "a content row with a well-formed fixture: pair passes execution (exit 0)" "[ $? -eq 0 ]"
assert "…including the finding-5 scan-path proof (no 'fixture proof' failure line for it — TEMPLATE and ADOPTED both silent)" \
  "! grep -q 'fixture proof' '$TMP/e9.out'"

echo ""
echo "E. finding 5: check-release's fixture proof runs the REAL scan discovery path"
echo "   (emit_content_item), not just the pattern regex, for TEMPLATE and ADOPTED"

E9C="$TMP/e-execute-fixture-nested"
mk_temp_root "$E9C" "9.9.9" "content | docs/nested/dir/setting.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9cfix"
mkdir -p "$E9C/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9C/tests/fixtures/release-migrations/e9cfix.before"
printf 'fixed, no longer has it\n' > "$E9C/tests/fixtures/release-migrations/e9cfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9C/CHANGELOG.md"
bash "$RM" check-release --root "$E9C" > "$TMP/e9c.out" 2>&1
assert "a fixture-backed row at a NESTED path: the scan-path proof builds the tree correctly and passes in both modes (exit 0, no fixture-proof failure)" \
  "[ $? -eq 0 ] && ! grep -q 'fixture proof' '$TMP/e9c.out'"

E9D="$TMP/e-execute-fixture-absent-fate"
mk_temp_root "$E9D" "9.9.9" "content | marker.md | absent | pattern:fixed-marker | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9dfix"
mkdir -p "$E9D/tests/fixtures/release-migrations"
printf 'no marker here — the problem state\n' > "$E9D/tests/fixtures/release-migrations/e9dfix.before"
printf 'fixed-marker now present\n' > "$E9D/tests/fixtures/release-migrations/e9dfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9D/CHANGELOG.md"
bash "$RM" check-release --root "$E9D" > "$TMP/e9d.out" 2>&1
assert "a fate=absent fixture-backed row: the scan-path proof exercises the OTHER emit branch and passes in both modes" \
  "[ $? -eq 0 ] && ! grep -q 'fixture proof' '$TMP/e9d.out'"

# The fail-then-pass proof for finding 5 itself (the two cases above are
# positive controls and pass with or without the scan-path proof): a .before
# fixture the pattern-level check ACCEPTS but scan's real discovery would
# NEVER fire on. A NUL byte does it — `$(cat fixture)` drops NULs (a bash
# variable cannot hold one), so the pattern helper sees plain text and
# matches, while emit_content_item greps the file on disk with -I, which
# classifies it as binary and finds nothing. Before this proof existed such
# a row passed check-release and shipped a migration that could never fire.
E9E="$TMP/e-execute-fixture-binary"
mk_temp_root "$E9E" "9.9.9" "content | w.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9efix"
mkdir -p "$E9E/tests/fixtures/release-migrations"
printf 'has foo\000but a NUL byte makes grep -I call it binary\n' > "$E9E/tests/fixtures/release-migrations/e9efix.before"
printf 'fixed, no longer has it\n' > "$E9E/tests/fixtures/release-migrations/e9efix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9E/CHANGELOG.md"
bash "$RM" check-release --root "$E9E" > "$TMP/e9e.out" 2>&1
assert "a .before fixture scan can never fire on (NUL byte -> grep -I binary) passes the pattern-level check but FAILS the scan-path proof: exit 1, naming both modes and the path" \
  "[ $? -eq 1 ] && grep -q 'fixture proof (TEMPLATE, scan path): the .before fixture at w.md does NOT produce a scan item' '$TMP/e9e.out' && grep -q 'fixture proof (ADOPTED, scan path): the .before fixture at w.md does NOT produce a scan item' '$TMP/e9e.out'"

# A proof that cannot run is a failure, not a silent pass: a content-row name
# spelled as a directory (docs/) is one scan's content_matches can never
# match, so the fixture cannot be placed at it — check-release must say so
# and fail rather than exit 0 with the row "declared".
E9F="$TMP/e-execute-fixture-unplaceable"
mk_temp_root "$E9F" "9.9.9" "content | docs/ | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9ffix"
mkdir -p "$E9F/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9F/tests/fixtures/release-migrations/e9ffix.before"
printf 'fixed\n' > "$E9F/tests/fixtures/release-migrations/e9ffix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9F/CHANGELOG.md"
bash "$RM" check-release --root "$E9F" > "$TMP/e9f.out" 2>&1
assert "a row whose name (docs/) content_matches can never match: the scan-path proof cannot place the fixture and FAILS loudly (exit 1) instead of passing vacuously" \
  "[ $? -eq 1 ] && grep -q 'cannot place the fixture at docs/' '$TMP/e9f.out' && ! grep -q 'declares 1 migration row' '$TMP/e9f.out'"

E10="$TMP/e-execute-fixture-broken-before"
mk_temp_root "$E10" "9.9.9" "content | w.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e10wfix"
mkdir -p "$E10/tests/fixtures/release-migrations"
printf 'does not have the target text at all\n' > "$E10/tests/fixtures/release-migrations/e10wfix.before"
printf 'fixed\n' > "$E10/tests/fixtures/release-migrations/e10wfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E10/CHANGELOG.md"
bash "$RM" check-release --root "$E10" > "$TMP/e10.out" 2>&1
assert "a fixture .before that does NOT reproduce the claimed problem state: fails closed, names the row" \
  "[ $? -eq 1 ] && grep -q 'content row w.md@v9.9.9: pattern does not reproduce the claimed prior state' '$TMP/e10.out'"

E11="$TMP/e-execute-fixture-broken-after"
mk_temp_root "$E11" "9.9.9" "content | v.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e11vfix"
mkdir -p "$E11/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E11/tests/fixtures/release-migrations/e11vfix.before"
printf 'still has foo — not actually fixed\n' > "$E11/tests/fixtures/release-migrations/e11vfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E11/CHANGELOG.md"
bash "$RM" check-release --root "$E11" > "$TMP/e11.out" 2>&1
assert "a fixture .after that still exhibits the pre-fix pattern: fails closed, names the row" \
  "[ $? -eq 1 ] && grep -q 'content row v.md@v9.9.9: its own fixture e11vfix.after still exhibits the pre-fix pattern' '$TMP/e11.out'"

E12="$TMP/e-execute-history"
mkdir -p "$E12/.logic-loom/config" "$E12/.logic-loom/lib"
git init -q "$E12"
echo "FRAMEWORK_VERSION=9.0.1" > "$E12/.logic-loom/config/architecture.conf"
cp "$LIB" "$E12/.logic-loom/lib/release-migrations.sh"
: > "$E12/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E12/u.md"
( cd "$E12" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E12" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E12/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E12/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E12/CHANGELOG.md"
( cd "$E12" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
bash "$RM" check-release --since auto --root "$E12" > "$TMP/e12.out" 2>&1
assert "a content row with NO fixture:, proven purely from git history (prev tag + current tree): exit 0" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e12.out'"
rm -f "$E12/u.md"
bash "$RM" check-release --since auto --root "$E12" > "$TMP/e12b.out" 2>&1
assert "…and once the current shipped copy is deleted entirely, the after-proof is explicitly skipped (not a failure)" \
  "[ $? -eq 0 ] && grep -q 'content row u.md@v9.0.1: (no shipped current copy' '$TMP/e12b.out'"

E13="$TMP/e-execute-glob"
mkdir -p "$E13/.logic-loom/config" "$E13/.logic-loom/lib" "$E13/docs"
git init -q "$E13"
cp "$LIB" "$E13/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E13/.logic-loom/config/architecture.conf"
echo "old text foo here" > "$E13/docs/a.md"
: > "$E13/.logic-loom/config/release-migrations.conf"
( cd "$E13" && git add -A >/dev/null && git commit -q -m "commit 1: pre-fix" )
git -C "$E13" update-ref refs/tags/v9.0.0 HEAD
echo 'content | docs/*.md | present | pattern:foo | PROPOSE | - | v9.0.1 | proposal: a; why: b' > "$E13/.logic-loom/config/release-migrations.conf"
echo "fixed text, no marker" > "$E13/docs/a.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E13/CHANGELOG.md"
( cd "$E13" && git add -A >/dev/null && git commit -q -m "commit 2: registry row (glob) + a.md fixed" )
bash "$RM" check-release --since auto --root "$E13" > "$TMP/e13.out" 2>&1
assert "a GLOB content row (docs/*.md), proven via git ls-tree at the prev tag + the current tree: exit 0" "[ $? -eq 0 ]"
echo "still has foo, not fixed" > "$E13/docs/a.md"
bash "$RM" check-release --since auto --root "$E13" > "$TMP/e13b.out" 2>&1
assert "…and once the glob's current copy regresses to the un-fixed state: fails closed, names the matched file" \
  "[ $? -eq 1 ] && grep -q 'content row docs/\\*.md@v9.0.1: current tree.*(docs/a.md)' '$TMP/e13b.out'"

# reviewer (finding 7): the before-proof for a GLOB row must be satisfied by
# ANY file at the previous tag, not only the first ls-tree match — a clean
# docs/a.md ahead of the problem-bearing docs/b.md was a false fail-closed.
E14="$TMP/e-execute-glob-anymatch"
mkdir -p "$E14/.logic-loom/config" "$E14/.logic-loom/lib" "$E14/docs"
git init -q "$E14"
cp "$LIB" "$E14/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E14/.logic-loom/config/architecture.conf"
echo "clean, nothing here" > "$E14/docs/a.md"
echo "old text foo here" > "$E14/docs/b.md"
: > "$E14/.logic-loom/config/release-migrations.conf"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 1: a.md clean, b.md pre-fix" )
git -C "$E14" update-ref refs/tags/v9.0.0 HEAD
echo 'content | docs/*.md | present | pattern:foo | PROPOSE | - | v9.0.1 | proposal: a; why: b' > "$E14/.logic-loom/config/release-migrations.conf"
echo "fixed" > "$E14/docs/b.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E14/CHANGELOG.md"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 2: registry row (glob) + b.md fixed" )
bash "$RM" check-release --since auto --root "$E14" > "$TMP/e14.out" 2>&1
assert "a GLOB content row whose FIRST match at the prev tag (docs/a.md) is clean but a LATER one (docs/b.md) has the pattern: grounded, exit 0" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce' '$TMP/e14.out'"
echo "nothing here either" > "$E14/docs/b.md"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 3: b.md never had it" )
git -C "$E14" update-ref refs/tags/v9.0.0 HEAD
bash "$RM" check-release --since auto --root "$E14" > "$TMP/e14b.out" 2>&1
assert "…and when NO file at the prev tag has it, the failure names every file it checked" \
  "[ $? -eq 1 ] && grep -q 'does not reproduce the claimed prior state (checked v9.0.0:docs/a.md, v9.0.0:docs/b.md)' '$TMP/e14b.out'"

echo ""
echo "E. finding 2: content_prev never resolves to the SAME release being checked"

# The release under test (v9.0.1) has ALREADY been tagged — a legitimate
# post-release audit. Two tags exist: v9.0.0 (the true pre-fix state) and
# v9.0.1 (== HEAD, the post-fix state, i.e. the version check-release is
# being asked to verify). loom_latest_tag_at_or_below("9.0.1") would return
# v9.0.1 itself (<=, not <); proving the row's PRIOR state against its own
# POST-fix content fails it closed for no real reason. loom_latest_tag_below
# (strict <) must resolve v9.0.0 instead.
E15="$TMP/e-content-prev-self-tag"
mkdir -p "$E15/.logic-loom/config" "$E15/.logic-loom/lib"
git init -q "$E15"
cp "$LIB" "$E15/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E15/.logic-loom/config/architecture.conf"
: > "$E15/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E15/u.md"
( cd "$E15" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E15" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E15/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E15/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E15/CHANGELOG.md"
( cd "$E15" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
git -C "$E15" update-ref refs/tags/v9.0.1 HEAD
bash "$RM" check-release --root "$E15" > "$TMP/e15.out" 2>&1
assert "the release being checked is ALSO tagged (v9.0.1 == HEAD): content_prev still resolves to the TRUE previous tag (v9.0.0), row proven, exit 0" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e15.out'"

echo ""
echo "E. finding 2: content_prev honors an explicit --since instead of silently recomputing its own"

# Two tags: v8.0.0 (the true pre-fix state) and v9.0.0 (the fix already
# landed there too, coincidentally — a stand-in for "the newest tag below
# the version being checked is NOT the release that actually introduced the
# fix"). --since auto would pick v9.0.0 (nearest-below) and fail the row
# closed (v9.0.0 does not show the problem state); an explicit --since
# v8.0.0 must be honored for content_prev too, not just the removal guard.
E16="$TMP/e-content-prev-explicit-since"
mkdir -p "$E16/.logic-loom/config" "$E16/.logic-loom/lib"
git init -q "$E16"
cp "$LIB" "$E16/.logic-loom/lib/release-migrations.sh"
: > "$E16/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E16/u.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix (the TRUE prior state)" )
git -C "$E16" update-ref refs/tags/v8.0.0 HEAD
echo "fixed-marker now present" > "$E16/u.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 2: u.md already fixed here too (coincidence)" )
git -C "$E16" update-ref refs/tags/v9.0.0 HEAD
echo "FRAMEWORK_VERSION=9.0.1" > "$E16/.logic-loom/config/architecture.conf"
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E16/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E16/CHANGELOG.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 3: registry row for v9.0.1" )
bash "$RM" check-release --since auto --root "$E16" > "$TMP/e16-auto.out" 2>&1
assert "--since auto picks the nearest-below tag (v9.0.0), which does NOT show the problem state: fails closed" \
  "[ $? -eq 1 ] && grep -q 'content row u.md@v9.0.1: pattern does not reproduce the claimed prior state' '$TMP/e16-auto.out'"
bash "$RM" check-release --since v8.0.0 --root "$E16" > "$TMP/e16-explicit.out" 2>&1
assert "…but an EXPLICIT --since v8.0.0 (the release that actually introduced the fix) is honored for content_prev too: exit 0, no false failure" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e16-explicit.out'"

echo ""
echo "E. finding 3: the removal guard's window validation holds for ANY --since ref, or rejects it plainly"

# A non-version --since (a raw commit sha, standing in for a branch name or
# any other non-release ref) must never let the window check (a removed
# item's registry row must date the removal to (prev, version]) silently
# degrade to a (kind,name)-only match — it is rejected outright instead.
E17="$TMP/e-since-nonversion"
mkdir -p "$E17/.logic-loom/config" "$E17/.logic-loom/lib" "$E17/plugins/sdd-foo"
git init -q "$E17"
echo "FRAMEWORK_VERSION=9.0.1" > "$E17/.logic-loom/config/architecture.conf"
cp "$LIB" "$E17/.logic-loom/lib/release-migrations.sh"
: > "$E17/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E17/CHANGELOG.md"
echo "x" > "$E17/plugins/sdd-foo/x.md"
( cd "$E17" && git add -A >/dev/null && git commit -q -m "commit 1: sdd-foo present" )
E17_C1="$(git -C "$E17" rev-parse HEAD)"
rm -rf "$E17/plugins/sdd-foo"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | misdated on purpose — a non-version --since must never let this slide through as (declared)" > "$E17/.logic-loom/config/release-migrations.conf"
( cd "$E17" && git add -A >/dev/null && git commit -q -m "commit 2: sdd-foo removed" )
bash "$RM" check-release --since "$E17_C1" --root "$E17" > "$TMP/e17.out" 2>&1
assert "a non-version --since (a bare commit sha) is rejected with a precise reason, not silently downgraded to a weaker match" \
  "[ $? -eq 1 ] && grep -q 'does not resolve to a vX.Y.Z release tag' '$TMP/e17.out'"
assert "…and the guard body never ran at all (no 'previous release:' / 'removals since' line — rejected before either could print)" \
  "! grep -q 'previous release:' '$TMP/e17.out' && ! grep -q 'removals since' '$TMP/e17.out'"

echo ""
echo "E. finding 3 (round-2 half): --since must resolve as an actual TAG, a branch of the same name is not enough"
# A BRANCH named vX.Y.Z resolves fine via the plain `rev-parse <prev>^{commit}`
# used to test resolvability at all (git's short-name lookup checks
# refs/heads too) and IS version-shaped text -- so, unlike E17's bare-sha
# case above, it would sail past both the "resolves" and "is version-shaped"
# gates. Only a check that requires refs/tags/<prev> specifically (not just
# ANY ref of that name) catches it. Positive control (an actual TAG named
# v9.0.0 is accepted) already exists elsewhere in this file (the "…and
# --since v9.0.0 (strictly below) is accepted" assertion, finding 2/3
# section below) -- this proves the negative half: a same-named BRANCH,
# with NO tag of that name anywhere in the repo, is rejected.
E17B="$TMP/e-since-branch-not-tag"
mkdir -p "$E17B/.logic-loom/config" "$E17B/.logic-loom/lib"
git init -q "$E17B"
echo "FRAMEWORK_VERSION=9.0.1" > "$E17B/.logic-loom/config/architecture.conf"
cp "$LIB" "$E17B/.logic-loom/lib/release-migrations.sh"
: > "$E17B/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E17B/CHANGELOG.md"
( cd "$E17B" && git add -A >/dev/null && git commit -q -m "commit 1" )
git -C "$E17B" branch v9.0.0 HEAD >/dev/null
assert "fixture sanity: v9.0.0 resolves to a commit (via the branch) but refs/tags/v9.0.0 does NOT exist" \
  "git -C '$E17B' rev-parse -q --verify 'v9.0.0^{commit}' >/dev/null 2>&1 && ! git -C '$E17B' rev-parse -q --verify 'refs/tags/v9.0.0^{commit}' >/dev/null 2>&1"
bash "$RM" check-release --since v9.0.0 --root "$E17B" > "$TMP/e17b.out" 2>&1
assert "a BRANCH named v9.0.0 (version-shaped, resolves, but not a tag) is rejected with the tag-specific reason, not silently accepted" \
  "[ $? -eq 1 ] && grep -q 'looks like a release (vX.Y.Z) but does not name an actual release tag' '$TMP/e17b.out' && grep -q 'refs/tags/v9.0.0 does not exist' '$TMP/e17b.out'"
assert "…and it is NOT rejected via the non-version-ref reason (E17's case) — this is the round-2 tag-specific gate, a different reason" \
  "! grep -q 'does not resolve to a vX.Y.Z release tag' '$TMP/e17b.out'"
assert "…and the guard body never ran at all here either" \
  "! grep -q 'previous release:' '$TMP/e17b.out' && ! grep -q 'removals since' '$TMP/e17b.out'"

# The remaining way version-shaped --since text could slide past the guard:
# a name that resolves to NOTHING at all (a typo, a tag never fetched). Only
# `--since auto` may honestly find no previous release (E7 below pins that
# skip for a repo with no tags); an EXPLICIT --since that resolves to nothing
# is bad input and must be REJECTED (exit 1) — not printed as "removal guard
# skipped" with exit 0, which reads as a pass for a guard that never ran.
bash "$RM" check-release --since v0.0.1 --root "$E17B" > "$TMP/e17c.out" 2>&1
assert "an EXPLICIT --since naming a ref that does not exist at all (v0.0.1) is rejected (exit 1) with a precise reason — never silently 'removal guard skipped' with exit 0" \
  "[ $? -eq 1 ] && grep -q \"since 'v0.0.1' does not resolve to any commit\" '$TMP/e17c.out' && ! grep -q 'removal guard skipped' '$TMP/e17c.out'"

echo ""
echo "E. finding 2/3: an explicit --since AT or ABOVE the release being checked is rejected"
echo "   (it would prove every content row against its own post-fix content — finding 2, by hand)"
# Three tags: v9.0.0 (the true prior state), and v9.0.1 + v9.5.0 both at the
# post-fix HEAD. --since v9.0.1 (the release under check) and --since v9.5.0
# (after it) must each be refused with a precise reason — not accepted and
# then surfaced as a misleading "pattern does not reproduce the claimed prior
# state" — while --since v9.0.0 is accepted and the row proven.
E18="$TMP/e-since-not-below"
mkdir -p "$E18/.logic-loom/config" "$E18/.logic-loom/lib"
git init -q "$E18"
cp "$LIB" "$E18/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E18/.logic-loom/config/architecture.conf"
: > "$E18/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E18/u.md"
( cd "$E18" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E18" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E18/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E18/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E18/CHANGELOG.md"
( cd "$E18" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
git -C "$E18" update-ref refs/tags/v9.0.1 HEAD
git -C "$E18" update-ref refs/tags/v9.5.0 HEAD
for since_bad in v9.0.1 v9.5.0; do
  bash "$RM" check-release --since "$since_bad" --root "$E18" > "$TMP/e18-$since_bad.out" 2>&1
  assert "--since $since_bad while checking v9.0.1: rejected with a precise reason (exit 1), the guard body never runs, and NO false 'does not reproduce the claimed prior state' line" \
    "[ $? -eq 1 ] && grep -q \"since '$since_bad' is not BELOW the release being checked (v9.0.1)\" '$TMP/e18-$since_bad.out' && ! grep -q 'previous release:' '$TMP/e18-$since_bad.out' && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e18-$since_bad.out'"
done
bash "$RM" check-release --since v9.0.0 --root "$E18" > "$TMP/e18-ok.out" 2>&1
assert "…and --since v9.0.0 (strictly below) is accepted: exit 0, guard ran against v9.0.0, row proven" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e18-ok.out' && ! grep -q 'does not reproduce' '$TMP/e18-ok.out'"

echo ""
echo "E. removal guard — throwaway repo (git tags, real removal)"

E6="$TMP/e-removal"
mkdir -p "$E6/.logic-loom/config" "$E6/.logic-loom/lib" "$E6/plugins/sdd-foo"
git init -q "$E6"
echo "FRAMEWORK_VERSION=9.0.1" > "$E6/.logic-loom/config/architecture.conf"
cp "$LIB" "$E6/.logic-loom/lib/release-migrations.sh"
: > "$E6/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E6/CHANGELOG.md"
echo "x" > "$E6/plugins/sdd-foo/x.md"
( cd "$E6" && git add -A >/dev/null && git commit -q -m "commit 1: sdd-foo present" )
E6_C1="$(git -C "$E6" rev-parse HEAD)"
git -C "$E6" update-ref refs/tags/v9.0.0 "$E6_C1"
rm -rf "$E6/plugins/sdd-foo"
( cd "$E6" && git add -A >/dev/null && git commit -q -m "commit 2: sdd-foo removed" )

bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6.out" 2>&1
assert "an undeclared removal since v9.0.0 fails the guard" \
  "[ $? -eq 1 ] && grep -q 'removed since v9.0.0 without a registry row: plugins/sdd-foo' '$TMP/e6.out'"

echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6b.out" 2>&1
assert "with the registry row added: exit 0, names 'previous release: v9.0.0'" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e6b.out'"
assert "…and the declared removal + structure line" \
  "grep -q 'removals since v9.0.0: plugins/sdd-foo (declared)' '$TMP/e6b.out' && grep -q 'structure verified' '$TMP/e6b.out'"

echo "none | - | none | none | - | - | v9.0.1 | nothing" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6c.out" 2>&1
assert "a none row for v9.0.1 while sdd-foo was removed since v9.0.0: exit 1, contradiction" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e6c.out'"

echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since v9.0.0 --root "$E6" > "$TMP/e6d.out" 2>&1
assert "explicit --since v9.0.0 behaves the same as --since auto" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e6d.out'"

# finding 5b (reviewer: reproduced as REAL, then fixed): the guard matched a
# row on (kind, name) alone. Registry lint's one-row-per-name rule does not
# help here — the ONE row can simply carry the wrong release. An item present
# at the previous tag and gone now was removed in (prev, version]; a row dated
# outside that window (a FUTURE pre-declaration, or a STALE row claiming an
# earlier release already lacked it) does not declare THIS release's removal.
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | pre-declared for a future release" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6e.out" 2>&1
assert "5b: the only row for sdd-foo is dated v9.9.0 (future) while it was removed in v9.0.1: exit 1, names the window and the row's release" \
  "[ $? -eq 1 ] && grep -q 'removed since v9.0.0 but its registry row dates the removal outside (v9.0.0, v9.0.1]: plugins/sdd-foo (row says v9.9.0)' '$TMP/e6e.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v8.0.0 | v8.5.0 | stale: claims v8.5.0 lacked it, but v9.0.0 still had it" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6f.out" 2>&1
assert "5b: …dated v8.5.0 (stale, not after the v9.0.0 tree that still had it): exit 1, same precise message" \
  "[ $? -eq 1 ] && grep -q 'plugins/sdd-foo (row says v8.5.0)' '$TMP/e6f.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6g.out" 2>&1
assert "5b: …and the correctly dated v9.0.1 row still passes (window is (prev, version], inclusive of version)" \
  "[ $? -eq 0 ] && grep -q 'removals since v9.0.0: plugins/sdd-foo (declared)' '$TMP/e6g.out'"
echo "none | - | none | none | - | - | v9.0.1 | nothing" > "$E6/.logic-loom/config/release-migrations.conf"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | future" >> "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6h.out" 2>&1
assert "5b: a misdated row still counts as a removal against a v9.0.1 none row (contradiction reported, exit 1)" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e6h.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"

E7="$TMP/e-notags"
mkdir -p "$E7/.logic-loom/config" "$E7/.logic-loom/lib"
git init -q "$E7"
echo "FRAMEWORK_VERSION=9.0.1" > "$E7/.logic-loom/config/architecture.conf"
cp "$LIB" "$E7/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E7/.logic-loom/config/release-migrations.conf"
( cd "$E7" && git add -A >/dev/null && git commit -q -m init )
bash "$RM" check-release --since auto --root "$E7" > "$TMP/e7.out" 2>&1
assert "a repo with no tags: 'removal guard skipped', exit unaffected by the guard itself" \
  "grep -q 'removal guard skipped' '$TMP/e7.out'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION F — command/SKILL prose pins (§15.2-E)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "F. command/SKILL prose pins"
echo "   (a prose pin proves the instruction is present in the right step, not that it is obeyed)"

for f in "$CMD_MD" "$SKILL_MD"; do
  base="$(basename "$f")"
  assert "$base: cites 'release-migrations.sh scan' verbatim" \
    "grep -qF 'bash plugins/loom-maintenance/scripts/release-migrations.sh scan' '$f'"
  assert "$base: cites 'record-update-writes.sh --version'" \
    "grep -qF 'record-update-writes.sh --version' '$f'"
  assert "$base: cites 'record-update-writes.sh --reconcile'" \
    "grep -qF 'record-update-writes.sh --reconcile' '$f'"
  assert "$base: cites 'Decisions in force'" \
    "grep -qF 'Decisions in force' '$f'"
  assert "$base: states 'a decision suppresses a proposal, never the fact'" \
    "grep -qF 'a decision suppresses a proposal, never the fact' '$f'"
  assert "$base: cites the '[m]ove' menu entry" \
    "grep -qF '[m]ove' '$f'"
done

CMD_STEP5_LINE="$(grep -n '^### Step 5' "$CMD_MD" | head -1 | cut -d: -f1)"
CMD_RECORDER_LINE="$(grep -n 'record-update-writes.sh --version' "$CMD_MD" | head -1 | cut -d: -f1)"
CMD_STEP6_LINE="$(grep -n '^### Step 6' "$CMD_MD" | head -1 | cut -d: -f1)"
assert "command: '### Step 5' < recorder line < '### Step 6'" \
  "[ -n '$CMD_STEP5_LINE' ] && [ -n '$CMD_RECORDER_LINE' ] && [ -n '$CMD_STEP6_LINE' ] \
   && [ '$CMD_STEP5_LINE' -lt '$CMD_RECORDER_LINE' ] && [ '$CMD_RECORDER_LINE' -lt '$CMD_STEP6_LINE' ]"

SKILL_STEP7_LINE="$(grep -n '^### Step 7:' "$SKILL_MD" | head -1 | cut -d: -f1)"
SKILL_RECORDER_LINE="$(grep -n 'record-update-writes.sh --version' "$SKILL_MD" | head -1 | cut -d: -f1)"
SKILL_STEP8_LINE="$(grep -n '^### Step 8:' "$SKILL_MD" | head -1 | cut -d: -f1)"
assert "SKILL: '### Step 7' < recorder line < '### Step 8'" \
  "[ -n '$SKILL_STEP7_LINE' ] && [ -n '$SKILL_RECORDER_LINE' ] && [ -n '$SKILL_STEP8_LINE' ] \
   && [ '$SKILL_STEP7_LINE' -lt '$SKILL_RECORDER_LINE' ] && [ '$SKILL_RECORDER_LINE' -lt '$SKILL_STEP8_LINE' ]"

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
