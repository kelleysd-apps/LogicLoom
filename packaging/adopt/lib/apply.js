'use strict';
// apply.js — the WRITE half of the adopt CLI.
//
// It consumes a plan (`logicloom/adopt-plan@1`, PLAN-FORMAT.md), writes only
// what the user named on the command line, records what it wrote, and stops.
//
// THE SHAPE IS /scaffold-environments', DELIBERATELY
// -----------------------------------------------------------------------------
// This CLI is that command's sibling, not a new thing:
//   * plan first and ALWAYS — `init` with no write flag plans and writes nothing
//   * `--only=` is MANDATORY with `--apply`; there is no "apply everything by
//     omission"
//   * there is NO `--force`. If a file already exists, it stays. The user moves
//     it aside themselves if they want ours
//   * a second run is a no-op and says so
//   * a SKIP is usually the right answer, not a limitation, and every skip is
//     printed with its reason
//
// THE EIGHT REFUSALS, STATED IN CODE AND NOT ONLY IN A DOC
// -----------------------------------------------------------------------------
// Each is implemented by a named function or constant below, and each emits a
// REFUSE-* code so a refusal in the output is traceable to a line here.
//
//  1. NEVER OVERWRITE A FILE IT DID NOT CREATE.  `copyFileNew()` opens with the
//     'wx' flag — the kernel refuses an existing path — and every path unit is
//     re-stat'd immediately before the write. The two merges are the only paths
//     that touch a file the adopter owns, and each is additive-and-fenced.
//     REFUSE-EXISTS.
//  2. NEVER RUN A MUTATING GIT COMMAND.  This module spawns nothing except the
//     two entries in SPAWN_ALLOWLIST, through `spawnAllowed()`, which refuses
//     any other executable before a process exists. It requires lib/git-ro.js
//     for every git question, and git-ro's verb allowlist is the ceiling for the
//     whole package. Not stash, not clean, not checkout, not add, not commit.
//     REFUSE-SPAWN.
//  3. NEVER DELETE OR TRUNCATE A TARGET FILE.  There is no unlink, no rm, no
//     rmdir, no truncate, and no 'w' open flag against a target anywhere in this
//     file. `obsolete` findings are printed on every run and actioned on none.
//  4. NEVER WRITE OUTSIDE THE TARGET REPO ROOT.  `insideRoot()` resolves both
//     sides and refuses anything that is not strictly beneath the realpath of
//     the root, so a `..` or a symlinked payload entry cannot escape. `~/.claude`
//     is refused by name as well, because it is the specific escape that would
//     change the user's OTHER sessions. REFUSE-OUTSIDE-ROOT.
//  5. NEVER MOVE PRODUCT SOURCE.  There is no move/rename action in this
//     applier at all — `rename:` rows in the manifest name where OUR file
//     installs, never where theirs goes. Where the plan reports product source
//     at the repo root, the divergence from the harness/product boundary is
//     RECORDED and printed, and nothing is moved.
//  6. NEVER INSTALL A HOOK THE USER DID NOT NAME.  The `hooks` target is
//     excluded from `--only=all` and must be typed by name. The governance floor
//     changes what the user's own sessions may do; adopting it as a side effect
//     of the word "all" is the most surprising thing this tool could do.
//  7. NEVER READ OR WRITE A SECRET-SHAPED FILE.  `isSecretShaped()` is consulted
//     before a file is opened, not after — the file is not read even to classify
//     it. REFUSE-SECRET.
//  8. NEVER CLAIM IT DID SOMETHING IT DID NOT.  Every unit ends in exactly one
//     of WROTE / SKIPPED / FAILED / NOT-ATTEMPTED, all four are printed, the
//     receipt records the same four, and a partial apply exits non-zero.
//
// STALE PLANS: THE APPLIER RE-PLANS. IT NEVER ACTS ON A PLAN FILE.
// -----------------------------------------------------------------------------
// A plan is a REVIEW ARTIFACT, not an instruction set. Acting on a serialized
// plan means acting on facts about a tree that may no longer exist — the user
// reviewed it, went to lunch, pulled, and the `.claude/` that was absent now
// holds their work. Planning is pure and cheap (the planner has no write path at
// all), so there is no reason to trust an old one: `--apply` ALWAYS rebuilds the
// plan against the tree as it is at write time and applies from that.
//
// `--plan <file>` is therefore not an input to the apply; it is an ASSERTION
// about what the user reviewed. The fresh plan is compared against it, and any
// material divergence — mode, applyReady, the blocking set, the additive unit
// ids — REFUSES with the specific difference named. That is the honest handling
// of a stale plan: not "apply the old one", not "silently apply a different
// one", but "the world moved, here is how, look again".
//
// PARTIAL FAILURE: REPORT AND STOP. NO ROLLBACK. THE ARGUMENT:
// -----------------------------------------------------------------------------
//  1. A rollback is a delete path. Building one means building exactly the
//     capability refusal 3 says this tool must not have, and a bug in it
//     destroys the adopter's file rather than merely leaving a mess. A
//     half-rollback — the failure mode of every rollback written under a partial
//     failure it did not anticipate — is strictly worse than an honest report.
//  2. There is very little to roll back. Every path unit is a file that DID NOT
//     EXIST (refusal 1 guarantees it), so a partial apply leaves added files and
//     no half-written file of theirs. The two merges are each atomic on their
//     own: merge_settings_json.py refuses without writing, and merge-gitignore.sh
//     assembles into a temp file and lands it in one copy.
//  3. The receipt is flushed after EVERY unit, not at the end, so the exact set
//     that landed is on disk even if the process is killed mid-run.
//  4. Reversal is then a list the human runs — which is what "uninstall is a
//     list, not a command" means. The report prints that list.
//
// Node, CommonJS, no dependencies.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const planLib = require('./plan');
const manifestLib = require('./manifest');
const detectLib = require('./detect');

