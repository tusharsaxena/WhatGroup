# WhatGroup — Claude Context

## Project Overview

WhatGroup is a World of Warcraft (retail) addon. It hooks into the Premade Group Finder (LFG) flow to capture group details at apply time and display them when the player joins the group.

For a human-oriented architecture reference (module map, capture pipeline diagram, schema/settings system, saved-variables shape, conventions), see [ARCHITECTURE.md](ARCHITECTURE.md). This file is the agent-oriented companion — same facts, plus the development-policy notes that don't belong in user-facing docs.

## File Structure

| File | Purpose |
|---|---|
| `WhatGroup.toc` | Addon manifest (interface version, SavedVariables, lib + code load order) |
| `WhatGroup.lua` | AceAddon shell, event handling, capture logic, slash dispatch, teleport spell table |
| `WhatGroup_Settings.lua` | Settings schema rows + Helpers (Resolve/Get/Set/FindSchema/RestoreDefaults/BuildDefaults/RefreshAll) + canvas-layout panel builder |
| `WhatGroup_Frame.lua` | UI: popup dialog frame, field population, teleport button, value color resolvers |
| `libs/` | Embedded Ace3 — copied from Ka0s KickCD to keep versions aligned |

### Embedded libraries

`LibStub`, `CallbackHandler-1.0`, `AceAddon-3.0`, `AceEvent-3.0`, `AceConsole-3.0`, `AceDB-3.0`, `AceHook-3.0`, `AceGUI-3.0`. Loaded in that order at the top of `WhatGroup.toc`. AceGUI is last and loads via its `.xml` (which pulls in `widgets/`); the rest load via their `.lua`. Copy fresh from `KickCD/libs/` if you ever need to refresh.

## Key Architecture

- **`WhatGroup`** — AceAddon object (mixed in `AceConsole-3.0`, `AceEvent-3.0`, `AceHook-3.0`); also assigned to `_G.WhatGroup` so the other files can pick it up via the global
- **`WhatGroup.db`** — AceDB instance; `db.profile.*` is the persisted user-settings tree (shape derived from the schema by `Settings.BuildDefaults()`)
- **`WhatGroup.debug`** — runtime flag mirroring `db.profile.debug`; seeded in `OnInitialize`, kept in sync by `/wg debug` and the schema row's `onChange`
- **`WhatGroup.pendingInfo`** — the single group info object shown in the frame; set on `inviteaccepted`, cleared on group leave; **session-only**, never persisted
- **`WhatGroup:RunTest()`** — public method that injects synthetic `pendingInfo` and runs the full notification + popup flow. Both `/wg test` and the panel's Test button route here, so the two stay in lockstep.
- **`captureQueue`** / **`pendingApplications`** — module-locals in `WhatGroup.lua`; FIFO + appID-keyed map of in-flight captures; **session-only**
- **`wasInGroup`** — module-local in `WhatGroup.lua` tracking the prior in-group state; seeded in `OnEnable` from `IsInGroup()` and updated on every `GROUP_ROSTER_UPDATE`. The not-in→in transition is what triggers the post-join notification + popup; the in→not-in transition wipes `pendingInfo` and both queues. Session-only.
- **`WhatGroup.TeleportSpells`** — table mapping `activityID`/`instanceID` → `spellID` for dungeon teleports
- **`WhatGroup._parentSettingsCategory`** — the parent category ("Ka0s WhatGroup"); just a sidebar anchor, holds no widgets (12.0 hides parent widgets when subcategories exist)
- **`WhatGroup._settingsCategory`** — the **General subcategory** handle; this is what `/wg config` opens via `Settings.OpenToCategory(category:GetID())`, so the user lands directly on the populated page
- **`WhatGroup._settingsRegistered`** — re-entrancy guard for `Settings.Register()`
- **`CHAT_PREFIX`** — module-local cyan `[WG]` string prepended to every `print()` call; debug lines additionally tag `[DBG]` in orange

### Boot sequence

TOC load order: libs → `WhatGroup.lua` (NewAddon, OnInitialize/OnEnable methods defined) → `WhatGroup_Settings.lua` (stamps `Settings.Schema` + `Settings.Helpers` + `Settings.BuildDefaults` + `Settings.Register` on the addon) → `WhatGroup_Frame.lua` (creates the popup frame, attaches `ShowFrame`/`HideFrame` methods).

