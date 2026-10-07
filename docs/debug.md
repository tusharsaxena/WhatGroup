# Debug surfaces

WhatGroup has two debug surfaces, and both write into the same window:

- **The debug console** is `LibKa0s-DebugLog-1.0`'s window. Tagged `NS.Debug` lines land there while
  the session flag is on. What WhatGroup feeds it (the descriptor, the tags, the flag, `/wg debug`) is
  [debug-content.md](./debug-content.md).
- **The diagnostics report** is a one-shot snapshot of the addon's state, written into the console by
  `/wg diagnostics` (`debug-logging-§14`). It is why this page exists (`documentation-§3`, Tier 2):
  every Ka0s addon ships the report, and a maintainer reading a pasted one needs to know what each
  line means.
- **The coverage map** ([Coverage](#coverage), below) is the trace's other half: every tag the
  console carries, what writes it and when, and which repeating paths stay quiet on purpose.

The console and the report frame are the library's, and their contract lives in LibKa0s's
[`docs/api/DebugLog/version-19.2.1-docs.md`](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/api/DebugLog/version-19.2.1-docs.md)
(DebugLog minor 19 with its `DebugLogDiagnostics.lua` secondary file at minor 2 and its
`DebugLogGates.lua` secondary file at minor 1, as vendored from the LibKa0s tag on the
[`CLAUDE.md`](../CLAUDE.md) provenance line: the resizable
console, the title bar's Diagnostics link, a report run that turns logging on for the session, and
the change gates and at-enable queue).
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

There are exactly two typed forms, and no third:

- `/wg diagnostics`, a row of the `COMMANDS` table in `settings/Slash.lua`;
- `/wg debug diagnostics`, the first word `runDebug` tests, in any case.

`/whatgroup` reaches both, as it reaches every verb. `diag`, `dump`, `dx` and every other short name
are ordinary unknown words: `/wg diag` prints `unknown command 'diag'` and the help index, and
`/wg debug diag` prints the three-line `debug` usage.

The console's title bar also carries the library's orange **Diagnostics** link, just right of the
`Debug: ON`/`OFF` toggle with a small gap, in the same plain text (DebugLog 17). A click runs the same
report, `NS.DebugLog:RunDiagnostics()`.

Running the report, by either form or the link, **turns debug logging on for the session**
(debug-logging-§14, DebugLogDiagnostics 2), as `/wg debug on` would; a `/reload` turns it off again.

`diagnostics` is on the library's live set (`lib.LIVE_VERBS`, Slash minor 16), so both forms answer
while the addon is **disabled**. A disabled addon is stood down, and the report says so (the
identity section's `stoodDown=true` and the capture section's one `stood down` line) rather than
printing emptied tables as if they were data.

### What it does to the console

- **It appends.** The report lands after whatever the console already holds, so the trace a player
  has just reproduced stays above it and one Copy carries both. Nothing the report reaches calls
  `Clear()`.
- **It turns logging on first.** When logging is off, the run sets it through the one seam
  (`NS.DebugLog:SetEnabled(true)`) before it writes, so the `debug logging ON` chat line, the
  `[Debug] logging enabled` line and the `[Init]` summary land just ahead of the begin marker, and the
  header reads `debug logging: on`. It never turns logging off, and with logging already on it writes no second
  enable line. WhatGroup keeps the library's default: its descriptor does not set
  `diagnosticsEnablesLogging = false`. The sections themselves read state only and never touch the
  flag. A report run first leaves logging on, so what the player does next is traced too.
- **It is ungated.** It writes through the library's raw append, not `NS.Debug`, so every line lands
  in full whatever the gate would say.
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
| capture | The client's own applications as `C_LFGList` holds them, `id=status role=<role>` (the role is `GetApplicationInfo`'s 5th return, printed raw so its position can be checked in game, WhatGroup#1), beside what the addon captured: `capturesByResult` and `pendingApplications` as `key=title`, keys sorted so two reports diff cleanly. Then `wasInGroup` and whether the join notice already fired for the current group. Stood down, the section is one line: `capture: stood down, runtime state released` |
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

## Coverage

What the gated trace carries, tag by tag: which code writes each line and when it lands. This is the
map `debug-logging-§8` (the flows and the diagnosis checklist) and `debug-logging-§9` (one line per
pass, and none when nothing changed) are checked against. Every line is one gated call with its
formatting behind the gate: `NS.Debug`, the console's change gate (`D.DebugOnce` / `D.DebugChanged`)
or its at-enable queue (`D.DebugAtEnable`). **Whose line it is** is the second column: a row that
names the library is written by a LibKa0s module through the `debug` sink its descriptor is passed
(LibKa0s v1.65.0), and this addon writes no copy of it (debug-logging-§8); `Debug`, `Init`, `Cmd`,
`Lifecycle`, the library half of `Cfg`, `Launcher` and the `[Set] <path> = <value>` line are the
library's, every other tag is this addon's. The diagnostics report above is not part of the trace: it is
ungated and runs only when asked (a run turns the trace on for the session, as above).

| Tag | Written by | When |
|---|---|---|
| `Debug` | the library | The `logging enabled` / `logging disabled` bracket, at each flip of the flag. |
| `Init` | the library, from `WhatGroup:InitSummary()` | Once per enable, after the bracket: identity, runtime state, then `rejected events: …` when a registration was refused and `link route: SetItemRef post-hook (degraded client)` on a client without Blizzard's addon link type. Both clauses are absent otherwise. This is where the dependencies are logged, because the flag is off at login. |
| `Migrate` | `core/Database.lua`, through the at-enable queue | `vX -> vY`, only when a migration actually moves the version. The login run is at `OnInitialize`, with logging off, so it is held and written the first time logging is turned on, after `[Init]`; a run with logging on (a profile switch) writes at once. |
| `Lifecycle` | the library's Lifecycle major, through `core/LifecycleSetup.lua`'s `debug` | `stood down: added <key> (holds: <set>)` on the latch's down edge, before the stand-down runs, so the teardown lines below it read as its consequences; `stood up: released <key> (holds: none)` on the up edge. Once per edge; a hold that does not move the latch writes nothing. This addon wrote its own `[State]` pair until LibKa0s v1.65.0 and no longer does. |
| `Cmd` | the library's Slash major, through `settings/Slash.lua`'s `debug` | `refused <verb>[ <arg>]: <guard>`, once per refusal the dispatcher decides, after its chat line: `disabled` (a feature verb while the addon is off), `unknown verb`, `usage` / `not found` for `get` / `set` / `reset`, `parse (…)` / `write refused (…)` for `set`, `no default` for `reset`, and `unavailable` / `already current` / `in combat` / `unknown profile` for `profile`. The refusals this addon's own verbs decide keep their own tags (`Frame`, `Set`). |
| `Apply` | the `ApplyToGroup` post-hook | `id=… captured "…" (activity=… map=… m+=…)` per apply; `ignored id=…: addon stood down` for an apply while disabled (the hook cannot be unregistered). |
| `Capture` | `core/WhatGroup.lua` | `GetSearchResultInfo returned nil for id=…` (the capture that never happened); `GetApplicationInfo gave no id …` per status event; `GetApplicationInfo raised (falling back to appID): <err>` once per distinct error; `GetApplicationInfo unavailable: falling back to appID` once (both through `NS.DebugErrorOnce`, the console's `D.DebugOnce`, so a Clear or turning logging on re-arms them); `wiped (<reason>)` when a reasoned wipe had something in flight. |
| `LFG` | the status event | `appID=… status=…` per event; `appID=… applied: nothing captured under result id=… to pair`; `dropped the capture for appID=… (<status>)`. |
| `Invite` | the `inviteaccepted` arm | `accepted appID=… → "<title>" map=… (source=fresh\|queued)` or `→ no capture`; `ignored appID=…: addon stood down` for a direct call while disabled. |
| `Roster` | `GROUP_ROSTER_UPDATE` | Only on an in-group transition, or a leave with a capture still held. |
| `Notify` | `_TryFireJoinNotify`, its timer, `ShowNotification` | `scheduling in Ns (<reason>)`; the skips, each naming its guard (`no pendingInfo`, `already notified for this group`, `not in a group yet`, `notify.enabled is off`); at fire time `fired`, `canceled (superseded)`, `popup held: test mode is on` or `popup not auto-shown: frame.autoShow is off`. |
| `ChatLink` | `OnSetItemRef`, the degraded post-hook | `clicked hasPending=…` per click on the details link; `ignored: addon stood down` on the degraded route only (the normal route is unregistered while disabled). Another addon's link writes nothing. |
| `Frame` | `modules/Frame.lua`, and `/wg show` in `settings/Slash.lua` | `popup shown …` per show request, then its teleport state (`teleport spellID=… known=… (activity=… map=…)`, with ` on cooldown` appended and a `teleport on cooldown, … remaining` line after it while the spell recharges) once per request and again when that state changes under an open popup (the console's `D.DebugChanged`, re-armed per request). `teleport button pressed …` per press. `popup suppressed: visibility = never`, `popup built but not shown: visibility = …`. `popup <before> → <after>: <cause>` when the popup's state moved: the visibility gate on a combat edge or a setting, a dismissal (Close, Escape, the launcher), the stand-down, the owed Hide settling. `held until combat ends: <key> (in combat)` when a combat-end slot fills, `combat ended: flushing N held (<keys>)` when the edge drains it, `dropped held work: <keys> (addon stood down)` when a stand-down drops it. The combat refusals: `popup size not applied`, `popup scale not applied`, `popup saved position dropped; re-anchor refused`. `popup position reset to the shipped anchor`. `/wg show refused: no captured group`. |
| `Test` | test mode, `RunTest` | `test mode on`, `test mode off (<why>)`, `test mode refused: in combat`, `synthetic capture injected "…"`. |
| `Set` | the library's write seam, the profile handlers, `/wg enable\|disable` | `<path> = <value>` once per write; the bulk and profile-reset/copy lines ([debug-content.md](./debug-content.md#tag-vocabulary)); `enabled refused: <err>` when the seam turns the switch down. |
| `Profile` | `OnProfileChanged` | `switched to '<name>'`, once per switch. |
| `Cfg` | the library's Options major; `settings/OptionsSetup.lua`, `settings/Panel.lua` | The library's: `register parked (in combat)` and `register flushed (combat ended)`, `open refused (in combat)`, and `<what> refused (in combat)` for a write, Defaults, button, toggle or tab the open panel's combat lock refuses (`write <path>`, `defaults <page>`, `tab <key>`, …), each once per combat. This addon's: `settings page '<key>' render raised: <err>` and `button '<text>' onClick raised: <err>`, once per distinct error, beside the chat line the player already sees. |
| `Launcher` | the library's Launcher major | Its events (shown, hidden, a refusal, a raise) through `debug`; its registration state (`registered`, or `LibDataBroker-1.1 absent; no launcher` / `LibDBIcon-1.0 absent; broker plugin only` / `descriptor.minimap answered no table; no minimap button`) through `debugAtEnable`, held from `OnEnable` and written the first time logging is turned on. |

### What stays quiet, and why

- **The cooldown ticker**, the addon's one repeating timer, writes nothing per tick. The change it
  exists for (the cooldown running out) re-runs the configure, and that logs the new teleport state.
- **The combat edges** re-ask the visibility gate twice per pull for the rest of the session once the
  popup has been built. They write a line only when the popup's state changed, or when held work is
  flushed.
- **`GROUP_ROSTER_UPDATE`** fires on every roster change in a raid, and writes only on a transition.
- **One open runs the teleport configure twice** (the fill, then `OnShow` arming the ticker). The
  teleport line is change-gated so the pair lands once per show request.
- **Edges this addon does not react to** (loading screens, zone and instance changes, spec changes,
  the addon-restriction state) have no line, because nothing here changes on them.

The pins are the `debug-logging-§8` / `debug-logging-§9` cases at the end of
`tests/test_debuglog.lua`, each with a red-under comment naming the line it protects; the quiet
cases run the path many times and assert the buffer did not grow. The library-owned lines (`Cmd`,
the `Cfg` park, `Launcher` and `Migrate` through the at-enable queue, and the change gate's re-arm on
Clear) are pinned landing here exactly once in `tests/test_library_lines.lua`.

## Where else this is pinned

The command rows are in [slash-dispatch.md](./slash-dispatch.md), and the player-facing steps are the
README's `## Reporting a bug`. The in-game checks are DIAG-17 to DIAG-24, DIAG-30 to DIAG-33 and DIAG-5 of
[smoke-tests.md](./smoke-tests.md). The suites are `tests/test_diagnostics.lua` (this addon's
sections), the kit's shared `tests/_kit/test_diagnostics_contract.lua` (wired in `tests/run.lua`),
`tests/test_disabled.lua` (both forms while disabled) and `tests/test_slash.lua` (the usage line and
`debug diag`).
