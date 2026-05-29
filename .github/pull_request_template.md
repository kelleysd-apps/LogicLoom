## Summary

<!-- Brief description of changes -->

## Plugin Impact

<!-- Which plugins are affected? -->

- [ ] loom-governance (🔒 protected)
- [ ] sdd-specification
- [ ] loom-git
- [ ] sdd-debug
- [ ] loom-creation
- [ ] loom-orchestrator
- [ ] Domain plugin(s): _____________
- [ ] No plugin changes

## Constitutional Compliance

<!-- All PRs must pass constitutional check -->

- [ ] Principle II (Test-First): Tests written and passing
- [ ] Principle III (Contract-First): Contracts defined before implementation
- [ ] Principle VI (Git Approval): All git operations approved by user
- [ ] Principle IX (Dependencies): All dependencies declared and version-pinned
- [ ] Principle XVI (Plugin-First): Changes organized as plugin components

## Checklist

- [ ] Contract tests pass (`bash tests/contract/plugins/test_plugin_lifecycle.sh`)
- [ ] Plugin manifests valid JSON with required fields
- [ ] RL metrics baseline included in new plugins
- [ ] Deprecation headers added to superseded monolithic files
- [ ] CLAUDE.md and AGENTS.md updated if commands/agents changed
- [ ] No secrets or credentials committed

## Test Plan

<!-- How was this tested? -->

- [ ] Contract tests: `bash tests/contract/plugins/test_plugin_lifecycle.sh`
- [ ] Constitutional check: `.logic-loom/scripts/bash/constitutional-check.sh`
- [ ] Manual validation: _______________

---

🤖 Generated with [Claude Code](https://claude.ai/code)
