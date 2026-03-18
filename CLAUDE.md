# WhatGroup — Claude Context

## Project Overview

WhatGroup is a World of Warcraft (retail) addon. It hooks into the Premade Group Finder (LFG) flow to capture group details at apply time and display them when the player joins the group.

## File Structure

| File | Purpose |
|---|---|
| `WhatGroup.toc` | Addon manifest (interface version, load order) |
| `WhatGroup.lua` | Core logic: event handling, data capture, chat output, slash commands |
| `WhatGroup_Frame.lua` | UI: popup dialog frame, field population, teleport button |

## Key Architecture

- **`WhatGroup`** — global addon table, shared across files
- **`captureQueue`** — FIFO of captured group info waiting to be matched to an `appID`
- **`pendingApplications`** — map of `appID → capturedInfo` for accepted invites
- **`WhatGroup.pendingInfo`** — the single group info object shown in the frame; set on `inviteaccepted`

### Event/Hook Flow

1. `C_LFGList.ApplyToGroup` hook → captures group info → pushed onto `captureQueue`
2. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"applied"` → dequeues capture → stored in `pendingApplications[appID]`
3. `LFG_LIST_APPLICATION_STATUS_UPDATED` with `"inviteaccepted"` → sets `WhatGroup.pendingInfo`
4. `GROUP_ROSTER_UPDATE` (transition from not-in-group to in-group) → triggers notification + frame display

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
