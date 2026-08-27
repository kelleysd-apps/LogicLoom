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
//     entry. Each entry is independently additive (they do not have it) or
//     keep-theirs (they already run that exact command).
//   * `.gitignore` is not one unit. It is one unit per pattern line.
//   * Everything else genuinely is a path.
//
// At that granularity every unit has exactly one counterpart-or-not question,
// and additive / keep-theirs / replace / obsolete cover it.
//
// Reads the payload. Writes nothing.

const fs = require('node:fs');
const path = require('node:path');
const manifestLib = require('./manifest');

// A .gitignore pattern line ships only if it names one of these harness-owned
// prefixes (PRE-8: "append ONLY the harness-specific block"). Everything else in
// LogicLoom's own .gitignore — package-lock.json, dist/, build/, coverage/,
// .vscode/ — is opinionated project config and is the adopter's call. Selecting
// by prefix rather than by line range means a reordered .gitignore cannot
// silently start shipping the hostile third.
const HARNESS_IGNORE_PREFIXES = [
  '.logic-loom/', '.loom-', '.claude/', '.sdd-', 'plugins/loom-',
  '.docs/agents/', '.docs/governance/', '.docs/research/', '.docs/memory/',
  '.brain/', '.devloop/', 'test-checkpoint-'
];

function isHarnessIgnoreLine(line) {
  const t = line.trim();
  if (!t || t.charAt(0) === '#') return false;
  const bare = t.replace(/^!/, '');
  for (const p of HARNESS_IGNORE_PREFIXES) {
    if (bare.indexOf(p) === 0) return true;
  }
  return false;
}

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
function settingsUnits(payloadRoot, settingsRelPath, strategy) {
  const units = [];
  const abs = path.join(payloadRoot, settingsRelPath);
  let json = null;
  try { json = JSON.parse(fs.readFileSync(abs, 'utf8')); }
  catch (e) { return { units, error: 'payload ' + settingsRelPath + ' unreadable/invalid: ' + e.message }; }

  const hooks = json && json.hooks;
  if (!hooks || typeof hooks !== 'object') return { units, error: 'payload settings.json has no hooks object' };

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
function gitignoreUnits(payloadRoot, relPath, strategy) {
  const units = [];
  const abs = path.join(payloadRoot, relPath);
  let text = null;
  try { text = fs.readFileSync(abs, 'utf8'); }
  catch (e) { return { units, error: 'payload ' + relPath + ' unreadable: ' + e.message }; }

  const lines = text.split('\n');
  for (const line of lines) {
    if (!isHarnessIgnoreLine(line)) continue;
    const pattern = line.trim();
    units.push({
      id: 'gitignore-line:' + pattern,
      kind: 'gitignore-line',
      granularity: 'line',
      sourcePath: relPath,
      targetPath: relPath,
      action: 'append-line',
      strategy: strategy,
      selector: { match: 'exact-pattern', pattern: pattern },
      value: pattern,
      payloadPresent: true
    });
  }
  return { units, error: null };
}

// ── the whole inventory ──────────────────────────────────────────────────────
function enumerate(payloadRoot, parsed) {
  const errors = [];
  let units = pathUnits(payloadRoot, parsed);

  for (const m of parsed.merges) {
    if (m.path === '.claude/settings.json') {
      const r = settingsUnits(payloadRoot, m.path, m.arg);
      if (r.error) errors.push(r.error);
      units = units.concat(r.units);
    } else if (m.path === '.gitignore') {
      const r = gitignoreUnits(payloadRoot, m.path, m.arg);
      if (r.error) errors.push(r.error);
      units = units.concat(r.units);
    } else {
      errors.push(`merge: ${m.path} :: ${m.arg} — no strategy implemented for this path (manifest line ${m.lineNo})`);
    }
  }

  return { units, errors };
}

module.exports = {
  enumerate, pathUnits, settingsUnits, gitignoreUnits,
  isHarnessIgnoreLine, HARNESS_IGNORE_PREFIXES
};
