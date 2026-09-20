#!/usr/bin/env bash
# Release Migration Scan / Plan / Convert / Lint / Check-Release
# Plugin: loom-maintenance (Additive Update Framework)
#
# Evaluates the release-migration registry (.logic-loom/config/release-migrations.conf)
# and, in an ADOPTED repo, the project-owned registry
# (.logic-loom/config/project-migrations.conf) against the working tree, and
# prints a guided, per-item proposal. NEVER runs a mutating git command and
# NEVER edits, deletes, or writes anything outside .claude/skills/,
# .claude/agents/, and .logic-loom/config/migration-decisions.conf. Every
# `git rm` / `git mv` / `.mcp.json` edit it recommends is printed as text for
# the user to approve — it never runs one itself.
#
# Usage:
#   release-migrations.sh scan [--json] [--root <dir>] [--registry <file>]
#   release-migrations.sh plan <name> [--root <dir>] [--registry <file>]
#   release-migrations.sh convert <name> (--dry-run|--apply) [--customized-only] [--root <dir>] [--registry <file>]
#   release-migrations.sh lint [--root <dir>] [--registry <file>]
#   release-migrations.sh check-release [<vX.Y.Z>] [--since <tag>|auto] [--root <dir>] [--registry <file>]
#   release-migrations.sh --help
#
# Exit codes: 0 ok; 1 usage/registry error or a failed check-release;
# 2 conversion unit stopped by collision, or registry not found.
#
# bash 3.2 safe: no `declare -A`, `mapfile`/`readarray`, `[[ -v ]]`, `${v,,}`,
# `sort -V`. Read-only git only: rev-parse, cat-file, ls-tree, ls-files,
# rev-list, show, diff, for-each-ref, grep, merge-base --is-ancestor. Never
# hash-object, tag, ls-remote, or any mutating verb.

# Deliberately `-uo pipefail` WITHOUT `-e`: this script's read-only
# introspection (find/grep on a directory a plugin may not have, a lookup
# that legitimately finds nothing) returns non-zero for perfectly normal
# "not found/empty" outcomes, and every one of those sits behind a
# `var="$(...)"` capture — which, unlike a bare `cmd1 && cmd2` statement,
# DOES trip `errexit` on the capturing assignment even though the "failure"
# is expected, not an error. Auditing every such call site to opt out
# individually was tried and abandoned as more error-prone than dropping
# `-e` here; every real failure path in this script exits or returns an
# explicit non-zero status instead of relying on errexit to stop it — and
# every WRITE in `convert --apply` is checked explicitly (a failed write
# stops that unit, is printed as ERROR, and no `converted =` decision is
# recorded). extract-proposals.sh, which we source for ADOPTED detection,
# sets `-e` at its top level; `_loom_rm_init_adopt_mode` restores our
# posture right after the source so scan/plan run the same way convert does.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Temp copy of the upstream registry (see resolve_registry); removed on exit.
_LOOM_RM_TMP_REGISTRY=""
# A single mktemp -d directory that every check-release fixture-scan-path
# proof tree (finding 5, _loom_rm_verify_fixture_scan_path below) is created
# UNDER — never a sibling of it. This is the safety boundary the cleanup
# trap enforces: nothing outside this one mktemp-created directory is ever
# removed, no matter what ends up in the list below. Created lazily by
# _loom_rm_proof_base(), once, on first use.
_LOOM_RM_PROOF_BASE=""
# Throwaway trees the fixture-scan-path proof builds, one per mktemp -d call,
# each a direct child of $_LOOM_RM_PROOF_BASE. NEWLINE-delimited (not
# space-delimited): a TMPDIR containing a space would otherwise word-split a
# single path into two bogus "words" when this list is walked, and an
# unquoted `for x in $list` loop feeding `rm -rf` a word-split fragment can
# hit a directory this run never created. Appended to (never overwritten) by
# _loom_rm_verify_fixture_scan_path; removed on exit alongside the registry
# temp copy and the base directory itself.
_LOOM_RM_PROOF_TMP_DIRS=""

# Ensure $_LOOM_RM_PROOF_BASE exists (mktemp -d it on first call) and print
# it. Every fixture-scan-path proof tree must be created as a direct child
# of this single directory so the cleanup trap has one unambiguous boundary
# to check paths against, instead of trusting a list of free-floating paths.
_loom_rm_proof_base() {
    if [ -z "$_LOOM_RM_PROOF_BASE" ] || [ ! -d "$_LOOM_RM_PROOF_BASE" ]; then
        _LOOM_RM_PROOF_BASE="$(mktemp -d "${TMPDIR:-/tmp}/loom-rm-fixtureproof-base.XXXXXX" 2>/dev/null)" || return 1
    fi
    [ -n "$_LOOM_RM_PROOF_BASE" ] && [ -d "$_LOOM_RM_PROOF_BASE" ]
    printf '%s\n' "$_LOOM_RM_PROOF_BASE"
}