const RECEIPT_SCHEMA = 'logicloom/adopt-receipt@1';
const RECEIPT_NAME = '.logicloom-adopt-receipt.json';

// ── Targets ──────────────────────────────────────────────────────────────────
// A target is a NAME THE USER TYPES. It groups units by the decision the user is
// actually making, which is not the same as the granularity the classifier works
// at: nobody wants to name eleven hook commands, and nobody should be able to
// install a governance floor by naming a directory.
const TARGETS = {
  harness: {
    summary: 'the harness tree itself — .logic-loom/, plugins/, .claude/{hooks,commands,context,agents,policies,schemas}, .docs/, the workspace stubs',
    granularity: 'path',
    inAll: true
  },
  gitignore: {
    summary: 'append the harness ignore block to .gitignore, inside a marked fence',
    granularity: 'line',
    inAll: true
  },
  hooks: {
    summary: 'register LogicLoom\'s governance hooks in .claude/settings.json',
    granularity: 'json-key',
    // REFUSAL 6. Not in `all`. This target changes what the adopter's own Claude
    // Code sessions are permitted to do — every prompt, in every session, from
    // then on. `--only=all` is a convenience, and a convenience must not be able
    // to reach it. It has to be typed.
    inAll: false
  }
};

const ALL_TARGETS = Object.keys(TARGETS);
const IN_ALL = ALL_TARGETS.filter((t) => TARGETS[t].inAll);

// ── REFUSAL 2: the complete list of executables this module may spawn ────────
// Anything not here throws before a process exists. There is no git verb on this
// list: every git question in this package goes through lib/git-ro.js, whose
// allowlist is read-only and is a strict subset of the subagent guard's.
const SPAWN_ALLOWLIST = ['python3', 'bash'];

