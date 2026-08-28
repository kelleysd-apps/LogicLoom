'use strict';
// receipt.js — reading `.logicloom-adopt-receipt.json`.
//
// Split out of apply.js because the PLANNER now reads it too. The plan is still
// a pure read: nothing here writes, creates or touches a file. `writeReceipt`
// deliberately stays in apply.js, with the rest of the write half.
//
// The receipt is this tool's only memory. It answers three questions, and it is
// worth naming them because they are not the same question:
//
//   1. "Has this tool run here before?"        — priorRun()
//   2. "Did we write at or under this path?"   — provenance().wrote
//   3. "Is this file we MERGED into still      — provenance().digests
//       exactly what we left?"
//
// (3) is the one that makes a re-run safe. See lib/selfcaused.js.

const fs = require('node:fs');
const path = require('node:path');

const RECEIPT_SCHEMA = 'logicloom/adopt-receipt@1';
const RECEIPT_NAME = '.logicloom-adopt-receipt.json';

function receiptPath(root) { return path.join(root, RECEIPT_NAME); }

function readReceipt(root) {
  try {
    const j = JSON.parse(fs.readFileSync(receiptPath(root), 'utf8'));
    if (j && j.schema === RECEIPT_SCHEMA && Array.isArray(j.runs)) return j;
    return null;
  } catch (e) { return null; }
}

function priorRun(root) {
  const r = readReceipt(root);
  if (!r) return null;
  // Prefer the most recent run that actually WROTE something — a later no-op run
  // is still evidence of adoption, but it is not the run whose footprint the
  // report should name.
  let fallback = null;
  for (let i = r.runs.length - 1; i >= 0; i--) {
    const run = r.runs[i];
    if (run.status !== 'complete' && run.status !== 'partial') continue;
    if ((run.wrote || []).length) return run;
    if (!fallback) fallback = run;
  }
  return fallback;
}

function stripSlash(p) { return String(p || '').replace(/\/+$/, ''); }

// The union across EVERY run, not just the last one. A two-step install
// (`--only=all` then `--only=hooks`) writes its footprint across two runs, and
// the second run's own blocking items are caused by the first.
//
//   wrote    — every path any run recorded writing, slash-stripped
//   digests  — path -> digest, for the files we MERGED into. Last writer wins:
//              if run 2 merged again it left the file in a newer state.
function provenance(root) {
  const r = readReceipt(root);
  if (!r) return null;
  const wrote = [];
  const digests = Object.create(null);
  let runs = 0;
  for (const run of r.runs) {
    if (run.status !== 'complete' && run.status !== 'partial') continue;
    runs += 1;
    for (const w of (run.wrote || [])) {
      const p = stripSlash(w.path);
      if (!p) continue;
      if (wrote.indexOf(p) === -1) wrote.push(p);
      if (w.kind === 'merge' && typeof w.digest === 'string' && w.digest) digests[p] = w.digest;
    }
  }
  if (!runs) return null;
  return { wrote: wrote, digests: digests, runs: runs };
}

// Did an earlier run of ours write at, under, or above this path?
//
// "Above" is deliberate and is the `.claude/` case: git collapses an untracked
// directory to one entry, so the blocking item names `.claude/` while the
// receipt names `.claude/settings.json`. Both directions mean the same thing —
// that entry exists in the working tree because this tool put something there.
function wroteUnder(prov, relPath) {
  if (!prov) return false;
  const clean = stripSlash(relPath);
  if (!clean) return false;
  for (const wp of prov.wrote) {
    if (wp === clean || wp.indexOf(clean + '/') === 0 || clean.indexOf(wp + '/') === 0) return true;
  }
  return false;
}

module.exports = {
  RECEIPT_SCHEMA, RECEIPT_NAME, receiptPath, readReceipt, priorRun,
  provenance, wroteUnder, stripSlash
};
