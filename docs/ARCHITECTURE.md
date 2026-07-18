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
                              self:ScheduleTimer(notify.delay)   (AceTimer-3.0)
                                      ├─ ShowNotification   chat output
                                      └─ ShowFrame          popup dialog (if frame.autoShow)

  Settings.Schema  ─►  panel widget + /wg list/get/set + AceDB defaults + /wg reset
  COMMANDS table   ─►  /wg help + /wg <verb> dispatch
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-file responsibility map | `WhatGroup.toc`, `core/WhatGroup.lua`, `defaults/TeleportSpells.lua`, `settings/Schema.lua`, `settings/Panel.lua`, `modules/Frame.lua` | [docs/file-index.md](./file-index.md) |
| Boundary decisions (in / out of scope, resolved choices) | — | [docs/scope.md](./scope.md) |
| LFG capture pipeline + queue mechanics + `hooksecurefunc` on `SetItemRef` | `core/WhatGroup.lua` | [docs/capture-pipeline.md](./capture-pipeline.md) |
| Settings schema, panel renderer, helpers, db.profile shape | `settings/Schema.lua`, `settings/Panel.lua` | [docs/settings-system.md](./settings-system.md) |
| `/wg` slash UX + `COMMANDS` table | `core/WhatGroup.lua` | [docs/slash-dispatch.md](./slash-dispatch.md) |
| On-screen debug console + `NS.Debug` sink | `core/DebugLog.lua` | [docs/debug-console.md](./debug-console.md) |
| Popup dialog (`WhatGroupFrame`) | `modules/Frame.lua` | [docs/frame.md](./frame.md) |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | — | [docs/wow-quirks.md](./wow-quirks.md) |
| Routine recipes (add a setting, add a command, refresh libs) | — | [docs/common-tasks.md](./common-tasks.md) |
| Manual smoke tests (boot health, slash, settings panel, `/wg test`, real LFG, regression checks) | — | [docs/smoke-tests.md](./smoke-tests.md) |

## Invariants worth not breaking

