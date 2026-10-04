const EV = '/private/tmp/claude-501/-Users-bkelley-kelleysd-apps-LogicLoom/d496e1a8-c16a-4dfe-8c5a-ab96151341aa/scratchpad/mods-proof/evidence';
const PROOF3_FILE = '/private/tmp/claude-501/-Users-bkelley-kelleysd-apps-LogicLoom/d496e1a8-c16a-4dfe-8c5a-ab96151341aa/scratchpad/mods-proof/proj/proof3.txt';
const PROJ_DIR = '/private/tmp/claude-501/-Users-bkelley-kelleysd-apps-LogicLoom/d496e1a8-c16a-4dfe-8c5a-ab96151341aa/scratchpad/mods-proof/proj';
function parseFiles(out) {
  let s = String(out).trim();
  const tryParse = (t) => { try { const o = JSON.parse(t); return o && Array.isArray(o.files) ? o.files : null; } catch (_) { return null; } };
  let r = tryParse(s);
  if (r) return r;
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence && (r = tryParse(fence[1].trim()))) return r;
  const a = s.indexOf('{'), b = s.lastIndexOf('}');
  if (a >= 0 && b > a && (r = tryParse(s.slice(a, b + 1)))) return r;
  return [];
}
const seen = {};
const mainSeen = {};

async function log($, o) {
  try {
    const p = EV + '/mod.log';
    let prev = '';
    try { prev = await $.fs.read(p); } catch (_) {}
    await $.fs.write(p, prev + JSON.stringify(o) + '\n');
  } catch (err) { $.ui.log('modlog fail ' + err); }
}
const keys = (o) => o && typeof o === 'object'
  ? Object.fromEntries(Object.entries(o).map(([k, v]) => [k, typeof v === 'string' ? v.slice(0, 60) : Array.isArray(v) ? 'array(' + v.length + ')' : v === null ? null : typeof v]))
  : o;

