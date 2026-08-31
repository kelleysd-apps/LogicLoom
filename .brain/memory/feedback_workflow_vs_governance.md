---
name: Don't conflate workflow scaffolding with constitutional governance
description: When the user proposes changes to "the framework" or "the methodology," distinguish workflow/dev-flow scaffolding (spec→plan→tasks waterfall, validators, refinement loops, plan templates, command surface) from constitutional governance (principles, hooks, git-approval rules, agent-delegation policy, memory infra). Default to workflow-scope only unless the user says otherwise.
type: feedback
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---
When the user said "we need to migrate away from SDD development methodology and tools and move towards vision and plan based engineering," I incorrectly proposed retiring the 16-principle constitution as part of that migration. The user corrected on 2026-05-01: vision.md replaces the SDD flow (waterfall, validators, refinement loops, three-phase gating), NOT the constitutional governance. Governance review is a separate conversation later.

**Why**: Workflow patterns (how features get specified, planned, executed) and governance (rules that apply universally — git approval, test-first, agent delegation) live at different layers. Killing one doesn't imply killing the other. Conflating them risks blowing away durable constraints alongside obsolete ceremony.

**How to apply**: When the user says "migrate from X" or "move away from Y" about a methodology, default to **workflow scaffolding scope only** — commands, templates, validators, phase gates, refinement loops, the surface developers interact with day-to-day. Do NOT fold in: the constitution, governance hooks, memory plugins, principle lists, or compliance enforcement, unless the user explicitly extends scope to them. If unsure, ask before touching anything in `.specify/memory/`, `plugins/sdd-governance/`, or governance hooks.
