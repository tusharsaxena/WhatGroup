# Debug content

The on-screen debug console is **LibKa0s-DebugLog-1.0**, wired by `core/DebugLogSetup.lua` from a
descriptor. The window, the line format, the buffer, the scrollbar and line counter, the copy and
clear controls, the enable seam and the diagnostics report's frame are all the library's, and the
library documents them once: LibKa0s `docs/api/DebugLog/` (major `LibKa0s-DebugLog-1.0`, minor 14 with
its `DebugLogDiagnostics.lua` secondary file at the vendored v1.60.0, documented as version 14.1). This
page does not restate any of it.

What this page holds is the part only WhatGroup knows: what the descriptor hands the library, the
tags this addon logs under, where the session flag lives, what `/wg debug` does, and how to add a
line. It is a Tier 3 doc (see `ARCHITECTURE.md` → `## Documentation map`). The diagnostics report
(`/wg diagnostics`, `debug-logging-§14`) is a debug surface beyond the console, so the Tier 2
[debug.md](./debug.md) now ships beside this page and documents the report: its two forms, what it
prints section by section, its caps and what it never does.

## What the descriptor supplies

`core/DebugLogSetup.lua` hands `lib:New` only what the library cannot know:

- `name = addonName` — seeds the frame globals `WhatGroupDebugWindow`,
  `WhatGroupDebugCopyWindow`, `WhatGroupDebugCopyScroll`, the names `/framestack` and any Esc-close
  muscle memory expect.
