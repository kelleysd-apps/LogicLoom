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
# NEVER runs mutating git. Both modes run read-only git only (ls-files,
# cat-file -e / -p, rev-parse, merge-base --is-ancestor): record mode needs
# it to resolve the upstream blob whose digest it records (upstream_blob_sha
# below), and both modes need it to prove .sdd-sync-ref is upstream's.
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
# UNINSTALL: runs[] is the single source of truth; `uninstall` is a VIEW over
# it, not a second copy of the record. `packaging/adopt/lib/apply.js`'s
# uninstallProcedure() derives `uninstall` fresh from the COMPLETE receipt.runs
# every time it runs (readReceipt() loads the full on-disk runs[] — including
# any this script appended — before recomputing), so a run this script adds is
# already correctly covered the next time it runs. This script therefore never
# tries to reimplement that derivation (its prose steps, its anchor text, its
# sha256/pre-merge-state handling) as a second writer in bash/python/node that
# would have to be kept byte-for-byte in sync with apply.js forever. Instead,
# every `append-run` REPLACES the receipt's `uninstall` with a STALE MARKER:
# a cached `uninstall` computed from a SHORTER runs[] is now provably
# incomplete — it cannot list a path this run just recorded — and a wrong list
# that looks authoritative is worse than none. The marker carries nothing
# runnable (no remove.files, no steps): `stale: true`, `invalidatedByRun`, why,
# the exact command that regenerates it, and what the record still holds
# meanwhile. It is written INTO the receipt rather than only into this comment
# because the receipt is where the install report told the adopter the
# procedure lives — a key that silently vanished would leave them with nothing
# to explain it. `packaging` is stripped from every adopted/customer tree
# (payload-manifest.txt), so apply.js itself never ships there; a fresh,
# complete `uninstall` comes back the next time the adopter runs
#     npx logicloom init --apply --only=<the targets the install used>
# (`--only` is REQUIRED with `--apply`; a bare `--apply` is refused with exit
# 2). On a clean tree with everything already installed that re-apply exits 0
# and writes no files. It is NOT unconditional: it is REFUSED — nothing
# written, the marker stays — while a merge target (.gitignore,
# .claude/settings.json, CLAUDE.md) has uncommitted changes, which is exactly
# the state right after an /update-framework that touched one; commit first.
# And a newer package payload may add files that are new to it (never
# overwriting an existing one). Until regenerated, a path this script records
# is still visible to extract-proposals.sh's ownership filter (so it can
# receive proposals); it is just not listed under `uninstall.remove.files`. A
# 6.x-installer receipt that never goes through this script is untouched.
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
                sha256 digest of an UPSTREAM BLOB -- NEVER the working tree's
                current bytes, so recording a file you customised after
                accepting it stamps what LogicLoom wrote, not your edit) and,
                for every ancestor directory not already recorded, one
                `kind:"dir"` entry — all inside ONE new run appended to
                runs[]. Which upstream blob: the path's blob at .sdd-sync-ref
                and at refs/loom-upstream/main (present during, and possibly
                left over after, an /update-framework run) are the two
                candidates; when the file on disk is byte-identical to one of
                them, that one is what LogicLoom wrote here (mid-run, the
                clean-apply just landed the refs/loom-upstream/main bytes
                while .sdd-sync-ref still names the previous commit); when
                it matches neither -- your own edit -- the .sdd-sync-ref
                blob is recorded, and a later uninstall compares, mismatches,
                and KEEPS the file. The disk is read only to choose between
                two upstream digests; the recorded digest is always one of
                theirs. A path with no blob at either location is REFUSED
                (exit 2, nothing written) rather than guessed from disk
                bytes. .sdd-sync-ref is a candidate ONLY when it is provably
                LogicLoom's own record: a hex object name that
                refs/loom-upstream/main exists locally AND reaches (the
                same rule /update-framework itself applies to the file). A
                sync-ref that fails that test -- a symbolic name, your own
                commit written there, or ANY value while upstream history
                has not been fetched -- is simply not a candidate, so with
                nothing at refs/loom-upstream/main either the path is
                REFUSED with the remedy (run /update-framework, i.e. bash
                plugins/loom-maintenance/scripts/extract-proposals.sh, so
                upstream history is fetched; then retry). Hex shape alone
                never proves who wrote the sync-ref. A path whose already-recorded sha256 already matches
                the resolved upstream digest is dropped (nothing changed
                upstream since it was last recorded); when every requested
                path drops out this way, nothing is written and the script
                prints "nothing new to record" and exits 0.

  --reconcile [--apply]
                Recover the past. Needs a .sdd-sync-ref that is provably
                LogicLoom's own record (the same rule as record mode: a hex
                object name reachable from a locally present
                refs/loom-upstream/main) -- anything else exits 2 with the
                remedy and lists nothing, because "byte-identical to the
                sync-ref blob" proves upstream authorship only when the
                sync-ref commit is upstream's. Lists, for every file
                `git ls-files` finds under a directory this receipt already
                recorded as a `dir`, that is NOT itself recorded as a `file`
                and exists at .sdd-sync-ref:
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

