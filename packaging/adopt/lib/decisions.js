'use strict';
// decisions.js — the choices a HUMAN has to make, as data.
//
// WHY THIS EXISTS
// -----------------------------------------------------------------------------
// The plan already contains everything: `claudeMd` carries the integration
// mode, `buckets` carries the worklist, `preconditions` carries what blocks.
// A person reading the rendered report gets the decisions for free, because the
// report is written to present them.
//
// An AGENT does not. Handed 39 KB of structure, it has to reverse-engineer
// "what must my user actually decide?" from four unrelated fields, and every
// agent reverse-engineers it slightly differently. That is a contract gap, not
// a documentation gap: the answer is knowable, it is just not stated.
//
// So it is stated. One list. Each entry is one question, in plain language,
// with the options, what each one means, the default and why it is the default,
// and THE EXACT FLAG THAT SETS IT. An agent walks the list, asks its user in its
// own words, and assembles the apply command without inferring anything.
//
// TWO PROPERTIES THIS FILE COMMITS TO
// -----------------------------------------------------------------------------
//   1. DERIVED, never hardcoded. The `--only` options come from
//      lib/apply.js's TARGETS; the `--claude-md` options come from
//      lib/claude-md.js's MODES. Adding a target or a mode adds a decision
//      option automatically. A hand-maintained list here would be a second
//      source of truth that drifts silently, which is the same defect this
//      change was opened to fix.
//   2. NO NEW POLICY. Nothing here decides anything. Every `default` is the
//      behaviour the tool already has when the flag is omitted, and every
//      `applicable: false` is a case the tool already collapses. This module
//      reports; it does not choose.
//
// Pure. Reads nothing, writes nothing, spawns nothing.

const claudeMdLib = require('./claude-md');

// Loaded lazily — apply.js requires plan.js indirectly, and a static require
// here would close a cycle at module-load time.
function targetsLib() { return require('./apply'); }

// Per-target consequences. The TARGET LIST is derived; these sentences are the
// part a summary line cannot carry, and they are the reason `--only` is a real
// decision rather than a formality. Keyed by target name, and a target with no
// entry here simply carries none — a missing sentence must never be a missing
// option.
const TARGET_CONSEQUENCE = {
  harness: 'Files only, all of them new. Nothing you already have is touched: any path ' +
    'that collides is classified keep-theirs and dropped. Without this the other ' +
    'targets reference scripts that are not there.',
  gitignore: 'Appends one fenced block of harness-written paths to your .gitignore. ' +
    'Everything above the fence stays byte-identical. Nothing you track is untracked ' +
    'by it — the block is curated, and merge/gitignore-decisions.txt records every ' +
    'pattern of ours that was deliberately NOT shipped, with the reason.',
  rules: 'Writes .claude/rules/logicloom-*.md — the harness operating instructions. ' +
    'Whether anything is appended to YOUR CLAUDE.md is the separate `claude-md` ' +
    'decision below, and only its `import` mode touches that file.',
  hooks: 'CHANGES WHAT YOUR OWN CLAUDE CODE SESSIONS MAY DO in this repository, from ' +
    'the next prompt onward: git mutations start prompting for approval, subagents ' +
    'are denied mutating git, and the governance surface becomes write-protected. ' +
    'This is the point of the harness, and it is also why it is excluded from ' +
    '`--only=all` and has to be typed by name.'
};

