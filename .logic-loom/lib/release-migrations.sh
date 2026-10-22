#!/usr/bin/env bash
# Release-migration registry parser — sourceable, bash 3.2 safe.
#
# Parses .logic-loom/config/release-migrations.conf (grammar documented in
# that file's header): line-oriented, '#' comments and blank lines ignored,
# exactly 8 pipe-separated fields, whitespace trimmed per field, '\|' inside
# a field decodes to a literal '|'.
#
# No `declare -A`, no `mapfile`/`readarray`, no `[[ -v ]]`, no `${v,,}`, no
# `sort -V` (not on macOS) — bash 3.2 / stock macOS /bin/bash only.
#
# Public functions:
#   loom_migrations_registry_path [root]
#   loom_migration_rows [file]
#   loom_deprecation_rows [file]
#   loom_migration_row <name> [file]
#   loom_deprecation_row <name> [file]
#   loom_migration_rows_for_release <vX.Y.Z> [file]
#   loom_deprecation_dir <kind> <name>
#   loom_is_deprecated_plugin_dir <name> [file]
#   loom_latest_tag_at_or_below <vX.Y.Z> [root]
#   loom_latest_tag_below <vX.Y.Z> [root]
#   loom_sync_ref_is_loom_record <sync_ref> [root]
#   loom_upstream_ever_had_dir <path> [root]
#   loom_path_traversal_safe <path>
#   loom_migration_lint [file]
#   loom_deprecation_lint [file]        # alias for loom_migration_lint
# Constant:
#   LOOM_MIGRATION_GATE_FLOOR=7.0.0
#
# Row fields (TAB-separated on stdout, in this order):
#   kind  name  fate  replacement  default  first_shipped  release  note

LOOM_MIGRATION_GATE_FLOOR="7.0.0"

_LOOM_RM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── internal helpers ────────────────────────────────────────────────────────

_loom_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# Strip a leading 'v' from a version string.
_loom_version_strip() {
    local v="$1"
    v="${v#v}"
    printf '%s' "$v"
}

# Numeric-only first token of a dot-separated component (defends against a
# stray non-numeric suffix; the registry never has one, but callers may pass
# arbitrary strings).
_loom_version_num() {
    local n="$1"
    n="$(printf '%s' "$n" | sed 's/[^0-9].*$//')"
    [ -n "$n" ] || n=0
    printf '%s' "$n"
}

# 0 if a <= b (numeric X.Y.Z compare), 1 otherwise. Missing components = 0.
_loom_version_le() {
    local a b a1 a2 a3 b1 b2 b3
    a="$(_loom_version_strip "$1")"
    b="$(_loom_version_strip "$2")"
    IFS='.' read -r a1 a2 a3 <<< "$a"
    IFS='.' read -r b1 b2 b3 <<< "$b"
    a1="$(_loom_version_num "${a1:-0}")"; a2="$(_loom_version_num "${a2:-0}")"; a3="$(_loom_version_num "${a3:-0}")"
    b1="$(_loom_version_num "${b1:-0}")"; b2="$(_loom_version_num "${b2:-0}")"; b3="$(_loom_version_num "${b3:-0}")"
    if [ "$a1" -lt "$b1" ]; then return 0; fi
    if [ "$a1" -gt "$b1" ]; then return 1; fi
    if [ "$a2" -lt "$b2" ]; then return 0; fi
    if [ "$a2" -gt "$b2" ]; then return 1; fi
    if [ "$a3" -lt "$b3" ]; then return 0; fi
    if [ "$a3" -gt "$b3" ]; then return 1; fi
    return 0
}

# 0 if a < b (strict), 1 otherwise (a >= b).
_loom_version_lt() {
    if _loom_version_le "$1" "$2"; then
        if _loom_version_le "$2" "$1"; then
            return 1   # equal
        fi
        return 0
    fi
    return 1
}

