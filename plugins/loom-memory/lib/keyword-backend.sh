#!/usr/bin/env bash
# Keyword Backend (v1.0 compatible)
# Plugin: loom-memory v2.0.0
# Wraps the existing grep-based keyword search as a pluggable backend.
#
# This is the default backend that preserves all v1.0 behavior.
# It implements the backend interface defined in backend-interface.sh.

set -euo pipefail

KEYWORD_BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYWORD_PLUGIN_DIR="$(cd "$KEYWORD_BACKEND_DIR/.." && pwd)"
KEYWORD_REPO_ROOT="$(cd "$KEYWORD_PLUGIN_DIR/../.." && pwd)"

# Source the backend interface
source "$KEYWORD_BACKEND_DIR/backend-interface.sh"

# ============================================
# Configuration (from memory.conf or memory-v2.conf)
# ============================================

STOP_WORDS="${STOP_WORDS:-the a an is are was were be been being have has had do does did will would shall should may might can could of in to for on with at by from as into through during before after above below between out off over under}"

# ============================================
# Internal Functions
# ============================================

# Extract keywords from a query (remove stop words, short words)
_keyword_extract() {
    local message="$1"
    local words
    words=$(echo "$message" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | sort -u)

    local keywords=""
    for word in $words; do
        [ ${#word} -lt 3 ] && continue
        if ! echo " $STOP_WORDS " | grep -qi " $word "; then
            keywords="${keywords:+$keywords }$word"
        fi
    done
    echo "$keywords"
}

# Search a single directory for keyword matches
_keyword_search_dir() {
    local search_path="$1"
    local keyword="$2"
    local max_per_keyword="${3:-3}"

    [ -e "$search_path" ] || return 0

    # Exclude generated/noise trees so the live grep stays fast and does not
    # match its own audit/search-log output (which otherwise grows unbounded and
    # feeds back into every search). These are never legitimate memory content.
    #
    # Rank candidates by the number of MATCHING LINES, not by directory-traversal
    # order. `grep -r` does not define a traversal order: BSD grep (macOS) walks
    # sorted, GNU grep (Linux/CI) walks readdir order. Taking the first N files
    # therefore made recall — and so whether any hit cleared
    # MEMORY_CONFIDENCE_THRESHOLD — depend on the host filesystem and on which
    # untracked files happened to be present.
    #
    # Two phases, because this runs inside a per-prompt UserPromptSubmit hook:
    #   Phase 1 — cheap discovery with `grep -rIl`, which EARLY-EXITS on a file's
    #     first match, and skips binary files (`-I`). A recursive `grep -c` would
    #     instead read every file end to end, and the >50KB skip used to sit in
    #     the loop BELOW the recursive grep, so it no longer protected the
    #     expensive step at all.
    #   Phase 2 — size-filter the candidate set FIRST, then count matching lines
    #     over the survivors only. The survivor set is small, so counting is
    #     bounded and no oversized file is ever read end to end.
    #
    # NOTE: the candidate list is newline-delimited, so a filename containing a
    # literal newline is not handled. Deliberately out of scope for this corpus.
    local candidate_files=()
    local candidate
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        candidate_files+=("$candidate")
    done < <(grep -rIil \
        --exclude-dir=audit --exclude-dir=.git --exclude-dir=node_modules \
        --exclude='search-log.jsonl' --exclude='*.log' \
        "$keyword" "$search_path" 2>/dev/null || true)
    [ "${#candidate_files[@]}" -gt 0 ] || return 0

    # Phase 2. `find` applies the size filter to the candidate list and
    # `-exec ... +` hands only the survivors to `grep -c`, so an oversized file
    # is never counted and the size filter + counting together cost one fork.
    # (A `wc -c` per candidate would cost more than the counting it protects.)
    # `-size -50001c` keeps files of at most 50000 bytes — exactly the previous
    # `-gt 50000` skip; `-L` follows symlinks so the size measured is the size
    # grep would read.
    #
    # The ranking line emits the sort key FIRST, as "count<TAB>path". Sorting a
    # `path:count` line with `sort -t: -k2,2rn` mis-ranked any path containing a
    # colon (legal in a Unix filename) because the count was then no longer
    # field 2. With the
    # count leading, colons anywhere in the path are harmless. LC_ALL=C makes the
    # tie-break collation identical on macOS and ubuntu — the cross-platform
    # nondeterminism this ranking exists to eliminate.
    local tab=$'\t'
    local counted="" count_line count_val counted_lines=0
    while IFS= read -r count_line; do
        [ -n "$count_line" ] || continue
        # `grep -Hc` emits "path:count"; ${x##*:} / ${x%:*} split on the LAST
        # colon, so colons inside the path are safe here.
        count_val="${count_line##*:}"
        # Drop zero-count lines here with a builtin test rather than piping the
        # whole set through `grep -v` — this function runs once per
        # (search path x keyword) pair, so every avoided fork matters.
        [ "$count_val" = "0" ] && continue
        counted="${counted}${count_val}${tab}${count_line%:*}
"
        counted_lines=$((counted_lines + 1))
    done < <(find -L "${candidate_files[@]}" -maxdepth 0 -type f -size -50001c \
        -exec grep -Hci -- "$keyword" {} + 2>/dev/null || true)
    [ "$counted_lines" -gt 0 ] || return 0

    local ranked
    if [ "$counted_lines" -eq 1 ]; then
        # Nothing to order — skip the sort fork entirely.
        ranked="${counted%$'\n'}"
    else
        ranked=$(LC_ALL=C sort -k1,1rn <<EOF
${counted%$'\n'}
EOF
) || true
    fi
    [ -n "$ranked" ] || return 0

    local selected=0
    local match_file match_count
    while IFS="$tab" read -r match_count match_file; do
        [ -n "$match_file" ] || continue
        [ "$selected" -ge "$max_per_keyword" ] && break
        [ -f "$match_file" ] || continue

        # Get line number of first match. `grep -m 1` already emits at most one
        # line, and `${x%%:*}` is a builtin split — this loop body runs for every
        # emitted result, so the dropped `| head -1` and `| cut` forks are the
        # dominant per-prompt cost, well above the grep itself.
        local line_info
        line_info=$(grep -n -m 1 -i "$keyword" "$match_file" 2>/dev/null) || continue
        local line_num="${line_info%%:*}"
        [ -z "$line_num" ] && continue

        # Get surrounding context (2 lines before and after)
        local start=$((line_num > 2 ? line_num - 2 : 1))
        local end=$((line_num + 2))
        local context
        context=$(sed -n "${start},${end}p" "$match_file" 2>/dev/null) || continue

        # Score from the count grep already returned. NOTE: `grep -c` counts
        # MATCHING LINES, not occurrences — a line with three hits counts once.
        # (That was equally true of the pre-ranking implementation, so the
        # scoring semantics are unchanged; only the wording here is corrected so
        # the 0.7 threshold is not misread as "seven occurrences".)
        # (Do NOT re-derive the count with `grep -c ... || echo 0`: grep -c
        # PRINTS 0 and EXITS 1 on no match, so the `|| echo 0` appends a second
        # line and yields the two-line string "0\n0", which crashes
        # `[ ... -ge ... ]` with "integer expression expected".) Sanitize to a
        # single integer defensively.
        case "$match_count" in
            *[!0-9]*|'') match_count=$(printf '%s' "$match_count" | tr -dc '0-9') ;;
        esac
        [ -n "$match_count" ] || match_count=0

        # Normalize score (simple: matching lines / 10, capped at 1.0)
        local score
        if [ "$match_count" -ge 10 ]; then
            score="1.0"
        else
            # Use awk for float division
            score=$(awk "BEGIN {printf \"%.2f\", $match_count / 10}")
        fi

        local rel_path="${match_file#$KEYWORD_REPO_ROOT/}"
        format_search_result "$score" "$rel_path" "$line_num" "$context"
        selected=$((selected + 1))
    done <<EOF
$ranked
EOF
}

# ============================================
# Backend Interface Implementation
# ============================================

backend_search() {
    local query="${1:-}"
    local max_results="${2:-10}"
    local timeout_ms="${3:-3000}"
    local scope="${4:-session}"

    if [ -z "$query" ]; then
        return 0
    fi

    local keywords
    keywords=$(_keyword_extract "$query")

    # Cap keyword count to bound the per-message grep fan-out (search cost is
    # paths * keywords). The most salient terms come first after extraction;
    # 6 keeps recall high while keeping UserPromptSubmit latency in check.
    keywords=$(echo "$keywords" | tr ' ' '\n' | grep -v '^$' | head -n "${KEYWORD_MAX_TERMS:-6}" | tr '\n' ' ')
    keywords="${keywords% }"

    if [ -z "$keywords" ]; then
        return 0
    fi

    # Determine search paths based on scope
    local current_branch
    current_branch=$(git -C "$KEYWORD_REPO_ROOT" branch --show-current 2>/dev/null || echo "main")

    local search_paths=()

    if [ "$scope" = "session" ]; then
        # Session scope: working + recall tiers only
        [ -d "$KEYWORD_REPO_ROOT/specs" ] && search_paths+=("$KEYWORD_REPO_ROOT/specs")
        [ -d "$KEYWORD_REPO_ROOT/.docs" ] && search_paths+=("$KEYWORD_REPO_ROOT/.docs")
    else
        # Global scope: all tiers
        [ -d "$KEYWORD_REPO_ROOT/specs" ] && search_paths+=("$KEYWORD_REPO_ROOT/specs")
        [ -d "$KEYWORD_REPO_ROOT/.docs" ] && search_paths+=("$KEYWORD_REPO_ROOT/.docs")
        [ -d "$KEYWORD_REPO_ROOT/.logic-loom/memory" ] && search_paths+=("$KEYWORD_REPO_ROOT/.logic-loom/memory")
        [ -d "$KEYWORD_REPO_ROOT/plugins" ] && search_paths+=("$KEYWORD_REPO_ROOT/plugins")
    fi

    # features/ recall tier — scoped to SUMMARY files only (retro.md,
    # plan-review.md, prd.md, sprints/**/result.md) so raw exploration/ dumps
    # don't add noise. /retro and the swarm pack write these; neither path was
    # searched before. Searched in every scope.
    if [ -d "$KEYWORD_REPO_ROOT/features" ]; then
        local feature_summary
        while IFS= read -r feature_summary; do
            [ -n "$feature_summary" ] && search_paths+=("$feature_summary")
        done < <(find "$KEYWORD_REPO_ROOT/features" -type f \
            \( -name 'retro.md' -o -name 'plan-review.md' -o -name 'prd.md' \
               -o \( -path '*/sprints/*' -name 'result.md' \) \) 2>/dev/null)
    fi

    # Durable memory tier — where /retro writes lessons. RESOLVED, not assumed:
    # the destination is a project setting (memory-backend.conf), and retrieval
    # has to follow the write target or the learning loop reads an empty store.
    # Falls back to the historical `project` path when the resolver is absent,
    # so a partial tree still searches what /retro used to write.
    local durable_memory resolver
    resolver="$KEYWORD_REPO_ROOT/.logic-loom/scripts/bash/resolve-memory-backend.sh"
    if [ -f "$resolver" ]; then
        durable_memory=$(bash "$resolver" --path 2>/dev/null || true)
    fi
    if [ -z "${durable_memory:-}" ]; then
        durable_memory="$HOME/.claude/projects/$(printf '%s' "$KEYWORD_REPO_ROOT" | sed 's|/|-|g')/memory"
    fi
    [ -d "$durable_memory" ] && search_paths+=("$durable_memory")

    # Search across all paths for all keywords, collect results
    local all_results=""
    for search_path in "${search_paths[@]}"; do
        for keyword in $keywords; do
            local results
            results=$(_keyword_search_dir "$search_path" "$keyword" 3)
            if [ -n "$results" ]; then
                all_results="${all_results}${results}
"
            fi
        done
    done

    # Sort by score descending, deduplicate by file, limit to max_results
    if [ -n "$all_results" ]; then
        echo "$all_results" | grep -v '^$' | sort -t$'\t' -k1 -rn | \
            awk -F'\t' '!seen[$2]++' | head -n "$max_results"
    fi

    return 0
}

backend_index() {
    # Keyword backend doesn't maintain an index — grep searches live
    return 0
}

backend_reindex_all() {
    # No index to rebuild for keyword search
    return 0
}

backend_health_check() {
    # Keyword backend is always healthy (just grep)
    echo "keyword backend: healthy (grep-based, no index required)"
    return 0
}
