# Design — WhatGroup debug console + colored `list`/`get`

**Date:** 2026-07-14
**Status:** Approved (brainstorming) — pending implementation plan
**Scope:** Bring `/wg` debug and settings-slash output to parity with the
AbsorbTracker reference and the Ka0s WoW Addon Standard.

## Motivation

Smoke-test feedback on the last audit flagged two look-and-feel gaps against the
user's other addon (AbsorbTracker):

1. The debug experience is chat-spam, not a window.
2. `/wg list` / `/wg get` output is uncolored.

Investigation shows both are **live deviations from the standard**, not new
feature requests:

- WhatGroup has a main window (`WhatGroupFrame`). Per `debug-logging §7`, any
  addon with a main window **MUST** route debug to an on-screen console, not the
  chat frame. WhatGroup instead flips `NS.State.debug` and chat-spams
  `|cffFF8C00[DBG]|r` lines via the `dbg()` helper. AbsorbTracker's
  `core/DebugLog.lua` is the reference-compliant implementation.
- `/wg list`/`get` lack the `slash-commands §5` color scheme (header green
  `33ff99`, section azure `3399ff`, shared `FormatKV` key gold `ffff00` / value
  white).

Porting AbsorbTracker's console and color scheme therefore **remediates** the
deviations rather than introducing new ones. No new accepted-deviation needed;
the direction conforms to the standard.

## Decisions

- **Monospace font: full parity.** Vendor `JetBrainsMono-Regular.ttf` + `OFL.txt`
  under `media/fonts/`, add `LibSharedMedia-3.0` to `libs/` + TOC, register the
  font at load, expose the path as `NS.FONT_MONO`. (User choice; satisfies the
  `debug-logging §2` SHOULD with zero deviation.)
- **`/wg debug` semantics change** to match AbsorbTracker + `debug-logging §5`:
  `/wg debug` toggles the *window*; `/wg debug on|off` sets the session flag.
  This rewrites documented smoke-test C5 (currently `/wg debug` → `Debug mode:
  ON`). Intended alignment, called out explicitly.
- **No version bump, no git commit** — per the repo's standing rules. This
  overrides the brainstorming skill's "commit the design doc" step: the spec is
  written but left modified-but-unstaged for the user to commit.

## Components

### A. `DebugLog.lua` (new, flat root-level file)

Near-direct port of AbsorbTracker `core/DebugLog.lua`, adapted to WhatGroup's
namespace (`local addonName, NS = ...`) and print seam (`NS.PREFIX` /
`WhatGroup._print`). Provides:

- **Console frame** `WhatGroupDebugWindow` — `BackdropTemplate`, `UIParent`,
  `DIALOG` strata, **700×344**, movable, clamped, in `UISpecialFrames`.
  Draggable title bar titled `"Ka0s WhatGroup — Debug"`, 1px black divider, `×`
  close glyph. Backdrop matches `WhatGroupFrame` (bg `0.08,0.08,0.08,0.95`,
  border `0.3,0.3,0.3,1`) via a local `applySkin` seam.
- **Log surface** — `ScrollingMessageFrame`, `SetFont(NS.FONT_MONO, 10, "")`,
  `SetJustifyH("LEFT")`, fading off, `SetMaxLines(500)`, mouse-wheel scroll.
- **Title-bar controls** — left: `Debug: ON` (green `0.30,0.85,0.30`) /
  `Debug: OFF` (red `0.90,0.30,0.30`) state toggle button; right (right-to-left):
  `×` close, `Clear`, `Copy` flat text buttons.
- **Copy window** `WhatGroupDebugCopyWindow` — `FULLSCREEN` strata, read-through
  multiline `EditBox` in the same mono font, pre-filled with the plain buffer,
  auto-highlighted; `Esc` clears focus and hides. In `UISpecialFrames`.
- **Two pure formatters** (frame-free, unit-tested):
  - `D.FormatPlain(ts, tag, msg)` → `"<ts> | [<tag>] <msg>"`
  - `D.FormatColored(ts, tag, msg)` → ts `6f8faf`, `[tag]` `c9a66b`, `||`
    separator + msg default white.
- **Plain buffer** capped at 500 lines, mirrors the console with no color codes.
- **Sink** `NS.Debug(tag, fmt, ...)` — gate on `NS.State.debug` is the first
  line (zero-alloc when off); otherwise `string.format` only if varargs present,
  then `D:Add(tag, msg)`. Never `print()`s to chat.
