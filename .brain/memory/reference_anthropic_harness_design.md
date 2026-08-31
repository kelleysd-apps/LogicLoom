---
name: Anthropic harness-design article (load-bearing reference)
description: Anthropic engineering article on harness design for long-running coding agents. Load-bearing reference for the SDD → vision/plan migration. Key thesis is that scaffolding encodes assumptions about model weakness and should be stress-tested as models improve.
type: reference
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---
# Reference: Anthropic — Harness Design for Long-Running Applications

**URL**: https://www.anthropic.com/engineering/harness-design-long-running-apps

## Why this is load-bearing

This is the conceptual foundation for the SDD → vision/plan migration decided 2026-05-01. When questions come up about "do we need component X," go back to this article's stress-test heuristic.

## Key takeaways the migration relies on

1. **Three-agent pattern**: planner → generator → evaluator, with files as handoff artifacts between them.
2. **High-level specs over granular ones**: "if the planner tried to specify granular technical details upfront and got something wrong, the errors in the spec would cascade." Argues against the SDD-style 0.90-completeness spec.
3. **Context resets > compaction** for "context anxiety" — agents prematurely wrapping up as they near perceived limits. Resets need a good handoff artifact.
4. **Don't trust self-evaluation**: agents praise their own work. External evaluator agent required for honest grading.
5. **Concrete grading rubrics** for subjective domains (e.g., frontend design quality / originality / craft / functionality).
6. **Sprint contracts became optional** as Opus 4.6 improved — explicit demonstration that scaffolding sheds as capability grows.
7. **Cost data**: solo agent $9 / 20min vs full harness $200 / 6hr (20× more expensive but produces working product). Simplified V2 harness $124.70 / 3h50m.

## The stress-test heuristic (use this when deciding what to keep)

> "Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing."

When evaluating any current SDD component, ask: what model weakness does this assume, and is that weakness still real for Opus 4.7?

## When to re-read

Before designing any new component of the lightweight framework. Especially relevant for: (a) the evaluator agent design, (b) deciding what handoff artifacts go between vision → plan → execution, (c) deciding when sprint-style decomposition adds value vs noise.
