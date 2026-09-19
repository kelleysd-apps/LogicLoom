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
# Throwaway trees the check-release fixture-scan-path proof builds (finding
# 5, _loom_rm_verify_fixture_scan_path below); space-separated, removed on
# exit alongside the registry temp copy.
_LOOM_RM_PROOF_TMP_DIRS=""
_loom_rm_cleanup() {
    [ -n "$_LOOM_RM_TMP_REGISTRY" ] && rm -f "$_LOOM_RM_TMP_REGISTRY"
    local d
    for d in $_LOOM_RM_PROOF_TMP_DIRS; do
        [ -n "$d" ] && rm -rf "$d"
    done
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
            --root) shift 2 ;;
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

    local tmp
    if ! tmp="$(mktemp -d "${TMPDIR:-/tmp}/loom-rm-fixtureproof.XXXXXX" 2>/dev/null)" || [ -z "$tmp" ]; then
        echo "check-release: $label: fixture proof (scan path): cannot create a scratch tree (mktemp -d failed) — the proof could not run, and a proof that cannot run is not a pass"
        return 1
    fi
    _LOOM_RM_PROOF_TMP_DIRS="${_LOOM_RM_PROOF_TMP_DIRS} $tmp"

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
            local current_matches; current_matches="$(content_matches "$name")"
            if [ -z "$current_matches" ]; then
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
            --root) shift 2 ;;
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
        case "$prev" in v[0-9]*.[0-9]*.[0-9]*) prev_is_version="true" ;; esac
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
            surface_n="$(git -C "$REPO_ROOT" diff --name-only "$prev" -- plugins .logic-loom/config .logic-loom/lib .claude/settings.json .claude/hooks 2>/dev/null | wc -l | tr -d ' ')" || surface_n=0
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

build_remove_cmd() {
    local kind="$1" name="$2" path="$3"
    case "$kind" in
        plugin) REC_REMOVE_CMD="git rm -r plugins/$name" ;;
        mcp-server) REC_REMOVE_CMD="git rm -r mcp-servers/$name" ;;
        path)
            if [ -d "$REPO_ROOT/$path" ]; then
                REC_REMOVE_CMD="git rm -r $path"
            else
                REC_REMOVE_CMD="git rm $path"
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
# itself produced. Unlike a tag, an adopter cannot forge this: it is not
# "does this commit look like a release", it is "did LogicLoom's own writer
# (record-update-writes.sh / packaging/adopt's apply.js) record THIS exact
# path with THIS exact hash". Only ever matches a `kind:"file"` entry, so it
# naturally never fires for a plugin/mcp-server directory (those are
# recorded, if at all, as `kind:"dir"` — presence only, no hash, and
# presence alone proves nothing about whether the directory has since been
# customized). Empty stdout + rc 1 when the receipt is absent, unparsable,
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
    files = {}
    for run in data['runs']:
        if not isinstance(run, dict) or run.get('status') not in ('complete', 'partial', 'in-progress'):
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
_loom_rm_sha256_file() {
    local f="$1"
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
        if recorded_sha="$(_loom_rm_adopt_receipt_sha256 "$path")" && [ -n "$recorded_sha" ]; then
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

# Sets STATE, STATE_CHANGED, STATE_ADDED, STATE_DELETED (newline lists).
resolve_state() {
    local path="$1" baseline="$2"
    STATE_CHANGED=""; STATE_ADDED=""; STATE_DELETED=""
    if [ "$baseline" = "none" ]; then
        STATE="unknown"
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
    local untracked
    untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$path" 2>/dev/null)" || untracked=""
    if git -C "$REPO_ROOT" diff --quiet "$baseref" -- "$path" 2>/dev/null && [ -z "$untracked" ]; then
        STATE="pristine"
    else
        STATE="customized"
        local ns
        ns="$(git -C "$REPO_ROOT" diff --name-status "$baseref" -- "$path" 2>/dev/null)" || ns=""
        STATE_CHANGED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^M/ {print $NF}')"
        STATE_ADDED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^A/ {print $NF}')"
        STATE_DELETED="$(printf '%s\n' "$ns" | awk -F'\t' '$1 ~ /^D/ {print $NF}')"
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
# and ALSO any untracked, non-ignored file under it, exactly as
# resolve_state() counts untracked files for every other row. An untracked
# file inside plugins/<name> is a customer's bytes that no commit vouches
# for; a REMOVE plan line on that directory recommends deleting it (the
# printed `git rm -r` would leave it, but the recommendation is the harm the
# governing principle names). "unknown" when no decision commit can be found
# at all: never silently read as "unchanged". Read-only git only (diff,
# ls-files).
_loom_rm_converted_plugin_status() {
    local plugin="$1" path="$2" commit untracked
    if ! commit="$(_loom_rm_converted_decision_commit "$plugin")"; then
        printf 'unknown'
        return 0
    fi
    untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$path" 2>/dev/null)" || untracked=""
    if [ -z "$untracked" ] && git -C "$REPO_ROOT" diff --quiet "$commit" -- "$path" 2>/dev/null; then
        printf 'unchanged'
    else
        printf 'changed:%s' "$commit"
    fi
    return 0
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
                REC_REASON="CONVERTED, but $path was edited after conversion (changed since the decision commit ${cstatus#changed:}: a tracked edit, or an untracked file under it) — ASK before removing; verify the edit was carried over, then decide by hand"
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
                    REC_MOVE_CMD="if [ -e '$newp' ]; then echo 'release-migrations: $newp already exists on disk — refusing to overwrite (something added it since this was planned); re-run: release-migrations.sh plan $name' >&2; false; else mkdir -p \"\$(dirname '$newp')\" && git mv $path $newp; fi"
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
            find "$REPO_ROOT" \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/node_modules" \) -prune \
                -o -type f -path "$REPO_ROOT/$name" -print 2>/dev/null \
                | sed "s#^$REPO_ROOT/##" ;;
        *)
            [ -f "$REPO_ROOT/$name" ] && printf '%s\n' "$name" ;;
    esac
    return 0
}

emit_content_item() {
    local source="$1" row="$2" json_mode="$3"
    local kind name fate repl default first release note
    IFS=$'\t' read -r kind name fate repl default first release note <<< "$row"
    [ "$kind" = "content" ] || return 1
    local pattern="${repl#pattern:}"

    local matched_files
    matched_files="$(content_matches "$name")"
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
                    consequence="plugins/$dname still on disk — delete it once the converted command works, then run .logic-loom/scripts/bash/sync-plugin-commands.sh prune"
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
            --root) shift 2 ;;
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
            --root) shift 2 ;;
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

