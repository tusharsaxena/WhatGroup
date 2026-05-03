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

Four module-locals in `WhatGroup.lua` plus one field on the addon table:

| State | Shape | Lifetime |
|---|---|---|
| `captureQueue` | FIFO array of capture tables | session; wiped on group-leave or after `inviteaccepted` |
| `pendingApplications` | `{ [appID] = capture }` | session; wiped on group-leave or after `inviteaccepted` |
| `wasInGroup` | bool | session; tracks `IsInGroup()`, seeded in `OnEnable` |
| `notifiedFor` | the `pendingInfo` table reference that already triggered notify+popup | session; cleared on `inviteaccepted` (new pendingInfo) and on group-leave |
| `WhatGroup.pendingInfo` | single capture table (the active one) | session; cleared on group-leave |

None of these are persisted — capture state is recomputed from live LFG events every session.

## Flow

```
Player clicks Apply
        │
        ▼
hooksecurefunc on C_LFGList.ApplyToGroup ─► OnApplyToGroup(searchResultID)
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
        ├─ notifiedFor = nil                       new pendingInfo → eligible to fire
        ├─ wipe(captureQueue) + wipe(pendingApplications)
        └─ _TryFireJoinNotify("inviteaccepted")
        │
        ▼
GROUP_ROSTER_UPDATE  (transition: inGroup ∧ ¬wasInGroup)
        ├─ _TryFireJoinNotify("ROSTER transition")
        └─ wasInGroup = inGroup

  _TryFireJoinNotify(reason):
        ├─ skip if pendingInfo is nil
        ├─ skip if notifiedFor == pendingInfo (already fired for this join)
        ├─ skip if not IsInGroup()
        ├─ notifiedFor = pendingInfo
        └─ C_Timer.After(notify.delay, function()
              ├─ ShowNotification()                always (gated internally on notify.enabled)
              └─ if frame.autoShow then ShowFrame() end
           end)
        │
        ▼
GROUP_ROSTER_UPDATE  ¬inGroup
        ├─ pendingInfo = nil
        ├─ notifiedFor = nil
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

## Why the dual-path trigger via `_TryFireJoinNotify`

`GROUP_ROSTER_UPDATE` fires for every roster change once you're in a group — members joining, leaving, going offline. We only want to fire the notification on the not-in-group → in-group transition. `wasInGroup` is seeded in `OnEnable` from `IsInGroup()` (so reloading mid-group doesn't re-trigger) and updated on every `GROUP_ROSTER_UPDATE`. The transition that interests us is `inGroup ∧ ¬wasInGroup`.

But the transition alone isn't enough as the trigger gate. In retail, the order of `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED` (`inviteaccepted`) at join time isn't deterministic — `GROUP_ROSTER_UPDATE` often arrives before `inviteaccepted` lands and sets `pendingInfo`. The old "fire on roster transition only when `pendingInfo` is non-nil" gate would silently miss in that order: by the time `pendingInfo` got set, the transition had already passed.

`WhatGroup:_TryFireJoinNotify(reason)` is the single entry point that schedules `ShowNotification` + `ShowFrame`. It's called from BOTH event paths:

- The `GROUP_ROSTER_UPDATE` not-in → in transition (covers the case where `pendingInfo` was already set when the transition arrived).
- The `LFG_LIST_APPLICATION_STATUS_UPDATED` `inviteaccepted` handler, after `pendingInfo` is assigned (covers the reverse ordering).

The function gates on three conditions: `pendingInfo` set, `IsInGroup()` true, and `notifiedFor ~= pendingInfo`. The `notifiedFor` flag — assigned to the current `pendingInfo` reference once we schedule notify — prevents double-firing when both paths catch the same join. It's cleared in two places: when `inviteaccepted` assigns a new `pendingInfo` (so the next join can fire), and on group-leave when state is wiped.

## Why `hooksecurefunc` on `SetItemRef`

The notification's last line is a clickable green hyperlink:

```
|cff00FF7F|HWhatGroup:show|h[Click here to view details]|h|r
```

`SetItemRef` is the global handler for chat link clicks. We need to:

1. Detect clicks on links whose `linkData` starts with `WhatGroup:`.
2. Open the popup (`WhatGroup:ShowFrame()`).

We *don't* need to suppress the original — Blizzard's `SetItemRef` walks an `if/elseif` chain on `linkType` and silently returns for unknown prefixes, so when our `WhatGroup:show` link is clicked the default already does nothing useful. A secure post-hook is enough:

```lua
hooksecurefunc("SetItemRef", function(linkArg, text, button, ...)
    if not (linkArg and linkArg:match("^WhatGroup:")) then return end
    WhatGroup:OnSetItemRef(linkArg, text, button, ...)
end)
```

```lua
function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    if not self.pendingInfo then
        -- Stale link from a previous session — the chat scrollback
        -- survives /reload but pendingInfo doesn't. Print a hint
        -- instead of opening a "No data" popup.
        p("Group info no longer available — captures clear on group-leave or /reload. Use /wg test to preview.")
        return
    end
    self:ShowFrame()
