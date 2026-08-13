# Known Issues

Active and recently-resolved issues that affect projects built from LogicLoom.
For the full update mechanics see `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`.

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