# Parse one raw registry line into _LOOM_F1.._LOOM_F8 (globals, internal
# use only). Returns 0 on a well-formed 8-field row, 1 with _LOOM_ROW_ERR set
# otherwise. Caller has already skipped blank/comment lines.
_loom_parse_row() {
    local line="$1"
    local us subst f1 f2 f3 f4 f5 f6 f7 f8 f9
    us="$(printf '\037')"
    subst="${line//\\|/$us}"
    IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 f8 f9 <<< "$subst"
    # Round-5 finding 7 (low, permissive grammar): `[ -n "$f9" ]` alone only
    # catches a NONEMPTY 9th field. A trailing pipe with nothing after it
    # ("...|h|") produces exactly 9 real fields, the 9th being the empty
    # string — `read` cannot distinguish that from "only 8 fields were ever
    # there" (both leave f9=""), so that row passed silently, contradicting
    # the documented "exactly 8 pipe-separated fields" contract for no
    # observed safety reason (nothing downstream ever reads f9). Count the
    # real delimiters directly instead of inferring field count from
    # `read`'s tolerant short-read behavior: $subst has already had every
    # escaped `\|` swapped out for $us, so a literal `|` byte remaining in
    # it is always a genuine field delimiter, and a well-formed 8-field row
    # has exactly 7 of them, no more, no less.
    local _lpr_pipes
    _lpr_pipes="$(printf '%s' "$subst" | tr -cd '|' | wc -c | tr -d '[:space:]')"
    if [ -n "$f9" ] || [ -z "$f8" ] || [ "$_lpr_pipes" -ne 7 ]; then
        _LOOM_ROW_ERR="expected exactly 8 pipe-separated fields"
        return 1
    fi
    f1="$(_loom_trim "$f1")"; f1="${f1//$us/|}"
    f2="$(_loom_trim "$f2")"; f2="${f2//$us/|}"
    f3="$(_loom_trim "$f3")"; f3="${f3//$us/|}"
    f4="$(_loom_trim "$f4")"; f4="${f4//$us/|}"
    f5="$(_loom_trim "$f5")"; f5="${f5//$us/|}"
    f6="$(_loom_trim "$f6")"; f6="${f6//$us/|}"
    f7="$(_loom_trim "$f7")"; f7="${f7//$us/|}"
    f8="$(_loom_trim "$f8")"; f8="${f8//$us/|}"
    # Finding 5, the AT-USE half made total (round-4 review): the name field
    # is built into real filesystem paths by every consumer — scan/plan's
    # loom_deprecation_dir ("plugins/<name>", printed straight into the
    # recommended `git rm -r`), convert's ".claude/skills/<name>/CONVERTED.md"
    # (a write), and check-release's fixture scratch tree. Only the last of
    # those had its own guard, and only `lint` ran the lint-time check — a
    # project registry (project-migrations.conf) is never linted before
    # scan/plan/convert read it, so "plugin | ../victim" was walked straight
    # through as plugins/../victim and .claude/skills/../victim/. Reject it
    # HERE, in the one parser every consumer goes through: a traversing name
    # is a malformed row, reported the same way as a wrong field count, and
    # no consumer ever sees it. An empty name is a different defect with a
    # different message — but round-4 review found this sentence stale: it
    # used to be "left to lint's own grammar checks" (i.e. NOT checked
    # here), which the empty-field loop directly below now contradicts —
    # that loop is IN this same parser, so an empty name (or any other
    # empty field) is rejected right here too, same "at-use half made
    # total" reasoning as the traversal check, not deferred to `lint`.
    # Reviewer round 1 (empty fields): every consumer reads a row back with
    # `IFS=$'\t' read -r kind name fate ...`, and a TAB is IFS whitespace —
    # bash collapses consecutive whitespace delimiters, so an EMPTY field
    # does not read as "", it DISAPPEARS and every later field shifts left
    # by one. An unlinted project row `plugin |  | removed | none | ...`
    # therefore reached emit_deprecation_item as name="removed",
    # fate="none", ...: a path built from the wrong field, a decision looked
    # up under the wrong name. Lint requires every field non-empty anyway
    # (a valid `none` row uses '-' for its name/default/first_shipped, never
    # ""), so reject it HERE, in the one parser every consumer goes through
    # — the same "at-use half made total" rule as the traversal check just
    # below — so no consumer ever sees a shifted row. f8's (note) EMPTINESS
    # is already covered by the field-count check above (empty f8 makes f9
    # look absorbed the same as a well-formed row, which is why that check
    # tests `[ -z "$f8" ]` directly rather than relying on this loop).
    #
    # Round-5 finding 4 (medium, embedded-TAB row corruption): this loop
    # used to check ONLY emptiness. Every consumer re-reads a row via
    # `IFS=$'\t' read -r kind name fate ... <<< "$row"` against
    # loom_migration_rows'/loom_deprecation_rows' TAB-joined
    # `printf '%s\t%s\t...'` output — but nothing ever rejected a field that
    # itself contains a literal TAB byte (pipe-delimited input has no reason
    # to exclude it; TAB is not `|`). A field with an embedded tab survives
    # parsing here untouched, gets serialized into a row with ONE EXTRA tab
    # boundary, and `read`'s positional split then shifts every field AFTER
    # the embedded one to the left by one column — the exact "empty field"
    # corruption class above, just triggered by a tab INSIDE a field instead
    # of an empty one between fields. For a plugin/mcp-server/path row (the
    # kinds that build a `git rm`/`git mv` command) this also means
    # _loom_lint_name_shell_safe's AT-USE call (release-migrations.sh)
    # validates the TRUNCATED (post-corruption) name, not the true
    # tab-containing value — a belt-and-suspenders gap on top of the
    # misalignment itself. Reject an embedded tab in ANY field HERE, in the
    # one parser every consumer goes through, exactly like the empty-field
    # and traversal checks around it — checking f8 (note) too, even though
    # a tab there cannot shift anything (it is the last column `read`
    # absorbs), for one honest invariant: no field this parser hands out
    # ever contains the byte every consumer re-splits on.
    local _ef_i=1 _ef_v _ef_name _ef_tab
    _ef_tab="$(printf '\t')"
    for _ef_v in "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7" "$f8"; do
        case "$_ef_i" in
            1) _ef_name="kind" ;; 2) _ef_name="name" ;; 3) _ef_name="fate" ;;
            4) _ef_name="replacement" ;; 5) _ef_name="default" ;;
            6) _ef_name="first_shipped" ;; 7) _ef_name="release" ;; *) _ef_name="note" ;;
        esac
        if [ "$_ef_i" -le 7 ] && [ -z "$_ef_v" ]; then
            _LOOM_ROW_ERR="field $_ef_i ($_ef_name) must not be empty (a valid none row uses '-')"
            return 1
        fi
        case "$_ef_v" in
            *"$_ef_tab"*)
                _LOOM_ROW_ERR="field $_ef_i ($_ef_name) must not contain a literal tab (rows are re-serialized tab-separated; an embedded tab shifts every later field on read-back)"
                return 1
                ;;
        esac
        _ef_i=$((_ef_i + 1))
    done
    if ! loom_path_traversal_safe "$f2"; then
        _LOOM_ROW_ERR="name '$f2' must not be absolute or contain a '..'/'.' path segment"
        return 1
    fi
    _LOOM_F1="$f1"; _LOOM_F2="$f2"; _LOOM_F3="$f3"; _LOOM_F4="$f4"
    _LOOM_F5="$f5"; _LOOM_F6="$f6"; _LOOM_F7="$f7"; _LOOM_F8="$f8"
    return 0
}

