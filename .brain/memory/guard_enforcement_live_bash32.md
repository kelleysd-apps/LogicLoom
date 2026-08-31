---
name: guard-enforcement-live-bash32
description: Dangerous-command guard now ACTUALLY enforces on stock macOS bash 3.2 — and pattern-matches whole command strings, so prose quoting dangerous examples gets blocked.
metadata:
  type: project
---

As of 2026-08-04 (PR #62, merged to `dev-main` as `d1226b8`), `guard-dangerous-commands.sh`
**enforces** rather than fails open. Two things changed: `logging.sh` / `policy.sh`
became bash 3.2 compatible (macOS ships 3.2 as `/bin/bash`), and the explicit
`BASH_VERSINFO<4` gate was removed. This machine has **no bash 4+ installed at all**,
so the re-exec shim from PR #61 was a no-op here — the policy had never once run.

**Why:** the bash<4 fail-open was a documented governance residual in
`.docs/architecture/governance-threat-model.md`. It is now closed, not merely
mitigated by telling users to install bash. Remaining fail-open is narrow: missing
or unsourceable policy file, or absent `validate_tool_call`.

**How to apply:** the guard matches against the **entire Bash command string**, not
just the command position. So a command that merely *quotes* a dangerous example —
a commit message, a PR body, a doc edit, a test fixture — will be blocked. This bit
during the very PR that enabled it: `gh pr create --body "...rm -rf /..."` was denied
because a line ended in that pattern. **Workaround: write the text to a file and pass
`--body-file` / `-F -`**, since file contents are not inspected — only the command
line is. A future refinement would scope matching to the command position.

Related: [[architecture_v6_2_native_primitives]] (floor hardening),
[[surface_portability_corrected_strategy]] (which listed "bash<4 guard-dangerous
fails open" as an open gap — **now resolved**).
