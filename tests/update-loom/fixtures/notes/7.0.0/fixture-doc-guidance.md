---
id: fixture-doc-guidance
title: The guide tells you to run /update-loom
purpose: The fixture guide tells a reader to run /update-loom to take improvements, instead of describing the old update steps.
touches:
  - .docs/guides/FIXTURE.md
adds: []
requires: []
safety: false
done-when:
  - ".docs/guides/FIXTURE.md contains the sentence Run /update-loom to take improvements."
check: fixture-doc-guidance.check.sh
project-data: false
---

## What changed and why

The guide described the old way to update. It now points at the new command, so a
reader who opens the guide is sent to the right place.

## What a stock file looks like after

The "Running updates" section of `.docs/guides/FIXTURE.md` reads: "Run
/update-loom to take improvements." followed by one sentence about how each
improvement arrives. The other sections are unchanged.
