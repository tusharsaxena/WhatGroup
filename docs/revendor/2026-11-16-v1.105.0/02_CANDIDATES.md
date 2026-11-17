# 02 Candidates, LibKa0s v1.93.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.94.0 to v1.105.0 blocks and v1.105.0's *What a consumer owes*; Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` and its research notes R8 and R9.

**Class A, delivered on the copy alone**
- Skin colors (#82, #84): Ka0s Default's rows and seven skins' `icon.hot`, on the popup and the settings panel.
- Header marks (#86) on every library window this addon opens (the debug console, the copy window, the skin picker): extras, settings, close. The settings mark opens WhatGroup's settings through the launcher.
- The console (#79, #90): its status line is a 24 px Widgets footer, and Copy hands out plain text.
- Library tooltips (#92): dropdown entries, the minimap button (toward the screen's center) and the skin picker's toolbar tips, placed by `LibKa0s-Tooltip-1.0`.
- OptionsWidgets minor 46: a slider box reverts junk text on Enter and on focus loss.
- Media minor 13: two more font faces in the pickers.

**Class B, host change required: owed in phase [3], not offered in this run**
- #92 tooltip placement: one own site, `modules/Frame.lua:545` (`GameTooltip:SetOwner(self, "ANCHOR_RIGHT")`, the teleport button), onto `PlaceBeside`/`PlaceAttached`.
- #86 header strip: the popup's own title-bar marks (`modules/FrameLayout.lua`) onto `W.HeaderButtons`, with a settings mark. Not in the adoption plan's affected list; evaluate at adoption.
- #87 shared sample characters: `core/TestPreview.lua:34` seeds `leaderName = "Testadin-Silvermoon"`, a real realm, which `Sim.Sample(client)` replaces.
- #79 `D:Report`: no report verb is known here (R8: "none obvious"); confirm against the slash handlers at adoption.
- skinning-§2 `DefaultSkin` (a MUST since v1.94.0): 0 references here; adoption plan item 1.

**Not applicable**: #85 (Callout, no countdown or callout here), #88 (no test strip), #89 (no own footer), #80 and #81 (Skill Master only).

**Class C, whole-module**: Callout, Role, Tooltip and WaypointArrow are new majors with no lookup here; Tooltip is the #92 candidate above, the other three have no use in this addon.

**Blockers (3g)**: none.