# Low finding (round 5 review, prose corrected round 4): the previous
# check-then-rm here was pure TOCTOU — a case-match against
# $_LOOM_RM_PROOF_BASE, then a separate `rm -rf` a moment later, with
# nothing stopping a path component from being swapped for a symlink in
# between (or the entry itself being a symlink to begin with). Note what the
# actual exposure is NOT: `rm -rf` on a symlink argument never follows it
# into a directory's content — both GNU and BSD `rm` lstat the argument and
# simply unlink the symlink node itself, the same as for any symlink
# encountered during recursion. The real exposure is narrower and easy to
# miss for exactly that reason: an INTERMEDIATE ancestor of $d being swapped
# for a symlink between the case-match and the `rm -rf`, so $d still looks
# like a real directory under $_LOOM_RM_PROOF_BASE by name, while its
# CANONICAL location has moved outside it. Re-checked, right at removal time, not at
# case-match time: (1) the entry itself is not a symlink — refused outright,
# never followed; (2) its PARENT resolves (via `cd -P`, which does not
# traverse the final component, only the ones above it) to a real path that
# is still $_LOOM_RM_PROOF_BASE or under it, using canonical paths on both
# sides so a symlink swapped into an intermediate component after the fact
# is caught, not trusted. A path that fails either check is skipped, not
# removed — a proof gone missing is a test-integrity bug to fix, never a
# reason to widen what EXIT cleanup is allowed to delete.
_loom_rm_safe_to_remove() {
    local d="$1" base="$2"
    [ -n "$d" ] && [ -n "$base" ] || return 1
    case "$d" in
        "$base"/*) : ;;
        *) return 1 ;;
    esac
    [ -L "$d" ] && return 1
    [ -e "$d" ] || return 1
    # High finding (round-2 review): $base itself (normally
    # $_LOOM_RM_PROOF_BASE) must never be trusted as a symlink either — the
    # canonicalization below (`cd -P`) follows a symlink at $base
    # transparently, so if $base were swapped for a symlink between creation
    # and cleanup, real_base and real_parent would both resolve through that
    # SAME symlink and match each other, routing removal into whatever it
    # points at. Refused here, before any canonicalization runs, the same
    # "never follow" rule this function already applies to $d itself.
    [ -L "$base" ] && return 1
    local real_base real_parent
    real_base="$(cd -P -- "$base" 2>/dev/null && pwd -P)" || return 1
    real_parent="$(cd -P -- "$(dirname -- "$d")" 2>/dev/null && pwd -P)" || return 1
    case "$real_parent" in
        "$real_base") : ;;
        "$real_base"/*) : ;;
        *) return 1 ;;
    esac
    return 0
}

_loom_rm_cleanup() {
    [ -n "$_LOOM_RM_TMP_REGISTRY" ] && rm -f "$_LOOM_RM_TMP_REGISTRY"
    # Walk the NEWLINE-delimited list one entry at a time via `read -r` (never
    # an unquoted `for d in $list`, which would word-split on spaces in
    # TMPDIR).
    if [ -n "$_LOOM_RM_PROOF_TMP_DIRS" ] && [ -n "$_LOOM_RM_PROOF_BASE" ] && [ -d "$_LOOM_RM_PROOF_BASE" ]; then
        local d
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            if _loom_rm_safe_to_remove "$d" "$_LOOM_RM_PROOF_BASE"; then
                rm -rf -- "$d"
            fi
        done <<EOF
$_LOOM_RM_PROOF_TMP_DIRS
EOF
    fi
    # The base itself is exactly one mktemp-created directory held in a
    # scalar (never word-split), so removing it wholesale is safe and also
    # catches anything the per-entry loop above could not account for — but
    # still refuse if it itself is now a symlink rather than a real
    # directory (same "never follow" rule as every entry above).
    if [ -n "$_LOOM_RM_PROOF_BASE" ] && [ -d "$_LOOM_RM_PROOF_BASE" ] && [ ! -L "$_LOOM_RM_PROOF_BASE" ]; then
        rm -rf -- "$_LOOM_RM_PROOF_BASE"
    fi
    return 0
}
trap _loom_rm_cleanup EXIT

# ── arg pre-scan for --root (must run before we source the lib) ────────────
_ARGV=("$@")
_ROOT_OVERRIDE=""
_i=0
while [ $_i -lt ${#_ARGV[@]} ]; do
    if [ "${_ARGV[$_i]}" = "--root" ]; then
        _next=$((_i + 1))
        if [ $_next -lt ${#_ARGV[@]} ]; then
            _ROOT_OVERRIDE="${_ARGV[$_next]}"
        fi
    fi
    _i=$((_i + 1))
done
if [ -n "$_ROOT_OVERRIDE" ]; then
    [ -d "$_ROOT_OVERRIDE" ] || { echo "release-migrations.sh: --root '$_ROOT_OVERRIDE' is not a directory" >&2; exit 1; }
    REPO_ROOT="$(cd "$_ROOT_OVERRIDE" && pwd)"
fi
[ -f "$REPO_ROOT/.logic-loom/lib/release-migrations.sh" ] \
    || { echo "release-migrations.sh: $REPO_ROOT/.logic-loom/lib/release-migrations.sh not found (is this a LogicLoom tree?)" >&2; exit 1; }

# shellcheck source=/dev/null
source "$REPO_ROOT/.logic-loom/lib/release-migrations.sh"

# ============================================================================
# Small shared helpers
# ============================================================================

die_usage() {
    echo "release-migrations.sh: $1" >&2
    exit 1
}

json_escape() {
    # backslash, double quote; newline/CR/tab -> space (a raw tab is not
    # legal inside a JSON string, and grep hits carry the file's own tabs).
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="$(printf '%s' "$s" | tr '\n\r\t' '   ')"
    printf '%s' "$s"
}

# JSON array of strings from a newline list.
json_string_list() {
    local list="$1" out="[" first=1 x
    [ -z "$list" ] && { printf '[]'; return 0; }
    while IFS= read -r x; do
        [ -z "$x" ] && continue
        [ "$first" -eq 0 ] && out="${out},"
        out="${out}\"$(json_escape "$x")\""
        first=0
    done <<< "$list"
    printf '%s]' "$out"
}

# Lines of `diff a b` that changed (a rewrite count for one file).
count_rewrites() {
    local before="$1" after="$2"
    [ "$before" = "$after" ] && { printf '0'; return 0; }
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") 2>/dev/null | grep -c '^>' | tr -d ' '
}

truncate120() {
    local s="$1"
    if [ "${#s}" -gt 120 ]; then
        printf '%s' "${s:0:120}"
    else
        printf '%s' "$s"
    fi
}

is_dir_row() {
    case "$1" in plugin|mcp-server|path) return 0 ;; *) return 1 ;; esac
}

# ============================================================================
# Registry / project-registry / decisions resolution
# ============================================================================

REGISTRY_FILE=""
REGISTRY_SOURCE=""     # upstream | local
REGISTRY_ROWS=0
PROJECT_REGISTRY_FILE=""
PROJECT_REGISTRY_ROWS=0
DECISIONS_FILE="$REPO_ROOT/.logic-loom/config/migration-decisions.conf"

resolve_registry() {
    local explicit="$1"
    if [ -n "$explicit" ]; then
        [ -f "$explicit" ] || { echo "release-migrations.sh: registry not found: $explicit" >&2; exit 2; }
        REGISTRY_FILE="$explicit"
        REGISTRY_SOURCE="local"
        REGISTRY_ROWS="$(loom_migration_rows "$REGISTRY_FILE" 2>/dev/null | wc -l | tr -d ' ')" || true
        return 0
    fi
    if [ -n "${LOOM_MIGRATION_REGISTRY:-}" ]; then
        [ -f "$LOOM_MIGRATION_REGISTRY" ] || { echo "release-migrations.sh: registry not found: $LOOM_MIGRATION_REGISTRY" >&2; exit 2; }
        REGISTRY_FILE="$LOOM_MIGRATION_REGISTRY"
        REGISTRY_SOURCE="local"
        REGISTRY_ROWS="$(loom_migration_rows "$REGISTRY_FILE" 2>/dev/null | wc -l | tr -d ' ')" || true
        return 0
    fi
    local have_ref="false"
    if git -C "$REPO_ROOT" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1; then
        have_ref="true"
    fi
    if [ "$have_ref" = "true" ]; then
        local tmp
        tmp="$(mktemp "${TMPDIR:-/tmp}/loom-registry.XXXXXX")"
        if git -C "$REPO_ROOT" show refs/loom-upstream/main:.logic-loom/config/release-migrations.conf > "$tmp" 2>/dev/null; then
            _loom_rm_cleanup
            _LOOM_RM_TMP_REGISTRY="$tmp"
            REGISTRY_FILE="$tmp"
            REGISTRY_SOURCE="upstream"
            REGISTRY_ROWS="$(loom_migration_rows "$REGISTRY_FILE" 2>/dev/null | wc -l | tr -d ' ')" || true
            return 0
        fi
        rm -f "$tmp"
    fi
    local local_file
    local_file="$(loom_migrations_registry_path "$REPO_ROOT")"
    if [ -f "$local_file" ]; then
        REGISTRY_FILE="$local_file"
        REGISTRY_SOURCE="local"
        REGISTRY_ROWS="$(loom_migration_rows "$REGISTRY_FILE" 2>/dev/null | wc -l | tr -d ' ')" || true
        return 0
    fi
    echo "release-migrations.sh: registry not found" >&2
    exit 2
}

resolve_project_registry() {
    local explicit="$1"
    local candidate="$REPO_ROOT/.logic-loom/config/project-migrations.conf"
    if [ -f "$candidate" ]; then
        PROJECT_REGISTRY_FILE="$candidate"
        PROJECT_REGISTRY_ROWS="$(loom_migration_rows "$PROJECT_REGISTRY_FILE" 2>/dev/null | wc -l | tr -d ' ')" || true
    else
        PROJECT_REGISTRY_FILE=""
        PROJECT_REGISTRY_ROWS=0
    fi
}

registry_header_lines() {
    if [ "$REGISTRY_SOURCE" = "upstream" ]; then
        echo "registry: upstream (refs/loom-upstream/main, $REGISTRY_ROWS rows)"
    else
        echo "registry: local ($REGISTRY_ROWS rows)"
    fi
    if [ -n "$PROJECT_REGISTRY_FILE" ]; then
        echo "project registry: $PROJECT_REGISTRY_ROWS rows"
    else
        echo "project registry: none"
    fi
}

# ============================================================================
# --help
# ============================================================================

rm_show_help() {
    # Named rm_show_help, not show_help: extract-proposals.sh (sourced for
    # ADOPTED detection) defines its own show_help and would replace ours.
    cat <<'EOF'
release-migrations.sh — scan/plan/convert/lint/check-release for the
release-migration registry (.logic-loom/config/release-migrations.conf).

Usage:
  release-migrations.sh scan [--json] [--root <dir>] [--registry <file>]
  release-migrations.sh plan <name> [--root <dir>] [--registry <file>]
  release-migrations.sh convert <name> (--dry-run|--apply) [--customized-only] [--root <dir>] [--registry <file>]
  release-migrations.sh lint [--root <dir>] [--registry <file>]
  release-migrations.sh check-release [<vX.Y.Z>] [--since <tag>|auto] [--root <dir>] [--registry <file>]
  release-migrations.sh --help

scan          Evaluate every registry row (upstream/local + project-owned)
              against the working tree: deprecation items (plugin/mcp-server/
              path), content items, an undeclared-orphan pass, and a
              "Decisions in force" briefing when
              .logic-loom/config/migration-decisions.conf has any line.
              --json prints one object: {registry, rows, project_rows,
              release, orphan_check, items, dangling_hooks, dangling_mcp,
              decisions, summary}.

plan <name>   One item's block, its references, whether it is blocked, and
              the action text verbatim (never runs git or edits a protected
              file itself).

convert <name>
              Plugin-kind items only. Converts plugins/<name>/{skills,
              commands,agents,hooks,scripts,lib,config,templates,tests,
              README.md} into .claude/skills/ and .claude/agents/, writes
              nothing under plugins/, .claude/settings.json, .claude/commands/
              or .claude/hooks/. --dry-run prints the plan; --apply writes it
              and records `converted = <name>` in
              .logic-loom/config/migration-decisions.conf. --customized-only
              restricts to units touched since baseline (refuses when the
              baseline is unknown).

lint          Runs loom_migration_lint on the resolved registry, and on
              .logic-loom/config/project-migrations.conf when present.

check-release [<vX.Y.Z>] [--since <tag>|auto]
              Without --since: the release-declaration gate (§14.4 in
              .docs/guides/MIGRATION_GUIDE.md) — every release must declare
              a migration row, or a `none` row, for its version (defaulted
              from FRAMEWORK_VERSION in .logic-loom/config/architecture.conf).
              With --since: ALSO runs the removal guard first — every
              plugins/<x> or mcp-servers/<x> directory present at the given
              (or auto-resolved) previous release tag and absent from the
              working tree must have a registry row, or check-release fails.
              --since must resolve to a vX.Y.Z release tag (auto always does;
              an explicit ref that is not version-shaped — a branch, a sha —
              is rejected, since the guard's window check and a content row's
              before-proof are both version-ordering comparisons), and it must
              be strictly BELOW the release being checked (a --since at or
              after it is rejected too: it would prove every content row
              against its own post-fix content).

Every recommended git operation (`git rm`, `git mv`) and every `.mcp.json`
edit is printed as text only — this script never runs git, and edits nothing
under plugins/, .claude/settings.json, .claude/commands/, or .claude/hooks/.
Full guide: .docs/guides/MIGRATION_GUIDE.md
Framework sync background: .docs/guides/FRAMEWORK_SYNC_GUIDE.md
EOF
}

# ============================================================================
# lint
# ============================================================================

cmd_lint() {
    local registry_arg=""
    while [ $# -gt 0 ]; do
        case "$1" in
            # Round-6 finding (low): `shift 2` with `--root` as the LAST
            # argument (no value after it) leaves $# unchanged (bash's
            # `shift n` with n > $# is a silent no-op, unlike referencing
            # `$2` directly, which `set -u` would catch) — `$1` stays
            # `--root` forever and this loop never terminates. Require the
            # value to actually be there before shifting past it.
            --root) [ $# -ge 2 ] || die_usage "lint: --root requires a value"; shift 2 ;;
            --registry) registry_arg="$2"; shift 2 ;;
            *) die_usage "lint: unknown argument '$1'" ;;
        esac
    done
    resolve_registry "$registry_arg"
    echo "registry: $REGISTRY_SOURCE ($REGISTRY_ROWS rows)"
    local rc=0
    loom_migration_lint "$REGISTRY_FILE" || rc=1
    if [ -f "$REPO_ROOT/.logic-loom/config/project-migrations.conf" ]; then
        echo "project registry: .logic-loom/config/project-migrations.conf"
        loom_migration_lint "$REPO_ROOT/.logic-loom/config/project-migrations.conf" || rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        echo "lint: clean"
    fi
    return $rc
}

# ============================================================================
# check-release
# ============================================================================

normalize_version() {
    local v="$1"
    case "$v" in
        v*) printf '%s' "$v" ;;
        *) printf 'v%s' "$v" ;;
    esac
}

framework_version() {
    local conf="$REPO_ROOT/.logic-loom/config/architecture.conf"
    if [ ! -f "$conf" ]; then
        return 1
    fi
    local line
    line="$(grep -E '^FRAMEWORK_VERSION=' "$conf" | head -1)" || true
    [ -z "$line" ] && return 1
    printf '%s' "${line#FRAMEWORK_VERSION=}"
}

# ── content-row execution proof (finding 7: the release gate must EXECUTE
#    every content row of the release it checks, not merely count it) ─────

# The `fixture:<name>` token from a content row's note, or "".
_loom_rm_fixture_ref() {
    local note="$1" rest
    case "$note" in
        *fixture:*)
            rest="${note#*fixture:}"
            rest="${rest%%[;[:space:]]*}"
            printf '%s' "$rest" ;;
        *) printf '' ;;
    esac
    return 0
}

# Files under <tag>'s tree matching a literal path or glob `name` (one per
# line; empty when none). Read-only git only (ls-tree/cat-file).
_loom_rm_tag_matches() {
    local tag="$1" name="$2"
    case "$name" in
        *\**|*\?*)
            local all f
            all="$(git -C "$REPO_ROOT" ls-tree -r --name-only "$tag" -- . 2>/dev/null)" || all=""
            [ -z "$all" ] && return 0
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                case "$f" in $name) printf '%s\n' "$f" ;; esac
            done <<< "$all" ;;
        *)
            git -C "$REPO_ROOT" cat-file -e "$tag:$name" 2>/dev/null && printf '%s\n' "$name" ;;
    esac
    return 0
}

# rc 0 iff <content> exhibits the row's claimed PRE-FIX ("problem") state:
# fate=present -> the pattern must match (the bad content is there);
# fate=absent  -> the pattern must NOT match (the fix/marker is missing).
_loom_rm_is_problem_state() {
    local fate="$1" pattern="$2" content="$3"
    if printf '%s\n' "$content" | grep -qIE -- "$pattern"; then
        [ "$fate" = "present" ]
    else
        [ "$fate" = "absent" ]
    fi
}

# Finding 5: the .before/.after checks (verify_content_rows_execution, below)
# prove the row's PATTERN in isolation — running the regex helper directly
# against fixture text. They never prove that scan's REAL content-row
# discovery (emit_content_item / content_matches, defined later in this
# file — bash resolves them at call time, so the forward reference here is
# fine) actually reports an item, or correctly reports nothing, when that
# exact text sits on disk at the row's own target path. This builds a
# throwaway tree with the fixture content at <name>, then calls
# emit_content_item itself — the exact function scan/plan use — once in
# TEMPLATE mode and once in ADOPTED mode (with a synthetic receipt entry
# recording <name>, so ownership-scoping is exercised too, not bypassed):
# .before must produce an item in both modes; .after must produce none in
# either. Writes only inside its own mktemp tree, never $REPO_ROOT or the
# real registry/decisions files (REPO_ROOT is swapped locally and restored;
# DECISIONS_FILE stays pointed at the real repo — an UNRESTRICTED `keep =
# <name>` decision line there does match the synthetic row, but that only
# flips the item's recommendation to KEEP-AS-IS; item-or-no-item, which is
# all this proof reads, is decided by the pattern match before the decision
# lookup, so a decision line cannot mask a result).
# Prints one "check-release: ..." line per mismatch; rc 1 if any. A proof
# that cannot run (no scratch tree; a fixture that cannot be placed at
# <name>, e.g. a name spelled as a directory that content_matches could never
# match) is reported and FAILS too — a release gate that silently skips a
# proof passes a row scan can never fire, which is exactly the gap finding 5
# is about. This is an ADDITIONAL proof on top of the pattern-level one
# above, never the only one.
_loom_rm_verify_fixture_scan_path() {
    local label="$1" name="$2" fate="$3" pattern="$4" default="$5" before_file="$6" after_file="$7"
    local rc=0

    # Finding 5, at-use half (lint above covers the shipped registry; this
    # covers a project registry that was never linted, and is the check that
    # actually stands between $name and the mkdir/cp calls below that build a
    # real filesystem path out of it).
    if ! loom_path_traversal_safe "$name"; then
        echo "check-release: $label: fixture proof (scan path): row name '$name' is absolute or contains a '..' path segment — refusing to build a filesystem path from it"
        return 1
    fi

    # emit_content_item's ADOPTED-mode ownership scoping calls
    # adopt_file_recorded, which lives in extract-proposals.sh. check-release
    # never sources it (only scan/plan do, via _loom_rm_init_adopt_mode) —
    # source it here, once, function-defs only (guarded so a repeat call, or
    # a caller that already ran _loom_rm_init_adopt_mode, is a no-op).
    if ! command -v adopt_file_recorded >/dev/null 2>&1; then
        local saved_src_root="$REPO_ROOT" had_errexit="false"
        case "$-" in *e*) had_errexit="true" ;; esac
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/extract-proposals.sh"
        [ "$had_errexit" = "true" ] || set +e
        REPO_ROOT="$saved_src_root"
    fi

    # Call _loom_rm_proof_base DIRECTLY, never via `$(...)` — a command
    # substitution runs the function in a SUBSHELL, so the global
    # $_LOOM_RM_PROOF_BASE assignment inside it would be lost the instant
    # that subshell exits, leaving the EXIT-trap cleanup's own copy of
    # $_LOOM_RM_PROOF_BASE permanently empty (and, since the cleanup's
    # per-entry loop over $_LOOM_RM_PROOF_TMP_DIRS is itself gated on
    # $_LOOM_RM_PROOF_BASE being non-empty, that also silently skips —
    # every scratch tree this proof creates would leak). Calling it plain
    # runs it in the current shell, so the global assignment sticks; we then
    # read that same global rather than trust any stdout it printed.
    if ! _loom_rm_proof_base >/dev/null || [ -z "$_LOOM_RM_PROOF_BASE" ] || [ ! -d "$_LOOM_RM_PROOF_BASE" ]; then
        echo "check-release: $label: fixture proof (scan path): cannot create a scratch tree (mktemp -d failed) — the proof could not run, and a proof that cannot run is not a pass"
        return 1
    fi
    local base="$_LOOM_RM_PROOF_BASE"
    local tmp
    if ! tmp="$(mktemp -d "$base/fixtureproof.XXXXXX" 2>/dev/null)" || [ -z "$tmp" ]; then
        echo "check-release: $label: fixture proof (scan path): cannot create a scratch tree (mktemp -d failed) — the proof could not run, and a proof that cannot run is not a pass"
        return 1
    fi
    # NEWLINE-delimited append (never space-delimited — see the cleanup trap
    # at the top of this file for why a space in TMPDIR makes that unsafe).
    if [ -z "$_LOOM_RM_PROOF_TMP_DIRS" ]; then
        _LOOM_RM_PROOF_TMP_DIRS="$tmp"
    else
        _LOOM_RM_PROOF_TMP_DIRS="${_LOOM_RM_PROOF_TMP_DIRS}
$tmp"
    fi

    local rel_dir; rel_dir="$(dirname "$name")"
    [ "$rel_dir" = "." ] && rel_dir=""
    if [ -n "$rel_dir" ] && ! mkdir -p "$tmp/$rel_dir" 2>/dev/null; then
        echo "check-release: $label: fixture proof (scan path): cannot place the fixture at $name (mkdir -p $rel_dir failed under the scratch tree) — the proof could not run, and a proof that cannot run is not a pass"
        return 1
    fi

    local row
    row="$(printf 'content\t%s\t%s\tpattern:%s\t%s\t-\tv0.0.0\tproposal: p; why: w' \
        "$name" "$fate" "$pattern" "$default")"

    local saved_root="$REPO_ROOT" saved_mode="${ADOPT_MODE:-TEMPLATE}" saved_wrote="${ADOPT_WROTE:-}"
    local saved_id="${ITEM_ID_N:-0}" saved_items="${ITEMS_JSON:-}"
    local saved_pending="${PENDING_N:-0}" saved_kept="${KEPT_N:-0}"
    local phase src found mode_label

    for phase in before after; do
        src="$before_file"
        [ "$phase" = "after" ] && src="$after_file"
        if ! cp "$src" "$tmp/$name" 2>/dev/null; then
            echo "check-release: $label: fixture proof (scan path): cannot place the fixture at $name (is the row's name a real file path scan's content_matches could ever match?) — the proof could not run, and a proof that cannot run is not a pass"
            rc=1
            break
        fi

        for mode_label in TEMPLATE ADOPTED; do
            REPO_ROOT="$tmp"
            ADOPT_MODE="$mode_label"
            ADOPT_WROTE=""
            [ "$mode_label" = "ADOPTED" ] && ADOPT_WROTE="file"$'\t'"$name"
            ITEM_ID_N=0; ITEMS_JSON=""; PENDING_N=0; KEPT_N=0
            emit_content_item "upstream" "$row" "true" >/dev/null 2>&1
            found="false"
            [ -n "$ITEMS_JSON" ] && found="true"

            if [ "$phase" = "before" ] && [ "$found" != "true" ]; then
                echo "check-release: $label: fixture proof ($mode_label, scan path): the .before fixture at $name does NOT produce a scan item — emit_content_item found nothing"
                rc=1
            fi
            if [ "$phase" = "after" ] && [ "$found" != "false" ]; then
                echo "check-release: $label: fixture proof ($mode_label, scan path): the .after fixture at $name still produces a scan item — emit_content_item still fires"
                rc=1
            fi
        done
    done

    REPO_ROOT="$saved_root"; ADOPT_MODE="$saved_mode"; ADOPT_WROTE="$saved_wrote"
    ITEM_ID_N="$saved_id"; ITEMS_JSON="$saved_items"
    PENDING_N="$saved_pending"; KEPT_N="$saved_kept"
    return $rc
}

# Every content row of <version> must prove itself: its pattern is grounded
# in a real problem state (a copy from the previous release's tree, or a
# named fixture when no LogicLoom-shipped prior copy can exist), and it does
# not still match wherever the row claims the content is now fixed. Prints
# one precise "check-release: ..." line per failure; rc 1 if any. Never
# writes; every git call is read-only (ls-tree/cat-file/show).
verify_content_rows_execution() {
    local version="$1" content_prev="$2"
    local rows rc=0
    rows="$(loom_migration_rows_for_release "$version" "$REGISTRY_FILE" 2>/dev/null)" || rows=""
    [ -z "$rows" ] && return 0
    while IFS=$'\t' read -r kind name fate repl default first release note; do
        [ "$kind" = "content" ] || continue
        local pattern="${repl#pattern:}"
        local label="content row $name@$release"
        local fixture; fixture="$(_loom_rm_fixture_ref "$note")"

        # BEFORE: the pattern is grounded in a real prior/problem state.
        local before_src="" before_found="false" before_ok="false"
        if [ -n "$fixture" ]; then
            local bf="$REPO_ROOT/tests/fixtures/release-migrations/${fixture}.before"
            if [ -f "$bf" ]; then
                before_found="true"; before_src="fixture ${fixture}.before"
                _loom_rm_is_problem_state "$fate" "$pattern" "$(cat "$bf")" && before_ok="true"
            fi
        elif [ -n "$content_prev" ]; then
            # A glob names many files at the previous tag; the row is
            # grounded when ANY of them exhibits the problem state (the
            # first ls-tree match being clean proves nothing about the
            # rest), so every match is checked, not just the first.
            local bpaths bpath
            bpaths="$(_loom_rm_tag_matches "$content_prev" "$name")"
            while IFS= read -r bpath; do
                [ -z "$bpath" ] && continue
                before_found="true"
                before_src="${before_src}${before_src:+, }$content_prev:$bpath"
                if [ "$before_ok" != "true" ] \
                   && _loom_rm_is_problem_state "$fate" "$pattern" "$(git -C "$REPO_ROOT" show "${content_prev}:${bpath}" 2>/dev/null)"; then
                    before_ok="true"
                fi
            done <<< "$bpaths"
        fi
        if [ "$before_found" != "true" ]; then
            echo "check-release: $label: cannot verify — no copy of $name in ${content_prev:-<no previous release resolvable>} and no fixture: reference in its note"
            rc=1
        elif [ "$before_ok" != "true" ]; then
            echo "check-release: $label: pattern does not reproduce the claimed prior state (checked $before_src) — the pattern may be wrong"
            rc=1
        fi

        # AFTER: proof the content is now fixed, wherever that is checkable.
        if [ -n "$fixture" ]; then
            local af="$REPO_ROOT/tests/fixtures/release-migrations/${fixture}.after"
            if [ ! -f "$af" ]; then
                echo "check-release: $label: fixture ${fixture}.after is missing — a fixture: row needs both .before and .after"
                rc=1
            else
                local after_content; after_content="$(cat "$af")"
                if _loom_rm_is_problem_state "$fate" "$pattern" "$after_content"; then
                    echo "check-release: $label: its own fixture ${fixture}.after still exhibits the pre-fix pattern — the row claims this is fixed but the fixture doesn't show it"
                    rc=1
                fi
            fi
        else
            local current_matches current_matches_rc=0
            current_matches="$(content_matches "$name")" || current_matches_rc=$?
            # Round-6 finding (medium, fail-open): distinguish "the glob
            # legitimately matched nothing" (rc 0, no output — skip the
            # after-proof, same as before) from "the enumeration itself
            # failed" (rc != 0 — content_matches now propagates this; see
            # its own comment) — the latter proves nothing, so fail the
            # check loudly instead of silently skipping the after-proof.
            if [ "$current_matches_rc" -ne 0 ]; then
                echo "check-release: $label: could not enumerate current copies of $name — find exited $current_matches_rc (e.g. a subdirectory it cannot read); after-proof unverifiable, not skipped"
                rc=1
            elif [ -z "$current_matches" ]; then
                echo "check-release: $label: (no shipped current copy of $name — after-proof skipped)"
            else
                local cf
                while IFS= read -r cf; do
                    [ -z "$cf" ] && continue
                    local cur_content; cur_content="$(cat "$REPO_ROOT/$cf" 2>/dev/null)"
                    if _loom_rm_is_problem_state "$fate" "$pattern" "$cur_content"; then
                        echo "check-release: $label: current tree's own shipped copy ($cf) still exhibits the pattern's target state — the row claims this is fixed but it isn't"
                        rc=1
                    fi
                done <<< "$current_matches"
            fi
        fi

        # Finding 5: also run the real scan discovery path, not just the
        # pattern-level checks above — see _loom_rm_verify_fixture_scan_path.
        # Fixture-backed only (a git-history-grounded row already gets its
        # "after" proof from content_matches against the real tree, above);
        # skipped for a glob target, which needs a real multi-file tree the
        # .before/.after pair cannot stand in for — the pattern-level checks
        # already ground those. Gated on both files actually existing so a
        # missing-fixture failure (reported above) isn't reported twice.
        if [ -n "$fixture" ]; then
            case "$name" in
                *\**|*\?*) : ;;
                *)
                    if [ -f "$bf" ] && [ -f "$af" ]; then
                        _loom_rm_verify_fixture_scan_path "$label" "$name" "$fate" "$pattern" "$default" "$bf" "$af" || rc=1
                    fi ;;
            esac
        fi
    done <<< "$rows"
    return $rc
}

cmd_check_release() {
    local registry_arg="" version_arg="" since_arg=""
    local positional=()
    while [ $# -gt 0 ]; do
        case "$1" in
            # Round-6 finding (low): see cmd_lint's identical fix above —
            # `--root` as the last, valueless argument would hang this
            # loop forever without the bounds check.
            --root) [ $# -ge 2 ] || die_usage "check-release: --root requires a value"; shift 2 ;;
            --registry) registry_arg="$2"; shift 2 ;;
            --since) since_arg="$2"; shift 2 ;;
            -*) die_usage "check-release: unknown argument '$1'" ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    if [ "${#positional[@]}" -gt 1 ]; then
        die_usage "check-release: too many arguments"
    fi
    if [ "${#positional[@]}" -eq 1 ]; then
        version_arg="${positional[0]}"
    fi

    resolve_registry "$registry_arg"

    # Round-4 review: a row the parser refuses (wrong field count, or a
    # traversing name — _loom_parse_row in the lib) is dropped from every
    # row listing this gate reads, so without this the gate would report
    # "declares no migration" for a registry that DOES name the release —
    # just in a row it will not parse — and the real reason would be hidden
    # behind the 2>/dev/null every listing below uses. A release gate must
    # name the row it refused and fail on it, never pass over it silently.
    local parse_errs
    parse_errs="$(loom_migration_rows "$REGISTRY_FILE" 2>&1 >/dev/null)" || true
    if [ -n "$parse_errs" ]; then
        printf '%s\n' "$parse_errs" | sed 's/^/check-release: registry row refused: /'
        return 1
    fi

    if [ -z "$version_arg" ]; then
        local fv
        if ! fv="$(framework_version)"; then
            echo "check-release: FRAMEWORK_VERSION not found in .logic-loom/config/architecture.conf" >&2
            return 1
        fi
        version_arg="$fv"
    fi
    local version
    version="$(normalize_version "$version_arg")"

    local overall_rc=0

    # ── removal guard (--since), runs FIRST, regardless of the floor ───────
    # $prev is hoisted to function scope (not just this `if`) — finding 2's
    # content_prev, below, reuses whatever this block resolved instead of
    # silently recomputing its own and ignoring an explicit --since.
    local prev=""
    if [ -n "$since_arg" ]; then
        if [ "$since_arg" = "auto" ]; then
            # STRICTLY below $version (never $version's own tag — see
            # loom_latest_tag_below; finding 2). loom_latest_tag_below only
            # ever walks refs/tags/, so "auto" is unaffected by finding 3
            # below — it can never produce a branch name.
            prev="$(loom_latest_tag_below "$version" "$REPO_ROOT" 2>/dev/null)" || prev=""
        else
            # Take the tag as given; only if that does not resolve, try the
            # vX.Y.Z spelling (so `--since 6.6.2` and `--since v6.6.2` both
            # work and a non-version tag name is not mangled). This is a
            # SPELLING choice only — whether the settled spelling actually
            # names a real tag is decided below, uniformly.
            prev="$since_arg"
            if ! git -C "$REPO_ROOT" rev-parse -q --verify "${prev}^{commit}" >/dev/null 2>&1; then
                prev="$(normalize_version "$since_arg")"
            fi
        fi
        local prev_resolves="false" prev_is_version="false" prev_is_tag="false"
        if [ -n "$prev" ] && git -C "$REPO_ROOT" rev-parse -q --verify "${prev}^{commit}" >/dev/null 2>&1; then
            prev_resolves="true"
        fi
        # Finding 6: a glob (`v[0-9]*.[0-9]*.[0-9]*`) is loose — a `*` matches
        # ANY characters, not just digits, so it also accepts "v9x.0.0" and
        # "v8.0.0-rc1" as if they were plain vX.Y.Z releases; both then sail
        # through the version-ordering compare below (the numeric parser
        # silently truncates "9x" to "9" and "0-rc1" to "0"). Require the
        # strict anchored shape instead — digits only, in all three
        # components, start to end.
        if printf '%s' "$prev" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
            prev_is_version="true"
        fi
        # Finding 3: version-shaped text is not enough — it must resolve as
        # an ACTUAL TAG (refs/tags/<prev>), not merely as SOME ref that
        # happens to share the text. A branch named v6.6.2 resolves fine via
        # the plain `rev-parse <prev>^{commit}` above (git's short-name
        # lookup checks refs/heads too) and, before this check, would have
        # sailed through to the version-ordering compare despite never having
        # been a release.
        if [ -n "$prev" ] && git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/${prev}^{commit}" >/dev/null 2>&1; then
            prev_is_tag="true"
        fi
        if [ "$prev_resolves" != "true" ] && [ "$since_arg" = "auto" ]; then
            # Only "auto" may legitimately find nothing (a repo with no
            # earlier release tag at all): that is a fact about the repo,
            # not bad input, and skipping is the honest answer.
            echo "previous release: none resolvable — removal guard skipped"
            prev=""
        elif [ "$prev_resolves" != "true" ]; then
            # Finding 3, same principle as the two branches below: an
            # EXPLICIT --since that resolves to nothing (a typo, a tag that
            # was never fetched, a name that is not a ref here) is bad
            # input, and bad input is REJECTED — never silently downgraded to
            # "no baseline", which would skip the guard the caller
            # explicitly asked to run and exit 0 as if it had passed.
            echo "check-release: --since '$since_arg' does not resolve to any commit in this repository — the removal guard cannot run against it; pass a real version tag (e.g. --since v6.6.2) or --since auto"
            overall_rc=1
            prev=""
        elif [ "$prev_is_version" != "true" ]; then
            # Finding 3 (original half): the window validation below (a
            # removed item's registry row must date the removal to (prev,
            # version]) is a VERSION-ORDERING check. A non-version --since (a
            # branch, a sha, any ref that isn't version-shaped at all) has no
            # place in that ordering — silently falling back to a
            # (kind,name)-only match would accept a misdated/stale/future row
            # the guard exists to catch. Fail closed with a precise reason
            # instead of degrading the guard's meaning: pass a version tag,
            # or --since auto.
            echo "check-release: --since '$prev' does not resolve to a vX.Y.Z release tag — the removal guard's window check (a removed item's registry row must date the removal to (prev, version]) is a version-ordering comparison and cannot run against a non-version ref; pass a version tag (e.g. --since v6.6.2) or --since auto"
            overall_rc=1
            prev=""
        elif [ "$prev_is_tag" != "true" ]; then
            # Finding 3 (round-2 half): version-SHAPED text that is not
            # actually a release tag — e.g. a branch someone named v6.6.2 —
            # must be rejected the same way, with its own precise reason
            # (never silently treated as "no baseline" — that would SKIP the
            # guard instead of REJECTING the bad input, letting a misdated
            # row slide through unchecked).
            echo "check-release: --since '$prev' looks like a release (vX.Y.Z) but does not name an actual release tag — refs/tags/$prev does not exist (it may be a branch or other ref of the same name); pass a real version tag (e.g. --since v6.6.2) or --since auto"
            overall_rc=1
            prev=""
        elif ! _loom_version_lt "$prev" "$version"; then
            # An explicit --since AT or ABOVE the release being checked is
            # finding 2 reintroduced by hand: the removal guard's window
            # (prev, version] is empty or inverted, and a content row's
            # before-proof would read the row's PRIOR state from a tag that
            # already carries the fix (or from the very release under check)
            # and fail every row falsely, with a misleading "pattern may be
            # wrong". "Previous release" means strictly earlier; say so.
            echo "check-release: --since '$prev' is not BELOW the release being checked ($version) — the previous release must be strictly earlier: the removal guard's window is (prev, version] and a content row's before-proof reads its prior state from prev, so a --since at or after $version would prove every row against its own post-fix content and fail it falsely; pass an earlier version tag (e.g. --since v6.6.2) or --since auto"
            overall_rc=1
            prev=""
        else
            echo "previous release: $prev"
            local removed_dirs="" removed_declared="" removed_misdeclared="" misdeclared_detail=""
            local kind name dirpath
            local ls dep_rows
            ls="$(git -C "$REPO_ROOT" ls-tree -d --name-only "$prev" -- plugins/ mcp-servers/ 2>/dev/null)" || ls=""
            dep_rows="$(loom_deprecation_rows "$REGISTRY_FILE" 2>/dev/null)" || dep_rows=""
            # A deprecation row's `release` is "the first shipped tag that
            # lacks it" (registry header). An item present at $prev and gone
            # now was therefore removed in some release in ($prev, $version]
            # — a row dated outside that window is a STALE row (it claims an
            # earlier release already lacked the item, yet $prev still had
            # it) or a FUTURE row (it pre-declares a release not being cut),
            # and neither declares THIS release's removal. $prev is always
            # version-shaped by the time we get here (finding 3, above).
            local d
            for d in $ls; do
                [ -d "$REPO_ROOT/$d" ] && continue
                case "$d" in
                    plugins/*) kind="plugin"; name="${d#plugins/}" ;;
                    mcp-servers/*) kind="mcp-server"; name="${d#mcp-servers/}" ;;
                    *) continue ;;
                esac
                name="${name%/}"
                local row_release=""
                if [ -n "$dep_rows" ]; then
                    row_release="$(printf '%s\n' "$dep_rows" \
                        | awk -F'\t' -v k="$kind" -v n="$name" '$1 == k && $2 == n { print $7; exit }')"
                fi
                if [ -z "$row_release" ]; then
                    removed_dirs="$removed_dirs $d"
                elif { ! _loom_version_lt "$prev" "$row_release" || _loom_version_lt "$version" "$row_release"; }; then
                    removed_misdeclared="$removed_misdeclared $d"
                    misdeclared_detail="$misdeclared_detail $d (row says $row_release)"
                else
                    removed_declared="$removed_declared $d"
                fi
            done
            if [ -n "$removed_misdeclared" ]; then
                echo "check-release: removed since $prev but its registry row dates the removal outside ($prev, $version]:$misdeclared_detail — a deprecation row's release is the first shipped tag that lacks the item"
                overall_rc=1
            fi
            if [ -n "$removed_dirs" ]; then
                echo "check-release: removed since $prev without a registry row:$removed_dirs"
                overall_rc=1
            elif [ -n "$removed_misdeclared" ]; then
                :
            else
                if [ -n "$removed_declared" ]; then
                    echo "removals since $prev:$removed_declared (declared)"
                else
                    echo "removals since $prev: none"
                fi
            fi
            local none_row_here
            none_row_here="$(loom_migration_rows_for_release "$version" "$REGISTRY_FILE" 2>/dev/null | awk -F'\t' '$1 == "none"')" || none_row_here=""
            if [ -n "$none_row_here" ] && { [ -n "$removed_dirs" ] || [ -n "$removed_declared" ] || [ -n "$removed_misdeclared" ]; }; then
                local any_removed_dir
                any_removed_dir="$(printf '%s %s %s' "$removed_dirs" "$removed_declared" "$removed_misdeclared" | awk '{print $1}')"
                echo "check-release: contradiction: $version declares none but ${any_removed_dir} was removed since $prev"
                overall_rc=1
            fi
            local surface_n
            # Round-6 REVIEWER: same `--no-ext-diff --no-textconv` rule as
            # every other git diff in this file (see resolve_state) — this
            # count is descriptive, but one rule for every call site is
            # what the E7 source pin in the contract suite holds us to.
            surface_n="$(git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --name-only "$prev" -- plugins .logic-loom/config .logic-loom/lib .claude/settings.json .claude/hooks 2>/dev/null | wc -l | tr -d ' ')" || surface_n=0
            echo "adopter-facing surface since $prev: $surface_n file(s) changed under plugins/ .logic-loom/config .logic-loom/lib .claude/settings.json .claude/hooks"
            echo "structure verified; whether the declared rows are the right rows for those files is your call"
        fi
    fi

    # ── §14.4 half: floor + row-declaration gate ────────────────────────────
    if _loom_version_lt "$version" "v$LOOM_MIGRATION_GATE_FLOOR"; then
        echo "check-release: $version predates the migration registry (floor v$LOOM_MIGRATION_GATE_FLOOR) — not gated"
        return $overall_rc
    fi

    local rows
    rows="$(loom_migration_rows_for_release "$version" "$REGISTRY_FILE" 2>/dev/null)" || rows=""
    local row_count=0
    [ -n "$rows" ] && row_count="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
    local has_none="false"
    [ -n "$rows" ] && printf '%s\n' "$rows" | awk -F'\t' '$1 == "none" { found=1 } END { exit(found?0:1) }' && has_none="true" || true

    if [ "$row_count" -eq 0 ]; then
        echo "check-release: $version declares no migration. Add a row with release $version to .logic-loom/config/release-migrations.conf — a none row if nothing adopter-facing changed."
        overall_rc=1
    elif [ "$has_none" = "true" ] && [ "$row_count" -gt 1 ]; then
        echo "check-release: $version declares none AND $((row_count - 1)) other row(s) — contradiction"
        overall_rc=1
    fi

    # Every content row of the release being checked must be EXECUTED, not
    # merely declared (finding 7): prove its pattern is grounded in a real
    # prior/problem state, and that it does not still match the current
    # tree's own shipped "fixed" copy. A row whose target LogicLoom never
    # ships (a customer-generated file, or a PROPOSE-ADVISORY/KORI-CLASS row
    # on a fork-owned file) carries a `fixture:` note instead — see the
    # registry header comment.
    #
    # Finding 2: reuse whatever the removal guard above already resolved as
    # "the previous release" ($prev — set from an explicit --since when one
    # was given and it resolved) instead of silently recomputing a separate
    # answer that ignores --since. When no --since was given (or it did not
    # resolve), fall back to the newest tag STRICTLY BELOW $version — never
    # $version's own tag, which would prove a row's prior state against its
    # own post-fix content and fail it falsely (loom_latest_tag_below).
    local content_prev="$prev"
    if [ -z "$content_prev" ]; then
        content_prev="$(loom_latest_tag_below "$version" "$REPO_ROOT" 2>/dev/null)" || content_prev=""
    fi
    verify_content_rows_execution "$version" "$content_prev" || overall_rc=1

    local changelog="$REPO_ROOT/CHANGELOG.md"
    if [ -f "$changelog" ]; then
        local bare_version="${version#v}" re_version
        re_version="$(printf '%s' "$bare_version" | sed 's/\./\\./g')"
        if ! grep -qE "^## \[$re_version\]" "$changelog"; then
            echo "check-release: CHANGELOG.md has no ## [$bare_version] section — roll the CHANGELOG (/promote does this before the push)"
            overall_rc=1
        else
            if [ "$row_count" -gt 0 ] && [ "$has_none" != "true" ]; then
                local section
                section="$(awk -v v="$re_version" '
                    BEGIN { in_sec=0 }
                    /^## \[/ {
                        if (in_sec) { exit }
                        if ($0 ~ "^## \\[" v "\\]") { in_sec=1; next }
                    }
                    in_sec { print }
                ' "$changelog")"
                if ! printf '%s\n' "$section" | grep -qE '^### .*[Mm]igrat'; then
                    echo "check-release: CHANGELOG.md [$bare_version] lacks a ### Migrating… subsection"
                    overall_rc=1
                fi
            fi
        fi
    else
        echo "changelog: not present — skipped"
    fi

    if [ "$overall_rc" -eq 0 ]; then
        echo "check-release: $version declares $row_count migration row(s):"
        [ -n "$rows" ] && printf '%s\n' "$rows"
    fi
    return $overall_rc
}

# ============================================================================
# scan / plan / convert — shared item-evaluation helpers
# ============================================================================

# ADOPTED-repo detection, sourced once. extract-proposals.sh recomputes its
# own SCRIPT_DIR/REPO_ROOT on source (from ITS OWN BASH_SOURCE), so we save
# and restore our resolved REPO_ROOT around the source.
_loom_rm_init_adopt_mode() {
    local saved_root="$REPO_ROOT" had_errexit="false"
    case "$-" in *e*) had_errexit="true" ;; esac
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/extract-proposals.sh"
    # extract-proposals.sh runs `set -euo pipefail` at its top level; restore
    # OUR posture (see the header) so scan/plan behave exactly like convert.
    [ "$had_errexit" = "true" ] || set +e
    REPO_ROOT="$saved_root"
    detect_adopt_mode
}

# Names of every deprecation row in both registries (newline list).
all_deprecation_names() {
    local rows
    rows="$(loom_deprecation_rows "$REGISTRY_FILE" 2>/dev/null)" || rows=""
    if [ -n "$PROJECT_REGISTRY_FILE" ]; then
        local proj
        proj="$(loom_deprecation_rows "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || proj=""
        [ -n "$proj" ] && rows="${rows}"$'\n'"${proj}"
    fi
    [ -n "$rows" ] && printf '%s\n' "$rows" | awk -F'\t' 'NF >= 2 { print $2 }'
    return 0
}

declared_harness_plugins_local() {
    [ -f "$REPO_ROOT/CLAUDE.md" ] || return 0
    sed -n '/^## Plugin Registry/,/^## /p' "$REPO_ROOT/CLAUDE.md" \
        | grep -E '^\|[[:space:]]*`[A-Za-z0-9_.-]+`[[:space:]]*\|' \
        | sed -e 's/^|[[:space:]]*`//' -e 's/`.*$//'
    return 0
}

# POSIX single-quote a string for safe interpolation into an ADVISORY shell
# command this tool only ever PRINTS (never executes — see build_remove_cmd
# and the MOVE-command site below). Belt-and-suspenders alongside
# loom_path_traversal_safe's character whitelist (medium finding, round 5
# review): the lib already refuses a name/path that could break out of this
# quoting by the time it reaches here, but every printed command quotes its
# paths anyway so a future caller that skips the lib check is not silently
# unsafe.
#
# NOT a bash `${s//\'/\'\\\'\'}` parameter-substitution one-liner — that
# shape looks like the standard close-escape-reopen idiom but, empirically,
# bash does not expand its backslashes the way the visual pattern suggests:
# it emits `\'\\'\'` for a single embedded quote instead of the intended
# `'\''`, which is not even balanced-quote shell syntax (an `eval` of the
# resulting "quoted" command hits "unexpected EOF" rather than reproducing
# the original string) — silently defeating the entire point of this
# function for the one input it exists to handle. Found while adding test
# coverage for the medium finding (round 5 review) this function closes;
# fixed via `sed`, already a floor-safe dependency used elsewhere in this
# file, rather than a hand-rolled character-class expansion whose failure
# mode here was exactly the kind of subtle breakage this function is
# supposed to prevent.
shell_quote() {
    local s="$1"
    printf "'%s'" "$(printf '%s' "$s" | sed "s/'/'\\\\''/g")"
}

build_remove_cmd() {
    local kind="$1" name="$2" path="$3"
    case "$kind" in
        plugin) REC_REMOVE_CMD="git rm -r $(shell_quote "plugins/$name")" ;;
        mcp-server) REC_REMOVE_CMD="git rm -r $(shell_quote "mcp-servers/$name")" ;;
        path)
            if [ -d "$REPO_ROOT/$path" ]; then
                REC_REMOVE_CMD="git rm -r $(shell_quote "$path")"
            else
                REC_REMOVE_CMD="git rm $(shell_quote "$path")"
            fi ;;
        *) REC_REMOVE_CMD="" ;;
    esac
}

# Finding 1 (fix BY DESIGN, not a better heuristic): a local `v[0-9]*` tag
# MUST NEVER establish a baseline that can lead to REMOVE, full stop — not
# even one whose tree carries LogicLoom's own version stamp. The previous
# heuristic here (package.json name+version, or architecture.conf
# FRAMEWORK_VERSION) tried to tell "a LogicLoom release tag" apart from "an
# adopter's own semver tag that happens to share the vX.Y.Z shape" by
# checking whether the tag's CONTENT looks like LogicLoom's. That can never
# work in an ADOPTED install: an adopted repo legitimately CONTAINS
# LogicLoom's own files (that is what adoption means), so a customer tag on
# a customized, retired plugin can carry a perfectly genuine
# FRAMEWORK_VERSION stamp — or a hand-set package.json — and still not be a
# tag LogicLoom itself cut. No content stamp, however specific, can prove
# WHO tagged a commit. Only LogicLoom's own SYNC RECORD can: a ref this
# harness itself wrote (.sdd-sync-ref, refs/loom-upstream/main) or, in an
# ADOPTED install, the adopt receipt's own recorded sha256 for the exact
# file this harness itself wrote and hashed (_loom_rm_adopt_receipt_sha256
# below) — never a "does this commit look like ours" guess. With no such
# record, the item is UNKNOWN, and resolve_state()/compute_recommendation()
# always route UNKNOWN through the same branch as "customized" (never the
# `state = pristine` branch that leads to REMOVE). A tag is never consulted
# here, for display or anything else — there is nothing to prove it is safe
# to look at, and a "display-only" fork of this logic would be exactly the
# kind of parallel heuristic this fix is meant to close.

# ADOPTED-only: the sha256 an adopted install's own receipt
# (.logicloom-adopt-receipt.json) recorded the last time LogicLoom itself
# wrote <path> — never guessed, read straight from the one record LogicLoom
# itself produced. Unlike a tag, this is not "does this commit look like a
# release" content-sniffing — it is "did LogicLoom's own writer
# (record-update-writes.sh / packaging/adopt's apply.js) record THIS exact
# path with THIS exact hash". Only ever matches a `kind:"file"` entry, so it
# naturally never fires for a plugin/mcp-server directory (those are
# recorded, if at all, as `kind:"dir"` — presence only, no hash, and
# presence alone proves nothing about whether the directory has since been
# customized). This function alone is still trust-on-read from a plain,
# adopter-editable JSON file, exactly like a tag's content would be —
# nothing here signs it; see _loom_rm_receipt_sha256_corroborated below for
# the actual forgery gate REMOVE requires on top of this. Empty stdout + rc 1
# when the receipt is absent, unparsable,
# python3 is unavailable, or it never recorded a file write for this path —
# every one of those falls through to the next baseline candidate, never to
# a false "pristine".
# Cache: a scan/plan run calls this once PER REGISTRY ROW (up to ~25+ in the
# real registry, more with project rows), and re-spawning python3 to reparse
# the whole receipt for each one is real, avoidable overhead. Parsed once per
# $REPO_ROOT per process and memoized here as "path<TAB>sha256" lines; every
# call after the first is a plain awk lookup against this in-memory cache,
# never a second subprocess.
_LOOM_RM_RECEIPT_CACHE_ROOT=""
_LOOM_RM_RECEIPT_CACHE=""
_LOOM_RM_RECEIPT_CACHE_OK="false"

_loom_rm_adopt_receipt_sha256() {
    local path="$1"
    local receipt="$REPO_ROOT/.logicloom-adopt-receipt.json"
    [ -f "$receipt" ] || return 1
    if [ "$_LOOM_RM_RECEIPT_CACHE_ROOT" != "$REPO_ROOT" ]; then
        _LOOM_RM_RECEIPT_CACHE_ROOT="$REPO_ROOT"
        _LOOM_RM_RECEIPT_CACHE=""
        _LOOM_RM_RECEIPT_CACHE_OK="false"
        if command -v python3 >/dev/null 2>&1; then
            _LOOM_RM_RECEIPT_CACHE="$(python3 - "$receipt" <<'PY' 2>/dev/null
import json, re, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    if not isinstance(data, dict) or data.get('schema') != 'logicloom/adopt-receipt@1' or not isinstance(data.get('runs'), list):
        sys.exit(1)
    # Finding 2: a digest is trustworthy ONLY when the run that recorded it
    # was written by one of the two writers LogicLoom itself owns -- the npm installer
    # (packaging/adopt/lib/apply.js, generator "logicloom@<version>") or the
    # v7 recorder (record-update-writes.sh, generator
    # "logicloom-update-framework@<version>") -- AND that run finished
    # ('status': 'complete'; 'partial'/'in-progress' means the writer itself
    # is not vouching for the bytes it left behind). Anything else -- a
    # foreign/absent generator, a wrong status, a malformed run -- is a run
    # this receipt reader does not trust, so it is skipped entirely: not used
    # to establish a digest, and not used to invalidate one either. The
    # receipt is adopter-editable, so "it says LogicLoom wrote this" is
    # exactly the kind of unproven claim this baseline must never act on.
    generator_re = re.compile(r'^(logicloom|logicloom-update-framework)@.+$')
    files = {}
    for run in data['runs']:
        if not isinstance(run, dict) or run.get('status') != 'complete':
            continue
        if not generator_re.match(str(run.get('generator') or '')):
            continue
        for w in (run.get('wrote') or []):
            if not isinstance(w, dict):
                continue
            if w.get('kind') == 'file':
                p = w.get('path')
                if p:
                    # NOTE: this heredoc sits inside a $( ) substitution and
                    # bash 3.2 does not skip comments while scanning for the
                    # closing paren -- no quotes or parens in comments here.
                    # Both real writers store the digest as sha256:<hex> --
                    # packaging/adopt/lib/fsops.js sha256File, and the JSON
                    # helper sha256 op in record-update-writes.sh -- so
                    # normalize to bare lowercase hex, which is what
                    # _loom_rm_sha256_file prints and resolve_state compares
                    # against. Anything that is not a 64-hex digest after
                    # that is unusable. Last writer wins across runs,
                    # unusable included: a later write with no usable digest
                    # must not let an earlier run digest vouch for bytes it
                    # never saw.
                    s = str(w.get('sha256') or '').strip().lower()
                    if s.startswith('sha256:'):
                        s = s[7:]
                    if not re.match(r'^[0-9a-f]{64}$', s):
                        s = ''
                    files[p] = s
    for p, sha in files.items():
        if sha:
            sys.stdout.write(p + '\t' + sha + '\n')
except Exception:
    sys.exit(1)
PY
)"
            [ -n "$_LOOM_RM_RECEIPT_CACHE" ] && _LOOM_RM_RECEIPT_CACHE_OK="true"
        fi
    fi
    [ "$_LOOM_RM_RECEIPT_CACHE_OK" = "true" ] || return 1
    local sha
    sha="$(printf '%s\n' "$_LOOM_RM_RECEIPT_CACHE" | awk -F'\t' -v p="$path" '$1 == p { print $2; exit }')"
    [ -n "$sha" ] || return 1
    printf '%s' "$sha"
    return 0
}

# sha256 of a file's current on-disk bytes (python3 only — matches the
# hashing record-update-writes.sh itself used to fill the receipt, so a
# comparison against _loom_rm_adopt_receipt_sha256 is meaningful). Empty
# stdout + rc 1 when python3 is unavailable or the file cannot be read.
#
# Round-5 finding 5 (medium, symlink-follow): `[ -f "$f" ]` and Python's
# open() both DEREFERENCE a symlink — true/readable for a symlink to a
# regular file, same as this diff's other read/write paths refuse to do
# (see _loom_rm_refuse_existing_symlink_target and the sibling `[ -L ... ]`
# guards throughout this file). Without this check, a customer's OWN
# symlink at a receipt-recorded path whose TARGET happens to byte-match the
# recorded digest reads back as "pristine" here — resolve_baseline/
# resolve_state then drive a REMOVE recommendation whose `git rm` deletes
# the symlink ENTRY itself (not the target, which lives elsewhere and is
# untouched — still a narrower harm than deleting real content, but still
# removing a path this tool did not create). `[ -L ]` before `[ -f ]`
# refuses the symlink outright: both callers (resolve_baseline,
# resolve_state) already treat this function's failure as "cannot confirm
# pristine" -> customized/no-match, never as license to proceed — doubt ->
# KEEP, no other code path to touch.
_loom_rm_sha256_file() {
    local f="$1"
    [ -L "$f" ] && return 1
    # Round-5 REVIEWER (high, data-loss): the round-5 `[ -L ]` above looks at
    # the FINAL component only. `[ -f ]` and open() both resolve a symlink
    # at any PARENT directory just as readily — `docs -> <outside dir>` with
    # a byte-identical docs/old-note.md on its far side hashed clean, the
    # receipt candidate won in resolve_baseline (a receipt match beats a
    # stale sync-ref by design), resolve_state read it as pristine, and the
    # printed `git rm 'docs/old-note.md'` — run in the reproduction —
    # DELETED the file at the link's target, outside the repository: git rm
    # unlinks by path and the kernel resolves the directory link. git's own
    # diff already reports a tracked file behind a symlinked leading path
    # as deleted (so the sync-ref/upstream baselines were safe); this route
    # never asks git, so it applies the same rule itself. Same walk
    # record-update-writes.sh's _path_has_symlink_ancestor does.
    local _sf_rel="${f#"$REPO_ROOT"/}"
    if [ "$_sf_rel" != "$f" ] && _loom_rm_path_has_symlink_ancestor "$_sf_rel" >/dev/null; then
        return 1
    fi
    [ -f "$f" ] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    local sha
    sha="$(python3 - "$f" <<'PY' 2>/dev/null
import hashlib, sys
try:
    h = hashlib.sha256()
    with open(sys.argv[1], 'rb') as fh:
        for chunk in iter(lambda: fh.read(65536), b''):
            h.update(chunk)
    sys.stdout.write(h.hexdigest())
except Exception:
    sys.exit(1)
PY
)" || return 1
    [ -n "$sha" ] || return 1
    printf '%s' "$sha"
    return 0
}

# Same as _loom_rm_sha256_file but hashes STDIN — used to hash a blob's
# content straight from `git show <commit>:<path>` without ever writing it
# to disk. Empty stdout + rc 1 when python3 is unavailable.
_loom_rm_sha256_stdin() {
    command -v python3 >/dev/null 2>&1 || return 1
    local sha
    sha="$(python3 -c '
import hashlib, sys
h = hashlib.sha256()
h.update(sys.stdin.buffer.read())
sys.stdout.write(h.hexdigest())
' 2>/dev/null)" || return 1
    [ -n "$sha" ] || return 1
    printf '%s' "$sha"
    return 0
}

# Round-5 REVIEWER (high, data-loss). rc 0 + prints the DEEPEST ancestor
# directory of repo-relative $1 (any component between REPO_ROOT and the
# entry itself — the entry excluded) that is a symlink on disk; rc 1 +
# empty stdout when none is. Why the entry itself is excluded: a tracked
# symlink at the FINAL component is something upstream can legitimately
# ship, git diff reports a type change when the customer swapped one in,
# and `git rm` on it removes only the link entry — so that case already
# resolves correctly through the baseline compare. A symlinked ANCESTOR is
# different in kind: every path under it names bytes that live wherever
# the link points (reproduced: outside the repository entirely), git's
# tracked-file view of it is a deletion, and a `git rm` of a path through
# it unlinks the file AT the target. Nothing under such a directory can be
# proven LogicLoom's, so resolve_state treats the item as customized
# (doubt -> KEEP and ASK) and _loom_rm_sha256_file refuses to hash through
# it at all. Pure lstat, no git — the same walk record-update-writes.sh's
# _path_has_symlink_ancestor and this file's own
# _loom_rm_refuse_symlink_parents already do for their own paths.
_loom_rm_path_has_symlink_ancestor() {   # $1 = repo-relative path
    local check
    check="$(dirname -- "$1")"
    while [ "$check" != "." ] && [ "$check" != "/" ] && [ -n "$check" ]; do
        if [ -L "$REPO_ROOT/$check" ]; then
            printf '%s' "$check"
            return 0
        fi
        check="$(dirname -- "$check")"
    done
    return 1
}

# Round-5 REVIEWER (medium, twice). Prints, one line each, what this
# repository's own git listings are structurally BLIND to under directory
# $1 — two things resolve_state's `ls-files --others [--ignored]` + `diff
# --quiet` pristine test could not see, so a directory holding either read
# as pristine and got the REMOVE recommendation (reproduced for both); the
# round-6 REVIEWER added two more of the same class at the bottom (a
# special file, an empty directory — see there):
#   (1) a NESTED GIT REPOSITORY — a `.git` directory (the customer ran
#       `git init` inside a retired plugin to keep their own history of it)
#       or a `.git` gitdir-pointer FILE (what `git worktree` writes). The
#       outer repository's git never lists anything under a nested
#       repository as untracked and its diff stays clean, while the nested
#       history — commits, stashes, unpushed work — is bytes nobody but the
#       customer owns, and `git rm -r` of the parent would strand it.
#   (2) a SUBDIRECTORY THIS USER CANNOT READ (mode 000, another account's
#       leftover, a container run): `git ls-files --others` lists nothing
#       under it and still exits 0, so a customer file behind that door was
#       invisible to every listing. `find` does fail (non-zero exit) on it,
#       which is the same signal unconverted_plugin_files() already treats
#       as "an enumeration that did not complete proves nothing about the
#       tree" (reviewer round 2) — applied here too.
# Empty output when neither applies, or when $1 is not a real directory (a
# `path`-kind row naming a file; a symlinked directory, which the
# leading-symlink rule above already makes customized and which is never
# walked through). Each line is a description a human reads, not a bare
# path: it lands under `added` so the item is customized, never pristine.
# Doubt -> KEEP and ASK. No git; `find` never follows symlinks (no -L) and
# never descends into a `.git` it finds (-prune), so the listing is cheap
# even for a large nested repository.
_loom_rm_git_blind_spots() {   # $1 = repo-relative directory
    local _bs_abs="$REPO_ROOT/$1" _bs_nested _bs_rc=0 _bs_n
    [ -d "$_bs_abs" ] || return 0
    [ -L "$_bs_abs" ] && return 0
    _bs_nested="$(find "$_bs_abs" -mindepth 1 -name .git -prune -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || _bs_rc=$?
    if [ "$_bs_rc" -ne 0 ]; then
        printf '%s/ (could not fully enumerate this directory: find exited %s, e.g. a subdirectory this user cannot read; nothing under it can be verified as LogicLoom-written)\n' "$1" "$_bs_rc"
    fi
    if [ -n "$_bs_nested" ]; then
        while IFS= read -r _bs_n; do
            [ -z "$_bs_n" ] && continue
            printf '%s (a nested git repository: its history, and any file tracked only there, is invisible to git in this repository and is nobody but yours)\n' "$_bs_n"
        done <<< "$_bs_nested"
    fi
    # Round-6 REVIEWER (low — parity with the round-2 empty-directory
    # finding, which closed this on the convert side only): two more
    # things git's own listings structurally cannot see, reproduced as
    # state pristine / REMOVE with added_files [] on the scan side:
    #   (3) a SPECIAL FILE — a named pipe, a socket, a device node. git's
    #       directory walker drops every entry that is not a regular file,
    #       symlink or directory (dir.c: path_none), so `ls-files --others`
    #       never lists one, with or without --ignored, and it cannot be
    #       tracked, so `diff` is clean. `find ! -type d ! -type f ! -type l`
    #       is exactly that set.
    #   (4) an EMPTY DIRECTORY — git tracks no directories, so an empty one
    #       is nowhere in any listing. `git rm -r` leaves both behind (they
    #       hold no tracked bytes), so nothing is lost by the printed
    #       command — but a REMOVE recommendation claims the path holds
    #       nothing but LogicLoom's bytes, and it also holds a node this
    #       tool never created and, until now, never saw. Same disposition
    #       as unconverted_plugin_files' `-empty` listing ("nothing converts
    #       or lists it either"): named under `added`, never pristine, the
    #       user is asked. Both walks prune `.git` like the one above and
    #       fail closed the same way when they cannot complete.
    # Only walked when the `.git` walk above completed: an enumeration
    # failure is already reported once, by that walk, and a second or third
    # copy of the same line would only pad `added` with duplicates.
    local _bs_special="" _bs_empty="" _bs_rc2=0
    if [ "$_bs_rc" -eq 0 ]; then
        _bs_special="$(find "$_bs_abs" -mindepth 1 -name .git -prune -o \( ! -type d ! -type f ! -type l \) -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || _bs_rc2=$?
        if [ "$_bs_rc2" -eq 0 ]; then
            _bs_empty="$(find "$_bs_abs" -mindepth 1 -name .git -prune -o -type d -empty -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || _bs_rc2=$?
        fi
        if [ "$_bs_rc2" -ne 0 ]; then
            printf '%s/ (could not fully enumerate this directory: find exited %s, e.g. a subdirectory this user cannot read; nothing under it can be verified as LogicLoom-written)\n' "$1" "$_bs_rc2"
        fi
    fi
    if [ -n "$_bs_special" ]; then
        while IFS= read -r _bs_n; do
            [ -z "$_bs_n" ] && continue
            printf '%s (a special file — named pipe, socket or device node: git never lists or tracks one, so nothing about it is LogicLoom-written; a `git rm -r` would leave it behind, but this path is not only LogicLoom bytes)\n' "$_bs_n"
        done <<< "$_bs_special"
    fi
    if [ -n "$_bs_empty" ]; then
        while IFS= read -r _bs_n; do
            [ -z "$_bs_n" ] && continue
            printf '%s/ (an empty directory — holds no bytes, and git never lists or tracks one, so nothing created it but you; a `git rm -r` would leave it behind, but this path is not only LogicLoom bytes)\n' "$_bs_n"
        done <<< "$_bs_empty"
    fi
    return 0
}

# TRUST BOUNDARY (medium finding, round 5 review — documented here AND in
# .docs/guides/MIGRATION_GUIDE.md's "Trust boundary — the adopt receipt"
# section, per the finding's own instruction; we do NOT invent crypto to
# close this, only add a cheap corroboration on top of what already exists).
#
# .logicloom-adopt-receipt.json is a plain, hand-editable JSON file
# committed in the adopter's own repo. _loom_rm_adopt_receipt_sha256 already
# restricts it to entries a TRUSTED GENERATOR STRING wrote with status
# "complete" — but the generator string and the recorded digest are both
# just bytes in that same hand-editable file; nothing stops someone from
# hand-writing an entry that claims "logicloom@2.0.0" wrote a customer's own
# file and records that file's own hash as "the pristine LogicLoom copy".
# resolve_baseline would then read the customer's unmodified bytes as
# byte-identical to that forged "pristine" record and recommend REMOVE on
# work that was never LogicLoom's. This is the SAME local, unsigned trust
# model as .sdd-sync-ref (see loom_sync_ref_is_loom_record's own comment)
# and refs/loom-upstream/main itself: all three are records this repo's own
# git history can edit, never cryptographically signed, and nothing in this
# tool invents signing to close that gap.
#
# What IS cheap to add: a receipt-recorded digest may authorize REMOVE only
# when that EXACT digest ALSO equals the sha256 of some blob LogicLoom
# itself shipped at this same path, per refs/loom-upstream/main's own
# history (every commit that ever touched the path there, not only the
# tip — a file's pristine content moves across releases, and the sync-ref
# commit itself is one point in that history, already covered by walking
# it). Forging a receipt entry to pass this now also requires forging a
# matching commit in refs/loom-upstream/main — a strictly higher bar than
# editing one JSON file, even though neither is cryptographic proof.
# Uncorroborated (no refs/loom-upstream/main locally, or no historical blob
# at this path ever hashed to this digest): rc 1, and the caller
# (resolve_baseline) must treat the receipt candidate as if it did not
# exist — fall through to sync-ref/upstream/none, never trust it alone.
# Doubt -> KEEP and ASK, never a silent REMOVE. Read-only git only.
_loom_rm_receipt_sha256_corroborated() {
    local path="$1" want_sha="$2"
    [ -n "$path" ] && [ -n "$want_sha" ] || return 1
    git -C "$REPO_ROOT" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 || return 1
    local commits commit got_sha
    commits="$(git -C "$REPO_ROOT" log --format=%H refs/loom-upstream/main -- "$path" 2>/dev/null)" || return 1
    [ -n "$commits" ] || return 1
    while IFS= read -r commit; do
        [ -n "$commit" ] || continue
        git -C "$REPO_ROOT" cat-file -e "$commit:$path" 2>/dev/null || continue
        got_sha="$(git -C "$REPO_ROOT" show "$commit:$path" 2>/dev/null | _loom_rm_sha256_stdin)" || continue
        [ "$got_sha" = "$want_sha" ] && return 0
    done <<EOF
$commits
EOF
    return 1
}

# .sdd-sync-ref is LogicLoom's own record ONLY in the shape LogicLoom itself
# writes it — `git rev-parse` output, a hex object name (KNOWN_ISSUES.md's
# manual repair writes the same) — AND ONLY when refs/loom-upstream/main
# (the ad-hoc fetch extract-proposals.sh maintains) exists locally and
# REACHES that commit. That reachability test is not new policy: it is the
# exact validity rule /update-framework already applies (extract-proposals.sh
# refuses to proceed from a sync-ref that is "NOT reachable from upstream
# main"); the scanner merely stops being looser than the update path about
# the same file. Why it matters here: a customer who writes their OWN commit
# into the file — or a symbolic name (HEAD, a branch) that resolves to one —
# has not produced a LogicLoom record, and diffing the working tree against
# their own commit reads their customized bytes as "pristine", the exact
# route to a REMOVE recommendation on a customer's work.
#
# Round 2 (shared with the recorder — record-update-writes.sh's
# resolve_sync_ref/upstream_blob_sha apply the SAME rule via the SAME
# function): with refs/loom-upstream/main absent, hex shape alone is NEVER
# enough — there is no baseline to prove reachability against, so the item
# is UNKNOWN, not "the shape stands on its own". Moved into the shared lib
# (loom_sync_ref_is_loom_record, .logic-loom/lib/release-migrations.sh) so
# both callers enforce one rule instead of two copies drifting apart.
_loom_rm_sync_ref_is_loom_record() {
    loom_sync_ref_is_loom_record "$1" "$REPO_ROOT"
}

# LogicLoom's own sync record: .sdd-sync-ref (only when it is provably
# LogicLoom's — _loom_rm_sync_ref_is_loom_record above), the (ADOPTED only)
# adopt receipt's recorded sha256 for this exact file, then
# refs/loom-upstream/main. NEVER a tag (finding 1 — see the block comment
# above). Read-only git only.
#
# ORDERING (cross-file finding: a receipt-sha256 candidate that byte-matches
# disk wins over a sync-ref candidate that exists but does not — never the
# reverse, and never dropped silently): .sdd-sync-ref is advanced only at
# /update-framework Step 6/8, AFTER record-update-writes.sh runs at Step
# 5/7b (see upstream_blob_sha's block comment in record-update-writes.sh).
# For a MODIFIED path — the common case a retired/replaced file falls under
# — the pre-advance .sdd-sync-ref commit still has SOME version of the path,
# so "sync-ref exists for this path" alone is true well before the sync-ref
# blob reflects what LogicLoom just wrote. Picking sync-ref on existence
# alone, unconditionally, would make the receipt-sha256 route (finding 1's
# ADOPTED fix) a dead branch for exactly the case it was built to cover:
# it would never be consulted, because the stale-but-present sync-ref
# candidate always wins first. So when a receipt-sha256 candidate exists,
# check it FIRST: if the file's current on-disk bytes are byte-identical to
# what LogicLoom's own receipt recorded there, that is proof by the same
# OWNERSHIP RULE record-update-writes.sh's own two-candidate resolver
# relies on (a byte-identical copy of a LogicLoom-recorded digest can only
# have come from LogicLoom) — return it regardless of what sync-ref says.
# Only when the receipt candidate does NOT match disk (customized since
# recorded, or no receipt entry at all) does a sync-ref candidate that DOES
# resolve take over; this is unchanged from before. A receipt candidate
# that matches neither disk nor exists falls through the same as ever —
# never a stronger claim than sync-ref, only ever a matching, provable one.
# Prints "sync-ref:S" | "receipt-sha256:H" | "upstream:D^" | "none".
resolve_baseline() {
    local path="$1"
    local sync_baseline=""
    if [ -f "$REPO_ROOT/.sdd-sync-ref" ]; then
        local sync_ref
        sync_ref="$(tr -d '[:space:]' < "$REPO_ROOT/.sdd-sync-ref" 2>/dev/null)" || sync_ref=""
        if _loom_rm_sync_ref_is_loom_record "$sync_ref" \
           && git -C "$REPO_ROOT" cat-file -e "$sync_ref:$path" 2>/dev/null; then
            sync_baseline="sync-ref:$sync_ref"
        fi
    fi
    if [ "${ADOPT_MODE:-TEMPLATE}" = "ADOPTED" ]; then
        local recorded_sha
        if recorded_sha="$(_loom_rm_adopt_receipt_sha256 "$path")" && [ -n "$recorded_sha" ] \
           && _loom_rm_receipt_sha256_corroborated "$path" "$recorded_sha"; then
            local current
            if current="$(_loom_rm_sha256_file "$REPO_ROOT/$path")" && [ -n "$current" ] \
               && [ "$current" = "$recorded_sha" ]; then
                printf 'receipt-sha256:%s' "$recorded_sha"
                return 0
            fi
            if [ -z "$sync_baseline" ]; then
                printf 'receipt-sha256:%s' "$recorded_sha"
                return 0
            fi
        fi
    fi
    if [ -n "$sync_baseline" ]; then
        printf '%s' "$sync_baseline"
        return 0
    fi
    if git -C "$REPO_ROOT" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1; then
        local d
        d="$(git -C "$REPO_ROOT" rev-list -n1 refs/loom-upstream/main -- "$path" 2>/dev/null)" || d=""
        if [ -n "$d" ] && git -C "$REPO_ROOT" cat-file -e "${d}^:$path" 2>/dev/null; then
            printf 'upstream:%s^' "$d"
            return 0
        fi
    fi
    # No provable LogicLoom baseline: never let an unproven baseline read as
    # pristine (that would authorize REMOVE on a customized item). "none" ->
    # resolve_state() -> STATE=unknown, which compute_recommendation() always
    # routes through the SAME branch as "customized" (never through the
    # `state = pristine` branch that leads to REMOVE).
    printf 'none'
    return 0
}

# Round-3 REVIEWER finding (high, data-loss): `git diff` and `git status`
# TRUST THE INDEX for an entry flagged skip-worktree (`git update-index
# --skip-worktree`, tag `S` in `ls-files -v`) or assume-unchanged
# (`--assume-unchanged`, a LOWERCASE tag) — they never stat the working
# tree for it, so a local edit to such a file is invisible to every
# "unchanged since <commit>" test this script makes. Both flags are
# ordinary, documented git usage (sparse checkouts, "keep my local copy of
# this config"), and a tracked plugin file carrying one read as pristine:
# scan said REMOVE, plan printed `git rm -r plugins/<p>`. Reproduced on a
# scratch repo — and with assume-unchanged, running that printed command
# DELETED the edited file outright (git rm does not re-check a worktree it
# was told not to look at). Nothing this script can diff proves anything
# about such an entry, so it is customized/changed by construction: doubt
# -> KEEP and ASK. Prints the flagged paths under <path> (git's own
# possibly C-quoted spelling — descriptive only; the decision reads only
# whether the list is empty). Read-only git only (ls-files).
_loom_rm_index_hidden_paths() {   # $1 = repo-relative path
    # Round-6 finding (high, fail-open): this used to end with an
    # unconditional `return 0`, discarding whatever exit status the
    # `git ls-files -v | awk` pipeline actually produced. Under this
    # script's `set -o pipefail`, that pipeline's real status already
    # reflects a git failure (permission issue, corrupt index, anything
    # that makes `ls-files` exit non-zero) as long as awk itself succeeds —
    # but the `return 0` threw that signal away, so the caller could not
    # tell "git failed, nothing proven" from "git succeeded and found
    # nothing hidden", the exact fail-open class this same round's review
    # already named for resolve_state's untracked/ignored captures. Return
    # the pipeline's own status instead of masking it.
    local _rc
    git -C "$REPO_ROOT" ls-files -v -- "$1" 2>/dev/null | awk '
        { tag = substr($0, 1, 1) }
        tag == "S" || tag ~ /^[a-z]$/ { print substr($0, 3) }'
    _rc=$?
    return "$_rc"
}

# Sets STATE, STATE_CHANGED, STATE_ADDED, STATE_DELETED (newline lists).
resolve_state() {
    local path="$1" baseline="$2"
    STATE_CHANGED=""; STATE_ADDED=""; STATE_DELETED=""
    if [ "$baseline" = "none" ]; then
        STATE="unknown"
        return 0
    fi
    # Round-5 REVIEWER (high, data-loss): a symlinked ANCESTOR directory is
    # customized by construction for EVERY baseline kind, decided here once
    # rather than left to each branch — see _loom_rm_path_has_symlink_ancestor.
    # The git-baseline branch below was already safe in practice (git diff
    # reports a tracked file behind a symlinked leading path as deleted),
    # but the receipt-sha256 branch never consults git and read straight
    # through the link to a pristine hash; making the rule explicit here
    # means neither branch depends on a git internal for it.
    local _rs_symanc
    if _rs_symanc="$(_loom_rm_path_has_symlink_ancestor "$path")" && [ -n "$_rs_symanc" ]; then
        STATE="customized"
        STATE_CHANGED="$_rs_symanc (a directory on this path is a symlink -> $(readlink "$REPO_ROOT/$_rs_symanc" 2>/dev/null): the bytes under it live wherever that link points, not at this path, and nothing there is proven LogicLoom-written)"
        return 0
    fi
    case "$baseline" in
        receipt-sha256:*)
            # No git ref to diff against — the receipt names one file and one
            # hash. Compare bytes directly; anything short of an exact match
            # (including "can't hash it") is customized, never pristine.
            local recorded="${baseline#receipt-sha256:}" current
            if current="$(_loom_rm_sha256_file "$REPO_ROOT/$path")" && [ -n "$current" ] && [ "$current" = "$recorded" ]; then
                STATE="pristine"
            else
                STATE="customized"
                STATE_CHANGED="$path"
            fi
            return 0
            ;;
    esac
    local baseref="${baseline#*:}"
    local untracked ignored untracked_rc=0 ignored_rc=0
    untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$path" 2>/dev/null)" || untracked_rc=$?
    # Round-6 finding (high, fail-open): `|| untracked=""` collapsed a
    # FAILED enumeration (permission issue, corrupt index, anything that
    # makes `ls-files` exit non-zero) to the same empty string a genuinely
    # clean, untracked-free directory produces — the pristine test below
    # cannot tell those apart, so a failed listing read as proof of nothing
    # to report and could drive a REMOVE recommendation over bytes this
    # enumeration never actually saw. Check the real exit status instead of
    # discarding it; a failure refuses this path outright, the same
    # "doubt -> KEEP and ASK" rule unconverted_plugin_files already applies
    # to a failed `find`.
    if [ "$untracked_rc" -ne 0 ]; then
        STATE="customized"
        STATE_CHANGED="$path (could not enumerate untracked files under this path — git ls-files exited $untracked_rc; nothing here can be verified as pristine)"
        return 0
    fi
    # Finding 4, resolve_state's half (round-4 review): the SAME gap
    # _loom_rm_converted_plugin_status closes below existed here, on the
    # far more common path — every plugin/mcp-server/path row that is NOT
    # converted. `--others --exclude-standard` alone never lists a
    # GITIGNORED file, so a customer's `.env`, build output or `*.local`
    # scratch under plugins/<name> was invisible, the directory read as
    # pristine, and `git rm -r plugins/<name>` was recommended over bytes
    # no commit vouches for. Union the `--ignored` listing in; every
    # untracked file counts, ignored or not, and is reported under `added`.
    ignored="$(git -C "$REPO_ROOT" ls-files --others --ignored --exclude-standard -- "$path" 2>/dev/null)" || ignored_rc=$?
    if [ "$ignored_rc" -ne 0 ]; then
        STATE="customized"
        STATE_CHANGED="$path (could not enumerate ignored files under this path — git ls-files exited $ignored_rc; nothing here can be verified as pristine)"
        return 0
    fi
    if [ -n "$ignored" ]; then
        if [ -n "$untracked" ]; then
            untracked="${untracked}"$'\n'"${ignored}"
        else
            untracked="$ignored"
        fi
    fi
    # Round-5 REVIEWER (medium, twice): what git's own listings above are
    # blind to — a nested git repository under $path, or a subdirectory
    # this user cannot read (see _loom_rm_git_blind_spots). Unioned into
    # `untracked` so the one pristine test below fails on it and the entry
    # is reported under `added` like any other bytes no commit vouches for.
    local _rs_blind
    _rs_blind="$(_loom_rm_git_blind_spots "$path")"
    if [ -n "$_rs_blind" ]; then
        if [ -n "$untracked" ]; then
            untracked="${untracked}"$'\n'"${_rs_blind}"
        else
            untracked="$_rs_blind"
        fi
    fi
    # Round-3 REVIEWER (see _loom_rm_index_hidden_paths): an index entry
    # git was told not to look at cannot be proven pristine by any diff —
    # customized, listed under `changed`, never the `pristine` branch.
    local hidden hidden_rc=0
    hidden="$(_loom_rm_index_hidden_paths "$path")" || hidden_rc=$?
    # Round-6 finding (high, fail-open): same class as the untracked/ignored
    # captures above — _loom_rm_index_hidden_paths now propagates a real
    # git failure instead of always returning 0, so check it here too. A
    # failed `ls-files -v` proves nothing about skip-worktree/
    # assume-unchanged entries either way; refuse the path rather than let
    # it fall through to the pristine test below.
    if [ "$hidden_rc" -ne 0 ]; then
        STATE="customized"
        STATE_CHANGED="$path (could not check for skip-worktree/assume-unchanged index entries — git ls-files exited $hidden_rc; nothing here can be verified as pristine)"
        return 0
    fi
    # Round-6 REVIEWER (high, governing principle): `git diff --quiet`
    # consults the customer's OWN diff helpers — GIT_EXTERNAL_DIFF in the
    # environment, `diff.external` in their config, a `.gitattributes`
    # `diff=<driver>` with a `command` or a `textconv` — and, when the
    # helper's exit code is trusted (GIT_EXTERNAL_DIFF_TRUST_EXIT_CODE,
    # diff.trustExitCode, diff.<driver>.trustExitCode; for a lossy textconv
    # even without that), takes the helper's word for "no difference" over
    # its own blob compare. Reproduced on git 2.54 with an EDITED tracked
    # file under every one of those routes: state pristine, changed_files
    # [], REMOVE, `git rm -r plugins/<p>` printed over a customer edit
    # (git rm itself then refuses the modified file — the wrong
    # recommendation is the harm). None of those settings is a
    # misconfiguration; external diffs are ordinary git usage this tool
    # must not inherit. `--no-ext-diff --no-textconv` makes every decision
    # here git's own blob-id comparison and nothing else; the descriptive
    # --name-status below and the other two call sites in this file take
    # the same flags so no path through this script ever asks a helper.
    if [ -z "$hidden" ] && git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --quiet "$baseref" -- "$path" 2>/dev/null && [ -z "$untracked" ]; then
        STATE="pristine"
    else
        STATE="customized"
        local ns
        ns="$(git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --name-status "$baseref" -- "$path" 2>/dev/null)" || ns=""
        STATE_CHANGED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^M/ {print $NF}')"
        STATE_ADDED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^A/ {print $NF}')"
        STATE_DELETED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^D/ {print $NF}')"
        if [ -n "$hidden" ]; then
            if [ -n "$STATE_CHANGED" ]; then
                STATE_CHANGED="$(printf '%s\n%s\n' "$STATE_CHANGED" "$hidden" | awk '!seen[$0]++')"
            else
                STATE_CHANGED="$hidden"
            fi
        fi
        if [ -n "$untracked" ]; then
            if [ -n "$STATE_ADDED" ]; then
                STATE_ADDED="$(printf '%s\n%s\n' "$STATE_ADDED" "$untracked")"
            else
                STATE_ADDED="$untracked"
            fi
        fi
    fi
    return 0
}

count_lines() {
    if [ -z "$1" ]; then printf '0'; else printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' '; fi
}

# Contents summary for a plugin directory.
compute_contents() {
    local kind="$1" path="$2"
    if [ "$kind" != "plugin" ]; then printf ''; return 0; fi
    local dir="$REPO_ROOT/$path"
    [ -d "$dir" ] || { printf ''; return 0; }
    local ncmd nskill nagent nhook nscripts hookjson
    ncmd="$(find "$dir/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    nskill="$(find "$dir/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
    nagent="$(find "$dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    hookjson="absent"; [ -f "$dir/hooks/hooks.json" ] && hookjson="present"
    nhook="$(find "$dir/hooks/scripts" -type f 2>/dev/null | wc -l | tr -d ' ')"
    nscripts="$(find "$dir/scripts" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    printf '%s command(s), %s skill(s), %s agent(s), hooks.json: %s, %s hook script(s), %s script(s)' \
        "$ncmd" "$nskill" "$nagent" "$hookjson" "$nhook" "$nscripts"
}

# References to <path> across the tree, excluding the standard set. Sets
# REFERENCES (file<TAB>line<TAB>text<TAB>class per line, first 50),
# WIRED_HOOKS (the wired-hook references whose command path starts with
# <path>/, same shape), BLOCKERS (file<TAB>line<TAB>class: every wired-hook
# and ci-workflow reference — what makes a REMOVE blocked), and the flags
# WIRED_HOOKS_NONEMPTY / CI_WORKFLOW_REF (true/false).
scan_references() {
    local path="$1" name="$2" kind="${3:-}"
    local escaped
    escaped="$(printf '%s' "$path" | sed 's/\./\\./g')"
    local exclude=(":(exclude)$path" ":(exclude).git" ":(exclude)node_modules"
                   ":(exclude)CHANGELOG.md" ":(exclude)KNOWN_ISSUES.md"
                   ":(exclude).docs" ":(exclude).brain"
                   ":(exclude).logic-loom/config/release-migrations.conf"
                   ":(exclude).logic-loom/config/migration-decisions.conf"
                   ":(exclude).logic-loom/config/project-migrations.conf")
    # .github/ is scanned in BOTH modes (finding 2): an adopter's own CI
    # referencing a retired plugin's path must block REMOVE and be reported
    # as theirs, same as any other reference. This scan only ever READS
    # .github — it never proposes or writes a change under it (the plan/
    # convert text for a REMOVE names only `git rm`/`.mcp.json` for the
    # retired item itself). The unrelated "skip the inherited-maintainer-CI
    # check" in update-framework.md Step 4 is a different, narrower thing:
    # not treating LogicLoom's own leftover maintainer CI as the adopter's —
    # it never blinds this reference scan.
    # An explicit --registry file that lives inside the root is registry
    # text, not a dependency.
    case "${REGISTRY_FILE:-}" in
        "$REPO_ROOT"/*) exclude+=(":(exclude)${REGISTRY_FILE#"$REPO_ROOT"/}") ;;
    esac
    local hits
    hits="$(git -C "$REPO_ROOT" grep -nI --untracked -E -- "${escaped}([^A-Za-z0-9_.-]|\$)" -- . "${exclude[@]}" 2>/dev/null)" || hits=""
    # `git grep --untracked` never surfaces a GITIGNORED file (only untracked
    # but NOT ignored) — .claude/settings.local.json is gitignored by design
    # (versioning personal/local config is out of scope for this repo), so a
    # locally wired hook that points at a retired plugin is otherwise
    # invisible to this scan even though the classifier below already knows
    # how to read a settings.local.json hit once it has one (finding 3).
    local local_settings="$REPO_ROOT/.claude/settings.local.json"
    if [ -f "$local_settings" ]; then
        local local_hits
        local_hits="$(grep -nI -E -- "${escaped}([^A-Za-z0-9_.-]|\$)" "$local_settings" 2>/dev/null | sed 's|^|.claude/settings.local.json:|')" || local_hits=""
        if [ -n "$local_hits" ]; then
            if [ -n "$hits" ]; then hits="${hits}"$'\n'"${local_hits}"; else hits="$local_hits"; fi
        fi
    fi
    # mcp-server rows: the .mcp.json entry is keyed "<name>": — a line the
    # path pattern above never matches.
    if [ "$kind" = "mcp-server" ] && [ -f "$REPO_ROOT/.mcp.json" ]; then
        local keyhits
        keyhits="$(grep -nF -- "\"$name\":" "$REPO_ROOT/.mcp.json" 2>/dev/null | sed 's|^|.mcp.json:|')" || keyhits=""
        if [ -n "$keyhits" ]; then
            if [ -n "$hits" ]; then hits="${hits}"$'\n'"${keyhits}"; else hits="$keyhits"; fi
        fi
    fi
    REFERENCES=""
    WIRED_HOOKS=""
    BLOCKERS=""
    WIRED_HOOKS_NONEMPTY="false"
    CI_WORKFLOW_REF="false"
    [ -z "$hits" ] && return 0
    local n=0
    local hitline f rest ln text base cls seen=""
    while IFS= read -r hitline; do
        [ -z "$hitline" ] && continue
        f="${hitline%%:*}"
        rest="${hitline#*:}"
        ln="${rest%%:*}"
        text="${rest#*:}"
        # the record below is TAB-separated; a tab inside the matched line
        # would split it.
        text="$(printf '%s' "$text" | tr '\t' ' ')"
        case "$seen" in *"|${f}:${ln}|"*) continue ;; esac
        seen="${seen}|${f}:${ln}|"
        base="${f##*/}"
        [ "$base" = "CONVERTED.md" ] && continue
        if [ -f "$REPO_ROOT/$f" ] && head -20 "$REPO_ROOT/$f" 2>/dev/null | grep -q "converted-from:"; then
            continue
        fi
        case "$f" in
            .claude/settings.json|.claude/settings.local.json)
                case "$text" in *'"command"'*) cls="wired-hook" ;; *) cls="other" ;; esac ;;
            .claude/commands/*.md)
                cls="other"
                if [ -f "$REPO_ROOT/$f" ]; then
                    if head -10 "$REPO_ROOT/$f" 2>/dev/null | grep -q "AUTO-GENERATED by plugin-bridge" \
                       && head -10 "$REPO_ROOT/$f" 2>/dev/null | grep -q "source: $name"; then
                        cls="bridge-wrapper"
                    fi
                fi ;;
            .github/workflows/*.yml|.github/workflows/*.yaml) cls="ci-workflow" ;;
            .mcp.json) cls="mcp-config" ;;
            plugins/*) cls="plugin-cross-ref" ;;
            .claude/agents/*|.claude/skills/*|.claude/rules/*) cls="project-agent-or-skill" ;;
            CLAUDE.md|AGENTS.md|.logic-loom/AGENTS.md|README.md|*/README.md) cls="docs" ;;
            *) cls="other" ;;
        esac
        if [ "$cls" = "wired-hook" ]; then
            case "$text" in
                *"${path}/"*)
                    WIRED_HOOKS_NONEMPTY="true"
                    WIRED_HOOKS="${WIRED_HOOKS}${f}"$'\t'"${ln}"$'\t'"$(truncate120 "$text")"$'\t'"${cls}"$'\n'
                    BLOCKERS="${BLOCKERS}${f}"$'\t'"${ln}"$'\t'"${cls}"$'\n' ;;
            esac
        fi
        if [ "$cls" = "ci-workflow" ]; then
            CI_WORKFLOW_REF="true"
            BLOCKERS="${BLOCKERS}${f}"$'\t'"${ln}"$'\t'"${cls}"$'\n'
        fi
        n=$((n + 1))
        [ "$n" -gt 50 ] && continue
        REFERENCES="${REFERENCES}${f}"$'\t'"${ln}"$'\t'"$(truncate120 "$text")"$'\t'"${cls}"$'\n'
    done <<< "$hits"
    return 0
}

