# Project domain-brief overlays

The seven shipped domain briefs (`plugins/loom-governance/domain-briefs/`) are
**stack-neutral** (LOOM-0053): they describe what each domain owns
conceptually — component architecture, API design, the test pyramid, and so
on — without naming a framework, a test runner, or a file layout. That is
deliberate: the same shipped brief has to be true for a web app, a mobile app,
a CLI, and an edge-function service alike.

A brief that stays true everywhere can't tell a worker *this project's*
frameworks or *this project's* file layout — that's what this directory is for.

## What an overlay is

An overlay is a plain markdown file at:

    .logic-loom/domain-briefs/<domain>.md

one per domain (`frontend.md`, `backend.md`, `database.md`, `testing.md`,
`devops.md`, `performance.md`, `security.md`, or a domain of your own). It has
no required format — no `## Task Brief` heading, no schema — because it is
**your** file, not ours: `get_domain_brief` emits it verbatim.

## How it's used

`get_domain_brief <domain>` (`.logic-loom/scripts/bash/common.sh`) is the
single place swarm/team workers get their domain guidance from. When an
overlay exists for a domain, its content is appended **after** the shipped
brief, so the project's own words come last — the most recently read guidance
wins when the two ever appear to disagree. When no overlay exists, output is
unchanged from the shipped brief alone.

You can also add an overlay for a domain the shipped registry doesn't cover
at all (there is no `plugins/loom-governance/domain-briefs/<domain>.md`) — the
overlay is still emitted on its own.

## Why an overlay and not just editing the shipped brief

`plugins/loom-governance/domain-briefs/*.md` ships with the framework and is
refreshed by `/update-framework`. Editing those files directly means your
project's stack description gets silently overwritten on the next upgrade.
This directory is **project-owned** — nothing under `.logic-loom/domain-briefs/`
is ever written by `/update-framework` — so what you write here survives every
upgrade.

## Worked example: a non-web stack

Say the project is a React Native + Expo mobile app, with its backend running
as Supabase Edge Functions (Deno). None of the shipped frontend/backend briefs'
former framework or path assumptions would have fit — that's the exact gap
this feature closes.

`.logic-loom/domain-briefs/frontend.md`:

```markdown
## This project

- Framework: React Native + Expo (Expo Router for navigation)
- Language: TypeScript
- Styling: NativeWind (Tailwind-style utility classes for RN)
- State: Zustand for app state, TanStack Query for server state
- Testing: Jest + React Native Testing Library for unit/component tests,
  Maestro for end-to-end flows
- File ownership: `app/**` (routes/screens), `components/**`, `hooks/**`,
  `stores/**`
```

`.logic-loom/domain-briefs/backend.md`:

```markdown
## This project

- Runtime: Supabase Edge Functions (Deno), not a long-running Node server
- Language: TypeScript, Deno-native imports (no `npm install` — use
  `npm:`/`jsr:` specifiers or the Deno standard library)
- Data access: Supabase client (`@supabase/supabase-js`) against Postgres,
  with row-level security as the primary authorization mechanism
- Testing: `deno test` for unit tests; integration tests run against a local
  Supabase stack (`supabase start`)
- File ownership: `supabase/functions/**` (one directory per function),
  `supabase/migrations/**`
```

A worker reading `frontend` guidance now gets the shipped conceptual brief
(component architecture, accessibility, testing layers, quality bar) followed
by this project's actual framework, styling system, and file layout — instead
of being primed to reach for React DOM, Jest configs assuming a `src/`
directory, or a Node server that doesn't exist in this stack.

## Files here

- `<domain>.md` — one overlay per domain, created by the project as needed.
  None ship by default.
- `.gitkeep` — keeps this directory present (and this README readable) in a
  fresh clone even before any overlay is written.
