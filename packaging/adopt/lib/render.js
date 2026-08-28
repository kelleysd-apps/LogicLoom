'use strict';
// render.js — the human-readable plan report.
//
// Shaped after .logic-loom/scripts/bash/detect-environment-topology.sh's report
// format on purpose: same "here is what I found, here is what I could not
// determine, nothing was written" posture, same habit of printing the evidence
// beside the verdict. This CLI is a sibling of /scaffold-environments, not a new
// shape.
//
// Prints. Writes no file.

const UNKNOWN = 'unknown';

function line(s) { return s === undefined ? '' : String(s); }

// `opts.isTTY` — whether stdout is a terminal. See agentHeader() below for why
// this changes the header and nothing else, and why the default is `false`:
// an omitted flag should fail toward MORE agent guidance, never less.
function render(plan, opts) {
  const o = opts || {};
  const isTTY = o.isTTY === true;
  return plan.mode.mode === 'new-project'
    ? renderNewProject(plan, isTTY)
    : renderExisting(plan, isTTY);
}

// ── NEW PROJECT ──────────────────────────────────────────────────────────────
// A first-class mode, not an edge case of the other one. The CLASSIFIER is not
// special-cased — with nothing in the directory, every unit falls out of R2 as
// `additive` on its own. What differs is the REPORT: showing someone with an
// empty directory a four-bucket table with three empty buckets, and a
// precondition list about dirty files that cannot exist, is noise that hides the
// one thing they want, which is the list of what will be created.
function renderNewProject(plan, isTTY) {
  const L = [];
  const p = (s) => L.push(line(s));

  p('LogicLoom init — NEW PROJECT (read-only: nothing was written)');
  agentHeader(p, plan, isTTY);
  p('='.repeat(78));
  p('');
  p(`  MODE                  : NEW PROJECT — fresh scaffold`);
  wrap('why: ' + plan.mode.reason, 4).forEach(p);
  p('');
  p(`  target directory      : ${plan.target.root}`);
  p(`  payload source        : ${plan.payload.source}`);
  p(`  git                   : ${plan.target.isGitRepo ? plan.target.gitDetect + ', ' + (plan.target.hasCommits ? 'has commits' : 'no commits yet') : 'not a git repository'}`);
  p(`  generator             : ${plan.generator.package}@${plan.generator.version} on node ${plan.generator.nodeVersion}`);
  p('');

  const created = plan.buckets.additive;
  p(`  WOULD CREATE (${created.length})`);
  const paths = created.filter((u) => u.granularity === 'path');
  const keys = created.filter((u) => u.granularity === 'json-key');
  const lines = created.filter((u) => u.granularity === 'line');
  for (const u of paths) {
    p(`    ${u.targetPath}${u.renamedFrom ? `   (from ${u.renamedFrom})` : ''}`);
  }
  if (keys.length) p(`    .claude/settings.json    — ${keys.length} governance hook entries`);
  if (lines.length) p(`    .gitignore               — ${lines.length} harness ignore patterns`);
  p('');
  wouldWriteSection(p, plan);
  bookkeepingSection(p, plan);

  claudeMdSection(p, plan);

  if (plan.counts['keep-theirs'] || plan.counts.replace || plan.counts.obsolete) {
    // Should be impossible in this mode; if it happens, say so rather than hide it.
    p('  UNEXPECTED for a new project — these buckets should be empty here:');
    p(`    keep-theirs ${plan.counts['keep-theirs']}   replace ${plan.counts.replace}   obsolete ${plan.counts.obsolete}`);
    p('');
  }

  preconditionSection(p, plan);
  p('');

  if (plan.preconditions.warnings.length) {
    p('  Worth knowing');
    for (const w of plan.preconditions.warnings) {
      p(`    [${w.code}]`);
      wrap(w.detail, 6).forEach(p);
      wrap('→ ' + w.remedy, 6).forEach(p);
    }
    p('');
  }

  if (plan.defers.length) {
    p(`  DEFERRED in the payload manifest (${plan.defers.length}) — not shipped, undecided upstream`);
    for (const d of plan.defers) p(`    - ${d.path}: ${d.question}`);
    p('');
  }

  if (plan.errors.length) {
    p('  ERRORS');
    for (const e of plan.errors) wrap('- ' + e, 4).forEach(p);
    p('');
  }

  p('  Named limits');
  for (const n of plan.notes) wrap('- ' + n, 4).forEach(p);
  p('');
  p('  APPLY READY           : ' + (plan.applyReady ? 'yes' : 'NO — see BLOCKING above'));
  p('  Nothing was written. This command has no write path.');
  return L.join('\n');
}

