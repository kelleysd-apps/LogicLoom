---
name: feedback-improve-harness-not-user-skills
description: "When asked to enhance the LogicLoom harness (esp. to match powerful harnesses), improve the harness MACHINERY ITSELF — not by adding user-addable skills/plugins/commands."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f04e87cb-d270-41ef-b5c2-61b93a6da9f0
---

When the user asks to "enhance/improve the harness" — including "make it more like powerful harnesses (Hermes/OpenClaw/etc.)" — the target is **the harness machinery itself**: how it orchestrates, governs, grounds context, manages memory, and behaves for *every* development task. The target is NOT new skills, plugins, or slash-commands.

**Why:** Skills/tools/commands are user-space — "skills and tools that any user can add" (user's exact words, 2026-06-16). A plugin of `/commands` rides ON the harness; it does not improve the harness. The user explicitly cut a freshly-built `loom-codeintel` plugin (verify-and-fix, and questioned grounded-retrieval) for being exactly this wrong category — twice correcting scope drift toward additive skills.

**How to apply:** Frame enhancements as changes to EXISTING harness systems — the swarm/team orchestration packs, governance hooks, the preflight injection, context-cap/compaction behavior, loom-memory + `/retro` learning, domain briefs. Because these edit existing systems, the original-goal constraint applies: **propose with justification first, implement on approval** (never silently edit the framework). Always distinguish a "harness behavior change for all dev work" (right) from "a new invokable tool" (wrong). Also rejected this effort: execution sandboxing (a terminal-native dev harness must not cage the model's execution) and governance/workflow-ops add-ons (risk-tier classifier, cost-preview) as not-development-focused. Related: [[feedback_workflow_vs_governance]].
