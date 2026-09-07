# WhatGroup — In-Client Smoke Tests (2026-09-07)

Execute **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Everything here needs a
logged-in game client. The headless suites (`luacheck`, `lua5.1 tests/run.lua`,
`lua5.1 tests/run.lua --list`, `lizard`) already ran in Step 0 of the review and are **not** repeated
as manual steps.

**Pre-flight (one command, not a test):** from the repo root, `luacheck . && lua5.1 tests/run.lua`
must both be green before you log in. If C-05 landed, the expected pass count is **530**, and
`docs/test-cases.md` plus the README `[tests]` badge must already show it.

---

## Pre-flight

1. Build/install: copy the repo folder to `World of Warcraft/_retail_/Interface/AddOns/WhatGroup`.
   The folder name **must** be `WhatGroup` — C-11 makes the composer read it from the load vararg, so
   a renamed folder is now a legitimate way to break the Master controls tab and you want to know it
   is the folder that matters.
2. TOC `## Interface: 120007`. Retail only; none of this applies to Classic.
3. Character: any, at level cap, with **at least one Mythic+ dungeon teleport learned** and
   **at least one not learned**. Season-2 Midnight teleports are in `defaults/TeleportSpells.lua`.
4. `/console scriptErrors 1` — Lua errors must be visible, not swallowed.
5. Start from a **fresh SavedVariables**: exit the client, delete
   `WTF/Account/<ACCOUNT>/SavedVariables/WhatGroup.lua` (and the `.bak`), then log in. Several tests
   below assert shipped defaults.
6. Have a target dummy reachable (Stormwind/Orgrimmar training dummies) — every combat-transition
   test uses one.
7. Keep `/etrace` handy but closed; T-01 uses it once.

---

## T-01 — Combat transitions drive the popup (C-01 / `WHATGROUP-R-01`)

**Change covered:** C-01 — `visibility` is re-evaluated on `PLAYER_REGEN_DISABLED` /
`PLAYER_REGEN_ENABLED`, and `ApplyFrameVisibility` can now show as well as hide.

**Setup.** Fresh profile. `/wg test` once to confirm the popup appears at all, then close it.
Open `/wg config` → **General** → **Master controls**.

**Steps.**
1. Set **General visibility** to `Only in combat`. Close Settings.
2. `/wg test`. Observe: the chat summary prints, the popup does **not** appear.
3. Attack the training dummy. Wait for combat to engage.
4. Observe the popup.
5. Step away and let combat drop (5 s). Observe the popup.
6. Set **General visibility** to `Only out of combat`. `/wg test` — the popup appears.
7. Attack the dummy. Observe the popup.
8. Drop combat. Observe the popup.
9. Set **General visibility** to `Never`. Attack the dummy, drop combat.
10. Set **General visibility** to `Always`. `/wg test`, then enter and leave combat twice.
11. `/etrace`, filter `PLAYER_REGEN`, repeat one dummy pull, and confirm both events fire and no red
    error text appears.

**Expected.**
- Step 4: the popup **appears** on its own, showing the synthetic test group's rows.
- Step 5: the popup **disappears** on its own.
- Step 7: the popup **disappears** on its own.
- Step 8: the popup **reappears** on its own.
- Step 9: no popup at any point, no error.
- Step 10: the popup stays visible across both transitions, unchanged.
- Step 11: no `Interface action failed because of an AddOn` text, no Lua error popup.

**Pass / Fail.** PASS only if steps 4, 5, 7 and 8 all behave as stated **and** step 9 produces
nothing. A popup that appears but is blank, or one that flickers on every transition under `Always`,
is a FAIL.

---

## T-02 — The cooldown ticker does not run behind a hidden popup (C-02 / `WHATGROUP-R-02`)

**Change covered:** C-02 — the ticker arms only against a visible popup.

**Setup.** Use a dungeon whose teleport you **have learned** and then **use it** so it is on
cooldown, and whose `mapID` is in `defaults/TeleportSpells.lua`. `/wg debug on` and `/wg debug` to
open the console.

