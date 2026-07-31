# Debug console

`DebugLog.lua` is the addon's on-screen debug console. It exists because the
**Ka0s WoW Addon Standard** (`debug-logging §`) requires any addon that ships a
main window — WhatGroup has `WhatGroupFrame` — to route debug output to a
**dedicated on-screen console styled like its own window**, never to the chat
frame (debug-logging-§7). The reference implementation is Ka0s AbsorbTracker's
`core/DebugLog.lua`; this is a close port adapted to WhatGroup's namespace.

## Public surface

Everything hangs off the shared namespace (`local addonName, NS = ...`):

- **`NS.Debug(tag, fmt, ...)`** — the global sink. Zero-allocation when debug is
  off (the `NS.State.debug` gate is the first line; no `format`/concat before
  it). Secret-safe when on: it `pcall`s `string.format` and, on failure,
  rebuilds the line from `NS.SafeToString`'d args so a combat-protected value
  yields `<secret>` instead of raising (events-frames-taint-§8 / WG-22). The
  **tag is the first argument** so every call site self-documents its category:
  `NS.Debug("Capture", "title=%s", title)`. Appends to the console — it never
  `print()`s to chat.
- **`NS.DebugLog`** (`= D`) — the console object:
  - `D:Show()` / `D:Hide()` / `D:Toggle()` — window visibility. The window
    persists its position across reloads via `NS.Windows` (saved on drag-stop,
    restored on build; default `CENTER, 220, -80`, WG-26).
  - `D:IsShown()` — is the console window currently visible? Deliberately has
    **no `EnsureFrame` side effect** (false before the frame is ever built), so
    the Settings panel's session-only "Debug console" checkbox can read it
    without forcing the console into existence.
  - `D:SetEnabled(on)` — the **single state seam** (see below).
  - `D:RefreshHeader()` — re-render the header toggle label/colour.
  - `D:Add(tag, msg)` — raw append (bypasses the flag gate; used for the
    enable/disable bracket lines).
  - `D:Clear()` / `D:ShowCopy()` — Clear and Copy actions.
  - `D:UpdateScrollBar()` / `D:UpdateStatus()` — re-sync the §11 scrollbar thumb
    and the line counter. Called on every `Add`, on `Clear`, and on wheel-scroll;
    both no-op until the frame exists.
  - `D.FormatPlain(ts, tag, msg)` / `D.FormatColored(ts, tag, msg)` — the two
    pure formatters (frame-free, unit-tested in `tests/test_debuglog.lua`).
  - `D.buffer` — the plain-text mirror (capped at 500 lines) the Copy window reads.
- **`WhatGroup:InitSummary()`** (in `WhatGroup.lua`) — a pure builder returning
  the one-line `[Init]` session summary: the standard-mandated identity fields
  first — `WhatGroup v<version>, schema v<schemaVersion>, profile '<profile>'` —
  then the current runtime state `(enabled=…, notify.delay=…s, autoShow=…,
  inGroup=…, hasPending=…)` on the same line. The `D:SetEnabled` seam calls it and
  appends the line via raw `D:Add` **on enable, immediately after the
  `[Debug] logging enabled` bracket** (debug-logging-§5 MUST). Emitted at the
  seam, not at login — the session-only flag is off at login, so the seam is the
  only current, visible point (debug-logging-§8). This makes a pasted log self-identifying
  (which build / schema / profile) without asking the reporter.

## The window

- `WhatGroupDebugWindow` — a `BackdropTemplate` frame on **`DIALOG`** strata
  (above the main popup), **700×344**, movable, clamped, registered in
  `UISpecialFrames` (ESC closes). Skinned through `NS.ApplySkin`, which paints
  the shared `NS.SKIN` colours (bg `0.08,0.08,0.08,0.95`, border `0.3,0.3,0.3`)
  over this file's own backdrop table — so the console reads like
  `WhatGroupFrame` while keeping its heavier 12px `UI-Tooltip-Border` frame
  where the popup uses a 1px hairline (WG-28).
- Title bar: draggable, titled `Ka0s WhatGroup — Debug`, 1px divider.
  - **Left:** the `Debug: ON` (green) / `Debug: OFF` (red) state toggle — clicking
    it flips logging through `D:SetEnabled`.
  - **Right:** `Copy`, `Clear`, `×` (close).
- Log surface: a `ScrollingMessageFrame`, `SetMaxLines(500)`, mouse-wheel scroll,
  monospace `NS.FONT_MONO` at 10pt, `SetJustifyH("LEFT")`, fading off. Its
  TOPLEFT/BOTTOMRIGHT anchors inset by `BAR_W` on the right and `STATUS_H` at the
  bottom to clear the scrollbar gutter and the status bar below.
