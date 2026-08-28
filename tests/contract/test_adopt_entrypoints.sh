#!/usr/bin/env bash
# Contract Tests: the adopt ENTRY POINTS and the post-install path (PRE-13)
#
# Two things this pins, and they are the same failure in two places: a documented
# command that does not work.
#
#   1. THE THREE WAYS IN. README.md:18 used to say `git clone <your-repo-url>
#      logic-loom` and nothing else. That instruction assumes an empty directory
#      and is wrong for two of the three situations a reader is now in (new
#      project via `logicloom init`, existing repository via `logicloom init`,
#      template clone via git). Both customer entry points must carry all three.
#
#   2. THE UNPUBLISHED CAVEAT. The package is `private: true` and has never been
#      published, so `npx logicloom` resolves for nobody. Documenting it without
#      saying so hands every reader a command that fails. Both entry points must
#      say it, and this suite fails the day the caveat is removed while the
#      package is still private — and fails the OTHER way once it is published
#      and the caveat is stale.
#
#   3. PRE-13 — /initialize-project must know it is post-ADOPT, not post-clone.
#      "Do not point adopters at it" was never a control: the payload ships
#      plugins/ and .claude/commands/, so the command is in an adopter's palette
#      regardless. The command file and the skill must both detect the adopt
#      receipt, and both must SKIP their maintainer-CI removal step when adopted
#      — that step's `rm -f .github/workflows/*.yml` would delete the adopter's
#      own CI, since the payload excludes .github/ wholesale.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); desc="$1"; condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

README="$ROOT/README.md"
START="$ROOT/START_HERE.md"
PKG_JSON="$ROOT/packaging/adopt/package.json"
INIT_CMD="$ROOT/plugins/loom-maintenance/commands/initialize-project.md"
INIT_SKILL="$ROOT/plugins/loom-maintenance/skills/project-initialization/SKILL.md"
MANIFEST="$ROOT/packaging/adopt/payload-manifest.txt"

echo "🧪 Adopt Entry Points + Post-Install Contract Tests"
echo "=================================================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# Same shape and reason as the other adopt suites: `packaging` is a
# template-strip-manifest entry, so packaging/adopt/package.json does not exist
# in a shipped tree. The docs assertions still run there — README.md and
# START_HERE.md DO ship — but the package-state assertions cannot.
PKG_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$PKG_JSON" >/dev/null 2>&1; then PKG_TRACKED=yes; fi

echo "── 1. The three ways in ──"
for f in "$README" "$START"; do
  assert "entry point exists: ${f#$ROOT/}" "[ -f '$f' ]"
done

# Each entry point must name all three, not just mention `logicloom init` once.
for f in "$README" "$START"; do
  n="${f#$ROOT/}"
  assert "$n offers \`logicloom init\`" "grep -q 'logicloom init' '$f'"
  assert "$n still documents the template clone (git clone)" "grep -q 'git clone' '$f'"
  assert "$n names the EXISTING-repository case" \
    "grep -qiE 'existing (repositor|project)' '$f'"
  assert "$n names the NEW/empty-directory case" \
    "grep -qiE 'empty directory|new project' '$f'"
done

# The old text was the ONLY documented way in, and it assumed an empty dir.
assert "README no longer presents \`git clone <your-repo-url>\` as the only way in" \
  "grep -qiE 'three ways in' '$README'"
echo ""

echo "── 2. The unpublished caveat (an instruction that fails is worse than none) ──"
if [ "$PKG_TRACKED" = yes ] && [ -f "$PKG_JSON" ]; then
  IS_PRIVATE=no
  grep -q '"private"[[:space:]]*:[[:space:]]*true' "$PKG_JSON" && IS_PRIVATE=yes
  assert "the adopt package state is readable (private=$IS_PRIVATE)" "[ -n '$IS_PRIVATE' ]"
  if [ "$IS_PRIVATE" = yes ]; then
    for f in "$README" "$START"; do
      n="${f#$ROOT/}"
      assert "$n says plainly that \`npx logicloom\` does not resolve yet" \
        "grep -qiE 'npx logicloom.{0,40}does not resolve|does not resolve.{0,40}npx logicloom' '$f'"
      assert "$n gives a form that DOES work today (running out of a checkout)" \
        "grep -q 'packaging/adopt' '$f'"
    done
    # The packed-tarball route is the plausible-looking one that silently
    # produces an empty payload, because payload assembly is release-time work
    # that is not built. Naming it is the difference between a reader losing ten
    # minutes and a reader concluding the tool is broken.
    assert "README warns that npm pack / a tarball install has no payload yet" \
      "grep -qi 'npm pack' '$README'"
    assert "START_HERE warns the same" \
      "grep -qi 'tarball' '$START'"
  else
    # Published. The caveat is now FALSE and must be gone — a stale "this is not
    # published" is the same defect pointing the other way.
    for f in "$README" "$START"; do
      n="${f#$ROOT/}"
      assert "$n no longer claims the package is unpublished (it is not private any more)" \
        "! grep -qi 'does not resolve' '$f'"
    done
  fi
