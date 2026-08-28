'use strict';
// units.js — enumerate the PAYLOAD's installable units, at the granularity a
// decision is actually made at.
//
// THE GRANULARITY POINT (why four buckets are enough)
// -----------------------------------------------------------------------------
// A file-level classifier would have to invent a fifth "merge" bucket, because
// `.claude/settings.json` and `.gitignore` are neither ours nor theirs — they
// are both. Classifying at the level the DECISION is made at removes the need:
//
//   * `.claude/settings.json` is not one unit. It is one unit per hook command
//     entry in the SHIPPED FRAGMENT. Each entry is independently additive (they
//     do not have it) or keep-theirs (they already run that exact command).
//   * `.gitignore` is not one unit. It is one unit per pattern line of the
//     SHIPPED BLOCK.
//   * Everything else genuinely is a path.
//
// At that granularity every unit has exactly one counterpart-or-not question,
// and additive / keep-theirs / replace / obsolete cover it.
//
// Reads the payload and the package's own merge/ artifacts. Writes nothing.

const fs = require('node:fs');
const path = require('node:path');
const manifestLib = require('./manifest');

// MERGE UNITS COME FROM THE ARTIFACT THE MERGE ACTUALLY SHIPS.
//
// This used to filter LogicLoom's own `.gitignore` by harness-owned prefix, and
// classify the payload's own `.claude/settings.json`. Both were a DIFFERENT set
// from what `--apply` installs — the merges install `merge/gitignore-block.txt`
// and `merge/settings-hooks-fragment.json` — and the difference was not
// theoretical: the prefix filter produced three patterns the curated block
// deliberately drops (`.devloop/`, `test-checkpoint-*`,
// `.claude/skill-index.json.bak`, all dead in the harness — see
// merge/gitignore-decisions.txt) and MISSED five the block does ship
// (`**/.claude/settings.local.json` and friends, which no prefix matches).
// The plan is the artifact under review, so a plan that promises 27 lines while
// the apply writes 29 different ones is the plan lying, however honestly the
// applier reports the mismatch afterwards.
//
// So the planner reads the same two files the merges do. Plan and apply cannot
// disagree about the SET, because there is only one set. The applier keeps its
// write-time cross-check anyway (refusal 8): a guarantee that costs nothing to
// re-assert is worth re-asserting.
const GITIGNORE_BLOCK = 'merge/gitignore-block.txt';
const SETTINGS_FRAGMENT = 'merge/settings-hooks-fragment.json';

function exists(p) { try { fs.statSync(p); return true; } catch (e) { return false; } }

// ── path units, from the manifest's include:/rename: rows ────────────────────
function pathUnits(payloadRoot, parsed) {
  const units = [];

  for (const inc of parsed.includes) {
    if (inc.path.indexOf('*') !== -1) continue; // globs are excludes in practice
    const src = path.join(payloadRoot, inc.path);
    const present = exists(src);
    units.push({
      id: 'path:' + inc.path,
      kind: exists(src) && fs.statSync(src).isDirectory() ? 'dir' : 'file',
      granularity: 'path',
      sourcePath: inc.path,
      targetPath: inc.path,
      action: 'copy',
      manifestLine: inc.lineNo,
      payloadPresent: present
    });
  }

  for (const r of parsed.renames) {
    const src = path.join(payloadRoot, r.path);
    units.push({
      id: 'rename:' + r.path,
      kind: 'file',
      granularity: 'path',
      sourcePath: r.path,
      targetPath: r.arg,
      action: 'copy',
      renamedFrom: r.path,
      manifestLine: r.lineNo,
      payloadPresent: exists(src)
    });
  }

  return units;
}

// ── json-key units: one per hook command entry in .claude/settings.json ──────
// The selector is a JSON Pointer-ish path plus the command string, because the
// ARRAY INDEX is not stable across an adopter's own edits — the applier matches
// on (event, matcher, command), never on index. That is recorded here rather
// than left for the applier to decide.
function settingsUnits(pkgRoot, settingsRelPath, strategy) {
  const units = [];
  if (!pkgRoot) return { units, error: SETTINGS_FRAGMENT + ' cannot be resolved — no package root was supplied' };
  const abs = path.join(pkgRoot, SETTINGS_FRAGMENT);
  let json = null;
  try { json = JSON.parse(fs.readFileSync(abs, 'utf8')); }
  catch (e) { return { units, error: SETTINGS_FRAGMENT + ' unreadable/invalid: ' + e.message }; }

  const hooks = json && json.hooks;
  if (!hooks || typeof hooks !== 'object') return { units, error: SETTINGS_FRAGMENT + ' has no hooks object' };

  for (const event of Object.keys(hooks)) {
    const groups = hooks[event];
    if (!Array.isArray(groups)) continue;
    for (const group of groups) {
      const matcher = typeof group.matcher === 'string' ? group.matcher : '';
      const inner = Array.isArray(group.hooks) ? group.hooks : [];
      for (const h of inner) {
        if (!h || h.type !== 'command' || typeof h.command !== 'string') continue;
        units.push({
          id: 'settings-hook:' + event + '|' + matcher + '|' + h.command,
          kind: 'json-key',
          granularity: 'json-key',
          sourcePath: settingsRelPath,
          targetPath: settingsRelPath,
          action: 'merge-json-key',
          strategy: strategy,
          mergeSource: SETTINGS_FRAGMENT,
          selector: {
            match: 'hooks-command',
            event: event,
            matcher: matcher,
            command: h.command
          },
          value: { type: 'command', command: h.command, timeout: h.timeout },
          payloadPresent: true
        });
      }
    }
  }
  return { units, error: null };
}

