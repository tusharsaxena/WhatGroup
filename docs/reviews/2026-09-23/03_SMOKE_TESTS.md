# WhatGroup — in-client smoke tests for the 2026-09-23 review

These are the checks only the game client can make. The headless suites (luacheck, `tests/run.lua`,
`tests/perf.lua`, lizard) already ran in Step 0 and are recorded in `01_FINDINGS.md`. Re-run them
once after the changes land, as a single pre-flight line:

```sh
~/.claude/wow-addon/bin/ka0s-bounded luacheck . && ~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua && ~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/perf.lua
```

## Pre-flight

1. Retail client at **12.1.0**. The TOC's `## Interface: 120100` must match the client, and nothing
   may show "out of date" in the AddOns list.
2. Install the working tree as `Interface\AddOns\WhatGroup\`, a whole-folder copy that includes
   `libs/`.
3. `/console scriptErrors 1`, then `/reload`. Keep BugSack/BugGrabber, or the default error frame,
   visible.
4. Test on a character that knows at least one current-season dungeon teleport (a "Path of …"
   spell), and is **near a target dummy** for combat checks. Stormwind and Orgrimmar both have
   dummies.
5. `/wg debug on`, then `/wg debug` to open the console. Clear it before each section.
6. Leave `/etrace` available for C-010.

---

## S-001 — C-001: no protected `Hide` when reopening a soft-hidden popup with no capture (F-001)

- **Setup:** no group, and no capture (`/reload` first). Default visibility (`always`).
- **Steps:**
  1. Left-click the WhatGroup minimap button. The popup opens reading "No data".
  2. Attack the target dummy to enter combat.
  3. Press the popup's **Close** button. It must vanish at once, because it goes to alpha 0.
  4. Still in combat, left-click the minimap button again.
  5. Stop attacking and wait for combat to end.
- **Variant A (the teleport button was visible):** out of combat, run `/wg test notify`, so the
  popup shows sample data with the teleport button. Then `/leave` if you are grouped, so the
  capture is wiped (or `/wg test off` if test mode is on). Enter combat, press Close, then
  left-click the minimap button.
- **Expected:** no "Interface action failed because of an AddOn" text, no `ADDON_ACTION_BLOCKED`
  error naming WhatGroup, and no Lua error. After combat ends the teleport button is hidden (Variant
  A) or stays hidden.
- **Pass/Fail:** **Pass** only if no blocked-action message appears in either variant. Any blocked
  message naming WhatGroup is a **Fail**. Record the unfixed build's result as well, to confirm F-001
  in the client (the finding marks the "already hidden" variant unverified).

## S-002 — C-002: the gate-declined reopen stays hidden, and the launcher and ESC still work (F-002)

- **Setup:** `/wg set visibility outOfCombat`, then `/wg test notify` to get a capture and the
  popup on screen.
- **Steps:**
  1. With the popup up, attack the dummy. The popup must disappear on the pull (alpha 0).
  2. In combat, type `/wg show`.
  3. In combat, click the `[Click here to view details]` chat link from step 0's notification.
  4. In combat, left-click the minimap button.
  5. In combat, `/wg set alpha 0.8`.
  6. End combat.
- **Expected:** steps 2–5 leave the popup **invisible** during combat, and no blocked-action text
  appears. After combat ends the popup comes back once, on its own, at alpha 0.8.
- **Pass/Fail:** **Fail** if the popup becomes visible at any point during combat, or if, once
  visible, neither the minimap button nor Escape closes it. **Pass** otherwise.

## S-003 — C-003: the schema stamp persists (F-003)

- **Setup:** an existing WhatGroup install with a `WTF/Account/<acct>/SavedVariables/WhatGroup.lua`.
- **Steps:**
  1. Log in on the new build, `/wg debug on`, `/reload`, `/wg debug on`, `/wg debug`.
  2. Log out fully (not `/reload`), and open `WhatGroup.lua` in a text editor.
  3. Log back in and repeat step 1.
- **Expected:** after step 2 the file contains `["schemaVersion"] = 1` under `["global"]`. Before the
  fix the key is absent. The `[Migrate] v0 -> v1` line appears at most once, on the first login of
  the new build, and never again.
- **Pass/Fail:** **Pass** if the key is present after logout and the migrate line does not repeat.

## S-004 — C-004: `/wg resetall` really resets on a degraded install (F-004)

- **Setup:** close the client and **rename** `Interface\AddOns\WhatGroup\libs\LibKa0s` to
  `LibKa0s.off`, then start the client. This simulates a partial install. Restore the folder after
  the test.
- **Steps:**
  1. Log in. Expect a one-time "The LibKa0s library is missing …" line.
  2. `/wg disable`, then `/wg enable`, to confirm the host verbs work.
  3. Change a stored value the degraded surface can reach: `/wg test on`, then `/wg test off`. Then
     edit a value with `/run` (for example
     `/run WhatGroupDB.profiles.Default.notify.delay = 7`). Adjust `Default` to the active profile
     name.
  4. `/wg resetall` and click **Yes**.
  5. `/run print(WhatGroupDB.profiles.Default.notify.delay)`
- **Expected:** step 4 prints "all settings reset to defaults", and step 5 prints `nil` (reset to
  the default and stripped) or `0`.
- **Pass/Fail:** **Fail** if step 5 prints `7`. Restore `libs\LibKa0s` afterwards and `/reload`.

## S-005 — C-005: debug lines unchanged in wording (F-005)

- **Steps:** with `/wg debug on` and the console open:
  1. `/wg set notify.delay 2`, which must log `[Set] notify.delay = 2`.
  2. Apply to any LFG listing, then cancel, which must log
     `[LFG] appID=<n> status=applied` and then `… status=cancelled`.
  3. `/wg test notify`, which must log `[Test] synthetic capture injected "Test Group — Windrunner Spire +12"`.
  4. Open the popup on a capture with a teleport, which must log
     `[Frame] teleport spellID=<id> known=<bool> (activity=<n> map=<n>)`.
- **Pass/Fail:** **Pass** if every line reads exactly as before the change (compare against a
  console copy taken on the old build) and no line shows a literal `%s`.

## S-006 — C-006: the teleport button still works (F-016)

- **Setup:** out of combat, with a capture whose teleport you know and which is off cooldown
  (`/wg test notify` uses Windrunner Spire).
- **Steps:** hover the teleport button (the tooltip shows the spell), move away (the tooltip hides),
  then click the button.
- **Expected:** the tooltip appears and clears, and the click casts the teleport. With debug on, one
  `teleport button pressed → /cast …` line appears per press, not two.
- **Pass/Fail:** **Pass** if all three behave. Then re-run `tests/perf.lua` and record
  `showFrameRepeat` bytes/iter in `docs/performance.md`.

## S-007 — C-007, C-008, C-009, C-011: behavior-neutral changes

- **Steps:** `/wg`, `/wg help`, `/wg list`, `/wg config` (out of combat), open the General page and
  click through the Master controls, Chat and Popup tabs, then close.
- **Expected:** the panel opens, the landing page lists 13 commands, every tab renders, and no Lua
  error appears.
- **Pass/Fail:** **Pass** if no error appears and the panel looks as it did before.

## S-008 — C-010: terminal statuses drop the capture (F-012)

- **Steps:**
  1. `/etrace` with a filter on `LFG_LIST_APPLICATION_STATUS_UPDATED`. Apply to a listing and let it
     time out, or decline an invite. **Record the exact status strings the client sends.** They are
     the input C-010 depends on.
  2. With debug on, confirm that a `[LFG] dropped the capture for appID=… (timedout)` (or
     `invitedeclined`) line appears.
- **Pass/Fail:** **Pass** if the strings match the ones C-010 added, and the drop line appears.

## Regression suite

1. `/reload` with no errors. Log out and log in, and watch `ADDON_LOADED` → `PLAYER_LOGIN` →
   `PLAYER_ENTERING_WORLD` complete with no errors.
2. **Fresh SavedVariables:** delete `WhatGroup.lua` from SavedVariables, log in, and check that
   `/wg list` shows the defaults (`notify.delay = 0.0s`, `frame.width = 420 px`, and so on).
3. **A real join:** apply through Premade Groups, get invited and accept. The chat summary prints
   after `notify.delay`, the popup opens (autoShow), and the teleport button is correct for the
   dungeon.
4. **Combat, default visibility:** open the popup, pull, press Close in combat (it vanishes), end
   combat (it stays closed), then `/wg show` (it opens).
5. **Profile switch:** create a second profile via `/run WhatGroupDB` tooling or AceDB options if
   present, toggle `enabled` off in one profile and switch to it. The addon stands down: the popup
   hides and `/wg show` refuses with the disabled line. Switch back and it stands up.
6. **Disable and enable in combat:** `/wg disable` during combat with the popup up. The popup goes to
   alpha 0 and no error appears. After combat the popup is really hidden. `/wg enable` restores it.
7. **Settings panel:** open it with `/wg config` and from Esc → Options → AddOns → Ka0s WhatGroup.
   Toggle every Master-controls row once. Press **Reset all settings** and confirm the popup
   appears, click Yes, and check that the values return to their defaults and the minimap button
   keeps its shown/hidden state.
8. **Logout taint:** after all of the above, press Esc → Log Out. It must complete with no
   `ADDON_ACTION_FORBIDDEN`.

## Taint-specific checks (F-001, F-002)

- In combat with the popup soft-hidden, click an action-bar ability, then open and close the game
  menu with Escape. There must be no "Interface action failed because of an AddOn".
- `/wg config` in combat must print the library's combat refusal and must **not** open the panel.
- The panel opens from `/wg config` **and** from Esc → Options → AddOns.

## Cross-addon dispatch (the in-client half of the cross-addon pass)

With all ten Ka0s addons loaded:

1. Type each root and confirm it reaches **its own** addon's help or panel: `/at`, `/am`, `/bl`,
   `/cm`, `/kcd`, `/lh`, `/mm`, `/pm`, `/pc`, `/wg`, plus each full-name alias
   (`/absorbtracker`, `/auramaster`, `/bankledger`, `/consumablemaster`, `/kickcd`,
   `/loothistory`, `/multimeters`, `/panelmaster`, `/prettychat`, `/whatgroup`).
2. Open Settings → AddOns. Each addon appears **exactly once**, and each multi-page addon's pages
   appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-001 (S-001) | | | |
| C-002 (S-002) | | | |
| C-003 (S-003) | | | |
| C-004 (S-004) | | | |
| C-005 (S-005) | | | |
| C-006 (S-006) | | | |
| C-007 (S-007) | | | |
| C-008 (S-007) | | | |
| C-009 (S-007) | | | |
| C-010 (S-008) | | | |
| C-011 (S-007) | | | |
| Regression suite | | | |
| Taint checks | | | |
| Cross-addon dispatch | | | |
