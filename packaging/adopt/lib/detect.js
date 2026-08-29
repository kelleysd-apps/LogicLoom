'use strict';
// detect.js — READ-ONLY detection of what the TARGET repository already has.
//
// The rule this file follows everywhere: report `unknown` rather than guess.
// A guess here becomes a classification, and a wrong classification becomes an
// apply that overwrites something a human wrote. Every field below is either a
// fact read off disk, a fact read from an allowlisted git verb, or the string
// 'unknown' with a `*Reason` field naming why.
//
// Writes nothing. Creates nothing. Runs no mutating git (see lib/git-ro.js for
// the allowlist and for why this tool shells out where
// detect-environment-topology.sh deliberately does not).

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const gitro = require('./git-ro');

const UNKNOWN = 'unknown';

function statKind(p) {
  try {
    const st = fs.lstatSync(p);
    if (st.isSymbolicLink()) return 'symlink';
    if (st.isDirectory()) return 'dir';
    if (st.isFile()) return 'file';
    return 'other';
  } catch (e) {
    if (e && e.code === 'ENOENT') return 'absent';
    return UNKNOWN;
  }
}

function readTextOrNull(p) {
  try { return fs.readFileSync(p, 'utf8'); } catch (e) { return null; }
}

function listDir(p) {
  try { return fs.readdirSync(p).sort(); } catch (e) { return null; }
}

function countLines(p) {
  const t = readTextOrNull(p);
  if (t === null) return null;
  return t.length === 0 ? 0 : t.split('\n').length;
}

