# WhatGroup — Claude Context

## Project Overview

WhatGroup is a World of Warcraft (retail) addon. It hooks into the Premade Group Finder (LFG) flow to capture group details at apply time and display them when the player joins the group.

## File Structure

| File | Purpose |
|---|---|
| `WhatGroup.toc` | Addon manifest (interface version, load order) |
| `WhatGroup.lua` | Core logic: event handling, data capture, chat output, slash commands, teleport spell table |
| `WhatGroup_Frame.lua` | UI: popup dialog frame, field population, teleport button, value color resolvers |

## Key Architecture

- **`WhatGroup`** — global addon table, shared across files
- **`captureQueue`** — FIFO of captured group info waiting to be matched to an `appID`
- **`pendingApplications`** — map of `appID → capturedInfo` for accepted invites
- **`WhatGroup.pendingInfo`** — the single group info object shown in the frame; set on `inviteaccepted`
- **`WhatGroup.TeleportSpells`** — table mapping `activityID`/`instanceID` → `spellID` for dungeon teleports

### Event/Hook Flow

1. `C_LFGList.ApplyToGroup` hook → captures group info → pushed onto `captureQueue`
2. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"applied"` → dequeues capture → stored in `pendingApplications[appID]`
3. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"invited"` → no-op (waits for user to accept)
4. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"inviteaccepted"` → sets `WhatGroup.pendingInfo`, wipes queues
5. `GROUP_ROSTER_UPDATE` (transition from not-in-group to in-group) → triggers notification + frame display after 1.5s delay

### Captured Info Fields

`title`, `leaderName`, `numMembers`, `voiceChat`, `playstyle`, `age`, `activityIDs`, `activityID`, `fullName`, `activityName`, `shortName`, `maxNumPlayers`, `isMythicPlus`, `isCurrentRaid`, `isHeroicRaid`, `categoryID`, `mapID`

### Frame Layout

- **Displayed rows:** Group, Instance, Type, Leader, Playstyle, Teleport
- **`VALUE_COLORS`** — per-field color resolver table; each field can define a `function(info) → hex` to colorize its value
- **`GetGroupTypeLabel`** is duplicated in both `WhatGroup.lua` and `WhatGroup_Frame.lua`
- **Playstyle labels** (`PLAYSTYLE_LABELS`) are also duplicated in both files

## WoW Lua API Notes

- Uses `C_LFGList.GetSearchResultInfo`, `C_LFGList.GetActivityInfoTable`
- Uses `C_Spell.GetSpellTexture`, `IsSpellKnown`, `CastSpellByID`
- Frame uses `BackdropTemplate` for the dark panel background
- `UISpecialFrames` registration enables ESC-to-close
- `SetItemRef` is hooked to handle the custom `WhatGroup:show` hyperlink

## Development Notes

- No SavedVariables — all state is session-only and cleared on group leave
- `WhatGroup.debug` can be toggled with `/wg debug` to print verbose event/hook logs
- Use `/wg test` to exercise the full UI flow without actually joining a group
- Interface version in `WhatGroup.toc` must be updated each major WoW patch
- `/wg` and `/whatgroup` are registered as slash command aliases