// ── EXISTING PROJECT ─────────────────────────────────────────────────────────
function renderExisting(plan, isTTY) {
  const L = [];
  const p = (s) => L.push(line(s));

  p('LogicLoom init — PLAN (read-only: nothing was written to this repository)');
  agentHeader(p, plan, isTTY);
  p('='.repeat(78));
  p('');
  p('  MODE                  : EXISTING PROJECT — propose, do not scaffold');
  wrap('why: ' + plan.mode.reason, 4).forEach(p);
  p('');
  p(`  target repository     : ${plan.target.root}`);
  p(`  payload source        : ${plan.payload.source}`);
  p(`                          ${plan.payload.root}`);
  p(`  payload manifest      : ${plan.payload.manifest} (${plan.payload.manifestEntries} entries)`);
  p(`  generator             : ${plan.generator.package}@${plan.generator.version} on node ${plan.generator.nodeVersion}`);
  p('');

  // ── already adopted ────────────────────────────────────────────────────────
  if (plan.target.adoption.state !== 'absent') {
    p(`  ADOPTION STATE        : ${plan.target.adoption.state.toUpperCase()}`);
    for (const e of plan.target.adoption.evidence) p(`      - ${e.path}   (${e.why})`);
    if (plan.target.adoption.harnessVersion !== UNKNOWN) {
      p(`      CLAUDE.md declares logic-loom v${plan.target.adoption.harnessVersion}`);
    }
    p('');
  }

  // ── git facts ──────────────────────────────────────────────────────────────
  p('  Repository state');
  p(`    git work tree       : ${plan.target.isGitRepo ? plan.target.gitDetect : 'NOT A GIT REPO'}`);
  p(`    commits present     : ${plan.target.hasCommits}`);
  p(`    HEAD                : ${plan.target.headState}  (branch: ${plan.target.currentBranch})`);
  p(`    default branch      : ${plan.target.defaultBranch}  (source: ${plan.target.defaultBranchSource})`);
  p(`    branches (${plan.target.branches.length})`.padEnd(25) + `: ${plan.target.branches.slice(0, 12).join(', ') || '(none)'}` +
    (plan.target.branches.length > 12 ? `, +${plan.target.branches.length - 12} more` : ''));
  p(`    in-progress ops     : ${plan.target.inProgress.length ? plan.target.inProgress.join(', ') : 'none'}`);
  p(`    tracked files       : ${plan.target.trackedFiles}`);
  p('');

  // ── what they already have ─────────────────────────────────────────────────
  p('  What this repository already has');
  const ac = plan.detect.agentConfig.filter((a) => a.kind !== 'absent');
  if (ac.length) {
    for (const a of ac) {
      const extra = a.lines !== undefined ? ` (${a.lines} lines)` : a.entries !== undefined ? ` (${a.entries} entries)` : '';
      p(`    agent config        : ${a.path}  [${a.kind}]${extra}`);
    }
  } else {
    p('    agent config        : none of CLAUDE.md / AGENTS.md / .cursorrules / copilot-instructions');
  }
  p(`    .claude/            : ${plan.detect.claude.kind}`);
  const sub = Object.keys(plan.detect.claude.subdirs || {});
  if (sub.length) for (const d of sub) p(`      .claude/${d}`.padEnd(25) + `: ${plan.detect.claude.subdirs[d].entries} entries`);
  p(`    .claude/settings.json: ${plan.detect.claude.settings.kind}` +
    (plan.detect.claude.settings.kind !== 'absent'
      ? `  parse=${plan.detect.claude.settings.parse} indent=${plan.detect.claude.settings.indent} hooks=[${(plan.detect.claude.settings.hookEvents || []).join(', ')}]`
      : ''));
  p(`    memory dirs         : ${plan.detect.memoryDirs.length ? plan.detect.memoryDirs.map((m) => m.path).join(', ') : 'none detected'}`);
  p(`    task/backlog files  : ${plan.detect.taskFiles.length ? plan.detect.taskFiles.map((t) => t.path).join(', ') : 'none detected'}`);
  p(`    CI                  : ${plan.detect.ci.provider}${plan.detect.ci.evidence ? '  (' + plan.detect.ci.evidence + ')' : ''}` +
    (plan.detect.ci.workflows.length ? `  ${plan.detect.ci.workflows.length} workflow file(s)` : ''));
  p(`    test setup          : ${(plan.detect.tests.dirs.concat(plan.detect.tests.configs)).join(', ') || 'none detected'}`);
  p(`    .gitignore          : ${plan.detect.gitignore.kind}` +
    (plan.detect.gitignore.kind === 'file' ? ` (${plan.detect.gitignore.lineCount} lines)` : ''));
  p(`    .gitattributes      : ${plan.detect.gitattributes.kind}`);
  p(`    root manifest       : ${plan.detect.rootManifest.present ? plan.detect.rootManifest.files.join(', ') + `  [${plan.detect.rootManifest.ecosystem}]` : 'none'}`);
  p(`    product at root?    : ${plan.detect.productSourceAtRoot.answer.toUpperCase()} — ${plan.detect.productSourceAtRoot.reason}`);
  p('');

  // ── preconditions ──────────────────────────────────────────────────────────
  p('  Preconditions for an APPLY (the plan itself is always safe and ran anyway)');
  preconditionSection(p, plan);
  p('');
  if (plan.preconditions.warnings.length) {
    p(`    warnings            : ${plan.preconditions.warnings.length}`);
    for (const w of plan.preconditions.warnings) {
      p(`      [${w.code}]`);
      wrap(w.detail, 8).forEach(p);
    }
    p('');
  }
  p('    NOTE: no remedy above is `git stash`, and none ever will be. A stash is a');
  p('    git mutation that succeeds silently and puts the work one `git stash drop`');
  p('    from gone. Where a backup is warranted the remedy is a `cp -a` you run.');
  p('');

  claudeMdSection(p, plan);

  // ── the four buckets ───────────────────────────────────────────────────────
  p('  Classification (4 buckets) — PLAN ENTRIES, not files');
  p(`    additive     ${String(plan.counts.additive).padStart(4)}   LogicLoom unit has no counterpart here`);
  p(`    keep-theirs  ${String(plan.counts['keep-theirs']).padStart(4)}   both exist — YOURS WINS, ours is dropped (each printed below)`);
  p(`    replace      ${String(plan.counts.replace).padStart(4)}   ours overwrites yours (explicitly named only; empty by design)`);
  p(`    obsolete     ${String(plan.counts.obsolete).padStart(4)}   YOUR rule references something absent (report only, never actioned)`);
  p('');
  wouldWriteSection(p, plan);
  bookkeepingSection(p, plan);

  bucketSection(p, 'ADDITIVE — would be installed', plan.buckets.additive);
  bucketSection(p, 'KEEP-THEIRS — ours dropped, with the reason', plan.buckets['keep-theirs']);
  bucketSection(p, 'REPLACE — ours overwrites yours', plan.buckets.replace, 'none (empty by design)');

  p(`    OBSOLETE — findings about YOUR repo (${plan.buckets.obsolete.length}) — report only, nothing is actioned`);
  if (!plan.buckets.obsolete.length) p('      none');
  for (const o of plan.buckets.obsolete) p(`      - ${o.source}: ${o.detail}`);
  p('');

  // ── deferred rows ──────────────────────────────────────────────────────────
  // Printed as its own section rather than left to the blocking list, because a
  // `defer:` is the reason a collision you can SEE in your repo may be absent
  // from the buckets above. Without this, a reader with a 500-line CLAUDE.md
  // reads "keep-theirs 0" and concludes the tool did not look.
  if (plan.defers.length) {
    p(`    DEFERRED in the payload manifest (${plan.defers.length}) — NOT classified, because`);
    p('    the maintainer has not decided how they install. Any collision you have at');
    p('    these paths is therefore absent from the buckets above, not resolved.');
    for (const d of plan.defers) {
      p(`      - ${d.path}  (payload-manifest.txt:${d.manifestLine})`);
      wrap(d.question, 10).forEach(p);
    }
    p('');
  }

  // ── errors / defers / notes ────────────────────────────────────────────────
  if (plan.errors.length) {
    p('  ERRORS');
    for (const e of plan.errors) wrap('- ' + e, 4).forEach(p);
    p('');
  }
  if (plan.notes.length) {
    p('  Named limits');
    for (const n of plan.notes) wrap('- ' + n, 4).forEach(p);
    p('');
  }

  p('  APPLY READY           : ' + (plan.applyReady ? 'yes' : 'NO — see BLOCKING above'));
  p('  Nothing was written. This command has no write path.');
  return L.join('\n');
}

