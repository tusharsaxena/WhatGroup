# Smoke tests

WhatGroup has a **headless test harness** (`lua tests/run.lua`) that covers pure logic — Compat shims, schema defaults/validation/get/set, labels, teleport lookup, and the capture-merge preference — plus `luacheck .` for lint. What the harness **cannot** cover — AceGUI panel rendering, the secure teleport button, and taint — is validated **manually, in-game** with this checklist. Run the relevant section after any of:

- `/wow-addon:commit` of a non-trivial change
- A WoW patch (Interface bump)
- A `libs/` refresh — from KickCD for Ace3, or from `../LibKa0s` for the shared library
- Before tagging a release

Each section lists steps, the expected outcome, and (when relevant) the bug it guards against. Times are wall-clock estimates assuming you're already logged in.

---

## 1. Boot smoke (~1 min)

Verifies the addon loads cleanly and registers nothing that taints Blizzard's secure-execute chain.

### 1.1 Cold load

1. Quit the game completely.
2. Launch, log in to any character.
3. Open chat.

**Expected:** No Lua errors. No `[WG]` chat spam on first boot — debug logging is session-only and OFF by default (nothing routes to the console until you `/wg debug on`).

### 1.2 `/reload` health

1. `/reload`
2. Watch chat.

**Expected:** No Lua errors. No taint warnings.

### 1.3 GameMenu Logout — no taint regression (CRITICAL)

The addon was previously tainting `GameMenuFrame`'s button callbacks; clicking Logout fired `ADDON_ACTION_FORBIDDEN ... 'callback()'` and the action wouldn't proceed. This must stay clean.

1. `/reload`
2. Press **ESC** (opens GameMenu).
3. Click **Logout**.

**Expected:** The character logs out cleanly, no Lua error, no `ADDON_ACTION_FORBIDDEN` line.

Repeat after each of these to make sure no surface re-introduces the leak:
- After `/wg test` (exercises `WhatGroupFrame` + secure teleport button)
- After a fresh login / `/reload`, before running anything (`Settings.Register` now runs at `OnEnable`, so the AddOns entry is registered at boot — this is the key case for the login-register change)
- After `/wg config` (re-opens the already-registered panel)
- After `/wg reset` confirm (exercises lazy `StaticPopupDialogs["WHATGROUP_RESET_ALL"]`)
- After clicking the teleport button on the popup
- After applying to a real LFG group

If **any** of these tests reproduces the taint error, the boot path has regressed — see [midnight-quirks.md → Taint propagation in the boot window](./midnight-quirks.md) and [common-tasks.md → Adding a Blizzard-protected surface touch](./common-tasks.md).

### 1.4 Reset popup — registered in combat as well as out (CRITICAL)

`Settings.EnsureResetPopup` writes one key into `StaticPopupDialogs` and no longer assigns the table
itself. The assignment it used to carry (`StaticPopupDialogs = StaticPopupDialogs or {}`) guarded
against a client with no such table, which does not exist, and was itself the kind of write to the
protected global that § 1.3 exists to keep out of the boot window. Nothing headless can see the
difference — taint is not a test failure — so it is checked here.

1. Out of combat: `/wg config`, open the settings page, press **Defaults**, confirm the popup, then
   dismiss it.
2. Pull a target and stay in combat. Do step 1 again — the popup must still appear and still accept.
3. Out of combat again, press **ESC** and click **Logout**, then cancel at the confirmation.

**Expected:** the popup shows and dismisses in both combat states, and no step raises "Interface
action failed because of an AddOn" or `ADDON_ACTION_FORBIDDEN`. Step 3 is § 1.3 run after a reset has
touched the table, and is the step that actually catches a leak.

---

## 2. Slash commands smoke (~3 min)

Every entry in `WhatGroup.COMMANDS` is exercised at least once.

