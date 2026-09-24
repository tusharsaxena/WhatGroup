# Architecture

Orient-yourself map for **Ka0s WhatGroup**. This file is the high-level index; topic detail lives in `docs/`.

## Overview

WhatGroup observes the Premade Group Finder (LFG) flow. It captures the group details visible on the search-result tile when the player applies, holds them across the application → invite → accept → join sequence, and resurfaces them once the player is actually in the group as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells.

The addon is observation-only. It never modifies LFG state, never auto-applies, and never blocks the join flow. Capture is a direct `hooksecurefunc` post-hook on `C_LFGList.ApplyToGroup`. A click on the chat notification's details link, Blizzard's `addon` link type, arrives as an `EventRegistry` `"SetItemRef"` callback filtered to `addon:WhatGroup:` links. A client without that path falls back to a `hooksecurefunc("SetItemRef")` post-hook. No AceHook wrappers — those leave per-invocation closures that taint Blizzard's secure-execute chain on Logout.

## Module Map

```
LFG events ─▶ capture pipeline ─▶ pendingInfo
                  │                    │
                  ▼                    ▼
        ApplyToGroup → applied   _TryFireJoinNotify(reason)
        → inviteaccepted          (called from BOTH paths below;
        (keyed by searchResultID)  `notifiedFor` flag prevents double-fire)
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

  Ten of those arrows are LibKa0s-owned. The addon supplies a descriptor per
  module (or, for Compat, wires the library's members) and the library owns the rest:

    core/CoreSetup.lua      ─►  LibKa0s-Core-1.0      printer, secret-safe seam, window skin
    core/MediaSetup.lua     ─►  LibKa0s-Media-1.0     NS.Icon / NS.MediaFont over the shipped catalog
    core/EnvSetup.lua       ─►  LibKa0s-Env-1.0       the TOC-metadata reader (version, Notes)
    core/Compat.lua         ─►  LibKa0s-Compat-1.0    the spell name, icon and cooldown readers
    core/DebugLogSetup.lua  ─►  LibKa0s-DebugLog-1.0  the console, both formatters, the buffer
    settings/SchemaSetup    ─►  LibKa0s-Schema-1.0    the schema runtime: path walk, write seam, bracket
    settings/OptionsSetup   ─►  LibKa0s-Options-1.0   canvas shell, widget makers, flow engine
    settings/Slash.lua      ─►  LibKa0s-Slash-1.0     dispatcher, help, the schema CLI
    core/LauncherSetup.lua  ─►  LibKa0s-Launcher-1.0  the broker object + the minimap button
    core/LifecycleSetup.lua ─►  LibKa0s-Lifecycle-1.0 the stand-down latch and its two named holds
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-file responsibility map | `WhatGroup.toc`, `core/WhatGroup.lua`, `defaults/TeleportSpells.lua`, `settings/Schema.lua`, `settings/Panel.lua`, `modules/Frame.lua` | [docs/module-map.md](./module-map.md) |
| Boundary decisions (in / out of scope, resolved choices) | — | [docs/scope.md](./scope.md) |
| LFG capture pipeline + queue mechanics + the details chat link's click route | `core/WhatGroup.lua` | [docs/data-flow.md](./data-flow.md) |
| Settings schema, panel wiring, helpers, db.profile shape | `settings/SchemaSetup.lua`, `settings/Schema.lua`, `settings/OptionsSetup.lua`, `settings/Panel.lua` | [docs/settings-panel.md](./settings-panel.md) |
| `/wg` slash UX + `COMMANDS` table | `settings/Slash.lua` | [docs/slash-dispatch.md](./slash-dispatch.md) |
| On-screen debug console + `NS.Debug` sink | `core/DebugLogSetup.lua` | [docs/debug-content.md](./debug-content.md) |
| The shared library, its ten seams and the degraded install | `libs/LibKa0s/`, `core/CoreSetup.lua`, `core/Compat.lua`, `core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`, `core/LauncherSetup.lua`, `core/LifecycleSetup.lua`, `settings/SchemaSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` | this file, below |
| The launcher — the minimap button and the broker plugin | `core/LauncherSetup.lua` | this file (`## Invariants`); [docs/module-map.md → Load order](./module-map.md#load-order) |
| The stand-down — what disabled means, the latch and its holds, what survives | `core/LifecycleSetup.lua`, `core/WhatGroup.lua`, `modules/Frame.lua` | [docs/stand-down.md](./stand-down.md) |
| Popup dialog (`WhatGroupFrame`) | `modules/Frame.lua` | [docs/frame.md](./frame.md) |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | — | [docs/midnight-quirks.md](./midnight-quirks.md) |
| Routine recipes (add a setting, add a command, refresh libs) | — | [docs/common-tasks.md](./common-tasks.md) |
| Verification model (headless harness, mock fidelity, `--list` inventory + badge sync) | `tests/` | [docs/testing.md](./testing.md) |
| Manual smoke tests (boot health, slash, settings panel, `/wg test notify`, test mode, real LFG, regression checks) | — | [docs/smoke-tests.md](./smoke-tests.md) |

## Settings Schema

