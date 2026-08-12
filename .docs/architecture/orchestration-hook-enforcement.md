# Orchestration hook enforcement

How to make an orchestration policy actually bind, and where it stops working.

Status: field-tested on Claude Code (local CLI + Desktop Code tab). Portability
claims below are marked with their verification level — some are confirmed from
official docs, some are explicitly undocumented. Do not upgrade an
"undocumented" row to a fact without re-verifying.

Related: `orchestrator-worker-ladder.md`, `model-selection-policy.md`,
`plugins/loom-orchestrator-hook/`.

---

## The problem

A harness can define an orchestrator/worker ladder perfectly and still watch the
main agent do all the work itself. Instructions written in `CLAUDE.md`,
`AGENTS.md`, or a skill are loaded **once**, at the top of the context window.
As a session grows, they compete with thousands of tokens of more recent, more
specific material. The model does not stop believing the policy; the policy just
stops being salient. The observable failure is a main agent that reads twelve
files, edits six, runs the tests, and never spawns a worker — while an
orchestration doc sits at position zero saying it should have.

Reinforcing the doc doesn't fix this. Re-injecting it does.

## Core insight

A `UserPromptSubmit` hook writes into context on **every turn**. That is a
categorically different mechanism from a file read at load time, and it is the
only supported way to keep a policy at constant salience for the life of a
session regardless of length.

This is the whole trick. Everything below is refinement.

---

## Pattern 1 — policy re-injection

`UserPromptSubmit`. Emit the full policy on the first prompt of a session, and a
compressed reminder on every prompt after. Key the state on `session_id` from
the hook's stdin JSON.

Why the split: the full policy is expensive to repeat every turn, but a
four-line reminder is not, and recency is what's actually doing the work. The
full text establishes; the short text sustains.

```bash
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0   # no jq -> degrade to silence, never break the turn

STATE_DIR="${CLAUDE_PROJECT_DIR:-$HOME/.claude}/hooks/.state"
mkdir -p "$STATE_DIR" 2>/dev/null
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null   # prune old sessions

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
marker="$STATE_DIR/policy-${session_id}.seen"

if [ -f "$marker" ]; then
  cat <<'SHORT'
[ORCHESTRATION POLICY — still in force] You are the orchestrator, not the executor.
Delegate execution to workers. Consult an advisor before committing to any
non-trivial approach. Get adversarial review before calling complex work done.
SHORT
  exit 0
fi

touch "$marker"
cat <<'FULL'
...full policy...
FULL
```

Two details that matter:

- **Prune the state dir**, as above. Otherwise it accumulates one file per
  session forever. Guard `jq` too: a hook that dies on a missing dependency
  takes the turn's context with it, so exit 0 silently instead.
- **Plain stdout is the right channel here** — verified in use, and worth
  stating plainly because it gets disputed. For `UserPromptSubmit`,
  stdout on exit 0 is injected as context — this event is an explicit exception
  to the rule that hook stdout is debug-only. The structured
  `hookSpecificOutput.additionalContext` form also works but is wrapped in a
  `system-reminder`, which is framed to the model as background context rather
  than as instruction. For a policy you want *followed*, plain stdout is the
  stronger channel.

## Pattern 2 — delegation nudge

`PreToolUse` on `Edit|Write|MultiEdit|NotebookEdit|Bash`. Count how often the
main agent executes directly, and inject a correction once it crosses a
threshold.

This is where the load-bearing mechanism lives:

### The `agent_id` discriminator

`PreToolUse` fires for subagent tool calls as well as main-agent ones, and
subagents **share the parent's `session_id`**. So neither the event nor the
session tells you who acted. The distinguishing field is `agent_id`:

| Field | Main agent | Subagent |
|---|---|---|
| `agent_id` | absent | present (subagent uuid) |
| `agent_type` | absent* | subagent type, e.g. `Explore` |
| `session_id` | session uuid | **same** session uuid |

\* `agent_type` also appears when the top-level session itself was launched with
`--agent`, so test `agent_id`, not `agent_type`.

Without this, a delegation-enforcement hook is impossible to write: the workers
you asked for trip your own counter, and the hook punishes compliance.

```bash
# Subagent call -> delegation is working. Stay silent.
if printf '%s' "$input" | jq -e '.agent_id // empty' >/dev/null 2>&1; then
  exit 0
fi
```

