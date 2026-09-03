# Debug console

The on-screen debug console is **LibKa0s-DebugLog-1.0**, wired by
`core/DebugLogSetup.lua` from a descriptor. It exists because the **Ka0s WoW
Addon Standard** (`debug-logging`) requires any addon that ships a main window
— WhatGroup has `WhatGroupFrame` — to route debug output to a **dedicated
on-screen console styled like its own window**, never to the chat frame
(debug-logging-§7). One console is shared across the collection, so this addon
owns none of it — not the formatters, the buffer, the frames, the scrollbar or
the enable seam.

What is genuinely per-addon is the **content** of what gets logged, plus the
handful of facts in the descriptor below.

## What the descriptor supplies

`core/DebugLogSetup.lua` hands `lib:New` only what the library cannot know:

- `name = addonName` — seeds the frame globals `WhatGroupDebugWindow`,
  `WhatGroupDebugCopyWindow`, `WhatGroupDebugCopyScroll` — the names
  `/framestack` and any Esc-close muscle memory expect.
- `title = "Ka0s WhatGroup"` — the bare brand; the library appends its own
  `" — Debug"`.
- `font = resolveConsoleFont(NS.FONT_MONO)`, `slash = "/wg"` (the latter only
  composes the console checkbox's tooltip). See **Font** below for why the path
  is probed rather than passed through.
- `addonName = addonName` — passed **beside** `name`, not instead of it. `name`
  seeds the frame globals above; `addonName` is what the library builds a
  **texture path** from, so its own close, clear and copy controls draw this
  collection's marks instead of a multiplication sign and the words `Clear` and
  `Copy`. Same string here, different questions everywhere. A vendored library
  cannot infer it — there is no one path to it — and a wrong one draws nothing
  and raises nothing.
- `isEnabled` / `setEnabled` — the flag **stays this addon's**
  (`NS.State.debug`). The library never keeps a copy — a second copy inside the
  library would be a second truth.
- `print` / `safeToString` — thin **call-time** forwarders to `NS.Print` /
  `NS.SafeToString` (`NS.SafeToString` is published by `core/CoreSetup.lua`;
  `NS.Print` is `core/WhatGroup.lua`'s reclaim of the printer CoreSetup publishes
  as `NS.Util.print`, which AceConsole's `:Print` mixin would otherwise clobber);
  never captured references, so a later re-publish is honored.
- `initSummary` — `WhatGroup:InitSummary()`. The library owns *when* it is
  emitted; only the addon knows what it says.
- `onVisibilityChanged` — calls `Settings.Helpers.RefreshAll()` so the General
  page's console checkbox re-syncs when the window is closed with Esc or the `×`.

Deliberately **not** passed: `L` (this addon translates none of the console's
strings, and a locale table with a key-returning metatable would render
`DEBUG_ON` in place of English), and `skin` / `applySkin` / `makeCloseButton` —
as of Core minor 3 the library's own default *is* the normative Ka0s window edge,
which the popup now wears too, and the `×` on a library window is the library's.

**TOC slot: after `core/WhatGroup.lua`**, which is a move from where
`core/DebugLog.lua` sat. The library validates `name`, `title`, `font`,
`isEnabled` and `setEnabled` at `:New` time, and both `NS.FONT_MONO` and
`NS.State.debug` are defined in `core/WhatGroup.lua`. Nothing calls `NS.Debug` at
file load, so the move costs nothing.

## Public surface

Everything hangs off the shared namespace (`local addonName, NS = ...`):

- **`NS.Debug(tag, fmt, ...)`** — the gated sink, bound **bare** from the
  library's `D.Debug` so the ~20 existing call sites keep working unchanged.
  Zero-allocation when debug is off (it returns before building the argument
  table). Secret-safe when on: every vararg goes through `NS.SafeToString`, the
  `string.format` is `pcall`ed, and on failure the line still **lands** — the
  format string verbatim followed by the stringified arguments, space-joined
  (events-frames-taint-§8 / WG-22). The **tag is the first argument** so every
  call site self-documents its category: `NS.Debug("Capture", "title=%s", title)`.
  Appends to the console — it never `print()`s to chat.
- **`NS.DebugLog`** (`= D`) — the library instance:
  - `D:Show()` / `D:Hide()` / `D:Toggle()` — window visibility.
  - `D:IsShown()` — is the console window currently visible? **Never builds the
    frame** (false before it exists), so the Settings panel can read it on every
    refresh without forcing the console into existence.
  - `D:SetEnabled(on)` / `D:IsEnabled()` — the **single state seam** (see below).
  - `D:RefreshHeader()` — re-render the header toggle label/color.
  - `D:Add(tag, msg)` — raw append, **ungated** (used for the enable/disable
    bracket lines). Routes `msg` through `safeToString`.
  - `D:Clear()` / `D:ShowCopy()` / `D:CopyText()` — Clear and Copy actions, plus
    exactly what the copy window puts in front of the user.
  - `D:UpdateScrollBar()` / `D:UpdateStatus()` — re-sync the debug-logging-§11 scrollbar thumb
    and the line counter. Called on every `Add`, on `Clear`, and on wheel-scroll;
    both no-op until the frame exists.
  - `D.FormatPlain(ts, tag, msg)` / `D.FormatColored(ts, tag, msg)` — the two
    pure formatters, lib-level and frame-free (asserted in
    `tests/test_debuglog.lua`).
  - `D:BufferSize()` / `D:LastLine()` / `D:FindLine(substr)` — buffer readers for
    tests and diagnostics.
  - `D:ConsoleCheckbox()` — a plain `{ label, tooltip, get, set }` table for the
    settings panel to render (see below). Data, not a widget, so neither library
    reaches for the other.
  - `D.buffer` — the plain-text mirror (capped at `lib.MAX_BUFFER`, 1500 lines)
    the Copy window reads.
- **`WhatGroup:InitSummary()`** (in `core/WhatGroup.lua`) — a pure builder
  returning the one-line `[Init]` session summary: the standard-mandated identity
  fields first — `WhatGroup v<version>, schema v<schemaVersion>, profile
  '<profile>'` — then the current runtime state `(enabled=…, notify.delay=…s,
  autoShow=…, inGroup=…, hasPending=…)` on the same line. The library's
  `SetEnabled` seam calls it and appends the line via raw `Add` **on enable,
  immediately after the `[Debug] logging enabled` bracket** (debug-logging-§5
  MUST). Emitted at the seam, not at login — the session-only flag is off at
  login, so the seam is the only current, visible point (debug-logging-§8). This
  makes a pasted log self-identifying (which build / schema / profile) without
  asking the reporter.

## The window

The library builds it; this section records the behavior a developer needs, not
an implementation this repo owns.

- `WhatGroupDebugWindow` — a `BackdropTemplate` frame on **`DIALOG`** strata
  (the same strata `WhatGroupFrame` uses), **700×344**, movable, clamped,
  registered in `UISpecialFrames` (ESC closes). Skinned with the shared
  `LibKa0s-Core-1.0` skin: the flat 1px black border, the 1px gray inner
  highlight, the gold title and the gray divider — the same edge
  `WhatGroupFrame` now wears.
- **It does not remember its position.** The library owns the drag bar and
  exposes neither it nor a geometry hook, so `NS.Windows` (WG-26) has nothing to
  attach to — there is no adapter, only a fork. Accepted as a gap —
  [`LIBKA0S-05`](https://github.com/tusharsaxena/WhatGroup/issues/11). The popup, the
  window a player actually positions, keeps its own persistence.
- Title bar: draggable, titled `Ka0s WhatGroup — Debug`, 1px divider.
  - **Left:** the `Debug: ON` (green) / `Debug: OFF` (red) state toggle — clicking
    it flips logging through `D:SetEnabled`.
  - **Right:** copy, clear and close — three small square targets drawing the
    shared `copy`, `clear` and `close` marks from the LibKa0s icon catalog. All
    three are the library's own controls; they draw art rather than words only
    because the descriptor passes `addonName`. Without it they fall back to the
    words `Copy` and `Clear` beside a multiplication sign, which is what a
    degraded install correctly gets and what a regression looks like.
- Log surface: a `ScrollingMessageFrame`, `SetMaxLines(1500)`, mouse-wheel scroll,
  monospace `NS.FONT_MONO` at 10pt, `SetJustifyH("LEFT")`, fading off, inset to
  clear the scrollbar gutter and the status bar.
- **Scrollbar** (debug-logging-§11 MUST): a `ScrollingMessageFrame` has no native
  scrollbar, so a thin flat vertical `Slider` on the right edge drives its scroll
  offset. **Always shown** — going inert (`EnableMouse(false)`) rather than
  hiding when the whole log fits, so the gutter stays a constant width, matching
  the options panel's always-shown scrollbar (options-ui-§10). Synced both ways,
  with a `_syncing` re-entrancy guard between them. Vertical Sliders run value
  0 = top = **oldest** while the message-frame offset runs 0 = **newest**, so the
  two are related by `offset = maxOffset - value`. Driven **only** by the Lua
  mixin API (`GetMaxScrollRange` / `GetScrollOffset` / `SetScrollOffset`) — the
  old C getters (`GetNumLinesDisplayed` / `GetCurrentScroll`) are nil on this
  mixin and MUST NOT be used (anti-pattern #41). Type-guarded, so the headless
  mock is a clean no-op.
- **Status bar**: a 1px divider plus a right-aligned `N / 1500 lines` counter in
  the log's own monospace font, updated on every append and reset by `Clear`.
  `N` is `#D.buffer`, capped in lock-step with the log's `SetMaxLines`.
- **Frames are lazy** — the console window and the copy window are built
  separately, on first `Add`/`Show` and on first `ShowCopy`, so a session that
  never opens the console pays nothing. The skin and the initial scrollbar/counter
  sync run **last** in the window build — after the `Hide` and the
  `UISpecialFrames` insert — so a frame-API surprise there can never leave a
  visible window nobody can close.

## Line format

Each line is `HH:MM:SS | [Tag] message`, in the library's format:

- Console view: the timestamp and the `[tag]` carry the library's color codes;
  the `|` separator and the message stay default white.
- Copy buffer (plain): identical text, **no color codes**, so copied logs paste
  clean. The two pure formatters keep the colored and plain strings from
  drifting.

Tags currently in use:

- **Lifecycle** — `Init` (session summary: addon/version, schema, profile —
  emitted at the `SetEnabled` seam on enable), `Migrate` (only when
  `RunMigrations` actually moves the version, `core/Database.lua`).
- **Capture flow** (`core/WhatGroup.lua`) — `Apply` (one merged line per apply:
  `id=… captured "…" (activity=… map=… m+=…)`), `Capture` (no-op / wipe
  decisions), `LFG` (status events), `Invite` (accepted, with the winning
  `source=fresh|queued`), `Roster` (in-group transitions only), `Notify`
  (`scheduling` / `fired` / `canceled` / skip), `ChatLink`, `Test`.
- **Frame** (`modules/Frame.lua`) — `Frame` (`popup shown …`, `teleport
  spellID=… known=…`).
- **Settings** (`settings/Schema.lua`) — `Set` (the one canonical
  settings-change line, at the `Helpers.Set` seam — a single-row
  `/wg reset <path>` lands here too, because it resets through `Helpers.Set`),
  `Reset` (one coalesced summary for `RestoreAllDefaults`, i.e. `/wg resetall`
  and the panel's Defaults button), `Schema` (internal path-lookup miss).
- **Console** — `Debug` (the enable/disable bracket lines, written by the
  library).

`[Debug]` and `[Init]` are structure rather than prose — the library leaves them
untranslatable for exactly that reason. The set is otherwise open; add a tag as
needed. The content rules the addon follows — **coverage** of the main flows
(debug-logging-§8), **coalescing** to one summary line per pass
(debug-logging-§9), and **one `[Set]` line per settings change at the single
seam** (debug-logging-§10) — are MUSTs in the standard's `debug-logging` section.

## Enabled-state — session-only, decoupled from the window

`NS.State.debug` is a **runtime flag independent of the window's visibility**,
and it is the addon's, not the library's:

- **Session-only**: default off, held in `NS.State.debug` (never in
  SavedVariables), reset to off on every `/reload` and fresh login. The FLAG is
  **not** a schema row (WG-12) — there is no `/wg set debug`. The **window's
  visibility** is one, on the Master controls tab: `options-ui-§15` makes "Debug
  console" one of the canonical eight, so it is a `sessionOnly` schema row on the
  path `state.debugConsole` rather than the bespoke `SessionCheckbox` it used to
  be. `settings/Schema.lua`'s `SESSION` table routes that path to
  `D:ConsoleCheckbox()`'s own `get`/`set` in front of `Resolve`, so the module
  that owns the window still owns what the toggle *does*, and nothing about it
  reaches `db.profile`. The label and tooltip are now the composer's, which is
  the one visible difference. `BuildDefaults` skips the row; `RestoreAllDefaults`
  sweeps it by hand, because `db:ResetProfile()` cannot reach storage that is not
  the db (`options-ui-§12`).
- **Logging and the window are independent** — capture runs even with the console
  closed, so a bug can be reproduced first and the log opened after.
- **Single write path**: `D:SetEnabled(on)` writes the flag through the
  descriptor's `setEnabled` → `RefreshHeader` → **color-coded** chat ack through
  the descriptor's `print`, i.e. `NS.Print` (`debug logging |cff40ff40ON|r` /
  `|cffff4040OFF|r` — ON green `40ff40`, OFF red `ff4040`, matching the title-bar
  toggle) → a `[Debug] logging enabled/disabled` **console** bracket line at both
  transitions → **on enable only**, the `[Init]` session summary
  (`InitSummary()`) immediately after the bracket. Both are written through raw
  `Add` (not the gated sink) so they land regardless of the flag — through the
  sink the "disabled" line would early-return and never appear. The slash command
  and the header toggle both route through this one seam, so they can't diverge
  (debug-logging-§5).

## Slash semantics (`/wg debug`)

Per `debug-logging-§5`, and handled by `runDebug` in `settings/Slash.lua`:

- `/wg debug` — **toggles the console window** (`D:Toggle()`); logging state
  untouched.
- `/wg debug on` / `/wg debug off` — set the session flag through
  `D:SetEnabled`.

See [slash-dispatch.md](./slash-dispatch.md) for the dispatch table.

## Font

`NS.FONT_MONO` points at **the library payload's**
`libs/LibKa0s/media/fonts/JetBrainsMono-Regular.ttf` (OFL, shipped with the
library's own `JetBrainsMono-OFL.txt`). The face used to be this addon's, under
`media/fonts/`; it moved into LibKa0s with `LibKa0s-Media-1.0`, because six Ka0s
addons shipping six copies of one font is six licenses to track and a collection
that stops looking like one author's work the first time one copy is regenerated
and the rest are not.

`core/WhatGroup.lua` resolves it as
`NS.MediaFont and NS.MediaFont(NS.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT` —
the seam published by `core/MediaSetup.lua`, whose TOC slot is load-bearing for
exactly this reason. **The fallback is a real client font on purpose:** `SetFont`
accepts a path to a file that is not there, fails to load it, and the text simply
does not draw, so a degraded install must land on a face the client definitely
has rather than on nil or on a dead path. `core/MediaSetup.lua` also makes the
LibSharedMedia registration, through `Media.RegisterLSM(addonName)` at file load
— one call, pointing every Ka0s addon at one set of bytes under one key, in place
of this addon's own `LSM:Register`. The descriptor hands the resolved path to the
library, which feeds it straight to `SetFont` for both the console log and the
Copy `EditBox`.

**The fetch-failure fallback (debug-logging-§2).** `core/DebugLogSetup.lua` does
not hand `NS.FONT_MONO` over unexamined. It probes the path once at load —
`CreateFont("WhatGroupFontProbe"):SetFont(path, 10, "")` — and passes
`Fonts\ARIALN.TTF` instead if the probe fails. This matters because the failure
is **silent**: `SetFont` answers `false` when the client cannot load the file (a
packager that dropped the library's `media/`, a corrupt TTF, a path case-mangled on a
case-sensitive filesystem) and does not raise, so without the fallback the
console would come up in whatever font the region already carried — a
proportional one — and the aligned `HH:MM:SS | [tag] …` columns the monospace
requirement exists for would be gone with nothing in the error log to explain
it. A `Font` object rather than a throwaway frame: it is the lightest thing in
the API carrying `SetFont`, it is never parented or shown, and probing it cannot
disturb a shared Blizzard font object. The probe resolves at load because the
library validates `descriptor.font` as a string at `:New` time. Two cases in
`tests/test_debuglog.lua` pin both branches, driving the failure through the
mock's `fontFetchFails` table.

## Copy / Clear

- **Clear** wipes both the visible log and the `D.buffer` Copy mirror.
- **Copy** opens `WhatGroupDebugCopyWindow` — a multiline `EditBox` pre-filled
  with `D:CopyText()` (the whole buffer, in order) and auto-highlighted for
  `Ctrl+C` (WoW exposes no clipboard API, so the user's `Ctrl+C` inside an
  `EditBox` is the only copy path). Same monospace font as the console, on
  `FULLSCREEN` strata so it sits above the console.

## When the library is missing

`core/DebugLogSetup.lua` degrades rather than errors. The stub answers **every**
member the addon calls, and the **flag still works** — `NS.State.debug` is this
addon's, so `/wg debug on` still moves it and still prints the color-coded ack.
What is lost is the window, and the stub says so once per entry point: enabling,
asking for the window, and asking for the copy box each spend their own announce
token, phrased as `NS.LIBKA0S_MISSING` plus the consequence. `ConsoleCheckbox()`
still answers a well-formed spec whose tooltip carries the same sentence.

The stub copies **no** formatter. Nothing in the addon calls them outside the
library's own `Add`, and hand-transcribing the strings whose drift the extraction
exists to end is the one duplicate debug-logging-§3 and testing-§8 most
specifically forbid.

## Adding a debug line

Just call the sink with a tag (format args are applied only when debug is on, so
string-building stays behind the gate — debug-logging-§9):

```lua
NS.Debug("Apply", 'id=%s captured "%s" (map=%s)', tostring(id), tostring(title), tostring(mapID))
```

No guard needed at the call site — `NS.Debug` self-gates on `NS.State.debug` and
is zero-alloc when off. Follow the content rules: cover the main flows (debug-logging-§8),
coalesce repeating paths to one summary line per pass — never per item (debug-logging-§9), and
log each settings change once at the `Helpers.Set` seam (debug-logging-§10).

## Tests

`tests/test_debuglog.lua` covers the behavior, wherever it now lives: the pure
formatters, the `NS.FONT_MONO` constant, the window-vs-flag `/wg debug`
semantics, the header-toggle flip, the enable/disable bracket lines, the `[Init]`
summary's content and its position after the bracket, the color-coded ack, the
zero-write-when-off contract, the `%d`-with-a-secret path, the one-`[Set]`-per-change
and one-`[Reset]`-per-wipe content rules, and that the debug-logging-§11 scrollbar/counter sync
stays a safe no-op under the mock.

`tests/test_libka0s.lua` covers the seam itself: that `NS.DebugLog` is the
library's instance and `NS.Debug` is bound bare, that the frame globals and the
composed window title are unchanged, that the flag stays the addon's, that
`[Init]` is reached through the descriptor, that the console's strings resolve to
prose rather than to their own keys, and that the degraded stub answers every
member while copying no formatter.

Run with `lua tests/run.lua`. The in-game scrollbar and counter behavior itself
is a manual check — [smoke-tests.md](./smoke-tests.md) row 2.8b-i.
