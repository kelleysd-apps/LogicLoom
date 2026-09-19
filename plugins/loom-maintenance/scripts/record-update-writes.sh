#!/usr/bin/env bash
# record-update-writes.sh — close the adopted-repo rot gap (LOOM v7.0.0).
#
# THE GAP: `npx logicloom init` writes `.logicloom-adopt-receipt.json` once, at
# install time. `/update-framework` never writes to it. So a file first ADDED
# through `/update-framework` (a `clean-add`) is never recorded as `wrote` — and
# `extract-proposals.sh`'s ownership filter (`adopt_file_recorded`) only offers
# an `M|D|R*` proposal for a path that IS recorded. The file's next upstream
# edit is therefore suppressed forever, silently, as "not installed here" even
# though the adopter's own /update-framework put it there.
#
# THIS SCRIPT is the write side extract-proposals.sh never had. It never reads
# proposals and never decides what to adopt — it only appends `runs[]` entries
# to the SAME receipt schema `packaging/adopt/lib/apply.js` writes, so the
# reader (`extract-proposals.sh`'s `detect_adopt_mode` / `adopt_file_recorded`
# / `adopt_dir_recorded`) sees these paths as owned on the next run.
#
# Two modes:
#   record-update-writes.sh [--root <dir>] [--version <vX.Y.Z>] <path>...
#       Record specific paths /update-framework just wrote (called from the
#       command/SKILL apply step, right after a clean-add/clean-apply lands).
#   record-update-writes.sh --reconcile [--apply] [--root <dir>] [--version <vX.Y.Z>]
#       Recover the past: find files under a recorded top-level directory that
#       are byte-identical to the upstream blob at .sdd-sync-ref but were never
#       recorded, and offer to record them.
#
# NEVER runs mutating git. --reconcile runs read-only git only (ls-files,
# cat-file -e / -p, rev-parse). Record mode never touches git at all.
#
# OWNERSHIP RULE: a byte-identical copy of an upstream harness file can only
# have come from upstream; anything that differs may be the adopter's own, and
# ownership is the one thing this tool must not guess — it is never recorded
# automatically. Name it yourself with the plain (non-reconcile) form to record
# it explicitly.
#
# THE DELIBERATE ASYMMETRY: recording a byte-identical copy costs at most one
# extra user-gated PROPOSAL the next time upstream touches that file (still
# reviewed, still never auto-applied) — a false positive is cheap and visible.
# NOT recording a file that update-framework actually wrote costs permanent,
# silent suppression of every future proposal for it — a false negative is
# expensive and invisible. When in doubt, this tool records.
#
# HONEST LIMIT: this script only ever APPENDS to runs[]. It never rebuilds the
# receipt's derived `uninstall` object (that logic lives in the npm package,
# packaging/adopt/lib/apply.js, which regenerates it on its next --apply).
# Until an adopter runs `npx logicloom init --apply` again, a path this script
# records is visible to extract-proposals.sh's ownership filter (so it can
# receive proposals) but is NOT yet listed under `uninstall.remove.files`.
#
# Docs: .docs/guides/MIGRATION_GUIDE.md, .docs/guides/FRAMEWORK_SYNC_GUIDE.md
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}, no &>>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

RECEIPT_NAME=".logicloom-adopt-receipt.json"
RECEIPT_SCHEMA="logicloom/adopt-receipt@1"
SYNC_REF_NAME=".sdd-sync-ref"

# ============================================
# Usage
# ============================================

