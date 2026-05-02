# Capture pipeline

The path from "player clicks Apply" to "popup shows after the join". Every step lives in `WhatGroup.lua`.

## What the pipeline solves

The Premade Group Finder is a multi-step state machine spanning at least four LFG events between an apply and a join:

```
ApplyToGroup → "applied" → "invited" → "inviteaccepted" → GROUP_ROSTER_UPDATE
```

WhatGroup needs to associate the group-info table read at apply time with the player's eventual group join. The complications:

- The `searchResultID` is known at apply time but the `appID` (which the LFG events use) isn't assigned until `applied` fires.
- A player can have multiple applications in flight at once. Captures need to queue FIFO and pair up by appID.
- The user might not actually accept the invite (decline / time out). Captures should be discarded if the invite is never accepted.
- The user might leave a group and then join another. State must be cleared on group-leave so the next join's notification reflects the right capture.

## State

Three module-locals in `WhatGroup.lua` plus one field on the addon table:

| State | Shape | Lifetime |
|---|---|---|
| `captureQueue` | FIFO array of capture tables | session; wiped on group-leave |
| `pendingApplications` | `{ [appID] = capture }` | session; wiped on group-leave or after `inviteaccepted` |
| `wasInGroup` | bool | session; tracks `IsInGroup()`, seeded in `OnEnable` |
| `WhatGroup.pendingInfo` | single capture table (the active one) | session; cleared on group-leave |

None of these are persisted — capture state is recomputed from live LFG events every session.

## Flow

```
Player clicks Apply
        │
        ▼
SecureHook on C_LFGList.ApplyToGroup ───► OnApplyToGroup(searchResultID)
                                          ├─ db.profile.enabled gate (early-return if false)
                                          ├─ CaptureGroupInfo(searchResultID)
                                          │    ├─ C_LFGList.GetSearchResultInfo
                                          │    └─ C_LFGList.GetActivityInfoTable (first activityID)
                                          └─ table.insert(captureQueue, captured)
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED  status = "applied"   appID assigned
        ├─ table.remove(captureQueue, 1)        FIFO dequeue
        └─ pendingApplications[appID] = capture
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED  status = "invited"   no-op (waits for accept)
        │
        ▼
LFG_LIST_APPLICATION_STATUS_UPDATED  status = "inviteaccepted"
        ├─ fresh = CaptureGroupInfo(appID)        re-fetch fresh from LFG API
        ├─ WhatGroup.pendingInfo = fresh ?? pendingApplications[appID]
        └─ wipe(captureQueue) + wipe(pendingApplications)
        │
        ▼
GROUP_ROSTER_UPDATE  inGroup ∧ ¬wasInGroup ∧ pendingInfo
        ├─ C_Timer.After(notify.delay, function()
        │     ├─ ShowNotification()                 always (gated internally on notify.enabled)
        │     └─ if frame.autoShow then ShowFrame() end
        │  end)
        └─ wasInGroup = inGroup
        │
        ▼
GROUP_ROSTER_UPDATE  ¬inGroup
        ├─ pendingInfo = nil
        └─ wipe(captureQueue) + wipe(pendingApplications)
```

## Why a queue, not a single slot

A player can have multiple applications in flight before any of them resolve. The `searchResultID` we capture at apply time isn't useful for matching against later events — only the LFG-assigned `appID` is, and that's not known until `applied` fires.

The queue is FIFO because the LFG API fires `applied` in apply-order. Each `applied` event dequeues one capture and pairs it with the freshly-assigned `appID`. The pairing means captures that *don't* receive an `applied` event (e.g. apply-rejected before it ever became an application) get pushed off the front of the queue by subsequent applies and eventually wiped on group-leave.

## Why we re-capture at `inviteaccepted`

`CaptureGroupInfo` is called once at apply time, but `C_LFGList.GetActivityInfoTable` can return nil or partial data at that point — keystone groups in particular sometimes don't have their activity-info table fully populated until the invite is on the way. That makes `mapID`, `fullName`, `shortName`, and the `isMythicPlus` / `isCurrentRaid` flags silently default to nil/empty, which surfaces as "popup shows the group title and leader but the teleport icon is missing."

