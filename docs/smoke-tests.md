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
| PANEL-1 – PANEL-22 | [Settings panel](#settings-panel) | Landing page, the General tab strip, widgets, Defaults, the frame rows, raw-key trap, the pooled strip, the folder name on the Options descriptor, the item 020 layout and wording |
| PROFILE-1 – PROFILE-14 | [Profiles](#profiles) | The Profiles page, `/wg profile`, persistence, what a switch leaves alone, the page in combat |
| STATE-1 – STATE-8 | [Enable and disable](#enable-and-disable) | The stand-down, refusals while disabled, the way back, the chat-link callback |
| COMBAT-1 – COMBAT-14 | [Combat](#combat) | Reset popup and Settings registration in combat, Close and ESC in combat, the visibility gate on combat edges, a soft-hidden popup's mouse-dead controls and its residual |
| POPUP-1 – POPUP-10 | [The popup](#the-popup) | `/wg test notify`, reopening, the chat link, ESC, drag, position, the window chrome, the Role row at the minimum height, the popup's layering, the body-mouse probe |
| TEST-1 – TEST-12 | [Test mode](#test-mode) | The sample popup, its checkbox and verb, every way it ends, the sample role |
| TELE-1 – TELE-6 | [The teleport button](#the-teleport-button) | Casting, not learned, the cooldown display and its ticker |
| LFG-1 – LFG-8 | [Real Group Finder flow](#real-group-finder-flow) | A real application, its details link, concurrent applications, leaving, the signed-up role |
| LAUNCH-1 – LAUNCH-16 | [The launcher](#the-launcher) | The AddOns icon, the minimap button, its menu and tooltip, broker displays, the Show window key binding |
| DIAG-1 – DIAG-33 | [Debug console and diagnostics](#debug-console-and-diagnostics) | The console window, logging, the buffer, shared art, `/wg diagnostics` and the logging it turns on, resizing the console and its copy window, the console's Diagnostics link, the library's own lines in the console |
| SKIN-1 – SKIN-24 | [Skins](#skins) | Ka0s Default as before but for its face, title band and Close button; the Skin tab; each skin live on the popup; the teleport button beside its label; fonts, corners, the settings panel's Scope, the debug console; what stays Blizzard's; EllesmereUI on and off; copy, profiles, combat, the overrides; the first-run skin picker; other addons unchanged; the popup without the library |
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
  | A `libs/` refresh | INSTALL-2, PANEL-1, PANEL-2, POPUP-1. If an Ace3 module was added or removed, match `WhatGroup.toc`'s lib block to the folders (AceConfig's `.xml` must stay below AceGUI's, and `LibKa0s.xml` loads last) |
  | A LibKa0s re-vendor, or a change to a seam file | The row above, plus PANEL-4, PANEL-5, PANEL-14 to PANEL-19, SLASH-9 to SLASH-11, POPUP-6 to POPUP-8, DIAG-11 to DIAG-16, DIAG-19, DIAG-25 to DIAG-33 and all of DEGRADED |
  | A change to the look of a surface, to `core/SkinSetup.lua` or `modules/FrameSkin.lua`, or a re-vendor that moves the Skin major | SKIN-1, SKIN-3, SKIN-4, SKIN-8 and SKIN-10, plus the SKIN checks for what changed |
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
  to the console until `/wg debug on`. Result: pass (owner-marked 2026-10-10)
- **INSTALL-2. `/reload` health.** `/reload` and watch chat → no Lua error and no taint warning.
  Result: pass (owner-marked 2026-10-10)
- **INSTALL-3. GameMenu Logout on a clean boot (critical).** `/reload`, run nothing, press **ESC**,
  click **Logout**, then cancel the countdown → the countdown starts normally, with no Lua error and
  no `ADDON_ACTION_FORBIDDEN ... 'callback()'` line. `Settings.Register` runs at `OnEnable`, so this
  is the case that proves the login-time registration adds nothing to the secure chain. If it
  fails, see [midnight-quirks.md → Taint propagation in the boot window](./midnight-quirks.md).
  Result: pass (owner-marked 2026-10-10)
- **INSTALL-4. GameMenu Logout after each surface (critical).** Repeat INSTALL-3's ESC → Logout →
  cancel after each of these: `/wg test notify`; `/wg config`; `/wg resetall` →
  **Yes** (the lazy `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` write); a click on the popup's
  teleport button; applying to a real Group Finder listing → the same clean countdown every time.
  ESC in combat is COMBAT-7's last step and `/wg disable` + `/wg enable` is STATE-7. Result: pass (owner-marked 2026-10-10)
- **INSTALL-5. Patch day.** After bumping `## Interface:` in `WhatGroup.toc`, log in on the patched
  client and open the AddOns list → no "out of date" warning on WhatGroup. Result: pass (owner-marked 2026-10-10)

## Slash commands

- **SLASH-1. Help and the long alias.** `/wg help`, then `/whatgroup help` → both print the same
  index, every line tagged `[WG]`: a header `v<version> — slash commands (/whatgroup is an alias
  for /wg)` with **no** trailing colon, then one row per command, fifteen in all, including
  `version`, `profile` and `diagnostics`. Result: pass (owner-marked 2026-10-10)
- **SLASH-2. Bare `/wg` and `/wg config`.** `/wg`, close the panel, then `/wg config` → each opens
  Settings on the **Ka0s WhatGroup** landing page with the **General** and **Profiles**
  subcategories visible in the sidebar. No help index prints. Result: pass (owner-marked 2026-10-10)
- **SLASH-3. `/wg version`.** → prints `[WG] v<version>` on its own line, matching the TOC's
  `## Version`. Result: pass (owner-marked 2026-10-10)
- **SLASH-4. `/wg list`.** → a green **Available settings** header, azure `[section]` group
  headers, and each row as `key = value` with a gold key and white value. Result: pass (owner-marked 2026-10-10)
- **SLASH-5. `/wg get enabled`.** → `enabled = true`, gold key and white value. Result: pass (owner-marked 2026-10-10)
- **SLASH-6. `/wg set` a number.** `/wg set notify.delay 2.5`, then `/wg get notify.delay` → both
  print `notify.delay = 2.5s`. `/wg reset notify.delay` afterwards. Result: pass (owner-marked 2026-10-10)
- **SLASH-7. `/wg set` toggle.** `/wg set notify.enabled toggle`, `/wg get notify.enabled`, then
  the toggle again → the value flips each time and ends where it started. Result: pass (owner-marked 2026-10-10)
- **SLASH-8. An enum refuses a bad value.** `/wg set visibility nonsense` → refused, naming the
  four legal values; `/wg get visibility` is unchanged. Result: pass (owner-marked 2026-10-10)
- **SLASH-9. Bare `/wg reset` resets nothing.** `/wg set notify.delay 3`, then `/wg reset` with no
  argument → three lines: `/wg reset now takes a setting PATH.`, how to reset one setting
  (`/wg reset <path>`), and how to reset everything (`/wg resetall` or the **Defaults** button).
  `/wg get notify.delay` still reads `3.0s`. Result: pass (owner-marked 2026-10-10)
- **SLASH-10. `/wg reset <path>`.** With `notify.delay` at 3, `/wg reset notify.delay` → that row
  goes back to its default with no confirmation, and nothing else moves (`/wg list`). Result: pass (owner-marked 2026-10-10)
- **SLASH-11. `/wg resetall`.** Change two settings, then `/wg resetall` → the same confirmation
  popup the **Defaults** button raises (PANEL-5). **No** changes nothing; **Yes** puts every
  setting back to its default. Result: pass (owner-marked 2026-10-10)
- **SLASH-12. `/wg show` with nothing captured.** After a `/reload`, before any group or test,
  `/wg show` → `No group info available. Use /wg test to preview.` and no popup. Result: pass (owner-marked 2026-10-10)

## Settings panel

- **PANEL-1. Landing page.** `/wg config` → the logo renders, the one-line notes are visible, then
  a **Slash Commands** heading and one row per command, each `/wg <verb> — <description>` with a
  single space either side of the dash. The scrollbar is visible, grayed when the content fits.
  Result: pass (owner-marked 2026-10-10)
- **PANEL-2. General page layout (SM-WG-LY).** Click **General** in the sidebar → a tab strip
  reading **Master controls | Notifications | Skin | Keybindings**, left to right, with **Master controls**
  selected and drawn as the disabled (current) tab; a two-column grid under it and no group
  headings; **Defaults** in the top-right corner; hovering any widget shows its tooltip. **Master
  controls** reads, in order, *Enable WhatGroup | General visibility*, *Master scale | Master
  opacity*, *Lock frame | Debug console*, *Minimap button | Test mode*, then the **Reset position |
  Reset all settings** buttons. **Notifications**: a **Timing** heading over *Delay after joining (seconds)*
  alone; a **Chat summary** heading over *Print to chat* alone, then *Instance | Type*, *Leader |
  Role*, *Playstyle | Teleport spell*, *Details link* alone; a **Popup window** heading over *Open on
  join* alone, then *Width (px) | Height (px)*; then the **Test notification** button. No **Chat**, **Popup**,
  **Text**, **Behavior** or **Layout** label is left anywhere. Each tab swaps the content rather
  than scrolling; clicking the current tab does nothing; the **Test notification** button shows on
  Notifications only and the reset pair on Master controls only. **Skin** is the library's tab
  (SKIN-2 walks it). (Amended by WG-05, 2026-10-29, the skinning rollout: the Skin tab; the
  2026-10-24 pass covered three tabs.) Result:
- **PANEL-3. Widget and CLI round-trip.** **Notifications** → untick *Open on join*, then
  slide *Delay after joining (seconds)* to 3.0s; close Settings. `/wg get frame.autoShow` → `false`;
  `/wg get notify.delay` → `3.0s`. Reopen the Notifications tab, then `/wg set frame.autoShow on` with it
  open → the checkbox ticks in place, without a rebuild. Restore both. Result: pass (owner-marked 2026-10-10)
- **PANEL-4. A slider commits on release.** Drag *Delay after joining (seconds)* slowly and watch the value
  → the stored value changes when you release, not on every frame of the drag. Reopen the page: it
  kept what you released on. Result: pass (owner-marked 2026-10-10)
- **PANEL-5. Defaults button.** Open **General** for the first time this session → the
  **Defaults** button appears a frame after the page, styled like every other button on it (a red
  stone Blizzard button means it was built before a UI skin hooked AceGUI). Change several
  settings, click **Defaults**, then **Yes** → every changed widget snaps back, `/wg list` shows
  defaults, and chat prints `[WG] all settings reset to defaults`. Result: pass (owner-marked 2026-10-10)
- **PANEL-6. Test notification button.** **Notifications** tab → **Test notification** → the same chat summary and popup as
  `/wg test notify` (POPUP-1); the button runs `WhatGroup:RunTest()`. Result: pass (owner-marked 2026-10-10)
- **PANEL-7. Popup size defaults and live resize.** On a profile that never touched them, the
  **Notifications** tab reads **Width (px)** `420 px` and **Height (px)** `280 px`. `/wg test notify`, leave the popup
  open, drag **Width (px)** to 600 and release, then **Height (px)** to 340 → the open popup resizes on
  release, its rows and teleport button stay anchored to its corners, and the Close button stays
  12px off the bottom edge. Result: pass (owner-marked 2026-10-10)
- **PANEL-8. Popup size clamps.** `/wg set frame.width 4000`, `/wg show` → drawn 700 wide, not off
  screen; `/wg set frame.height 10` → drawn 200 high. `/wg reset frame.width` and
  `/wg reset frame.height` → back to 420 × 280. Result: pass (owner-marked 2026-10-10)
- **PANEL-9. Master scale.** With the popup open, **Master scale** → 1.5 → the popup grows at once
  and `/wg get scale` reads `1.5`. `/wg set scale 40` → drawn at 2×, not 40×. `/wg set scale 1`.
  Result: pass (owner-marked 2026-10-10)
- **PANEL-10. Master alpha.** **Master alpha** → 40% → the popup fades at once. Restore 100%, pull
  a dummy, then `/wg set alpha 0.4` (the slider sits under the combat cover, COMBAT-4) → the popup
  fades in combat too, unlike scale. Drop combat and `/wg set alpha 1`. Result: pass (owner-marked 2026-10-10)
- **PANEL-11. Lock frame.** Drag the popup by its title bar, tick **Lock frame**, drag again → the
  first drag moves it, the second does nothing, and the same holds with **Test mode** ticked.
  Untick both; dragging works again. Result: pass (owner-marked 2026-10-10)
- **PANEL-12. Reset position.** Drag the popup somewhere odd, click **Reset position** → it jumps
  back to the shipped anchor (centered, raised a quarter of the screen). `/reload`, `/wg show` → it
  is still there, because the stored point was dropped too. Result: pass (owner-marked 2026-10-10)
- **PANEL-13. General visibility: Never.** Set *Never*, `/wg show` → nothing opens and nothing
  errors; `/wg test notify` prints the chat summary and shows no popup. Set *Always*, open the
  popup, then set *Never* with it open → it closes on the spot. Restore *Always*. Result: pass (owner-marked 2026-10-10)
- **PANEL-14. No raw keys on screen.** Read the landing page and every tab of **General**: every
  label, every tooltip (hover each), the tab labels and the **Defaults** button. `/wg debug`: the
  title, the `Debug: ON`/`OFF` toggle, the copy and clear controls, the `N / 3000 lines` counter,
  and the copy window's title; `/wg diagnostics` and its chat line. `/wg help`, `/wg list`,
  `/wg set notify.showLeader nonsense`, `/wg profile` → not one `SCREAMING_SNAKE_CASE` string
  anywhere. One means a library descriptor was handed `NS.L`, whose fallback answers every key
  with itself. Result: pass (owner-marked 2026-10-10)
- **PANEL-15. Pooled tab strip: labels.** `/wg config` → **General**, then cycle every tab three
  times, ending on the first → each tab shows its own label on every pass; a label carried over
  from another tab is a pooled button handed back half-dressed. Result: pass (owner-marked 2026-10-10)
- **PANEL-16. Pooled tab strip: selection.** During PANEL-15, watch the highlight → it is on the
  tab you pressed every time; a highlight on another button means `OnClick` was not re-set. Result: pass (owner-marked 2026-10-10)
- **PANEL-17. Pooled tab strip: band height.** During PANEL-15, watch the strip's band → its height
  never changes between passes. No headless case can pin this yet (the shared mock answers
  `GetHeight` with 0). Result: pass (owner-marked 2026-10-10)
- **PANEL-18. Pooled tab strip: body.** During PANEL-15, watch the content under the strip → it is
  always the selected tab's rows, never a panel still parented to the previous selection. Result: pass (owner-marked 2026-10-10)
- **PANEL-19. Pooled tab strip: a fresh build.** **ESC**, `/wg config` again, walk the strip once
  more → PANEL-15 to PANEL-18 hold on the second build, where a released frame can come back
  dressed for another tab. Result: pass (owner-marked 2026-10-10)
- **PANEL-20. The Options descriptor names the folder.** `/reload`, `/wg debug on`, then `/wg config`
  → no Lua error on load or on open, and the landing page, every **General** tab and the
  **Profiles** page render exactly as before. The console shows no `[Cfg] help art:` line: no list
  in this addon carries help, so the library never asks for the art (LibKa0s#42, CA-WG-NM). Result: pass (owner-marked 2026-10-10)
- **PANEL-21. The item 020 wording, and nothing lost (SM-WG-LY).** Note `/wg list` first. Then on
  **General**: hover **Defaults** → the same words as **Reset all settings**' tooltip (a reset of
  this profile, pointing at Profiles → Reset Profile), then `Key bindings are not changed.`
  Master controls: *General visibility* ends `Here, that is the group info popup.`, *Master scale*
  ends `Scales the group info popup; not changed in combat, applied on the next open.`, *Master
  opacity* ends `Opacity of the group info popup.`, *Lock frame* ends `Stops the group info popup
  being dragged by its title bar.`, and *Test mode* opens with the library's own sentence and ends
  `Untick Lock frame first if you want to move it.` Notifications: *Delay after joining (seconds)* opens
  `Applies to both the chat summary and the popup.`; *Print to chat* ends `The popup always shows
  every line; these choose the chat summary only.`; every line toggle says `chat summary`, never
  `chat notification`; *Width (px)* and *Height (px)* end `Tick Test mode on General > Master controls to
  see the popup while you size it.`; **Test notification**'s tooltip names `/wg test notify` and
  Test mode. Now `/reload` and `/wg list` again → the same paths, in the same sections, with the same
  values as before the change: no setting lost, no key moved, no default changed.
  Result: pass (owner, 2026-10-24)
- **PANEL-22. The landing page's command words (SM-WG-LY).** `/wg config` → the landing list reads
  `/wg show — Show the group info popup again`, `/wg config — Open the Ka0s WhatGroup settings`
  and `/wg resetall — Reset this profile to defaults`; `/wg help` prints the same three lines. The
  verbs themselves act as before. Result: pass (owner, 2026-10-24)

## Profiles

Setup: on the Profiles page create `Alt` (creating a profile switches to it) and set its
**Notifications** → *Width (px)* to 600; create `My Main` (with the space); then choose `Default` again.

- **PROFILE-1. The Profiles page.** Settings → AddOns → **Ka0s WhatGroup** → **Profiles** → it is
  the last subcategory, below **General**; it has no **Defaults** button; its body is Ace's
  profile controls and nothing else, each under Ace's own line of explanation: **Reset Profile**,
  `Current Profile: Default` on a fresh install, **New**, **Existing Profiles**, **Copy From** and
  **Delete a Profile**. **Existing Profiles** also offers this character's, realm's and class's
  profile names beside `Default`, as Ace always does. Result: pass (owner-marked 2026-10-10)
- **PROFILE-2. A switch on the page.** With `/wg debug on` and the popup open (`/wg test notify`),
  choose `Alt` on the Profiles page → the popup resizes to 600 wide, **General** → **Notifications** reads
  600, and the console shows one `[Profile] switched to 'Alt'` line and no `[Set]` line. Result: pass (owner-marked 2026-10-10)
- **PROFILE-3. `/wg profile` lists.** `/wg profile` → a green `Profiles` header with no trailing
  colon, one indented row per profile sorted ignoring case (`Alt`, `Default`, `My Main`), the
  current one suffixed `(current)`, then `/wg profile <name> switches profile`. Result: pass (owner-marked 2026-10-10)
- **PROFILE-4. `/wg profile <name>` switches.** With `/wg debug on` and **General** → **Notifications**
  open, `/wg profile Default` → `Switched to profile 'Default'.`; the open page re-reads its
  widgets at once (width 420); the Profiles page names `Default` as current; the console shows one
  `[Profile] switched to 'Default'` line and nothing from the verb itself. Result: pass (owner-marked 2026-10-10)
- **PROFILE-5. The current profile.** `/wg profile Default` again → `Already on profile
  'Default'.` and no `[Profile]` line. Result: pass (owner-marked 2026-10-10)
- **PROFILE-6. An unknown name is refused.** `/wg profile alt` → `No profile named 'alt'.`, then
  `Did you mean 'Alt'?`, then the list. `/wg profile Nope` → the refusal and the list with no
  did-you-mean. Open the Profiles page's profile dropdown → no `alt` and no `Nope`: a typo never
  creates a profile. Result: pass (owner-marked 2026-10-10)
- **PROFILE-7. Quotes and spaces.** `/wg profile "My Main"` → `Switched to profile 'My Main'.`;
  `/wg profile 'My Main'` and `/wg profile My Main` → `Already on profile 'My Main'.`. Result: pass (owner-marked 2026-10-10)
- **PROFILE-8. While disabled.** On `My Main`, `/wg disable`, then `/wg profile` → it lists with no
  disabled refusal. `/wg profile Alt` (whose *Enable WhatGroup* is still ticked) → it switches and
  the addon is running again with no `/wg enable` and no reload: `/wg show` answers normally and
  the Master controls checkbox reads ticked. `/wg profile "My Main"` → the addon stands down
  again. `/wg enable` afterwards. Result: pass (owner-marked 2026-10-10)
- **PROFILE-9. Not in combat.** Pull a dummy, then `/wg profile Alt` → `Can't switch profiles
  in combat.` and nothing switches (`/wg profile` still lists, with the same profile current).
  Result: pass (owner-marked 2026-10-10)
- **PROFILE-10. Settings persist.** `/wg profile Default`, `/wg set notify.delay 4.5`, `/reload`,
  `/wg get notify.delay` → `4.5s`. Log in on a second character on `Default` (the Profiles page
  names it) → still `4.5s`; switch that character to `Alt` → `Alt`'s own value. `/wg reset
  notify.delay` on `Default` afterwards. Result: pass (owner-marked 2026-10-10)
- **PROFILE-11. The popup position is account-wide.** Drag the popup to a corner, then
  `/wg profile Alt`, `/wg show` → the popup is where you left it: its position is
  `db.global.windows`, not a profile row. Result: pass (owner-marked 2026-10-10)
- **PROFILE-12. Copy and reset on the page.** With `/wg debug on`, on `Alt`, **Copy From**
  `Default` → one `[Set] copied profile 'Default' → 'Alt'` line and `Alt` now reads `Default`'s
  values. **Reset Profile** → one `[Set] reset profile 'Alt' to defaults` line, and the General
  widgets read defaults. Result: pass (owner-marked 2026-10-10)
- **PROFILE-13. Reset all settings touches one profile.** `/wg profile Default`,
  `/wg set notify.delay 2`; `/wg profile Alt`, `/wg set notify.delay 4`, then `/wg resetall` →
  **Yes** → `Alt` reads `0.0s`. `/wg profile Default` → still `2.0s`, and `/wg profile` lists the
  same three profiles. `/wg reset notify.delay` afterwards. Result: pass (owner-marked 2026-10-10)
- **PROFILE-14. The Profiles page in combat.** Open Settings → AddOns → **Ka0s WhatGroup** →
  **General**, pull a dummy, then click **Profiles** in the sidebar (the route that reaches it
  mid-fight; `/wg config` is refused, COMBAT-3) → the page is covered (*Settings are locked during
  combat.*), clicking its dropdowns and buttons does nothing, no profile changes, and at most one
  gray `settings are locked during combat` line prints for the fight. Drop combat with the page
  open → the cover lifts and the profile controls answer again, naming the current profile.
  Result: pass (owner-marked 2026-10-10)

## Enable and disable

- **STATE-1. Disabled is inert, not quiet.** `/wg set enabled false`, apply to a Group Finder
  listing and join → no capture, no chat summary, no popup. Still disabled, start and end combat,
  then join and leave a group → nothing appears, nothing is logged under `/wg debug on`, and no
  error names WhatGroup: the event registrations are gone, not gated. `/wg set enabled true`.
  Result: pass (owner-marked 2026-10-10)
- **STATE-2. Feature verbs refuse.** `/wg disable`, then `/wg show`, `/wg test on`,
  `/wg test notify` → each answers exactly one `[WG] Ka0s WhatGroup is disabled — enable it with
  /wg enable` line and does nothing else: no popup, no chat summary, and the *Test mode* checkbox
  stays unticked. Result: pass (owner-marked 2026-10-10)
- **STATE-3. Everything else answers while disabled.** Still disabled: `/wg help`, `/wg version`,
  `/wg list`, `/wg get enabled`, `/wg set notify.delay 2`, `/wg reset notify.delay`, `/wg debug`,
  `/wg profile` and a bare `/wg` → each answers normally and none is refused. `/wg help` prints
  the refusal line once, unindented, straight under its header, as a note on the index: the
  header, that line, then all fifteen rows. No other command here prints it. Result: pass (owner-marked 2026-10-10)
- **STATE-4. The Test notification button while disabled.** Still disabled, **Notifications** tab → **Test notification** → it
  previews as usual; it is the panel route that replaced `/wg test notify`'s old master-switch
  bypass. Result: pass (owner-marked 2026-10-10)
- **STATE-5. A typo while disabled.** Still disabled, `/wg shwo` → `unknown command 'shwo'`, then
  the help index with the refusal line under its header (as in STATE-3); never the refusal line
  alone. Result: pass (owner-marked 2026-10-10)
- **STATE-6. The way back.** Still disabled, **Notifications** → drag *Width (px)* to 600, then `/wg enable` and
  `/wg test notify` → it acts at once with no reload, and the popup opens 600 wide, the width you
  set while off. `/wg reset frame.width`. Result: pass (owner-marked 2026-10-10)
- **STATE-7. The chat-link callback comes back without taint (critical).** `/wg disable`,
  `/wg enable`, then ESC → **Logout** and cancel → no `ADDON_ACTION_FORBIDDEN` or
  `ADDON_ACTION_BLOCKED` naming WhatGroup, and the countdown starts normally. If it fails, the
  re-registration in `NS.StandUp` is the cause: revert it and record a slash-commands-§7 row
  under `docs/ARCHITECTURE.md` → `## Documented deviations`. Result: pass (owner-marked 2026-10-10)
- **STATE-8. The chat-link callback goes away.** `/wg test notify` (or a real join), click the
  summary's `[Click here to view details]` → the popup opens. Close it, `/wg disable`, click the
  same link → nothing: no popup, no hint, no error. `/wg enable`. Result: pass (owner-marked 2026-10-10)

## Combat

- **COMBAT-1. The reset popup in and out of combat (critical).** `/reload`, so nothing has raised
  the popup this session. Pull a dummy and, in combat, `/wg resetall` → **Yes**. The verb is not
  combat-refused, so this first raise makes `Settings.EnsureResetPopup`'s one `StaticPopupDialogs`
  write happen in combat (the **Defaults** button sits under the combat cover, COMBAT-4). Drop
  combat, then **General** → **Defaults** → **Yes** → the popup shows and accepts both times. Out
  of combat, ESC → **Logout** → cancel → no "Interface action failed because of an AddOn" and no
  `ADDON_ACTION_FORBIDDEN` at any step. `Settings.EnsureResetPopup` writes one key into
  `StaticPopupDialogs` and never assigns the table itself. Result: pass (owner-marked 2026-10-10)
- **COMBAT-2. A `/reload` in combat registers Settings at combat end.** Pull a dummy, `/reload`
  mid-fight, and open Settings → AddOns while still in combat → **Ka0s WhatGroup** is missing.
  Leave combat and look again without running `/wg config` → it is there, with its **General**
  and **Profiles** subcategories. ESC → **Logout** → cancel → no Lua error and no taint line. Result: pass (owner-marked 2026-10-10)
- **COMBAT-3. `/wg config` in combat.** Pull a dummy, `/wg config` → a gray `[WG] cannot open
  settings during combat — Blizzard's category-switch is protected` and no panel. Result: pass (owner-marked 2026-10-10)
- **COMBAT-4. The panel locks in combat.** Open **General**, pull a dummy, then click any widget →
  the page is covered (*Settings are locked during combat.*), the click does nothing, and at most
  one gray `settings are locked during combat — changes are refused until it ends` line prints
  for the whole fight. Result: pass (owner-marked 2026-10-10)
- **COMBAT-5. Size and scale wait for combat end.** With the popup open, pull a dummy, then
  `/wg set frame.width 500` and `/wg set scale 1.5` (a CLI write is not combat-locked; the
  **Master scale** slider sits under the combat cover) → the open popup neither resizes nor
  rescales, with no error and no "action blocked". Drop combat, `/wg show` → width 500 and scale
  1.5 apply. `/wg reset frame.width` and `/wg set scale 1`. Result: pass (owner-marked 2026-10-10)
- **COMBAT-6. Close works in combat.** `/wg test notify`, pull a dummy, press **Close** → the popup
  goes at once, with no error and no chat line. Drop combat → it stays gone. Until combat ends the
  frame is invisible but present (alpha 0); COMBAT-13 checks its controls are mouse-dead.
  Result: pass (owner-marked 2026-10-10)
- **COMBAT-7. ESC works in combat (critical).** `/wg test notify`, pull a dummy, press **ESC** →
  the popup closes at once, the game menu does **not** open, and nothing in BugGrabber names
  WhatGroup (no `ADDON_ACTION_BLOCKED` on `WhatGroupFrame:Hide()`). Press **ESC** again in combat →
  the game menu opens; close it. Drop combat → the popup is really gone (its area catches no
  clicks) and does not spring back. Pull and drop combat again → still closed. Then ESC →
  **Logout** → cancel → no `ADDON_ACTION_FORBIDDEN`. Result: pass (owner-marked 2026-10-10)
- **COMBAT-8. A dismissed popup stays dismissed.** *General visibility* = *Always* (the default).
  `/wg test notify`, **Close**, pull a dummy, drop combat → the popup stays closed throughout.
  Repeat, closing with **ESC** instead → the same: ESC reaches the popup through the
  `WhatGroupFrameEscape` proxy and is exactly as durable as the button. Result: pass (owner-marked 2026-10-10)
- **COMBAT-9. *Only out of combat* follows the pull.** Set it, `/wg test notify`, then pull without
  closing the popup → it goes off screen on the pull, with no taint line. Drop combat → it comes
  back by itself, all seven rows still filled in (not "No data"). Result: pass (owner-marked 2026-10-10)
- **COMBAT-10. *Only in combat*.** Set it, `/wg test notify` out of combat → the chat summary
  prints and nothing shows; `/wg show` → nothing shows. Pull a dummy → no error; the popup does
  **not** open, because Show is protected in combat and a hidden frame cannot be revealed there
  (a known limitation, [frame.md](./frame.md)). If it does open, record that. If it did not, still
  in combat, `/wg show` → one line, `Popup deferred until combat ends.`, no popup and no error.
  Drop combat → nothing opens (out of combat the gate withholds the deferred show) and no popup is
  left behind. Restore *Always*. Result: pass (owner-marked 2026-10-10)
- **COMBAT-11. No capture, no popup on a combat edge.** *Only out of combat* set, `/reload` so
  nothing is captured, then pull and drop combat → nothing opens: an empty popup must never
  appear on a combat edge. Restore *Always*. Result: pass (owner-marked 2026-10-10)
- **COMBAT-12. A popup requested in combat is deferred.** With the popup closed, pull a dummy,
  `/wg test notify` → no error and no popup; chat prints the join summary (POPUP-1's nine
  lines), then one more line, `Popup deferred until combat ends.` Drop combat → the popup opens
  now, with that capture. Result: pass (owner-marked 2026-10-10)
- **COMBAT-13. A soft-hidden popup's controls are mouse-dead (SM-WG-ZS).** `/wg test notify`, pull
  a dummy, press **Close** → the popup goes. Still in combat, drag where its title bar was → nothing
  moves; click where its Close button was → nothing happens and no error. Clicks there do **not**
  reach what is underneath: the popup body and the 24px teleport button still catch clicks while
  soft-hidden, which is the documented residual (`docs/ARCHITECTURE.md`'s register; POPUP-10 is the
  probe that could lift it for the body). Drop combat → the owed Hide lands and clicks there reach
  the world again. Repeat with *General visibility* = *Only out of combat* and the popup up when the
  pull starts → the same. No `ADDON_ACTION_BLOCKED` at any step. Result: pass (owner, 2026-10-24)
- **COMBAT-14. A reopen in combat gives the controls back (SM-WG-ZS).** After COMBAT-13's
  **Close**, still in combat, press the Show window key (or the launcher's Show window) → the popup
  is back and its **Close** button works on the first click. Drop combat → the title bar drags
  again. Result: pass (owner, 2026-10-24)

## The popup

- **POPUP-1. `/wg test notify`.** → with the default toggles, chat prints:

  ```
  [WG] You have joined a group!
  [WG]   - Group: Test Group — Windrunner Spire +12
  [WG]   - Instance: Dungeons > Mythic+ > Windrunner Spire
  [WG]   - Type: Mythic+
  [WG]   - Leader: Testadin-Silvermoon
  [WG]   - Role: <damage icon>Damage
  [WG]   - Playstyle: Fun (Serious)
  [WG]   - Teleport: [Path of the Windrunners]
  [WG]   - [Click here to view details]
  ```

  The Teleport row adds `(not learned)` or `(on cooldown)` when either applies; in a group where the
  leader assigned you a role, Role shows that one instead. The popup shows all seven rows (Group,
  Instance, Type, Leader, Role, Playstyle, Teleport); the teleport icon is at full alpha
  when the spell is learned and ready, desaturated at 50% otherwise. Result: pass (owner-marked 2026-10-10)
- **POPUP-2. `/wg show` reopens.** Close the popup, `/wg show` → the same popup with the same data.
  Result: pass (owner-marked 2026-10-10)
- **POPUP-3. The test link.** Click `[Click here to view details]` in POPUP-1's summary → the popup
  reopens with the same data, with no ItemRef tooltip and no error. A test link does not stand in
  for a real join's (LFG-2). Result: pass (owner-marked 2026-10-10)
- **POPUP-4. ESC out of combat.** With the popup open, press **ESC** → the popup closes and the
  game menu does not open. **ESC** again → the game menu opens, because the escape proxy went down
  with the popup. Result: pass (owner-marked 2026-10-10)
- **POPUP-5. Drag.** Drag the popup by its title bar → the whole popup, teleport button included,
  moves; dropped near a screen edge it clamps on screen. Result: pass (owner-marked 2026-10-10)
- **POPUP-6. The position survives a reload.** Drag it somewhere, `/reload`, `/wg show` → it
  reopens where you left it, not re-centered. Result: pass (owner-marked 2026-10-10)
- **POPUP-7. The footer Close button.** → the word `Close` alone, centered, with no mark beside it.
  A mark means something draws `NS.Icon("close")` again, and the `standalone-windows` row in
  `docs/ARCHITECTURE.md` → `## Documented deviations` needs revisiting. Result: pass (owner-marked 2026-10-10)
- **POPUP-8. The shared window edge.** Open the popup and the debug console side by side → both
  wear the same edge: a hard 1px black outer border with a lighter gray line inside it. Result: pass (owner-marked 2026-10-10)
- **POPUP-9. The Role row at the minimum height.** `/wg set frame.height 200`, `/wg test notify` →
  all seven rows (Group to Teleport, Role fifth) fit above the Close button with nothing clipped or
  overlapping, and the teleport button sits beside the `Teleport:` label. `/wg reset frame.height`
  → the popup is 280 tall again. Result: pass (owner, 2026-10-02)
- **POPUP-10. The popup's layering, and the body-mouse probe (SM-WG-ZS).** Out of combat,
  `/wg test notify`, then click the popup's empty body over a unit or the world → the click stays
  on the popup (the body keeps the mouse); the title bar still drags it and **Close** still closes
  it. Open Settings → **Ka0s WhatGroup** → General, tick *Test mode* → the popup shows over the
  Settings panel and stays over it while you drag the Width slider. Open the debug console
  (`/wg debug`) where it overlaps the popup and click the console → the console comes to the
  front. **Probe (WHA-Z01's condition):** with the popup up, pull a dummy and, in combat, run
  `/run WhatGroupFrame:EnableMouse(false) print(WhatGroupFrame:IsMouseEnabled())`. Record whether
  the call is refused (an `ADDON_ACTION_BLOCKED` / *Interface action failed* in BugGrabber, and
  `true` printed) or not (`false` printed, no error). Drop combat and run
  `/run WhatGroupFrame:EnableMouse(true)` to put the body back. Not refused → the soft hide may take
  the body too (a follow-up change); refused → the residual stands. This is a probe: record what
  it showed, never mark it passed. Result: run (owner, 2026-10-24): reported
  passing; no observation text captured

## Test mode

- **TEST-1. The checkbox at rest.** `/reload`, **Master controls** → *Test mode* is unticked, and
  its tooltip talks about the popup. Result: pass (owner-marked 2026-10-10)
- **TEST-2. Ticking it shows the sample.** Tick *Test mode* → the popup opens on the sample group
  (*Test Group — Windrunner Spire +12*), one chat line says test mode is on, and no join summary
  prints. Result: pass (owner-marked 2026-10-10)
- **TEST-3. Unticking closes it.** Drag the popup somewhere new, then untick → the popup closes and
  `Test mode off` prints. `/wg test notify` opens it where you left it. Result: pass (owner-marked 2026-10-10)
- **TEST-4. The verb.** With the panel open, `/wg test` → the box ticks and the sample opens;
  `/wg test` again → it unticks and closes. `/wg test on` twice leaves it on; `/wg test off` turns
  it off; `/wg test sideways` prints a three-line usage. Result: pass (owner-marked 2026-10-10)
- **TEST-5. It overrides the gates.** *General visibility* → *Never* and **Notifications** → *Open
  on join* off, then tick *Test mode* → the popup opens anyway. Untick and restore both.
  Result: pass (owner-marked 2026-10-10)
- **TEST-6. Close and ESC end it.** Tick it, press **Close** → the box unticks. Tick it, press
  **ESC** → the same. Result: pass (owner-marked 2026-10-10)
- **TEST-7. A pull ends it.** Tick it and pull a dummy → the popup goes as combat starts, one line
  reads `Test mode off — combat started`, the box is unticked, and there is no
  `ADDON_ACTION_BLOCKED`. Drop combat → it does not come back. Result: pass (owner-marked 2026-10-10)
- **TEST-8. Not in combat.** In combat, `/wg test` → one gray `cannot start test mode during
  combat`, no popup, box unticked. Result: pass (owner-marked 2026-10-10)
- **TEST-9. `/wg test notify` takes over.** Tick it, then `/wg test notify` → the box unticks and
  the one-shot flow runs: the chat summary, then the popup showing that capture. Result: pass (owner-marked 2026-10-10)
- **TEST-10. Resets and reloads end it.** Tick it, `/wg resetall` → **Yes** → test mode ends. Tick
  it, `/reload` → unticked afterwards, and `WhatGroupDB` has no `state` table. Result: pass (owner-marked 2026-10-10)
- **TEST-11. A real join during test mode.** Tick it, then join a group through the Group Finder
  → the chat summary prints, the popup keeps the sample, and the box stays ticked. Click the
  summary's details link → the real group's popup replaces the sample and the box unticks. Result: pass (owner-marked 2026-10-10)
- **TEST-12. The sample role.** Out of a group, `/wg test` → the popup's `Role:` row reads the
  damage icon and `Damage`, and `/wg test notify` prints `Role: Damage` in the summary. In a group
  where the leader assigned you a role, the assigned role shows instead. Result: pass (owner, 2026-10-02)

## The teleport button

- **TELE-1. A learned teleport casts.** With `/wg debug on`, `/wg test notify` (or a real popup)
  for a teleport you know and is ready. Hover the icon, then click → the tooltip shows the spell;
  the cast starts (or fails for zone or combat, which still proves the secure click reached the
  cast); no `ADDON_ACTION_FORBIDDEN`; the console shows exactly one `[Frame] teleport button
  pressed → /cast <Spell> (spellID=<N>, button=<btn>)` line per press. Result: pass (owner-marked 2026-10-10)
- **TELE-2. Not learned.** A popup for a teleport you have not learned → the icon is desaturated at
  50% with no swipe; beside it `Teleport spell not learned`, never the cooldown wording; hovering
  shows no tooltip; clicking does nothing, with no error. Result: pass (owner-marked 2026-10-10)
- **TELE-3. On cooldown.** Cast `Path of the Windrunners`, then `/wg test notify` → the icon is
  desaturated at 50% under a sweeping cooldown swipe; beside it a dim `On cooldown — 7h 58m 12s`
  that matches the spell tooltip's own remaining time; hovering still shows the tooltip; clicking
  casts nothing and raises nothing; `/wg debug on` shows one `[Frame] teleport on cooldown, <time>
  remaining (spellID=<N>)` line; the chat summary's row is tagged `(on cooldown)` with no figure.
  Result: pass (owner-marked 2026-10-10)
- **TELE-4. The countdown ticks once.** With TELE-3's popup open, watch for five seconds → the text
  drops one second per second, smoothly. Close it, wait ten seconds, reopen → it has dropped by
  about ten. Open and close it five times, then leave it open → still one second per second, not
  five (a stacked ticker shows no other way). Result: pass (owner-marked 2026-10-10)
- **TELE-5. No ticker behind a hidden popup.** *Only in combat* set, teleport on cooldown,
  `/wg test notify` out of combat so the popup is held off screen. Wait a minute, set *Always*,
  `/wg show` → the time shown has dropped by the real elapsed amount: the ticker arms only on
  `OnShow`, the invariant the `performance-§12` deviation row rests on. Result: pass (owner-marked 2026-10-10)
- **TELE-6. The cooldown expires live.** Leave a cooldown popup open across the expiry → the button
  rearms itself: no swipe, no note, full alpha, and a click that casts, with no close and reopen.
  Result: pass (owner-marked 2026-10-10)

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

  Result: pass (owner-marked 2026-10-10)
- **LFG-2. The real join's details link.** After LFG-1, close the popup and click that join's own
  `[Click here to view details]` → the popup reopens with the real group's data, no ItemRef tooltip
  and no error. Close it and **shift-click** the link, once with the chat edit box closed and once
  with it open → it reopens the same way and nothing is inserted into the edit box. The console
  logs `[ChatLink] clicked hasPending=true` for each click; if the popup does not open, record
  whether that line appeared at all. Result: pass (owner-marked 2026-10-10)
- **LFG-3. Concurrent applications.** `/wg debug on`, apply to two listings (different dungeons)
  in quick succession, and let one be accepted and one declined, the decline first if you can;
  three listings if easy → the summary and popup name the group you joined, not the first or the
  latest applied; the console shows one `[LFG] dropped the capture for appID=<N> (declined)` line
  when the decline lands, not at group leave; the rest are wiped at `inviteaccepted`. Result: pass (owner-marked 2026-10-10)
- **LFG-4. Leaving the group.** Leave (portrait → **Leave Group**, or `/leavegroup`) → the console
  shows `[Roster] inGroup=false wasInGroup=true hasPending=true`, and `/wg show` then prints
  `No group info available. …`: the capture is cleared on leave. Result: pass (owner-marked 2026-10-10)
- **LFG-5. DPS only.** Sign up for a premade as **Damage** only and get invited and accept → the
  popup and the chat summary both show `Role:` with the damage icon and `Damage`. Result: pass (owner, 2026-10-02)
- **LFG-6. Two roles offered, one assigned.** Sign up as **Tank** and **Healer**, and have the
  leader set you to healer after the join → the popup shows `Healer` (reopen it with `/wg show`
  if it opened before the leader's change). Before any assignment, record what it showed (the
  application's role, or `Tank / Healer`). Result: pass (owner, 2026-10-02)
- **LFG-7. The chat row's toggle.** **Notifications** → *Role* off, then repeat LFG-5 or `/wg test notify`
  → the chat summary has no `Role:` line and the popup still shows the role. Turn it back on.
  Result: pass (owner, 2026-10-02)
- **LFG-8. Where the client keeps the role.** With an application pending (after the invite,
  before accepting), `/wg diagnostics` → the `client applications:` line reads
  `<id>=invited role=TANK` (or `HEALER` / `DAMAGER`). Record exactly what `role=` shows: anything
  but one of the three tokens means `GetApplicationInfo`'s 5th return is not the role on this
  client, and the Role row is living on its other two sources. Result: pass (owner, 2026-10-02)

## The launcher

- **LAUNCH-1. The AddOns list icon.** ESC → AddOns → the WhatGroup row carries the addon's logo,
  not a bag icon or a blank square. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-2. The minimap button draws.** → a round button wearing the same logo. A blank or green
  square means a wrong `.tga` format (regenerate it with layout-§4's recipe). Result: pass (owner-marked 2026-10-10)
- **LAUNCH-3. Left-click.** → Settings opens on the landing page, as `/wg config` does. With the
  popup open, the panel opens and the popup stays. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-4. Right-click menu and Show window.** Right-click → a menu titled **Ka0s WhatGroup**
  with four checkboxes in order: **Enabled** (ticked), **Locked**, **Test mode**, **Show window**.
  Click **Show window** → the popup opens ("No data" if nothing is captured); reopen the menu → it
  reads ticked; click it again → the popup closes. No error or taint line. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-5. Menu: Test mode.** Click **Test mode** → the sample popup opens, chat says what
  `/wg test` says, and the Master controls checkbox follows. Click again to end it. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-6. Menu: Locked.** Click **Locked** → chat prints `locked = true`, exactly as
  `/wg set locked toggle` does, and the popup's title bar no longer drags. Click again to unlock.
  Result: pass (owner-marked 2026-10-10)
- **LAUNCH-7. Menu: Enabled.** Click **Enabled** → chat prints what `/wg disable` prints and the
  addon stands down. Reopen the menu → **Enabled** is unticked and clickable; **Locked**, **Test
  mode** and **Show window** are grayed, each reading `(enable the addon first)`, and clicking one
  does nothing. Click **Enabled** to switch it back on. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-8. Left-click while disabled.** `/wg disable`, left-click the button → the settings
  panel opens as it does when running, and nothing prints. The button stays on the minimap.
  `/wg enable`. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-9. Drag it.** Drag the button around the minimap, `/reload` → it comes back where you
  left it (`db.global.minimap`). Result: pass (owner-marked 2026-10-10)
- **LAUNCH-10. The Minimap button row.** Untick *Minimap button* on **Master controls** → the button
  goes at once, not at the next reload. Tick it → it returns at the same angle. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-11. Hidden survives every reset.** With the button hidden, run in turn: `/wg profile Alt`
  (the profile from the [Profiles](#profiles) setup; create it first if that theme has not run) and
  back, `/wg resetall` → **Yes**, the page's **Defaults**, and **Reset all settings** on
  Master controls → it stays hidden through all of them, and returns at the same angle when you
  tick the row. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-12. A broker display.** In Titan Panel, ElvUI data texts or Bazooka, if you run one →
  one entry labeled exactly `Ka0s WhatGroup` in plain text (so it files beside the rest of the
  collection), wearing the same logo, whose left click and right-click menu do what the minimap
  button's do. There is deliberately no addon setting for its visibility. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-13. The tooltip.** Hover the button → top to bottom: `Ka0s WhatGroup  v<version>`,
  `Enabled: Yes` (green), `Locked: No`, `Test mode: Off`, `Left-click: Open settings`,
  `Right-click: Options menu`, nothing drawn twice. Tick **Lock frame** and **Test mode** →
  `Locked: Yes`, `Test mode: On`. `/wg disable` → still shows, `Enabled: No` in red, with the same
  two hints. `/wg enable`. Result: pass (owner-marked 2026-10-10)
- **LAUNCH-14. The Show window key binding.** Esc → Options → Key Bindings → AddOns → `Ka0s WhatGroup`
  lists `Toggle group popup` with no key preassigned; bind a key. With no capture, press it → the
  popup opens on its "No data" fallbacks; press again → it closes, as Close and ESC do. One press
  toggles once. `/wg test`, then press the key → the sample popup closes and test mode ends, as the
  menu's Show window does. `/reload` → the key is still bound. Result: pass (owner-marked 2026-10-23)
- **LAUNCH-15. The key while disabled.** `/wg disable`, press the key → exactly one chat line,
  `Ka0s WhatGroup is disabled — enable it with /wg enable`, and no popup. `/wg enable`. Result: pass (owner-marked 2026-10-23)
- **LAUNCH-16. The key in combat.** In combat, press the key → the popup opens or closes exactly as
  the launcher menu's Show window does in combat, with no `ADDON_ACTION_BLOCKED` and no taint line
  in the error frame or `/wg debug`. Result: pass (owner-marked 2026-10-23)
- **LAUNCH-17. The binding's own section (SM-WG-KB1).** Esc → Options → Keybindings → a section
  titled `Ka0s WhatGroup` (no longer under AddOns, which LAUNCH-14 above walked), holding
  `Toggle group popup` and nothing else, with no blank spacer row above or inside it. A key bound
  before this change is still bound. Result: pass (owner, 2026-10-24)
- **LAUNCH-18. The Keybindings tab, both ways (SM-WG-KB2).** `/wg` → General → the strip ends in
  **Keybindings**, after Skin (amended by WG-05, 2026-10-29: Skin sits between Notifications and
  Keybindings); it lists `Toggle group popup` with one key button and Clear
  (SM-WG-RV3). Bind a key on the button → Options → Keybindings shows it on the same action, and the
  bound key toggles the popup; bind a second key there → reopen the tab and the button reads `<first
  key> +1`, and hovering it shows a tooltip naming both keys and saying the other was set on Options →
  Keybindings. Clear → both keys are gone, here and there. Tick **Character Specific Keybindings** in
  Options → Keybindings, then repeat both directions: the tab's line under the rows reads `Saved for:
  this character only` and the keys follow the character set; untick it (Blizzard's own confirm) and it
  reads `Saved for: all characters`. General's Defaults and **Reset all settings** leave the keys alone.
  Result: pass (owner, 2026-10-24)
- **LAUNCH-19. The key, Escape and combat on the tab (SM-WG-KB3).** The key bound on the tab toggles the
  popup, as LAUNCH-14's does. Click the key button so it reads `Press a key...`, press Escape → the
  capture cancels and the Settings window stays open. In combat, click the key button or Clear → nothing
  is bound or cleared and the line reads `Key bindings can be changed after combat.`
  Result: pass (owner, 2026-10-24)

## Debug console and diagnostics

- **DIAG-1. `/wg debug` opens and closes the console.** → a window titled `Ka0s WhatGroup — Debug`,
  700×344 by default, monospace. Again → it closes. The logging state is untouched: the title-bar toggle still
  reads `Debug: OFF`. Result: pass (owner-marked 2026-10-10)
- **DIAG-2. `/wg debug on` and `off`.** → each prints `[WG] debug logging ON` / `OFF` with the word
  colored (ON green, OFF red, as on the title-bar toggle) and appends a `[Debug] logging enabled` /
  `disabled` line in the console. `on` also appends one `[Init]` line: `WhatGroup v<ver>, schema
  v<N>, profile '<name>'` and the runtime state (`enabled`, `notify.delay`, `autoShow`, `inGroup`,
  `hasPending`). Result: pass (owner-marked 2026-10-10)
- **DIAG-3. The title-bar controls.** Click the `Debug: OFF`/`ON` toggle → it flips logging with
  the same chat line and console line as the verb. The copy control opens a highlight-ready
  plain-text buffer; the clear control empties both views. Result: pass (owner-marked 2026-10-10)
- **DIAG-4. Scrollbar and counter.** → a thin scrollbar on the log's right edge and an
  `N / 3000 lines` counter bottom-right, in the log's font. First open must not error: a blank
  toggle or a dead ESC means the initial sync threw. With debug on, write lines until the log
  overflows → the counter climbs and the thumb becomes draggable; dragging it scrolls the log and
  the mouse wheel moves the thumb, top oldest and bottom newest. Clear → `0 / 3000` and a parked,
  gray thumb. On a short log the bar shows but is inert. Result: pass (owner-marked 2026-10-10)
- **DIAG-5. The buffer cap.** With debug on, write well past 3000 lines (`/wg diagnostics` run a
  hundred-odd times from a macro) → the counter pins at `3000 / 3000 lines` and the oldest lines
  drop off the top. Copy opens without a hitch and holds exactly the newest 3000 lines, ending on
  the latest report's end marker. Result: pass (owner-marked 2026-10-10)
- **DIAG-6. One `[Set]` line per write.** With debug on, `/wg set notify.delay 3` → exactly one
  `[Set] notify.delay = 3` line; `/wg set notify.delay 0` → one more. A Master controls checkbox
  write logs the same single line. The verbs write through the same seam: `/wg disable` → one
  `[Set] enabled = false` line, `/wg enable` → one `[Set] enabled = true`, `/wg test on` → one
  `[Set] state.testMode = true`, and `/wg test off` → one `[Set] state.testMode = false`. Result: pass (owner-marked 2026-10-10)
- **DIAG-7. Reset all logs once.** With debug on, `/wg set notify.delay 3`, `/wg resetall` →
  **Yes** → the console closes (it is a session-only row the reset sweeps). Reopen it with
  `/wg debug` → after the `[Set] notify.delay = 3` line, exactly one `[Set] reset profile '<name>'
  to defaults (1 rows)` line, no per-row `[Set]` and no `[Reset]`. A second `/wg resetall` straight
  after reads `(0 rows)`. Result: pass (owner-marked 2026-10-10)
- **DIAG-8. The Debug console checkbox shows the window only.** After a login, **Master controls**
  → *Debug console* is unticked. Tick → the window appears; untick → it hides. With
  `/wg debug on` first, tick it → the window shows with no `debug logging` chat line and the header
  still reads `Debug: ON`; untick → logging stays on. Result: pass (owner-marked 2026-10-10)
- **DIAG-9. The checkbox follows the window.** With the panel open, close the console with its own
  close control (or ESC), then reopen **Master controls** → the box reads unticked. Result: pass (owner-marked 2026-10-10)
- **DIAG-10. The checkbox is session-only.** Tick it, log out fully and back in → unticked. `/wg
  list` shows `state.debugConsole`, but `WhatGroupDB` has no `state` table and no `debug` field.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-11. The console forgets its position.** Drag the console somewhere, `/reload`,
  `/wg debug` → it is back at its default position. The library owns the window and offers no
  geometry hook (a known loss, [LIBKA0S-05](https://github.com/tusharsaxena/WhatGroup/issues/11)),
  not a regression. Result: pass (owner-marked 2026-10-10)
- **DIAG-12. The title-bar marks.** `/wg debug` → the three right-hand controls are small square
  marks, not words: copy, clear and close, in the same gray as every Ka0s window, red under the
  pointer. The words `Copy` and `Clear` beside a `×` mean the library fell back because
  `addonName` stopped reaching its descriptor in `core/DebugLogSetup.lua`. A blank square means the
  `CLAUDE.md` `LibKa0s icons:` line misses a name, and the re-vendor pruned that mark (LibKa0s
  v1.75.0). Result: pass (owner-marked 2026-10-23)
- **DIAG-13. The copy window's mark.** Click the copy control → the copy window's close control is
  the same square mark; a `×` here alone means the two windows are built from different
  descriptors. A blank square means the `LibKa0s icons:` line misses a name (`close`). Result: pass (owner-marked 2026-10-23)
- **DIAG-14. The log font.** → monospace, with the `HH:MM:SS | [tag] …` columns aligned: the
  library's JetBrains Mono under `libs/LibKa0s/media/fonts/`. A proportional face means
  `NS.MediaFont` answered nil and `STANDARD_TEXT_FONT` caught it. Result: pass (owner-marked 2026-10-10)
- **DIAG-15. One shared font entry.** Open any Ka0s addon's font dropdown → `JetBrains Mono` is
  listed once: `Media.RegisterLSM` registers one set of bytes for the whole collection. Result: pass (owner-marked 2026-10-10)
- **DIAG-16. Matching consoles.** Open another Ka0s addon's debug console beside this one → the two
  title bars are indistinguishable: same marks, size, pitch and gray. Result: pass (owner-marked 2026-10-10)
- **DIAG-17. The report appends.** `/reload`, `/wg debug on`, `/wg test notify`, close the popup,
  then `/wg diagnostics` → the console opens if closed; the `[Test]` and `[Frame]` lines stay above
  `[Diag] ==== Ka0s WhatGroup diagnostics begin ====`; the sections follow in order (identity,
  settings with its `[Set]` rows, registration, group, capture, pending, teleport, popup, launcher)
  and end on `[Diag] ==== Ka0s WhatGroup diagnostics end: N line(s) ====`. Chat prints one line,
  `Diagnostic report written to the debug console: N lines. Use Copy to share it.`, with the same
  N. `enabled = true (true)`, `notify.enabled = true (true)` and `frame.autoShow = true (true)`
  print at their defaults, and no `section <name> failed:` line appears. Result: pass (owner-marked 2026-10-10)
- **DIAG-18. The copy holds it clean.** Copy, select all, paste into an editor → the trace, the
  begin marker and the whole report to the end marker, with no `|c`, `|r`, `|T` or `|H` escape.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-19. Diagnostics turns logging on for the session.** `/reload` → the title bar reads
  `Debug: OFF`. `/wg diagnostics` → chat prints `[WG] debug logging ON`, then the report's
  line-count line; the console holds `[Debug] logging enabled` and the `[Init]` line just ahead of
  the begin marker, the report's header reads `debug logging: on`, the title bar reads `Debug: ON`,
  and `/wg set notify.delay 2` writes one `[Set]` line. `/wg diagnostics` again → a second full
  report under the first with no second `logging enabled` line. `/reload` → `Debug: OFF` again, and
  `/wg set notify.delay 3` writes nothing; `/wg debug diagnostics` → logging on for the session, the
  same way. `/wg debug off` → logging stops, and nothing turns it back on until the next report or
  `/wg debug on`. `/wg reset notify.delay`. Result: pass (owner-marked 2026-10-10)
- **DIAG-20. Both forms, the alias, no short form.** `/wg debug diagnostics`,
  `/whatgroup diagnostics`, `/whatgroup debug diagnostics` → each writes the report. `/wg diag` →
  `unknown command 'diag'` and the help index; `/wg debug diag` → the three-line `debug` usage;
  neither writes a report. Result: pass (owner-marked 2026-10-10)
- **DIAG-21. While disabled.** `/wg disable`, then `/wg diagnostics` and `/wg debug diagnostics` →
  both run with no refusal; identity reads `enabled=false stoodDown=true` and names the `disabled`
  hold; capture is the one line `capture: stood down, runtime state released`. `/wg enable`.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-22. The report never builds the popup.** `/reload`, `/wg diagnostics` before anything
  opens the popup → `popup: not built` and nothing on screen. `/wg test notify`, close it, run it
  again → `built=true` and a live point. Result: pass (owner-marked 2026-10-10)
- **DIAG-23. In combat.** Pull a dummy, `/wg diagnostics` mid-fight; again with a captured group
  whose teleport is on cooldown if you have one → no Lua error and no `ADDON_ACTION_BLOCKED`; the
  header reads combat `true`; a secret or unreadable value prints `<secret>` or `unreadable`; the
  teleport line is `teleport cooldown start=… duration=…` or `teleport cooldown unreadable`.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-24. The README steps.** `/reload`, close the console, and follow the README's
  `## Reporting a bug` word for word → every step works as written, and the one Copy holds the
  trace and the whole report. Result: pass (owner-marked 2026-10-10)
- **DIAG-25. The console resizes from its grip.** `/wg debug` → a small size grip in the
  bottom-right corner, clear of the `N / 3000 lines` counter. Drag it out on both axes → the window
  follows the pointer; the log reflows to the new width, the scrollbar runs the full new height with
  its thumb resynced, the counter stays bottom-right, and the title-bar controls stay placed. The
  buffer and the scroll position are kept. Result: pass (owner-marked 2026-10-10)
- **DIAG-26. The console's minimum holds.** Drag the grip as far up and left as it goes → it stops
  where the title and every title-bar control still fit side by side without overlap, with the
  status bar and a few log lines showing. Result: pass (owner-marked 2026-10-10)
- **DIAG-27. The size lasts the session, and only the session.** Resize the console, close it,
  `/wg debug` → it reopens at the size you left it. `/reload`, `/wg debug` → back at 700×344, and
  nothing in `WhatGroupDB` holds a size. Result: pass (owner-marked 2026-10-10)
- **DIAG-28. The copy window resizes too.** Click the copy control, then drag the copy window's
  bottom-right grip → it resizes on both axes and the text re-wraps to the new width; it will not
  shrink below 240×140. The scroll bar's down button sits above the grip and takes a click on its
  whole face. Close it and copy again → the same size; after a `/reload` → its default size.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-29. Another addon's console is its own.** Resize this console, then open another Ka0s
  addon's debug console → it opens at its own default size; resize it → this one does not move.
  Result: pass (owner-marked 2026-10-10)
- **DIAG-30. The Diagnostics link.** `/reload`, `/wg debug` → in the title bar, top left, the word
  `Diagnostics` sits just right of the `Debug: OFF` toggle with a small gap, drawn orange in the same
  plain text as the toggle: no button art, border or background. Hover it → it brightens; move off →
  orange again. Click it → logging turns on first (the toggle reads `Debug: ON`, chat prints
  `[WG] debug logging ON`, the console gains `[Debug] logging enabled` and the `[Init]` line), then
  the diagnostics report is written after them, begin to end marker as in DIAG-17, with the one chat
  line giving its line count. Click it again → the report appends once more, with no second
  `logging enabled` line. Flip the toggle between `ON` and `OFF` → the gap after it holds for either
  word. Drag the grip in as far as it goes (DIAG-26) → the link still fits beside the toggle and the
  title. Result: pass (owner-marked 2026-10-10)
- **DIAG-31. A slash refusal shows in the console.** `/wg debug on`, `/wg debug`, then `/wg nope` →
  chat says the command is unknown, as before, and the console gains one line,
  `[Cmd] refused nope: unknown verb`. `/wg disable`, then `/wg show` → chat prints the disabled
  line, and the console gains one `[Cmd] refused show: disabled` line and no second refusal line.
  `/wg enable` afterwards. Result: pass (owner-marked 2026-10-10)
- **DIAG-32. A stand-down and a stand-up show in the console, once each.** `/wg debug on`,
  `/wg debug`, then `/wg disable` → the console gains
  `[Lifecycle] stood down: added disabled (holds: disabled)`, before the teardown's own lines, and no
  `[State]` line. `/wg enable` → one `[Lifecycle] stood up: released disabled (holds: none)` line.
  A second `/wg enable` writes no `[Lifecycle]` line. Result: pass (owner-marked 2026-10-10)
- **DIAG-33. The launcher's registration lands when logging is turned on.** `/reload`, then
  `/wg debug on`, `/wg debug` → after `[Debug] logging enabled` and the `[Init]` line, the console
  holds one `[Launcher] registered` line. `/wg debug off`, `/wg debug on` → no second
  `[Launcher] registered` line. Result: pass (owner-marked 2026-10-10)

## Skins

The skinning rollout's checks (Ka0sAddonsCommonTasks `docs/2026-10-29-SKINNING_ROLLOUT/`, items WG-01
to WG-04). Start from a **fresh client start**, not a `/reload`, after checking out the branch: the
client finds new font and texture files only at start, so a `/reload` leaves a skin's face as
fallback squares. Pick skins on `/wg config` → General → **Skin**. Every check also fails on a Lua
error or a taint warning. WhatGroup has **no HUD**, so the rollout's one-time HUD style reset (owner
ruling O2) does not run here and moves nothing (WG-03 had nothing to do); what changes under Ka0s
Default is SKIN-1's list and nothing else.

- **SKIN-1. Ka0s Default looks as before, in its own face (WG-02, WG-04; the rollout's X1, D4).** On
  **Ka0s Default**, `/wg test` → the popup looks as it did before the run in color, edge and
  spacing: the near-black body, the 1px black edge with its gray inner line, the "WhatGroup" span
  of the title and the seven field labels in the same bright gold, the rest of the title in the
  title gold, the values white, the "No data" and em-dash placeholders and the teleport note in
  the same mid gray. Three things changed, and they are the run's: every string reads in
  **Oxanium** (a squared, technical face; SemiBold for the labels and values, Bold for the title)
  instead of the game's Friz Quadrata; the 30px title band behind the title is filled a shade
  darker than the body; and **Close** is the skin's flat button (a dark fill inside a 1px edge) instead of
  Blizzard's red stone button. Fail: any other changed color, edge or
  spacing, a label in a different gold from the "WhatGroup" span, a string still in Friz Quadrata,
  or text clipped or overlapping because the face is wider. Result:
- **SKIN-2. The Skin tab (WG-01).** `/wg config` → General → the strip reads **Master controls |
  Notifications | Skin | Keybindings**. **Skin** → a **Skin source** heading over *Ka0s skins* (on)
  and *EllesmereUI* (disabled with a line saying why, unless EllesmereUI is loaded and can skin this
  addon); a **Look** heading over the nine skins, three to a line, each with its swatches and name,
  Ka0s Default on; a **Font and texture** heading over **Font** and **Texture**, both *Skin's own*;
  a **Scope** heading over **Ignore settings panel** (on) and **Ignore fonts** (off); **Copy to every
  Ka0s addon…**; and the note *Skins change every visual element. HUD style options follow the
  skin unless you set them yourself.* No heading on the tab reads **Skin**. Pick **Obsidian** → no
  reload; `/wg get skin.skin` → `obsidian`; `/reload` → still Obsidian. Pick **Ka0s Default** again.
  Fail: the tab missing, out of place or labeled Appearance, a pick that does not stick, a reload
  prompt on a Ka0s-to-Ka0s pick. Result:
- **SKIN-3. Each skin, live, on the popup (WG-02).** `/wg test`, then pick each skin in turn on the
  Skin tab: Obsidian, Azeroth, Glass, High Contrast, Ember, WoW Default, WoW Midnight, WoW Forever,
  then Ka0s Default → with **no reload** the popup's body, edge, title band, title (the "WhatGroup"
  span included), divider, labels, values, teleport note and **Close** button all repaint, and every
  string stays readable. Repeat once from `/wg show` with nothing captured (the launcher's **Show
  window** after a `/reload`) → the "No data" placeholders repaint too. `/wg set skin.skin azeroth`
  with the popup open → the same repaint, from the CLI. Fail: a part of the popup that keeps the old
  skin until it is closed and reopened, or until `/reload`. Result:
- **SKIN-4. The teleport button follows its label (WG-02; inventory R2, R4).** `/wg test` on Ka0s
  Default, note where the teleport icon sits beside **Teleport:**, then pick **High Contrast** (the
  largest face) → the icon moves with its label and sits beside it, not over it and not left where
  it was; back to **Ka0s Default** → it returns. Now pull a dummy with the popup up and, in combat,
  `/wg set skin.skin contrast` → no `ADDON_ACTION_BLOCKED` and no *Interface action failed*; the
  strings repaint at once, the icon may stay put until combat ends, and drops beside its label the
  moment you leave combat. `/wg set skin.skin ka0s` to finish. Fail: the icon detached from its label
  after the switch or after combat, or a blocked-action error. Result:
- **SKIN-5. Labels fit under every skin (inventory R5).** `/wg test` → under **High Contrast**,
  **Azeroth** and **WoW Midnight**, read the label column → *Playstyle:*, *Instance:* and *Teleport:*
  are whole, none cut or ending in an ellipsis, and no value runs over its label. Fail: a clipped
  label. Result:
- **SKIN-6. Fonts (LibKa0s skin faces).** On an English client each skin draws its own family on the
  popup, title and labels alike, with no fallback squares: Ka0s Default Oxanium, Obsidian Inter,
  Azeroth Vollkorn, Glass Nunito, High Contrast Atkinson Hyperlegible, Ember Bitter, WoW Midnight
  Philosopher, WoW Forever Fira Sans; WoW Default the client's Friz Quadrata. The title is the
  family's heavier weight, never a different face. Fail: an empty square where a letter should be,
  or two skins in the same face. Result:
- **SKIN-7. Window corners (WG-02).** Under **Azeroth**, **High Contrast** and **WoW Midnight**,
  `/wg test` and look at the popup's four corners → the edge runs unbroken round each one, and the
  title band sits inside it. Ka0s Default's 1px edge is where it was. Result:
- **SKIN-8. The settings panel, Scope on and off (WG-01, WG-04).** On a non-default skin with
  **Ignore settings panel** on (the default) → WhatGroup's landing page, General's tabs, the **Test
  notification** button and the **Profiles** page stay the game's own look; the popup still wears
  the skin. Untick **Ignore settings panel** → with no reload WhatGroup's pages, the tab strip, the
  check boxes, sliders, dropdowns, the **Test notification** button on Notifications and every
  control on the **Profiles** page take the skin; open Profiles twice (it is redrawn each time) →
  skinned both times. Open another Ka0s addon's settings and a non-Ka0s AceGUI addon's, and flip
  back and forth a few times → those pages stay **stock** every time (the AceGUI pool leak check).
  Tick **Ignore settings panel** again → WhatGroup's pages go back to stock with no reload. Result:
- **SKIN-9. The debug console follows the skin (WG-04).** On **Azeroth**, `/wg debug`, then its
  **Copy** window → both wear WhatGroup's skin: the window edge and title, the buttons, the scroll
  bar and the line counter; the log lines keep their monospace face (JetBrains Mono) under every
  skin. Switch to **Ka0s Default** with the console open → it repaints with no reload, and looks as
  it did before the run. Result:
- **SKIN-10. What stays Blizzard's (inventory § Exceptions; X7).** Under **High Contrast** and
  **Azeroth** → the teleport icon (no new edge round it, desaturated at 50% when not ready), its
  cooldown swipe, its spell tooltip, the *Reset all settings* confirmation, the minimap button, its
  hover tooltip and its right-click menu all look as they did before the run. The chat summary is
  unchanged too: the cyan `[WG]` tag, the gold row labels, the green details link and the yellow
  command words in help text. Fail: any of these recolored, or a frame drawn round the teleport
  icon. Result:
- **SKIN-11. EllesmereUI on (WG-01; LibKa0s's EllesmereUI provider).** With EllesmereUI loaded, its
  third-party skinning on and WhatGroup on in its Third-Party list → Skin → **Skin source** offers
  **EllesmereUI**; choosing it repaints the popup (`/wg test`) in EllesmereUI's look, live; the
  teleport icon stays beside its label. Result:
- **SKIN-12. EllesmereUI off (WG-01).** Turn WhatGroup off in EllesmereUI's Third-Party list (or
  disable EllesmereUI) and `/reload` → the EllesmereUI choice is disabled, the failing condition and
  its fix are listed, and the popup wears its Ka0s skin. Run without EllesmereUI installed at all →
  the choice is disabled with its reason, and nothing else on the tab changes. Result:
- **SKIN-13. Back from EllesmereUI needs a reload (WG-01).** With EllesmereUI as the source, pick
  **Ka0s skins** → a reload is offered; after it, the Ka0s skin shows. Switch to a profile on Ka0s
  skins while EllesmereUI painted this session → chat prints one `[WG]` line asking for a
  `/reload`. Result:
- **SKIN-14. Copy to every Ka0s addon (WG-01).** With another Ka0s addon that uses skins loaded
  (Ka0s Loot History or the Ka0s Skin Tester), set a skin, a font and a texture on WhatGroup's Skin
  tab and press **Copy to every Ka0s addon…** → the confirmation names the other addons; accept →
  each wears the same skin, font and texture with no reload. With WhatGroup the only one loaded →
  the button is disabled with *No other loaded Ka0s addon uses skins yet.* Result:
- **SKIN-15. Profiles (WG-01).** Give two profiles different skins, switch between them on the
  Profiles page with the popup open (`/wg test`), then reset one → the skin follows the profile each
  time with no reload, and a reset goes back to Ka0s Default. `/wg profile <name>` does the same.
  Result:
- **SKIN-16. Combat (WG-01).** In combat on a dummy, change the skin with `/wg set skin.skin
  obsidian` → no Lua error and no taint warning (SKIN-4 covers the teleport button); the settings
  page is refused in combat as it is for any other setting. Result:
- **SKIN-17. Font and texture overrides (WG-01).** With the popup open, pick a clearly different face
  in **Font** → with no reload every popup string takes it, at the size it had; the debug console's
  log lines keep their monospace face; another skin keeps the override; *Skin's own* brings the
  skin's face back. Turn **Ignore fonts** on with an override set → every popup string goes back to
  the game's own face, still in the skin's colors; off → the override returns. Pick any **Texture**
  → nothing on the popup changes (WhatGroup draws no bars) and nothing errors. `/wg get skin.font`
  shows the key while set and an empty value after. Result:
- **SKIN-18. The skin picker at login and on a fresh profile (WG-04; owner ruling O3).** For a
  profile that never closed it (every profile on the first login of this build), log in → about two
  seconds after the world loads a small window titled **Choose a skin for Ka0s WhatGroup** opens
  about three quarters of the way up the screen: a dropdown showing the skin worn now, an eye and a
  gear beside it, **Apply** under it and a close mark, plus **Apply to all Ka0s addons** only while
  another Ka0s addon that uses skins is loaded. Close it, then create a new profile on the Profiles
  page → it opens again; reset that profile → again. It never opens while WhatGroup is disabled
  (`/wg disable`, `/reload`), and a login in combat holds it until combat ends. Fail: a window on a
  profile that already closed it, none on a new or reset profile, or one while disabled. Result:
- **SKIN-19. The picker previews, and its eye (WG-04; X6).** Open the dropdown → every skin, each row
  in that skin's face with its swatches. Pick **Obsidian** → the popup and the picker repaint with
  no reload, the picker stays up, and `/wg get skin.skin` still prints the skin it opened with. Press
  the eye → the popup opens in test mode (the sample group) in the previewed skin, and the picker
  stays above it, clickable. Hover the eye → its tooltip says it opens test mode. Fail: the popup
  over the picker, or the preview lost on the eye. Result:
- **SKIN-20. Apply, the gear, the close mark and Escape (WG-04).** On a fresh profile: preview
  **Obsidian** and press **Apply** → the picker closes, Obsidian stays and is saved (`/wg get
  skin.skin` → `obsidian`), and `/reload` does not bring the picker back. On another fresh profile,
  preview a skin and press the gear → Settings opens on **General** with its **Skin** tab selected,
  showing the preview saved, and the picker closes. On a third, preview a skin and press the close
  mark → the old skin comes back and nothing is saved; on a fourth, the same with **Escape**. Each of
  these closes counts: the picker does not open again on that profile. Result:
- **SKIN-21. The picker, the stand-down and a profile switch (WG-04).** With the picker up and a
  preview pending, `/wg disable` → it closes, the stored skin comes back, and nothing is saved;
  `/wg enable`, `/reload` → it opens again, because the player never closed it. Give a second profile
  **Azeroth** and close its picker; on a fresh profile preview **Obsidian**, then switch to the
  Azeroth profile → the picker closes and the popup wears **Azeroth**, never Obsidian or Ka0s
  Default; switch back → Ka0s Default, and the picker opens again. Result:
- **SKIN-22. One picker at a time across Ka0s addons (WG-04).** With WhatGroup and a second Ka0s addon
  that uses skins both on fresh profiles, `/reload` → one picker opens, naming one addon; close it →
  the other opens at once. Reset both and `/reload` → press **Apply to all Ka0s addons** → both addons
  wear the skin and no second picker opens. Reset both again, `/reload`, enter combat and close the
  open picker → the waiting one opens only when combat ends. In combat, a pick, **Apply**, **Apply to
  all** and the gear each say they cannot be done in combat, and the close mark still closes it.
  Result:
- **SKIN-23. Other Ka0s addons unchanged (WG-01).** With WhatGroup on a non-default skin, open two
  other Ka0s addons' windows, debug consoles and settings pages → each looks and behaves exactly as
  before. Disable WhatGroup, `/reload` and compare → still unchanged. Result:
- **SKIN-24. The popup without the library (WG-01, WG-02).** Under the [Library-absent
  install](#library-absent-install) setup, `/wg test notify` → the popup draws in the colors it had
  before the run (gold labels, white values, gray placeholders, the 1px black edge) in the game's
  own fonts, with **Close** as Blizzard's button; there is no **Skin** tab, no picker at login, and
  `/wg set skin.skin obsidian` prints the library-absent CLI line. Fail: a Lua error, a blank title
  or a blank label. Result:

## Library-absent install

Quit the game and rename `Interface/AddOns/WhatGroup/libs/LibKa0s` to `libs/LibKa0s.off` first,
and disable every other Ka0s addon on the AddOns list: each ships its own LibKa0s, and LibStub
hands WhatGroup that copy, so nothing here degrades while one of them loads. Rename the folder
back, re-enable the others and `/reload` when done. The eleven seam files (`core/CoreSetup.lua`,
`core/SkinSetup.lua`, `core/Compat.lua`, `core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`,
`core/LauncherSetup.lua`, `core/LifecycleSetup.lua`, `settings/OptionsSetup.lua`,
`settings/SchemaSetup.lua`, `settings/Slash.lua`) each fall back; only a real broken install
proves they do.

- **DEGRADED-1. It loads, and the CLI says it is gone.** Log in, `/wg list` → zero Lua errors at
  load, and `/wg list` prints one `[WG]` line, *The LibKa0s library is missing from this
  installation of Ka0s WhatGroup (expected in libs/LibKa0s), so the settings CLI is unavailable.*,
  not a listing: the schema CLI is the library's. That the schema itself loads whole is headless
  (`tests/test_libka0s.lua` "degraded: every HAND-WRITTEN schema row survives the options
  library's absence (options-ui-§1)"). Result: pass (owner-marked 2026-10-10)
- **DEGRADED-2. The notices, counted.** `/wg config` twice, `/wg debug on`, `/wg debug` twice →
  every notice is one `[WG]` line starting *The LibKa0s library is missing from this installation
  of Ka0s WhatGroup (expected in libs/LibKa0s)*, with only the tail differing (reduced built-in
  fallbacks; settings panel unavailable; no minimap button and no broker plugin; debug console
  window unavailable; settings CLI unavailable). The printer's notice appears exactly once per
  session; the launcher notice once, at login; the settings notice twice (login and the first
  `/wg config`, not the second); the console notice twice (`/wg debug on` and the first bare
  `/wg debug`, not the second). Result: pass (owner-marked 2026-10-10)
- **DEGRADED-3. The debug flag still flips.** `/wg debug on` → it reports the flag flipping; only
  the window is lost. Result: pass (owner-marked 2026-10-10)
- **DEGRADED-4. Library-owned verbs say so.** `/wg disable`, `/wg enable`, `/wg test on`,
  `/wg diagnostics`, `/wg debug diagnostics`, `/wg profile`, `/wg profile Alt` → each prints one
  `[WG] <verb> is unavailable: the LibKa0s library did not load.` line, raises nothing, and moves
  nothing: the addon stays enabled, no popup opens, no report is written, no profile switches.
  The verb named is `/wg disable`, `/wg enable`, `/wg test`, `/wg diagnostics` for both report
  forms, and `/wg profile` for both profile forms. Result: pass (owner-marked 2026-10-10)
- **DEGRADED-5. The popup without the art.** `/wg debug` → no console window (the window is the
  library's), and nothing prints once DEGRADED-2 has spent the console notice. `/wg test notify`
  → the chat summary and the popup, whose footer still reads `Close` alone. A blank footer button
  or a Lua error is the failure. Result: pass (owner-marked 2026-10-10)

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
  glyphs. Result: pass (owner-marked 2026-10-10)
- **LOC-2. Field width.** Read the popup and the chat summary with that longer name → it fits its
  row or truncates cleanly at the field's edge. Fail: text over the border, over the next field, or
  a frame pushed wider than the screen. Result: pass (owner-marked 2026-10-10)
- **LOC-3. Playstyle, including the load-time read.** With the popup up, `/dump
  GROUP_FINDER_GENERAL_PLAYSTYLE1`, then `2`, `3` and `4` → four non-empty strings in the client's
  language, and a Playstyle row that reads as words. Fail: any nil, which stays nil for the whole
  session; record which. Result: pass (owner-marked 2026-10-10)
- **LOC-4. The teleport casts by the client's name.** A popup for a teleport you know: hover, then
  click (TELE-1) → the tooltip is the localized spell tooltip and the click casts. Fail: a click
  that does nothing while the button is drawn ready, meaning the macrotext holds a name this client
  does not answer to. Result: pass (owner-marked 2026-10-10)
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
  Result: pass (owner-marked 2026-10-10)
- **LOC-6. Nothing else moved.** On this client run INSTALL-1 to INSTALL-4, COMBAT-1, COMBAT-2,
  POPUP-1, POPUP-3 to POPUP-5, TELE-1 to TELE-4, TELE-6, COMBAT-6 to COMBAT-10, COMBAT-12 and
  LFG-1 → identical to English. Fail: any Lua error, meaning a localized string reached code that assumed
  an English one. Result: pass (owner-marked 2026-10-10)

## Pending sign-off

On 2026-10-10 the owner marked every check in this file as passed, recorded on its
`Result:` line as `pass (owner-marked 2026-10-10)`; a check that already carried a dated owner pass
keeps it. On 2026-10-24 the owner reported that every check of the keybindings, settings layout and
frame layering run passed (PANEL-2, PANEL-21, PANEL-22, COMBAT-13, COMBAT-14, LAUNCH-17 to
LAUNCH-19), recorded on each `Result:` line as `pass (owner, 2026-10-24)`. POPUP-10's probe records
an observation and is never marked passed; its 2026-10-24 run is recorded as reported passing, with
no observation text captured. A check added or rewritten after that date is listed here until its
`Result:` line records a pass.

Owed from the skinning rollout (Ka0sAddonsCommonTasks `docs/2026-10-29-SKINNING_ROLLOUT/`, items
WG-01 to WG-05, 2026-10-29): PANEL-2 (amended: the Skin tab in the strip), LAUNCH-18 (amended:
Keybindings after Skin), and SKIN-1 to SKIN-24 (new: Ka0s Default's face, title band and Close
button; the Skin tab; each skin on the popup; the teleport button's anchor; fonts and corners; the
Scope; the console; what stays Blizzard's; EllesmereUI on and off; copy, profiles, combat and the
overrides; the first-run skin picker; other addons unchanged; the popup without the library).
