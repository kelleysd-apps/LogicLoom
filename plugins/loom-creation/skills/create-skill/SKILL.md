---
name: create-skill
version: 4.0.0
category: creation
description: "⚠️ DEPRECATED — Use create-plugin skill instead (Plugin-First Architecture v4.0)"
triggers:
  - create skill
  - new skill
  - /create-skill
---

# ⚠️ DEPRECATED: Create Skill

**This skill has been replaced by `create-plugin`.**

In Plugin-First Architecture (v4.0), capabilities are organized as plugins.
Skills are components within plugins, not standalone entities.

## Migration

Use `/create-plugin` instead of `/create-skill`.
Skills are created as part of the plugin scaffold.

**Removal Target**: v5.0
**Replacement**: `plugins/loom-creation/skills/create-plugin/SKILL.md`
