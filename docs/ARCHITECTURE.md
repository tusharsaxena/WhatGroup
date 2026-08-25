# Architecture

Orient-yourself map for **Ka0s WhatGroup**. This file is the high-level index; topic detail lives in `docs/`.

## Overview

WhatGroup observes the Premade Group Finder (LFG) flow. It captures the group details visible on the search-result tile when the player applies, holds them across the application → invite → accept → join sequence, and resurfaces them once the player is actually in the group as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells.

The addon is observation-only. It never modifies LFG state, never auto-applies, and never blocks the join flow — both hooks are direct `hooksecurefunc` post-hooks (one on `C_LFGList.ApplyToGroup` for capture, one on `SetItemRef` filtered to `WhatGroup:` link clicks). No AceHook wrappers — those leave per-invocation closures that taint Blizzard's secure-execute chain on Logout.

## Module Map

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
  COMMANDS table   ─►  /wg help + /wg <verb> dispatch + the settings landing page

  Six of those arrows are LibKa0s-owned. The addon supplies a descriptor per
  module and the library owns the rest:

    core/CoreSetup.lua      ─►  LibKa0s-Core-1.0      printer, secret-safe seam, window skin
    core/MediaSetup.lua     ─►  LibKa0s-Media-1.0     NS.Icon / NS.MediaFont over the shipped catalog
    core/EnvSetup.lua       ─►  LibKa0s-Env-1.0       the TOC-metadata reader (version, Notes)
    core/DebugLogSetup.lua  ─►  LibKa0s-DebugLog-1.0  the console, both formatters, the buffer
    settings/OptionsSetup   ─►  LibKa0s-Options-1.0   canvas shell, widget makers, flow engine
    settings/Slash.lua      ─►  LibKa0s-Slash-1.0     dispatcher, help, the schema CLI
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-file responsibility map | `WhatGroup.toc`, `core/WhatGroup.lua`, `defaults/TeleportSpells.lua`, `settings/Schema.lua`, `settings/Panel.lua`, `modules/Frame.lua` | [docs/module-map.md](./module-map.md) |
| Boundary decisions (in / out of scope, resolved choices) | — | [docs/scope.md](./scope.md) |
| LFG capture pipeline + queue mechanics + `hooksecurefunc` on `SetItemRef` | `core/WhatGroup.lua` | [docs/data-flow.md](./data-flow.md) |
| Settings schema, panel wiring, helpers, db.profile shape | `settings/Schema.lua`, `settings/OptionsSetup.lua`, `settings/Panel.lua` | [docs/settings-panel.md](./settings-panel.md) |
| `/wg` slash UX + `COMMANDS` table | `settings/Slash.lua` | [docs/slash-dispatch.md](./slash-dispatch.md) |
| On-screen debug console + `NS.Debug` sink | `core/DebugLogSetup.lua` | [docs/debug.md](./debug.md) |
| The shared library, its six seams and the degraded install | `libs/LibKa0s/`, `core/CoreSetup.lua`, `core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` | this file, below |
| Popup dialog (`WhatGroupFrame`) | `modules/Frame.lua` | [docs/frame.md](./frame.md) |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | — | [docs/midnight-quirks.md](./midnight-quirks.md) |
| Routine recipes (add a setting, add a command, refresh libs) | — | [docs/common-tasks.md](./common-tasks.md) |
| Verification model (headless harness, mock fidelity, `--list` inventory + badge sync) | `tests/` | [docs/testing.md](./testing.md) |
| Manual smoke tests (boot health, slash, settings panel, `/wg test`, real LFG, regression checks) | — | [docs/smoke-tests.md](./smoke-tests.md) |

## Settings Schema

Ten rows, all profile-scoped, declared in `settings/Schema.lua` and valued in `defaults/Profile.lua`
(`NS.C`) — the schema owns the STRUCTURE, `NS.C` owns the VALUES (savedvariables-§2 / WG-24):

| Path | Type | Panel group |
|---|---|---|
| `enabled` | bool | General — the master switch; its `onChange` off-flip calls `WhatGroup:WipeCapture()` |
| `frame.autoShow` | bool | General — open the popup automatically on join |
| `notify.enabled` | bool | General — print the chat summary on join |
| `notify.delay` | number | Notify — seconds to wait before notify + popup (`0` = instant) |
| `notify.showInstance` | bool | Notify — line toggles |
| `notify.showType` | bool | Notify |
| `notify.showLeader` | bool | Notify |
| `notify.showPlaystyle` | bool | Notify |
| `notify.showClickLink` | bool | Notify |
| `notify.showTeleport` | bool | Notify |

