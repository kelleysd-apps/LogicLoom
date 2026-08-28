'use strict';
// classify.js — the four-bucket classifier.
//
// THE RULES, stated once, in force order. Every classification carries the rule
// id that produced it, so a surprising verdict is traceable to a line here
// rather than to a judgement call.
//
//   R0  payload-missing   The unit's source is not in the payload. Not a bucket:
//                         a defect in the payload, reported as an error.
//   R1  replace           targetPath appears in REPLACE_ALLOWLIST. Requires the
//                         path to be named EXPLICITLY, in this file, with a
//                         reason. There is no rule that computes "ours is
//                         better" — a classifier cannot know that, and a
//                         classifier that guesses it overwrites someone's work.
//                         The list is EMPTY by design. Near-empty is the target
//                         state, not a stub.
//   R2  additive          No counterpart at targetPath / selector. Nothing of
//                         the adopter's is at stake.
//   R3  keep-theirs       A counterpart exists and R1 did not name it. DEFAULT
//                         FOR EVERY COLLISION. Ours is dropped — and PRINTED,
//                         with the reason, because a silent drop is how an
//                         adopter discovers six weeks later that a hook they
//                         assumed was installed never was.
//   R4  keep-theirs-identical  A counterpart exists and is byte-identical (or,
//                         for json-key/line units, the same command/pattern).
//                         Same bucket as R3, distinct reason: nothing is lost,
//                         and this is what makes a re-run report "already
//                         installed" instead of "collision".
//
// OBSOLETE is not a bucket a payload unit falls into. It is a finding ABOUT THE
// TARGET: the project's own rule references something that does not exist. It is
// report-only and no applier ever actions it — the reference might be to a file
// the human is about to write.
//
// Writes nothing.

const fs = require('node:fs');
const path = require('node:path');
const detect = require('./detect');

// ── R1: the explicit replace list ────────────────────────────────────────────
// EMPTY BY DESIGN. An entry is a claim that LogicLoom's version of a file the
// adopter already has is strictly better than theirs, which is almost never a
// claim anyone can make about a file they have not read. Each entry needs a
// `reason` a human can disagree with, and a `test` describing what would have to
// be true of the adopter's copy for the claim to hold.
const REPLACE_ALLOWLIST = [
  // Example of the required shape (commented, not active):
  // { targetPath: '.claude/some-file', reason: '...', test: '...' }
];

function replaceEntryFor(targetPath) {
  for (const e of REPLACE_ALLOWLIST) if (e.targetPath === targetPath) return e;
  return null;
}

// ── counterpart tests, per granularity ───────────────────────────────────────
function pathCounterpart(root, unit) {
  const abs = path.join(root, unit.targetPath);
  const kind = detect.statKind(abs);
  if (kind === 'absent') return { exists: false, kind };
  if (kind === 'file' && unit.kind === 'file') {
    // Byte comparison against the payload — the R4 case.
    return { exists: true, kind, identical: null, abs };
  }
  return { exists: true, kind, abs };
}

function sameFileBytes(a, b) {
  try {
    const A = fs.readFileSync(a);
    const B = fs.readFileSync(b);
    return A.length === B.length && A.equals(B);
  } catch (e) { return null; }
}

// A hook command entry counts as present when the adopter already runs the SAME
// command under the same event. Matcher is compared too but a differing matcher
// is reported rather than treated as absent — installing a second copy of a hook
// under a different matcher is a real change to their config.
function settingsCounterpart(targetSettings, unit) {
  if (!targetSettings || targetSettings.kind === 'absent') return { exists: false, reason: 'no .claude/settings.json' };
  if (targetSettings.parse !== 'ok') {
    return { exists: 'unknown', reason: 'their settings.json does not parse: ' + targetSettings.reason };
  }
  const hooks = targetSettings.value && targetSettings.value.hooks;
  if (!hooks || typeof hooks !== 'object') return { exists: false, reason: 'no hooks object' };
  const groups = hooks[unit.selector.event];
  if (!Array.isArray(groups)) return { exists: false, reason: `no ${unit.selector.event} hooks` };
  let matcherMismatch = null;
  for (const g of groups) {
    const inner = Array.isArray(g.hooks) ? g.hooks : [];
    for (const h of inner) {
      if (!h || h.command !== unit.selector.command) continue;
      const gm = typeof g.matcher === 'string' ? g.matcher : '';
      if (gm === unit.selector.matcher) return { exists: true, identical: true, reason: 'same command, same matcher' };
      matcherMismatch = gm;
    }
  }
  if (matcherMismatch !== null) {
    return { exists: true, identical: false, reason: `same command under a DIFFERENT matcher ('${matcherMismatch}' vs ours '${unit.selector.matcher}')` };
  }
  return { exists: false, reason: 'command not present' };
}