show_help() {
    cat <<'EOF'
record-update-writes.sh — record files/dirs /update-framework wrote into
.logicloom-adopt-receipt.json, closing the adopted-repo rot gap.

Usage:
  record-update-writes.sh [--root <dir>] [--version <vX.Y.Z>] <path>...
  record-update-writes.sh --reconcile [--apply] [--root <dir>] [--version <vX.Y.Z>]
  record-update-writes.sh --help

Modes:
  <path>...     Record one or more repo-relative paths as freshly written by
                /update-framework. Each path must resolve inside --root (or
                the repo root, when --root is omitted) and be a regular file.
                For every path this appends one `kind:"file"` entry (with a
                sha256 digest of its current bytes) and, for every ancestor
                directory not already recorded, one `kind:"dir"` entry — all
                inside ONE new run appended to runs[]. A path whose already-
                recorded sha256 already matches its current bytes is dropped
                (nothing changed since it was last recorded); when every
                requested path drops out this way, nothing is written and the
                script prints "nothing new to record" and exits 0.

  --reconcile [--apply]
                Recover the past. Lists, for every file `git ls-files` finds
                under a directory this receipt already recorded as a `dir`,
                that is NOT itself recorded as a `file` and exists at
                .sdd-sync-ref:
                  RECONCILE <path>   working-tree bytes == the sync-ref blob
                                     (can only have come from upstream —
                                     recordable)
                  DIFFERS <path>     working-tree bytes != the sync-ref blob
                                     (may be the adopter's own edit — NEVER
                                     recorded automatically; record it
                                     yourself by name if you know it is
                                     actually an accepted upstream file)
                Without --apply this only prints the two lists (a proposal) —
                nothing is written. With --apply, every RECONCILE path (never
                a DIFFERS path) is recorded in ONE run whose "only" field is
                ["reconcile"], exactly as record mode records a path: the
                file entry plus a `kind:"dir"` entry for every ancestor
                directory the receipt has not recorded yet. A second
                --reconcile --apply after that finds nothing left to do.

Options:
  --root <dir>       Repo root to operate on (default: derived from this
                      script's own location, three directories up).
  --version <vX.Y.Z> Framework version stamped into the run's "generator"
                      field as logicloom-update-framework@<X.Y.Z>. Defaults
                      to FRAMEWORK_VERSION in
                      <root>/.logic-loom/config/architecture.conf.
  --help              This text.

JSON tool: python3 is preferred; node is used when python3 is not on PATH
(every adopted install has node — it is what wrote the receipt in the first
place). LOOM_JSON_TOOL=python3|node|<path-to-executable> forces one; a value
that is not runnable fails the same way as having neither on PATH:
  record-update-writes: needs python3 or node to read and write
  .logicloom-adopt-receipt.json — neither is on PATH
Both implementations write the SAME document: python
json.dump(obj, f, indent=2, ensure_ascii=False) plus a trailing newline; node
fs.writeFileSync(path, JSON.stringify(obj, null, 2) + '\n').

OWNERSHIP RULE: a byte-identical copy of an upstream harness file can only
have come from upstream; anything that differs may be yours and is never
recorded automatically — name it yourself to record it.

THE DELIBERATE ASYMMETRY: recording a byte-identical copy costs at most one
extra user-gated proposal on a later upstream edit; not recording costs
permanent silent suppression.

HONEST LIMIT: this script only appends to runs[]. It does not rebuild the
receipt's derived `uninstall` object — the npm tool (packaging/adopt/lib/
apply.js) regenerates that on its next `--apply`.

Docs: .docs/guides/MIGRATION_GUIDE.md, .docs/guides/FRAMEWORK_SYNC_GUIDE.md
EOF
}

# ============================================
# JSON tool resolution (python3, else node, else exit 2)
# ============================================

JSON_TOOL_KIND=""
JSON_TOOL_BIN=""

resolve_json_tool() {
    local forced="${LOOM_JSON_TOOL:-}"
    if [ -n "$forced" ]; then
        case "$forced" in
            python3)
                if command -v python3 >/dev/null 2>&1; then
                    JSON_TOOL_KIND="python3"; JSON_TOOL_BIN="python3"; return 0
                fi
                return 1
                ;;
            node)
                if command -v node >/dev/null 2>&1; then
                    JSON_TOOL_KIND="node"; JSON_TOOL_BIN="node"; return 0
                fi
                return 1
                ;;
            *)
                if [ -x "$forced" ]; then
                    case "$forced" in
                        *python*) JSON_TOOL_KIND="python3" ;;
                        *) JSON_TOOL_KIND="node" ;;
                    esac
                    JSON_TOOL_BIN="$forced"
                    return 0
                fi
                return 1
                ;;
        esac
    fi
    if command -v python3 >/dev/null 2>&1; then
        JSON_TOOL_KIND="python3"; JSON_TOOL_BIN="python3"; return 0
    fi
    if command -v node >/dev/null 2>&1; then
        JSON_TOOL_KIND="node"; JSON_TOOL_BIN="node"; return 0
    fi
    return 1
}

