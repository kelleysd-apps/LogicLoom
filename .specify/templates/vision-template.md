<!--
TEMPLATE — DO NOT EDIT IN PLACE.
Copy this file to `features/<feature-name>/vision.md` and fill in.

Philosophy (per Anthropic's harness-design article): a vision declares
WHAT we want to achieve — it deliberately leaves room for the agent to
reason about HOW during exploration, research, and PRD synthesis.
Tight specs cascade upstream errors; broad visions don't.

Keep this document short. If you find yourself writing acceptance
criteria or schemas, stop — that belongs in the PRD or plan.
-->

# Vision: [FEATURE NAME]

**Feature**: `[feature-name]`
**Created**: [DATE]
**Owner**: [NAME]
**Status**: Draft

---

## North Star

[One sentence. What is the single outcome this feature exists to produce?]

## Who this is for

[Concrete user or persona — name a role, not "users". Include the situation they're in when this matters.]

## What success looks like

**Qualitative**:
- [What the user notices / can now do / no longer struggles with]
- [What the team / product gains]

**Quantitative** *(only if tractable at this stage — otherwise leave blank)*:
- [Metric + target, e.g., "p95 latency under 200ms", "30% reduction in X"]

## Design language *(omit if not applicable)*

[Visual / UX feel in one or two sentences. Reference existing surfaces or precedents rather than re-deriving. e.g., "Quiet, dense, terminal-adjacent — matches the existing CLI aesthetic."]

## What this is NOT

- [Explicit non-goal — something a reasonable person might assume is in scope but isn't]
- [Another non-goal]
- [Boundary against an adjacent feature]

## Open questions

[Acknowledged unknowns to resolve during exploration/research. Don't try to answer them here.]

- [Question]
- [Question]

---

*Next step after vision is locked: `/swarm explore <topic>` and/or `/research <question>` to fill the unknowns, then `/create-prd <feature-name>` to synthesize the broad PRD.*
