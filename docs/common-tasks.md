# Common tasks

Recipes for the routine modifications. For deeper context on any subsystem, see [settings-system.md](./settings-system.md), [slash-dispatch.md](./slash-dispatch.md), [capture-pipeline.md](./capture-pipeline.md), and [wow-quirks.md](./wow-quirks.md).

## Add a setting

One row to `Settings.Schema` in `WhatGroup_Settings.lua`. The UI, CLI, defaults, and reset surfaces all follow automatically.

### Bool setting

```lua
add{
    section = "frame",  group = "General",
    path    = "frame.someToggle",  type = "bool",
    label   = "Some Toggle",
    tooltip = "What this toggle does, in one sentence.",
    default = true,
    -- onChange = function(v) … end,   -- optional, runs after the panel widget OR /wg set
    -- solo = true,                      -- optional, force onto its own row
}
```

### Number setting

```lua
add{
    section = "notify",  group = "Notify",
    path    = "notify.someValue",  type = "number",
    label   = "Some Value",
    tooltip = "What this value controls.",
    default = 2.0,
    min = 0, max = 10, step = 0.5, fmt = "%.1fs",
}
```

`min` / `max` clamp the panel slider and `/wg set`. `fmt` is the format string used by `/wg get` / `/wg list` for display (Lua `string.format` rules).

### Action button (afterGroup)

Non-setting affordances live outside the schema. Hand the action to `Helpers.InlineButton` from an `afterGroup` callback in `Settings.Register`:

```lua
Helpers.RenderSchema(generalCtx, {
    ["General"] = function(ctxRef)
        Helpers.InlineButton(ctxRef, {
            text    = "Do The Thing",
            tooltip = "What clicking this does.",
            onClick = function() WhatGroup:DoTheThing() end,
        })
    end,
})
```

The callback fires once, immediately after the last schema row of the named group. `Helpers.InlineButton` renders a 160-px button (override via `spec.width`) left-aligned in a full-width row.

### After adding a row

- If you also want the new value to do something on change, add an `onChange = function(value) … end` to the row. Both the panel widget and `/wg set <path>` call it.
- Read the new value from runtime code via `Settings.Helpers.Get("frame.someToggle")` — never reach into `db.profile` directly, or `Helpers.RefreshAll` won't sync the panel checkbox.
- If you want a section heading break before the row, change its `group` field — `RenderSchema` emits an AceGUI Heading on every group transition.

## Add a slash command

One row to `COMMANDS` in `WhatGroup.lua`. Help output and dispatcher both update automatically.

```lua
local COMMANDS = {
    -- … existing rows …
    {"clear", "Forget the captured group info so /wg show is empty",
        function(self) runClear(self) end},
}

-- … add the handler near the other action commands …

local function runClear(self)
    WhatGroup.pendingInfo = nil
    p("group info cleared")
end
```

If your handler is defined further down the file, add the local to the forward-declaration block at the top of the dispatch section:

```lua
local printHelp, listSettings, getSetting, setSetting
local runReset, runShow, runTest, runConfig, runDebug, runClear   -- ← add yours
```

The order in `COMMANDS` is also the order in `/wg help` output. Pick a slot that reads sensibly.

## Add a dungeon teleport spell mapping

