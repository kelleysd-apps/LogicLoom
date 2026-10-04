#!/bin/sh
# Cases for plugins/loom-maintenance/scripts/json-valid.sh and json-flat.sh.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

scripts="$UL_T_ROOT/plugins/loom-maintenance/scripts"
jv="$scripts/json-valid.sh"
jf="$scripts/json-flat.sh"
fix="$UL_T_FIX/world"
tmp=$(ul_t_tmp)

valid() { "$SH" "$jv" "$1" >/dev/null 2>&1; }
invalid_with_reason() { # file: exit 1 and last line reason=
  _o=$("$SH" "$jv" "$1" 2>&1); _rc=$?
  [ "$_rc" -eq 1 ] || return 1
  printf '%s\n' "$_o" | tail -1 | grep '^reason=.' >/dev/null
}
flat() { "$SH" "$jf" "$1" 2>/dev/null; }

# ----------------------------------------------------------- json-valid: yes
ul_t_check "json-valid: tools exist" test -f "$jv" -a -f "$jf"
ul_t_check "json-valid accepts fixture base settings" valid "$fix/base/.claude/settings.json"
ul_t_check "json-valid accepts fixture head settings" valid "$fix/head/.claude/settings.json"
ul_t_check "json-valid accepts fixture customer settings" valid "$fix/customer/.claude/settings.json"
ul_t_check "json-valid accepts fixture tool-restrictions (one-line file)" valid "$fix/base/.claude/policies/tool-restrictions.json"

# Compact one-line version: strip whitespace outside strings.
awk '
{ sub(/\r$/, ""); buf = buf $0 "\n" }
END {
  n = length(buf); out = ""; instr = 0; esc = 0
  for (i = 1; i <= n; i++) {
    c = substr(buf, i, 1)
    if (instr) {
      out = out c
      if (esc) esc = 0
      else if (c == "\\") esc = 1
      else if (c == "\"") instr = 0
      continue
    }
    if (c == "\"") { instr = 1; out = out c; continue }
    if (c == " " || c == "\t" || c == "\n" || c == "\r") continue
    out = out c
  }
  printf "%s", out
}' "$fix/customer/.claude/settings.json" > "$tmp/compact.json"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$fix/customer/.claude/settings.json" > "$tmp/crlf.json"
{ printf '\357\273\277'; cat "$fix/customer/.claude/settings.json"; } > "$tmp/bom.json"

ul_t_check "json-valid accepts a compact one-line file" valid "$tmp/compact.json"
ul_t_check "json-valid accepts a CRLF file" valid "$tmp/crlf.json"
ul_t_check "json-valid accepts a file with a UTF-8 BOM" valid "$tmp/bom.json"

# ------------------------------------------------------------ json-valid: no
printf '{"a": 1,}\n' > "$tmp/trailing-comma.json"
printf '{"a": "unterminated}\n' > "$tmp/unterminated.json"
printf '{"a": 1} garbage\n' > "$tmp/garbage.json"
printf '[1, 2,]\n' > "$tmp/array-comma.json"
: > "$tmp/empty.json"
ul_t_check "json-valid rejects a trailing comma with a reason= last line" invalid_with_reason "$tmp/trailing-comma.json"
ul_t_check "json-valid rejects an unterminated string with a reason= last line" invalid_with_reason "$tmp/unterminated.json"
ul_t_check "json-valid rejects trailing garbage with a reason= last line" invalid_with_reason "$tmp/garbage.json"
ul_t_check "json-valid rejects a trailing comma in an array" invalid_with_reason "$tmp/array-comma.json"
ul_t_check "json-valid rejects an empty file" invalid_with_reason "$tmp/empty.json"
out=$("$SH" "$jv" "$tmp/does-not-exist.json" 2>&1); rc=$?
ul_t_check "json-valid: a missing file exits 1 with reason=" test "$rc" = 1 -a "$(printf '%s\n' "$out" | tail -1 | cut -c1-7)" = "reason="
out=$("$SH" "$jv" 2>&1); rc=$?
ul_t_check "json-valid: no argument exits 1 with reason=" test "$rc" = 1 -a "$(printf '%s\n' "$out" | tail -1 | cut -c1-7)" = "reason="

# ------------------------------------------------------------------ json-flat
out=$(flat "$fix/customer/.claude/settings.json")
ul_t_check "json-flat: the adopter hook command is at /hooks/PreToolUse/1/hooks/0/command" \
  ul_t_hasline "$out" "$(printf '/hooks/PreToolUse/1/hooks/0/command\tbash scripts/hooks/guard-prod-db.sh')"
