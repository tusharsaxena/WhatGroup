# 02 — Candidates: LibKa0s v1.31.0 → v1.32.0

Sources, in order: `git -C ../LibKa0s log --oneline v1.31.0..v1.32.0` (five commits after
`807925a`, of which `f7d78cd` "v1.32.0: Options 16 and Slash 8 bracket their reset walks" carries the
payload and `4083889` adds `info.profileReset`), the `## v1.32.0` block of the tag's `CHANGELOG.md`,
`docs/api/Options/version-16.15.4.3-docs.md` and `docs/api/Slash/version-8-docs.md`. The rule these
serve is `debug-logging-§10` as of standard v2.44.0 (WowAddonStandards `7883278`).

One change, carried by two files: an optional `bulkBegin` / `bulkEnd` bracket around the library's
three reset walks.

## Class A — reached the addon on the re-vendor alone

| Item | Evidence | Why it needs no host change |
|---|---|---|
| Options 16 bracket around `RestoreDefaults` / `RestoreAllDefaults`, unsupplied | CHANGELOG "A host that supplies neither new field runs the exact walk it ran at v1.31.0, with no `pcall` on the path" | The suite was 589 / 0 / 589 on the new payload before any host edit. |
| Slash 8 bracket around `CliResetAll` | Slash v8 docs `### The two fields` | `/wg resetall` is host-owned (`settings/Slash.lua` `runResetAll`, behind the popup) and never calls `CliResetAll`; the bracket is unreached. |

## Class B — host change required

**B-1. The global reset's one line (the rule, not the library).**

- What: `Helpers.RestoreAllDefaults` (`settings/Schema.lua`) is a wholesale `db:ResetProfile()`
  (options-ui-§12) that overrides the library's member (LIBKA0S-08, WhatGroup#10), so no library
  bracket reaches it. §10 has a profile-wide reset logged ONCE, by the profile-event handler, as
  `[Set] reset profile '<name>' to defaults (N rows)`, replacing `[Reset] active profile reset to
  defaults`.
- N: the rows whose stored value the reset changes (the post-review correction: never the rows in
  scope). Cheap here, because only `RestoreAllDefaults` runs before the reset and the schema is the
  list: compare each profile row with its default, hand the count to the handler.
- Constraint: no `resetProfile` descriptor field, which would route the library's own walk onto the
  path and break `tests/test_settings.lua`'s "refreshes once, not once per row" case. The reset
  stays not-through-the-helper, so "RestoreAllDefaults skips per-row onChange (F3)" stays valid.
- Touches: `settings/Schema.lua`, `core/WhatGroup.lua`, `tests/test_debuglog.lua`.
- Recommendation: **adopt** (owner ruling).

**B-2. Wire the Options bracket defensively.**

- What: supply `bulkBegin` / `bulkEnd`, muting the seam's per-row `[Set]` and logging one
  `[Set] reset <scope>: N rows` line at the outermost close. N is the seam's own tally of changed
  writes, and nothing is logged when `info.profileReset` is set.
- Evidence: Options v16 docs `### Worked example`, `### What the host logs — the contract`.
- Why defensive: `O.RestoreAllDefaults` is overwritten on the instance, and nothing calls
  `O.RestoreDefaults` because the Defaults button goes through the popup. Wiring it means a future
  caller logs one line per act, not one per row.
- Touches: `settings/Schema.lua`, `settings/OptionsSetup.lua`, `tests/test_debuglog.lua`.
- Recommendation: **adopt** (orchestrator: optional, defensive).

## Class C — whole-module adoption

None new. Perf stays declined on structural grounds (LIBKA0S-15, WhatGroup#7); v1.32.0 does not
touch Perf.
