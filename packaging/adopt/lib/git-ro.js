'use strict';
// git-ro.js — the ONLY place this package invokes git, and it invokes nothing
// that can mutate a repository.
//
// WHY THIS EXISTS AND HOW IT DIVERGES FROM detect-environment-topology.sh
// -----------------------------------------------------------------------------
// The harness's own detector (.logic-loom/scripts/bash/detect-environment-topology.sh)
// states in its header that it "DOES NOT SHELL OUT TO GIT — deliberately", and
// reads refs straight off .git/ on disk. That is the stronger guarantee and it
// is the right one for that script, whose whole question is "which branches
// exist".
//
// THIS TOOL CANNOT ADOPT THAT STANCE, and the divergence is deliberate rather
// than a shortcut. The adopt planner's blocking question is not "which branches
// exist" but "is this exact path dirty or untracked right now". That is a
// working-tree/index question. It is answered by comparing the index, the
// worktree and HEAD — which means reading git's index format, its stat cache,
// every .gitignore in the tree, core.excludesFile, .git/info/exclude, assume-
// unchanged and skip-worktree bits, and every attribute that affects the
// comparison. Reimplementing that is not "reading git's on-disk format"; it is
// reimplementing git, and a wrong answer here is the failure mode this planner
// exists to prevent: telling someone their hand-written work is safe to
// overwrite.
//
// So we shell out, and we bound it instead:
//
//   1. ALLOWLIST BY VERB. Only the verbs in ALLOWED_VERBS run. Everything else
//      throws before a process is spawned. The list is a strict subset of the
//      read-only allowlist in
//      plugins/loom-governance/hooks/scripts/subagent-git-guard.sh, so this tool
//      runs unchanged under a LogicLoom subagent.
//   2. NO SHELL. execFileSync with an argv array — there is no string a caller
//      can craft that becomes a second command.
//   3. NO CODE-EXECUTING GLOBALS. -c / --git-dir / --work-tree / --exec-path /
//      --namespace are rejected in arguments, matching the guard's rule. A
//      `-c core.pager=...` reaching git here would be arbitrary execution.
//   4. -C <root> IS PREPENDED BY US, never by a caller, so the target repo is
//      not a function of process.cwd().
//
// This module writes nothing, and no verb it can run writes anything.

const { execFileSync } = require('node:child_process');

// Strict subset of subagent-git-guard.sh's read-only allowlist. Add a verb here
// only after checking it against that script — this list is the boundary.
const ALLOWED_VERBS = ['status', 'ls-files', 'diff', 'rev-parse', 'branch', 'show'];

// Global flags that make git execute code or retarget the repository.
const FORBIDDEN_ARG = /^(-c$|--exec-path|--git-dir|--work-tree|--namespace|--upload-pack)/;

class GitUnavailable extends Error {}

function run(root, args, opts) {
  const options = opts || {};
  if (!Array.isArray(args) || args.length === 0) {
    throw new Error('git-ro: args must be a non-empty array');
  }
  const verb = args[0];
  if (ALLOWED_VERBS.indexOf(verb) === -1) {
    throw new Error(
      `git-ro: refusing to run non-allowlisted git verb '${verb}'. ` +
        `Allowed: ${ALLOWED_VERBS.join(', ')}.`
    );
  }
  for (const a of args) {
    if (typeof a !== 'string') throw new Error('git-ro: every arg must be a string');
    if (FORBIDDEN_ARG.test(a)) {
      throw new Error(`git-ro: refusing code-executing/retargeting global flag '${a}'`);
    }
  }
  // `diff` is allowlisted only in its name-listing forms. A bare `git diff` is
  // still read-only, but restricting it keeps the surface exactly as narrow as
  // what this planner needs.
  if (verb === 'diff') {
    const ok = args.some((a) => a === '--name-only' || a === '--name-status' || a === '--quiet');
    if (!ok) throw new Error("git-ro: 'diff' is allowed only with --name-only/--name-status/--quiet");
  }

  try {
    const out = execFileSync('git', ['-C', root].concat(args), {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 64 * 1024 * 1024,
      timeout: options.timeoutMs || 30000,
      env: Object.assign({}, process.env, {
        // Never let a pager or an editor block a non-interactive run.
        GIT_PAGER: 'cat',
        GIT_TERMINAL_PROMPT: '0',
        GIT_OPTIONAL_LOCKS: '0'
      })
    });
    return { ok: true, stdout: out, status: 0 };
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      throw new GitUnavailable('git executable not found on PATH');
    }
    return {
      ok: false,
      stdout: (err && err.stdout) || '',
      stderr: (err && err.stderr) || '',
      status: typeof err.status === 'number' ? err.status : -1
    };
  }
}

// Convenience: run and return trimmed stdout, or null when git said no.
function tryLine(root, args) {
  const r = run(root, args);
  if (!r.ok) return null;
  const s = String(r.stdout).trim();
  return s.length ? s : null;
}

function lines(root, args) {
  const r = run(root, args);
  if (!r.ok) return null;
  return String(r.stdout).split('\n').filter((l) => l.length > 0);
}

module.exports = { run, tryLine, lines, ALLOWED_VERBS, GitUnavailable };
