'use strict';
// preconditions.js — what would BLOCK an apply.
//
// The plan itself always runs and is always safe; it writes nothing under any
// condition. What this module produces is the list an APPLIER must be clear of
// before it touches a file — computed and printed by the plan so the human sees
// it before, not during.
//
// NEVER PROPOSE `git stash`, ANYWHERE, FOR ANY OF THESE.
// -----------------------------------------------------------------------------
// A stash is a git mutation, and it is the specific mechanism that loses
// hand-written work: it succeeds silently, prints a cheerful line, and the work
// is then one `git stash drop` — or one forgotten stash entry — from gone. The
// remedy this module emits where a backup is warranted is a `cp -a` command the
// HUMAN runs, so the copy exists outside git's object model and outside this
// tool's reach. There is a test asserting the string 'stash' never appears in a
// remedy.

const fs = require('node:fs');
const path = require('node:path');
const detect = require('./detect');

const BLOCKING = 'blocking';
const WARNING = 'warning';
const UNKNOWN = detect.UNKNOWN;
const UNKNOWN_PLATFORM = detect.UNKNOWN;

// Paths whose uncommitted state is specifically dangerous, because the applier
// MERGES into them rather than creating them. A dirty merge target means the
// human's in-flight edit and our merge land in the same file with no clean
// revert point.
const MERGE_TARGETS = ['.gitignore', '.gitattributes', '.claude/settings.json'];

// The trailing slash matters: git reports untracked directories as `.claude/`,
// and `cp -a src/ dest` copies INTO dest rather than creating it. Strip it, or
// the printed remedy quietly does the wrong thing.
function backupRemedy(root, rel) {
  const clean = String(rel).replace(/\/+$/, '');
  const abs = path.join(root, clean);
  return `cp -a "${abs}" "${abs}.pre-logicloom"  # then re-run the plan`;
}

