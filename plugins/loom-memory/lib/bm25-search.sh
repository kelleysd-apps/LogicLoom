#!/usr/bin/env bash
# BM25 Search Backend
# Plugin: loom-memory v2.0.0
# Implements BM25 (Okapi BM25) scoring for memory retrieval.
#
# BM25 formula: score(D,Q) = SUM[ IDF(qi) * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * dl/avgdl)) ]
#   where:
#     tf     = term frequency in document
#     dl     = document length (word count)
#     avgdl  = average document length across corpus
#     k1     = 1.2 (term frequency saturation)
#     b      = 0.75 (document length normalization)
#     IDF(q) = ln((N - n(q) + 0.5) / (n(q) + 0.5) + 1)
#       N    = total documents
#       n(q) = documents containing term q
#
# Index storage: .loom-memory-index/bm25/ (repo root relative)
#   terms/<term>       - doc:freq pairs, one per line
#   meta/doc-lengths   - file:wordcount pairs, one per line
#   meta/corpus-stats  - N (total docs) and avgdl on separate lines

set -euo pipefail

BM25_BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BM25_PLUGIN_DIR="$(cd "$BM25_BACKEND_DIR/.." && pwd)"
BM25_REPO_ROOT="$(cd "$BM25_PLUGIN_DIR/../.." && pwd)"

# Source the backend interface
source "$BM25_BACKEND_DIR/backend-interface.sh"

# ============================================
# BM25 Configuration
# ============================================

BM25_K1=1.2
BM25_B=0.75
BM25_INDEX_DIR="$BM25_REPO_ROOT/.loom-memory-index/bm25"
BM25_TERMS_DIR="$BM25_INDEX_DIR/terms"
BM25_META_DIR="$BM25_INDEX_DIR/meta"
BM25_DOC_LENGTHS="$BM25_META_DIR/doc-lengths"
BM25_CORPUS_STATS="$BM25_META_DIR/corpus-stats"

STOP_WORDS="${STOP_WORDS:-the a an is are was were be been being have has had do does did will would shall should may might can could of in to for on with at by from as into through during before after above below between out off over under}"

# Maximum file size to index (50KB)
BM25_MAX_FILE_SIZE=50000

# ============================================
# Internal Functions
# ============================================

# Ensure index directories exist
_bm25_ensure_dirs() {
    mkdir -p "$BM25_TERMS_DIR" "$BM25_META_DIR"
}

# Extract keywords from text: lowercase, strip punctuation, remove stop words and short words
# Args: $1=text
# Output: space-separated keywords
_bm25_extract_keywords() {
    local text="$1"
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | \
        awk -v stops=" $STOP_WORDS " '
        length >= 3 && index(stops, " " $0 " ") == 0 { print }
        ' | sort -u | tr '\n' ' '
}

# Tokenize a file: lowercase, strip punctuation, emit all words (not unique, for frequency counting)
# Args: $1=file_path
# Output: one word per line (lowercased, punctuation stripped)
_bm25_tokenize_file() {
    local file_path="$1"
    tr '[:upper:]' '[:lower:]' < "$file_path" | tr -cs '[:alnum:]' '\n' | \
        awk 'length >= 1 { print }'
}

# Get the repo-relative path for a file
# Args: $1=absolute_path
# Output: relative path
_bm25_rel_path() {
    local abs_path="$1"
    echo "${abs_path#$BM25_REPO_ROOT/}"
}

# Read corpus stats: total docs and average doc length
# Sets: BM25_N (total docs), BM25_AVGDL (average doc length)
_bm25_load_corpus_stats() {
    BM25_N=0
    BM25_AVGDL=1
    if [ -f "$BM25_CORPUS_STATS" ]; then
        BM25_N=$(sed -n '1p' "$BM25_CORPUS_STATS" 2>/dev/null || echo "0")
        BM25_AVGDL=$(sed -n '2p' "$BM25_CORPUS_STATS" 2>/dev/null || echo "1")
        if [ -z "$BM25_N" ]; then BM25_N=0; fi
        if [ -z "$BM25_AVGDL" ]; then BM25_AVGDL=1; fi
    fi
    return 0
}

# Recalculate and write corpus stats from doc-lengths file
_bm25_update_corpus_stats() {
    if [ ! -f "$BM25_DOC_LENGTHS" ] || [ ! -s "$BM25_DOC_LENGTHS" ]; then
        printf "0\n1\n" > "$BM25_CORPUS_STATS"
        return
    fi
    awk -F'\t' '
    {
        n++
        total += $2
    }
    END {
        printf "%d\n", n
        if (n > 0) printf "%.2f\n", total / n
        else printf "1\n"
    }
    ' "$BM25_DOC_LENGTHS" > "$BM25_CORPUS_STATS"
}