To make the activity-derived fields reliable, the `inviteaccepted` branch re-runs `CaptureGroupInfo` against the same id (the event's first arg, which for the player's own application is the same value as the searchResultID — feeding it back into `GetSearchResultInfo` works). By that point the activity table is reliably populated. The queued capture from `pendingApplications` becomes the safety-net fallback only used if the fresh re-capture itself returns nil.

The merge isn't a flat "fresh wins" — it picks the more-complete capture:

```lua
local queued = pendingApplications[appID]
local fresh  = self:CaptureGroupInfo(appID)
local final
if     fresh  and fresh.mapID  then final = fresh        -- fresh is most current AND has the field that drives the teleport icon
elseif queued and queued.mapID then final = queued       -- fresh re-capture missed mapID; queued had it
elseif fresh                   then final = fresh        -- neither has mapID — take whichever exists
elseif queued                  then final = queued
end
self.pendingInfo = final
```

`mapID` is the discriminator because (a) it drives the teleport icon, the most visible failure mode, and (b) it's the field most prone to upstream flakiness — the rest of the activity-info table tends to be present when `mapID` is, so picking on `mapID` correlates well with "this capture is healthy."

## Why `wasInGroup` is the join trigger

`GROUP_ROSTER_UPDATE` fires for every roster change once you're in a group — members joining, leaving, going offline. We only want to fire the notification on the not-in-group → in-group transition.

