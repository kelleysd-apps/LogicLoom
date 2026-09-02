#!/usr/bin/env bash
# Extract Enhancement Proposals from Upstream History
# Plugin: loom-maintenance (Additive Update Framework)
#
# Reads .sdd-sync-ref, fetches upstream's history AD-HOC (fetch-only, no remote),
# diffs upstream's OWN history, and outputs categorized enhancement proposals for
# selective adoption.
#
# MISFIRE-PROOF BY DESIGN:
#   • FETCH-ONLY. The upstream is fetched ad-hoc into the namespaced ref
#     `refs/loom-upstream/main`. NO `upstream` remote is ever created, so
#     `git push upstream …` cannot exist. Nothing here can push your commits
#     anywhere. All adoption (done by the skill/command) commits to YOUR branch.
#   • The upstream URL is config-driven (framework-upstream.conf / LOOM_UPSTREAM_URL),
#     NEVER derived from `origin` (origin is your own repo — the wrong direction).
#   • Upstream-history-only: diffs sync-ref..refs/loom-upstream/main. NEVER
#     compares downstream content vs upstream; NEVER merges.
#
# Usage:
#   bash extract-proposals.sh              # fetch + extract proposals (JSON)
#   bash extract-proposals.sh --dry-run    # fetch + show sync-ref/upstream status
#   bash extract-proposals.sh --help       # usage
#
# Output: JSON array of enhancement proposals to stdout (proposals only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC_REF_FILE="$REPO_ROOT/.sdd-sync-ref"
UPSTREAM_CONF="$REPO_ROOT/.logic-loom/config/framework-upstream.conf"

# The ad-hoc, non-branch, non-remote ref the upstream lands in. `git push --all` /
# push.default ignore refs/loom-upstream/*, and there is no remote to push to.
LOOM_UPSTREAM_REF="${LOOM_UPSTREAM_REF:-refs/loom-upstream/main}"

# ============================================
# Adopted-repo awareness (globals; safe defaults = TEMPLATE-CLONE / no-op)
# ============================================
#
# A TEMPLATE CLONE (this repo included) must see COMPLETELY UNCHANGED behavior.
# These globals default to the template-clone posture so that any caller which
# never invokes detect_adopt_mode (e.g. a test sourcing this file and calling
# extract_proposals directly) still gets the original behavior.
ADOPT_MODE="TEMPLATE"
ADOPT_DETECTED_BY=""
ADOPT_WROTE=""              # newline list of "kind<TAB>path" from the receipt
ADOPT_GENERATOR_VERSION=""
ADOPT_RECEIPT_USABLE="false"
ADOPT_PY_MISSING="false"

# ============================================
# Usage
# ============================================

show_help() {
    cat <<'EOF'
Extract Enhancement Proposals from Upstream History (fetch-only, no remote)

Usage:
  extract-proposals.sh              Fetch upstream ad-hoc + extract proposals (JSON)
  extract-proposals.sh --dry-run    Fetch + show sync-ref and upstream status
  extract-proposals.sh --help       Show this help

Fetches the configured upstream (framework-upstream.conf or $LOOM_UPSTREAM_URL)
into refs/loom-upstream/main WITHOUT creating a git remote, reads .sdd-sync-ref,
and diffs upstream's own history (sync-ref..refs/loom-upstream/main) to extract
discrete enhancement proposals. Never compares downstream vs upstream; never
pushes; never merges. Adoption + commits are done by /update-framework against
YOUR current branch.

Each proposal carries the upstream release tag it landed in (release_tag), so
/update-framework can group proposals by release rather than presenting one flat
undifferentiated list. Proposals with no reachable tag report release_tag: null.

Output: JSON array of enhancement proposals.
EOF
}

# ============================================
# Config / upstream resolution
# ============================================

