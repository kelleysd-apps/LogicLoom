---
id: settings-ask-restore
title: Restoring files from git asks you first
purpose: The permissions.ask list in .claude/settings.json contains Bash(git restore:*), so a command that discards uncommitted work asks you before it runs.
touches:
  - .claude/settings.json
adds: []
requires: []
safety: false
done-when:
  - ".claude/settings.json lists Bash(git restore:*) under permissions.ask"
check: settings-ask-restore.check.sh
project-data: false
---

## What changed and why

`git restore` can throw away uncommitted work in one command. Listing it under
`permissions.ask` makes the agent stop and ask before it does that. This note
shares `.claude/settings.json` with the dangerous-command guard, so the two are
approved together.

## What a stock file looks like after

`permissions.ask` in `.claude/settings.json` has the single entry
`Bash(git restore:*)`. Your other permissions are unchanged.
