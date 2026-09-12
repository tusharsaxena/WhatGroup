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
