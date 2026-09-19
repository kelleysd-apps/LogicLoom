# Mandate: ESCALATION-RUNG-REQUIRED

Constrains: how work is scored before it starts and before it is called done.
Rule: restates the escalation ladder from the harness's own operating
principles, unmodified in substance.
Rationale: keep the fork's copy in sync without forcing every reader back to
the master doc.

## Escalation

Two questions. Ask them before you commit to an approach, and again before you
call the work done.

Cost if this turns out wrong:
- 0 = nothing leaves the working tree
- 1 = a revert fixes it
- 3 = it leaves something a revert cannot take back, such as mail already
  sent, a charge, a published package, a migrated table, a rotated
  credential, or anything already serving production
- 3 = it changes auth, payment, or customer-data logic

Width:
- 0 = one file, or one obvious place
- 1 = several files that move together
- 2 = many independent places, or you cannot yet list them

The same ladder, restated without list bullets (a fork that copied the
master doc's indented form instead of the bulleted form):
  0 = nothing leaves the working tree
  1 = a revert fixes it
  3 = it leaves something a revert can't take back
  3 = it changes auth, payment, or customer-data logic
