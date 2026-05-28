#!/usr/bin/env bash
# Vector Search Backend
# Plugin: sdd-memory v2.0.0
# Implements the backend interface for embedding-based semantic search.
#
# Uses Python with sentence-transformers (or fallback) for embedding computation
# and cosine similarity matching. Stores vectors in .sdd-memory-index/vectors/.
#
# CRITICAL: Gracefully degrades if Python or dependencies are unavailable.
# The hybrid layer will fall back to keyword/BM25 search when health_check returns 1.

set -euo pipefail

VECTOR_BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VECTOR_PLUGIN_DIR="$(cd "$VECTOR_BACKEND_DIR/.." && pwd)"
VECTOR_REPO_ROOT="$(cd "$VECTOR_PLUGIN_DIR/../.." && pwd)"

# Source the backend interface (provides stubs + format_search_result + top_k_results)
source "$VECTOR_BACKEND_DIR/backend-interface.sh"

# ============================================
# Configuration
# ============================================

VECTOR_INDEX_DIR="${VECTOR_REPO_ROOT}/.sdd-memory-index/vectors"
VECTOR_METADATA_DIR="${VECTOR_REPO_ROOT}/.sdd-memory-index/metadata"
VECTOR_PYTHON_HELPER="${VECTOR_BACKEND_DIR}/vector_helper.py"

# Embedding model configuration (from memory-v2.conf)
EMBEDDING_MODEL="${EMBEDDING_MODEL:-sentence-transformers}"
EMBEDDING_DIM="${EMBEDDING_DIM:-384}"  # all-MiniLM-L6-v2 default dimension

# Chunk configuration
CHUNK_SIZE="${CHUNK_SIZE:-512}"       # Characters per chunk
CHUNK_OVERLAP="${CHUNK_OVERLAP:-64}"  # Overlap between chunks

# Search scope paths (mirrors keyword backend)
STOP_WORDS="${STOP_WORDS:-the a an is are was were be been being have has had do does did will would shall should may might can could of in to for on with at by from as into through during before after above below between out off over under}"

# ============================================
# Python Helper (embedded)
# ============================================

