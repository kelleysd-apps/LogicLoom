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
        echo "ERROR: .sdd-sync-ref ($sync_ref) is NOT reachable from upstream main." >&2
        echo "An upstream release PR was likely squash/rebase-merged, breaking the single-parent chain." >&2
        echo "See .docs/guides/FRAMEWORK_SYNC_GUIDE.md -> 'Broken sync baseline'." >&2
        echo "Safe re-baseline (adopts nothing, resets the baseline):" >&2
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

extract_proposals() {
    local sync_ref="$1"
    local upstream_ref="${2:-$LOOM_UPSTREAM_REF}"
    local changes
    changes=$(git -C "$REPO_ROOT" diff --name-status "$sync_ref..$upstream_ref" 2>/dev/null || echo "")
    if [ -z "$changes" ]; then echo "[]"; return; fi

    local proposals="[" first=true id=1
    while IFS=$'\t' read -r status file_path; do
        [ -z "$status" ] && continue
        [ -z "$file_path" ] && continue
        # The sync-ref marker is upstream bookkeeping, not an adoptable change.
        [ "$file_path" = ".sdd-sync-ref" ] && continue

        local change_type="${status:0:1}"
        local category description ptype
        category=$(categorize_change "$file_path")
        description=$(describe_change "$file_path" "$change_type" "$category")
        ptype=$(proposal_type "$change_type")

        local downstream_exists="false"
        [ -f "$REPO_ROOT/$file_path" ] && downstream_exists="true"

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
                    if git -C "$REPO_ROOT" cat-file -e "$sync_ref:$file_path" 2>/dev/null \
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

        if [ "$first" = true ]; then first=false; else proposals="${proposals},"; fi
        local padded_id; padded_id=$(printf "EP-%03d" "$id")
        local tag_json="null"; [ -n "$release_tag" ] && tag_json="\"$release_tag\""

        proposals="${proposals}
    {
      \"id\": \"$padded_id\",
      \"type\": \"$ptype\",
      \"category\": \"$category\",
      \"description\": \"$description\",
      \"upstream_file\": \"$file_path\",
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
                    CHANGE_COUNT=$(git -C "$REPO_ROOT" diff --name-only "$SYNC_REF..$LOOM_UPSTREAM_REF" 2>/dev/null | grep -vc '^\.sdd-sync-ref$' || echo 0)
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
