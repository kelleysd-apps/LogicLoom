# Known Issues

Active and recently-resolved issues that affect projects built from LogicLoom.
For the full update mechanics see `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`.

---

## Plugins removed upstream stayed in your tree with no notice

**Status:** FIXED in **v7.0.0**.
**Affects:** every project installed before the plugin it held was retired
upstream (any `sdd-*` plugin renamed, folded, or removed before v6.2.0, and
every future retirement going forward).

**Symptom** — `/update-framework` never mentioned that a plugin you were
still holding had been renamed, folded into a domain brief, replaced by a
native Claude Code feature, or removed outright. The directory sat in
`plugins/` indefinitely, invisible to the update flow.

**Cause** — `extract-proposals.sh` only ever diffs upstream's *own* history
against your sync point; a plugin's removal from upstream never produced a
proposal for a customer who already held a copy of it, because there was
nothing left upstream to diff against.

**Fix** — `/update-framework` Step 3b now scans a release-migration registry
against your tree on every run and offers REMOVE / ADOPT-REPLACEMENT /
CONVERT-TO-LOCAL / KEEP-AS-IS per item, with a standing-decisions briefing on
every subsequent run. See `.docs/guides/MIGRATION_GUIDE.md`.

---

## Adopted installs never received updates to files added by `/update-framework`

**Status:** FIXED in **v7.0.0**.
**Affects:** every `npx logicloom init` install (6.6.0+) that accepted a
`clean-add` proposal through `/update-framework`.

**Symptom** — later upstream edits to a file that `/update-framework` had
added to your repository never appeared as a proposal again; the only trace
was a `Suppressed: … not-installed-here` count on stderr.

**Cause** — the adopt receipt's `wrote` list, which the proposal filter
checks, was written only by the `npx logicloom init` installer itself.
Applying an accepted `clean-add` through `/update-framework` wrote the file
to disk but never recorded it in the receipt, so every later upstream change
to that path looked like a file the adopter never owned.

**Fix** — `plugins/loom-maintenance/scripts/record-update-writes.sh` runs
after every update from v7.0.0 on, recording what `/update-framework` just
wrote. `--reconcile` records the past once, for files added before v7.0.0
(the scan proposes running it). See `.docs/guides/MIGRATION_GUIDE.md`.

---

## `/update-framework` fails: `.sdd-sync-ref` is NOT reachable from upstream main

**Status:** FIXED in **v6.4.1** (repair is automatic from that version on).
**Affects:** projects installed from **v6.3.1** and **v6.4.0**.

**Symptom** — `/update-framework` exits 3 and prints:

```
ERROR: .sdd-sync-ref (<sha>) is NOT reachable from upstream main.
An upstream release PR was likely squash/rebase-merged, breaking the single-parent chain.
```

You can never adopt any upstream change.

**Cause** — those two release PRs were squash-merged (branch protection required
linear history, so a merge commit was impossible). The `.sdd-sync-ref` baseline
they shipped points at a commit that only ever existed on the release branch,
never on `main`. `/update-framework` requires the baseline to be an ancestor of
upstream `main`, so the guard fires. The release process has been fixed.

### Recommended fix (keeps the correct diff)

Set `.sdd-sync-ref` to the `main` commit for **your** installed version:

| Your version | Bad SHA (what you have) | Correct SHA (what to write) |
|---|---|---|
| v6.3.1 | `6c4c42067161bf77e3e1af0ff91691319bd2fbdc` | `a2ed86231e097886f58e7fd0e5161648c6e6cfa3` |
| v6.4.0 | `c6d040f36ecb6ef4a5365e9434b4e31dc741e4ac` | `75551c3574eea3f54a92d044da2e1a92b4e9590c` |

```bash
# v6.3.1
echo a2ed86231e097886f58e7fd0e5161648c6e6cfa3 > .sdd-sync-ref
# v6.4.0
echo 75551c3574eea3f54a92d044da2e1a92b4e9590c > .sdd-sync-ref
```

Then re-run `/update-framework` — you get every change made upstream since your
version.

For any other version, find the matching `main` commit yourself:

```bash
git log --oneline refs/loom-upstream/main | grep "Release v<your version>"
```

### Fallback (skips changes — last resort)

```bash
git rev-parse refs/loom-upstream/main > .sdd-sync-ref
```

This re-baselines to today's upstream tip and **adopts nothing**: every upstream
change between your version and now is skipped permanently and will never be
proposed. Only use it if you cannot identify your version's `main` commit.

### Once on v6.4.1+

No action needed. `extract-proposals.sh` recognises both bad SHAs, rewrites
`.sdd-sync-ref` to the correct `main` commit, prints a one-line notice, and
continues — including the changes you had been missing.
