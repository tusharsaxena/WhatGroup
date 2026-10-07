# 04 — Technical design (2026-10-07)

How to close the four roots in `02_DEVIATIONS.md`. All four are small. None touches the settings
schema, SavedVariables or the vendored payloads. The order is in `05_EXECUTION_PLAN.md`.

## §1 — WG-84: route the owed-`Hide` registration through the helper

**Files:** `core/WhatGroup.lua`, `docs/ARCHITECTURE.md`, `tests/test_disabled.lua`, and
`docs/stand-down.md` if it repeats the "never a bare" claim.

**Change.** In `NS.StandDown` (`core/WhatGroup.lua:435-437`), replace

```lua
self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")
```

with

```lua
NS.SafeRegisterEvent(self, "PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded", NS.RejectedEvents)
```

This is the same helper and the same rejected list as `registerFeatureEvents`. `NS.SafeRegisterEvent`
is published on both Core branches (`core/CoreSetup.lua:112`, `:136`), so the degraded load is
covered with no new stub member.

**Why this and not a comment.** `events-frames-taint-§1` has no carve-out for a single registration,
and the hub already promises the helper for every row. A one-line change makes the promise true.
Rewording the hub around the exception would document the gap instead of closing it.

**Test (characterization first, `testing-§13`).** In `tests/test_disabled.lua`, add one case:
- set the kit mock's `__badEvents` to `{ PLAYER_REGEN_ENABLED = true }` after login. The mock raises on an event's first registrant (`tests/_kit/mock_base.lua:721-723`), and `NS.StandDown` has just dropped the other registrant, so the call at `:436` is the first;
- enter combat with a popup that owes a `Hide`;
- disable;
- assert that `NS.StandDown` returns (no raise), that the four feature registrations are gone, and that
  `NS.RejectedEvents` holds the name once.

Add a `-- red under:` line naming the bare `RegisterEvent`.

**Risk.** Nil. On every current client the helper calls the same `RegisterEvent`. The
`OnDisabledCombatEnded` and `NS.StandUp` unregisters at `:444` and `:457` are unchanged.

**Docs.** Leave `docs/ARCHITECTURE.md:184-186` as it is, since the claim becomes true. If
`docs/stand-down.md` names `:436`'s shape, update it in the same commit.

## §2 — WG-71: one span bundle for v1.69.0–v1.70.0

**Files:** a new `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` holding exactly two files, the shape
`audit-review-history` fixes for a lapsed span.

- `01_DELTA.md`, whose line 1 is exactly
  `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`.

  The span list names every tag the bundle covers. The base `v1.68.1` is the tag vendored before the
  span (`2026-10-04-v1.68.1`), and it is not itself covered.

  Then the delta as it landed:
  - `WidgetsLineChart.lua` (v1.69.0, `9677d99`), plus kit 37's `mock_lines.lua` and the
    `mock_base.lua` / `framework.lua` / `README.md` lines;
  - `WidgetsAutocomplete.lua` and a 10-line `WidgetsLineChart.lua` change (v1.70.0, `3fd8a2f`);
  - `LibKa0s.xml` +1 at each tag;
  - `tests/loader.lua` gaining each file in XML order.
- `05_SUMMARY.md`, one line per tag:
  - `v1.69.0 — carried by sweep (9677d99), nothing adopted: no chart surface; Widgets declined (#12)`
  - `v1.70.0 — carried by sweep (3fd8a2f), nothing adopted: no free-text field to autocomplete; Widgets declined (#12)`

**Why a span bundle and not two folders.** Nothing was deliberated at either tag. Two full five-file
bundles would record a decision process that did not happen, and the standard names the span bundle as
the compliant answer.

**Check after.** Re-run `AUDIT.md`'s loop (03 §C.6). `unrecorded:` must print nothing.

**Recurrence.** This is the second lapse after a closure. The two re-vendors were made by a bulk sweep
(`chore: re-vendor …`) and not by `/dev-copilot:wow-revendor-libka0s`, which is what writes the store.
The durable fix belongs to the cross-repo sweep, which should write the bundle. Record that in the
remediation's cross-repo notes. It is not a code change here.

