'use strict';
// selfcaused.js — which blocking preconditions did THIS TOOL cause?
//
// THE DEFECT THIS CLOSES
// -----------------------------------------------------------------------------
// A successful `--apply` necessarily leaves the tree dirty with its own output:
// `.gitignore` is modified (we merged into it) and `.claude/` is untracked (we
// created it). Those are precisely the two conditions preconditions.js refuses
// on. So the second run — the one an agent makes to confirm idempotency, the
// one AGENT-INSTALL.md promises is "a no-op that says so" — exited 1 with
// `REFUSED — 2 blocking precondition(s)`, naming as an obstacle the footprint it
// had just reported creating. A successful install read as a failed one.
//
// WHY DISCOUNTING IS SAFE HERE, STATED IN FULL
// -----------------------------------------------------------------------------
// The precondition exists so an apply never writes into a tree holding
// unreviewed changes. Discounting it would be indefensible if a write could
// then land on top of someone's work. It cannot, and the reasons are structural
// rather than careful:
//
//   * Refusal 1 means the applier NEVER overwrites a file it did not create —
//     `copyFileNew` opens 'wx', so the kernel refuses an existing path. A file
//     the adopter edited after our run therefore exists, and is SKIPPED with
//     REFUSE-EXISTS. Their edit is not at risk from a re-run; it is not
//     reachable by one.
//   * Everything else the applier adds is a path that did not exist. A re-run
//     can add, never replace, so "no clean revert point" does not arise: the
//     receipt lists every path, which is the revert list.
//   * The two MERGES are the only writes that touch a file the adopter also
//     owns, and they are the one real exposure. So they are not discounted on
//     provenance at all — they are discounted only against a CONTENT DIGEST
//     recorded at the moment we left the file. Digest matches: the file is
//     byte-for-byte what we wrote, the dirtiness is entirely ours, nothing of
//     theirs is in it. Digest differs, or was never recorded: the adopter has
//     edited it since, THE BLOCK STANDS, and the report says why in those words.
//
// That is the answer to "what if the user edited a file we wrote between runs?"
// — the ordinary files are unreachable by refusal 1, and the merge targets are
// caught exactly, by content, and still block.
//
// This is NOT a `--force`:
//   * it is not settable by any flag or environment variable;
//   * it applies only to items this tool's own receipt accounts for;
//   * every discount is PRINTED, with the reason, on the run that takes it;
//   * a forged receipt buys nothing — an already-adopted repo classifies every
//     unit keep-theirs, so the apply writes nothing anyway, and forging a
//     matching digest requires already knowing the file's exact bytes.
//
// Reads the receipt. Writes nothing.

const path = require('node:path');

const receiptLib = require('./receipt');
const fsops = require('./fsops');
const preLib = require('./preconditions');

// Codes this tool can cause by having installed the harness once already.
const ADOPTION_CODES = ['ALREADY-ADOPTED', 'PARTIAL-ADOPTION'];

// Codes that describe a working-tree path being dirty or untracked. These are
// the F1 codes: caused by our own output sitting uncommitted.
const TREE_CODES = ['UNTRACKED-UNDER-TARGET', 'DIRTY-TARGET-PATH', 'DIRTY-MERGE-TARGET'];

// Paths the applier MERGES into rather than creates. Provenance alone never
// clears one of these; only a matching digest does.
function mergeSensitive() {
  const out = preLib.MERGE_TARGETS.slice();
  if (out.indexOf('CLAUDE.md') === -1) out.push('CLAUDE.md');
  return out;
}

function under(entry, p) {
  const e = receiptLib.stripSlash(entry);
  const q = receiptLib.stripSlash(p);
  return q === e || q.indexOf(e + '/') === 0;
}

// Every merge-sensitive path we recorded a digest for that sits at or under this
// blocking entry must still match. One mismatch blocks the whole entry: an edit
// to `.claude/settings.json` is a reason to refuse `.claude/`, because that is
// the entry git reports and the entry the write would go through.
function digestsHold(root, prov, entryPath) {
  const stale = [];
  for (const p of Object.keys(prov.digests)) {
    if (!under(entryPath, p)) continue;
    if (fsops.sha256File(path.join(root, p)) !== prov.digests[p]) stale.push(p);
  }
  return stale;
}

// Annotate IN PLACE. Each blocking item gains `selfCaused` (boolean) and, when
// true, `selfCausedReason`; when a discount was considered and refused, it gains
// `selfCausedRefused` so the report can say "we wrote this, and you have since
// changed it" rather than the generic remedy alone.
//
// Items are annotated, never removed. `preconditions.blocking` stays the
// complete list — a plan that quietly dropped an item would be a plan that
// hides what the tree looks like — and `applyReady` is computed over the ones
// that are not self-caused.
function annotate(root, blocking) {
  const prov = receiptLib.provenance(root);
  const discounted = [];
  const sensitive = mergeSensitive();

  for (const b of blocking) {
    b.selfCaused = false;
    if (!prov) continue;

    if (ADOPTION_CODES.indexOf(b.code) !== -1) {
      b.selfCaused = true;
      b.selfCausedReason =
        `this tool's own receipt records ${prov.runs} prior run(s) here, so the harness ` +
        'markers that raise this are its output, not a pre-existing install';
      discounted.push(b);
      continue;
    }

    if (TREE_CODES.indexOf(b.code) === -1) continue;
    if (!receiptLib.wroteUnder(prov, b.path)) continue;

    const entry = receiptLib.stripSlash(b.path);
    // A merge target named directly: nothing but a digest clears it.
    if (sensitive.indexOf(entry) !== -1 && !Object.prototype.hasOwnProperty.call(prov.digests, entry)) {
      b.selfCausedRefused =
        'this tool wrote here, but it MERGED into this file and no content digest was ' +
        'recorded for it (an older receipt). It cannot prove the file is still exactly ' +
        'what it left, so the block stands.';
      continue;
    }
    const stale = digestsHold(root, prov, entry);
    if (stale.length) {
      b.selfCausedRefused =
        'this tool wrote here, but ' + stale.join(', ') + ' — a file it MERGED into — has ' +
        'CHANGED since. That change is yours and unreviewed, so the block stands.';
      continue;
    }

    b.selfCaused = true;
    b.selfCausedReason =
      'this path is here because this tool put it here (see runs[].wrote[] in ' +
      receiptLib.RECEIPT_NAME + ')' +
      (sensitive.indexOf(entry) !== -1
        ? ', and it is byte-for-byte identical to what it left'
        : ', and a re-run can only add paths — refusal 1 skips anything that now exists');
    discounted.push(b);
  }

  return discounted;
}

module.exports = { annotate, ADOPTION_CODES, TREE_CODES, mergeSensitive };