Nineteen rows — sixteen profile-scoped, one **global** and two session-only — valued in
`defaults/Profile.lua` (`NS.C`), apart from the global one, whose default is declared where it is
stored. Eleven are declared in `settings/Schema.lua`; the other eight are the **Master controls**
block, composed by `LibKa0s-Options-1.0`'s `MasterControls` from one declaration in
`settings/Panel.lua` and spliced at the head of the array (`options-ui-§15`). Either way the schema
owns the STRUCTURE and `NS.C` owns the VALUES (savedvariables-§2 / WG-24). The one settings page is
**tabbed** (`options-ui-§13`): one tab per row `group`, in declaration order — **Master controls**
(8), **Chat** (8), **Popup** (3), detailed in
[docs/settings-panel.md](./settings-panel.md#the-tab-strip).

| Path | Type | Tab |
|---|---|---|
| `enabled` | bool | Master controls — the master switch; its `onChange` sets the latch's `disabled` hold, which is the whole stand-down (see `## The stand-down`) |
| `visibility` | string | Master controls — `always` / `inCombat` / `outOfCombat` / `never`; gates every path into `WhatGroup:ShowFrame()` |
| `scale` | number | Master controls — popup scale (0.5–2), applied by `WhatGroup:ApplyFrameScale()`, refused in combat |
| `alpha` | number | Master controls — popup opacity (0–1), applied by `WhatGroup:ApplyFrameAlpha()`, allowed in combat |
| `locked` | bool | Master controls — read at drag time by the title bar's `OnMouseDown` |
| `state.debugConsole` | bool | Master controls — **session-only**; shows/hides the console window, never `db.profile` (WG-12) |
| `global.minimap.shown` | bool | Master controls — **global**, stored at LibDBIcon's OWN key `db.global.minimap.hide`: the path and the row say *shown* and the stored boolean says hidden, so `Helpers.Get` / `Helpers.Set` invert and `Set` calls `NS.Launcher:SetShown` so the button follows the checkbox now rather than at the next reload (launcher-§3) |
| `state.testMode` | bool | Master controls — **session-only**; the popup's test mode: sample group info on the popup until it is turned off, closed, asked to show the real capture, or combat starts (`modules/Frame.lua`) |
| `notify.delay` | number | Chat — seconds to wait before notify **and** popup (`0` = instant) |
| `notify.enabled` | bool | Chat — print the chat summary on join; the master for the six below |
| `notify.showInstance` | bool | Chat — line toggles |
| `notify.showType` | bool | Chat |
| `notify.showLeader` | bool | Chat |
| `notify.showPlaystyle` | bool | Chat |
| `notify.showClickLink` | bool | Chat |
| `notify.showTeleport` | bool | Chat |
| `frame.autoShow` | bool | Popup — open the popup automatically on join |
| `frame.width` | number | Popup — popup width in pixels, clamped 320..700 (was `FRAME_WIDTH`) |
| `frame.height` | number | Popup — popup height in pixels, clamped 200..520 (was `FRAME_HEIGHT`) |

Every path is **absolute**: there are no window-relative paths, there being no active-window state
to be relative to. The account-wide `global` table carries `schemaVersion`, `windows` and `minimap`. **Exactly one
schema row lives there** — `global.minimap.shown` (launcher-§3), stored at `db.global.minimap.hide` and inverted by the `get` / `set` `settings/Schema.lua`'s `GLOBAL` table stamps on the row, as `SESSION` does for the session paths; the other two keys are not rows.
Every row reads and writes through **one schema runtime**, `NS.SchemaRuntime` over `LibKa0s-Schema-1.0` (`settings/SchemaSetup.lua` holds the library-absent stub), bound as `Helpers.Get` / `Helpers.Set`: `Set` is the single write-path (refuse a path no row declares → store → `[Set]` line → `onChange` → `RefreshAll`) and `Get` on an unknown path returns nil
**without materializing parent tables**. Detail, including why the
launcher's row is global: [docs/settings-panel.md](./settings-panel.md).

**Named non-setting state (`architecture-§5`).** `db.global.windows`: the popup's position,
`windows.popup = { point, relPoint, x, y }` (WG-26). Only a drag determines it; no control sets it
and no row addresses it. **Owner:** `NS.Windows` (`core/Util.lua`), whose `Restore` reads it back on
build. **Writers:** `NS.Windows.Save` on **drag-stop**, from the title bar's `OnMouseUp`, and
`WhatGroup:ResetFramePosition()` from the **Reset position** button, which sets the entry to nil.
`Settings.BuildDefaults` seeds the empty table. Detail: [docs/frame.md](./frame.md).

**Named non-setting state, second entry.** `db.global.minimap.minimapPos`, the angle the player
dragged the button to. **Owner:** LibDBIcon-1.0, handed the whole `db.global.minimap` table at
`Register`. Its sibling `hide` IS a row, whose `set` moves that key rather than the section — which
is what stops the dragged angle being flattened.

**No structural registry (`architecture-§5`).** WhatGroup holds no collection whose members the
player creates or deletes: every profile value is a fixed schema row, so there is no registry writer
and no load pass to name.

## Message Bus

**There is none, because** WhatGroup is below the threshold in `architecture-§4` (as amended in
standard v2.65.0). The bus MUST binds an addon with two or more feature modules, or a feature module
that registers game events a second feature module must react to — and the AceAddon object's own
event handlers are not a feature module. WhatGroup is the shell (`core/WhatGroup.lua`, which
registers the four game events) plus one feature module (`modules/Frame.lua`, which registers none),
so direct calls are permitted: the capture path calls `WhatGroup:_TryFireJoinNotify(reason)`, and the
`notifiedFor` identity flag, not a message, keeps the two trigger paths from double-firing.
`grep -rn "SendMessage\|RegisterMessage" core modules settings defaults` returns nothing, and there
is no deviation register row because nothing deviates.

**Re-open when** a second feature module appears, or a second consumer of the join data does.
AceEvent-3.0's `SendMessage` is already mixed in and is the route to take then.

## Slash Commands

`/wg` (alias `/whatgroup`), dispatched by `LibKa0s-Slash-1.0` over the `COMMANDS` table in
`settings/Slash.lua`. Rows are **positional triples** — `{ name, description, handler }`, handler
taking `rest` alone — and the same table is published as `WhatGroup.COMMANDS` so the settings
landing page renders exactly what the dispatcher runs.

| Verb | Owner | Does |
|---|---|---|
| `help` | library | Lists every row |
| `show` | host | Re-opens the popup for the current group |
| `test` | host | Toggles test mode (`on\|off` sets it) through the Test mode checkbox's own setter; `test notify` injects synthetic group info and runs the full notify + frame flow once, ending test mode if it is on |
| `config` | host | Opens the settings panel on its landing page (refused in combat, inside `OpenOptionsPanel`). A bare `/wg` runs it too, and the launcher's right click calls the same `WhatGroup:OpenSettings` |
| `enable` / `disable` | host | The reserved pair (`slash-commands-§2`): **aliases** for the `enabled` row, written through the same `Helpers.Set` the Master controls checkbox writes through, holding no state of their own. The dispatcher answers in either state, so the switch is never one-way — and while `enabled` is false a **feature verb** (`show`, `test`) refuses on one tagged line naming `/wg enable` and does nothing else, gated once in the dispatcher rather than per verb (`slash-commands-§2`, [slash-dispatch.md](./slash-dispatch.md#and-a-feature-verb-refuses-instead-of-acting)) |
| `version` | library | Prints the addon version |
| `list` / `get` / `set` | library | The schema CLI, over the nineteen rows above (`/wg set state.testMode` reaches test mode too; `/wg test` is its verb) |
| `reset` | host | Resets **one** path — `/wg reset <path>`, no confirmation ([`LIBKA0S-13`](https://github.com/tusharsaxena/WhatGroup/issues/8)) |
| `resetall` | host | Resets the **active profile** to the shipped defaults — a profile reset, the same act as AceDBOptions' Reset Profile (`options-ui-§12`) — behind the shared `WHATGROUP_RESET_ALL` popup |
| `debug` | host | Opens/closes the debug console; `on|off` toggles logging |

`perf` stays a reserved verb (`slash-commands-§2`) and is deliberately not registered — see
`## Documented deviations`. Detail: [docs/slash-dispatch.md](./slash-dispatch.md).

## Event Subscriptions

Small and deliberately so — the whole surface, from `grep -rn "RegisterEvent\|hooksecurefunc"`:

**Every row below is registered while the addon is ENABLED and gone while it is disabled** — the
`EventRegistry` chat-link callback included — except the two `hooksecurefunc` rows, which have no
un-hook and gate their own bodies instead, and one
transient: a stand-down taken in combat keeps `PLAYER_REGEN_ENABLED` until it can finish the
protected `Hide` it owes. See `## The stand-down`.

| Registered | Where | Handler does |
|---|---|---|
| `GROUP_ROSTER_UPDATE` | `core/WhatGroup.lua` `OnEnable` | Detects the not-in → in transition and calls `_TryFireJoinNotify("ROSTER transition")`; on leave, `WipeCapture()` |
| `LFG_LIST_APPLICATION_STATUS_UPDATED` | `core/WhatGroup.lua` `OnEnable` | Advances the application queue; on `inviteaccepted` sets `pendingInfo` and calls `_TryFireJoinNotify("inviteaccepted")` |
| `PLAYER_REGEN_DISABLED` + `PLAYER_REGEN_ENABLED` | `core/WhatGroup.lua` `OnEnable`, both to `OnCombatStateChanged` | On `PLAYER_REGEN_DISABLED`, first ends test mode if it is on (`WhatGroup:EndTestModeForCombat()`, one chat line), while secure writes are still allowed. Then re-asks the `visibility` gate on the transition and applies the answer — **asymmetrically, because the client makes it so**: it shows a popup the gate has just opened for when a capture is still pending, on either edge, but it can only *hide* on `PLAYER_REGEN_ENABLED`. `f` parents a secure child, so `Hide` is refused under lockdown; a gate that closes on the way in is honored one edge late, through the same `hidePopup()` seam that carries a `Close` pressed in combat (`M2-28`). The edge is taken from the **event name**, not from `InCombatLockdown()`, which can still read stale on the frame `PLAYER_REGEN_DISABLED` fires. On `PLAYER_REGEN_ENABLED` it first drains `modules/Frame.lua`'s **combat-end queue** (`NS.FrameDrainCombatEnd`): the deferred `ConfigureTeleportButton` write, then the deferred first show. `modules/Frame.lua` registers no event of its own; both replays are queued with `NS.FrameQueueForCombatEnd`, one slot per key |
| `EventRegistry:RegisterCallback("SetItemRef", …, WhatGroup)` | `core/WhatGroup.lua`, file-load (`registerLinkCallback`); `NS.StandDown` unregisters it and `NS.StandUp` registers it again | Clicks on Blizzard's `addon` link type. Blizzard's registered handler raises this event and counts the link Handled, so `SetItemRef` never reaches its ItemRef-tooltip fallthrough. Filtered to `addon:WhatGroup:` links, it re-opens the popup, or prints the stale-link hint. It has a real unregister, so it is **gone while disabled**, not gated |
| `hooksecurefunc(C_LFGList, "ApplyToGroup")` | `core/WhatGroup.lua`, file-load | Records the group applied to |
| `hooksecurefunc("SetItemRef")` | `core/WhatGroup.lua`, file-load, **only** where `NS.Compat.AddOnLinkType()` is nil | The degraded client's route for the old `WhatGroup:show` link. It runs after Blizzard's fallthrough ([data-flow.md](./data-flow.md)) |

The four event rows are registered through **`NS.SafeRegisterEvent`** (LibKa0s-Core minor 8,
bound in `core/CoreSetup.lua`; a one-rung `pcall` stub on the degraded path), never a bare
`self:RegisterEvent`, so one name a patch retires costs only its own row and not the rest of
`OnEnable` (events-frames-taint-§1). A refused name is kept once in the session-only
`NS.RejectedEvents` and shown in the `[Init]` summary as `, rejected events: <names>`; the
summary is unchanged when the list is empty. See [midnight-quirks.md](./midnight-quirks.md).

Both subscriptions are **installed at file load**, never through AceHook and never in `OnEnable`:
the `ApplyToGroup` post-hook, and the chat-link callback (or, on a degraded client, its post-hook).
The `EventRegistry` callback is not in the `grep` above; `grep -n "RegisterCallback" core/WhatGroup.lua`
finds it beside AceDB's three profile callbacks.
There is no `OnUpdate` handler anywhere in the addon, and exactly **one** repeating timer — the
teleport cooldown countdown at `modules/Frame.lua:524`, a 1-second `ScheduleRepeatingTimer` added
2026-08-06. The sweep behind both statements is in [`performance.md`](./performance.md), and the
ticker is what ended the no-combat-path exemption; the wiring is still declined, now as a ratified
deviation in its own right (see `## Documented deviations`).

The teleport button's cooldown swipe is engine-driven and costs nothing; its countdown text ticks
once a second and cannot outlive the popup that armed it (armed from `OnShow` under `f:IsShown()`,
canceled from `OnHide`). Detail: [frame.md → Teleport button](./frame.md#teleport-button).

## The stand-down

**Disabled means the addon is not running** (`slash-commands-§7`): every event unregistered, every
timer canceled, nothing drawn and nothing written from a game event. It is not a draw gate that
stops reacting while still watching. `core/LifecycleSetup.lua` builds **one**
`LibKa0s-Lifecycle-1.0` latch with two named holds, `disabled` (persisted, taken from the stored
`enabled` path) and `perf` (session-only, and unused because Perf is declined). The addon stands up
only when the **last** hold is released, and rebuilds from current state. `NS.StandDown` and
`NS.FrameStandDown` are the whole teardown. The `hooksecurefunc` bodies gate themselves because a
hook cannot be undone; setup survives (the slash dispatcher, the settings registration, AceDB and
its profile callbacks, the launcher). A stand-down in combat keeps `PLAYER_REGEN_ENABLED` for the
one `Hide` it owes, and the launcher's left click is refused while disabled. `tests/test_disabled.lua`
is the conformance suite. Detail: [stand-down.md](./stand-down.md).

## Taint Notes

- **No AceHook.** `SecureHook` / `RawHook` wrap the callback in a per-invocation bookkeeping closure,
  and that closure taints the secure-execute chain Blizzard runs for the GameMenu Logout button
  (`ADDON_ACTION_FORBIDDEN … 'callback()'`). Direct `hooksecurefunc` adds no closure of ours.
- **Subscriptions at file load, secure frames at first use.** The `ApplyToGroup` post-hook and the
  chat link's `EventRegistry` `"SetItemRef"` callback (on a degraded client, its `SetItemRef`
  post-hook) install at file-load top level, so GameMenu's `InitButtons` sees a clean context. The
  callback is a plain registration on Blizzard's own callback registry: it replaces no global and
  wraps nothing, and the registry invokes it through `securecallfunction`
  (`Blizzard_SharedXMLBase/CallbackRegistry.lua:209-213` at 12.1.0). The popup's `SecureActionButtonTemplate`
  teleport button, its `UISpecialFrames` insert and the `WHATGROUP_RESET_ALL` popup registration are
  all deferred to first use. The `UISpecialFrames` entry is the unprotected `WhatGroupFrameEscape`
  proxy, never `"WhatGroupFrame"`: Escape's `CloseWindows` calls a bare `Hide()` on each entry, and
  on the popup that call is protected in combat. The proxy's `OnHide` routes Escape through
  `hidePopup()` instead ([frame.md → ESC-to-close](./frame.md#esc-to-close); the `standalone-windows`
  row in `## Documented deviations`).
- **Two combat guards, both in `modules/Frame.lua`.** `ConfigureTeleportButton` stashes `info` and
  reruns on `PLAYER_REGEN_ENABLED`; `ShowFrame` defers the first `buildFrame()` past combat on the
  same combat-end queue and says so in chat. Both guard genuine secure-frame writes.
- **Category registration is not combat-gated** (options-ui-§9). Registering a canvas category
  never taints, and eager registration at load is a MUST; only panel *open* is refused, and that
  refusal lives inside `OpenOptionsPanel` so every caller gets it (options-ui-§2). The category
  still registers at login with no user action; in combat the library parks it and lands it at
  combat end (`LibKa0s-Options-1.0` minor 24), so no second `Register()` is needed.
  `Settings.Register()` carried a third, defense-in-depth `InCombatLockdown()` guard until
  2026-08-05; it bought nothing and cost the AddOns-list entry on any `/reload` taken in combat.
- **Two `C_Timer.After(0, …)` hops are taint avoidance, not timers.** They move the panel and frame
  builds out of Blizzard's secure-execute chain; each carries a justification comment.
- **The chat path stringifies through `NS.SafeToString`**, so a combat-protected value degrades to
  `<secret>` instead of raising (events-frames-taint-§8 / WG-22).

## Invariants worth not breaking

- **Observation-only, direct hooksecurefunc only, never AceHook.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Capture is a direct `hooksecurefunc` post-hook on `C_LFGList.ApplyToGroup`. The chat link's click is not hooked. It is Blizzard's `addon` link type, heard as an `EventRegistry` `"SetItemRef"` callback filtered to `addon:WhatGroup:` links, and it falls back to a direct `hooksecurefunc("SetItemRef")` post-hook only on a client without that path (`NS.Compat.AddOnLinkType()` nil). No AceHook `SecureHook` / `RawHook` — AceHook adds a per-invocation bookkeeping closure around the callback, and that closure taints the secure-execute chain that Blizzard runs when the player clicks the GameMenu's Logout button (surfacing as `ADDON_ACTION_FORBIDDEN ... 'callback()'`). Direct `hooksecurefunc` has no closure on our side, no taint.
- **Private `NS` namespace, no public global.** Every source file starts with `local addonName, NS = ...` — or `local _, NS = ...` where the folder name is not read, which is the ten files that do not talk to a vendored library (`M4c-04`); the AceAddon object is `NS.addon` (mixed into `NS`, aliased downstream as `local WhatGroup = NS.addon`). There is **no `_G.WhatGroup`** (WG-01). New standalone data/logic hangs on `NS.*` (`NS.Compat`, `NS.L`, `NS.State`, `NS.TeleportSpells`, `NS.PREFIX`, …). If a public surface is ever needed, expose only a versioned `NS.API.v1` via `_G[addonName]` — never the whole table.
- **Schema-first.** Adding a setting = one row in `Settings.Schema`. The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Slash-first.** Adding a command = one row in `COMMANDS` (`settings/Slash.lua`). The help index, the settings landing page and the dispatcher all iterate that one table. Rows are **positional triples** — `{ name, description, handler }` — and the handler takes `rest` alone, never `(self, rest)`: that is the shape `LibKa0s-Slash-1.0` reads, and a table of named fields is silently invisible to it.
- **The library seams degrade, they never error.** All ten wiring files — `core/CoreSetup.lua` (Core), `core/DebugLogSetup.lua` (DebugLog), `core/EnvSetup.lua` (Env), `core/MediaSetup.lua` (Media), `core/Compat.lua` (Compat), `core/LauncherSetup.lua` (Launcher), `core/LifecycleSetup.lua` (Lifecycle), `settings/OptionsSetup.lua` (Options), `settings/Slash.lua` (Slash) and `settings/SchemaSetup.lua` (Schema) — resolve their major with `LibStub(major, true)` and fall back when it is absent: a stub, a nil answer, or the client's own API. `core/CoreSetup.lua` publishes the one shared cause clause, **`NS.LIBKA0S_MISSING`**, *outside* its own `if not lib` branch, because `core/DebugLogSetup.lua`, `core/LauncherSetup.lua`, `settings/OptionsSetup.lua` and `settings/Slash.lua` read it on both paths; each appends its own consequence (`", so the debug console window is unavailable."`, `", so the settings panel is unavailable."`, `", so the settings CLI is unavailable."`, `", so there is no minimap button and no broker plugin."`) and the Core fallback printer announces once with `"; running on reduced built-in fallbacks."`. A degraded install therefore says the same thing about **why** at every site and a different thing about **what** at each one. That is a cross-file contract, not an implementation detail of one file.
- **`settings/OptionsSetup.lua`'s stub is LOAD-COMPLETING, not member-answering** — the one documented exception (options-ui-§1). Its members are no-ops rather than honest-line printers because a page file that touched one *at file load* would raise and take a third of the schema with it. WhatGroup's measured load-time set is empty, and `tests/test_libka0s.lua` pins that by loading with the library absent and comparing the schema row count against a full load.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — the third arg `true` shares one `Default` profile across every character on the account. WhatGroup is account-wide by design.
- **`Settings.Register()` is idempotent.** The `WhatGroup._settingsRegistered` guard means it can be called multiple times without re-registering categories. It runs from `OnEnable` (PLAYER_LOGIN) so the panel is in the Settings → AddOns list at login — the same place every other Ka0s addon registers — and again, as a no-op, from `runConfig`. Registering a canvas category at login is taint-safe; WhatGroup's real boot-taint sources (the secure teleport button + `UISpecialFrames` insert) stay deferred in `modules/Frame.lua`. See [docs/settings-panel.md](./settings-panel.md#lazy-panel-build) and [docs/midnight-quirks.md](./midnight-quirks.md).
- **Parent settings category is the landing page.** The parent never carries schema widgets — instead it shows the logo, TOC notes, and the slash-command list. `/wg config` calls `Helpers.OpenOptionsPanel()` and nothing else: since the `LibKa0s-Options-1.0` adoption that member is the **library's**, and it holds the main category's own ID, opens the parent, and unfolds the sidebar tree through the private `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` traversal (`pcall`-wrapped, because that shape is Blizzard internals). The `InCombatLockdown()` refusal lives inside `OpenOptionsPanel` too, so **every** caller is refused rather than just this verb (options-ui-§2). The user lands on the landing page with one click separating them from the General settings. See [docs/midnight-quirks.md](./midnight-quirks.md#settings-api-parent-vs-subcategory).
- **Join notify uses a dual-path trigger.** `WhatGroup:_TryFireJoinNotify(reason)` is the single entry point that schedules `ShowNotification` + `ShowFrame`. It's called from BOTH the `GROUP_ROSTER_UPDATE` not-in → in transition AND the `LFG_LIST_APPLICATION_STATUS_UPDATED` `inviteaccepted` handler — because retail can fire those in either order, and the old "fire only on roster transition when pendingInfo is set" gate would silently miss when `inviteaccepted` arrived after the transition. A `notifiedFor` identity flag (the `pendingInfo` reference that already triggered) prevents double-firing when both paths catch the same join.
- **Capture state is session-only.** `capturesByResult`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor`, and the `self.notifyTimer` AceTimer handle never touch SavedVariables. Group-leave and the master-switch off-flip both route through `WhatGroup:WipeCapture()`, which clears all of them.
- **The master switch is a LATCH, not a gate.** Flipping `db.profile.enabled` to false (panel checkbox, `/wg disable`, `/wg set enabled false`, a profile switch) takes the `disabled` hold on the one `LibKa0s-Lifecycle-1.0` instance, and the latch runs `NS.StandDown` — every event unregistered, every timer canceled, the popup off screen at the source. `WhatGroup:WipeCapture()` is one line of that teardown and is also reused on group-leave. There is **no second teardown path**: an addon with two mechanisms that both mean "be inert" has two things to keep in step, and they diverge on the first module added after the second one was written. See `## The stand-down`.
- **Notify timer is an AceTimer one-shot, canceled by `WipeCapture`.** `_TryFireJoinNotify` schedules the notify via `self:ScheduleTimer(fn, notify.delay)` (AceTimer-3.0) and stashes the handle in `self.notifyTimer`; `WipeCapture` `self:CancelTimer`s it so a scheduled callback can't fire after group-leave or the master-switch off-flip. The callback also re-checks `self.pendingInfo` identity before firing, guarding a same-tick replacement. Prevents an empty-data popup auto-opening during the delay window.
- **Combat-defer for the secure popup.** `modules/Frame.lua` guards two secure-frame writes against `InCombatLockdown()`: (a) `ConfigureTeleportButton` stashes `info` and reruns on `PLAYER_REGEN_ENABLED`, through the combat-end queue `OnCombatStateChanged` drains; (b) `WhatGroup:ShowFrame` defers the first-time `buildFrame()` past combat, printing a `Popup deferred until combat ends.` chat hint. Without these guards, secure-attribute writes on `SecureActionButtonTemplate` would silently drop in combat and leave the teleport button stuck in a stale state. `Settings.Register()` is **not** a third case — canvas-category registration is not a secure write and is not gated (options-ui-§9).
- **Cyan `[WG]` chat prefix on every user-facing line, through one secret-safe printer.** Every chat line funnels through `NS.Util.print` — `LibKa0s-Core-1.0`'s printer, built in `core/CoreSetup.lua` and exposed as `NS.Print` / `WhatGroup._print` and a file-local `p` in `core/WhatGroup.lua`. It prepends `NS.PREFIX = "\|cff00FFFF[WG]\|r"` and runs each argument through `NS.SafeToString`, so a combat-protected value degrades to `<secret>` instead of raising in the chat path (events-frames-taint-§8 / WG-22); call sites pass label and value as **separate args** rather than pre-concatenating (WG-23). **Debug output does not go to chat** — it routes to the on-screen debug console (`NS.Debug(tag, …)` → `LibKa0s-DebugLog-1.0`, wired in `core/DebugLogSetup.lua`), wearing the same shared Ka0s window edge the popup does, as required for any addon with a main window (debug-logging-§7). Each console line is `HH:MM:SS | [Tag] message`. The log carries a thin always-shown scrollbar synced both ways to its scroll offset and a `N / 1500 lines` counter in the same monospace font (debug-logging-§11), driven only by the Lua mixin scroll API — the C getters are nil on a `ScrollingMessageFrame` (anti-pattern #41). Debug state is session-only (`NS.State.debug`), off on every login, never persisted. See [docs/debug-content.md](./debug-content.md).
- **Debug state is session-only, and the console is the only sink.** `NS.State.debug` (debug-logging-§5 / WG-12) is **off** on every login, is **not** a schema row, and is never written to SavedVariables — don't reintroduce a `db.profile.debug`, and don't add a chat `[DBG]` sink. `/wg debug` toggles the console **window**; `/wg debug on|off` toggles logging — both route through the single `NS.DebugLog:SetEnabled` seam. See [docs/debug-content.md](./debug-content.md).
- **English-only, but the locale shell is mandatory.** Every *player-facing* string the addon authors is routed through `NS.L[...]` (`locales/enUS.lua`), whose fall-back metatable returns the key, so English needs no translation table. Three classes stay unrouted on purpose — slash-CLI diagnostics, strings that double as identifiers (`"General"`, `"Master controls"`, `"Ka0s WhatGroup"`), and strings `LibKa0s-Options-1.0` authors — and that partial routing is a **ratified deviation**, listed with its reasoning and its re-check trigger in [`## Documented deviations`](#documented-deviations) below. Localization *content* is a deliberate non-goal ([docs/scope.md](./scope.md)); the locale *shell* (localization-§3 / WG-07) stays. Playstyle enum values still read Blizzard's `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` globals — those are Blizzard's strings, not ours.
- **Delayed timers use AceTimer-3.0 (WG-17).** AceTimer is the standard's mandated timer lib and is mixed into the addon (`NewAddon(…, "AceTimer-3.0")`). The one-shot notify delay runs through `self:ScheduleTimer(fn, delay)` with the handle stashed in `self.notifyTimer` and canceled by `WipeCapture` via `self:CancelTimer`. The two `C_Timer.After(0, …)` calls that remain are next-frame secure-defer hops (moving panel/frame builds out of Blizzard's secure-execute chain) — a taint-avoidance idiom, not delayed timers, so they stay raw and each carries a justification comment.
- **Debug console uses a non-Blizzard monospace font (deliberate; WG-20, now closed into the library-stack media rule).** The debug-logging standard (debug-logging-§2) requires the on-screen console to render monospace, but retail ships no guaranteed monospace face — so JetBrains Mono (OFL) is used. **It is no longer this addon's copy.** WG-20 justified vendoring one under `media/fonts/`; the face now arrives with the LibKa0s payload at `libs/LibKa0s/media/fonts/`, and `core/MediaSetup.lua` resolves it through `LibKa0s-Media-1.0` (library-stack-§8). What was a per-addon deviation is now the collection's shared media rule, and a private copy of it would be anti-pattern #63. It is still the only non-Blizzard default font the addon draws with; every other FontString uses a `GameFont*` object. Resolution at `NS.FONT_MONO` in `core/WhatGroup.lua`, which falls back to the client's own `STANDARD_TEXT_FONT` — never to a dead path, because `SetFont` fails silently. `core/DebugLogSetup.lua` then probes the resolved path with `CreateFont` before handing it to the library and substitutes `Fonts\\ARIALN.TTF` if the client cannot fetch it — debug-logging-§2's fetch-failure fallback, now the third rung of the ladder rather than the second.
- **Settings landing page shows a vendored brand-logo texture (deliberate, WG-21).** `settings/Panel.lua` draws the addon's own `media/logos/whatgroup.logo.tga` — the only non-Blizzard default texture in the addon; every backdrop, border, and divider elsewhere is a Blizzard asset (`WHITE8X8`, `UI-Tooltip-Border`, the `Options_HorizontalDivider` atlas, spell icons). Branding art, analogous to the TOC `IconTexture`; no standards section mandates Blizzard-only textures, so this is a deviation from the addon's Blizzard-default-only baseline, not from the standard.
- **Lazy AceGUI panel build, plus this addon's extra frame hop.** The library owns *when* a page draws — first `OnShow`, and again when a refresh marked a hidden page dirty — and it calls the renderer and `EnsureDefaultsButton` **synchronously** inside that `OnShow`. WhatGroup does not: `settings/OptionsSetup.lua` wraps both members **on the instance** so the work runs on the next frame, because Blizzard's GameMenu / Logout flows can dispatch a settings canvas's `OnShow` inside a secure-execute chain and creating AceGUI frames there was tripping `ADDON_ACTION_FORBIDDEN` on the Logout button. Wrapped on the instance rather than beside it, because the library resolves both from `O` at call time. Host-shaped, so it stayed local (`LIBKA0S-07`); options-ui-§9 sanctions the library's synchronous form, and this is the addon keeping a belt it had already fastened. The AceGUI ScrollFrame parented to each panel hooks `OnSizeChanged` to forward dimensions into AceGUI's layout pipeline. Without this, parented-to-Blizzard containers stay at 0×0. The header's **Defaults button builds in that same deferred hop** rather than at `Settings.Register` time: it's an AceGUI widget, and UI skins restyle those by hooking `RegisterAsWidget`, so one created during load keeps Blizzard's stock red button art for the session (options-ui-§5). Its click handler is parked at registration as `panel.defaultsOnClick` and wired by the builder. See [docs/settings-panel.md](./settings-panel.md#lazy-panel-build) and [docs/midnight-quirks.md](./midnight-quirks.md#lazy-acegui-panel-build).
- **Defaults button + `/wg resetall` share one popup.** Both routes call `StaticPopup_Show("WHATGROUP_RESET_ALL")`; the OnAccept body lives in `settings/Schema.lua` and calls `Helpers.RestoreAllDefaults()`. No second confirmation path can drift from the first. **`/wg reset` now takes a PATH** and resets one row without confirmation — a breaking change taken deliberately ([`LIBKA0S-13`](https://github.com/tusharsaxena/WhatGroup/issues/8)), because `reset` means one row everywhere else in the collection. A bare `/wg reset` is intercepted and answered with both replacements rather than with a usage line.
- **`Helpers.RestoreAllDefaults` deliberately OVERRIDES the library's, and is a profile reset.** `LibKa0s-Options-1.0` ships a member of that name and this addon's wins. It is now one `db:ResetProfile()` (`options-ui-§12`): AceDB empties the active profile **in place**, merges the defaults back, and fires `OnProfileReset`. The wipe-then-re-thread loop it replaced had the right instinct — a reset should yield a *pristine* profile rather than default-valued known keys, dropping any value from a removed or renamed schema row — and the wrong mechanism, because a row walk can only address rows and so can never restore a stored **array**. It logs **one** line, `[Set] reset profile '<name>' to defaults (N rows)`, and never a `[Set]` per row (debug-logging-§10). The line comes from the `OnProfileReset` handler, not from this function, because §10 has the profile-event handler log a wholesale replacement. What this function contributes is N, since only it runs before the reset: the profile rows whose stored value differs from the default just beforehand, which are the rows the reset actually changes. A row already at its default is not counted, and neither is an orphaned key that no row names. A reset driven straight at the db logs the same line without a count. If `db:ResetProfile()` raises before AceDB fires the event, the count is cleared all the same, so no later reset can claim it. The line is then logged once, from here, without a count and with ` (stopped by an error)` appended, and the error is re-raised. The library's per-page `RestoreDefaults(pageKey, ctx)` is a different verb with a different arity and is left alone. Copying the host's members onto the instance only where the instance was nil silently handed callers the library's row-by-row form — see [`LIBKA0S-08`](https://github.com/tusharsaxena/WhatGroup/issues/10).
- **Profile callbacks, which this addon had none of.** `core/WhatGroup.lua` registers `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` right after `AceDB:New`; each re-runs the migrations (an incoming copied profile may predate the current schema version) and refreshes every open panel. `OnProfileReset` also logs the reset's one `[Set] reset profile '<name>' to defaults (N rows)` line first (debug-logging-§10). It takes N from `Settings.ConsumeResetCount`, and a reset that did not come through `RestoreAllDefaults` has no count and logs the line without one. A copy logs one `[Set] copied profile '<A>' → '<B>'` line from its handler, the `WhatGroup:OnProfileCopied` method, naming the source key AceDB passes and the active profile it landed in. A switch logs nothing, because this addon ships no profile UI. A reset that fires inside an open `Settings.Bulk` bracket silences that bracket, so the act keeps its one line. It went unnoticed for as long as nothing switched profiles — until the global reset became a profile reset and started firing the same event.
- **`Settings.Helpers` IS the library instance** (options-ui-§1), decorated in place: `settings/Schema.lua`'s data seams move *onto* it, never the library's members into a host table. `RenderRows` resolves `RenderField` from the instance at call time, so a copy-across would give a test — and a host page helper — a member nobody calls.
- **ONE launcher object, registered twice, and the rung is (a).** `core/LauncherSetup.lua` builds a single LibDataBroker-1.1 object of `type = "launcher"` and hands THAT object to LibDBIcon-1.0 (launcher-§1): one `OnClick`, one icon, one label, one identity, so the minimap button and any broker display cannot drift apart. Both registrations use the addon's FOLDER name, because LibDBIcon keys the button's saved position by it; the object's **`label`** is the brand name in plain text, **`Ka0s WhatGroup`** (launcher-§1), which is what a broker display prints beside the other ten Ka0s rows — not the TOC `Title` and not the folder name. **Left-click toggles the group popup** through `WhatGroup:ToggleFrame` — the addon's own seam, whose close arm is the same `dismissPopup` body the Close button and ESC run — and **right-click always opens the settings panel** through `WhatGroup:OpenSettings`, the `/wg config` body. The launcher keeps no copy of either state, and there is no setting that reassigns either button. Visibility is the one **global** schema row, `global.minimap.shown` (stored at `db.global.minimap.hide`; see `## Settings Schema`), and **it survives every reset this addon ships** — a property of the row rather than of its store (launcher-§3, standard v2.54.0), and true here without an exemption because all three reset surfaces land on one `db:ResetProfile()` body: see [docs/settings-panel.md → The minimap button row](./settings-panel.md#the-minimap-button-row). The broker object itself has no toggle, deliberately, because a display already offers the player one.
- **Don't overwrite `category.ID`.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/WhatGroup/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/` are the same repo via symlink; either path works for git and file tools.
- **CRLF on disk.** `.gitattributes` enforces CRLF for `.lua` / `.toc` / `.xml` (WoW client expectation) and for `.md`. The generated `docs/test-cases.md` no longer needs a `sed`/`tr` pair: the shared kit's `--list` renderer writes CRLF itself, so a plain redirect is correct ([docs/testing.md](./testing.md)).
- **Match the sibling addons.** WhatGroup is on the same shared library as the rest of the collection: `libs/LibKa0s/` and `tests/_kit/` are **whole-folder copies** of `../LibKa0s`'s ship folders and MUST stay byte-identical to them — never edit either in place, and never copy a single file. A library problem is a finding to fix upstream and re-vendor ([docs/testing.md](./testing.md), [docs/common-tasks.md](./common-tasks.md#refresh-embedded-libs)). The Ace3 libs are copied verbatim from KickCD (except `LibSharedMedia-3.0`, from AbsorbTracker).

## External dependencies

All vendored under `libs/`; where each was copied from and what each is for is in
[module-map.md → Embedded libraries](./module-map.md#embedded-libraries). Ace3 (`LibStub`,
`CallbackHandler-1.0`, `AceAddon-3.0`, `AceEvent-3.0`, `AceConsole-3.0`, `AceTimer-3.0` — the
mandated timer lib, WG-17 — `AceDB-3.0`, and `AceGUI-3.0` via its `.xml`), `LibSharedMedia-3.0`,
the launcher's `LibDataBroker-1.1` and `LibDBIcon-1.0` (`OptionalDeps`, `launcher-§1`), and:

- `LibKa0s` (loaded **last**, via its own `LibKa0s.xml`) — the shared Ka0s addon library. WhatGroup takes ten of its majors: **Core** (the prefixed secret-safe printer, `SafeToString`, the shared window skin, the close-button factory), **Env** (the TOC-manifest reader behind `NS.Meta` / `NS.Version`), **Compat** (the spell name, icon and cooldown readers behind `NS.Compat`, since v1.55.0), **Media** (the icon catalog and the monospace face), **DebugLog** (the on-screen console), **Options** (the settings-canvas shell, the widget makers and the two-column flow engine), **Schema** (the settings schema's runtime — the path walk, the row index, the single write seam, the bulk bracket and the reset count — as `NS.SchemaRuntime`, wired in `settings/SchemaSetup.lua` and `settings/Schema.lua`, [#22](https://github.com/tusharsaxena/WhatGroup/issues/22)), **Slash** (the dispatcher, the help renderer and the schema CLI), **Launcher** (the one LibDataBroker object, both registrations and the click dispatch) and **Lifecycle** (the stand-down latch and its two named holds). **Perf is declined** on structural grounds — no hot path, and `suspend` would stop a capture addon capturing ([`LIBKA0S-15`](https://github.com/tusharsaxena/WhatGroup/issues/7)) — and so is **Bus**, because there is no bus ([#21](https://github.com/tusharsaxena/WhatGroup/issues/21)). Schema's seam refuses a write to a path with no row, and on a library-absent load `enabled` and `state.testMode` have none; no `writeThrough` list is passed, so there `/wg enable`, `/wg disable` and `/wg test` print the library-absent line instead of writing — `options-ui-§1` route (b), the owner's ruling on #22, recorded in `## Documented deviations`. The folder is vendored whole regardless, because the other majors sit on `Core` and a hand-picked subset is anti-pattern #48.

WoW retail APIs the addon depends on: `C_LFGList.ApplyToGroup` / `GetSearchResultInfo` / `GetApplicationInfo` / `GetActivityInfoTable`, `C_Spell.GetSpellName` / `GetSpellTexture` / `GetSpellLink` / `GetSpellCooldown` (the legacy `GetSpell*` globals are the fallback rung for all but `GetSpellLink`, which degrades straight to `nil` — `core/Compat.lua:67-72`; the name, texture and cooldown ladders are `LibKa0s-Compat-1.0`'s), `C_SpellBook.IsSpellKnown` (the `IsSpellKnown` global is its fallback rung), `C_Timer.After`, `GetTime`, `IsInGroup`, and, for the details chat link, `LinkTypes.AddOn` plus `EventRegistry:RegisterCallback("SetItemRef", …)` (both detected in `NS.Compat.AddOnLinkType`; `SetItemRef` is post-hooked only when either is missing). Teleport casting goes through a `SecureActionButtonTemplate` `macrotext` (`/cast <SpellName>`) — **not** `CastSpellByID`, which a non-secure addon click would trip `ADDON_ACTION_FORBIDDEN` on. Settings API: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`. Frame chrome: `BackdropTemplate`, `SecureActionButtonTemplate`, `UISpecialFrames`.

## Load order

`WhatGroup.toc` is the source of truth, and the order is dependency, not alphabetical: the vendored
libraries first (`LibKa0s` last among them), then the addon files by folder in the `toc-file-§5`
section order — `# Locales`, `# Core`, `# Defaults`, `# Modules`, `# Settings`. A few slots are
load-bearing (`core/CoreSetup.lua` first in `# Core`, `core/MediaSetup.lua` before
`core/WhatGroup.lua`, `settings/SchemaSetup.lua` directly above `settings/Schema.lua`); the rest are
conventional. Hooks install at file load, `OnInitialize` builds the db, and `OnEnable` registers the
events, the settings category and the launcher. The per-file list with each slot's reason, the
shared file header and the `OnInitialize` / `OnEnable` lifecycle are in
[module-map.md → Load order](./module-map.md#load-order).

If you add a new runtime file, put it in the right place in `WhatGroup.toc` (after libs, after the file it depends on).

## Known Limitations

Things the addon does not do, and the reason each is a boundary rather than a bug. Scope decisions are reasoned in [docs/scope.md](./scope.md); a limitation that is a *ratified standards deviation* lives in the table below this one, not here.

- **Capture is session-only.** `capturesByResult`, `pendingApplications`, `pendingInfo`, `wasInGroup` and `notifiedFor` never touch SavedVariables, so `/reload` mid-application loses the pending capture and the join that follows prints nothing. Deliberate: the data describes a group you are in right now, and persisting it would resurface a stale group after a relog.
- **Only groups joined through the Premade Group Finder are captured.** A guild or party invite carries no LFG search result, so there is nothing to observe. `/wg test notify` exists precisely because the real path cannot be exercised on demand.
- **Teleport is limited to dungeon Path-of spells the player has learned.** The button renders grayed until `IsSpellKnown` says otherwise, and only for map IDs present in `defaults/TeleportSpells.lua` — a hand-maintained table, so a newly added dungeon needs a data update.
- **English only.** The locale shell (`locales/enUS.lua`, `NS.L`) is mandatory and every authored player-facing string routes through it, but translation content is a non-goal (localization-§1 / WG-07). The partial routing is ratified in the deviation table, re-check trigger "the first non-English locale file".
- **No profiler wiring.** `LibKa0s-Perf-1.0` is vendored but not wired; see the deviation table.
- **A load missing LibKa0s draws the teleport button bare.** The spell name, icon and cooldown reads are `LibKa0s-Compat-1.0`'s, and without the library they answer its documented no-answer values rather than a copy of its ladder (LibKa0s `docs/api/Compat/version-1-docs.md`, *Degradation*). The popup shows the question-mark icon and no cooldown, and the secure `/cast` macro has no name. It never raises, and that install is already announced once by `core/CoreSetup.lua`.

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
| `slash-dispatch.md` | Present | 13 verbs in the command table |
| `midnight-quirks.md` | Present | LFG and group-API behavior the addon works around |
| `debug.md` | Not applicable | No debug surface beyond the LibKa0s console: no debug verb, dump or window of the addon's own. The addon-owned debug content is the Tier 3 `debug-content.md` |
| `message-bus.md` | Not applicable | Below the `architecture-§4` threshold: a shell plus one feature module, so no cross-module messages (see `## Message Bus`) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes six addon-specific shims, over the three-or-more threshold |
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
| `stand-down.md` | What disabled means here: the one latch and its two holds, what goes down and what survives, the combat-owed `Hide`, the launcher click. Tier 3 because the stand-down is this addon's wiring of `slash-commands-§7`, not a Tier 1 or Tier 2 subject |
| `debug-content.md` | What WhatGroup feeds the LibKa0s console: the descriptor, the tag vocabulary, the session flag, `/wg debug`. Tier 3 because the Tier 2 `debug.md` trigger has not fired, yet this content is the addon's own and not the library's |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`). A decision may be *reasoned* at length in this repo's GitHub issues and the **Why** cell cites that id — but **a deviation not in this table is not ratified**, and an audit files it as an open MUST failure. **Re-check trigger** is the condition that ends the deviation, stated so a reader can tell whether it has already fired; a row without one is a permanent opt-out wearing a table's clothes. A row whose cited rule the standard has since changed is **retired**, not kept.

A `WG-NN` or `WG-A-NN` id in a **Why** cell is a deviation an audit filed and resolves in `docs/audits/`; one followed directly by a dated bundle — `WG-37 (docs/audits/2026-08-05/)` — resolves in that bundle. A review finding is cited as `F-NNN` **followed directly by its dated bundle** — `F-006 (docs/reviews/2026-08-05/)` — and resolves in that bundle's `01_FINDINGS.md`: review ids restart at `F-001` in every bundle, so a bare one names a different finding in each. The same holds for the 2026-09-07 review's `WHATGROUP-R-NN` ids and this repository's `WG-R-NN` shorthand for them — code comments and suites use the short form too — which resolve only beside `docs/reviews/2026-09-07/`. `tests/test_register.lua` holds every cited id to this key, and does not count an audit bundle's `## Recorded deviations` echo of this table as assigning anything.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§12` (the exemption is not claimed) | **The no-combat-path exemption was claimed on 2026-08-02, ended on 2026-08-06, and the wiring is still declined.** `modules/Frame.lua:524` arms a 1-second `ScheduleRepeatingTimer` for the teleport cooldown countdown — a repeating ticker, which is the exact condition `performance-§12` names as re-arming the full wiring MUST. Nothing was wired in response: still no `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb registration, no suspend/resume contract, no `docs/perf-analysis/`. **`tests/perf.lua` is the one piece that has since been built (2026-09-16)** — offline scenarios suspend nothing, ship nothing to the client and add no SavedVariable, so none of this row's argument bore on them, and the `perf` suite now reads `pass` rather than `skip`. The **in-game** half stays declined, which is what the rest of this row is about. | The trigger fired on the letter of `performance-§12`, but **only criterion (a) broke; (b) and (c) did not.** Every declared bucket would still read `0.000` — `performance-§3` calls such a bucket *a lie in every report* — and `suspend` would still make a *capture* addon miss the apply or invite-accept it exists to record. Wiring Perf here buys a `perf` verb dispatching into an instance with nothing to say, plus a second SavedVariables global, to account for one `C_Spell.GetSpellCooldown`, one formatted string and one `SetText` per second **while a popup the player opened is on screen showing a live cooldown**. The ticker cannot outlive that window, and **as of 2026-09-08 that is enforced rather than asserted**: the arm is behind `f:IsShown()` and re-run from the popup's `OnShow`, so it is one handle, replaced not stacked, armed only against a frame on screen and canceled from the popup's `OnHide`, from the top of every `ConfigureTeleportButton`, and by the tick that reaches zero — pinned by seven cases in `tests/test_frame.lua`. Between 2026-08-06 and that date the claim was false in one direction: `applyTeleportNote` armed before `ShowFrame` reached `f:Show()`, and `OnHide` fires only on a transition, so a popup the `inCombat` / `outOfCombat` gate declined to show left a ticker with no cancel site. Amended in place rather than re-decided, because the defect was in the enforcement and not in the argument. The addon also gained its first `PLAYER_REGEN_DISABLED` registration on the same date (`core/WhatGroup.lua:312`): one gate evaluation twice per pull, and then at most one `Show` on the entering edge or one `Show` or `Hide` on the leaving one — the entering edge cannot hide at all, because `f` parents a secure child and the client refuses `Hide` under lockdown (`M2-28`). The regenerated sweep is in [`performance.md`](./performance.md), which since 2026-09-16 also carries the **measured** cost of that ticker rather than the asserted one: two API calls and 240 bytes per second-tick, and a combat transition that changes nothing measured at zero of both. This row's central factual claim is now checked by a suite on every run. **An amendment is proposed upstream** — that §12's trigger should exempt a ticker gated on an addon's own transient window — and if it is accepted this row retires in favor of a row claiming the exemption. Justification comment at `cooldownTimer` in `modules/Frame.lua`. | 2026-08-06 | **Two triggers, either one ends this row.** (1) The upstream §12 amendment lands — this row retires, and the exemption is claimed afresh against the amended text rather than re-asserted from the old one. (2) The ticker stops being window-bounded, or a second repeating timer appears, or any repeating work starts running with the popup closed — at which point (a)'s spirit is gone too, not just its letter, and the **full wiring is wired**, not re-argued. |
| `localization-§1` | **English-only, and the routing SHOULD is met in part.** Both MUSTs are unconditional and are met: the `NS.L` seam is exported from `locales/enUS.lua`, and `enUS.lua` ships and loads first (`toc-file-§5`). What deviates is the routing SHOULD — three classes of string stay unrouted literals. (1) **Slash-CLI diagnostics** — `"unknown command"`, `"Usage: …"`, `"debug logging ON/OFF"`. (2) **Strings that double as identifiers** — `"General"` is at once the options page id (`Helpers.RegisterOptionsPage("general", "General", …)`) and the Blizzard subcategory label, and `"Master controls"` is simultaneously a schema `group`, a tab label and the `afterGroup` key its button pair hangs from (`options-ui-§15`); `"Ka0s WhatGroup"` is the brand, carried by the TOC `Title`, the parent category and the debug-console title. (3) **The library's own copy** — the `Defaults` button label and the combat-refusal notice are `LibKa0s-Options-1.0`'s `DEFAULTS_LABEL` / `COMBAT_REFUSED`, authored there. | English-only is a stated project non-goal ([`scope.md`](./scope.md)), so the routing SHOULD's only beneficiary is a translator who does not exist yet — and the seam plus the shipped `enUS.lua` are exactly what makes one cheap to onboard later. Routing class (2) would be actively wrong, not merely unnecessary: translating `"General"`'s display copy without translating the schema `group` key unmatches the two and empties the page, which is a live bug rather than a missing translation. Class (3) would install a second source of truth for a string the library owns. Class (1) is developer feedback on a command line, not player chrome. Five keys that no `L[…]` ever read — `"Ka0s WhatGroup"`, `"General"`, `"Defaults"`, and the combat-refusal notice, plus the landing heading — were the standing evidence that this had never been decided; four are deleted and `"Slash Commands"` is now routed, so the table states the real surface. `F-006` (`docs/reviews/2026-08-05/`). | 2026-08-05 | **The first non-English locale file.** Adding `locales/<X>.lua` re-arms the full routing SHOULD: audit every unrouted literal at that point, and resolve `"General"` by giving the page a stable non-display id before translating its label. |
| `events-frames-taint-§8` | **The pre-formatting SHOULD is not met at every site, and two `pout` fallbacks end in the global `print`.** Chat lines are built with `..` / `tostring` before they reach the seam — `core/WhatGroup.lua:744`, `:752` (the join summary's gold-labeled rows) and `:760` (its details-link row). (The debug lines no longer are: every `NS.Debug` call passes a format and the raw values, debug-logging-§4.) Separately, `settings/Panel.lua`'s and `settings/Schema.lua`'s file-local `pout` helpers fall back to a bare `print(...)` when `WhatGroup._print` is unset. | **Re-graded under the scoped rule (`M1-STD-11` option (a), 2026-08-05).** §8's pre-formatting MUST NOT is now scoped to call sites whose arguments can reach a value read from one of the named combat-protected APIs; everywhere else it is a SHOULD NOT, and the risk is future drift rather than a live raise. A committed whole-repo sweep — `grep -rnE 'UnitGetTotalAbsorbs\|UnitGetTotalHealAbsorbs\|UnitGetIncomingHeals\|UnitHealth\|UnitHealthMax\|UnitThreatSituation\|UnitDetailedThreatSituation\|C_UnitAuras\|GetPlayerAuraBySpellID\|"UNIT_AURA"'` over `core/ defaults/ locales/ modules/ settings/` — returns **zero** hits: WhatGroup reads LFG search-result data only (strings, integers, booleans from `C_LFGList`), so **no site in this addon is in the trigger set** and every one of them is a SHOULD. `grep -rcE 'print\(\(".*"\):format' settings/` is `0` in all four files. The seam's own guarantee is unaffected and is met: `NS.Print` is `LibKa0s-Core-1.0`'s prefixed printer and runs every argument through `NS.SafeToString` (WG-22), and `NS.Debug` routes through the library sink. The **two `pout` fallbacks are a separate matter and are NOT re-graded away** — §8 keeps the no-global-`print` prohibition unqualified. They stand because they are **unreachable**: `core/WhatGroup.lua` sets `WhatGroup._print` and the TOC loads it before `settings/`, so the branch cannot execute, which grades it Info (no user, no session, no SavedVariables reaches it). They are kept as load-order defense, not as sanctioned output. `WG-37` (`docs/audits/2026-08-05/`). | 2026-08-05 | **Two triggers, either one ends this row.** (1) The first call to any API in §8's trigger set, or any value derived from one, entering a chat or debug line — that site converts as a **MUST** and the sweep above is regenerated. (2) Anything that makes a `pout` fallback reachable — a TOC reorder putting a `settings/` file before `core/WhatGroup.lua`, or a caller invoking `pout` at file load — at which point the bare `print` is a live MUST-NOT failure and the fallback goes rather than being re-ratified. |
| `standalone-windows` | The popup's footer **Close** button (`modules/Frame.lua`, `UIPanelButtonTemplate`, 90×24) carries **no mark beside its label** — just the word *Close*, centered on the template's own art. The SHOULD it departs from is *"a wide action button keeps its label and gains a mark beside it"* — cited by bare filename because `standalone-windows.md` carries no numbered subsections for a `§N` to resolve into (`WG-52`). The mark was drawn (a `decorateCloseButton` helper tinting the catalog's `close` icon at 12×12 on the button's left) and has been removed. | That SHOULD exists for buttons whose action lands **somewhere outward** — its own examples are *Export to CSV* and *Print to Chat*, and its stated reason is that "which one posts to guild?" should not be a question answered by hovering. Dismissing a dialog is neither outward nor ambiguous: it is the one verb every window in the collection already shares, the label says it in full, and the button is the popup's only footer control, so there is nothing for a mark to disambiguate it **from**. The `close` mark's own home is the title-strip control — the same section's *title-bar control strip* and *close control* bullets — where a small square target has no room for a word; repeating it on a labeled 90px button read as a second, competing element rather than as reinforcement. Decided by the user on the screenshot. | 2026-08-25 | The footer gains a **second** wide action button (an export, a report, a link-to-chat) — at which point the row of buttons is exactly the surface that SHOULD is about, and every button in it takes its mark, Close included. Also fires if `standalone-windows` is amended to name dismissal controls explicitly either way. |
| `standalone-windows` | `UISpecialFrames` holds an unprotected proxy (`WhatGroupFrameEscape`) that mirrors the popup being on screen, not `"WhatGroupFrame"` | The popup parents a `SecureActionButtonTemplate`, so the client blocks Escape's direct `WhatGroupFrame:Hide()` in combat (`ADDON_ACTION_BLOCKED`); the proxy's `OnHide` sends Escape through `hidePopup()` | 2026-09-12 | The popup stops parenting a secure child, or `standalone-windows` is amended to cover windows with secure content |
| `options-ui-§1` | **Route (b), not the SHOULD route (a), for the composed rows on a library-absent load.** On a load without LibKa0s the Master controls block is not composed (the hollow composer), so `enabled` and `state.testMode` have no schema row, and the schema seam (`LibKa0s-Schema-1.0`, or `settings/SchemaSetup.lua`'s stub) refuses a row-less path. Route (a) would hand the seam a `writeThrough` list so `/wg enable` and `/wg disable` still write `enabled`; WhatGroup passes **no list**, and `/wg enable`, `/wg disable`, `/wg test`, `/wg test on` and `/wg test off` print `<verb> is unavailable: the LibKa0s library did not load.` instead (`settings/Slash.lua`), with no Lua error, no write and no ack. | The owner's ruling on [WhatGroup#22](https://github.com/tusharsaxena/WhatGroup/issues/22) (2026-09-23), accepted as a known gap; composers stay hollow and no host copy is written (anti-pattern #73). Pinned by `tests/test_libka0s.lua`'s two degraded cases. | 2026-09-24 | A report of a library-absent install that needs the switch, `options-ui-§1` raising (a) to a MUST, or the owner reopening #22 |

**Retired on 2026-09-08: the claimed `performance-§12` exemption.** The register carried two `performance-§12` rows, the first claiming the no-combat-path exemption on 2026-08-02 and the second recording that its re-check trigger had **fired on 2026-08-06** when `modules/Frame.lua`'s teleport-cooldown `ScheduleRepeatingTimer` arrived. The first row said so of itself, in its own trigger cell, and was kept "only as the record of what was claimed and on what evidence". That is the graveyard `documentation-§3` forbids, and it is now reportable rather than merely wrong: `audit-review-history` MUSTs that an audit evaluate every trigger against the tree and report any row whose condition has already come true, because "that deviation ended on the day the condition came true, and every day the row stays in the register the document asserts a live deviation that is not one". It had asserted one for a month. The claim and the date it ended are not lost — they are the opening sentence of the row that survives, which is where a reader looking at today's deviation will actually be. The evidence is where it always was, in issue [#7](https://github.com/tusharsaxena/WhatGroup/issues/7) and in [`performance.md`](./performance.md)'s regenerated sweep.

### Files over the 1500-line cap

The `layout-§1` census: every authored `.lua` file this repository tracks that is over the 1500-line cap, with its terminal state. Vendored code (`libs/`, `tests/_kit/`) is out of scope, and this repository has no generated data to carve out.

Nothing is over the cap today. Measured 2026-09-24 with `git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -n`: the largest authored file is `tests/test_frame.lua` at 1421 lines, then `modules/Frame.lua` at 1165 and `core/WhatGroup.lua` at 1117. `tests/_kit/test_layout_cap.lua` holds this census to the tree on every run.