- **Scrollbar** (debug-logging-§11 MUST): a `ScrollingMessageFrame` has no native
  scrollbar, so a thin flat vertical `Slider` on the right edge drives its scroll
  offset. **Always shown** — going inert (`EnableMouse(false)`, thumb parked)
  rather than hiding when the whole log fits, so the gutter stays a constant
  width, matching the options panel's always-shown scrollbar (options-ui-§10).
  Synced both ways: dragging the thumb scrolls the log, wheeling the log moves
  the thumb, with a `frame._syncing` re-entrancy guard between them. Vertical
  Sliders run value 0 = top = **oldest** while the message-frame offset runs
  0 = **newest**, so the two are related by `offset = maxOffset - value`. Driven
  **only** by the Lua mixin API (`GetMaxScrollRange` / `GetScrollOffset` /
  `SetScrollOffset`) — the old C getters (`GetNumLinesDisplayed` /
  `GetCurrentScroll`) are nil on this mixin and MUST NOT be used
  (anti-pattern #41). Type-guarded, so the headless mock is a clean no-op.
- **Status bar**: a 1px divider plus a right-aligned `N / 500 lines` counter in
  the log's own monospace font, updated on every append and reset by `Clear`.
  `N` is `#D.buffer`, capped in lock-step with the log's `SetMaxLines`.
- **Frames are lazy** — `EnsureFrame()` / `EnsureCopyFrame()` build them on first
  `Add`/`Show`, so a session that never opens the console pays nothing. The
  initial scrollbar/counter sync runs **last** in the window build — after the
  header, `RefreshHeader`, and the `UISpecialFrames` insert — so a frame-API
  surprise inside the sync can never leave a blank header or an unregistered
  ESC-to-close.

## Line format

Each line is `HH:MM:SS | [Tag] message`:

- Console view (coloured): timestamp muted steel-blue `6f8faf`, `[tag]` muted
  tan-gold `c9a66b`, the `|` separator and message default white.
- Copy buffer (plain): identical text, **no colour codes**, so copied logs paste
  clean. The two pure formatters keep the coloured and plain strings from
  drifting.

Tags currently in use:

- **Lifecycle** — `Init` (session summary: addon/version, schema, profile —
  emitted at the `SetEnabled` seam on enable), `Migrate` (only when
  `RunMigrations` actually moves the version).
- **Capture flow** (`WhatGroup.lua`) — `Apply` (one merged line per apply:
  `id=… captured "…" (activity=… map=… m+=…)`), `Capture` (no-op / wipe
  decisions), `LFG` (status events), `Invite` (accepted, with the winning
  `source=fresh|queued`), `Roster` (in-group transitions only), `Notify`
  (`scheduling` / `fired` / `cancelled` / skip), `ChatLink`, `Test`.
- **Frame** (`modules/Frame.lua`) — `Frame` (`popup shown …`, `teleport
  spellID=… known=…`).
- **Settings** (`settings/Schema.lua`) — `Set` (the one canonical
  settings-change line, at the `Helpers.Set` seam), `Reset` (one coalesced
  summary for `/wg reset`), `Schema` (internal path-lookup miss).
- **Console** — `Debug` (the enable/disable bracket lines).

The set is open — add a tag as needed. The content rules the addon follows —
**coverage** of the main flows (debug-logging-§8), **coalescing** to one summary line per pass
(debug-logging-§9), and **one `[Set]` line per settings change at the single seam** (debug-logging-§10) — are
MUSTs in the standard's `debug-logging` section.

## Enabled-state — session-only, decoupled from the window

`NS.State.debug` is a **runtime flag independent of the window's visibility**:

- **Session-only**: default off, held in `NS.State.debug` (never in
  SavedVariables), reset to off on every `/reload` and fresh login. It is **not**
  a schema row (WG-12) — there is no `/wg set debug`. The General panel's "Debug
  console" checkbox is a session-only, non-schema affordance that toggles the
  **window's visibility** only (`D:Show` / `D:Hide` via `D:IsShown`); it never
  touches `NS.State.debug` and never writes `db.profile`.
- **Logging and the window are independent** — capture runs even with the console
  closed, so a bug can be reproduced first and the log opened after.
- **Single write path**: `D:SetEnabled(on)` sets the flag → `RefreshHeader` →
  **colour-coded** chat ack via `NS.Print` (`debug logging |cff40ff40ON|r` /
  `|cffff4040OFF|r` — ON green `40ff40`, OFF red `ff4040`, matching the title-bar
  toggle) → a `[Debug] logging enabled/disabled` **console** bracket line at both
  transitions → **on enable only**, the `[Init]` session summary
  (`InitSummary()`) immediately after the bracket. The disable and `[Init]` lines
  are written through raw `D:Add` (not `NS.Debug`) so they land regardless of the
  gate. The slash command and the header toggle both route through this one seam,
  so they can't diverge (debug-logging-§5).

## Slash semantics (`/wg debug`)

Per `debug-logging-§5` (and matching AbsorbTracker):

- `/wg debug` — **toggles the console window** (`D:Toggle()`); logging state
  untouched.
- `/wg debug on` / `/wg debug off` — set the session flag through
  `D:SetEnabled`.

See [slash-dispatch.md](./slash-dispatch.md) for the dispatch table.

## Font

`NS.FONT_MONO` points at the vendored `media/fonts/JetBrainsMono-Regular.ttf`
(OFL, shipped with `OFL.txt`). `WhatGroup.lua` registers it with
LibSharedMedia-3.0 at load (`LSM:Register("font", "JetBrains Mono", …)`, guarded
so a missing LSM is a no-op) and feeds the same path straight to `SetFont` for
both the console log and the Copy `EditBox`.

## Copy / Clear

- **Clear** wipes both the visible log and the `D.buffer` Copy mirror.
- **Copy** opens `WhatGroupDebugCopyWindow` — a read-through multiline `EditBox`
  pre-filled with the plain buffer and auto-highlighted for `Ctrl+C` (WoW exposes
  no clipboard API, so the user's `Ctrl+C` inside an `EditBox` is the only copy
  path). Same monospace font as the console.

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

`tests/test_debuglog.lua` covers the pure formatters, the `NS.FONT_MONO`
constant, the window-vs-flag `/wg debug` semantics, the header-toggle flip, the
enable/disable bracket lines, the zero-write-when-off contract, and that the §11
scrollbar/counter sync stays a safe no-op under the mock. Run with
`lua tests/run.lua`. The in-game scrollbar and counter behaviour itself is a
manual check — [smoke-tests.md](./smoke-tests.md) row 2.8b-i.