function gitignoreCounterpart(targetIgnore, unit) {
  if (!targetIgnore || targetIgnore.kind !== 'file') return { exists: false, reason: 'no .gitignore' };
  const lines = targetIgnore.lines;
  if (lines === detect.UNKNOWN || !Array.isArray(lines)) return { exists: 'unknown', reason: '.gitignore unreadable' };
  for (const l of lines) {
    if (l.trim() === unit.value) return { exists: true, identical: true, reason: 'exact pattern already present' };
  }
  return { exists: false, reason: 'pattern not present' };
}

// ── the classifier ───────────────────────────────────────────────────────────
function classifyUnit(unit, ctx) {
  const { root, payloadRoot, surfaces } = ctx;

  if (unit.payloadPresent === false) {
    return Object.assign({}, unit, {
      bucket: 'error',
      rule: 'R0',
      reason: 'manifest names this path but the payload does not contain it'
    });
  }

  const rep = replaceEntryFor(unit.targetPath);

  let cp;
  if (unit.granularity === 'json-key') {
    cp = settingsCounterpart(surfaces.claude && surfaces.claude.settings, unit);
  } else if (unit.granularity === 'line') {
    cp = gitignoreCounterpart(surfaces.gitignore, unit);
  } else {
    cp = pathCounterpart(root, unit);
    if (cp.exists === true && unit.kind === 'file' && cp.kind === 'file') {
      // `sourceAbs` is set by units whose source is resolved against the PACKAGE
      // root rather than the payload root (the `author:` rows). Falling back to
      // the payload root for those would compare against a path that does not
      // exist, which reads as "could not be compared" — a keep-theirs with a
      // wrong reason attached.
      const srcAbs = unit.sourceAbs || path.join(payloadRoot, unit.sourcePath);
      const same = sameFileBytes(srcAbs, cp.abs);
      cp.identical = same;
      cp.reason = same === true ? 'byte-identical to the payload copy'
        : same === false ? 'exists with different content'
        : 'exists; could not be compared';
    } else if (cp.exists === true) {
      cp.reason = `a ${cp.kind} already exists at this path`;
    } else {
      cp.reason = 'no counterpart in the target repo';
    }
  }

  if (cp.exists === 'unknown') {
    return Object.assign({}, unit, {
      bucket: 'keep-theirs',
      rule: 'R3',
      counterpart: cp,
      reason: 'UNKNOWN whether a counterpart exists (' + cp.reason + ') — failing toward theirs'
    });
  }

  if (cp.exists === false) {
    if (rep) {
      return Object.assign({}, unit, {
        bucket: 'additive', rule: 'R2', counterpart: cp,
        reason: 'no counterpart (listed for replace, but there is nothing to replace)'
      });
    }
    return Object.assign({}, unit, {
      bucket: 'additive', rule: 'R2', counterpart: cp, reason: cp.reason
    });
  }

  if (rep) {
    return Object.assign({}, unit, {
      bucket: 'replace', rule: 'R1', counterpart: cp,
      reason: rep.reason, replaceTest: rep.test
    });
  }

  if (cp.identical === true) {
    return Object.assign({}, unit, {
      bucket: 'keep-theirs', rule: 'R4', counterpart: cp,
      reason: 'already present and identical — nothing to install, nothing lost'
    });
  }

  return Object.assign({}, unit, {
    bucket: 'keep-theirs', rule: 'R3', counterpart: cp,
    reason: 'the target already has this and it is theirs; ours is DROPPED — ' + cp.reason
  });
}

