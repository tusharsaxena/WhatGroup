# Slash dispatch

`/wg` and `/whatgroup` are aliases for the same command set. The dispatcher, the help renderer, the schema CLI and the type-aware value parser are **LibKa0s-Slash-1.0**'s (`libs/LibKa0s/Slash.lua`). `settings/Slash.lua` — last in the TOC — supplies the descriptor, owns the `COMMANDS` table, and implements the verbs whose behavior is genuinely this addon's.

## Registration

Both names are registered through `AceConsole-3.0:RegisterChatCommand` in `OnInitialize` (`core/WhatGroup.lua:289`):

```lua
self:RegisterChatCommand("wg",        "OnSlashCommand")
self:RegisterChatCommand("whatgroup", "OnSlashCommand")
```

`WhatGroup:OnSlashCommand` (`settings/Slash.lua:449`) hands the raw input straight to `Sl:OnSlash`. The library deliberately registers no chat command of its own — AceConsole stays the single registrar, so every verb's output keeps flowing through the tagged printer (slash-commands-§1).

## Case-preserving parse

The dispatcher (`libs/LibKa0s/Slash.lua:766`) lowercases only the command name — the rest of the input is passed through untouched:

```lua
local cmd, rest = raw:match("^(%S+)%s*(.*)$")
cmd  = (cmd or ""):lower()
rest = rest or ""
```

This matters for paths like `notify.showInstance` in `/wg set notify.showInstance false` — lowercasing the whole input would corrupt the path. Schema row paths are camelCase to match Lua's idiomatic field naming, so case-preservation is required. `Sl:CliReset` does not lowercase its path argument either, for the same reason.

## The `COMMANDS` table

The table stays host-owned, in `settings/Slash.lua`, and crosses to the library as plain **data** on the descriptor's `commands` field. That is what keeps the slash library and the options library from having to resolve each other: the settings landing page renders the same table (published as `WhatGroup.COMMANDS`) without its library depending on this one.

Every command is one row in a single ordered list:

```lua
local COMMANDS = {
    {"help",     L["List available commands"],
        function() Sl:PrintHelp() end},
    {"show",     L["Show the last group info dialog"],
        function() runShow() end},
    ...
    {"reset",    L["Reset one setting to its default — `/wg reset <path>`"],
        function(rest) runReset(rest) end},
    {"resetall", L["Reset every setting to defaults"],
        function() runResetAll() end},
    {"debug",    L["Open/close the debug window — `/wg debug on|off` toggles logging"],
        function(rest) runDebug(rest) end},
}
```

Each entry is a **positional triple** `{name, description, fn(rest)}` — the shape the library reads (`entry[1]` / `[2]` / `[3]`); a table of named fields is silently invisible to it. The handler takes `rest` **alone**, never `self` plus `rest`: `entry[3](rest)` is the only call the library makes. `findCommand` linear-scans by `entry[1]`; an unknown verb prints `unknown command '<name>'` and then the help index.

Descriptions route through `NS.L` at **declaration** rather than at render, because the library renders the table verbatim. `NS.L`'s metatable answers an unknown key with the key itself, so this is behavior-preserving today and the translator's surface tomorrow (localization-§1).

The order in the table is the order of both `/wg help` and the settings landing page — `Sl:HelpRows` / `Sl:LandingRows` walk it directly. So adding a command = one row, in whichever order reads sensibly.

Forward declarations at the top of the file let the table reference the host handlers defined further down:

```lua
local Sl                      -- forward-declared: the handlers below reach it at call time
local runShow, runTest, runConfig, runDebug, runReset, runResetAll, runEnabled
```

## Help output convention

```
[WG] v1.4.0 — slash commands (/whatgroup is an alias for /wg)
  /wg help — List available commands
  /wg show — Show the last group info dialog
```

