# Debug console

The on-screen debug console is **LibKa0s-DebugLog-1.0**, wired by
`core/DebugLogSetup.lua` from a descriptor. It exists because the **Ka0s WoW
Addon Standard** (`debug-logging §`) requires any addon that ships a main window
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
- `font = NS.FONT_MONO`, `slash = "/wg"` (the latter only composes the console
  checkbox's tooltip).
- `isEnabled` / `setEnabled` — the flag **stays this addon's**
  (`NS.State.debug`). The library never keeps a copy — a second copy inside the
  library would be a second truth.
- `print` / `safeToString` — thin **call-time** forwarders to `NS.Print` /
  `NS.SafeToString` (`NS.SafeToString` is published by `core/CoreSetup.lua`;
  `NS.Print` is `core/WhatGroup.lua`'s reclaim of the printer CoreSetup publishes
  as `NS.Util.print`, which AceConsole's `:Print` mixin would otherwise clobber);
  never captured references, so a later re-publish is honoured.
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
  - `D:RefreshHeader()` — re-render the header toggle label/colour.
  - `D:Add(tag, msg)` — raw append, **ungated** (used for the enable/disable
    bracket lines). Routes `msg` through `safeToString`.
  - `D:Clear()` / `D:ShowCopy()` / `D:CopyText()` — Clear and Copy actions, plus
    exactly what the copy window puts in front of the user.
  - `D:UpdateScrollBar()` / `D:UpdateStatus()` — re-sync the §11 scrollbar thumb
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
  - `D.buffer` — the plain-text mirror (capped at `lib.MAX_BUFFER`, 500 lines)
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

The library builds it; this section records the behaviour a developer needs, not
an implementation this repo owns.

- `WhatGroupDebugWindow` — a `BackdropTemplate` frame on **`DIALOG`** strata
  (the same strata `WhatGroupFrame` uses), **700×344**, movable, clamped,
  registered in `UISpecialFrames` (ESC closes). Skinned with the shared
  `LibKa0s-Core-1.0` skin: the flat 1px black border, the 1px grey inner
  highlight, the gold title and the grey divider — the same edge
  `WhatGroupFrame` now wears.
- **It does not remember its position.** The library owns the drag bar and
  exposes neither it nor a geometry hook, so `NS.Windows` (WG-26) has nothing to
  attach to — there is no adapter, only a fork. Accepted as a gap —
  `LIBKA0S-05` in [docs/pending/LEDGER.md](./pending/LEDGER.md). The popup, the
  window a player actually positions, keeps its own persistence.
- Title bar: draggable, titled `Ka0s WhatGroup — Debug`, 1px divider.
  - **Left:** the `Debug: ON` (green) / `Debug: OFF` (red) state toggle — clicking
    it flips logging through `D:SetEnabled`.
  - **Right:** `Copy`, `Clear`, `×` (close), the last from Core's factory.
- Log surface: a `ScrollingMessageFrame`, `SetMaxLines(500)`, mouse-wheel scroll,
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
- **Status bar**: a 1px divider plus a right-aligned `N / 500 lines` counter in
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

- Console view: the timestamp and the `[tag]` carry the library's colour codes;
  the `|` separator and the message stay default white.
- Copy buffer (plain): identical text, **no colour codes**, so copied logs paste
  clean. The two pure formatters keep the coloured and plain strings from
  drifting.

Tags currently in use:

- **Lifecycle** — `Init` (session summary: addon/version, schema, profile —
  emitted at the `SetEnabled` seam on enable), `Migrate` (only when
  `RunMigrations` actually moves the version, `core/Database.lua`).
- **Capture flow** (`core/WhatGroup.lua`) — `Apply` (one merged line per apply:
  `id=… captured "…" (activity=… map=… m+=…)`), `Capture` (no-op / wipe
  decisions), `LFG` (status events), `Invite` (accepted, with the winning
  `source=fresh|queued`), `Roster` (in-group transitions only), `Notify`
  (`scheduling` / `fired` / `cancelled` / skip), `ChatLink`, `Test`.
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
  SavedVariables), reset to off on every `/reload` and fresh login. It is **not**
  a schema row (WG-12) — there is no `/wg set debug`. The General panel's "Debug
  console" checkbox is a session-only, non-schema affordance rendered from
  `D:ConsoleCheckbox()`, so its label and tooltip come from the module that owns
  the window; it toggles the **window's visibility** only (`D:Show` / `D:Hide`
  via `D:IsShown`), never `NS.State.debug` and never `db.profile`.
- **Logging and the window are independent** — capture runs even with the console
  closed, so a bug can be reproduced first and the log opened after.
- **Single write path**: `D:SetEnabled(on)` writes the flag through the
  descriptor's `setEnabled` → `RefreshHeader` → **colour-coded** chat ack through
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

`NS.FONT_MONO` points at the vendored `media/fonts/JetBrainsMono-Regular.ttf`
(OFL, shipped with `OFL.txt`). `core/WhatGroup.lua` defines it and registers it
with LibSharedMedia-3.0 at load (`LSM:Register("font", "JetBrains Mono", …)`,
guarded so a missing LSM is a no-op); the descriptor hands the same path to the
library, which feeds it straight to `SetFont` for both the console log and the
Copy `EditBox`.

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
addon's, so `/wg debug on` still moves it and still prints the colour-coded ack.
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

`tests/test_debuglog.lua` covers the behaviour, wherever it now lives: the pure
formatters, the `NS.FONT_MONO` constant, the window-vs-flag `/wg debug`
semantics, the header-toggle flip, the enable/disable bracket lines, the `[Init]`
summary's content and its position after the bracket, the colour-coded ack, the
zero-write-when-off contract, the `%d`-with-a-secret path, the one-`[Set]`-per-change
and one-`[Reset]`-per-wipe content rules, and that the §11 scrollbar/counter sync
stays a safe no-op under the mock.

`tests/test_libka0s.lua` covers the seam itself: that `NS.DebugLog` is the
library's instance and `NS.Debug` is bound bare, that the frame globals and the
composed window title are unchanged, that the flag stays the addon's, that
`[Init]` is reached through the descriptor, that the console's strings resolve to
prose rather than to their own keys, and that the degraded stub answers every
member while copying no formatter.

Run with `lua tests/run.lua`. The in-game scrollbar and counter behaviour itself
is a manual check — [smoke-tests.md](./smoke-tests.md) row 2.8b-i.
