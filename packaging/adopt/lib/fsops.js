'use strict';
// fsops.js — the write primitives and the payload walk, in one place.
//
// EXTRACTED FROM apply.js, NOT REWRITTEN. Every function below is the one the
// applier already used; nothing about the refusals changed in the move. The
// reason it moved is lib/plan.js: the plan reports a RESOLVED file count
// alongside its unit count (see counts.wouldWrite in PLAN-FORMAT.md), and the
// only honest way to predict what a copy will write is to run the same walk the
// copy runs. A second, "predictive" implementation of the same traversal would
// drift from this one the first time an exclusion rule changed, and the plan
// would then promise a number the apply does not deliver — which is the exact
// class of defect the count was added to close.
//
// So there is ONE traversal. `ctx.predictOnly` suppresses the two write calls
// and nothing else: the same exclusion rows, the same symlink refusal, the same
// secret-shaped refusal, the same REFUSE-EXISTS check, the same `out.wrote`
// entries. In predict mode the tree is not created, so every child still stats
// as absent and the prediction counts what a real run would create.
//
// Node, CommonJS, no dependencies. Writes nothing unless copyTree is called
// without predictOnly.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const manifestLib = require('./manifest');
const detectLib = require('./detect');

// ── REFUSAL 4: nothing is written outside the target repo root ───────────────
function realpathOrSelf(p) {
  try { return fs.realpathSync(p); } catch (e) { return path.resolve(p); }
}

function insideRoot(rootReal, absPath) {
  // Resolve the deepest EXISTING ancestor, so a not-yet-created path is judged by
  // where it would land rather than failing realpath.
  let probe = path.resolve(absPath);
  const unresolved = [];
  for (;;) {
    try { probe = fs.realpathSync(probe); break; } catch (e) { /* keep walking up */ }
    const parent = path.dirname(probe);
    if (parent === probe) break;
    unresolved.unshift(path.basename(probe));
    probe = parent;
  }
  const resolved = path.join(probe, ...unresolved);
  return resolved === rootReal || resolved.indexOf(rootReal + path.sep) === 0;
}

function assertWritableTarget(rootReal, absPath) {
  if (!insideRoot(rootReal, absPath)) {
    throw new Error(`REFUSE-OUTSIDE-ROOT: ${absPath} is not inside the target repository ${rootReal}`);
  }
  // Named explicitly because it is the ONE escape that would change the user's
  // other sessions rather than this repository.
  const home = realpathOrSelf(os.homedir());
  const userClaude = path.join(home, '.claude');
  const r = path.resolve(absPath);
  if (r === userClaude || r.indexOf(userClaude + path.sep) === 0) {
    throw new Error('REFUSE-OUTSIDE-ROOT: this tool never writes to ~/.claude — the harness governs one repository, not your user configuration');
  }
}

// ── REFUSAL 7: secret-shaped paths are never opened, not even to classify ────
const SECRET_BASENAMES = [
  '.env', '.envrc', '.npmrc', '.netrc', '.pgpass', '.htpasswd',
  'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'credentials', 'secrets'
];
const SECRET_PATTERNS = [
  /^\.env(\..+)?$/i,
  /\.(pem|key|pfx|p12|jks|keystore|asc|gpg|kdbx)$/i,
  /(^|[._-])(secret|secrets|credential|credentials|token|apikey|api[-_]key|private[-_]key)([._-]|$)/i
];

function isSecretShaped(relOrBase) {
  const base = path.basename(String(relOrBase));
  if (SECRET_BASENAMES.indexOf(base) !== -1) return true;
  for (const re of SECRET_PATTERNS) if (re.test(base)) return true;
  return false;
}

// ── REFUSAL 1 + 3: the only two write primitives in this file ────────────────
// Neither can overwrite, neither can truncate. 'wx' fails with EEXIST if the
// path is there — the refusal is enforced by the kernel, not by a check that a
// later edit could drop.
function copyFileNew(src, dst, mode) {
  const data = fs.readFileSync(src);
  const fd = fs.openSync(dst, 'wx', mode === undefined ? 0o666 : mode);
  try { fs.writeSync(fd, data); } finally { fs.closeSync(fd); }
  if (mode !== undefined) { try { fs.chmodSync(dst, mode); } catch (e) { /* best effort */ } }
}

