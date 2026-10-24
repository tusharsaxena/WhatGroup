# Candidates (WhatGroup, LibKa0s v1.76.0 to v1.77.0)

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` (15 commits), the tag's `CHANGELOG.md`
block v1.77.0, and the `docs/api/` documents it links. The base, v1.76.0, comes from this repo's
CLAUDE.md provenance line. The one 3g blocker (the four Options stub members) was fixed in the
re-vendor commit and is not a candidate.

## A. Delivered on the re-vendor alone

- **The debug console is toplevel and keeps a shown confirmation on top** (DebugLog 21, Core 12).
  WhatGroup's `/wg debug` console is the library's (`core/DebugLogSetup.lua`), so a click now raises
  it among its DIALOG peers, the Settings panel included. A console shown while the
  `WHATGROUP_RESET_ALL` popup is up raises that popup over itself through
  `Core.RaiseStaticPopups()`.
- **Nothing else reaches this addon at runtime.** The clamped dropdown menu and suggestion list
  (Widgets 15, WidgetsAutocomplete 3), the combat close of the suggestion list (OptionsIds 3,
  OptionsCombat 2) and the toplevel perf and sim panels (PerfPanel 9, SimPanel 6) sit under
  surfaces this addon does not draw. The client loads every file of the XML, so the new minors win
  LibStub's comparison in any session where WhatGroup's copy is the newest. That is harmless,
  because each change keeps the old behavior for a caller that passes nothing new.

## B. Host change required

- **The Keybindings tab** (`O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED`;
  OptionsKeybinds 2 and 3; `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`, *The
  Keybindings tab*). options-ui-§20 for a windowed addon. This run's **WG-KB** adopts it.
- **Kit 42's binding mock and the Bindings.xml check** (`tests/_kit/mock_bindings.lua`,
  `Kit.assertBindingsXml`, `Kit.keybindThroughTab`; `docs/api/testkit/version-42-docs.md`). Used by
  **WG-KB**.
- **Kit 42's frame-layer recorder** (`tests/_kit/mock_layers.lua`). Used by **WG-ZS**, which the
  run holds for the owner.
- **`O.StrataTooltip`** (OptionsCompose 8). The shared tooltip for a player strata row. WhatGroup's
  schema has no strata row today (`grep -rni strata settings defaults` finds only the stub), so
  nothing draws it unless WG-ZS's accepted changes add one.
- **`Core.RaiseStaticPopups()`** (Core 12) called from a host window's `OnShow`. WhatGroup's own
  popup window (`modules/Frame.lua`) could call it. Whether it should is a frame-layering call, so
  it belongs to WG-ZS and `plan-data/accepted.json`.
- **DragHandle `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha`** (WidgetsDragHandle
  5). WhatGroup builds no DragHandle and does not consume Widgets (#12).

## C. Whole-module adoption

- **Widgets, Perf and Sim** stay unconsumed. Their settled reasons are unchanged by this release:
  Widgets declined (#12), Perf declined (the addon's own record), Sim tracked as
  [WhatGroup#24](https://github.com/tusharsaxena/WhatGroup/issues/24).
