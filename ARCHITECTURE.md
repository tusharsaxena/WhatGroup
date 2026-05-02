# Architecture

Reference document for WhatGroup's current shape (WoW retail, Interface 12.0/12.0.1/12.0.5). For the agent-oriented guide (development conventions, version policy, anti-patterns), see [CLAUDE.md](CLAUDE.md). For the user-facing manual, see [README.md](README.md).

WhatGroup is small enough (4 source files, ~1,400 LOC) that the entire architecture fits in one document. If it grows past ~10 files, consider splitting into a `docs/ARCHITECTURE_*` set in the style of Ka0s KickCD.

## Purpose

WhatGroup observes the Premade Group Finder (LFG) flow: it captures the group details visible on the search-result tile when the player applies, holds them across the application → invite → accept → join sequence, and resurfaces them once the player is actually in the group as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells.

The addon is observation-only. It never modifies LFG state, never auto-applies, and never blocks the join flow — every hook is either a `SecureHook` (read-only) or a `RawHook` that short-circuits only on its own custom hyperlink.

## Module map

```
WhatGroup/
├── WhatGroup.toc            Manifest: Interface, SVs, lib + code load order
├── WhatGroup.lua            AceAddon shell, capture pipeline, slash dispatch, teleport spell table
├── WhatGroup_Settings.lua   Schema, Helpers, canvas-layout panel renderer
├── WhatGroup_Frame.lua      420×260 popup dialog, field population, teleport button
├── libs/                    Embedded Ace3 (LibStub, CallbackHandler, AceAddon, AceEvent,
│                            AceConsole, AceDB, AceHook, AceGUI). Copied from Ka0s KickCD.
└── media/                   Logo / screenshot assets referenced by README.md
```

External runtime dependencies: WoW retail's `C_LFGList`, `C_Spell`, `C_Timer` namespaces; the Settings API (`Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.OpenToCategory`); `IsInGroup`, `IsSpellKnown`, `CastSpellByID`, `SetItemRef`. Frame chrome uses `BackdropTemplate` and `UISpecialFrames`.

## Boot sequence

TOC file-load order (top of `WhatGroup.toc`):

