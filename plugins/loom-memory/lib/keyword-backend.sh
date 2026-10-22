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

# Collect raw hit counts for ONE (search_path, keyword) pair. This is phase
# 1+2 of the old _keyword_search_dir, with the context-fetch/scoring/select
# logic pulled OUT — scoring now needs every keyword's hits for a file
# aggregated together (see _keyword_aggregate_and_format), not one keyword in
# isolation.
#
# Output: KEYWORD<TAB>COUNT<TAB>FILE lines, one per matching file. No sort, no
# cap — the caller aggregates across every (path, keyword) pair first.
_keyword_count_hits() {
    local search_path="$1"
    local keyword="$2"

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
    # Emit KEYWORD<TAB>COUNT<TAB>FILE. NOTE: `grep -c` counts MATCHING LINES,
    # not occurrences — a line with three hits counts once. No sort here: this
    # function no longer decides relevance on its own, so there is nothing to
    # rank yet. `grep -Hc` emits "path:count"; `${x##*:}` / `${x%:*}` split on
    # the LAST colon, so colons inside the path are safe.
    local count_line count_val
    while IFS= read -r count_line; do
        [ -n "$count_line" ] || continue
        count_val="${count_line##*:}"
        case "$count_val" in
            *[!0-9]*|'') continue ;;
        esac
        # Drop zero-count lines with a builtin test rather than piping the
        # whole set through `grep -v` — this function runs once per (search
        # path x keyword) pair, so every avoided fork matters.
        [ "$count_val" = "0" ] && continue
        printf '%s\t%s\t%s\n' "$keyword" "$count_val" "${count_line%:*}"
    done < <(find -L "${candidate_files[@]}" -maxdepth 0 -type f -size -50001c \
        -exec grep -Hci -- "$keyword" {} + 2>/dev/null || true)
}