ul_t_check "json-flat: enabledPlugins entry flattens to true" \
  ul_t_hasline "$out" "$(printf '/enabledPlugins/fixture@local\ttrue')"
ul_t_check "json-flat: a deny entry is read by content" \
  ul_t_hasline "$out" "$(printf '/permissions/deny/1\tBash(rm -rf:*)')"
ul_t_check "json-flat: an empty-string leaf is kept" \
  ul_t_hasline "$out" "$(printf '/hooks/SessionStart/0/matcher\t')"
out2=$(flat "$tmp/compact.json")
ul_t_check "json-flat: compact and pretty layouts flatten identically" test "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$out2" | sort)"
out3=$(flat "$tmp/crlf.json")
ul_t_check "json-flat: CRLF layout flattens identically" test "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$out3" | sort)"
out4=$(flat "$tmp/bom.json")
ul_t_check "json-flat: BOM layout flattens identically" test "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$out4" | sort)"

cat > "$tmp/slash-key.json" <<'JSONEOF'
{"a/b": {"c": 1}, "d\\e": 2, "hooks/PreToolUse/0/matcher": "^spoof", "hooks": {"PreToolUse": [{"matcher": "Bash"}]}, "t": true, "f": false, "n": null, "num": -1.5e3}
JSONEOF
out=$(flat "$tmp/slash-key.json")
ul_t_check "json-flat: a / in a key is escaped as \\/" ul_t_hasline "$out" "$(printf '/a\\/b/c\t1')"
ul_t_check "json-flat: a backslash in a key is escaped as a doubled backslash" ul_t_hasline "$out" "$(printf '/d\\\\e\t2')"
ul_t_check "json-flat: a spoofing key stays one escaped path component" \
  ul_t_hasline "$out" "$(printf '/hooks\\/PreToolUse\\/0\\/matcher\t^spoof')"
ul_t_check "json-flat: the real nested path is still reachable" ul_t_hasline "$out" "$(printf '/hooks/PreToolUse/0/matcher\tBash')"
ul_t_check "json-flat: a spoofed slash key never reads as the real nested path" test "$(printf '%s\n' "$out" | grep -c '^/hooks/PreToolUse/0/matcher')" = 1
ul_t_check "json-flat: true leaf" ul_t_hasline "$out" "$(printf '/t\ttrue')"
ul_t_check "json-flat: false leaf" ul_t_hasline "$out" "$(printf '/f\tfalse')"
ul_t_check "json-flat: null leaf" ul_t_hasline "$out" "$(printf '/n\tnull')"
ul_t_check "json-flat: a number leaf keeps its own digits" ul_t_hasline "$out" "$(printf '/num\t-1.5e3')"

out=$("$SH" "$jf" "$tmp/trailing-comma.json" 2>&1); rc=$?
ul_t_check "json-flat: invalid JSON exits 1" test "$rc" = 1
ul_t_check "json-flat: invalid JSON prints only a reason= line" test "$(printf '%s\n' "$out" | grep -vc '^reason=')" = 0 -a -n "$out"

# json-flat finds json-valid.sh beside itself: remove the validator and it must
# refuse, not silently flatten an unchecked file.
mkdir -p "$tmp/alone"
cp "$jf" "$tmp/alone/json-flat.sh"
out=$("$SH" "$tmp/alone/json-flat.sh" "$fix/base/.claude/settings.json" 2>&1); rc=$?
ul_t_check "json-flat: without json-valid.sh beside it, refuses with reason=" test "$rc" = 1 -a "$(printf '%s\n' "$out" | tail -1 | cut -c1-7)" = "reason="
cp "$jv" "$tmp/alone/json-valid.sh"
out=$("$SH" "$tmp/alone/json-flat.sh" "$fix/base/.claude/settings.json" 2>&1); rc=$?
ul_t_check "json-flat: with json-valid.sh beside it, flattens" test "$rc" = 0 -a -n "$out"

# Portable-shell hygiene of the two tools themselves.
ul_t_check "json-valid.sh parses under sh -n" sh -n "$jv"
ul_t_check "json-flat.sh parses under sh -n" sh -n "$jf"
if [ -x /bin/dash ]; then
  ul_t_check "json-valid.sh parses under dash -n" /bin/dash -n "$jv"
  ul_t_check "json-flat.sh parses under dash -n" /bin/dash -n "$jf"
fi
ul_t_check "json tools carry no Launchhouse or founder wording" test "$(grep -ci 'launchhouse\|founder\|connector-safety' "$jv" "$jf" | awk -F: '{s += $NF} END {print s + 0}')" = 0
ul_t_check "json tools name the LogicLoom script path in their usage" grep -q 'plugins/loom-maintenance/scripts/json-flat.sh' "$jf"

ul_t_done