1. **libs/** — `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceDB-3.0` → `AceHook-3.0` → `AceGUI-3.0` (last; loaded via its `.xml` because that pulls in `widgets/`).
2. **WhatGroup.lua** — calls `AceAddon:NewAddon(existing, "WhatGroup", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")`, assigns `_G.WhatGroup`, defines methods. Module-locals `captureQueue`, `pendingApplications`, `wasInGroup` initialise to empty / `false`.
3. **WhatGroup_Settings.lua** — picks up the addon via `LibStub("AceAddon-3.0"):GetAddon("WhatGroup")`, stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, BuildDefaults, Register }`. Schema rows are appended via `add{}` calls in source order.
4. **WhatGroup_Frame.lua** — creates the global `WhatGroupFrame`, attaches `WhatGroup:ShowFrame()` / `WhatGroup:HideFrame()` methods. Registered with `UISpecialFrames` for ESC-to-close.

Lifecycle:

- **`OnInitialize`** (`ADDON_LOADED` for "WhatGroup"): builds `defaults` from `Settings.BuildDefaults()`, opens AceDB as `WhatGroup.db = AceDB:New("WhatGroupDB", defaults, true)` (third arg `true` → shared `Default` profile across every character on the account), seeds the runtime `WhatGroup.debug` flag from `db.profile.debug`, registers `/wg` and `/whatgroup` chat commands.
- **`OnEnable`**: registers `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED` events, installs the `SecureHook` on `C_LFGList.ApplyToGroup` and the `RawHook` on `SetItemRef`, snapshots `wasInGroup = IsInGroup()`, and calls `Settings.Register()`.

`Settings.Register()` is idempotent (`WhatGroup._settingsRegistered` guard). It registers a parent canvas category "Ka0s WhatGroup" that's intentionally a thin landing page (12.0 hides a parent's own widgets when it has subcategories) and a "General" subcategory whose body is built lazily on the first `OnShow` so AceGUI widgets render against a non-zero panel width. The subcategory handle is stashed at `WhatGroup._settingsCategory` so `/wg config` opens directly to the populated page.

## Capture pipeline

The pipeline associates a captured group-info table with the player's eventual group join, surviving the multi-step LFG state machine. State is held in three module-locals in `WhatGroup.lua`:

| Local | Shape | Lifetime |
|---|---|---|
| `captureQueue` | FIFO array of capture tables | session; wiped on group-leave |
| `pendingApplications` | `{ [appID] = capture }` | session; wiped on group-leave |
| `wasInGroup` | bool | session; tracks `IsInGroup()` state |
| `WhatGroup.pendingInfo` | single capture table (the active one) | session; cleared on group-leave |

Flow:

```
Player clicks Apply
        │
        ▼
SecureHook on C_LFGList.ApplyToGroup ───► OnApplyToGroup(searchResultID)
                                          ├─ db.profile.enabled gate (early-return if false)
                                          ├─ CaptureGroupInfo(searchResultID)
                                          │    ├─ C_LFGList.GetSearchResultInfo
                                          │    └─ C_LFGList.GetActivityInfoTable
                                          └─ table.insert(captureQueue, captured)
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED status="applied"   appID assigned
        ├─ table.remove(captureQueue, 1)  (FIFO dequeue)
        └─ pendingApplications[appID] = capture
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED status="invited"   no-op (waits for accept)
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED status="inviteaccepted"
        ├─ WhatGroup.pendingInfo = pendingApplications[appID]
        └─ wipe(captureQueue) + wipe(pendingApplications)
        │
        ▼
GROUP_ROSTER_UPDATE  inGroup ∧ ¬wasInGroup ∧ pendingInfo
        ├─ C_Timer.After(notify.delay)
        │     ├─ ShowNotification()                always (gated internally on notify.enabled)
        │     └─ ShowFrame()                       only if frame.autoShow
        └─ wasInGroup = inGroup
        │
        ▼
GROUP_ROSTER_UPDATE  ¬inGroup
        └─ pendingInfo = nil + wipe both queues
```

Why a queue instead of a single slot: a player can have multiple applications in flight before any of them resolve. The `applied` event is the first place the LFG API tells us which `appID` belongs to a given submission, so captures wait FIFO until they're paired up.

The `RawHook` on `SetItemRef` short-circuits the custom `WhatGroup:show` hyperlink (emitted by `ShowNotification` as the green `[Click here to view details]` chat link) and routes it to `ShowFrame()`. RawHook (not SecureHook) is required so we can return early without invoking the original handler on our prefix.

## Captured info

`CaptureGroupInfo(searchResultID)` returns a table with:

`title`, `leaderName`, `numMembers`, `voiceChat`, `playstyle`, `age`, `activityIDs`, `activityID`, `fullName`, `activityName`, `shortName`, `maxNumPlayers`, `isMythicPlus`, `isCurrentRaid`, `isHeroicRaid`, `categoryID`, `mapID`.

Defaults are filled in for every field so downstream consumers (`ShowNotification`, `ShowFrame`) can read without nil checks. The activity-derived fields (`fullName`, `activityName`, `shortName`, `maxNumPlayers`, `isMythicPlus`, `isCurrentRaid`, `isHeroicRaid`, `categoryID`) are only populated when `C_LFGList.GetActivityInfoTable` returns a non-nil table for the first activity in `activityIDs`.

## Settings system

A single flat array `WhatGroup.Settings.Schema` declares every option. One row drives six surfaces simultaneously:

| Surface | Mechanism |
|---|---|
| Settings panel widget | `renderSchema()` → `makeField()` → `makeCheckbox` / `makeSlider` / `makeActionButton`; value widgets register a refresher closure in `Settings._refreshers` |
| `/wg list` | groups schema by `section`, prints `path = formattedValue` per row |
| `/wg get <path>` | `Helpers.FindSchema(path)` + format |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set` → `onChange` → `Helpers.RefreshAll` |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each row's `default` into the right slot under `profile.*` |
| `/wg reset` | `Helpers.RestoreDefaults()` resets every row to its `default`, runs `onChange`, refreshes panel |

Row schema:

```lua
{
    section,          -- groups in /wg list output (general, frame, notify, …)
    group,            -- heading shown in the Settings panel ("General", "Notify", …)
    path,             -- dotted path into db.profile (e.g. "notify.delay"). Omit for type="action".
    type,             -- "bool" | "number" | "action"
    label, tooltip,
    default,                -- omit for type="action"
    min, max, step, fmt,    -- numbers only
    onChange,               -- optional fn(value) called by both panel widget and /wg set
    onClick,                -- type="action" only: fn() called when the panel button is clicked
    solo,                   -- if true, render alone in the left half of its own row
    spacerBefore,           -- if true, insert a blank row before this widget
    panelHidden,            -- if true, skip the row in the panel renderer (still in /wg list/get/set)
}
```

**Panel layout.** The "General" subcategory renders the schema as a two-column AceGUI Flow layout (50%/50% per row). Widgets pair into rows by default; `solo = true` flushes the in-progress row and forces the widget to its own line; `spacerBefore = true` flushes and adds a blank row before the widget. `group` transitions emit a Heading widget. The renderer is a scaled-down port of KickCD's `Helpers.RenderSchema` (no `valueGate`, no `afterGroup`, no `panelKey`).

**Action rows.** `type = "action"` renders as an AceGUI Button that participates in the two-column pairing. Action rows have no `path` and no value, so they're skipped by `BuildDefaults` / `RestoreDefaults` / `/wg list` / `/wg get` / `/wg set`. The current Test row is the only action; its `onClick` calls `WhatGroup:RunTest()` — the same code path as `/wg test`, so the panel button and the slash command stay in lockstep.

**Helpers.** All schema reads and writes go through `Helpers.Resolve(path)` which walks dotted paths into `db.profile`. `Helpers.Get` / `Helpers.Set` use it; `Helpers.FindSchema(path)` linear-scans the Schema array. `Helpers.RefreshAll` re-syncs every panel widget against the current `db.profile` value via the refresher closures registered at widget-creation time.

**Adding an option** = one schema row. UI, CLI, defaults, and reset all follow automatically.

### Current rows

Order matches panel render order:

| Section | Path | Type | Default | Layout | Purpose |
|---|---|---|---|---|---|
| general | `enabled` | bool | true | (paired) | Master switch. Gates `OnApplyToGroup` only — `/wg test` and `/wg show` bypass it. |
| frame | `frame.autoShow` | bool | true | (paired) | Auto-open the popup on group join. |
| notify | `notify.enabled` | bool | true | (paired) | Print the chat summary on group join. |
| notify | `notify.delay` | number | 1.5 | (paired) | Seconds (0–10, step 0.5) between joining and notifying. |
| general | _(Test)_ | action | — | (paired) | Action button — calls `WhatGroup:RunTest()`. |
| general | `debug` | bool | false | (paired) | Verbose event/hook logging (mirrors to `WhatGroup.debug` via `onChange`). |
| notify | `notify.showInstance` | bool | true | solo | Include the Instance line in chat. |
| notify | `notify.showType` | bool | true | solo | Include the Type line in chat. |
| notify | `notify.showLeader` | bool | true | solo | Include the Leader line in chat. |
| notify | `notify.showPlaystyle` | bool | true | solo | Include the Playstyle line in chat. |
| notify | `notify.showClickLink` | bool | true | solo | Include the green "[Click here to view details]" chat link. |
| notify | `notify.showTeleport` | bool | true | solo | Include a Teleport line; skipped silently when `WhatGroup:GetTeleportSpell` returns nil. |

The popup dialog always renders every field; the `notify.show*` rows gate **chat output only**.

## Frame layout

`WhatGroup_Frame.lua` builds a single global `WhatGroupFrame`:

- 420 × 260 dialog, `DIALOG` strata, `BackdropTemplate` chrome, dark background (0.08/0.95) with a 1px grey border.
- Drag handle is the title bar; `SetClampedToScreen(true)` keeps it on-screen.
- Six rows: Group, Instance, Type, Leader, Playstyle, Teleport. Labels are left-justified in a 72px column; values flow right.
- The Teleport row is a 24×24 button textured with `C_Spell.GetSpellTexture(spellID)`, desaturated and `EnableMouse(false)` when `IsSpellKnown(spellID)` is false. `OnClick` calls `CastSpellByID(spellID)`; tooltip via `GameTooltip:SetSpellByID`.
- `VALUE_COLORS` is a per-field hex-resolver table — every field is uncoloured today, but the hook is in place for future per-field colour rules without touching the populator.
- Registered with `UISpecialFrames` for ESC-to-close; closes via the bottom Close button or `WhatGroup:HideFrame()`.

`GetGroupTypeLabel` and the `PLAYSTYLE_LABELS` map are duplicated between `WhatGroup.lua` (chat notification) and `WhatGroup_Frame.lua` (popup). The duplication is intentional for now — keeping the two files independent of each other lets the popup file load without touching the addon's slash/dispatch code paths during boot.

## Slash dispatch

`/wg` and `/whatgroup` are registered through `AceConsole-3.0:RegisterChatCommand`, both routing to `WhatGroup:OnSlashCommand`. The dispatcher lowercases only the command name (`raw:match("^(%S+)%s*(.*)$")`) and preserves case in the rest of the input, so schema paths like `notify.showInstance` survive `/wg set …`.

The `COMMANDS` table is the single source of truth; help output iterates it, so adding a command = one row. Each entry is `{name, description, fn(self, rest)}`. Forward declarations at the top of the dispatch section let the table reference handlers defined further down.

| Command | Behavior |
|---|---|
| `/wg` (no args) | Print help |
| `/wg help` | Print help |
| `/wg show` | Open the popup if `pendingInfo` is set, otherwise hint to use `/wg test` |
| `/wg test` | Inject synthetic `pendingInfo` (Mythic+ Stonevault) and run the full notify + popup flow. Mirrors the panel's Test button via `WhatGroup:RunTest()`. |
| `/wg config` | `Settings.OpenToCategory(self._settingsCategory:GetID())` — opens the General subcategory directly. |
| `/wg list` | Group schema by `section`, print `path = formattedValue` for every row with a `path` (skips action rows). |
| `/wg get <path>` | `Helpers.FindSchema` + format. |
| `/wg set <path> <value>` | bool accepts `true/false/on/off/1/0/yes/no/toggle`; number clamps to `min/max`. Calls `onChange`, then `Helpers.RefreshAll`. |
| `/wg reset` | `Helpers.RestoreDefaults()` — every row to its `default`, runs `onChange`, refreshes panel widgets. |
| `/wg debug` | Toggles `db.profile.debug` and `WhatGroup.debug` together. Equivalent to `/wg set debug toggle`, kept as a convenience shortcut. |

## Saved variables

Single SV: `WhatGroupDB` (declared in `WhatGroup.toc`). Holds an AceDB instance with the shared `Default` profile (third arg `true` to `AceDB:New`). Schema-defined defaults are recomputed at every login by `Settings.BuildDefaults()`, so a new schema row appears with its `default` value the first time the user logs in after the upgrade; existing keys are preserved untouched.

`db.profile` shape (current):

```
profile = {
  enabled = true,
  debug   = false,
  frame   = { autoShow = true },
  notify  = {
    enabled       = true,
    delay         = 1.5,
    showInstance  = true,
    showType      = true,
    showLeader    = true,
    showPlaystyle = true,
    showClickLink = true,
    showTeleport  = true,
  },
}
```

Capture/pending state (`captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`) stays session-only and never touches SVs.

## Conventions

- **Chat prefix.** Every line the addon prints is routed through the module-local `CHAT_PREFIX = "|cff00FFFF[WG]|r"` so users can identify WhatGroup output at a glance. Debug lines additionally tag `[DBG]` in orange.
- **Hook discipline.** `SecureHook` for read-only observation (`C_LFGList.ApplyToGroup`); `RawHook` only when we genuinely need to short-circuit the original on a prefix we own (`SetItemRef`'s `WhatGroup:` hyperlinks). Never `SecureHook` something whose original we want to suppress; never `RawHook` something we're only observing.
- **Settings API.** Always pass `category:GetID()` (not the category object, not a string) to `Settings.OpenToCategory`. The integer ID is auto-assigned by the API; overwriting `category.ID` with a string breaks the lookup.
- **Lazy panel build.** AceGUI widgets must render against a non-zero panel width. The General subcategory's body is built on the first `OnShow` (one-shot via a `built` flag), and the AceGUI container's frame hooks `OnSizeChanged` to forward width/height into AceGUI's layout — without this, parented-to-Blizzard containers stay at 0×0.
- **Schema-first changes.** Adding a setting = adding one row to the Schema array. Don't reach into `db.profile` directly from new code; go through `Helpers.Get` / `Helpers.Set` so the panel refreshers and `/wg list/get/set` stay in sync.
- **Pattern reference.** Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD`) is the source pattern for both the slash dispatch (`KickCD/core/KickCD.lua`) and the schema-driven settings rendering (`KickCD/settings/Panel.lua`). When in doubt about how to extend a system here, check how the equivalent system is shaped over there.
