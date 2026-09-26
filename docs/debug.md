# Debug surfaces

WhatGroup has two debug surfaces, and both write into the same window:

- **The debug console** is `LibKa0s-DebugLog-1.0`'s window. Tagged `NS.Debug` lines land there while
  the session flag is on. What WhatGroup feeds it (the descriptor, the tags, the flag, `/wg debug`) is
  [debug-content.md](./debug-content.md).
- **The diagnostics report** is a one-shot snapshot of the addon's state, written into the console by
  `/wg diagnostics` (`debug-logging-§14`). It is why this page exists (`documentation-§3`, Tier 2):
  every Ka0s addon ships the report, and a maintainer reading a pasted one needs to know what each
  line means.

The console and the report frame are the library's, and their contract lives in LibKa0s's
[`docs/api/DebugLog/version-14.1-docs.md`](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/api/DebugLog/version-14.1-docs.md)
(DebugLog minor 14 with its `DebugLogDiagnostics.lua` secondary file, vendored from LibKa0s v1.60.0).
This page covers only what WhatGroup adds on top.

## The console in one table

| Command | Effect |
|---|---|
| `/wg debug` | Shows or hides the console window, "Ka0s WhatGroup — Debug". The logging flag is unchanged. |
| `/wg debug on` / `off` | Sets or clears the session-only `NS.State.debug` flag through `NS.DebugLog:SetEnabled`, which confirms on one color-coded chat line. |
| `/wg debug diagnostics` | Writes the diagnostics report (below). |
| `/wg debug <anything else>` | Prints the three-line `debug` usage. |

The buffer is the library's **3000 lines** (`lib.MAX_BUFFER`). The footer counter reads
`N / 3000 lines` and pins there, and Copy pastes out of the same buffer, so a long capture keeps only
its newest 3000 lines.

## The diagnostics report

### Running it

There are exactly two forms, and no third:

- `/wg diagnostics`, a row of the `COMMANDS` table in `settings/Slash.lua`;
- `/wg debug diagnostics`, the first word `runDebug` tests, in any case.

`/whatgroup` reaches both, as it reaches every verb. `diag`, `dump`, `dx` and every other short name
are ordinary unknown words: `/wg diag` prints `unknown command 'diag'` and the help index, and
`/wg debug diag` prints the three-line `debug` usage.

`diagnostics` is on the library's live set (`lib.LIVE_VERBS`, Slash minor 16), so both forms answer
while the addon is **disabled**. A disabled addon is stood down, and the report says so (the
identity section's `stoodDown=true` and the capture section's one `stood down` line) rather than
printing emptied tables as if they were data.

### What it does to the console

- **It appends.** The report lands after whatever the console already holds, so the trace a player
  has just reproduced stays above it and one Copy carries both. Nothing the report reaches calls
  `Clear()`.
- **It is ungated.** It writes through the library's raw append, not `NS.Debug`, so it lands in full
  with logging off, and it does not change the flag: the header reads the same afterwards.
- **It reveals the console** if it is hidden, then prints one chat line through `NS.L`:
  `Diagnostic report written to the debug console: N lines. Use Copy to share it.`
- **It is plain text.** The library strips color, texture, atlas and hyperlink escapes from every
  line, so the Copy text reads cleanly.