// ── git facts ────────────────────────────────────────────────────────────────
function detectGit(root) {
  const g = {
    isGitRepo: false,
    gitDetect: 'none',          // dir | worktree | none | unknown
    gitAvailable: true,
    hasCommits: UNKNOWN,
    headState: UNKNOWN,         // attached | detached | unborn | unknown
    currentBranch: UNKNOWN,
    defaultBranch: UNKNOWN,
    defaultBranchSource: 'none',
    branches: [],
    inProgress: [],             // rebase / merge / cherry-pick / revert / bisect
    porcelain: null,            // raw `git status --porcelain` lines, or null
    trackedCount: UNKNOWN,
    // `git rev-parse --show-toplevel` for THIS root, regardless of which of
    // the three isGitRepo paths below found it. Used by preconditions.js to
    // catch a NESTED install — `root` is a git work tree, but not its own
    // toplevel, meaning it is a subdirectory of a larger repo (a monorepo
    // package, say). payload-manifest.txt already declares nested installs
    // unsupported: every installed hook command is cwd-relative, so hooks
    // invoked from the real repo root would never find what got written here.
    toplevel: UNKNOWN,
    reason: null
  };

  const dotgit = path.join(root, '.git');
  const kind = statKind(dotgit);
  if (kind === 'dir') { g.isGitRepo = true; g.gitDetect = 'dir'; }
  else if (kind === 'file') { g.isGitRepo = true; g.gitDetect = 'worktree'; }
  else {
    // Could still be a subdirectory of a repo; ask git rather than assume.
    let top = null;
    try { top = gitro.tryLine(root, ['rev-parse', '--show-toplevel']); }
    catch (e) { g.gitAvailable = false; g.reason = e.message; return g; }
    if (top) { g.isGitRepo = true; g.gitDetect = 'dir'; }
    else { g.reason = 'no .git at the given root and git reports no work tree'; return g; }
  }

  let gitDirAbs = null;
  try {
    gitDirAbs = gitro.tryLine(root, ['rev-parse', '--absolute-git-dir']);
  } catch (e) {
    g.gitAvailable = false; g.reason = e.message; return g;
  }

  // One extra call, always made once `isGitRepo` is settled — the subdirectory
  // branch above already ran the same verb to answer a DIFFERENT question
  // (is this a repo at all?); this answers "is `root` the repo's OWN root?".
  const top = gitro.tryLine(root, ['rev-parse', '--show-toplevel']);
  g.toplevel = top || UNKNOWN;

  // Commits present?
  const headSha = gitro.tryLine(root, ['rev-parse', '--verify', '--quiet', 'HEAD']);
  g.hasCommits = headSha !== null;

  if (!g.hasCommits) {
    g.headState = 'unborn';
    const sym = gitro.tryLine(root, ['rev-parse', '--abbrev-ref', 'HEAD']);
    g.currentBranch = sym || UNKNOWN;
  } else {
    const abbrev = gitro.tryLine(root, ['rev-parse', '--abbrev-ref', 'HEAD']);
    if (abbrev === 'HEAD') { g.headState = 'detached'; g.currentBranch = UNKNOWN; }
    else if (abbrev) { g.headState = 'attached'; g.currentBranch = abbrev; }
    else { g.headState = UNKNOWN; }
  }

  const br = gitro.lines(root, ['branch', '--format=%(refname:short)']);
  g.branches = br === null ? [] : br.map((s) => s.trim()).filter(Boolean);

  const originHead = gitro.tryLine(root, ['rev-parse', '--abbrev-ref', 'origin/HEAD']);
  if (originHead && originHead.indexOf('/') !== -1) {
    g.defaultBranch = originHead.slice(originHead.indexOf('/') + 1);
    g.defaultBranchSource = 'origin/HEAD';
  } else if (g.branches.indexOf('main') !== -1) {
    g.defaultBranch = 'main'; g.defaultBranchSource = 'branch-name-heuristic';
  } else if (g.branches.indexOf('master') !== -1) {
    g.defaultBranch = 'master'; g.defaultBranchSource = 'branch-name-heuristic';
  } else {
    g.defaultBranch = UNKNOWN; g.defaultBranchSource = 'none';
  }

  // In-progress operations. These are directory/file markers inside the git dir;
  // there is no read-only git verb that reports them as a set.
  if (gitDirAbs) {
    const marks = [
      ['rebase-merge', 'rebase'],
      ['rebase-apply', 'rebase'],
      ['MERGE_HEAD', 'merge'],
      ['CHERRY_PICK_HEAD', 'cherry-pick'],
      ['REVERT_HEAD', 'revert'],
      ['BISECT_LOG', 'bisect']
    ];
    for (const [f, name] of marks) {
      if (statKind(path.join(gitDirAbs, f)) !== 'absent') {
        if (g.inProgress.indexOf(name) === -1) g.inProgress.push(name);
      }
    }
  }

  const st = gitro.lines(root, ['status', '--porcelain', '--untracked-files=normal']);
  g.porcelain = st === null ? null : st;

  const tracked = gitro.lines(root, ['ls-files']);
  g.trackedCount = tracked === null ? UNKNOWN : tracked.length;

  return g;
}

// Porcelain-v1 status codes → a per-path record. Handles the rename form
// `R  old -> new` and quoted paths (core.quotepath).
function parsePorcelain(porcelain) {
  const map = new Map();
  if (!porcelain) return map;
  for (const line of porcelain) {
    if (line.length < 4) continue;
    const x = line.charAt(0);
    const y = line.charAt(1);
    let rest = line.slice(3);
    let p = rest;
    const arrow = rest.indexOf(' -> ');
    if (arrow !== -1) p = rest.slice(arrow + 4);
    if (p.charAt(0) === '"' && p.charAt(p.length - 1) === '"') {
      p = p.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
    }
    map.set(p, {
      path: p,
      indexStatus: x,
      worktreeStatus: y,
      untracked: x === '?' && y === '?',
      ignored: x === '!' && y === '!',
      dirty: !(x === '?' && y === '?') && !(x === '!' && y === '!')
    });
  }
  return map;
}

