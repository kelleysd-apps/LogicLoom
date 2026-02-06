# Contributing to SDD Plugins

## Creating a Domain Plugin

1. **Use the template**:
   ```bash
   cp -r plugins/sdd-domain-template plugins/sdd-domain-yourname
   ```

2. **Required structure**:
   ```
   sdd-domain-yourname/
   ├── .claude-plugin/plugin.json    # Manifest (required)
   ├── skills/                       # At least 1 skill
   │   └── yourname-operations/
   │       └── SKILL.md
   ├── agents/                       # At least 1 agent
   │   └── yourname-specialist.md
   └── README.md                     # Documentation (required)
   ```

3. **plugin.json requirements**:
   - `name`: Must start with `sdd-domain-`
   - `dependencies`: Must include `sdd-governance`
   - `rl_metrics`: Include with default values
   - `version`: Semantic versioning

4. **Testing requirements**:
   - Skills must load without errors
   - Agents must have valid YAML frontmatter
   - Plugin must coexist with other SDD plugins
   - No hook conflicts with governance plugin

## Submitting to Marketplace

1. Fork `kelleysd-apps/sdd-plugins-marketplace`
2. Add your plugin to `plugins/`
3. Run validation: `./validate-plugin.sh plugins/sdd-domain-yourname`
4. Submit PR with description of use case and testing results