build_rewrite_sed() {
    local plugin="$1" sedfile="$2"
    : > "$sedfile"
    {
        printf 's|\\${CLAUDE_PLUGIN_ROOT}|.claude/skills/%s|g\n' "$plugin"
        printf 's|\\$CLAUDE_PLUGIN_ROOT|.claude/skills/%s|g\n' "$plugin"
        local s
        for s in $SKILL_UNITS; do
            [ -z "$s" ] && continue
            printf 's|plugins/%s/skills/%s|.claude/skills/%s|g\n' "$plugin" "$s" "$s"
        done
        local c
        for c in $COMMAND_UNITS; do
            [ -z "$c" ] && continue
            printf 's|plugins/%s/commands/%s\\.md|.claude/skills/%s/SKILL.md|g\n' "$plugin" "$c" "$c"
        done
        local a
        for a in $AGENT_UNITS; do
            [ -z "$a" ] && continue
            printf 's|plugins/%s/agents/%s\\.md|.claude/agents/%s.md|g\n' "$plugin" "$a" "$a"
        done
        printf 's|plugins/%s/|.claude/skills/%s/|g\n' "$plugin" "$plugin"
    } >> "$sedfile"
}

apply_path_rewrites() {
    local content="$1" plugin="$2" sedfile
    sedfile="$(mktemp "${TMPDIR:-/tmp}/loom-rw.XXXXXX")"
    build_rewrite_sed "$plugin" "$sedfile"
    printf '%s\n' "$content" | sed -f "$sedfile"
    rm -f "$sedfile"
}

plan_convert_units() {
    local plugin="$1" plugin_dir
    plugin_dir="$REPO_ROOT/plugins/$plugin"
    SKILL_UNITS="$(find "$plugin_dir/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s#^$plugin_dir/skills/##")"
    COMMAND_UNITS="$(find "$plugin_dir/commands" -maxdepth 1 -name '*.md' 2>/dev/null | sed "s#^$plugin_dir/commands/##; s/\\.md\$//")"
    AGENT_UNITS="$(find "$plugin_dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | sed "s#^$plugin_dir/agents/##; s/\\.md\$//")"
}