// Is `relPath` — a file OR a directory prefix — dirty or untracked?
//
// THE MATCH IS BIDIRECTIONAL, and getting this wrong silently defeats the whole
// precondition check. `git status --porcelain` COLLAPSES untracked directories:
// a repo with `.claude/commands/mine.md` untracked reports `?? .claude/`, not
// the file. So there are two ways a status entry can concern a target path:
//
//   (a) the entry is AT or BENEATH the target   — `.claude/commands/x` vs `.claude/commands`
//   (b) the entry is a directory ABOVE it       — `.claude/`             vs `.claude/commands`
//
// Checking only (a) — the obvious direction — reports "clean" for a target whose
// entire parent directory is untracked, which is exactly the case where the
// adopter has the most unsaved work at stake.
function statusFor(statusMap, relPath) {
  const hits = [];
  const target = relPath.replace(/\/+$/, '');
  const beneath = target + '/';
  for (const [p, rec] of statusMap) {
    const entry = p.replace(/\/+$/, '');
    if (entry === target) { hits.push(rec); continue; }
    if (entry.indexOf(beneath) === 0) { hits.push(rec); continue; }   // (a)
    // (b) — only when the status entry was reported AS a directory (trailing
    // slash). A plain file path that happens to be a string prefix is not a
    // parent, and treating it as one would invent hits.
    if (p !== entry && target.indexOf(entry + '/') === 0) hits.push(rec);
  }
  return hits;
}

// ── execution environment ────────────────────────────────────────────────────
// What would actually RUN an apply on the adopter's machine, as opposed to
// everything above (which is about their REPO). Same rule as the rest of this
// file: report what was found, never guess, never throw, never write.
//
// PRESENCE ON PATH IS NOT ENOUGH for python3 — a stub, a wrapper, or (on
// Windows) the App Execution Alias can sit on PATH, exit 0, and do nothing. So
// python3 is PROBED: actually invoked with a short timeout and the answer it
// gives is what gets recorded, not the mere fact that a file exists.
//
// bash is resolved the same way the adopter's shell WOULD resolve it — via
// PATH, not `/bin/bash` — because the shipped scripts are invoked as
// `#!/usr/bin/env bash`, and on macOS a Homebrew bash on PATH can be an
// entirely different major version from the stock `/bin/bash`.
//
// Every probe is bounded (short timeout, no shell, argv array — the same
// spawn discipline lib/apply.js's spawnAllowed() and lib/git-ro.js's run()
// already use) and every failure mode — not found, found but exits non-zero,
// found but times out, found but answers something unparseable — resolves to
// a recorded fact, never a thrown exception. detect() has no permission to
// throw; a probe that can't answer just says so.
const ENV_PROBE_TIMEOUT_MS = 3000;

// Resolve `exe` the way PATH lookup would, for REPORTING only — this is not
// the mechanism that runs anything (spawnSync below does its own PATH
// resolution independently); it exists purely so the recorded fact names
// WHICH executable would run, since two different `bash`es on the same
// machine can be different major versions.
function resolveOnPath(exe) {
  const pathEnv = process.env.PATH || '';
  const dirs = pathEnv.split(path.delimiter).filter(Boolean);
  const exts = process.platform === 'win32'
    ? (process.env.PATHEXT || '.EXE;.CMD;.BAT').split(';')
    : [''];
  for (const d of dirs) {
    for (const ext of exts) {
      const candidate = path.join(d, exe + ext);
      try {
        fs.accessSync(candidate, fs.constants.X_OK);
        return candidate;
      } catch (e) { /* not this one */ }
    }
  }
  return null;
}

// Bounded spawn: no shell, argv array, short timeout, and every failure mode
// (missing, spawn error, timeout, non-zero exit) comes back as data.
function runBounded(exe, args) {
  let r;
  try {
    r = spawnSync(exe, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: ENV_PROBE_TIMEOUT_MS,
      maxBuffer: 1024 * 1024,
      shell: false
    });
  } catch (e) {
    return { ok: false, reason: 'threw: ' + e.message };
  }
  if (r.error) {
    if (r.error.code === 'ENOENT') return { ok: false, reason: 'not found' };
    return { ok: false, reason: 'spawn error: ' + r.error.message };
  }
  if (r.signal) return { ok: false, reason: 'timed out (killed with ' + r.signal + ')' };
  return {
    ok: r.status === 0,
    status: typeof r.status === 'number' ? r.status : -1,
    stdout: String(r.stdout || '').trim(),
    stderr: String(r.stderr || '').trim()
  };
}