# Generate the Python helper script on first use.
# This avoids requiring a separate Python file to be distributed.
_ensure_python_helper() {
    if [ -f "$VECTOR_PYTHON_HELPER" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$VECTOR_PYTHON_HELPER")"

    cat > "$VECTOR_PYTHON_HELPER" << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Vector Search Helper for sdd-memory plugin.
Handles embedding computation, storage, and cosine similarity search.

Commands:
    health     - Check if dependencies are available
    embed      - Embed text and output vector as JSON array
    index      - Embed file chunks and store vectors
    search     - Search stored vectors for a query
"""

import sys
import os
import json
import hashlib
import math
import time

# ── Dependency Detection ──

BACKEND = None  # "sentence-transformers" or "numpy-only"
MODEL = None

def detect_backend():
    """Detect available embedding backend."""
    global BACKEND, MODEL

    # Try sentence-transformers first (best quality)
    try:
        from sentence_transformers import SentenceTransformer
        MODEL = SentenceTransformer("all-MiniLM-L6-v2")
        BACKEND = "sentence-transformers"
        return True
    except ImportError:
        pass

    # No usable backend
    BACKEND = None
    return False


def health_check():
    """Check if embedding dependencies are available."""
    if detect_backend():
        print(json.dumps({
            "status": "healthy",
            "backend": BACKEND,
            "message": f"vector backend: healthy ({BACKEND})"
        }))
        return 0
    else:
        print(json.dumps({
            "status": "unhealthy",
            "backend": None,
            "message": "vector backend: unhealthy (sentence-transformers not installed)"
        }))
        return 1


# ── Embedding Functions ──

def embed_text(text):
    """Generate embedding vector for text."""
    if BACKEND == "sentence-transformers":
        vec = MODEL.encode(text, show_progress_bar=False)
        return vec.tolist()
    else:
        raise RuntimeError("No embedding backend available")


def cosine_similarity(vec_a, vec_b):
    """Compute cosine similarity between two vectors."""
    dot = sum(a * b for a, b in zip(vec_a, vec_b))
    norm_a = math.sqrt(sum(a * a for a in vec_a))
    norm_b = math.sqrt(sum(b * b for b in vec_b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


# ── Chunking ──

def chunk_text(text, chunk_size=512, overlap=64):
    """Split text into overlapping chunks."""
    chunks = []
    lines = text.split("\n")
    current_chunk = []
    current_len = 0

    for line in lines:
        line_len = len(line) + 1  # +1 for newline
        if current_len + line_len > chunk_size and current_chunk:
            chunk_text_str = "\n".join(current_chunk)
            chunks.append(chunk_text_str)

            # Keep overlap: retain last few lines that fit within overlap budget
            overlap_lines = []
            overlap_len = 0
            for prev_line in reversed(current_chunk):
                if overlap_len + len(prev_line) + 1 > overlap:
                    break
                overlap_lines.insert(0, prev_line)
                overlap_len += len(prev_line) + 1

            current_chunk = overlap_lines
            current_len = overlap_len

        current_chunk.append(line)
        current_len += line_len

    # Final chunk
    if current_chunk:
        chunks.append("\n".join(current_chunk))

    return chunks


# ── Index Operations ──

def index_file(file_path, vector_dir, metadata_dir, chunk_size=512, overlap=64):
    """Index a file by chunking and embedding its content."""
    if not detect_backend():
        print(json.dumps({"error": "No embedding backend available"}))
        return 1

    if not os.path.isfile(file_path):
        print(json.dumps({"error": f"File not found: {file_path}"}))
        return 1

    # Skip binary and large files
    try:
        file_size = os.path.getsize(file_path)
        if file_size > 100000:  # 100KB limit
            print(json.dumps({"skipped": True, "reason": "file too large", "path": file_path}))
            return 0
        if file_size == 0:
            print(json.dumps({"skipped": True, "reason": "empty file", "path": file_path}))
            return 0
    except OSError:
        return 1

    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except Exception as e:
        print(json.dumps({"error": f"Cannot read file: {e}"}))
        return 1

    # Generate file hash for change detection
    file_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()[:16]

    # Check if already indexed with same hash
    file_id = hashlib.sha256(file_path.encode("utf-8")).hexdigest()[:16]
    meta_path = os.path.join(metadata_dir, f"{file_id}.json")

    if os.path.exists(meta_path):
        try:
            with open(meta_path, "r") as f:
                existing_meta = json.load(f)
            if existing_meta.get("file_hash") == file_hash:
                print(json.dumps({"skipped": True, "reason": "unchanged", "path": file_path}))
                return 0
        except (json.JSONDecodeError, KeyError):
            pass  # Re-index if metadata is corrupt

    # Chunk the content
    chunks = chunk_text(content, chunk_size, overlap)
    if not chunks:
        return 0

    # Embed all chunks
    os.makedirs(vector_dir, exist_ok=True)
    os.makedirs(metadata_dir, exist_ok=True)

    chunk_vectors = []
    for i, chunk in enumerate(chunks):
        vec = embed_text(chunk)
        chunk_vectors.append({
            "chunk_index": i,
            "vector": vec,
            "line_start": _estimate_line_number(content, chunk),
            "snippet": chunk[:500]
        })

    # Store vectors
    vec_path = os.path.join(vector_dir, f"{file_id}.json")
    with open(vec_path, "w") as f:
        json.dump(chunk_vectors, f)

    # Store metadata
    meta = {
        "file_path": file_path,
        "file_hash": file_hash,
        "chunk_count": len(chunks),
        "indexed_at": time.time()
    }
    with open(meta_path, "w") as f:
        json.dump(meta, f)

    print(json.dumps({
        "indexed": True,
        "path": file_path,
        "chunks": len(chunks)
    }))
    return 0


def _estimate_line_number(full_text, chunk_text):
    """Estimate the line number where a chunk starts in the full text."""
    pos = full_text.find(chunk_text[:80])
    if pos < 0:
        return 1
    return full_text[:pos].count("\n") + 1


# ── Search ──

def search_vectors(query, vector_dir, metadata_dir, max_results=10, timeout_s=3.0):
    """Search stored vectors for the most similar chunks to the query."""
    if not detect_backend():
        print(json.dumps({"error": "No embedding backend available", "results": []}))
        return 1

    start_time = time.time()

    # Embed the query
    query_vec = embed_text(query)

    results = []
    elapsed = time.time() - start_time

    # Scan all stored vector files
    if not os.path.isdir(vector_dir):
        print(json.dumps({"results": []}))
        return 0

    for vec_file in os.listdir(vector_dir):
        # Check timeout budget (reserve 0.2s for sorting/output)
        if time.time() - start_time > timeout_s - 0.2:
            break

        if not vec_file.endswith(".json"):
            continue

        file_id = vec_file.replace(".json", "")
        meta_path = os.path.join(metadata_dir, f"{file_id}.json")

        # Load metadata for file path
        if not os.path.exists(meta_path):
            continue
        try:
            with open(meta_path, "r") as f:
                meta = json.load(f)
        except (json.JSONDecodeError, IOError):
            continue

        # Load vectors
        vec_path = os.path.join(vector_dir, vec_file)
        try:
            with open(vec_path, "r") as f:
                chunks = json.load(f)
        except (json.JSONDecodeError, IOError):
            continue

        # Compute similarity for each chunk
        for chunk_data in chunks:
            sim = cosine_similarity(query_vec, chunk_data["vector"])
            if sim > 0.1:  # Minimum similarity threshold
                results.append({
                    "score": round(sim, 4),
                    "file_path": meta.get("file_path", ""),
                    "line_num": chunk_data.get("line_start", 0),
                    "snippet": chunk_data.get("snippet", "")
                })

    # Sort by score descending, take top results
    results.sort(key=lambda x: x["score"], reverse=True)
    results = results[:max_results]

    print(json.dumps({"results": results}))
    return 0


# ── Reindex ──

def reindex_all(repo_root, vector_dir, metadata_dir, chunk_size=512, overlap=64):
    """Rebuild the entire vector index from scratch."""
    if not detect_backend():
        print(json.dumps({"error": "No embedding backend available"}))
        return 1

    # Clear existing index
    for d in [vector_dir, metadata_dir]:
        if os.path.isdir(d):
            for f in os.listdir(d):
                fp = os.path.join(d, f)
                if os.path.isfile(fp):
                    os.remove(fp)

    # Directories to index
    search_dirs = [
        os.path.join(repo_root, "specs"),
        os.path.join(repo_root, ".docs"),
        os.path.join(repo_root, ".specify", "memory"),
        os.path.join(repo_root, "plugins"),
    ]

    # Also index .devloop/sessions if it exists
    devloop_sessions = os.path.join(repo_root, ".devloop", "sessions")
    if os.path.isdir(devloop_sessions):
        search_dirs.append(devloop_sessions)

    indexed = 0
    skipped = 0
    errors = 0

    # Allowed extensions for indexing
    allowed_ext = {".md", ".txt", ".sh", ".json", ".conf", ".yaml", ".yml", ".py", ".js", ".ts"}

    for search_dir in search_dirs:
        if not os.path.isdir(search_dir):
            continue
        for root, _dirs, files in os.walk(search_dir):
            # Skip hidden directories (except .specify, .docs, .devloop)
            rel_root = os.path.relpath(root, repo_root)
            parts = rel_root.split(os.sep)
            skip = False
            for part in parts:
                if part.startswith(".") and part not in (".specify", ".docs", ".devloop"):
                    skip = True
                    break
            if skip:
                continue

            for fname in files:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in allowed_ext:
                    continue

                fpath = os.path.join(root, fname)
                try:
                    rc = index_file(fpath, vector_dir, metadata_dir, chunk_size, overlap)
                    if rc == 0:
                        indexed += 1
                    else:
                        errors += 1
                except Exception:
                    errors += 1

    print(json.dumps({
        "reindexed": True,
        "indexed": indexed,
        "skipped": skipped,
        "errors": errors
    }))
    return 0


# ── CLI Dispatch ──

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: vector_helper.py <command> [args...]"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "health":
        sys.exit(health_check())

    elif cmd == "embed":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Usage: vector_helper.py embed <text>"}))
            sys.exit(1)
        if not detect_backend():
            print(json.dumps({"error": "No embedding backend available"}))
            sys.exit(1)
        text = sys.argv[2]
        vec = embed_text(text)
        print(json.dumps({"vector": vec, "dimensions": len(vec)}))

    elif cmd == "index":
        if len(sys.argv) < 5:
            print(json.dumps({"error": "Usage: vector_helper.py index <file_path> <vector_dir> <metadata_dir> [chunk_size] [overlap]"}))
            sys.exit(1)
        file_path = sys.argv[2]
        vector_dir = sys.argv[3]
        metadata_dir = sys.argv[4]
        chunk_size = int(sys.argv[5]) if len(sys.argv) > 5 else 512
        overlap = int(sys.argv[6]) if len(sys.argv) > 6 else 64
        sys.exit(index_file(file_path, vector_dir, metadata_dir, chunk_size, overlap))

    elif cmd == "search":
        if len(sys.argv) < 5:
            print(json.dumps({"error": "Usage: vector_helper.py search <query> <vector_dir> <metadata_dir> [max_results] [timeout_s]"}))
            sys.exit(1)
        query = sys.argv[2]
        vector_dir = sys.argv[3]
        metadata_dir = sys.argv[4]
        max_results = int(sys.argv[5]) if len(sys.argv) > 5 else 10
        timeout_s = float(sys.argv[6]) if len(sys.argv) > 6 else 3.0
        sys.exit(search_vectors(query, vector_dir, metadata_dir, max_results, timeout_s))

    elif cmd == "reindex":
        if len(sys.argv) < 5:
            print(json.dumps({"error": "Usage: vector_helper.py reindex <repo_root> <vector_dir> <metadata_dir> [chunk_size] [overlap]"}))
            sys.exit(1)
        repo_root = sys.argv[2]
        vector_dir = sys.argv[3]
        metadata_dir = sys.argv[4]
        chunk_size = int(sys.argv[5]) if len(sys.argv) > 5 else 512
        overlap = int(sys.argv[6]) if len(sys.argv) > 6 else 64
        sys.exit(reindex_all(repo_root, vector_dir, metadata_dir, chunk_size, overlap))

    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
PYTHON_EOF

    chmod +x "$VECTOR_PYTHON_HELPER"
}

# ============================================
# Internal Helpers
# ============================================

# Find a suitable Python 3 interpreter
_vector_find_python() {
    local py=""
    for candidate in python3 python; do
        if command -v "$candidate" &>/dev/null; then
            local ver
            ver=$("$candidate" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1) || continue
            local major
            major=$(echo "$ver" | cut -d. -f1)
            if [ "$major" = "3" ]; then
                py="$candidate"
                break
            fi
        fi
    done
    echo "$py"
}

# Run the Python helper with timeout protection
# Args: $1=timeout_seconds, $2...=python helper args
_vector_run_python() {
    local timeout_s="$1"
    shift

    local python_cmd
    python_cmd=$(_vector_find_python)
    if [ -z "$python_cmd" ]; then
        echo '{"error": "Python 3 not found"}' >&2
        return 1
    fi

    _ensure_python_helper

    # Use timeout command if available, otherwise just run directly
    if command -v timeout &>/dev/null; then
        timeout "${timeout_s}s" "$python_cmd" "$VECTOR_PYTHON_HELPER" "$@" 2>/dev/null
    elif command -v gtimeout &>/dev/null; then
        gtimeout "${timeout_s}s" "$python_cmd" "$VECTOR_PYTHON_HELPER" "$@" 2>/dev/null
    else
        "$python_cmd" "$VECTOR_PYTHON_HELPER" "$@" 2>/dev/null
    fi
}

# Determine search paths based on scope (mirrors keyword backend logic)
_vector_search_paths() {
    local scope="${1:-session}"
    local paths=()

    if [ "$scope" = "session" ]; then
        [ -d "$VECTOR_REPO_ROOT/specs" ] && paths+=("$VECTOR_REPO_ROOT/specs")
        [ -d "$VECTOR_REPO_ROOT/.devloop/sessions" ] && paths+=("$VECTOR_REPO_ROOT/.devloop/sessions")
        [ -d "$VECTOR_REPO_ROOT/.docs" ] && paths+=("$VECTOR_REPO_ROOT/.docs")
    else
        [ -d "$VECTOR_REPO_ROOT/specs" ] && paths+=("$VECTOR_REPO_ROOT/specs")
        [ -d "$VECTOR_REPO_ROOT/.devloop/sessions" ] && paths+=("$VECTOR_REPO_ROOT/.devloop/sessions")
        [ -d "$VECTOR_REPO_ROOT/.docs" ] && paths+=("$VECTOR_REPO_ROOT/.docs")
        [ -d "$VECTOR_REPO_ROOT/.logic-loom/memory" ] && paths+=("$VECTOR_REPO_ROOT/.logic-loom/memory")
        [ -d "$VECTOR_REPO_ROOT/plugins" ] && paths+=("$VECTOR_REPO_ROOT/plugins")
    fi

    echo "${paths[@]}"
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

    # Convert timeout from ms to seconds (reserve 0.5s for shell overhead)
    local timeout_s
    timeout_s=$(awk "BEGIN {t = ($timeout_ms / 1000.0) - 0.5; printf \"%.1f\", (t > 0.5 ? t : 0.5)}")

    # Check if index directory exists
    if [ ! -d "$VECTOR_INDEX_DIR" ]; then
        echo "ERROR: vector index not built. Run backend_reindex_all() first." >&2
        return 1
    fi

    # Run Python search with timeout
    local raw_output
    raw_output=$(_vector_run_python "$timeout_s" search \
        "$query" "$VECTOR_INDEX_DIR" "$VECTOR_METADATA_DIR" \
        "$max_results" "$timeout_s") || {
        echo "ERROR: vector search failed or timed out" >&2
        return 1
    }

    # Parse JSON results and convert to SearchResult format (tab-separated lines)
    local python_cmd
    python_cmd=$(_vector_find_python)
    if [ -z "$python_cmd" ]; then
        return 1
    fi

    echo "$raw_output" | "$python_cmd" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'error' in data:
        sys.exit(1)
    for r in data.get('results', []):
        score = r.get('score', 0)
        fpath = r.get('file_path', '')
        line = r.get('line_num', 0)
        snippet = r.get('snippet', '').replace('\n', ' ')[:500]
        # Make path relative to repo root if absolute
        repo_root = '$VECTOR_REPO_ROOT'
        if fpath.startswith(repo_root + '/'):
            fpath = fpath[len(repo_root) + 1:]
        print(f'{score}\t{fpath}\t{line}\t{snippet}')
except Exception:
    sys.exit(1)
" 2>/dev/null || {
        echo "ERROR: failed to parse vector search results" >&2
        return 1
    }

    return 0
}

backend_index() {
    local file_path="${1:-}"

    if [ -z "$file_path" ]; then
        echo "ERROR: file_path required" >&2
        return 1
    fi

    # Resolve to absolute path if relative
    if [[ "$file_path" != /* ]]; then
        file_path="$VECTOR_REPO_ROOT/$file_path"
    fi

    if [ ! -f "$file_path" ]; then
        echo "ERROR: file not found: $file_path" >&2
        return 1
    fi

    # Ensure index directories exist
    mkdir -p "$VECTOR_INDEX_DIR" "$VECTOR_METADATA_DIR"

    # Run Python indexer (allow up to 30s for single file)
    local output
    output=$(_vector_run_python 30 index \
        "$file_path" "$VECTOR_INDEX_DIR" "$VECTOR_METADATA_DIR" \
        "$CHUNK_SIZE" "$CHUNK_OVERLAP") || {
        echo "ERROR: failed to index $file_path" >&2
        return 1
    }

    return 0
}

backend_reindex_all() {
    # Ensure index directories exist
    mkdir -p "$VECTOR_INDEX_DIR" "$VECTOR_METADATA_DIR"

    # Run Python reindexer (allow up to 300s for full reindex)
    local output
    output=$(_vector_run_python 300 reindex \
        "$VECTOR_REPO_ROOT" "$VECTOR_INDEX_DIR" "$VECTOR_METADATA_DIR" \
        "$CHUNK_SIZE" "$CHUNK_OVERLAP") || {
        echo "ERROR: full reindex failed" >&2
        return 1
    }

    # Output summary
    local python_cmd
    python_cmd=$(_vector_find_python)
    if [ -n "$python_cmd" ]; then
        local summary
        summary=$(echo "$output" | "$python_cmd" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'error' in data:
        print(f\"ERROR: {data['error']}\", file=sys.stderr)
        sys.exit(1)
    indexed = data.get('indexed', 0)
    errors = data.get('errors', 0)
    print(f'vector reindex complete: {indexed} files indexed, {errors} errors')
except Exception as e:
    print(f'vector reindex: output parse error', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null) && echo "$summary"
    fi

    return 0
}

backend_health_check() {
    # Step 1: Check Python 3 is available
    local python_cmd
    python_cmd=$(_vector_find_python)
    if [ -z "$python_cmd" ]; then
        echo "vector backend: unhealthy (Python 3 not found)"
        return 1
    fi

    # Step 2: Run Python health check (checks sentence-transformers)
    _ensure_python_helper

    local output
    output=$(_vector_run_python 10 health) || {
        echo "vector backend: unhealthy (health check failed or timed out)"
        return 1
    }

    # Step 3: Parse result
    local status
    status=$(echo "$output" | "$python_cmd" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('message', 'unknown status'))
    sys.exit(0 if data.get('status') == 'healthy' else 1)
except Exception:
    print('vector backend: unhealthy (parse error)')
    sys.exit(1)
" 2>/dev/null)
    local rc=$?

    echo "$status"
    return $rc
}