unit_touched() {
    local plugin="$1" sub="$2" full
    full="plugins/$plugin/$sub"
    printf '%s\n%s\n' "$STATE_CHANGED" "$STATE_ADDED" | grep -qE "^${full}(\$|/)" && return 0
    return 1
}

find_other_plugin_owning() {
    # $1 = glob-relative path under plugins/*/, $2 = path to exclude
    find "$REPO_ROOT/plugins" -maxdepth 4 -path "$REPO_ROOT/plugins/*/$1" ! -path "$2" 2>/dev/null | head -1
}

owning_plugin_name() {
    printf '%s' "$1" | sed -E "s#^$REPO_ROOT/plugins/([^/]+)/.*\$#\\1#"
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
write_text_target() {   # $1 = repo-relative target, $2 = content (newline appended), $3 = optional source path whose +x bit to preserve
    local target="$1" content="$2" srcfile="${3:-}"
    if mkdir -p "$REPO_ROOT/$(dirname "$target")" 2>/dev/null \
       && printf '%s\n' "$content" > "$REPO_ROOT/$target" 2>/dev/null; then
        # A rewritten text file (path rewrites, marker insertion, model
        # pin rewrite) still goes through the `>` redirect above, which
        # never carries over the source's mode — preserve the executable
        # bit explicitly so a converted helper script stays runnable.
        [ -n "$srcfile" ] && [ -x "$srcfile" ] && chmod +x "$REPO_ROOT/$target" 2>/dev/null
        return 0
    fi
    echo "ERROR $target: write failed"
    WRITE_FAILED="true"
    return 1
}
copy_target() {   # $1 = repo-relative target, $2 = absolute source (mode preserved)
    local target="$1" src="$2"
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
classify_existing_text() {   # $1 = target, $2 = rendered content
    if diff -q <(printf '%s\n' "$2") "$REPO_ROOT/$1" >/dev/null 2>&1; then
        echo "SKIP $1 up-to-date"
    else
        echo "KEEP $1 modified-after-conversion"
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
            rendered="$(apply_path_rewrites "$original" "$plugin")"
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
        note_mapping "$target <- plugins/$plugin/skills/$skill/$relf"
        if [ -e "$REPO_ROOT/$target" ]; then
            if [ -n "$rendered" ]; then
                classify_existing_text "$target" "$rendered"
            elif cmp -s "$f" "$REPO_ROOT/$target" 2>/dev/null; then
                echo "SKIP $target up-to-date"
            else
                echo "KEEP $target modified-after-conversion"
            fi
            continue
        fi
        if [ "$mode" = "dry-run" ]; then
            echo "MKDIR $(dirname "$target")"
            echo "WRITE $target <- plugins/$plugin/skills/$skill/$relf [rewrites: $nrw]$modelnote"
        else
            if [ -n "$rendered" ]; then
                write_text_target "$target" "$rendered" "$f" || return 1
            else
                copy_target "$target" "$f" || return 1
            fi
            echo "WROTE $target <- plugins/$plugin/skills/$skill/$relf [rewrites: $nrw]$modelnote"
        fi
    done <<< "$(find "$srcdir" -type f 2>/dev/null | sort)"
    return 0
}

render_command_skill() {
    local plugin="$1" cmd="$2" src content
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
    content="$(apply_path_rewrites "$content" "$plugin")"
    content="$(insert_marker "$content" "$plugin" "commands/$cmd.md")"
    printf '%s\n' "$content"
}

render_append_section() {
    local plugin="$1" cmd="$2" src fm body
    src="$REPO_ROOT/plugins/$plugin/commands/$cmd.md"
    fm=""; body=""
    if head -1 "$src" 2>/dev/null | grep -q '^---$'; then
        fm="$(awk 'BEGIN{infm=0} NR==1&&$0=="---"{infm=1;next} infm==1&&$0=="---"{exit} infm==1{print}' "$src")"
        body="$(awk 'BEGIN{infm=0;past=0} NR==1&&$0=="---"{infm=1;next} infm==1&&$0=="---"{infm=0;past=1;next} past==1{print}' "$src")"
    else
        body="$(cat "$src")"
    fi
    body="$(apply_path_rewrites "$body" "$plugin")"
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
    [ -f "$REPO_ROOT/$target" ] && existing_body="$(cat "$REPO_ROOT/$target")"
    note_mapping "$ledger"
    if printf '%s\n' "$existing_body" | grep -qF -- "$start_marker"; then
        local between
        between="$(printf '%s\n' "$existing_body" | awk -v s="$start_marker" -v e="$end_marker" '$0==s{inb=1;next} $0==e{inb=0;next} inb{print}')"
        if [ "$between" = "$section" ]; then
            echo "SKIP $target up-to-date"
        else
            echo "KEEP $target modified-after-conversion"
        fi
        return 0
    fi
    if [ "$mode" = "dry-run" ]; then
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
    local section; section="$(render_append_section "$plugin" "$cmd")"
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
    local rendered; rendered="$(render_command_skill "$plugin" "$cmd")"
    if [ -e "$REPO_ROOT/$target" ]; then
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/commands/$cmd.md "; then
            note_mapping "$target <- plugins/$plugin/commands/$cmd.md"
            classify_existing_text "$target" "$rendered"
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
    local nrw original
    original="$(cat "$src")"
    nrw="$(count_rewrites "$original" "$(apply_path_rewrites "$original" "$plugin")")"
    rewrite_model_if_pinned "$original"
    note_mapping "$target <- plugins/$plugin/commands/$cmd.md"
    if [ "$mode" = "dry-run" ]; then
        echo "MKDIR .claude/skills/$cmd"
        echo "WRITE $target <- plugins/$plugin/commands/$cmd.md [rewrites: $nrw]$RW_MODEL_NOTE"
    else
        write_text_target "$target" "$rendered" "$src" || return 1
        echo "WROTE $target <- plugins/$plugin/commands/$cmd.md [rewrites: $nrw]$RW_MODEL_NOTE"
    fi
    return 0
}

convert_agent_unit() {
    local plugin="$1" agent="$2" mode="$3"
    local src="$REPO_ROOT/plugins/$plugin/agents/$agent.md"
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
    local rewritten; rewritten="$(apply_path_rewrites "$content" "$plugin")"
    nrw="$(count_rewrites "$content" "$rewritten")"
    content="$(insert_marker "$rewritten" "$plugin" "agents/$agent.md")"
    if [ -e "$REPO_ROOT/$target" ]; then
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/agents/$agent.md "; then
            note_mapping "$target <- plugins/$plugin/agents/$agent.md"
            classify_existing_text "$target" "$content"
            return 0
        else
            echo "STOP agents/$agent.md: .claude/agents/$agent.md already exists without our marker"
            return 1
        fi
    fi
    note_mapping "$target <- plugins/$plugin/agents/$agent.md"
    if [ "$mode" = "dry-run" ]; then
        echo "WRITE $target <- plugins/$plugin/agents/$agent.md [rewrites: $nrw]$modelnote"
    else
        write_text_target "$target" "$content" "$src" || return 1
        echo "WROTE $target <- plugins/$plugin/agents/$agent.md [rewrites: $nrw]$modelnote"
    fi
    return 0
}

# hooks/, scripts/, lib/, config/, templates/, tests/, README.md and the
# manifest -> .claude/skills/<p>/… . A target that already exists is
# classified (§4.3): byte-identical -> SKIP; listed in the existing
# CONVERTED.md ledger -> KEEP; anything else -> STOP (never overwritten).
convert_hooks_and_support() {
    local plugin="$1" mode="$2" srcdir="$REPO_ROOT/plugins/$1" rel rc=0
    for rel in hooks scripts lib config templates tests README.md; do
        local srcpath="$srcdir/$rel"
        [ -e "$srcpath" ] || continue
        local files
        if [ -d "$srcpath" ]; then files="$(find "$srcpath" -type f 2>/dev/null | sort)"; else files="$srcpath"; fi
        local f relf target is_text rendered original nrw
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            relf="${f#"$srcdir"/}"
            target=".claude/skills/$plugin/$relf"
            is_text="false"; rendered=""; nrw=0
            if grep -Iq . "$f" 2>/dev/null; then
                is_text="true"
                original="$(cat "$f")"
                rendered="$(apply_path_rewrites "$original" "$plugin")"
                nrw="$(count_rewrites "$original" "$rendered")"
            fi
            if [ "$rel" = "hooks" ] && [ "$relf" != "hooks/hooks.json" ]; then
                HOOKS_SNIPPET="${HOOKS_SNIPPET}{\"type\":\"command\",\"command\":\"bash $target\"}"$'\n'
            fi
            if [ -e "$REPO_ROOT/$target" ]; then
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
                else
                    echo "STOP $relf: $target already exists and is not ours (not in .claude/skills/$plugin/CONVERTED.md)"
                    rc=1
                fi
                continue
            fi
            note_mapping "$target <- plugins/$plugin/$relf"
            if [ "$mode" = "dry-run" ]; then
                echo "MKDIR $(dirname "$target")"
                echo "WRITE $target <- plugins/$plugin/$relf [rewrites: $nrw]"
            else
                if [ "$is_text" = "true" ]; then
                    write_text_target "$target" "$rendered" "$f" || { rc=1; continue; }
                else
                    copy_target "$target" "$f" || { rc=1; continue; }
                fi
                echo "WROTE $target <- plugins/$plugin/$relf [rewrites: $nrw]"
            fi
        done <<< "$files"
    done
    if [ -f "$srcdir/.claude-plugin/plugin.json" ]; then
        local target=".claude/skills/$plugin/plugin.json.orig"
        note_mapping "$target <- plugins/$plugin/.claude-plugin/plugin.json"
        if [ -e "$REPO_ROOT/$target" ]; then
            if cmp -s "$srcdir/.claude-plugin/plugin.json" "$REPO_ROOT/$target" 2>/dev/null; then
                echo "SKIP $target up-to-date"
            else
                echo "KEEP $target modified-after-conversion"
            fi
        elif [ "$mode" = "dry-run" ]; then
            echo "WRITE $target <- plugins/$plugin/.claude-plugin/plugin.json"
        else
            copy_target "$target" "$srcdir/.claude-plugin/plugin.json" || rc=1
            [ "$rc" -eq 0 ] && echo "WROTE $target <- plugins/$plugin/.claude-plugin/plugin.json"
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
    note_mapping "$target <- plugins/$plugin/ (support index)"
    if [ -e "$REPO_ROOT/$target" ]; then
        if head -20 "$REPO_ROOT/$target" 2>/dev/null | grep -qF "converted-from: plugins/$plugin/ "; then
            classify_existing_text "$target" "$content"
            return 0
        fi
        echo "STOP support index: $target already exists without our marker"
        return 1
    fi
    if [ "$mode" = "dry-run" ]; then
        echo "WRITE $target (support index for plugins/$plugin)"
    else
        write_text_target "$target" "$content" || return 1
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

# The record. A pure function of the source tree + the registry row: no
# timestamps, and the mapping is the plan, not this run's writes.
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
    echo "- delete plugins/$plugin once its converted commands/skills work through .claude/skills/"
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
    if [ ! -f "$DECISIONS_FILE" ]; then
        mkdir -p "$(dirname "$DECISIONS_FILE")"
        {
            echo "# Migration decisions — project-owned. 'keep = <name>[@<release>]' or 'converted = <name>'."
            echo "# Created on first use; commit it — decisions travel with the repo."
        } > "$DECISIONS_FILE"
    fi
    if ! grep -qxF "converted = $plugin" "$DECISIONS_FILE" 2>/dev/null; then
        echo "converted = $plugin" >> "$DECISIONS_FILE"
    fi
}

cmd_convert() {
    local registry_arg="" name="" mode="" customized_only="false"
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) shift 2 ;;
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
    local stopped="false"

    local s
    for s in $SKILL_UNITS; do
        [ -z "$s" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "skills/$s"; then continue; fi
        convert_skill_unit "$name" "$s" "$mode" || stopped="true"
    done
    local c
    for c in $COMMAND_UNITS; do
        [ -z "$c" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "commands/$c.md"; then continue; fi
        convert_command_unit "$name" "$c" "$mode" "$customized_only" || stopped="true"
    done
    local a
    for a in $AGENT_UNITS; do
        [ -z "$a" ] && continue
        if [ "$customized_only" = "true" ] && ! unit_touched "$name" "agents/$a.md"; then continue; fi
        convert_agent_unit "$name" "$a" "$mode" || stopped="true"
    done

    if [ "$customized_only" != "true" ]; then
        convert_hooks_and_support "$name" "$mode" || stopped="true"
        convert_support_index "$name" "$mode" || stopped="true"
    fi

    finalize_convert "$name" "$mode" || stopped="true"
    echo "Next steps: delete plugins/$name once its commands/skills work through .claude/skills/, then run .logic-loom/scripts/bash/sync-plugin-commands.sh prune."

    [ "$WRITE_FAILED" = "true" ] && stopped="true"
    if [ "$mode" = "apply" ] && [ "$stopped" != "true" ]; then
        record_converted_decision "$name"
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

main "$@"