else
  echo "  ⏭  SKIP: packaging/adopt/package.json absent and untracked (stripped tree)"
fi
echo ""

echo "── 3. PRE-13: /initialize-project knows it is post-adopt ──"
for f in "$INIT_CMD" "$INIT_SKILL"; do
  n="${f#$ROOT/}"
  assert "$n exists" "[ -f '$f' ]"
  assert "$n detects the install kind from the adopt receipt" \
    "grep -q 'logicloom-adopt-receipt.json' '$f'"
  assert "$n names the receipt SCHEMA, not just the filename (a foreign file is not a receipt)" \
    "grep -q 'logicloom/adopt-receipt@1' '$f'"
  assert "$n distinguishes TEMPLATE CLONE from ADOPTED by name" \
    "grep -q 'TEMPLATE CLONE' '$f' && grep -q 'ADOPTED' '$f'"
  assert "$n SKIPS the maintainer-CI removal when adopted" \
    "grep -qiE 'skip (this step )?entirely' '$f'"
  assert "$n says WHY: .github/ is excluded from the payload, so that CI is the adopter's" \
    "grep -q 'excludes \`.github/\`' '$f' || grep -q 'payload excludes' '$f'"
  assert "$n protects the adopter's own CLAUDE.md from the framework-documents step" \
    "grep -qi 'CLAUDE.md. is ..theirs' '$f'"
done

# The coupling the skip rests on. `packaging` is a template-strip-manifest entry,
# so the manifest is absent on a shipped tree and these three cannot run there —
# same guard as section 2. The assertions above (the command + skill files) DO
# ship and keep running, which is the half a customer tree can actually check.
if [ -f "$MANIFEST" ]; then
  # The skip is only SAFE because the payload really does exclude .github/. If
  # that row is ever relaxed, the skip becomes a hole and this goes red first.
  assert "the payload manifest still excludes .github wholesale (what makes the skip safe)" \
    "grep -qE '^exclude:[[:space:]]+\\.github[[:space:]]*\$' '$MANIFEST'"
  # And the reason the whole of PRE-13 exists: the command DOES reach an adopter.
  assert "the payload ships plugins/ (so /initialize-project reaches an adopter)" \
    "grep -qE '^include:[[:space:]]+plugins[[:space:]]*\$' '$MANIFEST'"
  assert "the payload ships .claude/commands/ (the slash-command bridge)" \
    "grep -qE '^include:[[:space:]]+\\.claude/commands[[:space:]]*\$' '$MANIFEST'"
elif [ "$PKG_TRACKED" = yes ]; then
  assert "payload manifest is tracked, so it must be on disk" "[ -f '$MANIFEST' ]"
else
  echo "  ⏭  SKIP: payload manifest absent and untracked (stripped tree)"
fi
echo ""

echo "── 4. The uninstall answer lives in the repo, not in our docs ──"
# PRE-14's decision is "a list the human runs". That is only honest if the list
# is IN the adopted repo. Both entry points must point at the receipt for it.
for f in "$README" "$START"; do
  n="${f#$ROOT/}"
  assert "$n points at the receipt for what was installed" \
    "grep -q 'logicloom-adopt-receipt.json' '$f'"
  assert "$n states the uninstall position (a list you run, not a command we ship)" \
    "grep -qiE 'list you run, not a command' '$f'"
  assert "$n gives the REASON, not just the position" \
    "grep -qiE 'delete path|refuses to delete' '$f'"
done

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