UNINSTALL: runs[] is the single source of truth. This script never rebuilds
the receipt's derived `uninstall` object (packaging/adopt/lib/apply.js's
uninstallProcedure() is the one place that does, and `packaging` never ships
to an adopted repo) — instead, every run this script appends REPLACES
`uninstall` with a stale marker (stale: true, invalidatedByRun, why,
regenerate, untilThen — nothing runnable), so the receipt never carries a
cached list that a just-recorded path is provably missing from, and still
says in-file why and how to get it back. A fresh, complete `uninstall` comes
back the next time you run
  npx logicloom init --apply --only=<the targets your install used>
(`--only` is required; a bare `--apply` is refused). On a clean tree with
everything already installed it exits 0 and writes nothing. It is REFUSED —
nothing written, the marker stays — while .gitignore, .claude/settings.json
or CLAUDE.md has uncommitted changes: commit them, then re-run. Until then, a
recorded path is still visible to extract-proposals.sh's ownership filter.

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

def stale_uninstall_marker(run_index):
    return {
        "stale": True,
        "invalidatedByRun": run_index,
        "why": ("runs[" + str(run_index) + "] was appended by plugins/loom-maintenance/scripts/"
                "record-update-writes.sh (/update-framework) after this object was last derived. "
                "`uninstall` is a VIEW over runs[], not a second record: a copy derived from a "
                "shorter runs[] cannot list the paths that run recorded, so it was replaced by "
                "this marker rather than left looking complete. Nothing in this marker is a list "
                "to run."),
        "regenerate": ("npx logicloom init --apply --only=<the targets your install runs used; see "
                       "each runs[].only above, e.g. all> -- when everything is already installed "
                       "and the working tree is clean it exits 0, writes no files, and rewrites this "
                       "object from the complete runs[]. It is REFUSED (nothing written, this marker "
                       "stays) while a merge target (.gitignore, .claude/settings.json, CLAUDE.md) "
                       "has uncommitted changes: commit them, then re-run. A newer package payload "
                       "may also add files that are new to it; it never overwrites an existing one."),
        "untilThen": ("runs[].wrote[] above is the complete record: every kind:file entry carries "
                      "the sha256 of the bytes this harness left there (a mismatch means the file "
                      "changed since -- yours to review, never something to delete on this "
                      "record's word), every kind:dir entry is a directory it created, and a "
                      "kind:merge entry is a file it only edited inside a fence, never one to "
                      "delete by path.")
    }

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
        # A cached 'uninstall' (from a prior `npx logicloom init --apply
        # --only=...`) was derived from a SHORTER runs[] than this one -- it
        # cannot list the path(s) just appended, so it is now provably
        # incomplete. Replace it with a marker that carries NOTHING runnable
        # (no remove.files, no steps) but says, in the receipt itself, why the
        # list is gone and how to get it back -- the receipt is where the
        # install report told the adopter to look. See the UNINSTALL comment
        # near the top of this file for why this script does not recompute it.
        # Text is ASCII-only and built identically in the node helper below, so
        # both JSON tools write byte-identical receipts.
        if 'uninstall' in data:
            del data['uninstall']
        data['uninstall'] = stale_uninstall_marker(len(data['runs']) - 1)
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