# Remove a document from the inverted index
# Args: $1=rel_path (repo-relative path)
_bm25_remove_doc_from_index() {
    local rel_path="$1"
    local escaped_path
    # Escape special regex chars in path for use in grep/sed
    escaped_path=$(printf '%s' "$rel_path" | sed 's/[.[\/*^$()+?{|]/\\&/g')

    # Remove from doc-lengths
    if [ -f "$BM25_DOC_LENGTHS" ]; then
        grep -v "^${escaped_path}	" "$BM25_DOC_LENGTHS" > "$BM25_DOC_LENGTHS.tmp" 2>/dev/null || true
        mv "$BM25_DOC_LENGTHS.tmp" "$BM25_DOC_LENGTHS"
    fi

    # Remove from all term files that reference this document
    local term_files
    term_files=$(grep -rl "^${escaped_path}	" "$BM25_TERMS_DIR/" 2>/dev/null) || true
    for tf in $term_files; do
        [ -f "$tf" ] || continue
        grep -v "^${escaped_path}	" "$tf" > "$tf.tmp" 2>/dev/null || true
        if [ -s "$tf.tmp" ]; then
            mv "$tf.tmp" "$tf"
        else
            rm -f "$tf" "$tf.tmp"
        fi
    done
}

# Get a safe filename for a term (hash long terms, keep short ones readable)
# Args: $1=term
# Output: filename-safe string
_bm25_term_filename() {
    local term="$1"
    if [ ${#term} -le 40 ]; then
        echo "$term"
    else
        echo "$term" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$term" | shasum | cut -d' ' -f1
    fi
}

# Get first matching line number and context snippet for a keyword in a file
# Args: $1=file_path, $2=keyword
# Output: LINE_NUM<TAB>SNIPPET
_bm25_get_snippet() {
    local file_path="$1"
    local keyword="$2"

    [ -f "$file_path" ] || return 0

    local line_info
    line_info=$(grep -n -m 1 -i "$keyword" "$file_path" 2>/dev/null | head -1) || true

    if [ -z "$line_info" ]; then
        local snippet
        snippet=$(head -5 "$file_path" 2>/dev/null | tr '\n' ' ' | cut -c1-500)
        printf "1\t%s" "$snippet"
        return
    fi

    local line_num
    line_num=$(echo "$line_info" | cut -d: -f1)
    [ -z "$line_num" ] && line_num=1

    local start=$((line_num > 2 ? line_num - 2 : 1))
    local end=$((line_num + 2))
    local context
    context=$(sed -n "${start},${end}p" "$file_path" 2>/dev/null | tr '\n' ' ' | cut -c1-500) || true

    printf "%s\t%s" "$line_num" "$context"
}

# Collect all indexable .md files in the project
# Output: one absolute path per line
_bm25_find_indexable_files() {
    find "$BM25_REPO_ROOT" \
        -type f -name "*.md" \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/.loom-memory-index/*" \
        -not -path "*/vendor/*" \
        -size -"${BM25_MAX_FILE_SIZE}c" \
        2>/dev/null || true
}

# Index a single file and append its term-frequency data to a flat output file.
# This is the core indexing function used by both backend_index and backend_reindex_all.
# Args: $1=absolute file path, $2=flat output file path (term\tdoc\tfreq lines appended)
# Side effect: appends doc length to BM25_DOC_LENGTHS
_bm25_index_single_file() {
    local file_path="$1"
    local flat_output="$2"

    [ -f "$file_path" ] || return 0

    local rel_path
    rel_path=$(_bm25_rel_path "$file_path")

    # Single awk pass: tokenize, count term frequencies, compute doc length, emit results.
    # Output format: one line per term with TERM<TAB>DOC<TAB>FREQ
    # First line is special: __DOCLEN__<TAB>DOC<TAB>WORDCOUNT
    tr '[:upper:]' '[:lower:]' < "$file_path" | tr -cs '[:alnum:]' '\n' | \
        awk -v stops=" $STOP_WORDS " -v doc="$rel_path" '
        length >= 1 { total++ }
        length >= 3 && index(stops, " " $0 " ") == 0 {
            count[$0]++
        }
        END {
            printf "__DOCLEN__\t%s\t%d\n", doc, total + 0
            for (w in count) printf "%s\t%s\t%d\n", w, doc, count[w]
        }
        ' >> "$flat_output"
}

# Scatter a flat term data file into per-term index files.
# Reads lines of TERM<TAB>DOC<TAB>FREQ and writes DOC<TAB>FREQ to terms/<TERM>.
# Also extracts __DOCLEN__ lines and writes to doc-lengths file.
# Args: $1=flat input file
_bm25_scatter_to_index() {
    local flat_input="$1"

    # Use awk to do all the scattering in a single pass.
    # awk writes each term's entries to the appropriate file under terms_dir.
    awk -F'\t' -v terms_dir="$BM25_TERMS_DIR" -v doc_lengths="$BM25_DOC_LENGTHS" '
    {
        term = $1
        doc = $2
        freq = $3
        if (term == "__DOCLEN__") {
            print doc "\t" freq >> doc_lengths
        } else {
            # Terms <= 40 chars use their name directly; longer ones we skip
            # (rare in practice for natural language terms)
            if (length(term) <= 40) {
                outfile = terms_dir "/" term
                print doc "\t" freq >> outfile
            }
        }
    }
    ' "$flat_input"
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

    # Check index exists
    if [ ! -d "$BM25_TERMS_DIR" ] || [ ! -f "$BM25_CORPUS_STATS" ]; then
        echo "BM25: index not built, run reindex first" >&2
        return 1
    fi

    _bm25_load_corpus_stats

    if [ "$BM25_N" -eq 0 ]; then
        return 0
    fi

    # Extract query keywords
    local keywords
    keywords=$(_bm25_extract_keywords "$query")

    if [ -z "$keywords" ]; then
        return 0
    fi

    # Determine scope filter paths (for filtering results)
    local scope_pattern=""
    if [ "$scope" = "session" ]; then
        scope_pattern="^(specs/|\.devloop/sessions/|\.docs/)"
    fi

    # Build a temporary file with all term data needed for scoring.
    # For each query keyword, cat its term file and prepend the keyword + nq.
    local tmp_score_input
    tmp_score_input=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_score_input'" RETURN

    for keyword in $keywords; do
        local term_file="$BM25_TERMS_DIR/$(_bm25_term_filename "$keyword")"
        if [ ! -f "$term_file" ]; then
            continue
        fi

        # n(q) = number of documents containing this term
        local nq
        nq=$(wc -l < "$term_file" | tr -d ' ')

        # Prepend keyword and nq to each line: keyword<TAB>nq<TAB>doc<TAB>tf
        awk -F'\t' -v kw="$keyword" -v nq="$nq" '
            $1 != "" { printf "%s\t%s\t%s\t%s\n", kw, nq, $1, $2 }
        ' "$term_file" >> "$tmp_score_input"
    done

    if [ ! -s "$tmp_score_input" ]; then
        rm -f "$tmp_score_input"
        return 0
    fi

    # Compute BM25 scores using awk in a single pass
    local results
    results=$(awk -F'\t' \
        -v k1="$BM25_K1" \
        -v b="$BM25_B" \
        -v N="$BM25_N" \
        -v avgdl="$BM25_AVGDL" \
        -v doc_lengths_file="$BM25_DOC_LENGTHS" \
        -v scope_pattern="$scope_pattern" \
        -v max_results="$max_results" \
        '
    BEGIN {
        # Load document lengths
        while ((getline line < doc_lengths_file) > 0) {
            split(line, parts, "\t")
            dl[parts[1]] = parts[2]
        }
        close(doc_lengths_file)
    }
    {
        keyword = $1
        nq = $2 + 0
        doc = $3
        tf = $4 + 0

        # Skip if scope filtering and doc does not match
        if (scope_pattern != "" && doc !~ scope_pattern) next

        # IDF: ln((N - nq + 0.5) / (nq + 0.5) + 1)
        idf = log((N - nq + 0.5) / (nq + 0.5) + 1)
        if (idf < 0) idf = 0

        # Document length (default to avgdl if missing)
        d = (doc in dl) ? dl[doc] + 0 : avgdl

        # BM25 term score
        denom = tf + k1 * (1 - b + b * d / avgdl)
        if (denom == 0) denom = 1
        term_score = idf * (tf * (k1 + 1)) / denom

        scores[doc] += term_score

        # Track which keyword had the highest tf for snippet lookup
        if (!(doc in best_keyword) || tf > best_tf[doc]) {
            best_keyword[doc] = keyword
            best_tf[doc] = tf
        }
    }
    END {
        # Collect scored docs into arrays for sorting
        n = 0
        for (doc in scores) {
            n++
            sdocs[n] = doc
            sscores[n] = scores[doc]
            skw[n] = best_keyword[doc]
        }

        # Insertion sort (adequate for typical result sets of tens to low hundreds)
        for (i = 2; i <= n; i++) {
            j = i
            while (j > 1 && sscores[j] > sscores[j-1]) {
                tmp = sdocs[j]; sdocs[j] = sdocs[j-1]; sdocs[j-1] = tmp
                tmp = sscores[j]; sscores[j] = sscores[j-1]; sscores[j-1] = tmp
                tmp = skw[j]; skw[j] = skw[j-1]; skw[j-1] = tmp
                j--
            }
        }

        # Output top results: raw_score<TAB>doc<TAB>best_keyword
        limit = (max_results + 0 < n) ? max_results + 0 : n
        for (i = 1; i <= limit; i++) {
            printf "%.6f\t%s\t%s\n", sscores[i], sdocs[i], skw[i]
        }
    }
    ' "$tmp_score_input")

    rm -f "$tmp_score_input"

    if [ -z "$results" ]; then
        return 0
    fi

    # Find the maximum raw score for normalization to 0.0-1.0
    local max_raw_score
    max_raw_score=$(echo "$results" | head -1 | cut -f1)

    # For each result, get snippet and normalize score, then output SearchResult format
    while IFS=$'\t' read -r raw_score doc_path best_kw; do
        [ -z "$doc_path" ] && continue

        local abs_path="$BM25_REPO_ROOT/$doc_path"

        # Normalize score to 0.0-1.0 range
        local norm_score
        norm_score=$(awk "BEGIN {
            if ($max_raw_score > 0) printf \"%.2f\", $raw_score / $max_raw_score
            else printf \"0.00\"
        }")

        # Get line number and snippet
        local snippet_data
        snippet_data=$(_bm25_get_snippet "$abs_path" "$best_kw")
        local line_num
        line_num=$(printf '%s' "$snippet_data" | cut -f1)
        local snippet
        snippet=$(printf '%s' "$snippet_data" | cut -f2-)

        format_search_result "$norm_score" "$doc_path" "$line_num" "$snippet"
    done <<< "$results"

    return 0
}

backend_index() {
    local file_path="${1:-}"

    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo "BM25: file not found: $file_path" >&2
        return 1
    fi

    _bm25_ensure_dirs

    # Skip files that are too large
    local file_size
    file_size=$(wc -c < "$file_path" 2>/dev/null | tr -d ' ')
    if [ "$file_size" -gt "$BM25_MAX_FILE_SIZE" ]; then
        return 0
    fi

    local rel_path
    rel_path=$(_bm25_rel_path "$file_path")

    # Remove any existing index entries for this document
    _bm25_remove_doc_from_index "$rel_path"

    # Index the file: collect term data into a temp flat file, then scatter
    local tmp_flat
    tmp_flat=$(mktemp)

    _bm25_index_single_file "$file_path" "$tmp_flat"
    _bm25_scatter_to_index "$tmp_flat"

    rm -f "$tmp_flat"

    # Update corpus stats
    _bm25_update_corpus_stats

    return 0
}

backend_reindex_all() {
    _bm25_ensure_dirs

    # Clear existing index
    rm -rf "$BM25_TERMS_DIR" "$BM25_META_DIR"
    mkdir -p "$BM25_TERMS_DIR" "$BM25_META_DIR"

    # Find all indexable files
    local file_list
    file_list=$(_bm25_find_indexable_files)

    if [ -z "$file_list" ]; then
        printf "0\n1\n" > "$BM25_CORPUS_STATS"
        echo "BM25: no files to index"
        return 0
    fi

    # Phase 1: Build a single flat file with all term data from all files.
    # Each file gets one _bm25_index_single_file call which runs a single awk pass.
    # All output goes to the same flat file.
    local tmp_flat
    tmp_flat=$(mktemp)

    while IFS= read -r file_path; do
        [ -f "$file_path" ] || continue
        _bm25_index_single_file "$file_path" "$tmp_flat"
    done <<< "$file_list"

    # Phase 2: Scatter the flat file into per-term index files (single awk pass).
    _bm25_scatter_to_index "$tmp_flat"

    rm -f "$tmp_flat"

    # Phase 3: Compute corpus stats
    _bm25_update_corpus_stats

    _bm25_load_corpus_stats
    echo "BM25: indexed $BM25_N documents (avgdl=$BM25_AVGDL)"
    return 0
}

backend_health_check() {
    if [ ! -d "$BM25_INDEX_DIR" ]; then
        echo "BM25: index directory missing ($BM25_INDEX_DIR)"
        return 1
    fi

    if [ ! -d "$BM25_TERMS_DIR" ]; then
        echo "BM25: terms directory missing"
        return 1
    fi

    if [ ! -f "$BM25_CORPUS_STATS" ]; then
        echo "BM25: corpus stats file missing"
        return 1
    fi

    # Check if there are any term files
    local term_count
    term_count=$(find "$BM25_TERMS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ "$term_count" -eq 0 ]; then
        echo "BM25: index is empty (0 terms)"
        return 1
    fi

    _bm25_load_corpus_stats
    echo "BM25: healthy ($BM25_N docs, $term_count terms, avgdl=$BM25_AVGDL)"
    return 0
}
