'use strict';
// manifest.js — parser for packaging/adopt/payload-manifest.txt.
//
// The manifest is the SOURCE OF TRUTH for what the adopt package would install.
// This planner does not carry a second copy of that list; it reads the manifest,
// so overruling the boundary is still one file edit (the manifest's own header
// promises exactly that).
//
// Grammar (verbatim from the manifest header — every line carries a verb, there
// is no bare-path form):
//   include: <path-or-glob>
//   exclude: <path-or-glob>
//   rename:  <src> :: <dst>
//   merge:   <path> :: <strategy>
//   defer:   <path> :: <question>
// Precedence: an `exclude:` beats an `include:` covering the same path. That is
// the only precedence rule.
//
// Reads a file. Writes nothing.

const fs = require('node:fs');

const VERBS = ['include', 'exclude', 'rename', 'merge', 'defer'];

function parse(text) {
  const entries = [];
  const errors = [];
  const raw = String(text).split('\n');

  for (let i = 0; i < raw.length; i++) {
    const lineNo = i + 1;
    const line = raw[i];
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.charAt(0) === '#') continue;

    const m = /^([a-z]+):\s*(.*)$/.exec(trimmed);
    if (!m) {
      errors.push({ lineNo, line: trimmed, error: 'no verb — the manifest has no bare-path form' });
      continue;
    }
    const verb = m[1];
    const rest = m[2].trim();
    if (VERBS.indexOf(verb) === -1) {
      errors.push({ lineNo, line: trimmed, error: `unknown verb '${verb}'` });
      continue;
    }
    if (verb === 'include' || verb === 'exclude') {
      if (!rest) { errors.push({ lineNo, line: trimmed, error: 'empty path' }); continue; }
      entries.push({ verb, path: rest, lineNo });
    } else {
      const parts = rest.split('::');
      if (parts.length !== 2) {
        errors.push({ lineNo, line: trimmed, error: `'${verb}:' requires '<a> :: <b>'` });
        continue;
      }
      entries.push({ verb, path: parts[0].trim(), arg: parts[1].trim(), lineNo });
    }
  }
  return { entries, errors };
}

function load(file) {
  const text = fs.readFileSync(file, 'utf8');
  const parsed = parse(text);
  parsed.file = file;
  parsed.includes = parsed.entries.filter((e) => e.verb === 'include');
  parsed.excludes = parsed.entries.filter((e) => e.verb === 'exclude');
  parsed.renames = parsed.entries.filter((e) => e.verb === 'rename');
  parsed.merges = parsed.entries.filter((e) => e.verb === 'merge');
  parsed.defers = parsed.entries.filter((e) => e.verb === 'defer');
  return parsed;
}

// Glob semantics deliberately match the manifest's stated model: "globs match
// against `git ls-files` output". Only `*` (no `/`) and a trailing `/` are used
// in the file today; anything else is treated literally rather than guessed at.
function globToRegExp(glob) {
  let out = '^';
  for (const ch of glob) {
    if (ch === '*') out += '[^/]*';
    else if ('\\^$.|?+()[]{}'.indexOf(ch) !== -1) out += '\\' + ch;
    else out += ch;
  }
  // A directory entry is recursive (manifest header, `include:`).
  out += '(/.*)?$';
  return new RegExp(out);
}

// Does an exclude entry cover this repo-relative path?
function isExcluded(parsed, relPath) {
  for (const e of parsed.excludes) {
    const pat = e.path.replace(/\/$/, '');
    if (globToRegExp(pat).test(relPath)) return e;
  }
  return null;
}

module.exports = { parse, load, isExcluded, globToRegExp, VERBS };