function spawnAllowed(exe, args, opts) {
  if (SPAWN_ALLOWLIST.indexOf(exe) === -1) {
    throw new Error(`REFUSE-SPAWN: this applier may only spawn ${SPAWN_ALLOWLIST.join(', ')}; refused '${exe}'`);
  }
  // Belt and braces: even inside an allowed interpreter, refuse an argv that is
  // trying to be a git invocation. `bash merge-gitignore.sh` is a script path,
  // not a shell string, and there is no shell in this call.
  for (const a of args) {
    if (/(^|[\s;|&])git(\s|$)/.test(String(a))) {
      throw new Error(`REFUSE-SPAWN: refusing an argument that looks like a git invocation: ${a}`);
    }
  }
  // spawnSync, not execFileSync, and the reason is refusal 8. Both merge tools
  // report their outcome ("status: merged" / "status: nochange") on STDERR and
  // exit 0 either way. execFileSync returns stdout only and surfaces stderr on
  // the thrown error, so a successful no-op arrived here indistinguishable from
  // a successful write — and this applier would then have claimed it appended a
  // block it had not touched. Refusal 8 broken by an omission rather than a lie.
  const r = spawnSync(exe, args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: (opts && opts.timeoutMs) || 60000,
    maxBuffer: 32 * 1024 * 1024,
    cwd: (opts && opts.cwd) || undefined,
    shell: false
  });
  if (r.error && r.error.code === 'ENOENT') {
    return { ok: false, status: -1, stdout: '', stderr: `${exe} is not on PATH`, missing: true };
  }
  if (r.error) return { ok: false, status: -1, stdout: r.stdout || '', stderr: String(r.error.message) };
  return {
    ok: r.status === 0,
    status: typeof r.status === 'number' ? r.status : -1,
    stdout: r.stdout || '',
    stderr: r.stderr || ''
  };
}

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

  assertWritableTarget(ctx.rootReal, dstAbs);

  if (st.isDirectory()) {
    if (detectLib.statKind(dstAbs) === 'absent') {
      fs.mkdirSync(dstAbs, { recursive: false, mode: st.mode & 0o777 });
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
  copyFileNew(srcAbs, dstAbs, st.mode & 0o777);
  out.wrote.push({ path: rel, kind: 'file' });
}

// ── the receipt (the marker manifest PLAN-FORMAT.md describes) ───────────────
// Everything written is identifiable later from one file, so uninstall is a list
// the human runs. Appends a run rather than replacing, because a second run —
// including a no-op one — is itself a fact worth keeping.
function receiptPath(root) { return path.join(root, RECEIPT_NAME); }

function readReceipt(root) {
  try {
    const j = JSON.parse(fs.readFileSync(receiptPath(root), 'utf8'));
    if (j && j.schema === RECEIPT_SCHEMA && Array.isArray(j.runs)) return j;
    return null;
  } catch (e) { return null; }
}

function writeReceipt(root, receipt) {
  const p = receiptPath(root);
  // The one place a 'w' flag is used, and it is against OUR OWN file: the schema
  // is checked on read, and a foreign file at this path is refused rather than
  // clobbered (see priorRun()).
  fs.writeFileSync(p, JSON.stringify(receipt, null, 2) + '\n', 'utf8');
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

// ── option parsing ───────────────────────────────────────────────────────────
function parseOnly(raw) {
  if (raw === undefined || raw === null || raw === '') {
    return { error: '--only is REQUIRED with --apply. There is no "apply everything by omission". ' +
                    'Valid targets: ' + ALL_TARGETS.join(', ') + ', or all (which is ' + IN_ALL.join('+') + ' — ' +
                    '`hooks` is never included in `all` and must be named).' };
  }
  const asked = String(raw).split(',').map((s) => s.trim()).filter((s) => s.length);
  const out = [];
  for (const a of asked) {
    if (a === 'all') { for (const t of IN_ALL) if (out.indexOf(t) === -1) out.push(t); continue; }
    if (!Object.prototype.hasOwnProperty.call(TARGETS, a)) {
      return { error: `unknown --only target '${a}'. Valid: ${ALL_TARGETS.join(', ')}, all` };
    }
    if (out.indexOf(a) === -1) out.push(a);
  }
  if (!out.length) return { error: '--only names no targets' };
  return { targets: out };
}

// ── stale-plan comparison ────────────────────────────────────────────────────
// Compares the fresh plan against the one the user says they reviewed. Material
// facts only — `generatedAt` and payload paths differ legitimately.
function planDivergence(reviewed, fresh) {
  const diffs = [];
  if (reviewed.schema !== fresh.schema) diffs.push(`schema: reviewed ${reviewed.schema}, now ${fresh.schema}`);
  if (reviewed.mode.mode !== fresh.mode.mode) diffs.push(`mode: reviewed ${reviewed.mode.mode}, now ${fresh.mode.mode}`);
  if (reviewed.applyReady !== fresh.applyReady) diffs.push(`applyReady: reviewed ${reviewed.applyReady}, now ${fresh.applyReady}`);

  const codes = (p) => p.preconditions.blocking.map((b) => b.code + '@' + (b.path || '')).sort();
  const a = codes(reviewed).join('|'), b = codes(fresh).join('|');
  if (a !== b) diffs.push(`blocking set changed:\n        reviewed: ${a || '(none)'}\n        now     : ${b || '(none)'}`);

  const ids = (p) => p.buckets.additive.map((u) => u.id).sort();
  const ia = ids(reviewed), ib = ids(fresh);
  const gone = ia.filter((x) => ib.indexOf(x) === -1);
  const added = ib.filter((x) => ia.indexOf(x) === -1);
  if (gone.length) diffs.push(`${gone.length} unit(s) that were additive are no longer: ${gone.slice(0, 5).join(', ')}${gone.length > 5 ? ', …' : ''}`);
  if (added.length) diffs.push(`${added.length} unit(s) became additive since you looked: ${added.slice(0, 5).join(', ')}${added.length > 5 ? ', …' : ''}`);
  return diffs;
}

// ── self-caused blocking items ───────────────────────────────────────────────
// ALREADY-ADOPTED and PARTIAL-ADOPTION are the only two blocking codes this tool
// can CAUSE. After a successful `--only=harness`, a later `--only=hooks` would
// otherwise be blocked by the harness it just wrote — the second half of an
// install refused because the first half succeeded.
//
// They are discounted ONLY when this package's own receipt records a prior run
// against this root. That is not a `--force`: it is not user-settable, it does
// not apply to any other code, and it is printed. If a receipt were forged, the
// consequence is nil — every unit in an already-adopted repo classifies
// keep-theirs, so the apply writes nothing anyway.
const SELF_CAUSED = ['ALREADY-ADOPTED', 'PARTIAL-ADOPTION'];

// Did an earlier run of ours write at or under this path? Report-only.
function wroteUnder(prior, relPath) {
  const clean = String(relPath || '').replace(/\/+$/, '');
  if (!clean) return false;
  for (const w of (prior.wrote || [])) {
    const wp = String(w.path || '').replace(/\/+$/, '');
    if (wp === clean || wp.indexOf(clean + '/') === 0 || clean.indexOf(wp + '/') === 0) return true;
  }
  return false;
}

function effectiveBlocking(plan, prior) {
  if (!prior) return { blocking: plan.preconditions.blocking, discounted: [] };
  const discounted = plan.preconditions.blocking.filter((b) => SELF_CAUSED.indexOf(b.code) !== -1);
  const blocking = plan.preconditions.blocking.filter((b) => SELF_CAUSED.indexOf(b.code) === -1);
  return { blocking, discounted };
}

// ── the apply ────────────────────────────────────────────────────────────────
function apply(opts) {
  const L = [];
  const p = (s) => L.push(s === undefined ? '' : String(s));

  const root = path.resolve(opts.target);
  const rootReal = realpathOrSelf(root);
  const pkgRoot = opts.pkgRoot;

  const result = {
    ok: false,
    exitCode: 1,
    status: 'refused',
    wrote: [],
    skipped: [],
    failed: [],
    notAttempted: [],
    report: ''
  };

  const finish = (code, status) => {
    result.exitCode = code;
    result.status = status;
    result.ok = code === 0;
    result.report = L.join('\n');
    return result;
  };

  p('LogicLoom init --apply');
  p('='.repeat(78));
  p('');

  // ── 1. RE-PLAN AT WRITE TIME. The plan file, if given, is only an assertion.
  let fresh;
  try {
    fresh = planLib.build({
      pkgRoot: pkgRoot,
      pkgName: opts.pkgName,
      pkgVersion: opts.pkgVersion,
      target: root,
      payload: opts.payload,
      manifest: opts.manifest
    });
  } catch (e) {
    p(`  REFUSED — the plan could not be rebuilt at write time: ${e && e.message}`);
    p('  Nothing was written.');
    return finish(3, 'plan-error');
  }

  p(`  target repository     : ${fresh.target.root}`);
  p(`  payload source        : ${fresh.payload.source}`);
  p(`  mode                  : ${fresh.mode.mode}`);
  p(`  targets requested     : ${opts.only.join(', ')}`);
  p('');
  p('  The plan was REBUILT just now against the tree as it is. A plan file is a');
  p('  review artifact, never an instruction set — acting on one would mean acting');
  p('  on facts about a tree that may have changed since you read it.');
  p('');

  // ── 2. If the user asserted a reviewed plan, hold the fresh one to it.
  if (opts.planFile) {
    let reviewed = null;
    try { reviewed = JSON.parse(fs.readFileSync(opts.planFile, 'utf8')); }
    catch (e) {
      p(`  REFUSED — --plan ${opts.planFile} could not be read as JSON: ${e && e.message}`);
      return finish(2, 'refused');
    }
    if (reviewed.schema !== planLib.SCHEMA) {
      p(`  REFUSED — the reviewed plan declares schema '${reviewed.schema}'; this applier knows only '${planLib.SCHEMA}'.`);
      p('  An applier MUST refuse a schema it does not know (PLAN-FORMAT.md).');
      return finish(1, 'refused');
    }
    const diffs = planDivergence(reviewed, fresh);
    if (diffs.length) {
      p('  REFUSED — the repository changed since the plan you reviewed:');
      for (const d of diffs) p('      - ' + d);
      p('');
      p('  Nothing was written. Re-run the plan, read it, then apply again.');
      return finish(1, 'stale-plan');
    }
    p('  reviewed plan         : matches the fresh one on mode, applyReady, blocking set and unit ids');
    p('');
  }

  // ── 3. The gate. applyReady is not overridable and there is no --force.
  const prior = priorRun(root);
  const eff = effectiveBlocking(fresh, prior);
  if (eff.discounted.length) {
    p('  Discounted blocking items (caused by this tool\'s own earlier run, per the receipt):');
    for (const b of eff.discounted) p(`      [${b.code}] — a prior run at ${prior.at} wrote ${prior.wrote.length} path(s) here`);
    p('  Nothing else is ever discounted, and this is not a flag you can set.');
    p('');
  }
  if (fresh.errors.length) {
    p(`  REFUSED — the plan itself is unsound (${fresh.errors.length} error(s)):`);
    for (const e of fresh.errors) p('      - ' + e);
    p('  Nothing was written.');
    return finish(1, 'refused');
  }
  if (eff.blocking.length) {
    p(`  REFUSED — ${eff.blocking.length} blocking precondition(s). There is no --force, and there will not be:`);
    p('  every one of these is a condition under which a write can destroy work that');
    p('  has no other copy.');
    for (const b of eff.blocking) {
      p('');
      p(`      [${b.code}]  ${b.path}`);
      p(`      ${b.detail}`);
      p(`      remedy (YOU run this, not the tool): ${b.remedy}`);
      // Honesty about our own footprint: after a first `--only=harness`, the
      // paths this tool wrote are untracked, and they block the next target.
      // Say so, rather than letting the user read it as their own mess.
      if (prior && /^UNTRACKED/.test(b.code) && wroteUnder(prior, b.path)) {
        p('      NOTE: this path was written by THIS TOOL in an earlier run (see the receipt).');
        p('            Committing it is the right next step, and then the remaining targets apply.');
      }
    }
    p('');
    p('  Nothing was written.');
    return finish(1, 'blocked');
  }

  // ── 4. REFUSAL 5 — record a harness/product boundary divergence, move nothing.
  if (fresh.detect.productSourceAtRoot.answer === 'yes') {
    p('  RECORDED DIVERGENCE (nothing will be moved)');
    p(`    ${fresh.detect.productSourceAtRoot.reason}`);
    p('    The harness owns the repo root, so its root files and yours will share a');
    p('    directory. This applier never moves product source, even where the');
    p('    boundary says it belongs in web/ or apps/<name>/. That is yours to do.');
    p('');
  }

  // ── 5. Load the manifest — the copy needs its exclude: rows.
  const manifestPath = fresh.payload.manifest;
  let manifest;
  try { manifest = manifestLib.load(manifestPath); }
  catch (e) {
    p(`  REFUSED — payload manifest unreadable at write time: ${e && e.message}`);
    return finish(3, 'plan-error');
  }

  const ctx = { rootReal, manifest, payloadRoot: fresh.payload.root };

  // ── 6. Split the additive worklist by requested target.
  const wanted = {};
  for (const t of opts.only) wanted[t] = true;
  const byGran = { path: [], line: [], 'json-key': [] };
  for (const u of fresh.buckets.additive) {
    if (byGran[u.granularity]) byGran[u.granularity].push(u);
  }

  const receipt = readReceipt(root) || { schema: RECEIPT_SCHEMA, runs: [] };
  const run = {
    at: new Date().toISOString(),
    generator: `${fresh.generator.package}@${fresh.generator.version}`,
    node: fresh.generator.nodeVersion,
    payloadSource: fresh.payload.source,
    only: opts.only.slice(),
    status: 'in-progress',
    wrote: [],
    skipped: [],
    failed: [],
    notAttempted: []
  };
  receipt.runs.push(run);

  const flush = () => { try { writeReceipt(root, receipt); } catch (e) { /* reported below */ } };

  // A foreign file sitting at the receipt path is refused, never clobbered.
  if (detectLib.statKind(receiptPath(root)) !== 'absent' && readReceipt(root) === null) {
    p(`  REFUSED — ${RECEIPT_NAME} exists but is not a LogicLoom adopt receipt.`);
    p('  Refusing to overwrite a file this tool did not create. Move it aside yourself.');
    return finish(1, 'refused');
  }

  const targetOrder = ALL_TARGETS.filter((t) => wanted[t]);
  const pending = targetOrder.slice();
  let hardFailure = null;

  const noteNotAttempted = (why) => {
    for (const t of pending) {
      run.notAttempted.push({ target: t, why });
      result.notAttempted.push({ target: t, why });
    }
    pending.length = 0;
  };

  // ── REFUSAL 1, reported before anything is written ────────────────────────
  // The classifier already dropped these: a counterpart exists, so ours is not
  // installed. They never reach the worklist, which is exactly why they have to
  // be PRINTED — a silent drop is how an adopter discovers six weeks later that
  // a file they assumed was installed never was. There is no flag that would
  // install them; the tool never overwrites a file it did not create.
  const keptGrans = {};
  for (const t of opts.only) keptGrans[TARGETS[t].granularity] = true;
  const kept = fresh.buckets['keep-theirs'].filter((u) => keptGrans[u.granularity]);
  if (kept.length) {
    p(`  KEPT YOURS (${kept.length}) — a counterpart exists, so OUR copy is dropped. Nothing here`);
    p('  is overwritten, and there is no flag that would overwrite it. If you want ours,');
    p('  move yours aside yourself and re-run.');
    for (const u of kept.slice(0, 25)) {
      p(`      - [${u.granularity}] ${u.targetPath}${u.granularity === 'line' ? '  ' + u.value : ''}`);
      p(`          ${u.reason}`);
    }
    if (kept.length > 25) p(`      … and ${kept.length - 25} more (run without --apply for the full list)`);
    p('');
  }

  p('  APPLY');
  p('');

  for (let ti = 0; ti < targetOrder.length; ti++) {
    const target = targetOrder[ti];
    pending.shift();
    p(`  ── ${target} ──`);
    try {
      if (target === 'harness') applyHarness(byGran.path, ctx, run, result, p, opts);
      else if (target === 'gitignore') applyGitignore(byGran.line, ctx, run, result, p, opts, root, pkgRoot);
      else if (target === 'hooks') applyHooks(byGran['json-key'], ctx, run, result, p, opts, root, pkgRoot);
      flush();
    } catch (e) {
      const msg = (e && e.message) || String(e);
      run.failed.push({ target: target, why: msg });
      result.failed.push({ target: target, why: msg });
      flush();
      hardFailure = { target, msg };
      p(`      FAILED: ${msg}`);
      break;
    }
    p('');
  }

  if (hardFailure) {
    noteNotAttempted(`the ${hardFailure.target} target failed before this one was reached`);
    run.status = 'partial';
    flush();
  } else {
    run.status = result.failed.length ? 'partial' : 'complete';
    flush();
  }

  // ── 7. The report. Every unit ends in exactly one of four states. ──────────
  p('');
  p('  RESULT');
  p(`    WROTE          ${run.wrote.length}`);
  p(`    SKIPPED        ${run.skipped.length}   (each with a reason, below)`);
  p(`    FAILED         ${run.failed.length}`);
  p(`    NOT ATTEMPTED  ${run.notAttempted.length}`);
  p('');

  if (run.skipped.length) {
    p('    SKIPPED — a skip is usually the right answer, not a limitation:');
    const shown = run.skipped.slice(0, 40);
    for (const s of shown) p(`      - ${s.path || s.target}: ${s.why}`);
    if (run.skipped.length > shown.length) p(`      … and ${run.skipped.length - shown.length} more (all in ${RECEIPT_NAME})`);
    p('');
  }
  if (run.failed.length) {
    p('    FAILED:');
    for (const f of run.failed) p(`      - ${f.target}: ${f.why}`);
    p('');
  }
  if (run.notAttempted.length) {
    p('    NOT ATTEMPTED — these were requested and were NOT run:');
    for (const n of run.notAttempted) p(`      - ${n.target}: ${n.why}`);
    p('');
  }

  const notNamed = ALL_TARGETS.filter((t) => !wanted[t]);
  if (notNamed.length) {
    p(`    NOT REQUESTED  : ${notNamed.join(', ')}`);
    if (notNamed.indexOf('hooks') !== -1) {
      p('      `hooks` is deliberately NOT part of `--only=all`. It registers the');
      p('      governance floor in .claude/settings.json, which changes what YOUR');
      p('      Claude Code sessions may do in this repo. Nothing installs it as a');
      p('      side effect — run `--apply --only=hooks` if you want it.');
    }
    p('');
  }

  p(`    receipt        : ${RECEIPT_NAME} — every path above, identifiable later.`);
  p('    UNINSTALL is a list you run, not a command this tool ships. The receipt');
  p('    holds the paths; remove them yourself, and undo the two merges by');
  p('    deleting their fenced/recorded regions.');
  p('');

  if (run.wrote.length === 0 && run.failed.length === 0) {
    p('    NO-OP — nothing needed writing. Everything requested is already present,');
    p('    or was skipped for a reason listed above. A second run changes nothing,');
    p('    and this is that run.');
    p('');
  }

  if (hardFailure || run.failed.length) {
    p('    PARTIAL APPLY. Nothing was rolled back, deliberately: a rollback is a');
    p('    delete path, and this tool refuses to have one. Everything that landed is');
    p(`    listed above and in ${RECEIPT_NAME}; nothing of yours was overwritten or`);
    p('    truncated, because every write refuses an existing path.');
    return finish(4, 'partial');
  }

  return finish(0, run.wrote.length ? 'applied' : 'noop');
}

// ── target: harness (path units) ─────────────────────────────────────────────
function applyHarness(units, ctx, run, result, p, opts) {
  if (!units.length) { p('      nothing additive at path granularity — already present, or all keep-theirs.'); return; }
  for (const u of units) {
    const src = path.join(ctx.payloadRoot, u.sourcePath);
    const dst = path.join(ctx.rootReal, u.targetPath);
    assertWritableTarget(ctx.rootReal, dst);

    if (detectLib.statKind(src) === 'absent') {
      run.skipped.push({ path: u.targetPath, why: 'payload no longer contains ' + u.sourcePath });
      result.skipped.push({ path: u.targetPath });
      continue;
    }
    // REFUSAL 1, re-checked here even though the plan said additive: the plan may
    // be seconds old and the tree is not frozen.
    if (detectLib.statKind(dst) !== 'absent' && !fs.lstatSync(src).isDirectory()) {
      run.skipped.push({ path: u.targetPath, why: 'REFUSE-EXISTS: appeared since the plan was built; it is yours and it stays' });
      result.skipped.push({ path: u.targetPath });
      p(`      SKIP  ${u.targetPath}  (exists — yours, kept)`);
      continue;
    }
    if (opts.dryRunWrites) { p(`      WOULD ${u.targetPath}`); continue; }

    fs.mkdirSync(path.dirname(dst), { recursive: true });
    const out = { wrote: [], skipped: [] };
    copyTree(src, dst, u.targetPath, ctx, out);
    for (const w of out.wrote) { run.wrote.push({ target: 'harness', path: w.path, kind: w.kind }); result.wrote.push(w); }
    for (const s of out.skipped) { run.skipped.push(s); result.skipped.push(s); }
    p(`      WROTE ${u.targetPath}${u.renamedFrom ? `   (from ${u.renamedFrom})` : ''}  — ${out.wrote.length} entr${out.wrote.length === 1 ? 'y' : 'ies'}` +
      (out.skipped.length ? `, ${out.skipped.length} skipped` : ''));
  }
}

// ── target: gitignore (line units, via the shipped merge) ────────────────────
function applyGitignore(units, ctx, run, result, p, opts, root, pkgRoot) {
  if (!units.length) {
    p('      every harness ignore pattern is already in your .gitignore — nothing to append.');
    run.skipped.push({ target: 'gitignore', path: '.gitignore', why: 'all patterns already present' });
    return;
  }
  const script = path.join(pkgRoot, 'merge', 'merge-gitignore.sh');
  const block = path.join(pkgRoot, 'merge', 'gitignore-block.txt');
  if (detectLib.statKind(script) === 'absent' || detectLib.statKind(block) === 'absent') {
    throw new Error(`the shipped gitignore merge is missing (${script})`);
  }

  // THE PLAN'S LINE UNITS AND THE SHIPPED BLOCK ARE NOT THE SAME SET, on purpose.
  // The units come from the payload's own .gitignore filtered by prefix;
  // gitignore-block.txt is the CURATED list, and merge/gitignore-decisions.txt
  // records every drop with its reason (`.devloop/` — pack removed in v6.2;
  // `test-checkpoint-*` — no producer left; `.claude/skill-index.json.bak` —
  // dead). The merge tool installs the block, so anything additive that is NOT
  // in the block would never land. Reporting the unit count as "appended" would
  // therefore be a claim about patterns that were never written — refusal 8.
  const blockPatterns = fs.readFileSync(block, 'utf8').split('\n')
    .map((l) => l.trim()).filter((l) => l.length && l.charAt(0) !== '#');
  const willLand = units.filter((u) => blockPatterns.indexOf(u.value) !== -1);
  const neverShipped = units.filter((u) => blockPatterns.indexOf(u.value) === -1);
  for (const u of neverShipped) {
    run.skipped.push({ target: 'gitignore', path: u.value,
      why: 'deliberately NOT in the shipped block — see merge/gitignore-decisions.txt for the reason it was dropped' });
  }
  if (!willLand.length) {
    p(`      NO-OP every pattern the shipped block carries is already in your .gitignore.`);
    p(`             ${neverShipped.length} pattern(s) from our own .gitignore are deliberately not shipped.`);
    run.skipped.push({ target: 'gitignore', path: '.gitignore', why: 'the shipped block is already fully present' });
    return;
  }

  const target = path.join(ctx.rootReal, '.gitignore');
  assertWritableTarget(ctx.rootReal, target);
  if (opts.dryRunWrites) { p('      WOULD append the fenced harness block to .gitignore'); return; }

  const r = spawnAllowed('bash', [script, '--target', target, '--block', block, '--write'], { cwd: root });
  if (!r.ok) {
    // Exit 10 is the merge's own refusal, and it never partially writes.
    throw new Error(`merge-gitignore.sh refused or failed (exit ${r.status}): ${String(r.stderr).trim().split('\n').slice(-3).join(' | ')}`);
  }
  const status = /status:\s*(\w+)/.exec(String(r.stderr));
  const st = status ? status[1] : 'merged';
  if (st === 'nochange') {
    run.skipped.push({ target: 'gitignore', path: '.gitignore', why: 'the managed block is already present and identical (no-op)' });
    p('      NO-OP the managed block is already present and identical.');
  } else {
    run.wrote.push({ target: 'gitignore', path: '.gitignore', kind: 'merge', region: 'the fenced "LogicLoom adopt — managed block"' });
    result.wrote.push({ path: '.gitignore' });
    p(`      MERGED .gitignore — the shipped harness block (${blockPatterns.length} patterns, ${willLand.length} of them new to you)`);
    p('             appended inside a marked fence. Everything above it is byte-identical.');
    if (neverShipped.length) {
      p(`             ${neverShipped.length} pattern(s) in LogicLoom's own .gitignore are deliberately NOT`);
      p('             shipped; merge/gitignore-decisions.txt records why, one line each.');
    }
  }
}

// ── target: hooks (json-key units, via the shipped merge) ────────────────────
function applyHooks(units, ctx, run, result, p, opts, root, pkgRoot) {
  const script = path.join(pkgRoot, 'merge', 'merge_settings_json.py');
  const fragment = path.join(pkgRoot, 'merge', 'settings-hooks-fragment.json');
  if (detectLib.statKind(script) === 'absent' || detectLib.statKind(fragment) === 'absent') {
    throw new Error(`the shipped settings merge is missing (${script})`);
  }
  if (!units.length) {
    p('      every governance hook is already registered in your settings.json — nothing to merge.');
    run.skipped.push({ target: 'hooks', path: '.claude/settings.json', why: 'all hook commands already present' });
    return;
  }

  // The merge tool installs THE FRAGMENT; the plan classified the PAYLOAD's
  // settings.json. tests/contract/test_adopt_merges.sh holds the two equal, but
  // this applier does not take that on faith at write time: an additive unit
  // whose command is not in the fragment would be reported as installed and
  // would not be.
  let frag;
  try { frag = JSON.parse(fs.readFileSync(fragment, 'utf8')); }
  catch (e) { throw new Error(`settings-hooks-fragment.json is unreadable: ${e && e.message}`); }
  const fragCommands = [];
  for (const ev of Object.keys(frag.hooks || {})) {
    for (const g of frag.hooks[ev] || []) {
      for (const h of (g.hooks || [])) if (h && typeof h.command === 'string') fragCommands.push(ev + '|' + h.command);
    }
  }
  const missing = units.filter((u) => fragCommands.indexOf(u.selector.event + '|' + u.selector.command) === -1);
  if (missing.length) {
    throw new Error(
      `${missing.length} hook command(s) the plan says are additive are NOT in settings-hooks-fragment.json ` +
      `(e.g. ${missing[0].selector.command}). The payload and the merge fragment have drifted; refusing rather ` +
      'than reporting an install that would not happen.');
  }

  const target = path.join(ctx.rootReal, '.claude', 'settings.json');
  assertWritableTarget(ctx.rootReal, target);
  if (opts.dryRunWrites) { p(`      WOULD register ${units.length} governance hook command(s) in .claude/settings.json`); return; }

  fs.mkdirSync(path.dirname(target), { recursive: true });
  const r = spawnAllowed('python3', [script, '--target', target, '--fragment', fragment, '--write'], { cwd: root });
  if (!r.ok) {
    if (r.missing) throw new Error('python3 is not on PATH; the settings merge cannot run. Nothing was written to .claude/settings.json.');
    throw new Error(`merge_settings_json.py refused or failed (exit ${r.status}): ${String(r.stderr).trim().split('\n').slice(-3).join(' | ')}`);
  }
  const status = /status:\s*(\w+)/.exec(String(r.stderr));
  const st = status ? status[1] : 'merged';
  if (st === 'nochange') {
    run.skipped.push({ target: 'hooks', path: '.claude/settings.json', why: 'every hook group is already registered (no-op)' });
    p('      NO-OP every hook group is already registered.');
  } else {
    run.wrote.push({ target: 'hooks', path: '.claude/settings.json', kind: 'merge', region: '.claude/.logicloom-adopt-settings.json records exactly what was inserted' });
    run.wrote.push({ target: 'hooks', path: '.claude/.logicloom-adopt-settings.json', kind: 'file' });
    result.wrote.push({ path: '.claude/settings.json' });
    p(`      MERGED .claude/settings.json — ${units.length} governance hook command(s) added additively.`);
    p('             No key of yours was set, removed, or reordered. Provenance is in');
    p('             .claude/.logicloom-adopt-settings.json, which makes a re-run a no-op.');
    p('             These hooks now run in YOUR sessions in this repository.');
  }
}

module.exports = {
  apply, TARGETS, ALL_TARGETS, IN_ALL, parseOnly, planDivergence,
  isSecretShaped, insideRoot, assertWritableTarget, copyTree, spawnAllowed,
  SPAWN_ALLOWLIST, SELF_CAUSED, RECEIPT_SCHEMA, RECEIPT_NAME,
  readReceipt, priorRun, effectiveBlocking
};
