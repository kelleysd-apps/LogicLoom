#!/usr/bin/env node
'use strict';
// logicloom — the LogicLoom CLI entry point.
//
// SUBCOMMAND DISPATCH, AND THE ONE RULE THAT MATTERS HERE
// -----------------------------------------------------------------------------
// argv[0] after the binary is the subcommand. An absent or unrecognised
// subcommand prints usage and exits NON-ZERO. It does NOT fall through to
// `init`.
//
// That is not tidiness. `npx logicloom` is a thing someone types in a repo they
// care about, often just to see what the tool is, and a bare invocation that
// starts installing is the same class of surprise as an installer with no
// confirm. The tool does nothing until it is told which thing to do.
//
// NAMING — standard unless no standard exists
// -----------------------------------------------------------------------------
// `init` is the near-universal verb for "set this up in my existing project":
// `prisma init`, `tailwindcss init`, `eslint --init`, `tsc --init`. That is the
// convention this tool is in, so that is the word.
//
// It is deliberately NOT `create-*`. npm formalises that other convention —
// `npm init foo` execs `create-foo`, and `npm create` is an alias for `npm init`
// — and it means SCAFFOLD A NEW PROJECT. This tool does the opposite: it merges
// into a project that already exists. The package is correspondingly not named
// `create-logicloom`.
//
// `adopt` is kept as a HIDDEN ALIAS. It is the more precise word for what
// actually happens (merge into an existing project, with a review step, rather
// than write fresh config) and it is the word the design docs use — so typing it
// works. It is not advertised: one documented way to do a thing.
//
// `init` is currently the ONLY subcommand. The shape leaves room for a later
// `doctor` without forcing a second package; the usage text says so plainly
// rather than implying a suite that does not exist.
//
// WHAT `init` DOES TODAY: the read-only half — detect, classify, plan. The
// applier is NOT built. `init` therefore produces a plan and says so; it has no
// write path at all, in any flag combination.

const fs = require('node:fs');
const path = require('node:path');

const PKG_ROOT = path.resolve(__dirname, '..');

let PKG = { name: 'logicloom', version: 'unknown' };
try { PKG = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, 'package.json'), 'utf8')); } catch (e) { /* dev */ }

// Advertised subcommands. `adopt` is handled below but deliberately absent here.
const SUBCOMMANDS = {
  init: {
    summary: 'Set LogicLoom up in this existing repository.',
    detail: 'Read-only today: it detects, classifies and prints a plan. It writes nothing.'
  }
};

// Accepted but not advertised. See the naming note above.
const HIDDEN_ALIASES = { adopt: 'init' };

function usage() {
  const L = [];
  L.push(`${PKG.name} ${PKG.version} — LogicLoom`);
  L.push('');
  L.push('USAGE');
  L.push(`  npx ${PKG.name} <subcommand> [dir] [options]`);
  L.push('');
  L.push('SUBCOMMANDS');
  for (const name of Object.keys(SUBCOMMANDS)) {
    L.push(`  ${name.padEnd(10)} ${SUBCOMMANDS[name].summary}`);
    L.push(`  ${' '.repeat(10)} ${SUBCOMMANDS[name].detail}`);
  }
  L.push('');
  L.push('  `init` is currently the ONLY subcommand. There is no suite behind this shape');
  L.push('  yet — it exists so a later `doctor` needs no second package.');
  L.push('');
  L.push('OPTIONS for `init`');
  L.push('  [dir]                Repository to work on (default: current directory)');
  L.push('  --dry-run            Report what would be done and write nothing. This is the');
  L.push('                       default and, today, the only behaviour: no applier exists.');
  L.push('  --payload <dir>      Harness tree that would be installed');
  L.push('                       (default: the packaged payload/, else a dev checkout)');
  L.push('  --manifest <file>    Payload manifest (default: <pkg>/payload-manifest.txt)');
  L.push('  --json               Emit the plan as JSON on stdout instead of a report');
  L.push('  -h, --help           This text');
  L.push('');
  L.push('EXIT CODES');
  L.push('  0  a plan was produced and an apply would be clear to proceed');
  L.push('  1  a plan was produced but an apply is BLOCKED (see the blocking list)');
  L.push('  2  usage error, or no subcommand given');
  L.push('  3  the plan could not be produced (unreadable manifest, git unavailable)');
  L.push('');
  L.push('This command never writes to the target repository and never runs mutating git.');
  return L.join('\n');
}

