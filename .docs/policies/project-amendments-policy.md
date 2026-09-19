# Project Amendments — Doctrine and Rationale

`.logic-loom/memory/constitution.md` § *Project Amendments* is the normative
statement. This file is its doctrine and rationale.

---

**Followed, not enforced — and nothing loads it. That is settled, not pending.**
No hook, preflight, or context module reads `amendments.md`; nothing validates a
mandate; nothing fails closed. A fork that does not read the file gets no
mandates and gets no warning. Mandates work only because `CLAUDE.md` and
`AGENTS.md` tell agents to read them. Read `.logic-loom/memory/amendments.md`
when it exists and treat its mandates as binding alongside the principles.

Wiring `amendments.md` into `governance-preflight.sh` was **considered and
declined** (2026-08-24) — there is no loader coming, so do not read the absence
as unfinished work. A loader would make mandates *look* enforced without making
them enforced: the hook floor would still never consult a mandate, so the only
thing gained is a stronger impression of enforcement than the mechanism can
support. What a fork gets is a file upstream never overwrites, a mandate grammar,
and composition rules binding on any agent that reads them. What it does not get
is injection, validation, a warning, or any change in hook behaviour.

The only normative unit is a **named mandate**: `### Mandate: <NAME>` with
`Constrains:` / `Rule:` / `Rationale:`. There is no second surface — no in-line
project markers in the constitution, no per-principle override blocks.

Composition is a conjunction: **effective governance = constitution AND every
mandate**. The constitutional floor stays normatively supreme; mandates are
intended to add obligations only, and any relaxing effect is invalid. That
invariant is **adjudicated, not structural**: the grammar has no `Overrides` /
`Waives` field, but `Rule` is unrestricted natural language, so a mandate *can*
weaken a principle semantically — by redefinition, by broadening what counts as
approval, by constraining enforcement rather than behaviour, or by making
compliance vacuous. The missing verb makes weakening conspicuous, not impossible.

Adjudication defaults, all failing toward the floor: relaxing wording is **void in
that respect**; an ambiguous mandate is read under its tightening interpretation
(and is void if it has none); a formal "tightening" that makes a principle
impossible to satisfy is void the same way; conflicting mandates compose to the
stricter obligation, and genuinely contradicting ones are both void in that
respect; validity is assessed per-effect, so a partly-valid mandate keeps only its
valid part. `VISION.md` sets direction and never relaxes a mandate. Mandates are
policy, not enforcement: they cannot touch a hook. Full statement including the
precedence order: `.logic-loom/memory/constitution.md` § *Project Amendments*.
