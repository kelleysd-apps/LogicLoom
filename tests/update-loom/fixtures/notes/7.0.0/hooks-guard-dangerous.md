---
id: hooks-guard-dangerous
title: Dangerous shell commands are stopped before they run
purpose: Every shell command the agent runs passes through a guard that refuses the destructive ones, because the guard is wired into .claude/settings.json and the script it names exists.
touches:
  - .claude/settings.json
adds:
  - .claude/hooks/guard-dangerous-commands.sh
requires: []
safety: true
done-when:
  - ".claude/settings.json has a PreToolUse hook whose command runs .claude/hooks/guard-dangerous-commands.sh"
  - ".claude/hooks/guard-dangerous-commands.sh exists"
check: hooks-guard-dangerous.check.sh
project-data: false
---

## What changed and why

The agent can run shell commands on your machine. Until now nothing stood between
a mistaken or malicious command and your files. This update adds a guard script
and wires it into the PreToolUse hooks in `.claude/settings.json`, so a
destructive command is refused before it runs. Hooks you already have stay exactly
as they are; the guard is one more entry beside them.

## What a stock file looks like after

`.claude/settings.json` has a second `Bash` entry under `hooks.PreToolUse` whose
command is `bash .claude/hooks/guard-dangerous-commands.sh`, and the script exists
under `.claude/hooks/`.
