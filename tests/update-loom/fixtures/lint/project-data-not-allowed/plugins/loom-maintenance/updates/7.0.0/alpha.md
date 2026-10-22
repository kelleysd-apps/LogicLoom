---
id: alpha
title: Alpha guidance
purpose: The guide mentions alpha.
touches:
  - docs/a.md
adds: []
requires: []
safety: false
done-when:
  - "docs/a.md mentions alpha"
check: alpha.check.sh
pattern: '^bad line'
project-data: true
---

## What this note may claim

Only that your file matches a known defect pattern.

## Example

Before: a bad line. After: that line is removed and nothing else changes.