# ── public: registry location ───────────────────────────────────────────────

loom_migrations_registry_path() {
    local root="${1:-}"
    if [ -n "${LOOM_MIGRATION_REGISTRY:-}" ]; then
        printf '%s' "$LOOM_MIGRATION_REGISTRY"
        return 0
    fi
    if [ -z "$root" ]; then
        root="$(cd "$_LOOM_RM_LIB_DIR/../.." && pwd)"
    fi
    printf '%s' "$root/.logic-loom/config/release-migrations.conf"
}

# ── public: row iteration ───────────────────────────────────────────────────

# Every row, normalized, TAB-separated 8 fields, one per stdout line.
# On a malformed row: "LINT: line N: <why>" to stderr; parsing continues;
# rc 1 after the whole file has been read if any row was malformed.
loom_migration_rows() {
    local file="${1:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    if [ ! -f "$file" ]; then
        echo "LINT: registry not found: $file" >&2
        return 1
    fi
    local lineno=0 had_error=0 line trimmed
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        trimmed="$(_loom_trim "$line")"
        [ -z "$trimmed" ] && continue
        [ "${trimmed#\#}" != "$trimmed" ] && continue
        if _loom_parse_row "$line"; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$_LOOM_F1" "$_LOOM_F2" "$_LOOM_F3" "$_LOOM_F4" \
                "$_LOOM_F5" "$_LOOM_F6" "$_LOOM_F7" "$_LOOM_F8"
        else
            echo "LINT: line $lineno: $_LOOM_ROW_ERR" >&2
            had_error=1
        fi
    done < "$file"
    [ "$had_error" -eq 0 ] || return 1
    return 0
}

# The 23 deprecation-kind rows (plugin | mcp-server | path).
loom_deprecation_rows() {
    local file="${1:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    local all rc=0
    all="$(loom_migration_rows "$file")" || rc=$?
    [ -n "$all" ] && printf '%s\n' "$all" | while IFS=$'\t' read -r k f2 f3 f4 f5 f6 f7 f8; do
        case "$k" in
            plugin|mcp-server|path)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7" "$f8" ;;
        esac
    done
    return $rc
}

# First row of any kind named <name>. rc 1 + empty stdout when none.
loom_migration_row() {
    local name="$1" file="${2:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    local all
    all="$(loom_migration_rows "$file" 2>/dev/null)" || true
    [ -z "$all" ] && return 1
    local found
    found="$(printf '%s\n' "$all" | awk -F'\t' -v n="$name" '$2 == n { print; exit }')"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi
    return 1
}

# First DEPRECATION row (plugin/mcp-server/path) named <name>.
loom_deprecation_row() {
    local name="$1" file="${2:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    local all found
    all="$(loom_deprecation_rows "$file" 2>/dev/null)" || true
    [ -z "$all" ] && return 1
    found="$(printf '%s\n' "$all" | awk -F'\t' -v n="$name" '$2 == n { print; exit }')"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi
    return 1
}

