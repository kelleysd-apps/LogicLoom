#!/usr/bin/env bash
# Hybrid Search Backend
# Plugin: sdd-memory v2.0.0
# Combines BM25 + vector search with configurable weights.
# Implements the backend interface defined in backend-interface.sh.
#
# When MEMORY_BACKEND=hybrid, this backend:
#   1. Runs BM25 search and vector search as subprocesses
#   2. Reweights scores: BM25 * KEYWORD_WEIGHT + vector * VECTOR_WEIGHT
#   3. Merges results, deduplicates by file, sorts by merged score
#   4. Falls back gracefully: vector unhealthy → BM25 only → keyword fallback

set -euo pipefail

HYBRID_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYBRID_PLUGIN_DIR="$(cd "$HYBRID_LIB_DIR/.." && pwd)"
HYBRID_REPO_ROOT="$(cd "$HYBRID_PLUGIN_DIR/../.." && pwd)"

# Source the backend interface
source "$HYBRID_LIB_DIR/backend-interface.sh"

# ============================================
# Configuration (from memory-v2.conf)
# ============================================

HYBRID_CONF="$HYBRID_PLUGIN_DIR/config/memory-v2.conf"

# Defaults
VECTOR_WEIGHT="${VECTOR_WEIGHT:-0.7}"
KEYWORD_WEIGHT="${KEYWORD_WEIGHT:-0.3}"
MAX_CANDIDATES="${MAX_CANDIDATES:-10}"

# Load config if available
if [ -f "$HYBRID_CONF" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"//' | sed 's/"$//')
        case "$key" in
            VECTOR_WEIGHT) VECTOR_WEIGHT="$value" ;;
            KEYWORD_WEIGHT) KEYWORD_WEIGHT="$value" ;;
            MAX_CANDIDATES) MAX_CANDIDATES="$value" ;;
        esac
    done < "$HYBRID_CONF"
fi

# ============================================
# Backend Health State
# ============================================

_HYBRID_BM25_HEALTHY=""
_HYBRID_VECTOR_HEALTHY=""

# Check and cache backend health
_hybrid_check_backends() {
    if [ -z "$_HYBRID_BM25_HEALTHY" ]; then
        # Check BM25 health via subprocess
        if bash -c "source '$HYBRID_LIB_DIR/bm25-search.sh' && backend_health_check" >/dev/null 2>&1; then
            _HYBRID_BM25_HEALTHY="true"
        else
            _HYBRID_BM25_HEALTHY="false"
        fi
    fi

    if [ -z "$_HYBRID_VECTOR_HEALTHY" ]; then
        # Check vector health via subprocess
        if bash -c "source '$HYBRID_LIB_DIR/vector-search.sh' && backend_health_check" >/dev/null 2>&1; then
            _HYBRID_VECTOR_HEALTHY="true"
        else
            _HYBRID_VECTOR_HEALTHY="false"
        fi
    fi
}

# ============================================
# Result Merging
# ============================================