- **`SetEnabled(on)` seam** — single write path: set `NS.State.debug` → refresh
  header → `NS.PREFIX` chat ack (via the shared printer) → console bracket line.
  `[Debug] logging enabled` on enable / `[Debug] logging disabled` on disable;
  the disable line is written via raw `D:Add` (not `NS.Debug`) so it lands after
  the flag flips off.
- **Public API**: `NS.DebugLog:Show/Hide/Toggle/SetEnabled/RefreshHeader/Add/
  Clear/ShowCopy`.

### B. Reroute existing debug call-sites (10 total)

- `WhatGroup.lua` — the `dbg()` local and the public `WhatGroup._dbg` become
  thin shims that forward to `NS.Debug`. The `[DBG]` chat branch is removed.
- Each call-site gains a **tag**:
  - `WhatGroup.lua`: `Capture` (156, 204), `Notify` (291, 390, 405),
    `Invite` (346, 358, 492), `Roster` (439), `LFG` (455). (Line numbers
    indicative; final tags assigned per call semantics.)
  - `WhatGroup_Frame.lua`: `Frame` (195, 312).
  - `WhatGroup_Settings.lua`: `Settings` (207–208).
- Call-sites are converted from string-concat form to the tag + format form
  where it reads cleanly; concat is acceptable where the message is a single
  pre-built string.

### C. Slash-dispatch changes (`WhatGroup.lua`)

- `runDebug` reworked: `/wg debug` → `NS.DebugLog:Toggle()` (window only);
  `/wg debug on|off` → `NS.DebugLog:SetEnabled(true|false)`.
- The `debug` row help text updated to reflect window-toggle + on/off.

### D. Colored `list`/`get`/`set` (`WhatGroup.lua`)

- Add a shared `FormatKV(path, valueStr)` →
  `"|cFFFFFF00%s|r = |cFFFFFFFF%s|r"`.
- `listSettings`: header `|cff33ff99Available settings|r`; section headers
  `|cff3399ff[<section>]|r`; rows via `FormatKV`.
- `getSetting` and the `set` echo use `FormatKV` so `key = value` is identical
  everywhere. No trailing colons.

### E. Vendoring & TOC (`WhatGroup.toc`, `libs/`, `media/fonts/`)

- Copy `JetBrainsMono-Regular.ttf` + `OFL.txt` from AbsorbTracker into
  `media/fonts/`.
- Copy `LibSharedMedia-3.0` from AbsorbTracker into `libs/`; add its load line to
  the libraries block of the TOC.
- Register the font at load (`LSM:Register("font", "JetBrains Mono", path)`) and
  set `NS.FONT_MONO` to the addon-relative TTF path.
- Add `DebugLog.lua` to the TOC after `Database.lua`, before `WhatGroup.lua`
  (so `NS.Debug` exists before any runtime handler fires).

### F. Docs & tests

- `docs/slash-dispatch.md` — document new `/wg debug` window semantics + colored
  output.
- `docs/smoke-tests.md` — rewrite C5/C6 for the console + window-toggle behavior.
- `docs/ARCHITECTURE.md` / `docs/file-index.md` — add `DebugLog.lua`, LSM, font
  asset; update load order.
- `tests/test_debuglog.lua` — pure-formatter unit tests (mirror AbsorbTracker),
  wired into `tests/run.lua`. Verify `tests/wow_mock.lua` exposes `date`,
  `CreateFrame` stubs, `UISpecialFrames`, `wipe` as needed.

## Load order (final TOC)

```
libs: … AceDB, LibSharedMedia-3.0, AceGUI
Compat.lua
Locale.lua
Database.lua
DebugLog.lua        <-- new
TeleportSpells.lua
WhatGroup.lua
WhatGroup_Settings.lua
WhatGroup_Frame.lua
```

## Out of scope (YAGNI)

- Structured dump verbs (`/wg debug <topic>`).
- Any `WhatGroupFrame` redesign.
- `resetposition` or other new commands.

## Standards touchpoints

- `debug-logging §1–§7` — console, mono font, line format, sink, session-only
  state, Copy/Clear, main-window-MUST-use-console.
- `slash-commands §4–§5` — `NS.PREFIX` chat seam, colored `list`/`get` scheme,
  `/wg debug` window-vs-flag semantics.
- Deviation rule (`§0`): no new deviation introduced; the change removes two
  existing deviations. No `SHOULD`-justification comments required.