# Every row (any kind) whose release field equals <vX.Y.Z>.
loom_migration_rows_for_release() {
    local release="$1" file="${2:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    local all rc=0
    all="$(loom_migration_rows "$file")" || rc=$?
    [ -n "$all" ] && printf '%s\n' "$all" | awk -F'\t' -v r="$release" '$7 == r { print }'
    return $rc
}

# plugins/<name> | mcp-servers/<name> | <name> (path kind: name IS the path)
loom_deprecation_dir() {
    local kind="$1" name="$2"
    case "$kind" in
        plugin) printf 'plugins/%s' "$name" ;;
        mcp-server) printf 'mcp-servers/%s' "$name" ;;
        path) printf '%s' "$name" ;;
        *) return 1 ;;
    esac
    return 0
}

# rc 0 iff a `plugin`-kind row named <name> exists.
loom_is_deprecated_plugin_dir() {
    local name="$1" file="${2:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    local all
    all="$(loom_deprecation_rows "$file" 2>/dev/null)" || true
    [ -z "$all" ] && return 1
    printf '%s\n' "$all" | awk -F'\t' -v n="$name" '$1 == "plugin" && $2 == n { found=1 } END { exit(found ? 0 : 1) }'
}

# Newest local tag (v[0-9]*) whose numeric version is <= <vX.Y.Z>, with the
# leading 'v'. rc 1 + empty stdout when none resolves.
loom_latest_tag_at_or_below() {
    local target="$1" root="${2:-}"
    [ -n "$root" ] || root="$(cd "$_LOOM_RM_LIB_DIR/../.." && pwd)"
    local tags stripped sorted t
    tags="$(git -C "$root" for-each-ref --format='%(refname:short)' refs/tags/ 2>/dev/null)" || return 1
    [ -z "$tags" ] && return 1
    # Low finding (round 5 review): the same strict vX.Y.Z filter lint and
    # --since already require (_loom_lint_strict_version), applied here too
    # — the previous /^v[0-9]/ let "v9x.0.0" or "v8.0.0-rc1" through, and
    # _loom_version_num's non-numeric-suffix stripping would then silently
    # misread the first component instead of excluding the tag outright.
    stripped="$(printf '%s\n' "$tags" | awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, ""); print }')"
    [ -z "$stripped" ] && return 1
    sorted="$(printf '%s\n' "$stripped" | sort -t. -k1,1nr -k2,2nr -k3,3nr)"
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        if _loom_version_le "$t" "$target"; then
            printf 'v%s' "$t"
            return 0
        fi
    done <<< "$sorted"
    return 1
}

# Newest local tag (v[0-9]*) whose numeric version is STRICTLY LESS THAN
# <vX.Y.Z> — never the release being checked itself. check-release's "the
# previous release" (removal-guard --since auto, and a content row's
# before-proof content_prev) means "what shipped immediately before this
# one", and once a version has ALSO been tagged (a post-release audit,
# or simply re-running the gate after tagging), the at-or-below variant
# above happily returns that SAME tag — which then "proves" a content row's
# claimed prior/problem state against that row's own POST-fix content and
# fails the row closed for no real reason. rc 1 + empty stdout when none
# resolves (no tag exists that is strictly earlier).
loom_latest_tag_below() {
    local target="$1" root="${2:-}"
    [ -n "$root" ] || root="$(cd "$_LOOM_RM_LIB_DIR/../.." && pwd)"
    local tags stripped sorted t
    tags="$(git -C "$root" for-each-ref --format='%(refname:short)' refs/tags/ 2>/dev/null)" || return 1
    [ -z "$tags" ] && return 1
    # Low finding (round 5 review): same strict vX.Y.Z filter as
    # loom_latest_tag_at_or_below above — see its comment.
    stripped="$(printf '%s\n' "$tags" | awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, ""); print }')"
    [ -z "$stripped" ] && return 1
    sorted="$(printf '%s\n' "$stripped" | sort -t. -k1,1nr -k2,2nr -k3,3nr)"
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        if _loom_version_lt "$t" "$target"; then
            printf 'v%s' "$t"
            return 0
        fi
    done <<< "$sorted"
    return 1
}

# ── public: sync-ref provenance ─────────────────────────────────────────────