// ── execution environment ────────────────────────────────────────────────────
// Facts about the machine that would RUN an apply, surfaced from
// lib/detect.js's detectEnvironment() (see there for how each is probed).
//
// WHY EVERY ONE OF THESE IS A WARNING, NEVER BLOCKING
// -----------------------------------------------------------------------------
// `--only` — which targets an apply would actually touch — is parsed at APPLY
// time (bin/logicloom.js's parseOnly), strictly after the plan this function
// produces already exists: a bare `logicloom init <dir>` (no --apply, no
// --only) runs this evaluate() with no idea which targets the adopter even
// wants. python3 only matters for `--only=hooks` (never reached by the `all`
// convenience — see TARGETS.hooks.inAll in lib/apply.js); bash only for
// `gitignore` (which IS in `all`) and `hooks`. Blocking on python3 here would
// refuse an adopter who only ever asked for `--only=harness`, over a tool this
// operation does not use — exactly the "refuses to install anything because
// python3 is missing" failure this module exists to avoid elsewhere.
//
// So: always a warning, always worded with which target(s) it would affect,
// and the corresponding guard AT APPLY TIME — where --only is finally known —
// belongs in lib/apply.js, which this module does not own and does not edit.
function evaluateEnvironment(env) {
  const items = [];
  if (!env) return items;

  const python3 = env.python3 || {};
  const bash = env.bash || {};
  const git = env.git || {};
  const node = env.node || {};
  const jq = env.jq || {};
  const platform = env.platform || UNKNOWN_PLATFORM;

  // Always present, healthy or not — this is the "what was found" record the
  // plan carries, not merely a problem report. Never blocking.
  items.push({
    code: 'ENVIRONMENT',
    severity: WARNING,
    path: '(execution environment)',
    detail: 'python3: ' + shortEnvDetail(python3) + '.  bash: ' + shortEnvDetail(bash) +
            '.  git: ' + shortEnvDetail(git) + '.  node: ' + shortEnvDetail(node) +
            '.  jq: ' + shortEnvDetail(jq) + `.  platform: ${platform}.`,
    remedy: 'informational — see the items below for anything that would affect a specific --only target',
    // Structured, not just prose: the full probe record for each tool, exactly
    // as lib/detect.js reported it (path/version/usable), for a reader (human
    // or agent) that wants the facts rather than the sentence.
    environment: { python3, bash, git, node, jq, platform }
  });

  if (!python3.present || !python3.usable) {
    items.push({
      code: python3.present ? 'PYTHON3-UNUSABLE' : 'PYTHON3-MISSING',
      severity: WARNING,
      path: '(execution environment)',
      detail: '`--only=hooks` merges into .claude/settings.json with a python3 script, and ' +
              (python3.present
                ? `python3 on PATH (${python3.resolvedPath}) is ${python3.detail}`
                : 'no python3 was found on PATH') +
              '. This affects the `hooks` target only — `harness`, `rules` and `gitignore` do not need python3.',
      remedy: python3.present
        ? 'put a real Python 3 earlier on PATH before running `--apply --only=hooks` (or any --only including hooks)'
        : 'install python3 and put it on PATH before running `--apply --only=hooks` (or any --only including hooks)'
    });
  }

  if (!bash.present) {
    items.push({
      code: 'BASH-MISSING',
      severity: WARNING,
      path: '(execution environment)',
      detail: 'no bash was found on PATH. The `.gitignore` merge runs a bash script and `gitignore` ' +
              'is included in the `all` convenience by default; `hooks` and the hooks it installs also need bash.',
      remedy: 'install bash and put it on PATH before running `--apply` with `gitignore` or `hooks` in --only'
    });
  }

  if (node.meetsFloor === false) {
    items.push({
      code: 'NODE-BELOW-DECLARED-FLOOR',
      severity: WARNING,
      path: '(execution environment)',
      detail: `the node running this planner is ${node.version}, below the package's declared floor ` +
              `(${node.declaredFloor}). The declared floor is conservative — this CLI uses only core node ` +
              'builtins and no syntax newer than Node 16 — so this is unlikely to matter in practice, but is ' +
              'named here rather than silently ignored. This is never a blocking condition.',
      remedy: 'optional: upgrade node to the declared floor, or proceed if the planner and apply otherwise work'
    });
  }

  // jq matters to the INSTALLED payload's hooks at SESSION RUNTIME, not to
  // this apply — so it is worded around what happens later, not around --only.
  // Two distinct failure modes, and the wording says which one applies:
  //   1. guard-dangerous-commands.sh has NO jq fallback: every Bash tool call
  //      in every later session becomes an approval prompt. Safe, but reads
  //      as broken.
  //   2. subagent-git-guard.sh / protect-governance-files.sh fall back
  //      jq -> python3. With BOTH absent they fail OPEN (return allow where
  //      they should deny) — the adopter believes they installed a governance
  //      floor and silently gets a thinner one.
  if (!jq.present) {
    const python3Ok = python3.present && python3.usable;
    items.push({
      code: 'JQ-MISSING',
      severity: WARNING,
      path: '(execution environment)',
      detail: 'no jq was found on PATH. This matters to the installed governance hooks at SESSION ' +
              'RUNTIME, after this apply is long done, not to the apply itself. guard-dangerous-commands.sh ' +
              'has no jq fallback: without it, every Bash tool call in every later Claude Code session ' +
              'becomes an approval prompt — safe, but the adopter will think the harness is broken.' +
              (python3Ok
                ? ' subagent-git-guard.sh and protect-governance-files.sh fall back to python3, which ' +
                  'IS usable here, so those two still enforce correctly.'
                : ' subagent-git-guard.sh and protect-governance-files.sh fall back to python3 — which ' +
                  'is ALSO ' + (python3.present ? 'unusable' : 'missing') + ' here — and with both absent ' +
                  'those guards fail OPEN (return allow where they should deny): the adopter would believe ' +
                  'they installed a governance floor and silently get a thinner one.'),
      remedy: python3Ok
        ? 'install jq before relying on the installed hooks, to avoid an approval prompt on every Bash call'
        : 'install jq AND a usable python3 before relying on the installed hooks — right now neither ' +
          'fallback is available and the two guards named above would fail open'
    });
  }

  // No `process.platform` check exists anywhere else in this package. Both
  // merge scripts and every installed hook are POSIX shell, cwd-relative
  // `.sh`; there is no native-Windows code path.
  if (platform === 'win32') {
    items.push({
      code: 'WIN32-POSIX-ONLY',
      severity: WARNING,
      path: '(execution environment)',
      detail: 'this planner is running on win32. This tool and the payload it installs assume a ' +
              'POSIX shell throughout: both merge scripts (.gitignore, .claude/settings.json) need ' +
              'bash and python3, and every installed hook command is a cwd-relative `.sh` script. ' +
              'There is no native-Windows code path anywhere in this package.',
      remedy: 'run this under WSL, Git Bash, or Cygwin — not a native Windows shell (cmd.exe / PowerShell)'
    });
  }

  return items;
}