- Cyan `[WG]` chat prefix on every line, from `NS.PREFIX` via the shared printer.
- Header is `lib.STRINGS.HELP_HEADER` — `v%s — slash commands`, with an **em dash** — plus `HELP_ALIAS`, which names `/whatgroup` as the alias for `/wg` in gold.
- One row per command, from `lib.FormatRow`: gold command, an em dash with one space either side, white description. `Sl:HelpRows()` indents each row by two spaces (the chat form, sitting under a header); `Sl:LandingRows()` is the same rows un-indented (the panel form, where each row is its own label).
- Gold is `|cFFFFFF00` and white `|cFFFFFFFF` — **upper-case** hex in the command-row and `key = value` formatters. The `/wg list` header and group headings stay lower-case (`|cff33ff99`, `|cff3399ff`) on purpose: only the row formatters converged on upper-case, and recasing the rest would be a user-visible change nobody asked for.
- No trailing colon on any printed line (slash-commands-§4 / WG-19).
- The version comes from `NS.Version()` in `core/EnvSetup.lua`, passed to the descriptor as `version` and called at render time — TOC metadata through `LibKa0s-Env-1.0` (or the `C_AddOns.GetAddOnMetadata` ladder when the library is absent) first, so it cannot drift from the packaged manifest, falling back to the in-code `WhatGroup.VERSION`.

## Command behavior

Library verbs delegate to the instance; host verbs are the file-local functions at the bottom of `settings/Slash.lua`.

