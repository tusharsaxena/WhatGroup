# Slash dispatch

`/wg` and `/whatgroup` are aliases for the same command set. The dispatcher, the help renderer, the schema CLI and the type-aware value parser are **LibKa0s-Slash-1.0**'s (`libs/LibKa0s/Slash.lua`). `settings/Slash.lua` — last in the TOC — supplies the descriptor, owns the `COMMANDS` table, and implements the verbs whose behavior is genuinely this addon's.

## Registration

Both names are registered through `AceConsole-3.0:RegisterChatCommand` in `OnInitialize` (`core/WhatGroup.lua:265`):

```lua
self:RegisterChatCommand("wg",        "OnSlashCommand")
self:RegisterChatCommand("whatgroup", "OnSlashCommand")
```

`WhatGroup:OnSlashCommand` (`settings/Slash.lua:421`) hands the raw input straight to `Sl:OnSlash`. The library deliberately registers no chat command of its own — AceConsole stays the single registrar, so every verb's output keeps flowing through the tagged printer (slash-commands-§1).

## Case-preserving parse

The dispatcher (`libs/LibKa0s/Slash.lua:657`) lowercases only the command name — the rest of the input is passed through untouched:

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
| `/wg test` / `/wg test on\|off` / `/wg test notify` | `runTest(rest)` (host), behind the disabled gate | **Refused while `enabled` is false**, in all three forms; the panel's Test button is the surviving preview route. Otherwise: **Test mode.** Bare `/wg test` toggles the popup's test mode and `/wg test on\|off` sets it, by writing the `state.testMode` session row through `Helpers.Set`, the setter the Master controls **Test mode** checkbox uses. So the box follows, and a start in combat is refused with the checkbox's one gray line (options-ui-§15). `/wg test notify` is the one-shot check: `WhatGroup:RunTest()` injects synthetic `pendingInfo` (Mythic+ Windrunner Spire) and runs `ShowNotification()` + `ShowFrame()` once, ending test mode if it is on. The panel's Test button runs the same method. Any other word prints a three-line usage. |
| `/wg config` | `runConfig` → `WhatGroup:OpenSettings` (host) → `Helpers.OpenOptionsPanel` (library) | Calls the idempotent `Settings.Register()` fallback, then hands off. The body sits on the addon rather than in a file-local because the launcher's **right click** opens the panel through the same one (launcher-§2). The combat refusal and the sidebar unfold both live inside `OpenOptionsPanel`, not in this dispatcher, so *every* caller is refused — the verb, a `/run` script, a future internal caller (options-ui-§2 / WG-25). Under `InCombatLockdown()` it prints the canonical gray notice *"cannot open settings during combat — Blizzard's category-switch is protected"* and returns; no defer-replay. Otherwise it opens the addon category and expands the subcategory tree so General — whose first tab is **Master controls** — is one click away. |
| `/wg enable` / `/wg disable` | `runEnabled(on)` (host) | The reserved pair (slash-commands-§2). **Aliases**, not a second switch: both write the `enabled` row — the Master controls *Enable WhatGroup* checkbox's own stored path — through the same `Helpers.Set`, so the row's `onChange` (the off-flip capture wipe) runs whichever surface the player used and the `[Set]` trace logs once. They hold no state of their own. The ack is the CLI's own `key = value` line, re-read from the store rather than echoed. `/wg set enabled true` is the same write by its long name. |
| `/wg version` | `Sl:CliVersion` (library) | Print `[WG] v<version>` on its own line (slash-commands-§3 / WG-29), through the host's `version` seam. |
| `/wg list` | `Sl:CliList` (library) | Green `Available settings` header, then rows grouped in **declaration order** under azure `[section]` headings — the descriptor's `groupKey` returns `row.section`, because these rows carry no `page` field the library's default would have read. Each row is `lib.FormatKV`: gold path, white value. |
| `/wg get <path>` | `Sl:CliGet` (library) | `findRow` (→ `Helpers.FindSchema`) then the same `FormatKV` echo, so `key = value` reads identically to `/wg list` and the `/wg set` echo. Number rows render through the row's `fmt` (e.g. `"%.1fs"` → `1.5s`). Prints `Setting not found: <path>` for unknown paths, and `Usage: /wg get <path>` for none. |
| `/wg set <path> <value>` | `Sl:CliSet` (library) | Type-aware parse (see the adapter below), then `Helpers.Set(path, value)` — the orchestrated single write-path that writes the value, fires the row's `onChange` and refreshes panel widgets. The echo **re-reads** the stored value rather than repeating what was parsed, so a clamped number is visible. Usage line is `Usage: /wg set <path> <value>  (try /wg list)`. |
| `/wg reset <path>` | `runReset` (host) → `Sl:CliReset` (library) | Reset **one** row to its default via `Helpers.ApplyDefault`, no confirmation, and echo the restored value. A bare `/wg reset` prints the deprecation notice below instead. |
| `/wg resetall` | `runResetAll` (host) → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → `Helpers.RestoreAllDefaults()` | Show a confirm popup; on accept, `db:ResetProfile()` (which empties the profile in place, merges the defaults back and fires `OnProfileReset`), then restore the `sessionOnly` rows by hand, because a profile reset cannot reach storage that is not the db (options-ui-§12). The *Reset all settings* button on the **Master controls** tab is a third entry point onto the same body. With no `StaticPopup_Show` or `Settings.EnsureResetPopup` (headless) it calls `Helpers.RestoreAllDefaults()` directly, unconfirmed. Per-row `onChange` is skipped — the default baseline is already the reconciled state. The Defaults button in the General sub-page header (and Blizzard's own footer control, which the library forwards to it) shows the same popup, so all paths share one OnAccept body. |
| `/wg debug` / `/wg debug on\|off` | `runDebug` (host) | Bare `/wg debug` **toggles the on-screen debug console window** (`NS.DebugLog:Toggle()`), state untouched; `/wg debug on\|off` sets the session-only `NS.State.debug` flag through the single `NS.DebugLog:SetEnabled` seam (color-coded chat ack + `[Debug] logging enabled/disabled` console line). The FLAG is off on every login, never persisted, and **not** a schema row (WG-12), so there's no `/wg set debug`. The **Debug console** checkbox on the Master controls tab is *not* a second toggle for it — it is a `sessionOnly` schema row on the path `state.debugConsole` that shows/hides the console **window** only, routed to `NS.DebugLog`'s own get/set by `settings/Schema.lua`'s `SESSION` table so it never reaches `db.profile`. Debug output (`NS.Debug(tag, …)`) renders in the console, not chat — see [debug.md](./debug.md). |

`Helpers.RestoreAllDefaults` deliberately **overrides** the library member of the same name (`settings/OptionsSetup.lua:287-300`, [LIBKA0S-08](https://github.com/tusharsaxena/WhatGroup/issues/10)): the library's is row-by-row over every row, with no profile reset and no confirmation. The library's per-page `RestoreDefaults(pageKey, ctx)` is a different verb with a different arity and is untouched.

## The dispatcher survives the disabled state

`slash-commands-§2` requires it, and it is what stops `enable` / `disable` being a one-way switch:
a player who turned the addon off with a verb has to be able to turn it back on with one, or the
only route left is the settings panel they were trying not to open.

It holds here **because the master switch is read in exactly two places** —
`core/WhatGroup.lua`'s `OnApplyToGroup` and the `inviteaccepted` arm of the status handler — and
nowhere else. Nothing unregisters `/wg`, empties `COMMANDS` or tears the dispatcher down on the
off-flip: the chat commands are registered in `OnInitialize` and the settings category in
`OnEnable`, both of which are **setup**, not features. So `/wg`, `help`, `config`, `version` and
`enable` all answer exactly as before while the addon is off. `tests/test_slash.lua` pins that
rather than leaving it to inspection.

### ...and a feature verb refuses instead of acting

`slash-commands-§2`'s trailing SHOULD, made precise in standard **v2.54.0**, and this addon takes
it. A verb that **drives the addon's features** — anything that draws, shows, tracks, tests or
clears the thing the addon exists to do — answers on **one tagged line naming `/wg enable`** and
does **nothing else**: no partial work, no side effect, no second line. Here that is **`show`** and
**`test`**, in all of `test`'s forms.

**The live set never refuses**, and it is the standard's list rather than this addon's judgement of
what felt safe: `help`, `config`, `version`, `enable`, `disable`, `debug` and the schema CLI (`get`,
`set`, `list`, `reset`, `resetall`). `perf` is on the list too, and is reserved-but-unregistered
here ([LIBKA0S-15](https://github.com/tusharsaxena/WhatGroup/issues/7)); keeping the entry is what
makes the set read as the rule rather than as a subset of it. The reasoning is that a player has to
be able to **read and repair settings** and **reach the panel** while the addon is off — which is
exactly when they are likeliest to need to — and **`enable` above all**, or the pair above is
one-way again. `debug` is a diagnostic, not a feature: the usual reason to reach for it is that the
addon is misbehaving.

**It is implemented in ONE place — the dispatcher — and never as a guard inside each verb.**
`settings/Slash.lua` names the live set once, as data (`ALWAYS_LIVE`), and wraps `entry[3]` for
every row that is not on it, immediately after the `COMMANDS` literal. That is the seam every verb
already passes through: the library's dispatcher and the no-LibKa0s stub both call the handler out
of this table and neither has another way in, so both paths are gated by one wrapper and **a verb
added tomorrow is gated by default**. A guard pasted into `runShow` and `runTest` would be two
places to forget and a third the next verb forgets silently. The wrap touches handlers only, so the
help index and the panel's landing page — which read `entry[1]` and `entry[2]` — still list the
refused verbs, which is how the player finds out the addon has them.

The check **fails open**: only a stored `enabled == false` refuses. A nil — no db yet, no `Helpers`
yet, a path the profile has never held — is not the player having turned the addon off, and reading
it as one would refuse every feature verb on an install that is merely early or degraded.

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

Every Ka0s addon's `/<slash> test` is its test mode, switched by the same state as the Master controls **Test mode** checkbox (options-ui-§15). Here that state is the `sessionOnly` schema row `state.testMode`, and `runTest` writes it through `Helpers.Set` — bare toggles, `on|off` sets — so the verb and the checkbox cannot disagree: the box follows the verb, the verb gets the checkbox's combat refusal, and the `[Set]` trace logs either way. The schema CLI reaches the same row (`/wg set state.testMode on`, `/wg get state.testMode`) along the same path, not a second one. The one-shot flow the verb used to run lives on as `/wg test notify`.

## Adding a command

One row to `COMMANDS` in `settings/Slash.lua`. See [common-tasks.md](./common-tasks.md#add-a-slash-command) for the recipe.
