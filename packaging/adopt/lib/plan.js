'use strict';
// plan.js — assembles the plan object. This is the read-only half's whole
// output, and the applier's only input.
//
// The plan WRITES NOTHING. Not a lockfile, not a cache, not a temp file in the
// target. `logicloom init` on a repo you do not own is safe by
// construction, and that property is what makes it worth running first.
//
// The emitted shape is specified in PLAN-FORMAT.md, which is the contract the
// applier is written against. Change the shape, bump `schema`.

const fs = require('node:fs');
const path = require('node:path');

const detectLib = require('./detect');
const manifestLib = require('./manifest');
const unitsLib = require('./units');
const classifyLib = require('./classify');
const preLib = require('./preconditions');
const claudeMdLib = require('./claude-md');

const SCHEMA = 'logicloom/adopt-plan@1';

// Resolve where the payload (the harness tree that would be installed) lives.
// Three sources, in order, and the plan RECORDS which one was used — a plan
// built against a dev checkout is not the same artifact as one built against a
// packed payload, and pretending otherwise is how a stale boundary ships.
function resolvePayloadRoot(pkgRoot, override) {
  if (override) {
    return { root: path.resolve(override), source: 'explicit --payload' };
  }
  if (process.env.LOOM_ADOPT_PAYLOAD) {
    return { root: path.resolve(process.env.LOOM_ADOPT_PAYLOAD), source: 'LOOM_ADOPT_PAYLOAD' };
  }
  // A PACKED PAYLOAD IS RECOGNISED BY ITS CONTENT, NOT BY ITS NAME. `payload/`
  // also holds the authored `payload/rules/*.md` in a dev checkout, where the
  // harness tree is NOT beneath it — the repo root two levels up is. Treating a
  // bare-existing `payload/` as the packed tree would point every `include:` row
  // at a directory that does not have it, and every unit would classify as an
  // R0 payload defect. `.logic-loom/` is the marker because it is the one entry
  // no packed payload can lack.
  const packed = path.join(pkgRoot, 'payload');
  try {
    if (fs.statSync(packed).isDirectory() && fs.statSync(path.join(packed, '.logic-loom')).isDirectory()) {
      return { root: packed, source: 'packaged payload/' };
    }
  } catch (e) { /* not packed yet */ }
  // Development fallback: packaging/adopt/ lives inside the LogicLoom repo, so
  // the repo root two levels up IS the payload source. Reported as such.
  const devRoot = path.resolve(pkgRoot, '..', '..');
  return { root: devRoot, source: 'DEV FALLBACK — the LogicLoom checkout containing this package' };
}