**Steps.**
1. With **General visibility** = `Always`, `/wg test`, then join or fake the relevant dungeon capture
   so the popup shows the teleport row. Confirm the note reads `On cooldown — <time>` and the number
   decreases once per second.
2. Close the popup with the footer **Close** button. Watch the debug console for 30 s.
3. Set **General visibility** to `Only in combat`, out of combat. `/wg show`. The popup does not
   appear.
4. Watch the debug console for 60 s.
5. Enter combat on the dummy. The popup appears (T-01), and the note now counts down.
6. Leave combat — the popup hides. Watch the console for 30 s.
7. Set **General visibility** back to `Always`. Open the popup, enter combat, press `ESC` to close
   the popup **while still in combat**, then leave combat. Watch the console for 30 s.

**Expected.**
- Steps 2, 4, 6, 7: **no** further `[Frame]` teleport lines and no evidence of per-second work while
  the popup is off screen.
- Step 5: the countdown resumes at the correct remaining time, not from where it left off.

**Pass / Fail.** PASS if the countdown is live exactly and only while the popup is on screen, and
resumes correctly on every re-show. FAIL if the note ever stops updating on a visible popup.

---

## T-03 — Reset confirmation still works after the global assignment is dropped (C-03 / `WHATGROUP-R-03`)

**Change covered:** C-03 — `StaticPopupDialogs = StaticPopupDialogs or {}` removed.

**Setup.** Change at least three settings away from their defaults (e.g. `Master alpha` to 0.5,
`notify.delay` to 3, untick `Leader`).

**Steps.**
1. `/wg resetall`. A confirmation dialog appears.
2. Click **No**. Verify the three settings are unchanged.
3. `/wg resetall` again, click **Yes**.
4. Open `/wg config` → **General** and read the three rows.
5. Reload (`/reload`) and read them again.
6. Repeat via the **Reset all settings** button in Master controls, and via the **Defaults** button
   in the panel's top-right.
7. **Taint check:** with no `/reload` since login, open the game menu (`ESC`) and click **Logout**,
   then cancel at the character screen and log back in. Repeat after having run a reset.

**Expected.** The confirmation dialog appears every time and carries the collection's verbatim
wording. All three routes reset to defaults and survive `/reload`. Step 7 produces **no**
`Interface action failed because of an AddOn` red text on the Logout click.

**Pass / Fail.** PASS if all three reset routes confirm-then-reset and step 7 is clean.

---

## T-04 — Master controls tab still draws its reset pair (C-04 / `WHATGROUP-R-04`)

**Change covered:** C-04 — the `afterGroup` key is read from `Helpers.MASTER_GROUP`.

**Steps.**
1. `/wg config` → **General**.
2. Confirm the tab strip reads **Master controls | Chat | Popup**, in that order.
3. On **Master controls**, scroll to the bottom.
4. Click **Reset position**, then **Reset all settings**.

**Expected.** The **Reset position** and **Reset all settings** button pair is present at the bottom
of the Master controls tab (not under Chat, not under Popup). Both act.

**Pass / Fail.** PASS if the pair renders under the correct tab and both buttons work. A missing pair
is the exact silent failure C-04 exists to prevent — FAIL.

---

## T-06 — `IsSpellKnown` still answers correctly through the new rung (C-06 / `WHATGROUP-R-06`)

**Change covered:** C-06 — `C_SpellBook.IsSpellKnown` preferred over the bare global.
**This test decides whether C-06 ships at all.** The finding is filed unverified.

**Setup.** You need one **learned** and one **unlearned** dungeon teleport, both keyed in
`defaults/TeleportSpells.lua`.

**Steps.**
1. `/run print(type(C_SpellBook and C_SpellBook.IsSpellKnown), type(IsSpellKnown))` — record both.
2. `/run local id = <learned teleport spellID> print(C_SpellBook and C_SpellBook.IsSpellKnown and
   C_SpellBook.IsSpellKnown(id), IsSpellKnown and IsSpellKnown(id))` — record both.