// ── the integration choice, presented ONCE, here ─────────────────────────────
// This is where the question is asked and the only place it is asked. There is
// no prompt anywhere in this tool: the plan lays out the options, a flag or an
// environment variable answers, and the applier executes exactly that.
//
// WHEN THERE IS NO CLAUDE.md THE MENU IS NOT PRINTED. One line saying so, and
// on. A scaffold must not interrogate someone about a file that does not exist.
function claudeMdSection(p, plan) {
  const c = plan.claudeMd;
  if (!c) return;

  if (!c.asked) {
    p('  CLAUDE.md INTEGRATION : not asked — ' + c.resolved);
    wrap(c.reason, 4).forEach(p);
    if (c.collapsed) {
      wrap('You passed --claude-md=' + c.requested + '; it was collapsed, not ignored, ' +
           'and the receipt records both.', 4).forEach(p);
    }
    p('');
    return;
  }

  p('  CLAUDE.md INTEGRATION — YOUR CHOICE, made here, executed mechanically');
  p('');
  wrap('You have a CLAUDE.md. The harness has operating instructions of its own ' +
       '(' + c.ruleFiles.length + ' files). How they reach the model is your call:', 4).forEach(p);
  p('');
  for (const o of c.options) {
    const mark = o.mode === c.resolved ? '  ->' : '    ';
    p(`  ${mark} ${o.mode.padEnd(7)} ${o.summary}`);
  }
  p('');
  p(`      selected : ${c.resolved}   (from ${c.source})`);
  wrap('Change it with `' + c.flag + '=<mode>` or `' + c.env + '=<mode>`. ' +
       'No mode ever overwrites your CLAUDE.md; `import` appends one marked block ' +
       'and nothing else, and re-running is a no-op.', 6).forEach(p);
  p('');
  if (c.resolved === 'rules') {
    wrap('Under `rules` your CLAUDE.md is never opened, read, or written. Verify the ' +
         'files actually load with `/context` -> Memory files; if they do not appear, ' +
         're-run with ' + c.flag + '=import.', 6).forEach(p);
    p('');
  }
}

