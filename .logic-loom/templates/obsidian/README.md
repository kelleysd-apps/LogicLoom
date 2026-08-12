# Open this project as an Obsidian vault (optional, human-only)

The project's docs are *already* Obsidian-shaped: `.docs/`, `features/`, `specs/`,
and `.logic-loom/memory/` are folders of markdown with `[[wikilinks]]`. A vault is
"a folder and its subfolders" — so opening the repo root (or `.docs/`) as a vault
yields a working graph view with **zero conversion**.

**To open:**
1. Obsidian → *Open folder as vault* → point at the **repo root** (whole project)
   or **`.docs/`** (docs-only, less noise).
2. Copy this dir's `graph.json` into the vault's `.obsidian/` folder so the graph
   view opens sane (markdown-scoped search, tags/attachments off, folder colors)
   with no tuning. `.obsidian/` is created on first open.

**Agents do NOT need Obsidian.** Subagents read these files directly with
Read/Grep — Obsidian is a *human* lens for exploring links, backlinks, and the
graph view. No MCP, no running app, nothing to install for the agent path.

**Personal-vault tandem (kept separate, never merged).** Your personal Obsidian
vault (second brain / saved links) lives *outside* any repo and is never
templated in. Run it side-by-side with the project vault — Obsidian opens
multiple vaults at once and their links don't cross. The agent consults the
project graph (repo context) and, if you've wired it, your personal vault's
CLI/MCP (personal context) as two independent queries. Keeping the stores
separate is what makes the project graph portable.

## Graph metadata (optional)

Specs and ADRs may declare which code they govern via a `covers:` frontmatter key
so the code↔docs bridge can link a doc node to the files/dirs it describes:

```yaml
---
title: Auth cookie rotation
covers: [src/auth/login.ts, plugins/loom-git/]
---
```

- Paths are repo-relative; a trailing `/` means "the whole directory."
- New docs should also prefer `[[wikilinks]]` so the Obsidian graph is meaningful.
- A **dangling** `covers:` entry (points at a deleted/moved path) makes the linter
  **warn, never block** — fail-open, like the rest of the governance floor.

See `covers-convention.md` in this dir for the full authoring shape.
