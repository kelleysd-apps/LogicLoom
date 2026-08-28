'use strict';
// bookkeeping.js — two things the plan owed a reader, both found by the first
// real-repo run of the tool rather than by the test suite.
//
// 1. THE TOOL'S OWN FILES, IN THE PLAN.
//    `--apply` writes two files nothing in `buckets.additive` mentions:
//    `.logicloom-adopt-receipt.json` (the record of the run) and, when `hooks`
//    is applied, `.claude/.logicloom-adopt-settings.json` (what the settings
//    merge inserted). Both were disclosed in the apply report and in the
//    uninstall procedure — after the fact. The PLAN is the artifact a user
//    reviews and approves, so a file that lands must appear in it. They are not
//    additive units: no manifest row names them, they are not harness content,
//    and an adopter uninstalling should be able to tell "the harness" from
//    "the installer's paperwork" at a glance. Hence a separate list with an
//    explicit owner.
//
// 2. A FILE COUNT THAT IS COMPARABLE TO WHAT THE APPLY REPORTS.
//    `counts.additive` counts UNITS — the granularity a decision is made at —
//    so `62` sat beside an apply reporting `WROTE 407` and an agent told to
//    "compare the plan's counts to what was written" found two correct numbers
//    that do not compare. `predict()` resolves the units to the paths a write
//    would actually create, by running the applier's OWN traversal in predict
//    mode (lib/fsops.js, `ctx.predictOnly`). Not a second implementation: the
//    same exclusion rows, the same refusals, the same `out.wrote` entries — so
//    the number cannot drift from the copy it predicts.
//
// Reads the payload. Writes nothing.

const path = require('node:path');

const fsops = require('./fsops');
const detectLib = require('./detect');
const receiptLib = require('./receipt');

const SETTINGS_SIDECAR = '.claude/.logicloom-adopt-settings.json';

// The tool's own files, with the condition under which each lands.
function list(plan) {
  const hooksWouldWrite = plan.buckets.additive.some((u) => u.granularity === 'json-key');
  const out = [{
    path: receiptLib.RECEIPT_NAME,
    owner: 'tool',
    kind: 'file',
    when: 'every --apply run, including a no-op one',
    purpose: 'the record of what this tool wrote here, and the uninstall procedure. ' +
             'Appended to, never replaced; a foreign file at this path is refused, not clobbered.',
    countedInWouldWrite: false,
    countedInWroteNote: 'written outside the unit worklist, so the apply report\'s WROTE count ' +
                        'does not include it — it is the record OF that count'
  }];
  if (hooksWouldWrite) {
    out.push({
      path: SETTINGS_SIDECAR,
      owner: 'tool',
      kind: 'file',
      when: '--only names `hooks` and the settings merge actually inserts something',
      purpose: 'exactly which hook matcher groups were inserted into your .claude/settings.json, ' +
               'so the uninstall step is mechanical and a re-run is a no-op.',
      countedInWouldWrite: true
    });
  }
  return out;
}

// Resolve the additive units to the paths a write would create.
//
// The four numbers mirror the four `--only` targets, so a reader can compare
// this to the apply report line by line. `total` is what `WROTE` will say for
// `--only=all,hooks` on a tree that has not moved.
function predict(plan, opts) {
  const additive = plan.buckets.additive;
  const out = {
    harness: 0,
    rules: additive.filter((u) => u.granularity === 'rules').length,
    gitignore: additive.some((u) => u.granularity === 'line') ? 1 : 0,
    hooks: additive.some((u) => u.granularity === 'json-key') ? 2 : 0,
    total: 0,
    resolvedFrom: {
      path: additive.filter((u) => u.granularity === 'path').length,
      rules: additive.filter((u) => u.granularity === 'rules').length,
      line: additive.filter((u) => u.granularity === 'line').length,
      'json-key': additive.filter((u) => u.granularity === 'json-key').length
    },
    unresolved: [],
    note: 'paths a write would CREATE — files and directories — not plan units. ' +
          'For `--only=all,hooks` on an unchanged tree this equals the apply report\'s WROTE. ' +
          'gitignore counts 1 (one fenced merge, whatever the pattern count); hooks counts 2 ' +
          '(the settings merge and its sidecar).'
  };

  if (!opts || !opts.manifest || !opts.payloadRoot) {
    out.unresolved.push('the payload manifest could not be loaded; harness paths were not resolved');
    out.harness = null;
    out.total = null;
    return out;
  }

  const ctx = {
    rootReal: opts.targetRoot,
    manifest: opts.manifest,
    payloadRoot: opts.payloadRoot,
    predictOnly: true
  };
  for (const u of additive) {
    if (u.granularity !== 'path') continue;
    const src = path.join(opts.payloadRoot, u.sourcePath);
    if (detectLib.statKind(src) === 'absent') {
      out.unresolved.push(u.sourcePath + ' is named by the manifest but is not in the payload');
      continue;
    }
    const walked = { wrote: [], skipped: [] };
    try {
      fsops.copyTree(src, path.join(opts.targetRoot, u.targetPath), u.targetPath, ctx, walked);
    } catch (e) {
      out.unresolved.push(u.targetPath + ': ' + ((e && e.message) || String(e)));
      continue;
    }
    out.harness += walked.wrote.length;
  }
  out.total = out.harness + out.rules + out.gitignore + out.hooks;
  return out;
}

module.exports = { list, predict, SETTINGS_SIDECAR };