# Round-2 finding 1 (shared by the scanner and the recorder — see both
# callers' own comments for why the check exists at all): a .sdd-sync-ref
# value counts as LogicLoom's OWN record ONLY when it is hex-shaped AND
# refs/loom-upstream/main exists locally AND the sync-ref commit is an
# ancestor of (or equal to) it. This mirrors the exact reachability rule
# extract-proposals.sh already enforces on the very same file
# (ensure_sync_ref: "NOT reachable from upstream main" is fatal there) — the
# scanner and recorder merely stop being looser than the update path about
# the same file.
#
# THE FIX BY DESIGN (round 2): when refs/loom-upstream/main is ABSENT, this
# used to fall through and accept hex shape alone as sufficient ("nothing to
# check reachability against, so the shape stands on its own"). That is
# wrong: absent upstream history proves nothing about who wrote the
# sync-ref, and a customer's own commit sha (or a symbolic name that happens
# to resolve to one) written into the file is indistinguishable from
# LogicLoom's own record by shape alone. With no upstream history there is
# NO BASELINE, full stop — never "the shape is enough". Callers see this as
# rc 1 (not a loom record), which routes them to their own safe fallback:
# the scanner's resolve_baseline treats it as no sync-ref candidate (state
# unknown, never REMOVE — governing principle: doubt -> KEEP and ASK); the
# recorder's resolve_sync_ref/upstream_blob_sha refuse to record from it,
# telling the caller to run /update-framework (bash extract-proposals.sh)
# first so upstream history is actually fetched.
#
# rc 0 iff <sync_ref> may serve as a LogicLoom-authored baseline. Read-only
# git only (rev-parse, merge-base).
loom_sync_ref_is_loom_record() {
    local sync_ref="$1" root="${2:-}"
    [ -n "$root" ] || root="$(cd "$_LOOM_RM_LIB_DIR/../.." && pwd)"
    [ -n "$sync_ref" ] || return 1
    case "$sync_ref" in *[!0-9a-fA-F]*) return 1 ;; esac
    [ "${#sync_ref}" -ge 7 ] && [ "${#sync_ref}" -le 64 ] || return 1
    git -C "$root" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 || return 1
    git -C "$root" merge-base --is-ancestor "$sync_ref" refs/loom-upstream/main 2>/dev/null || return 1
    return 0
}

# Round-4 finding 6 (high, receipt forgery — directory-ownership
# corroboration). .logicloom-adopt-receipt.json is a plain, hand-editable
# JSON file (see release-migrations.sh's own trust-boundary comment on
# _loom_rm_adopt_receipt_sha256 / _loom_rm_receipt_sha256_corroborated for
# the full statement of this). record-update-writes.sh's TRUSTED_GENERATOR_RE
# restricts which run entries the 'recorded' op will read at all, but that
# regex only checks the SHAPE of a string in the same adopter-editable file
# — it is not proof of authorship. A kind:"file" entry at least carries a
# sha256 that build_entries/--reconcile verify against a blob at that exact
# path in a PROVABLY upstream commit (loom_sync_ref_is_loom_record). A
# kind:"dir" entry carries no hash — there is nothing on it to verify — so a
# hand-written run with a plausible generator string and a fabricated
# `{"path": "<any directory>", "kind": "dir"}` entry was the ONLY gate
# between an attacker and licensing --reconcile's sweep into an arbitrary
# directory, including one LogicLoom's own writers never touched (a
# customer's own top-level directory, a product workspace like web/ — see
# CLAUDE.md's harness/product boundary). A directory has no hash, but it
# does have a PATH, and LogicLoom's own upstream history
# (refs/loom-upstream/main) either did or did not ever contain a TREE at
# that path. Cheap, read-only, no crypto, same shape as
# _loom_rm_receipt_sha256_corroborated: walk every commit refs/loom-upstream/main
# reaches that ever touched $path and ask whether $path was ever a tree
# object there (not a blob — a file existing at that exact path proves
# nothing about directory-scoped ownership, and a leftover blob-vs-tree type
# change across releases must not produce a false positive either way).
# Uncorroborated (no refs/loom-upstream/main locally, or $path was never a
# tree in its reachable history): rc 1, and the caller must treat the dir
# entry as unusable — never as license to sweep. Doubt -> KEEP and ASK.
loom_upstream_ever_had_dir() {
    local path="$1" root="${2:-}"
    [ -n "$root" ] || root="$(cd "$_LOOM_RM_LIB_DIR/../.." && pwd)"
    path="${path%/}"
    [ -n "$path" ] || return 1
    git -C "$root" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 || return 1
    local commits commit
    # Round-5 REVIEWER: the path goes to `git log` as a PATHSPEC, and a name
    # beginning with ':' is pathspec magic to git (`:colon` parses as the
    # pattern "colon"), so a legitimately recorded ':'-named directory could
    # never be corroborated (empty log, rc 1 — fail-safe but wrong). A glob
    # character could only over-match (git tries the literal prefix first),
    # and the `cat-file -t <commit>:<path>` check below is an object name,
    # already literal. `:(literal)` makes the log lookup literal too, so the
    # two halves of this function agree on which path they are asking about.
    # $path is non-empty here (guarded above): `:(literal)` alone would
    # match the whole tree.
    commits="$(git -C "$root" log --format=%H refs/loom-upstream/main -- ":(literal)$path" 2>/dev/null)" || return 1
    [ -n "$commits" ] || return 1
    while IFS= read -r commit; do
        [ -n "$commit" ] || continue
        if [ "$(git -C "$root" cat-file -t "${commit}:${path}" 2>/dev/null)" = "tree" ]; then
            return 0
        fi
    done <<EOF
$commits
EOF
    return 1
}

