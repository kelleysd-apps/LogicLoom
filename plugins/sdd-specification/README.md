# sdd-specification

SDD specification lifecycle plugin. It ships **one command**, `/specification`,
backed by **one skill**, `unified-specification`.

## Commands
| Command | Purpose |
|---------|---------|
| `/specification` | Unified specification workflow — spec, plan, and tasks run as three sequential phases |

There is no separate `/specify`, `/plan`, or `/tasks` command. The three were
merged into `/specification`, and their skills merged into
`unified-specification`. Any material that tells you to run `/specify`, `/plan`,
or `/tasks` — or that names an `sdd-specification`, `sdd-planning`, or
`sdd-tasks` skill — is out of date.

## Skills: unified-specification (the only skill in this plugin)
## Agents: (none — the specification lifecycle is skill-based)