function probePython3() {
  const resolvedPath = resolveOnPath('python3');
  const rec = { name: 'python3', resolvedPath, present: resolvedPath !== null, usable: false, version: UNKNOWN, detail: null };
  if (!resolvedPath) { rec.detail = 'not found on PATH'; return rec; }
  const r = runBounded('python3', ['-c', 'import sys; print(sys.version_info[0], sys.version.split()[0])']);
  if (!r.ok) {
    rec.detail = 'found on PATH at ' + resolvedPath + ' but could not be run (' +
      (r.reason || ('exited ' + r.status + (r.stderr ? ': ' + r.stderr.slice(0, 200) : ''))) + ')';
    return rec;
  }
  const parts = r.stdout.split(/\s+/);
  const major = parts[0];
  const version = parts[1] || UNKNOWN;
  rec.version = version;
  // Anything that is not a bare major digit means the thing on PATH did not
  // answer the question we asked — a wrapper, a shim, a Windows Store alias, a
  // Python 2 whose print syntax made this a tuple. Say THAT, rather than
  // interpolating its output into a sentence shaped like a version report:
  // a stub echoing "Python 2.7.18" produced "reports Python Python (2.7.18)".
  if (!/^[0-9]+$/.test(major)) {
    rec.detail = 'found on PATH at ' + resolvedPath + ' but did not answer a ' +
      'version probe in the expected form (got ' + JSON.stringify(r.stdout.slice(0, 120)) +
      ') — treat it as present but unusable';
    return rec;
  }
  if (major !== '3') {
    rec.detail = 'found on PATH at ' + resolvedPath + ' but reports Python ' + major +
      ' (' + version + '), not Python 3 — present but unusable';
    return rec;
  }
  rec.usable = true;
  rec.detail = 'usable — Python ' + version + ' at ' + resolvedPath;
  return rec;
}

function probeBash() {
  const resolvedPath = resolveOnPath('bash');
  const rec = { name: 'bash', resolvedPath, present: resolvedPath !== null, usable: false, version: UNKNOWN, detail: null };
  if (!resolvedPath) {
    rec.detail = 'not found on PATH — the .gitignore merge and the installed hooks need bash';
    return rec;
  }
  // Resolved via PATH (not /bin/bash) on purpose: `#!/usr/bin/env bash` means
  // PATH decides which bash runs, and that is the one worth reporting.
  const r = runBounded('bash', ['-c', 'printf %s "$BASH_VERSION"']);
  if (!r.ok || !r.stdout) {
    rec.detail = 'found on PATH at ' + resolvedPath + ' but could not be run (' +
      (r.reason || 'reported no $BASH_VERSION') + ')';
    return rec;
  }
  rec.version = r.stdout;
  rec.usable = true;
  rec.detail = 'usable — bash ' + r.stdout + ' at ' + resolvedPath +
    ' (the shipped merge scripts target the 3.2 floor; any bash >= 3.2 is fine)';
  return rec;
}

function probeGit() {
  const resolvedPath = resolveOnPath('git');
  const rec = { name: 'git', resolvedPath, present: resolvedPath !== null, usable: false, version: UNKNOWN, detail: null };
  if (!resolvedPath) { rec.detail = 'not found on PATH'; return rec; }
  const r = runBounded('git', ['--version']);
  if (!r.ok || !r.stdout) {
    rec.detail = 'found on PATH at ' + resolvedPath + ' but `git --version` failed (' + (r.reason || 'exit ' + r.status) + ')';
    return rec;
  }
  const m = /version\s+(\S+)/.exec(r.stdout);
  rec.version = m ? m[1] : r.stdout;
  rec.usable = true;
  rec.detail = 'usable — ' + r.stdout + ' at ' + resolvedPath;
  return rec;
}