# ── public: lint ─────────────────────────────────────────────────────────────

_loom_lint_kind_ok() {
    case "$1" in plugin|mcp-server|path|content|none) return 0 ;; *) return 1 ;; esac
}

_loom_lint_fate_ok() {
    local kind="$1" fate="$2"
    case "$kind" in
        plugin|mcp-server|path)
            case "$fate" in renamed|folded|native|removed) return 0 ;; *) return 1 ;; esac ;;
        content)
            case "$fate" in present|absent) return 0 ;; *) return 1 ;; esac ;;
        none)
            [ "$fate" = "none" ] && return 0 ; return 1 ;;
    esac
    return 1
}

_loom_lint_default_ok() {
    local kind="$1" default="$2"
    case "$kind" in
        content)
            case "$default" in PROPOSE|PROPOSE-ADVISORY) return 0 ;; *) return 1 ;; esac ;;
        none) [ "$default" = "-" ] && return 0 ; return 1 ;;
        *)
            case "$default" in
                REMOVE|ADOPT-REPLACEMENT|CONVERT-TO-LOCAL|KEEP-AS-IS|MOVE) return 0 ;;
                *) return 1 ;;
            esac ;;
    esac
}

# PROPOSE-ADVISORY content rows are the KORI CLASS (§ project-amendments):
# LogicLoom never shipped this text, so the row MAY only target a fork-owned
# file — the harness has no authority to declare anyone else's file stale.
_loom_lint_advisory_target_ok() {
    local name="$1" base
    base="${name##*/}"
    case "$base" in
        amendments.md|CLAUDE.md|CLAUDE.local.md|AGENTS.md) return 0 ;;
        *) return 1 ;;
    esac
}

# Medium finding (round 5 review): scoped to the exact-path kinds
# (plugin/mcp-server/path) — the only kinds build_remove_cmd ever turns
# into a printed `git rm ...` advisory command (release-migrations.sh's
# build_remove_cmd has no case for "content" at all: REC_REMOVE_CMD stays
# empty). A content row's name is a glob PATTERN (content_matches()
# legitimately matches it on '*'/'?'), so it is deliberately exempt here —
# unlike loom_path_traversal_safe above, this check is NOT shared with
# content rows. Whitespace or a shell metacharacter (";", "|", "&", "$",
# backticks, quotes, redirection, a bare glob) in a plugin/mcp-server/path
# name would ride straight into that printed command; build_remove_cmd now
# also quotes every path it prints (belt-and-suspenders — this closes the
# hole at the source, at lint time, so a bad name never ships at all).
#
# Reviewer round 1 (option-shaped names): '-' is in the whitelist, so a
# `path` row named "-f" (or "-r", "--cached", …) lints clean — and quoting
# cannot help with it: `git rm '-f'` still hands git an OPTION, not a path.
# A leading '-' is rejected for the same three kinds; a `none` row's '-'
# name is a different kind and stays valid. Applied at lint time here and
# AGAIN at use (release-migrations.sh's compute_recommendation calls this
# function on every plugin/mcp-server/path row before building any
# command), so an unlinted project registry gets the same refusal.
_loom_lint_name_shell_safe() {
    local kind="$1" name="$2"
    case "$kind" in
        plugin|mcp-server|path) : ;;
        *) return 0 ;;
    esac
    case "$name" in
        -*) return 1 ;;
        *[!A-Za-z0-9._/-]*) return 1 ;;
    esac
    return 0
}

_loom_lint_replacement_ok() {
    local kind="$1" repl="$2"
    if [ "$kind" = "content" ]; then
        case "$repl" in pattern:*) return 0 ;; *) return 1 ;; esac
    fi
    case "$repl" in
        pattern:*) return 1 ;;
        none) return 0 ;;
        plugin:*|path:*|command:*|native:*|external:*) return 0 ;;
        *) return 1 ;;
    esac
}