function parseInitArgs(argv) {
  const opts = { target: null, payload: null, manifest: null, json: false, help: false, dryRun: true };
  const needsValue = (name, v) => (v === undefined ? { error: `option '${name}' requires a value` } : null);

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    let err = null;
    if (a === '--json') opts.json = true;
    // `--dry-run` is the standard name. `--plan` is accepted because it is the
    // word the design docs use; both are no-ops while no write path exists.
    else if (a === '--dry-run' || a === '--plan') opts.dryRun = true;
    else if (a === '-h' || a === '--help') opts.help = true;
    else if (a === '--target' || a === '--root') { opts.target = argv[++i]; err = needsValue(a, opts.target); }
    else if (a.indexOf('--target=') === 0) opts.target = a.slice(9);
    else if (a.indexOf('--root=') === 0) opts.target = a.slice(7);
    else if (a === '--payload') { opts.payload = argv[++i]; err = needsValue(a, opts.payload); }
    else if (a.indexOf('--payload=') === 0) opts.payload = a.slice(10);
    else if (a === '--manifest') { opts.manifest = argv[++i]; err = needsValue(a, opts.manifest); }
    else if (a.indexOf('--manifest=') === 0) opts.manifest = a.slice(11);
    else if (a.charAt(0) === '-') return { error: `unknown option '${a}'` };
    // Positional directory — the shape `prisma init`/`tsc --init` users expect.
    else if (opts.target === null) opts.target = a;
    else return { error: `unexpected second positional argument '${a}'` };
    if (err) return err;
  }
  if (opts.target === null) opts.target = process.cwd();
  return opts;
}

function cmdInit(argv) {
  const opts = parseInitArgs(argv);
  if (opts.error) { process.stderr.write(opts.error + '\n\n' + usage() + '\n'); return 2; }
  if (opts.help) { process.stdout.write(usage() + '\n'); return 0; }

  let targetAbs;
  try {
    targetAbs = path.resolve(opts.target);
    if (!fs.statSync(targetAbs).isDirectory()) throw new Error('not a directory');
  } catch (e) {
    process.stderr.write(`ERROR: target is not a readable directory: ${opts.target}\n`);
    return 2;
  }

  const planLib = require('../lib/plan');
  const renderLib = require('../lib/render');

  let plan;
  try {
    plan = planLib.build({
      pkgRoot: PKG_ROOT,
      pkgName: PKG.name,
      pkgVersion: PKG.version,
      target: targetAbs,
      payload: opts.payload,
      manifest: opts.manifest
    });
  } catch (e) {
    process.stderr.write('ERROR: could not produce a plan: ' + (e && e.message) + '\n');
    return 3;
  }

  if (opts.json) process.stdout.write(JSON.stringify(plan, null, 2) + '\n');
  else process.stdout.write(renderLib.render(plan) + '\n');

  return plan.applyReady ? 0 : 1;
}

function resolveSubcommand(sub) {
  if (Object.prototype.hasOwnProperty.call(SUBCOMMANDS, sub)) return sub;
  if (Object.prototype.hasOwnProperty.call(HIDDEN_ALIASES, sub)) return HIDDEN_ALIASES[sub];
  return null;
}

function main(argv) {
  const sub = argv[0];

  if (sub === undefined || sub === '-h' || sub === '--help' || sub === 'help') {
    // --help is a request; no subcommand is a usage error. Both print the same
    // text, and they exit differently on purpose.
    const asked = sub !== undefined;
    process.stdout.write(usage() + '\n');
    if (!asked) {
      process.stderr.write('\nERROR: no subcommand given. Nothing was done.\n');
      return 2;
    }
    return 0;
  }

  if (sub === '--version' || sub === '-v') {
    process.stdout.write(PKG.version + '\n');
    return 0;
  }

  const resolved = resolveSubcommand(sub);
  if (resolved === null) {
    process.stderr.write(`ERROR: unknown subcommand '${sub}'. Nothing was done.\n\n`);
    process.stderr.write(usage() + '\n');
    return 2;
  }

  if (resolved === 'init') return cmdInit(argv.slice(1));
  /* istanbul ignore next — unreachable while init is the only subcommand */
  return 2;
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}

module.exports = { main, usage, SUBCOMMANDS, HIDDEN_ALIASES, resolveSubcommand };