// jq — PRESENCE ONLY, no invocation. Unlike python3/bash it is never spawned
// by this package (it is not on lib/apply.js's SPAWN_ALLOWLIST and this change
// does not add it there just to print a version string); it matters only to
// hooks the PAYLOAD installs and runs in later Claude Code sessions, long
// after this planner has exited. A PATH lookup is the whole probe.
function probeJq() {
  const resolvedPath = resolveOnPath('jq');
  return {
    name: 'jq',
    resolvedPath,
    present: resolvedPath !== null,
    usable: resolvedPath !== null,
    version: UNKNOWN,
    detail: resolvedPath !== null ? ('found on PATH at ' + resolvedPath) : 'not found on PATH'
  };
}

// The floor this PACKAGE declares for itself, read from its own package.json
// rather than threaded through as an argument — detect() is called with just a
// target root everywhere in this codebase, so this is the one way to get the
// declared floor into a detection that runs before any --only is known.
function readDeclaredNodeFloor() {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
    return (pkg.engines && pkg.engines.node) || null;
  } catch (e) {
    return null;
  }
}

function parseSemver(v) {
  const m = /(\d+)\.(\d+)\.(\d+)/.exec(String(v));
  if (!m) return null;
  return [parseInt(m[1], 10), parseInt(m[2], 10), parseInt(m[3], 10)];
}

// true/false, or UNKNOWN when either side does not parse as semver.
function meetsFloor(runningVersion, floorSpec) {
  const running = parseSemver(runningVersion);
  const floor = parseSemver(floorSpec);
  if (!running || !floor) return UNKNOWN;
  for (let i = 0; i < 3; i++) {
    if (running[i] > floor[i]) return true;
    if (running[i] < floor[i]) return false;
  }
  return true;
}

function probeNode() {
  const declaredFloor = readDeclaredNodeFloor();
  const running = process.version;
  const meets = declaredFloor ? meetsFloor(running, declaredFloor) : UNKNOWN;
  return {
    name: 'node',
    resolvedPath: process.execPath,
    present: true,
    usable: true,
    version: running,
    declaredFloor: declaredFloor || UNKNOWN,
    meetsFloor: meets,
    detail: !declaredFloor
      ? 'running ' + running + '; the package\'s declared floor could not be read'
      : 'running ' + running + (meets === false
        ? ' — BELOW the declared floor ' + declaredFloor
        : ' — meets the declared floor ' + declaredFloor)
  };
}

// Never throws. Every probe above already resolves its own failures to data,
// but this is a second belt: a probe function throwing for an unanticipated
// reason must still leave detect() returning a plan, not an exception.
function safeProbe(fn, name) {
  try {
    return fn();
  } catch (e) {
    return { name, resolvedPath: null, present: UNKNOWN, usable: false, version: UNKNOWN, detail: 'probe threw: ' + e.message };
  }
}

function detectEnvironment() {
  return {
    python3: safeProbe(probePython3, 'python3'),
    bash: safeProbe(probeBash, 'bash'),
    git: safeProbe(probeGit, 'git'),
    node: safeProbe(probeNode, 'node'),
    jq: safeProbe(probeJq, 'jq'),
    // No `process.platform` check exists anywhere else in this package. Both
    // merge scripts and every installed hook are POSIX shell, cwd-relative
    // `.sh`; there is no native-Windows code path. Recorded here so a Windows
    // adopter sees the honest posture before anything else does.
    platform: process.platform
  };
}

// ── target-repo surface detection ────────────────────────────────────────────
const AGENT_CONFIG_PATHS = [
  'CLAUDE.md',
  'CLAUDE.local.md',
  'AGENTS.md',
  '.cursorrules',
  '.cursor/rules',
  '.github/copilot-instructions.md',
  '.windsurfrules',
  'GEMINI.md',
  '.aider.conf.yml'
];