# Bridge wrappers among REFERENCES (newline list of files), for the prune text.
bridge_wrapper_files() {
    [ -n "${REFERENCES:-}" ] || return 0
    printf '%s' "$REFERENCES" | awk -F'\t' '$4 == "bridge-wrapper" { print $1 }'
}

# Sets COUNTERPARTS (file<TAB>counterpart<TAB>exists per line).
#   renamed: for each changed/added plugins/<old>/<rel>, plugins/<new>/<rel>
#   folded:  the brief path
compute_counterparts() {
    local kind="$1" fate="$2" repl="$3" path="$4"
    COUNTERPARTS=""
    [ "$kind" = "plugin" ] || return 0
    case "$fate" in
        renamed)
            local newp="${repl#plugin:}" f rel cp ex
            [ "$newp" = "$repl" ] && return 0
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                rel="${f#"$path"/}"
                cp="plugins/$newp/$rel"
                ex="false"; [ -e "$REPO_ROOT/$cp" ] && ex="true"
                COUNTERPARTS="${COUNTERPARTS}${f}"$'\t'"${cp}"$'\t'"${ex}"$'\n'
            done <<< "$(printf '%s\n%s\n' "$STATE_CHANGED" "$STATE_ADDED")" ;;
        folded)
            local brief="${repl#path:}" ex
            [ "$brief" = "$repl" ] && return 0
            ex="false"; [ -e "$REPO_ROOT/$brief" ] && ex="true"
            COUNTERPARTS="${path}/"$'\t'"${brief}"$'\t'"${ex}"$'\n' ;;
    esac
    return 0
}