function shortEnvDetail(rec) {
  if (!rec || rec.present === undefined) return UNKNOWN;
  if (rec.present === false) return 'not found';
  if (rec.usable === false) return 'present but unusable (' + (rec.detail || 'see detail') + ')';
  return (rec.version || 'found') + (rec.resolvedPath ? ' at ' + rec.resolvedPath : '');
}

// `opts.claudeMdMode` — under `import` the applier appends a fenced block to the
// adopter's CLAUDE.md, which makes it a merge target like .gitignore. Adding it
// to the list is what makes a DIRTY or UNTRACKED CLAUDE.md block the apply,
// through the machinery that already exists rather than a second check.
function evaluate(detected, classified, opts) {
  const items = [];
  const root = detected.root;
  const git = detected.git;
  const mode = detected.mode.mode;

  // ── execution environment ──────────────────────────────────────────────────
  // Runs unconditionally, ahead of every mode/git branch below (including the
  // early returns): it is a fact about the machine, not about this target
  // repo, so it belongs in the plan even when the repo itself can't be read.
  for (const it of evaluateEnvironment(detected.environment)) items.push(it);

  // ── nested install: target root is a SUBDIRECTORY of a git work tree ──────
  // Unlike the environment items above, this one IS unconditionally blocking:
  // it is not target-scoped (a nested install is non-functional for every
  // --only alike, since it is the working-directory relationship between the
  // installed hooks and the repo root that breaks, not any one tool), it is
  // cheap to be certain about (one git verb, already run), and the remedy is
  // simply re-running from the repository root — never a workaround that
  // trades away safety. payload-manifest.txt already declares nested installs
  // unsupported for exactly this reason: every installed hook command is
  // cwd-relative, so a hook invoked from the REAL repo root would never find
  // what got written here.
  if (git.isGitRepo && git.toplevel && git.toplevel !== detect.UNKNOWN) {
    let realRoot = root;
    let realTop = git.toplevel;
    try { realRoot = fs.realpathSync(root); } catch (e) { /* keep root as given */ }
    try { realTop = fs.realpathSync(git.toplevel); } catch (e) { /* keep toplevel as given */ }
    if (realRoot !== realTop) {
      items.push({
        code: 'NESTED-GIT-INSTALL',
        severity: BLOCKING,
        path: root,
        detail: `the target (${root}) is a SUBDIRECTORY of a git work tree, not that work tree's own ` +
                `root — the repository root is ${git.toplevel}. Installing here would not be functional: ` +
                'every installed hook command is cwd-relative, so a hook invoked from the real repository ' +
                'root would never find what was written here. payload-manifest.txt already declares ' +
                'nested installs unsupported for exactly this reason.',
        remedy: `re-run \`logicloom init\` from the repository root instead: ${git.toplevel}`,
        nestedInstall: { targetRoot: root, gitToplevel: git.toplevel }
      });
    }
  }

  // ── mode could not be determined ───────────────────────────────────────────
  // Refuse rather than guess. Picking "scaffold" for a directory that turned out
  // to have work in it is the worst outcome available to this tool.
  if (mode === 'unknown') {
    items.push({
      code: 'MODE-UNDETERMINED',
      severity: BLOCKING,
      path: root,
      detail: detected.mode.reason,
      remedy: 'make the directory readable, or point --target somewhere else'
    });
    return finish(items);
  }

  // A NEW PROJECT HAS NOTHING TO LOSE, and the git-baseline items exist purely
  // to protect something that could be lost. In an empty directory there is no
  // uncommitted edit, no untracked file, and no prior state a revert would go
  // back to — so requiring a commit first is ceremony, not safety. They are
  // reported as warnings so the advice still reaches the user.
  const gitBaselineSeverity = mode === 'new-project' ? WARNING : BLOCKING;

  // ── repo-level ─────────────────────────────────────────────────────────────
  if (!git.isGitRepo) {
    items.push({
      code: 'NOT-A-GIT-REPO',
      severity: gitBaselineSeverity,
      path: root,
      detail: mode === 'new-project'
        ? 'this directory is not a git work tree. Nothing is at risk — there is nothing here yet — ' +
          'but the harness expects to live in a repository and several of its hooks read git state.'
        : 'the target is not a git work tree, so nothing the applier writes would be revertable',
      remedy: 'run `git init` yourself' +
        (mode === 'new-project' ? ' before or after the scaffold; both work' :
         ', and make one commit, so there is a baseline to diff against')
    });
    if (mode !== 'new-project') return finish(items);
  }

  if (!git.gitAvailable) {
    items.push({
      code: 'GIT-UNAVAILABLE', severity: BLOCKING, path: root,
      detail: git.reason || 'git could not be invoked',
      remedy: 'install git, or run the planner where git is on PATH'
    });
    return finish(items);
  }

  if (git.hasCommits === false) {
    items.push({
      code: 'NO-COMMITS',
      severity: gitBaselineSeverity,
      path: root,
      detail: mode === 'new-project'
        ? 'the repository has no commits yet. That is expected for a new project and nothing is at ' +
          'risk, since there is no prior state a revert would need to reach.'
        : 'the repository has no commits (unborn HEAD) — there is nothing to revert to',
      remedy: mode === 'new-project'
        ? 'nothing required; commit after the scaffold so the harness lands in its own commit'
        : 'make one commit first: `git add -A && git commit -m "baseline"` (run this yourself)'
    });
  }

  if (git.headState === 'detached') {
    items.push({
      code: 'DETACHED-HEAD',
      severity: BLOCKING,
      path: root,
      detail: 'HEAD is detached — commits made here are not on any branch and are easy to lose',
      remedy: 'check out a branch first (`git switch -c <name>`), run this yourself'
    });
  }

  for (const op of git.inProgress) {
    items.push({
      code: 'IN-PROGRESS-' + op.toUpperCase(),
      severity: BLOCKING,
      path: root,
      detail: `a ${op} is in progress — the index is mid-operation and a write now compounds the conflict`,
      remedy: `finish or abort the ${op} yourself, then re-run the plan`
    });
  }

  // ── per-path: any path the applier would touch, dirty or untracked ─────────
  const targets = [];
  for (const c of classified) {
    if (c.bucket !== 'additive' && c.bucket !== 'replace') continue;
    if (targets.indexOf(c.targetPath) === -1) targets.push(c.targetPath);
  }
  for (const t of MERGE_TARGETS) if (targets.indexOf(t) === -1) targets.push(t);
  if (opts && opts.claudeMdMode === 'import' && targets.indexOf('CLAUDE.md') === -1) targets.push('CLAUDE.md');

  // GROUPED BY THE STATUS ENTRY, NOT BY THE TARGET, and the reason is the
  // `cp -a` remedy. git collapses untracked directories, so one `?? .claude/`
  // is reported against every payload target beneath it — eight blocking items
  // for one cause, each telling the human to copy `.claude/hooks`, a path that
  // DOES NOT EXIST. A remedy naming a nonexistent path is worse than no remedy:
  // it fails, and the human concludes the tool is broken rather than that their
  // work is at risk. So: one item per real dirty/untracked path, naming the
  // targets it blocks.
  const byEntry = new Map();
  for (const t of targets) {
    for (const hit of detect.statusFor(detected.statusMap, t)) {
      if (hit.ignored) continue;
      let g = byEntry.get(hit.path);
      if (!g) { g = { rec: hit, targets: [] }; byEntry.set(hit.path, g); }
      if (g.targets.indexOf(t) === -1) g.targets.push(t);
    }
  }

  for (const [entryPath, g] of byEntry) {
    const affects = g.targets.slice(0, 8).join(', ') +
      (g.targets.length > 8 ? `, +${g.targets.length - 8} more` : '');
    const onlyMergeTargets = g.targets.every((t) => MERGE_TARGETS.indexOf(t) !== -1 || t === 'CLAUDE.md');

    if (g.rec.untracked) {
      items.push({
        code: 'UNTRACKED-UNDER-TARGET',
        severity: BLOCKING,
        path: entryPath,
        affects: g.targets,
        detail: `\`${entryPath}\` is UNTRACKED and the apply would write inside it ` +
                `(blocks: ${affects}). Untracked work has no copy in git at all.`,
        remedy: 'commit it, or copy it out yourself first: ' + backupRemedy(root, entryPath)
      });
    } else if (g.rec.dirty) {
      items.push({
        code: onlyMergeTargets ? 'DIRTY-MERGE-TARGET' : 'DIRTY-TARGET-PATH',
        severity: BLOCKING,
        path: entryPath,
        affects: g.targets,
        detail: `\`${entryPath}\` is modified-but-uncommitted and the apply would ` +
                (onlyMergeTargets ? 'MERGE INTO it' : 'write inside it') +
                ` (blocks: ${affects}). Your edit and ours would land in the same file ` +
                'with no clean revert point between them.',
        remedy: 'commit it, or take a copy before proceeding: ' + backupRemedy(root, entryPath)
      });
    }
  }

  // ── repo-wide untracked volume: a warning, not a block ─────────────────────
  let untrackedTotal = 0;
  let dirtyTotal = 0;
  for (const [, rec] of detected.statusMap) {
    if (rec.untracked) untrackedTotal++;
    else if (rec.dirty) dirtyTotal++;
  }
  if (untrackedTotal > 0) {
    items.push({
      code: 'UNTRACKED-WORK-PRESENT',
      severity: WARNING,
      path: root,
      detail: `${untrackedTotal} untracked path(s) elsewhere in the repo. The applier does not touch them, ` +
              'but they have no copy in git, so a mistaken `git clean` anywhere would take them.',
      remedy: 'nothing required for the apply — noted so it is your decision, not a surprise'
    });
  }
  if (dirtyTotal > 0) {
    items.push({
      code: 'UNCOMMITTED-WORK-PRESENT',
      severity: WARNING,
      path: root,
      detail: `${dirtyTotal} modified-but-uncommitted path(s) elsewhere in the repo — a clean tree ` +
              'would make the adopt diff readable on its own.',
      remedy: 'optional: commit first so `git diff` after the apply shows only what adopt wrote'
    });
  }

  // ── adoption state ─────────────────────────────────────────────────────────
  if (detected.adoption.state === 'adopted') {
    items.push({
      code: 'ALREADY-ADOPTED',
      severity: BLOCKING,
      path: root,
      detail: 'this repository already has LogicLoom installed (' +
              detected.adoption.evidence.map((e) => e.path).join(', ') +
              (detected.adoption.harnessVersion !== detect.UNKNOWN
                ? `; CLAUDE.md declares v${detected.adoption.harnessVersion}` : '') +
              '). Adopting again is not the operation you want.',
      remedy: 'use `/update-framework` to move an installed harness forward; adopt installs it once'
    });
  } else if (detected.adoption.state === 'partial') {
    items.push({
      code: 'PARTIAL-ADOPTION',
      severity: BLOCKING,
      path: root,
      detail: 'some harness markers are present but not enough to call this adopted (' +
              detected.adoption.evidence.map((e) => e.path).join(', ') +
              '). That is either a half-finished install or a name collision, and the tool ' +
              'cannot tell which.',
      remedy: 'inspect those paths yourself and decide; the planner will not guess'
    });
  }

  return finish(items);
}

function finish(items) {
  return {
    blocking: items.filter((i) => i.severity === BLOCKING),
    warnings: items.filter((i) => i.severity === WARNING),
    all: items
  };
}

module.exports = { evaluate, evaluateEnvironment, MERGE_TARGETS, BLOCKING, WARNING };
