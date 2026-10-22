---
id: amendments-ladder-plus-three
title: Escalation ladder: the auth/payment line is a +3 on top, not a fourth 3
purpose: A fork's escalation ladder that lists "it changes auth, payment, or customer-data logic" as another 3 on the reversibility scale under-scores a reversible auth change; the current form treats it as +3 added on top of whichever reversibility line applies.
touches:
  - .logic-loom/memory/amendments.md
adds: []
requires: []
safety: false
done-when:
  - "no line in amendments.md scores the auth/payment/customer-data case as a bare 3 on the reversibility scale"
  - "every other line of the file is byte-identical to before"
check: amendments-ladder-plus-three.check.sh
pattern: '^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic'
project-data: true
---

## What this note may claim

Only this: your file matches a known defect pattern. It may not claim LogicLoom
shipped the ladder text (it did not), and it may not cite any maintainer's
personal files. It carries the target wording itself:

    Plus, on top of whichever reversibility line applies:
    +3 - it changes auth, payment, or customer-data logic

## Example

Before: the bullet "- 3 = it changes auth, payment, or customer-data logic" sits
as the fourth line under the cost-if-wrong scale, next to the 0, 1 and 3 lines.
The same line may also appear without the bullet, indented, in a restated copy of
the ladder.

After: that line is removed from each place it appears, and these two lines are
inserted after the 0, 1 and 3 lines:

    Plus, on top of whichever reversibility line applies:
    +3 - it changes auth, payment, or customer-data logic

Nothing else in the file changes.

## What a stock file looks like after

The reversibility scale lists 0, 1 and 3 only. The line "Plus, on top of whichever
reversibility line applies:" follows it, then "+3 - it changes auth, payment, or
customer-data logic". No other line of your file is different.