const CLAUDE_SUBDIRS = ['hooks', 'commands', 'agents', 'skills', 'rules', 'context', 'policies', 'schemas', 'plugins'];

const MEMORY_CANDIDATES = [
  '.brain/memory',
  '.brain',
  '.logic-loom/memory',
  '.claude/memory',
  'memory',
  '.ai/memory'
];

const TASK_FILE_CANDIDATES = [
  'TODO.md', 'TODOS.md', 'BACKLOG.md', 'backlog.md', 'todos.md',
  '.logic-loom/memory/todos.md', '.logic-loom/memory/backlog.md',
  'docs/backlog.md', 'ROADMAP.md', 'WORKSTREAMS.md'
];

const CI_DIRS = [
  ['.github/workflows', 'github-actions'],
  ['.gitlab-ci.yml', 'gitlab-ci'],
  ['.circleci/config.yml', 'circleci'],
  ['Jenkinsfile', 'jenkins'],
  ['azure-pipelines.yml', 'azure-pipelines']
];

const ROOT_MANIFESTS = [
  ['package.json', 'node'],
  ['pyproject.toml', 'python'],
  ['setup.py', 'python'],
  ['Cargo.toml', 'rust'],
  ['go.mod', 'go'],
  ['Gemfile', 'ruby'],
  ['pom.xml', 'java-maven'],
  ['build.gradle', 'java-gradle'],
  ['composer.json', 'php'],
  ['deno.json', 'deno'],
  ['deno.jsonc', 'deno']
];

// Directory names that mean "the product lives in its own workspace", per the
// harness's Harness ↔ product boundary.
const PRODUCT_WORKSPACE_DIRS = ['web', 'apps', 'packages', 'services', 'src'];

