Delta: LibKa0s v1.84.0 -> v1.85.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (FS-WG-RV). The tag is local, cut by that run's `FS-REL`, at `9776130`, extracted with `git -C ../LibKa0s archive v1.85.0 LibKa0s testkit tools`.

## Base (3a)

`grep -n '[Bb]undles' CLAUDE.md` named v1.84.0, and `diff -rq` of both payloads against `git archive v1.84.0` printed only the undeclared icons. The range is `git -C ../LibKa0s log --oneline v1.84.0..v1.85.0`: 24 commits.

The newest single-tag bundle, `2026-11-01-v1.84.0`, states base v1.83.0, which is this addon's history. No correction is owed.

## Per-file minors (3c), moved files only

From the loop over the tag's `LibKa0s.xml`, old against tag.

| File | old | new |
|---|---|---|
| Glow.lua | 1 | 2 |
| Toast.lua | 1 | 2 |
| Skin.lua | 11 | 14 |
| SkinDefs.lua | 19 | 24 |
| SkinDefsOthers.lua | 1 | 6 |
| SkinPaint.lua | 13 | 16 |
| SkinPaintExtras.lua | 7 | 15 |
| SkinPaintControls.lua | 11 | 14 |
| SkinEUI.lua | 2 | 3 |
| SkinAce.lua | 6 | 9 |
| Widgets.lua | 17 | 20 |
| WidgetsReorder.lua | 3 | 5 |
| WidgetsDragHandle.lua | 10 | 12 |
| WidgetsLineChart.lua | 5 | 6 |
| WidgetsAutocomplete.lua | 5 | 6 |
| WidgetsCopyWindow.lua | 2 | 4 |
| DebugLogWindow.lua | 2 | 3 |
| Launcher.lua | 5 | 6 |
| OptionsWidgets.lua | 41 | 44 |
| OptionsIds.lua | 6 | 7 |
| OptionsIdList.lua | 7 | 8 |
| OptionsTabs.lua | 13 | 15 |
| OptionsCompose.lua | 16 | 17 |
| OptionsScroll.lua | 10 | 13 |
| OptionsNav.lua | 4 | 5 |
| OptionsDrawer.lua | 4 | 5 |
| OptionsKeybinds.lua | 6 | 7 |
| OptionsAppearance.lua | 5 | 6 |
| OptionsSkinPicker.lua | 5 | 7 |
| OptionsMedia.lua | 3 | 4 |
| PerfPanel.lua | 11 | 12 |
| SimPanel.lua | 9 | 10 |
| SimPanelRender.lua | 1 | 2 |

No file is behind the old tag: no cross-major skew.

## Diffs (3d)

Against the whole copy, before the prune: `diff -r --strip-trailing-cr` of both payloads printed nothing.

## Consumption (3e)

Lookups outside `libs/` and `tests/`: Env, Launcher, Compat, Skin, Lifecycle, Core, DebugLog, Media, Options, Slash, Schema. Unchanged.

## Kit (3f)

`grep -n 'Kit.VERSION'`: revision 47 -> 49. The two payloads move together.

## Blockers (3g, 3j)

- **Facade.** LibKa0s `docs/releasing.md` step 8 and `CHANGELOG.md` v1.85.0, "What a consumer owes": the degraded Skin facade (`core/SkinSetup.lua`) gains `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`. `HudFont` is the Options document's stub. The Options stub (`settings/OptionsSetup.lua`) gains `LabelFont`. Resolved in the re-vendor commit.
- **Icons (3i).** `docs/releasing.md`, "Step 8 for v1.85.0": `chevron-down, chevron-up, close, confirm, info, move, reset, volume-high`, or kit revision 49's vendor gate goes red. Decided by the plan, not re-asked. Hand lists have drifted before, and the owner's smoke is the backstop.
- **3j.** `tests/test_mediasetup.lua` pins the drawn set to the declaration, so its list moved with the line.
- No `__Attach*` member moved here, and `__releaseChrome` has no mirror.

## Unrecorded tags (3h)

v1.80.0 to v1.83.0 are recorded by the span bundle `2026-10-31-v1.80.0-v1.83.0`; nothing unrecorded.
