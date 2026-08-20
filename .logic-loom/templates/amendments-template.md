# Project Amendments

**Project**: [PROJECT_NAME]
**Extends**: `.logic-loom/memory/constitution.md` (LogicLoom Constitution)
**Status**: ACTIVE
**Last Updated**: [DATE]

> Copy this template to `.logic-loom/memory/amendments.md` and edit it there.
> That file is **yours** — upstream LogicLoom never ships it, so
> `/update-framework` has nothing to propose against it and your mandates
> survive every framework update. Do **not** put project mandates in
> `constitution.md`; a customized constitution becomes a permanent
> `conflict-review` file on every upstream constitution change.

---

## How this file composes with the Constitution

Effective governance = **the Constitution AND every mandate below**. It is a
conjunction, so this file is meant only ever to *add* conditions.

**Read this first — there is no loader.** Nothing injects this file into an
agent's context. No hook, no preflight, no context module reads it. Nothing
validates a mandate's shape or checks that it is additive. Nothing fails closed:
a project that never reads this file simply gets no mandates, silently. Your
mandates are honoured because `CLAUDE.md` and `AGENTS.md` tell agents to read
`amendments.md` — and only by agents that do. They are **followed** policy, never
**enforced** policy.

The Constitution's floor stays normatively supreme:

- A mandate MAY **tighten** any principle (I–XVI), the immutable three included.
- A mandate MAY govern an area the Constitution is silent on.
- A mandate MUST NOT relax, disable, exempt from, waive, or override a principle
  — outright or by redefining a term, broadening what counts as approval,
  constraining enforcement instead of behaviour, or making compliance vacuous.
- The grammar does not stop you. There is no `Overrides`, `Disables`, `Exempts`,
  `Waives`, or `Relaxes` field, but `Rule` is unrestricted natural language, so a
  weakening rule can be written inside the shape. The missing verb makes
  weakening **conspicuous, not impossible** — the invariant is upheld by whoever
  reads and adjudicates the file, not by its structure.
- If a mandate reads as relaxing a principle by any wording, the **principle
  prevails and the mandate is void in that respect**. A mandate that formally
  tightens but makes a principle impossible to satisfy (an unachievable or
  circular precondition) is void the same way — the test is effect, not form.
- Where a mandate is **ambiguous**, the tightening reading applies. If no
  tightening reading exists, it is void in that respect. Ambiguity never resolves
  toward less obligation.
- Where two mandates conflict, both apply and the **stricter obligation governs**.
  Where they genuinely contradict, both are void in that respect and the
  Constitution's own requirement stands — fix the contradiction here rather than
  resolving it at read time.
- Validity is **per-effect**: a mandate valid in one respect and relaxing in
  another keeps the valid part and loses the other.
- A mandate is policy, not enforcement. It cannot disable or rewire a hook — that
  is a governance-surface edit, gated by `protect-governance-files.sh`, and is
  not an amendment.
- This file is **not** hook-protected by default. Add it to your own protected
  paths if you want it to be; nothing here will warn you if a mandate is weakened
  or deleted.

Named mandates are the only **normative** unit in this file. The header, this
section, and the amendment log are documentation and carry no governance force.
No in-line markers in `constitution.md`, no per-principle override blocks, no
second mechanism.

See `.logic-loom/memory/constitution.md` § *Project Amendments (the fork
extension point)* for the ratified statement of these rules, including the full
precedence order.

---

## Mandates

### Mandate: EXAMPLE-COVERAGE

**Constrains**: II (Test-First)
**Rule**: Coverage minimum is **95%**, not 80%, for anything under `src/billing/`.
**Rationale**: Billing defects are not revertible once money has moved.

### Mandate: EXAMPLE-NEW-AREA

**Constrains**: —
**Rule**: Every outbound HTTP client MUST set an explicit timeout; an unbounded
call is a defect regardless of test status.
**Rationale**: The Constitution is silent on network hygiene; this project has
been bitten by hung upstream calls.

<!--
Delete the two EXAMPLE mandates above and add your own. Shape, verbatim:

### Mandate: <SHORT-NAME>

**Constrains**: <principle numeral(s), or "—" for a new area>
**Rule**: <the additional requirement — MUST / MUST NOT>
**Rationale**: <why this project needs it>
-->

---

## Amendment log

| Date | Mandate | Change |
|------|---------|--------|
| [DATE] | — | File created from `amendments-template.md` |