# lookup_decision <name> <release> [<alt-name>] — the verb of the first
# decision line naming <name> (or <alt-name>, e.g. the file a glob row
# matched), unrestricted or restricted to <release>.
lookup_decision() {
    local name="$1" release="$2" alt="${3:-}"
    [ -f "$DECISIONS_FILE" ] || return 1
    local line verb rhs dname drelease bare
    bare="${release#v}"
    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed
        trimmed="$(_loom_trim "$line")"
        [ -z "$trimmed" ] && continue
        [ "${trimmed#\#}" != "$trimmed" ] && continue
        case "$trimmed" in
            *=*)
                verb="$(_loom_trim "${trimmed%%=*}")"
                rhs="$(_loom_trim "${trimmed#*=}")"
                case "$rhs" in
                    *@*) dname="$(_loom_trim "${rhs%@*}")"; drelease="$(_loom_trim "${rhs##*@}")" ;;
                    *) dname="$rhs"; drelease="" ;;
                esac
                if [ "$dname" = "$name" ] || { [ -n "$alt" ] && [ "$dname" = "$alt" ]; }; then
                    if [ -z "$drelease" ] || [ "$drelease" = "$release" ] || [ "$drelease" = "$bare" ]; then
                        printf '%s' "$verb"
                        return 0
                    fi
                fi ;;
        esac
    done < "$DECISIONS_FILE"
    return 1
}

# The paths a previous `convert --apply` wrote, from its CONVERTED.md ledger
# (space-separated targets), empty when none.
converted_paths_for() {
    local plugin="$1" ledger="$REPO_ROOT/.claude/skills/$1/CONVERTED.md"
    [ -f "$ledger" ] || return 0
    sed -n 's/^- \(\.claude\/[^ ]*\) .*<- .*$/\1/p' "$ledger" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}

# Round-2 finding 2: decision=converted must not force REMOVE regardless of
# what happened to plugins/<name> since the conversion was recorded — that
# would silently discard a customer's own post-conversion edit. Evidence the
# converter itself keeps, checked in order:
#   1. the commit that CREATED .claude/skills/<name>/CONVERTED.md — the
#      converter's own ledger. finalize_convert() never rewrites an EXISTING
#      one (it only classifies it SKIP/KEEP against a fresh render), so a
#      completed conversion writes it exactly once: its creation commit IS
#      the conversion decision, committed evidence a customer cannot have
#      pre-dated by editing the plugin first.
#   2. failing that (CONVERTED.md was never committed — a same-session
#      convert whose decision is still only in the working tree), the commit
#      that added the "converted = <name>" line to DECISIONS_FILE — matched
#      as a WHOLE LINE (`-G` with an anchored, escaped regex), never as a
#      substring: `-S"converted = foo"` also counts "converted = foobar", so a
#      same-prefix plugin converted earlier would date foo's decision to the
#      WRONG (older) commit and diff the plugin against the wrong tree.
# Neither committed -> empty stdout, rc 1: the caller must NOT read that as
# "nothing to compare" / "unchanged" (Governing principle: doubt -> KEEP and
# ASK, never REMOVE). Read-only git only (log).
_loom_rm_converted_decision_commit() {
    local plugin="$1" c
    c="$(git -C "$REPO_ROOT" log --diff-filter=A --format='%H' -- \
        ".claude/skills/$plugin/CONVERTED.md" 2>/dev/null | tail -1)"
    if [ -z "$c" ] && [ -f "$DECISIONS_FILE" ]; then
        local plugin_re
        plugin_re="$(printf '%s' "$plugin" | sed 's/[][\\.*^$/]/\\&/g')"
        c="$(git -C "$REPO_ROOT" log -G"^converted = ${plugin_re}\$" --format='%H' -- \
            "$DECISIONS_FILE" 2>/dev/null | tail -1)"
    fi
    [ -n "$c" ] || return 1
    printf '%s' "$c"
    return 0
}

# "unchanged" | "changed:<commit>" | "unknown" — whether <path> (plugins/
# <name>) has changed since the conversion-decision commit above: any
# TRACKED change (working tree vs that commit — the finding's own minimum),
# and ALSO any untracked file under it, whether or not it is gitignored.
# Finding 4: `ls-files --others --exclude-standard` alone reports only
# untracked-and-NOT-ignored files — a customer file added under plugins/
# <name> that happens to match a .gitignore pattern (a build artifact, a
# local .env, anything project-local) would be invisible to that one
# listing, so a second `--ignored` listing is unioned in. Between the two,
# every untracked file is counted, exactly as resolve_state() counts
# untracked files for every other row. An untracked file inside plugins/
# <name> is a customer's bytes that no commit vouches for; a REMOVE plan
# line on that directory recommends deleting it (the printed `git rm -r`
# would leave it, but the recommendation is the harm the governing principle
# names). "unknown" when no decision commit can be found at all: never
# silently read as "unchanged". Read-only git only (diff, ls-files).
#
# Round-4 review, "render-stale:<commit>": "unchanged since the decision
# commit" proves plugins/<name> was not touched AFTER the commit that
# recorded the conversion — it says nothing about what went INTO that
# commit. The ordinary /update-framework flow runs `convert --apply`, and the
# user commits at /git-push some time later; an edit to plugins/<name> made
# in between lands in the SAME commit as CONVERTED.md, so it dates as "part
# of the conversion", the diff against that commit is empty, and the edit —
# which the converter never saw and never carried into .claude/ — was
# recommended for `git rm -r`. The converter's own re-run classification is
# the evidence that catches this: `convert <name> --dry-run` re-renders every
# unit from the plugin source AS IT STANDS and reports SKIP (byte-identical
# to what is on disk under .claude/) or KEEP/WRITE/STOP/APPEND (it is not).
# Only an all-SKIP re-render proves the on-disk conversion reflects the
# source; anything else — including a re-render that cannot run at all — is
# doubt, and doubt is KEEP and ASK, never REMOVE. The dry-run is run inside a
# command substitution, i.e. a subshell: it writes nothing (every write in
# convert is gated on --apply), its globals (STATE_*, MAP_LIST, unit lists,
# REGISTRY_ROWS, PROJECT_REGISTRY_*) die with the subshell, its `exit` on a
# usage error ends only the subshell, and the parent's EXIT trap is not
# inherited by a command-substitution subshell, so the parent's temp files
# survive it. This helper is itself always called via `$(...)`, so the cost
# is one nested subshell per converted row per scan — a handful of find/sed/
# diff calls, nothing repo-wide.
_loom_rm_converted_plugin_status() {
    local plugin="$1" path="$2" commit untracked ignored
    local untracked_rc=0 ignored_rc=0 hidden_rc=0
    if ! commit="$(_loom_rm_converted_decision_commit "$plugin")"; then
        printf 'unknown'
        return 0
    fi
    untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$path" 2>/dev/null)" || untracked_rc=$?
    ignored="$(git -C "$REPO_ROOT" ls-files --others --ignored --exclude-standard -- "$path" 2>/dev/null)" || ignored_rc=$?
    # Round-3 REVIEWER: a skip-worktree / assume-unchanged entry under the
    # plugin makes the diff below meaningless for it (see
    # _loom_rm_index_hidden_paths) — the re-render gate further down would
    # usually still catch an edited SOURCE, but "usually" is not the
    # contract; changed by construction, same as resolve_state.
    local hidden
    hidden="$(_loom_rm_index_hidden_paths "$path")" || hidden_rc=$?
    # Round-6 finding (high, fail-open — same class fixed in resolve_state
    # above): these three captures used to swallow a FAILED git enumeration
    # into the same empty string a genuinely clean result produces, so a
    # failed listing here read as "nothing hidden/untracked" and this
    # plugin could still reach the re-render gate below and come back
    # "unchanged" — the same doubt this function otherwise treats as
    # `changed:<commit>` on purpose. Any of the three failing is doubt;
    # doubt is `changed`, same as an actual untracked/hidden file.
    if [ "$untracked_rc" -ne 0 ] || [ "$ignored_rc" -ne 0 ] || [ "$hidden_rc" -ne 0 ]; then
        printf 'changed:%s' "$commit"
        return 0
    fi
    # Round-5 REVIEWER: the same two blind spots resolve_state now closes
    # (a nested git repository, an unreadable subdirectory — see
    # _loom_rm_git_blind_spots) and the same symlinked-ancestor rule; the
    # re-render gate below would usually catch the first through
    # unconverted_plugin_files' own .git reporting, but "usually" is not
    # the contract — changed by construction, same as resolve_state.
    local _cs_blind _cs_symanc=""
    _cs_blind="$(_loom_rm_git_blind_spots "$path")"
    _cs_symanc="$(_loom_rm_path_has_symlink_ancestor "$path")" || _cs_symanc=""
    # Round-6 REVIEWER: `--no-ext-diff --no-textconv` for the same reason as
    # resolve_state's pristine test (see its comment) — this diff decides
    # "unchanged since the conversion" and must never defer to a helper.
    if [ -n "$untracked" ] || [ -n "$ignored" ] || [ -n "$hidden" ] || [ -n "$_cs_blind" ] || [ -n "$_cs_symanc" ] || ! git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --quiet "$commit" -- "$path" 2>/dev/null; then
        printf 'changed:%s' "$commit"
        return 0
    fi
    # Re-render gate (see the block comment above). No registry to render
    # from is the same as a re-render that could not run: unverified.
    local render rc=0
    if [ -z "${REGISTRY_FILE:-}" ]; then
        printf 'render-stale:%s' "$commit"
        return 0
    fi
    render="$(cmd_convert "$plugin" --dry-run --root "$REPO_ROOT" --registry "$REGISTRY_FILE" 2>/dev/null)" || rc=$?
    if [ "$rc" -ne 0 ] || printf '%s\n' "$render" | grep -qE '^(KEEP|WRITE|MKDIR|APPEND|STOP|ERROR) '; then
        printf 'render-stale:%s' "$commit"
        return 0
    fi
    # Reviewer round 1, "incomplete:<commit>:<files>": an all-SKIP re-render
    # proves every unit the converter KNOWS about matches disk — it says
    # nothing about the files the converter never maps at all (a
    # non-.md file under commands/ or agents/, a symlink, a nested dir
    # under skills/ that is not a skill). cmd_convert already withholds its
    # own delete step for exactly those (finding 2) and prints the
    # machine-stable `accounted:` line either way; `converted =` is still
    # recorded for the units that DID convert, so the next scan used to read
    # the decision alone as "delete when verified" and recommend `git rm -r`
    # over bytes that were never carried into .claude/ and are not provably
    # LogicLoom's. Fail-closed on the POSITIVE line: absent (withheld, or a
    # future cmd_convert that stopped printing it) is not verified. The
    # leftover list is carried along for the reason text — cmd_convert
    # prints it as "    - <path>" lines under "Not carried over by this run:".
    if ! printf '%s\n' "$render" | grep -qF "accounted: every file under plugins/$plugin is carried over"; then
        local left
        left="$(printf '%s\n' "$render" | sed -n 's/^    - //p' | tr '\n' ' ' | sed 's/ $//')"
        printf 'incomplete:%s:%s' "$commit" "$left"
        return 0
    fi
    printf 'unchanged'
    return 0
}

# Shared by compute_recommendation (REC_*) and compute_decisions_briefing
# (DECISIONS_*) so the two surfaces can never again describe the SAME
# plugins/<name> differently (finding 3): both now read this one status —
# never re-derive their own "is it safe to delete" text. Sets
# CONV_BRIEF_CONSEQUENCE to what compute_decisions_briefing prints, and
# returns 0 when the conversion-status is "unchanged" (delete is the live
# recommendation), 1 otherwise (KEEP — something needs a human look first).
_loom_rm_converted_briefing_consequence() {
    local plugin="$1" path="$2" cstatus
    cstatus="$(_loom_rm_converted_plugin_status "$plugin" "$path")"
    case "$cstatus" in
        unchanged)
            CONV_BRIEF_CONSEQUENCE="$path still on disk — delete it once the converted command works, then run .logic-loom/scripts/bash/sync-plugin-commands.sh prune"
            return 0 ;;
        changed:*)
            CONV_BRIEF_CONSEQUENCE="$path was edited after conversion (changed since the decision commit ${cstatus#changed:}: a tracked edit, or an untracked file, special file or empty directory under it, or an index entry flagged skip-worktree/assume-unchanged whose edits git diff cannot see) — KEEP-AS-IS; verify the edit was carried over, then decide by hand"
            return 1 ;;
        render-stale:*)
            CONV_BRIEF_CONSEQUENCE="$path was converted, but re-rendering it now (convert $plugin --dry-run) does not reproduce what is on disk under .claude/ (a KEEP/WRITE/STOP line, or the re-render could not run) — KEEP-AS-IS; the decision commit ${cstatus#render-stale:} may carry an edit the conversion never saw; reconcile by hand, then decide"
            return 1 ;;
        incomplete:*)
            local _ic_rest="${cstatus#incomplete:}" _ic_commit _ic_files
            _ic_commit="${_ic_rest%%:*}"; _ic_files="${_ic_rest#*:}"
            CONV_BRIEF_CONSEQUENCE="$path was converted (decision commit $_ic_commit), but NOT every file under it was carried over into .claude/ — never converted, not in CONVERTED.md: ${_ic_files:-run convert $plugin --dry-run to list them} — KEEP-AS-IS; carry or remove those by hand, then decide"
            return 1 ;;
        *)
            CONV_BRIEF_CONSEQUENCE="$path — the conversion decision has no committed record (.claude/skills/$plugin/CONVERTED.md or migration-decisions.conf) — cannot verify $path wasn't edited since; commit the decision, then re-run"
            return 1 ;;
    esac
}

# REMOVE is blocked by a wired hook or a CI workflow reference (§15.2-B).
# Only REMOVE: every other action keeps the reference as its first step.
apply_remove_blockers() {
    if [ "$REC_ACTION" = "REMOVE" ] && { [ "$WIRED_HOOKS_NONEMPTY" = "true" ] || [ "$CI_WORKFLOW_REF" = "true" ]; }; then
        REC_BLOCKED="true"
    fi
}

# Sets REC_ACTION REC_REASON REC_BLOCKED REC_BLOCKED_BY_EXTRA REC_REMOVE_CMD REC_MOVE_CMD
compute_recommendation() {
    local kind="$1" name="$2" fate="$3" repl="$4" state="$5" decision="$6" path="$7"
    REC_BLOCKED="false"; REC_BLOCKED_BY_EXTRA=""; REC_REMOVE_CMD=""; REC_MOVE_CMD=""

    # Reviewer round 1: the AT-USE half of _loom_lint_name_shell_safe for
    # the NAME field. The round-5 fix applied it at lint time (every row,
    # so a bad name never ships in the upstream registry) and at-use only
    # for a MOVE row's replacement path — but a project registry is never
    # linted before scan/plan/convert read it, and a plugin/mcp-server/path
    # row's name is the other string every printed `git rm` embeds.
    # shell_quote already neutralises whitespace and metacharacters there;
    # what quoting can NOT neutralise is an OPTION-SHAPED path: a `path`
    # row named "-f" lints clean today (only [A-Za-z0-9._/-] is checked,
    # and '-' is in it) and scan prints `git rm '-f'` — the quotes are
    # cosmetic, git still parses the argument as an option. Refuse to build
    # any command from such a name (KEEP-AS-IS with the reason), same
    # belt-and-suspenders shape as the MOVE guard below; lint now rejects a
    # leading '-' too.
    case "$kind" in
        plugin|mcp-server|path)
            if ! _loom_lint_name_shell_safe "$kind" "$name"; then
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="registry row name '$name' contains whitespace, a shell metacharacter, or starts with '-' (a character outside [A-Za-z0-9._/-], or an option-shaped path) — refusing to build any git command from it; fix the registry row (lint rejects it)"
                return 0
            fi ;;
    esac

    if [ "$decision" = "converted" ]; then
        local cstatus
        cstatus="$(_loom_rm_converted_plugin_status "$name" "$path")"
        case "$cstatus" in
            unchanged)
                REC_ACTION="REMOVE"
                local cpaths
                cpaths="$(converted_paths_for "$name")"
                REC_REASON="CONVERTED - plugins/$name still on disk; delete when verified"
                [ -n "$cpaths" ] && REC_REASON="$REC_REASON (converted: $cpaths)"
                build_remove_cmd "$kind" "$name" "$path"
                apply_remove_blockers
                ;;
            changed:*)
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="CONVERTED, but $path was edited after conversion (changed since the decision commit ${cstatus#changed:}: a tracked edit, or an untracked file, special file or empty directory under it, or an index entry flagged skip-worktree/assume-unchanged whose edits git diff cannot see) — ASK before removing; verify the edit was carried over, then decide by hand"
                ;;
            render-stale:*)
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="CONVERTED, but re-rendering $path now (convert $name --dry-run) does not reproduce what is on disk under .claude/ — a KEEP/WRITE/STOP line, or the re-render could not run — so the decision commit ${cstatus#render-stale:} may carry an edit made to $path after convert --apply that the conversion never saw; ASK before removing: re-run convert $name --dry-run, reconcile by hand, then decide"
                ;;
            incomplete:*)
                local _ic_rest="${cstatus#incomplete:}" _ic_commit _ic_files
                _ic_commit="${_ic_rest%%:*}"; _ic_files="${_ic_rest#*:}"
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="CONVERTED (decision commit $_ic_commit), but NOT every file under $path was carried over into .claude/ — never converted, not in CONVERTED.md: ${_ic_files:-run convert $name --dry-run to list them} — ASK before removing: carry or remove those by hand, then decide"
                ;;
            *)
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="CONVERTED, but the conversion decision has no committed record (.claude/skills/$name/CONVERTED.md or migration-decisions.conf) — cannot verify $path wasn't edited since; commit the decision, then re-run"
                ;;
        esac
        return 0
    fi
    if [ "$decision" = "keep" ]; then
        REC_ACTION="KEEP-AS-IS"
        REC_REASON="acknowledged (decision: keep = $name)"
        return 0
    fi

    # moved path: path kind, fate renamed, replacement path:<new>
    if [ "$kind" = "path" ] && [ "$fate" = "renamed" ] && [ "${repl#path:}" != "$repl" ]; then
        local newp="${repl#path:}"
        # Medium finding (round 5 review), residual gap found while adding
        # test coverage for it: lint's _loom_lint_name_shell_safe and
        # loom_path_traversal_safe validate the row's `name` field, but
        # $newp comes from the REPLACEMENT field instead (_loom_lint_replacement_ok
        # only checks the "path:" prefix shape, never the path after it) —
        # and this is the exact other path REC_MOVE_CMD below embeds into a
        # printed `git mv` command. Same belt-and-suspenders shape as
        # _loom_rm_verify_fixture_scan_path's at-use guard: lint should
        # catch this in the shipped registry (not added here — this is the
        # at-use half, covering a project registry that was never linted
        # too), and this refuses to build any shell command out of an
        # unsafe $newp regardless.
        if ! loom_path_traversal_safe "$newp" || ! _loom_lint_name_shell_safe path "$newp"; then
            REC_ACTION="KEEP-AS-IS"
            REC_BLOCKED="true"
            REC_REASON="registry row's replacement path '$newp' is absolute, contains a '..'/'.' path segment, a character outside [A-Za-z0-9._/-], or starts with '-' — refusing to build a move command from it; fix the registry row's replacement field"
            return 0
        fi
        if [ "$state" = "pristine" ]; then
            if [ ! -e "$REPO_ROOT/$newp" ]; then
                local at_upstream="false"
                if git -C "$REPO_ROOT" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 \
                   && git -C "$REPO_ROOT" cat-file -e "refs/loom-upstream/main:$newp" 2>/dev/null; then
                    at_upstream="true"
                fi
                if [ "$at_upstream" = "true" ]; then
                    REC_ACTION="REMOVE"; REC_BLOCKED="true"
                    REC_REASON="upstream ships $newp — accept its clean-add proposal first; blocked until $newp exists on disk"
                    REC_BLOCKED_BY_EXTRA="refs/loom-upstream/main:$newp"$'\t'"0"$'\t'"pending-clean-add"
                else
                    REC_ACTION="MOVE"
                    # Finding 4: this recommendation was computed at scan
                    # time and is never re-checked at apply time — a
                    # same-run clean-add landing at $newp between "plan"
                    # printing this and the user pasting it would otherwise
                    # make a bare `git mv` overwrite-fail messily (or, worse,
                    # on some tools, silently). The PRINTED/apply command
                    # itself now re-checks immediately before it runs and
                    # refuses with a clear message instead of ever calling
                    # `git mv` onto an existing destination. It also
                    # `mkdir -p`s $newp's own parent directory first: `git mv`
                    # (unlike a plain `mv`) does NOT create an intermediate
                    # destination directory itself — verified directly
                    # against real git — so the un-guarded, pre-fix
                    # recommendation would already have failed with "No such
                    # file or directory" on the ordinary case a MOVE row
                    # exists for at all: moving into a path that does not
                    # exist yet.
                    # $newp is already proven safe by the at-use guard just
                    # above (loom_path_traversal_safe + _loom_lint_name_shell_safe
                    # restrict it to [A-Za-z0-9._/-], so it can never itself
                    # contain a quote or shell metacharacter) — still quoted
                    # here at every embedding, belt-and-suspenders, so this
                    # stays consistent with build_remove_cmd and never
                    # silently regresses to raw interpolation if that guard
                    # is ever loosened.
                    # Round-5 finding 9 (low, diagnostic-accuracy gap): `-e`
                    # alone is FALSE for a dangling symlink (one whose
                    # target does not exist) — the printed guard's own
                    # friendly refusal message would not fire for that case,
                    # silently falling through to `git mv`, which does
                    # independently refuse to overwrite an existing
                    # index/lstat entry (including a dangling symlink) —
                    # so no path is ever actually overwritten either way,
                    # only a less friendly raw git error instead of this
                    # tool's own message. `-e $newp || -L $newp` catches a
                    # dangling symlink too (lstat sees it even when stat
                    # cannot), matching the existing regular/non-dangling
                    # case exactly.
                    REC_MOVE_CMD="if [ -e $(shell_quote "$newp") ] || [ -L $(shell_quote "$newp") ]; then echo 'release-migrations: $newp already exists on disk — refusing to overwrite (something added it since this was planned); re-run: release-migrations.sh plan $name' >&2; false; else mkdir -p \"\$(dirname $(shell_quote "$newp"))\" && git mv $(shell_quote "$path") $(shell_quote "$newp"); fi"
                    REC_REASON="Replaced by: path:$newp."
                fi
            else
                REC_ACTION="REMOVE"
                build_remove_cmd "$kind" "$name" "$path"
                REC_REASON="Replaced by: path:$newp."
            fi
        else
            REC_ACTION="KEEP-AS-IS"
            REC_REASON="carry your diff into $newp, then re-run"
        fi
        apply_remove_blockers
        return 0
    fi

    case "$kind" in
        mcp-server|path)
            if [ "$state" = "pristine" ]; then
                REC_ACTION="REMOVE"; build_remove_cmd "$kind" "$name" "$path"
                REC_REASON="Replaced by: $repl."
            else
                REC_ACTION="KEEP-AS-IS"
                REC_REASON="no conversion for this kind — consequence: no upstream updates"
            fi ;;
        plugin)
            case "$fate" in
                renamed)
                    local replname="${repl#plugin:}"
                    if [ "$state" = "pristine" ]; then
                        if [ -d "$REPO_ROOT/plugins/$replname" ]; then
                            REC_ACTION="REMOVE"; build_remove_cmd "$kind" "$name" "$path"
                            REC_REASON="Replaced by: $repl."
                        else
                            REC_ACTION="KEEP-AS-IS"
                            REC_REASON="replacement not installed yet - accept the clean-add proposals for plugins/$replname/ first, then re-run"
                        fi
                    else
                        REC_ACTION="ADOPT-REPLACEMENT"
                        REC_REASON="carry your customizations into $repl (files with no counterpart: convert $name --apply --customized-only)"
                    fi ;;
                folded)
                    local brief="${repl#path:}"
                    if [ "$state" = "pristine" ]; then
                        if [ -f "$REPO_ROOT/$brief" ]; then
                            REC_ACTION="REMOVE"; build_remove_cmd "$kind" "$name" "$path"
                            REC_REASON="Replaced by: $repl."
                        else
                            REC_ACTION="KEEP-AS-IS"
                            REC_REASON="replacement not installed yet - accept the clean-add proposals for $brief first, then re-run"
                        fi
                    else
                        REC_ACTION="CONVERT-TO-LOCAL"
                        REC_REASON="the brief is upstream-owned; editing it would make it conflict-review forever"
                    fi ;;
                native|removed)
                    if [ "$state" = "pristine" ]; then
                        REC_ACTION="REMOVE"; build_remove_cmd "$kind" "$name" "$path"
                        REC_REASON="Replaced by: $repl."
                    else
                        REC_ACTION="CONVERT-TO-LOCAL"
                        REC_REASON="preserve your customizations before removing (convert $name --dry-run first)"
                    fi ;;
            esac ;;
    esac

    apply_remove_blockers
    return 0
}