`ADDON_LOADED` for "WhatGroup" → AceAddon fires `OnInitialize` → `db = AceDB:New("WhatGroupDB", Settings.BuildDefaults(), true)` → seed `WhatGroup.debug` from `db.profile.debug` → register `/wg` and `/whatgroup` slash commands. Then `OnEnable` → register events (`GROUP_ROSTER_UPDATE`, `LFG_LIST_APPLICATION_STATUS_UPDATED`), install `SecureHook` on `C_LFGList.ApplyToGroup`, install `RawHook` on `SetItemRef`, call `Settings.Register()`.

### Event/Hook Flow

1. `C_LFGList.ApplyToGroup` SecureHook → `OnApplyToGroup` early-returns when `db.profile.enabled` is false; otherwise captures group info → pushed onto `captureQueue`
2. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"applied"` → dequeues capture → stored in `pendingApplications[appID]`
3. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"invited"` → no-op (waits for user to accept)
4. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"inviteaccepted"` → sets `WhatGroup.pendingInfo`, wipes queues
5. `GROUP_ROSTER_UPDATE` (transition from not-in-group to in-group) → `C_Timer.After(db.profile.notify.delay, ...)` → `ShowNotification()` always, `ShowFrame()` only if `db.profile.frame.autoShow`
6. `SetItemRef` RawHook → if link prefix `WhatGroup:`, call `ShowFrame()` and short-circuit; otherwise pass through to `self.hooks.SetItemRef(...)`

### Captured Info Fields

`title`, `leaderName`, `numMembers`, `voiceChat`, `playstyle`, `age`, `activityIDs`, `activityID`, `fullName`, `activityName`, `shortName`, `maxNumPlayers`, `isMythicPlus`, `isCurrentRaid`, `isHeroicRaid`, `categoryID`, `mapID`

### Frame Layout

- **Displayed rows:** Group, Instance, Type, Leader, Playstyle, Teleport
- **`VALUE_COLORS`** — per-field color resolver table; each field can define a `function(info) → hex` to colorize its value
- **`GetGroupTypeLabel`** is duplicated in both `WhatGroup.lua` and `WhatGroup_Frame.lua`
- **Playstyle labels** (`PLAYSTYLE_LABELS`) are also duplicated in both files
- The frame always shows every field; the `notify.show*` schema rows gate **chat output only**, not the popup

## Settings schema

`WhatGroup.Settings.Schema` is a flat array; each row declares one option:

```lua
{
    section,            -- groups in /wg list output (general, frame, notify, …)
    group,              -- heading shown in the Settings panel ("General", "Notify", …)
    path,               -- dotted path into db.profile (e.g. "notify.delay"). Omit for type="action".
    type,               -- "bool" | "number" | "action"
    label, tooltip,
    default,                -- omit for type="action"
    min, max, step, fmt,    -- numbers only
    onChange,               -- optional fn(value) called by both panel widget and /wg set
    onClick,                -- type="action" only: fn() called when the panel button is clicked
    solo,                   -- if true, render alone in the left half of its own row (right half empty)
    spacerBefore,           -- if true, insert a blank row before this widget
    panelHidden,            -- if true, skip the row in the panel renderer (still in /wg list/get/set)
}
```

**Action rows** (`type = "action"`) render as a Button widget in the panel and participate in the two-column pairing — placing an action row immediately before a bool/number row puts both on the same line. They have no `path` and no value, so `BuildDefaults` / `RestoreDefaults` / `/wg list` / `/wg get` / `/wg set` skip them. The current Test row is the only action; its `onClick` calls `WhatGroup:RunTest()`.

The General subcategory renders the schema as a two-column Flow layout (50%/50% per row). Widgets pair into rows by default; `solo = true` forces a widget onto its own row; `spacerBefore = true` flushes the in-progress row and adds a blank row before the widget. `group` transitions emit a `Heading` widget. The renderer lives in `renderSchema()` inside `WhatGroup_Settings.lua` — direct port of KickCD's `Helpers.RenderSchema` shape, scaled down (no `valueGate`, no `afterGroup`, no `panelKey`).

Adding an option = one row. The same row drives:

| Surface | How |
|---|---|
| Settings panel widget | `renderSchema()` walks the schema and dispatches each row via `makeField()` to `makeCheckbox` / `makeSlider` / `makeActionButton`; the value widgets register a refresher closure in `Settings._refreshers` (action buttons skip this since they have no value) |
| `/wg list` | groups schema by `section`, prints `path = formattedValue` |
| `/wg get <path>` | `Helpers.FindSchema(path)` + format |
| `/wg set <path> <value>` | type-aware parse (bool accepts true/false/on/off/1/0/yes/no/toggle; number clamps to `min/max`) → `Helpers.Set` → `onChange` → `RefreshAll` |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each `default` into the right slot under `profile.*` |
| `/wg reset` | `Helpers.RestoreDefaults()` resets every row to its `default`, runs `onChange`, refreshes panel |

### Current schema rows

Order matches panel render order:

| Section | Path | Type | Default | Layout | Purpose |
|---|---|---|---|---|---|
| general | `enabled` | bool | true | (paired) | **Master switch.** When false, `OnApplyToGroup` short-circuits — no capture, no notification, no popup. `/wg test` and `/wg show` bypass this gate. |
| frame | `frame.autoShow` | bool | true | (paired) | Auto-open the popup on group join |
| notify | `notify.enabled` | bool | true | (paired) | Print the group-details summary to chat |
| notify | `notify.delay` | number | 1.5 | (paired) | Seconds between joining and notifying |
| general | _(Test)_ | action | — | (paired) | Action button — calls `WhatGroup:RunTest()`. No path/value. |
| general | `debug` | bool | false | (paired) | Verbose event/hook logging (sets `WhatGroup.debug` via `onChange`) |
| notify | `notify.showInstance` | bool | true | solo | Include the Instance line in chat |
| notify | `notify.showType` | bool | true | solo | Include the Type line in chat |
| notify | `notify.showLeader` | bool | true | solo | Include the Leader line in chat |
| notify | `notify.showPlaystyle` | bool | true | solo | Include the Playstyle line in chat |
| notify | `notify.showClickLink` | bool | true | solo | Include the "[Click here…]" chat link |
| notify | `notify.showTeleport` | bool | true | solo | Include a Teleport line with the dungeon's teleport spell link (skipped silently when `WhatGroup:GetTeleportSpell` returns nil) |

Rendered panel layout:

```
--- General ---
[Enable]        | [Auto Show]
[Print to Chat] | [Notification Delay]
[Test]          | [Debug]

