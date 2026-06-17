# Contributing to LogicLoom Plugins

## Naming

New plugins use the `loom-` prefix (e.g. `loom-analytics`,
`loom-integration-slack`). The one exception is `sdd-specification`, which keeps
its legacy prefix — it **is** the SDD workflow. Do not rename existing plugins.

## Adding a Domain Brief

**Domains are briefs, not plugins.** The seven former `sdd-domain-*` plugins
(frontend, backend, database, testing, security, performance, devops) have been
collapsed into a consolidated **domain-brief registry** under
`plugins/loom-governance/domain-briefs/`. Each brief is a single Markdown file
surfaced at runtime via `get_domain_brief` (in
`.logic-loom/scripts/bash/common.sh`). Do **not** create a plugin for a new
technical domain.

To add or change a domain:

1. **Add the brief**:
   ```bash
   cp plugins/loom-governance/domain-briefs/backend.md \
      plugins/loom-governance/domain-briefs/yourname.md
   ```
   Edit it down to a focused worker brief for that domain. See
   `plugins/loom-governance/domain-briefs/README.md` for the brief format.

2. **Wire detection keywords**: add `keyword=yourname` lines to
   `plugins/loom-orchestrator-hook/config/domains.conf` so the
   governance-preflight hook can surface the brief as a swarm/team worker
   recommendation.

3. **Verify**:
   ```bash
   bash tests/contract/test_memory_search.sh   # exercises get_domain_brief
   ```

## Creating a Plugin

1. **Required structure**:
   ```
   loom-yourname/
   ├── .claude-plugin/plugin.json    # Manifest (required)
   ├── skills/                       # At least 1 skill
   │   └── yourname-operations/
   │       └── SKILL.md
   ├── agents/                       # At least 1 agent
   │   └── yourname-specialist.md
   └── README.md                     # Documentation (required)
   ```

2. **plugin.json requirements**:
   - `name`: Must start with `loom-`
   - `dependencies`: Must include `loom-governance`
   - `version`: Semantic versioning

3. **Testing requirements**:
   - Skills must load without errors
   - Agents must have valid YAML frontmatter
   - Plugin must coexist with other LogicLoom plugins
   - No hook conflicts with the governance plugin

## Distribution

Plugins are bundled in-repo under `plugins/` and exposed through the command
bridge:

```bash
bash .logic-loom/scripts/bash/sync-plugin-commands.sh sync
```

LogicLoom no longer ships its own marketplace MCP. For third-party plugin
discovery and install, use the **Anthropic Claude Code Plugin Marketplace**
(`/plugin`) and the **Docker MCP Toolkit** gateway.
