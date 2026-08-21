#!/usr/bin/env bash
# Contract Tests: gh-telemetry detection is DETECT-AND-INFORM, never write
#
# GitHub issue #55 originally proposed that setup write `telemetry: disabled`
# into ~/.config/gh/config.yml AND append `export GH_TELEMETRY=0` to the user's
# ~/.zshrc / ~/.bashrc. That was rejected against the harness↔user boundary
# (LogicLoom writes nothing outside the repository) and for the Principle VI
# irony of a silent, unapproved bootstrap write. This suite pins the replacement
# so the rejected behavior cannot creep back in:
#
#   1. The detector exists, parses, and is registered where setup calls it.
#   2. It NEVER writes outside the repo — proven by running it against a
#      throwaway HOME and diffing that HOME before/after.
#   3. It NEVER shells out to `gh` — proven by putting a booby-trapped `gh` on
#      PATH that drops a canary file if invoked. (`gh config get` can
#      materialize a default config file; that would itself be an outside write.)
#   4. It always exits 0 across gh-present / gh-absent / already-opted-out, so
#      it can never block setup.
#   5. Its status classification is correct in each state.
#   6. No source in this feature writes to a shell rc, and no dead `SDD_*` env
#      name reappears.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

DETECTOR="$ROOT/.logic-loom/scripts/bash/check-gh-telemetry.sh"

# Sandbox: a throwaway HOME plus a shim PATH dir. Nothing here touches the real
# user's home directory.
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t loomgh)"
cleanup() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

FAKE_HOME="$SANDBOX/home"
SHIM_BIN="$SANDBOX/bin"
CANARY="$SANDBOX/gh-was-invoked"
mkdir -p "$FAKE_HOME" "$SHIM_BIN"

# Booby-trapped gh: any invocation leaves a canary and succeeds quietly, so a
# detector that shells out to gh still "works" but is caught.
cat > "$SHIM_BIN/gh" <<'SHIM'
#!/usr/bin/env bash
printf 'invoked: %s\n' "$*" >> "$LOOM_TEST_CANARY"
exit 0
SHIM
chmod +x "$SHIM_BIN/gh"

# Snapshot a directory tree (paths + sizes + mtimes) for before/after diffing.
snapshot() {
  find "$1" -mindepth 0 2>/dev/null | sort | while IFS= read -r p; do
    if [ -f "$p" ]; then
      printf '%s|%s|%s\n' "$p" "$(wc -c < "$p" | tr -d ' ')" "$(ls -ld "$p" | awk '{print $6,$7,$8}')"
    else
      printf '%s|DIR\n' "$p"
    fi
  done
}

# Run the detector in the sandbox. $1 = extra env assignments, $2 = args.
run_detector() {
  env HOME="$FAKE_HOME" \
      XDG_CONFIG_HOME="" \
      GH_CONFIG_DIR="" \
      DO_NOT_TRACK="${T_DO_NOT_TRACK:-}" \
      GH_TELEMETRY="${T_GH_TELEMETRY:-}" \
      LOOM_TEST_CANARY="$CANARY" \
      PATH="${T_PATH:-$SHIM_BIN:/usr/bin:/bin}" \
      bash "$DETECTOR" "$@"
}

echo "═══ gh Telemetry: Detect-and-Inform Contract ═══"
echo ""

# ── 1. The detector exists and parses ────────────────────────────────────────
echo "1. Detector exists and is syntactically valid"
assert "detector present at .logic-loom/scripts/bash/check-gh-telemetry.sh" "[ -f \"\$DETECTOR\" ]"
assert "detector passes bash -n" "bash -n \"\$DETECTOR\" 2>/dev/null"

# ── 2. Wired into the setup surfaces ─────────────────────────────────────────
echo ""
echo "2. Wired into setup, and documented"
assert "init-project.sh invokes the detector" \
  "grep -q 'check-gh-telemetry.sh' \"\$ROOT/init-project.sh\""
assert "init-project.sh guards it with || true (set -e safety)" \
  "grep -A1 'check-gh-telemetry.sh\" || true' \"\$ROOT/init-project.sh\" >/dev/null 2>&1 || grep -q 'check-gh-telemetry.sh\" || true' \"\$ROOT/init-project.sh\""