// Byte-for-byte the same text as the python helper's stale_uninstall_marker.
function staleUninstallMarker(runIndex) {
  return {
    stale: true,
    invalidatedByRun: runIndex,
    why: 'runs[' + runIndex + '] was appended by plugins/loom-maintenance/scripts/' +
         'record-update-writes.sh (/update-framework) after this object was last derived. ' +
         '`uninstall` is a VIEW over runs[], not a second record: a copy derived from a ' +
         'shorter runs[] cannot list the paths that run recorded, so it was replaced by ' +
         'this marker rather than left looking complete. Nothing in this marker is a list ' +
         'to run.',
    regenerate: 'npx logicloom init --apply --only=<the targets your install runs used; see ' +
                'each runs[].only above, e.g. all> -- when everything is already installed ' +
                'and the working tree is clean it exits 0, writes no files, and rewrites this ' +
                'object from the complete runs[]. It is REFUSED (nothing written, this marker ' +
                'stays) while a merge target (.gitignore, .claude/settings.json, CLAUDE.md) ' +
                'has uncommitted changes: commit them, then re-run. A newer package payload ' +
                'may also add files that are new to it; it never overwrites an existing one.',
    untilThen: 'runs[].wrote[] above is the complete record: every kind:file entry carries ' +
               'the sha256 of the bytes this harness left there (a mismatch means the file ' +
               'changed since -- yours to review, never something to delete on this ' +
               'record\'s word), every kind:dir entry is a directory it created, and a ' +
               'kind:merge entry is a file it only edited inside a fence, never one to ' +
               'delete by path.'
  };
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
    // See the matching comment in the python helper's 'append-run' above --
    // a cached 'uninstall' was derived from a shorter runs[] and is now
    // provably incomplete, so it is replaced by the stale marker (nothing
    // runnable; says why and how to regenerate) rather than left stale or
    // silently dropped.
    if (Object.prototype.hasOwnProperty.call(data, 'uninstall')) delete data.uninstall;
    data.uninstall = staleUninstallMarker(data.runs.length - 1);
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

# Resolve .sdd-sync-ref to a commit that is PROVABLY LogicLoom's own record
# -- hex-shaped AND (round-2 finding 1) reachable from refs/loom-upstream/main,
# the same loom_sync_ref_is_loom_record rule release-migrations.sh's scanner
# enforces (shared, .logic-loom/lib/release-migrations.sh), which itself
# mirrors extract-proposals.sh's own reachability check on this same file.
# Without that history fetched, hex shape alone proves nothing -- a customer's
# own commit sha (or a symbolic name that resolves to one) is indistinguishable
# from LogicLoom's record by shape, and recording a "match" against it would
# stamp the wrong digest as what LogicLoom wrote. Prints the (whitespace-
# trimmed) ref/sha and returns 0, or prints nothing and returns 1 -- an
# unresolvable, missing, or unprovable sync-ref is not an error here (record
# mode falls back to refs/loom-upstream/main; only --reconcile treats an
# unresolvable one as fatal, at its own call site above -- --reconcile's own
# validation is a separate, narrower check: only that the file resolves to A
# commit in this repository, not that it is provably LogicLoom's).
resolve_sync_ref() {
    local sync_ref_file="$REPO_ROOT/$SYNC_REF_NAME" sync_ref
    [ -f "$sync_ref_file" ] || return 1
    sync_ref="$(tr -d '[:space:]' < "$sync_ref_file")"
    [ -n "$sync_ref" ] || return 1
    git -C "$REPO_ROOT" cat-file -e "${sync_ref}^{commit}" 2>/dev/null || return 1
    loom_sync_ref_is_loom_record "$sync_ref" "$REPO_ROOT" || return 1
    printf '%s\n' "$sync_ref"
}

# The sha256 of the UPSTREAM BLOB for repo-relative path $1 -- what LogicLoom
# actually WROTE there, never the working tree's current bytes. A file the
# adopter customised after accepting it must record the digest of the
# pristine upstream bytes, so a later comparison against the (customised)
# disk copy correctly MISMATCHES and keeps it (see the OWNERSHIP RULE / THE
# DELIBERATE ASYMMETRY comments near the top of this file, and
# packaging/adopt/lib/apply.js's uninstallProcedure(), whose step-1 prose is
# "digest MATCHES -> safe to delete; MISMATCHES -> KEEP").
#
# TWO candidates, both provably LogicLoom's: the path's blob at the
# .sdd-sync-ref commit (the version this repo says it is synced to) and at
# refs/loom-upstream/main (the ad-hoc fetch ref extract-proposals.sh
# maintains). The second one matters DURING an /update-framework run:
# record-update-writes.sh runs right after a clean-add/clean-apply lands
# (Step 5/7b), which wrote `git show refs/loom-upstream/main:P > P` -- the
# NEW bytes -- while .sdd-sync-ref is not advanced until Step 6/8, after
# recording. So mid-run, for a path that exists at BOTH commits (a
# modification, the common case), the sync-ref blob is the OLD version and
# refs/loom-upstream/main is what LogicLoom just wrote. Preferring sync-ref
# unconditionally stamps the stale digest (and, since the install receipt
# already carries it, drops the entry as "nothing new"); preferring the
# scratch ref unconditionally is wrong OUTSIDE a run, because only
# `extract-proposals.sh --dry-run` prunes that ref (extract-proposals.sh:762)
# -- the extract path leaves it behind, so its mere presence does not mean an
# update is in progress.
#
# THE CHOICE RULE, and why it is not a guess: when the file on disk is
# byte-identical to one candidate, that candidate is what LogicLoom wrote
# here (the OWNERSHIP RULE at the top of this file: a byte-identical copy of
# an upstream blob can only have come from upstream). When it matches neither
# -- the adopter's own edit, e.g. a conflict-review merge recorded by name --
# the sync-ref blob is recorded; both candidates mismatch the disk anyway, so
# either keeps the file at uninstall, and sync-ref is the stable one. The disk
# digest is computed ONLY to choose between two upstream digests and is never
# itself recorded: every digest this function returns is an upstream blob's.
#
# Prints "sha256:<hex>" and returns 0 on success. Returns 1 if the path
# resolves to a blob at NEITHER location (or a candidate blob cannot be
# hashed) -- callers MUST refuse to record rather than fall back to hashing
# disk bytes; this tool never guesses.
#
# Every risky command in these two functions is the condition of an `if`/`!`,
# never a bare statement -- under `set -e` a bare failing command substitution
# would abort the whole script right there (skipping the tmp-file cleanup)
# instead of letting the function return 1 for its caller to handle.

# "sha256:<hex>" of git blob $1 ("<rev>:<path>"), hashed by the same JSON
# tool that hashes everything else here; prints nothing and returns 1 on any
# failure.
blob_sha256() {
    local blob_ref="$1" tmp sha
    tmp="$(mktemp "${TMPDIR:-/tmp}/loom-upstream-blob.XXXXXX")"
    if ! git -C "$REPO_ROOT" cat-file -p "$blob_ref" > "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 1
    fi
    if ! sha="$(run_json_tool sha256 "$tmp")"; then
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    [ -n "$sha" ] || return 1
    printf '%s\n' "$sha"
}

upstream_blob_sha() {
    local rel="$1" ref sync_cand up_cand disk_sha cand sha first_sha
    sync_cand=""; up_cand=""; disk_sha=""; first_sha=""
    # A candidate must be a BLOB at that commit: `cat-file -e` is also true
    # for a tree of the same name, and `cat-file -p` on a tree prints its
    # listing -- hashing that would stamp a digest of a directory listing as
    # "the bytes LogicLoom wrote", which is nonsense (harmless at uninstall,
    # since it can never match a file, but a lie in the record).
    if ref="$(resolve_sync_ref)" && [ -n "$ref" ] \
       && [ "$(git -C "$REPO_ROOT" cat-file -t "${ref}:${rel}" 2>/dev/null)" = "blob" ]; then
        sync_cand="${ref}:${rel}"
    fi
    if git -C "$REPO_ROOT" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 \
       && [ "$(git -C "$REPO_ROOT" cat-file -t "refs/loom-upstream/main:${rel}" 2>/dev/null)" = "blob" ]; then
        up_cand="refs/loom-upstream/main:${rel}"
    fi
    [ -n "$sync_cand" ] || [ -n "$up_cand" ] || return 1
    # With ONE candidate there is nothing to choose; the disk is not read.
    if [ -n "$sync_cand" ] && [ -n "$up_cand" ]; then
        if ! disk_sha="$(run_json_tool sha256 "$REPO_ROOT/$rel")"; then
            disk_sha=""
        fi
    fi
    for cand in "$sync_cand" "$up_cand"; do
        [ -n "$cand" ] || continue
        if ! sha="$(blob_sha256 "$cand")" || [ -z "$sha" ]; then
            return 1
        fi
        if [ -n "$disk_sha" ] && [ "$sha" = "$disk_sha" ]; then
            printf '%s\n' "$sha"
            return 0
        fi
        [ -n "$first_sha" ] || first_sha="$sha"
    done
    [ -n "$first_sha" ] || return 1
    printf '%s\n' "$first_sha"
}

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
#   * each entry's sha256 is upstream_blob_sha()'s digest — what LogicLoom
#     wrote — NEVER a hash of the file's current disk bytes; a path with no
#     resolvable upstream blob aborts the whole call (exit 2), nothing
#     partially written;
#   * a file whose already-recorded sha256 (last writer wins across runs)
#     equals that upstream digest is dropped — upstream hasn't changed since
#     it was last recorded, so there is nothing new to say;
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

        # The entries file is TAB-separated, one entry per LINE: a path
        # holding a tab or a newline cannot be carried through it without
        # being split into the wrong columns or rows -- which would stamp a
        # digest onto a path that is not the one asked for. Refuse loudly;
        # never silently mis-record. (git permits both characters in a
        # filename; nothing LogicLoom ships uses either.)
        case "$rel" in
            *$'\t'*|*$'\n'*)
                echo "record-update-writes: refusing to record a path whose name contains a tab or newline (cannot be carried through this tool's entry format without corrupting the record): $(printf '%q' "$rel")" >&2
                exit 2 ;;
        esac

        if ! sha="$(upstream_blob_sha "$rel")" || [ -z "$sha" ]; then
            echo "record-update-writes: $rel has no resolvable upstream blob (checked $SYNC_REF_NAME and refs/loom-upstream/main) -- refusing to record; this tool records what LogicLoom actually wrote, never a guess from disk bytes. An adopted install has upstream history only after /update-framework has fetched it (bash plugins/loom-maintenance/scripts/extract-proposals.sh does that fetch): run that first, then retry. If the path still resolves nowhere, upstream never had it -- it is not a file LogicLoom wrote here, and it must not be recorded." >&2
            exit 2
        fi
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

