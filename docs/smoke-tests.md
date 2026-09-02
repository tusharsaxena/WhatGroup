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
| 2.8d | With debug on: `/wg resetall` → **Yes** | Console shows **one** coalesced `[Reset] active profile reset to defaults` line — **not** one `[Set]` per row. |
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

**Expected:** Popup re-opens with the same data.

### 4.3 ESC closes popup

1. Press **ESC** with the popup focused.

**Expected:** Popup hides. ESC menu does **not** open (because `WhatGroupFrame` is in `UISpecialFrames`).

### 4.4 Drag-to-reposition

1. Drag the popup from its title bar.

**Expected:** Whole popup including the teleport button moves. Dropping near a screen edge clamps without going off-screen.

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
<ts> | [Init] WhatGroup v1.3.0, schema v1, profile 'Default' (enabled=true, notify.delay=0s, autoShow=true, inGroup=false, hasPending=false)
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

### 5.2 Multiple concurrent applications

Tests the FIFO `captureQueue` + `pendingApplications[appID]` pairing.

1. Apply to 3 groups in quick succession (different dungeons / activities if possible).
2. Wait for an invite from one of them.
3. Accept.

**Expected:** The chat notification + popup show the **specific** group you joined (not the first or most-recent applied). The other two captures are wiped at `inviteaccepted`.

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

---

## 13. Quick reference checklist

For a fast pre-release pass, run at minimum:

- [ ] section 1.3 — ESC → Logout after `/reload`
- [ ] section 1.3 — ESC → Logout after `/wg test`
- [ ] section 1.3 — ESC → Logout after `/wg config`
- [ ] sections 2.1, 2.10, 2.12, 2.13 — `/wg help`, `/wg test`, `/wg config`, `/wg reset`
- [ ] section 3.4 — Defaults button confirm flow
- [ ] section 4.1 — Click teleport button (no taint)
- [ ] section 4.1a — Teleport on cooldown: swipe, ticking note, and a click that casts nothing
- [ ] section 4.1b — Teleport not learned: the note says so, and never says cooldown
- [ ] section 5.1 — One real LFG apply → join
- [ ] section 10 — no `SCREAMING_SNAKE` string on any page, in the console, or in chat
- [ ] sections 11.5 / 11.6 — `/wg resetall` confirms, and a bare `/wg reset` does not reset
- [ ] sections 12.1 / 12.4 — marks on the console title bar, and a mark **beside** the footer Close word

Run section 9 (degraded install), section 12 (shared art) and the rest of section 11 after a LibKa0s re-vendor or any change to the six seam files.

If all of those pass, the addon is in shippable shape for the 80% case. Run the full suite for releases tagged with feature work.