// ── gitignore line units ─────────────────────────────────────────────────────
function gitignoreUnits(pkgRoot, relPath, strategy) {
  const units = [];
  if (!pkgRoot) return { units, error: GITIGNORE_BLOCK + ' cannot be resolved — no package root was supplied' };
  const abs = path.join(pkgRoot, GITIGNORE_BLOCK);
  let text = null;
  try { text = fs.readFileSync(abs, 'utf8'); }
  catch (e) { return { units, error: GITIGNORE_BLOCK + ' unreadable: ' + e.message }; }

  const lines = text.split('\n');
  const seen = Object.create(null);
  for (const line of lines) {
    const pattern = line.trim();
    // Comments and blanks are the block's own commentary, not patterns. The
    // applier filters the block identically before counting what would land.
    if (!pattern.length || pattern.charAt(0) === '#') continue;
    if (seen[pattern]) continue;
    seen[pattern] = true;
    units.push({
      id: 'gitignore-line:' + pattern,
      kind: 'gitignore-line',
      granularity: 'line',
      sourcePath: relPath,
      targetPath: relPath,
      action: 'append-line',
      strategy: strategy,
      mergeSource: GITIGNORE_BLOCK,
      selector: { match: 'exact-pattern', pattern: pattern },
      value: pattern,
      payloadPresent: true
    });
  }
  return { units, error: null };
}

// ── author units: the rules files the package carries, not the payload ──────
// RESOLVED AGAINST THE PACKAGE ROOT, not the payload root, and that is the whole
// reason `author:` is a separate verb (see manifest.js). In a dev checkout the
// package root is packaging/adopt/; in a published package it is the package
// directory. `payload/rules/x.md` is the same relative path in both, which no
// payload-relative spelling manages.
//
// Granularity is `rules` — its own target, because installing the harness's
// operating instructions is a decision the adopter makes separately from
// installing the harness tree, and one of its modes writes into a file they own.
function authorUnits(pkgRoot, parsed) {
  const units = [];
  for (const a of parsed.authors) {
    const abs = path.join(pkgRoot, a.path);
    units.push({
      id: 'rules:' + a.arg,
      kind: 'file',
      granularity: 'rules',
      sourcePath: a.path,
      sourceRoot: 'package',
      sourceAbs: abs,
      targetPath: a.arg,
      action: 'copy',
      manifestLine: a.lineNo,
      payloadPresent: exists(abs)
    });
  }
  return units;
}

// ── the whole inventory ──────────────────────────────────────────────────────
function enumerate(payloadRoot, parsed, pkgRoot) {
  const errors = [];
  let units = pathUnits(payloadRoot, parsed);
  if (pkgRoot) units = units.concat(authorUnits(pkgRoot, parsed));
  else if (parsed.authors.length) {
    errors.push(`${parsed.authors.length} author: row(s) cannot be resolved — no package root was supplied`);
  }

  for (const m of parsed.merges) {
    if (m.path === '.claude/settings.json') {
      const r = settingsUnits(pkgRoot, m.path, m.arg);
      if (r.error) errors.push(r.error);
      units = units.concat(r.units);
    } else if (m.path === '.gitignore') {
      const r = gitignoreUnits(pkgRoot, m.path, m.arg);
      if (r.error) errors.push(r.error);
      units = units.concat(r.units);
    } else {
      errors.push(`merge: ${m.path} :: ${m.arg} — no strategy implemented for this path (manifest line ${m.lineNo})`);
    }
  }

  return { units, errors };
}

module.exports = {
  enumerate, pathUnits, authorUnits, settingsUnits, gitignoreUnits,
  GITIGNORE_BLOCK, SETTINGS_FRAGMENT
};