// ── THE AGENT POINTER — line 2, not line 249 ─────────────────────────────────
// This used to be a two-line footer. On a real existing repository the report
// is ~250 lines, which put the pointer at line 249: an agent that shells out,
// reads from byte zero and starts acting never reached it, and instead parsed
// prose formatted for a human. That is precisely how an agent misreads a plan.
//
// So it leads. Line 1 stays the title — a captured stream has to say what it is
// before it says anything else — and the pointer is lines 2..n, above the `===`
// rule and above every plan section. A human skims two lines; an agent reading
// from the top cannot miss them.
//
// TTY DETECTION — an ENHANCEMENT, never the mechanism.
// -----------------------------------------------------------------------------
// `!process.stdout.isTTY` is a reliable signal of "this output was captured by a
// program". It is NOT a reliable signal of the converse: several agent harnesses
// allocate a pty, so a TTY does not mean a human is reading. Any design that put
// the guidance ONLY in the non-TTY branch would therefore miss exactly the
// harnesses that are hardest to detect.
//
// Hence: the pointer is unconditional and identically placed in both branches.
// The non-TTY branch only makes it FULLER — the piped case has no human whose
// terminal we are spending, so the extra lines cost nothing there and buy the
// one thing an agent would otherwise reverse-engineer out of 39 KB of JSON:
// what its user actually has to decide, and whether an apply is even permitted.
// The TTY branch is deliberately two lines so the human report is not degraded
// to achieve any of that.
function agentHeader(p, plan, isTTY) {
  if (!plan.agentGuide) return;
  const guideCmd = plan.agentGuide.command;
  // Derived from the plan's own applyCommand rather than re-spelling the package
  // name here — one source for the invocation, same rule decisions.js follows.
  const base = String(plan.agentGuide.applyCommand || '').split(' --apply')[0];
  const jsonCmd = base ? base + ' --json' : guideCmd.replace('--agent-guide', '--json');

  if (isTTY) {
    p('  AGENT? Do not parse this report. `' + guideCmd + '` prints');
    p('  the install procedure; `--json` gives this plan as data, with `decisions[]`.');
    return;
  }

  p('  AGENT / CAPTURED OUTPUT — stdout is not a terminal, so a program is probably');
  p('  reading this. Do NOT parse the human prose below. Use these instead:');
  p('    the procedure     : ' + guideCmd);
  p('    this plan as data : ' + jsonCmd + '   <- re-run with this');
  p('    then apply        : ' + plan.agentGuide.applyCommand);
  decisionsInline(p, plan);
  const blocking = (plan.preconditions && plan.preconditions.blocking) || [];
  if (plan.applyReady) {
    p('    applyReady: yes — ask your user the decisions above. Do not answer them.');
  } else {
    p('    applyReady: NO — ' + blocking.length + ' blocking precondition' +
      (blocking.length === 1 ? '' : 's') + '. Relay each remedy; do not apply.');
  }
}