The report body is English diagnostic text and does not go through `NS.L`, like every trace line.
The chat line is the one localized string, handed to the library in the descriptor's plain `L` table
(see [debug-content.md](./debug-content.md#what-the-descriptor-supplies)).

### What it prints

The library writes the frame: the begin marker, the identity header, each section under its own
`pcall`, the cap and the end marker. `modules/Diagnostics.lua` writes the sections in between, in this
order. Every line is tagged `[Diag]` except the settings rows, which carry `[Set]`.

| Section | What it reports |
|---|---|
| (begin) | `==== Ka0s WhatGroup diagnostics begin ====` |
| (library header) | The `[Init]` summary (`WhatGroup v<version>, schema v<n>, profile '<name>'` plus the runtime state and any rejected events); the client's version, build, date and interface from `GetBuildInfo()`; the locale; the logging flag; `InCombatLockdown` and `UnitAffectingCombat("player")`; the **running** LibKa0s minors, file by file, which under LibStub may come from another addon's vendored copy |
| identity | The stored and code schema versions; the profile; the stored `enabled` switch beside `stoodDown` (the latch); the Lifecycle holds; whether test mode is on |
| settings | Every schema row that differs from its default, as `path = value (default)`. `enabled`, `notify.enabled` and `frame.autoShow` always print, whatever their value, because they are the three switches a "nothing happened" report turns on. The session-only rows (`state.debugConsole`, `state.testMode`) are skipped |
| registration | The four feature events (`GROUP_ROSTER_UPDATE`, `LFG_LIST_APPLICATION_STATUS_UPDATED`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`), each `=yes`, `=no` or `=unknown`, read from AceEvent's own registry; the chat-link route (`EventRegistry addon link`, or `SetItemRef post-hook (degraded client)`); the events this client refused to register |
| group | `inGroup`, `inRaid` and the member count, each read under `pcall` |
| capture | The client's own applications as `C_LFGList` holds them, `id=status`, beside what the addon captured: `capturesByResult` and `pendingApplications` as `key=title`, keys sorted so two reports diff cleanly. Then `wasInGroup` and whether the join notice already fired for the current group. Stood down, the section is one line: `capture: stood down, runtime state released` |
| pending | The captured group the popup would show: title, leader, voice chat, activity id, map id and full name, or `pending: none`. Then whether the notify timer is armed and its time left, and whether the first popup build is queued behind combat |
| teleport | For the pending group: the resolved Path-of spell id, whether it is known, and whether `TeleportSpells` has an entry. The cooldown prints as its raw `start` and `duration` when both are readable numbers, and as `teleport cooldown unreadable` otherwise. With no pending group: `teleport: no pending group` |
| popup | `popup: not built` until the first show. Once built: shown, on screen, soft-hidden, a pending hide, whether the visibility gate is withholding it, test mode, a deferred teleport configure, the cooldown ticker, the ESC proxy, and the combat-end queue. Then the saved point from `db.global.windows.popup` beside the live one |
| launcher | Whether the minimap launcher is registered and shown |
| (end) | `==== Ka0s WhatGroup diagnostics end: N line(s) ====`, with `N` counting both markers |

A section that raises costs one line, `section <name> failed: <err>`, and the rest of the report still
lands. On an install where `modules/Diagnostics.lua` failed to load, the descriptor's `diagnostics`
callback answers an empty list, and the report is the markers and the library header around no
sections.

### Caps

- **The whole report** stops at `lib.DIAG_MAX_LINES` (1200), which the library clamps to
  `lib.MAX_BUFFER - 100`, so the report never pushes itself out of the 3000-line buffer. The trace
  above it is kept on a best-effort basis. WhatGroup's own sections come to a few dozen lines.
- **Each list** (client applications, the two capture tables, rejected events) prints at most
  `lib.DIAG_MAX_PER_LIST` (40) entries and then `(+N more)`. The joined lines (the event
  registrations, the holds, the popup points and combat-end queue) are short fixed sets and carry
  no cap. A list or joined line wraps at 200 characters onto indented continuation lines; every
  other line prints whole, however long (a long group title, for one).
- A capped report ends with `truncated: N line(s) omitted, per-list caps hit=yes|no`, then the end
  marker.

### What it does not do

- **It writes nothing.** No Lifecycle hold taken or released, no event registered, no timer armed, no
  SavedVariables write. A report that repaired the state would describe a state the player is not in.
  The file-local capture tables and the popup's file-locals arrive through two read-only accessors,
  `WhatGroup:CaptureSnapshot()` (`core/WhatGroup.lua`) and `NS.FrameSnapshot()`
  (`modules/Frame.lua`), which hand out copies.
- **It never builds the popup and never touches the teleport button.** The popup parents a
  `SecureActionButtonTemplate` button, and building it is a secure write the report has no business
  doing, least of all in combat. An unbuilt popup answers `built = false` and the section says
  `not built`.
- **It calls no protected API**, so it is safe in combat.
- **It does no arithmetic on a value that may be secret.** Every value goes through
  `NS.SafeToString` before a format sees it, so a secret prints as `<secret>`, and the lines are
  `%s`-only. The teleport cooldown is the one number the addon would compute on:
  `Compat.GetSpellCooldownRemaining` subtracts, so the report does not call it, and reads the raw pair
  through `Compat.GetSpellCooldownTimes` behind `out:readable` instead.
- **Nothing is redacted.** Players send the report to the maintainer privately, so it prints what a
  maintainer needs to reproduce the bug, group titles and leader names included.

With no LibKa0s the stub's `RunDiagnostics` prints
`/wg diagnostics is unavailable: the LibKa0s library did not load.`, writes nothing and returns 0.

### Adding a section

Write a `local function name(out)` in `modules/Diagnostics.lua` and add `{ "name", name }` to
`NS.Diagnostics.Sections()` in the position it should print. Use the writer's own methods
(`out:add`, `out:list`, `out:joined`, `out:readable`, `out:nonDefaults`), pass raw values, and read
state only: anything file-local elsewhere gets a read-only accessor that returns a copy. Add its row
to the table above in the same change, and a case to `tests/test_diagnostics.lua`.

## Where else this is pinned

The command rows are in [slash-dispatch.md](./slash-dispatch.md), and the player-facing steps are the
README's `## Reporting a bug`. The in-game checks are section 2a and row 2.8b-ii of
[smoke-tests.md](./smoke-tests.md). The suites are `tests/test_diagnostics.lua` (this addon's
sections), the kit's shared `tests/_kit/test_diagnostics_contract.lua` (wired in `tests/run.lua`),
`tests/test_disabled.lua` (both forms while disabled) and `tests/test_slash.lua` (the usage line and
`debug diag`).