export function register(on) {
  on('tool.call', async ($, e, next) => {
    await log($, { ev: 'tool.call', tool: e.tool, agentId: e.agentId, file_path: e.file_path, content: e.content });
    return next(e);
  });

  on('turn.step', async function* ($, e, next) {
    let mode = 'observe';
    try { mode = (await $.fs.read(EV + '/mode.txt')).trim(); } catch (_) {}
    let agentType;
    if (e.agentId) {
      try {
        const l = await $.agent.list();
        agentType = (l.find((a) => a.id === e.agentId) || {}).type;
      } catch (x) { agentType = 'list-failed:' + x; }
    }
    const base = { ev: 'turn.step', mode, index: e.index, agentId: e.agentId, agentType, requestedModel: e.model, effort: e.effort, messageCount: e.messageCount, inputKeys: Object.keys(e) };

    if (mode === 'route' && e.agentId) {
      const r = yield* next({ ...e, model: 'claude-haiku-4-5-20251001' });
      await log($, { ...base, routedTo: 'claude-haiku-4-5-20251001', usageModel: r.usage && r.usage.model, usage: r.usage });
      return r;
    }

    if (mode === 'codex') {
      const PROJ = PROJ_DIR;
      if (!e.agentId) {
        mainSeen.n = (mainSeen.n || 0) + 1;
        if (mainSeen.n === 1) {
          const input = { description: 'codex task', subagent_type: 'scribe', prompt: 'Do the task in TASK.md' };
          yield { kind: 'tool', index: 0, id: 'toolu_main_001', name: 'Agent' };
          yield { kind: 'input', index: 0, json: JSON.stringify(input) };
          yield { kind: 'stop', stopReason: 'tool_use', usage: null };
          await log($, { ...base, answeredWithoutModel: 'main: Agent->scribe (codex)', usageModel: null });
          return { turnId: e.turnId, index: e.index, answer: '', toolUses: [{ name: 'Agent', input }], stopReason: 'tool_use', usage: null };
        }
        yield { kind: 'text', index: 0, text: 'ok' };
        yield { kind: 'stop', stopReason: 'end_turn', usage: null };
        await log($, { ...base, answeredWithoutModel: 'main: text ok', usageModel: null });
        return { turnId: e.turnId, index: e.index, answer: 'ok', toolUses: [], stopReason: 'end_turn', usage: null };
      }
      seen[e.agentId] = (seen[e.agentId] || 0) + 1;
      if (agentType === 'scribe' && seen[e.agentId] === 1) {
        const prompt = 'Read TASK.md and the files it names in the current directory. Do not modify anything. Reply with ONLY a JSON object of the form {"files":[{"path":"<relative path>","content":"<full new file content>"}]} for every file that must be created or changed. No prose, no code fences.';
        const argv = ['codex', 'exec', '-s', 'read-only', '--skip-git-repo-check', '-c', 'model_reasoning_effort=low', prompt];
        const TIMEOUT = 300000;
        const t0 = Date.now();
        let res;
        try {
          res = await $.process.run(argv, { cwd: PROJ, stdin: '', timeoutMs: TIMEOUT });
        } catch (err) {
          await log($, { ...base, codexError: String(err), durationMs: Date.now() - t0, timeoutMs: TIMEOUT });
          yield { kind: 'text', index: 0, text: 'codex failed: ' + err };
          yield { kind: 'stop', stopReason: 'end_turn', usage: null };
          return { turnId: e.turnId, index: e.index, answer: 'codex failed', toolUses: [], stopReason: 'end_turn', usage: null };
        }
        const dur = Date.now() - t0;
        await $.fs.write(EV + '/codex-raw.txt', res.stdout);
        await $.fs.write(EV + '/codex-stderr.txt', res.stderr);
        const parsed = parseFiles(res.stdout);
        const accepted = [];
        const refused = [];
        for (const f of parsed) {
          const p = f && f.path;
          if (typeof p !== 'string' || typeof f.content !== 'string' || p.startsWith('/') || /(^|[\\/])\.\.([\\/]|$)/.test(p) || /^(\.claude|\.git)([\\/]|$)/.test(p.replace(/^\.\//, ''))) {
            refused.push(String(p));
          } else accepted.push(f);
        }
        await log($, { ...base, codexCmd: argv.slice(0, -1).concat(['<prompt omitted>']), codexExit: res.exitCode, durationMs: dur, timeoutMs: TIMEOUT, stdoutBytes: new TextEncoder().encode(res.stdout).length, stderrBytes: new TextEncoder().encode(res.stderr).length, parsedFiles: parsed.map((f) => f && f.path), accepted: accepted.map((f) => f.path), refused });
        const toolUses = [];
        let i = 0;
        for (const f of accepted) {
          const input = { file_path: PROJ + '/' + f.path, content: f.content };
          yield { kind: 'tool', index: i, id: 'toolu_codex_' + i, name: 'Write' };
          yield { kind: 'input', index: i, json: JSON.stringify(input) };
          toolUses.push({ name: 'Write', input });
          i++;
        }
        yield { kind: 'stop', stopReason: 'tool_use', usage: null };
        return { turnId: e.turnId, index: e.index, answer: '', toolUses, stopReason: 'tool_use', usage: null };
      }
      yield { kind: 'text', index: 0, text: 'done by codex' };
      yield { kind: 'stop', stopReason: 'end_turn', usage: null };
      await log($, { ...base, answeredWithoutModel: 'text done by codex', usageModel: null });
      return { turnId: e.turnId, index: e.index, answer: 'done by codex', toolUses: [], stopReason: 'end_turn', usage: null };
    }

    if ((mode === 'standin' || mode === 'route') && !e.agentId) {
      // main loop also canned (no auth available in this headless env): delegate to scribe on step 0
      mainSeen.n = (mainSeen.n || 0) + 1;
      if (mainSeen.n === 1) {
        const input = { description: 'write proof3', subagent_type: 'scribe', prompt: 'Write the file proof3.txt' };
        yield { kind: 'tool', index: 0, id: 'toolu_main_001', name: 'Agent' };
        yield { kind: 'input', index: 0, json: JSON.stringify(input) };
        yield { kind: 'stop', stopReason: 'tool_use', usage: null };
        await log($, { ...base, answeredWithoutModel: 'main: Agent->scribe', usageModel: null });
        return { turnId: e.turnId, index: e.index, answer: '', toolUses: [{ name: 'Agent', input }], stopReason: 'tool_use', usage: null };
      }
      yield { kind: 'text', index: 0, text: 'ok' };
      yield { kind: 'stop', stopReason: 'end_turn', usage: null };
      await log($, { ...base, answeredWithoutModel: 'main: text ok', usageModel: null });
      return { turnId: e.turnId, index: e.index, answer: 'ok', toolUses: [], stopReason: 'end_turn', usage: null };
    }

    if (mode === 'standin' && e.agentId) {
      seen[e.agentId] = (seen[e.agentId] || 0) + 1;
      if (seen[e.agentId] === 1) {
        const input = { file_path: PROOF3_FILE, content: 'written by a non-Claude stand-in' };
        yield { kind: 'tool', index: 0, id: 'toolu_standin_001', name: 'Write' };
        yield { kind: 'input', index: 0, json: JSON.stringify(input) };
        yield { kind: 'stop', stopReason: 'tool_use', usage: null };
        await log($, { ...base, answeredWithoutModel: 'tool_use Write', usageModel: null });
        return { turnId: e.turnId, index: e.index, answer: '', toolUses: [{ name: 'Write', input }], stopReason: 'tool_use', usage: null };
      }
      yield { kind: 'text', index: 0, text: 'done' };
      yield { kind: 'stop', stopReason: 'end_turn', usage: null };
      await log($, { ...base, answeredWithoutModel: 'text done', usageModel: null });
      return { turnId: e.turnId, index: e.index, answer: 'done', toolUses: [], stopReason: 'end_turn', usage: null };
    }

    const r = yield* next(e);
    await log($, { ...base, usageModel: r.usage && r.usage.model, usage: r.usage });
    const sp = EV + '/turn-step-shape.json';
    let exists = true;
    try { await $.fs.stat(sp); } catch (_) { exists = false; }
    if (!exists) {
      await $.fs.write(sp, JSON.stringify({ note: 'keys only, values truncated', input: keys(e), result: keys(r), usage: keys(r.usage) }, null, 1));
    }
    return r;
  });
}