function build(opts) {
  const pkgRoot = opts.pkgRoot;
  const targetRoot = path.resolve(opts.target);
  const payload = resolvePayloadRoot(pkgRoot, opts.payload);

  const notes = [];
  const errors = [];

  if (payload.source.indexOf('DEV FALLBACK') === 0) {
    notes.push('PAYLOAD SOURCE IS A DEV CHECKOUT, not a packed payload. The classification ' +
      'is against the working tree at ' + payload.root + ', which may differ from any released tag.');
  }

  // Manifest
  const manifestPath = opts.manifest || path.join(pkgRoot, 'payload-manifest.txt');
  let parsed = null;
  try {
    parsed = manifestLib.load(manifestPath);
  } catch (e) {
    errors.push('payload manifest unreadable at ' + manifestPath + ': ' + e.message);
  }
  if (parsed && parsed.errors.length) {
    for (const e of parsed.errors) errors.push(`payload-manifest.txt:${e.lineNo} ${e.error} — "${e.line}"`);
  }

  // Detect
  const detected = detectLib.detect(targetRoot);

  // Enumerate + classify
  let units = [];
  let unitErrors = [];
  if (parsed) {
    const en = unitsLib.enumerate(payload.root, parsed, pkgRoot);
    units = en.units;
    unitErrors = en.errors;
  }
  for (const e of unitErrors) errors.push(e);

  const ctx = { root: targetRoot, payloadRoot: payload.root, surfaces: detected.surfaces };
  const { classified, buckets } = classifyLib.classifyAll(units, ctx);
  const obsolete = classifyLib.findObsolete(targetRoot, detected.surfaces);

  for (const e of buckets.error) {
    errors.push(`payload defect: ${e.sourcePath} named by the manifest is not in the payload`);
  }

  // ── The integration mode: how our instructions reach the model here ───────
  // Resolved BEFORE preconditions, because under `import` the adopter's
  // CLAUDE.md becomes a merge target and a dirty one must block.
  const req = claudeMdLib.requestedMode(opts.claudeMd, opts.env || process.env);
  if (req.error) errors.push(req.error);
  const hasClaudeMd = (detected.surfaces.agentConfig || [])
    .some((a) => a.path === 'CLAUDE.md' && a.kind === 'file');
  const cmd = claudeMdLib.resolve(req.error ? null : req, hasClaudeMd);
  const ruleTargets = classified
    .filter((u) => u.granularity === 'rules')
    .map((u) => u.targetPath).sort();

  // Preconditions
  const preconditions = preLib.evaluate(detected, classified, { claudeMdMode: cmd.resolved });

  // The deferred manifest rows — the installer must refuse while any stands.
  const defers = parsed ? parsed.defers.map((d) => ({
    path: d.path, question: d.arg, manifestLine: d.lineNo
  })) : [];
  if (defers.length) {
    preconditions.blocking.push({
      code: 'MANIFEST-DEFER-OPEN',
      severity: 'blocking',
      path: manifestPath,
      detail: `${defers.length} \`defer:\` row(s) stand in the payload manifest: ` +
              defers.map((d) => d.path).join(', ') +
              '. The manifest\'s own grammar says the installer must refuse to run while one does.',
      remedy: 'resolve the deferred rows in packaging/adopt/payload-manifest.txt (maintainer task, not the adopter\'s)'
    });
    preconditions.all.push(preconditions.blocking[preconditions.blocking.length - 1]);
  }

  // Named limits that belong in the output, not in a doc the adopter will not read.
  notes.push('The harness test suite (tests/) is NOT installed. If you later edit the harness ' +
    '(via /create-plugin, say) you have no local regression suite — clone LogicLoom itself for ' +
    'harness development.');
  notes.push('No .github/ workflow is installed. LogicLoom\'s own workflows encode LogicLoom\'s ' +
    'branch topology and would fail every PR you open.');
  notes.push('`replace` is empty by design. This tool never claims LogicLoom\'s copy of a file ' +
    'you already have is better than yours; every collision defaults to keep-theirs and is printed.');

  const applyReady = preconditions.blocking.length === 0 && errors.length === 0;

  return {
    schema: SCHEMA,
    generatedAt: new Date().toISOString(),
    generator: {
      package: opts.pkgName || 'logicloom',
      version: opts.pkgVersion || 'unknown',
      nodeVersion: process.version
    },
    payload: {
      root: payload.root,
      source: payload.source,
      manifest: manifestPath,
      manifestEntries: parsed ? parsed.entries.length : 0
    },
    mode: {
      mode: detected.mode.mode,
      reason: detected.mode.reason,
      content: detected.mode.content
    },
    target: {
      root: detected.root,
      isGitRepo: detected.git.isGitRepo,
      gitDetect: detected.git.gitDetect,
      hasCommits: detected.git.hasCommits,
      headState: detected.git.headState,
      currentBranch: detected.git.currentBranch,
      defaultBranch: detected.git.defaultBranch,
      defaultBranchSource: detected.git.defaultBranchSource,
      branches: detected.git.branches,
      inProgress: detected.git.inProgress,
      trackedFiles: detected.git.trackedCount,
      adoption: detected.adoption
    },
    detect: {
      agentConfig: detected.surfaces.agentConfig,
      claude: summariseClaude(detected.surfaces.claude),
      memoryDirs: detected.surfaces.memoryDirs,
      taskFiles: detected.surfaces.taskFiles,
      ci: detected.surfaces.ci,
      tests: detected.surfaces.tests,
      gitignore: { kind: detected.surfaces.gitignore.kind,
                   lineCount: Array.isArray(detected.surfaces.gitignore.lines)
                     ? detected.surfaces.gitignore.lines.length : detectLib.UNKNOWN },
      gitattributes: detected.surfaces.gitattributes,
      rootManifest: {
        present: detected.surfaces.rootManifest.present,
        files: detected.surfaces.rootManifest.files,
        ecosystem: detected.surfaces.rootManifest.ecosystem
      },
      productWorkspaces: detected.surfaces.productWorkspaces,
      productSourceAtRoot: productSourceAtRoot(detected)
    },
    preconditions: {
      blocking: preconditions.blocking,
      warnings: preconditions.warnings
    },
    buckets: {
      additive: buckets.additive.map(publicUnit),
      'keep-theirs': buckets['keep-theirs'].map(publicUnit),
      replace: buckets.replace.map(publicUnit),
      obsolete: obsolete
    },
    counts: {
      additive: buckets.additive.length,
      'keep-theirs': buckets['keep-theirs'].length,
      replace: buckets.replace.length,
      obsolete: obsolete.length,
      total: classified.length
    },
    claudeMd: {
      requested: cmd.requested,
      resolved: cmd.resolved,
      source: cmd.source,
      asked: cmd.asked,
      collapsed: !!cmd.collapsed,
      reason: cmd.reason,
      targetHasClaudeMd: hasClaudeMd,
      ruleFiles: ruleTargets,
      options: claudeMdLib.MODES.map((m) => ({ mode: m, summary: claudeMdLib.MODE_SUMMARY[m] })),
      flag: claudeMdLib.FLAG,
      env: claudeMdLib.ENV_VAR
    },
    defers: defers,
    errors: errors,
    notes: notes,
    applyReady: applyReady
  };
}