function writeFileNew(dst, text) {
  const fd = fs.openSync(dst, 'wx', 0o666);
  try { fs.writeSync(fd, text); } finally { fs.closeSync(fd); }
}

// ── the recursive copy ───────────────────────────────────────────────────────
// THE MANIFEST'S `exclude:` ROWS ARE APPLIED HERE, and that is load-bearing.
// The planner's units are whole paths (`include: .logic-loom`), so nothing
// upstream of this function has ever consulted the carve-outs beneath them. A
// copy that ignored them would ship `.logic-loom/tests/`, `.logic-loom/graph/`,
// `.docs/guides/dev-main-template-split.md`, and — worst — the
// `update-agent-context.sh` the manifest excludes precisely because its
// update-existing branch truncates the adopter's CLAUDE.md to zero bytes.
function copyTree(srcAbs, dstAbs, rel, ctx, out) {
  const st = fs.lstatSync(srcAbs);

  if (st.isSymbolicLink()) {
    // A symlink in the payload can point anywhere, including out of the root.
    // Not followed, not recreated, recorded.
    out.skipped.push({ path: rel, why: 'REFUSE-SYMLINK: payload entry is a symlink; not followed and not recreated' });
    return;
  }

  if (manifestLib.isExcluded(ctx.manifest, rel, st.isDirectory())) {
    out.skipped.push({ path: rel, why: 'excluded by payload-manifest.txt' });
    return;
  }
  if (path.basename(rel) === '.git' || path.basename(rel) === 'node_modules') {
    out.skipped.push({ path: rel, why: 'never copied: a repository or a dependency tree is not payload' });
    return;
  }
  if (!st.isDirectory() && isSecretShaped(rel)) {
    // REFUSAL 7 — refused BEFORE the file is read.
    out.skipped.push({ path: rel, why: 'REFUSE-SECRET: secret-shaped filename; not read, not copied' });
    return;
  }

  if (!ctx.predictOnly) assertWritableTarget(ctx.rootReal, dstAbs);

  if (st.isDirectory()) {
    if (detectLib.statKind(dstAbs) === 'absent') {
      if (!ctx.predictOnly) fs.mkdirSync(dstAbs, { recursive: false, mode: st.mode & 0o777 });
      out.wrote.push({ path: rel + '/', kind: 'dir' });
    }
    const entries = fs.readdirSync(srcAbs).sort();
    for (const e of entries) {
      copyTree(path.join(srcAbs, e), path.join(dstAbs, e), rel + '/' + e, ctx, out);
    }
    return;
  }

  if (!st.isFile()) {
    out.skipped.push({ path: rel, why: 'not a regular file (socket/fifo/device); not copied' });
    return;
  }

  // REFUSAL 1, re-checked at the instant of the write.
  if (detectLib.statKind(dstAbs) !== 'absent') {
    out.skipped.push({ path: rel, why: 'REFUSE-EXISTS: a file is already here and it is yours; move it aside yourself if you want ours' });
    return;
  }
  if (!ctx.predictOnly) copyFileNew(srcAbs, dstAbs, st.mode & 0o777);
  out.wrote.push({ path: rel, kind: 'file' });
}

// ── content provenance for the merge targets (see lib/selfcaused.js) ─────────
// A digest, not a timestamp: it answers "is this file still exactly what we
// left?" and nothing else. Recorded by the applier for the files it MERGES into
// — the only files it touches that the adopter also owns — so a later run can
// tell its own footprint from an edit made since. Returns null when the file is
// unreadable rather than throwing; a missing digest fails toward "block".
function sha256File(abs) {
  try {
    return 'sha256:' + crypto.createHash('sha256').update(fs.readFileSync(abs)).digest('hex');
  } catch (e) { return null; }
}

module.exports = {
  realpathOrSelf, insideRoot, assertWritableTarget,
  isSecretShaped, SECRET_BASENAMES, SECRET_PATTERNS,
  copyFileNew, writeFileNew, copyTree, sha256File
};
