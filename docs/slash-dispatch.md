# Slash dispatch

`/wg` and `/whatgroup` are aliases for the same command set. The dispatch lives at the bottom of `WhatGroup.lua` and is driven by a single ordered table.

## Registration

Both names are registered through `AceConsole-3.0:RegisterChatCommand` in `OnInitialize`:

```lua
self:RegisterChatCommand("wg",        "OnSlashCommand")
self:RegisterChatCommand("whatgroup", "OnSlashCommand")
```

The `OnSlashCommand` method receives the raw input (everything after the slash command name).

## Case-preserving parse

The dispatcher lowercases only the command name — the rest of the input is passed through untouched:

```lua
local cmd, rest = raw:match("^(%S+)%s*(.*)$")
cmd  = (cmd or ""):lower()
rest = rest or ""
```

This matters for paths like `notify.showInstance` in `/wg set notify.showInstance false` — lowercasing the whole input would corrupt the path. Schema row paths are camelCase to match Lua's idiomatic field naming, so case-preservation is required.

## The `COMMANDS` table

Every command is one row in a single ordered list:

```lua
local COMMANDS = {
    {"help",   "List available commands",                     handler},
    {"show",   "Show the last group info dialog",             handler},
    {"test",   "Inject synthetic group info and run …",       handler},
    {"config", "Open the Ka0s WhatGroup Settings panel",      handler},
    {"list",   "List every setting and its current value",    handler},
    {"get",    "Print a setting's current value …",            handler},
    {"set",    "Set a setting …",                              handler},
    {"reset",  "Reset every setting to defaults",             handler},
    {"debug",  "Toggle debug logging",                        handler},
}
```

Each entry is `{name, description, fn(self, rest)}`. `findCommand(COMMANDS, cmd)` linear-scans by `entry[1]`. An unknown command falls through to `printHelp(self)`.

The order in the table is also the order in `/wg help` output — `printHelp` iterates `COMMANDS` directly. So adding a command = one row, in whichever order makes the help output read sensibly.

Forward declarations at the top of the dispatch section let the table reference handlers defined further down:

```lua
local printHelp, listSettings, getSetting, setSetting
local runReset, runShow, runTest, runConfig, runDebug
```

## Help output convention

```
[WG] v1.2.0 — slash commands (/whatgroup is an alias for /wg):
  /wg help — List available commands
  /wg show — …
```

- Cyan `[WG]` chat prefix on every line.
- Yellow (`|cffFFFF00`) for slash commands.
- White (`|cffFFFFFF`) for explanatory text.
- One line per command.
- The version number comes from `WhatGroup.VERSION`, set at the top of `WhatGroup.lua`.

## Command behaviour

| Command | Handler | Behaviour |
|---|---|---|
| `/wg` (no args) | `printHelp` | Print help. |
| `/wg help` | `printHelp` | Print help. |
| `/wg show` | `runShow` | Open the popup if `pendingInfo` is set. Otherwise print a hint pointing at `/wg test`. |
| `/wg test` | `runTest` → `WhatGroup:RunTest()` | Inject synthetic `pendingInfo` (Mythic+ Stonevault) and run `ShowNotification()` + `ShowFrame()`. Mirrors the panel's Test button via the same `RunTest()` method, so the two affordances stay in lockstep. |
| `/wg config` | `runConfig` | Refuses during `InCombatLockdown()` (Settings UI is taint-protected). Otherwise calls `Settings.OpenToCategory(self._parentSettingsCategory:GetID())` then `pcall`s into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` — opens the addon-landing page and unfolds the subcategory tree so General is one click away. The pcall protects against patch-day shifts in the private CategoryList internals: if the path breaks, the panel still opens, the tree just doesn't auto-unfold. |
| `/wg list` | `listSettings` | Group `Schema` by `section`, print `path = formattedValue` for every row. |
| `/wg get <path>` | `getSetting` | `Helpers.FindSchema(path)` + format using `def.fmt` for numbers (e.g. `"%.1fs"` → `1.5s`). Prints "Setting not found" for unknown paths. |
| `/wg set <path> <value>` | `setSetting` → `applyFromText` | Type-aware parse: bool accepts `true / false / on / off / 1 / 0 / yes / no / toggle`; number coerces via `tonumber` and clamps to `min / max` if set. Calls `Helpers.Set(path, value)` — the orchestrated single write-path that internally writes the value, fires the row's `onChange`, then refreshes panel widgets — and echoes the new value. |
| `/wg reset` | `runReset` → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → `Helpers.RestoreDefaults()` | Show a confirm popup; on accept, reset every row to its `default`, run each `def.onChange(default)` in pcall, refresh panel widgets. The Defaults button in the General sub-page header shows the same popup, so both paths share one OnAccept body. |
| `/wg debug` | `runDebug` | Toggle `db.profile.debug` and `WhatGroup.debug` together. Equivalent to `/wg set debug toggle`, kept as a convenience shortcut. Prefers `Helpers.Set` so the panel checkbox refreshes; falls back to a direct `db.profile.debug` write only at early-boot if the settings layer isn't loaded yet. |

## Why `runTest` is split between `/wg test` and `WhatGroup:RunTest()`

`WhatGroup:RunTest()` is a public method on the addon table — anything with a handle on `WhatGroup` can invoke it. The local `runTest(self)` in the COMMANDS table just delegates: `function runTest(self) self:RunTest() end`.

This split exists because the Settings panel's Test button (rendered via `Helpers.InlineButton` in an `afterGroup` callback in `WhatGroup_Settings.lua`) needs to invoke the same code path without going through slash dispatch:

```lua
Helpers.InlineButton(ctxRef, {
    text    = "Test",
    onClick = function() if WhatGroup.RunTest then WhatGroup:RunTest() end end,
})
```

So `/wg test` and the panel button stay in lockstep with zero risk of drift.

## Adding a command

One row to `COMMANDS`. See [common-tasks.md](./common-tasks.md#add-a-slash-command) for the recipe.