- **Observation-only, direct hooksecurefunc only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Both hooks are direct `hooksecurefunc` post-hooks: one on `C_LFGList.ApplyToGroup` (for capture) and one on `SetItemRef` filtered to `WhatGroup:` link clicks. No AceHook `SecureHook` / `RawHook` — AceHook adds a per-invocation bookkeeping closure around the callback, and that closure taints the secure-execute chain that Blizzard runs when the player clicks the GameMenu's Logout button (surfacing as `ADDON_ACTION_FORBIDDEN ... 'callback()'`). Direct `hooksecurefunc` has no closure on our side, no taint.
- **Schema-first.** Adding a setting = one row in `Settings.Schema`. The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Slash-first.** Adding a command = one row in `COMMANDS`. Help output iterates the table.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — the third arg `true` shares one `Default` profile across every character on the account. WhatGroup is account-wide by design.
- **`Settings.Register()` is idempotent.** The `WhatGroup._settingsRegistered` guard means it can be called multiple times without re-registering categories. It runs from `OnEnable` (PLAYER_LOGIN) so the panel is in the Settings → AddOns list at login — the same place every other Ka0s addon registers — and again, as a no-op, from `runConfig`. Registering a canvas category at login is taint-safe; WhatGroup's real boot-taint sources (the secure teleport button + `UISpecialFrames` insert) stay deferred in `modules/Frame.lua`. See [docs/settings-system.md](./settings-system.md#lazy-panel-build) and [docs/wow-quirks.md](./wow-quirks.md).
- **Parent settings category is the landing page.** The parent never carries schema widgets — instead it shows the logo, TOC notes, and the slash-command list. `/wg config` opens the **parent** (`self._parentSettingsCategory:GetID()`) and reaches into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` (wrapped in `pcall` because that traversal is private Blizzard API) so every subcategory is visible in the sidebar tree. The user lands on the landing page with one click separating them from the General settings. The slash command also refuses to open during `InCombatLockdown()` because the Settings UI uses secure templates that can taint mid-combat. See [docs/wow-quirks.md](./wow-quirks.md#settings-api-parent-vs-subcategory).
- **Join notify uses a dual-path trigger.** `WhatGroup:_TryFireJoinNotify(reason)` is the single entry point that schedules `ShowNotification` + `ShowFrame`. It's called from BOTH the `GROUP_ROSTER_UPDATE` not-in → in transition AND the `LFG_LIST_APPLICATION_STATUS_UPDATED` `inviteaccepted` handler — because retail can fire those in either order, and the old "fire only on roster transition when pendingInfo is set" gate would silently miss when `inviteaccepted` arrived after the transition. A `notifiedFor` identity flag (the `pendingInfo` reference that already triggered) prevents double-firing when both paths catch the same join.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor`, and the `self.notifyTimer` AceTimer handle never touch SavedVariables. Group-leave and the master-switch off-flip both route through `WhatGroup:WipeCapture()`, which clears all of them.
- **`WhatGroup:WipeCapture()` is the master-switch wipe.** Flipping `db.profile.enabled` to false mid-flight (via panel checkbox or `/wg set enabled false`) calls `WipeCapture` so any pending capture, queued capture, or already-scheduled notify callback can't surface after the user has explicitly disabled the addon. Same method is reused on group-leave.
- **Notify timer is an AceTimer one-shot, cancelled by `WipeCapture`.** `_TryFireJoinNotify` schedules the notify via `self:ScheduleTimer(fn, notify.delay)` (AceTimer-3.0) and stashes the handle in `self.notifyTimer`; `WipeCapture` `self:CancelTimer`s it so a scheduled callback can't fire after group-leave or the master-switch off-flip. The callback also re-checks `self.pendingInfo` identity before firing, guarding a same-tick replacement. Prevents an empty-data popup auto-opening during the delay window.
- **Combat-defer for the secure popup.** `modules/Frame.lua` guards three secure-frame writes against `InCombatLockdown()`: (a) `ConfigureTeleportButton` stashes `info` and reruns on `PLAYER_REGEN_ENABLED`; (b) `WhatGroup:ShowFrame` defers the first-time `buildFrame()` past combat with a one-shot wait frame, printing a `Popup deferred until combat ends.` chat hint; (c) `Settings.Register()` self-guards on `InCombatLockdown()` as defense-in-depth atop the `runConfig` slash-handler refusal. Without these guards, secure-attribute writes on `SecureActionButtonTemplate` would silently drop in combat and leave the teleport button stuck in a stale state.
- **Cyan `[WG]` chat prefix on every user-facing line, through one secret-safe printer.** Every chat line funnels through `NS.Util.print` (`core/Util.lua`), exposed as `NS.Print` / `WhatGroup._print` and aliased to a file-local `p` in `core/WhatGroup.lua`. It prepends `NS.PREFIX = "\|cff00FFFF[WG]\|r"` and runs each argument through `NS.SafeToString`, so a combat-protected value degrades to `<secret>` instead of raising in the chat path (events-frames-taint-§8 / WG-22); call sites pass label and value as **separate args** rather than pre-concatenating (WG-23). **Debug output does not go to chat** — it routes to the on-screen debug console (`NS.Debug(tag, …)` → `core/DebugLog.lua`), styled like the main window, as required for any addon with a main window (debug-logging-§7). Each console line is `HH:MM:SS | [Tag] message`. Debug state is session-only (`NS.State.debug`), off on every login, never persisted. See [docs/debug-console.md](./debug-console.md).
- **Delayed timers use AceTimer-3.0 (WG-17).** AceTimer is the standard's mandated timer lib and is mixed into the addon (`NewAddon(…, "AceTimer-3.0")`). The one-shot notify delay runs through `self:ScheduleTimer(fn, delay)` with the handle stashed in `self.notifyTimer` and cancelled by `WipeCapture` via `self:CancelTimer`. The two `C_Timer.After(0, …)` calls that remain are next-frame secure-defer hops (moving panel/frame builds out of Blizzard's secure-execute chain) — a taint-avoidance idiom, not delayed timers, so they stay raw and each carries a justification comment.
- **Debug console uses a vendored monospace font, not a Blizzard font (deliberate, WG-20).** The debug-logging standard (§2) requires the on-screen console to render monospace, but retail ships no guaranteed monospace face — so JetBrains Mono (OFL) is vendored under `media/fonts/` and registered with LibSharedMedia. It's the only non-Blizzard default font in the addon; every other FontString uses a `GameFont*` object. A deviation from the addon's Blizzard-default-only baseline, not from the standard. Justification comment at `NS.FONT_MONO` in `core/WhatGroup.lua`.
- **Settings landing page shows a vendored brand-logo texture (deliberate, WG-21).** `settings/Panel.lua` draws the addon's own `media/logos/whatgroup.logo.tga` — the only non-Blizzard default texture in the addon; every backdrop, border, and divider elsewhere is a Blizzard asset (`WHITE8X8`, `UI-Tooltip-Border`, the `Options_HorizontalDivider` atlas, spell icons). Branding art, analogous to the TOC `IconTexture`; no standards section mandates Blizzard-only textures, so this is a deviation from the addon's Blizzard-default-only baseline, not from the standard.
- **Lazy AceGUI panel build.** Both the parent landing page and the General subcategory build their body on first `OnShow` (each behind its own one-shot guard). The AceGUI ScrollFrame parented to each panel hooks `OnSizeChanged` to forward dimensions into AceGUI's layout pipeline. Without this, parented-to-Blizzard containers stay at 0×0. See [docs/wow-quirks.md](./wow-quirks.md#lazy-acegui-panel-build).
- **Defaults button + `/wg reset` share one popup.** Both routes call `StaticPopup_Show("WHATGROUP_RESET_ALL")`; the OnAccept body lives in `settings/Schema.lua` and calls `Helpers.RestoreDefaults()`. No second confirmation path can drift from the first.
- **Don't overwrite `category.ID`.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.

