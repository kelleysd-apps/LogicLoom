---
id: fixture-doc-followup
title: A follow-up page continues the guide
purpose: The fixture guide has a follow-up page, so a reader who finishes the guide has somewhere to go next.
touches:
  - .docs/guides/FIXTURE-2.md
adds:
  - .docs/guides/FIXTURE-2.md
requires:
  - fixture-doc-guidance
safety: false
done-when:
  - ".docs/guides/FIXTURE-2.md exists and has an After the guide section"
check: fixture-doc-followup.check.sh
project-data: false
---

## What changed and why

The guide now has a second page for what to do after the first one. It builds on
the guidance change, so it is offered together with it and is not applied if you
skip that one.

## What a stock file looks like after

`.docs/guides/FIXTURE-2.md` exists, starts with `# Fixture follow-up`, and has a
`## After the guide` section.