# Strict vX.Y.Z — digits only in all three components, anchored start to
# end. Finding 6's class (round-4 review): the previous `v[0-9]*.[0-9]*.[0-9]*`
# case glob is loose — `*` matches ANY characters, so "v9x.0.0" and
# "v8.0.0-rc1" passed as well-formed, and a row carrying one then sits in
# the registry with a release no check-release/rows_for_release exact-match
# can ever find. grep -E, not `[[ =~ ]]`: bash 3.2's regex quoting is the
# one place its behaviour differs from later bash, and this file is on the
# 3.2 floor.
_loom_lint_strict_version() {
    printf '%s' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'
}

_loom_lint_first_shipped_ok() {
    local v="$1"
    case "$v" in
        never|-) return 0 ;;
    esac
    _loom_lint_strict_version "$v"
}

_loom_lint_release_ok() {
    _loom_lint_strict_version "$1"
}

_loom_lint_note_ok() {
    local kind="$1" note="$2"
    [ -z "$note" ] && return 1
    if [ "$kind" = "content" ]; then
        case "$note" in
            *proposal:*why:*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

# ── public: path safety ─────────────────────────────────────────────────────

# True (rc 0) iff <path> is safe to interpolate into a real filesystem path:
# not absolute, and no path segment is literally ".." or ".". Finding 5: a
# registry row's `name` field (a bare component for plugin/mcp-server rows,
# a repo-relative path for path/content rows) ends up built into real
# filesystem paths in several places — most concretely,
# _loom_rm_verify_fixture_scan_path in release-migrations.sh, which does
# `mkdir -p "$tmp/$(dirname "$name")"` and `cp ... "$tmp/$name"` with no
# traversal check of its own. A row whose name were "/etc/passwd" or
# "../../../../etc/passwd" would otherwise be walked straight through as a
# real path. Checked BOTH here at lint time (every row, so a bad name never
# ships) AND again at the one call site that actually builds a path from it
# (belt-and-suspenders: lint covers the shipped registry, the use-site check
# covers a project-owned registry a fork wrote by hand and never linted).
#
# Medium finding (round 5 review), the "." half: a bare "." segment used to
# slip through (only ".." was rejected) — for a plugin-kind row that turns
# into build_remove_cmd's `git rm -r plugins/.`, which is `plugins/` itself,
# not a specific plugin: a one-character name would recommend deleting every
# plugin in the tree. Rejected as a whole segment the same as "..".
#
# This function is shared by EVERY kind, including content rows, whose name
# is a glob PATTERN content_matches() matches with `*`/`?` (see
# release-migrations.sh) — so it deliberately does NOT restrict the
# character set; a stricter, kind-scoped whitelist (no whitespace, no shell
# metacharacter) for the plugin/mcp-server/path kinds that actually reach
# build_remove_cmd lives in _loom_lint_name_shell_safe below, lint-time only,
# and build_remove_cmd itself now quotes every path it prints regardless
# (see release-migrations.sh's shell_quote) — belt-and-suspenders, not a
# substitute for either.
# Pure string check: no git, no filesystem access.
loom_path_traversal_safe() {
    local path="$1"
    [ -n "$path" ] || return 1
    case "$path" in
        /*) return 1 ;;
    esac
    local seg old_ifs="$IFS"
    IFS='/'
    for seg in $path; do
        case "$seg" in
            .|..)
                IFS="$old_ifs"
                return 1 ;;
        esac
    done
    IFS="$old_ifs"
    return 0
}

# Grammar + every enumeration + content note markers + none-row exclusivity +
# duplicate deprecation names. Prints every "LINT: line N: <why>" message
# found; rc 1 if any.
loom_migration_lint() {
    local file="${1:-}"
    [ -n "$file" ] || file="$(loom_migrations_registry_path)"
    if [ ! -f "$file" ]; then
        echo "LINT: registry not found: $file" >&2
        return 1
    fi
    local lineno=0 had_error=0 line trimmed
    local seen_names="" seen_name
    local none_releases="" all_rows=""
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        trimmed="$(_loom_trim "$line")"
        [ -z "$trimmed" ] && continue
        [ "${trimmed#\#}" != "$trimmed" ] && continue
        if ! _loom_parse_row "$line"; then
            echo "LINT: line $lineno: $_LOOM_ROW_ERR" >&2
            had_error=1
            continue
        fi
        local kind="$_LOOM_F1" name="$_LOOM_F2" fate="$_LOOM_F3" repl="$_LOOM_F4"
        local default="$_LOOM_F5" first="$_LOOM_F6" release="$_LOOM_F7" note="$_LOOM_F8"

        if ! _loom_lint_kind_ok "$kind"; then
            echo "LINT: line $lineno: unknown kind '$kind'" >&2; had_error=1
        fi
        # Finding 5: name is later built into a real filesystem path (see
        # loom_path_traversal_safe above) — reject at lint time so a
        # traversal never ships in the registry at all.
        if ! loom_path_traversal_safe "$name"; then
            echo "LINT: line $lineno: name '$name' must not be absolute or contain a '..'/'.' path segment" >&2; had_error=1
        fi
        # Medium finding (round 5 review): plugin/mcp-server/path names feed
        # build_remove_cmd's printed `git rm ...` advice — reject whitespace
        # and shell metacharacters here so a degenerate name never ships.
        # Content rows are exempt (see _loom_lint_name_shell_safe above).
        if ! _loom_lint_name_shell_safe "$kind" "$name"; then
            echo "LINT: line $lineno: name '$name' must contain only letters, digits, '.', '_', '/', '-' for kind '$kind', and must not start with '-'" >&2; had_error=1
        fi
        if ! _loom_lint_fate_ok "$kind" "$fate"; then
            echo "LINT: line $lineno: fate '$fate' is not valid for kind '$kind'" >&2; had_error=1
        fi
        if ! _loom_lint_replacement_ok "$kind" "$repl"; then
            echo "LINT: line $lineno: replacement '$repl' is not valid for kind '$kind'" >&2; had_error=1
        fi
        # Medium finding (round 5 review), residual gap found while adding
        # test coverage for it: _loom_lint_replacement_ok above only checks
        # the "path:" PREFIX shape, never the path that follows it — but a
        # path-kind/renamed row's replacement path feeds
        # release-migrations.sh's compute_recommendation the same way `name`
        # does, into a printed `git mv` command (REC_MOVE_CMD). Reject it
        # here too, at lint time, so a degenerate replacement path never
        # ships in the registry either (compute_recommendation carries the
        # matching at-use guard for a project registry that was never
        # linted).
        if [ "$kind" = "path" ] && [ "$fate" = "renamed" ] && [ "${repl#path:}" != "$repl" ]; then
            local _newp="${repl#path:}"
            if ! loom_path_traversal_safe "$_newp"; then
                echo "LINT: line $lineno: replacement path '$_newp' must not be absolute or contain a '..'/'.' path segment" >&2; had_error=1
            fi
            if ! _loom_lint_name_shell_safe path "$_newp"; then
                echo "LINT: line $lineno: replacement path '$_newp' must contain only letters, digits, '.', '_', '/', '-', and must not start with '-'" >&2; had_error=1
            fi
        fi
        if ! _loom_lint_default_ok "$kind" "$default"; then
            echo "LINT: line $lineno: default '$default' is not valid for kind '$kind'" >&2; had_error=1
        fi
        if [ "$kind" = "content" ] && [ "$default" = "PROPOSE-ADVISORY" ] && ! _loom_lint_advisory_target_ok "$name"; then
            echo "LINT: line $lineno: PROPOSE-ADVISORY (KORI CLASS) may only target a fork-owned file (amendments.md, CLAUDE.md, CLAUDE.local.md, AGENTS.md) — got '$name'" >&2; had_error=1
        fi
        if ! _loom_lint_first_shipped_ok "$first"; then
            echo "LINT: line $lineno: first_shipped '$first' must be vX.Y.Z, 'never' or '-'" >&2; had_error=1
        fi
        if ! _loom_lint_release_ok "$release"; then
            echo "LINT: line $lineno: release '$release' must be vX.Y.Z" >&2; had_error=1
        fi
        if ! _loom_lint_note_ok "$kind" "$note"; then
            if [ "$kind" = "content" ]; then
                echo "LINT: line $lineno: content row note must contain both 'proposal:' and 'why:'" >&2
            else
                echo "LINT: line $lineno: note must not be empty" >&2
            fi
            had_error=1
        fi

        if [ "$kind" = "plugin" ] || [ "$kind" = "mcp-server" ] || [ "$kind" = "path" ]; then
            local dup=0
            for seen_name in $seen_names; do
                if [ "$seen_name" = "___${name}___" ]; then dup=1; break; fi
            done
            if [ "$dup" -eq 1 ]; then
                echo "LINT: line $lineno: duplicate deprecation name $name" >&2
                had_error=1
            else
                seen_names="$seen_names ___${name}___"
            fi
        fi

        if [ "$kind" = "none" ]; then
            none_releases="$none_releases $release"
        fi
        all_rows="${all_rows}${lineno}"$'\t'"${kind}"$'\t'"${release}"$'\n'
    done < "$file"

    local nr
    for nr in $none_releases; do
        local siblings
        siblings="$(printf '%s' "$all_rows" | awk -F'\t' -v r="$nr" '$3 == r' | wc -l | tr -d ' ')"
        if [ "$siblings" -gt 1 ]; then
            echo "LINT: release $nr: a 'none' row must be the only row naming its release" >&2
            had_error=1
        fi
    done

    [ "$had_error" -eq 0 ] || return 1
    return 0
}

loom_deprecation_lint() {
    loom_migration_lint "$@"
}
