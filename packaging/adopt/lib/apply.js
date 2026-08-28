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
const claudeMdLib = require('./claude-md');

const RECEIPT_SCHEMA = 'logicloom/adopt-receipt@1';
const RECEIPT_NAME = '.logicloom-adopt-receipt.json';

// ── UNINSTALL: A LIST THE HUMAN RUNS, AND WHY IT IS STILL THAT ───────────────
// The receipt now names every path this tool wrote, which is exactly the thing
// research § 6 PRE-14 asked for. It is worth saying plainly why that does NOT
// turn into a `logicloom uninstall` subcommand, because the receipt is the
// argument someone would use FOR building one:
//
//  1. It would be a delete path in a tool whose refusal 3 is that it has none.
//     The same binary cannot honestly say "if a file exists it stays, move it
//     aside yourself" and also own a code path that removes files. A bug in the
//     second destroys the adopter's work; a bug in the first writes nothing.
//  2. The receipt records what we wrote, not what those files ARE NOW. By the
//     time anyone uninstalls, `.logic-loom/memory/constitution.md` may carry
//     their amendments, `plugins/` may hold a plugin they built, `features/`
//     may hold their work. A path-list deleter cannot tell "our file" from "our
//     file they then made theirs". A human reading the list can, in seconds.
//  3. The merges are not deletable by path at all — `.gitignore` needs a fenced
//     region cut out, `.claude/settings.json` needs specific matcher groups
//     removed from arrays that also hold the adopter's own hooks, and under
//     `--claude-md=import` their CLAUDE.md carries a fenced block too. That is
//     editing, not removing, and it is the half that actually needs judgement.
//
// So: the receipt makes removal MECHANICAL, which is what was wanted. It does
// not make it AUTOMATIC, which was never the same thing. The procedure below is
// written into the receipt itself on every run and printed by the report, so an
// adopter answers "what did this put in my repo, and how do I take it out" from
// a file in their repo rather than from memory or from our docs.
const GITIGNORE_FENCE_BEGIN = '# >>> LogicLoom adopt — managed block. Do not edit inside. >>>';
const GITIGNORE_FENCE_END = '# <<< LogicLoom adopt — end managed block <<<';
const SETTINGS_SIDECAR = '.claude/.logicloom-adopt-settings.json';

