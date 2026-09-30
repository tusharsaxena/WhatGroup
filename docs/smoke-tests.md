# Smoke tests — Ka0s WhatGroup

These are the in-client checks the headless suite cannot make: AceGUI rendering, the secure teleport
button, taint, combat lockdown, what the client's own strings look like, and art that draws nothing
when it is wrong. `lua tests/run.lua` and `luacheck .` cover the logic ([testing.md](./testing.md)).
Start each session from a `/reload` with the settings at their defaults (`/wg resetall` → **Yes**)
and run with BugGrabber installed or `/console scriptErrors 1` set, or a taint check cannot fail
visibly. Turn debug logging on (`/wg debug on`) only where a step says so; it is session-only and
off after every `/reload`. Record each check on its `Result:` line (pass, or what you saw, plus the
date and client build). IDs are `<THEME>-<n>`, stable across edits: a retired check keeps its
number out of use rather than handing it to a new one.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1 – INSTALL-5 | [Install](#install) | Cold load, `/reload`, the GameMenu Logout taint check, patch day |
| SLASH-1 – SLASH-12 | [Slash commands](#slash-commands) | Help, alias, the schema CLI, reset verbs, `show` with nothing captured |
| PANEL-1 – PANEL-19 | [Settings panel](#settings-panel) | Landing page, the General tab strip, widgets, Defaults, the frame rows, raw-key trap, the pooled strip |
| PROFILE-1 – PROFILE-14 | [Profiles](#profiles) | The Profiles page, `/wg profile`, persistence, what a switch leaves alone, the page in combat |
| STATE-1 – STATE-8 | [Enable and disable](#enable-and-disable) | The stand-down, refusals while disabled, the way back, the chat-link callback |
| COMBAT-1 – COMBAT-12 | [Combat](#combat) | Reset popup and Settings registration in combat, Close and ESC in combat, the visibility gate on combat edges |
| POPUP-1 – POPUP-8 | [The popup](#the-popup) | `/wg test notify`, reopening, the chat link, ESC, drag, position, the window chrome |
| TEST-1 – TEST-11 | [Test mode](#test-mode) | The sample popup, its checkbox and verb, and every way it ends |
| TELE-1 – TELE-6 | [The teleport button](#the-teleport-button) | Casting, not learned, the cooldown display and its ticker |
| LFG-1 – LFG-4 | [Real Group Finder flow](#real-group-finder-flow) | A real application, its details link, concurrent applications, leaving |
| LAUNCH-1 – LAUNCH-13 | [The launcher](#the-launcher) | The AddOns icon, the minimap button, its menu and tooltip, broker displays |
| DIAG-1 – DIAG-33 | [Debug console and diagnostics](#debug-console-and-diagnostics) | The console window, logging, the buffer, shared art, `/wg diagnostics` and the logging it turns on, resizing the console and its copy window, the console's Diagnostics link, the library's own lines in the console |
| DEGRADED-1 – DEGRADED-5 | [Library-absent install](#library-absent-install) | Running with `libs/LibKa0s` missing |
| LOC-1 – LOC-6 | [Non-English client](#non-english-client) | A deDE or frFR client, and the `IsSpellKnown` readers |

## Before you start

- **Tools.** A training dummy to start and end combat on demand; a Mythic+ teleport you have
  learned and one you have not (`/wg test notify` uses Windrunner Spire, `Path of the Windrunners`);
  a second character on the same account; for the LFG theme, a live Group Finder.
- **When to run what.**

  | Occasion | Run |
  |---|---|
  | A non-trivial commit | The theme the change touches, plus INSTALL-3 and INSTALL-4 when it touches hooks, the popup, the panel or the StaticPopup table |
  | An `## Interface:` bump | INSTALL-1 to INSTALL-5, COMBAT-1, COMBAT-2, POPUP-1, POPUP-3 to POPUP-5, TELE-1 to TELE-4, TELE-6, COMBAT-6 to COMBAT-10, COMBAT-12, LFG-1 and LOC-5. If a Blizzard API broke, [data-flow.md → Captured info](./data-flow.md#captured-info) lists every field the capture reads |
  | A `libs/` refresh | INSTALL-2, PANEL-1, PANEL-2, POPUP-1. If an Ace3 module was added or removed, match `WhatGroup.toc`'s lib block to the folders (AceGUI's `.xml` loads last among Ace3, `LibKa0s.xml` after it) |
  | A LibKa0s re-vendor, or a change to a seam file | The row above, plus PANEL-4, PANEL-5, PANEL-14 to PANEL-19, SLASH-9 to SLASH-11, POPUP-6 to POPUP-8, DIAG-11 to DIAG-16, DIAG-19, DIAG-25 to DIAG-33 and all of DEGRADED |
  | A release | The release pass below; the whole suite for a release carrying feature work |

- **Release pass.** INSTALL-3, INSTALL-4, COMBAT-2, SLASH-1, SLASH-2, SLASH-9, SLASH-11, PANEL-5,
  PANEL-14 to PANEL-19, PROFILE-3, PROFILE-4, PROFILE-6, POPUP-1, POPUP-7, COMBAT-7, COMBAT-9 to
  COMBAT-11, TEST-2, TEST-6, TEST-7, TELE-1 to TELE-4, LFG-1, LFG-2, STATE-7, STATE-8, LAUNCH-2 to
  LAUNCH-4, LAUNCH-11, DIAG-5, DIAG-12, DIAG-17 to DIAG-22, and the whole non-English pass, LOC-1
  to LOC-6.
  These run on every release, signed off or not.

## Install

- **INSTALL-1. Cold load.** Quit the game completely, launch, log in to any character and open
  chat → no Lua error and no `[WG]` debug chatter: logging is off by default and nothing routes
  to the console until `/wg debug on`. Result:
- **INSTALL-2. `/reload` health.** `/reload` and watch chat → no Lua error and no taint warning.
  Result:
- **INSTALL-3. GameMenu Logout on a clean boot (critical).** `/reload`, run nothing, press **ESC**,
  click **Logout**, then cancel the countdown → the countdown starts normally, with no Lua error and
  no `ADDON_ACTION_FORBIDDEN ... 'callback()'` line. `Settings.Register` runs at `OnEnable`, so this
  is the case that proves the login-time registration adds nothing to the secure chain. If it
  fails, see [midnight-quirks.md → Taint propagation in the boot window](./midnight-quirks.md).
  Result:
- **INSTALL-4. GameMenu Logout after each surface (critical).** Repeat INSTALL-3's ESC → Logout →
  cancel after each of these: `/wg test notify`; `/wg config`; `/wg resetall` →
  **Yes** (the lazy `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` write); a click on the popup's
  teleport button; applying to a real Group Finder listing → the same clean countdown every time.
  ESC in combat is COMBAT-7's last step and `/wg disable` + `/wg enable` is STATE-7. Result:
- **INSTALL-5. Patch day.** After bumping `## Interface:` in `WhatGroup.toc`, log in on the patched
  client and open the AddOns list → no "out of date" warning on WhatGroup. Result:

## Slash commands

- **SLASH-1. Help and the long alias.** `/wg help`, then `/whatgroup help` → both print the same
  index, every line tagged `[WG]`: a header `v<version> — slash commands (/whatgroup is an alias
  for /wg)` with **no** trailing colon, then one row per command, fifteen in all, including
  `version`, `profile` and `diagnostics`. Result:
- **SLASH-2. Bare `/wg` and `/wg config`.** `/wg`, close the panel, then `/wg config` → each opens
  Settings on the **Ka0s WhatGroup** landing page with the **General** and **Profiles**
  subcategories visible in the sidebar. No help index prints. Result:
- **SLASH-3. `/wg version`.** → prints `[WG] v<version>` on its own line, matching the TOC's
  `## Version`. Result:
- **SLASH-4. `/wg list`.** → a green **Available settings** header, azure `[section]` group
  headers, and each row as `key = value` with a gold key and white value. Result:
- **SLASH-5. `/wg get enabled`.** → `enabled = true`, gold key and white value. Result:
- **SLASH-6. `/wg set` a number.** `/wg set notify.delay 2.5`, then `/wg get notify.delay` → both
  print `notify.delay = 2.5s`. `/wg reset notify.delay` afterwards. Result:
- **SLASH-7. `/wg set` toggle.** `/wg set notify.enabled toggle`, `/wg get notify.enabled`, then
  the toggle again → the value flips each time and ends where it started. Result:
- **SLASH-8. An enum refuses a bad value.** `/wg set visibility nonsense` → refused, naming the
  four legal values; `/wg get visibility` is unchanged. Result:
- **SLASH-9. Bare `/wg reset` resets nothing.** `/wg set notify.delay 3`, then `/wg reset` with no
  argument → three lines: `/wg reset now takes a setting PATH.`, how to reset one setting
  (`/wg reset <path>`), and how to reset everything (`/wg resetall` or the **Defaults** button).
  `/wg get notify.delay` still reads `3.0s`. Result:
- **SLASH-10. `/wg reset <path>`.** With `notify.delay` at 3, `/wg reset notify.delay` → that row
  goes back to its default with no confirmation, and nothing else moves (`/wg list`). Result:
- **SLASH-11. `/wg resetall`.** Change two settings, then `/wg resetall` → the same confirmation
  popup the **Defaults** button raises (PANEL-5). **No** changes nothing; **Yes** puts every
  setting back to its default. Result:
- **SLASH-12. `/wg show` with nothing captured.** After a `/reload`, before any group or test,
  `/wg show` → `No group info available. Use /wg test to preview.` and no popup. Result:

## Settings panel

- **PANEL-1. Landing page.** `/wg config` → the logo renders, the one-line notes are visible, then
  a **Slash Commands** heading and one row per command, each `/wg <verb> — <description>` with a
  single space either side of the dash. The scrollbar is visible, grayed when the content fits.
  Result:
- **PANEL-2. General page layout.** Click **General** in the sidebar → a tab strip reading
  **Master controls | Chat | Popup**, left to right, with **Master controls** selected and drawn as
  the disabled (current) tab; a two-column grid under it and no group headings; **Defaults** in
  the top-right corner; hovering any widget shows its tooltip. **Master controls** reads, in order,
  *Enable WhatGroup | General visibility*, *Master scale | Master alpha*, *Lock frame | Debug
  console*, *Minimap button | Test mode*, then the **Reset position | Reset all settings** buttons.
  **Chat**: a **Timing** heading over *Notification Delay* alone, a **Text** heading over *Print to
  Chat* alone, then *Instance | Type*, *Leader | Playstyle*, *Details link | Teleport spell*, then
  the **Test** button. **Popup**: a **Behavior** heading over *Open Automatically* alone, then a
  **Layout** heading over *Width | Height*. Each tab swaps the content rather than scrolling;
  clicking the current tab does nothing; the **Test** button shows on Chat only and the reset pair
  on Master controls only. Result:
- **PANEL-3. Widget and CLI round-trip.** **Popup** → untick *Open Automatically*; **Chat** →
  slide *Notification Delay* to 3.0s; close Settings. `/wg get frame.autoShow` → `false`;
  `/wg get notify.delay` → `3.0s`. Reopen the Popup tab, then `/wg set frame.autoShow on` with it
  open → the checkbox ticks in place, without a rebuild. Restore both. Result:
- **PANEL-4. A slider commits on release.** Drag *Notification Delay* slowly and watch the value
  → the stored value changes when you release, not on every frame of the drag. Reopen the page: it
  kept what you released on. Result:
- **PANEL-5. Defaults button.** Open **General** for the first time this session → the
  **Defaults** button appears a frame after the page, styled like every other button on it (a red
  stone Blizzard button means it was built before a UI skin hooked AceGUI). Change several
  settings, click **Defaults**, then **Yes** → every changed widget snaps back, `/wg list` shows
  defaults, and chat prints `[WG] all settings reset to defaults`. Result:
- **PANEL-6. Test button.** **Chat** tab → **Test** → the same chat summary and popup as
  `/wg test notify` (POPUP-1); the button runs `WhatGroup:RunTest()`. Result:
- **PANEL-7. Popup size defaults and live resize.** On a profile that never touched them, the
  **Popup** tab reads **Width** `420 px` and **Height** `260 px`. `/wg test notify`, leave the popup
  open, drag **Width** to 600 and release, then **Height** to 340 → the open popup resizes on
  release, its rows and teleport button stay anchored to its corners, and the Close button stays
  12px off the bottom edge. Result:
- **PANEL-8. Popup size clamps.** `/wg set frame.width 4000`, `/wg show` → drawn 700 wide, not off
  screen; `/wg set frame.height 10` → drawn 200 high. `/wg reset frame.width` and
  `/wg reset frame.height` → back to 420 × 260. Result:
- **PANEL-9. Master scale.** With the popup open, **Master scale** → 1.5 → the popup grows at once
  and `/wg get scale` reads `1.5`. `/wg set scale 40` → drawn at 2×, not 40×. `/wg set scale 1`.
  Result:
- **PANEL-10. Master alpha.** **Master alpha** → 40% → the popup fades at once. Restore 100%, pull
  a dummy, then `/wg set alpha 0.4` (the slider sits under the combat cover, COMBAT-4) → the popup
  fades in combat too, unlike scale. Drop combat and `/wg set alpha 1`. Result:
- **PANEL-11. Lock frame.** Drag the popup by its title bar, tick **Lock frame**, drag again → the
  first drag moves it, the second does nothing, and the same holds with **Test mode** ticked.
  Untick both; dragging works again. Result:
- **PANEL-12. Reset position.** Drag the popup somewhere odd, click **Reset position** → it jumps
  back to the shipped anchor (centered, raised a quarter of the screen). `/reload`, `/wg show` → it
  is still there, because the stored point was dropped too. Result:
- **PANEL-13. General visibility: Never.** Set *Never*, `/wg show` → nothing opens and nothing
  errors; `/wg test notify` prints the chat summary and shows no popup. Set *Always*, open the
  popup, then set *Never* with it open → it closes on the spot. Restore *Always*. Result:
- **PANEL-14. No raw keys on screen.** Read the landing page and every tab of **General**: every
  label, every tooltip (hover each), the tab labels and the **Defaults** button. `/wg debug`: the
  title, the `Debug: ON`/`OFF` toggle, the copy and clear controls, the `N / 3000 lines` counter,
  and the copy window's title; `/wg diagnostics` and its chat line. `/wg help`, `/wg list`,
  `/wg set notify.showLeader nonsense`, `/wg profile` → not one `SCREAMING_SNAKE_CASE` string
  anywhere. One means a library descriptor was handed `NS.L`, whose fallback answers every key
  with itself. Result:
- **PANEL-15. Pooled tab strip: labels.** `/wg config` → **General**, then cycle every tab three
  times, ending on the first → each tab shows its own label on every pass; a label carried over
  from another tab is a pooled button handed back half-dressed. Result:
- **PANEL-16. Pooled tab strip: selection.** During PANEL-15, watch the highlight → it is on the
  tab you pressed every time; a highlight on another button means `OnClick` was not re-set. Result:
- **PANEL-17. Pooled tab strip: band height.** During PANEL-15, watch the strip's band → its height
  never changes between passes. No headless case can pin this yet (the shared mock answers
  `GetHeight` with 0). Result:
- **PANEL-18. Pooled tab strip: body.** During PANEL-15, watch the content under the strip → it is
  always the selected tab's rows, never a panel still parented to the previous selection. Result:
- **PANEL-19. Pooled tab strip: a fresh build.** **ESC**, `/wg config` again, walk the strip once
  more → PANEL-15 to PANEL-18 hold on the second build, where a released frame can come back
  dressed for another tab. Result:

## Profiles

Setup: on the Profiles page create `Alt` (creating a profile switches to it) and set its
**Popup** width to 600; create `My Main` (with the space); then choose `Default` again.

- **PROFILE-1. The Profiles page.** Settings → AddOns → **Ka0s WhatGroup** → **Profiles** → it is
  the last subcategory, below **General**; it has no **Defaults** button; its body is Ace's
  profile controls and nothing else, each under Ace's own line of explanation: **Reset Profile**,
  `Current Profile: Default` on a fresh install, **New**, **Existing Profiles**, **Copy From** and
  **Delete a Profile**. **Existing Profiles** also offers this character's, realm's and class's
  profile names beside `Default`, as Ace always does. Result:
- **PROFILE-2. A switch on the page.** With `/wg debug on` and the popup open (`/wg test notify`),
  choose `Alt` on the Profiles page → the popup resizes to 600 wide, **General** → **Popup** reads
  600, and the console shows one `[Profile] switched to 'Alt'` line and no `[Set]` line. Result:
- **PROFILE-3. `/wg profile` lists.** `/wg profile` → a green `Profiles` header with no trailing
  colon, one indented row per profile sorted ignoring case (`Alt`, `Default`, `My Main`), the
  current one suffixed `(current)`, then `/wg profile <name> switches profile`. Result:
- **PROFILE-4. `/wg profile <name>` switches.** With `/wg debug on` and **General** → **Popup**
  open, `/wg profile Default` → `Switched to profile 'Default'.`; the open page re-reads its
  widgets at once (width 420); the Profiles page names `Default` as current; the console shows one
  `[Profile] switched to 'Default'` line and nothing from the verb itself. Result:
- **PROFILE-5. The current profile.** `/wg profile Default` again → `Already on profile
  'Default'.` and no `[Profile]` line. Result:
- **PROFILE-6. An unknown name is refused.** `/wg profile alt` → `No profile named 'alt'.`, then
  `Did you mean 'Alt'?`, then the list. `/wg profile Nope` → the refusal and the list with no
  did-you-mean. Open the Profiles page's profile dropdown → no `alt` and no `Nope`: a typo never
  creates a profile. Result:
- **PROFILE-7. Quotes and spaces.** `/wg profile "My Main"` → `Switched to profile 'My Main'.`;
  `/wg profile 'My Main'` and `/wg profile My Main` → `Already on profile 'My Main'.`. Result:
- **PROFILE-8. While disabled.** On `My Main`, `/wg disable`, then `/wg profile` → it lists with no
  disabled refusal. `/wg profile Alt` (whose *Enable WhatGroup* is still ticked) → it switches and
  the addon is running again with no `/wg enable` and no reload: `/wg show` answers normally and
  the Master controls checkbox reads ticked. `/wg profile "My Main"` → the addon stands down
  again. `/wg enable` afterwards. Result:
- **PROFILE-9. Not in combat.** Pull a dummy, then `/wg profile Alt` → `Can't switch profiles
  in combat.` and nothing switches (`/wg profile` still lists, with the same profile current).
  Result:
- **PROFILE-10. Settings persist.** `/wg profile Default`, `/wg set notify.delay 4.5`, `/reload`,
  `/wg get notify.delay` → `4.5s`. Log in on a second character on `Default` (the Profiles page
  names it) → still `4.5s`; switch that character to `Alt` → `Alt`'s own value. `/wg reset
  notify.delay` on `Default` afterwards. Result:
- **PROFILE-11. The popup position is account-wide.** Drag the popup to a corner, then
  `/wg profile Alt`, `/wg show` → the popup is where you left it: its position is
  `db.global.windows`, not a profile row. Result:
- **PROFILE-12. Copy and reset on the page.** With `/wg debug on`, on `Alt`, **Copy From**
  `Default` → one `[Set] copied profile 'Default' → 'Alt'` line and `Alt` now reads `Default`'s
  values. **Reset Profile** → one `[Set] reset profile 'Alt' to defaults` line, and the General
  widgets read defaults. Result:
- **PROFILE-13. Reset all settings touches one profile.** `/wg profile Default`,
  `/wg set notify.delay 2`; `/wg profile Alt`, `/wg set notify.delay 4`, then `/wg resetall` →
  **Yes** → `Alt` reads `0.0s`. `/wg profile Default` → still `2.0s`, and `/wg profile` lists the
  same three profiles. `/wg reset notify.delay` afterwards. Result:
- **PROFILE-14. The Profiles page in combat.** Open Settings → AddOns → **Ka0s WhatGroup** →
  **General**, pull a dummy, then click **Profiles** in the sidebar (the route that reaches it
  mid-fight; `/wg config` is refused, COMBAT-3) → the page is covered (*Settings are locked during
  combat.*), clicking its dropdowns and buttons does nothing, no profile changes, and at most one
  gray `settings are locked during combat` line prints for the fight. Drop combat with the page
  open → the cover lifts and the profile controls answer again, naming the current profile.
  Result:

## Enable and disable

- **STATE-1. Disabled is inert, not quiet.** `/wg set enabled false`, apply to a Group Finder
  listing and join → no capture, no chat summary, no popup. Still disabled, start and end combat,
  then join and leave a group → nothing appears, nothing is logged under `/wg debug on`, and no
  error names WhatGroup: the event registrations are gone, not gated. `/wg set enabled true`.
  Result:
- **STATE-2. Feature verbs refuse.** `/wg disable`, then `/wg show`, `/wg test on`,
  `/wg test notify` → each answers exactly one `[WG] Ka0s WhatGroup is disabled — enable it with
  /wg enable` line and does nothing else: no popup, no chat summary, and the *Test mode* checkbox
  stays unticked. Result:
- **STATE-3. Everything else answers while disabled.** Still disabled: `/wg help`, `/wg version`,
  `/wg list`, `/wg get enabled`, `/wg set notify.delay 2`, `/wg reset notify.delay`, `/wg debug`,
  `/wg profile` and a bare `/wg` → each answers normally and none is refused. `/wg help` prints
  the refusal line once, unindented, straight under its header, as a note on the index: the
  header, that line, then all fifteen rows. No other command here prints it. Result:
- **STATE-4. The Test button while disabled.** Still disabled, **Chat** tab → **Test** → it
  previews as usual; it is the panel route that replaced `/wg test notify`'s old master-switch
  bypass. Result:
- **STATE-5. A typo while disabled.** Still disabled, `/wg shwo` → `unknown command 'shwo'`, then
  the help index with the refusal line under its header (as in STATE-3); never the refusal line
  alone. Result:
- **STATE-6. The way back.** Still disabled, **Popup** → drag *Width* to 600, then `/wg enable` and
  `/wg test notify` → it acts at once with no reload, and the popup opens 600 wide, the width you
  set while off. `/wg reset frame.width`. Result:
- **STATE-7. The chat-link callback comes back without taint (critical).** `/wg disable`,
  `/wg enable`, then ESC → **Logout** and cancel → no `ADDON_ACTION_FORBIDDEN` or
  `ADDON_ACTION_BLOCKED` naming WhatGroup, and the countdown starts normally. If it fails, the
  re-registration in `NS.StandUp` is the cause: revert it and record a slash-commands-§7 row
  under `docs/ARCHITECTURE.md` → `## Documented deviations`. Result:
- **STATE-8. The chat-link callback goes away.** `/wg test notify` (or a real join), click the
  summary's `[Click here to view details]` → the popup opens. Close it, `/wg disable`, click the
  same link → nothing: no popup, no hint, no error. `/wg enable`. Result:

## Combat

- **COMBAT-1. The reset popup in and out of combat (critical).** `/reload`, so nothing has raised
  the popup this session. Pull a dummy and, in combat, `/wg resetall` → **Yes**. The verb is not
  combat-refused, so this first raise makes `Settings.EnsureResetPopup`'s one `StaticPopupDialogs`
  write happen in combat (the **Defaults** button sits under the combat cover, COMBAT-4). Drop
  combat, then **General** → **Defaults** → **Yes** → the popup shows and accepts both times. Out
  of combat, ESC → **Logout** → cancel → no "Interface action failed because of an AddOn" and no
  `ADDON_ACTION_FORBIDDEN` at any step. `Settings.EnsureResetPopup` writes one key into
  `StaticPopupDialogs` and never assigns the table itself. Result:
- **COMBAT-2. A `/reload` in combat registers Settings at combat end.** Pull a dummy, `/reload`
  mid-fight, and open Settings → AddOns while still in combat → **Ka0s WhatGroup** is missing.
  Leave combat and look again without running `/wg config` → it is there, with its **General**
  and **Profiles** subcategories. ESC → **Logout** → cancel → no Lua error and no taint line. Result:
- **COMBAT-3. `/wg config` in combat.** Pull a dummy, `/wg config` → a gray `[WG] cannot open
  settings during combat — Blizzard's category-switch is protected` and no panel. Result:
- **COMBAT-4. The panel locks in combat.** Open **General**, pull a dummy, then click any widget →
  the page is covered (*Settings are locked during combat.*), the click does nothing, and at most
  one gray `settings are locked during combat — changes are refused until it ends` line prints
  for the whole fight. Result:
- **COMBAT-5. Size and scale wait for combat end.** With the popup open, pull a dummy, then
  `/wg set frame.width 500` and `/wg set scale 1.5` (a CLI write is not combat-locked; the
  **Master scale** slider sits under the combat cover) → the open popup neither resizes nor
  rescales, with no error and no "action blocked". Drop combat, `/wg show` → width 500 and scale
  1.5 apply. `/wg reset frame.width` and `/wg set scale 1`. Result:
- **COMBAT-6. Close works in combat.** `/wg test notify`, pull a dummy, press **Close** → the popup
  goes at once, with no error and no chat line. Drop combat → it stays gone. Until combat ends the
  frame is invisible but present (alpha 0), so its title bar still drags; that is known and
  accepted. Result:
- **COMBAT-7. ESC works in combat (critical).** `/wg test notify`, pull a dummy, press **ESC** →
  the popup closes at once, the game menu does **not** open, and nothing in BugGrabber names
  WhatGroup (no `ADDON_ACTION_BLOCKED` on `WhatGroupFrame:Hide()`). Press **ESC** again in combat →
  the game menu opens; close it. Drop combat → the popup is really gone (its area catches no
  clicks) and does not spring back. Pull and drop combat again → still closed. Then ESC →
  **Logout** → cancel → no `ADDON_ACTION_FORBIDDEN`. Result:
- **COMBAT-8. A dismissed popup stays dismissed.** *General visibility* = *Always* (the default).
  `/wg test notify`, **Close**, pull a dummy, drop combat → the popup stays closed throughout.
  Repeat, closing with **ESC** instead → the same: ESC reaches the popup through the
  `WhatGroupFrameEscape` proxy and is exactly as durable as the button. Result:
- **COMBAT-9. *Only out of combat* follows the pull.** Set it, `/wg test notify`, then pull without
  closing the popup → it goes off screen on the pull, with no taint line. Drop combat → it comes
  back by itself, all six rows still filled in (not "No data"). Result:
- **COMBAT-10. *Only in combat*.** Set it, `/wg test notify` out of combat → the chat summary
  prints and nothing shows; `/wg show` → nothing shows. Pull a dummy → no error; the popup does
  **not** open, because Show is protected in combat and a hidden frame cannot be revealed there
  (a known limitation, [frame.md](./frame.md)). If it does open, record that. If it did not, still
  in combat, `/wg show` → one line, `Popup deferred until combat ends.`, no popup and no error.
  Drop combat → nothing opens (out of combat the gate withholds the deferred show) and no popup is
  left behind. Restore *Always*. Result:
- **COMBAT-11. No capture, no popup on a combat edge.** *Only out of combat* set, `/reload` so
  nothing is captured, then pull and drop combat → nothing opens: an empty popup must never
  appear on a combat edge. Restore *Always*. Result:
- **COMBAT-12. A popup requested in combat is deferred.** With the popup closed, pull a dummy,
  `/wg test notify` → no error and no popup; chat prints the join summary (POPUP-1's eight
  lines), then one more line, `Popup deferred until combat ends.` Drop combat → the popup opens
  now, with that capture. Result:

## The popup

- **POPUP-1. `/wg test notify`.** → with the default toggles, chat prints:

  ```
  [WG] You have joined a group!
  [WG]   - Group: Test Group — Windrunner Spire +12
  [WG]   - Instance: Dungeons > Mythic+ > Windrunner Spire
  [WG]   - Type: Mythic+
  [WG]   - Leader: Testadin-Silvermoon
  [WG]   - Playstyle: Fun (Serious)
  [WG]   - Teleport: [Path of the Windrunners]
  [WG]   - [Click here to view details]
  ```

  The Teleport row adds `(not learned)` or `(on cooldown)` when either applies. The popup shows all
  six rows (Group, Instance, Type, Leader, Playstyle, Teleport); the teleport icon is at full alpha
  when the spell is learned and ready, desaturated at 50% otherwise. Result:
- **POPUP-2. `/wg show` reopens.** Close the popup, `/wg show` → the same popup with the same data.
  Result:
- **POPUP-3. The test link.** Click `[Click here to view details]` in POPUP-1's summary → the popup
  reopens with the same data, with no ItemRef tooltip and no error. A test link does not stand in
  for a real join's (LFG-2). Result:
- **POPUP-4. ESC out of combat.** With the popup open, press **ESC** → the popup closes and the
  game menu does not open. **ESC** again → the game menu opens, because the escape proxy went down
  with the popup. Result:
- **POPUP-5. Drag.** Drag the popup by its title bar → the whole popup, teleport button included,
  moves; dropped near a screen edge it clamps on screen. Result:
- **POPUP-6. The position survives a reload.** Drag it somewhere, `/reload`, `/wg show` → it
  reopens where you left it, not re-centered. Result:
- **POPUP-7. The footer Close button.** → the word `Close` alone, centered, with no mark beside it.
  A mark means something draws `NS.Icon("close")` again, and the `standalone-windows` row in
  `docs/ARCHITECTURE.md` → `## Documented deviations` needs revisiting. Result:
- **POPUP-8. The shared window edge.** Open the popup and the debug console side by side → both
  wear the same edge: a hard 1px black outer border with a lighter gray line inside it. Result:

## Test mode

- **TEST-1. The checkbox at rest.** `/reload`, **Master controls** → *Test mode* is unticked, and
  its tooltip talks about the popup. Result:
- **TEST-2. Ticking it shows the sample.** Tick *Test mode* → the popup opens on the sample group
  (*Test Group — Windrunner Spire +12*), one chat line says test mode is on, and no join summary
  prints. Result:
- **TEST-3. Unticking closes it.** Drag the popup somewhere new, then untick → the popup closes and
  `Test mode off` prints. `/wg test notify` opens it where you left it. Result:
- **TEST-4. The verb.** With the panel open, `/wg test` → the box ticks and the sample opens;
  `/wg test` again → it unticks and closes. `/wg test on` twice leaves it on; `/wg test off` turns
  it off; `/wg test sideways` prints a three-line usage. Result:
- **TEST-5. It overrides the gates.** *General visibility* → *Never* and **Popup** → *Open
  Automatically* off, then tick *Test mode* → the popup opens anyway. Untick and restore both.
  Result:
- **TEST-6. Close and ESC end it.** Tick it, press **Close** → the box unticks. Tick it, press
  **ESC** → the same. Result:
- **TEST-7. A pull ends it.** Tick it and pull a dummy → the popup goes as combat starts, one line
  reads `Test mode off — combat started`, the box is unticked, and there is no
  `ADDON_ACTION_BLOCKED`. Drop combat → it does not come back. Result:
- **TEST-8. Not in combat.** In combat, `/wg test` → one gray `cannot start test mode during
  combat`, no popup, box unticked. Result:
- **TEST-9. `/wg test notify` takes over.** Tick it, then `/wg test notify` → the box unticks and
  the one-shot flow runs: the chat summary, then the popup showing that capture. Result:
- **TEST-10. Resets and reloads end it.** Tick it, `/wg resetall` → **Yes** → test mode ends. Tick
  it, `/reload` → unticked afterwards, and `WhatGroupDB` has no `state` table. Result:
- **TEST-11. A real join during test mode.** Tick it, then join a group through the Group Finder
  → the chat summary prints, the popup keeps the sample, and the box stays ticked. Click the
  summary's details link → the real group's popup replaces the sample and the box unticks. Result:

## The teleport button

- **TELE-1. A learned teleport casts.** With `/wg debug on`, `/wg test notify` (or a real popup)
  for a teleport you know and is ready. Hover the icon, then click → the tooltip shows the spell;
  the cast starts (or fails for zone or combat, which still proves the secure click reached the
  cast); no `ADDON_ACTION_FORBIDDEN`; the console shows exactly one `[Frame] teleport button
  pressed → /cast <Spell> (spellID=<N>, button=<btn>)` line per press. Result:
- **TELE-2. Not learned.** A popup for a teleport you have not learned → the icon is desaturated at
  50% with no swipe; beside it `Teleport spell not learned`, never the cooldown wording; hovering
  shows no tooltip; clicking does nothing, with no error. Result:
- **TELE-3. On cooldown.** Cast `Path of the Windrunners`, then `/wg test notify` → the icon is
  desaturated at 50% under a sweeping cooldown swipe; beside it a dim `On cooldown — 7h 58m 12s`
  that matches the spell tooltip's own remaining time; hovering still shows the tooltip; clicking
  casts nothing and raises nothing; `/wg debug on` shows one `[Frame] teleport on cooldown, <time>
  remaining (spellID=<N>)` line; the chat summary's row is tagged `(on cooldown)` with no figure.
  Result:
- **TELE-4. The countdown ticks once.** With TELE-3's popup open, watch for five seconds → the text
  drops one second per second, smoothly. Close it, wait ten seconds, reopen → it has dropped by
  about ten. Open and close it five times, then leave it open → still one second per second, not
  five (a stacked ticker shows no other way). Result:
- **TELE-5. No ticker behind a hidden popup.** *Only in combat* set, teleport on cooldown,
  `/wg test notify` out of combat so the popup is held off screen. Wait a minute, set *Always*,
  `/wg show` → the time shown has dropped by the real elapsed amount: the ticker arms only on
  `OnShow`, the invariant the `performance-§12` deviation row rests on. Result:
- **TELE-6. The cooldown expires live.** Leave a cooldown popup open across the expiry → the button
  rearms itself: no swipe, no note, full alpha, and a click that casts, with no close and reopen.
  Result:

## Real Group Finder flow

- **LFG-1. A single application.** `/reload`, `/wg debug on`, apply to a Mythic+ or raid listing,
  accept the invite, then open the console with `/wg debug` → after `notify.delay` seconds the
  chat summary and popup show the real group's name, leader and mapID-resolved teleport, and the
  console holds, in roughly this order:

  ```
  [Init] WhatGroup v<ver>, schema v<N>, profile '<name>' (enabled=true, notify.delay=0s, ...)
  [Apply] id=<N> captured "<title>" (activity=<A> map=<M> m+=true)
  [LFG] appID=<N> status=applied
  [LFG] appID=<N> status=invited            (some flows skip this)
  [LFG] appID=<N> status=inviteaccepted
  [Invite] accepted appID=<N> → "<title>" map=<M> (source=fresh)
  [Roster] inGroup=true wasInGroup=false hasPending=true
  [Notify] scheduling in <delay>s (<reason>)
  [Notify] fired
  [Frame] popup shown "<title>" map=<M>
  ```

  Result:
- **LFG-2. The real join's details link.** After LFG-1, close the popup and click that join's own
  `[Click here to view details]` → the popup reopens with the real group's data, no ItemRef tooltip
  and no error. Close it and **shift-click** the link, once with the chat edit box closed and once
  with it open → it reopens the same way and nothing is inserted into the edit box. The console
  logs `[ChatLink] clicked hasPending=true` for each click; if the popup does not open, record
  whether that line appeared at all. Result:
- **LFG-3. Concurrent applications.** `/wg debug on`, apply to two listings (different dungeons)
  in quick succession, and let one be accepted and one declined, the decline first if you can;
  three listings if easy → the summary and popup name the group you joined, not the first or the
  latest applied; the console shows one `[LFG] dropped the capture for appID=<N> (declined)` line
  when the decline lands, not at group leave; the rest are wiped at `inviteaccepted`. Result:
- **LFG-4. Leaving the group.** Leave (portrait → **Leave Group**, or `/leavegroup`) → the console
  shows `[Roster] inGroup=false wasInGroup=true hasPending=true`, and `/wg show` then prints
  `No group info available. …`: the capture is cleared on leave. Result:

## The launcher

- **LAUNCH-1. The AddOns list icon.** ESC → AddOns → the WhatGroup row carries the addon's logo,
  not a bag icon or a blank square. Result:
- **LAUNCH-2. The minimap button draws.** → a round button wearing the same logo. A blank or green
  square means a wrong `.tga` format (regenerate it with layout-§4's recipe). Result:
- **LAUNCH-3. Left-click.** → Settings opens on the landing page, as `/wg config` does. With the
  popup open, the panel opens and the popup stays. Result:
- **LAUNCH-4. Right-click menu and Show window.** Right-click → a menu titled **Ka0s WhatGroup**
  with four checkboxes in order: **Enabled** (ticked), **Locked**, **Test mode**, **Show window**.
  Click **Show window** → the popup opens ("No data" if nothing is captured); reopen the menu → it
  reads ticked; click it again → the popup closes. No error or taint line. Result:
- **LAUNCH-5. Menu: Test mode.** Click **Test mode** → the sample popup opens, chat says what
  `/wg test` says, and the Master controls checkbox follows. Click again to end it. Result:
- **LAUNCH-6. Menu: Locked.** Click **Locked** → chat prints `locked = true`, exactly as
  `/wg set locked toggle` does, and the popup's title bar no longer drags. Click again to unlock.
  Result:
- **LAUNCH-7. Menu: Enabled.** Click **Enabled** → chat prints what `/wg disable` prints and the
  addon stands down. Reopen the menu → **Enabled** is unticked and clickable; **Locked**, **Test
  mode** and **Show window** are grayed, each reading `(enable the addon first)`, and clicking one
  does nothing. Click **Enabled** to switch it back on. Result:
- **LAUNCH-8. Left-click while disabled.** `/wg disable`, left-click the button → the settings
  panel opens as it does when running, and nothing prints. The button stays on the minimap.
  `/wg enable`. Result:
- **LAUNCH-9. Drag it.** Drag the button around the minimap, `/reload` → it comes back where you
  left it (`db.global.minimap`). Result:
- **LAUNCH-10. The Minimap button row.** Untick *Minimap button* on **Master controls** → the button
  goes at once, not at the next reload. Tick it → it returns at the same angle. Result:
- **LAUNCH-11. Hidden survives every reset.** With the button hidden, run in turn: `/wg profile Alt`
  (the profile from the [Profiles](#profiles) setup; create it first if that theme has not run) and
  back, `/wg resetall` → **Yes**, the page's **Defaults**, and **Reset all settings** on
  Master controls → it stays hidden through all of them, and returns at the same angle when you
  tick the row. Result:
- **LAUNCH-12. A broker display.** In Titan Panel, ElvUI data texts or Bazooka, if you run one →
  one entry labeled exactly `Ka0s WhatGroup` in plain text (so it files beside the rest of the
  collection), wearing the same logo, whose left click and right-click menu do what the minimap
  button's do. There is deliberately no addon setting for its visibility. Result:
- **LAUNCH-13. The tooltip.** Hover the button → top to bottom: `Ka0s WhatGroup  v<version>`,
  `Enabled: Yes` (green), `Locked: No`, `Test mode: Off`, `Left-click: Open settings`,
  `Right-click: Options menu`, nothing drawn twice. Tick **Lock frame** and **Test mode** →
  `Locked: Yes`, `Test mode: On`. `/wg disable` → still shows, `Enabled: No` in red, with the same
  two hints. `/wg enable`. Result:

## Debug console and diagnostics

- **DIAG-1. `/wg debug` opens and closes the console.** → a window titled `Ka0s WhatGroup — Debug`,
  700×344 by default, monospace. Again → it closes. The logging state is untouched: the title-bar toggle still
  reads `Debug: OFF`. Result:
- **DIAG-2. `/wg debug on` and `off`.** → each prints `[WG] debug logging ON` / `OFF` with the word
  colored (ON green, OFF red, as on the title-bar toggle) and appends a `[Debug] logging enabled` /
  `disabled` line in the console. `on` also appends one `[Init]` line: `WhatGroup v<ver>, schema
  v<N>, profile '<name>'` and the runtime state (`enabled`, `notify.delay`, `autoShow`, `inGroup`,
  `hasPending`). Result:
- **DIAG-3. The title-bar controls.** Click the `Debug: OFF`/`ON` toggle → it flips logging with
  the same chat line and console line as the verb. The copy control opens a highlight-ready
  plain-text buffer; the clear control empties both views. Result:
- **DIAG-4. Scrollbar and counter.** → a thin scrollbar on the log's right edge and an
  `N / 3000 lines` counter bottom-right, in the log's font. First open must not error: a blank
  toggle or a dead ESC means the initial sync threw. With debug on, write lines until the log
  overflows → the counter climbs and the thumb becomes draggable; dragging it scrolls the log and
  the mouse wheel moves the thumb, top oldest and bottom newest. Clear → `0 / 3000` and a parked,
  gray thumb. On a short log the bar shows but is inert. Result:
- **DIAG-5. The buffer cap.** With debug on, write well past 3000 lines (`/wg diagnostics` run a
  hundred-odd times from a macro) → the counter pins at `3000 / 3000 lines` and the oldest lines
  drop off the top. Copy opens without a hitch and holds exactly the newest 3000 lines, ending on
  the latest report's end marker. Result:
- **DIAG-6. One `[Set]` line per write.** With debug on, `/wg set notify.delay 3` → exactly one
  `[Set] notify.delay = 3` line; `/wg set notify.delay 0` → one more. A Master controls checkbox
  write logs the same single line. The verbs write through the same seam: `/wg disable` → one
  `[Set] enabled = false` line, `/wg enable` → one `[Set] enabled = true`, `/wg test on` → one
  `[Set] state.testMode = true`, and `/wg test off` → one `[Set] state.testMode = false`. Result:
- **DIAG-7. Reset all logs once.** With debug on, `/wg set notify.delay 3`, `/wg resetall` →
  **Yes** → the console closes (it is a session-only row the reset sweeps). Reopen it with
  `/wg debug` → after the `[Set] notify.delay = 3` line, exactly one `[Set] reset profile '<name>'
  to defaults (1 rows)` line, no per-row `[Set]` and no `[Reset]`. A second `/wg resetall` straight
  after reads `(0 rows)`. Result:
- **DIAG-8. The Debug console checkbox shows the window only.** After a login, **Master controls**
  → *Debug console* is unticked. Tick → the window appears; untick → it hides. With
  `/wg debug on` first, tick it → the window shows with no `debug logging` chat line and the header
  still reads `Debug: ON`; untick → logging stays on. Result:
- **DIAG-9. The checkbox follows the window.** With the panel open, close the console with its own
  close control (or ESC), then reopen **Master controls** → the box reads unticked. Result:
- **DIAG-10. The checkbox is session-only.** Tick it, log out fully and back in → unticked. `/wg
  list` shows `state.debugConsole`, but `WhatGroupDB` has no `state` table and no `debug` field.
  Result:
- **DIAG-11. The console forgets its position.** Drag the console somewhere, `/reload`,
  `/wg debug` → it is back at its default position. The library owns the window and offers no
  geometry hook (a known loss, [LIBKA0S-05](https://github.com/tusharsaxena/WhatGroup/issues/11)),
  not a regression. Result:
- **DIAG-12. The title-bar marks.** `/wg debug` → the three right-hand controls are small square
  marks, not words: copy, clear and close, in the same gray as every Ka0s window, red under the
  pointer. The words `Copy` and `Clear` beside a `×` mean the library fell back because
  `addonName` stopped reaching its descriptor in `core/DebugLogSetup.lua`. Result:
- **DIAG-13. The copy window's mark.** Click the copy control → the copy window's close control is
  the same square mark; a `×` here alone means the two windows are built from different
  descriptors. Result:
- **DIAG-14. The log font.** → monospace, with the `HH:MM:SS | [tag] …` columns aligned: the
  library's JetBrains Mono under `libs/LibKa0s/media/fonts/`. A proportional face means
  `NS.MediaFont` answered nil and `STANDARD_TEXT_FONT` caught it. Result:
- **DIAG-15. One shared font entry.** Open any Ka0s addon's font dropdown → `JetBrains Mono` is
  listed once: `Media.RegisterLSM` registers one set of bytes for the whole collection. Result:
- **DIAG-16. Matching consoles.** Open another Ka0s addon's debug console beside this one → the two
  title bars are indistinguishable: same marks, size, pitch and gray. Result:
- **DIAG-17. The report appends.** `/reload`, `/wg debug on`, `/wg test notify`, close the popup,
  then `/wg diagnostics` → the console opens if closed; the `[Test]` and `[Frame]` lines stay above
  `[Diag] ==== Ka0s WhatGroup diagnostics begin ====`; the sections follow in order (identity,
  settings with its `[Set]` rows, registration, group, capture, pending, teleport, popup, launcher)
  and end on `[Diag] ==== Ka0s WhatGroup diagnostics end: N line(s) ====`. Chat prints one line,
  `Diagnostic report written to the debug console: N lines. Use Copy to share it.`, with the same
  N. `enabled = true (true)`, `notify.enabled = true (true)` and `frame.autoShow = true (true)`
  print at their defaults, and no `section <name> failed:` line appears. Result:
- **DIAG-18. The copy holds it clean.** Copy, select all, paste into an editor → the trace, the
  begin marker and the whole report to the end marker, with no `|c`, `|r`, `|T` or `|H` escape.
  Result:
- **DIAG-19. Diagnostics turns logging on for the session.** `/reload` → the title bar reads
  `Debug: OFF`. `/wg diagnostics` → chat prints `[WG] debug logging ON`, then the report's
  line-count line; the console holds `[Debug] logging enabled` and the `[Init]` line just ahead of
  the begin marker, the report's header reads `debug logging: on`, the title bar reads `Debug: ON`,
  and `/wg set notify.delay 2` writes one `[Set]` line. `/wg diagnostics` again → a second full
  report under the first with no second `logging enabled` line. `/reload` → `Debug: OFF` again, and
  `/wg set notify.delay 3` writes nothing; `/wg debug diagnostics` → logging on for the session, the
  same way. `/wg debug off` → logging stops, and nothing turns it back on until the next report or
  `/wg debug on`. `/wg reset notify.delay`. Result:
- **DIAG-20. Both forms, the alias, no short form.** `/wg debug diagnostics`,
  `/whatgroup diagnostics`, `/whatgroup debug diagnostics` → each writes the report. `/wg diag` →
  `unknown command 'diag'` and the help index; `/wg debug diag` → the three-line `debug` usage;
  neither writes a report. Result:
- **DIAG-21. While disabled.** `/wg disable`, then `/wg diagnostics` and `/wg debug diagnostics` →
  both run with no refusal; identity reads `enabled=false stoodDown=true` and names the `disabled`
  hold; capture is the one line `capture: stood down, runtime state released`. `/wg enable`.
  Result:
- **DIAG-22. The report never builds the popup.** `/reload`, `/wg diagnostics` before anything
  opens the popup → `popup: not built` and nothing on screen. `/wg test notify`, close it, run it
  again → `built=true` and a live point. Result:
- **DIAG-23. In combat.** Pull a dummy, `/wg diagnostics` mid-fight; again with a captured group
  whose teleport is on cooldown if you have one → no Lua error and no `ADDON_ACTION_BLOCKED`; the
  header reads combat `true`; a secret or unreadable value prints `<secret>` or `unreadable`; the
  teleport line is `teleport cooldown start=… duration=…` or `teleport cooldown unreadable`.
  Result:
- **DIAG-24. The README steps.** `/reload`, close the console, and follow the README's
  `## Reporting a bug` word for word → every step works as written, and the one Copy holds the
  trace and the whole report. Result:
- **DIAG-25. The console resizes from its grip.** `/wg debug` → a small size grip in the
  bottom-right corner, clear of the `N / 3000 lines` counter. Drag it out on both axes → the window
  follows the pointer; the log reflows to the new width, the scrollbar runs the full new height with
  its thumb resynced, the counter stays bottom-right, and the title-bar controls stay placed. The
  buffer and the scroll position are kept. Result:
- **DIAG-26. The console's minimum holds.** Drag the grip as far up and left as it goes → it stops
  where the title and every title-bar control still fit side by side without overlap, with the
  status bar and a few log lines showing. Result:
- **DIAG-27. The size lasts the session, and only the session.** Resize the console, close it,
  `/wg debug` → it reopens at the size you left it. `/reload`, `/wg debug` → back at 700×344, and
  nothing in `WhatGroupDB` holds a size. Result:
- **DIAG-28. The copy window resizes too.** Click the copy control, then drag the copy window's
  bottom-right grip → it resizes on both axes and the text re-wraps to the new width; it will not
  shrink below 240×140. The scroll bar's down button sits above the grip and takes a click on its
  whole face. Close it and copy again → the same size; after a `/reload` → its default size.
  Result:
- **DIAG-29. Another addon's console is its own.** Resize this console, then open another Ka0s
  addon's debug console → it opens at its own default size; resize it → this one does not move.
  Result:
- **DIAG-30. The Diagnostics link.** `/reload`, `/wg debug` → in the title bar, top left, the word
  `Diagnostics` sits just right of the `Debug: OFF` toggle with a small gap, drawn orange in the same
  plain text as the toggle: no button art, border or background. Hover it → it brightens; move off →
  orange again. Click it → logging turns on first (the toggle reads `Debug: ON`, chat prints
  `[WG] debug logging ON`, the console gains `[Debug] logging enabled` and the `[Init]` line), then
  the diagnostics report is written after them, begin to end marker as in DIAG-17, with the one chat
  line giving its line count. Click it again → the report appends once more, with no second
  `logging enabled` line. Flip the toggle between `ON` and `OFF` → the gap after it holds for either
  word. Drag the grip in as far as it goes (DIAG-26) → the link still fits beside the toggle and the
  title. Result:
- **DIAG-31. A slash refusal shows in the console.** `/wg debug on`, `/wg debug`, then `/wg nope` →
  chat says the command is unknown, as before, and the console gains one line,
  `[Cmd] refused nope: unknown verb`. `/wg disable`, then `/wg show` → chat prints the disabled
  line, and the console gains one `[Cmd] refused show: disabled` line and no second refusal line.
  `/wg enable` afterwards. Result:
- **DIAG-32. A stand-down and a stand-up show in the console, once each.** `/wg debug on`,
  `/wg debug`, then `/wg disable` → the console gains
  `[Lifecycle] stood down: added disabled (holds: disabled)`, before the teardown's own lines, and no
  `[State]` line. `/wg enable` → one `[Lifecycle] stood up: released disabled (holds: none)` line.
  A second `/wg enable` writes no `[Lifecycle]` line. Result:
- **DIAG-33. The launcher's registration lands when logging is turned on.** `/reload`, then
  `/wg debug on`, `/wg debug` → after `[Debug] logging enabled` and the `[Init]` line, the console
  holds one `[Launcher] registered` line. `/wg debug off`, `/wg debug on` → no second
  `[Launcher] registered` line. Result:

## Library-absent install

Quit the game and rename `Interface/AddOns/WhatGroup/libs/LibKa0s` to `libs/LibKa0s.off` first,
and disable every other Ka0s addon on the AddOns list: each ships its own LibKa0s, and LibStub
hands WhatGroup that copy, so nothing here degrades while one of them loads. Rename the folder
back, re-enable the others and `/reload` when done. The ten seam files (`core/CoreSetup.lua`,
`core/Compat.lua`, `core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`,
`core/LauncherSetup.lua`, `core/LifecycleSetup.lua`, `settings/OptionsSetup.lua`,
`settings/SchemaSetup.lua`, `settings/Slash.lua`) each fall back; only a real broken install
proves they do.

- **DEGRADED-1. It loads, and the CLI says it is gone.** Log in, `/wg list` → zero Lua errors at
  load, and `/wg list` prints one `[WG]` line, *The LibKa0s library is missing from this
  installation of Ka0s WhatGroup (expected in libs/LibKa0s), so the settings CLI is unavailable.*,
  not a listing: the schema CLI is the library's. That the schema itself loads whole is headless
  (`tests/test_libka0s.lua` "degraded: every HAND-WRITTEN schema row survives the options
  library's absence (options-ui-§1)"). Result:
- **DEGRADED-2. The notices, counted.** `/wg config` twice, `/wg debug on`, `/wg debug` twice →
  every notice is one `[WG]` line starting *The LibKa0s library is missing from this installation
  of Ka0s WhatGroup (expected in libs/LibKa0s)*, with only the tail differing (reduced built-in
  fallbacks; settings panel unavailable; no minimap button and no broker plugin; debug console
  window unavailable; settings CLI unavailable). The printer's notice appears exactly once per
  session; the launcher notice once, at login; the settings notice twice (login and the first
  `/wg config`, not the second); the console notice twice (`/wg debug on` and the first bare
  `/wg debug`, not the second). Result:
- **DEGRADED-3. The debug flag still flips.** `/wg debug on` → it reports the flag flipping; only
  the window is lost. Result:
- **DEGRADED-4. Library-owned verbs say so.** `/wg disable`, `/wg enable`, `/wg test on`,
  `/wg diagnostics`, `/wg debug diagnostics`, `/wg profile`, `/wg profile Alt` → each prints one
  `[WG] <verb> is unavailable: the LibKa0s library did not load.` line, raises nothing, and moves
  nothing: the addon stays enabled, no popup opens, no report is written, no profile switches.
  The verb named is `/wg disable`, `/wg enable`, `/wg test`, `/wg diagnostics` for both report
  forms, and `/wg profile` for both profile forms. Result:
- **DEGRADED-5. The popup without the art.** `/wg debug` → no console window (the window is the
  library's), and nothing prints once DEGRADED-2 has spent the console notice. `/wg test notify`
  → the chat summary and the popup, whose footer still reads `Close` alone. A blank footer button
  or a Lua error is the failure. Result:

## Non-English client

Run on a client set to **deDE or frFR**, the two locales ConsumableMaster LOC-1 and KickCD LOC-1
use. Nearly everything the addon shows about a group comes from the client in the player's
language: `info.fullName` and `info.shortName` from `C_LFGList.GetActivityInfoTable`,
`info.playstyleString`, the `GROUP_FINDER_GENERAL_PLAYSTYLE1` to `4` globals (read into
`Labels.PLAYSTYLE` once, at file load), and `Compat.GetSpellName`, which goes into the teleport
button's `/cast` macrotext. What the addon prints itself (every `NS.L` label, the banner) is English
on every client, which is its scope and not a defect; PANEL-14 checks those render as prose. The
`/wg test notify` fixture is English by construction, so use a real group. No step here has a
headless stand-in: `tests/wow_mock.lua` answers enUS for every string the capture path reads.

- **LOC-1. A real German or French activity name.** Apply to a group and let the popup appear
  (LFG-1) → the Instance row shows the client's own activity name, Type a short name or the
  group-type label, Playstyle the server's wording. Fail: `Unknown` in Instance (`fullName` came
  back empty and `applyActivityInfo`'s `activityName` fallback missed it), or mojibake or `?`
  glyphs. Result:
- **LOC-2. Field width.** Read the popup and the chat summary with that longer name → it fits its
  row or truncates cleanly at the field's edge. Fail: text over the border, over the next field, or
  a frame pushed wider than the screen. Result:
- **LOC-3. Playstyle, including the load-time read.** With the popup up, `/dump
  GROUP_FINDER_GENERAL_PLAYSTYLE1`, then `2`, `3` and `4` → four non-empty strings in the client's
  language, and a Playstyle row that reads as words. Fail: any nil, which stays nil for the whole
  session; record which. Result:
- **LOC-4. The teleport casts by the client's name.** A popup for a teleport you know: hover, then
  click (TELE-1) → the tooltip is the localized spell tooltip and the click casts. Fail: a click
  that does nothing while the button is drawn ready, meaning the macrotext holds a name this client
  does not answer to. Result:
- **LOC-5. The two `IsSpellKnown` readers agree.** `Compat.IsSpellKnown` asks
  `C_SpellBook.IsSpellKnown` first, then the `IsSpellKnown` global, then answers false; the first
  rung was built from Blizzard's generated API documentation (12.1.0, build 69587) and has never
  been checked in a client. Pick a teleport you know and one you do not. `/dump
  C_SpellBook.IsSpellKnown(<learned>)`, `/dump IsSpellKnown(<learned>)`, then both for the unlearned
  one, and record on issue #15:

  ```
  client build (/dump GetBuildInfo()):
  client locale (/dump GetLocale()):
  learned spellID:            C_SpellBook.IsSpellKnown = ___   IsSpellKnown = ___
  unlearned spellID:          C_SpellBook.IsSpellKnown = ___   IsSpellKnown = ___
  did C_SpellBook.IsSpellKnown exist at all? (yes / no, it errored)
  ```

  → both resolve and agree: true for the learned spell, false for the other. Fail: either call
  errors, or they disagree, which needs a decision about which reader is right; until then the
  popup's learned and not-learned states are suspect (TELE-2). Re-run on patch day and whenever the
  popup calls a learned teleport unlearned. [compat-layer.md](./compat-layer.md) has the reasoning.
  Result:
- **LOC-6. Nothing else moved.** On this client run INSTALL-1 to INSTALL-4, COMBAT-1, COMBAT-2,
  POPUP-1, POPUP-3 to POPUP-5, TELE-1 to TELE-4, TELE-6, COMBAT-6 to COMBAT-10, COMBAT-12 and
  LFG-1 → identical to English. Fail: any Lua error, meaning a localized string reached code that assumed
  an English one. Result:

## Pending sign-off

The old suite recorded no result for any check, so every check carried over from it is owed unless a
Ka0sAddonsCommonTasks plan records the owner's pass. Only the diagnostics rollout's does:
DIAG-5, DIAG-17, DIAG-18 and DIAG-20 to DIAG-24 passed on 2026-09-26 (`2026-09-25-DIAGNOSTICS_COMMAND/99_REPORT.md`
§ 6, WG-S1 to WG-S11 and WG-X1) and are not listed; DIAG-19 passed then too, and is listed again
because its expectation changed on 2026-09-30. Checks new in this rework, and checks whose
expectation it corrected against the code, are listed too. Sign one off on its own `Result:` line,
then remove its row here.

| ID | Origin in the old suite | Owed because |
|---|---|---|
| INSTALL-1 – INSTALL-3 | § 1.1 – 1.3 | No result recorded |
| INSTALL-4 | § 1.3 repeat list | No result recorded; its reset step corrected to `/wg resetall` |
| INSTALL-5 | § 7 step 1 | No result recorded |
| SLASH-1 | § 2.2, 2.3, 2.17 | No result recorded; the index now has fifteen rows, `profile` among them |
| SLASH-2 | § 2.1, 2.12 | No result recorded; now expects the Profiles subcategory |
| SLASH-3 – SLASH-8 | § 2.4 – 2.7, 2.16, 3.7j | No result recorded |
| SLASH-9, SLASH-10 | § 11.6, 11.7 | No result recorded |
| SLASH-11 | § 2.13, 11.5 | No result recorded; § 2.13's bare `/wg reset` corrected to `/wg resetall` |
| SLASH-12 | § 2.9 | No result recorded |
| PANEL-1 – PANEL-13 | § 3.1 – 3.7, 3.9 step 4, 11.1 – 11.4 | No result recorded; PANEL-2's Master controls order and PANEL-10's in-combat step corrected |
| PANEL-14 | § 10 | No result recorded; `/wg profile` added |
| PANEL-15 – PANEL-19 | § 12a.1 – 12a.5 | Never run since the pooled tab strip arrived with LibKa0s v1.27.0 |
| PROFILE-1 – PROFILE-14 | New; PROFILE-10 also carries § 6 | New in this rework (the `profile` verb and the Profiles page) |
| STATE-1, STATE-2, STATE-4, STATE-7, STATE-8 | § 5.4, 5.5 steps 1 – 2 and 4, 5.5a | No result recorded |
| STATE-3, STATE-5 | § 5.5 steps 3 and 6 | No result recorded; corrected: `/wg help` prints the refusal line under its header while disabled |
| STATE-6 | § 5.5 step 7 | No result recorded; the change made while off is now Popup Width |
| COMBAT-1 | § 1.4 | No result recorded; the in-combat raise is now `/wg resetall` |
| COMBAT-2 | § 1.5 | No result recorded; now expects the Profiles subcategory |
| COMBAT-3, COMBAT-4, COMBAT-6 – COMBAT-9, COMBAT-11 | § 2.15, 3.8, 3.9 step 8, 4.3a, 4.5 steps 1 – 6, 4.6 steps 1 – 4 | No result recorded |
| COMBAT-5 | § 3.5a step 5, 3.7c | No result recorded; the in-combat change is now `/wg set` |
| COMBAT-10 | § 3.7h, 3.8 step 4, 4.5 step 9, 4.6 steps 5 – 6 | No result recorded; the pull's expectation corrected per frame.md |
| COMBAT-12 | § 4.5 steps 7 – 8 | No result recorded; corrected: the join summary prints before the deferred line |
| POPUP-1 – POPUP-8 | § 2.10, 2.11, 2.18, 4, 4.2 – 4.4, 11.8, 11.9, 12.4 | No result recorded |
| TEST-1 – TEST-11 | § 2.10a, 3.9 | No result recorded |
| TELE-1 – TELE-6 | § 3.8 "Also here", 4.1, 4.1a, 4.1b | No result recorded |
| LFG-1 – LFG-4 | § 5.1 – 5.3 | No result recorded |
| LAUNCH-1 – LAUNCH-10, LAUNCH-12, LAUNCH-13 | § 5.5 step 5, 12c | No result recorded |
| LAUNCH-11 | § 12c.7 | No result recorded; the profile switch is now `/wg profile` |
| DIAG-1 – DIAG-4, DIAG-6 – DIAG-10, DIAG-12 – DIAG-16 | § 2.8 – 2.8b-i, 2.8c, 2.8d, 2.19, 3.6, 12.1 – 12.3, 12.5, 12.6 | No result recorded; DIAG-6 now also logs the verbs' `[Set]` lines |
| DIAG-11 | § 2.18, 11.10 | No result recorded; § 2.18's remembered console position corrected |
| DIAG-19 | New | Passed on 2026-09-26 as "Ungated, flag untouched"; corrected on 2026-09-30: a run now turns logging on for the session (standard v2.71.0, DebugLogDiagnostics 2, DL-WG-03) |
| DIAG-25 – DIAG-29 | New | New with LibKa0s v1.64.0 (the resizable console and copy window) |
| DIAG-30 | New | New on 2026-09-30 with the console's Diagnostics link (LibKa0s v1.64.0, DebugLog 16 and up, DL-WG-03) |
| DIAG-31 – DIAG-33 | New | New on 2026-10-01 with the library's own debug lines (LibKa0s v1.65.0: Slash 18, Lifecycle 3, Launcher 5, DebugLogGates 1; DG-WG-01) |
| DEGRADED-1 – DEGRADED-5 | § 9, 12 closing, 2.19 | No result recorded; corrected: the other Ka0s addons disabled, DEGRADED-1's `/wg list`, DEGRADED-2's launcher notice, DEGRADED-4's `/wg profile` lines, DEGRADED-5's console |
| LOC-1 – LOC-4, LOC-6 | § 12b steps 1 – 4 and 6 | Never run: no non-English client was available when the section landed |
| LOC-5 | § 7a, and § 12b step 5 | Never run; issue #15 waits on the readings |
