# Ka0s WhatGroup — Execution Plan (2026-08-05)

Ordered, checkable remediation steps for the deviations in `02_DEVIATIONS.md`, designed in
`04_TECHNICAL_DESIGN.md`. This is the hand-off to a separate remediation engagement — **this audit
changed no addon code.**

Green gate for every step unless stated otherwise: `luacheck .` → 0/0, and
`lua5.1 tests/run.lua` → all passing.

---

## Sprint 0 — the blocking decision (no code)

| # | Step | IDs | Done when |
|---|---|---|---|
| 0.1 | Put the Perf question to the user: **Route A** (wire `LibKa0s-Perf-1.0` with a capture-safe suspend) or **Route B** (amend `performance` upstream to carve out no-hot-path capture addons). Present `docs/pending/LEDGER.md` `LIBKA0S-15` and `02_DEVIATIONS.md` `WG-30` as the input. | WG-30 | A route is chosen and recorded in the ledger with a date |
| 0.2 | Determine whether `docs/automated-tests/RESULTS.md`'s gating blurb (`:9-11`) is written by the vendored `tests/_kit/run-automated-tests.sh` or is addon-authored standing prose. | WG-45 | Answer recorded; if runner-written, a finding is filed for `../LibKa0s` instead of a local edit |

Nothing in Sprint 1–3 is blocked on 0.1; only Sprint 4 is.

---

## Sprint 1 — the correctness fix (one change, highest value)

| # | Step | IDs | Done when |
|---|---|---|---|
| 1.1 | Remove `mock.searchResults[100] = nil` (`tests/test_capture.lua:71`) and `mock.searchResults[10] = nil` (`:271`); add the `-- red under: drop the profile.enabled guard in the "inviteaccepted" branch` comment to each case. | WG-44 | Suite is **red** on exactly those two cases — record the failing output |
| 1.2 | Gate `WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED`'s `"inviteaccepted"` branch (`core/WhatGroup.lua:628`) on `db.profile.enabled`, before the `CaptureGroupInfoFromApplication` call at `:639`. Factor the predicate into one named helper shared with `OnApplyToGroup:488`. | WG-44 | Suite green again at ≥ 422 cases; both cases from 1.1 pass for the right reason |
| 1.3 | Add a case flipping `enabled` **between** apply and accept, asserting no `pendingInfo` and no notify timer. | WG-44 | New case green; regenerate `docs/test-cases.md` and update the README `[tests]` badge in the same change (testing-§5, documentation-§1) |
| 1.4 | Smoke-check in client: disable via the panel, apply + accept a real group, confirm no chat lines and no popup. | WG-44 | `docs/smoke-tests.md` row ticked |

---

## Sprint 2 — docs (no code, no test impact)

| # | Step | IDs | Done when |
|---|---|---|---|
| 2.1 | Add the release-gate sentence + a gates-table row to `docs/testing.md` (after `:221-223` and `:228-229`) and `docs/automated-tests/README.md` (after `:28-30`). Name the checkpoint every time; do not delete the commit-gate wording, which stays correct. | WG-45 | Both docs state: commits → `lint`+`tests`; tag → all four `pass` + `complexity.warnings == 0`, evaluated from `manifest.json`, `skip` ≠ pass |
| 2.2 | Apply 0.2's answer to `docs/automated-tests/RESULTS.md:9-11` — either the local standing-prose edit, or a finding + fix upstream in `../LibKa0s`'s `testkit/` followed by a re-vendor commit here. **Never hand-patch `tests/_kit/`.** | WG-45 | Wording correct, and `tests/_kit/` still byte-identical to the kit |
| 2.3 | Re-mark `lizard` in `DEPENDENCIES.md:92` as required-to-release. | WG-45 | The install section and the release gate agree |
| 2.4 | Move `README.md:81-83` (`## Bundled libraries`) into `docs/ARCHITECTURE.md` `## External dependencies`; keep at most the MIT attribution line in the README. | WG-38 | README is exactly the twelve canonical sections in order |
| 2.5 | Add `## Settings Schema`, `## Slash Commands` (table from `NS.COMMANDS`), `## Message Bus` (a line saying there is none, and why) and `## Known Limitations` to `docs/ARCHITECTURE.md`. | WG-39 | All eight documentation-§3 topics have a home in the file |
| 2.6 | Fix the retired citations: `.luacheckrc:1` `§14` → `lint`; `.pkgmeta:4` `§3.3, §13` → `library-stack-§3, packaging`. | WG-43 | No `§N.M` reference remains anywhere in the repo outside frozen bundles |

---

## Sprint 3 — small code fixes (independent, low risk)

