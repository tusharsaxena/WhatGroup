Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b76, a local tag, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, item SD-RV-WG: copy and bundle only, no adoption interview and no issue filing (the run's items for this addon are pre-decided: SD-RV-WG and SD-SK-WG).

## Step 0 pre-flight
Newest single-tag bundle `2026-11-19-v1.107.0`, line 1 `Delta: LibKa0s v1.106.0 -> v1.107.0`; the provenance line before that re-vendor (`28ff1e5`, refreshed by `70616c3` for the re-cut tag) named v1.106.0. ok, no correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.107.0 before the roll (CLAUDE.md:48).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is 70616c3 ("AF-RV-WG: Re-vendor the re-cut LibKa0s v1.107.0"); its CLAUDE.md names v1.107.0. They agree.
- Payload before the copy equalled the library at v1.107.0: `diff -rq` of `libs/LibKa0s` (outside the pruned `media/icons` and `media/sounds`) and of `tests/_kit` against a v1.107.0 extract printed nothing (payload-matches).
- `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0`: 15 commits (SD-LK-94, SD-LK-99, SD-LK-100, SD-LK-97 Batches A to D, SD-LK-GUARD, SD-LK-REL). `git -C ../LibKa0s diff --stat v1.107.0 v1.108.0 -- LibKa0s testkit`: 23 files changed, 1363 insertions, 306 deletions.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.108.0)
The constants this addon carried matched v1.107.0's, so the line and the bytes agreed.
```
Core.lua  old: local MAJOR, MINOR = "LibKa0s-Core-1.0", 18  new: 19
Callout.lua  old: local MAJOR, MINOR = "LibKa0s-Callout-1.0", 4  new: 5
CalloutSettings.lua  old: local SETTINGS_MINOR = 5  new: 6
WaypointArrow.lua  old: local MAJOR, MINOR = "LibKa0s-WaypointArrow-1.0", 2  new: 3
WaypointArrowSettings.lua  old: local SETTINGS_MINOR = 2  new: 3
Charts.lua  old: local MAJOR, MINOR = "LibKa0s-Charts-1.0", 2  new: 3
ChartsRender.lua  old: local RENDER_MINOR = 1  new: 2
SkinPaint.lua  old: local PAINT_MINOR = 19  new: 20
SkinPaintHud.lua  old: local HUD_MINOR = 1  new: 2
SkinPaintControls.lua  old: local CONTROLS_MINOR = 18  new: 19
Widgets.lua  old: local MAJOR, MINOR = "LibKa0s-Widgets-1.0", 29  new: 30
WidgetsDropdown.lua  old: local DROPDOWN_MINOR = 2  new: 3
WidgetsDragHandle.lua  old: local DRAG_MINOR = 15  new: 16
WidgetsDragHandleTip.lua  old: local DRAGTIP_MINOR = 2  new: 3
WidgetsLineChart.lua  old: local CHART_MINOR = 7  new: 8
WidgetsBar.lua  old: local BAR_MINOR = 1  new: 2
OptionsCompose.lua  old: local COMPOSE_MINOR = 19  new: 20
```
Every other file in the tag's `LibKa0s.xml` kept its minor. No file is new and no `NEEDS_*` floor rose.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -rq` of both payloads against the v1.108.0 extract were empty. After the prune the only lines are `Only in <extract>/LibKa0s/media/icons...` and `Only in <extract>/LibKa0s/media/sounds...` (names not declared).

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings`: Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Schema, Sim, Skin, Slash, Tooltip and Widgets, one lookup site each, unchanged from `../2026-11-19-v1.107.0/`. Callout, WaypointArrow and Charts are not looked up. Of the moved files this addon reaches Core (the popup's `ApplySkin`, no `skinBands`), Skin (SkinPaint, SkinPaintControls, SkinPaintHud through its owner facade), Widgets (`W.HeaderButtons`, the library's own Dropdown rows on the settings pages) and Options (OptionsCompose, reached only by the library's own Appearance tab: `grep -rn 'FontGroup\|BorderGroup\|BarGroup\|ColorPair' core modules settings` finds only the degraded stubs in `settings/OptionsSetup.lua:110-113`).

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 57
new: testkit/framework.lua:20:Kit.VERSION = 58
```
Both payloads copied whole in one commit.

## 3g Contract delta and Blockers
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
- OptionsCompose minor 20 (composers emit FromSkin companions by default): this addon calls no composer, so no block emits a new path.
- WidgetsBar minor 2 (`borderFromSkin`, `glossFromSkin` default true), `S.ApplyBarFill` (97.17), Charts minor 3, Callout 5, WaypointArrow 3: no `W.Bar`, StatusBar, chart, call-out or arrow in this addon.
- Core minor 19 `skinBands`: the popup passes `ApplySkin(f, nil, addonName)` (modules/FrameLayout.lua:137), no host table, so nothing moves call for call.
- Widgets minor 30 Footer re-lay: this addon builds no footer.

**Blockers: one, test kit revision 58.** Its `test_skin_values` now reads a keyed table of four-number tables, and turned red on `core/CoreSetup.lua:97`, the degraded arm's `NS.SKIN = { bg = { 0.06, 0.06, 0.08, 0.92 }, border = { 0, 0, 0, 1 } }`. Fixed in the commit: the degraded `NS.ApplySkin` reads `win.bg` and `win.border` from `NS.SKIN_FALLBACK` (core/SkinSetup.lua, the host copy `tests/test_skinsetup.lua` holds to the live library) at call time, the same two colors, so no second copy remains. New case in `tests/test_frame_skin.lua` ("the degraded popup's edge draws the host copy's win.bg and win.border").

## 3h Unrecorded vendored tags
The re-vendor-bundle walk (provenance tags at every payload commit and every CLAUDE.md roll since the store's horizon, against the tags the bundles in `docs/revendor/` name) prints nothing: v1.107.0 has `../2026-11-19-v1.107.0/`. No span bundle.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: line 49, kept as written. No v1.108.0 surface this addon draws adds a library-drawn icon.
- `lua <extract>/tools/prune-icons.lua .`: icons and sounds pruned back to the declaration; after the prune `git status` shows no change under `libs/LibKa0s/media/`.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: tests/test_mediasetup.lua only, reading catalog names and declared files; green after the prune. Nothing to fix.