assert "/initialize-project command references the detector" \
  "grep -q 'check-gh-telemetry.sh' \"\$ROOT/plugins/loom-maintenance/commands/initialize-project.md\""
assert "project-initialization skill references the detector" \
  "grep -q 'check-gh-telemetry.sh' \"\$ROOT/plugins/loom-maintenance/skills/project-initialization/SKILL.md\""
assert "START_HERE.md carries the privacy note" \
  "grep -q 'A note on GitHub CLI telemetry' \"\$ROOT/START_HERE.md\""
assert "START_HERE.md gives the exact user-run opt-out command" \
  "grep -q 'gh config set telemetry disabled' \"\$ROOT/START_HERE.md\""

# ── 3. State (a): gh present, telemetry unset → enabled ──────────────────────
echo ""
echo "3. State (a) — gh present, telemetry unset"
T_PATH=""          # empty ⇒ run_detector falls back to the shim PATH (gh present)
BEFORE_A="$(snapshot "$FAKE_HOME")"
T_DO_NOT_TRACK="" T_GH_TELEMETRY="" OUT_A="$(run_detector 2>&1)"; RC_A=$?
T_DO_NOT_TRACK="" T_GH_TELEMETRY="" ST_A="$(run_detector --status 2>&1)"; RC_AS=$?
AFTER_A="$(snapshot "$FAKE_HOME")"
assert "exits 0"                      "[ $RC_A -eq 0 ] && [ $RC_AS -eq 0 ]"
assert "status is 'enabled'"          "[ \"\$ST_A\" = 'enabled' ]"
assert "notice names the opt-out command" \
  "printf '%s' \"\$OUT_A\" | grep -q 'gh config set telemetry disabled'"
assert "notice states LogicLoom will NOT change it" \
  "printf '%s' \"\$OUT_A\" | grep -qi 'will NOT change'"
assert "sandbox HOME unchanged"       "[ \"\$BEFORE_A\" = \"\$AFTER_A\" ]"

# ── 4. State (b): gh absent → gh-absent, silent ──────────────────────────────
echo ""
echo "4. State (b) — gh absent from PATH"
BEFORE_B="$(snapshot "$FAKE_HOME")"
T_PATH="/usr/bin:/bin" T_DO_NOT_TRACK="" T_GH_TELEMETRY="" OUT_B="$(run_detector 2>&1)"; RC_B=$?
T_PATH="/usr/bin:/bin" T_DO_NOT_TRACK="" T_GH_TELEMETRY="" ST_B="$(run_detector --status 2>&1)"; RC_BS=$?
AFTER_B="$(snapshot "$FAKE_HOME")"
# Guard: only meaningful if gh really is absent from the stripped PATH.
if PATH="/usr/bin:/bin" command -v gh >/dev/null 2>&1; then
  echo "     (skipped: gh is installed under /usr/bin or /bin on this host)"
else
  assert "exits 0 with gh absent"     "[ $RC_B -eq 0 ] && [ $RC_BS -eq 0 ]"
  assert "status is 'gh-absent'"      "[ \"\$ST_B\" = 'gh-absent' ]"
  assert "notice mode stays silent"   "[ -z \"\$OUT_B\" ]"
  assert "sandbox HOME unchanged"     "[ \"\$BEFORE_B\" = \"\$AFTER_B\" ]"
fi

# ── 5. State (c): already opted out ──────────────────────────────────────────
echo ""
echo "5. State (c) — telemetry already opted out"
# Restore the gh-present PATH: assignment-prefix vars persist in the current
# shell, so section 4's stripped PATH would otherwise leak into this section.
T_PATH=""
BEFORE_C="$(snapshot "$FAKE_HOME")"
T_DO_NOT_TRACK="1" T_GH_TELEMETRY="" OUT_C1="$(run_detector 2>&1)"; RC_C1=$?
T_DO_NOT_TRACK="1" T_GH_TELEMETRY="" ST_C1="$(run_detector --status 2>&1)"
T_DO_NOT_TRACK="" T_GH_TELEMETRY="0" OUT_C2="$(run_detector 2>&1)"; RC_C2=$?
T_DO_NOT_TRACK="" T_GH_TELEMETRY="0" ST_C2="$(run_detector --status 2>&1)"
assert "DO_NOT_TRACK=1 → exit 0"      "[ $RC_C1 -eq 0 ]"
assert "DO_NOT_TRACK=1 → opted-out-env" "[ \"\$ST_C1\" = 'opted-out-env' ]"
assert "DO_NOT_TRACK=1 → notice silent" "[ -z \"\$OUT_C1\" ]"
assert "GH_TELEMETRY=0 → exit 0"      "[ $RC_C2 -eq 0 ]"
assert "GH_TELEMETRY=0 → opted-out-env" "[ \"\$ST_C2\" = 'opted-out-env' ]"
assert "GH_TELEMETRY=0 → notice silent" "[ -z \"\$OUT_C2\" ]"