| # | Step | IDs | Done when |
|---|---|---|---|
| 3.1 | `.pkgmeta`: add `- _dev` and `- "*.bak"` to the ignore list. | WG-36 | packaging's four ignore targets are all present |
| 3.2 | Delete the global `print(...)` arm from `pout` in `settings/Panel.lua:22-25` and `settings/Schema.lua:48-51`; call `NS.Print` directly (or leave a **no-op** else-branch). | WG-37 | `grep -rn "^\s*print(" core defaults modules settings` returns only `core/CoreSetup.lua`'s sanctioned library-absent branch |
| 3.3 | Give `NS.FONT_MONO` (`core/WhatGroup.lua:96`) a `Fonts\ARIALN.TTF` fetch-failure fallback resolved at definition time — **or** record the omission as a deliberate deviation with an in-code reason. | WG-42 | debug-logging-§2 satisfied either by the fallback or by the written justification |
| 3.4 | Remove the `InCombatLockdown()` early return at `settings/Panel.lua:268-272` (or replace it with a one-shot `PLAYER_REGEN_ENABLED` re-registration, recorded in-code). Add a `tests/test_panel.lua` case registering under mocked combat and asserting the category exists. | WG-40 | New case green; category present after a simulated combat login |
| 3.5 | In-client smoke test for 3.4: log in during combat, confirm **Ka0s WhatGroup** appears in Settings → AddOns without `/wg config`, then GameMenu → Logout with no `ADDON_ACTION_FORBIDDEN`. | WG-40 | `docs/smoke-tests.md` taint row ticked |

---

## Sprint 4 — the Perf cluster (blocked on 0.1)

### If Route A (wire it)

| # | Step | IDs |
|---|---|---|
| 4A.1 | New `core/PerfSetup.lua`: silent-guarded `LibStub("LibKa0s-Perf-1.0", true)`, descriptor, and a stub answering **every** member the addon calls. TOC-insert in `# Core` after `core/CoreSetup.lua`, before `core/WhatGroup.lua`. | WG-30 |
| 4A.2 | Declare buckets on the capture path, the roster handler and the notify build; implement `suspend`/`resume` so suspend pauses **display**, never capture, with that intent commented at the implementation. | WG-30 |
| 4A.3 | `WhatGroup.toc:7` → `## SavedVariables: WhatGroupDB, WhatGroupPerfDB`. | WG-31 |
| 4A.4 | Add the `perf` row to `NS.COMMANDS` (`settings/Slash.lua:43-67`), dispatching into the library's command entry point and printing through `NS.Print`; add the row to the README and `docs/ARCHITECTURE.md` command tables in the same change. | WG-32 |
| 4A.5 | `.luacheckrc`: `debugprofilestop` → `read_globals`, `WhatGroupPerfDB` → `globals`. | WG-35 |
| 4A.6 | `tests/perf.lua` with, at minimum, the **zero-overhead scenario** performance-§2 names as required evidence; assert only deterministic quantities; keep it outside the green gate. | WG-34 |
| 4A.7 | Write `docs/performance.md` and `docs/perf-runs/README.md`. | WG-33 |
| 4A.8 | Run a full four-suite bundle; confirm `perf` now records `pass` rather than `skip`. | WG-30–35 |

### If Route B (amend the standard)

| # | Step | IDs |
|---|---|---|
| 4B.1 | Open the `performance` amendment upstream in `WowAddonStandards` (carve-out for addons with no hot path **and** a capture-style suspend contract). Do **not** edit this repo for it. | WG-30 |
| 4B.2 | On acceptance, write the one-screen `docs/performance.md` (what this addon brackets, and why nothing) and `docs/perf-runs/README.md` (the in-game half, empty but documented). | WG-33 |
| 4B.3 | Record `WG-30`, `WG-31`, `WG-32`, `WG-34`, `WG-35` as closed-by-standard-change in the ledger, citing the new standard version. | WG-30–35 |

---

## Sprint 5 — verify and record

| # | Step | IDs | Done when |
|---|---|---|---|
| 5.1 | Run **both** Ka0s-owned vendor diffs, which this audit could not: `diff -r ../LibKa0s/LibKa0s ./libs/LibKa0s` and `diff -r ../LibKa0s/testkit ./tests/_kit`. Both **MUST** be empty. A non-empty diff is an anti-pattern #45 finding; a file missing on the addon side is #48. | (closes the `03_EVIDENCE.md` §B1 gap) | Both diffs empty and the output recorded |
| 5.2 | Full four-suite run: `tests/_kit/run-automated-tests.sh`. | all | New frozen bundle + `ANALYSIS.md`; `RESULTS.md` gains one row; watch list still reads "None." or names what newly crossed with a disposition |
| 5.3 | Re-run `/wow-addon:standards-audit` against v2.21.0 (or later) and confirm the closed IDs stay closed. | all | New dated bundle; `WG-` prefix and every surviving ID preserved |
| 5.4 | Only then, if a release is cut: verify the release gate from the run's `manifest.json` — all four suites `pass` and `suites.complexity.warnings == 0`. A `perf` skip is permitted **only** on the "ships no `tests/perf.lua`" exception, and **MUST** be stated in the release notes. | WG-45 | Gate evaluated and the outcome written down before the tag |
</content>
