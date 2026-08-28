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
//   author:  <pkg-relative src> :: <install path>
//
// `author:` IS A SIXTH VERB AND IT WAS ADDED, NOT IMPROVISED. Every other verb
// names a path IN THE PAYLOAD — the harness tree, resolved against the payload
// root. The three `.claude/rules/*.md` files are not in that tree: they are
// authored by the adopt package FOR the adopter, shipped inside the package
// beside merge/, and resolved against the PACKAGE root. Spelling them as
// `rename:` would make units.js look for them under the payload root, where in
// a packed release they do not live — a row that resolves in a dev checkout and
// silently vanishes when published. A different resolution base is a different
// verb.
//
// Precedence: an `exclude:` beats an `include:` covering the same path. That is
// the only precedence rule.
//
// Reads a file. Writes nothing.

const fs = require('node:fs');

const VERBS = ['include', 'exclude', 'rename', 'merge', 'defer', 'author'];

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
  parsed.authors = parsed.entries.filter((e) => e.verb === 'author');
  return parsed;
}

// Glob semantics deliberately match the manifest's stated model: "globs match
// against `git ls-files` output". Only `*` (no `/`) and a trailing `/` are used
// in the file today; anything else is treated literally rather than guessed at.
// `recursive` (the default) also matches everything beneath the glob, which is
// what "a directory entry is recursive" means in the manifest header. Passing
// false gives the EXACT-ENTRY form, which isExcluded needs to tell
// `features/README.md` (the glob-matched entry itself) from `features/wip/x.md`
// (something beneath it). Built here rather than by rewriting a compiled
// regex's `.source`, which quietly failed on the escaped `\/`.
function globToRegExp(glob, recursive) {
  let out = '^';
  for (const ch of glob) {
    if (ch === '*') out += '[^/]*';
    else if ('\\^$.|?+()[]{}'.indexOf(ch) !== -1) out += '\\' + ch;
    else out += ch;
  }
  out += recursive === false ? '$' : '(/.*)?$';
  return new RegExp(out);
}

// Does an exclude entry cover this repo-relative path?
//
// THE TRAILING SLASH IS SEMANTIC, and dropping it is a real bug rather than a
// tidy-up. The manifest carries `exclude: features/*/` beside
// `include: features/README.md`. Stripping the slash turns that pattern into
// `features/*`, which matches `features/README.md` — so the per-feature content
// exclusion silently swallows the two files the manifest goes out of its way to
// ship, and `features/README.md` is cited by name from CLAUDE.md's See Also list.
//
// So a pattern ending in `/` matches DIRECTORIES and their contents only. That
// needs a fact a path string does not carry, hence `isDir`. A caller that cannot
// say passes `undefined`, and the pattern then matches only paths strictly
// BENEATH the glob — never the glob-matched entry itself. Failing toward "not
// excluded" is the right direction here: an exclude that fires by accident drops
// a file the manifest promised to ship, silently.
function isExcluded(parsed, relPath, isDir) {
  for (const e of parsed.excludes) {
    const dirOnly = /\/$/.test(e.path);
    const pat = e.path.replace(/\/+$/, '');
    if (!globToRegExp(pat).test(relPath)) continue;
    if (!dirOnly) return e;
    // Exactly the glob-matched entry: excluded only if we know it is a directory.
    if (globToRegExp(pat, false).test(relPath)) { if (isDir === true) return e; continue; }
    return e; // strictly beneath it
  }
  return null;
}

module.exports = { parse, load, isExcluded, globToRegExp, VERBS };