function detectSurfaces(root) {
  const s = {};

  s.agentConfig = AGENT_CONFIG_PATHS.map((p) => {
    const abs = path.join(root, p);
    const kind = statKind(abs);
    const rec = { path: p, kind };
    if (kind === 'file') rec.lines = countLines(abs);
    if (kind === 'dir') { const l = listDir(abs); rec.entries = l ? l.length : UNKNOWN; }
    return rec;
  });

  // .claude/ tree
  const claudeKind = statKind(path.join(root, '.claude'));
  s.claude = { kind: claudeKind, subdirs: {}, settings: null, settingsLocal: null };
  if (claudeKind === 'dir') {
    for (const d of CLAUDE_SUBDIRS) {
      const abs = path.join(root, '.claude', d);
      const k = statKind(abs);
      if (k !== 'absent') {
        const l = listDir(abs);
        s.claude.subdirs[d] = { kind: k, entries: l === null ? UNKNOWN : l.length, names: l === null ? [] : l.slice(0, 40) };
      }
    }
    s.claude.settings = readJsonReport(path.join(root, '.claude', 'settings.json'));
    s.claude.settingsLocal = readJsonReport(path.join(root, '.claude', 'settings.local.json'));
  }

  s.memoryDirs = MEMORY_CANDIDATES
    .map((p) => ({ path: p, kind: statKind(path.join(root, p)) }))
    .filter((r) => r.kind !== 'absent');

  s.taskFiles = TASK_FILE_CANDIDATES
    .map((p) => ({ path: p, kind: statKind(path.join(root, p)) }))
    .filter((r) => r.kind !== 'absent');

  // CI
  s.ci = { provider: 'none', evidence: null, workflows: [] };
  for (const [p, name] of CI_DIRS) {
    const abs = path.join(root, p);
    const k = statKind(abs);
    if (k === 'dir') {
      const l = listDir(abs) || [];
      const wf = l.filter((f) => /\.ya?ml$/.test(f));
      if (wf.length) { s.ci.provider = name; s.ci.evidence = p; s.ci.workflows = wf; break; }
      s.ci.provider = name + '-empty'; s.ci.evidence = p + ' (no workflows)';
    } else if (k === 'file') {
      s.ci.provider = name; s.ci.evidence = p; break;
    }
  }

  // Test setup — presence only. What a runner DOES is not inferable from a name.
  s.tests = { dirs: [], configs: [], scripts: [] };
  for (const d of ['tests', 'test', '__tests__', 'spec']) {
    if (statKind(path.join(root, d)) === 'dir') s.tests.dirs.push(d);
  }
  for (const f of ['jest.config.js', 'jest.config.ts', 'vitest.config.ts', 'vitest.config.js',
                   'pytest.ini', 'tox.ini', 'playwright.config.ts', 'karma.conf.js']) {
    if (statKind(path.join(root, f)) === 'file') s.tests.configs.push(f);
  }

  // .gitignore / .gitattributes
  s.gitignore = { kind: statKind(path.join(root, '.gitignore')) };
  if (s.gitignore.kind === 'file') {
    const t = readTextOrNull(path.join(root, '.gitignore'));
    s.gitignore.lines = t === null ? UNKNOWN : t.split('\n');
  }
  s.gitattributes = { kind: statKind(path.join(root, '.gitattributes')) };

  // Root manifest + product-at-root question
  s.rootManifest = { present: false, files: [], ecosystem: UNKNOWN };
  for (const [f, eco] of ROOT_MANIFESTS) {
    if (statKind(path.join(root, f)) === 'file') {
      s.rootManifest.present = true;
      s.rootManifest.files.push(f);
      if (s.rootManifest.ecosystem === UNKNOWN) s.rootManifest.ecosystem = eco;
    }
  }
  if (s.rootManifest.files.indexOf('package.json') !== -1) {
    s.rootManifest.packageJson = readJsonReport(path.join(root, 'package.json'));
  }

  s.productWorkspaces = PRODUCT_WORKSPACE_DIRS
    .map((d) => ({ dir: d, kind: statKind(path.join(root, d)) }))
    .filter((r) => r.kind === 'dir');

  return s;
}

function readJsonReport(abs) {
  const kind = statKind(abs);
  if (kind === 'absent') return { kind: 'absent' };
  const text = readTextOrNull(abs);
  if (text === null) return { kind, parse: UNKNOWN, reason: 'unreadable' };
  let value = null; let parse = 'ok'; let reason = null;
  try { value = JSON.parse(text); }
  catch (e) { parse = 'invalid'; reason = e.message; }
  // Indentation sniffing, husky-style: never reformat a file we do not own.
  let indent = UNKNOWN;
  const m = /\n([ \t]+)"/.exec(text);
  if (m) indent = m[1] === '\t' ? 'tab' : String(m[1].length);
  return { kind, parse, reason, value, indent, text };
}

// ── "is this repo already LogicLoom?" ────────────────────────────────────────
// Deliberately evidence-based and printed, not a single boolean sniff: this is
// the check that stops the tool proposing to reinstall the harness over itself.
function detectAdoption(root) {
  const evidence = [];
  const markers = [
    ['.logic-loom/memory/constitution.md', 'constitution'],
    ['.logic-loom/scripts/bash', 'harness scripts'],
    ['plugins/loom-governance', 'governance plugin'],
    ['.claude/hooks', 'hooks tree'],
    ['.sdd-sync-ref', 'update-framework baseline']
  ];
  for (const [p, why] of markers) {
    if (statKind(path.join(root, p)) !== 'absent') evidence.push({ path: p, why });
  }
  let version = UNKNOWN;
  const claudeMd = readTextOrNull(path.join(root, 'CLAUDE.md'));
  if (claudeMd) {
    const m = /logic-loom v(\d+\.\d+\.\d+)/.exec(claudeMd);
    if (m) version = m[1];
  }
  // Three or more markers is not a heuristic dressed as a fact: fewer than three
  // is reported as `partial`, which blocks an apply rather than resolving it.
  let state = 'absent';
  if (evidence.length >= 3) state = 'adopted';
  else if (evidence.length > 0) state = 'partial';
  return { state, evidence, harnessVersion: version };
}