// Built from what THIS repo actually holds after the run — the union of every
// run in the receipt, not a generic recipe. Steps whose cause never happened are
// omitted rather than printed as "if applicable".
function uninstallProcedure(receipt) {
  const paths = {};
  let didGitignore = false;
  let didSettings = false;
  let didClaudeMd = false;
  for (const r of receipt.runs) {
    for (const w of r.wrote || []) {
      if (w.kind === 'merge' && w.path === '.gitignore') { didGitignore = true; continue; }
      if (w.kind === 'merge' && w.path === '.claude/settings.json') { didSettings = true; continue; }
      // `--claude-md=import` appends one fenced block to a file the adopter owns.
      // It is the third merge, and leaving it out of the procedure would be the
      // one edit to THEIR file that uninstall forgot.
      if (w.kind === 'merge' && w.path === 'CLAUDE.md') { didClaudeMd = true; continue; }
      if (w.path) paths[w.path] = true;
    }
  }
  const pathList = Object.keys(paths).sort();

  const steps = [];
  if (pathList.length) {
    steps.push(
      'Remove the paths this tool wrote. They are listed under runs[].wrote[].path ' +
      'in this file (' + pathList.length + ' entr' + (pathList.length === 1 ? 'y' : 'ies') + '). ' +
      'READ THE LIST FIRST: anything you have since edited or added underneath one of ' +
      'these directories is yours, and removing the directory takes it with you.'
    );
  }
  if (didGitignore) {
    steps.push(
      'In .gitignore, delete the fenced region from "' + GITIGNORE_FENCE_BEGIN + '" ' +
      'through "' + GITIGNORE_FENCE_END + '", inclusive. Everything outside the fence ' +
      'is byte-identical to what you had before.'
    );
  }
  if (didSettings) {
    steps.push(
      'In .claude/settings.json, remove the hook matcher groups recorded in ' +
      SETTINGS_SIDECAR + '. Nothing else in that file was touched: the merge is ' +
      'per-key-path and appends to the hooks arrays only, so your own hooks are ' +
      'still in it and must stay. Then delete ' + SETTINGS_SIDECAR + ' itself.'
    );
  }
  if (didClaudeMd) {
    steps.push(
      'In CLAUDE.md — YOUR file — delete the fenced block from "' + claudeMdLib.BEGIN +
      '" through "' + claudeMdLib.END + '", inclusive. It was appended at the end and ' +
      'nothing above it was changed. This block exists only because ' +
      '--claude-md=import was used; the default mode never opens your CLAUDE.md.'
    );
  }
  steps.push('Delete ' + RECEIPT_NAME + ' last — it is the record of everything above.');

  return {
    position: 'a list you run, not a command this tool ships',
    why: 'This tool refuses to delete, truncate or move anything (refusal 3). An ' +
         'uninstall subcommand would be exactly the delete path it refuses to have, ' +
         'and by the time you run it some of these files are yours, not ours.',
    steps: steps,
    notRemovedByThis: 'Nothing under .brain/, features/, specs/ or artifacts/ that YOU ' +
      'created is named above; this tool never wrote it. Content you added inside a ' +
      'directory we created is likewise yours — check before you remove the directory.'
  };
}

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
  rules: {
    summary: 'the harness\'s operating instructions — .claude/rules/logicloom-*.md, ' +
             'and under --claude-md=import one marked block appended to your CLAUDE.md',
    granularity: 'rules',
    // IN `all`. Under the DEFAULT mode this target writes only new files into a
    // directory nothing else owns, and a harness whose operating instructions
    // were never installed is a pile of commands nobody knows to use. The one
    // mode that touches a file the adopter owns — `import` — has to be TYPED,
    // so `--only=all` on its own can never reach their CLAUDE.md.
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
  // Recomputed on every flush, so the procedure always matches the runs above it
  // — including a flush that happens mid-run because the process was killed.
  receipt.uninstall = uninstallProcedure(receipt);
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
  // The integration mode decides whether a file the adopter owns gets written
  // to. Reviewing a `rules` plan and applying an `import` one is exactly the
  // surprise --plan exists to prevent.
  const rcm = reviewed.claudeMd && reviewed.claudeMd.resolved;
  const fcm = fresh.claudeMd && fresh.claudeMd.resolved;
  if (rcm !== undefined && rcm !== fcm) diffs.push(`CLAUDE.md integration mode: reviewed ${rcm}, now ${fcm}`);

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
      manifest: opts.manifest,
      claudeMd: opts.claudeMd
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
  p(`  CLAUDE.md integration : ${fresh.claudeMd.resolved}  (${fresh.claudeMd.source})`);
  if (fresh.claudeMd.collapsed) {
    p(`                          requested '${fresh.claudeMd.requested}' — ${fresh.claudeMd.reason}`);
  }
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

  const ctx = { rootReal, manifest, payloadRoot: fresh.payload.root, pkgRoot };

  // ── 6. Split the additive worklist by requested target.
  const wanted = {};
  for (const t of opts.only) wanted[t] = true;
  const byGran = { path: [], line: [], 'json-key': [], rules: [] };
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
    // RECORDED, so a re-run and an uninstall both know what happened. The
    // resolved mode is what was executed; the requested one is what was typed,
    // and they differ exactly when the collapse rule fired.
    claudeMd: {
      requested: fresh.claudeMd.requested,
      resolved: fresh.claudeMd.resolved,
      source: fresh.claudeMd.source,
      collapsed: fresh.claudeMd.collapsed
    },
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
      else if (target === 'rules') applyRules(byGran.rules, ctx, run, result, p, opts, root, fresh);
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
  p('');
  p('    UNINSTALL is a list you run, not a command this tool ships — this tool');
  p('    refuses to delete, truncate or move anything, and an uninstall subcommand');
  p('    would be exactly the delete path it refuses to have. The procedure below');
  p(`    is also written into ${RECEIPT_NAME} under "uninstall", so you`);
  p('    never have to remember it or come back to this output:');
  const un = uninstallProcedure(receipt);
  let stepNo = 0;
  for (const s of un.steps) {
    stepNo += 1;
    const wrapped = String(s).replace(/(.{1,66})(\s|$)/g, '$1\n').split('\n').filter((x) => x.length);
    p(`      ${stepNo}. ${wrapped[0]}`);
    for (const cont of wrapped.slice(1)) p(`         ${cont}`);
  }
  p('');
  p(`      ${un.notRemovedByThis.replace(/(.{1,68})(\s|$)/g, '$1\n').split('\n').filter((x) => x.length).join('\n      ')}`);
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

  // THE PLAN'S LINE UNITS AND THE SHIPPED BLOCK ARE THE SAME SET BY
  // CONSTRUCTION: lib/units.js enumerates gitignore units FROM this same
  // gitignore-block.txt. It did not always — it filtered LogicLoom's own
  // .gitignore by prefix, which promised three patterns the block deliberately
  // drops and missed five it ships — and that is exactly why the cross-check
  // below stays. Refusal 8 says we never report a write we did not make; a
  // guarantee that costs one filter to re-assert is worth re-asserting, and if
  // `neverShipped` is ever non-empty again the report says so rather than
  // counting patterns that never landed.
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

// ── target: rules (the harness's operating instructions) ─────────────────────
// THE MODE IS READ, NOT DECIDED. `fresh.claudeMd.resolved` is a pure function of
// the flag/env and whether a CLAUDE.md exists (lib/claude-md.js). Nothing here
// inspects the adopter's file to form an opinion, and there is no branch that
// could produce a different result from the same inputs.
function applyRules(units, ctx, run, result, p, opts, root, fresh) {
  const mode = fresh.claudeMd.resolved;

  if (mode === 'none') {
    p('      MODE none — nothing loadable is installed: no .claude/rules/ files, and your');
    p('      CLAUDE.md is not opened. The harness tree and its reference material under');
    p('      .docs/ still install; wiring the instructions in is yours to do.');
    run.skipped.push({ target: 'rules', path: '.claude/rules/',
      why: 'integration mode `none` — nothing loadable installed, by explicit request' });
    return;
  }

  // 1. The rules files. Same refusals as every other path write.
  const installed = [];
  if (!units.length) {
    p('      every rules file is already present — nothing to install.');
    run.skipped.push({ target: 'rules', path: '.claude/rules/', why: 'all rules files already present' });
  }
  for (const u of units) {
    const src = u.sourceAbs || path.join(ctx.pkgRoot, u.sourcePath);
    const dst = path.join(ctx.rootReal, u.targetPath);
    assertWritableTarget(ctx.rootReal, dst);
    if (detectLib.statKind(src) === 'absent') {
      run.skipped.push({ path: u.targetPath, why: 'the package no longer carries ' + u.sourcePath });
      result.skipped.push({ path: u.targetPath });
      continue;
    }
    if (detectLib.statKind(dst) !== 'absent') {
      run.skipped.push({ path: u.targetPath,
        why: 'REFUSE-EXISTS: a file is already here and it is yours; move it aside yourself if you want ours' });
      result.skipped.push({ path: u.targetPath });
      p(`      SKIP  ${u.targetPath}  (exists — yours, kept)`);
      continue;
    }
    if (opts.dryRunWrites) { p(`      WOULD ${u.targetPath}`); continue; }
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    copyFileNew(src, dst, 0o644);
    run.wrote.push({ target: 'rules', path: u.targetPath, kind: 'file' });
    result.wrote.push({ path: u.targetPath, kind: 'file' });
    installed.push(u.targetPath);
    p(`      WROTE ${u.targetPath}`);
  }

  if (mode === 'rules') {
    p('      MODE rules — your CLAUDE.md was NOT opened, read, or written.');
    p('      These files load at launch at CLAUDE.md priority. Confirm with `/context`');
    p('      → Memory files; if they do not appear, re-run with --claude-md=import.');
    return;
  }

  // 2. MODE import — one marked block appended to THEIR CLAUDE.md.
  const all = fresh.claudeMd.ruleFiles;
  const target = path.join(ctx.rootReal, 'CLAUDE.md');
  assertWritableTarget(ctx.rootReal, target);

  if (detectLib.statKind(target) !== 'file') {
    // Unreachable while resolve() collapses `import` without a CLAUDE.md, but a
    // tree is not frozen between plan and write. Never create the file.
    run.skipped.push({ target: 'rules', path: 'CLAUDE.md',
      why: 'no CLAUDE.md at write time — this tool never creates one' });
    p('      SKIP  CLAUDE.md — it is not there, and this tool never creates it.');
    return;
  }

  const before = fs.readFileSync(target, 'utf8');
  if (claudeMdLib.hasBlock(before)) {
    run.skipped.push({ target: 'rules', path: 'CLAUDE.md',
      why: 'the managed @import block is already present (no-op)' });
    p('      NO-OP CLAUDE.md already carries the managed block.');
    return;
  }
  if (opts.dryRunWrites) { p('      WOULD append the marked @import block to CLAUDE.md'); return; }

  // APPEND, WITH THE APPEND SYSCALL. `appendFileSync` opens 'a', which cannot
  // truncate — so refusal 3 holds by the same kind of mechanism as refusal 1's
  // 'wx' flag rather than by a check a later edit could drop. Building the whole
  // new file and writing it back would be a truncating write against a file the
  // adopter owns; there is deliberately no such code path here.
  const suffix = claudeMdLib.appendSuffix(before, all);
  if (suffix === null || suffix.indexOf(claudeMdLib.BEGIN) === -1) {
    throw new Error('REFUSE-REWRITE: the CLAUDE.md block did not come out as a pure append; nothing was written');
  }
  fs.appendFileSync(target, suffix, 'utf8');
  run.wrote.push({ target: 'rules', path: 'CLAUDE.md', kind: 'merge',
    region: 'the fenced "LogicLoom adopt — managed block"' });
  result.wrote.push({ path: 'CLAUDE.md' });
  p(`      MERGED CLAUDE.md — one marked block, ${all.length} @import line(s), appended at the end.`);
  p('             Everything above it is byte-identical. Uninstall is: delete from the');
  p('             BEGIN marker to the END marker.');
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
  apply, applyRules, TARGETS, ALL_TARGETS, IN_ALL, parseOnly, planDivergence,
  isSecretShaped, insideRoot, assertWritableTarget, copyTree, spawnAllowed,
  SPAWN_ALLOWLIST, SELF_CAUSED, RECEIPT_SCHEMA, RECEIPT_NAME,
  readReceipt, priorRun, effectiveBlocking,
  uninstallProcedure, GITIGNORE_FENCE_BEGIN, GITIGNORE_FENCE_END, SETTINGS_SIDECAR
};