## External dependencies

All vendored under `libs/` and copied verbatim from Ka0s KickCD:

- `LibStub`
- `CallbackHandler-1.0`
- `AceAddon-3.0`
- `AceEvent-3.0`
- `AceConsole-3.0`
- `AceTimer-3.0` — the mandated timer lib (WG-17); backs the one-shot notify delay
- `AceDB-3.0`
- `AceGUI-3.0` (loaded via its `.xml`)
- `LibSharedMedia-3.0` (loaded last via its `lib.xml`; copied from Ka0s AbsorbTracker) — the media registry the debug console's JetBrains Mono font registers with

WoW retail APIs the addon depends on: `C_LFGList.ApplyToGroup` / `GetSearchResultInfo` / `GetActivityInfoTable`, `C_Spell.GetSpellName` / `GetSpellTexture` / `GetSpellLink`, `C_Timer.After`, `IsInGroup`, `IsSpellKnown`, `SetItemRef`. Teleport casting goes through a `SecureActionButtonTemplate` `macrotext` (`/cast <SpellName>`) — **not** `CastSpellByID`, which a non-secure addon click would trip `ADDON_ACTION_FORBIDDEN` on. Settings API: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`. Frame chrome: `BackdropTemplate`, `SecureActionButtonTemplate`, `UISpecialFrames`.

## Load order

`WhatGroup.toc` is the source of truth. Order is dependency, not alphabetical:

Every source file starts with `local addonName, NS = ...` — `NS` is the addon's
private namespace, shared across files (WG-01). There is **no `_G.WhatGroup`**.

1. **libs/** — `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceTimer-3.0` → `AceDB-3.0` → `AceGUI-3.0` (via its `.xml`, because that pulls in `widgets/`) → `LibSharedMedia-3.0` (last, via its `lib.xml`).
2. **`locales/enUS.lua`** — `NS.L`, a metatable shell whose missing keys return themselves. Loads first among the addon files (the `# Locales` section precedes `# Core`, toc-file-§5 / WG-14), so `NS.L` is available to every later file; callers still reference `NS.L[...]` at runtime by convention. Every string the addon authors is routed through it (localization-§3 / WG-07).
3. **`core/Util.lua`** — hangs the shared low-level seams on `NS`: `NS.IsConcatSafe` / `NS.SafeToString` (the secret-safe stringifier, events-frames-taint-§8 / WG-22), `NS.Util.print` (the single secret-safe chat printer, reclaimed as `NS.Print` / `WhatGroup._print` by `core/WhatGroup.lua`), and `NS.Windows` (standalone-window geometry persistence, WG-26). Loads first in `# Core` so those seams exist before any later file captures or calls them.
4. **`core/Compat.lua`** — hangs `NS.Compat` on the shared namespace. Version-variant spell / LFG shims (`GetSpellName` / `GetSpellInfo` / `GetSpellTexture` / `GetSpellLink` / `IsSpellKnown` / `GetActivityInfoTable`); the SOLE caller of `C_Spell.*` / legacy globals / `C_LFGList.GetActivityInfoTable`.
5. **`core/Database.lua`** — `NS.SCHEMA_VERSION` + `NS:RunMigrations()` (idempotent, called once after `AceDB:New`); establishes the migration seam (WG-08).
6. **`core/DebugLog.lua`** — hangs `NS.DebugLog` + the `NS.Debug(tag, fmt, …)` sink on the namespace. The sink is secret-safe: it `pcall`s `string.format` and, on failure, rebuilds the line from `NS.SafeToString`'d args (WG-22). Lazily builds the `WhatGroupDebugWindow` console (monospace, `DIALOG` strata) and its Copy window on first use; the console persists its position via `NS.Windows` (WG-26). Loads **before** `core/WhatGroup.lua` so `NS.Debug` exists before any runtime handler or the font registration runs. (Reads `NS.FONT_MONO`, set by `core/WhatGroup.lua`, only at frame-build time — runtime, so the forward reference is safe.)
7. **`core/WhatGroup.lua`** — `local WhatGroup = AceAddon:NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")` (mixes Ace methods, incl. `ScheduleTimer`/`CancelTimer`, into `NS`; `NS.addon = WhatGroup`). Seeds `NS.State.debug=false`, `NS.PREFIX`, aliases the `core/Util.lua` printer as the file-local `p` / `NS.Print` / `WhatGroup._print`, and `NS.FONT_MONO` (registering the vendored JetBrains Mono with LibSharedMedia). Then **at file-load top-level** installs the two direct `hooksecurefunc` post-hooks (on `C_LFGList.ApplyToGroup` and on `SetItemRef`), before any later boot-time work, so GameMenu's `InitButtons` sees a clean secure context. Defines `OnInitialize` / `OnEnable` / capture handlers / slash dispatch / `WhatGroup.Labels` (`PLAYSTYLE` / `GetGroupTypeLabel` / `GetPlaystyleLabel`). Module-locals `captureQueue`, `pendingApplications`, `wasInGroup`, `notifiedFor` initialise to empty / `false` / `nil`; the notify timer handle lives on `self.notifyTimer` (AceTimer). Its user-facing strings reference `NS.L[...]` at **runtime**; `NS.L` is already available since `locales/enUS.lua` now loads first.
8. **`defaults/Profile.lua`** — hangs `NS.C`, the nested table of profile default VALUES (savedvariables-§2 / WG-24). Each `settings/Schema.lua` row references its value via `default = NS.C.<path>`, so values live here and the schema stays the single source of structure. Loads before `settings/Schema.lua` (the `# Defaults` section precedes `# Settings`).
9. **`defaults/TeleportSpells.lua`** — populates `NS.TeleportSpells` (mapID → Path-of spell ID lookup; values are a single spellID or a `{ id1, id2 }` candidate list). Writes straight to `NS`, so load order relative to `core/WhatGroup.lua` is irrelevant.
10. **`modules/Frame.lua`** — `local WhatGroup = NS.addon`; file-load runs only the `WhatGroup:ShowFrame()` method assignment. Everything else (the `WhatGroupFrame`, the secure teleport button, the `UISpecialFrames` registration, `MakeLabel` calls) is wrapped in `buildFrame()`, called from the first `ShowFrame()`; the popup persists its position via `NS.Windows` (WG-26). Loads after `# Core` (needs `NS.addon` / `NS.L` / `NS.Windows`) and before `# Settings`, referencing nothing from the settings layer at load. Same lazy-creation reasoning as the Settings panel + reset popup.
11. **`settings/Schema.lua`** — `local WhatGroup = NS.addon`, `local C = NS.C`; stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, _refresherOrder, _panels }` and its schema/db `Helpers`: schema access (`Get` / `RawSet` / `Set` / `FindSchema` / `ValidateSchema`), defaults (`BuildDefaults`, which threads each row's `default = C.<path>` into the profile and seeds `global.schemaVersion` + an empty `global.windows`), and reset surfaces (`RestoreDefaults` / `RefreshAll`). `Helpers.Set` is the orchestrated single write-path — writes through `RawSet`, fires the row's `onChange`, then runs `RefreshAll`. `Settings.EnsureResetPopup()` lazily writes `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` on first use — writing at file-load taints GameMenu callbacks.
12. **`settings/Panel.lua`** — the Blizzard canvas-layout settings panel (landing page + General sub-page). Adds the panel-rendering `Helpers` (`CreatePanel` / `PatchAlwaysShowScrollbar` / `Section` / `RenderField` / `InlineButton` / `RenderSchema` / `BuildMainContent`) and `Settings.Register`. `Register` runs from `OnEnable` (so the panel is registered at login) and again as an idempotent no-op from `runConfig`; guarded by `WhatGroup._settingsRegistered` and self-guarded against `InCombatLockdown()`. Renders the schema (`settings/Schema.lua`) as AceGUI widgets. Loads last (the `# Settings` section is final, toc-file-§5 / WG-14).

Lifecycle:

- **`OnInitialize`** (fires on `ADDON_LOADED` for `"WhatGroup"`, after every TOC line has executed): `defaults = Settings.BuildDefaults()` → `db = AceDB:New("WhatGroupDB", defaults, true)` → `self:RunMigrations()` → register `/wg` and `/whatgroup` chat commands. Debug state is session-only (`NS.State.debug`), **not** seeded from SavedVariables.
- **`OnEnable`** registers `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED`, snapshots `wasInGroup = IsInGroup()`, and registers the Settings panel so the AddOns entry appears at login. **No hook installation** here — hooks are at file-load (above). The popup's secure teleport button + `UISpecialFrames` insert (the real boot-taint sources) stay deferred to first `ShowFrame()`, and the reset popup registers lazily on first reset request — so GameMenu's `InitButtons` still runs in a clean context and Logout works correctly even after `/reload`.

`Settings.Register()` runs at `OnEnable` (and again as a no-op from `runConfig`). It defers the AceGUI body build to the parent and General subcategory's first `OnShow` (each behind its own one-shot guard). See [docs/settings-system.md](./settings-system.md#lazy-panel-build).

If you add a new runtime file, put it in the right place in `WhatGroup.toc` (after libs, after the file it depends on).
