# Architecture

Orient-yourself map for **Ka0s WhatGroup**. This file is the high-level index; topic detail lives in `docs/`.

## What it does

WhatGroup observes the Premade Group Finder (LFG) flow. It captures the group details visible on the search-result tile when the player applies, holds them across the application → invite → accept → join sequence, and resurfaces them once the player is actually in the group as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells.

The addon is observation-only. It never modifies LFG state, never auto-applies, and never blocks the join flow — every hook is either a `SecureHook` (read-only) or a `RawHook` that short-circuits only on its own custom hyperlink.

## Subsystems at a glance

```
LFG events ─▶ capture pipeline ─▶ pendingInfo
                  │                    │
                  ▼                    ▼
        ApplyToGroup → applied   GROUP_ROSTER_UPDATE  (not-in → in transition)
        → inviteaccepted              │
        (FIFO queue + appID map)      ▼
                                  C_Timer.After(notify.delay)
                                      ├─ ShowNotification   chat output
                                      └─ ShowFrame          popup dialog (if frame.autoShow)

  Settings.Schema  ─►  panel widget + /wg list/get/set + AceDB defaults + /wg reset
  COMMANDS table   ─►  /wg help + /wg <verb> dispatch
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-file responsibility map | `WhatGroup.toc`, `WhatGroup.lua`, `WhatGroup_Settings.lua`, `WhatGroup_Frame.lua` | [docs/file-index.md](./docs/file-index.md) |
| Boundary decisions (in / out of scope, resolved choices) | — | [docs/scope.md](./docs/scope.md) |
| LFG capture pipeline + queue mechanics + RawHook on `SetItemRef` | `WhatGroup.lua` | [docs/capture-pipeline.md](./docs/capture-pipeline.md) |
| Settings schema, panel renderer, helpers, db.profile shape | `WhatGroup_Settings.lua` | [docs/settings-system.md](./docs/settings-system.md) |
| `/wg` slash UX + `COMMANDS` table | `WhatGroup.lua` | [docs/slash-dispatch.md](./docs/slash-dispatch.md) |
| Popup dialog (`WhatGroupFrame`) | `WhatGroup_Frame.lua` | [docs/frame.md](./docs/frame.md) |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | — | [docs/wow-quirks.md](./docs/wow-quirks.md) |
| Routine recipes (add a setting, add a command, refresh libs) | — | [docs/common-tasks.md](./docs/common-tasks.md) |

## Invariants worth not breaking

- **Observation-only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. `SecureHook` on `C_LFGList.ApplyToGroup` is read-only. The single `RawHook` on `SetItemRef` short-circuits ONLY on the `WhatGroup:` link prefix and chains through `self.hooks.SetItemRef(...)` for every other link.
- **Schema-first.** Adding a setting = one row in `Settings.Schema`. The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Slash-first.** Adding a command = one row in `COMMANDS`. Help output iterates the table.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — the third arg `true` shares one `Default` profile across every character on the account. WhatGroup is account-wide by design.
- **`Settings.Register()` is idempotent.** The `WhatGroup._settingsRegistered` guard means it can be called multiple times without re-registering categories. Always call through `self.Settings.Register()` in `OnEnable`, never `Settings.RegisterCanvasLayoutCategory(...)` directly.
- **Parent settings category is the landing page.** The parent never carries schema widgets — instead it shows the logo, TOC notes, and the slash-command list. `/wg config` opens the **parent** (`self._parentSettingsCategory:GetID()`) and reaches into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` (wrapped in `pcall` because that traversal is private Blizzard API) so every subcategory is visible in the sidebar tree. The user lands on the landing page with one click separating them from the General settings. The slash command also refuses to open during `InCombatLockdown()` because the Settings UI uses secure templates that can taint mid-combat. See [docs/wow-quirks.md](./docs/wow-quirks.md#settings-api-parent-vs-subcategory).
- **`wasInGroup` is the join trigger.** Notify + popup fire on the not-in-group → in-group transition only. Other roster updates inside an existing group don't re-fire.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup` never touch SavedVariables. Group-leave wipes all four.
- **Cyan `[WG]` chat prefix on every line.** Module-local `CHAT_PREFIX = "\|cff00FFFF[WG]\|r"` in `WhatGroup.lua` is prepended to every `print(...)`. Debug lines additionally tag `[DBG]` in orange.
- **Lazy AceGUI panel build.** Both the parent landing page and the General subcategory build their body on first `OnShow` (each behind its own one-shot guard). The AceGUI ScrollFrame parented to each panel hooks `OnSizeChanged` to forward dimensions into AceGUI's layout pipeline. Without this, parented-to-Blizzard containers stay at 0×0. See [docs/wow-quirks.md](./docs/wow-quirks.md#lazy-acegui-panel-build).
- **Defaults button + `/wg reset` share one popup.** Both routes call `StaticPopup_Show("WHATGROUP_RESET_ALL")`; the OnAccept body lives in `WhatGroup_Settings.lua` and calls `Helpers.RestoreDefaults()`. No second confirmation path can drift from the first.
- **Don't overwrite `category.ID`.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.

## External dependencies

All vendored under `libs/` and copied verbatim from Ka0s KickCD:

- `LibStub`
- `CallbackHandler-1.0`
- `AceAddon-3.0`
- `AceEvent-3.0`
- `AceConsole-3.0`
- `AceDB-3.0`
- `AceHook-3.0`
- `AceGUI-3.0` (loaded last via its `.xml`)

WoW retail APIs the addon depends on: `C_LFGList.ApplyToGroup` / `GetSearchResultInfo` / `GetActivityInfoTable`, `C_Spell.GetSpellTexture` / `GetSpellLink`, `C_Timer.After`, `IsInGroup`, `IsSpellKnown`, `CastSpellByID`, `SetItemRef`. Settings API: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`. Frame chrome: `BackdropTemplate`, `UISpecialFrames`.

## Load order

`WhatGroup.toc` is the source of truth. Order is dependency, not alphabetical:

1. **libs/** — `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceDB-3.0` → `AceHook-3.0` → `AceGUI-3.0` (last; loaded via its `.xml` because that pulls in `widgets/`).
2. **`WhatGroup.lua`** — calls `AceAddon:NewAddon(existing, "WhatGroup", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")`, assigns `_G.WhatGroup`, defines `OnInitialize` / `OnEnable` / capture handlers / slash dispatch / teleport spell table. Module-locals `captureQueue`, `pendingApplications`, `wasInGroup` initialise to empty / `false`.
3. **`WhatGroup_Settings.lua`** — picks up the addon via `LibStub("AceAddon-3.0"):GetAddon("WhatGroup")`, stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, _panels, BuildDefaults, Register }`. `Helpers` covers schema access (`Get` / `Set` / `FindSchema` / `ValidateSchema`), reset surfaces (`RestoreDefaults` / `RefreshAll`), and the panel-rendering surface (`CreatePanel` / `PatchAlwaysShowScrollbar` / `Section` / `RenderField` / `InlineButton` / `RenderSchema` / `BuildMainContent`). Schema rows are appended via `add{}` calls in source order. Defines `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` for the shared reset-confirmation flow.
4. **`WhatGroup_Frame.lua`** — creates the global `WhatGroupFrame`, attaches the `WhatGroup:ShowFrame()` method. Registered with `UISpecialFrames` for ESC-to-close (Close button + ESC handle the hide path; no programmatic Hide method is exposed).

Lifecycle:

- **`OnInitialize`** (fires on `ADDON_LOADED` for `"WhatGroup"`, after every TOC line has executed): `defaults = Settings.BuildDefaults()` → `db = AceDB:New("WhatGroupDB", defaults, true)` → seed `WhatGroup.debug` from `db.profile.debug` → register `/wg` and `/whatgroup` chat commands.
- **`OnEnable`**: register `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED` events, install `SecureHook` on `C_LFGList.ApplyToGroup`, install `RawHook` on `SetItemRef`, snapshot `wasInGroup = IsInGroup()`, call `Settings.Register()`.

`Settings.Register()` defers the AceGUI body build to the General subcategory's first `OnShow`. See [docs/settings-system.md](./docs/settings-system.md#lazy-panel-build).

If you add a new runtime file, put it in the right place in `WhatGroup.toc` (after libs, after the file it depends on).