# Merge and reweight results from two backends.
# Reads from two files, applies weights, deduplicates by file path.
# Args: $1=bm25_file, $2=vector_file, $3=bm25_weight, $4=vector_weight, $5=max_results
_hybrid_merge_results() {
    local bm25_file="$1"
    local vector_file="$2"
    local bm25_weight="$3"
    local vector_weight="$4"
    local max_results="$5"

    awk -F'\t' -v bw="$bm25_weight" -v vw="$vector_weight" -v max="$max_results" '
    BEGIN { OFS="\t" }
    {
        file = $2
        score = $1 + 0.0
        line = $3
        snippet = $4

        if (FILENAME == ARGV[1]) {
            # BM25 results: apply BM25 weight
            weighted = score * bw
        } else {
            # Vector results: apply vector weight
            weighted = score * vw
        }

        if (file in best_score) {
            best_score[file] += weighted
            # Keep the snippet from whichever had higher score
            if (weighted > best_weighted[file]) {
                best_weighted[file] = weighted
                best_line[file] = line
                best_snippet[file] = snippet
            }
        } else {
            best_score[file] = weighted
            best_weighted[file] = weighted
            best_line[file] = line
            best_snippet[file] = snippet
            files[++n] = file
        }
    }
    END {
        # Sort by merged score descending (simple selection sort for small N)
        for (i = 1; i <= n; i++) {
            max_idx = i
            for (j = i + 1; j <= n; j++) {
                if (best_score[files[j]] > best_score[files[max_idx]]) {
                    max_idx = j
                }
            }
            if (max_idx != i) {
                tmp = files[i]; files[i] = files[max_idx]; files[max_idx] = tmp
            }
        }

        # Output top results
        count = (n < max) ? n : max
        for (i = 1; i <= count; i++) {
            f = files[i]
            printf "%.4f\t%s\t%s\t%s\n", best_score[f], f, best_line[f], best_snippet[f]
        }
    }
    ' "$bm25_file" "$vector_file"
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

    _hybrid_check_backends

    # Split timeout budget between backends (reserve 200ms for merge overhead)
    local overhead_ms=200
    local available_ms=$((timeout_ms - overhead_ms))
    [ "$available_ms" -lt 500 ] && available_ms=500

    local bm25_results_file
    local vector_results_file
    bm25_results_file=$(mktemp)
    vector_results_file=$(mktemp)

    # Ensure cleanup
    trap "rm -f '$bm25_results_file' '$vector_results_file'" EXIT

    local active_backends=0
    [ "$_HYBRID_BM25_HEALTHY" = "true" ] && active_backends=$((active_backends + 1))
    [ "$_HYBRID_VECTOR_HEALTHY" = "true" ] && active_backends=$((active_backends + 1))

    if [ "$active_backends" -eq 0 ]; then
        # Both unhealthy: fall back to keyword backend
        rm -f "$bm25_results_file" "$vector_results_file"
        bash -c "
            source '$HYBRID_LIB_DIR/keyword-backend.sh'
            backend_search $(printf '%q' "$query") '$max_results' '$timeout_ms' '$scope'
        " 2>/dev/null || true
        return 0
    fi

    local timeout_per_backend_ms=$((available_ms / active_backends))

    # Run BM25 search
    if [ "$_HYBRID_BM25_HEALTHY" = "true" ]; then
        bash -c "
            source '$HYBRID_LIB_DIR/bm25-search.sh'
            backend_search $(printf '%q' "$query") '$MAX_CANDIDATES' '$timeout_per_backend_ms' '$scope'
        " > "$bm25_results_file" 2>/dev/null || true
    fi

    # Run vector search
    if [ "$_HYBRID_VECTOR_HEALTHY" = "true" ]; then
        bash -c "
            source '$HYBRID_LIB_DIR/vector-search.sh'
            backend_search $(printf '%q' "$query") '$MAX_CANDIDATES' '$timeout_per_backend_ms' '$scope'
        " > "$vector_results_file" 2>/dev/null || true
    fi

    # Determine effective weights
    local eff_bm25_weight="$KEYWORD_WEIGHT"
    local eff_vector_weight="$VECTOR_WEIGHT"

    # If only one backend produced results, give it full weight
    local bm25_has_results=false
    local vector_has_results=false
    [ -s "$bm25_results_file" ] && bm25_has_results=true
    [ -s "$vector_results_file" ] && vector_has_results=true

    if [ "$bm25_has_results" = true ] && [ "$vector_has_results" = false ]; then
        eff_bm25_weight="1.0"
        eff_vector_weight="0.0"
    elif [ "$bm25_has_results" = false ] && [ "$vector_has_results" = true ]; then
        eff_bm25_weight="0.0"
        eff_vector_weight="1.0"
    elif [ "$bm25_has_results" = false ] && [ "$vector_has_results" = false ]; then
        # Neither produced results: fall back to keyword
        rm -f "$bm25_results_file" "$vector_results_file"
        bash -c "
            source '$HYBRID_LIB_DIR/keyword-backend.sh'
            backend_search $(printf '%q' "$query") '$max_results' '$timeout_ms' '$scope'
        " 2>/dev/null || true
        return 0
    fi

    # Merge results with weights
    _hybrid_merge_results "$bm25_results_file" "$vector_results_file" \
        "$eff_bm25_weight" "$eff_vector_weight" "$max_results"

    rm -f "$bm25_results_file" "$vector_results_file"
    trap - EXIT
    return 0
}

backend_index() {
    local file_path="${1:-}"

    if [ -z "$file_path" ]; then
        echo "ERROR: file_path required" >&2
        return 1
    fi

    local rc=0

    # Index in BM25
    bash -c "
        source '$HYBRID_LIB_DIR/bm25-search.sh'
        backend_index $(printf '%q' "$file_path")
    " 2>/dev/null || rc=1

    # Index in vector
    bash -c "
        source '$HYBRID_LIB_DIR/vector-search.sh'
        backend_index $(printf '%q' "$file_path")
    " 2>/dev/null || true  # Vector failure is non-fatal

    return $rc
}

backend_reindex_all() {
    local rc=0

    # Reindex BM25
    echo "Reindexing BM25..." >&2
    bash -c "
        source '$HYBRID_LIB_DIR/bm25-search.sh'
        backend_reindex_all
    " 2>/dev/null || rc=1

    # Reindex vector (non-fatal if it fails)
    echo "Reindexing vector..." >&2
    bash -c "
        source '$HYBRID_LIB_DIR/vector-search.sh'
        backend_reindex_all
    " 2>/dev/null || true

    return $rc
}

backend_health_check() {
    _hybrid_check_backends

    local status_parts=""
    local overall_healthy=false

    if [ "$_HYBRID_BM25_HEALTHY" = "true" ]; then
        status_parts="BM25:healthy"
        overall_healthy=true
    else
        status_parts="BM25:unhealthy"
    fi

    if [ "$_HYBRID_VECTOR_HEALTHY" = "true" ]; then
        status_parts="$status_parts, vector:healthy"
        overall_healthy=true
    else
        status_parts="$status_parts, vector:unhealthy"
    fi

    if [ "$overall_healthy" = true ]; then
        echo "hybrid backend: healthy ($status_parts)"
        return 0
    else
        echo "hybrid backend: unhealthy ($status_parts)"
        return 1
    fi
}