One row to `WhatGroup.TeleportSpells` in `WhatGroup.lua`. The table is keyed by **`mapID`** (the dungeon's instance map ID — stable across seasons):

```lua
WhatGroup.TeleportSpells = {
    -- … existing entries …
    [<mapID>] = <teleportSpellID>,
}
```

Find the `mapID`:

- Stand at the dungeon's entrance (or inside it) and run `/dump select(8, GetInstanceInfo())` — that returns the `instanceMapID`.
- Or look it up on Wowhead's instance page (the URL pattern is `wowhead.com/zone=<mapID>` for the instance).

The teleport spell ID is on the Wowhead spell page (URL pattern `wowhead.com/spell=<id>`).

`WhatGroup:GetTeleportSpell(activityID, mapID)` checks `mapID` first; the `activityID` parameter is kept for back-compat but the table no longer carries activityID-keyed rows (Blizzard rotates activity IDs every season, so they're not a reliable key).

After adding the row:

- The chat notification gains a Teleport line on next group-join (when `notify.showTeleport` is on).
- The popup's Teleport button shows the spell icon, desaturated if `IsSpellKnown(spellID)` is false. The button is `SecureActionButtonTemplate` with `type="macro"` + `macrotext="/cast <SpellName>"` — clicking runs the cast through Blizzard's secure handler.
- The cyan `[WG]` chat output says `(not learned)` next to the spell link when the player doesn't have the teleport.

No other code touches the table; the row is fire-and-forget.

## Refresh embedded libs

`libs/` is vendored verbatim from Ka0s KickCD. To refresh:

```bash
# from the WhatGroup root
rm -rf libs/
cp -r /mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/ libs/
```

Then verify `WhatGroup.toc`'s lib block still matches the directory layout — file paths there must point at the actual `.lua` and `.xml` files in the vendored tree. If KickCD has added or removed an Ace3 module since the last refresh, update the TOC accordingly. AceGUI's `.xml` always loads last in the lib block (it pulls in `widgets/` internally).

After refresh:

1. Reload in-game (`/reload`) to confirm there are no boot errors.
2. Open the Settings panel and confirm widgets render normally.
3. Run `/wg test` to confirm the pipeline still works end-to-end.

## Bump the Interface version

When a major WoW patch ships, the `## Interface:` line in `WhatGroup.toc` needs to include the new build number(s):

```
## Interface: 120000,120001,120005,120100
```

Comma-separated, no spaces. The full list of supported builds — Blizzard rejects the addon at load if the live client's build number isn't in the list (or the user has to opt in via the AddOns "Load out-of-date" checkbox).

After bumping, also smoke-test:

- Login on the patched client without the "out of date" warning.
- `/wg test` — full pipeline.
- Apply to a real LFG group — capture pipeline.

If a Blizzard API broke (e.g. `C_LFGList.GetActivityInfoTable` fields renamed), [capture-pipeline.md → Captured info](./capture-pipeline.md#captured-info) is the table that lists every field WhatGroup reads.

## Bump the addon version

**Don't do this without an explicit instruction from the user** — release versioning is the user's call. See `CLAUDE.md` Hard Rules.

When the user does ask, the version sites are:

| Site | Where |
|---|---|
| `## Version:` | `WhatGroup.toc` line 5 |
| `WhatGroup.VERSION` | `WhatGroup.lua` line 25 |
| README badge | `README.md` (look for the version-shield URL) |
| README "Version History" table | `README.md` |
| Settings parent panel subtitle | derived from `WhatGroup.VERSION` at runtime — no hard-coded copy |
| `/wg help` output | derived from `WhatGroup.VERSION` at runtime — no hard-coded copy |

The user has a `/wow-addon:version-bump <X.Y.Z>` slash command in their personal `wow-addon` plugin that updates every site in one pass. Prefer that over manual edits.

## Add a captured-info field

If `C_LFGList.GetSearchResultInfo` or `C_LFGList.GetActivityInfoTable` exposes a new field worth showing:

1. Add it to the `captured` table inside `CaptureGroupInfo` in `WhatGroup.lua`, with a sensible default.
2. If it's surfaced in the popup, add a row to `WhatGroup_Frame.lua`:
   - Add a new `MakeLabel` call after the existing rows, anchored against the previous label.
   - Add a `fields.<name>` entry to the storage table.
   - Add a populator branch in `PopulateFields` reading `info.<field>`.
   - Add a `VALUE_COLORS.<name>` resolver if the field needs colour rules.
   - Update the content frame height (`content:SetHeight(math.abs(yGap) * <new row count> + 24)`).
3. If it's surfaced in chat, add a print branch in `ShowNotification` and a corresponding `notify.show<Name>` schema row gated by `n.show<Name>`.
4. Update the captured-info table in [capture-pipeline.md](./capture-pipeline.md#captured-info).
5. If the popup's height needs to grow to fit a new row, also bump `FRAME_HEIGHT` at the top of `WhatGroup_Frame.lua`.

## Test the full pipeline without joining a group

```
/wg test
```

Injects synthetic `pendingInfo` (a Mythic+ Stonevault group) and runs `ShowNotification` + `ShowFrame` directly. Bypasses `OnApplyToGroup`, the queue, the LFG event sequence, and the `wasInGroup` join gate.

The Settings panel's Test button runs the same code path — both invoke `WhatGroup:RunTest()`. See [slash-dispatch.md](./slash-dispatch.md#why-runtest-is-split-between-wg-test-and-whatgroupruntest).

## Toggle debug logging

```
/wg debug
```

Toggles `db.profile.debug` and the `WhatGroup.debug` runtime flag together. Verbose `[DBG]`-tagged lines start printing for every event/hook fire. Useful when:

- The notification fires at the wrong time → `GROUP_ROSTER_UPDATE` debug shows `inGroup` / `wasInGroup` / `hasPending` at every roster update.
- The capture is empty → `CaptureGroupInfo` debug dumps the entire `info` table from `GetSearchResultInfo`, the `actInfo` table from `GetActivityInfoTable` (or a "returned nil" line when it's missing), and a final `CaptureGroupInfo result:` summary with the fields downstream consumers actually read (`title`, `activityID`, `mapID`, `isMythicPlus`, `generalPlaystyle`, `playstyleString`).
- The teleport icon doesn't appear → `GetTeleportSpell` logs every lookup as either `HIT mapID=X spellID=Y`, `HIT activityID=X spellID=Y` (back-compat path), or `MISS — activityID=…, mapID=…`. A `MISS` paired with a `mapID=nil` line up in `CaptureGroupInfo result` means the activity table didn't surface a mapID; a `MISS` with a non-nil mapID means the dungeon needs a row in `WhatGroup.TeleportSpells`.
- The LFG event sequence is misordered → `LFG_LIST_APPLICATION_STATUS_UPDATED` debug logs every (`appID`, `status`) tuple. The `inviteaccepted` branch logs `inviteaccepted resolved: fresh=mapID=… queued=mapID=… pendingInfo=mapID=… title=…` so you can see exactly which capture (fresh re-fetch vs apply-time queued) won the merge and what the final `pendingInfo` looks like.
- The popup or chat link came up empty → the trail at notify time is `GROUP_ROSTER_UPDATE: scheduling notify in Xs pendingInfo at schedule: …` → `notify timer fired pendingInfo still set? true/false same identity? true/false` → `ShowNotification: pendingInfo=…` → `ShowFrame: pendingInfo=…` → `ConfigureTeleportButton: info.activityID=… info.mapID=… spellID=…`. If `pendingInfo` is set at scheduling time but nil when the timer fires, watch for a `GROUP_ROSTER_UPDATE inGroup=false → clearing pendingInfo` line in between — that's the join transition flipping back to false (server hiccup, group disbanded, etc.). For chat-link clicks, `OnSetItemRef WhatGroup link clicked, pendingInfo=…` shows the state at click time.

Same code path as `/wg set debug toggle` — the `/wg debug` shortcut exists so it's reachable from muscle memory.