# config-file opt-out (the user having run `gh config set telemetry disabled`)
mkdir -p "$FAKE_HOME/.config/gh"
printf 'version: "1"\ntelemetry: disabled\n' > "$FAKE_HOME/.config/gh/config.yml"
T_DO_NOT_TRACK="" T_GH_TELEMETRY="" ST_C3="$(run_detector --status 2>&1)"; RC_C3=$?
T_DO_NOT_TRACK="" T_GH_TELEMETRY="" OUT_C3="$(run_detector 2>&1)"
assert "config 'telemetry: disabled' → exit 0" "[ $RC_C3 -eq 0 ]"
assert "config 'telemetry: disabled' → opted-out-config" "[ \"\$ST_C3\" = 'opted-out-config' ]"
assert "config opt-out → notice silent" "[ -z \"\$OUT_C3\" ]"
AFTER_C="$(snapshot "$FAKE_HOME")"
assert "only the test's own config write changed the sandbox" \
  "[ \"\$BEFORE_C\" != \"\$AFTER_C\" ]"

# unreadable config must degrade, not error
UNREADABLE="$FAKE_HOME/.config/gh/config.yml"
chmod 000 "$UNREADABLE" 2>/dev/null || true
if [ -r "$UNREADABLE" ]; then
  echo "     (skipped unreadable-config case: running as a user that bypasses mode 000)"
else
  T_DO_NOT_TRACK="" T_GH_TELEMETRY="" ST_C4="$(run_detector --status 2>&1)"; RC_C4=$?
  assert "unreadable config → still exit 0" "[ $RC_C4 -eq 0 ]"
  assert "unreadable config → falls back to 'enabled', not an error" "[ \"\$ST_C4\" = 'enabled' ]"
fi
chmod 644 "$UNREADABLE" 2>/dev/null || true

# ── 6. It never shells out to gh ─────────────────────────────────────────────
echo ""
echo "6. The detector never invokes a gh subcommand"
assert "booby-trapped gh on PATH was never invoked across every run above" \
  "[ ! -f \"\$CANARY\" ]"

# ── 7. Rejected mechanisms stay rejected ─────────────────────────────────────
echo ""
echo "7. The rejected issue-#55 mechanisms are absent"
FEATURE_FILES="$DETECTOR $ROOT/init-project.sh $ROOT/plugins/loom-maintenance/commands/initialize-project.md $ROOT/plugins/loom-maintenance/skills/project-initialization/SKILL.md"
# A redirect INTO a shell rc — the thing the issue asked for. Matches `>> ~/.zshrc`
# and friends; the word "~/.zshrc" appearing in prose (as a "we do not do this"
# statement) is fine and deliberate.
assert "no redirect into a shell rc anywhere in this feature" \
  "! grep -nE '>>?[[:space:]]*(\"?[~\$]\{?HOME\}?\"?/)?\.(zshrc|bashrc|bash_profile|profile)' \$FEATURE_FILES >/dev/null 2>&1"
assert "detector never runs 'gh config set'" \
  "! grep -nE '^[[:space:]]*(gh|\"?\\\$\\{?GH[A-Z_]*\\}?\"?)[[:space:]]+config[[:space:]]+set' \"\$DETECTOR\" >/dev/null 2>&1"
assert "no dead SDD_ env name reintroduced" \
  "! grep -n 'SDD_[A-Z_]*' \$FEATURE_FILES >/dev/null 2>&1"
assert "detector documents that it always exits 0" \
  "grep -qi 'ALWAYS exits 0' \"\$DETECTOR\""

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