end
```

The `pendingInfo == nil` guard sits ahead of `ShowFrame` because `pendingInfo` is session-only — it's wiped on group-leave (in `GROUP_ROSTER_UPDATE`) and absent after a `/reload`, but the chat link itself persists in scrollback. Without the guard, clicking a link from a previous session opens an empty popup with `No data` in every value field, which reads as broken rather than "your previous capture has expired."

### Why not `RawHook`

An earlier version used `AceHook:RawHook("SetItemRef", "OnSetItemRef", true)` to short-circuit on our prefix. That works visually but replaces the global `SetItemRef` with a non-secure wrapper. The replacement leaves a taint trace that surfaces much later — when the player presses the GameMenu's **Logout** button, Blizzard's secure-execute chain (which calls `Logout()` from `Blizzard_GameMenu/Shared/GameMenuFrame.lua:69` inside a wrapper named `callback()`) detects the taint and fires `ADDON_ACTION_FORBIDDEN ... 'callback()'` attributed to WhatGroup. Switching to `hooksecurefunc` (which leaves the global function in place and just chains a callback after) eliminates the taint with no visible behavioural change.

See [wow-quirks.md](./wow-quirks.md#hook-discipline) for the rules on when each hook type is appropriate.

## Captured info

`CaptureGroupInfo(searchResultID)` returns a table with the following fields. Defaults are filled in for every field so downstream consumers (`ShowNotification`, the popup `PopulateFields`) can read without nil checks.

| Field | Source | Default |
|---|---|---|
| `title` | `info.name or info.title` | `"Unknown"` |
| `leaderName` | `info.leaderName` | `"Unknown"` |
| `numMembers` | `info.numMembers` | `0` |
| `voiceChat` | `info.voiceChat` | `""` |
| `generalPlaystyle` | `info.generalPlaystyle` (current API) → `info.playstyle` (legacy fallback) | `0` (= `Enum.LFGEntryGeneralPlaystyle.None` → `""` via `WhatGroup.Labels.PLAYSTYLE`) |
| `playstyleString` | `info.playstyleString` (server-rendered, localized) | `""` (consumers fall back to `WhatGroup.Labels.PLAYSTYLE[generalPlaystyle]`) |
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

`WhatGroup.TeleportSpells` is a flat table keyed by `mapID` (the dungeon's instance map ID — stable across seasons), organized into per-expansion sections. Values are either a single `spellID` (number) or a list `{spellID1, spellID2}` for dungeons whose teleport has been re-issued under a new spell ID over time. `WhatGroup:GetTeleportSpell(activityID, mapID)` checks `mapID` first, then falls back to `activityID` for backwards compatibility — but the table no longer carries activityID-keyed rows, so the fallback is effectively a nop. activityID was abandoned as a key because Blizzard rotates activity IDs every season.

**Primary source for spell IDs and names** is the Warcraft Wiki's [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities). Every "Path of …" spell page lists the canonical spell ID and destination in its infobox; the table's trailing comments cite the wiki spell name so any future audit can re-validate by browsing the category.

When a row's value is a list, the lookup walks it and returns the first `IsSpellKnown` hit; if the player knows none of them, it falls back to the first entry so the popup at least renders the icon (desaturated). This gives "old characters keep working with the spell they originally learned, new characters use the most recent" behavior automatically.

For the recipe to add a row (or sweep the table for a new season), see [common-tasks.md → Add a dungeon teleport spell mapping](./common-tasks.md#add-a-dungeon-teleport-spell-mapping).

The lookup is consumed by:

- `ShowNotification` — only emits the Teleport line if `spellID` is non-nil and `notify.showTeleport` is on; the line includes `IsSpellKnown(spellID)` as a `(not learned)` tag when false.
- `ConfigureTeleportButton` (popup) — desaturates the icon and sets `EnableMouse(false)` when `IsSpellKnown` is false; the button is hidden entirely when `spellID` is nil. The button is a `SecureActionButtonTemplate` parented directly to the popup frame `f` with `type="macro"` + `macrotext="/cast <SpellName>"` — `CastSpellByID` from a non-secure click hits `ADDON_ACTION_FORBIDDEN` in retail. See [frame.md → Teleport button](./frame.md#teleport-button).

## Test path

`WhatGroup:RunTest()` injects synthetic `pendingInfo` (a Mythic+ Stonevault group) and runs `ShowNotification()` + `ShowFrame()` directly — bypassing `OnApplyToGroup`, the queue, the LFG event sequence, and the `_TryFireJoinNotify` join gate. Both `/wg test` and the panel's Test button route through this method, so the two affordances stay in lockstep.

`/wg show` is the read-only equivalent: it opens the popup with whatever `pendingInfo` happens to be set (the most recent real capture), or prints a hint if `pendingInfo` is nil.