function summariseClaude(c) {
  if (!c) return { kind: 'absent' };
  return {
    kind: c.kind,
    subdirs: c.subdirs,
    settings: c.settings ? { kind: c.settings.kind, parse: c.settings.parse, indent: c.settings.indent,
                             hookEvents: c.settings.value && c.settings.value.hooks
                               ? Object.keys(c.settings.value.hooks) : [] } : { kind: 'absent' },
    settingsLocal: c.settingsLocal ? { kind: c.settingsLocal.kind } : { kind: 'absent' }
  };
}

// "Does product source sit at the repo root?" — reported as a THREE-state answer.
// A yes/no here would be a guess: a root package.json with a `web/` workspace is
// not product-at-root, and a root src/ with no manifest might be anything.
function productSourceAtRoot(detected) {
  const s = detected.surfaces;
  const hasWorkspace = s.productWorkspaces.some((w) => w.dir !== 'src');
  if (!s.rootManifest.present && !hasWorkspace) {
    return { answer: 'unknown', reason: 'no root manifest and no recognised workspace directory' };
  }
  if (hasWorkspace && s.rootManifest.present) {
    return { answer: 'no',
             reason: 'root manifest plus a workspace dir (' +
                     s.productWorkspaces.map((w) => w.dir).join(', ') + ') — product is in its own workspace' };
  }
  if (s.rootManifest.present && !hasWorkspace) {
    return { answer: 'yes',
             reason: 'root manifest (' + s.rootManifest.files.join(', ') +
                     ') and no separate workspace directory — the product appears to live at the root. ' +
                     'The harness owns the repo root, so its root files and yours share a directory.' };
  }
  return { answer: 'unknown', reason: 'workspace dirs present but no root manifest to attribute them to' };
}

// The applier's view of a unit. Deliberately strips the payload-side internals
// (raw file text, parsed JSON) so a plan file is diffable and reviewable.
function publicUnit(u) {
  const out = {
    id: u.id,
    kind: u.kind,
    granularity: u.granularity,
    sourcePath: u.sourcePath,
    targetPath: u.targetPath,
    action: u.bucket === 'keep-theirs' ? 'skip' : u.action,
    bucket: u.bucket,
    rule: u.rule,
    reason: u.reason
  };
  if (u.renamedFrom) out.renamedFrom = u.renamedFrom;
  if (u.sourceRoot) out.sourceRoot = u.sourceRoot;
  if (u.strategy) out.strategy = u.strategy;
  if (u.selector) out.selector = u.selector;
  if (u.value !== undefined) out.value = u.value;
  if (u.manifestLine) out.manifestLine = u.manifestLine;
  if (u.counterpart) {
    out.targetExists = u.counterpart.exists;
    if (u.counterpart.kind) out.targetKind = u.counterpart.kind;
    if (u.counterpart.identical !== undefined) out.identical = u.counterpart.identical;
  }
  if (u.replaceTest) out.replaceTest = u.replaceTest;
  return out;
}

module.exports = { build, SCHEMA, resolvePayloadRoot, publicUnit, productSourceAtRoot };
