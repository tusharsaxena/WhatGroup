Delta: LibKa0s v1.93.0 -> v1.105.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 43ea2bd, a local tag, not yet pushed: `git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing, which this run expects). Run under Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-WG, copy-and-bundle half only.

## Step 0 pre-flight (this addon)
- Newest single-tag bundle `2026-11-07-v1.93.0` states base v1.92.0. The commit that vendored v1.93.0 is 1ce43c7, and the provenance line at its parent names v1.92.0. ok, no correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.93.0 before the roll (CLAUDE.md:48).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 5f3cbb8; its CLAUDE.md names v1.93.0. They agree.
- Payload before the copy equalled the library at v1.93.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.93.0 extract printed nothing beyond the undeclared icons (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0` is 117 commits, the tags v1.94.0 to v1.105.0.

## 3b/3c Per-file minors that moved (old = this addon at v1.93.0, new = v1.105.0)
```
Core.lua  old: 17  new: 18
Tooltip.lua  old: none  new: 1
Compat.lua  old: 3  new: 4
Role.lua  old: none  new: 1
Callout.lua  old: none  new: 4
CalloutSettings.lua  old: none  new: 5
WaypointArrow.lua  old: none  new: 2
WaypointArrowSettings.lua  old: none  new: 2
Charts.lua  old: 1  new: 2
Media.lua  old: 12  new: 13
Skin.lua  old: 17  new: 18
SkinDefs.lua  old: 27  new: 28
SkinDefsOthers.lua  old: 8  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: 1  new: 2
WidgetsReorder.lua  old: 6  new: 7
WidgetsDragHandle.lua  old: 13  new: 14
WidgetsDragHandleTip.lua  old: none  new: 1
WidgetsCopyWindow.lua  old: 5  new: 6
WidgetsHeader.lua  old: none  new: 1
WidgetsBar.lua  old: none  new: 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: 7  new: 11
DebugLogWindow.lua  old: 4  new: 5
Launcher.lua  old: 9  new: 11
OptionsWidgets.lua  old: 45  new: 46
OptionsNav.lua  old: 6  new: 7
OptionsSkinPicker.lua  old: 11  new: 12
OptionsSkinPickerQueue.lua  old: none  new: 1
IconBrowserWindow.lua  old: 1  new: 2
IconBrowser.lua  old: 1  new: 2
PerfPanel.lua  old: 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: 10  new: 11
SimPanelRender.lua  old: 3  new: 4
```
Every file not listed matched v1.93.0 before the copy, so there is no cross-major skew. Ten files are new (72 -> 82 in `LibKa0s.xml`): Tooltip, Role, Callout, CalloutSettings, WaypointArrow, WaypointArrowSettings, WidgetsDragHandleTip, WidgetsHeader, WidgetsBar, OptionsSkinPickerQueue.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.105.0 extract were empty. After the prune the only difference is the undeclared icons and the callout sounds (no `LibKa0s sounds:` line); `tests/test_vendor_sync.lua` is green. `media/waypoint/` and the two new fonts ship whole, as the tag requires (not pruneable).

## 3e Consumption map
```
core/Compat.lua:36:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:46:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:20:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:41:LibStub("LibKa0s-Env-1.0", true)
core/LauncherSetup.lua:42:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:38:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:50:LibStub("LibKa0s-Media-1.0", true)
core/SkinSetup.lua:79:LibStub("LibKa0s-Skin-1.0", true)
settings/OptionsSetup.lua:17:LibStub("LibKa0s-Options-1.0", true)
settings/SchemaSetup.lua:236:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:134:LibStub("LibKa0s-Slash-1.0", true)
```
Unchanged from v1.93.0. Majors in the payload with no lookup here: Bus, Callout, Charts, Glow, IconBrowser, Item, Perf, Pool, Role, Sim, Toast, Tooltip, WaypointArrow, Widgets.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 53
new: testkit/framework.lua:20:Kit.VERSION = 57
```
Kit revision 57 pairs with v1.105.0, and both payloads are copied whole in one commit. Revision 57 holds a registered mock frame alive (LibKa0s#75) and adds the opt-in `mock_screen.lua`; no suite here relied on a collected frame (the full suite is green). Its `LIBRARY_MARKS` gains `settings`, which this addon already declares.

## 3g Contract delta and Blockers
Consumed majors that moved a minor: Core (18), Compat (4), Media (13), Skin (SkinDefs 28, SkinDefsOthers 10, Skin 18), DebugLog (23, Diagnostics 11, Window 5), Launcher (11), Options (OptionsWidgets 46, OptionsNav 7, OptionsSkinPicker 12, OptionsSkinPickerQueue 1). Env, Lifecycle, Schema and Slash did not move. Host-supplied members, `__Attach*` sites outside libs, the kit and tests:
```
none
```
Read against the v1.94.0..v1.105.0 CHANGELOG blocks and their *What a consumer owes* lists: no surface this addon calls changed what it requires of the host. The changes it does owe are stub-shape and loader changes, fixed in this commit:
- `tests/loader.lua`: the ten new payload files, in `LibKa0s.xml` order (without `OptionsSkinPickerQueue.lua` every settings path raised at `OptionsSkinPicker.lua:1357`).
- DebugLog stub: `Report` and `Serialize` (DebugLog minor 23, DebugLogDiagnostics minor 11).
- Options helpers stub: `SideTabs` (OptionsNav minor 7, since v1.100.0).
- Compat reader arm: `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey` (Compat minor 4, since v1.94.0), wired to the library with the documented absent answers. Nothing calls them yet.

**Blockers: none.**

## 3h Unrecorded vendored tags
```
(empty)
```
No span bundle owed.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 49:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.
- Kept as written. `settings` is already declared, which kit 57's `LIBRARY_MARKS` now requires.
- Prune: `lua tools/prune-icons.lua .` kept 13 icon files for 12 names and removed the rest of the copied catalog (Open Iconic only ships, as before); sounds none, 362 removed. Net change under `media/icons/` against v1.93.0: none.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds the same `tests/test_mediasetup.lua` lines as at v1.93.0 (128, 141, 167-176, 189, 261). They read declared names and the catalog list, and they pass after the prune.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none.