// The decisions, one line each, in the header. Not a second source of truth:
// read straight off plan.decisions, which decisions.js derives from the target
// and mode registries. A decision added there appears here with no edit.
function decisionsInline(p, plan) {
  const d = plan.decisions || [];
  if (!d.length) return;
  const asks = d.filter((x) => x.applicable !== false);
  p('    decisions to put to your user (' + asks.length + ' of ' + d.length +
    ') — REQUIRED = no omission default:');
  for (const x of d) {
    if (x.applicable === false) {
      p('      - ' + x.id.padEnd(10) + ' NOT APPLICABLE here — do not ask it');
      continue;
    }
    p('      - ' + x.id.padEnd(10) + (x.flag || '') +
      (x.required ? ' [REQUIRED]' : '') +
      (x.default && x.default.value !== undefined ? ' default=' + x.default.value : ''));
  }
}

function bucketSection(p, title, units, emptyText) {
  p(`    ${title} (${units.length})`);
  if (!units.length) { p('      ' + (emptyText || 'none')); p(''); return; }
  for (const u of units) {
    const where = u.targetPath + (u.renamedFrom ? `   (renamed from ${u.renamedFrom})` : '');
    p(`      - [${u.granularity}] ${where}`);
    if (u.granularity === 'json-key') p(`          key: ${u.selector.event} / matcher '${u.selector.matcher}' / ${u.selector.command}`);
    if (u.granularity === 'line') p(`          line: ${u.value}`);
    if (u.sourceRoot === 'package') p(`          authored by the adopt package (${u.sourcePath}), not carved from LogicLoom's own CLAUDE.md`);
    wrap(u.reason, 10).forEach(p);
  }
  p('');
}