- `title = "Ka0s WhatGroup"` — the bare brand; the library appends its own `" — Debug"`.
- `font = resolveConsoleFont(NS.FONT_MONO)` — `NS.FONT_MONO` is the library payload's JetBrains Mono,
  resolved through `core/MediaSetup.lua`'s `NS.MediaFont` seam. The path is **probed** once at load
  (`CreateFont("WhatGroupFontProbe"):SetFont(path, 10, "")`) and `Fonts\ARIALN.TTF` is passed instead
  when the probe fails (debug-logging-§2's fetch-failure fallback). `SetFont` answers `false` on a file
  it cannot load and raises nothing, so without the probe a packager that dropped the library's
  `media/` would give a proportional console with nothing in the error log to say why. The probe
  resolves at load because the library validates `descriptor.font` as a string at `:New` time.
- `slash = "/wg"` — only composes the console checkbox's tooltip.
- `addonName = addonName` — passed **beside** `name`, not instead of it. `name` seeds frame globals;
  `addonName` is what the library builds a **texture path** from, so its close, clear and copy
  controls draw the collection's marks rather than a multiplication sign and the words `Clear` and
  `Copy`. A wrong value draws nothing and raises nothing.
- `isEnabled` / `setEnabled` — the flag **stays this addon's** (`NS.State.debug`); see below.
- `print` / `safeToString` — thin **call-time** forwarders to `NS.Print` / `NS.SafeToString`
  (`NS.SafeToString` is published by `core/CoreSetup.lua`; `NS.Print` is `core/WhatGroup.lua`'s
  reclaim of the printer CoreSetup publishes as `NS.Util.print`, which AceConsole's `:Print` mixin
  would otherwise clobber). Never captured references, so a later re-publish is honored.
- `initSummary` — `WhatGroup:InitSummary()`. The library owns *when* the `[Init]` line is written
  (on enable, right after the `[Debug] logging enabled` bracket); only the addon knows what it says.
- `onVisibilityChanged` — calls `Settings.Helpers.RefreshAll()` so the Master controls tab's console
  checkbox re-syncs when the window is closed with Esc or the `×`.
- `brandName = "Ka0s WhatGroup"` — the full brand the diagnostics report's begin and end markers
  carry, so a paste holding several addons' reports can be split.
- `diagnostics` — a function that answers `NS.Diagnostics.Sections()`, read at **run** time, because
  `modules/Diagnostics.lua` loads after this file. Its sections are [debug.md](./debug.md)'s subject.
- `L` — a **plain** table holding one key, `DIAG_WRITTEN`, the report's chat line resolved through
  `NS.L`. It is the one console string a player reads in chat, so it is the one this addon routes.
  Never `NS.L` itself: its metatable answers every key with the key, and the console would render
  `DEBUG_ON` in place of English. The library reads the table with `rawget`, so every other key keeps
  the library's English.

Deliberately **not** passed: `skin` / `applySkin` / `makeCloseButton`, because the library's own
default is the normative Ka0s window edge.

**TOC slot: after `core/WhatGroup.lua`.** The library validates `name`, `title`, `font`, `isEnabled`
and `setEnabled` at `:New` time, and both `NS.FONT_MONO` and `NS.State.debug` are defined in
`core/WhatGroup.lua`. Nothing calls `NS.Debug` at file load.

What `core/DebugLogSetup.lua` publishes: **`NS.Debug(tag, fmt, ...)`**, bound **bare** from the
library's `D.Debug` so every call site passes its tag first, and **`NS.DebugLog`**, the library
instance. Their contracts (gating, zero allocation when off, secret-safe formatting, the members of
the instance) are the library's document, not this page.

## The `[Init]` line

`WhatGroup:InitSummary()` (in `core/WhatGroup.lua`) is a pure builder. It returns the identity fields
the standard requires first, `WhatGroup v<version>, schema v<schemaVersion>, profile '<profile>'`, then
the runtime state `(enabled=…, notify.delay=…s, autoShow=…, inGroup=…, hasPending=…)` on the same line
(debug-logging-§5). When `registerFeatureEvents` refused an event name, the line ends
`, rejected events: <names>`, read from the session-only `NS.RejectedEvents` that
`NS.SafeRegisterEvent` fills (WG-06). That clause is the only record of a refused name; nothing is
printed to chat. It is absent when every name registered.

## Tag vocabulary

Each console line carries its tag in brackets; the tag is the first argument at the call site.

- **Lifecycle** — `Init` (the summary above), `Migrate` (only when `RunMigrations` actually moves the
  version, `core/Database.lua`).
- **Capture flow** (`core/WhatGroup.lua`) — `Apply` (one merged line per apply:
  `id=… captured "…" (activity=… map=… m+=…)`), `Capture` (no-op / wipe decisions), `LFG` (status
  events), `Invite` (accepted, with the winning `source=fresh|queued`), `Roster` (in-group transitions
  only), `Notify` (`scheduling` / `fired` / `canceled` / skip), `ChatLink`, `Test`.
- **Frame** (`modules/Frame.lua`) — `Frame` (`popup shown …`, `teleport spellID=… known=…`, the
  teleport button press) and `Test`.
- **Settings** — `Set`, the tag every settings line carries (debug-logging-§10):
  - `[Set] <path> = <value>` — the one canonical settings-change line, written by
    `LibKa0s-Schema-1.0`'s write seam through the `debug` forwarder `settings/Schema.lua` passes it. A
    single-row `/wg reset <path>` lands here too.
  - `[Set] reset profile '<name>' to defaults (N rows)` — the whole-profile reset (`/wg resetall` and
    the panel's Defaults button), logged once by the `OnProfileReset` handler in `core/WhatGroup.lua`.
    N is the rows the reset changed. A reset driven straight at the db logs the line without a count.
  - `[Set] copied profile '<A>' → '<B>'` — a profile copy, logged once by `OnProfileCopied`.
  - `[Set] reset <scope>: N rows` — the bulk bracket's one line around the library's reset walks.
    N is the rows whose stored value changed.

  A bulk act that ends in an error still logs its one line, with ` (stopped by an error)` appended.
- **Library lines through this addon's sink** — `Cfg` (`LibKa0s-Options-1.0`: the settings category
  parked in combat, opened, or refused in combat) and `Launcher` (`LibKa0s-Launcher-1.0`), both
  reaching the console through the `debug` forwarders `settings/OptionsSetup.lua` and
  `core/LauncherSetup.lua` pass.
- **Console** — `Debug` (the enable/disable bracket lines, written by the library).

The set is otherwise open; add a tag as needed. The content rules the addon follows are **coverage**
of the main flows (debug-logging-§8), **coalescing** to one summary line per pass (debug-logging-§9),
and **one `[Set]` line per settings change at the single seam** (debug-logging-§10).

## The enabled flag is this addon's

`NS.State.debug` is a **runtime flag independent of the window's visibility**:

- **Session-only**: default off, never in SavedVariables, reset to off on every `/reload` and login.
  It is **not** a schema row (WG-12), so there is no `/wg set debug`.
- The **window's visibility** is one, on the Master controls tab: `options-ui-§15` makes "Debug
  console" one of the canonical nine, so it is a `sessionOnly` schema row on the path
  `state.debugConsole`. `settings/Schema.lua`'s `SESSION` table binds that row to
  `D:ConsoleCheckbox()`'s own `get`/`set`, so nothing about it reaches `db.profile`. `BuildDefaults`
  skips the row; `RestoreAllDefaults` sweeps it by hand (`options-ui-§12`).
- Logging and the window are independent, so a bug can be reproduced first and the log opened after.
- The slash verb and the header toggle both write the flag through the library's one `SetEnabled`
  seam, which calls back into the descriptor's `setEnabled` (debug-logging-§5).

## Slash semantics (`/wg debug`)

Handled by `runDebug` in `settings/Slash.lua`:

- `/wg debug diagnostics` — writes the diagnostics report (`D:RunDiagnostics()`). Tested **first**,
  in any case; see [debug.md](./debug.md).
- `/wg debug` — **toggles the console window** (`D:Toggle()`); logging state untouched.
- `/wg debug on` / `/wg debug off` — set the session flag through `D:SetEnabled`.
- Any other word — the three-line usage. `diag` is such a word: no short name runs the report.

See [slash-dispatch.md](./slash-dispatch.md) for the dispatch table.

## When the library is missing

`core/DebugLogSetup.lua` degrades rather than errors. The stub answers **every** member the addon
calls, and the **flag still works**: `NS.State.debug` is this addon's, so `/wg debug on` still moves it
and still prints the color-coded ack. What is lost is the window, and the stub says so once per entry
point: enabling, asking for the window, and asking for the copy box each spend their own announce
token, phrased as `NS.LIBKA0S_MISSING` plus the consequence. `ConsoleCheckbox()` still answers a
well-formed spec whose tooltip carries the same sentence.

The stub's `RunDiagnostics` prints `/wg diagnostics is unavailable: the LibKa0s library did not
load.` on the collection's library-absent line, writes nothing and returns 0.

The stub copies **no** formatter. Nothing in the addon calls them outside the library's own `Add`,
and hand-transcribing them is the duplicate debug-logging-§3 and testing-§8 forbid.

## Adding a debug line

Call the sink with a tag, a format and raw values. Format args are applied only when debug is on, so
string-building stays behind the gate (debug-logging-§4, debug-logging-§9):

```lua
NS.Debug("Apply", 'id=%s captured "%s" (map=%s)', id, title, mapID)
```

No guard at the call site: `NS.Debug` self-gates on `NS.State.debug`. Cover the main flows, coalesce
repeating paths to one summary line per pass, and log each settings change once at the write seam.

## Tests

`tests/test_debuglog.lua` covers the addon's side: the `NS.FONT_MONO` constant and both branches of
the font probe (through the mock's `fontFetchFails` table), the window-vs-flag `/wg debug` semantics,
the `[Init]` summary's content and position, the zero-write-when-off contract, the `%d`-with-a-secret
path, and the one-`[Set]`-per-change and one-`[Set]`-per-bulk-reset content rules.

`tests/test_libka0s.lua` covers the seam: `NS.DebugLog` is the library's instance and `NS.Debug` is
bound bare, the frame globals and the composed window title are unchanged, the flag stays the
addon's, `[Init]` is reached through the descriptor, and the degraded stub answers every member while
copying no formatter.

The diagnostics report's cases are listed in [debug.md](./debug.md#where-else-this-is-pinned).

The in-game scrollbar and counter checks are [smoke-tests.md](./smoke-tests.md) rows 2.8b-i and
2.8b-ii (the counter pinning at 3000).
