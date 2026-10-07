# WhatGroup — in-client smoke tests (2026-10-07 review)

This checklist covers only what the game client can check. Lint, the suite, `--list`, `tests/perf.lua`
and complexity ran headless; see `01_FINDINGS.md`, *Measurement run*. Results are the owner's to record.
Never mark a row passed on someone else's behalf.

## Pre-flight

1. Apply the changes, then run `lua tests/run.lua` and `luacheck .` from the repo root. Expect 0/0, and
   the pass count C-002 and C-003 predict (**918 passed**).
2. Client: retail **12.1.0** (`## Interface: 120100`). Load the game from `GIT/WhatGroup` through the
   usual symlink, never from a side worktree.
3. Run `/console scriptErrors 1`. Have BugSack or the default error frame visible.
4. Use a character that has learned at least one M+ teleport. *Path of the Windrunners* (1254400) is the
   one `/wg test notify`'s sample resolves to. A target dummy should be in reach.
5. Run `/wg debug on` to watch the console lines named below.

## S-001 — Confirm F-001 on the **current** build (before C-001)

Run this before the fix. It records whether the client really marks the teleport cooldown secret in
combat.

- **Setup:** learn *Path of the Windrunners* and cast it, so its cooldown is running. Leave
  `visibility` on *Always*.
- **Steps:**
  1. Type `/wg test notify` out of combat. The popup shows `On cooldown — 7h 59m …`.
  2. Leave the popup open, attack the dummy, and stay in combat for 5 seconds.
  3. Still in combat, type `/wg test notify` again.
- **Expected (bug present):** a Lua error at `core/Compat.lua:112` (*attempt to compare … secret*). The
  note stops counting down. Step 3 prints the summary rows but no *Teleport* or details-link row.
- **Expected (bug absent, so F-001 does not reach this client):** no error, and the note keeps counting.
- **Result:** record which of the two happened. This decides whether F-001 stays High or is downgraded
  to a defensive fix.

## C-001 — Secret-safe cooldown reader

- **Setup:** as S-001, with the fix applied.
- **Steps:**
  1. `/wg test notify` out of combat, then leave the popup open.
  2. Pull the dummy, fight for 10 seconds, then drop combat.
  3. Pull again and run `/wg test notify` mid-fight.
- **Expected:**
  - No Lua error at any point.
  - During combat the note keeps its last value, or keeps counting if the client gives plain numbers.
  - Within about 1 second of combat ending, the note counts down again and shows the real remaining time
    (compare with the spell tooltip).
  - Step 3 prints every enabled row, including *Teleport* (without a tag if the value was unreadable)
    and the details-link row.
  - `/wg diagnostics` mid-fight shows `cooldownTicking=true`.
- **Pass:** no error, the countdown resumes after combat, and the link row prints.

## C-003 — The test preview leaves the real capture alone

### TEST-1: a real capture survives the test

- **Setup:** join a real group through the Premade Group Finder and let the summary and popup appear.
  Close the popup.
- **Steps:** Settings → Ka0s WhatGroup → General → Chat → **Test**. Close the sample popup. Click the
  original details link in chat, then type `/wg show`.
- **Expected:** the link and `/wg show` both open **your real group**, not *Test Group — Windrunner Spire
  +12*.
- **Pass:** the real group's title is shown both times.

### TEST-2: disabled, Test, enabled

- **Setup:** `/wg disable`, then open General.
- **Steps:** click **Test**, then tick **Enabled**.
- **Expected:** the chat summary prints on Test, and no popup appears then. When the addon is enabled,
  **no popup appears**. `/wg diagnostics` shows `popup: not built` if nothing had built it earlier this
  session.
- **Pass:** nothing pops up when the addon is enabled.

### TEST-3: closing a one-shot preview

- **Steps:** `/wg test notify`, then press **Escape**.
- **Expected:** the popup closes and the game menu does not open. `/wg show` with no real capture prints
  `No group info available…`.
- **Pass:** both expectations hold.

### TEST-4: test mode is not affected

- **Steps:** run the existing test-mode smoke checks in `docs/smoke-tests.md` (the *Test mode* section)
  unchanged.
- **Expected:** as recorded there.

## C-004 — Height tooltip

- **Steps:** Settings → General → Popup → hover **Height**.
- **Expected:** the tooltip says the default is **280**. Click **Defaults**, confirm, and the slider
  reads `280 px`.

## C-005, C-006

These change documents and comments only, so there is nothing to check in the client.

## Regression suite

1. Run `/reload`. Expect no errors on load, and the `[WG]` lines appear only when the addon prints.
2. Log in on a fresh profile. Settings → AddOns lists **Ka0s WhatGroup** with **General** and
   **Profiles**.
3. Run a real Premade Group Finder join end to end. Apply, get invited and accept. The chat summary
   prints after `notify.delay`, every enabled row is present, and the popup opens. The teleport button
   casts out of combat.
4. Combat with the popup open on each `visibility` value (*Always*, *Only in combat*, *Only out of
   combat*, *Never*). There should be no `ADDON_ACTION_BLOCKED`, and the popup follows the gate.
5. Switch profiles to one with `enabled = false`, then back. The addon stands down and up, and the popup
   follows.
6. Open the settings panel and toggle every option at least once. No errors.

## Cross-addon (in client)

The four source-level classes were clean today. Their client-side counterparts still need checking in a
session with several Ka0s addons loaded:

1. Type each of the 22 roots and confirm each reaches its own addon: `/at /am /bl /cm /kcd /lh /mm
   /pm /pfe /pc /wg`, plus each full addon name.
2. Open Settings → AddOns. Each addon appears once, and each multi-page addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| S-001 | | | records whether F-001 is live on 12.1.0 |
| C-001 | | | |
| C-003 TEST-1 | | | |
| C-003 TEST-2 | | | |
| C-003 TEST-3 | | | |
| C-003 TEST-4 | | | |
| C-004 | | | |
| Regression 1-6 | | | |
| Cross-addon 1-2 | | | |