// ── preconditions, with our own footprint told apart from theirs ─────────────
// `preconditions.blocking` is the whole truth about the tree and stays whole.
// What splits here is who CAUSED each item: an entry this tool's own receipt
// accounts for is discounted by the applier, and printing it in the same list
// as a real obstacle is how a successful install came to read as a failed one.
// A discount that was CONSIDERED AND REFUSED (you edited a file we merged into)
// stays in the standing list, with the refusal spelled out.
function preconditionSection(p, plan) {
  const all = plan.preconditions.blocking || [];
  const discounted = all.filter((b) => b.selfCaused === true);
  const standing = all.filter((b) => b.selfCaused !== true);

  if (!standing.length) {
    p('    BLOCKING            : none' + (discounted.length ? ' that would stop an apply' : ''));
  } else {
    p(`    BLOCKING            : ${standing.length}`);
    for (const b of standing) {
      p('');
      p(`      [${b.code}]  ${b.path}`);
      wrap(b.detail, 8).forEach(p);
      if (b.selfCausedRefused) {
        wrap('NOTE: this tool wrote here, and the discount that would normally clear ' +
             'that was REFUSED — ' + b.selfCausedRefused, 8).forEach(p);
      }
      wrap('remedy (YOU run this, not the tool): ' + b.remedy, 8).forEach(p);
    }
  }
  if (discounted.length) {
    p('');
    p(`    DISCOUNTED          : ${discounted.length} — caused by this tool's own earlier run,`);
    p('                          per its receipt. The applier does not stop for these.');
    for (const b of discounted) {
      p(`      [${b.code}]  ${b.path}`);
      wrap(b.selfCausedReason || '', 10).forEach(p);
    }
    wrap('Not a flag and not settable. A file this tool MERGED into is discounted only ' +
         'while its recorded content digest still matches, so an edit of yours brings ' +
         'the block back.', 6).forEach(p);
  }
}

// ── the tool's own two files, in the artifact the user approves ──────────────
// They are not harness content and not additive units, so they get their own
// short list rather than being smuggled into the buckets. Without this the plan
// promised N paths and the apply wrote N+2 — true, disclosed afterwards, and
// still not what was reviewed.
function bookkeepingSection(p, plan) {
  const items = plan.bookkeeping || [];
  if (!items.length) return;
  p(`  BOOKKEEPING (${items.length}) — written by the TOOL, not part of the harness`);
  for (const b of items) {
    p(`    ${b.path}`);
    wrap(b.purpose, 6).forEach(p);
    wrap('written: ' + b.when, 6).forEach(p);
  }
  wrap('Both are named in the uninstall procedure. Removing them removes the record ' +
       'of what was installed, so remove them last.', 4).forEach(p);
  p('');
}

// ── the number that compares to the apply report ─────────────────────────────
// A unit is a decision, not a file: twelve of the additive units are whole
// directories. Printing only the unit count put `62` next to an apply reporting
// `WROTE 407` and invited a reader to conclude one of them was wrong. This
// resolves the units by running the applier's own traversal in predict mode, so
// the two numbers are the same kind of thing and can be compared at a glance.
function wouldWriteSection(p, plan) {
  const w = plan.counts && plan.counts.wouldWrite;
  if (!w) return;
  p('  RESOLVED to paths — this is the number to compare against the apply report');
  if (w.total === null) {
    p('    could not be resolved:');
    for (const u of w.unresolved) wrap('- ' + u, 6).forEach(p);
    p('');
    return;
  }
  p(`    harness      ${String(w.harness).padStart(4)}   files and directories created (from ${w.resolvedFrom.path} path unit(s))`);
  p(`    rules        ${String(w.rules).padStart(4)}   .claude/rules/ files`);
  p(`    gitignore    ${String(w.gitignore).padStart(4)}   one fenced merge, carrying ${w.resolvedFrom.line} pattern(s)`);
  p(`    hooks        ${String(w.hooks).padStart(4)}   the settings merge and its sidecar, for ${w.resolvedFrom['json-key']} hook command(s)`);
  p(`    TOTAL        ${String(w.total).padStart(4)}   what \`--apply --only=all,hooks\` will report as WROTE`);
  if (w.unresolved.length) {
    p('    not resolved:');
    for (const u of w.unresolved) wrap('- ' + u, 6).forEach(p);
  }
  p('');
}

function wrap(text, indent) {
  const width = 78 - indent;
  const pad = ' '.repeat(indent);
  const words = String(text).split(/\s+/);
  const out = [];
  let cur = '';
  for (const w of words) {
    if (cur.length && cur.length + 1 + w.length > width) { out.push(pad + cur); cur = w; }
    else cur = cur.length ? cur + ' ' + w : w;
  }
  if (cur.length) out.push(pad + cur);
  return out;
}

module.exports = { render, wrap };