`wasInGroup` is seeded in `OnEnable` from `IsInGroup()` (so reloading mid-group doesn't re-trigger) and updated on every `GROUP_ROSTER_UPDATE`. The notify branch fires only when `inGroup ∧ ¬wasInGroup ∧ pendingInfo`.

## Why `RawHook` on `SetItemRef`

The notification's last line is a clickable green hyperlink:

```
|cff00FF7F|HWhatGroup:show|h[Click here to view details]|h|r
```

`SetItemRef` is the global handler for chat link clicks. We need to:

1. Detect clicks on links whose `linkData` starts with `WhatGroup:`.
2. Open the popup (`WhatGroup:ShowFrame()`).
3. **Short-circuit the original** so WoW doesn't try to interpret the link as an item / spell / etc. (it would error or open an unrelated tooltip).

`SecureHook` runs after the original and can't suppress it. `RawHook` replaces the original (with `self.hooks.SetItemRef(...)` reaching the real one) and lets us return early on our prefix:

```lua
function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    if linkArg and linkArg:match("^WhatGroup:") then
        if not self.pendingInfo then
            -- Stale link from a previous session — the chat scrollback
            -- survives /reload but pendingInfo doesn't. Print a hint
            -- instead of opening a "No data" popup.
            p("Group info no longer available — captures clear on group-leave or /reload. Use /wg test to preview.")
            return
        end
        self:ShowFrame()
        return
    end
    return self.hooks.SetItemRef(linkArg, text, button, ...)
end
```

The `pendingInfo == nil` guard sits ahead of `ShowFrame` because `pendingInfo` is session-only — it's wiped on group-leave (in `GROUP_ROSTER_UPDATE`) and absent after a `/reload`, but the chat link itself persists in scrollback. Without the guard, clicking a link from a previous session opens an empty popup with `No data` in every value field, which reads as broken rather than "your previous capture has expired."

The third arg `true` to `RawHook("SetItemRef", "OnSetItemRef", true)` enables secure post-hooking semantics for the case where Blizzard re-tags `SetItemRef` as protected in a future patch.

See [wow-quirks.md](./wow-quirks.md#hook-discipline) for the rules on when to use `SecureHook` vs `RawHook` more generally.

## Captured info

`CaptureGroupInfo(searchResultID)` returns a table with the following fields. Defaults are filled in for every field so downstream consumers (`ShowNotification`, the popup `PopulateFields`) can read without nil checks.

| Field | Source | Default |
|---|---|---|
| `title` | `info.name or info.title` | `"Unknown"` |
| `leaderName` | `info.leaderName` | `"Unknown"` |
| `numMembers` | `info.numMembers` | `0` |
| `voiceChat` | `info.voiceChat` | `""` |
| `generalPlaystyle` | `info.generalPlaystyle` (current API) → `info.playstyle` (legacy fallback) | `0` (= `Enum.LFGEntryGeneralPlaystyle.None` → `""` via `PLAYSTYLE_LABELS`) |
| `playstyleString` | `info.playstyleString` (server-rendered, localized) | `""` (consumers fall back to `PLAYSTYLE_LABELS[generalPlaystyle]`) |
| `playstyle` | alias for `generalPlaystyle` | mirrors `generalPlaystyle` |
| `age` | `info.age` | `0` |
| `activityIDs` | `info.activityIDs` (or `{info.activityID}` fallback) | `{}` |
| `activityID` | `activityIDs[1]` | `nil` |
| `fullName` | `actInfo.fullName or actInfo.activityName` | `""` |
| `activityName` | `actInfo.activityName` | `""` |
| `shortName` | `actInfo.shortName` | (only set when `actInfo` is non-nil; absent otherwise) |
| `maxNumPlayers` | `actInfo.maxNumPlayers` | `0` |
| `isMythicPlus` | `actInfo.isMythicPlusActivity` | `false` |
| `isCurrentRaid` | `actInfo.isCurrentRaidActivity` | `false` |
| `isHeroicRaid` | `actInfo.isHeroicRaidActivity` | `false` |
| `categoryID` | `actInfo.categoryID` | `0` |
| `mapID` | `actInfo.mapID` (the dungeon's instance map ID — stable across seasons; the key used by `WhatGroup.TeleportSpells`) | `nil` |

The activity-derived fields are only populated when `C_LFGList.GetActivityInfoTable(firstActivityID)` returns a non-nil table. If the activity table is missing the fields stay at their defaults — the popup and notification still render, just with placeholder values.

`GetGroupTypeLabel(info)` (in `WhatGroup.lua`) and a duplicate in `WhatGroup_Frame.lua` derive a human-readable type from these fields: Mythic+ wins, then Raid (Current), Heroic Raid, PvP (`categoryID == 2`), Dungeon (`categoryID == 1`), Raid (`maxNumPlayers >= 10`), Dungeon (`maxNumPlayers > 0`), or "Group" as the final fallback. See [frame.md](./frame.md#why-getgrouptypelabel-and-playstyle_labels-are-duplicated) for why the helper is duplicated.

## Teleport spell lookup

`WhatGroup.TeleportSpells` is a flat table keyed by `mapID` (the dungeon's instance map ID — stable across seasons) mapping to the dungeon's teleport `spellID`. `WhatGroup:GetTeleportSpell(activityID, mapID)` checks `mapID` first, then falls back to `activityID` for backwards compatibility — but the table no longer carries activityID-keyed rows, so the fallback is effectively a nop. activityID was abandoned as a key because Blizzard rotates activity IDs every season.

The lookup is consumed by:

- `ShowNotification` — only emits the Teleport line if `spellID` is non-nil and `notify.showTeleport` is on; the line includes `IsSpellKnown(spellID)` as a `(not learned)` tag when false.
- `ConfigureTeleportButton` (popup) — desaturates the icon and sets `EnableMouse(false)` when `IsSpellKnown` is false; the button is hidden entirely when `spellID` is nil. The button is a `SecureActionButtonTemplate` parented to UIParent with `type="macro"` + `macrotext="/cast <SpellName>"` — `CastSpellByID` from a non-secure click hits `ADDON_ACTION_FORBIDDEN` in retail. See [frame.md → Teleport button](./frame.md#teleport-button).

Adding a teleport mapping is one row in the table — see [common-tasks.md](./common-tasks.md#add-a-dungeon-teleport-spell-mapping).

## Test path

`WhatGroup:RunTest()` injects synthetic `pendingInfo` (a Mythic+ Stonevault group) and runs `ShowNotification()` + `ShowFrame()` directly — bypassing `OnApplyToGroup`, the queue, the LFG event sequence, and the `wasInGroup` join gate. Both `/wg test` and the panel's Test button route through this method, so the two affordances stay in lockstep.

`/wg show` is the read-only equivalent: it opens the popup with whatever `pendingInfo` happens to be set (the most recent real capture), or prints a hint if `pendingInfo` is nil.