### Exempt orchestrator recon

An orchestrator legitimately runs cheap read-only commands to decide what to
delegate. Counting those produces noise and trains the operator to ignore the
hook.

```bash
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')

if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
  if printf '%s' "$cmd" | grep -Eq '^[[:space:]]*(ls|pwd|which|echo|cat|head|wc|file|stat|env|date|git (status|log|diff|branch|remote|rev-parse))\b'; then
    exit 0
  fi
fi
```

> **Read this before reusing that regex.** `grep -Eq` matches if *any* line
> qualifies, and the pattern only anchors the start of a line. `echo hi; rm -rf /`
> and a multi-line `ls\nrm -rf /` both match on their first token and are
> exempted.
>
> In *this* hook that is a counting inaccuracy, not a vulnerability — the hook
> emits context and never grants permission, so the worst outcome is a
> destructive command that fails to increment a nudge counter. **In the
> hard-block variant below it is a real security hole**, because the same
> pattern would be deciding what to let through. If you adapt this for blocking,
> match the whole command, reject anything containing `;`, `&&`, `||`, `|`,
> backticks, `$(`, or a newline, and prefer an allowlist over a regex.

### Threshold, not tripwire

Fire on the Nth direct action and every Nth after (N=3 works). A hook that fires
on the first direct edit is wrong often enough that it gets disabled.

```bash
counter="$STATE_DIR/direct-${session_id}.count"
count=$(cat "$counter" 2>/dev/null || echo 0)
count=$((count + 1))
printf '%s' "$count" > "$counter"

if [ "$count" -lt 3 ] || [ $((count % 3)) -ne 0 ]; then
  exit 0
fi

printf '%s' "[DELEGATION CHECK] Direct main-agent execution #${count} this session, with no subagent doing the work. You are the orchestrator — workers execute. Unless this is a permitted direct action, hand the rest to a subagent with a self-contained brief." \
  | jq -R -s '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: .}}'
```

`jq -R -s` is doing real work there: it reads the message as raw text and emits
it as a correctly escaped JSON string. Interpolating the message into a JSON
template by hand breaks the moment it contains a quote or newline.