// ── OBSOLETE: findings about the target, never actioned ──────────────────────
// A project rule that references something absent. Report-only: the reference
// may be to a file the human is about to write, and deleting or rewriting
// someone's config on that inference is exactly the class of damage this planner
// refuses to do.
function findObsolete(root, surfaces) {
  const found = [];

  // 1. Hook commands in their settings.json pointing at a missing script.
  const st = surfaces.claude && surfaces.claude.settings;
  if (st && st.parse === 'ok' && st.value && st.value.hooks) {
    for (const event of Object.keys(st.value.hooks)) {
      const groups = st.value.hooks[event];
      if (!Array.isArray(groups)) continue;
      for (const g of groups) {
        for (const h of (Array.isArray(g.hooks) ? g.hooks : [])) {
          if (!h || typeof h.command !== 'string') continue;
          const m = /(?:^|\s)((?:\.\/)?[\w.\-/]+\.(?:sh|js|py|ts))(?:\s|$)/.exec(h.command);
          if (!m) continue;
          const rel = m[1].replace(/^\.\//, '');
          if (rel.charAt(0) === '/') continue; // absolute: not ours to judge
          if (detect.statKind(path.join(root, rel)) === 'absent') {
            found.push({
              kind: 'missing-hook-script',
              source: '.claude/settings.json',
              reference: rel,
              detail: `${event} hook runs \`${h.command}\` but ${rel} does not exist`,
              action: 'report-only'
            });
          }
        }
      }
    }
  }

  // 2. @imports in their CLAUDE.md / AGENTS.md pointing at a missing file.
  for (const f of ['CLAUDE.md', 'CLAUDE.local.md', 'AGENTS.md']) {
    const text = detect.readTextOrNull(path.join(root, f));
    if (text === null) continue;
    const re = /(?:^|\s)@([\w.\-/]+\.(?:md|json|txt|ya?ml))/gm;
    let m;
    while ((m = re.exec(text)) !== null) {
      const rel = m[1];
      if (rel.charAt(0) === '/') continue;
      if (detect.statKind(path.join(root, rel)) === 'absent') {
        found.push({
          kind: 'missing-import',
          source: f,
          reference: rel,
          detail: `${f} imports @${rel}, which does not exist`,
          action: 'report-only'
        });
      }
    }
  }

  // 3. Backtick-quoted repo paths cited by their agent-config files. Restricted
  //    to path-looking strings with a directory separator and a known extension,
  //    so ordinary prose in backticks is not swept in.
  //
  //    ROOT-ANCHORING, and why it is not optional. Docs cite path FRAGMENTS
  //    constantly — `domain-briefs/frontend.md` (whose real home is
  //    plugins/loom-governance/), `hooks/hooks.json` and
  //    `.claude-plugin/plugin.json` (per-plugin patterns, not one location).
  //    None of those is a broken reference; all three resolve as "absent" if you
  //    test them from the repo root. A finding must therefore also be ANCHORED:
  //    its first segment has to be a real top-level entry in this repo. Without
  //    that filter the bucket fills with noise, and a report-only bucket nobody
  //    trusts is worse than no bucket.
  for (const f of ['CLAUDE.md', 'AGENTS.md', '.cursorrules']) {
    const text = detect.readTextOrNull(path.join(root, f));
    if (text === null) continue;
    const re = /`([\w.\-]+(?:\/[\w.\-]+)+\.(?:sh|md|json|ya?ml|js|ts|py))`/g;
    const seen = {};
    let m;
    while ((m = re.exec(text)) !== null) {
      const rel = m[1];
      if (seen[rel]) continue;
      seen[rel] = true;
      const firstSegment = rel.slice(0, rel.indexOf('/'));
      if (detect.statKind(path.join(root, firstSegment)) !== 'dir') continue;
      if (detect.statKind(path.join(root, rel)) === 'absent') {
        found.push({
          kind: 'missing-cited-path',
          source: f,
          reference: rel,
          detail: `${f} cites \`${rel}\`, which does not exist`,
          action: 'report-only'
        });
      }
    }
  }

  return found;
}

function classifyAll(units, ctx) {
  const classified = units.map((u) => classifyUnit(u, ctx));
  const buckets = { additive: [], 'keep-theirs': [], replace: [], error: [] };
  for (const c of classified) buckets[c.bucket].push(c);
  return { classified, buckets };
}

module.exports = {
  classifyUnit, classifyAll, findObsolete,
  REPLACE_ALLOWLIST, replaceEntryFor,
  settingsCounterpart, gitignoreCounterpart, pathCounterpart, sameFileBytes
};