# ---- python3 helper (dispatch by argv[1]) ----
read -r -d '' JSON_HELPER_PY <<'PYEOF' || true
import sys, json, hashlib, os, datetime

def sha256_hex(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def load_receipt(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(2)
    op = args[0]
    rest = args[1:]

    if op == 'sha256':
        sys.stdout.write('sha256:' + sha256_hex(rest[0]) + '\n')
        return 0

    if op == 'validate':
        path = rest[0]
        if not os.path.isfile(path):
            return 3
        try:
            data = load_receipt(path)
        except Exception:
            return 4
        if not isinstance(data, dict) or data.get('schema') != 'logicloom/adopt-receipt@1' or not isinstance(data.get('runs'), list):
            return 4
        return 0

    if op == 'recorded':
        path = rest[0]
        data = load_receipt(path)
        files = {}
        dirs = {}
        for run in data.get('runs', []) or []:
            if not isinstance(run, dict):
                continue
            if run.get('status') not in ('complete', 'partial', 'in-progress'):
                continue
            for w in (run.get('wrote') or []):
                if not isinstance(w, dict):
                    continue
                wp = w.get('path'); wk = w.get('kind')
                if not wp or not wk:
                    continue
                if wk == 'dir':
                    dirs[wp.rstrip('/')] = True
                elif wk == 'file':
                    files[wp] = w.get('sha256') or ''
        out = []
        for p in files:
            out.append('file\t' + p + '\t' + files[p])
        for d in dirs:
            out.append('dir\t' + d + '\t')
        if out:
            sys.stdout.write('\n'.join(out) + '\n')
        return 0

    if op == 'append-run':
        receipt_path = rest[0]
        version = rest[1]
        only_json = rest[2]
        entries_path = rest[3]
        data = load_receipt(receipt_path)
        wrote = []
        with open(entries_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.rstrip('\n')
                if not line:
                    continue
                parts = line.split('\t')
                kind = parts[0]; p = parts[1]
                if kind == 'file':
                    sha = parts[2] if len(parts) > 2 else ''
                    wrote.append({"target": "harness", "path": p, "kind": "file", "sha256": sha})
                else:
                    wrote.append({"target": "harness", "path": p, "kind": "dir"})
        only = json.loads(only_json)
        now = datetime.datetime.now(datetime.timezone.utc)
        at = now.strftime('%Y-%m-%dT%H:%M:%S.') + ('%03dZ' % (now.microsecond // 1000))
        run = {
            "at": at,
            "generator": "logicloom-update-framework@" + version,
            "status": "complete",
            "only": only,
            "wrote": wrote,
            "skipped": [],
            "failed": [],
            "notAttempted": []
        }
        data['runs'].append(run)
        with open(receipt_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        sys.stdout.write(str(len(data['runs'])) + '\n')
        return 0

    return 2

sys.exit(main())
PYEOF

# ---- node helper (dispatch by argv[1]) ----
read -r -d '' JSON_HELPER_NODE <<'NODEEOF' || true
const fs = require('fs');
const crypto = require('crypto');

function sha256Hex(p) {
  const buf = fs.readFileSync(p);
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function loadReceipt(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function main() {
  const args = process.argv.slice(1);
  if (!args.length) process.exit(2);
  const op = args[0];
  const rest = args.slice(1);

  if (op === 'sha256') {
    process.stdout.write('sha256:' + sha256Hex(rest[0]) + '\n');
    return 0;
  }

  if (op === 'validate') {
    const p = rest[0];
    let st;
    try { st = fs.statSync(p); } catch (e) { return 3; }
    if (!st.isFile()) return 3;
    let data;
    try { data = loadReceipt(p); } catch (e) { return 4; }
    if (!data || typeof data !== 'object' || data.schema !== 'logicloom/adopt-receipt@1' || !Array.isArray(data.runs)) return 4;
    return 0;
  }

  if (op === 'recorded') {
    const p = rest[0];
    const data = loadReceipt(p);
    const files = {};
    const dirs = {};
    for (const run of (data.runs || [])) {
      if (!run || typeof run !== 'object') continue;
      if (['complete', 'partial', 'in-progress'].indexOf(run.status) === -1) continue;
      for (const w of (run.wrote || [])) {
        if (!w || typeof w !== 'object') continue;
        const wp = w.path, wk = w.kind;
        if (!wp || !wk) continue;
        if (wk === 'dir') { dirs[wp.replace(/\/+$/, '')] = true; }
        else if (wk === 'file') { files[wp] = w.sha256 || ''; }
      }
    }
    const out = [];
    for (const p2 of Object.keys(files)) out.push('file\t' + p2 + '\t' + files[p2]);
    for (const d of Object.keys(dirs)) out.push('dir\t' + d + '\t');
    if (out.length) process.stdout.write(out.join('\n') + '\n');
    return 0;
  }

  if (op === 'append-run') {
    const receiptPath = rest[0];
    const version = rest[1];
    const onlyJson = rest[2];
    const entriesPath = rest[3];
    const data = loadReceipt(receiptPath);
    const raw = fs.readFileSync(entriesPath, 'utf8').split('\n');
    const wrote = [];
    for (const line of raw) {
      if (!line) continue;
      const parts = line.split('\t');
      const kind = parts[0], p2 = parts[1];
      if (kind === 'file') {
        wrote.push({ target: 'harness', path: p2, kind: 'file', sha256: parts[2] || '' });
      } else {
        wrote.push({ target: 'harness', path: p2, kind: 'dir' });
      }
    }
    const only = JSON.parse(onlyJson);
    const run = {
      at: new Date().toISOString(),
      generator: 'logicloom-update-framework@' + version,
      status: 'complete',
      only: only,
      wrote: wrote,
      skipped: [],
      failed: [],
      notAttempted: []
    };
    data.runs.push(run);
    fs.writeFileSync(receiptPath, JSON.stringify(data, null, 2) + '\n');
    process.stdout.write(String(data.runs.length) + '\n');
    return 0;
  }

  return 2;
}

process.exit(main());
NODEEOF

run_json_tool() {
    if [ "$JSON_TOOL_KIND" = "node" ]; then
        "$JSON_TOOL_BIN" -e "$JSON_HELPER_NODE" -- "$@"
    else
        "$JSON_TOOL_BIN" -c "$JSON_HELPER_PY" "$@"
    fi
}

# ============================================
# Small helpers
# ============================================

# Ancestor directories of $1 (repo-relative, no leading slash), deepest first,
# excluding "." and "/".
path_ancestors() {
    local p="$1" dir
    dir="$(dirname "$p")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
        echo "$dir"
        dir="$(dirname "$dir")"
    done
}

# Resolve $1 (possibly relative) to an absolute, symlink-canonicalized path,
# and print it — or print nothing and return 1 if its parent dir does not
# exist on disk.
canon_path() {
    local rel="$1" abs dir base canon_dir
    case "$rel" in
        /*) abs="$rel" ;;
        *) abs="$REPO_ROOT/$rel" ;;
    esac
    dir="$(dirname "$abs")"
    base="$(basename "$abs")"
    if [ ! -d "$dir" ]; then
        return 1
    fi
    canon_dir="$(cd "$dir" && pwd -P)"
    printf '%s/%s\n' "$canon_dir" "$base"
}

default_version() {
    local conf="$REPO_ROOT/.logic-loom/config/architecture.conf"
    local v=""
    if [ -f "$conf" ]; then
        v="$(sed -n 's/^FRAMEWORK_VERSION=[[:space:]]*//p' "$conf" | head -1 | tr -d '[:space:]\r')"
    fi
    printf '%s\n' "$v"
}

normalize_version() {
    local v="$1"
    v="${v#v}"
    printf '%s\n' "$v"
}

# Look up a value already recorded in the receipt.
# $1 = kind (file|dir), $2 = path (no trailing slash for dir lookups)
lookup_recorded() {
    local kind="$1" path="$2"
    printf '%s\n' "$RECORDED_TSV" | awk -F'\t' -v k="$kind" -v p="$path" \
        '$1 == k && $2 == p { print $3; found=1 } END { if (!found) exit 1 }'
}

is_dir_recorded() {
    lookup_recorded "dir" "$1" >/dev/null 2>&1
}

# One temp file at a time; cleaned on every exit path (including exit 2 and
# a set -e abort), not only on a normal function return.
ENTRIES_TMP=""
cleanup_entries_tmp() { [ -n "$ENTRIES_TMP" ] && rm -f "$ENTRIES_TMP"; return 0; }
trap cleanup_entries_tmp EXIT

# Build the wrote[] entries for a list of repo-relative regular files into the
# TSV file $1 — the ONE place both record mode and --reconcile --apply produce
# entries, so they cannot drift ("exactly as record mode does").
#   * a file whose already-recorded sha256 (last writer wins across runs)
#     equals its current bytes is dropped — nothing changed since it was
#     last recorded;
#   * the same file named twice (or under two spellings that resolve to the
#     same path) is recorded once;
#   * every ancestor directory not already recorded as kind:dir is recorded
#     once, trailing-slash form, so a later upstream A under it passes the
#     ancestor rule.
# Prints "RECORDED <path>" per entry; sets ENTRY_COUNT to the number written.
ENTRY_COUNT=0
build_entries() {
    local entries_file="$1"; shift
    local -a seen_dirs=()
    local -a seen_files=()
    local rel sha existing_sha dir already sf sd
    ENTRY_COUNT=0
    for rel in "$@"; do
        already="false"
        for sf in "${seen_files[@]:-}"; do
            [ "$sf" = "$rel" ] && already="true" && break
        done
        [ "$already" = "true" ] && continue
        seen_files+=("$rel")

        sha="$(run_json_tool sha256 "$REPO_ROOT/$rel")"
        existing_sha=""
        if existing_sha="$(lookup_recorded file "$rel")"; then
            if [ "$existing_sha" = "$sha" ]; then
                continue
            fi
        fi
        printf 'file\t%s\t%s\n' "$rel" "$sha" >> "$entries_file"
        echo "RECORDED $rel"
        ENTRY_COUNT=$((ENTRY_COUNT + 1))

        while IFS= read -r dir; do
            [ -z "$dir" ] && continue
            if is_dir_recorded "$dir"; then
                continue
            fi
            already="false"
            for sd in "${seen_dirs[@]:-}"; do
                [ "$sd" = "$dir" ] && already="true" && break
            done
            [ "$already" = "true" ] && continue
            seen_dirs+=("$dir")
            printf 'dir\t%s/\t\n' "$dir" >> "$entries_file"
            echo "RECORDED $dir/"
            ENTRY_COUNT=$((ENTRY_COUNT + 1))
        done <<< "$(path_ancestors "$rel")"
    done
}

# "N entry|entries recorded in run M" — one wording for both modes.
report_recorded() {
    local n="$1" run="$2"
    if [ "$n" -eq 1 ]; then
        echo "record-update-writes: 1 entry recorded in run $run"
    else
        echo "record-update-writes: $n entries recorded in run $run"
    fi
}

# ============================================
# Argument parsing
# ============================================

MODE="record"
VERSION_ARG=""
APPLY="false"
PATHS=()
ROOT_OVERRIDDEN="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --root)
            [ $# -ge 2 ] || { echo "record-update-writes: --root needs a value" >&2; exit 1; }
            REPO_ROOT="$(cd "$2" && pwd -P)"
            ROOT_OVERRIDDEN="true"
            shift 2
            ;;
        --version)
            [ $# -ge 2 ] || { echo "record-update-writes: --version needs a value" >&2; exit 1; }
            VERSION_ARG="$2"
            shift 2
            ;;
        --reconcile)
            MODE="reconcile"
            shift
            ;;
        --apply)
            APPLY="true"
            shift
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do PATHS+=("$1"); shift; done
            ;;
        -*)
            echo "record-update-writes: unknown option: $1 (see --help)" >&2
            exit 1
            ;;
        *)
            PATHS+=("$1")
            shift
            ;;
    esac
done

if [ "$MODE" = "reconcile" ] && [ ${#PATHS[@]} -gt 0 ]; then
    echo "record-update-writes: --reconcile takes no paths (see --help)" >&2
    exit 1
fi
if [ "$MODE" = "record" ] && [ ${#PATHS[@]} -eq 0 ]; then
    echo "record-update-writes: nothing to do — pass one or more paths, or --reconcile (see --help)" >&2
    exit 1
fi
if [ "$APPLY" = "true" ] && [ "$MODE" != "reconcile" ]; then
    echo "record-update-writes: --apply is only valid with --reconcile" >&2
    exit 1
fi

if ! resolve_json_tool; then
    echo "record-update-writes: needs python3 or node to read and write .logicloom-adopt-receipt.json — neither is on PATH" >&2
    exit 2
fi

RECEIPT_PATH="$REPO_ROOT/$RECEIPT_NAME"

if [ ! -f "$RECEIPT_PATH" ]; then
    echo "record-update-writes: no $RECEIPT_NAME — this is a template clone or the receipt is gone; nothing to record" >&2
    exit 2
fi

VALIDATE_RC=0
run_json_tool validate "$RECEIPT_PATH" || VALIDATE_RC=$?
if [ "$VALIDATE_RC" -eq 3 ]; then
    echo "record-update-writes: no $RECEIPT_NAME — this is a template clone or the receipt is gone; nothing to record" >&2
    exit 2
elif [ "$VALIDATE_RC" -ne 0 ]; then
    echo "record-update-writes: $RECEIPT_NAME does not have schema $RECEIPT_SCHEMA (or its runs[] is malformed) — nothing to record" >&2
    exit 2
fi

RECORDED_TSV="$(run_json_tool recorded "$RECEIPT_PATH")"

VERSION="${VERSION_ARG:-$(default_version)}"
VERSION="$(normalize_version "$VERSION")"

# ============================================
# record mode
# ============================================

record_paths() {
    local -a resolved_rel=()
    local p abs
    for p in "${PATHS[@]}"; do
        if ! abs="$(canon_path "$p")"; then
            echo "record-update-writes: $p does not resolve inside the root" >&2
            exit 2
        fi
        case "$abs" in
            "$REPO_ROOT"/*) : ;;
            *)
                echo "record-update-writes: $p resolves outside the root" >&2
                exit 2
                ;;
        esac
        # A symlink is not a regular file, even when `test -f` would follow it
        # to one: /update-framework writes plain files, and recording a link
        # would attach a digest to bytes that live somewhere else.
        if [ -L "$abs" ] || [ ! -f "$abs" ]; then
            echo "record-update-writes: $p is not a regular file" >&2
            exit 2
        fi
        resolved_rel+=("${abs#"$REPO_ROOT"/}")
    done

    ENTRIES_TMP="$(mktemp "${TMPDIR:-/tmp}/loom-record-writes.XXXXXX")"
    build_entries "$ENTRIES_TMP" "${resolved_rel[@]}"

    if [ "$ENTRY_COUNT" -eq 0 ]; then
        echo "record-update-writes: nothing new to record"
        exit 0
    fi

    local run_count
    run_count="$(run_json_tool append-run "$RECEIPT_PATH" "$VERSION" '["update-framework"]' "$ENTRIES_TMP")"
    report_recorded "$ENTRY_COUNT" "$run_count"
}

# ============================================
# --reconcile
# ============================================

reconcile() {
    local sync_ref_file="$REPO_ROOT/$SYNC_REF_NAME"
    if [ ! -f "$sync_ref_file" ]; then
        echo "record-update-writes: --reconcile needs a resolvable $SYNC_REF_NAME — none found" >&2
        exit 2
    fi
    local sync_ref
    sync_ref="$(tr -d '[:space:]' < "$sync_ref_file")"
    if [ -z "$sync_ref" ] || ! git -C "$REPO_ROOT" cat-file -e "${sync_ref}^{commit}" 2>/dev/null; then
        echo "record-update-writes: --reconcile needs a resolvable $SYNC_REF_NAME — '$sync_ref' does not resolve to a commit in this repository (an adopted install has upstream history only after /update-framework has fetched it once; run that first, then retry)" >&2
        exit 2
    fi

    local -a recorded_dirs=()
    local line kind path
    while IFS=$'\t' read -r kind path _rest; do
        [ -z "$kind" ] && continue
        [ "$kind" = "dir" ] && recorded_dirs+=("$path")
    done <<< "$RECORDED_TSV"

    if [ ${#recorded_dirs[@]} -eq 0 ]; then
        echo "reconcile: nothing to record"
        exit 0
    fi

    local -a candidates=()
    local d f
    for d in "${recorded_dirs[@]}"; do
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            candidates+=("$f")
        done < <(git -C "$REPO_ROOT" ls-files -- "$d" 2>/dev/null || true)
    done

    local -a uniq_candidates=()
    if [ ${#candidates[@]} -gt 0 ]; then
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            uniq_candidates+=("$f")
        done < <(printf '%s\n' "${candidates[@]}" | sort -u)
    fi

    local -a reconcile_list=()
    local -a differs_list=()
    local tmpblob
    # bash 3.2: "${arr[@]}" on an EMPTY array is an unbound-variable error under
    # set -u (fixed only in 4.4), so never expand a possibly-empty array without
    # a count guard. Zero candidates is a real case: a receipt that recorded
    # directories nothing is tracked under yet.
    if [ ${#uniq_candidates[@]} -gt 0 ]; then
        for f in "${uniq_candidates[@]}"; do
            if lookup_recorded file "$f" >/dev/null 2>&1; then
                continue
            fi
            if ! git -C "$REPO_ROOT" cat-file -e "${sync_ref}:${f}" 2>/dev/null; then
                continue
            fi
            if [ -L "$REPO_ROOT/$f" ] || [ ! -f "$REPO_ROOT/$f" ]; then
                continue
            fi
            tmpblob="$(mktemp "${TMPDIR:-/tmp}/loom-reconcile.XXXXXX")"
            git -C "$REPO_ROOT" cat-file -p "${sync_ref}:${f}" > "$tmpblob" 2>/dev/null || true
            if cmp -s "$tmpblob" "$REPO_ROOT/$f"; then
                echo "RECONCILE $f"
                reconcile_list+=("$f")
            else
                echo "DIFFERS $f"
                differs_list+=("$f")
            fi
            rm -f "$tmpblob"
        done
    fi

    if [ ${#differs_list[@]} -gt 0 ]; then
        echo "if you accepted a DIFFERS file through /update-framework and edited it afterwards, record it explicitly: bash plugins/loom-maintenance/scripts/record-update-writes.sh <path>"
    fi

    if [ ${#reconcile_list[@]} -eq 0 ]; then
        echo "reconcile: nothing to record"
        exit 0
    fi

    if [ "$APPLY" != "true" ]; then
        echo "reconcile: ${#reconcile_list[@]} candidate(s) — re-run with --apply to record them"
        exit 0
    fi

    echo "reconcile: ${#reconcile_list[@]} candidate(s) — recording them now"

    # Exactly as record mode does: the same builder, so a RECONCILE file also
    # gets the kind:dir entries for any ancestor the receipt never recorded —
    # without them a later upstream A under that directory would still fail
    # the ancestor rule, and the second half of the rot gap would stay open.
    ENTRIES_TMP="$(mktemp "${TMPDIR:-/tmp}/loom-reconcile-writes.XXXXXX")"
    build_entries "$ENTRIES_TMP" "${reconcile_list[@]}"
    if [ "$ENTRY_COUNT" -eq 0 ]; then
        # Cannot happen (every RECONCILE path is unrecorded by construction),
        # but never append an empty run.
        echo "record-update-writes: nothing new to record"
        exit 0
    fi
    local run_count
    run_count="$(run_json_tool append-run "$RECEIPT_PATH" "$VERSION" '["reconcile"]' "$ENTRIES_TMP")"
    report_recorded "$ENTRY_COUNT" "$run_count"
}

if [ "$MODE" = "reconcile" ]; then
    reconcile
else
    record_paths
fi