# Read a key=value from a conf file (strips quotes, trailing comments, whitespace)
_conf_val() {
    grep -E "^[[:space:]]*$2[[:space:]]*=" "$1" 2>/dev/null | head -1 \
        | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

# Resolve the upstream URL. Precedence: env LOOM_UPSTREAM_URL > conf URL >
# conf REPO (-> github url). NEVER falls back to origin. Returns 1 if unresolved.
resolve_upstream_url() {
    if [ -n "${LOOM_UPSTREAM_URL:-}" ]; then
        printf '%s' "$LOOM_UPSTREAM_URL"; return 0
    fi
    if [ -f "$UPSTREAM_CONF" ]; then
        local url repo
        url="$(_conf_val "$UPSTREAM_CONF" LOOM_UPSTREAM_URL)"
        if [ -n "$url" ]; then printf '%s' "$url"; return 0; fi
        repo="$(_conf_val "$UPSTREAM_CONF" LOOM_UPSTREAM_REPO)"
        if [ -n "$repo" ]; then printf 'https://github.com/%s.git' "$repo"; return 0; fi
    fi
    return 1
}

# Ad-hoc FETCH-ONLY into the namespaced ref. Creates no remote, pulls no tags.
fetch_upstream() {
    local url="$1"
    local opts="--no-tags"
    # --no-write-fetch-head (git 2.29+) keeps FETCH_HEAD clean; use only if supported.
    if git fetch -h 2>&1 | grep -q -- '--no-write-fetch-head'; then
        opts="$opts --no-write-fetch-head"
    fi
    # shellcheck disable=SC2086
    git -C "$REPO_ROOT" fetch $opts "$url" "+refs/heads/main:$LOOM_UPSTREAM_REF"
}

read_sync_ref() {
    [ -f "$SYNC_REF_FILE" ] && tr -d '[:space:]' < "$SYNC_REF_FILE" || echo ""
}

# ============================================
# Known-bad sync-ref remap (one-time historical repair)
# ============================================
#
# WHY THIS EXISTS
#   Two shipped releases (v6.3.1, v6.4.0) stamped `.sdd-sync-ref` with a commit
#   that lives ONLY on the release branch: their release PRs were squash-merged
#   (branch protection required linear history, so a merge commit was impossible),
#   so the stamped SHA never landed on `main`. Every customer on those releases
#   hits the "NOT reachable from upstream main" guard below and can never update.
#   The release process has since been fixed.
#
# CRITERIA FOR ADDING AN ENTRY (all must hold)
#   1. The bad SHA was actually SHIPPED in a template release (customers have it).
#   2. There is an unambiguous equivalent commit ON `main` for the SAME release.
#   3. The mapped target has been verified an ancestor of `main`.
#   This is a fixed historical repair list, NOT a general remapping mechanism —
#   do not use it to paper over a future baseline bug. Fix the release process.
#
# bash 3.2 safe: a case statement, no associative arrays.
remap_known_bad_sync_ref() {
    case "$1" in
        # v6.3.1 — stamped release-branch SHA -> the v6.3.1 commit on main
        6c4c42067161bf77e3e1af0ff91691319bd2fbdc)
            echo "a2ed86231e097886f58e7fd0e5161648c6e6cfa3" ;;
        # v6.4.0 — stamped release-branch SHA -> the v6.4.0 commit on main
        c6d040f36ecb6ef4a5365e9434b4e31dc741e4ac)
            echo "75551c3574eea3f54a92d044da2e1a92b4e9590c" ;;
        *)
            echo "" ;;
    esac
}

