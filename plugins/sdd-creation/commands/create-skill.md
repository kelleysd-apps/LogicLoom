---
name: create-skill
description: "⚠️ DEPRECATED — Use /create-plugin instead (Plugin-First Architecture v4.0)"
model: opus
---
# ⚠️ DEPRECATED: /create-skill

**This command has been replaced by `/create-plugin`.**

In Plugin-First Architecture (v4.0), all capabilities are organized as plugins.
Skills, agents, and commands are components within plugins, not standalone entities.

## Migration

```
# Old (deprecated):
/create-skill my-skill --category domain

# New:
/create-plugin sdd-domain-myskill --category domain
```

**Removal Target**: v5.0
**Replacement**: `/create-plugin` (in this same plugin: sdd-creation)
