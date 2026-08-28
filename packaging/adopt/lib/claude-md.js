'use strict';
// claude-md.js — the INTEGRATION MODE: how the harness's operating instructions
// relate to the adopter's own CLAUDE.md.
//
// WHY THIS IS A CHOICE AT ALL
// -----------------------------------------------------------------------------
// The harness's own instructions have to be loaded for the harness to be worth
// having. The adopter's CLAUDE.md is theirs. Those two facts do not settle each
// other, so the tool asks once — in the plan — and then executes mechanically.
//
// THE OPTION SET, AND WHY IT IS THESE THREE
// -----------------------------------------------------------------------------
//   rules   Install .claude/rules/logicloom-*.md. Their CLAUDE.md is never
//           opened. DEFAULT. Rules files without `paths:` frontmatter are
//           documented to load at launch at the same priority as
//           .claude/CLAUDE.md, so this gets the instructions loaded without
//           touching a file we do not own.
//
//   import  The same files, PLUS one marked block appended to their CLAUDE.md
//           carrying an `@` import of each. This is not redundancy for its own
//           sake: the project-scope `.claude/rules/` load path is confirmed by
//           the vendor documentation and by the CLI's own settings text, but was
//           NOT observed end-to-end when this was written
//           (.docs/design/claude-md-split.md § 0, § 8). If it does not load, the
//           `rules` mode installs 200 lines nothing reads — a silent, total
//           failure. `@import` is the older, unambiguously supported mechanism,
//           and it costs one fenced block. It also makes the extra instructions
//           VISIBLE to a human reading their CLAUDE.md, which some adopters
//           want on its own.
//
//   none    Install nothing loadable. The harness tree still installs; its
//           reference material still reaches them under .docs/. For an adopter
//           who wants to wire the instructions in themselves, or who has decided
//           their context budget is spent.
//
// REJECTED, and stated so the set can be argued with:
//   * inline-append — paste the ~200 lines into their CLAUDE.md inside a fence.
//     Same loading guarantee as `import` at 200× the footprint in a file they
//     own, with drift that is invisible and an uninstall that is surgery.
//     `import` gets the same result with one block.
//   * paths-scoped rules — `paths:` frontmatter so a rule only fires on a file
//     class. Right idea, wrong content: all three files are standing
//     obligations that must be in force before the first tool call.
//   * overwrite / merge their CLAUDE.md — never. The applier does not overwrite
//     a file it did not create, and that refusal is not negotiable per mode.
//
// DETERMINISM IS THE POINT
// -----------------------------------------------------------------------------
// The mode comes from a flag or an environment variable — never from a prompt,
// never from a heuristic, never from a model. `resolve()` is a pure function of
// (requested mode, does a CLAUDE.md exist). The same inputs give the same
// answer every time, and the answer is recorded in the receipt so a re-run and
// an uninstall both know what happened.
//
// Reads nothing. Writes nothing. Pure.

const MODES = ['rules', 'import', 'none'];

const MODE_SUMMARY = {
  rules: 'install .claude/rules/logicloom-*.md; your CLAUDE.md is never opened  [DEFAULT]',
  import: 'the same files, PLUS one marked @import block appended to your CLAUDE.md',
  none: 'install nothing loadable — no rules files, no CLAUDE.md edit'
};

const DEFAULT_MODE = 'rules';
const ENV_VAR = 'LOOM_ADOPT_CLAUDE_MD';
const FLAG = '--claude-md';

// The fence. BEGIN/END are matched literally; uninstall is "delete from BEGIN to
// END", which is a thing a human can do with an editor and no tool.
const BEGIN = '<!-- BEGIN LogicLoom adopt — managed block. Delete from BEGIN to END to uninstall. -->';
const END = '<!-- END LogicLoom adopt — managed block -->';