# Shared with release-migrations.sh (the scanner): the sync-ref provenance
# rule (round-2 finding 1) lives in exactly one place so both callers stay in
# lockstep instead of drifting into two copies. See
# loom_sync_ref_is_loom_record's own comment for the rule itself. Sourced
# here, AFTER --root has been parsed (not at top-of-file, before REPO_ROOT
# could still be the script's own location) — the lib lives inside the repo
# --root names, which is the fixture/scratch tree under test, not
# necessarily this script's own checkout.
if [ -f "$REPO_ROOT/.logic-loom/lib/release-migrations.sh" ]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/.logic-loom/lib/release-migrations.sh"
fi
if ! declare -F loom_sync_ref_is_loom_record >/dev/null 2>&1; then
    # The --root tree does not carry the shared lib (or carries a version
    # that predates the function). That is not a hypothetical: the lib
    # itself first ships in the same release as this script, and
    # /update-framework is proposal-based SELECTIVE adoption -- a 6.x
    # install can accept this script and decline the lib, or run this
    # script before the lib's own proposal has landed. Sourcing is therefore
    # sometimes impossible, and the one justified duplicate is the SAME
    # STRICT rule, byte-for-byte in effect: hex shape AND refs/loom-upstream/
    # main present AND reachable. A looser fallback (hex shape alone, the
    # pre-round-2 rule) would make the tree that is MOST likely to be a
    # customer's mid-migration 6.x install the one place a forged sync-ref
    # still stamps a customer's own digest as LogicLoom's -- exactly the
    # hole round-2 finding 1 closes. When the lib IS present it wins
    # (defined above); this definition only fills the gap, so the two can
    # never disagree on a tree that has the lib.
    loom_sync_ref_is_loom_record() {
        local sync_ref="$1" root="${2:-$REPO_ROOT}"
        [ -n "$sync_ref" ] || return 1
        case "$sync_ref" in *[!0-9a-fA-F]*) return 1 ;; esac
        [ "${#sync_ref}" -ge 7 ] && [ "${#sync_ref}" -le 64 ] || return 1
        git -C "$root" rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1 || return 1
        git -C "$root" merge-base --is-ancestor "$sync_ref" refs/loom-upstream/main 2>/dev/null || return 1
        return 0
    }
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
    # Round-2 finding 1, --reconcile's half: "byte-identical to the sync-ref
    # blob" proves upstream authorship ONLY when the sync-ref commit is
    # provably upstream's. Resolving to SOME commit is not that: a customer's
    # own commit written into the file resolves fine, and every file they
    # committed there is then byte-identical to "the sync-ref blob" -- a
    # RECONCILE line (a recommendation to stamp it as LogicLoom's) on
    # evidence that is not LogicLoom's. --apply would already be stopped at
    # build_entries/upstream_blob_sha (the same rule), but the LISTING is the
    # recommendation, so the same rule gates it here, up front, with the
    # same remedy. Doubt -> refuse and ask, never list.
    if ! loom_sync_ref_is_loom_record "$sync_ref" "$REPO_ROOT"; then
        echo "record-update-writes: --reconcile refuses: $SYNC_REF_NAME ('$sync_ref') is not provably LogicLoom's own record — it must be a hex object name that refs/loom-upstream/main exists locally AND reaches (the rule /update-framework itself applies to this file); refs/loom-upstream/main is absent here, or does not reach that commit. Nothing listed, nothing written. Run /update-framework (bash plugins/loom-maintenance/scripts/extract-proposals.sh) so upstream history is fetched, then retry; if it still refuses, the sync-ref names a commit that is not upstream's — repair it per KNOWN_ISSUES.md rather than recording against it." >&2
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
        # Round-2 finding 5: -z / NUL-delimited, not plain `ls-files -- "$d"`.
        # Without -z, git C-quotes a path containing a quote, backslash, or
        # non-ASCII byte (e.g. `"weird\"file.sh"`) in its default output --
        # `while IFS= read -r f` then takes that quoted, escaped LITERAL as
        # the path, which never matches a real file on disk and silently
        # drops the candidate instead of reconciling it. `-z` prints raw
        # bytes, NUL-terminated; `read -r -d ''` splits on NUL and needs no
        # bash version newer than 3.2 (§7, .docs/policies/shell-idiom-policy.md).
        while IFS= read -r -d '' f; do
            [ -z "$f" ] && continue
            candidates+=("$f")
        done < <(git -C "$REPO_ROOT" ls-files -z -- "$d" 2>/dev/null || true)
    done

    # Dedupe WITHOUT joining on newlines: a `printf '%s\n' | sort -u` round
    # trip splits a path that itself contains a newline into two bogus
    # candidates, each of which then fails the `-f` test below and is
    # dropped without a word -- the same silent-skip class as finding 5. A
    # plain nested loop (bash 3.2 has no associative arrays) keeps every
    # byte of every candidate intact. A candidate whose name holds a tab or
    # newline is then skipped LOUDLY here rather than reaching the
    # tab-separated, line-per-entry record (build_entries refuses those).
    local -a uniq_candidates=()
    local u dup
    local -a odd_seen=()
    if [ ${#candidates[@]} -gt 0 ]; then
        for f in "${candidates[@]}"; do
            # Dedupe FIRST: nested recorded dirs list the same file once per
            # ancestor, and an odd name must be reported once, not once per
            # ancestor.
            dup="false"
            for u in "${uniq_candidates[@]:-}" "${odd_seen[@]:-}"; do
                [ "$u" = "$f" ] && dup="true" && break
            done
            [ "$dup" = "true" ] && continue
            case "$f" in
                *$'\t'*|*$'\n'*)
                    odd_seen+=("$f")
                    echo "record-update-writes: --reconcile skipping a path whose name contains a tab or newline (this tool cannot record it; nothing about it is decided): $(printf '%q' "$f")" >&2
                    continue ;;
            esac
            uniq_candidates+=("$f")
        done
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