### Fail safe: emit context, never a decision

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[DELEGATION CHECK] ..."
  }
}
```

`PreToolUse` supports `permissionDecision` (`allow`/`deny`/`ask`/`defer`), and
it is tempting to pair the nudge with `"allow"` so the message definitely
surfaces. **Don't.** Emitting `allow` auto-approves the call and silently
overrides the operator's permission configuration — a governance hook that
weakens governance as a side effect of nagging. Omitting `permissionDecision`
entirely means the worst case is that the nudge does nothing, which is the
correct direction to fail.

The tradeoff is honest: context-only output on `PreToolUse` is documented, but
whether it renders reliably in every client is worth verifying in your own
environment before depending on it. Make three direct edits in a fresh session
and confirm the check appears.

### Hard-block variant

`exit 2` with the reason on stderr blocks the call outright. Reasonable for a
governance pack where the orchestrator must *never* execute. Expect friction on
genuine one-line fixes; pair it with an explicit allowlist of permitted direct
actions if you go this way.

---

## Write the escape hatches into the policy

A rule with no permitted exceptions gets discarded wholesale rather than
followed at the margin. The policy text should name what direct action is
allowed:

> Act directly only for: a single edit to a file already in context, one
> read-only lookup, something answerable from loaded context, or writing the
> brief itself. Anything larger — delegate it.

Likewise, make the adversarial-review step a **command**, not a concept.
"Get outside review" is ignorable; `codex exec "<brief>"` or `agy -p "<brief>"`
is executable. Any external CLI works — the value is a different model with
different blind spots, and these run outside the harness so they can't inherit
its assumptions.

---

## Surface portability

The most expensive thing to learn by trial. Confidence levels are stated because
several of these are genuinely undocumented.

| Surface | Executes | User `~/.claude` hooks | Repo `.claude/settings.json` hooks | Confidence |
|---|---|---|---|---|
| Claude Code — terminal CLI | local | yes | yes | verified in use |
| Claude Code — Desktop *Code* tab | local | yes | yes | verified in use |
| Claude Code — cloud (`--cloud`, web) | Anthropic cloud | **no** | **yes** | official docs |
| Cowork | Anthropic cloud VM | **no** | **no** | official docs |
| Normal chat (claude.ai / Desktop *Chat*) | server-side | **no** | **no** | official docs |

Consequences worth internalizing:

- **Cowork is not a Code cloud session.** It sources skills, plugins and
  connectors from the claude.ai account config, not from `~/.claude`, and unlike
  Code cloud sessions it does not pick up repo-committed hooks either. Its
  supported substitute is Settings → Cowork → Global Instructions: static text
  read before each session, advisory rather than enforced. Hook support in
  Cowork was requested in anthropics/claude-code#63360 (filed 2026-05-28); that
  issue is **closed**, and this doc does not establish why — check its
  resolution before assuming the gap either persists or has been filled.
- **User-level hooks never leave the machine.** Anything that must survive into
  a cloud session has to be committed to the repo.
- **claude.ai profile/personalization instructions do not reach Claude Code.**
  The Claude Code memory documentation enumerates every instruction source —
  managed policy CLAUDE.md, user CLAUDE.md, project CLAUDE.md, local CLAUDE.md,
  `.claude/rules/`, auto memory — and that field appears nowhere, including in
  the troubleshooting section listing every reason an instruction may not apply.
  Operators routinely assume it carries over. It does not.
- **In normal chat the policy is unactionable.** No subagents, no shell. Porting
  an orchestration policy there instructs the model to use tools it doesn't
  have, which produces *performed* delegation rather than better answers. Leave
  it out.

### Explicitly undocumented

State these as unknown rather than guessing:

- Whether Cowork inherits the account-level instructions field, or whether its
  Global Instructions field is fully independent. **Practical guidance:** fill
  Cowork's field with complete, self-sufficient text; do not rely on inheritance.
- Precedence when account instructions, Cowork Global Instructions, and Cowork
  Folder Instructions overlap or contradict.
- Whether Cowork supports subagents (the Agent/Task tool) at all.
- Whether extra CLI tooling can be provisioned into a Cowork sandbox, the way
  setup scripts provision Code cloud environments.

---

## Installation

Repo-level (recommended for a harness — travels with the project and reaches
Code cloud sessions):

```jsonc
// .claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "timeout": 10,
        "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/orchestration-policy.sh" } ] }
    ],
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash",
        "hooks": [ { "type": "command", "timeout": 10,
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/delegation-nudge.sh" } ] }
    ]
  }
}
```

For a user-level install in `~/.claude/settings.json`, **use absolute paths**.
`$HOME` expansion in the `command` field is not guaranteed, and the failure mode
is a hook that silently never runs.

`chmod +x` both scripts. Verify by piping synthetic JSON before trusting them:

```bash
echo '{"session_id":"t","tool_name":"Edit","agent_id":"sub-1","tool_input":{}}' \
  | .claude/hooks/delegation-nudge.sh   # expect: no output
```

Matcher syntax: a bare string is an exact match; `|` or `, ` ORs exact names;
anything with other regex metacharacters is an unanchored JS RegExp, so anchor
with `^...$` when you mean exact.

---

## Relationship to `loom-orchestrator-hook`

This harness already ships hook infrastructure and an orchestration-guidance
skill. This document does not propose replacing either. What it adds is the
enforcement layer: the `agent_id` discriminator, the recon exemption, the
threshold, the fail-safe output shape, and the portability matrix. The natural
home for an implementation is inside the existing orchestrator-hook plugin
rather than a new one — `plugins/CONTRIBUTING.md` is explicit that new plugins
need a distinct domain, and this is not one.

Not assessed here: how the counter should interact with the governance pack's
existing `PreToolUse` matchers on `Write|Edit|MultiEdit|NotebookEdit` and
`Bash`. Two hooks on the same matcher both fire; ordering and combined output
behavior should be tested before shipping.

## Open questions for contributors

1. Should the counter reset on a successful delegation, rather than only at
   session start? Current behavior means a session that delegates heavily late
   still carries early direct-execution count.
2. Is there a signal better than a raw count — e.g. ratio of direct actions to
   spawned workers, or bytes edited directly?
3. Can the nudge be made to name *what* should have been delegated, by reading
   `tool_input`, rather than issuing a generic reminder?