## §3 — WG-77: one doc-sync pass

**Files:** `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/compat-layer.md`, `core/Compat.lua`
(comment only), `.luacheckrc` (comments only), `DEPENDENCIES.md`, `.pkgmeta` (comment only).

| Site | Edit |
|---|---|
| `docs/ARCHITECTURE.md:69`, `:71`, `:76` | "Twenty rows — seventeen profile-scoped, one global and two session-only"; "Twelve are declared in `settings/Schema.lua`"; "**Master controls** (8), **Chat** (9), **Popup** (3)" |
| `docs/ARCHITECTURE.md:155` | "over the twenty rows above" |
| `docs/module-map.md:24` | "Twelve rows are declared here … giving twenty rows … **Chat** (9)" |
| `docs/ARCHITECTURE.md:349` | "`core/Compat.lua` publishes nine addon-specific shims, over the three-or-more threshold" |
| `docs/compat-layer.md:16-17` | "**Nine shims**", quoting the standard's grep verbatim: `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua`. Add a `Role` group of three rows to the table at `:23-30` that points at the section at `:109`, so the table and the count agree. |
| `core/Compat.lua:3` | Replace "Loaded first among the addon files" with the true position, "Loaded in `# Core` before `core/WhatGroup.lua`, which calls `NS.Compat.AddOnLinkType()` at file scope (see WhatGroup.toc)". |
| `.luacheckrc:71` | `tests/loader.lua:129` → `tests/loader.lua:132` |
| `.luacheckrc:102` | "The sibling handler at :707" → "The sibling handler, `OnCombatStateChanged` (:1080)". Prefer naming the function over a bare line, so the next edit above it does not rot the comment. |
| `DEPENDENCIES.md:46` | `tests/loader.lua:134` → `tests/loader.lua:137` |
| `.pkgmeta:20-21` | "Tracked, and they change a download. Two screenshots, about 220K, …". Drop "the only entries", because the logo source lines below also change a download. |
| `docs/module-map.md:130` | "`performance.md` — why Perf is declined (`performance-§12`, ratified) + the committed whole-repo combat-path sweep" |

**Make the counts harder to rot (optional).** `tests/test_doc_structure.lua` already reads tracked
`.md` files. A case asserting that the hub's "N rows" phrase matches `#Settings.Schema`, and that
`ARCHITECTURE.md`'s Compat trigger cell matches the grep, would have caught both. That case is
optional, because `documentation-§5`'s instrument is `/dev-copilot:sync-docs`. If it is added, the
words-to-number parse must be tolerant ("Twenty" / "20").

**Risk.** Comments and docs only. `luacheck` and the suite are unaffected, apart from
`tests/test_lintconfig.lua` if it pins `.luacheckrc` comment text. Re-run both.

## §4 — WG-48: the next release run is the first sighted bundle

No code change. At the next release, run `bash tests/_kit/run-automated-tests.sh` (full, bounded) on
kit 37. That writes the record's first sighted bundle, with `blindFiles` 0 expected per today's
`--no-bundle` run, and a fresh `RESULTS.md`, which also drops the generated `/wow-addon:` name. In
the run's `ANALYSIS.md`:
- record the 1591 → 1792 function jump as **newly measured** by the sighted shadow, not as growth;
- disposition the new band entry `tests/test_libka0s.lua` (1037);
- carry the two existing dispositions, re-measured at 1313 and 1319, both under their 1450 re-check.

This is the release-gate step `automated-tests-§6` already requires. Nothing is owed before the next
release.

## Ordering constraints

- §1 is code. Commit it alone with its test, behind the green gate.
- §2 and §3 are docs. §3's `ARCHITECTURE.md` edits and §1's possible `stand-down.md` edit touch
  neighboring text, so do §1 first.
- §4 waits for the release, and must come after §1–§3 so that the bundle measures the fixed tree.
- After §1–§3, update `CLAUDE.md`'s *"The newest frozen compliance snapshot is
  `docs/audits/2026-09-23/`"* to name this bundle (`/dev-copilot:sync-docs`).