# Newline list of the CI signals a kept item raises (static, §2.1 `ci`).
ci_notices_for_kind() {
    case "$1" in
        plugin) printf 'floor test 1b info line\nmanifest validator SKIPPED line\nlifecycle suite pending-migration notice\n' ;;
        *) printf '' ;;
    esac
}

# JSON for blocked_by: BLOCKERS (file<TAB>line<TAB>class) + REC_BLOCKED_BY_EXTRA.
json_blocked_by() {
    local out="[" first=1 bf bl bc
    if [ "${REC_BLOCKED:-false}" = "true" ] && [ -n "${BLOCKERS:-}" ]; then
        while IFS=$'\t' read -r bf bl bc; do
            [ -z "$bf" ] && continue
            [ "$first" -eq 0 ] && out="${out},"
            out="${out}{\"file\":\"$(json_escape "$bf")\",\"line\":$bl,\"class\":\"$bc\"}"
            first=0
        done <<< "$BLOCKERS"
    fi
    if [ -n "${REC_BLOCKED_BY_EXTRA:-}" ]; then
        IFS=$'\t' read -r bf bl bc <<< "$REC_BLOCKED_BY_EXTRA"
        [ "$first" -eq 0 ] && out="${out},"
        out="${out}{\"file\":\"$(json_escape "$bf")\",\"line\":$bl,\"class\":\"$bc\"}"
        first=0
    fi
    printf '%s]' "$out"
}

# Human "file:line, …" for the blocked-by set.
human_blocked_by() {
    local out="" bf bl bc
    if [ -n "${BLOCKERS:-}" ]; then
        while IFS=$'\t' read -r bf bl bc; do
            [ -z "$bf" ] && continue
            out="${out}${out:+, }${bf}:${bl}"
        done <<< "$BLOCKERS"
    fi
    if [ -n "${REC_BLOCKED_BY_EXTRA:-}" ]; then
        IFS=$'\t' read -r bf bl bc <<< "$REC_BLOCKED_BY_EXTRA"
        out="${out}${out:+, }${bf}"
    fi
    printf '%s' "$out"
}

# JSON array of {file,line,text,class} from a REFERENCES-shaped list.
json_reference_list() {
    local list="$1" out="[" first=1 rf rln rtext rcls
    [ -z "$list" ] && { printf '[]'; return 0; }
    while IFS=$'\t' read -r rf rln rtext rcls; do
        [ -z "$rf" ] && continue
        [ "$first" -eq 0 ] && out="${out},"
        out="${out}{\"file\":\"$(json_escape "$rf")\",\"line\":$rln,\"text\":\"$(json_escape "$rtext")\",\"class\":\"$rcls\"}"
        first=0
    done <<< "$list"
    printf '%s]' "$out"
}

# ============================================================================
# scan
# ============================================================================

ITEM_ID_N=0
ITEMS_HUMAN=""
ITEMS_JSON=""
PENDING_N=0
KEPT_N=0
CONVERTED_N=0
DANGLING_HOOKS_HUMAN=""
DANGLING_HOOKS_JSON=""
DANGLING_MCP_HUMAN=""
DANGLING_MCP_JSON=""

emit_deprecation_item() {
    local source="$1" row="$2" json_mode="$3"
    local kind name fate repl default first release note
    IFS=$'\t' read -r kind name fate repl default first release note <<< "$row"
    local path
    path="$(loom_deprecation_dir "$kind" "$name")"
    local exists="false"
    if [ "$kind" = "path" ]; then
        [ -e "$REPO_ROOT/$path" ] && exists="true"
    else
        [ -d "$REPO_ROOT/$path" ] && exists="true"
    fi
    [ "$exists" = "true" ] || return 1

    ITEM_ID_N=$((ITEM_ID_N + 1)); local id; id="$(printf 'MG-%03d' "$ITEM_ID_N")"
    local baseline; baseline="$(resolve_baseline "$path")"
    resolve_state "$path" "$baseline"
    local contents; contents="$(compute_contents "$kind" "$path")"
    scan_references "$path" "$name" "$kind"
    compute_counterparts "$kind" "$fate" "$repl" "$path"
    local decision=""
    decision="$(lookup_decision "$name" "$release" 2>/dev/null)" || decision=""
    compute_recommendation "$kind" "$name" "$fate" "$repl" "$STATE" "$decision" "$path"
    local ci; ci="$(ci_notices_for_kind "$kind")"

    case "$REC_ACTION" in
        KEEP-AS-IS) [ "$decision" = "keep" ] && KEPT_N=$((KEPT_N + 1)) || PENDING_N=$((PENDING_N + 1)) ;;
        *)
            if [ "$decision" = "converted" ]; then
                CONVERTED_N=$((CONVERTED_N + 1))
            else
                PENDING_N=$((PENDING_N + 1))
            fi ;;
    esac

    if [ "$json_mode" = "true" ]; then
        local jcp="[" first_c=1 cf cc ce
        if [ -n "$COUNTERPARTS" ]; then
            while IFS=$'\t' read -r cf cc ce; do
                [ -z "$cf" ] && continue
                [ "$first_c" -eq 0 ] && jcp="${jcp},"
                jcp="${jcp}{\"file\":\"$(json_escape "$cf")\",\"counterpart\":\"$(json_escape "$cc")\",\"exists\":$ce}"
                first_c=0
            done <<< "$COUNTERPARTS"
        fi
        jcp="${jcp}]"
        local item="{\"id\":\"$id\",\"kind\":\"$kind\",\"source\":\"$source\",\"path\":\"$(json_escape "$path")\",\"fate\":\"$fate\",\"replacement\":\"$(json_escape "$repl")\",\"release\":\"$release\",\"baseline\":\"$baseline\",\"state\":\"$STATE\",\"changed_files\":$(json_string_list "$STATE_CHANGED"),\"added_files\":$(json_string_list "$STATE_ADDED"),\"deleted_files\":$(json_string_list "$STATE_DELETED"),\"contents\":\"$(json_escape "$contents")\",\"references\":$(json_reference_list "$REFERENCES"),\"wired_hooks\":$(json_reference_list "$WIRED_HOOKS"),\"counterparts\":$jcp,\"decision\":\"$decision\",\"recommended\":\"$REC_ACTION\",\"reason\":\"$(json_escape "$REC_REASON")\",\"blocked\":$( [ "$REC_BLOCKED" = "true" ] && echo true || echo false ),\"blocked_by\":$(json_blocked_by),\"remove_command\":\"$(json_escape "$REC_REMOVE_CMD")\",\"move_command\":\"$(json_escape "$REC_MOVE_CMD")\",\"ci\":$(json_string_list "$ci")}"
        [ -n "$ITEMS_JSON" ] && ITEMS_JSON="${ITEMS_JSON},"
        ITEMS_JSON="${ITEMS_JSON}${item}"
    else
        local block
        block="$id  $path   $fate in $release · replaced by: $repl"$'\n'
        block="${block}        state: ${STATE} (baseline ${baseline}"
        if [ "$STATE" != "unknown" ]; then
            block="${block} — $(count_lines "$STATE_CHANGED") changed, $(count_lines "$STATE_ADDED") added, $(count_lines "$STATE_DELETED") deleted"
        fi
        block="${block})"$'\n'
        [ -n "$contents" ] && block="${block}        contains: ${contents}"$'\n'
        if [ -n "$REFERENCES" ]; then
            while IFS=$'\t' read -r rf rln rtext rcls; do
                [ -z "$rf" ] && continue
                block="${block}        referenced by: ${rf}:${rln} (${rcls})"$'\n'
            done <<< "$REFERENCES"
        fi
        if [ -n "$WIRED_HOOKS" ]; then
            while IFS=$'\t' read -r rf rln rtext rcls; do
                [ -z "$rf" ] && continue
                block="${block}        wired hooks: ${rf}:${rln} $(_loom_trim "$rtext")  <- will dangle"$'\n'
            done <<< "$WIRED_HOOKS"
        fi
        if [ -n "$COUNTERPARTS" ]; then
            while IFS=$'\t' read -r cf cc ce; do
                [ -z "$cf" ] && continue
                if [ "$ce" = "true" ]; then
                    block="${block}        counterpart: ${cf} -> ${cc} (exists)"$'\n'
                else
                    block="${block}        counterpart: ${cf} -> ${cc} (absent)"$'\n'
                fi
            done <<< "$COUNTERPARTS"
        fi
        [ -n "$ci" ] && block="${block}        ci notices if kept: $(printf '%s' "$ci" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"$'\n'
        block="${block}        recommended: ${REC_ACTION}"
        [ -n "$REC_REASON" ] && block="${block}  (${REC_REASON})"
        if [ "$REC_BLOCKED" = "true" ]; then
            block="${block} (blocked by: $(human_blocked_by))"
        fi
        # Low finding (round 5 review): resolve_baseline treats bytes that
        # are merely COINCIDENTALLY identical to an upstream/receipt blob as
        # pristine, REMOVE-eligible — not just a provably-tracked LogicLoom
        # copy. No bytes are lost either way (identical to upstream by
        # definition), but the plan text should say so plainly and name the
        # exact command to bring the path back, rather than leave the
        # reader to work out git recovery mechanics themselves after the
        # fact.
        if [ "$REC_ACTION" = "REMOVE" ] && [ "${STATE:-}" = "pristine" ]; then
            # Medium finding (round-2 review): "pristine" via a receipt-sha256
            # baseline (resolve_state's receipt-sha256 branch) is set from a
            # pure byte comparison — it never checks that $path is tracked at
            # HEAD. `git checkout HEAD -- $path` only ever restores a path
            # HEAD actually has; printed unconditionally it is misleading
            # advice for a path that reached "pristine" purely by matching a
            # receipt hash (e.g. corroborated via upstream history, never
            # committed to THIS repo's HEAD). Check first, word the advice to
            # match, and single-quote $path both places so it prints and
            # copy-pastes correctly even if $path ever contains a space.
            if git -C "$REPO_ROOT" rev-parse --verify -q "HEAD:$path" >/dev/null 2>&1; then
                block="${block}"$'\n'"        recoverable: removing a pristine path never loses bytes — before committing, \`git checkout HEAD -- '$path'\` restores it; after committing, \`git revert <the removal commit>\` or \`git checkout <commit-before-removal> -- '$path'\` does"
            else
                block="${block}"$'\n'"        recoverable: '$path' is not tracked at HEAD (this baseline came from a receipt/upstream match, not a commit in this repo) — \`git checkout HEAD -- '$path'\` will NOT restore it; recover the bytes from wherever this baseline actually lives instead"
            fi
        fi
        local menu=""
        case "$kind" in
            plugin) menu="[r]emove  [c]onvert-to-local  [k]eep  [s]kip" ;;
            mcp-server|path)
                if [ "$REC_ACTION" = "MOVE" ]; then menu="[m]ove  [k]eep  [s]kip"; else menu="[r]emove  [k]eep  [s]kip"; fi ;;
        esac
        [ -n "$menu" ] && block="${block}"$'\n'"        ${menu}"
        ITEMS_HUMAN="${ITEMS_HUMAN}${block}"$'\n'
    fi
    return 0
}

process_deprecation_rows() {
    local rows="$1" source="$2" json_mode="$3"
    [ -z "$rows" ] && return 0
    while IFS= read -r row; do
        [ -z "$row" ] && continue
        emit_deprecation_item "$source" "$row" "$json_mode" || true
    done <<< "$rows"
}

# Content rows: match by literal path or glob (name field).
content_matches() {
    local name="$1"
    case "$name" in
        *\**|*\?*)
            # Round-6 finding (medium, fail-open): this branch used to end
            # with an unconditional `return 0` below, so a `find` that
            # failed PARTWAY (a subdirectory it cannot read, the same class
            # already fixed in unconverted_plugin_files) was indistinguishable
            # from "the glob legitimately matched nothing" — both produced
            # empty output and a zero return. Callers (check-release's
            # content-row proof, scan's content-row detection) then read a
            # failed enumeration as "nothing to verify/propose" and moved on
            # silently. Propagate the pipeline's real exit status (this
            # script runs with `set -o pipefail`, so it already reflects a
            # failing `find` even though `_loom_rm_strip_prefix` succeeds)
            # instead of masking it.
            local _cm_rc
            find "$REPO_ROOT" \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/node_modules" \) -prune \
                -o -type f -path "$REPO_ROOT/$name" -print 2>/dev/null \
                | _loom_rm_strip_prefix "$REPO_ROOT/"
            _cm_rc=$?
            return "$_cm_rc" ;;
        *)
            # A single `-f` stat cannot fail partway the way a multi-file
            # `find` walk can, so this branch has nothing to propagate: no
            # match is unambiguously "not a match", not "could not check".
            [ -f "$REPO_ROOT/$name" ] && printf '%s\n' "$name"
            return 0 ;;
    esac
}

emit_content_item() {
    local source="$1" row="$2" json_mode="$3"
    local kind name fate repl default first release note
    IFS=$'\t' read -r kind name fate repl default first release note <<< "$row"
    [ "$kind" = "content" ] || return 1
    local pattern="${repl#pattern:}"

    local matched_files matched_files_rc=0
    matched_files="$(content_matches "$name")" || matched_files_rc=$?
    # Round-6 finding (medium, fail-open): a failed enumeration (rc != 0,
    # content_matches now propagates it — see its own comment) is not the
    # same as "the glob matched nothing" (rc 0, empty output). This
    # function has no in-band way to report "could not verify" without
    # changing the scan/plan item schema every consumer of this function's
    # stdout depends on, so — same disposition as this round's other
    # observability-only fix (record-update-writes.sh's empty-version
    # generator warning) — surface it on stderr, which scan/plan do NOT
    # redirect away, rather than let it pass in total silence; the
    # skip-this-row behavior itself is unchanged (nothing was silently
    # promoted to a false proposal either).
    if [ "$matched_files_rc" -ne 0 ]; then
        echo "WARNING: content row '$name': could not enumerate matching files — find exited $matched_files_rc (e.g. a subdirectory it cannot read); this row's detection is skipped, not proven absent" >&2
    fi
    [ -z "$matched_files" ] && return 1

    local is_advisory="false"
    [ "$default" = "PROPOSE-ADVISORY" ] && is_advisory="true"

    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        # Ownership scoping (ADOPTED mode) only applies to content the
        # harness itself might have written — an advisory (KORI CLASS) row
        # targets a fork-owned file update-framework never wrote a byte of,
        # so there is no adopt-receipt entry to require and this row must
        # fire the same way in TEMPLATE and ADOPTED alike.
        if [ "$is_advisory" != "true" ] && [ "${ADOPT_MODE:-TEMPLATE}" = "ADOPTED" ] && [ "$source" != "project" ]; then
            if [ "$f" != ".logicloom-adopt-receipt.json" ] && ! adopt_file_recorded "$f"; then
                continue
            fi
        fi
        local hits
        hits="$(grep -nIE -- "$pattern" "$REPO_ROOT/$f" 2>/dev/null)" || hits=""
        local emit="false"
        if [ "$fate" = "present" ] && [ -n "$hits" ]; then emit="true"; fi
        if [ "$fate" = "absent" ] && [ -z "$hits" ]; then emit="true"; fi
        [ "$emit" = "true" ] || continue

        ITEM_ID_N=$((ITEM_ID_N + 1)); local id; id="$(printf 'MG-%03d' "$ITEM_ID_N")"
        local decision=""
        decision="$(lookup_decision "$name" "$release" "$f" 2>/dev/null)" || decision=""
        local recommended="PROPOSE" reason=""
        local proposal="${note#*proposal: }"; proposal="${proposal%%; why:*}"; proposal="${proposal%%; fixture:*}"
        local why="${note#*why: }"; why="${why%%; fixture:*}"
        local advisory_prefix=""
        [ "$is_advisory" = "true" ] && advisory_prefix="ADVISORY — LogicLoom did not ship this text (it is your own file); this proposal is informational only and is never applied automatically: "
        if [ "$decision" = "keep" ]; then
            recommended="KEEP-AS-IS"
            reason="acknowledged"
            KEPT_N=$((KEPT_N + 1))
        else
            [ "$is_advisory" = "true" ] && recommended="PROPOSE-ADVISORY"
            PENDING_N=$((PENDING_N + 1))
            reason="${advisory_prefix}${why}"
        fi

        if [ "$json_mode" = "true" ]; then
            local jmatches="[" fr=1
            if [ -n "$hits" ]; then
                while IFS= read -r hl; do
                    [ -z "$hl" ] && continue
                    local hln htxt
                    hln="${hl%%:*}"; htxt="${hl#*:}"
                    [ "$fr" -eq 0 ] && jmatches="${jmatches},"
                    jmatches="${jmatches}{\"line\":$hln,\"text\":\"$(json_escape "$(truncate120 "$htxt")")\"}"
                    fr=0
                done <<< "$(printf '%s\n' "$hits" | head -20)"
            fi
            jmatches="${jmatches}]"
            local item="{\"id\":\"$id\",\"kind\":\"content\",\"source\":\"$source\",\"path\":\"$(json_escape "$f")\",\"release\":\"$release\",\"fate\":\"$fate\",\"pattern\":\"$(json_escape "$pattern")\",\"advisory\":$( [ "$is_advisory" = "true" ] && echo true || echo false ),\"matches\":$jmatches,\"proposal\":\"$(json_escape "$proposal")\",\"why\":\"$(json_escape "$why")\",\"decision\":\"$decision\",\"recommended\":\"$recommended\",\"reason\":\"$(json_escape "$reason")\",\"blocked\":false,\"blocked_by\":[],\"remove_command\":\"\",\"move_command\":\"\"}"
            [ -n "$ITEMS_JSON" ] && ITEMS_JSON="${ITEMS_JSON},"
            ITEMS_JSON="${ITEMS_JSON}${item}"
        else
            local block
            block="$id  $f   content check ($release)"$'\n'
            if [ "$is_advisory" = "true" ]; then
                block="${block}        ADVISORY — LogicLoom did not ship this text (it is your own file); this proposal is informational only and is never applied automatically"$'\n'
            fi
            if [ -n "$hits" ]; then
                while IFS= read -r hl; do
                    [ -z "$hl" ] && continue
                    local hln htxt
                    hln="${hl%%:*}"; htxt="${hl#*:}"
                    block="${block}        matches: ${f}:${hln}:$(truncate120 "$htxt")"$'\n'
                done <<< "$(printf '%s\n' "$hits" | head -20)"
            fi
            block="${block}        proposal: ${proposal}"$'\n'
            block="${block}        why: ${why}"$'\n'
            block="${block}        recommended: ${recommended}  [k]eep  [s]kip"
            ITEMS_HUMAN="${ITEMS_HUMAN}${block}"$'\n'
        fi
    done <<< "$matched_files"
    return 0
}

process_content_rows() {
    local all_rows="$1" source="$2" json_mode="$3"
    [ -z "$all_rows" ] && return 0
    while IFS= read -r row; do
        [ -z "$row" ] && continue
        local k; k="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"
        [ "$k" = "content" ] || continue
        emit_content_item "$source" "$row" "$json_mode" || true
    done <<< "$all_rows"
}

# plugins/loom-* and plugins/sdd-* directories that are neither a registry
# row (either registry) nor declared in CLAUDE.md's Plugin Registry table.
process_orphans() {
    local declared="$1" json_mode="$2"
    local d name row_names
    row_names="$(all_deprecation_names)"
    for d in "$REPO_ROOT"/plugins/*/; do
        [ -d "$d" ] || continue
        name="${d%/}"; name="${name##*/}"
        case "$name" in loom-*|sdd-*) ;; *) continue ;; esac
        if printf '%s\n' "$declared" | grep -qx "$name"; then continue; fi
        if printf '%s\n' "$row_names" | grep -qx "$name"; then continue; fi
        ITEM_ID_N=$((ITEM_ID_N + 1)); local id; id="$(printf 'MG-%03d' "$ITEM_ID_N")"
        PENDING_N=$((PENDING_N + 1))
        if [ "$json_mode" = "true" ]; then
            local item="{\"id\":\"$id\",\"kind\":\"orphan\",\"source\":\"upstream\",\"path\":\"plugins/$name\",\"state\":\"unknown\",\"recommended\":\"KEEP-AS-IS\",\"reason\":\"carries the harness namespace but LogicLoom never shipped it under this name; rename it out of loom-*/sdd-* or it will keep tripping the floor test\",\"blocked\":false,\"blocked_by\":[],\"remove_command\":\"\",\"move_command\":\"\"}"
            [ -n "$ITEMS_JSON" ] && ITEMS_JSON="${ITEMS_JSON},"
            ITEMS_JSON="${ITEMS_JSON}${item}"
        else
            local block
            block="$id  plugins/$name   orphan (state: unknown)"$'\n'
            block="${block}        recommended: KEEP-AS-IS  (carries the harness namespace but LogicLoom never shipped it under this name; rename it out of loom-*/sdd-* or it will keep tripping the floor test)"
            ITEMS_HUMAN="${ITEMS_HUMAN}${block}"$'\n'
        fi
    done
    return 0
}

compute_dangling() {
    local json_mode="$1"
    local settings="$REPO_ROOT/.claude/settings.json"
    local all_dep
    all_dep="$(loom_deprecation_rows "$REGISTRY_FILE" 2>/dev/null)" || all_dep=""
    if [ -n "$PROJECT_REGISTRY_FILE" ]; then
        local proj; proj="$(loom_deprecation_rows "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || proj=""
        [ -n "$proj" ] && all_dep="${all_dep}"$'\n'"${proj}"
    fi
    [ -z "$all_dep" ] && return 0
    if [ -f "$settings" ]; then
        local row kind name path
        while IFS=$'\t' read -r kind name fate repl default first release note; do
            [ -z "$kind" ] && continue
            path="$(loom_deprecation_dir "$kind" "$name")" || continue
            [ -e "$REPO_ROOT/$path" ] && continue
            local hit
            hit="$(grep -nF "$path/" "$settings" 2>/dev/null | grep -F '"command"')" || hit=""
            [ -z "$hit" ] && continue
            while IFS= read -r hl; do
                [ -z "$hl" ] && continue
                local hln htxt
                hln="${hl%%:*}"; htxt="${hl#*:}"
                if [ "$json_mode" = "true" ]; then
                    [ -n "$DANGLING_HOOKS_JSON" ] && DANGLING_HOOKS_JSON="${DANGLING_HOOKS_JSON},"
                    DANGLING_HOOKS_JSON="${DANGLING_HOOKS_JSON}{\"file\":\".claude/settings.json\",\"line\":$hln,\"text\":\"$(json_escape "$(truncate120 "$htxt")")\"}"
                else
                    DANGLING_HOOKS_HUMAN="${DANGLING_HOOKS_HUMAN}.claude/settings.json:${hln} $(truncate120 "$htxt")"$'\n'
                fi
            done <<< "$hit"
        done <<< "$all_dep"
    fi
    local mcpjson="$REPO_ROOT/.mcp.json"
    if [ -f "$mcpjson" ]; then
        local kind name
        while IFS=$'\t' read -r kind name fate repl default first release note; do
            [ -z "$kind" ] && continue
            [ "$kind" = "mcp-server" ] || continue
            [ -d "$REPO_ROOT/mcp-servers/$name" ] && continue
            local hit
            hit="$(grep -nE "\"$name\":|mcp-servers/$name" "$mcpjson" 2>/dev/null)" || hit=""
            [ -z "$hit" ] && continue
            while IFS= read -r hl; do
                [ -z "$hl" ] && continue
                local hln htxt
                hln="${hl%%:*}"; htxt="${hl#*:}"
                if [ "$json_mode" = "true" ]; then
                    [ -n "$DANGLING_MCP_JSON" ] && DANGLING_MCP_JSON="${DANGLING_MCP_JSON},"
                    DANGLING_MCP_JSON="${DANGLING_MCP_JSON}{\"file\":\".mcp.json\",\"line\":$hln,\"text\":\"$(json_escape "$(truncate120 "$htxt")")\"}"
                else
                    DANGLING_MCP_HUMAN="${DANGLING_MCP_HUMAN}.mcp.json:${hln} $(truncate120 "$htxt")"$'\n'
                fi
            done <<< "$hit"
        done <<< "$all_dep"
    fi
    return 0
}

DECISIONS_HUMAN=""
DECISIONS_JSON=""

compute_decisions_briefing() {
    local json_mode="$1"
    [ -f "$DECISIONS_FILE" ] || return 0
    local line trimmed verb rhs dname drelease
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="$(_loom_trim "$line")"
        [ -z "$trimmed" ] && continue
        [ "${trimmed#\#}" != "$trimmed" ] && continue
        case "$trimmed" in *=*) : ;; *) continue ;; esac
        verb="$(_loom_trim "${trimmed%%=*}")"
        rhs="$(_loom_trim "${trimmed#*=}")"
        case "$rhs" in
            *@*) dname="$(_loom_trim "${rhs%@*}")"; drelease="$(_loom_trim "${rhs##*@}")" ;;
            *) dname="$rhs"; drelease="" ;;
        esac
        local stale="false" consequence="" path=""
        local dep_row any_row content_row=""
        dep_row="$(loom_deprecation_row "$dname" "$REGISTRY_FILE" 2>/dev/null)" || dep_row=""
        if [ -z "$dep_row" ] && [ -n "$PROJECT_REGISTRY_FILE" ]; then
            dep_row="$(loom_deprecation_row "$dname" "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || dep_row=""
        fi
        if [ -z "$dep_row" ]; then
            any_row="$(loom_migration_row "$dname" "$REGISTRY_FILE" 2>/dev/null)" || any_row=""
            if [ -z "$any_row" ] && [ -n "$PROJECT_REGISTRY_FILE" ]; then
                any_row="$(loom_migration_row "$dname" "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || any_row=""
            fi
            case "$(printf '%s' "$any_row" | awk -F'\t' '{print $1}')" in content) content_row="$any_row" ;; esac
        fi
        # stale = names no registry row, or a plugin/mcp-server/path decision
        # whose path is absent on disk.
        case "$verb" in
            keep)
                if [ -n "$dep_row" ]; then
                    local dkind
                    dkind="$(printf '%s' "$dep_row" | awk -F'\t' '{print $1}')"
                    path="$(loom_deprecation_dir "$dkind" "$dname")"
                    if [ ! -e "$REPO_ROOT/$path" ]; then
                        stale="true"
                        consequence="names nothing on disk and no registry row — remove the line"
                    elif [ "$dkind" = "plugin" ]; then
                        consequence="$path stays as-is: no upstream updates ever; CI notices it raises: floor test 1b info line, manifest validator SKIPPED line, lifecycle suite pending-migration notice; its commands resolve only through their bridge wrappers"
                    else
                        consequence="$path stays; no upstream updates"
                    fi
                elif [ -n "$content_row" ]; then
                    path="$dname"
                    consequence="content check silenced for ${drelease:-every release}; nothing else is affected"
                else
                    stale="true"
                    consequence="names nothing on disk and no registry row — remove the line"
                fi ;;
            converted)
                path="plugins/$dname"
                if [ -n "$dep_row" ] && [ -d "$REPO_ROOT/$path" ]; then
                    # Finding 3: never hand-roll this text — it must agree
                    # with what compute_recommendation would say for the same
                    # plugin, so both surfaces are driven off the one shared
                    # status helper.
                    _loom_rm_converted_briefing_consequence "$dname" "$path"
                    consequence="$CONV_BRIEF_CONSEQUENCE"
                else
                    stale="true"
                    consequence="names nothing on disk and no registry row — remove the line"
                fi ;;
            *) stale="true"; consequence="names nothing on disk and no registry row — remove the line" ;;
        esac
        if [ "$json_mode" = "true" ]; then
            [ -n "$DECISIONS_JSON" ] && DECISIONS_JSON="${DECISIONS_JSON},"
            DECISIONS_JSON="${DECISIONS_JSON}{\"verb\":\"$verb\",\"name\":\"$(json_escape "$dname")\",\"release\":\"$(json_escape "$drelease")\",\"path\":\"$(json_escape "$path")\",\"consequence\":\"$(json_escape "$consequence")\",\"stale\":$( [ "$stale" = "true" ] && echo true || echo false )}"
        else
            local label="$dname"
            [ -n "$drelease" ] && label="${dname}@${drelease}"
            DECISIONS_HUMAN="${DECISIONS_HUMAN}  $(printf '%-10s' "$verb") $(printf '%-18s' "$label") ${consequence}"$'\n'
        fi
    done < "$DECISIONS_FILE"
    return 0
}

