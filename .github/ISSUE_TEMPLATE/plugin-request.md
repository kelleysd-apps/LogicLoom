---
name: Plugin Request
about: Request a new plugin or plugin enhancement
title: "[Plugin] "
labels: plugin, enhancement
assignees: ''
---

## Plugin Details

**Plugin name**: loom-_____
**Category**: Core / Orchestration / Community
**Description**: 

> Note: domain expertise is no longer packaged as standalone `sdd-domain-*`
> plugins. Domains now live as lightweight **domain briefs** under
> `plugins/loom-governance/domain-briefs/<domain>.md`, retrieved via
> `get_domain_brief()`. Request a new domain brief by editing the governance
> registry rather than filing a plugin request. New capability plugins should
> use the `loom-` name prefix.

## Proposed Structure

```
plugins/loom-<name>/
  .claude-plugin/plugin.json
  skills/
    <skill-name>/SKILL.md
  agents/
    <agent-name>.md
  commands/        (optional)
  hooks/           (optional)
  scripts/         (optional)
  README.md
```

## Dependencies

- [ ] loom-governance (required)
- [ ] Other: _____________

## Use Cases

1. 
2. 
3. 

## Constitutional Impact

- Does this plugin introduce new principles? No / Yes: _____
- Does this plugin modify governance hooks? No / Yes: _____
