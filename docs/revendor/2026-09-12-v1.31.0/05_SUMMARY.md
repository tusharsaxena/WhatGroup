# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

| | |
|---|---|
| From | v1.30.0, kit revision 16 |
| To | **v1.31.0** (tag at `30db4ed`), kit revision **17** |
| Run | non-interactive, triage wave B2, 2026-09-12. No issue filed, nothing pushed |

## Per-file minors

| File | v1.30.0 | v1.31.0 |
|---|---|---|
| `OptionsWidgets.lua` (`WIDGETS_MINOR`) | 14 | **15** |
| `OptionsCompose.lua` (`COMPOSE_MINOR`) | 3 | **4** |
| Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, Slash 7, Options 15, `SCROLL_MINOR` 3, Perf 10, `PANEL_MINOR` 5 | unchanged | unchanged |

Both payloads were copied whole from `git archive v1.31.0`, and the `CLAUDE.md` provenance line moved
in the same commit. `docs/testing.md`'s sibling-state note moved with it, and so did
`docs/smoke-tests.md` 12a.3, which named kit 16 as the geometry flip; the flip is now revision 18 at
the earliest. After the copy, both diffs were empty in both directions, content and bytes. There were
no `Only in` lines, so nothing was deleted inside either payload.

## Delivered for free (class A)

- `OptionsWidgets` 15 and `OptionsCompose` 4 are inert here: every row is path-keyed, and there are no
  registry records to bind.
- Kit 17's `__fireTimers` cancellation and AceGUI `WidgetVersions` / layouts reached the harness.
  Cancellation only matters once B-1 is in, and nothing reads the AceGUI members.

## Adopted

| Candidate | Commit |
|---|---|
| Re-vendor (payload + provenance) | `23c57c8` Re-vendor LibKa0s v1.31.0 (kit revision 17) |
| B-1 harness onto the kit's Ace fakes (#19, option 1) | `ef039b3` Harness: run the addon object on the kit's Ace fakes, for #19 |
| B-2 `C_SpellBook` in the mock | `9039729` Harness: model C_SpellBook beside the IsSpellKnown global, for #19 |

## Declined, skipped, unreached

Nothing was declined. Filing was skipped by instruction, and there was nothing to file. The Perf
decline (WhatGroup#7) stands, and this release does not move its premise.

## Gates

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, before the copy | 573 / 0 failed / 573 | 0 / 0, 41 files |
| After the copy (`23c57c8`) | 573 / 0 / 573, `test_vendor_sync` green against v1.31.0 | 0 / 0 |
| B-1 red step | 572 / 6 failed: the five new harness cases, plus eol on an LF append, which was repaired | — |
| After B-1 (`ef039b3`) | 578 / 0 / 578 | 0 / 0 |
| B-2 red step | 577 / 1 failed ("normalizes to a plain boolean") | — |
| After B-2 (`9039729`) | 579 / 0 / 579 | 0 / 0 |

`luacheck` excludes `libs/` and `tests/_kit/`. The files this run changed (`tests/wow_mock.lua` and
the ported suites) are inside the checked set. No production Lua changed. `lizard -C 15 -w` over
`core modules settings defaults locales` and over the six changed test files reports no function
above CCN 15.

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. Commit `fa2fdc1` ("Re-vendor LibKa0s v1.31.0 from the
re-cut tag (e7e1962)") copied both payloads whole from the re-cut tag, and the vendor-sync cases pass
against it. The provenance line in `CLAUDE.md` already named v1.31.0, so it did not move.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `LibKa0s/` move in this release, not two, and any "the ring trim is not traced" finding
recorded above is resolved upstream by Perf minor 11.

The re-cut needed one consumer follow-up. The reviewed kit records a canceled timer handle under
AceTimer's own field name, `cancelled`, where the first cut used `canceled`. The supersede case in
`tests/test_notify.lua` read the old name, and it was the one failure `fa2fdc1` left. Commit `0fd5493`
("Tests: read the canceled timer handle as AceTimer's `cancelled`") ported that read from `.canceled` to
`.cancelled`. No other addon code reads the renamed field.

The gate, re-run on the re-cut payload:

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| After the re-cut copy (`fa2fdc1`) | one failure: the `test_notify.lua` supersede case reading `.canceled` | — |
| After the port (`0fd5493`) | 579 / 0 / 579, `test_vendor_sync` green against `e7e1962` | — |
| After the chat-link fix (`fcf8197`) | 589 / 0 / 589 | 0 / 0, 41 files |

The ten cases between the last two rows come from `fcf8197`'s chat-link tests, not from the re-cut.
