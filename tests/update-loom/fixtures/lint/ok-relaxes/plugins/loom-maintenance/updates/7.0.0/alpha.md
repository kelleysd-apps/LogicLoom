---
id: alpha
title: Alpha guidance
purpose: The guide mentions alpha.
touches:
  - .claude/settings.json
adds: []
requires: []
safety: false
done-when:
  - "settings.json has an ask list"
check: alpha.check.sh
relaxes:
  - .claude/settings.json :: permissions.deny :: Bash(git push --force:*)
project-data: false
---

## What changed and why

The guide now mentions alpha.

## What a stock file looks like after

The guide mentions alpha.