// Which mode was ASKED for. Flag beats environment beats default; the source is
// returned because a report that says "rules" without saying where it came from
// is not reviewable.
function requestedMode(flagValue, env) {
  if (flagValue !== null && flagValue !== undefined && flagValue !== '') {
    const v = String(flagValue).trim();
    if (MODES.indexOf(v) === -1) {
      return { error: `unknown ${FLAG} mode '${v}'. Valid: ${MODES.join(', ')}.` };
    }
    return { mode: v, source: FLAG + '=' + v };
  }
  const e = env && env[ENV_VAR];
  if (e !== undefined && e !== null && String(e).trim() !== '') {
    const v = String(e).trim();
    if (MODES.indexOf(v) === -1) {
      return { error: `unknown ${ENV_VAR} value '${v}'. Valid: ${MODES.join(', ')}.` };
    }
    return { mode: v, source: ENV_VAR + '=' + v };
  }
  return { mode: DEFAULT_MODE, source: 'default' };
}

// The whole decision, as one pure function.
//
// `asked` is false when there is no CLAUDE.md in the target. That is the
// new-project case and it is not a question: there is nothing to reconcile, and
// this tool never creates a CLAUDE.md, so `import` has nothing to import from.
// A scaffold must not interrogate someone about a file that does not exist.
function resolve(requested, hasClaudeMd) {
  const req = requested && requested.mode ? requested.mode : DEFAULT_MODE;
  const source = (requested && requested.source) || 'default';

  if (!hasClaudeMd) {
    if (req === 'import') {
      return {
        requested: req, resolved: 'rules', source: source, asked: false,
        reason: 'there is no CLAUDE.md in this repository, so there is nothing to import from — ' +
                'and this tool never creates one. `import` collapses to `rules`.',
        collapsed: true
      };
    }
    return {
      requested: req, resolved: req, source: source, asked: false,
      reason: 'there is no CLAUDE.md in this repository, so there is nothing to reconcile. ' +
              'The question is not asked.',
      collapsed: false
    };
  }

  return {
    requested: req, resolved: req, source: source, asked: true,
    reason: 'a CLAUDE.md exists here, so how the harness instructions reach the model is your call. ' +
            'It was made by ' + (source === 'default' ? 'the default' : source) + '.',
    collapsed: false
  };
}

// The block, built from the install paths the manifest's `author:` rows name.
// Sorted so the output is byte-stable across runs regardless of manifest order.
function importBlock(targetPaths) {
  const lines = [];
  lines.push(BEGIN);
  lines.push('<!-- Installed by `logicloom init --claude-md=import`. LogicLoom harness rules. -->');
  const sorted = targetPaths.slice().sort();
  for (const t of sorted) lines.push('@' + t);
  lines.push(END);
  return lines.join('\n');
}

function hasBlock(text) {
  return String(text).indexOf(BEGIN) !== -1;
}

// THE SUFFIX ONLY — the exact bytes to append and nothing else.
//
// This is what the applier writes, through `fs.appendFileSync`, and the shape
// matters: an append cannot truncate. Building the whole new file and writing it
// back would be a truncating write against a file the adopter owns, which is the
// one thing this package refuses to have a code path for, however carefully
// guarded. Returns null when the block is already present — that is what makes a
// second run a no-op rather than a duplicate.
function appendSuffix(text, targetPaths) {
  const src = String(text);
  if (hasBlock(src)) return null;
  const sep = src.length === 0 ? '' : (/\n\n$/.test(src) ? '' : (/\n$/.test(src) ? '\n' : '\n\n'));
  return sep + importBlock(targetPaths) + '\n';
}

// The resulting whole file, for callers that want to reason about it (the
// applier's pure-append check, and tests). Never itself written anywhere.
function appendBlock(text, targetPaths) {
  const suffix = appendSuffix(text, targetPaths);
  return suffix === null ? null : String(text) + suffix;
}

module.exports = {
  MODES, MODE_SUMMARY, DEFAULT_MODE, ENV_VAR, FLAG, BEGIN, END,
  requestedMode, resolve, importBlock, hasBlock, appendSuffix, appendBlock
};
