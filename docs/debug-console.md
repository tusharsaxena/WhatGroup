# Debug console

`DebugLog.lua` is the addon's on-screen debug console. It exists because the
**Ka0s WoW Addon Standard** (`debug-logging §`) requires any addon that ships a
main window — WhatGroup has `WhatGroupFrame` — to route debug output to a
**dedicated on-screen console styled like its own window**, never to the chat
frame (§7). The reference implementation is Ka0s AbsorbTracker's
`core/DebugLog.lua`; this is a close port adapted to WhatGroup's flat layout and
namespace.

## Public surface

Everything hangs off the shared namespace (`local addonName, NS = ...`):

- **`NS.Debug(tag, fmt, ...)`** — the global sink. Zero-allocation when debug is
  off (the `NS.State.debug` gate is the first line; no `format`/concat before
  it). The **tag is the first argument** so every call site self-documents its
  category: `NS.Debug("Capture", "title=%s", title)`. Appends to the console —
  it never `print()`s to chat.
- **`NS.DebugLog`** (`= D`) — the console object:
  - `D:Show()` / `D:Hide()` / `D:Toggle()` — window visibility.
  - `D:SetEnabled(on)` — the **single state seam** (see below).
  - `D:RefreshHeader()` — re-render the header toggle label/colour.
  - `D:Add(tag, msg)` — raw append (bypasses the flag gate; used for the
    enable/disable bracket lines).
  - `D:Clear()` / `D:ShowCopy()` — Clear and Copy actions.
  - `D.FormatPlain(ts, tag, msg)` / `D.FormatColored(ts, tag, msg)` — the two
    pure formatters (frame-free, unit-tested in `tests/test_debuglog.lua`).
  - `D.buffer` — the plain-text mirror (capped at 500 lines) the Copy window reads.

## The window

- `WhatGroupDebugWindow` — a `BackdropTemplate` frame on **`DIALOG`** strata
  (above the main popup), **700×344**, movable, clamped, registered in
  `UISpecialFrames` (ESC closes). Skinned to match `WhatGroupFrame` (bg
  `0.08,0.08,0.08,0.95`, border `0.3,0.3,0.3`).
- Title bar: draggable, titled `Ka0s WhatGroup — Debug`, 1px divider.
  - **Left:** the `Debug: ON` (green) / `Debug: OFF` (red) state toggle — clicking
    it flips logging through `D:SetEnabled`.
  - **Right:** `Copy`, `Clear`, `×` (close).
- Log surface: a `ScrollingMessageFrame`, `SetMaxLines(500)`, mouse-wheel scroll,
  monospace `NS.FONT_MONO` at 10pt, `SetJustifyH("LEFT")`, fading off.
- **Frames are lazy** — `EnsureFrame()` / `EnsureCopyFrame()` build them on first
  `Add`/`Show`, so a session that never opens the console pays nothing.

## Line format

Each line is `HH:MM:SS | [Tag] message`:

- Console view (coloured): timestamp muted steel-blue `6f8faf`, `[tag]` muted
  tan-gold `c9a66b`, the `|` separator and message default white.
- Copy buffer (plain): identical text, **no colour codes**, so copied logs paste
  clean. The two pure formatters keep the coloured and plain strings from
  drifting.

Tags currently in use: `Capture`, `Notify`, `Apply`, `ChatLink`, `Roster`,
`LFG`, `Invite` (`WhatGroup.lua`), `Frame` (`WhatGroup_Frame.lua`), `Settings`
(`WhatGroup_Settings.lua`), and `Debug` (the enable/disable bracket lines). The
set is open — add a tag as needed.

## Enabled-state — session-only, decoupled from the window

`NS.State.debug` is a **runtime flag independent of the window's visibility**:

- **Session-only**: default off, held in `NS.State.debug` (never in
  SavedVariables), reset to off on every `/reload` and fresh login. It is **not**
  a schema row (WG-12) — there is no `/wg set debug` and no panel checkbox.
- **Logging and the window are independent** — capture runs even with the console
  closed, so a bug can be reproduced first and the log opened after.
- **Single write path**: `D:SetEnabled(on)` sets the flag → `RefreshHeader` →
  chat ack via `NS.Print` (`Debug mode: ON/OFF`) → a `[Debug] logging
  enabled/disabled` **console** bracket line at both transitions. The disable
  line is written through raw `D:Add` (not `NS.Debug`) so it still lands after
  the flag has flipped off. The slash command and the header toggle both route
  through this one seam, so they can't diverge.

## Slash semantics (`/wg debug`)

Per `debug-logging §5` (and matching AbsorbTracker):

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

Just call the sink with a tag:

```lua
NS.Debug("Capture", "title=%s mapID=%s", tostring(title), tostring(mapID))
```

No guard needed at the call site — `NS.Debug` self-gates on `NS.State.debug` and
is zero-alloc when off.

## Tests

`tests/test_debuglog.lua` covers the pure formatters, the `NS.FONT_MONO`
constant, the window-vs-flag `/wg debug` semantics, the header-toggle flip, the
enable/disable bracket lines, and the zero-write-when-off contract. Run with
`lua tests/run.lua`.