--- Notify ---
[Show Instance]
[Show Type]
[Show Leader]
[Show Playstyle]
[Show ClickLink]
[Show Teleport]
```

## WoW Lua API Notes

- Uses `C_LFGList.GetSearchResultInfo`, `C_LFGList.GetActivityInfoTable`
- Uses `C_Spell.GetSpellTexture`, `IsSpellKnown`, `CastSpellByID`
- Frame uses `BackdropTemplate` for the dark panel background
- `UISpecialFrames` registration enables ESC-to-close
- `SetItemRef` is hooked via `AceHook:RawHook(..., true)` to handle the custom `WhatGroup:show` hyperlink — RawHook (not SecureHook) because we need to short-circuit the original on our prefix
- `C_LFGList.ApplyToGroup` is hooked via `AceHook:SecureHook` — observer only, no need to intercept
- AceEvent supplies `RegisterEvent`; handlers are methods on the addon named after the event (`WhatGroup:GROUP_ROSTER_UPDATE`, `WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, …)`)
- Settings panel uses a parent + subcategory structure: parent "Ka0s WhatGroup" via `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, subcategory "General" via `Settings.RegisterCanvasLayoutSubcategory(parent, panel, "General")`. The parent panel is intentionally minimal — in WoW 12.0 the parent's own widgets are hidden whenever it has subcategories, so widgets there would never display. `/wg config` opens the **subcategory** ID so the user lands on the populated page rather than the empty parent.
- Do NOT overwrite `category.ID` with a string — `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID.
- AceGUI body is built lazily on the first `OnShow` of the General panel, so widgets render against a non-zero panel width; `OnSizeChanged` is hooked on the AceGUI container's frame to forward width/height into AceGUI's layout (the parented-to-Blizzard container otherwise stays at 0×0)

## Slash Commands

`/wg` and `/whatgroup` are aliases registered through `AceConsole-3.0:RegisterChatCommand`, both routed to `WhatGroup:OnSlashCommand`. The dispatcher lowercases only the command name and preserves case in the rest of the input, so schema paths like `notify.showInstance` survive `/wg set ...`.

The `COMMANDS` table in `WhatGroup.lua` drives the entire slash UX. Each entry is `{name, description, fn}`. Help output is generated by iterating it, so adding a command = one row.

| Command | Behavior |
|---|---|
| `/wg` (no args) | Print help |
| `/wg help` | Print help |
| `/wg show` | Open the info dialog if `pendingInfo` is set, otherwise print a hint |
| `/wg test` | Inject synthetic `pendingInfo` and run the full notify + frame flow |
| `/wg config` | Open the Ka0s WhatGroup Settings panel |
| `/wg list` | List every schema row, grouped by section, with current values |
| `/wg get <path>` | Print one setting's current value |
| `/wg set <path> <value>` | Type-aware write to one setting; bool accepts `true/false/on/off/1/0/yes/no/toggle`, number clamps to `min/max` |
| `/wg reset` | Reset every schema row to its default |
| `/wg debug` | Toggle `db.profile.debug` (and `WhatGroup.debug`); equivalent to `/wg set debug toggle` but kept as a shortcut |

Help output convention: cyan `[WG]` prefix, yellow (`|cffFFFF00`) for slash commands, white (`|cffFFFFFF`) for explanatory text.

## Development Notes

- **Do not auto-stage, auto-commit, or auto-push.** The user chooses when to `git add` / `git stage`, `git commit`, and `git push`. Even after completing work, do not run any of those commands unless the user explicitly asks in the current turn. A prior approval does not carry forward. After making edits, leave the working tree in whatever modified-but-unstaged state your edits produced — describe what changed, do not stage it.
    - **Carve-out — `/wow-addon:commit`:** When the user invokes the `/wow-addon:commit` slash command (from their personal `wow-addon` plugin), that invocation IS the explicit per-turn instruction this rule asks for. Follow the command's flow (propose message → `y` confirmation → `git add <named files>` → `git commit`) and treat the user's `y` reply as authorization to stage and commit the proposed file set. This carve-out is narrow: it only applies when the user has explicitly invoked `/wow-addon:commit` (or equivalently typed "commit these"/"commit it" in plain language) in the current turn. It does NOT extend to other slash commands and does NOT mean a `y` to something else earlier in the session counts. Outside of an explicit commit instruction in the current turn, the no-auto-commit rule above still applies in full.
- **Do not bump the version without explicit instruction.** Never edit `## Version:` in `WhatGroup.toc`, `WhatGroup.VERSION` in `WhatGroup.lua`, the README version badge, or any other version site unless the user says so in the current turn. Refactors, feature additions, dep upgrades, and doc changes do not justify a bump — release versioning is the user's call. If a change feels release-worthy, mention it in the end-of-turn summary but leave the edit to the user.
- **SavedVariables**: `WhatGroupDB` (AceDB instance with default profile). User prefs are persisted; capture/pending state stays session-only and is cleared on group leave.
- `Settings.BuildDefaults()` walks the schema at every login to recompute defaults — a new schema row appears with its `default` value the first time the user logs in after the upgrade; existing keys are preserved untouched.
- `WhatGroup.debug` can be toggled with `/wg debug` to print verbose event/hook logs (now persisted across sessions).
- Use `/wg test` to exercise the full UI flow without actually joining a group.
- Interface version in `WhatGroup.toc` must be updated each major WoW patch.
- All chat output must be routed through `CHAT_PREFIX` (defined at the top of `WhatGroup.lua`) so every line is tagged with the cyan `[WG]` marker.
- Pattern reference: Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD`) — schema-driven slash dispatch and settings rendering. The shape here is a scaled-down version of `KickCD/core/KickCD.lua` (slash dispatch) and `KickCD/settings/Panel.lua` (helpers + builder).