// ── decision 1: which targets to install ─────────────────────────────────────
function targetsDecision(plan) {
  const A = targetsLib();
  const additive = plan.buckets.additive;
  const kept = plan.buckets['keep-theirs'];

  const options = A.ALL_TARGETS.map((name) => {
    const gran = A.TARGETS[name].granularity;
    const mine = additive.filter((u) => u.granularity === gran);
    const theirs = kept.filter((u) => u.granularity === gran);
    return {
      value: name,
      summary: A.TARGETS[name].summary,
      consequence: TARGET_CONSEQUENCE[name] || null,
      inDefault: !!A.TARGETS[name].inAll,
      wouldWrite: mine.length,
      wouldKeepYours: theirs.length,
      // An agent should not ask a question whose only honest answer is "there is
      // nothing to do". Stated rather than left to be computed from the buckets.
      noOp: mine.length === 0
    };
  });

  return {
    id: 'targets',
    question: 'Which parts of LogicLoom should be installed here?',
    kind: 'multi-select',
    required: true,
    applicable: true,
    flag: '--only',
    flagForm: '--only=<comma-separated values, or "all">',
    env: null,
    default: {
      value: 'all',
      expandsTo: A.IN_ALL.slice(),
      why: '`all` is the three targets that write only new files or an append-only fenced ' +
           'block. `hooks` is NOT in it and never will be: it changes what your sessions ' +
           'are permitted to do, and nothing installs a governance floor as a side effect ' +
           'of the word "all".'
    },
    options: options,
    // There is no "apply everything by omission" — say so where the agent reads.
    notes: [
      '`--only` is MANDATORY with `--apply`. Omitting it is a usage error (exit 2), not ' +
      'a default.',
      'Order does not matter and repeats are harmless. `all` may be combined: ' +
      '`--only=all,hooks` is the full install.',
      'Naming a target with nothing to do is not an error — it reports a no-op.'
    ]
  };
}

// ── decision 2: how the harness instructions reach the model ─────────────────
function claudeMdDecision(plan) {
  const c = plan.claudeMd;
  const applicable = !!c.asked;

  return {
    id: 'claude-md',
    question: 'How should the harness\'s operating instructions reach the model in this repository?',
    kind: 'single-select',
    required: false,
    // `asked: false` means there is no CLAUDE.md here, so there is nothing to
    // reconcile and the question is NOT a question. An agent that asks it anyway
    // is interrogating its user about a file that does not exist.
    applicable: applicable,
    notApplicableReason: applicable ? null : c.reason,
    flag: c.flag,
    flagForm: c.flag + '=<mode>',
    env: c.env,
    default: {
      value: claudeMdLib.DEFAULT_MODE,
      why: 'It installs the instructions as .claude/rules/logicloom-*.md and never opens ' +
           'your CLAUDE.md. Choose `import` if you want the harness rules visible in your ' +
           'own CLAUDE.md, or if `/context` shows the rules files are not loading.'
    },
    options: c.options.map((o) => ({
      value: o.mode,
      summary: o.summary,
      consequence: MODE_CONSEQUENCE[o.mode] || null,
      inDefault: o.mode === claudeMdLib.DEFAULT_MODE,
      // Only `import` writes into a file the adopter owns, and even then only
      // as a fenced append. Flagged because it is the one thing an agent should
      // say out loud before choosing it on someone's behalf.
      touchesYourFiles: o.mode === 'import' ? ['CLAUDE.md'] : []
    })),
    // What the tool ALREADY resolved, given the flags/env in force for this
    // plan. An agent that is only confirming a default reads this and stops.
    resolved: { value: c.resolved, source: c.source, collapsed: !!c.collapsed, reason: c.reason },
    notes: [
      'Requires `--only=rules` (or `all`) to have any effect — the mode says HOW the ' +
      'rules install, not WHETHER.',
      'No mode ever overwrites your CLAUDE.md. `import` appends one marked block and ' +
      'nothing else; re-running is a no-op.',
      'With no CLAUDE.md in the repository, `import` collapses to `rules` and the ' +
      'collapse is recorded, not silent — this tool never creates a CLAUDE.md.'
    ]
  };
}

const MODE_CONSEQUENCE = {
  rules: 'Three new files under .claude/rules/. Your CLAUDE.md is never opened, read, or ' +
    'written. Verify they load with `/context` -> Memory files.',
  import: 'The same three files, PLUS one fenced block appended to the END of your ' +
    'CLAUDE.md carrying an @import of each. Append-only and verified to be a pure ' +
    'append before it lands. Uninstall is deleting from the BEGIN marker to the END ' +
    'marker. Under this mode a dirty or untracked CLAUDE.md BLOCKS the apply.',
  none: 'Nothing loadable is installed. The harness tree still installs and its reference ' +
    'material still lands under .docs/, but no agent in this repository is told the ' +
    'harness rules exist. Choose this only if you intend to wire them in yourself.'
};

// ── the list ─────────────────────────────────────────────────────────────────
// Ordered by when the answer is needed: you pick the targets, then how one of
// them installs.
function build(plan) {
  return [targetsDecision(plan), claudeMdDecision(plan)];
}

module.exports = { build, TARGET_CONSEQUENCE, MODE_CONSEQUENCE };