# Bootstrap-if-missing + reachability guard. Prints the sync-ref on success.
# On a missing sync-ref: sets the baseline to the fetched upstream tip, adopts
# nothing this run, emits [] and exits 0. On an unreachable sync-ref (the
# single-parent chain broke via a squash/rebase merge upstream): clear error +
# safe re-baseline hint, exit 3.
ensure_sync_ref() {
    local sync_ref tip
    sync_ref="$(read_sync_ref)"
    if [ -z "$sync_ref" ]; then
        tip="$(git -C "$REPO_ROOT" rev-parse "$LOOM_UPSTREAM_REF" 2>/dev/null || echo "")"
        [ -n "$tip" ] && printf '%s\n' "$tip" > "$SYNC_REF_FILE"
        echo "No .sdd-sync-ref found — baseline established at current upstream HEAD (${tip:-unknown})." >&2
        echo "Adopting nothing this run; re-run /update-framework later to see new upstream changes." >&2
        echo "[]"
        exit 0
    fi
    if ! git -C "$REPO_ROOT" cat-file -e "${sync_ref}^{commit}" 2>/dev/null \
       || ! git -C "$REPO_ROOT" merge-base --is-ancestor "$sync_ref" "$LOOM_UPSTREAM_REF" 2>/dev/null; then

        # Self-heal: a known-bad SHIPPED baseline is repaired in place, then we
        # continue normally. The mapped target must itself be reachable from the
        # fetched upstream (a fork/custom upstream may not have it) — otherwise
        # fall through to the error path rather than writing a bogus value.
        local remapped
        remapped="$(remap_known_bad_sync_ref "$sync_ref")"
        if [ -n "$remapped" ] \
           && git -C "$REPO_ROOT" cat-file -e "${remapped}^{commit}" 2>/dev/null \
           && git -C "$REPO_ROOT" merge-base --is-ancestor "$remapped" "$LOOM_UPSTREAM_REF" 2>/dev/null; then
            printf '%s\n' "$remapped" > "$SYNC_REF_FILE"
            echo "NOTICE: your .sdd-sync-ref ($sync_ref) was a known-bad baseline shipped by an upstream release (its release PR was squash-merged, so that commit only ever existed on a release branch, never on main). It has been repaired automatically to the equivalent main commit ($remapped); the update proceeds normally from here and WILL include the changes you were previously unable to see." >&2
            printf '%s' "$remapped"
            return 0
        fi

        echo "ERROR: .sdd-sync-ref ($sync_ref) is NOT reachable from upstream main." >&2
        echo "An upstream release PR was likely squash/rebase-merged, breaking the single-parent chain." >&2
        echo "See .docs/guides/FRAMEWORK_SYNC_GUIDE.md -> 'Broken sync baseline'." >&2
        echo "" >&2
        echo "PREFERRED FIX — keep your real diff. Point .sdd-sync-ref at the upstream main" >&2
        echo "commit matching the LogicLoom version you actually have installed. Find it with:" >&2
        echo "  git log --oneline $LOOM_UPSTREAM_REF | grep \"Release v<your version>\"" >&2
        echo "then write that SHA into .sdd-sync-ref. You will then be offered every change" >&2
        echo "made upstream since your version." >&2
        echo "" >&2
        echo "LAST RESORT — safe re-baseline. This ADOPTS NOTHING: it declares you already" >&2
        echo "current, so every upstream change between your version and today's upstream is" >&2
        echo "SKIPPED PERMANENTLY and will never be proposed to you:" >&2
        echo "  git rev-parse $LOOM_UPSTREAM_REF > .sdd-sync-ref" >&2
        exit 3
    fi
    printf '%s' "$sync_ref"
}

# ============================================
# Proposal helpers (history-only; unchanged logic)
# ============================================

list_tags_in_range() {
    local sync_ref="$1"
    local upstream_ref="${2:-$LOOM_UPSTREAM_REF}"
    git -C "$REPO_ROOT" log --format='%H' "$sync_ref..$upstream_ref" 2>/dev/null | while read -r commit; do
        local tag
        tag=$(git -C "$REPO_ROOT" tag --points-at "$commit" 2>/dev/null | grep -E '^v[0-9]' | head -1)
        [ -n "$tag" ] && echo "$tag $commit"
    done
}

find_tag_for_file() {
    local file_path="$1"
    local sync_ref="$2"
    local upstream_ref="${3:-$LOOM_UPSTREAM_REF}"
    local commits
    commits=$(git -C "$REPO_ROOT" log --format='%H' "$sync_ref..$upstream_ref" -- "$file_path" 2>/dev/null)
    for commit in $commits; do
        local tag
        tag=$(git -C "$REPO_ROOT" tag --points-at "$commit" 2>/dev/null | grep -E '^v[0-9]' | head -1)
        if [ -n "$tag" ]; then echo "$tag"; return; fi
    done
    local range_tags
    range_tags=$(list_tags_in_range "$sync_ref" "$upstream_ref")
    if [ -n "$range_tags" ]; then
        echo "$range_tags" | while read -r tag commit; do
            if git -C "$REPO_ROOT" diff --name-only "$sync_ref..$commit" 2>/dev/null | grep -qF "$file_path"; then
                echo "$tag"; return
            fi
        done | head -1
    fi
    echo ""
}

