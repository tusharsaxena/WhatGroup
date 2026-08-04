# Ka0s WhatGroup — Final Summary (2026-08-03)

> **Status: forward-looking.** This document is written under the assumption that every change in
> `02_PROPOSED_CHANGES.md` has been implemented per `04_EXECUTION_PLAN.md` and that every check in
> `03_SMOKE_TESTS.md` has passed. Until the sign-off table in `03_SMOKE_TESTS.md` is filled in, treat
> this as the intended shipping record rather than the achieved one.

## Headline

This cycle closed one real functional bug and a set of small drifts left over from the LibKa0s
adoption. The bug: a group-info popup requested while in combat could resurrect a capture that
leaving the group had already discarded — and because the same discard resets the "already
announced" guard, the **next** group you joined could be announced with the **previous** group's
title, leader, instance and teleport spell. Alongside it, the migration seam stopped stamping the
saved-variables schema version forward without actually migrating anything, the last stray
deprecated-API detection moved behind `Compat`, the popup stopped re-deriving a label the chat
notification already computes, and a handful of orphaned strings, aliases and lint declarations were
removed. No user-facing feature changed; the addon simply tells the truth in more places.

## Counts

`Critical fixed: 0, High fixed: 1, Medium fixed: 6, Low fixed: 6`

- **Critical:** none were found.
- **Deferred:** none. F-005 (teleport-anchor nil guard) was implemented as hardening even though the
  failure could not be reproduced in-client — the fallback costs two lines and removes an
  unverifiable assumption from the addon's primary surface.
- **Not in scope, by rule:** no `[upstream]` findings were raised. `libs/LibKa0s/` and `tests/_kit/`
  were verified byte-identical to their source repo and were not edited.

## Changes by theme

### T-1 — "The capture you are shown is the capture you joined"

- **What changed.** Capture state now carries a wipe generation. The combat-deferred popup records
  the generation it captured at and restores `pendingInfo` only if nothing invalidated it in the
  meantime; applications that end without a join (declined, cancelled, timed out) are dropped from
  the session table instead of accumulating; and `shortName` is seeded in the capture shape rather
  than appearing only when activity info resolves.
- **Why it mattered.** The addon's entire promise is "these are the details of the group you just
  joined". The deferral path could break that promise silently, and only in the combat-plus-leave
  sequence that a player is least likely to reproduce on demand. The other two items were latent:
  an unbounded session accumulation and a nil field two call sites survived by operator-precedence
  luck.
- **Findings covered:** F-001, F-006, F-009. **Changes implemented:** C-01, C-02, C-03.
- **Files touched:** `core/WhatGroup.lua`, `modules/Frame.lua`, `tests/test_frame.lua`,
  `tests/test_capture.lua`.

### T-2 — The last version-variant API back behind Compat

- **What changed.** `Compat.GetAddOnMetadata(name, field)` was added, and the two inline
  `C_AddOns`-vs-global detections in `settings/Panel.lua` and `settings/Slash.lua` now call it —
  with `addonName` instead of a hardcoded `"WhatGroup"` string.
- **Why it mattered.** `core/Compat.lua` declares itself the sole caller of version-variant APIs and
  the docs repeat that claim, but this one API was detected twice, in two files, with two different
  fallbacks. A patch that moved it would have needed three edits and would have degraded
  inconsistently.
- **Findings covered:** F-003. **Changes implemented:** C-05.
- **Files touched:** `core/Compat.lua`, `settings/Panel.lua`, `settings/Slash.lua`,
  `tests/test_compat.lua`, `docs/file-index.md`.

### T-3 — A migration seam that fails loudly

- **What changed.** `RunMigrations` no longer stamps `db.global.schemaVersion` forward
  unconditionally; the step loop is the only writer, and a database written by a newer build is left
  untouched with a `[Migrate]` line saying so.
- **Why it mattered.** The stamp was the one line able to destroy the only evidence that a profile
  still needed migrating. It cost nothing at `schemaVersion == 1` — which is exactly why it would
  not have been noticed until the first real migration, when it would be unrecoverable.
- **Findings covered:** F-004. **Changes implemented:** C-06.
- **Files touched:** `core/Database.lua`, `tests/test_database.lua`.