# Aggregate raw KEYWORD<TAB>COUNT<TAB>FILE hit lines (collected across every
# (search_path, keyword) pair a query touched) into scored SearchResult lines.
#
# THE FIX: relevance is QUERY COVERAGE, not single-keyword line frequency.
#   coverage = distinct query keywords the file matched / total query keywords
#   bonus    = small, density-derived nudge, capped at 0.05 total
#   sortkey  = min(1.0, coverage + bonus) — used ONLY to ORDER results below
#
# The EMITTED score (what format_search_result reports, and so the only value
# MEMORY_CONFIDENCE_THRESHOLD ever sees) is coverage ALONE, never sortkey.
# A bonus smaller than one coverage step can still bridge a threshold that
# falls INSIDE that step (e.g. 4/6=0.667 + 0.05=0.717 crosses 0.7, even though
# 0.05 is well under the 1/6 step size) — so density must be barred from the
# emitted score structurally, for ANY threshold the caller configures, rather
# than relying on the bonus cap alone to stay under one specific number.
#
# One awk pass does the aggregation (dedupe (file,keyword) pairs — the same
# pair can arrive twice if a file lives under two search paths — then group by
# file). Context (line number + snippet) is fetched with ONE grep PER
# SELECTED FILE, not per (file, keyword) pair, so this is cheaper than the
# pre-fix code even though it now looks across all keywords: the pre-fix
# _keyword_search_dir fetched context for up to `max_per_keyword` files PER
# keyword PER path; this fetches it only for the top `max_results` files
# overall.
#
# Args: $1=raw hit lines (KEYWORD<TAB>COUNT<TAB>FILE), $2=total_keywords
#       (the query's keyword count — NOT a per-file count), $3=max_results
_keyword_aggregate_and_format() {
    local raw_hits="$1"
    local total_keywords="$2"
    local max_results="$3"

    [ -n "$raw_hits" ] || return 0
    [ "$total_keywords" -gt 0 ] || return 0

    local tab=$'\t'
    local scored
    scored=$(printf '%s' "$raw_hits" | LC_ALL=C awk -F'\t' -v total="$total_keywords" '
        {
            kw = $1; cnt = $2 + 0; file = $3
            if (file == "") next
            pairkey = file SUBSEP kw
            if (pairkey in seen) next
            seen[pairkey] = 1
            matched[file]++
            capped = (cnt > 10) ? 10 : cnt
            density[file] += capped
            # Remember the highest-count matched keyword per file — used
            # below to fetch one representative line of context.
            if (!(file in best_count) || cnt > best_count[file]) {
                best_count[file] = cnt
                best_kw[file] = kw
            }
        }
        END {
            for (f in matched) {
                coverage = matched[f] / total
                if (coverage > 1.0) coverage = 1.0
                bonus = density[f] / (total * 100)
                if (bonus > 0.05) bonus = 0.05
                sortkey = coverage + bonus
                if (sortkey > 1.0) sortkey = 1.0
                printf "%.4f\t%.4f\t%s\t%s\n", sortkey, coverage, f, best_kw[f]
            }
        }
    ' | LC_ALL=C sort -t"$tab" -k1,1rn) || true
    [ -n "$scored" ] || return 0

    local selected=0
    local sortkey coverage match_file best_kw
    while IFS="$tab" read -r sortkey coverage match_file best_kw; do
        [ -n "$match_file" ] || continue
        [ "$selected" -ge "$max_results" ] && break
        [ -f "$match_file" ] || continue

        # Get line number of the best-matched keyword's first occurrence.
        local line_info
        line_info=$(grep -n -m 1 -i "$best_kw" "$match_file" 2>/dev/null) || continue
        local line_num="${line_info%%:*}"
        [ -z "$line_num" ] && continue

        # Get surrounding context (2 lines before and after)
        local start=$((line_num > 2 ? line_num - 2 : 1))
        local end=$((line_num + 2))
        local context
        context=$(sed -n "${start},${end}p" "$match_file" 2>/dev/null) || continue

        local rel_path="${match_file#$KEYWORD_REPO_ROOT/}"
        format_search_result "$coverage" "$rel_path" "$line_num" "$context"
        selected=$((selected + 1))
    done <<EOF
$scored
EOF
}

# Core multi-path, multi-keyword search: collect raw hits across every
# (search_path, keyword) pair, then score by query coverage (see
# _keyword_aggregate_and_format). Split out from backend_search so it is
# testable against fixture directories, independent of backend_search's
# hardcoded repo-relative search-path selection.
#
# Args: $1=search paths, one per line (newline-separated — paths never
#         contain newlines in this corpus)
#       $2=keywords, space-separated (post-extraction, post-cap)
#       $3=max_results
_keyword_search() {
    local search_paths_str="$1"
    local keywords="$2"
    local max_results="$3"

    [ -n "$keywords" ] || return 0

    local total_keywords
    total_keywords=$(echo "$keywords" | wc -w | tr -d ' ')
    [ "$total_keywords" -gt 0 ] || return 0

    local search_path all_hits=""
    while IFS= read -r search_path; do
        [ -n "$search_path" ] || continue
        local keyword hits
        for keyword in $keywords; do
            hits=$(_keyword_count_hits "$search_path" "$keyword")
            if [ -n "$hits" ]; then
                all_hits="${all_hits}${hits}
"
            fi
        done
    done <<EOF
$search_paths_str
EOF

    _keyword_aggregate_and_format "$all_hits" "$total_keywords" "$max_results"
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

    # Distilled knowledge tier — .brain/wiki/ (concepts/ + decisions/), where
    # /distill promotes captures. FIXED in-repo path, NOT backend-dependent:
    # unlike durable memory below, this lives in-tree regardless of whether
    # memory_backend resolves to `repo` or `project`, so it is never derived
    # from the resolver. Searched in every scope — without this, LOOM-0063:
    # distillation writes to a shelf no query ever reads.
    [ -d "$KEYWORD_REPO_ROOT/.brain/wiki" ] && search_paths+=("$KEYWORD_REPO_ROOT/.brain/wiki")

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

    # Delegate to the testable core: search every path for every keyword,
    # aggregate hits per file across keywords, and score by query coverage.
    local search_paths_str
    search_paths_str=$(printf '%s\n' "${search_paths[@]}")
    _keyword_search "$search_paths_str" "$keywords" "$max_results"

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