The account-wide `global` table carries `schemaVersion` and `windows` (standalone-window geometry,
WG-26) and no schema rows. Reads and writes go through `Helpers.Get` / `Helpers.Set` — `Set` is the
orchestrated single write-path (`RawSet` → the row's `onChange` → `RefreshAll`), and `Get` on an
unknown path returns nil **without materializing parent tables**. Detail:
[docs/settings-panel.md](./settings-panel.md).

## Message Bus

**There is none, because** WhatGroup is a single-addon capture pipeline with no cross-module
publish/subscribe need: `grep -rn "SendMessage\|RegisterMessage" core modules settings defaults`
returns nothing. The capture path calls `WhatGroup:_TryFireJoinNotify(reason)` directly, and that
one entry point is the coordination seam a bus would otherwise provide — the `notifiedFor` identity
flag, not a message, is what keeps the two trigger paths from double-firing. If a second consumer of
join data ever appears, AceEvent-3.0's `SendMessage` is already mixed in and is the route to take.

## Slash Commands

`/wg` (alias `/whatgroup`), dispatched by `LibKa0s-Slash-1.0` over the `COMMANDS` table in
`settings/Slash.lua`. Rows are **positional triples** — `{ name, description, handler }`, handler
taking `rest` alone — and the same table is published as `WhatGroup.COMMANDS` so the settings
landing page renders exactly what the dispatcher runs.

| Verb | Owner | Does |
|---|---|---|
| `help` | library | Lists every row |
| `show` | host | Re-opens the popup for the current group |
| `test` | host | Injects synthetic group info and runs the full notify + frame flow |
| `config` | host | Opens the settings panel (refused in combat, inside `OpenOptionsPanel`) |
| `version` | library | Prints the addon version |
| `list` / `get` / `set` | library | The schema CLI, over the ten rows above |
| `reset` | host | Resets **one** path — `/wg reset <path>`, no confirmation ([`LIBKA0S-13`](https://github.com/tusharsaxena/WhatGroup/issues/8)) |
| `resetall` | host | Resets everything, behind the shared `WHATGROUP_RESET_ALL` popup |
| `debug` | host | Opens/closes the debug console; `on|off` toggles logging |

`perf` stays a reserved verb (`slash-commands-§2`) and is deliberately not registered — see
`## Documented deviations`. Detail: [docs/slash-dispatch.md](./slash-dispatch.md).

## Event Subscriptions

Small and deliberately so — the whole surface, from `grep -rn "RegisterEvent\|hooksecurefunc"`:

| Registered | Where | Handler does |
|---|---|---|
| `GROUP_ROSTER_UPDATE` | `core/WhatGroup.lua` `OnEnable` | Detects the not-in → in transition and calls `_TryFireJoinNotify("ROSTER transition")`; on leave, `WipeCapture()` |
| `LFG_LIST_APPLICATION_STATUS_UPDATED` | `core/WhatGroup.lua` `OnEnable` | Advances the application queue; on `inviteaccepted` sets `pendingInfo` and calls `_TryFireJoinNotify("inviteaccepted")` |
| `PLAYER_REGEN_ENABLED` | `modules/Frame.lua` (two one-shot frames) | Re-runs the deferred `ConfigureTeleportButton` write, and the deferred first `buildFrame()` |
| `hooksecurefunc(C_LFGList, "ApplyToGroup")` | `core/WhatGroup.lua`, file-load | Records the group applied to |
| `hooksecurefunc("SetItemRef")` | `core/WhatGroup.lua`, file-load | Filtered to `WhatGroup:` links — re-opens the popup |

Both hooks are **direct post-hooks installed at file load**, never AceHook and never in `OnEnable`.
There is no `OnUpdate` handler anywhere in the addon, and exactly **one** repeating timer — the
teleport cooldown countdown at `modules/Frame.lua:146`, a 1-second `ScheduleRepeatingTimer` added
2026-08-06. The sweep behind both statements is in [`performance.md`](./performance.md), and the
ticker is what ended the no-combat-path exemption; the wiring is still declined, now as a ratified
deviation in its own right (see `## Documented deviations`).

The teleport button's cooldown swipe (`modules/Frame.lua`) costs nothing on top of that: a
`CooldownFrameTemplate` is driven engine-side once armed with `SetCooldown`, so the Lua side runs
exactly once per popup open. Its companion countdown text is what ticks — one
`C_Spell.GetSpellCooldown` and one `SetText` per second — and it cannot outlive the popup that
armed it: a single handle, replaced rather than stacked, cancelled from the popup's `OnHide`, from
the top of every `ConfigureTeleportButton` run, and by the tick that sees the cooldown reach zero.

## Taint Notes

- **No AceHook.** `SecureHook` / `RawHook` wrap the callback in a per-invocation bookkeeping closure,
  and that closure taints the secure-execute chain Blizzard runs for the GameMenu Logout button
  (`ADDON_ACTION_FORBIDDEN … 'callback()'`). Direct `hooksecurefunc` adds no closure of ours.
- **Hooks at file load, secure frames at first use.** The two post-hooks install at file-load top
  level so GameMenu's `InitButtons` sees a clean context; the popup's `SecureActionButtonTemplate`
  teleport button, its `UISpecialFrames` insert and the `WHATGROUP_RESET_ALL` popup registration are
  all deferred to first use.
- **Two combat guards, both in `modules/Frame.lua`.** `ConfigureTeleportButton` stashes `info` and
  reruns on `PLAYER_REGEN_ENABLED`; `ShowFrame` defers the first `buildFrame()` past combat with a
  one-shot wait frame and says so in chat. Both guard genuine secure-frame writes.
- **Category registration is not combat-gated** (options-ui-§9). Registering a canvas category
  never taints, and eager registration at load is a MUST; only panel *open* is refused, and that
  refusal lives inside `OpenOptionsPanel` so every caller gets it (options-ui-§2).
  `Settings.Register()` carried a third, defense-in-depth `InCombatLockdown()` guard until
  2026-08-05; it bought nothing and cost the AddOns-list entry on any `/reload` taken in combat.
- **Two `C_Timer.After(0, …)` hops are taint avoidance, not timers.** They move the panel and frame
  builds out of Blizzard's secure-execute chain; each carries a justification comment.
- **The chat path stringifies through `NS.SafeToString`**, so a combat-protected value degrades to
  `<secret>` instead of raising (events-frames-taint-§8 / WG-22).

## Invariants worth not breaking

- **Observation-only, direct hooksecurefunc only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Both hooks are direct `hooksecurefunc` post-hooks: one on `C_LFGList.ApplyToGroup` (for capture) and one on `SetItemRef` filtered to `WhatGroup:` link clicks. No AceHook `SecureHook` / `RawHook` — AceHook adds a per-invocation bookkeeping closure around the callback, and that closure taints the secure-execute chain that Blizzard runs when the player clicks the GameMenu's Logout button (surfacing as `ADDON_ACTION_FORBIDDEN ... 'callback()'`). Direct `hooksecurefunc` has no closure on our side, no taint.
- **Private `NS` namespace, no public global.** Every source file starts with `local addonName, NS = ...`; the AceAddon object is `NS.addon` (mixed into `NS`, aliased downstream as `local WhatGroup = NS.addon`). There is **no `_G.WhatGroup`** (WG-01). New standalone data/logic hangs on `NS.*` (`NS.Compat`, `NS.L`, `NS.State`, `NS.TeleportSpells`, `NS.PREFIX`, …). If a public surface is ever needed, expose only a versioned `NS.API.v1` via `_G[addonName]` — never the whole table.
- **Schema-first.** Adding a setting = one row in `Settings.Schema`. The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Slash-first.** Adding a command = one row in `COMMANDS` (`settings/Slash.lua`). The help index, the settings landing page and the dispatcher all iterate that one table. Rows are **positional triples** — `{ name, description, handler }` — and the handler takes `rest` alone, never `(self, rest)`: that is the shape `LibKa0s-Slash-1.0` reads, and a table of named fields is silently invisible to it.
- **The library seams degrade, they never error.** `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua` and `settings/Slash.lua` each resolve their major with `LibStub(major, true)` and fall back to a stub when it is absent. `core/CoreSetup.lua` publishes the one shared cause clause, **`NS.LIBKA0S_MISSING`**, *outside* its own `if not lib` branch, because the other three read it on both paths; each appends its own consequence (`", so the debug console window is unavailable."`, `", so the settings panel is unavailable."`, `", so the settings CLI is unavailable."`) and the Core fallback printer announces once with `"; running on reduced built-in fallbacks."`. A degraded install therefore says the same thing about **why** at every site and a different thing about **what** at each one. That is a cross-file contract, not an implementation detail of one file.
- **`settings/OptionsSetup.lua`'s stub is LOAD-COMPLETING, not member-answering** — the one documented exception (options-ui-§1). Its members are no-ops rather than honest-line printers because a page file that touched one *at file load* would raise and take a third of the schema with it. WhatGroup's measured load-time set is empty, and `tests/test_libka0s.lua` pins that by loading with the library absent and comparing the schema row count against a full load.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — the third arg `true` shares one `Default` profile across every character on the account. WhatGroup is account-wide by design.
- **`Settings.Register()` is idempotent.** The `WhatGroup._settingsRegistered` guard means it can be called multiple times without re-registering categories. It runs from `OnEnable` (PLAYER_LOGIN) so the panel is in the Settings → AddOns list at login — the same place every other Ka0s addon registers — and again, as a no-op, from `runConfig`. Registering a canvas category at login is taint-safe; WhatGroup's real boot-taint sources (the secure teleport button + `UISpecialFrames` insert) stay deferred in `modules/Frame.lua`. See [docs/settings-panel.md](./settings-panel.md#lazy-panel-build) and [docs/midnight-quirks.md](./midnight-quirks.md).
- **Parent settings category is the landing page.** The parent never carries schema widgets — instead it shows the logo, TOC notes, and the slash-command list. `/wg config` calls `Helpers.OpenOptionsPanel()` and nothing else: since the `LibKa0s-Options-1.0` adoption that member is the **library's**, and it holds the main category's own ID, opens the parent, and unfolds the sidebar tree through the private `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` traversal (`pcall`-wrapped, because that shape is Blizzard internals). `settings/Panel.lua` still records `WhatGroup._parentSettingsCategory` and `WhatGroup._settingsCategory`, but the open path does not read either. The `InCombatLockdown()` refusal lives inside `OpenOptionsPanel` too, so **every** caller is refused rather than just this verb (options-ui-§2). The user lands on the landing page with one click separating them from the General settings. See [docs/midnight-quirks.md](./midnight-quirks.md#settings-api-parent-vs-subcategory).
- **Join notify uses a dual-path trigger.** `WhatGroup:_TryFireJoinNotify(reason)` is the single entry point that schedules `ShowNotification` + `ShowFrame`. It's called from BOTH the `GROUP_ROSTER_UPDATE` not-in → in transition AND the `LFG_LIST_APPLICATION_STATUS_UPDATED` `inviteaccepted` handler — because retail can fire those in either order, and the old "fire only on roster transition when pendingInfo is set" gate would silently miss when `inviteaccepted` arrived after the transition. A `notifiedFor` identity flag (the `pendingInfo` reference that already triggered) prevents double-firing when both paths catch the same join.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor`, and the `self.notifyTimer` AceTimer handle never touch SavedVariables. Group-leave and the master-switch off-flip both route through `WhatGroup:WipeCapture()`, which clears all of them.
- **`WhatGroup:WipeCapture()` is the master-switch wipe.** Flipping `db.profile.enabled` to false mid-flight (via panel checkbox or `/wg set enabled false`) calls `WipeCapture` so any pending capture, queued capture, or already-scheduled notify callback can't surface after the user has explicitly disabled the addon. Same method is reused on group-leave.
- **Notify timer is an AceTimer one-shot, canceled by `WipeCapture`.** `_TryFireJoinNotify` schedules the notify via `self:ScheduleTimer(fn, notify.delay)` (AceTimer-3.0) and stashes the handle in `self.notifyTimer`; `WipeCapture` `self:CancelTimer`s it so a scheduled callback can't fire after group-leave or the master-switch off-flip. The callback also re-checks `self.pendingInfo` identity before firing, guarding a same-tick replacement. Prevents an empty-data popup auto-opening during the delay window.
- **Combat-defer for the secure popup.** `modules/Frame.lua` guards two secure-frame writes against `InCombatLockdown()`: (a) `ConfigureTeleportButton` stashes `info` and reruns on `PLAYER_REGEN_ENABLED`; (b) `WhatGroup:ShowFrame` defers the first-time `buildFrame()` past combat with a one-shot wait frame, printing a `Popup deferred until combat ends.` chat hint. Without these guards, secure-attribute writes on `SecureActionButtonTemplate` would silently drop in combat and leave the teleport button stuck in a stale state. `Settings.Register()` is **not** a third case — canvas-category registration is not a secure write and is not gated (options-ui-§9).
- **Cyan `[WG]` chat prefix on every user-facing line, through one secret-safe printer.** Every chat line funnels through `NS.Util.print` — `LibKa0s-Core-1.0`'s printer, built in `core/CoreSetup.lua` and exposed as `NS.Print` / `WhatGroup._print` and a file-local `p` in `core/WhatGroup.lua`. It prepends `NS.PREFIX = "\|cff00FFFF[WG]\|r"` and runs each argument through `NS.SafeToString`, so a combat-protected value degrades to `<secret>` instead of raising in the chat path (events-frames-taint-§8 / WG-22); call sites pass label and value as **separate args** rather than pre-concatenating (WG-23). **Debug output does not go to chat** — it routes to the on-screen debug console (`NS.Debug(tag, …)` → `LibKa0s-DebugLog-1.0`, wired in `core/DebugLogSetup.lua`), wearing the same shared Ka0s window edge the popup does, as required for any addon with a main window (debug-logging-§7). Each console line is `HH:MM:SS | [Tag] message`. The log carries a thin always-shown scrollbar synced both ways to its scroll offset and a `N / 1500 lines` counter in the same monospace font (debug-logging-§11), driven only by the Lua mixin scroll API — the C getters are nil on a `ScrollingMessageFrame` (anti-pattern #41). Debug state is session-only (`NS.State.debug`), off on every login, never persisted. See [docs/debug.md](./debug.md).
- **Debug state is session-only, and the console is the only sink.** `NS.State.debug` (debug-logging-§5 / WG-12) is **off** on every login, is **not** a schema row, and is never written to SavedVariables — don't reintroduce a `db.profile.debug`, and don't add a chat `[DBG]` sink. `/wg debug` toggles the console **window**; `/wg debug on|off` toggles logging — both route through the single `NS.DebugLog:SetEnabled` seam. See [docs/debug.md](./debug.md).
- **English-only, but the locale shell is mandatory.** Every *player-facing* string the addon authors is routed through `NS.L[...]` (`locales/enUS.lua`), whose fall-back metatable returns the key, so English needs no translation table. Three classes stay unrouted on purpose — slash-CLI diagnostics, strings that double as identifiers (`"General"`, `"Ka0s WhatGroup"`), and strings `LibKa0s-Options-1.0` authors — and that partial routing is a **ratified deviation**, listed with its reasoning and its re-check trigger in [`## Documented deviations`](#documented-deviations) below. Localization *content* is a deliberate non-goal ([docs/scope.md](./scope.md)); the locale *shell* (localization-§3 / WG-07) stays. Playstyle enum values still read Blizzard's `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` globals — those are Blizzard's strings, not ours.
- **Delayed timers use AceTimer-3.0 (WG-17).** AceTimer is the standard's mandated timer lib and is mixed into the addon (`NewAddon(…, "AceTimer-3.0")`). The one-shot notify delay runs through `self:ScheduleTimer(fn, delay)` with the handle stashed in `self.notifyTimer` and canceled by `WipeCapture` via `self:CancelTimer`. The two `C_Timer.After(0, …)` calls that remain are next-frame secure-defer hops (moving panel/frame builds out of Blizzard's secure-execute chain) — a taint-avoidance idiom, not delayed timers, so they stay raw and each carries a justification comment.
- **Debug console uses a non-Blizzard monospace font (deliberate; WG-20, now closed into the library-stack media rule).** The debug-logging standard (debug-logging-§2) requires the on-screen console to render monospace, but retail ships no guaranteed monospace face — so JetBrains Mono (OFL) is used. **It is no longer this addon's copy.** WG-20 justified vendoring one under `media/fonts/`; the face now arrives with the LibKa0s payload at `libs/LibKa0s/media/fonts/`, and `core/MediaSetup.lua` resolves it through `LibKa0s-Media-1.0` (library-stack-§8). What was a per-addon deviation is now the collection's shared media rule, and a private copy of it would be anti-pattern #63. It is still the only non-Blizzard default font the addon draws with; every other FontString uses a `GameFont*` object. Resolution at `NS.FONT_MONO` in `core/WhatGroup.lua`, which falls back to the client's own `STANDARD_TEXT_FONT` — never to a dead path, because `SetFont` fails silently. `core/DebugLogSetup.lua` then probes the resolved path with `CreateFont` before handing it to the library and substitutes `Fonts\\ARIALN.TTF` if the client cannot fetch it — debug-logging-§2's fetch-failure fallback, now the third rung of the ladder rather than the second.
- **Settings landing page shows a vendored brand-logo texture (deliberate, WG-21).** `settings/Panel.lua` draws the addon's own `media/logos/whatgroup.logo.tga` — the only non-Blizzard default texture in the addon; every backdrop, border, and divider elsewhere is a Blizzard asset (`WHITE8X8`, `UI-Tooltip-Border`, the `Options_HorizontalDivider` atlas, spell icons). Branding art, analogous to the TOC `IconTexture`; no standards section mandates Blizzard-only textures, so this is a deviation from the addon's Blizzard-default-only baseline, not from the standard.
- **Lazy AceGUI panel build, plus this addon's extra frame hop.** The library owns *when* a page draws — first `OnShow`, and again when a refresh marked a hidden page dirty — and it calls the renderer and `EnsureDefaultsButton` **synchronously** inside that `OnShow`. WhatGroup does not: `settings/OptionsSetup.lua` wraps both members **on the instance** so the work runs on the next frame, because Blizzard's GameMenu / Logout flows can dispatch a settings canvas's `OnShow` inside a secure-execute chain and creating AceGUI frames there was tripping `ADDON_ACTION_FORBIDDEN` on the Logout button. Wrapped on the instance rather than beside it, because the library resolves both from `O` at call time. Host-shaped, so it stayed local (`LIBKA0S-07`); options-ui-§9 sanctions the library's synchronous form, and this is the addon keeping a belt it had already fastened. The AceGUI ScrollFrame parented to each panel hooks `OnSizeChanged` to forward dimensions into AceGUI's layout pipeline. Without this, parented-to-Blizzard containers stay at 0×0. The header's **Defaults button builds in that same deferred hop** rather than at `Settings.Register` time: it's an AceGUI widget, and UI skins restyle those by hooking `RegisterAsWidget`, so one created during load keeps Blizzard's stock red button art for the session (options-ui-§5). Its click handler is parked at registration as `panel.defaultsOnClick` and wired by the builder. See [docs/settings-panel.md](./settings-panel.md#lazy-panel-build) and [docs/midnight-quirks.md](./midnight-quirks.md#lazy-acegui-panel-build).
- **Defaults button + `/wg resetall` share one popup.** Both routes call `StaticPopup_Show("WHATGROUP_RESET_ALL")`; the OnAccept body lives in `settings/Schema.lua` and calls `Helpers.RestoreAllDefaults()`. No second confirmation path can drift from the first. **`/wg reset` now takes a PATH** and resets one row without confirmation — a breaking change taken deliberately ([`LIBKA0S-13`](https://github.com/tusharsaxena/WhatGroup/issues/8)), because `reset` means one row everywhere else in the collection. A bare `/wg reset` is intercepted and answered with both replacements rather than with a usage line.
- **`Helpers.RestoreAllDefaults` deliberately OVERRIDES the library's.** `LibKa0s-Options-1.0` ships a member of that name and this addon's wins: it wipes `db.profile` before re-threading the defaults, which is what drops a value from a removed or renamed schema row, and it coalesces the per-row `[Set]` lines into one `[Reset]` summary (debug-logging-§9). The library's per-page `RestoreDefaults(pageKey, ctx)` is a different verb with a different arity and is left alone. Copying the host's members onto the instance only where the instance was nil silently handed callers the library's row-by-row form — see [`LIBKA0S-08`](https://github.com/tusharsaxena/WhatGroup/issues/10).
- **`Settings.Helpers` IS the library instance** (options-ui-§1), decorated in place: `settings/Schema.lua`'s data seams move *onto* it, never the library's members into a host table. `RenderRows` resolves `RenderField` from the instance at call time, so a copy-across would give a test — and a host page helper — a member nobody calls.
- **Don't overwrite `category.ID`.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/WhatGroup/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/` are the same repo via symlink; either path works for git and file tools.
- **CRLF on disk.** `.gitattributes` enforces CRLF for `.lua` / `.toc` / `.xml` (WoW client expectation) and for `.md`. The generated `docs/test-cases.md` no longer needs a `sed`/`tr` pair: the shared kit's `--list` renderer writes CRLF itself, so a plain redirect is correct ([docs/testing.md](./testing.md)).
- **Match the sibling addons.** WhatGroup is on the same shared library as the rest of the collection: `libs/LibKa0s/` and `tests/_kit/` are **whole-folder copies** of `../LibKa0s`'s ship folders and MUST stay byte-identical to them — never edit either in place, and never copy a single file. A library problem is a finding to fix upstream and re-vendor ([docs/testing.md](./testing.md), [docs/common-tasks.md](./common-tasks.md#refresh-embedded-libs)). The Ace3 libs are copied verbatim from KickCD (except `LibSharedMedia-3.0`, from AbsorbTracker).

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
- `LibSharedMedia-3.0` (via its `lib.xml`; copied from Ka0s AbsorbTracker) — the media registry `core/MediaSetup.lua` registers the library's JetBrains Mono and bar textures with, through one `Media.RegisterLSM(addonName)` call at load
- `LibKa0s` (loaded **last**, via its own `LibKa0s.xml`) — the shared Ka0s addon library. WhatGroup takes six of its majors: **Core** (the prefixed secret-safe printer, `SafeToString`, the shared window skin, the close-button factory), **Env** (the TOC-manifest reader behind `NS.Meta` / `NS.Version`), **Media** (the icon catalog and the monospace face), **DebugLog** (the on-screen console), **Options** (the settings-canvas shell, the widget makers and the two-column flow engine) and **Slash** (the dispatcher, the help renderer and the schema CLI). **Perf is declined** on structural grounds — no hot path, and `suspend` would stop a capture addon capturing ([`LIBKA0S-15`](https://github.com/tusharsaxena/WhatGroup/issues/7)) — but the folder is vendored whole regardless, because the other majors sit on `Core` and a hand-picked subset is anti-pattern #48.

WoW retail APIs the addon depends on: `C_LFGList.ApplyToGroup` / `GetSearchResultInfo` / `GetApplicationInfo` / `GetActivityInfoTable`, `C_Spell.GetSpellName` / `GetSpellTexture` / `GetSpellLink`, `C_Timer.After`, `IsInGroup`, `IsSpellKnown`, `SetItemRef`. Teleport casting goes through a `SecureActionButtonTemplate` `macrotext` (`/cast <SpellName>`) — **not** `CastSpellByID`, which a non-secure addon click would trip `ADDON_ACTION_FORBIDDEN` on. Settings API: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`. Frame chrome: `BackdropTemplate`, `SecureActionButtonTemplate`, `UISpecialFrames`.

## Load order

`WhatGroup.toc` is the source of truth. Order is dependency, not alphabetical:

Every source file starts with `local addonName, NS = ...` — `NS` is the addon's
private namespace, shared across files (WG-01). There is **no `_G.WhatGroup`**.

1. **libs/** — `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceTimer-3.0` → `AceDB-3.0` → `AceGUI-3.0` (via its `.xml`, because that pulls in `widgets/`) → `LibSharedMedia-3.0` (via its `lib.xml`) → **`LibKa0s`** (last, via its own `LibKa0s.xml`, which spells out `Core` → `Env` → `Pool` → `Item` → `Media` → `Widgets` → `DebugLog` → `Slash` → `Options` → `OptionsWidgets` → `OptionsScroll` → `Perf` → `PerfPanel`; every other major refuses to register without `Core`, which is why the folder is vendored whole).
2. **`locales/enUS.lua`** — `NS.L`, a metatable shell whose missing keys return themselves. Loads first among the addon files (the `# Locales` section precedes `# Core`, toc-file-§5 / WG-14), so `NS.L` is available to every later file; callers still reference `NS.L[...]` at runtime by convention. Every *player-facing* string the addon authors routes through it; three classes deliberately do not, and the deviation table below carries the reasoning and the re-check trigger (localization-§3 / WG-07).
3. **`core/CoreSetup.lua`** — wires `LibKa0s-Core-1.0` and publishes the seams under the keys the addon already reads: `NS.IsConcatSafe` / `NS.SafeToString` (the secret-safe stringifier, events-frames-taint-§8 / WG-22), `NS.Util.print` (the prefixed secret-safe chat printer, aliased to `NS.Print` / `WhatGroup._print` by `core/WhatGroup.lua`), and `NS.SKIN` / `NS.ApplySkin` / `NS.MakeCloseButton` (the shared Ka0s window chrome, standalone-windows). Also publishes `NS.LIBKA0S_MISSING`, the one cause clause every other seam appends to. **First** in `# Core`, and three facts put it there: `core/WhatGroup.lua` takes the printer as a file-scope upvalue (`local p = NS.Util.print`), so a seam that published later would be a silent no-op; the printer is published on `NS.Util.print` rather than `NS.Print`, out of reach of AceConsole's `:Print` embed (anti-patterns #36); and `NS.PREFIX` is defined two files later, so `prefix` is passed in its **function** form, which Core re-reads on every call. `sink` is passed explicitly too — this addon prints through the Lua global `print`, not `DEFAULT_CHAT_FRAME:AddMessage`.
4. **`core/MediaSetup.lua`** — wires `LibKa0s-Media-1.0` and publishes `NS.Icon(name)` / `NS.MediaFont(name)`, both answering `nil` without the library, then calls `Media.RegisterLSM(addonName)` at file load. **This slot is load-bearing**, not conventional: `core/WhatGroup.lua` resolves `NS.FONT_MONO` from `NS.MediaFont` at load and `core/DebugLogSetup.lua` hands that value to a descriptor the library validates as a string, so a later slot would leave both reading `nil`. `addonName` is the addon's **folder** name — a texture path is absolute from `Interface\AddOns\` and a vendored library cannot infer which folder it was copied into. Does no frame work, which is what makes file-load registration safe here (library-stack-§8).
5. **`core/Util.lua`** — what the library does not own: `NS.Windows`, standalone-window geometry persistence (WG-26).
6. **`core/Compat.lua`** — hangs `NS.Compat` on the shared namespace. Version-variant spell / LFG shims (`GetSpellName` / `GetSpellTexture` / `GetSpellLink` / `IsSpellKnown` / `GetActivityInfoTable`); the SOLE caller of `C_Spell.*` / legacy globals / `C_LFGList.GetActivityInfoTable`.
7. **`core/Database.lua`** — `NS.SCHEMA_VERSION` + `NS:RunMigrations()` (idempotent, called once after `AceDB:New`); establishes the migration seam (WG-08).
8. **`core/WhatGroup.lua`** — `local WhatGroup = AceAddon:NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")` (mixes Ace methods, incl. `ScheduleTimer`/`CancelTimer`, into `NS`; `NS.addon = WhatGroup`). Seeds `NS.State.debug=false`, `NS.PREFIX`, aliases the `core/CoreSetup.lua` printer as the file-local `p` / `NS.Print` / `WhatGroup._print` (the reclaim from AceConsole's embed, anti-patterns #36), and `NS.FONT_MONO_NAME` / `NS.FONT_MONO` (the latter resolved from `core/MediaSetup.lua`'s `NS.MediaFont` seam, which is why that file's TOC slot is load-bearing; the LibSharedMedia registration moved there too). Then **at file-load top-level** installs the two direct `hooksecurefunc` post-hooks (on `C_LFGList.ApplyToGroup` and on `SetItemRef`), before any later boot-time work, so GameMenu's `InitButtons` sees a clean secure context. Defines `OnInitialize` / `OnEnable` / the capture handlers / `WhatGroup:RunTest` / `WhatGroup.Labels` (`PLAYSTYLE` / `GetGroupTypeLabel` / `GetPlaystyleLabel`). Module-locals `captureQueue`, `pendingApplications`, `wasInGroup`, `notifiedFor` initialize to empty / `false` / `nil`; the notify timer handle lives on `self.notifyTimer` (AceTimer). Its user-facing strings reference `NS.L[...]` at **runtime**; `NS.L` is already available since `locales/enUS.lua` now loads first.
9. **`core/DebugLogSetup.lua`** — wires `LibKa0s-DebugLog-1.0` and hangs `NS.DebugLog` + the bare `NS.Debug(tag, fmt, …)` sink on the namespace. The library owns the `WhatGroupDebugWindow` console, its Copy window, both line formatters, the ring buffer, the scrollbar sync and the enable seam; the descriptor supplies the frame-name prefix, the title, the mono font path, where the flag lives, what the `[Init]` summary says and who to tell when the window opens or closes. Loads **after** `core/WhatGroup.lua`, which is a move from where the hand-written console sat: the library validates `font`, `title`, `isEnabled` and `setEnabled` at `:New` time, and both `NS.FONT_MONO` and `NS.State.debug` are defined there. Nothing calls `NS.Debug` at file load, so the move costs nothing.
10. **`defaults/Profile.lua`** — hangs `NS.C`, the nested table of profile default VALUES (savedvariables-§2 / WG-24). Each `settings/Schema.lua` row references its value via `default = NS.C.<path>`, so values live here and the schema stays the single source of structure. Loads before `settings/Schema.lua` (the `# Defaults` section precedes `# Settings`).
11. **`defaults/TeleportSpells.lua`** — populates `NS.TeleportSpells` (mapID → Path-of spell ID lookup; values are a single spellID or a `{ id1, id2 }` candidate list). Writes straight to `NS`, so load order relative to `core/WhatGroup.lua` is irrelevant.
12. **`modules/Frame.lua`** — `local WhatGroup = NS.addon`; file-load runs only the `WhatGroup:ShowFrame()` method assignment. Everything else (the `WhatGroupFrame`, the secure teleport button, the `UISpecialFrames` registration, `MakeLabel` calls) is wrapped in `buildFrame()`, called from the first `ShowFrame()`; the popup persists its position via `NS.Windows` (WG-26). Loads after `# Core` (needs `NS.addon` / `NS.L` / `NS.Windows`) and before `# Settings`, referencing nothing from the settings layer at load. Same lazy-creation reasoning as the Settings panel + reset popup.
13. **`settings/Schema.lua`** — `local WhatGroup = NS.addon`, `local C = NS.C`; stamps `WhatGroup.Settings = { Schema, Helpers }` and its schema/db `Helpers`: schema access (`Get` / `RawSet` / `Set` / `FindSchema` / `ValidateSchema`), defaults (`BuildDefaults`, which threads each row's `default = C.<path>` into the profile and seeds `global.schemaVersion` + an empty `global.windows`), and the reset surfaces (`ApplyDefault` / `RestoreAllDefaults` / `RefreshAll`). `Helpers.Set` is the orchestrated single write-path — writes through `RawSet`, fires the row's `onChange`, then runs `RefreshAll`. `Settings.EnsureResetPopup()` lazily writes `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` on first use — writing at file-load taints GameMenu callbacks. The refresher registry that used to live here is the library's now, and per-ctx rather than per-addon.
14. **`settings/OptionsSetup.lua`** — wires `LibKa0s-Options-1.0` and **publishes the instance as `Settings.Helpers`**, with `settings/Schema.lua`'s data seams moved onto it. Also carries the addon's one adapter: the wrappers that keep the panel body and the Defaults button building on the next frame. Loads after `settings/Schema.lua` (whose `Get` / `Set` / `FindSchema` the descriptor reads) and before `settings/Panel.lua` (which takes the instance as a file-scope upvalue).
15. **`settings/Panel.lua`** — the two halves of the settings surface that are genuinely this addon's: `Helpers.BuildMainContent` (the landing page's logo, TOC-notes line and command list), `Helpers.InlineButton` (the one fixed-width action button the library's `InlineButtonPair` cannot express), and the General page's registration through `Helpers.RegisterOptionsPage`. `Settings.Register` runs from `OnEnable` and again as an idempotent no-op from the `config` verb; guarded by `WhatGroup._settingsRegistered` and self-guarded against `InCombatLockdown()`.
16. **`settings/Slash.lua`** — wires `LibKa0s-Slash-1.0`. Carries the `COMMANDS` table (positional triples, published as `WhatGroup.COMMANDS` so the landing page renders the same data), the five host verbs (`show`, `test`, `config`, `resetall`, `debug`), the `parse` adapter that keeps `toggle` working, and `WhatGroup:OnSlashCommand`. Loads last (the `# Settings` section is final, toc-file-§5 / WG-14).

Lifecycle:

- **`OnInitialize`** (fires on `ADDON_LOADED` for `"WhatGroup"`, after every TOC line has executed): `defaults = Settings.BuildDefaults()` → `db = AceDB:New("WhatGroupDB", defaults, true)` → `self:RunMigrations()` → register `/wg` and `/whatgroup` chat commands. Debug state is session-only (`NS.State.debug`), **not** seeded from SavedVariables.
- **`OnEnable`** registers `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED`, snapshots `wasInGroup = IsInGroup()`, and registers the Settings panel so the AddOns entry appears at login. **No hook installation** here — hooks are at file-load (above). The popup's secure teleport button + `UISpecialFrames` insert (the real boot-taint sources) stay deferred to first `ShowFrame()`, and the reset popup registers lazily on first reset request — so GameMenu's `InitButtons` still runs in a clean context and Logout works correctly even after `/reload`.

`Settings.Register()` runs at `OnEnable` (and again as a no-op from `runConfig`). It defers the AceGUI body build to the parent and General subcategory's first `OnShow` (each behind its own one-shot guard). See [docs/settings-panel.md](./settings-panel.md#lazy-panel-build).

If you add a new runtime file, put it in the right place in `WhatGroup.toc` (after libs, after the file it depends on).

## Known Limitations

Things the addon does not do, and the reason each is a boundary rather than a bug. Scope decisions
are reasoned in [docs/scope.md](./scope.md); a limitation that is a *ratified standards deviation*
lives in the table below this one, not here.

- **Capture is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup` and
  `notifiedFor` never touch SavedVariables, so `/reload` mid-application loses the pending capture
  and the join that follows prints nothing. Deliberate: the data describes a group you are in right
  now, and persisting it would resurface a stale group after a relog.
- **Only groups joined through the Premade Group Finder are captured.** A guild or party invite
  carries no LFG search result, so there is nothing to observe. `/wg test` exists precisely because
  the real path cannot be exercised on demand.
- **Teleport is limited to dungeon Path-of spells the player has learned.** The button renders
  grayed until `IsSpellKnown` says otherwise, and only for map IDs present in
  `defaults/TeleportSpells.lua` — a hand-maintained table, so a newly added dungeon needs a data
  update.
- **English only.** The locale shell (`locales/enUS.lua`, `NS.L`) is mandatory and every authored
  player-facing string routes through it, but translation content is a non-goal (localization-§3 /
  WG-07). The partial routing is ratified in the deviation table, re-check trigger "the first
  non-English locale file".
- **No profiler wiring.** `LibKa0s-Perf-1.0` is vendored but not wired; see the deviation table.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the popup reports on joining a group, and what it leaves out |
| `module-map.md` | Every non-vendored file, its responsibility, and load order |
| `schema.md` | The persisted shape, every default, and the migration seam |
| `settings-panel.md` | The panel tree, per-option behavior, and the write seam |
| `data-flow.md` | Group-join event → capture → summary and popup |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 11 verbs in the command table |
| `midnight-quirks.md` | Present | LFG and group-API behavior the addon works around |
| `debug.md` | Present | The addon’s own debug surface beyond the library console |
| `message-bus.md` | Not applicable | The addon defines no cross-module messages — it is a single feature module |
| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes LFG and unit APIs with no addon-specific shim to document separately |
| `profiles.md` | Not applicable | No profile control ships in the options UI; a hook is noted in `settings/Schema.lua` if AceDBOptions is ever added |
| `perf-analysis/README.md` | Not applicable | No performance harness is wired — see `performance.md` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `frame.md` | The popup frame: layout, rows, and the teleport buttons |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`).
A decision may be *reasoned* at length in this repo's GitHub issues and the **Why**
cell cites that id — but **a deviation not in this table is not ratified**, and an audit files it as
an open MUST failure. **Re-check trigger** is the condition that ends the deviation, stated so a
reader can tell whether it has already fired; a row without one is a permanent opt-out wearing a
table's clothes. A row whose cited rule the standard has since changed is **retired**, not kept.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§12` | The no-combat-path exemption is claimed: `libs/LibKa0s/` is vendored **whole**, Perf.lua included, but nothing is wired — no `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb registration, no suspend/resume contract, no `tests/perf.lua`, no `docs/perf-analysis/`. `perf` stays a reserved verb (`slash-commands-§2`); it is simply not registered. | **Criterion (a)** — no combat path — is proven by the committed whole-repo `RegisterEvent` / `SetScript("OnUpdate"` / `C_Timer` sweep in [`performance.md`](./performance.md), which names the per-event work for every hit: zero `OnUpdate`, zero repeating tickers, zero repeating timers, and the one handler reachable inside a combat window (`GROUP_ROSTER_UPDATE`) is an `IsInGroup()` and three comparisons. **Both (b) and (c) apply**: every declared bucket would read `0.000` by construction (`performance-§3` calls such a bucket a lie in every report), and `suspend` would suppress the data the addon exists to record — this is a *capture* addon, so an apply or an invite-accept inside a measurement window would never be recorded and the popup the player installed it for would silently not appear. Reasoned in full, and ratified with the user, at [`LIBKA0S-15`](https://github.com/tusharsaxena/WhatGroup/issues/7). | 2026-08-02 | **FIRED 2026-08-06** — the cooldown countdown ticker (`modules/Frame.lua:146`) is a repeating ticker. This row is superseded by the one below and is kept only as the record of what was claimed and on what evidence; the sweep in `performance.md` has been regenerated. |
| `performance-§12` (re-check fired) | **The exemption above ended on 2026-08-06, and the wiring is still declined.** `modules/Frame.lua:146` arms a 1-second `ScheduleRepeatingTimer` for the teleport cooldown countdown — a repeating ticker, which is the exact condition the row above names as re-arming the full wiring MUST. Nothing was wired in response: still no `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb registration, no suspend/resume contract, no `tests/perf.lua`, no `docs/perf-analysis/`. | The trigger fired on the letter of `performance-§12`, but **only criterion (a) broke; (b) and (c) did not.** Every declared bucket would still read `0.000` — `performance-§3` calls such a bucket *a lie in every report* — and `suspend` would still make a *capture* addon miss the apply or invite-accept it exists to record. Wiring Perf here buys a `perf` verb dispatching into an instance with nothing to say, plus a second SavedVariables global, to account for one `C_Spell.GetSpellCooldown` and one `SetText` per second **while a popup the player opened is on screen showing a live cooldown**. The ticker cannot outlive that window: one handle, replaced not stacked, cancelled from the popup's `OnHide`, from the top of every `ConfigureTeleportButton`, and by the tick that reaches zero — pinned by five cases in `tests/test_frame.lua`. The regenerated sweep is in [`performance.md`](./performance.md). **An amendment is proposed upstream** — that §12's trigger should exempt a ticker gated on an addon's own transient window — and if it is accepted this row retires in favour of the exemption row above. Justification comment at `cooldownTimer` in `modules/Frame.lua`. | 2026-08-06 | **Two triggers, either one ends this row.** (1) The upstream §12 amendment lands — this row retires and the exemption row above is re-claimed against the amended text. (2) The ticker stops being window-bounded, or a second repeating timer appears, or any repeating work starts running with the popup closed — at which point (a)'s spirit is gone too, not just its letter, and the **full wiring is wired**, not re-argued. |
| `localization-§3` | **English-only, and the routing SHOULD is met in part.** Both MUSTs are unconditional and are met: the `NS.L` seam is exported from `locales/enUS.lua`, and `enUS.lua` ships and loads first (`toc-file-§5`). What deviates is the routing SHOULD — three classes of string stay unrouted literals. (1) **Slash-CLI diagnostics** — `"unknown command"`, `"Usage: …"`, `"Settings layer not ready yet"`, `"debug logging ON/OFF"`. (2) **Strings that double as identifiers** — `"General"` is at once the options page id (`Helpers.RegisterOptionsPage("general", "General", …)`), the `group` key on three `settings/Schema.lua` rows, and the Blizzard subcategory label; `"Ka0s WhatGroup"` is the brand, carried by the TOC `Title`, the parent category and the debug-console title. (3) **The library's own copy** — the `Defaults` button label and the combat-refusal notice are `LibKa0s-Options-1.0`'s `DEFAULTS_LABEL` / `COMBAT_REFUSED`, authored there. | English-only is a stated project non-goal ([`scope.md`](./scope.md)), so the routing SHOULD's only beneficiary is a translator who does not exist yet — and the seam plus the shipped `enUS.lua` are exactly what makes one cheap to onboard later. Routing class (2) would be actively wrong, not merely unnecessary: translating `"General"`'s display copy without translating the schema `group` key unmatches the two and empties the page, which is a live bug rather than a missing translation. Class (3) would install a second source of truth for a string the library owns. Class (1) is developer feedback on a command line, not player chrome. Five keys that no `L[…]` ever read — `"Ka0s WhatGroup"`, `"General"`, `"Defaults"`, and the combat-refusal notice, plus the landing heading — were the standing evidence that this had never been decided; four are deleted and `"Slash Commands"` is now routed, so the table states the real surface. `WG-R-06`. | 2026-08-05 | **The first non-English locale file.** Adding `locales/<X>.lua` re-arms the full routing SHOULD: audit every unrouted literal at that point, and resolve `"General"` by giving the page a stable non-display id before translating its label. |
| `events-frames-taint-§8` | **The pre-formatting SHOULD is not met at every site, and two `pout` fallbacks end in the global `print`.** Chat and debug lines are built with `..` / `tostring` before they reach the seam — `core/WhatGroup.lua:488`, `:496`, `:504` (the join summary's gold-labelled rows) and every `NS.Debug(tag, "…" .. tostring(x))` call in `core/`, `modules/` and `settings/`. Separately, `settings/Panel.lua`'s and `settings/Schema.lua`'s file-local `pout` helpers fall back to a bare `print(...)` when `WhatGroup._print` is unset. | **Re-graded under the scoped rule (`M1-STD-11` option (a), 2026-08-05).** §8's pre-formatting MUST NOT is now scoped to call sites whose arguments can reach a value read from one of the named combat-protected APIs; everywhere else it is a SHOULD NOT, and the risk is future drift rather than a live raise. A committed whole-repo sweep — `grep -rnE 'UnitGetTotalAbsorbs\|UnitGetTotalHealAbsorbs\|UnitGetIncomingHeals\|UnitHealth\|UnitHealthMax\|UnitThreatSituation\|UnitDetailedThreatSituation\|C_UnitAuras\|GetPlayerAuraBySpellID\|"UNIT_AURA"'` over `core/ defaults/ locales/ modules/ settings/` — returns **zero** hits: WhatGroup reads LFG search-result data only (strings, integers, booleans from `C_LFGList`), so **no site in this addon is in the trigger set** and every one of them is a SHOULD. `grep -rcE 'print\(\(".*"\):format' settings/` is `0` in all four files. The seam's own guarantee is unaffected and is met: `NS.Print` is `LibKa0s-Core-1.0`'s prefixed printer and runs every argument through `NS.SafeToString` (WG-22), and `NS.Debug` routes through the library sink. The **two `pout` fallbacks are a separate matter and are NOT re-graded away** — §8 keeps the no-global-`print` prohibition unqualified. They stand because they are **unreachable**: `core/WhatGroup.lua` sets `WhatGroup._print` and the TOC loads it before `settings/`, so the branch cannot execute, which grades it Info (no user, no session, no SavedVariables reaches it). They are kept as load-order defense, not as sanctioned output. `WG-A-08`. | 2026-08-05 | **Two triggers, either one ends this row.** (1) The first call to any API in §8's trigger set, or any value derived from one, entering a chat or debug line — that site converts as a **MUST** and the sweep above is regenerated. (2) Anything that makes a `pout` fallback reachable — a TOC reorder putting a `settings/` file before `core/WhatGroup.lua`, or a caller invoking `pout` at file load — at which point the bare `print` is a live MUST-NOT failure and the fallback goes rather than being re-ratified. |