### T-4 — Removing the duplications the library adoption otherwise ended

- **What changed.** The popup calls `Labels.GetPlaystyleLabel` instead of re-deriving the
  string-else-enum precedence; five locale keys that nothing referenced were removed (including one
  that duplicated a string the library now owns); the never-read `captured.playstyle` alias was
  dropped; three stale `read_globals` entries were pruned from `.luacheckrc`; and two chat lines were
  brought into the addon's voice.
- **Why it mattered.** The whole point of the LibKa0s adoption was to stop the same text existing in
  two places with a fix landing in one. These were the same shape at addon scale, and each one
  contradicted a comment that claimed otherwise.
- **Findings covered:** F-002, F-008, F-010, F-011, F-012. **Changes implemented:** C-04, C-09.
- **Files touched:** `modules/Frame.lua`, `locales/enUS.lua`, `core/WhatGroup.lua`, `.luacheckrc`,
  `settings/Panel.lua`, `settings/Slash.lua`, `tests/test_capture.lua`, `tests/test_frame.lua`.

### T-5 — Hardening the two lazily-built UI paths

- **What changed.** The teleport button's anchor falls back to the layout constants that produced it
  when a region rect is not resolvable, instead of doing bare arithmetic on four getters that can
  return nil; and the deferred Defaults-button latch is cleared inside its own callback so
  `panel.defaultsBtn` remains the real idempotence guard.
- **Why it mattered.** Both were "works today, fails invisibly tomorrow" — one would have taken out
  the popup's first build entirely, the other would have left a settings page permanently missing its
  Defaults button with no error.
- **Findings covered:** F-005, F-013. **Changes implemented:** C-07, C-08.
- **Files touched:** `modules/Frame.lua`, `settings/OptionsSetup.lua`, `tests/test_panel.lua`.

### T-6 — Release hygiene

- **What changed.** The version was bumped in the TOC and in `WhatGroup.VERSION` together, and the
  README's `## What's new` heading and `## Version History` top row were rolled forward in the same
  change, naming the `/wg reset` re-specification and the new `/wg resetall`.
- **Why it mattered.** Master had been carrying a backwards-incompatible change to a command shipped
  since 1.0 while every version marker still read 1.3.0 and the README's What's new described the
  previous release.
- **Findings covered:** F-007. **Changes implemented:** C-10.
- **Files touched:** `WhatGroup.toc`, `core/WhatGroup.lua`, `README.md`.

## API / behavior changes

- **Slash commands:** no verb added or removed by *this* cycle. The `/wg reset` → per-path
  re-specification and the new `/wg resetall` landed earlier on master; this cycle is what finally
  **versions and documents** them (C-10).
