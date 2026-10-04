# Mods proof — 2026-10-04 (Claude Code 2.1.289)

Throwaway experiment, kept as evidence. Not shipped, not wired, not a design.

- `mod/` — the test mod (`hooks/register.js`); modes `observe`, `route`, `standin`, `codex`.
- `evidence/` — logs from the runs.

Results:
1. A mod loads from a local directory with `--plugin-dir` (no marketplace install). PASS.
2. A mod can answer a subagent's model request without calling the model; the
   resulting Write still passed through the project's `PreToolUse` settings hook. PASS.
3. Codex CLI (read-only, ChatGPT login, no API key) authored a small task; the mod
   turned its JSON into Write calls; both writes were logged by the settings hook
   as agent `scribe`; the generated test passed; Claude cost $0, 34 s. PASS.
4. Per-role model rewrite in `turn.step`: applied, but NOT verified to take effect
   (terminal CLI was logged out, no real model answered). OPEN.

Not proven: multi-turn tool use by the external model; reads through Claude Code's
Read tool (Codex read files in its own sandbox); feedback when a write is denied;
a real main session (it was canned); tasks of realistic size.