cmd_scan() {
    local json_mode="false" registry_arg=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) json_mode="true"; shift ;;
            # Round-6 finding (low): see cmd_lint's identical fix above.
            --root) [ $# -ge 2 ] || die_usage "scan: --root requires a value"; shift 2 ;;
            --registry) registry_arg="$2"; shift 2 ;;
            *) die_usage "scan: unknown argument '$1'" ;;
        esac
    done

    resolve_registry "$registry_arg"
    resolve_project_registry ""
    _loom_rm_init_adopt_mode

    local fv version
    fv="$(framework_version 2>/dev/null)" || fv="0.0.0"
    version="$(normalize_version "${fv:-0.0.0}")"

    local rel_rows rel_count=0
    rel_rows="$(loom_migration_rows_for_release "$version" "$REGISTRY_FILE" 2>/dev/null)" || rel_rows=""
    [ -n "$rel_rows" ] && rel_count="$(count_lines "$rel_rows")"

    local dep_rows
    dep_rows="$(loom_deprecation_rows "$REGISTRY_FILE" 2>/dev/null)" || dep_rows=""
    process_deprecation_rows "$dep_rows" "upstream" "$json_mode"
    if [ -n "$PROJECT_REGISTRY_FILE" ]; then
        local proj_dep
        proj_dep="$(loom_deprecation_rows "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || proj_dep=""
        process_deprecation_rows "$proj_dep" "project" "$json_mode"
    fi

    local all_rows
    all_rows="$(loom_migration_rows "$REGISTRY_FILE" 2>/dev/null)" || all_rows=""
    process_content_rows "$all_rows" "upstream" "$json_mode"
    if [ -n "$PROJECT_REGISTRY_FILE" ]; then
        local proj_all
        proj_all="$(loom_migration_rows "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || proj_all=""
        process_content_rows "$proj_all" "project" "$json_mode"
    fi

    local orphan_check="run"
    local declared
    declared="$(declared_harness_plugins_local)"
    if [ -z "$declared" ]; then
        orphan_check="skipped"
    else
        process_orphans "$declared" "$json_mode"
    fi

    compute_dangling "$json_mode"
    compute_decisions_briefing "$json_mode"

    if [ "$json_mode" = "true" ]; then
        printf '{"registry":"%s","rows":%s,"project_rows":%s,"release":"%s","orphan_check":"%s","items":[%s],"dangling_hooks":[%s],"dangling_mcp":[%s],"decisions":[%s],"summary":{"pending":%s,"kept":%s,"converted":%s}}\n' \
            "$REGISTRY_SOURCE" "$REGISTRY_ROWS" "$PROJECT_REGISTRY_ROWS" "$version" "$orphan_check" \
            "$ITEMS_JSON" "$DANGLING_HOOKS_JSON" "$DANGLING_MCP_JSON" "$DECISIONS_JSON" \
            "$PENDING_N" "$KEPT_N" "$CONVERTED_N"
        return 0
    fi

    registry_header_lines
    if [ "$rel_count" -eq 0 ]; then
        echo "this release ($version): none declared"
    else
        echo "this release ($version): $rel_count migration row(s) declared"
    fi
    if [ "$orphan_check" = "skipped" ]; then
        echo "orphan check: skipped (no Plugin Registry table in CLAUDE.md)"
    else
        echo "orphan check: run"
    fi
    echo ""

    if [ -z "$ITEMS_HUMAN" ]; then
        echo "Release migrations: none pending."
    else
        printf '%s' "$ITEMS_HUMAN"
        if [ -n "$DANGLING_HOOKS_HUMAN" ]; then
            echo "Dangling hook wiring (plugin already gone):"
            printf '%s' "$DANGLING_HOOKS_HUMAN"
        fi
        if [ -n "$DANGLING_MCP_HUMAN" ]; then
            echo "Dangling .mcp.json entries (server already gone):"
            printf '%s' "$DANGLING_MCP_HUMAN"
        fi
    fi

    if [ -n "$DECISIONS_HUMAN" ]; then
        echo ""
        echo "Decisions in force (.logic-loom/config/migration-decisions.conf — edit or delete a line to revisit)"
        printf '%s' "$DECISIONS_HUMAN"
    fi

    echo ""
    echo "Summary: $PENDING_N pending, $KEPT_N kept (acknowledged), $CONVERTED_N converted (delete when verified)"
    return 0
}

# ============================================================================
# plan
# ============================================================================

cmd_plan() {
    local registry_arg="" name=""
    while [ $# -gt 0 ]; do
        case "$1" in
            # Round-6 finding (low): see cmd_lint's identical fix above.
            --root) [ $# -ge 2 ] || die_usage "plan: --root requires a value"; shift 2 ;;
            --registry) registry_arg="$2"; shift 2 ;;
            -*) die_usage "plan: unknown argument '$1'" ;;
            *) name="$1"; shift ;;
        esac
    done
    [ -n "$name" ] || die_usage "plan: <name> is required"

    resolve_registry "$registry_arg"
    resolve_project_registry ""
    _loom_rm_init_adopt_mode

    local row
    row="$(loom_migration_row "$name" "$REGISTRY_FILE" 2>/dev/null)" || row=""
    local source="upstream"
    if [ -z "$row" ] && [ -n "$PROJECT_REGISTRY_FILE" ]; then
        row="$(loom_migration_row "$name" "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || row=""
        source="project"
    fi
    [ -n "$row" ] || die_usage "plan: no registry row named '$name'"

    local kind
    kind="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"

    ITEMS_HUMAN=""
    if [ "$kind" = "content" ]; then
        emit_content_item "$source" "$row" "false" || true
    else
        emit_deprecation_item "$source" "$row" "false" || true
    fi

    if [ -z "$ITEMS_HUMAN" ]; then
        echo "plan: '$name' has no on-disk item (its path/file does not exist — nothing to plan)"
        return 0
    fi
    printf '%s' "$ITEMS_HUMAN"

    if [ -n "${REFERENCES:-}" ]; then
        local other_refs=""
        while IFS=$'\t' read -r rf rln rtext rcls; do
            [ -z "$rf" ] && continue
            case "$rcls" in
                docs|bridge-wrapper) : ;;
                *) other_refs="${other_refs}${rf}:${rln} " ;;
            esac
        done <<< "$REFERENCES"
        [ -n "$other_refs" ] && echo "repoint or remove these references first: $other_refs"
    fi
    if [ "${REC_BLOCKED:-false}" = "true" ]; then
        echo "BLOCKED until: $(human_blocked_by) no longer reference $(printf '%s' "$row" | awk -F'\t' '{print $2}') (repoint or remove them first)"
    fi

    case "${REC_ACTION:-}" in
        REMOVE)
            case "$kind" in
                plugin)
                    local wrappers
                    wrappers="$(bridge_wrapper_files | tr '\n' ' ' | sed 's/ $//')"
                    [ -z "$wrappers" ] && wrappers="(none found)"
                    echo "${REC_REMOVE_CMD} (gate policy git.rm = ask, so you approve it), then .logic-loom/scripts/bash/sync-plugin-commands.sh prune to drop the bridge wrapper(s) ${wrappers}. Replaced by: $(printf '%s' "$row" | awk -F'\t' '{print $4}')."
                    ;;
                mcp-server)
                    echo "1. remove the \"$(printf '%s' "$row" | awk -F'\t' '{print $2}')\": entry from .mcp.json (the main agent edits it on your yes, showing the diff first — .mcp.json is not a protected file)."
                    echo "2. ${REC_REMOVE_CMD} (gate policy git.rm = ask, so you approve it). Replaced by: $(printf '%s' "$row" | awk -F'\t' '{print $4}')."
                    ;;
                path)
                    echo "${REC_REMOVE_CMD} (gate policy git.rm = ask, so you approve it). Replaced by: $(printf '%s' "$row" | awk -F'\t' '{print $4}')."
                    ;;
            esac ;;
        MOVE)
            echo "${REC_MOVE_CMD} (gate policy git.mv = ask, so you approve it). Replaced by: $(printf '%s' "$row" | awk -F'\t' '{print $4}')."
            echo "the command above re-checks the destination right before it moves anything and refuses (never overwrites) if something has landed there since this was planned — re-run plan $name to get a fresh recommendation either way."
            ;;
        CONVERT-TO-LOCAL|ADOPT-REPLACEMENT)
            echo ""
            echo "convert $name --dry-run:"
            cmd_convert "$name" --dry-run --root "$REPO_ROOT" --registry "$REGISTRY_FILE" || true
            ;;
    esac
    return 0
}

# ============================================================================
# convert
# ============================================================================

insert_marker() {
    local content="$1" plugin="$2" relpath="$3"
    local marker="<!-- converted-from: plugins/${plugin}/${relpath} | logicloom-plugin-deprecations v1 | project-owned: upstream never updates this file -->"
    if printf '%s\n' "$content" | head -1 | grep -q '^---$'; then
        printf '%s\n' "$content" | awk -v m="$marker" '
            NR==1 && $0=="---" { print; infm=1; next }
            infm==1 && $0=="---" { print; print m; infm=0; next }
            { print }'
    else
        printf '%s\n%s\n' "$marker" "$content"
    fi
}

detect_model_rewrite_needed() {
    local content="$1" val
    val="$(printf '%s\n' "$content" | awk '
        BEGIN{infm=0}
        NR==1 && $0=="---" { infm=1; next }
        infm==1 && $0=="---" { exit }
        infm==1 && $0 ~ /^model:[ \t]*/ { sub(/^model:[ \t]*/,""); gsub(/[ \t]+$/,""); print; exit }')"
    [ -z "$val" ] && return 1
    case "$val" in opus|sonnet|haiku|inherit) return 1 ;; esac
    return 0
}

apply_model_rewrite() {
    printf '%s\n' "$1" | awk '
        BEGIN{infm=0}
        NR==1 && $0=="---" { infm=1; print; next }
        infm==1 && $0=="---" { infm=0; print; next }
        infm==1 && $0 ~ /^model:[ \t]*/ { print "model: opus"; next }
        { print }'
}

extract_fm_field() {
    local file="$1" field="$2"
    [ -f "$file" ] || return 0
    awk -v f="$field" '
        BEGIN{infm=0}
        NR==1 && $0=="---" { infm=1; next }
        infm==1 && $0=="---" { exit }
        infm==1 && $0 ~ "^"f":" { sub("^"f":[ \t]*",""); print; exit }' "$file"
}

# Round-4 finding (low): escapes a value for safe interpolation into a
# `s|pattern|replacement|g` line whose delimiter is `|`. Two rules, because
# the two sides of a substitution mean different things: the PATTERN side
# is a BRE, where `. * [ ^ $ \` change what gets matched rather than
# matching themselves, and `|` would end the field early since it is our
# chosen delimiter; the REPLACEMENT side only treats `& \` specially (a
# bare `&` re-inserts the whole match) plus the same delimiter risk. Unit
# and plugin names are conventionally kebab-case (see CLAUDE.md's naming
# table), so this rarely fires — but a name that departs from it (a dot, a
# literal `$`, an `&`) used to corrupt the rendered file silently while the
# unit still got marked "accounted for".
_loom_rm_sed_escape_pattern() {
    printf '%s' "$1" | sed 's/[][\.*^$|]/\\&/g'
}
_loom_rm_sed_escape_repl() {
    printf '%s' "$1" | sed 's/[\&|]/\\&/g'
}

build_rewrite_sed() {
    local plugin="$1" sedfile="$2"
    local plugin_pat plugin_repl
    plugin_pat="$(_loom_rm_sed_escape_pattern "$plugin")"
    plugin_repl="$(_loom_rm_sed_escape_repl "$plugin")"
    : > "$sedfile"
    {
        printf 's|\\${CLAUDE_PLUGIN_ROOT}|.claude/skills/%s|g\n' "$plugin_repl"
        printf 's|\\$CLAUDE_PLUGIN_ROOT|.claude/skills/%s|g\n' "$plugin_repl"
        # Round-5 finding 6 (low, unquoted word-splitting/glob risk): an
        # unquoted `for x in $LIST` both word-splits on EVERY IFS
        # character (not just the newlines this list is actually joined
        # by — a unit name containing a literal space would itself split
        # into two bogus loop iterations) AND glob-expands each resulting
        # word against files in $PWD. SKILL_UNITS/COMMAND_UNITS/AGENT_UNITS
        # are newline-per-entry by construction (build_convert_units'
        # `find | ...`), so `while IFS= read -r` is both the correct
        # delimiter (newline only) and immune to glob expansion — the same
        # NUL/newline-safe-loop idiom this diff already uses elsewhere
        # (.docs/policies/shell-idiom-policy.md §7) instead of reaching for
        # it here too. An empty list still runs the loop body once with an
        # empty line (a bare `<<<` here-string always feeds one line, even
        # empty), which is why the existing `[ -z ... ] && continue` guard
        # stays — unchanged from the unquoted-for version's own zero-length
        # handling.
        local s s_pat s_repl
        while IFS= read -r s; do
            [ -z "$s" ] && continue
            s_pat="$(_loom_rm_sed_escape_pattern "$s")"; s_repl="$(_loom_rm_sed_escape_repl "$s")"
            printf 's|plugins/%s/skills/%s|.claude/skills/%s|g\n' "$plugin_pat" "$s_pat" "$s_repl"
        done <<< "$SKILL_UNITS"
        local c c_pat c_repl
        while IFS= read -r c; do
            [ -z "$c" ] && continue
            c_pat="$(_loom_rm_sed_escape_pattern "$c")"; c_repl="$(_loom_rm_sed_escape_repl "$c")"
            printf 's|plugins/%s/commands/%s\\.md|.claude/skills/%s/SKILL.md|g\n' "$plugin_pat" "$c_pat" "$c_repl"
        done <<< "$COMMAND_UNITS"
        local a a_pat a_repl
        while IFS= read -r a; do
            [ -z "$a" ] && continue
            a_pat="$(_loom_rm_sed_escape_pattern "$a")"; a_repl="$(_loom_rm_sed_escape_repl "$a")"
            printf 's|plugins/%s/agents/%s\\.md|.claude/agents/%s.md|g\n' "$plugin_pat" "$a_pat" "$a_repl"
        done <<< "$AGENT_UNITS"
        printf 's|plugins/%s/|.claude/skills/%s/|g\n' "$plugin_pat" "$plugin_repl"
    } >> "$sedfile"
}

apply_path_rewrites() {
    local content="$1" plugin="$2" sedfile
    # Medium finding (round-2 review): neither mktemp's exit status nor the
    # sed pipeline's was checked. A failed mktemp (TMPDIR unwritable/full)
    # fed `sed -f ""` an empty filename, which errors under this script's
    # `-uo pipefail` (no `-e`, see the top-of-file rationale) WITHOUT
    # stopping the caller — the pipeline's (likely empty) stdout was used
    # unconditionally as the rendered content, written, WROTE-logged, and
    # counted as accounted-for, with the plugin's real content never
    # byte-verified to have reached the target. Check both explicitly; on
    # either failure, fall back to the ORIGINAL, unrewritten content (never
    # empty) so a real write still carries real bytes, and mark the run
    # stopped via WRITE_FAILED so `converted =` is never recorded from it.
    sedfile="$(mktemp "${TMPDIR:-/tmp}/loom-rw.XXXXXX" 2>/dev/null)"
    if [ -z "$sedfile" ] || [ ! -f "$sedfile" ]; then
        echo "ERROR apply_path_rewrites: mktemp failed for plugins/$plugin — path rewrites skipped, unrewritten content used" >&2
        WRITE_FAILED="true"
        printf '%s\n' "$content"
        return 1
    fi
    build_rewrite_sed "$plugin" "$sedfile"
    local rewritten rc=0
    rewritten="$(printf '%s\n' "$content" | sed -f "$sedfile")" || rc=$?
    rm -f "$sedfile"
    if [ "$rc" -ne 0 ]; then
        echo "ERROR apply_path_rewrites: sed -f failed for plugins/$plugin — path rewrites skipped, unrewritten content used" >&2
        WRITE_FAILED="true"
        printf '%s\n' "$content"
        return 1
    fi
    printf '%s\n' "$rewritten"
}

plan_convert_units() {
    local plugin="$1" plugin_dir
    plugin_dir="$REPO_ROOT/plugins/$plugin"
    # Reviewer round 2: prefix stripped by parameter expansion, never by a
    # sed expression with the checkout path interpolated as its pattern —
    # see _loom_rm_strip_prefix for the fail-open that closed. The `.md`
    # suffix strip below has nothing interpolated and stays sed.
    #
    # Round-3 review finding (high, data-loss): COMMAND_UNITS/AGENT_UNITS
    # used `-name '*.md'` with NO `-type f`, so a symlink named e.g.
    # evilcmd.md directly under commands/ or agents/ (pointed at a file
    # anywhere on disk, including outside the plugin or the repo) matched by
    # basename exactly like a real command/agent file — convert_command_unit
    # and convert_agent_unit both `cat` their `$src` unconditionally, so the
    # link's TARGET content was read through and written into
    # .claude/skills/<cmd>/SKILL.md or .claude/agents/<agent>.md, counted as
    # carried over, and never reported as "Not carried over" by
    # unconverted_plugin_files() because it WAS mapped. `-type f` matches by
    # lstat (no `-L`) so a symlink entry — to a file or a directory — is
    # excluded from both lists the same way a directory named foo.md already
    # was; it is left for unconverted_plugin_files()'s `! -type d` walk to
    # report, the same documented "symlinks are never converted" contract
    # convert_hooks_and_support() upholds for generic plugin-root entries.
    # SKILL_UNITS is unaffected — `-type d` already excludes a symlink (even
    # one pointing at a real directory) by the same lstat rule.
    #
    # Round-3 REVIEWER: skills/, commands/ or agents/ being a symlink to a
    # directory was safe only by the same find quirk the comment above
    # leans on (a link given AS the start point is not descended, on GNU,
    # BSD and bfs alike — probed on all three). Make it explicit: a
    # symlinked unit directory yields no units, and the link is left for
    # unconverted_plugin_files()'s `! -type d` walk to report, so the
    # contract no longer depends on which find is on PATH.
    SKILL_UNITS=""; COMMAND_UNITS=""; AGENT_UNITS=""
    [ -L "$plugin_dir/skills" ] || SKILL_UNITS="$(find "$plugin_dir/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | _loom_rm_strip_prefix "$plugin_dir/skills/")"
    [ -L "$plugin_dir/commands" ] || COMMAND_UNITS="$(find "$plugin_dir/commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null | _loom_rm_strip_prefix "$plugin_dir/commands/" | sed 's/\.md$//')"
    [ -L "$plugin_dir/agents" ] || AGENT_UNITS="$(find "$plugin_dir/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null | _loom_rm_strip_prefix "$plugin_dir/agents/" | sed 's/\.md$//')"
}

unit_touched() {
    # Round-5 finding 6 (low, ERE-interpolation risk): $full used to be
    # spliced straight into a `grep -E` PATTERN operand. Plugin/unit names
    # are conventionally kebab-case, so this rarely fires — but any of the
    # standard ERE metacharacters in a plugin or unit name (a literal `.`,
    # `*`, `+`, `(`, `[`, …) would be read as regex syntax, not a literal
    # character, and an unbalanced one (a stray `(`) makes `grep -E` itself
    # error. Neither failure mode is dangerous here (grep is not eval, and
    # a match failure or grep error both fall through to `return 1`, the
    # conservative "not touched" answer — see the call sites' own comments:
    # a false "not touched" just means --customized-only skips a unit it
    # should have caught, never a wrong write), but it is still a real
    # deviation from the careful literal-string matching used everywhere
    # else in this diff. `case` with the interpolated part quoted (glob
    # metacharacters in $full are literal; only the trailing `/*` this
    # function itself writes is a wildcard) does the same "$full" OR
    # "$full/<anything>" match with no interpreter reading $full as syntax
    # at all.
    local plugin="$1" sub="$2" full line
    full="plugins/$plugin/$sub"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [ "$line" = "$full" ] && return 0
        case "$line" in
            "$full"/*) return 0 ;;
        esac
    done <<< "$(printf '%s\n%s\n' "$STATE_CHANGED" "$STATE_ADDED")"
    return 1
}

find_other_plugin_owning() {
    # $1 = glob-relative path under plugins/*/, $2 = path to exclude
    find "$REPO_ROOT/plugins" -maxdepth 4 -path "$REPO_ROOT/plugins/*/$1" ! -path "$2" 2>/dev/null | head -1
}

owning_plugin_name() {
    # Reviewer round 2: parameter expansion, not a sed expression with the
    # checkout path interpolated (see _loom_rm_strip_prefix). $1 is always
    # a find result under $REPO_ROOT/plugins/ (find_other_plugin_owning).
    local rest="${1#"$REPO_ROOT"/plugins/}"
    printf '%s' "${rest%%/*}"
}


# frontmatter_differs <cmdfile> <skill-source-file>: 0 when the command's
# allowed-tools: or model: differs from what the converted skill will carry
# (the skill source's frontmatter, with a pinned model already read as opus);
# FM_DIFF_KEYS names the differing keys.
frontmatter_differs() {
    local cmdfile="$1" skillfile="$2"
    FM_DIFF_KEYS=""
    [ -f "$skillfile" ] || return 1
    local cat_v cmodel sat smodel
    cat_v="$(extract_fm_field "$cmdfile" "allowed-tools")"
    cmodel="$(extract_fm_field "$cmdfile" "model")"
    sat="$(extract_fm_field "$skillfile" "allowed-tools")"
    smodel="$(extract_fm_field "$skillfile" "model")"
    case "$smodel" in ""|opus|sonnet|haiku|inherit) ;; *) smodel="opus" ;; esac
    if [ -n "$cat_v" ] && [ "$cat_v" != "$sat" ]; then FM_DIFF_KEYS="allowed-tools"; fi
    if [ -n "$cmodel" ] && [ "$cmodel" != "$smodel" ]; then FM_DIFF_KEYS="${FM_DIFF_KEYS}${FM_DIFF_KEYS:+, }model"; fi
    [ -n "$FM_DIFF_KEYS" ] && return 0
    return 1
}

# ── write helpers: every write in --apply is checked; a failure prints an
#    ERROR line, marks the run stopped, and nothing records `converted =`.
WRITE_FAILED="false"
# Reviewer round 2: set by cmd_convert right before finalize_convert renders
# CONVERTED.md — "true" when a unit STOPped or WRITE_FAILED is already true —
# so render_converted_md's Follow-ups can take the same gate as the
# terminal `accounted:` line (see both).
CONVERT_RUN_STOPPED="false"
# Reviewer round 1 (write-through a symlink): every "target already exists"
# guard in the unit converters above is a `-e`/`-f` test, and `-e` is FALSE
# for a DANGLING symlink — so a target that is a symlink to a path that does
# not exist yet sails past every guard, and the `>` redirect / `cp` below
# then FOLLOWS the link and creates the file wherever it points, possibly
# outside .claude/ and outside the repository entirely (reproduced: a
# `.claude/skills/<p>/SKILL.md -> <elsewhere>/victim.md` link made convert
# --apply create <elsewhere>/victim.md). This tool's own contract is that it
# never writes outside .claude/skills/, .claude/agents/ and the decisions
# file, so a symlink at a target — dangling or not — is refused outright
# and counted as a failed write (the unit STOPs, no `converted =` is
# recorded, and the delete recommendation is withheld); it is never
# followed, never replaced, never removed.
_loom_rm_refuse_symlink_target() {   # $1 = repo-relative target
    if [ -L "$REPO_ROOT/$1" ]; then
        echo "ERROR $1: is a symlink (-> $(readlink "$REPO_ROOT/$1" 2>/dev/null)) — refusing to write through it; replace it with a real file or remove it yourself, then re-run"
        WRITE_FAILED="true"
        return 1
    fi
    return 0
}
# Round-4 finding (medium): every "-e \$target" branch below (a target that
# ALREADY exists) tests with plain `[ -e ]`, which FOLLOWS a symlink — so a
# pre-existing target that is a symlink to real content (not dangling) was
# read/classified straight through it via classify_existing_text/cmp and
# then marked "accounted for" in MAP_LIST, without this tool ever noticing
# the target itself is a symlink. No write happens on this branch (so this
# is not itself data loss the way the WRITE-path symlink was), but it
# contradicts this file's own MIGRATION_GUIDE-documented guarantee that a
# target symlink is refused, and can mark a plugin fully "accounted for"
# when its actual .claude/ output is just a symlink. Same treatment as a
# genuine write failure (WRITE_FAILED="true", never note_mapping'd) so
# unconverted_plugin_files/cmd_convert's delete gate see it as NOT carried
# over — Doubt -> KEEP and ASK, never silently agree.
_loom_rm_refuse_existing_symlink_target() {   # $1 = repo-relative target
    if [ -L "$REPO_ROOT/$1" ]; then
        echo "ERROR $1: already exists but is a symlink (-> $(readlink "$REPO_ROOT/$1" 2>/dev/null)) — refusing to read/classify through it; replace it with a real file or remove it yourself, then re-run"
        WRITE_FAILED="true"
        return 1
    fi
    # Round-4 REVIEWER (the same fix, one level up — the write path already
    # has it, see _loom_rm_refuse_symlink_parents below): the round-4 check
    # above looked at the FINAL component only. `[ -e ]` follows a symlinked
    # PARENT just as readily, so `.claude/skills/<skill> -> <anywhere>`
    # (reproduced with a directory OUTSIDE the repository holding a
    # previously converted, marker-bearing copy) had every file under it
    # classified SKIP through the link, mapped, "accounted: every file …
    # carried over", "Next steps: delete plugins/<p>", and scan said REMOVE
    # — while the only in-repo home of those bytes was a symlink to an
    # unversioned directory. MIGRATION_GUIDE.md states the guarantee for
    # "a symlink at a target … or at any parent directory of one"; the
    # classify path now honours it the same way the write path does. Walk
    # every existing component from the target's parent up to (not
    # including) REPO_ROOT; refuse on the first symlink. Doubt -> KEEP and
    # ASK: never count bytes as carried over on the far side of a link.
    local check
    check="$(dirname -- "$1")"
    while [ "$check" != "." ] && [ "$check" != "/" ] && [ -n "$check" ]; do
        if [ -e "$REPO_ROOT/$check" ] && [ -L "$REPO_ROOT/$check" ]; then
            echo "ERROR $1: already exists, but its parent directory $check is a symlink (-> $(readlink "$REPO_ROOT/$check" 2>/dev/null)) — refusing to read/classify through it (the bytes it would count as carried over live wherever that link points, not under .claude/); replace it with a real directory or remove it yourself, then re-run"
            WRITE_FAILED="true"
            return 1
        fi
        check="$(dirname -- "$check")"
    done
    return 0
}
# High finding (round-2 review): the check above only ever looked at the
# FINAL path component. `mkdir -p` does not refuse an existing symlinked
# intermediate directory — it follows it and creates any missing components
# INSIDE whatever it points to — and a `>` redirect / `cp -p` then follows
# the same chain, so a symlink at e.g. `.claude/skills/<plugin>` itself (not
# the file being written) silently sent every write for that plugin outside
# `.claude/skills/`, contradicting this script's own stated contract. Walk
# every path component from the target's parent up to (not including)
# REPO_ROOT and refuse if any component that already EXISTS is a symlink —
# a component that does not exist yet cannot be one, and mkdir -p will
# create it (and only it) as a real directory.
_loom_rm_refuse_symlink_parents() {   # $1 = repo-relative target
    local target="$1" check
    check="$(dirname -- "$target")"
    while [ "$check" != "." ] && [ "$check" != "/" ] && [ -n "$check" ]; do
        if [ -e "$REPO_ROOT/$check" ] && [ -L "$REPO_ROOT/$check" ]; then
            echo "ERROR $target: parent directory $check is a symlink (-> $(readlink "$REPO_ROOT/$check" 2>/dev/null)) — refusing to write through it; replace it with a real directory or remove it yourself, then re-run"
            WRITE_FAILED="true"
            return 1
        fi
        check="$(dirname -- "$check")"
    done
    return 0
}
write_text_target() {   # $1 = repo-relative target, $2 = content (newline appended), $3 = optional source path whose +x bit to preserve
    local target="$1" content="$2" srcfile="${3:-}"
    _loom_rm_refuse_symlink_target "$target" || return 1
    _loom_rm_refuse_symlink_parents "$target" || return 1
    if mkdir -p "$REPO_ROOT/$(dirname "$target")" 2>/dev/null \
       && printf '%s\n' "$content" > "$REPO_ROOT/$target" 2>/dev/null; then
        # A rewritten text file (path rewrites, marker insertion, model
        # pin rewrite) still goes through the `>` redirect above, which
        # never carries over the source's mode — preserve the executable
        # bit explicitly so a converted helper script stays runnable.
        # Round-6 finding (medium): this chmod's own exit status used to go
        # unchecked, so a failure (permission denied, a filesystem that
        # refuses the mode change, an immutable flag) was silently
        # swallowed and the function still `return 0`'d — the caller then
        # printed WROTE, recorded the mapping, and unconverted_plugin_files
        # counted the source as carried over, even though the target on
        # disk was not executable. Contradicts this file's own header claim
        # that "every WRITE ... is checked explicitly." Check it like any
        # other write: a failed chmod here is a failed write, full stop —
        # never counted as carried over.
        if [ -n "$srcfile" ] && [ -x "$srcfile" ]; then
            if ! chmod +x "$REPO_ROOT/$target" 2>/dev/null; then
                echo "ERROR $target: wrote content but chmod +x failed — the converted file would not be executable; treating this as a failed write so it is never counted as carried over"
                WRITE_FAILED="true"
                return 1
            fi
        fi
        return 0
    fi
    echo "ERROR $target: write failed"
    WRITE_FAILED="true"
    return 1
}
copy_target() {   # $1 = repo-relative target, $2 = absolute source (mode preserved)
    local target="$1" src="$2"
    _loom_rm_refuse_symlink_target "$target" || return 1
    _loom_rm_refuse_symlink_parents "$target" || return 1
    if mkdir -p "$REPO_ROOT/$(dirname "$target")" 2>/dev/null \
       && cp -p "$src" "$REPO_ROOT/$target" 2>/dev/null; then
        return 0
    fi
    echo "ERROR $target: write failed"
    WRITE_FAILED="true"
    return 1
}

# The conversion's mapping ledger — every target this conversion owns, as
# "<target> <- <source>", whether written now, skipped or kept. A pure
# function of the source tree, so CONVERTED.md is byte-stable across re-runs.
note_mapping() { MAP_LIST="${MAP_LIST}$1"$'\n'; }

# Reviewer round 2 (data-loss finding, residual): the "target already
# exists" branch of every unit converter maps its source into MAP_LIST and
# then CLASSIFIES the target — SKIP (byte-identical to what the source
# renders to now) or KEEP modified-after-conversion (it differs; nothing is
# overwritten). A KEEP is the one case where a mapped source's CURRENT
# bytes are provably NOT at the target: the plugin source was edited after
# conversion, or the target was, or both — the tool cannot tell which, and
# it writes nothing either way. MAP_LIST is the plan ("the mapping is the
# plan, not this run's writes"), so the mapping stays; this SEPARATE list
# records every KEEP so unconverted_plugin_files can report it under "not
# carried over by this run" and both delete gates (cmd_convert's terminal
# `accounted:` line and CONVERTED.md's Follow-ups) withhold the delete
# step. scan/plan already treat any KEEP line in a dry-run re-render as
# render-stale / KEEP-AS-IS ("reconcile by hand, then decide"); this makes
# convert's own output say the same instead of contradicting it.
# Reproduced: convert --apply, edit plugins/<p>/hooks/h.sh, convert --apply
# again -> "KEEP … modified-after-conversion", the edit nowhere under
# .claude/, and "Next steps: delete plugins/<p>". Doubt -> KEEP and ASK.
KEEP_DIFFERS_LIST=""
note_keep_differs() {   # $1 = repo-relative source under plugins/, $2 = repo-relative target
    KEEP_DIFFERS_LIST="${KEEP_DIFFERS_LIST}$1 (target $2 exists but differs from what this source renders to now — KEEP, not overwritten; reconcile by hand, then decide)"$'\n'
}