3. Repeat step 2 with the **unlearned** spellID.
4. Join (or `/wg test` against) a dungeon with the **learned** teleport: the popup's icon is full
   colour and clicking it casts.
5. Join (or fake) one with the **unlearned** teleport: the icon is desaturated at half alpha, the
   note reads `Teleport spell not learned`, and clicking it casts nothing.
6. Repeat 4 and 5 with `Teleport spell` ticked in the Chat tab and read the chat rows.

**Expected.** Steps 2 and 3 return the **same** answer from both APIs. Steps 4–6 behave exactly as
before the change.

**Pass / Fail.** PASS if the two APIs agree and behaviour is unchanged. If step 1 shows
`C_SpellBook.IsSpellKnown` is `nil`, or step 2/3 disagree, **do not ship C-06** — revert it and
record the client's answer in a comment at `core/Compat.lua:62`.

---

## T-07 — Interleaved applications pair with the right group (C-07 / `WHATGROUP-R-07`)

**Change covered:** C-07 — captures keyed by search-result id rather than FIFO-popped.

**Setup.** `/wg debug on` and `/wg debug` to open the console. Open the Premade Group Finder,
Dungeons, and find at least **three** listed groups for **visibly different** dungeons.

**Steps.**
1. Click **Sign Up** on group A, then immediately on group B, then C — as fast as the UI allows,
   without waiting for any status.
2. Read the debug console's `[Apply]` lines: one per sign-up, each naming a distinct title.
3. Read the `[LFG]` lines as `applied` statuses arrive.
4. Withdraw from B. Read the console.
5. Accept an invite from whichever group offers one first.
6. Read the `[Invite]` line and then the popup and chat summary.
7. Leave the group. Read the `[Roster]` line.
8. Repeat the whole sequence twice more.

**Expected.**
- Step 6: the `[Invite]` line's title, the popup's **Group** row and the chat summary's **Group** row
  all name **the group you actually joined**, and the **Instance** row names its dungeon.
- Step 4: withdrawing does not leave a stale entry — a later accept from A or C is still correct.
- Step 7: `[Capture] wiped` or the `[Roster]` line, and `/wg show` then says the info is gone.
- No Lua errors at any point.

**Pass / Fail.** PASS only if all three repetitions name the correct group. This is the addon's core
job; one wrong group is a FAIL.

---

## T-08 — Packaged build carries no dev content (C-08 / `WHATGROUP-R-09`)

**Steps.**
1. Run the packager (or inspect the produced zip).
2. List its contents.

**Expected.** No `media/screenshots/`, no `CLAUDE.md`, no `DEPENDENCIES.md`, no `docs/`, no `tests/`,
no `.luacheckrc`. `media/logos/whatgroup.logo.tga` **is** present; the `.png` and `.jpg` are not.

**Pass / Fail.** PASS if the zip contains exactly the runtime payload plus `README.md` and `LICENSE`.
Then install that zip and run T-04 against it — the settings landing page must still draw its logo.

---

## Regression suite

Run after all changes, on a fresh SavedVariables, regardless of which tests above passed.