// ── MODE: new project, or existing project? ──────────────────────────────────
// `init` serves both cases, which is why `init` is the right verb — it is the
// standard verb precisely because it means "set up here" regardless of what is
// already here (prisma init, tsc --init, eslint --init all work either way).
//
// THE EMPTINESS TEST, STATED EXPLICITLY, because "empty" is a judgement and a
// silent wrong judgement here is the worst outcome this tool can produce:
// scaffolding over a directory that turned out to have work in it.
//
//   IGNORABLE — entries that do not make a directory non-empty. Deliberately a
//   SHORT, CLOSED list: git's own directory, and OS/editor droppings that no
//   human put there on purpose.
//
//   Anything else — one stray README.md, one unrecognised config, one source
//   file — makes this an EXISTING PROJECT. That is the erring-toward-safe
//   direction and it is chosen on purpose: the existing-project path is safe by
//   construction (it proposes; it does not write), so a false "existing" costs
//   the user one extra read of a plan, while a false "new" costs them their
//   files. The asymmetry is not close.
//
//   Note what is NOT on the ignorable list: README.md, LICENSE, .gitignore.
//   Those are plausible "empty new repo" contents on GitHub, and treating them
//   as ignorable is exactly the tempting judgement that gets someone's work
//   overwritten. They count as content, and the reported reason says so.
//
// A directory that cannot be read is neither: mode is `unknown`, which BLOCKS.
// Refuse and say what was seen; never guess.
const IGNORABLE_ENTRIES = ['.git', '.DS_Store', '.localized', 'Thumbs.db', 'desktop.ini', '.Spotlight-V100', '.Trashes'];

function detectMode(root) {
  const entries = listDir(root);
  if (entries === null) {
    return {
      mode: 'unknown',
      reason: 'the target directory could not be read, so emptiness could not be determined',
      content: []
    };
  }
  const content = entries.filter((e) => IGNORABLE_ENTRIES.indexOf(e) === -1);

  if (content.length === 0) {
    const hasGit = entries.indexOf('.git') !== -1;
    return {
      mode: 'new-project',
      reason: hasGit
        ? 'the directory holds nothing but .git — there is no project here yet, so this is a fresh scaffold'
        : 'the directory is empty — there is no project here yet, so this is a fresh scaffold',
      content: []
    };
  }

  return {
    mode: 'existing-project',
    reason: `the directory holds ${content.length} entr${content.length === 1 ? 'y' : 'ies'} ` +
            `(${content.slice(0, 6).join(', ')}${content.length > 6 ? `, +${content.length - 6} more` : ''}) — ` +
            'anything other than .git and OS droppings counts as an existing project, so nothing is ' +
            'scaffolded over: the plan proposes and you decide',
    content: content
  };
}

function detect(root) {
  const abs = path.resolve(root);
  const git = detectGit(abs);
  return {
    root: abs,
    git,
    mode: detectMode(abs),
    statusMap: parsePorcelain(git.porcelain),
    surfaces: detectSurfaces(abs),
    adoption: detectAdoption(abs),
    // The ADOPTER'S execution environment, not their repo — see "execution
    // environment" above. Independent of `root`: this is a fact about the
    // machine running the planner, not about the target directory.
    environment: detectEnvironment()
  };
}

module.exports = {
  detect, detectGit, detectSurfaces, detectAdoption, detectMode,
  parsePorcelain, statusFor, statKind, readTextOrNull, readJsonReport,
  detectEnvironment, probePython3, probeBash, probeGit, probeNode, probeJq,
  resolveOnPath, meetsFloor, readDeclaredNodeFloor,
  UNKNOWN, AGENT_CONFIG_PATHS, IGNORABLE_ENTRIES
};