# Reviewer round 2 (data-loss, fail-open): strip a literal path prefix from
# every stdin line with parameter expansion, never `sed "s#^$PREFIX/##"`.
# The prefix is (or is built from) REPO_ROOT, a user-chosen checkout path:
# a `#` in it is sed's delimiter in that expression ("bad flag in
# substitute command"), a `[` opens an unbalanced bracket expression — and
# either way sed errored with EMPTY output, under `-uo pipefail` but no
# `-e`. plan_convert_units then saw no skill/command/agent units at all
# (none converted, none mapped — only hooks/support, which already used
# parameter expansion) and unconverted_plugin_files saw zero files under
# plugins/<p>: the positive `accounted:` line fired, `converted =` was
# recorded, and the next scan said REMOVE with `git rm -r plugins/<p>` over
# a skill never carried into .claude/. Reproduced for both characters on
# the pre-fix tree. A prefix that does not match leaves the line intact
# (same as sed's no-match), so every caller's downstream check stays
# fail-closed on an unexpected shape rather than fail-open on an empty one.
_loom_rm_strip_prefix() {   # $1 = literal prefix; stdin = lines
    local prefix="$1" line
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "${line#"$prefix"}"
    done
}

# Model rewrite for a SKILL.md / agent body (CD-11): sets RW_CONTENT and
# RW_MODEL_NOTE (" [model: pinned->opus]" or empty).
rewrite_model_if_pinned() {
    local content="$1"
    RW_CONTENT="$content"; RW_MODEL_NOTE=""
    if detect_model_rewrite_needed "$content"; then
        RW_CONTENT="$(apply_model_rewrite "$content")"
        RW_MODEL_NOTE=" [model: pinned->opus]"
    fi
}

# Classify an existing target against its freshly rendered content:
# prints "SKIP <t> up-to-date" or "KEEP <t> modified-after-conversion".
# Returns 0 on SKIP and 1 on KEEP (reviewer round 2) so a unit converter
# can record the KEEP via note_keep_differs; callers that classify the
# tool's OWN generated files (the support index, CONVERTED.md) ignore the
# return code on purpose — those are not plugin source bytes.
classify_existing_text() {   # $1 = target, $2 = rendered content
    if diff -q <(printf '%s\n' "$2") "$REPO_ROOT/$1" >/dev/null 2>&1; then
        echo "SKIP $1 up-to-date"
        return 0
    else
        echo "KEEP $1 modified-after-conversion"
        return 1
    fi
}

# Is $1 (a repo-relative target) listed in the existing CONVERTED.md of $2?
listed_in_ledger() {
    local target="$1" plugin="$2" ledger="$REPO_ROOT/.claude/skills/$2/CONVERTED.md"
    [ -f "$ledger" ] || return 1
    grep -qF -- "- $target " "$ledger" 2>/dev/null
}

convert_skill_unit() {
    local plugin="$1" skill="$2" mode="$3"
    local srcdir="$REPO_ROOT/plugins/$plugin/skills/$skill"
    local targetdir=".claude/skills/$skill"
    local other
    other="$(find_other_plugin_owning "skills/$skill" "$srcdir")"
    if [ -n "$other" ]; then
        local otherplug; otherplug="$(owning_plugin_name "$other")"
        echo "STOP skills/$skill: skills/$skill is provided by plugins/$otherplug; carry your diff into plugins/$otherplug/skills/$skill/"
        STOPPED_SKILLS="${STOPPED_SKILLS}${skill}"$'\n'
        return 1
    fi
    if [ -d "$REPO_ROOT/$targetdir" ] && [ -f "$REPO_ROOT/$targetdir/SKILL.md" ]; then
        if ! head -20 "$REPO_ROOT/$targetdir/SKILL.md" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/skills/$skill/"; then
            echo "STOP skills/$skill: .claude/skills/$skill/ already exists without our marker"
            STOPPED_SKILLS="${STOPPED_SKILLS}${skill}"$'\n'
            return 1
        fi
    fi
    local f relf target rendered original nrw modelnote
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        relf="${f#"$srcdir"/}"
        target="$targetdir/$relf"
        rendered=""; nrw=0; modelnote=""
        if grep -Iq . "$f" 2>/dev/null; then
            original="$(cat "$f")"
            # apply_path_rewrites always runs inside a `$(...)` capture, so a
            # WRITE_FAILED="true" it sets internally lives only in that
            # forked subshell and never reaches this function's own
            # (unforked) scope — its RETURN CODE is the only channel that
            # survives the fork, so it must be checked here explicitly.
            rendered="$(apply_path_rewrites "$original" "$plugin")" || WRITE_FAILED="true"
            nrw="$(count_rewrites "$original" "$rendered")"
            case "$relf" in
                *.md)
                    if [ "$relf" = "SKILL.md" ]; then
                        rewrite_model_if_pinned "$rendered"
                        rendered="$RW_CONTENT"; modelnote="$RW_MODEL_NOTE"
                    fi
                    rendered="$(insert_marker "$rendered" "$plugin" "skills/$skill/$relf")" ;;
            esac
        fi
        # Data-loss finding (round-2 review): note_mapping used to be called
        # HERE, unconditionally, before the write below was even attempted —
        # so a write that genuinely failed (write_text_target/copy_target
        # returning 1) still left this source marked "accounted for" in
        # MAP_LIST, and unconverted_plugin_files (which diffs the real
        # source tree against MAP_LIST) then saw nothing missing. Moved to
        # AFTER a successful write (or into the pre-existing-target branch,
        # which never writes and is always safe to map immediately) so a
        # failed write leaves its source OUT of MAP_LIST — exactly what
        # unconverted_plugin_files needs to report it as not carried over,
        # which is what both render_converted_md's Follow-ups (the on-disk
        # CONVERTED.md) and cmd_convert's own `accounted:` gate key off of.
        if [ -e "$REPO_ROOT/$target" ]; then
            _loom_rm_refuse_existing_symlink_target "$target" || continue
            note_mapping "$target <- plugins/$plugin/skills/$skill/$relf"
            # Reviewer round 2: a KEEP means this source's current bytes are
            # NOT at the target (see note_keep_differs) — recorded so the
            # delete gates withhold; the mapping above stays (it is the plan).
            if [ -n "$rendered" ]; then
                classify_existing_text "$target" "$rendered" \
                    || note_keep_differs "plugins/$plugin/skills/$skill/$relf" "$target"
            elif cmp -s "$f" "$REPO_ROOT/$target" 2>/dev/null; then
                echo "SKIP $target up-to-date"
            else
                echo "KEEP $target modified-after-conversion"
                note_keep_differs "plugins/$plugin/skills/$skill/$relf" "$target"
            fi
            continue
        fi
        if [ "$mode" = "dry-run" ]; then
            note_mapping "$target <- plugins/$plugin/skills/$skill/$relf"
            echo "MKDIR $(dirname "$target")"
            echo "WRITE $target <- plugins/$plugin/skills/$skill/$relf [rewrites: $nrw]$modelnote"
        else
            if [ -n "$rendered" ]; then
                write_text_target "$target" "$rendered" "$f" || return 1
            else
                copy_target "$target" "$f" || return 1
            fi
            note_mapping "$target <- plugins/$plugin/skills/$skill/$relf"
            echo "WROTE $target <- plugins/$plugin/skills/$skill/$relf [rewrites: $nrw]$modelnote"
        fi
    done <<< "$(find "$srcdir" -name .git -prune -o -type f -print 2>/dev/null | sort)"
    return 0
}

render_command_skill() {
    local plugin="$1" cmd="$2" src content rc=0
    src="$REPO_ROOT/plugins/$plugin/commands/$cmd.md"
    content="$(cat "$src")"
    rewrite_model_if_pinned "$content"; content="$RW_CONTENT"
    if printf '%s\n' "$content" | head -1 | grep -q '^---$'; then
        local has_desc
        has_desc="$(printf '%s\n' "$content" | awk 'BEGIN{infm=0} NR==1&&$0=="---"{infm=1;next} infm==1&&$0=="---"{exit} infm==1&&$0~/^description:/{print "y";exit}')"
        if [ -z "$has_desc" ]; then
            content="$(printf '%s\n' "$content" | awk -v d="description: Converted from /$cmd (plugins/$plugin)" '
                NR==1 && $0=="---" { print; print d; next }
                { print }')"
        fi
    fi
    # This function is itself always called via `$(...)` (it prints its
    # result, does not return it), so apply_path_rewrites' own return code
    # would otherwise be silently discarded by the `content="$(insert_marker
    # ...)"` reassignment below — capture it into $rc and RETURN it, so
    # the caller (which IS in the un-forked call chain back to cmd_convert)
    # can see the failure via this function's own exit status.
    content="$(apply_path_rewrites "$content" "$plugin")" || rc=1
    content="$(insert_marker "$content" "$plugin" "commands/$cmd.md")"
    printf '%s\n' "$content"
    return $rc
}

render_append_section() {
    local plugin="$1" cmd="$2" src fm body rc=0
    src="$REPO_ROOT/plugins/$plugin/commands/$cmd.md"
    fm=""; body=""
    if head -1 "$src" 2>/dev/null | grep -q '^---$'; then
        fm="$(awk 'BEGIN{infm=0} NR==1&&$0=="---"{infm=1;next} infm==1&&$0=="---"{exit} infm==1{print}' "$src")"
        body="$(awk 'BEGIN{infm=0;past=0} NR==1&&$0=="---"{infm=1;next} infm==1&&$0=="---"{infm=0;past=1;next} past==1{print}' "$src")"
    else
        body="$(cat "$src")"
    fi
    # Same relay as render_command_skill above — this function's own return
    # code is the only channel apply_path_rewrites' failure survives through.
    body="$(apply_path_rewrites "$body" "$plugin")" || rc=1
    echo "## Command procedure (converted from commands/$cmd.md)"
    echo ""
    echo "Original command frontmatter (not merged — this skill's frontmatter governs; carry allowed-tools/model over by hand if you need them):"
    echo ""
    if [ -n "$fm" ]; then
        echo '```yaml'
        printf '%s\n' "$fm"
        echo '```'
        echo ""
    fi
    printf '%s\n' "$body"
    return $rc
}

# Append a marker-delimited section to an existing converted file. Re-run
# classification: start marker absent -> APPEND; present and the text between
# the markers byte-equals the fresh rendering -> SKIP up-to-date; present and
# different -> KEEP modified-after-conversion. The caller has already proved
# the target is OURS (our provenance marker) — this never touches a file it
# does not own.
append_marked_section() {   # $1 target, $2 start, $3 end, $4 section, $5 mode, $6 op label, $7 ledger line
    local target="$1" start_marker="$2" end_marker="$3" section="$4" mode="$5" label="$6" ledger="$7"
    local existing_body=""
    # Round-4 REVIEWER: the eighth "target already exists" read. The seven
    # unit branches were given _loom_rm_refuse_existing_symlink_target in
    # round 4; this one (the appended-section path for a command with a
    # home skill, and the support-index append) still read an existing
    # target through `[ -f ]`/`cat`, which follow a link. It was covered
    # only transitively — the skill unit ERRORs on the same SKILL.md first —
    # and `--customized-only` can skip that skill unit while still reaching
    # here. Same rule, applied where the read happens. `-e` is false for a
    # DANGLING link, which then falls to write_text_target's own refusal.
    if [ -e "$REPO_ROOT/$target" ]; then
        _loom_rm_refuse_existing_symlink_target "$target" || return 1
    fi
    [ -f "$REPO_ROOT/$target" ] && existing_body="$(cat "$REPO_ROOT/$target")"
    # Data-loss finding (round-2 review): note_mapping moved from here
    # (unconditional, before the write below was even attempted) to each
    # branch below, after that branch's outcome is known — same fix as
    # convert_skill_unit above, same reason: an unconditional call here left
    # a failed APPEND (write_text_target returning 1) mapped as
    # "accounted for" in MAP_LIST.
    if printf '%s\n' "$existing_body" | grep -qF -- "$start_marker"; then
        note_mapping "$ledger"
        local between
        between="$(printf '%s\n' "$existing_body" | awk -v s="$start_marker" -v e="$end_marker" '$0==s{inb=1;next} $0==e{inb=0;next} inb{print}')"
        if [ "$between" = "$section" ]; then
            echo "SKIP $target up-to-date"
        else
            echo "KEEP $target modified-after-conversion"
            # Reviewer round 2: recorded (see note_keep_differs). The source
            # is the tail of the ledger line ("… <- plugins/<p>/commands/
            # <c>.md"), the same field unconverted_plugin_files reads.
            note_keep_differs "${ledger##* <- }" "$target"
        fi
        return 0
    fi
    if [ "$mode" = "dry-run" ]; then
        note_mapping "$ledger"
        echo "APPEND $target $label"
    else
        local merged
        merged="$(
            [ -n "$existing_body" ] && printf '%s\n' "$existing_body"
            printf '%s\n' "$start_marker"
            printf '%s\n' "$section"
            printf '%s' "$end_marker"
        )"
        write_text_target "$target" "$merged" || return 1
        note_mapping "$ledger"
        echo "APPENDED $target $label"
    fi
    return 0
}

# commands/<c>.md whose plugin also has skills/<c>/ -> appended section in
# .claude/skills/<c>/SKILL.md (§15.2-G).
append_command_into_skill() {
    local plugin="$1" cmd="$2" skill="$3" mode="$4" customized_only="$5"
    local target=".claude/skills/$skill/SKILL.md"
    local start_marker="<!-- converted-from: plugins/${plugin}/commands/${cmd}.md | logicloom-plugin-deprecations v1 | appended section -->"
    local end_marker="<!-- end converted-from: plugins/${plugin}/commands/${cmd}.md -->"
    # The home skill must be ours: either already converted (our marker), or
    # about to be written by this very run's skill unit.
    if printf '%s\n' "$STOPPED_SKILLS" | grep -qx "$skill"; then
        echo "STOP commands/$cmd.md: its home skill skills/$skill was stopped above; nothing appended"
        return 1
    fi
    if [ -f "$REPO_ROOT/$target" ]; then
        if ! head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/skills/$skill/"; then
            echo "STOP commands/$cmd.md: .claude/skills/$skill/SKILL.md exists without our marker; nothing appended"
            return 1
        fi
    elif [ "$customized_only" = "true" ]; then
        echo "STOP commands/$cmd.md: .claude/skills/$skill/SKILL.md is not converted yet (skills/$skill was untouched) — run convert without --customized-only"
        return 1
    fi
    local section; section="$(render_append_section "$plugin" "$cmd")" || WRITE_FAILED="true"
    local note=""
    if frontmatter_differs "$REPO_ROOT/plugins/$plugin/commands/$cmd.md" "$REPO_ROOT/plugins/$plugin/skills/$skill/SKILL.md"; then
        note="NOTE $target: command frontmatter differs ($FM_DIFF_KEYS) — review"
    fi
    append_marked_section "$target" "$start_marker" "$end_marker" "$section" "$mode" \
        "(section from commands/$cmd.md) [frontmatter: kept in section, not merged]" \
        "$target (appended section) <- plugins/$plugin/commands/$cmd.md" || return 1
    [ -n "$note" ] && echo "$note"
    return 0
}

convert_command_unit() {
    local plugin="$1" cmd="$2" mode="$3" customized_only="$4"
    local src="$REPO_ROOT/plugins/$plugin/commands/$cmd.md"
    # Round-3 review finding (high, defense-in-depth): plan_convert_units()
    # now excludes a symlink named *.md from COMMAND_UNITS via `-type f`, so
    # this should never be reached for one in practice — but `-f` alone
    # (below) follows a symlink and is true for a symlink to a regular
    # file, so if this were ever called directly with a symlinked $src the
    # unconditional `cat "$src"` further down would still read through it.
    # Refuse it here too, the same "never converted" contract as everywhere
    # else a source path is read.
    if [ -L "$src" ]; then return 0; fi
    [ -f "$src" ] || return 0
    local other
    other="$(find_other_plugin_owning "commands/$cmd.md" "$src")"
    if [ -n "$other" ]; then
        local otherplug; otherplug="$(owning_plugin_name "$other")"
        echo "STOP commands/$cmd.md: /$cmd is provided by $otherplug; carry your diff into plugins/$otherplug/commands/$cmd.md"
        return 1
    fi
    # A .claude/commands/<c>.md that is not our own bridge wrapper is someone
    # else's /<c> (§4.3).
    if [ -f "$REPO_ROOT/.claude/commands/$cmd.md" ] \
       && ! head -10 "$REPO_ROOT/.claude/commands/$cmd.md" 2>/dev/null | grep -q "source: $plugin"; then
        echo "STOP commands/$cmd.md: /$cmd is provided by .claude/commands/$cmd.md (not this plugin's bridge wrapper); carry your diff into it"
        return 1
    fi
    local home_skill=""
    if printf '%s\n' "$SKILL_UNITS" | grep -qx "$cmd"; then home_skill="$cmd"; fi
    if [ -n "$home_skill" ]; then
        append_command_into_skill "$plugin" "$cmd" "$home_skill" "$mode" "$customized_only"
        return $?
    fi
    local target=".claude/skills/$cmd/SKILL.md"
    local rendered; rendered="$(render_command_skill "$plugin" "$cmd")" || WRITE_FAILED="true"
    if [ -e "$REPO_ROOT/$target" ]; then
        _loom_rm_refuse_existing_symlink_target "$target" || return 1
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/commands/$cmd.md "; then
            note_mapping "$target <- plugins/$plugin/commands/$cmd.md"
            # Reviewer round 2: a KEEP is recorded (see note_keep_differs).
            classify_existing_text "$target" "$rendered" \
                || note_keep_differs "plugins/$plugin/commands/$cmd.md" "$target"
            return 0
        else
            echo "STOP commands/$cmd.md: .claude/skills/$cmd/ already exists without our marker"
            return 1
        fi
    fi
    local other_skill
    other_skill="$(find_other_plugin_owning "skills/$cmd" "$REPO_ROOT/plugins/$plugin/skills/$cmd")"
    if [ -n "$other_skill" ]; then
        local otherplug2; otherplug2="$(owning_plugin_name "$other_skill")"
        echo "STOP commands/$cmd.md: /$cmd is provided by $otherplug2; carry your diff into plugins/$otherplug2/commands/$cmd.md"
        return 1
    fi
    local nrw original original_rewritten
    original="$(cat "$src")"
    # A doubly-nested `$(count_rewrites ... "$(apply_path_rewrites ...)")`
    # swallows apply_path_rewrites' own exit code entirely (only
    # count_rewrites' exit status would survive to `$?`) — split so its
    # failure is checked directly. (Redundant with the check on $rendered's
    # own apply_path_rewrites call inside render_command_skill above, since
    # both calls render the same plugin/content — but kept explicit rather
    # than relying on that coincidence.)
    original_rewritten="$(apply_path_rewrites "$original" "$plugin")" || WRITE_FAILED="true"
    nrw="$(count_rewrites "$original" "$original_rewritten")"
    rewrite_model_if_pinned "$original"
    # Data-loss finding (round-2 review): note_mapping moved from here
    # (unconditional, before the write below) to each branch, after that
    # branch's outcome is known — same fix, same reason as convert_skill_unit.
    if [ "$mode" = "dry-run" ]; then
        note_mapping "$target <- plugins/$plugin/commands/$cmd.md"
        echo "MKDIR .claude/skills/$cmd"
        echo "WRITE $target <- plugins/$plugin/commands/$cmd.md [rewrites: $nrw]$RW_MODEL_NOTE"
    else
        write_text_target "$target" "$rendered" "$src" || return 1
        note_mapping "$target <- plugins/$plugin/commands/$cmd.md"
        echo "WROTE $target <- plugins/$plugin/commands/$cmd.md [rewrites: $nrw]$RW_MODEL_NOTE"
    fi
    return 0
}

convert_agent_unit() {
    local plugin="$1" agent="$2" mode="$3"
    local src="$REPO_ROOT/plugins/$plugin/agents/$agent.md"
    # Round-3 review finding (high, defense-in-depth): same reasoning as the
    # symlink guard at the top of convert_command_unit — plan_convert_units()
    # already excludes a symlinked *.md from AGENT_UNITS, this is belt and
    # suspenders against a direct call.
    if [ -L "$src" ]; then return 0; fi
    [ -f "$src" ] || return 0
    local target=".claude/agents/$agent.md"
    local other
    other="$(find_other_plugin_owning "agents/$agent.md" "$src")"
    if [ -n "$other" ]; then
        local otherplug; otherplug="$(owning_plugin_name "$other")"
        echo "STOP agents/$agent.md: agents/$agent.md is provided by plugins/$otherplug; carry your diff into plugins/$otherplug/agents/$agent.md"
        return 1
    fi
    local content original modelnote="" nrw
    original="$(cat "$src")"
    rewrite_model_if_pinned "$original"
    content="$RW_CONTENT"; modelnote="$RW_MODEL_NOTE"
    local rewritten; rewritten="$(apply_path_rewrites "$content" "$plugin")" || WRITE_FAILED="true"
    nrw="$(count_rewrites "$content" "$rewritten")"
    content="$(insert_marker "$rewritten" "$plugin" "agents/$agent.md")"
    if [ -e "$REPO_ROOT/$target" ]; then
        _loom_rm_refuse_existing_symlink_target "$target" || return 1
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/agents/$agent.md "; then
            note_mapping "$target <- plugins/$plugin/agents/$agent.md"
            # Reviewer round 2: a KEEP is recorded (see note_keep_differs).
            classify_existing_text "$target" "$content" \
                || note_keep_differs "plugins/$plugin/agents/$agent.md" "$target"
            return 0
        else
            echo "STOP agents/$agent.md: .claude/agents/$agent.md already exists without our marker"
            return 1
        fi
    fi
    # Data-loss finding (round-2 review): note_mapping moved from here
    # (unconditional, before the write below) to each branch, after that
    # branch's outcome is known — same fix, same reason as convert_skill_unit.
    if [ "$mode" = "dry-run" ]; then
        note_mapping "$target <- plugins/$plugin/agents/$agent.md"
        echo "WRITE $target <- plugins/$plugin/agents/$agent.md [rewrites: $nrw]$modelnote"
    else
        write_text_target "$target" "$content" "$src" || return 1
        note_mapping "$target <- plugins/$plugin/agents/$agent.md"
        echo "WROTE $target <- plugins/$plugin/agents/$agent.md [rewrites: $nrw]$modelnote"
    fi
    return 0
}

# EVERY plugin-root entry except skills/, commands/, agents/ and
# .claude-plugin/ (each converted separately by their own unit converters,
# above, and the manifest handled after this loop) -> .claude/skills/<p>/… .
# A target that already exists is classified (§4.3): byte-identical -> SKIP;
# listed in the existing CONVERTED.md ledger -> KEEP; anything else -> STOP
# (never overwritten).
#
# Finding 1 (data-loss, round 5 review): this used to walk a FIXED list
# (hooks, scripts, lib, config, templates, tests, README.md) — any other
# plugin-root file or directory (LICENSE, package.json, CHANGELOG.md, a
# custom asset dir) was silently never converted and never even mentioned,
# so nothing marked it as carried over OR as left behind. Two real plugins
# in THIS repo already prove the gap: plugins/loom-governance/domain-briefs/
# (real shipped content, not on the old list at all) and
# plugins/loom-memory/{working,recall,archival}/ + .retention-last-run
# (runtime state dirs, also not on the old list). Enumerating every
# plugin-root entry generically, excluding only the four subtrees converted
# elsewhere, means a plugin can never grow a fifth kind of root entry that
# silently falls through conversion again — see also finding 2 immediately
# below, which depends on this loop actually seeing everything.
convert_hooks_and_support() {
    local plugin="$1" mode="$2" srcdir="$REPO_ROOT/plugins/$1" rel rc=0
    local _chs_entries _chs_entry
    _chs_entries="$(find "$srcdir" -mindepth 1 -maxdepth 1 2>/dev/null | sort)"
    while IFS= read -r _chs_entry; do
        [ -z "$_chs_entry" ] && continue
        rel="$(basename "$_chs_entry")"
        case "$rel" in
            skills|commands|agents|.claude-plugin) continue ;;
            # Round-5 REVIEWER (medium): a `.git` at plugin root — a
            # directory (the customer ran `git init` inside the plugin) or
            # a gitdir-pointer file (`git worktree`) — is NEVER converted.
            # The generic walk below used to carry `.git/**` into
            # .claude/skills/<p>/.git/ (a WROTE line per hook sample, HEAD,
            # config, the whole object store), which makes
            # .claude/skills/<p> an EMBEDDED repository the outer tree can
            # only ever hold as a 160000 gitlink (reproduced: `git add
            # .claude` warned "adding embedded git repository") — the
            # converted skill could never travel with the outer repo — and
            # for the pointer-file variant it then printed `accounted:
            # every file … carried over` and the delete step outright.
            # Skipped here (never read, never written); reported by
            # unconverted_plugin_files() as a nested repository, so both
            # delete gates withhold. A `.git` deeper down (inside a support
            # or skill directory) is pruned by the same name in every file
            # walk this converter runs, for the same reason.
            .git) continue ;;
        esac
        local srcpath="$srcdir/$rel"
        # Round-3 review finding (high, data-loss): a GENERIC plugin-root
        # entry that is a symlink to a FILE (a customer's LICENSE pointed at
        # a shared file elsewhere, say) fell through every check above —
        # `-e` follows the link and is true, and `-d` on a link-to-file is
        # false, landing in the `else` branch below where `files="$srcpath"`
        # is the link path itself, read via `cat`/copy_target exactly like a
        # real file and counted as carried over. unconverted_plugin_files()
        # never got a chance to flag it because it WAS mapped. The
        # documented contract (this file's own "reviewer round 1 (symlinks)"
        # comment on unconverted_plugin_files, and MIGRATION_GUIDE.md) is
        # that a symlink anywhere under plugins/<p> is never converted —
        # `continue` here so this entry is never read, never written, and
        # falls through to unconverted_plugin_files()'s own `! -type d` walk
        # (which DOES see symlinks) to be reported as "Not carried over". A
        # symlink to a DIRECTORY at plugin root was already safe by
        # accident (`find <link> -type f` without -L does not descend past
        # a link given as the start point on either GNU or BSD find — proven
        # by the existing "four symlinks" test) but this check makes both
        # cases explicit and no longer dependent on that non-descent quirk.
        if [ -L "$srcpath" ]; then continue; fi
        [ -e "$srcpath" ] || continue
        local files
        # Round-6 REVIEWER (medium, hang): the `else` branch used to take
        # EVERY non-directory, non-symlink plugin-root entry as a regular
        # file and run `grep -Iq .` on it to decide text-vs-binary — on a
        # named pipe that open() blocks until a writer appears, i.e.
        # forever (reproduced: convert never returned, and killing it left
        # the grep orphaned, still blocked on the pipe). A socket or device
        # node is the same shape. Only a regular file (`-f`; `-L` was
        # already refused above, so this never follows a link) is
        # converted from the plugin root; anything else is never read and
        # never written, and falls through to unconverted_plugin_files'
        # `! -type d` walk to be reported under "Not carried over" — the
        # same contract a symlink already has. The directory walk below is
        # already `-type f` and never had this gap.
        if [ -d "$srcpath" ]; then
            files="$(find "$srcpath" -name .git -prune -o -type f -print 2>/dev/null | sort)"
        elif [ -f "$srcpath" ]; then
            files="$srcpath"
        else
            continue
        fi
        local f relf target is_text rendered original nrw
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            relf="${f#"$srcdir"/}"
            target=".claude/skills/$plugin/$relf"
            is_text="false"; rendered=""; nrw=0
            if grep -Iq . "$f" 2>/dev/null; then
                is_text="true"
                original="$(cat "$f")"
                rendered="$(apply_path_rewrites "$original" "$plugin")" || WRITE_FAILED="true"
                nrw="$(count_rewrites "$original" "$rendered")"
            fi
            if [ "$rel" = "hooks" ] && [ "$relf" != "hooks/hooks.json" ]; then
                HOOKS_SNIPPET="${HOOKS_SNIPPET}{\"type\":\"command\",\"command\":\"bash $target\"}"$'\n'
            fi
            if [ -e "$REPO_ROOT/$target" ]; then
                if ! _loom_rm_refuse_existing_symlink_target "$target"; then
                    rc=1
                    continue
                fi
                local same="false"
                if [ "$is_text" = "true" ]; then
                    diff -q <(printf '%s\n' "$rendered") "$REPO_ROOT/$target" >/dev/null 2>&1 && same="true"
                else
                    cmp -s "$f" "$REPO_ROOT/$target" 2>/dev/null && same="true"
                fi
                if [ "$same" = "true" ]; then
                    note_mapping "$target <- plugins/$plugin/$relf"
                    echo "SKIP $target up-to-date"
                elif listed_in_ledger "$target" "$plugin"; then
                    note_mapping "$target <- plugins/$plugin/$relf"
                    echo "KEEP $target modified-after-conversion"
                    # Reviewer round 2: recorded (see note_keep_differs).
                    note_keep_differs "plugins/$plugin/$relf" "$target"
                else
                    echo "STOP $relf: $target already exists and is not ours (not in .claude/skills/$plugin/CONVERTED.md)"
                    rc=1
                fi
                continue
            fi
            # Data-loss finding (round-2 review): note_mapping used to be
            # called HERE, unconditionally, before the write below was even
            # attempted — a write that genuinely fails (rc=1; continue)
            # still left this source marked "accounted for" in MAP_LIST, so
            # render_converted_md's Follow-ups (written to the on-disk
            # CONVERTED.md) recommended `delete plugins/$plugin` over
            # content that was never actually written. Moved to AFTER a
            # successful write; on failure the source now stays OUT of
            # MAP_LIST, which is exactly what unconverted_plugin_files needs
            # to report it as not carried over.
            if [ "$mode" = "dry-run" ]; then
                note_mapping "$target <- plugins/$plugin/$relf"
                echo "MKDIR $(dirname "$target")"
                echo "WRITE $target <- plugins/$plugin/$relf [rewrites: $nrw]"
            else
                if [ "$is_text" = "true" ]; then
                    write_text_target "$target" "$rendered" "$f" || { rc=1; continue; }
                else
                    copy_target "$target" "$f" || { rc=1; continue; }
                fi
                note_mapping "$target <- plugins/$plugin/$relf"
                echo "WROTE $target <- plugins/$plugin/$relf [rewrites: $nrw]"
            fi
        done <<< "$files"
    done <<< "$_chs_entries"
    # Round-3 REVIEWER finding (high, data-loss): the same hole finding 1
    # closed for a generic plugin-root entry was still open for the
    # manifest — `-f` follows a symlink, so `.claude-plugin/plugin.json ->
    # <outside file>` was copied (cp -p follows it too) into
    # plugin.json.orig, mapped as carried over, and since the link path WAS
    # mapped, unconverted_plugin_files never flagged it: `accounted:` fired,
    # "delete plugins/<p>" printed, `converted =` recorded. Reproduced live
    # with an outside manifest. `.claude-plugin` itself being a symlink to a
    # directory holding a plugin.json read through the same `-f`. Neither
    # is converted: skipped here so the link (the dir link via `! -type d`,
    # or the file link) is reported by unconverted_plugin_files under "Not
    # carried over" and both delete gates withhold. Loop above already
    # skips the `.claude-plugin` entry by name, so this is the only read.
    if [ -L "$srcdir/.claude-plugin" ] || [ -L "$srcdir/.claude-plugin/plugin.json" ]; then
        :
    elif [ -f "$srcdir/.claude-plugin/plugin.json" ]; then
        local target=".claude/skills/$plugin/plugin.json.orig"
        if [ -e "$REPO_ROOT/$target" ] && ! _loom_rm_refuse_existing_symlink_target "$target"; then
            rc=1
        elif [ -e "$REPO_ROOT/$target" ]; then
            note_mapping "$target <- plugins/$plugin/.claude-plugin/plugin.json"
            if cmp -s "$srcdir/.claude-plugin/plugin.json" "$REPO_ROOT/$target" 2>/dev/null; then
                echo "SKIP $target up-to-date"
            else
                echo "KEEP $target modified-after-conversion"
                # Reviewer round 2: recorded (see note_keep_differs).
                note_keep_differs "plugins/$plugin/.claude-plugin/plugin.json" "$target"
            fi
        elif [ "$mode" = "dry-run" ]; then
            note_mapping "$target <- plugins/$plugin/.claude-plugin/plugin.json"
            echo "WRITE $target <- plugins/$plugin/.claude-plugin/plugin.json"
        else
            if copy_target "$target" "$srcdir/.claude-plugin/plugin.json"; then
                note_mapping "$target <- plugins/$plugin/.claude-plugin/plugin.json"
                echo "WROTE $target <- plugins/$plugin/.claude-plugin/plugin.json"
            else
                rc=1
            fi
        fi
    fi
    return $rc
}