categorize_change() {
    local file_path="$1"
    case "$file_path" in
        plugins/*/commands/*)   echo "command" ;;
        plugins/*/skills/*)     echo "skill" ;;
        plugins/*/agents/*)     echo "agent" ;;
        plugins/*)              echo "plugin" ;;
        .logic-loom/memory/*)   echo "governance" ;;
        .logic-loom/scripts/*)  echo "script" ;;
        .logic-loom/config/*)   echo "config" ;;
        .claude/*)              echo "config" ;;
        tests/*)                echo "test" ;;
        CLAUDE.md|AGENTS.md)    echo "config" ;;
        mcp-servers/*)          echo "mcp" ;;
        *)                      echo "other" ;;
    esac
}

describe_change() {
    local file_path="$1" change_type="$2" category="$3"
    case "$change_type" in
        A) echo "New ${category}: ${file_path}" ;;
        M) echo "Updated ${category}: ${file_path}" ;;
        D) echo "Removed upstream: ${file_path}" ;;
        R*) echo "Renamed/restructured: ${file_path}" ;;
        *) echo "Changed: ${file_path}" ;;
    esac
}

proposal_type() {
    case "$1" in
        A) echo "new-file" ;;
        M) echo "modified-content" ;;
        D) echo "info" ;;
        R*) echo "structural-change" ;;
        *) echo "modified-content" ;;
    esac
}

# ============================================
# Adopted-repo detection
# ============================================
#
# ADOPTED means: this checkout was produced by `npx logicloom init` into someone
# ELSE'S existing repo (packaging/adopt), not cloned as a template. In that mode
# most of a template's own upstream-diff proposals are wrong: they either target
# a merge channel that must never be overwritten (a) or a path the adopter never
# had installed in the first place ((c)/(d)) — see extract_proposals below.
#
# Primary signal: `.logicloom-adopt-receipt.json` at repo root, schema-checked.
# Fallback signal (receipt is not committed by default, so a teammate's clone of
# an adopted repo may lack it): `.logic-loom/AGENTS.md` — only the adopt path
# ever installs AGENTS.md there (a template clone has AGENTS.md at repo root).
# Anything else is a TEMPLATE CLONE — behavior must be identical to upstream.
detect_adopt_mode() {
    ADOPT_MODE="TEMPLATE"
    ADOPT_DETECTED_BY=""
    ADOPT_WROTE=""
    ADOPT_GENERATOR_VERSION=""
    ADOPT_RECEIPT_USABLE="false"
    ADOPT_PY_MISSING="false"

    local receipt_path="$REPO_ROOT/.logicloom-adopt-receipt.json"
    local agents_marker="$REPO_ROOT/.logic-loom/AGENTS.md"

    if [ -f "$receipt_path" ]; then
        if command -v python3 >/dev/null 2>&1; then
            local py_out first_line
            py_out="$(python3 - "$receipt_path" <<'PY'
import json, sys
try:
    path = sys.argv[1]
    with open(path, 'r') as f:
        data = json.load(f)
    if not isinstance(data, dict) or data.get('schema') != 'logicloom/adopt-receipt@1' or not isinstance(data.get('runs'), list):
        print('SCHEMA_MISMATCH')
    else:
        ok_statuses = ('complete', 'partial', 'in-progress')
        wrote = []
        seen = set()
        gen_version = ''
        for run in data['runs']:
            if not isinstance(run, dict) or run.get('status') not in ok_statuses:
                continue
            gen = run.get('generator')
            if isinstance(gen, str) and '@' in gen:
                gen_version = gen.rsplit('@', 1)[-1]
            for w in (run.get('wrote') or []):
                if not isinstance(w, dict):
                    continue
                p = str(w.get('path') or '')
                k = str(w.get('kind') or '')
                if not p or not k:
                    continue
                key = k + '\t' + p
                if key in seen:
                    continue
                seen.add(key)
                wrote.append(key)
        print('OK')
        print(gen_version)
        for line in wrote:
            print(line)
except Exception:
    print('PARSE_ERROR')
sys.exit(0)
PY
)"
            first_line="$(printf '%s\n' "$py_out" | head -1)"
            if [ "$first_line" = "OK" ]; then
                ADOPT_MODE="ADOPTED"
                ADOPT_DETECTED_BY="receipt"
                ADOPT_RECEIPT_USABLE="true"
                ADOPT_GENERATOR_VERSION="$(printf '%s\n' "$py_out" | sed -n '2p')"
                ADOPT_WROTE="$(printf '%s\n' "$py_out" | tail -n +3)"
            fi
            # SCHEMA_MISMATCH / PARSE_ERROR falls through to the fallback tell below.
        else
            ADOPT_PY_MISSING="true"
        fi
    fi

    if [ "$ADOPT_MODE" != "ADOPTED" ] && [ -f "$agents_marker" ]; then
        ADOPT_MODE="ADOPTED"
        ADOPT_DETECTED_BY="fallback"
    fi
}

# Was $1 (a file path) recorded as a `kind:'file'` write?
adopt_file_recorded() {
    local target="$1"
    [ -z "$ADOPT_WROTE" ] && return 1
    local kind path
    while IFS=$'\t' read -r kind path; do
        [ -z "$kind" ] && continue
        [ "$kind" = "file" ] && [ "$path" = "$target" ] && return 0
    done <<< "$ADOPT_WROTE"
    return 1
}

# Was $1 (a directory path, trailing slash optional) recorded as a `kind:'dir'`
# write? Compared trailing-slash-insensitively per the receipt's own convention.
adopt_dir_recorded() {
    local target="${1%/}"
    [ -z "$ADOPT_WROTE" ] && return 1
    local kind path pstripped
    while IFS=$'\t' read -r kind path; do
        [ -z "$kind" ] && continue
        if [ "$kind" = "dir" ]; then
            pstripped="${path%/}"
            [ "$pstripped" = "$target" ] && return 0
        fi
    done <<< "$ADOPT_WROTE"
    return 1
}

# Was $1 recorded as a `kind:'merge'` write? When the receipt is unusable (no
# receipt, unparsable, python3 absent, fallback-only detection) fall back to the
# two merge targets that are ALWAYS merge channels per the payload manifest
# (payload-manifest.txt: `.gitignore`, `.claude/settings.json`). CLAUDE.md is
# only a merge target under --claude-md=import, so it is NOT guessed here —
# without receipt data we cannot know that mode was used.
adopt_merge_recorded() {
    local target="$1"
    if [ "$ADOPT_RECEIPT_USABLE" = "true" ]; then
        local kind path
        while IFS=$'\t' read -r kind path; do
            [ -z "$kind" ] && continue
            [ "$kind" = "merge" ] && [ "$path" = "$target" ] && return 0
        done <<< "$ADOPT_WROTE"
        return 1
    fi
    case "$target" in
        .gitignore|.claude/settings.json) return 0 ;;
        *) return 1 ;;
    esac
}

# Conservative DENY-LIST used ONLY when ADOPTED but the receipt is unusable
# (fallback-tell detection, unparsable receipt, or python3 absent). With no
# ownership data (`wrote` is empty), the whitelist rule ("owns nothing until
# proven otherwise") suppresses EVERY proposal — a worse, invisible failure
# mode. Here we invert the posture: suppress only paths that are known-
# dangerous or known-not-adopter-owned, and offer everything else. $1 is the
# (possibly re-addressed) path being evaluated.
# Returns 0 = SUPPRESS (deny-listed), 1 = do not suppress on this basis.
adopt_denylist_suppressed() {
    local path="$1"
    case "$path" in
        CLAUDE.md|AGENTS.md|README.md|package.json) return 0 ;;
        .github/*) return 0 ;;
        tests/*) return 0 ;;
        TEMPLATE_INIT.md) return 0 ;;
    esac
    return 1
}

# Ancestor directories of $1, deepest first, excluding "." and "/".
adopt_ancestors() {
    local p="$1" dir
    dir="$(dirname "$p")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
        echo "$dir"
        dir="$(dirname "$dir")"
    done
}

# ADDED-file rule (Task 3(d)): OFFER only when some ancestor dir is recorded in
# `wrote`, AND no ancestor that existed upstream at sync_ref is missing from
# `wrote` (a payload exclusion, e.g. `.logic-loom/tests`, `.docs/design`).
# Returns 0 = OFFER, 1 = SUPPRESS.
adopt_offer_added_path() {
    local file_path="$1" sync_ref="$2"
    local dir any_recorded="false"
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        if git -C "$REPO_ROOT" cat-file -e "${sync_ref}:${dir}" 2>/dev/null; then
            if ! adopt_dir_recorded "$dir"; then
                return 1
            fi
        fi
        if adopt_dir_recorded "$dir"; then
            any_recorded="true"
        fi
    done <<< "$(adopt_ancestors "$file_path")"
    [ "$any_recorded" = "true" ] && return 0
    return 1
}

extract_proposals() {
    local sync_ref="$1"
    local upstream_ref="${2:-$LOOM_UPSTREAM_REF}"
    detect_adopt_mode
    local changes
    changes=$(git -C "$REPO_ROOT" diff --name-status "$sync_ref..$upstream_ref" 2>/dev/null || echo "")
    if [ -z "$changes" ]; then echo "[]"; return; fi

    local proposals="[" first=true id=1
    local suppressed_merge=0 suppressed_unowned=0 suppressed_excluded=0
    while IFS=$'\t' read -r status file_path new_path; do
        [ -z "$status" ] && continue
        [ -z "$file_path" ] && continue
        # git diff --name-status emits a THIRD tab-separated field for renames/
        # copies (`R100<TAB>old<TAB>new`, `C100<TAB>old<TAB>new`). Without reading
        # it, a 2-field `read` folds "old<TAB>new" into file_path as garbage. Use
        # the NEW path — that is the path that actually exists to propose.
        case "$status" in
            R*|C*)
                [ -n "$new_path" ] && file_path="$new_path"
                ;;
        esac
        # The sync-ref marker is upstream bookkeeping, not an adoptable change.
        [ "$file_path" = ".sdd-sync-ref" ] && continue

        local change_type="${status:0:1}"

        # Re-address the one manifest `rename:` row (AGENTS.md :: .logic-loom/AGENTS.md).
        # When ADOPTED, upstream AGENTS.md installs at .logic-loom/AGENTS.md — the
        # adopter's OWN root AGENTS.md is an unrelated file that merely shares a
        # name, and must never be diffed against upstream's AGENTS.md content.
        local compare_path="$file_path" is_readdressed="false"
        if [ "$ADOPT_MODE" = "ADOPTED" ] && [ "$file_path" = "AGENTS.md" ]; then
            compare_path=".logic-loom/AGENTS.md"
            is_readdressed="true"
        fi

        local category description ptype
        category=$(categorize_change "$file_path")
        description=$(describe_change "$compare_path" "$change_type" "$category")
        ptype=$(proposal_type "$change_type")

        local downstream_exists="false"
        [ -f "$REPO_ROOT/$compare_path" ] && downstream_exists="true"

        # 3-WAY CONFLICT AWARENESS — baseline (sync_ref blob) vs downstream (the
        # user's working file) vs upstream (the new version). Flags whether the
        # USER customized THIS upstream-changed file, so adoption never silently
        # overwrites their work. Stays upstream-history-scoped: only files upstream
        # changed are examined — this is NOT a global downstream..upstream diff.
        #   resolution:
        #     clean-apply   M/R: downstream == baseline (not customized) -> safe to update
        #     clean-add     file absent downstream -> safe to add upstream's version
        #     conflict-review  user customized this file AND upstream changed it -> review, never overwrite
        #     already-present  downstream already identical to upstream's version -> no-op
        #     info-*        upstream deleted / already absent -> informational
        local downstream_modified="false" conflict="false" resolution="review"
        if [ "$downstream_exists" = "true" ]; then
            case "$change_type" in
                M|R*)
                    if [ "$is_readdressed" = "true" ]; then
                        # Cross-path compare: the readdressed rename means upstream's
                        # content lives at $file_path (root AGENTS.md) in the
                        # sync-ref tree, while downstream it lives at $compare_path
                        # (.logic-loom/AGENTS.md) — `git diff <ref> -- <path>`
                        # cannot compare two different paths, so compare blob hashes
                        # directly instead.
                        local sync_blob downstream_blob
                        sync_blob="$(git -C "$REPO_ROOT" rev-parse "${sync_ref}:${file_path}" 2>/dev/null || true)"
                        downstream_blob="$(git -C "$REPO_ROOT" hash-object "$REPO_ROOT/$compare_path" 2>/dev/null || true)"
                        if [ -n "$sync_blob" ] && [ "$sync_blob" = "$downstream_blob" ]; then
                            resolution="clean-apply"
                        else
                            downstream_modified="true"; conflict="true"; resolution="conflict-review"
                        fi
                    elif git -C "$REPO_ROOT" cat-file -e "$sync_ref:$file_path" 2>/dev/null \
                       && git -C "$REPO_ROOT" diff --quiet "$sync_ref" -- "$file_path" 2>/dev/null; then
                        resolution="clean-apply"
                    else
                        downstream_modified="true"; conflict="true"; resolution="conflict-review"
                    fi ;;
                A)
                    if git -C "$REPO_ROOT" diff --quiet "$upstream_ref" -- "$file_path" 2>/dev/null; then
                        resolution="already-present"
                    else
                        downstream_modified="true"; conflict="true"; resolution="conflict-review"
                    fi ;;
                D) resolution="info-upstream-deleted" ;;
            esac
        else
            case "$change_type" in
                A|M) resolution="clean-add" ;;
                D)   resolution="info-already-absent" ;;
            esac
        fi

        local release_tag
        release_tag=$(find_tag_for_file "$file_path" "$sync_ref" "$upstream_ref")

        local breaking="false"
        if [ "$change_type" = "R" ] || echo "$status" | grep -q "R[0-9]"; then
            ptype="structural-change"; breaking="true"
        fi

        # ── Adopted-repo filtering (Task 3). TEMPLATE mode: no-op, unchanged. ──
        # Applied in order: (a) merge channels are never proposed as ordinary
        # changes — re-address them to an info-* proposal pointing at the re-run
        # channel; (c) M/D (and R, by the same ownership question) propose only
        # if the (readdressed) path was actually written by the installer;
        # (d) A (new upstream files) propose only per the ancestor-directory rule.
        if [ "$ADOPT_MODE" = "ADOPTED" ]; then
            if adopt_merge_recorded "$compare_path"; then
                suppressed_merge=$((suppressed_merge + 1))
                local version_hint="${ADOPT_GENERATOR_VERSION:-<version>}"
                description="Upstream changed ${compare_path}, which this repo installed as a MERGE (appended additively, fenced) — never overwritten. Re-run: npx logicloom@${version_hint} init --apply --only=hooks,gitignore to pick up the update additively."
                resolution="info-adopted-merge-channel"
                ptype="info"
                downstream_modified="false"; conflict="false"; breaking="false"
            elif [ "$ADOPT_RECEIPT_USABLE" = "true" ]; then
                case "$change_type" in
                    M|D|R*)
                        if ! adopt_file_recorded "$compare_path"; then
                            suppressed_unowned=$((suppressed_unowned + 1))
                            id=$((id + 1))
                            continue
                        fi
                        ;;
                    A)
                        if ! adopt_offer_added_path "$file_path" "$sync_ref"; then
                            suppressed_excluded=$((suppressed_excluded + 1))
                            id=$((id + 1))
                            continue
                        fi
                        ;;
                esac
            else
                # RECEIPT UNUSABLE (fallback-tell detection, unparsable receipt,
                # or python3 absent): there is no ownership data to whitelist
                # against, so switch from whitelist to a conservative deny-list
                # (adopt_denylist_suppressed) — suppress only known-dangerous/
                # known-not-ours paths and OFFER everything else, rather than
                # suppressing everything for lack of proof.
                case "$change_type" in
                    M|D|R*)
                        if adopt_denylist_suppressed "$compare_path"; then
                            suppressed_unowned=$((suppressed_unowned + 1))
                            id=$((id + 1))
                            continue
                        fi
                        ;;
                    A)
                        if adopt_denylist_suppressed "$file_path"; then
                            suppressed_excluded=$((suppressed_excluded + 1))
                            id=$((id + 1))
                            continue
                        fi
                        ;;
                esac
            fi
        fi

        if [ "$first" = true ]; then first=false; else proposals="${proposals},"; fi
        local padded_id; padded_id=$(printf "EP-%03d" "$id")
        local tag_json="null"; [ -n "$release_tag" ] && tag_json="\"$release_tag\""

        proposals="${proposals}
    {
      \"id\": \"$padded_id\",
      \"type\": \"$ptype\",
      \"category\": \"$category\",
      \"description\": \"$description\",
      \"upstream_file\": \"$compare_path\",
      \"downstream_exists\": $downstream_exists,
      \"downstream_modified\": $downstream_modified,
      \"conflict\": $conflict,
      \"resolution\": \"$resolution\",
      \"change_type\": \"$change_type\",
      \"release_tag\": $tag_json,
      \"status\": \"pending\",
      \"breaking\": $breaking
    }"
        id=$((id + 1))
    done <<< "$changes"

    proposals="${proposals}
  ]"

    # (e) Say what was hidden — never let silence be mistaken for "upstream
    # changed nothing." Reported to stderr only, so stdout stays a pure JSON array.
    if [ "$ADOPT_MODE" = "ADOPTED" ]; then
        local detected_note="$ADOPT_DETECTED_BY"
        if [ "$ADOPT_DETECTED_BY" = "fallback" ]; then
            detected_note="fallback (.logic-loom/AGENTS.md present; no usable .logicloom-adopt-receipt.json)"
        elif [ "$ADOPT_PY_MISSING" = "true" ]; then
            detected_note="receipt file present but python3 is unavailable to parse it — treated as no usable receipt"
        fi
        echo "ADOPTED REPO (detected by: $detected_note) — adopted-repo proposal filtering active." >&2
        if [ "$ADOPT_RECEIPT_USABLE" = "true" ]; then
            echo "Suppressed: $suppressed_merge merge-channel (see info-adopted-merge-channel proposals), $suppressed_unowned not-installed-here (M/D/R), $suppressed_excluded payload-excluded (A)." >&2
        else
            echo "DEGRADED FILTERING: .logicloom-adopt-receipt.json is MISSING or UNREADABLE, so precise ownership-based filtering is unavailable this run. Filtering has fallen back to a CONSERVATIVE DENY-LIST — only known-dangerous/known-not-ours paths (root CLAUDE.md, AGENTS.md, README.md, package.json; anything under .github/ or tests/; TEMPLATE_INIT.md; merge channels) are suppressed, and every other upstream change is being OFFERED even though this repo's actual ownership is unverified. This is NOT the same as 'upstream changed nothing.' Restore .logicloom-adopt-receipt.json (or commit it to this repo) to get precise, ownership-based filtering back." >&2
            echo "Suppressed: $suppressed_merge merge-channel (see info-adopted-merge-channel proposals), $suppressed_unowned deny-listed (M/D/R), $suppressed_excluded deny-listed (A)." >&2
        fi
    fi

    echo "$proposals"
}

# Resolve URL or fail closed with guidance (the skill/command then prompts).
require_url() {
    local url
    if ! url="$(resolve_upstream_url)"; then
        echo "Error: upstream URL not configured." >&2
        echo "Set it once in .logic-loom/config/framework-upstream.conf (LOOM_UPSTREAM_REPO=<owner>/<repo>)" >&2
        echo "or per-run:  export LOOM_UPSTREAM_URL=https://github.com/<owner>/<repo>.git" >&2
        echo "(It must be the PUBLIC template repo — NOT your own origin.)" >&2
        exit 2
    fi
    printf '%s' "$url"
}

# ============================================
# Main (guarded so the script can be sourced for testing without fetching)
# ============================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --dry-run)
        URL="$(require_url)"
        echo "Upstream (fetch-only, no remote): $URL"
        fetch_upstream "$URL" >&2 || { echo "Fetch failed — check the URL / network." >&2; exit 4; }
        SYNC_REF="$(read_sync_ref)"
        if [ -z "$SYNC_REF" ]; then
            echo "No .sdd-sync-ref yet — first run will baseline at upstream HEAD."
        else
            echo "Current sync-ref: $SYNC_REF"
            if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$SYNC_REF" "$LOOM_UPSTREAM_REF" 2>/dev/null; then
                echo "Status: SYNC-REF UNREACHABLE (broken baseline — see FRAMEWORK_SYNC_GUIDE.md)"
            else
                UP_HEAD=$(git -C "$REPO_ROOT" rev-parse "$LOOM_UPSTREAM_REF" 2>/dev/null || echo unknown)
                if [ "$SYNC_REF" = "$UP_HEAD" ]; then
                    echo "Status: UP TO DATE"
                else
                    # `grep -vc` prints "0" and exits 1 when nothing survives the
                    # inversion, so `|| echo 0` appended a second line ("0\n0").
                    # See .docs/policies/shell-idiom-policy.md §1.
                    CHANGE_COUNT=$(git -C "$REPO_ROOT" diff --name-only "$SYNC_REF..$LOOM_UPSTREAM_REF" 2>/dev/null | grep -vc '^\.sdd-sync-ref$' || true); CHANGE_COUNT=${CHANGE_COUNT:-0}
                    echo "Status: $CHANGE_COUNT files changed upstream since last sync"
                    TAGS_IN_RANGE=$(list_tags_in_range "$SYNC_REF" "$LOOM_UPSTREAM_REF")
                    if [ -n "$TAGS_IN_RANGE" ]; then
                        echo "Releases in range:"
                        echo "$TAGS_IN_RANGE" | while read -r tag commit; do
                            TAG_DATE=$(git -C "$REPO_ROOT" log -1 --format='%ci' "$commit" 2>/dev/null | cut -d' ' -f1)
                            echo "  $tag ($TAG_DATE)"
                        done
                    fi
                fi
            fi
        fi
        # Prune the scratch ref (re-fetched next run).
        git -C "$REPO_ROOT" update-ref -d "$LOOM_UPSTREAM_REF" 2>/dev/null || true
        ;;
    *)
        URL="$(require_url)"
        fetch_upstream "$URL" >&2 || { echo "Error: upstream fetch failed (URL/network)." >&2; exit 4; }
        SYNC_REF="$(ensure_sync_ref)"   # may exit 0 ([]) on bootstrap, or 3 on unreachable
        extract_proposals "$SYNC_REF" "$LOOM_UPSTREAM_REF"
        ;;
esac
fi
