---
name: promotion-lifecycle
description: The three-command promotion lifecycle — /promote-dev, /promote-staging, /promote-prod. How the gate resolves confirmation strength, enforces promotion order, and checks the rehearsal contract; and the hard boundary between gating and deploying.
---

# Promotion Lifecycle

Three commands that give a project **LogicLoom's working development
lifecycle** as guidance it can adopt and then change:

```
feature branch / worktree
    ↓  /promote-dev        plain yes/no, skippable with --yes
integration branch → dev
    ↓  /promote-staging    plain yes/no, skippable with --yes
rehearsal environment      → writes the rehearsal attestation
    ↓  /promote-prod       TYPED EXACT PHRASE — no flag bypasses it
production
```

Everything about the ladder is **declared, not hardcoded**. A project that wants
a different shape changes `.logic-loom/config/environments.conf`, not these
commands.

---

## The hard boundary — the thing to get right

These commands **orchestrate and gate. They do not deploy.**

They contain no cloud API call, no CI-provider call, no deploy command, no
migration runner, no seed, no teardown, no secret handling, and no rollback
mechanic — and they never will. Every such step is a call out to the `deploy`
seam declared in `environments.conf`: a **product-owned** script the harness
names and never inspects (`environment-promotion-policy.md` § 8, § 10).

If a request pushes toward putting deploy logic in here, say no and point at the
seam. The seam exists precisely so the harness never has to have an opinion
about a vendor.

The gate also **runs no git**, ever. Principle VI: any merge, tag, or push a
promotion needs is surfaced for the user's approval individually.

---

## The surface

| Piece | What it is |
|---|---|
| `plugins/loom-maintenance/commands/promote-dev.md` | Command — lowest rung |
| `plugins/loom-maintenance/commands/promote-staging.md` | Command — rehearsal rung |
| `plugins/loom-maintenance/commands/promote-prod.md` | Command — production rung |
| `.logic-loom/scripts/bash/promote-gate.sh` | The gate. Read-only except for nothing; evaluates, confirms, prints the seam command |
| `.logic-loom/scripts/bash/promotion-record.sh` | Appends one outcome to the promotion ledger — the only thing these commands write |
| `.logic-loom/templates/environment-promotion/rehearsal-attestation.conf.tmpl` | The attestation contract the product's rehearsal seam fills in |

State lives under `$LOOM_PROMOTION_STATE_DIR`, else `.logic-loom/state/`:
`promotion-ledger.tsv` and `rehearsal-<env>.conf`.

---

## How `confirm` resolves

**The declaration is the source of truth.** The per-command default is a
*fallback* for an environment that declares no `confirm`. That is what makes the
escalating ladder configurable rather than hardcoded — which is the whole point.

```
1. environments.conf: `confirm` in the target environment's block   ← wins
2. the command's --default-confirm  (dev: prompt, staging: prompt,
                                     prod: typed:PROMOTE TO PRODUCTION)
3. none
```

| Resolved value | Behaviour |
|---|---|
| `none` | No interactive step. |
| `prompt` | Yes/no. `--yes` skips it. Closed stdin with no `--yes` **refuses** rather than assuming yes. |
| `typed:<PHRASE>` | The operator types `<PHRASE>` exactly. **`--yes` is ignored and says so.** Empty input refuses. A mismatch refuses. One attempt. |

Two deliberate consequences:

- **A project can raise the bar.** Declaring `confirm = typed:SHIP DEV` on dev
  makes `/promote-dev` demand a typed phrase, and `--yes` stops working there.
- **A project can lower it.** Declaring `confirm = prompt` on production is
  honoured — but the gate prints a loud note saying the declaration is weaker
  than the stage's default. Honouring the declaration silently is how a
  production release quietly becomes a keystroke.

`validate-environments.sh` already refuses `confirm = typed:…` alongside
`requires_approval = false`, and refuses `typed:` with an empty phrase. The gate
runs the validator first and will not promote against an invalid declaration.

---

## How promotion order is enforced

From `promotes_from`, against the ledger. To promote into `E`:

- `E` declares no `promotes_from` → start of chain, nothing to check.
- `E` declares `promotes_from = P` → there must be a **success** line for `P` in
  `promotion-ledger.tsv`.