- **Chat output:** two operator-facing lines reworded (`settings/Panel.lua` combat-registration
  refusal; `settings/Slash.lua`'s panel-unavailable branch). No line's meaning changed.
- **Popup:** unchanged visually. In the one combat-plus-group-leave sequence it now shows "No data"
  instead of the previous group's details — the correct outcome, and the only externally observable
  behavior change in the cycle.
- **Deprecated calls replaced:** see the table below.
- **Locale keys removed:** `"Ka0s WhatGroup"`, `"General"`, `"Slash Commands"`, `"Defaults"`,
  `"cannot open settings during combat — Blizzard's category-switch is protected"`. None was
  referenced by any call site; the metatable fallback in `locales/enUS.lua` covers any literal that
  later wants routing.
- **Defaults:** unchanged. No profile default was added, removed or re-valued.

## Saved-variable / migration notes

**No schema bump.** `NS.SCHEMA_VERSION` stays at `1` and the persisted profile shape is unchanged,
so existing profiles carry over untouched and **no `/wg resetall` is required**.

What changed is the *runner*, not the data:

| | Before | After |
|---|---|---|
| Current DB (`schemaVersion == 1`) | version re-stamped to 1 every login | untouched; loop does not run |
| Older DB (`schemaVersion < N`) | stamped to `N` whether or not a step ran | advanced one step at a time by the loop |
| Newer DB (`schemaVersion > N`) | silently downgraded to `N` | left as-is, with a `[Migrate] db is newer` console line |

## Deprecated-API migrations

| Old API | New API | Files |
|---|---|---|
| `GetAddOnMetadata` (removed global, called inline) | `NS.Compat.GetAddOnMetadata` → `C_AddOns.GetAddOnMetadata` with the global as last-resort fallback | `core/Compat.lua` (new shim), `settings/Panel.lua`, `settings/Slash.lua` |

No other deprecated call was found outside `core/Compat.lua`. The pre-existing shims
(`C_Spell.GetSpellName` / `GetSpellTexture` / `GetSpellLink`, `IsSpellKnown`,
`C_LFGList.GetActivityInfoTable`) were reviewed and left unchanged; the settings surface already
uses `Settings.RegisterCanvasLayoutCategory` / `…Subcategory`, not the removed
`InterfaceOptions_AddCategory`.

## Performance impact

No perf-tagged changes. C-02 removes a small unbounded per-session accumulation (one capture table
per application that is declined or cancelled); the smoke-test spot-check
(`03_SMOKE_TESTS.md` → Performance spot-checks) is the record. The addon runs no `OnUpdate` handler
and no repeating ticker, so no frame-time measurement applies.

## Known follow-ups

- **`LibKa0s-Perf-1.0` remains unwired** — declined on structural grounds (no hot path; `suspend`
  would stop a capture addon capturing) and recorded as `LIBKA0S-15` in `docs/pending/LEDGER.md`.
  Untouched here because it is a standing, documented decision, not a review finding.
- **Locale scope** — `locales/enUS.lua` deliberately does not route settings-panel labels, schema
  tooltips or CLI diagnostics. C-09 aligned the file's contents with its stated scope; widening the
  scope is a separate decision (and, per `docs/scope.md`, English-only content is intentional).
- **The `## Interface:` line** — left at `120007`. It is a separate versioning axis driven by
  `wow-addon:bump-interface`, and the current live retail build could not be verified from the
  review environment.
- **`tests/test_frame.lua`'s combat-deferral cases** now assert both directions of the restore. If a
  third suspension path is ever added (a queued build during a loading screen, say), it should
  consult the same wipe generation rather than inventing its own rule.

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-03/03_SMOKE_TESTS.md`, sign-off table completed.
- **Headless gates:** `lua tests/run.lua` green (baseline before this cycle: 415 passed, 0 failed)
  and `luacheck .` clean (baseline: 0 warnings / 0 errors in 14 files) at every commit.
- **Commits:** the ten commits listed in `04_EXECUTION_PLAN.md` → *Incremental commit strategy*,
  each carrying a `Review: docs/reviews/2026-08-03/` line.

## Suggested commit message / PR description

```
Review 2026-08-03: fix the resurrected-capture bug and close the post-LibKa0s drift

A group-info popup requested during combat could restore a capture that leaving the
group had already wiped. Because the wipe also clears the "already announced" guard,
the next group joined — even by a plain invite with no LFG apply — could be announced
with the PREVIOUS group's title, leader, instance and teleport spell. Capture state now
carries a wipe generation and the deferred restore consults it (F-001).

Also in this cycle:
  * the migration runner no longer stamps schemaVersion forward without migrating, and
    leaves a database written by a newer build alone (F-004)
  * addon-metadata reads route through Compat instead of two inline C_AddOns probes
    with two different fallbacks (F-003)
  * the popup calls the shared playstyle label function instead of re-deriving it (F-002)
  * dead LFG applications are reclaimed; shortName is seeded in the capture shape
    (F-006, F-009)
  * teleport-anchor geometry is nil-safe; the deferred Defaults-button latch clears
    (F-005, F-013)
  * orphaned locale keys, an unread capture alias, stale lint globals and two
    off-voice chat lines removed (F-008, F-010, F-011, F-012)
  * version markers and the README's What's new / Version History rolled forward for
    the breaking /wg reset re-specification (F-007)

No SavedVariables schema change; existing profiles carry over untouched.
No edits under libs/ or tests/_kit/ — the vendored copies remain byte-identical to
their source repo.

Review: docs/reviews/2026-08-03/
```
</content>