| # | Check | Expected |
|---|---|---|
| R-1 | Log in with no `WhatGroup.lua` in SavedVariables | No error; **Ka0s WhatGroup** appears in Settings → AddOns immediately, without running `/wg config` |
| R-2 | `/reload` immediately after login | Clean; no error popup, no red taint text |
| R-3 | `/reload` **while in combat** on the dummy | Clean; the category is still in the AddOns list afterwards |
| R-4 | `/wg` with no argument | Prints the help header and all 11 verbs, each with the cyan `[WG]` tag |
| R-5 | Every verb once: `help show test config version list get set reset resetall debug` | Each answers; none raises; `/wg reset` with no path prints the three-line deprecation notice |
| R-6 | `/wg config`, then toggle **every** control on all three tabs at least once | No errors; each change visibly takes effect or is visibly refused |
| R-7 | Same as R-6 but **in combat** on the dummy | `/wg config` refuses with the combat notice; size and scale changes are refused and land on the next out-of-combat open; alpha changes land immediately |
| R-8 | Drag the popup, `/reload`, re-open | The popup returns to where it was dragged |
| R-9 | Tick **Lock frame**, try to drag | The popup does not move; untick and it moves again |
| R-10 | `/wg debug on`, `/wg debug`, use every console control, `/wg debug off` | The console opens in a monospace face, the header toggle flips state, `ESC` closes it |
| R-11 | Profile switch via AceDB (if a second profile exists) | Open panels re-read the new profile's values without being closed and reopened |
| R-12 | Full LFG cycle: sign up → invited → accepted → notify + popup → leave group | Chat summary and popup both correct; `/wg show` works while in the group and prints the hint after leaving |
| R-13 | Click the `[Click here to view details]` chat link, then `/reload`, then click it again | First click opens the popup; after `/reload` it prints the "no longer available" hint, not an empty popup |
| R-14 | `ESC` with the popup open, and with the debug console open | Each closes the topmost window; the game menu does not open instead |

---

## Taint-specific tests

Run these because C-01 adds two event registrations and C-03 changes a `StaticPopupDialogs` write.

| # | Check | Expected |
|---|---|---|
| X-1 | Fresh login, no addon interaction at all, then `ESC` → **Logout** | No `Interface action failed because of an AddOn` text. This is the exact regression `modules/Frame.lua`'s lazy build and `settings/Schema.lua`'s lazy popup registration exist to prevent |
| X-2 | Same, but after `/wg resetall` → **Yes** first | Same |
| X-3 | Same, but after opening the popup and clicking a **learned** teleport | The teleport casts; then Logout is clean |
| X-4 | In combat on the dummy, click an action bar slot immediately after the popup auto-appears (T-01 step 4) | The ability fires; no red taint text |
| X-5 | Open Settings from **ESC → Options → AddOns → Ka0s WhatGroup**, then from `/wg config` | Both land on the same page; neither taints |
| X-6 | In combat, click the popup's teleport button for a spell on cooldown | Nothing casts, no error, no taint text |

---

## Performance spot-checks

The addon ships no `tests/perf.lua` and wires no `LibKa0s-Perf-1.0` (ratified `performance-§12`
deviation), so there is no `/wg perf` verb and no two-arm capture protocol to run. Use the fallback:

1. With a live teleport cooldown and the popup **open**: `/run collectgarbage("collect")
   print(collectgarbage("count"))`, wait 60 s, print again. Record the delta.
2. Repeat with the popup **closed** (C-02's whole point). The delta must be indistinguishable from
   an idle client — this is the observable form of "the ticker does not run behind a hidden popup".
3. Repeat with **General visibility** = `Only in combat`, out of combat, after a `/wg show`.
4. `/console scriptProfile 1` → `/reload` → pull the dummy for 30 s →
   `/run UpdateAddOnCPUUsage() print(GetAddOnCPUUsage("WhatGroup"))`. Note the profiler attributes
   shared-frame time coarsely, so read this as a sanity bound, not as the addon's cost.

**Expected.** Steps 2 and 3 show no ongoing allocation attributable to the addon. Step 4 is
negligible against a baseline with the addon disabled.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 (T-01) | | | |
| C-02 (T-02) | | | |
| C-03 (T-03) | | | |
| C-04 (T-04) | | | |
| C-06 (T-06) | | | **Gates whether C-06 ships** |
| C-07 (T-07) | | | |
| C-08 (T-08) | | | |
| C-05 / C-09 / C-10 / C-11 / C-12 | | | Headless or trivial; covered by the pre-flight and R-6 |
| Regression R-1 … R-14 | | | |
| Taint X-1 … X-6 | | | |
| Perf 1 … 4 | | | |