# Support-asset targets under .claude/skills/<p>/ (everything but SKILL.md
# and CONVERTED.md), newline list, from the mapping ledger.
support_asset_targets() {
    local plugin="$1"
    printf '%s' "$MAP_LIST" | awk -v p=".claude/skills/$plugin/" '
        index($1, p) == 1 && $1 != p "SKILL.md" && $1 != p "CONVERTED.md" { print $1 }'
}

render_support_index_body() {
    local plugin="$1" t
    echo "## Support assets (converted from plugins/$plugin)"
    echo ""
    echo "support assets converted from plugins/$plugin; referenced by the skills and commands converted alongside them. tests/ under this directory are not run by the harness test runner."
    echo ""
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        echo "- $t"
    done <<< "$(support_asset_targets "$plugin")"
}

# §4.1 last row: when support assets exist, .claude/skills/<p>/ needs a
# SKILL.md — an index when no skill is named <p>; appended to that skill's
# SKILL.md (marker-delimited, idempotent) when one is.
convert_support_index() {
    local plugin="$1" mode="$2"
    [ -n "$(support_asset_targets "$plugin")" ] || return 0
    local target=".claude/skills/$plugin/SKILL.md"
    local body; body="$(render_support_index_body "$plugin")"
    if printf '%s\n' "$SKILL_UNITS" | grep -qx "$plugin"; then
        if printf '%s\n' "$STOPPED_SKILLS" | grep -qx "$plugin"; then
            echo "STOP support index: skills/$plugin was stopped above; index not appended"
            return 1
        fi
        if [ -f "$REPO_ROOT/$target" ] \
           && ! head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/skills/$plugin/"; then
            echo "STOP support index: $target exists without our marker; index not appended"
            return 1
        fi
        [ -f "$REPO_ROOT/$target" ] || [ "$mode" = "dry-run" ] || return 0
        append_marked_section "$target" \
            "<!-- converted-from: plugins/${plugin}/ | logicloom-plugin-deprecations v1 | support index -->" \
            "<!-- end converted-from: plugins/${plugin}/ -->" \
            "$body" "$mode" "(support index)" "$target (support index section) <- plugins/$plugin/"
        return $?
    fi
    local content
    content="$(printf -- '---\nname: %s\ndescription: Support assets converted from plugins/%s (index)\n---\n%s' "$plugin" "$plugin" "$body")"
    content="$(insert_marker "$content" "$plugin" "")"
    # Data-loss finding (round-2 review): note_mapping moved from here
    # (unconditional, before the write below) to each branch, after that
    # branch's outcome is known — same fix, same reason as convert_skill_unit.
    if [ -e "$REPO_ROOT/$target" ]; then
        _loom_rm_refuse_existing_symlink_target "$target" || return 1
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/ "; then
            note_mapping "$target <- plugins/$plugin/ (support index)"
            classify_existing_text "$target" "$content"
            return 0
        fi
        echo "STOP support index: $target already exists without our marker"
        return 1
    fi
    if [ "$mode" = "dry-run" ]; then
        note_mapping "$target <- plugins/$plugin/ (support index)"
        echo "WRITE $target (support index for plugins/$plugin)"
    else
        write_text_target "$target" "$content" || return 1
        note_mapping "$target <- plugins/$plugin/ (support index)"
        echo "WROTE $target (support index for plugins/$plugin)"
    fi
    return 0
}

# Currently wired .claude/settings.json command lines under plugins/<p>/ —
# they dangle once the plugin is deleted.
wired_lines_for_plugin() {
    local plugin="$1" settings="$REPO_ROOT/.claude/settings.json"
    [ -f "$settings" ] || return 0
    grep -nF "plugins/$plugin/" "$settings" 2>/dev/null | grep -F '"command"' | sed 's/^\([0-9]*\):[[:space:]]*/.claude\/settings.json:\1 /'
    return 0
}

# Finding 2 (data-loss, round 5 review): every physical file that sits
# under plugins/<plugin> right now — tracked, untracked AND git-ignored;
# `find` walks the real filesystem and does not consult .gitignore at all,
# so all three are covered by construction — that this run's MAP_LIST does
# NOT carry a "target <- plugins/<plugin>/<relpath>" mapping for. Every unit
# converter above calls note_mapping with the file's real source path before
# it does anything else with that file, so on a full (non
# --customized-only) run where every unit succeeded, MAP_LIST already
# covers the entire tree (finding 1 closed the one gap that used to leave
# real files off this list entirely) and this returns empty. A non-empty
# result means: a unit STOPped before mapping its files, a write failed, a
# custom asset finding 1 would previously have skipped is still unmapped, or
# --customized-only left the rest of the plugin untouched on purpose — every
# one of those is a real, sufficient reason a human must not blindly `rm
# -r plugins/<plugin>`. This is the ONLY gate cmd_convert and
# render_converted_md use before recommending that delete — see both call
# sites below.
#
# Reviewer round 1 (symlinks): `find -type f` is REGULAR files only — a
# symlink under plugins/<plugin> (a root-level link to a directory of shared
# assets, a link to a file inside config/, a link inside a skill dir, a
# dangling link) is neither converted by any unit above (each walks
# `-type f`, and `find <link-to-dir>` without -L does not descend) NOR
# listed here, so a plugin holding nothing but real files plus a customer's
# own symlinks read as fully accounted for and got the delete recommendation
# — `git rm -r plugins/<plugin>` then removes the link entries, paths this
# tool never created and never carried over. Enumerate everything that is
# NOT a directory (`! -type d`: regular files, symlinks, anything else) so a
# symlink is reported under "not carried over" and the delete step is
# withheld; symlinks are deliberately never converted (copying a link's
# target would silently turn the customer's wiring into a detached copy).
unconverted_plugin_files() {
    local plugin="$1"
    local srcdir="$REPO_ROOT/plugins/$plugin"
    [ -d "$srcdir" ] || return 0
    local all_files empty_dirs find_rc=0
    # Reviewer round 2 (fail-open, twice over): (1) the prefix is stripped
    # by parameter expansion, never `sed "s#^$REPO_ROOT/##"` — a `#` or `[`
    # in the checkout path made that sed error with EMPTY output, which read
    # here as "zero files under plugins/<p>", i.e. everything accounted for
    # (see _loom_rm_strip_prefix); (2) `find` itself can fail PARTWAY — a
    # directory under plugins/<p> it cannot read (permission denied) is
    # skipped with a non-zero exit, and under `-uo pipefail` that status
    # reached the assignment and was simply never checked, so a partial
    # listing read as complete and the delete step fired over bytes this
    # tool never saw. An enumeration that did not complete proves nothing
    # about the tree: report the directory itself as unverifiable and stop
    # — nothing under it can be called accounted for.
    # Round-5 REVIEWER (medium): a `.git` anywhere under plugins/<p> — a
    # nested repository's directory, or a gitdir-pointer file — is pruned
    # from BOTH walks below (never converted, see convert_hooks_and_support)
    # and reported ONCE, by name, as the third listing further down, instead
    # of as hundreds of object-store files that were "not carried over".
    all_files="$(find "$srcdir" -name .git -prune -o ! -type d -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || find_rc=$?
    if [ "$find_rc" -ne 0 ]; then
        echo "plugins/$plugin/ (could not fully enumerate this directory — find exited $find_rc, e.g. a subdirectory it cannot read; nothing under it can be verified as carried over)"
        return 0
    fi
    local nested_git
    nested_git="$(find "$srcdir" -mindepth 1 -name .git -prune -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || find_rc=$?
    if [ "$find_rc" -ne 0 ]; then
        echo "plugins/$plugin/ (could not fully enumerate this directory — find exited $find_rc, e.g. a subdirectory it cannot read; nothing under it can be verified as carried over)"
        return 0
    fi
    # Low finding (round-2 review): `find ! -type d` enumerates regular
    # files and symlinks only — a directory holding NOTHING (a customer's
    # empty scratch dir, or a plugin subtree left empty by a prior run) is
    # neither converted by any unit above nor reported here: it produces no
    # entry from that walk at all. No bytes are lost by that gap on its own
    # — an empty directory holds zero bytes — but `git rm -r plugins/<p>` on
    # this tool's own delete recommendation then removes the directory entry
    # with no record this tool ever saw it, a real (if low-stakes) gap in a
    # tool whose whole job is exhaustive accounting. `-empty` only ever
    # matches a directory with NO entries of its own, so a multi-level empty
    # chain (a/b/ where b is empty) is reported at its innermost level (b) —
    # enough to withhold the delete recommendation and name a real path.
    empty_dirs="$(find "$srcdir" -mindepth 1 -name .git -prune -o -type d -empty -print 2>/dev/null | _loom_rm_strip_prefix "$REPO_ROOT/" | sort)" || find_rc=$?
    if [ "$find_rc" -ne 0 ]; then
        echo "plugins/$plugin/ (could not fully enumerate this directory — find exited $find_rc, e.g. a subdirectory it cannot read; nothing under it can be verified as carried over)"
        return 0
    fi
    if [ -n "$all_files" ]; then
        local mapped_sources
        mapped_sources="$(printf '%s\n' "$MAP_LIST" | sed -n 's/.* <- //p' | sort -u)"
        comm -23 <(printf '%s\n' "$all_files") <(printf '%s\n' "$mapped_sources")
    fi
    [ -n "$empty_dirs" ] && printf '%s\n' "$empty_dirs" | sed 's#$#/ (empty directory — holds no bytes, but nothing converts or lists it either)#'
    # Round-5 REVIEWER (medium): see the .git prune above. A nested
    # repository is never converted (copying its metadata into .claude/
    # would create an embedded repository there) and is never this tool's
    # to delete: the delete step is withheld until the customer moves or
    # removes it themselves.
    [ -n "$nested_git" ] && printf '%s\n' "$nested_git" | sed 's#$# (a nested git repository — never converted, never carried over: move or remove it yourself before deleting this plugin)#'
    # Reviewer round 2 (data-loss finding, residual): a mapped source whose
    # existing target was classified KEEP modified-after-conversion is in
    # MAP_LIST (the plan) but its CURRENT bytes are provably not at the
    # target — see note_keep_differs. Listed here, after the unmapped files,
    # so both delete gates that read this function withhold on it.
    [ -n "${KEEP_DIFFERS_LIST:-}" ] && printf '%s' "$KEEP_DIFFERS_LIST"
    return 0
}

# The record. A pure function of the source tree + the registry row: no
# timestamps, and the mapping is the plan, not this run's writes — with one
# deliberate exception (reviewer round 2): the Follow-ups section also
# reads this run's outcome (a KEEP-but-differing target, a STOP, a failed
# write), because a record that recommends deleting the source must never
# be written by a run that could not carry the source over.
render_converted_md() {
    local plugin="$1" row
    row="$(loom_deprecation_row "$plugin" "$REGISTRY_FILE" 2>/dev/null | tr '\t' '|')" || row=""
    if [ -z "$row" ] && [ -n "$PROJECT_REGISTRY_FILE" ]; then
        row="$(loom_deprecation_row "$plugin" "$PROJECT_REGISTRY_FILE" 2>/dev/null | tr '\t' '|')" || row=""
    fi
    echo "# Converted from plugins/$plugin"
    echo ""
    echo "Registry row: $row"
    echo ""
    # Round-3 review finding (low): finalize_convert() writes this file
    # exactly once and never rewrites an EXISTING one (deliberate — the
    # record stays a pure function of the run that made the conversion,
    # and the "Converted paths" ledger that listed_in_ledger /
    # converted_paths_for read stays stable across later, possibly partial
    # or --customized-only, re-runs). Round-4 REVIEWER, for accuracy: the
    # conversion's DATING does not depend on this — _loom_rm_converted_decision_commit
    # reads the commit that ADDED the file (`--diff-filter=A`, earliest),
    # which a later rewrite could not move; never-rewrite is a ledger-
    # stability choice, not what the dating relies on. Its cost is the
    # staleness the paragraph below warns about; its coverage is the RV2K
    # re-run test. The ACTUAL remove/keep decision is never read from this
    # file's own text — scan/plan re-render fresh and fall back to
    # render-stale/KEEP-AS-IS when the plugin has changed since (see
    # _loom_rm_converted_plugin_status) — but a human who opens this file
    # directly, outside that live path, could still be looking at a
    # "delete" line written before a later edit to plugins/$plugin that
    # this file was never updated to reflect. Say so up front rather than
    # let a stale Follow-up read as current.
    echo "**This record is written once, at conversion time, and never rewritten by a later run.** If plugins/$plugin has changed since, the Follow-ups below (especially any 'delete' line) may be STALE — for the current recommendation, re-run \`release-migrations.sh scan --json\` (or \`plan\`) rather than trusting this file's own text."
    echo ""
    echo "## Converted paths (target <- source)"
    echo ""
    printf '%s' "$MAP_LIST" | sed '/^$/d' | sed 's/^/- /'
    echo ""
    echo "## Hooks (NOT wired)"
    echo ""
    if [ -n "$HOOKS_SNIPPET" ]; then
        echo "Ready to paste into .claude/settings.json (this conversion never edits it):"
        echo ""
        printf '%s' "$HOOKS_SNIPPET" | sed '/^$/d' | sed 's/^/- /'
    else
        echo "(none)"
    fi
    echo ""
    echo "## Currently wired lines that will dangle once plugins/$plugin is deleted"
    echo ""
    local wired; wired="$(wired_lines_for_plugin "$plugin")"
    if [ -n "$wired" ]; then
        printf '%s\n' "$wired" | sed 's/^/- /'
    else
        echo "(none)"
    fi
    echo ""
    echo "## Follow-ups"
    echo ""
    local _cvt_unaccounted; _cvt_unaccounted="$(unconverted_plugin_files "$plugin")"
    # Reviewer round 2 (data-loss finding, on-disk half): this Follow-ups
    # gate used to read unconverted_plugin_files ALONE, while cmd_convert's
    # terminal gate also required nothing STOPped / no write failed — so a
    # run whose every unit was mapped but whose rewrite step failed
    # (apply_path_rewrites -> WRITE_FAILED; the files were written
    # UNREWRITTEN) had the terminal say "DO NOT delete" and this file, the
    # one a user may read later on its own, say "delete plugins/<p>". Same
    # gate on both surfaces now: CONVERT_RUN_STOPPED is what cmd_convert
    # knew before it called finalize_convert (unit STOPs + WRITE_FAILED).
    # This makes the record depend on the run's outcome, not only on the
    # source tree — deliberately: a record written by a failed run must say
    # the run failed, and the next clean run re-classifies it as KEEP
    # (render-stale on the scan side) rather than silently agreeing.
    if [ -z "$_cvt_unaccounted" ] && [ "${WRITE_FAILED:-false}" != "true" ] && [ "${CONVERT_RUN_STOPPED:-false}" != "true" ]; then
        echo "- delete plugins/$plugin once its converted commands/skills work through .claude/skills/"
    else
        echo "- DO NOT delete plugins/$plugin yet — not every file under it is accounted for by this conversion:"
        [ -n "$_cvt_unaccounted" ] && printf '%s\n' "$_cvt_unaccounted" | sed 's/^/  - /'
        if [ "${WRITE_FAILED:-false}" = "true" ] || [ "${CONVERT_RUN_STOPPED:-false}" = "true" ]; then
            echo "  - one or more units STOPped or a write failed in the run that wrote this record — resolve them (see that run's ERROR/STOP lines) and re-run convert"
        fi
    fi
    echo "- run .logic-loom/scripts/bash/sync-plugin-commands.sh prune to drop the bridge wrapper(s)"
    echo "- guide: .docs/guides/MIGRATION_GUIDE.md"
}

finalize_convert() {
    local plugin="$1" mode="$2"
    echo "Hooks (NOT wired):"
    if [ -n "$HOOKS_SNIPPET" ]; then
        printf '%s' "$HOOKS_SNIPPET" | sed 's/^/  /'
    else
        echo "  (none)"
    fi
    local target=".claude/skills/$plugin/CONVERTED.md"
    local rendered; rendered="$(render_converted_md "$plugin")"
    if [ -e "$REPO_ROOT/$target" ]; then
        _loom_rm_refuse_existing_symlink_target "$target" || return 1
        classify_existing_text "$target" "$rendered"
        return 0
    fi
    if [ "$mode" = "dry-run" ]; then
        echo "WRITE $target"
    else
        write_text_target "$target" "$rendered" || return 1
        echo "WROTE $target"
    fi
    return 0
}

record_converted_decision() {
    local plugin="$1"
    # Medium finding (round-2 review): follows the same "never write through
    # a symlink" rule write_text_target/copy_target already apply to
    # .claude/skills/ and .claude/agents/ targets — a `>>` append (or the
    # initial `>` header write below) follows a symlink at DECISIONS_FILE, or
    # at its parent directory, exactly like any other redirect would.
    if [ -L "$DECISIONS_FILE" ]; then
        echo "ERROR $DECISIONS_FILE: is a symlink (-> $(readlink "$DECISIONS_FILE" 2>/dev/null)) — refusing to write through it; replace it with a real file or remove it yourself, then re-run" >&2
        return 1
    fi
    local decisions_dir; decisions_dir="$(dirname -- "$DECISIONS_FILE")"
    # Round-4 finding (medium): this used to check only decisions_dir itself
    # (.logic-loom/config, ONE level above DECISIONS_FILE) — a symlink
    # planted at .logic-loom ITSELF (one level further up) went unchecked,
    # so `mkdir -p`/the `>` header write/the `>>` append below would still
    # follow it. Walk every component from decisions_dir up to (not
    # including) REPO_ROOT, same rule _loom_rm_refuse_symlink_parents
    # already applies on the WRITE path for .claude/skills/ and
    # .claude/agents/ targets — a component that does not exist yet cannot
    # be a symlink, so only existing components are checked.
    local check="$decisions_dir"
    while [ "$check" != "$REPO_ROOT" ] && [ "$check" != "/" ] && [ -n "$check" ]; do
        if [ -e "$check" ] && [ -L "$check" ]; then
            echo "ERROR $DECISIONS_FILE: an ancestor directory $check is a symlink (-> $(readlink "$check" 2>/dev/null)) — refusing to write through it; replace it with a real directory or remove it yourself, then re-run" >&2
            return 1
        fi
        check="$(dirname -- "$check")"
    done
    if [ ! -f "$DECISIONS_FILE" ]; then
        mkdir -p "$decisions_dir" 2>/dev/null || { echo "ERROR $DECISIONS_FILE: could not create $decisions_dir" >&2; return 1; }
        {
            echo "# Migration decisions — project-owned. 'keep = <name>[@<release>]' or 'converted = <name>'."
            echo "# Created on first use; commit it — decisions travel with the repo."
        } > "$DECISIONS_FILE" 2>/dev/null || { echo "ERROR $DECISIONS_FILE: write failed" >&2; return 1; }
    fi
    if ! grep -qxF "converted = $plugin" "$DECISIONS_FILE" 2>/dev/null; then
        echo "converted = $plugin" >> "$DECISIONS_FILE" 2>/dev/null || { echo "ERROR $DECISIONS_FILE: write failed" >&2; return 1; }
    fi
    return 0
}

cmd_convert() {
    local registry_arg="" name="" mode="" customized_only="false"
    while [ $# -gt 0 ]; do
        case "$1" in
            # Round-6 finding (low): see cmd_lint's identical fix above.
            --root) [ $# -ge 2 ] || die_usage "convert: --root requires a value"; shift 2 ;;
            --registry) registry_arg="$2"; shift 2 ;;
            --dry-run) mode="dry-run"; shift ;;
            --apply) mode="apply"; shift ;;
            --customized-only) customized_only="true"; shift ;;
            -*) die_usage "convert: unknown argument '$1'" ;;
            *) name="$1"; shift ;;
        esac
    done
    [ -n "$name" ] || die_usage "convert: <name> is required"
    [ -n "$mode" ] || die_usage "convert: --dry-run or --apply is required"

    resolve_registry "$registry_arg"
    resolve_project_registry ""

    local row
    row="$(loom_deprecation_row "$name" "$REGISTRY_FILE" 2>/dev/null)" || row=""
    if [ -z "$row" ] && [ -n "$PROJECT_REGISTRY_FILE" ]; then
        row="$(loom_deprecation_row "$name" "$PROJECT_REGISTRY_FILE" 2>/dev/null)" || row=""
    fi
    [ -n "$row" ] || die_usage "convert: no plugin-kind registry row named '$name'"
    local kind; kind="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"
    [ "$kind" = "plugin" ] || die_usage "convert: '$name' is not a plugin-kind row"

    local plugin_dir="$REPO_ROOT/plugins/$name"
    # Round-3 REVIEWER finding (high, data-loss): plugins/<name> ITSELF being
    # a symlink was never checked — `-d` follows the link and is true, and
    # every unit converter then reads THROUGH it (`find "$plugin_dir/skills"
    # …` is a path through a symlinked component, which find and every
    # other tool resolve; only a symlink given AS the start point is left
    # undescended). Reproduced: `plugins/pg -> <outside tree>` had that
    # entire outside tree's skills/commands/hooks rendered into .claude/,
    # CONVERTED.md written for it and `converted = pg` recorded, all under a
    # contract that says a symlink anywhere under plugins/ is never
    # converted. The delete step happened to be withheld (the link path
    # itself is listed by unconverted_plugin_files) but nothing else was.
    # Refuse up front, before anything is read or written: STOP line on
    # stdout so cmd_plan's inline dry-run keeps its output shape, the same
    # machine-stable `accounted:` NOT line every other withheld run prints
    # (so _loom_rm_converted_plugin_status reads it as not verified), rc 2
    # so nothing records a decision.
    if [ -L "$plugin_dir" ]; then
        echo "STOP plugins/$name: is a symlink (-> $(readlink "$plugin_dir" 2>/dev/null)) — a symlink anywhere under plugins/ is never converted, and neither is a plugin directory that is itself one; replace it with a real directory (or carry its target over by hand), then re-run"
        echo "accounted: NOT every file under plugins/$name is carried over by this conversion"
        echo "Next steps: DO NOT delete plugins/$name yet."
        return 2
    fi
    [ -d "$plugin_dir" ] || die_usage "convert: plugins/$name does not exist on disk"

    STATE_CHANGED=""; STATE_ADDED=""; STATE_DELETED=""
    if [ "$customized_only" = "true" ]; then
        local baseline; baseline="$(resolve_baseline "plugins/$name")"
        if [ "$baseline" = "none" ]; then
            echo "convert: --customized-only needs a resolvable baseline; plugins/$name has none — run a full convert instead" >&2
            return 1
        fi
        resolve_state "plugins/$name" "$baseline"
    fi

    plan_convert_units "$name"

    MAP_LIST=""
    HOOKS_SNIPPET=""
    STOPPED_SKILLS=""
    WRITE_FAILED="false"
    KEEP_DIFFERS_LIST=""
    CONVERT_RUN_STOPPED="false"
    local stopped="false"

    # Round-5 finding 6 (low): see build_rewrite_sed's comment above on the
    # same class of fix — `while IFS= read -r` in place of an unquoted
    # `for x in $LIST`, immune to both word-splitting on an embedded space
    # and glob expansion. `<<<` never forks a subshell in bash, so
    # `stopped="true"` set inside the loop body is still visible after it,
    # exactly as the unquoted `for` version was.
    local s
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "skills/$s"; then continue; fi
        convert_skill_unit "$name" "$s" "$mode" || stopped="true"
    done <<< "$SKILL_UNITS"
    local c
    while IFS= read -r c; do
        [ -z "$c" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "commands/$c.md"; then continue; fi
        convert_command_unit "$name" "$c" "$mode" "$customized_only" || stopped="true"
    done <<< "$COMMAND_UNITS"
    local a
    while IFS= read -r a; do
        [ -z "$a" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "agents/$a.md"; then continue; fi
        convert_agent_unit "$name" "$a" "$mode" || stopped="true"
    done <<< "$AGENT_UNITS"

    if [ "$customized_only" != "true" ]; then
        convert_hooks_and_support "$name" "$mode" || stopped="true"
        convert_support_index "$name" "$mode" || stopped="true"
    fi

    # Reviewer round 2: what this run knows BEFORE the record is rendered —
    # render_converted_md reads it so CONVERTED.md's Follow-ups take the
    # same gate as the terminal below (finalize_convert's own write failure
    # cannot be in the record it is writing; it still stops the run below).
    [ "$WRITE_FAILED" = "true" ] && stopped="true"
    CONVERT_RUN_STOPPED="$stopped"
    finalize_convert "$name" "$mode" || stopped="true"
    [ "$WRITE_FAILED" = "true" ] && stopped="true"

    # Finding 2 (data-loss, round 5 review): the delete recommendation may
    # be printed ONLY when every file under plugins/$name is accounted for
    # (see unconverted_plugin_files above) AND nothing STOPped/failed above
    # — never unconditionally. customized_only runs always leave most of the
    # tree unmapped on purpose, so this also correctly never recommends
    # delete after one.
    #
    # Reviewer round 1: the `accounted:` line is the ONE machine-stable
    # statement of that gate's outcome, printed in both modes.
    # _loom_rm_converted_plugin_status re-runs this command in --dry-run
    # for every `converted =` decision and requires the POSITIVE line
    # (fail-closed: absent means not verified) before scan/plan may say
    # REMOVE — without it, a `converted =` decision recorded by a run that
    # itself said "DO NOT delete … not carried over" was read as "delete
    # when verified" on the very next scan (reproduced with a plugin-root
    # commands/helper.sh the converter never touches). And a DRY RUN never
    # prints the delete step at all: nothing was written, so "once its
    # converted commands/skills work" is a condition that cannot yet hold —
    # it says to --apply first.
    local _cvt_unaccounted; _cvt_unaccounted="$(unconverted_plugin_files "$name")"
    if [ "$stopped" != "true" ] && [ -z "$_cvt_unaccounted" ]; then
        echo "accounted: every file under plugins/$name is carried over by this conversion (nothing STOPped, no write failed)"
        if [ "$mode" = "dry-run" ]; then
            echo "Next steps: nothing was written (dry-run) — run: release-migrations.sh convert $name --apply. Delete plugins/$name only after that run reports every file accounted for AND its converted commands/skills work through .claude/skills/; then run .logic-loom/scripts/bash/sync-plugin-commands.sh prune."
        else
            echo "Next steps: delete plugins/$name once its commands/skills work through .claude/skills/, then run .logic-loom/scripts/bash/sync-plugin-commands.sh prune."
        fi
    else
        echo "accounted: NOT every file under plugins/$name is carried over by this conversion"
        echo "Next steps: DO NOT delete plugins/$name yet."
        if [ -n "$_cvt_unaccounted" ]; then
            echo "  Not carried over by this run:"
            printf '%s\n' "$_cvt_unaccounted" | sed 's/^/    - /'
        fi
        if [ "$stopped" = "true" ]; then
            echo "  One or more units STOPped or a write failed above; resolve them and re-run convert."
        fi
        echo "  Once every file is accounted for, run .logic-loom/scripts/bash/sync-plugin-commands.sh prune to drop the bridge wrapper(s)."
    fi

    if [ "$mode" = "apply" ] && [ "$stopped" != "true" ]; then
        record_converted_decision "$name" || stopped="true"
    fi

    [ "$stopped" = "true" ] && return 2
    return 0
}

main() {
    if [ $# -eq 0 ]; then
        rm_show_help
        exit 1
    fi
    local cmd="$1"; shift
    case "$cmd" in
        --help|-h) rm_show_help ;;
        lint) cmd_lint "$@" ;;
        check-release) cmd_check_release "$@" ;;
        scan) cmd_scan "$@" ;;
        plan) cmd_plan "$@" ;;
        convert) cmd_convert "$@" ;;
        *) die_usage "unknown subcommand '$cmd' (--help for usage)" ;;
    esac
}

# Medium finding (round 5 review): the standard "only run main when executed
# directly, not when sourced" guard — added so a test can `source` this file
# (in a subshell, to keep its own trap/globals from leaking out) to call an
# internal function like _loom_rm_verify_fixture_scan_path DIRECTLY, the
# only way to prove the at-use traversal guard inside it actually fires
# on its own (every external, subprocess-level path to it is refused one
# layer earlier, by the shared parser). Behavior when run normally
# (`bash release-migrations.sh <cmd>` or `./release-migrations.sh <cmd>`)
# is unchanged: ${BASH_SOURCE[0]} and $0 are the same path in that case.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