| # | Step | Expected |
|---|------|----------|
| 2.1 | `/wg` | Help index prints, listing all commands with the `[WG]` prefix. |
| 2.2 | `/wg help` | Same as 2.1. |
| 2.3 | `/whatgroup help` | Same — long alias works. |
| 2.4 | `/wg list` | Green **Available settings** header, azure `[section]` group headers, each `key = value` with a gold key and white value (slash-commands-§5). |
| 2.5 | `/wg get enabled` | Prints `enabled = true` (gold key / white value). |
| 2.6 | `/wg set notify.delay 2.5` | Prints `notify.delay = 2.5s`. Re-running `/wg get notify.delay` confirms. |
| 2.7 | `/wg set notify.enabled toggle` | Toggles bool — confirm with `/wg get notify.enabled`. Run twice to restore. |
| 2.8 | `/wg debug` | **Opens the debug console window** (`Ka0s WhatGroup — Debug`, 700×344, monospace). Run again to close it. State is untouched — the header toggle still reads `Debug: OFF`. |
| 2.8a | `/wg debug on` then `/wg debug off` | Each prints `[WG] debug logging ON`/`OFF` in chat with the state word **color-coded** (ON green `40ff40`, OFF red `ff4040`, matching the title-bar toggle) **and** appends a `[Debug] logging enabled`/`disabled` line inside the console. `on` also appends one `[Init]` line right after the bracket — `WhatGroup v<ver>, schema v1, profile '<name>'` followed by the current runtime state (`enabled`, `notify.delay`, `autoShow`, `inGroup`, `hasPending`). |
| 2.8b | Click the `Debug: OFF`/`ON` toggle in the console title bar | Flips logging state (green ON / red OFF) with the same chat ack + console bracket line as `/wg debug on\|off`. `Copy` opens a highlight-ready plain-text buffer; `Clear` wipes both views. |
| 2.8b-i | Scrollbar + line counter (debug-logging-§11) | The console has a **thin scrollbar** on the log's right edge and a **`N / 1500 lines`** counter in the bottom-right, in the log's monospace font. With debug on, spam lines (e.g. `/wg set notify.delay 1` a few times) until the log overflows: the counter climbs and the scrollbar thumb becomes draggable. **Drag the thumb** — the log scrolls; **mouse-wheel the log** — the thumb tracks it. Thumb **top = oldest**, **bottom = newest**. `Clear` resets the counter to `0 / 1500` and parks/grays the thumb. On a short (fitting) log the bar is still shown but inert. **First open must NOT error** — a blank `Debug: ON/OFF` header or dead ESC-to-close means the initial sync threw (anti-pattern #41). |
| 2.8c | With debug on: `/wg set notify.delay 3.0` | Console shows **one** `[Set] notify.delay = 3` line. Restore with `/wg set notify.delay 0` (another single `[Set]`). |
| 2.8d | With debug on: `/wg set notify.delay 3`, then `/wg resetall` → **Yes** | After the `[Set] notify.delay = 3` line, the console shows **one** `[Set] reset profile '<name>' to defaults (1 rows)` line (debug-logging-§10). There is **no** `[Set]` per row and **no** `[Reset]` line. The count is the rows the reset changed, so a second `/wg resetall` straight after reads `(0 rows)`. |
| 2.9 | `/wg show` (no group, no pendingInfo) | Prints "No group info available. Use `/wg test` to preview." |
| 2.10 | `/wg test` | Synthetic chat notification + popup fire (full coverage in section 4). |
| 2.11 | `/wg show` (right after 2.10) | Re-opens the same popup. |
| 2.12 | `/wg config` | Settings panel opens on the **Ka0s WhatGroup** landing page; the **General** subcategory is visible/expanded in the sidebar. |
| 2.13 | `/wg reset` | StaticPopup confirm appears. **Yes** resets all settings; **No** cancels. |
| 2.14 | `/wg gibberish` | Prints `unknown command 'gibberish'` followed by the help index. |
| 2.15 | `/wg config` while in combat | Prints the gray notice `[WG] cannot open settings during combat — Blizzard's category-switch is protected` and does **not** open the panel (WG-25). (Pull a target dummy first to enter combat.) |
| 2.16 | `/wg version` | Prints `[WG] v<version>` on its own line, matching the TOC `## Version` (WG-29). |
| 2.17 | `/wg help` | The header line ends with `…/wg)` — **no** trailing colon (WG-19) — and lists a `/wg version` row. |
| 2.18 | Move the popup (`/wg test`, drag it) and the debug console (`/wg debug`, drag it), then `/reload` and reopen each | Each window reopens at the spot you left it, not re-centered (WG-26). |

---

## 3. Settings panel smoke (~3 min)

Verifies AceGUI rendering, schema-driven widget refresh, and the Defaults flow.

### 3.1 Landing page

1. `/wg config`

**Expected:** Logo image renders. Notes one-liner is visible. "Slash Commands" heading + one row per `COMMANDS` entry. Scrollbar is visible (grayed out if content fits).

### 3.2 General subcategory

1. Click **General** in the Settings sidebar tree.

**Expected:** A **tab strip** across the top of the page reading **Master controls | Chat | Popup**, left to right, with **Master controls** selected and drawn as the disabled (current) tab. Below it, a two-column grid — and **no group headings**: the strip names the group now. `subgroup` headings *are* drawn, on the two tabs that mix control kinds. **Defaults** button in the top-right corner. Hovering any widget shows a tooltip with the schema row's `tooltip` field.

Click each tab in turn and confirm the page swaps content rather than scrolling:

- **Master controls** (options-ui-§15's canonical block, in this exact order): *Enable WhatGroup | General visibility*, *Master scale | Master alpha*, *Lock frame | Debug console*, then the **Reset position | Reset all settings** button pair.
- **Chat**: a **Timing** heading over *Notification Delay* alone, then a **Text** heading over *Print to Chat* alone, then *Instance | Type*, *Leader | Playstyle*, *Details link | Teleport spell*, then the *Test* button.
- **Popup**: a **Behavior** heading over *Open Automatically* alone, then a **Layout** heading over *Width | Height*.

Clicking the tab you are already on does nothing (the active tab is disabled). The **Test** button appears on **Chat only** and the reset pair on **Master controls only** — if either shows up elsewhere, the `afterGroup` key is wrong.

### 3.3 Widget round-trip

1. **Popup** tab → toggle **Open Automatically** off.
2. **Chat** tab → slide **Notification Delay** to 3.0s.
3. Close the Settings panel.
4. `/wg get frame.autoShow` → `false`.
5. `/wg get notify.delay` → `3.0s`.
6. `/wg set frame.autoShow on` → re-open Settings → **Popup** tab → checkbox is checked.
7. Restore both to defaults.

**Expected:** Panel widgets and slash-command get/set agree at every step. Each rendered widget registers a refresher closure on its page, and a `/wg set` re-runs them in place — no rebuild — so an open panel follows a slash write immediately.

### 3.4 Defaults button

0. The button appears one frame after the page first opens (it is built in the panel's
   secure-defer hop, not at login). It must look like every other button on the page —
   Blizzard's red stone button means it was created before a UI skin hooked AceGUI.
1. Make several changes via the panel.
2. Click **Defaults**.
3. **Yes** in the confirm popup.

**Expected:** Every changed widget snaps back to its declared default. `/wg list` shows defaults. The chat line "all settings reset to defaults" prints with the `[WG]` prefix.

### 3.5 Test button

1. Settings panel → **General** → **Test** button.

**Expected:** Same flow as `/wg test` — chat notification + popup. Confirms the Test button shares the `WhatGroup:RunTest()` code path with the slash command.

### 3.5a Popup size — the two promoted literals

1. `/wg config` → **Popup** tab. Confirm **Width** reads `420 px` and **Height** reads `260 px` on a
   profile that has never touched them. *These are the numbers the old `FRAME_WIDTH` / `FRAME_HEIGHT`
   file-locals held; a different default here means every existing install's popup just resized.*
2. `/wg test` to open the popup, leave it open, and drag **Width** to `600`. Release.
   **Expected:** the open popup widens as you release, and nothing inside it moves relative to the
   title bar — the rows and the teleport button are anchored to the frame's corners.
3. Drag **Height** to `340`. Release. Same again, vertically. The Close button stays 12px off the
   bottom edge.
4. `/wg set frame.width 4000`, then `/wg show`.
   **Expected:** the popup is drawn at **700** wide (the clamp's ceiling), not off the screen. Same
   with `/wg set frame.height 10` → drawn at **200**.
5. Pull a target dummy, and with the popup open `/wg set frame.width 500`.
   **Expected:** the open popup does **not** resize during combat (no error, no "action blocked").
   Drop combat, `/wg show` again — now it is 500 wide.
6. `/wg reset frame.width` and `/wg reset frame.height` → both back to 420 / 260.

### 3.6 Debug console checkbox — visibility only, session-only (WG-12 / debug-logging-§5)

Layout check first: `/wg config` → **Master controls** tab. The grid should read:

```
[Enable WhatGroup]    [General visibility]
[Master scale]        [Master alpha]
[Lock frame]          [Debug console]
[Reset position]      [Reset all settings]
```

i.e. **Debug console** pairs on the right of **Lock frame**, in options-ui-§15's canonical order. It was a bespoke checkbox paired against *Enable* before; it is a canonical schema row now, and its label and tooltip come from the composer.

1. Fresh login (or `/reload`). `/wg config` → **Master controls**. Confirm **Debug console** is **unchecked** (the window is hidden at login).
2. Check it → the debug console **window appears**.
3. Uncheck it → the window **hides**.
4. Confirm it does **not** touch logging state: with the box unchecked, `/wg debug on` (logging ON), then check the box — the window shows but there is **no** `debug logging OFF/ON` chat line from the checkbox, and `/wg debug` state is unchanged (the console header still reads `Debug: ON`). Unchecking hides the window while logging stays ON.
5. Close the console via its own **×** (or ESC) while the Settings panel is open, then reopen `/wg config` → **Master controls**: the checkbox has re-synced to **unchecked** (the `OnShow` refresher reads live window visibility).
6. Check the box, then **log out fully and back in**; reopen the panel.

7. `/wg resetall` → **Yes** with the console open.
   **Expected:** the console **closes**. It is a `sessionOnly` row, and options-ui-§12 requires those to be swept by hand because `db:ResetProfile()` cannot reach them.

**Expected:** step 4 proves the checkbox toggles *only* window visibility, never the logging flag. Step 6: after relog the box is **unchecked** — nothing persisted. `/wg list` does show `state.debugConsole` (it is a schema row now), but there is **no** `state` table and no `debug` field in `WhatGroupDB`. **Guards against:** the checkbox being wired as a persisted schema row (must not write `db.profile`), it wrongly flipping debug logging, and panel/console visibility drift.

### 3.7 Master controls — the four frame rows and the visibility gate (options-ui-§15)

Every row here is new in this build, and each is only real if the popup obeys it. Open the popup
first with `/wg test` so there is something to watch, and keep the Settings panel open beside it.

| # | Do | Expect |
|---|---|---|
| 3.7a | **Master scale** → 1.5 | The popup grows immediately. `/wg get scale` → `1.5`. Slide back to 1. |
| 3.7b | `/wg set scale 40` | Clamped: the popup is drawn at 2×, not 40×. `/wg set scale 1` to restore. |
| 3.7c | Pull a trainer dummy, then move **Master scale** while in combat | The popup does **not** rescale (the secure teleport button is anchored off its edges). Drop combat, `/wg show` → the size you set is applied on the next open. |
| 3.7d | **Master alpha** → 40% | The popup fades **immediately**, and it also fades while you are **in combat** — unlike scale. Restore to 100%. |
| 3.7e | Drag the popup by its title bar, tick **Lock frame**, drag again | The first drag moves it, the second does nothing. Untick and confirm dragging works again. |
| 3.7f | Drag the popup somewhere odd, then click **Reset position** | It jumps back to the shipped anchor (centered, raised a quarter of the screen). `/reload`, `/wg show` — it is **still** there, because the stored point was dropped too. |
| 3.7g | **General visibility** → *Never*, then `/wg show` | Nothing opens, and nothing errors. `/wg test` prints the chat summary but shows no popup. |
| 3.7h | **General visibility** → *Only in combat*, `/wg show` out of combat, then pull a dummy and `/wg show` | Out of combat: nothing on screen. In combat: the popup opens. (The frame is built the first time either way — it is just not shown.) |
| 3.7i | With the popup open, set **General visibility** → *Never* | The open popup **closes** on the spot. Set it back to *Always*. |
| 3.7j | `/wg set visibility nonsense` | Refused by the enum parser, naming the four legal values. |

**Guards against:** a declared setting the drawing code ignores; a scale change taken in combat
tainting the secure button; a lock read once at build time instead of at drag time; a *Reset
position* the next login undoes; and `Only in combat` deadlocking against the lazy first build.

### 3.8 The visibility gate follows a combat transition (options-ui-§15)

`Only in combat` and `Only out of combat` are the only two settings in the addon whose answer
changes without the player touching the panel. Until 2026-09-08 the gate was read only when
something opened the popup, so a transition taken with the popup already on screen was missed
entirely — the setting looked right on every fresh open and did nothing in the one window it was
bought for. `core/WhatGroup.lua`'s `OnEnable` now registers `PLAYER_REGEN_DISABLED` /
`PLAYER_REGEN_ENABLED` and both re-ask the gate. **Headless cases pin the logic; only the client
can prove the events actually arrive and that hiding a live popup mid-pull raises nothing.**

1. **General visibility** → *Only out of combat*. `/wg test` so the popup is on screen with a
   capture in it.
2. Pull a training dummy **without closing the popup**.
3. Drop combat and wait for the lockdown to end.
4. Repeat with **General visibility** → *Only in combat*: `/wg test` out of combat (nothing shows),
   then pull, then drop combat.
5. Close the popup, `/wg reset pendingInfo` is not a thing — instead `/reload` to clear the capture,
   then pull a dummy with *Only out of combat* still set and drop combat again.

**Pass** —
- Step 2: the popup **hides the moment combat starts**, and no `ADDON_ACTION_FORBIDDEN` or
  "Interface action failed because of an AddOn" line appears. The hide is what the setting promises;
  the absence of a taint line is what makes hiding a live frame from a combat-edge handler safe.
- Step 3: the popup **comes back**, with the same capture in it — all six rows still populated, not
  "No data".
- Step 4: the mirror. Nothing on screen out of combat, the popup appears on the pull, and it goes
  again when combat ends.
- Step 5: **nothing opens.** With no capture pending, a combat transition must never put an empty
  popup on screen — that is worse than no popup at all.

**Fail** — the popup stays up in combat; it hides and never returns; it returns showing "No data";
a popup appears in step 5; or any taint line at the transition.

**Also here, and it is the reason this step exists twice over:** with the popup **hidden by the
gate** (step 4, out of combat, *Only in combat* set, teleport on cooldown), the countdown ticker must
not be running. The observable is in § 4.1a — leave the popup hidden for a stretch, then let it open
and confirm the time shown has dropped by the real elapsed amount rather than sitting where it was.
Before 2026-09-08 the ticker armed against a frame that was never shown, and because `OnHide` fires
only on a transition it then had no cancel site at all and ran for the rest of the session. That is
the invariant the `performance-§12` deviation row in [`ARCHITECTURE.md`](./ARCHITECTURE.md) rests on.

**Guards against:** a combat-dependent setting that is only ever evaluated at open time; a
combat-edge `Hide` that taints; a re-show that resurrects an empty popup; and a repeating ticker
armed against a frame with no cancel site.
---

## 4. Synthetic flow smoke — `/wg test` (~1 min)

Exercises the notify + popup pipeline end-to-end without needing a real LFG application.

1. `/wg test`

**Expected chat output (with default toggles):**

```
[WG] You have joined a group!
[WG]   - Group: Test Group — Windrunner Spire +12
[WG]   - Instance: Dungeons > Mythic+ > Windrunner Spire
[WG]   - Type: Mythic+
[WG]   - Leader: Testadin-Silvermoon
[WG]   - Playstyle: Fun (Serious)
[WG]   - Teleport: [Path of the Windrunners]   (plus "(not learned)" or "(on cooldown)" if either applies)
[WG]   - [Click here to view details]
```

**Expected popup:** All six rows populated (Group / Instance / Type / Leader / Playstyle / Teleport). Teleport icon is full-alpha if you know `Path of the Windrunners` and it is off cooldown, desaturated 50%-alpha otherwise.

### 4.1 Teleport button click

1. With the popup open from step 4 above, hover the teleport icon.
2. Click it (only meaningful if you have the spell learned).

**Expected:**
- Tooltip shows the spell.
- If learned: cast initiates (or fails for in-combat / wrong zone — that's still success: the secure click reached `CastSpellByID`).
- If not learned: nothing happens (button is `EnableMouse(false)`).
- **No `ADDON_ACTION_FORBIDDEN` line in chat.** This is the secure-button regression test.
- With `/wg debug on` first: the console shows **one** `[Frame] teleport button pressed → /cast <Spell> (spellID=<N>, button=<btn>)` line per press (gated to the down edge, so exactly one line even though the button registers both click edges).

### 4.1a Teleport on cooldown

Needs a teleport you have learned **and recently used** — the eight-hour Keystone Hero cooldown makes this easy to arrange and slow to undo, so do it on a dungeon you were going to port to anyway. `/wg test` uses Windrunner Spire (`Path of the Windrunners`).

1. Cast the teleport.
2. Run `/wg test` and look at the Teleport row.

**Expected:**
- Icon desaturated at 50% alpha, with a **cooldown swipe** over it that visibly sweeps.
- Beside the button: a dim `On cooldown — 7h 58m 12s`, matching the spell tooltip's own "Cooldown remaining".
- Hovering still shows the tooltip — the cooldown state keeps it, unlike the not-learned state.
- **Clicking does nothing.** No cast, no error, no `ADDON_ACTION_FORBIDDEN`.
- The text **counts down once a second** while the popup is open. Watch it for ~5 seconds and confirm it decrements smoothly and does not jump or stall.
- Close the popup, wait ~10 seconds, re-open: the time shown must have dropped by roughly that much — i.e. the ticker stopped when the window closed and did not keep a stale value alive.
- Open and close the popup five times in a row, then leave it open: the countdown decrements by **one** second per second, not five. (A stacked ticker is the failure this catches, and it is invisible any other way.)
- With `/wg debug on`: one `[Frame] teleport on cooldown, <time> remaining (spellID=<N>)` line.
- The chat summary's Teleport row is tagged `(on cooldown)` — a bare tag with no figure, since that line cannot refresh itself.

Then, once the cooldown has expired, `/wg test` again: full alpha, no swipe, no note, and the click casts. Better still, catch it live — leave the popup open across the expiry and the button must rearm itself: swipe gone, note gone, full alpha, and a click that casts, with no close-and-reopen.

### 4.1b Teleport not learned

1. Join or `/wg test` for a dungeon whose teleport you have **not** learned.

**Expected:**
- Icon desaturated at 50% alpha, no cooldown swipe.
- Beside the button: `Teleport spell not learned` — never the cooldown wording, even if the spell reports a cooldown.
- Hovering shows **no** tooltip (the not-learned state drops the mouse, unlike the cooldown state).
- Clicking does nothing, with no error.

### 4.2 Chat link round-trip

1. Click `[Click here to view details]` in the chat output from step 4.

**Expected:** Popup re-opens with the same data. No ItemRef tooltip opens and no Lua error appears.
A `/wg test` link does **not** stand in for a real join's link. § 5.1a clicks that one.

### 4.3 ESC closes popup

1. Press **ESC** with the popup focused.

**Expected:** Popup hides. ESC menu does **not** open (because `WhatGroupFrame` is in `UISpecialFrames`).

### 4.4 Drag-to-reposition

1. Drag the popup from its title bar.

**Expected:** Whole popup including the teleport button moves. Dropping near a screen edge clamps without going off-screen.


### 4.5 The popup in combat — it closes, and nothing is blocked

**Reported from the client on 2026-09-07** as `AddOn 'WhatGroup' tried to call the protected function 'WhatGroupFrame:Hide()'`, and revised on 2026-09-08 when the owner ruled that closing in combat has to actually work.

The popup parents a `SecureActionButtonTemplate` teleport button, so the client refuses `Hide` on it — and on any ancestor of it — during a lockdown. Alpha is not refused, and this addon already ruled so: `ApplyFrameAlpha` is deliberately un-guarded because opacity moves nothing. So a close in combat takes the frame to alpha 0 and the real `Hide` lands when combat ends.

**Run with BugGrabber (or `/console scriptErrors 1`) enabled, or this check cannot fail visibly.**

1. `/wg test` to raise the popup, out of combat. Pull a training dummy.
   - **Expected:** no red error, nothing in BugGrabber naming WhatGroup.
2. Press **Close** while still in combat.
   - **Expected:** **the popup goes away immediately.** No error, no chat line. This is the behaviour the 2026-09-08 ruling asked for; before it, Close in combat did nothing visible.
3. Drop combat.
   - **Expected:** it is still gone, and stays gone.
4. `/wg test` again, pull, and this time press **ESC** in combat.
   - **Expected:** identical to step 2.
5. Set `General visibility` = **Out of combat**, `/wg test` out of combat, then pull.
   - **Expected:** the popup goes off screen **on the pull**, not a fight later. No error.
6. Drop combat.
   - **Expected:** **it comes back by itself.** This is the gate releasing what it withheld, and it is the half that must not be lost to the fix for step 2.
7. `/wg test` **while in combat**, with the popup closed.
   - **Expected:** no red error, and the popup does **not** appear. One chat line: *"Popup deferred until combat ends."*
8. Drop combat.
   - **Expected:** the popup opens now, carrying the capture from step 7.
9. Set `General visibility` = **In combat**, out of combat, holding a capture. The popup is hidden. Pull.
   - **Expected:** no red error, and — **known limitation** — the popup does **not** open. `Show` is protected in combat, so this value cannot be delivered from a hidden frame. See `docs/frame.md`; making it work means keeping the frame invisible-but-present out of combat, which is a decision nobody has taken.

**Known and accepted:** between steps 2 and 3 the frame is invisible but still present — it has not been `Hide`n yet, so its title bar can still be dragged and the teleport button still occupies its 24px. A teleport cannot be cast in combat, so a click there does nothing. If you can find a way to make that matter to a player, it is worth a finding.

**Failure means:** any red error; a Close in combat that leaves the popup on screen (steps 2, 4); the `Out of combat` value not clearing on the pull (step 5); or — the subtle one — the popup **not** returning at step 6 or **not** opening at step 7, which would mean the fix for closing killed the legitimate re-show along with the bug.

### 4.6 A popup you closed stays closed

**Reported from the client on 2026-09-08**, on the shipped default (`General visibility` = **Always**): `/wg test`, close the popup, pull something, and it springs open again. No Lua error — nothing about the call was wrong. The re-show arm could not tell "the gate is withholding this" from "the player put it away", and under `Always` the gate never withholds, so every firing of it was the second case.

1. `General visibility` = **Always** (the default). `/wg test`, then press **Close**.
2. Pull a training dummy.
   - **Expected:** the popup stays closed.
3. Drop combat.
   - **Expected:** still closed. The dismissal outlives the whole fight.
4. `/wg test` again, then press **ESC** instead of Close. Pull, drop combat.
   - **Expected:** identical. ESC routes through `UISpecialFrames` to a bare `Hide()`, so it must be exactly as durable as the button.
5. Now the direction that *must* still work: `General visibility` = **In combat**, out of combat, holding a capture. The popup is hidden. Pull.
   - **Expected:** the popup **opens**. This is the gate withholding and then releasing, and it is the one case the re-show arm exists for.
6. Drop combat.
   - **Expected:** hides again.

**Failure means:** a popup you dismissed reappearing on any combat edge (steps 2-4), or the `In combat` value never opening the popup at all (step 5) — the second would mean the fix went too far and killed the legitimate case with the bug.

---

## 5. Real LFG flow smoke (~5–10 min)

The end-to-end test. Requires an active LFG and at least one group leader willing to accept your invite.

### 5.1 Single application

1. `/wg debug on` to enable logging, then `/wg debug` to open the console window (or leave it closed — capture runs regardless; you can open it afterwards to read the trace).
2. `/reload`  *(logging is session-only — re-run `/wg debug on` after the reload)*
3. Open Premade Group Finder, find a Mythic+ or raid group.
4. Click **Apply**.
5. Wait for invite, accept it.
6. Open the console (`/wg debug`) and read the trace.

**Expected debug trace in the console (order may vary slightly), each line `HH:MM:SS | [Tag] …`:**

```
<ts> | [Init] WhatGroup v1.4.0, schema v1, profile 'Default' (enabled=true, notify.delay=0s, autoShow=true, inGroup=false, hasPending=false)
<ts> | [Apply] id=<N> captured "<title>" (activity=<A> map=<M> m+=true)
<ts> | [LFG] appID=<N> status=applied
<ts> | [LFG] appID=<N> status=invited            (some flows skip this)
<ts> | [LFG] appID=<N> status=inviteaccepted
<ts> | [Invite] accepted appID=<N> → "<title>" map=<M> (source=fresh)
<ts> | [Roster] inGroup=true wasInGroup=false hasPending=true
<ts> | [Notify] scheduling in <delay>s (<reason>)
<ts> | [Notify] fired
<ts> | [Frame] popup shown "<title>" map=<M>
```

**Expected user-visible output (after `notify.delay` seconds):** Full chat notification + popup, with the **real** group name, leader, mapID-resolved teleport spell.

### 5.1a The real join's details link: click and shift-click

The 2026-09-12 report: after a real join (open world, idle, 12.1.0 client), clicking this link did nothing. No popup opened and no hint printed. A later `/wg test` link worked, so § 4.2 cannot stand in for this step. Since then the link is Blizzard's `addon` link type (`addon:WhatGroup:show`), heard through `EventRegistry` rather than through a `SetItemRef` post-hook ([data-flow.md](./data-flow.md)).

1. Join a real group through the Group Finder, as in § 5.1, with `/wg debug on`. Leave the join's chat notification in scrollback.
2. Close the popup (Close or **ESC**).
3. Click `[Click here to view details]` in **that** notification, the real join's, not a `/wg test` one.
4. Close the popup, then **shift-click** the same link. Do it once with the chat edit box closed and once with it open (press **Enter** first).

**Expected:**
- Step 3: the popup re-opens with the real group's data. No ItemRef tooltip opens and no Lua error appears.
- Step 4: the popup re-opens the same way. Nothing is inserted into the chat edit box, and no tooltip or error appears.
- The console logs `[ChatLink] clicked hasPending=true` for each click.
- If the popup does not open, record whether the console shows a `[ChatLink]` line at all. No line means the click never reached the addon.

### 5.2 Multiple concurrent applications

Tests the `capturesByResult[searchResultID]` + `pendingApplications[appID]` pairing. This is the step that
only ever meant anything with **more than one** application outstanding: with one, every possible pairing is
the right one. It is also the check that a decline leaves nothing behind — the pairing used to be positional,
so a capture that never got an invite sat in the tables until group-leave.

1. `/wg debug on`.
2. Apply to **two** group-finder listings in quick succession — different dungeons or activities if you can,
   so the two titles are told apart at a glance.
3. Let both resolve, one **accepted** and one **declined**, in either order. If you can arrange for the
   decline to land first, do — that is the ordering the old code got wrong.
4. Repeat with three listings if two of them are easy to come by.

**Expected:**
- The chat notification and popup name the group you actually joined — not the first applied, not the
  most-recent applied, and not the other one of the pair.
- The console shows one `[LFG] dropped the capture for appID=<N> (declined)` line for the declined
  application, at the moment it is declined rather than at group-leave.
- The remaining captures are wiped at `inviteaccepted`.

**Fail:** the two swap, or the declined application's group is the one that surfaces.

### 5.3 Group leave

1. Right-click your portrait → **Leave Group**, or `/leavegroup`.

**Expected debug trace in the console:**

```
<ts> | [Roster] inGroup=false wasInGroup=true hasPending=true
```

`/wg show` after leaving prints "No group info available. …" — `pendingInfo` is cleared on leave, by design.

### 5.4 Master enable gate

1. `/wg set enabled false`
2. Apply to a group.

**Expected:** `ApplyToGroup` hook still fires and the debug line still prints, but `OnApplyToGroup` returns immediately at the `enabled` check — no capture, no `pendingInfo`, no chat / popup on join.

3. `/wg set enabled true` to restore.

---

## 6. Persistence smoke (~30 sec)

1. `/wg set notify.delay 4.5`
2. `/reload`
3. `/wg get notify.delay`

**Expected:** `notify.delay = 4.5s`. AceDB persisted the value across reload.

4. Log out completely, log back in on a **different character**.
5. `/wg get notify.delay`

**Expected:** Still `4.5s`. WhatGroup uses a single account-shared profile (`AceDB:New("WhatGroupDB", defaults, true)` — third arg `true`).

6. `/wg set notify.delay 0` to restore the default.

---

## 7. Patch-day smoke (~5 min)

Run after bumping the `## Interface:` line in `WhatGroup.toc` for a major patch.

1. Log in on the patched client.

**Expected:** No "out of date" warning in the AddOns dialog.

2. Run section 1 (Boot smoke).
3. Run section 4 (Synthetic flow — `/wg test`).
4. Run section 5.1 (Real LFG flow, single application).

If any Blizzard API broke (e.g. fields renamed on `C_LFGList.GetActivityInfoTable`), the most likely failure point is `CaptureGroupInfo` returning incomplete data — see [data-flow.md → Captured info](./data-flow.md#captured-info) for the field list and remediation steps.

### 7a · `Compat.IsSpellKnown` — do the two readers agree? (`WHATGROUP-R-06`)

`Compat.IsSpellKnown` asks `C_SpellBook.IsSpellKnown` first, falls back to the `IsSpellKnown` global, and answers `false` when neither exists. The first rung was added on 2026-09-12 from Blizzard's generated API documentation, not from a client: `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua` on the `live` branch of Gethe/wow-ui-source, commit `8ea15b61` (12.1.0, build 69587), documents `C_SpellBook.IsSpellKnown(spellID, spellBank = "Player") -> isKnown`. This step is the in-client check the rung shipped without. It confirms the two readers agree, so the fallback really is a fallback and not a different answer. [compat-layer.md](./compat-layer.md) has the reasoning.

Why it matters: the shim answers with whichever reader it reaches first, and on today's client that is `C_SpellBook.IsSpellKnown`. If it says `false` for a teleport the global calls learned, that teleport draws desaturated in the popup with `Teleport spell not learned` beside it (section 4.1b), and the chat summary tags the row `(not learned)`. No headless case can catch this, because the mock answers whatever the test tells it to.

1. Pick a teleport you have learned and one you have not, and note both spell IDs.
2. `/dump C_SpellBook.IsSpellKnown(<the learned one>)` then `/dump IsSpellKnown(<the same>)`.
3. Repeat both for the one you have not learned.

**Pass** — both calls resolve and agree: `true` for the learned spell and `false` for the unlearned one. Write down the client build (`/dump GetBuildInfo()`) and the two spell IDs on issue #15. A bare "it worked" is not evidence.

**Fail** — `C_SpellBook.IsSpellKnown` errors, which means it is not on this client and the shim is running on the global alone. Or the two answers disagree. A disagreement means the rung the shim asks first gives a different answer from its fallback, and that needs a decision about which reader is right, not a fallback ladder. Record both readings on issue #15, and treat the popup's learned and not-learned states as suspect until the decision is made.

Re-run on patch day, and on any day the popup starts calling learned teleports unlearned.

**Status: not yet run.** The owner accepted shipping the rung unconfirmed on 2026-09-12. Session 6 (section 12b, step 5) is the login scheduled to run it.

---

## 8. Lib-refresh smoke (~2 min)

Run after re-copying `libs/` (see [common-tasks.md → Refresh embedded libs](./common-tasks.md#refresh-embedded-libs)).

1. `/reload` — confirm no boot errors.
2. `/wg config` — confirm AceGUI widgets render normally.
3. `/wg test` — confirm the pipeline still works end-to-end.

If a new Ace3 module was added or removed in KickCD, also update `WhatGroup.toc`'s lib block to match the directory layout. AceGUI's `.xml` always loads last because it pulls in `widgets/`; `LibKa0s.xml` loads after it.

After a **LibKa0s** re-vendor specifically, also run sections 10, 11 and 12 — the three things no headless suite can reach.

---

## 9. LibKa0s degraded-install smoke (~3 min)

The six seam files (`core/CoreSetup.lua`, `core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua`) each fall back when their major is absent. The headless suite drives that by loading with the files omitted; only the client can prove a *real* broken install behaves.

1. Quit the game. Rename `Interface/AddOns/WhatGroup/libs/LibKa0s` to `libs/LibKa0s.off`.
2. Launch, log in.
3. `/wg list`
4. `/wg config`
5. `/wg config` again
6. `/wg debug on`
7. `/wg debug`
8. `/wg debug`

**Expected:**

- **Zero Lua errors**, at load and at every step. This is the whole point — a missing library must degrade, not error.
- Step 3 prints a **complete** listing of every setting. The schema loads whole even with the library gone; anything short here means a page file touched a helper at file load and took rows with it (options-ui-§1).
- Every notice is one line, tagged `[WG]`, and every one of them **starts with the same sentence**: *"The LibKa0s library is missing from this installation of Ka0s WhatGroup (expected in libs/LibKa0s)"*. Only the tail differs — `…; running on reduced built-in fallbacks.` from the printer, `…, so the settings panel is unavailable.` from steps 4/5, `…, so the debug console window is unavailable.` from steps 6–8, `…, so the settings CLI is unavailable.` from a schema verb.
- **Counted, not glanced at:** the printer's notice appears **exactly once** for the whole session. The settings notice appears **twice** — once at login, once for the first `/wg config` — and **not** on the second `/wg config`. The console notice appears **twice** — once for `/wg debug on`, once for the first bare `/wg debug` — and not on the second.
- `/wg debug on` still reports the flag flipping. The flag is this addon's; only the *window* is lost.

Rename the folder back and `/reload` before doing anything else.

---

## 10. The `L` trap — no raw keys on screen (~2 min)

Every module that takes an `L` override resolves the descriptor's table first. Hand one an addon-wide locale table — whose metatable answers every key with the key itself — and the library's own English is never reached, so the UI renders `CHECKBOX_LABEL`, `ERR_BOOL`, `LIST_HEADER` and friends. It fails for every string at once, and **only in game**: a synthesized value is still a string, so no headless case sees it. The source guard and the rendered assertions in `tests/test_libka0s.lua` are both blind to what the client actually draws.

1. `/wg config` — read the landing page top to bottom, then the **General** page top to bottom — every tab in the strip, every widget label, every tooltip (hover each), the tab labels themselves and the **Defaults** button. There are no section headings any more; the strip carries those names.
2. `/wg debug` — read the console: its title, the `Debug: ON`/`Debug: OFF` toggle, the `Copy` and `Clear` buttons, the `N / 1500 lines` counter. Click **Copy** and read that window's title too.
3. `/wg help`, then `/wg list`, then `/wg set notify.showLeader nonsense`.

**Expected:** not one `SCREAMING_SNAKE_CASE` string anywhere. Every label is prose. If you see one, a descriptor was handed `NS.L`.

---

## 11. Post-adoption parity — nothing moved (~4 min)

Framed as *"nothing moved"*: anything that looks different from the previous build is the finding. Two exceptions are **expected** and listed below.

1. `/wg config` — the landing page. Logo, the one-line notes, the **Slash Commands** heading, then one row per command.
   **Expected:** rows read `/wg <verb> — <description>` with a **single** space either side of the dash. They used to have double spaces and a white-colored dash; that change is deliberate (the panel and `/wg help` now share one formatter). Everything else about the page is unchanged.
2. **General** page. A **Master controls | Chat | Popup** tab strip, the canonical block on the first tab, the delay slider now under **Chat → Timing**, the **Test** button under the Chat rows, **Defaults** top-right.
   **Expected:** the first tab is the change, not a finding. What must be identical to the previous build is every stored value that already existed: `enabled`, `notify.*` and `frame.*` did not move paths, so a carried-over profile opens with every setting where the player left it. Five keys are **new** and arrive at their defaults — `visibility`, `scale`, `alpha`, `locked` and the session-only `state.debugConsole` — so `/wg list` prints more than it did. The Debug console checkbox's **tooltip wording** comes from the library and differs — also expected.
3. Drag the **Notification Delay** slider and watch the value.
   **Expected:** the stored value commits when you **release**, not on every frame of the drag. Re-open the page and confirm it kept what you released on.
4. Click **Defaults** → confirm → check that every setting is back to default.
5. `/wg resetall` → confirm.
   **Expected:** the *same* confirmation popup as step 4, and the same result. Both entry points must reach it — a suite that only clicks the button proves nothing about the verb.
6. `/wg reset` with no argument.
   **Expected:** a deprecation notice naming `/wg reset <path>` and `/wg resetall`. **Nothing is reset.**
7. `/wg reset notify.delay`.
   **Expected:** that one row goes back to its default, no confirmation, and nothing else moves.
8. `/wg test` to open the popup, and `/wg debug` to open the console. Put them side by side.
   **Expected:** both wear the **same** window edge — a hard 1px **black** outer border with a lighter gray line just inside it. The popup's border was gray and had no inner line before; that change is deliberate (both windows now read from the shared Ka0s skin). The console's border was a 12px tooltip frame; it is now the same 1px double edge.
9. Drag the **popup** somewhere, `/reload`, `/wg show`.
   **Expected:** it is where you left it.
10. Drag the **console** somewhere, `/reload`, `/wg debug`.
    **Expected:** it is back at its default position. The console no longer remembers where you put it — the library owns that window and offers no geometry hook. Deliberate, recorded at [`LIBKA0S-05`](https://github.com/tusharsaxena/WhatGroup/issues/11); it is a **known loss**, not a regression to file.

---

## 12. Shared art — the marks, and the two ways they vanish (~3 min)

`LibKa0s-Media-1.0` ships the icon catalog and JetBrains Mono inside the library payload, and
`core/MediaSetup.lua` tells the library which addon folder to build a texture path from. **Nothing
out of game can see any of this.** A texture path that is never built, or is built wrong, produces a
control that draws nothing and raises nothing: lint is silent, all 528 headless cases stay green,
and the only witness is a person looking at two windows side by side. That is the whole reason this
section exists.

| # | Step | Expect |
|---|------|--------|
| 12.1 | `/wg debug` | The console title bar's three right-hand controls are **small square marks, not words**: copy, clear and close, drawn in the same gray as every other Ka0s window's and turning red under the pointer. **A regression looks like the words `Copy` and `Clear` beside a multiplication sign `×`** — that is the library falling back, and it means `addonName` stopped being passed in the descriptor at `core/DebugLogSetup.lua`. |
| 12.2 | With the console open, click the copy control | The copy window opens, and **its** close control is the same square mark. A `×` here alone means the copy window is being built without the folder name while the console is not — the two come from the same descriptor key, so they should never disagree. |
| 12.3 | Read the log text | Monospace, with the `HH:MM:SS \| [tag] …` columns aligned. It is the **library's** JetBrains Mono now, at `libs/LibKa0s/media/fonts/`, not a copy under this addon's `media/`. A proportional face here means `NS.MediaFont` answered nil and the `STANDARD_TEXT_FONT` fallback caught it — readable, and wrong. |
| 12.4 | `/wg test`, then look at the popup's footer | The **Close** button keeps its word and gains a small close mark to its left, the pair centered together. The word must not disappear: this is a wide action button, not a title-bar target. If the mark is missing and the word is centered on its own, `NS.Icon("close")` answered nil and the button correctly fell back to what it always drew. |
| 12.5 | Settings → any Ka0s addon's font dropdown | `JetBrains Mono` appears in the list. It is registered by `Media.RegisterLSM(addonName)` at file load, once, pointing at one set of bytes — so **every** Ka0s addon offering the dropdown shows the same entry rather than several that merely share a name. |
| 12.6 | Open a second Ka0s addon's debug console beside this one | The two title bars are indistinguishable: same marks, same size, same pitch, same gray. Any difference between them is the defect this whole section is for. |

**After renaming `libs/LibKa0s` away (section 9), re-check 12.1 and 12.4:** the console's controls go
back to `Copy`, `Clear` and `×`, and the footer button back to the plain word `Close`. That is
correct — the art is inside the payload that is missing. What must **not** happen is a blank control,
an error, or a console that refuses to open.

## 12a. The pooled tab strip (~3 min)

**Smoke, session 3 of the 2026-09-07 remediation plan. NOT YET RUN.** New with `M4-01`'s LibKa0s
v1.27.0 re-vendor. `TabStrip` (`libs/LibKa0s/OptionsWidgets.lua`) no longer builds a button and a
content panel per click: it acquires both from per-`ctx` `LibKa0s-Pool-1.0` pools and re-dresses
them, re-setting `OnClick` on every dress. Its only headless proof counts `CreateFrame` calls on a
second selection pass, and the case that would pin band geometry as invariant under selection cannot
be written yet — the shared mock answers `GetHeight` with 0 for every frame, and that flips at kit
16, not here. **So a stale label, a mis-anchored button or a band that changed height on a
re-dressed tab is invisible to every automated check in this repo.** This addon hands its whole
strip to `RenderTabbedSchema` and measures no band of its own, which is exactly why it can say
nothing about one out of game.

| # | Step | Expect |
|---|------|--------|
| 12a.1 | `/wg config`, then cycle every tab of the strip three times, ending back on the first | Each tab shows **its own** label on all three passes. A label carried over from the previously-dressed tab is the pool handing back a frame it did not finish dressing. |
| 12a.2 | Watch the selection highlight as you go | The highlighted tab is the one you pressed, every time. A highlight on the wrong button means `OnClick` was not re-set on the dress. |
| 12a.3 | Watch the strip's band height across all three passes | It does not move. A band that grows or shrinks between passes is the geometry case the kit's geometry flip (revision 18 at the earliest) will be able to assert and revision 17 cannot. |
| 12a.4 | Watch the body under the strip | It is always the selected tab's rows. A body drawn under the wrong tab means the pooled content panel came back still parented to the previous selection. |
| 12a.5 | `Esc`, then `/wg config` again, and walk the strip once more | The same three things hold on a fresh build. The pools are per-`ctx`, so a second build is where a released frame can come back dressed for a different tab. |

`LibKa0s-Perf-1.0` minor 8 arrived in the same payload and respells five player-facing strings.
`Perf` is not wired in this addon, so none of them has a surface here.

---

## 12b. Non-English client (~10 min, session 6)

**Session 6 of the 2026-09-07 remediation plan, owned by `M5-08`. NOT YET RUN — no WoW client was
available when it landed. Nothing in this section has been performed and no step in it is recorded
as passed.** Run on a client set to **deDE or frFR**, the two the collection's other locale steps
use (`ConsumableMaster/docs/smoke-tests.md` § 3c, `KickCD/docs/smoke-tests.md` § 9b).

**This section and § 7a are one login.** Session 6 schedules both, and § 7a — the in-client check
that `C_SpellBook.IsSpellKnown` and the `IsSpellKnown` global agree, which the rung built from the
API documentation has never had — has waited through five milestones for want of somebody being in
a client at the time. Step 5 below is where it gets run.

**What this addon reads in the player's language.** Nearly everything it puts on screen about a
group:

- **`info.fullName`** and **`info.shortName`** from `C_LFGList.GetActivityInfoTable`
  (`core/Compat.lua:136-141`, stored at `core/WhatGroup.lua:343`, drawn at `modules/Frame.lua:768`
  and in the chat summary at `core/WhatGroup.lua:548`). German activity names are materially longer
  than English ones.
- **`info.playstyleString`**, which the server renders in the player's language, preferred over the
  enum lookup by `Labels.GetPlaystyleLabel` (`core/WhatGroup.lua:496-501`).
- **`GROUP_FINDER_GENERAL_PLAYSTYLE1` … `4`**, read into `Labels.PLAYSTYLE` at **file load time**
  (`core/WhatGroup.lua:469-474`). A global that is nil at load leaves that label nil for the whole
  session — there is no second read.
- **`Compat.GetSpellName`** (`core/Compat.lua:27-38`), whose return goes straight into the teleport
  button's `/cast` macrotext (`modules/Frame.lua:351`, built at `:463`). Casting by name only works
  when the name is the client's own, which is what makes this locale-independent by construction —
  and is therefore worth confirming rather than assuming.

What the addon **prints itself** — every `NS.L` label, the group-type words, the chat banner — is
English on every client. That is the addon's scope and not a defect. § 10 (the `L` trap) is the check
that they render as prose rather than as keys, and it is unrelated to this section.

**`/wg test` will not do for most of this.** Its fixture spells the activity name out in English
(`core/WhatGroup.lua:909`), so on a German client it is *expected* to show English. Use a real group
for steps 1 to 3.

1. **A real application, with a real German activity name.** Apply to a group through the LFG UI
   and let the popup appear (section 5.1's flow).
   **Expected:** the **Instance** field shows the client's own name for the activity, the **Type**
   field shows a short name or the group-type label, and the **Playstyle** row shows the server's
   own wording. No field shows `Unknown` where the client plainly has a name.
   **Fail:** `Unknown` in the Instance row — `fullName` came back empty on this locale and the
   `activityName` fallback at `core/WhatGroup.lua:343` did not cover it. Also fail: a name that
   renders as mojibake or `?` glyphs, which is the text not surviving the trip to the font.
2. **Field width.** Read the popup with that longer name in it, and check the chat summary line too.
   **Expected:** the name fits its row or is truncated cleanly at the field's edge.
   **Fail:** text overrunning the popup's border, overlapping the next field, or pushing the frame
   wider than the screen. German activity names are the longest the client produces, and this is the
   only place anything will notice.
3. **Playstyle, including the load-time capture.** With the popup up, run
   `/dump GROUP_FINDER_GENERAL_PLAYSTYLE1` and the same for `2`, `3` and `4`.
   **Expected:** four non-empty strings in the client's language, and a Playstyle row that reads as
   words rather than a number or a blank.
   **Fail:** any of the four nil. `Labels.PLAYSTYLE` is built once at file load, so a nil there is
   nil for the session and the enum fallback silently renders nothing for that playstyle — visible
   only when a group with that playstyle turns up, which may not be this login. Record which ones
   came back nil either way.
4. **The teleport button casts by the client's own name.** With a popup up for an instance whose
   teleport you have learned, hover the teleport button and then click it (section 4.1's flow).
   **Expected:** the tooltip is the German spell tooltip, and the click casts the teleport. The
   macrotext is `/cast ` plus whatever `C_Spell.GetSpellName` returned, so the name in it is the
   client's own.
   **Fail:** a click that does nothing while the button is drawn as ready. That means the macrotext
   holds a name this client does not answer to, which on this locale would mean `GetSpellName`
   returned an English name from somewhere — the one thing that would prove the shim is not reading
   the client's string table.
5. **Run § 7a now — this is the login it has been waiting for.** Follow § 7a as written:
   `/dump C_SpellBook.IsSpellKnown(<a teleport you have learned>)` and
   `/dump IsSpellKnown(<the same spell>)`, then both again for one you have **not** learned.

   **Record all six of these, in issue #15 and in the session-6 result:**

   ```
   client build (/dump GetBuildInfo()):
   client locale (/dump GetLocale()):
   learned spellID:            C_SpellBook.IsSpellKnown = ___   IsSpellKnown = ___
   unlearned spellID:          C_SpellBook.IsSpellKnown = ___   IsSpellKnown = ___
   did C_SpellBook.IsSpellKnown exist at all? (yes / no, it errored)
   ```

   **Pass** — both APIs resolve and agree on both spells. That confirms the `C_SpellBook.IsSpellKnown`
   rung `core/Compat.lua` already carries, which was built from Blizzard's API documentation and
   shipped without this reading (`WHATGROUP-R-06`).
   **Fail** — either call errors, or the two disagree. A disagreement means the rung the shim asks
   first and its fallback are not interchangeable, and the shim needs a decision about which one is
   right rather than a fallback ladder; record what you saw on issue #15. Both outcomes close
   session 6's obligation — one confirms the rung, the other files a finding against it — and a
   blank is the only result that does not.

   The locale is not incidental to this step. `GetLocale()` is recorded because "both APIs present"
   is a claim about a client build, and the one this observation is finally made on should be
   written down rather than assumed to be the English one somebody imagined.

6. **Nothing else moved.** Run section 1 (boot), section 4 (`/wg test`) and section 5.1 once on this
   client.
   **Expected:** identical behavior to English throughout.
   **Fail:** any Lua error, which here means a localized string reached something that assumed an
   English one.

**Sign-off without a non-English client.** There is none, for any step. `tests/wow_mock.lua` answers
enUS for every string the capture path reads, `tests/test_capture.lua` and `tests/test_labels.lua`
assert against those English values, and the `/wg test` fixture is English by construction — so the
suite is green on all of it whether it is right or wrong. Step 5 in particular can only be answered
in a client, which is why the rung `WHATGROUP-R-06` added is still unconfirmed. Until the pass runs, the
honest state of this section is unrun, and it is recorded that way rather than as coverage.

---

## 13. Quick reference checklist

For a fast pre-release pass, run at minimum:

- [ ] section 1.3 — ESC → Logout after `/reload`
- [ ] section 1.3 — ESC → Logout after `/wg test`
- [ ] section 1.3 — ESC → Logout after `/wg config`
- [ ] sections 2.1, 2.10, 2.12, 2.13 — `/wg help`, `/wg test`, `/wg config`, `/wg reset`
- [ ] section 3.4 — Defaults button confirm flow
- [ ] section 3.8 — the visibility gate follows a combat transition, in both directions, with no taint line
- [ ] section 4.1 — Click teleport button (no taint)
- [ ] section 4.1a — Teleport on cooldown: swipe, ticking note, and a click that casts nothing
- [ ] section 4.1b — Teleport not learned: the note says so, and never says cooldown
- [ ] section 5.1 — One real LFG apply → join
- [ ] section 5.1a — that join's details link opens the popup, by click and by shift-click
- [ ] section 10 — no `SCREAMING_SNAKE` string on any page, in the console, or in chat
- [ ] sections 11.5 / 11.6 — `/wg resetall` confirms, and a bare `/wg reset` does not reset
- [ ] sections 12.1 / 12.4 — marks on the console title bar, and a mark **beside** the footer Close word
- [ ] section 12a — the tab strip's labels, selection and band height survive three passes
- [ ] section 12b — the non-English-client pass, which is also the only login § 7a will get

Run section 9 (degraded install), section 12 (shared art), section 12a (the pooled tab strip) and the rest of section 11 after a LibKa0s re-vendor or any change to the six seam files.

Section 7a has **never been run**. Session 6 (section 12b, step 5) is where it is scheduled, and section 12b carries the block to record its six readings in. `core/Compat.lua`'s `IsSpellKnown` shim already asks `C_SpellBook.IsSpellKnown` first. That rung was built from Blizzard's API documentation, and until someone runs § 7a on a live client, nobody has seen the two readers agree.

If all of those pass, the addon is in shippable shape for the 80% case. Run the full suite for releases tagged with feature work.
