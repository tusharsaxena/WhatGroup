# Common tasks

Recipes for the routine modifications. For deeper context on any subsystem, see [settings-panel.md](./settings-panel.md), [slash-dispatch.md](./slash-dispatch.md), [data-flow.md](./data-flow.md), and [midnight-quirks.md](./midnight-quirks.md).

## Add a setting

One row to `Settings.Schema` in `settings/Schema.lua`. The UI, CLI, defaults, and reset surfaces all follow automatically.

**Its `group` is a TAB** (`options-ui-§13`), not a heading: the page draws one tab per distinct group, in declaration order. So a row filed under an existing group has to sit **inside that group's run** of `add{}` calls — a row placed after the run prints the same tab twice. A new `group` value is a new tab, drawn in the position its first row occupies; do not add one for a single row (a tab over one control is a click that reveals one checkbox, and `tests/test_settings.lua` fails it). The three today are **General**, **Chat** and **Popup**.

The value itself goes in `defaults/Profile.lua` as `NS.C.<path>`, and the row references it as `default = C.<path>` — two literals for one value is the shape that drifts.

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
    section = "notify",  group = "Chat",
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
Helpers.RenderTabbedSchema(generalCtx, "general", {
    ["General"] = function(ctxRef)
        Helpers.InlineButton(ctxRef, {
            text    = "Do The Thing",
            tooltip = "What clicking this does.",
            onClick = function() WhatGroup:DoTheThing() end,
        })
    end,
})
```

The callback fires once, immediately after the last schema row of the named group — so on a tabbed page it draws only while THAT tab is open, which is what keeps a General action off the Chat tab. `Helpers.InlineButton` renders a 160-px button (override via `spec.width`) left-aligned in a full-width row.

### After adding a row

- If you also want the new value to do something on change, add an `onChange = function(value) … end` to the row. Both the panel widget and `/wg set <path>` call it.
- Read the new value from runtime code via `Settings.Helpers.Get("frame.someToggle")` — never reach into `db.profile` directly, or `Helpers.RefreshAll` won't sync the panel checkbox.
- If you want the row on a different tab, change its `group` field and move the `add{}` call into that group's run. **Do not change its `path`** — the page is where a row is edited, the path is where it is stored, and renaming a path migrates every saved profile for something nobody can see.

## Add a slash command

One row to `COMMANDS` in `settings/Slash.lua`. The dispatcher, `/wg help` and the settings landing page all iterate that one table, so all three update automatically.

Rows are **positional triples** — `{ name, description, handler }` — and the handler takes `rest` **alone**. That is the shape `LibKa0s-Slash-1.0` reads (`entry[1]` / `[2]` / `[3]`); a table of named fields is silently invisible to it, and a handler written `function(self, rest)` receives the *rest string* as `self`.

```lua
local COMMANDS = {
    -- … existing rows …
    {"clear",    L["Forget the captured group info so /wg show is empty"],
        function() runClear() end},
}

-- … add the handler near the other host verbs, at the bottom of the file …

function runClear()
    WhatGroup.pendingInfo = nil
    NS.Print("group info cleared")