| Command | Handler | Behavior |
|---|---|---|
| `/wg` (no args) | the `config` row → `runConfig` (host) | The library's dispatcher runs the host's `config` verb, so a bare `/wg` opens the Settings panel on its landing page, exactly as `/wg config` does (slash-commands-§4). Whitespace-only input counts as bare. A host with no `config` row would get the help index instead. |
| `/wg help` | `Sl:PrintHelp` (library) | Print the header + every command row. |
| `/wg show` | `runShow` (host), behind the disabled gate | **Refused while `enabled` is false**, on one line naming `/wg enable`. Otherwise: open the popup if `pendingInfo` is set, ending test mode first if it is on. Otherwise print a hint pointing at `/wg test`. |
| `/wg test` / `/wg test on\|off` / `/wg test notify` | `runTest(rest)` (host), behind the disabled gate | **Refused while `enabled` is false**, in all three forms; the panel's Test button is the surviving preview route. Otherwise: **Test mode.** Bare `/wg test` toggles the popup's test mode and `/wg test on\|off` sets it, by writing the `state.testMode` session row through `Helpers.Set`, the setter the Master controls **Test mode** checkbox uses. So the box follows, and a start in combat is refused by `startTestMode` with one gray line, `cannot start test mode during combat` (options-ui-§15). (The checkbox itself is refused in combat by the library's lock before this setter runs.) `/wg test notify` is the one-shot check: `WhatGroup:RunTest()` injects synthetic `pendingInfo` (Mythic+ Windrunner Spire) and runs `ShowNotification()` + `ShowFrame()` once, ending test mode if it is on. The panel's Test button runs the same method. Any other word prints a three-line usage. |
| `/wg config` | `runConfig` → `WhatGroup:OpenSettings` (host) → `Helpers.OpenOptionsPanel` (library) | Calls the idempotent `Settings.Register()` fallback, then hands off. The body sits on the addon rather than in a file-local because the launcher's **right click** opens the panel through the same one (launcher-§2). The combat refusal and the sidebar unfold both live inside `OpenOptionsPanel`, not in this dispatcher, so *every* caller is refused — the verb, a `/run` script, a future internal caller (options-ui-§2 / WG-25). Under `InCombatLockdown()` it prints the canonical gray notice *"cannot open settings during combat — Blizzard's category-switch is protected"* and returns; no defer-replay. Otherwise it opens the addon category and expands the subcategory tree so General — whose first tab is **Master controls** — is one click away. |
| `/wg enable` / `/wg disable` | `runEnabled(on)` (host) | The reserved pair (slash-commands-§2). **Aliases**, not a second switch: both write the `enabled` row — the Master controls *Enable WhatGroup* checkbox's own stored path — through the same `Helpers.Set`, so the row's `onChange` (the off-flip capture wipe) runs whichever surface the player used and the `[Set]` trace logs once. They hold no state of their own. The ack is the CLI's own `key = value` line, re-read from the store rather than echoed, and it is printed only for a write that landed: a refusal from the seam prints the seam's own words instead. `/wg set enabled true` is the same write by its long name. On a library-absent load there is no `enabled` row, and each verb prints `/wg enable is unavailable: the LibKa0s library did not load.` (or `/wg disable …`) and writes nothing — see *When the library is absent*. |
| `/wg version` | `Sl:CliVersion` (library) | Print `[WG] v<version>` on its own line (slash-commands-§3 / WG-29), through the host's `version` seam. |
| `/wg list` | `Sl:CliList` (library) | Green `Available settings` header, then rows grouped in **declaration order** under azure `[section]` headings — the descriptor's `groupKey` returns `row.section`, because these rows carry no `page` field the library's default would have read. Each row is `lib.FormatKV`: gold path, white value. |
| `/wg get <path>` | `Sl:CliGet` (library) | `findRow` (→ `Helpers.FindSchema`) then the same `FormatKV` echo, so `key = value` reads identically to `/wg list` and the `/wg set` echo. Number rows render through the row's `fmt` (e.g. `"%.1fs"` → `1.5s`). Prints `Setting not found: <path>` for unknown paths, and `Usage: /wg get <path>` for none. |
| `/wg set <path> <value>` | `Sl:CliSet` (library) | Type-aware parse (see the adapter below), then the descriptor's `set`, bound to the schema runtime's `Set` (`NS.SchemaRuntime`, `LibKa0s-Schema-1.0`) — the single write-path that refuses a path no row declares, writes the value, fires the row's `onChange` and refreshes panel widgets. A refusal is printed in the seam's own words, never as a success echo. The echo **re-reads** the stored value rather than repeating what was parsed, so a clamped number is visible. Usage line is `Usage: /wg set <path> <value>  (try /wg list)`. |
| `/wg reset <path>` | `runReset` (host) → `Sl:CliReset` (library) | Reset **one** row to its default via `Helpers.ApplyDefault`, no confirmation, and echo the restored value. A bare `/wg reset` prints the deprecation notice below instead. |
| `/wg resetall` | `runResetAll` (host) → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → `Helpers.RestoreAllDefaults()` | Show a confirm popup; on accept, `db:ResetProfile()` (which empties the profile in place, merges the defaults back and fires `OnProfileReset`), then restore the `sessionOnly` rows by hand, because a profile reset cannot reach storage that is not the db (options-ui-§12). The *Reset all settings* button on the **Master controls** tab is a third entry point onto the same body. With no `StaticPopup_Show` or `Settings.EnsureResetPopup` (headless) it calls `Helpers.RestoreAllDefaults()` directly, unconfirmed. Per-row `onChange` is skipped — the default baseline is already the reconciled state. The Defaults button in the General sub-page header (and Blizzard's own footer control, which the library forwards to it) shows the same popup, so all paths share one OnAccept body. |
| `/wg debug` / `/wg debug on\|off` | `runDebug` (host) | Bare `/wg debug` **toggles the on-screen debug console window** (`NS.DebugLog:Toggle()`), state untouched; `/wg debug on\|off` sets the session-only `NS.State.debug` flag through the single `NS.DebugLog:SetEnabled` seam (color-coded chat ack + `[Debug] logging enabled/disabled` console line). The FLAG is off on every login, never persisted, and **not** a schema row (WG-12), so there's no `/wg set debug`. The **Debug console** checkbox on the Master controls tab is *not* a second toggle for it — it is a `sessionOnly` schema row on the path `state.debugConsole` that shows/hides the console **window** only, routed to `NS.DebugLog`'s own get/set by `settings/Schema.lua`'s `SESSION` table so it never reaches `db.profile`. Debug output (`NS.Debug(tag, …)`) renders in the console, not chat — see [debug-content.md](./debug-content.md). |

`Helpers.RestoreAllDefaults` deliberately **overrides** the library member of the same name (`settings/OptionsSetup.lua:287-303`, [LIBKA0S-08](https://github.com/tusharsaxena/WhatGroup/issues/10)): the library's is row-by-row over every row, with no profile reset and no confirmation. The library's per-page `RestoreDefaults(pageKey, ctx)` is a different verb with a different arity and is untouched.

## The dispatcher survives the disabled state, and so does every reserved verb

`slash-commands-§2` requires it, and it is what stops `enable` / `disable` being a one-way switch:
a player who turned the addon off with a verb has to be able to turn it back on with one, or the
only route left is the settings panel they were trying not to open.

Nothing unregisters `/wg`, empties `COMMANDS` or tears the dispatcher down on the off-flip: the
chat commands are registered in `OnInitialize` and the settings category in `OnEnable`, and both
are **setup**, not features — they come up on load in either state and stay up. What the off-flip
*does* do is take the latch's `disabled` hold, which unregisters every event, cancels every timer
and takes the popup off screen ([the stand-down](./stand-down.md)). **The addon is
inert; its command surface is not the addon.**

**Every reserved verb answers while the addon is off** — `help`, `config`, `version`, `enable`,
`disable`, `debug`, `perf`, `get`, `set`, `list`, `reset`, `resetall` — and the bare `/wg` opens the
settings panel exactly as it does when the addon is running.

That sentence is a **ruling rather than a default**, and the round trip behind it is worth knowing.
The standard narrowed this surface to `enable` and `help` at **v2.56.0** and **reversed it at
v2.57.0**, the same day. What settled it was ordinary: `/wg` on a disabled addon answered with a
refusal instead of opening the panel — the one surface a player uses to switch it back on by hand.
A rule that hides the off switch has mistaken which half of the pair it protects. The reasoning for
the restored set is that a player must be able to **read and repair settings** and **reach the
panel** while the addon is off, which is exactly when they are likeliest to need to, and **`enable`
above all**. `debug` and `perf` are diagnostics rather than features: the usual reason to reach for
either is that the addon is misbehaving. `perf` is reserved-but-unregistered here
([LIBKA0S-15](https://github.com/tusharsaxena/WhatGroup/issues/7)), and a live verb with no
`COMMANDS` row still gets the one line rather than the index — it is a real verb, not a typo.

### ...and a feature verb refuses instead of acting

`slash-commands-§2`'s trailing SHOULD, which survived the reversal unchanged and is **the only
refusal in the disabled state**. A verb that **drives the addon's features** — anything that draws,
shows, tracks, tests or clears the thing the addon exists to do — answers on **one tagged line
naming `/wg enable`** and does **nothing else**: no partial work, no side effect, no second line.
Here that is **`show`** and **`test`**, in all of `test`'s forms.

`lock` and `unlock` are **not** among them. `slash-commands-§8` is a MAY; this addon's lock is a
**checkbox only** and it registers no verbs for it, which that section names explicitly as the case
the MAY exists to leave alone. Declining a MAY is not a deviation and owes no register row.

### The gate is the library's, not this file's

`settings/Slash.lua` used to name the live set itself (`ALWAYS_LIVE`) and wrap `entry[3]` for every
row that was not on it. Both moved into `LibKa0s-Slash-1.0` at **minor 13**. The host now passes two
descriptor fields and nothing else:

- **`isEnabled`** — a function, asked at **dispatch time** and never cached, so the command after an
  `enable` works. It asks the **latch** (`NS.IsStoodDown`) rather than `db.profile.enabled`, so the
  `perf` hold and the `disabled` hold give the CLI one answer between them.
- **`brandName`** — the plain-text `Ka0s WhatGroup`, the **same string** `core/LauncherSetup.lua`
  gives the LDB object as `label`. One brand spelling per addon, not a second one invented for a
  message.

`liveVerbs` is deliberately **not** passed: the library's default *is* the standard's twelve, and
passing a copy would be this addon's own opinion about which verbs a player may use on an addon they
have switched off — the opinion v2.57.0 settled.

Two consequences of where the gate now sits are worth naming, because both were wrong before:

- **The gate sits AFTER the `COMMANDS` lookup.** A verb this addon ships and is standing down from
  is refused; a **typo** gets `unknown command '<verb>'` and the index, because the addon genuinely
  did not understand and `slash-commands-§3`'s unknown-verb MUST is unqualified. Gating before the
  lookup answered a misspelling with "the addon is disabled" — a true sentence and the wrong answer.
- **`help` prints the refusal line immediately after its header, unindented, and then the whole
  index.** It is not a refusal *of* `help`: the player has to be able to **see** `enable` in the
  list. It is a statement about the index, some of whose rows are this addon's own feature verbs.

The wording lives in exactly one place — `lib.DISABLED_LINE_FORMAT`, built by `Sl:DisabledLine()` —
and **MUST NOT** be re-spelled host-side. The launcher's gate is `LibKa0s-Launcher-1.0`'s (minor 2):
`core/LauncherSetup.lua` hands it `isEnabled` and a `disabledLine` that returns this same member, so
the refused left-click prints the dispatcher's line rather than writing the sentence again. The one
host copy is the degraded Slash stub's `DISABLED_LINE_FORMAT` in `settings/Slash.lua`, a byte copy
for the path where there is no library to ask; the stub publishes it as `__disabledLineFormat` and
`tests/test_libka0s.lua` pins it to the library's bytes with `Kit.assertLibraryConstant`, while a
sibling case fails any other `is disabled` literal in `core/` or `settings/`.

**`/wg test notify` changed behavior with this.** It used to bypass the master switch deliberately,
so a preview still ran with the addon disabled, and `tests/test_lifecycle.lua` pinned that. `test`
is a feature verb by the amended rule, so the verb now refuses. The preview itself is not lost: the
**Test** button on the settings panel's Chat tab runs the same `WhatGroup:RunTest()` body, and it is
a panel control rather than a slash verb, so `slash-commands-§2` does not reach it — and a player
standing in the panel with the addon off is looking at the *Enable WhatGroup* checkbox from where
they clicked.

## `reset` takes a path; `resetall` is the wipe

This is a **breaking** change to a verb shipped since 1.0. `/wg reset` used to be the confirmation-gated wipe of every setting; it now resets one row by path. The collection's `reset` means "one setting" everywhere else, and a verb meaning "one row" in six addons and "everything" in the seventh is a trap the first time somebody types it in the wrong window.

The capability did not move — `/wg resetall` is the same wipe behind the same popup. A bare `/wg reset` prints a deprecation rather than the library's `Usage:` line, because the old form still parses as *something* and a usage line would tell the user their syntax is wrong rather than that the verb changed:

```
[WG] /wg reset now takes a setting PATH.
[WG]   To reset one setting: /wg reset <path> (try /wg list)
[WG]   To reset everything: /wg resetall, or the Defaults button on the settings page.
```

## The `toggle` parse adapter

`toggle` is this addon's own boolean grammar; the library's `parseBool` accepts `true/false/on/off/1/0/yes/no` and nothing else. `/wg set notify.showLeader toggle` is a shipped verb, so `settings/Slash.lua` passes a `parse` function — the sanctioned seam for exactly this (slash-commands-§6) — that handles `toggle` on `bool` rows by reading the current value and inverting it, and delegates everything else to `lib.ParseValue`. Clamping, enum validation and the error strings stay the library's.

`lib.ParseValue` is lib-level and stateless, so it answers with `lib.STRINGS.ERR_BOOL` literally and has no instance through which to see an override. The adapter maps that one message back through `Sl:Text("ERR_BOOL")`. The descriptor therefore carries a **plain** one-key table:

```lua
L = { ERR_BOOL = "expected true/false/on/off/1/0/toggle" },
```

Plain, never `NS.L`: the library resolves overrides with `rawget`, but a metatable that answers every key with the key itself would still supply a genuine string for `LIST_HEADER` and render the whole CLI as SCREAMING_SNAKE. One key is overridden because one message is wrong — the library's wording lists `yes/no` and omits the word the adapter actually accepts.

## When the library is absent

**The composed-row verbs say they are unavailable** (`options-ui-§1` route (b), the owner's ruling on [WhatGroup#22](https://github.com/tusharsaxena/WhatGroup/issues/22)). The rows `enable`, `disable` and `test` write — `enabled` and `state.testMode` — are composed by `LibKa0s-Options-1.0`, so a library-absent load has no row for them, and the schema seam (`settings/SchemaSetup.lua`'s stub) refuses a row-less path. No `writeThrough` list is passed, so `/wg enable`, `/wg disable`, `/wg test`, `/wg test on` and `/wg test off` each print `<verb> is unavailable: the LibKa0s library did not load.` (one `L` key, one placeholder) with no Lua error, no write and no ack. `/wg test notify` is unaffected. The deviation from route (a) is a row in [ARCHITECTURE.md](./ARCHITECTURE.md)'s `## Documented deviations`.

`/wg` is registered unconditionally, so something has to answer it. If `LibKa0s-Slash-1.0` is missing, `settings/Slash.lua` installs a small stand-in `Sl`: the host verbs never went to the library and keep working, dispatch and a plain help index still render, a bare `/wg` still runs the `config` row as the library's dispatcher does, and every schema verb (`list`, `get`, `set`, and `/wg reset <path>`) prints one honest line naming the missing library — `NS.LIBKA0S_MISSING` plus *"so the settings CLI is unavailable."* `/wg resetall` is host-owned and never delegated to `CliResetAll`, so it still confirms and wipes; it prints that line only when `Helpers.RestoreAllDefaults` itself is missing. Nothing in that branch re-implements a row formatter, the `key = value` shape or the parser (slash-commands-§1).

## Why `/wg test notify` and the Test button share `WhatGroup:RunTest()`

`WhatGroup:RunTest()` is a public method on the addon table — anything with a handle on `WhatGroup` can invoke it. The local `runTest(rest)` behind the COMMANDS row calls it for the `notify` sub-word.

This split exists because the Settings panel's Test button (rendered via `Helpers.InlineButton` from the `AFTER_GROUP` table in `settings/Panel.lua`) needs to invoke the same code path without going through slash dispatch:

```lua
Helpers.InlineButton(ctx, {
    text    = "Test",
    tooltip = "Inject synthetic group info and run the full notification + popup flow. …",
    onClick = function() if WhatGroup.RunTest then WhatGroup:RunTest() end end,
})
```

So `/wg test notify` and the panel button stay in lockstep with zero risk of drift.

## `/wg test` is the test mode

Every Ka0s addon's `/<slash> test` is its test mode, switched by the same state as the Master controls **Test mode** checkbox (options-ui-§15). Here that state is the `sessionOnly` schema row `state.testMode`, and `runTest` writes it through `Helpers.Set` (the schema runtime's `Set`) — bare toggles, `on|off` sets — so the verb and the checkbox cannot disagree: the box follows the verb, the verb gets the checkbox's combat refusal, and the `[Set]` trace logs either way. The schema CLI reaches the same row (`/wg set state.testMode on`, `/wg get state.testMode`) along the same path, not a second one. The one-shot flow the verb used to run lives on as `/wg test notify`.

## Adding a command

One row to `COMMANDS` in `settings/Slash.lua`. See [common-tasks.md](./common-tasks.md#add-a-slash-command) for the recipe.
