# Initializing LogicLoom for your project

You are looking at the **LogicLoom framework template**. `README.md` describes the
framework itself. To turn this into your own project:

```bash
bash init-project.sh
```

That script:
- archives the framework `README.md` → `FRAMEWORK_README.md`,
- scaffolds a project-specific `README.md`,
- verifies prerequisites (Node.js, Git, Claude Code) and wires `.claude/` hooks,
- syncs plugin commands into `.claude/commands/`.

Then open Claude Code in the repo and pick a workflow pack (none is privileged):

- **Swarm** (exploratory): `/swarm explore` → `/create-prd` → plan mode →
  `/plan-review` → `/swarm implement` → `/review-team` → `/git-push`
- **SDD waterfall** (well-specified): `/specification` → `/build-team` /
  `/fullstack-team` → `/finalize`

See `START_HERE.md` for the full walkthrough and `CLAUDE.md` for governance.

**Framework**: LogicLoom v6.2.0 · **Constitution**: v3.2.0 (16 principles) ·
**Architecture**: governance core + interchangeable workflow packs