end
```

If your handler is defined below the table, add it to the forward-declaration line above it:

```lua
local runShow, runTest, runConfig, runDebug, runReset, runResetAll, runClear   -- ← add yours
```

Route the description through `NS.L[...]` at declaration, as the existing rows do — the library renders the table verbatim, so wrapping it later is not an option, and the metatable fallback makes it behavior-preserving today (localization-§1). Add the key to `locales/enUS.lua` alongside the others.

The order in `COMMANDS` is the order in `/wg help` **and** on the landing page. Pick a slot that reads sensibly.

## Add a dungeon teleport spell mapping

**Primary source for spell IDs and names**: [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) on the Warcraft Wiki. Every "Path of …" page on that wiki gives the canonical spell ID and the destination dungeon/raid in its infobox. Entries carry a trailing comment with the dungeon name for at-a-glance scanning.

One row to `NS.TeleportSpells` in `TeleportSpells.lua`. The table is keyed by **`mapID`** (the dungeon's instance map ID — stable across seasons):

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
- Or `/wg debug` and apply to a real LFG group for the dungeon — the `[Apply]` log line (`id=… captured "…" (activity=… map=…)`) shows the `mapID` the LFG API hands us.

Find the **spell ID** from a spellbook that owns the teleport — that is the only source that cannot be a near-miss. Paste this on a character who has learned it:

```
/run local B=Enum.SpellBookSpellBank.Player for i=1,600 do local s=C_SpellBook.GetSpellBookItemInfo(i,B) if s and s.name and s.name:find("Path of") then print(s.name,s.spellID) end end
```

It prints every learned "Path of …" with its ID, alphabetically. Take the ID from that list verbatim.

The Warcraft Wiki ([`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities), e.g. [`Path of the Corrupted Foundry`](https://warcraft.wiki.gg/wiki/Path_of_the_Corrupted_Foundry)) and Wowhead (`wowhead.com/spell=<id>`) are the fallback when nobody available has the spell, and a reasonable cross-check otherwise — but treat them as unverified. **The spell name never contains the dungeon name**, so searching by dungeon returns something adjacent rather than nothing, and neighbouring IDs in the same patch block are different spells entirely: `1254553` (one digit off Nexus-Point Xenas' real `1254563`) is a spell called "Hero's Path", and it shipped twice from name-based lookups before a spellbook dump caught it.

A wrong ID does not error. The row renders desaturated with a `(not learned)` tag for a player who owns the teleport, and the button's `/cast` names a spell nobody has — so "it looks fine, just greyed out" is the failure mode to watch for, not a clue that the player is missing the teleport.

`WhatGroup:GetTeleportSpell(activityID, mapID)` checks `mapID` first; the `activityID` parameter is kept for back-compat but the table no longer carries activityID-keyed rows (Blizzard rotates activity IDs every season, so they're not a reliable key). When the value is a list, the lookup picks the first spell the player has learned via `IsSpellKnown`; if none are known, it falls back to the first entry so the popup at least shows the icon (desaturated).

After adding the row:

- The chat notification gains a Teleport line on next group-join (when `notify.showTeleport` is on).
- The popup's Teleport button shows the spell icon, desaturated if `IsSpellKnown(spellID)` is false. The button is `SecureActionButtonTemplate` with `type="macro"` + `macrotext="/cast <SpellName>"` — clicking runs the cast through Blizzard's secure handler.
- The cyan `[WG]` chat output tags the spell link `(not learned)` when the player doesn't have the teleport, or `(on cooldown)` when they do but it is still recharging.

No other code touches the table; the row is fire-and-forget.

### Refreshing for a new season / patch

When Blizzard ships a new M+ season or a patch that adds/changes dungeon teleports, sweep the table:

1. **Identify the season's dungeon list.** From the in-game group finder UI, the patch notes, or by listing every M+ activity returned by `C_LFGList.GetAvailableActivities`. The new-season dungeons are the ones the addon will see in the wild.
2. **Cross-reference the wiki.** Open [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) — every learnable "Path of …" spell is listed there. New season teleports usually appear within hours of patch day. The wiki is the canonical source: each spell page's infobox shows the spell ID and destination dungeon/raid.
3. **For each new dungeon, get the mapID and spellID:**
   - mapID: `/dump select(8, GetInstanceInfo())` at the dungeon entrance, or `/wg debug` + apply to an LFG group and read the debug log's `mapID=` value.
   - spellID: from the spellbook sweep above, on a character that owns the teleport (authoritative). The wiki spell page and Wowhead are the fallback when nobody has it yet, and stay unverified until a spellbook confirms them.
4. **Add the row** under the appropriate `===== <Expansion> =====` section, with a trailing comment giving the dungeon name (e.g. `-- The Stonevault`). Keep entries sorted by mapID within each expansion for easy diffing.
5. **Check old dungeons that have been re-issued.** Sometimes Blizzard adds a *new* spellID for an existing dungeon (e.g. a Midnight-prepatch refresh — Skyreach picked up `1254557` alongside the original `159898`). If you find a second wiki spell page that points at a mapID already in the table, change the value from a single number to a `{ original, new }` list — the lookup resolves to whichever the player knows.
6. **Verify in-game.** With `/wg debug` on, apply to one group per new dungeon, open the popup, and confirm the `[Frame]` log line (`teleport spellID=… known=… (activity=… map=…)`) shows the right spell for that `mapID`, then click the popup's teleport icon and confirm the cast fires (or reports "you don't know that spell" if you haven't learned it — that's also success).

The bottom of `TeleportSpells.lua` keeps a "Pending in-game mapID verification" comment block plus commented-out placeholder rows (e.g. raid teleports whose spell exists on the wiki but whose mapID hasn't been captured in-game yet). When you encounter one of those instances in the wild and capture its mapID via `/wg debug`, replace the placeholder line with an active row and remove the comment.

### Raid teleports

The wiki's [`Category:Instance teleport abilities`](https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities) does include several learnable raid-teleport spells (Castle Nathria, Sanctum of Domination, Sepulcher of the First Ones, Vault of the Incarnates, Aberrus, Amirdrassil, Liberation of Undermine, Manaforge Omega — all "Path of …" spells like the dungeon teleports). They follow the same shape, so the addon handles them identically once a row is added. The placeholder block at the bottom of `TeleportSpells.lua` lists raids whose teleport spell exists but whose mapID still needs in-game confirmation; lift them into the active table as their mapIDs are captured (apply to a real LFG raid group with `/wg debug` on and the debug log will show the mapID).

## Refresh embedded libs

Two different jobs, with two different rules.

**The Ace3 stack** is vendored verbatim from Ka0s KickCD:

```bash
# from the WhatGroup root — Ace3 + LibStub + CallbackHandler + LibSharedMedia only
cp -r /mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/AceAddon-3.0/ libs/
# … and so on per directory. Do NOT `rm -rf libs/` — that takes libs/LibKa0s with it.
```

Then verify `WhatGroup.toc`'s lib block still matches the directory layout. If KickCD has added or removed an Ace3 module since the last refresh, update the TOC accordingly. AceGUI's `.xml` loads late in the block (it pulls in `widgets/` internally); `LibKa0s.xml` loads after it, last.

**`libs/LibKa0s/` is a sync, not a copy.** It and `tests/_kit/` are whole-folder copies of `../LibKa0s`'s two ship folders, and the rule is byte-identity:

```bash
cp -r ../LibKa0s/LibKa0s/. libs/LibKa0s/
cp -r ../LibKa0s/testkit/. tests/_kit/
```

- **Copy the WHOLE folder, never one file.** Every other major returns before `LibStub:NewLibrary` when `Core.lua` is missing or older than their floor, so a partial copy makes a module *absent* rather than half-wired — the addon loads, works badly, and says nothing (anti-patterns #48).
- **Never edit either tree.** A library problem is a finding to fix in `../LibKa0s` and re-vendor. A local patch is a fork nobody knows about, and the next re-vendor silently reverts it.
- **Run the vendor gate afterwards** — all four diffs in [testing.md](./testing.md) — because nothing else can see a stale copy: the library's suite passes against the library and this addon's passes against a stale copy that still works, so both repos stay green while they diverge (anti-patterns #45).
- **Move the `CLAUDE.md` provenance line in the same commit**, so "which LibKa0s does this ship?" stays answerable without grepping a minor constant out of every vendored library file.

After either refresh, run the [Lib-refresh smoke](./smoke-tests.md#8-lib-refresh-smoke--2-min) section — and after a LibKa0s one, §9 and §11 as well.

## Bump the Interface version

When a major WoW patch ships, the `## Interface:` line in `WhatGroup.toc` moves to the new build number:

```
## Interface: 120007
```

**One number, never a comma-separated list.** This addon is Retail-only (toc-file-§3, [scope.md](./scope.md)), so there is exactly one supported build at a time and a multi-build list is anti-pattern #15 — it is the shape an addon carries when it also ships Classic, which this one deliberately does not. Blizzard rejects the addon at load if the live client's build number is not the one named (or the user opts in via the AddOns "Load out-of-date" checkbox), which is the intended signal on patch day: the addon goes quiet until someone has actually checked the API surface still holds.

`/wow-addon:bump-interface` does this and tells you the current Live value.

**Move the README `[wow]` badge in the same change** (documentation-§1 / toc-file-§3). The static `WoW-<Expansion>_<X.Y.Z>-purple` badge and `## Interface:` MUST show the same patch and travel together — it renders fixed text, so it goes stale silently if deferred to a follow-up.

After bumping, run the [Patch-day smoke](./smoke-tests.md#7-patch-day-smoke--5-min) section. If a Blizzard API broke (e.g. `C_LFGList.GetActivityInfoTable` fields renamed), [data-flow.md → Captured info](./data-flow.md#captured-info) is the table that lists every field WhatGroup reads.

## Bump the addon version

**Don't do this without an explicit instruction from the user** — release versioning is the user's call. See the root [`CLAUDE.md`](../CLAUDE.md).

When the user does ask, the version sites are:

| Site | Where |
|---|---|
| `## Version:` | `WhatGroup.toc` line 5 |
| `WhatGroup.VERSION` | `core/WhatGroup.lua` line 35 |
| README badge | `README.md` (look for the version-shield URL) |
| README "Version History" table | `README.md` |
| Settings parent panel subtitle | derived from `WhatGroup.VERSION` at runtime — no hard-coded copy |
| `/wg help` output | derived from `WhatGroup.VERSION` at runtime — no hard-coded copy |

The user has a `/wow-addon:bump-version <X.Y.Z>` slash command in their personal `wow-addon` plugin that updates every site in one pass. Prefer that over manual edits.

**In the same change, before the tag:** regenerate the complexity report and read its diff —

```sh
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
```

— writing anything that newly crossed a threshold into `docs/automated-tests/RESULTS.md`'s watch list. This is a **release** checkpoint and **not** a commit gate; see [testing.md → The complexity report](./testing.md#the-complexity-report--a-release-checkpoint-not-a-commit-gate) and performance-§10.

## Add a captured-info field

If `C_LFGList.GetSearchResultInfo` or `C_LFGList.GetActivityInfoTable` exposes a new field worth showing:

1. Add it to the `captured` table literal inside the file-local `buildCapture` in `WhatGroup.lua`, with a sensible default. `CaptureGroupInfo` no longer holds that table — it is control flow only (nil guard, `buildCapture`, then the activity block). Write the default as an `or` chain like every other line there: `or` replaces a stored `false` with the default and `if x == nil` does not, and downstream consumers assume the `or` semantics. A field that comes from `C_LFGList.GetActivityInfoTable` rather than the search result goes in the sibling `applyActivityInfo` instead, and — unless it is deliberately absent-until-resolved like `shortName` — gets a placeholder in `buildCapture` too.
2. If it's surfaced in the popup, add a row to `modules/Frame.lua`:
   - Add a new `MakeLabel` call after the existing rows, anchored against the previous label.
   - Add a `fields.<name>` entry to the storage table.
   - Add a populator branch in `PopulateFields` reading `info.<field>`.
   - The `content` frame's size is fixed by its TOPLEFT + BOTTOMRIGHT anchors, so no SetHeight tweak is needed for layout. If the new row would push past `frame.height - 38 - 44` (≈ 178 px at the shipped 260), the popup needs to be taller — see step 5 below.
3. If it's surfaced in chat, add an entry to the module-level `NOTIFY_ROWS` table above `ShowNotification` — `{ flag = "show<Name>", label = "<Name>:", value = function(self, info) ... end }` — placed at the position in the table where you want the row printed, since the table order *is* the chat order. `ShowNotification` itself no longer carries a branch per row; it loops the table and gates each entry on `n[row.flag]`. Add `omitWhenNil = true` only if the row should vanish entirely when there is nothing to show — the default is to print the row with the value degraded by the `NS.SafeToString` seam, which is what the Leader row relies on. Add the matching `notify.show<Name>` schema row.
4. Update the captured-info table in [data-flow.md](./data-flow.md#captured-info).
5. If the popup's height needs to grow to fit a new row, the height is a **setting**, not a file-local: raise `frame.height`'s shipped default in `defaults/Profile.lua` (`NS.C.frame.height`) and, if the new floor is above it, the schema row's `min` in `settings/Schema.lua` together with `FRAME_H_MIN` / `FRAME_H_MAX` at the top of `modules/Frame.lua` — the clamp pair and the slider bounds are mirrored on purpose and must move together.

## Test the full pipeline without joining a group

```
/wg test
```

Injects synthetic `pendingInfo` (a Mythic+ Windrunner Spire group) and runs `ShowNotification` + `ShowFrame` directly. Bypasses `OnApplyToGroup`, the queue, the LFG event sequence, and the `wasInGroup` join gate.

The Settings panel's Test button runs the same code path — both invoke `WhatGroup:RunTest()`. See [slash-dispatch.md](./slash-dispatch.md#why-runtest-is-split-between-wg-test-and-whatgroupruntest).

## Toggle debug logging

```
/wg debug on      -- enable logging (session-only)
/wg debug         -- open/close the on-screen debug console window
/wg debug off     -- disable logging
```

Debug output routes to an **on-screen console** (`WhatGroupDebugWindow`), styled
like the main popup, in a monospace font — **not** the chat frame. This is the
standard's requirement for any addon that ships a main window (debug-logging-§7);
the console is `LibKa0s-DebugLog-1.0`'s, wired in `core/DebugLogSetup.lua`. Each line is
`HH:MM:SS | [Tag] message`. Full
detail in [debug.md](./debug.md).

`NS.State.debug` is session-only (default off, never persisted, off again on the
next login). Logging and the window are independent — capture runs even with the
console closed, so you can reproduce a bug first and open the console after with
`/wg debug` to read the trace. Enabling/disabling is session-bracketed by a
`[Debug] logging enabled` / `disabled` console line.

Turning debug on emits a one-line **`[Init]` session summary** first — the
standard-mandated `WhatGroup v<version>, schema v<schemaVersion>, profile
'<profile>'` followed by the current runtime state `(enabled=…, notify.delay=…s,
autoShow=…, inGroup=…, hasPending=…)` — so a pasted log is self-identifying
(build / schema / profile) and opens with full context. It's written at the
`DebugLog:SetEnabled` seam, right after the `[Debug] logging enabled` bracket
(debug-logging-§5). The tags emitted, and what each is useful for:

- **`[Init]`** / **`[Migrate]`** — lifecycle: the session summary (emitted on
  enable, via `WhatGroup:InitSummary()`); `[Migrate]` prints `vX -> vY` only when
  a DB migration actually runs.
- **`[Apply]`** → one merged line per apply: `id=… captured "…" (activity=… map=…
  m+=…)` — the apply-hook + capture in a single line. **`[Capture]`** carries the
  no-op decisions (`GetSearchResultInfo returned nil …`, `wiped (addon disabled)`)
  — for "capture is empty / vanished".
- **`[LFG]`** → every `appID status=…` event, and **`[Invite]`** → `accepted … →
  "<title>" map=… (source=fresh|queued)` showing which capture won the merge —
  for "the LFG sequence is misordered".
- **`[Roster]`** → `inGroup / wasInGroup / hasPending` on in-group transitions
  only (no-op ticks suppressed) — for "notification fires at the wrong time".
- **`[Notify]`** → `scheduling in Ns (reason)` → `fired` / `canceled
  (superseded)` / skip lines, and **`[Frame]`** → `popup shown "…"` /
  `teleport spellID=… known=…` — for "popup or chat link came up empty". A
  `teleport spellID=nil` with a non-nil `map=` means the dungeon needs a row in
  `WhatGroup.TeleportSpells`. **`[ChatLink]`** / **`[Test]`** mark the chat-link
  click and `/wg test` entry points.
- **`[Set]`** → one line per settings change (`<path> = <value>`) at the
  `Helpers.Set` seam; **`[Reset]`** → one summary for `/wg resetall`, naming the profile rather than a row count (it is a profile reset, not a row walk);
  **`[Schema]`** → an internal path-lookup miss.

To add a new debug line, call `NS.Debug("Tag", "fmt", …)` — it self-gates on
`NS.State.debug` and is zero-alloc when off. Follow the standard's content rules:
**cover** the main flows (debug-logging-§8), **coalesce** repeating paths to one summary line —
never per-item (debug-logging-§9), and log each **settings change once** at the `Helpers.Set`
seam (debug-logging-§10). Debug is **not** a schema row (WG-12), so there is no `/wg set debug`
— `/wg debug on|off` is the only enable path.
