# Architecture

Orient-yourself map for **Ka0s WhatGroup**. This file is the high-level index; topic detail lives in `docs/`.

## What it does

WhatGroup observes the Premade Group Finder (LFG) flow. It captures the group details visible on the search-result tile when the player applies, holds them across the application → invite → accept → join sequence, and resurfaces them once the player is actually in the group as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells.

The addon is observation-only. It never modifies LFG state, never auto-applies, and never blocks the join flow — both hooks are direct `hooksecurefunc` post-hooks (one on `C_LFGList.ApplyToGroup` for capture, one on `SetItemRef` filtered to `WhatGroup:` link clicks). No AceHook wrappers — those leave per-invocation closures that taint Blizzard's secure-execute chain on Logout.

## Subsystems at a glance

```
LFG events ─▶ capture pipeline ─▶ pendingInfo
                  │                    │
                  ▼                    ▼
        ApplyToGroup → applied   _TryFireJoinNotify(reason)
        → inviteaccepted          (called from BOTH paths below;
        (FIFO queue + appID map)   `notifiedFor` flag prevents double-fire)
                                      ▲                  ▲
                                      │                  │
                          ROSTER transition       inviteaccepted
                          (not-in → in)           (after pendingInfo set)
                                      │
                                      ▼
                                  C_Timer.After(notify.delay)
                                      ├─ ShowNotification   chat output
                                      └─ ShowFrame          popup dialog (if frame.autoShow)

  Settings.Schema  ─►  panel widget + /wg list/get/set + AceDB defaults + /wg reset
  COMMANDS table   ─►  /wg help + /wg <verb> dispatch
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-file responsibility map | `WhatGroup.toc`, `WhatGroup.lua`, `data/TeleportSpells.lua`, `WhatGroup_Settings.lua`, `WhatGroup_Frame.lua` | [docs/file-index.md](./docs/file-index.md) |
| Boundary decisions (in / out of scope, resolved choices) | — | [docs/scope.md](./docs/scope.md) |
| LFG capture pipeline + queue mechanics + `hooksecurefunc` on `SetItemRef` | `WhatGroup.lua` | [docs/capture-pipeline.md](./docs/capture-pipeline.md) |
| Settings schema, panel renderer, helpers, db.profile shape | `WhatGroup_Settings.lua` | [docs/settings-system.md](./docs/settings-system.md) |
| `/wg` slash UX + `COMMANDS` table | `WhatGroup.lua` | [docs/slash-dispatch.md](./docs/slash-dispatch.md) |
| Popup dialog (`WhatGroupFrame`) | `WhatGroup_Frame.lua` | [docs/frame.md](./docs/frame.md) |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | — | [docs/wow-quirks.md](./docs/wow-quirks.md) |
| Routine recipes (add a setting, add a command, refresh libs) | — | [docs/common-tasks.md](./docs/common-tasks.md) |
| Manual smoke tests (boot health, slash, settings panel, `/wg test`, real LFG, regression checks) | — | [docs/smoke-tests.md](./docs/smoke-tests.md) |

## Invariants worth not breaking

- **Observation-only, direct hooksecurefunc only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Both hooks are direct `hooksecurefunc` post-hooks: one on `C_LFGList.ApplyToGroup` (for capture) and one on `SetItemRef` filtered to `WhatGroup:` link clicks. No AceHook `SecureHook` / `RawHook` — AceHook adds a per-invocation bookkeeping closure around the callback, and that closure taints the secure-execute chain that Blizzard runs when the player clicks the GameMenu's Logout button (surfacing as `ADDON_ACTION_FORBIDDEN ... 'callback()'`). Direct `hooksecurefunc` has no closure on our side, no taint.
- **Schema-first.** Adding a setting = one row in `Settings.Schema`. The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Slash-first.** Adding a command = one row in `COMMANDS`. Help output iterates the table.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — the third arg `true` shares one `Default` profile across every character on the account. WhatGroup is account-wide by design.
- **`Settings.Register()` is idempotent and lazy.** The `WhatGroup._settingsRegistered` guard means it can be called multiple times without re-registering categories. It is **only** called from `runConfig` (the `/wg config` slash handler) — never from `OnEnable`. Calling `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterAddOnCategory` from non-secure addon code at PLAYER_LOGIN taints Blizzard's GameMenu callbacks. See [docs/settings-system.md](./docs/settings-system.md#lazy-panel-build) and [docs/wow-quirks.md](./docs/wow-quirks.md).
- **Parent settings category is the landing page.** The parent never carries schema widgets — instead it shows the logo, TOC notes, and the slash-command list. `/wg config` opens the **parent** (`self._parentSettingsCategory:GetID()`) and reaches into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` (wrapped in `pcall` because that traversal is private Blizzard API) so every subcategory is visible in the sidebar tree. The user lands on the landing page with one click separating them from the General settings. The slash command also refuses to open during `InCombatLockdown()` because the Settings UI uses secure templates that can taint mid-combat. See [docs/wow-quirks.md](./docs/wow-quirks.md#settings-api-parent-vs-subcategory).
- **Join notify uses a dual-path trigger.** `WhatGroup:_TryFireJoinNotify(reason)` is the single entry point that schedules `ShowNotification` + `ShowFrame`. It's called from BOTH the `GROUP_ROSTER_UPDATE` not-in → in transition AND the `LFG_LIST_APPLICATION_STATUS_UPDATED` `inviteaccepted` handler — because retail can fire those in either order, and the old "fire only on roster transition when pendingInfo is set" gate would silently miss when `inviteaccepted` arrived after the transition. A `notifiedFor` identity flag (the `pendingInfo` reference that already triggered) prevents double-firing when both paths catch the same join.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor`, `notifyGen` never touch SavedVariables. Group-leave and the master-switch off-flip both route through `WhatGroup:WipeCapture()`, which clears all of them.
- **`WhatGroup:WipeCapture()` is the master-switch wipe.** Flipping `db.profile.enabled` to false mid-flight (via panel checkbox or `/wg set enabled false`) calls `WipeCapture` so any pending capture, queued capture, or already-scheduled notify callback can't surface after the user has explicitly disabled the addon. Same method is reused on group-leave.
- **Notify timer cancels via a generation counter.** `_TryFireJoinNotify` snapshots `notifyGen` before scheduling the `C_Timer.After(notify.delay, …)` callback; the callback bails if `notifyGen` was bumped (by `WipeCapture`) or if `pendingInfo` was replaced before the timer fired. Prevents an empty-data popup auto-opening during the delay window if the player leaves the group or toggles the master switch off.
- **Combat-defer for the secure popup.** `WhatGroup_Frame.lua` guards three secure-frame writes against `InCombatLockdown()`: (a) `ConfigureTeleportButton` stashes `info` and reruns on `PLAYER_REGEN_ENABLED`; (b) `WhatGroup:ShowFrame` defers the first-time `buildFrame()` past combat with a one-shot wait frame, printing a `Popup deferred until combat ends.` chat hint; (c) `Settings.Register()` self-guards on `InCombatLockdown()` as defense-in-depth atop the `runConfig` slash-handler refusal. Without these guards, secure-attribute writes on `SecureActionButtonTemplate` would silently drop in combat and leave the teleport button stuck in a stale state.
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
- `AceGUI-3.0` (loaded last via its `.xml`)

WoW retail APIs the addon depends on: `C_LFGList.ApplyToGroup` / `GetSearchResultInfo` / `GetActivityInfoTable`, `C_Spell.GetSpellTexture` / `GetSpellLink`, `C_Timer.After`, `IsInGroup`, `IsSpellKnown`, `CastSpellByID`, `SetItemRef`. Settings API: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`. Frame chrome: `BackdropTemplate`, `UISpecialFrames`.

## Load order

`WhatGroup.toc` is the source of truth. Order is dependency, not alphabetical:

1. **libs/** — `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceDB-3.0` → `AceGUI-3.0` (last; loaded via its `.xml` because that pulls in `widgets/`).
2. **`WhatGroup.lua`** — calls `AceAddon:NewAddon(existing, "WhatGroup", "AceConsole-3.0", "AceEvent-3.0")`, assigns `_G.WhatGroup`, then **at file-load top-level** installs the two direct `hooksecurefunc` post-hooks (on `C_LFGList.ApplyToGroup` and on `SetItemRef`). The hooks are deliberately registered before any later boot-time work runs, so GameMenu's `InitButtons` (which builds the Logout/Settings/Macros button closures during boot) sees a clean secure context. Defines `OnInitialize` / `OnEnable` / capture handlers / slash dispatch / `WhatGroup.Labels` namespace (`PLAYSTYLE` / `GetGroupTypeLabel` / `GetPlaystyleLabel`) consumed by both chat and popup output. Module-locals `captureQueue`, `pendingApplications`, `wasInGroup`, `notifiedFor`, `notifyGen` initialise to empty / `false` / `nil` / `0`.
3. **`data/TeleportSpells.lua`** — populates `WhatGroup.TeleportSpells` (mapID → Path-of spell ID lookup, keyed by the dungeon's instance map ID; values are either a single spellID or a `{ id1, id2 }` candidate list). Loaded after `WhatGroup.lua` so `_G.WhatGroup` exists at the assignment.
4. **`WhatGroup_Settings.lua`** — picks up the addon via `LibStub("AceAddon-3.0"):GetAddon("WhatGroup")`, stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, _refresherOrder, _panels, BuildDefaults, Register, EnsureResetPopup }`. `Helpers` covers schema access (`Get` / `RawSet` / `Set` / `FindSchema` / `ValidateSchema`), reset surfaces (`RestoreDefaults` / `RefreshAll`), and the panel-rendering surface (`CreatePanel` / `PatchAlwaysShowScrollbar` / `Section` / `RenderField` / `InlineButton` / `RenderSchema` / `BuildMainContent`). `Helpers.Set` is the orchestrated single write-path — writes through `RawSet`, fires the row's `onChange`, then runs `RefreshAll` (with `opts.skipOnChange` / `opts.skipRefresh` escape hatches). Schema rows are appended via `add{}` calls in source order. `Settings.EnsureResetPopup()` lazily writes `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` on first call — writing to that table at file-load taints Blizzard's GameMenu callbacks, so it's deferred to first Defaults-button click or `/wg reset`.
5. **`WhatGroup_Frame.lua`** — file-load runs only the AceAddon lookup and the `WhatGroup:ShowFrame()` method assignment; everything else (the `WhatGroupFrame` itself, the secure teleport button, the `UISpecialFrames` registration, `MakeLabel` calls) is wrapped in a `buildFrame()` function called from the first `ShowFrame()`. Same lazy-creation reasoning as the Settings panel + reset popup. Close button + ESC handle the hide path; no programmatic Hide method is exposed.

Lifecycle:

- **`OnInitialize`** (fires on `ADDON_LOADED` for `"WhatGroup"`, after every TOC line has executed): `defaults = Settings.BuildDefaults()` → `db = AceDB:New("WhatGroupDB", defaults, true)` → seed `WhatGroup.debug` from `db.profile.debug` → register `/wg` and `/whatgroup` chat commands.
- **`OnEnable`** is intentionally minimal: register `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED` events, snapshot `wasInGroup = IsInGroup()`. **No hook installation, no Settings registration, no StaticPopup write.** Hooks are at file-load (above), Settings registers lazily on first `/wg config`, and the reset popup registers lazily on first reset request. Every addon-author write to a Blizzard-protected surface during the boot window leaks taint into the closures GameMenu builds for its buttons; deferring all of those means PLAYER_LOGIN finds the addon's secure footprint empty, GameMenu's `InitButtons` runs in a clean context, and Logout works correctly even after `/reload`.

`Settings.Register()` is itself called only from `runConfig`. It then defers the AceGUI body build to the parent and General subcategory's first `OnShow` (each behind its own one-shot guard). See [docs/settings-system.md](./docs/settings-system.md#lazy-panel-build).

If you add a new runtime file, put it in the right place in `WhatGroup.toc` (after libs, after the file it depends on).
