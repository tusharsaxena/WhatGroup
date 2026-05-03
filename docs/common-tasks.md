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

**Primary source for spell IDs and names**: [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) on the Warcraft Wiki. Every "Path of …" page on that wiki gives the canonical spell ID and the destination dungeon/raid in its infobox. The current `TeleportSpells` table has been validated against this category as of patch 12.0.5; entries cite the wiki spell name in their trailing comment so future audits stay easy.

One row to `WhatGroup.TeleportSpells` in `WhatGroup.lua`. The table is keyed by **`mapID`** (the dungeon's instance map ID — stable across seasons):

```lua
WhatGroup.TeleportSpells = {
    -- … existing entries …
    [<mapID>] = <teleportSpellID>,                 -- single spell
    [<mapID>] = { <spellID1>, <spellID2> },        -- when multiple spells exist for the same dungeon (e.g. an original + a re-issued one)
}
```

Find the `mapID`:

- Stand at the dungeon's entrance (or inside it) and run `/dump select(8, GetInstanceInfo())` — that returns the `instanceMapID`.
- Or look it up on Wowhead's instance page (the URL pattern is `wowhead.com/zone=<mapID>` for the instance).
- Or `/wg debug` and apply to a real LFG group for the dungeon — the `activity table OK: mapID=…` log line shows what the LFG API hands us.

For the spell ID, the primary source is the Warcraft Wiki: every "Path of …" page (e.g. [`Path of the Corrupted Foundry`](https://warcraft.wiki.gg/wiki/Path_of_the_Corrupted_Foundry)) lists the canonical spell ID and destination in its infobox. Browse [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) to find the page for the dungeon you need. Wowhead (URL pattern `wowhead.com/spell=<id>`) is a reasonable cross-check. For an in-game lookup, hover the spell in the spellbook with a tooltip-id addon active, or `/dump C_Spell.GetSpellInfo("Path of …")` if you know the localized name.

`WhatGroup:GetTeleportSpell(activityID, mapID)` checks `mapID` first; the `activityID` parameter is kept for back-compat but the table no longer carries activityID-keyed rows (Blizzard rotates activity IDs every season, so they're not a reliable key). When the value is a list, the lookup picks the first spell the player has learned via `IsSpellKnown`; if none are known, it falls back to the first entry so the popup at least shows the icon (desaturated).

After adding the row:

- The chat notification gains a Teleport line on next group-join (when `notify.showTeleport` is on).
- The popup's Teleport button shows the spell icon, desaturated if `IsSpellKnown(spellID)` is false. The button is `SecureActionButtonTemplate` with `type="macro"` + `macrotext="/cast <SpellName>"` — clicking runs the cast through Blizzard's secure handler.
- The cyan `[WG]` chat output says `(not learned)` next to the spell link when the player doesn't have the teleport.

No other code touches the table; the row is fire-and-forget.

### Refreshing for a new season / patch

When Blizzard ships a new M+ season or a patch that adds/changes dungeon teleports, sweep the table:

1. **Identify the season's dungeon list.** From the in-game group finder UI, the patch notes, or by listing every M+ activity returned by `C_LFGList.GetAvailableActivities`. The new-season dungeons are the ones the addon will see in the wild.
2. **Cross-reference the wiki.** Open [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) — every learnable "Path of …" spell is listed there. New season teleports usually appear within hours of patch day. The wiki is the canonical source: each spell page's infobox shows the spell ID and destination dungeon/raid.
3. **For each new dungeon, get the mapID and spellID:**
   - mapID: `/dump select(8, GetInstanceInfo())` at the dungeon entrance, or `/wg debug` + apply to an LFG group and read the debug log's `mapID=` value.
   - spellID: from the wiki spell page (preferred). Wowhead is a reasonable cross-check.
4. **Add the row** under the appropriate `===== <Expansion> =====` section, with a trailing comment that cites the wiki spell name (e.g. `-- Path of the Corrupted Foundry`) so future audits can re-verify quickly. Keep entries sorted by mapID within each expansion for easy diffing.
5. **Check old dungeons that have been re-issued.** Sometimes Blizzard adds a *new* spellID for an existing dungeon (e.g. a Midnight-prepatch refresh — Skyreach picked up `1254557` alongside the original `159898`). If you find a second wiki spell page that points at a mapID already in the table, change the value from a single number to a `{ original, new }` list — the lookup resolves to whichever the player knows.
6. **Verify in-game.** With `/wg debug` on, apply to one group per new dungeon and confirm the debug log shows `GetTeleportSpell HIT mapID=… spellID=…` for the right value, then click the popup's teleport icon and confirm the cast fires (or reports "you don't know that spell" if you haven't learned it — that's also success).

The bottom of `WhatGroup.TeleportSpells` keeps a TODO comment listing every wiki-validated spell whose mapID hasn't been confirmed in-game yet — that's the worklist for future contributions. When you encounter one of those dungeons or raids in the wild and capture its mapID via `/wg debug`, lift the entry up into the active table and delete its TODO line.

### Raid teleports

The wiki's [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) does include several learnable raid-teleport spells (Castle Nathria, Sanctum of Domination, Sepulcher of the First Ones, Vault of the Incarnates, Aberrus, Amirdrassil, Liberation of Undermine, Manaforge Omega — all "Path of …" spells like the dungeon teleports). They follow the same shape, so the addon handles them identically once a row is added. The TODO block at the bottom of `WhatGroup.TeleportSpells` lists every known raid spell with its wiki name; lift them into the active table as their mapIDs are confirmed in-game (apply to a real LFG raid group with `/wg debug` on and the debug log will show the mapID).

## Refresh embedded libs

`libs/` is vendored verbatim from Ka0s KickCD. To refresh:

```bash
# from the WhatGroup root
rm -rf libs/
cp -r /mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/ libs/
```

Then verify `WhatGroup.toc`'s lib block still matches the directory layout — file paths there must point at the actual `.lua` and `.xml` files in the vendored tree. If KickCD has added or removed an Ace3 module since the last refresh, update the TOC accordingly. AceGUI's `.xml` always loads last in the lib block (it pulls in `widgets/` internally).

After refresh, run the [Lib-refresh smoke](./smoke-tests.md#8-lib-refresh-smoke--2-min) section.

## Bump the Interface version

When a major WoW patch ships, the `## Interface:` line in `WhatGroup.toc` needs to include the new build number(s):

```
## Interface: 120000,120001,120005,120100
```

Comma-separated, no spaces. The full list of supported builds — Blizzard rejects the addon at load if the live client's build number isn't in the list (or the user has to opt in via the AddOns "Load out-of-date" checkbox).

After bumping, run the [Patch-day smoke](./smoke-tests.md#7-patch-day-smoke--5-min) section. If a Blizzard API broke (e.g. `C_LFGList.GetActivityInfoTable` fields renamed), [capture-pipeline.md → Captured info](./capture-pipeline.md#captured-info) is the table that lists every field WhatGroup reads.

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
   - The `content` frame's size is fixed by its TOPLEFT + BOTTOMRIGHT anchors, so no SetHeight tweak is needed for layout. If the new row would push past `FRAME_HEIGHT - 38 - 44 ≈ 178 px`, bump `FRAME_HEIGHT` instead (step 5 below).
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
