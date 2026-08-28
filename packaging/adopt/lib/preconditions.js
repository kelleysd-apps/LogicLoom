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

const path = require('node:path');
const detect = require('./detect');

const BLOCKING = 'blocking';
const WARNING = 'warning';

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

// `opts.claudeMdMode` — under `import` the applier appends a fenced block to the
// adopter's CLAUDE.md, which makes it a merge target like .gitignore. Adding it
// to the list is what makes a DIRTY or UNTRACKED CLAUDE.md block the apply,
// through the machinery that already exists rather than a second check.
function evaluate(detected, classified, opts) {
  const items = [];
  const root = detected.root;
  const git = detected.git;
  const mode = detected.mode.mode;

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

module.exports = { evaluate, MERGE_TARGETS, BLOCKING, WARNING };