- Otherwise **refused**, naming `P`, the ledger path, the `promotion-record.sh`
  invocation that would fix it, and the override.

Override: `--allow-out-of-order "<reason>"`. A **non-empty reason is required**
and is echoed into the verdict. An unexplained override is not an override.

Never reach for it on the user's behalf.

---

## The rehearsal contract (`--require-rehearsal`, used by `/promote-prod`)

Policy § 6.1 requires all three: the rehearsal **succeeded**, is **within a
staleness bound**, and rehearsed a commit that is an **ancestor** of what is
being promoted.

The harness runs no git and calls no CI API. So the third condition is a
**declared contract the product's seam reports** — and the split is stated
rather than blurred:

**Verified here:** the attestation exists, is readable, `status = success`,
`completed_at` parses and is inside the bound, `rehearsed_commit` is present,
and the promoted commit is either that commit or listed in `covers_commits`.

**Taken on trust:** that the rehearsal ran, that it passed, and that
`rehearsed_commit` really is an ancestor.

**The § 6.4 trap, which the seam owns:** a staging branch rebuilt from
production and re-merged means the commit actually rehearsed is the merge's
**second parent**, not the merge head. A seam writing the merge head writes a
plausible wrong answer, and this gate will accept it. A seam that cannot
identify the rehearsed commit unambiguously must write `status = failure`.

Override: `--allow-stale-rehearsal "<reason>"` — **the age bound alone**. It
cannot override an absent, failed, or unevaluable rehearsal, and it cannot touch
the confirmation. That narrowness is § 4.3's rule about where an override may
live.

---

## Fail closed, with a typed reason (§ 4.2)

Every refusal prints **why** it could not proceed and **which override exists**,
if one does. The cases:

| Situation | Verdict |
|---|---|
| No `environments.conf` | **exit 3** — not a failure. "Nothing declared", point at `/scaffold-environments`. |
| Declaration present but all blocks commented out | **exit 3**, same message. |
| Declaration unreadable | refused |
| Declaration invalid (per the validator) | refused, with the validator's own output |
| Target environment not declared | refused, listing what is declared |
| `promotes_from` names an undeclared environment | refused |
| Predecessor not promoted | refused — `--allow-out-of-order "<reason>"` |
| Ledger unreadable | refused |
| Rehearsal attestation absent | refused — **no override** |
| Rehearsal `status != success` | refused — **no override** |
| `completed_at` missing or unparseable | refused — **no override** |
| Rehearsal stale | refused — `--allow-stale-rehearsal "<reason>"` |
| No `--commit` under `--require-rehearsal` | refused — **no override** |
| Commit not covered by the attestation | refused — **no override** |
| No `deploy` declared | refused, with the exact line to add |
| Deploy seam missing / unreadable / non-executable | refused, **printing the path it looked for** |
| Confirmation not given / wrong / empty | refused |

Exit codes: `0` cleared · `1` refused · `2` usage · `3` nothing declared.

---

## Agent conduct

1. **Relay a refusal verbatim.** Its reason and its override line are the
   product. Do not paraphrase them into something softer.
2. **Never apply an override the user did not ask for**, and never re-run a
   refused gate hoping for a different answer.
3. **Never run the deploy seam.** Print the command; the user runs it.
4. **Never run git.** Surface every mutation for approval (Principle VI).
5. **Record only what was reported.** `promotion-record.sh` writes an
   attestation, not an observation — the harness did not watch the deploy.
   Recording an unverified success falsifies the next rung's gate.
6. **Do not report "deployed" as "verified."** A green rehearsal proves
   migrations applied, the authorization invariant held, functions answered a
   health check, and the artifact built. It does not prove any user flow works
   (§ 6.2, § 6.3).
7. **On exit 3, do not improvise a topology.** Point at
   `/scaffold-environments`. One environment — or none — is a complete answer
   (Principle V).

---

## Reference

- Methodology: `.docs/policies/environment-promotion-policy.md` (§ 4.1–4.7, § 5, § 6, § 12)
- Declaration schema: `.logic-loom/config/environments.conf`, `.docs/policies/deployment-policy.md`
- Scaffolding: `/scaffold-environments`
- Contract test: `tests/contract/test_promotion_lifecycle.sh`
