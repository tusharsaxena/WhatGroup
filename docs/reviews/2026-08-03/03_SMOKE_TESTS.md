# Ka0s WhatGroup — Manual Smoke Tests (2026-08-03)

Run **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Every step is literal:
type what is written, click what is named, compare against the stated expected output.

---

## Pre-flight

1. **Headless gates first** (they catch most regressions before the client is involved), from the
   repo root:
   - `lua tests/run.lua` → must end `NNN passed, 0 failed`.
   - `luacheck .` → must end `0 warnings / 0 errors`.
2. **Install:** copy/symlink the repo folder as `Interface/AddOns/WhatGroup`. The folder **must** be
   named `WhatGroup` (media paths and the metadata lookup key depend on it).
3. **Client:** Retail only. TOC `## Interface:` must match the live retail build (`120007` at the
   time of this review — do not change it as part of this work).
4. **Character:** any max-level character able to use Premade Group Finder, on a realm where you can
   actually apply to a group. A second character on the same account is useful for the profile-switch
   regression check.
5. **Error visibility:** `/console scriptErrors 1` and `/reload`. Every test below fails if a Lua
   error popup appears at any point, whether or not the step mentions it.
6. **Baseline SavedVariables:** for the tests marked *fresh SV*, log out, delete
   `WTF/Account/<ACC>/SavedVariables/WhatGroup.lua`, and log back in.
7. **Debug visibility:** `/wg debug on` then `/wg debug` opens the on-screen console. Most expected
   outputs below name a `[Tag]` console line; keep the console open while testing.

---

## C-01 — Wipe generation gates the deferred popup's `pendingInfo` restore

**Change covered:** C-01 — a capture wiped during a combat wait is no longer resurrected (F-001).

### C-01-a — the deferral still works when nothing was wiped (must not regress)

- **Setup:** in a group with captured info (join via Premade Group Finder, or `/wg test` then
  `/reload` is *not* equivalent — use a real join, or `/wg test` and skip to C-01-b). Popup never
  opened yet this session (`/reload` first).
- **Steps:**
  1. Pull a target dummy (Stormwind: Trade District dummies) and stay in combat.
  2. Type `/wg show`.
  3. Stop attacking; wait for combat to drop.
- **Expected:** step 2 prints `[WG] Popup deferred until combat ends.`; no popup while in combat;
  within a second of leaving combat the popup opens showing the real group's Group / Instance /
  Type / Leader rows.
- **Pass:** popup opens after combat with the correct group's data. **Fail:** no popup, "No data",
  or a Lua error.

### C-01-b — a wipe during the wait wins

- **Setup:** `/reload` (popup never built this session). Be in a group whose info was captured.
- **Steps:**
  1. Enter combat on a dummy.
  2. `/wg show` → expect the deferral message.
  3. **While still in combat**, leave the group (`/run C_PartyInfo.LeaveParty()` or right-click your
     portrait → Leave Group).
  4. Leave combat.
- **Expected:** the popup opens with **"No data"** in Group / Instance / Type / Leader and a dim
  em-dash for Playstyle; the teleport button is hidden. Console shows `[Roster] inGroup=false …`
  from step 3.
- **Pass:** "No data" popup, no stale group name anywhere. **Fail:** the popup shows the group you
  just left.

### C-01-c — the resurrected capture can no longer hijack the next join (the actual bug)

- **Setup:** continue directly from C-01-b without `/reload`.
- **Steps:**
  1. Have a friend/alt invite you to a party (a plain invite — **do not** apply via Group Finder).
  2. Accept the invite.
  3. Watch chat and the screen for ~10 seconds.
- **Expected:** **no** `[WG] You have joined a group!` block, **no** popup. The console shows
  `[Roster] inGroup=true …` and nothing else from WhatGroup.
- **Pass:** silence. **Fail:** any chat notification or popup naming the group from C-01-b.

---

## C-02 — Dead applications are reclaimed

**Change covered:** C-02 — declined/cancelled applications no longer accumulate (F-006).

- **Setup:** `/wg debug on`, console open. Not in a group.
- **Steps:**
  1. Open Premade Group Finder, apply to three listings.
  2. Cancel your application to one of them (click the pending entry → Cancel), and let another be
     declined if possible.
  3. `/run local n=0 for _ in pairs(_G) do end print("ok")` — (no direct handle to the private
     table; use the console instead) → confirm the console shows one `[LFG] appID=… status=applied`
     per application and one `[LFG] appID=… status=cancelled` / `declined` for the terminated ones.
  4. Now join one group for real (apply → invited → accept).
- **Expected:** the normal `[Apply]` → `[LFG]` → `[Invite] accepted appID=… → "<title>"` sequence,
  and the notification names the group you actually joined — not one of the cancelled ones.
- **Pass:** correct group announced; no Lua error on any status transition. **Fail:** wrong group
  named, or an error on a cancelled/declined status.

---

## C-03 / C-04 — Capture shape and playstyle label

**Changes covered:** C-03 (`shortName` seeded), C-04 (popup uses `Labels.GetPlaystyleLabel`)
(F-009, F-002).

- **Setup:** `/reload`. Fresh chat.
- **Steps:**
  1. `/wg test`.
  2. Read the chat block and the popup side by side.
  3. Join (or `/wg test` after joining) a real group whose listing has a custom playstyle string.
- **Expected:** for `/wg test`, chat's `- Type:` row and the popup's **Type** row both read
  `Mythic+`; chat's `- Playstyle:` and the popup's **Playstyle** row read the **same** text
  (`Fun (Serious)` on an enUS client). For the real group, both surfaces show the listing's
  server-rendered playstyle text, identical to each other.
- **Pass:** chat and popup agree on both rows in both scenarios. **Fail:** any difference between
  the two surfaces, or an empty/`nil` Type row.

---

## C-05 — `Compat.GetAddOnMetadata`

**Change covered:** C-05 — metadata reads routed through Compat (F-003).

- **Setup:** `/reload`.
- **Steps:**
  1. `/wg version`.
  2. `/wg config`, and read the landing page (the page you land on before clicking **General**).
  3. `/run print(WhatGroup and "global leaked" or "no global")` → must print `no global`.
- **Expected:** step 1 prints `[WG] v<the exact string in WhatGroup.toc's ## Version:>`. Step 2's
  landing page shows the logo, then the one-line description **"Notifies you of group details after
  joining via Premade Group Finder"** (the TOC `Notes` value), then the **Slash Commands** heading
  and one row per command.
- **Pass:** version matches the TOC exactly and the Notes line is non-empty. **Fail:** a blank
  description line, or a version that differs from the TOC.

---

## C-06 — Migration runner

**Change covered:** C-06 — no unconditional `schemaVersion` stamp (F-004).

### C-06-a — fresh database

- **Setup:** *fresh SV* (delete `WhatGroup.lua` from SavedVariables), log in.
- **Steps:** `/wg debug on` → read the `[Init]` line in the console. Then `/reload`.
- **Expected:** the `[Init]` line contains `schema v1`. **No** `[Migrate]` line on either login.
- **Pass:** `schema v1`, no `[Migrate]`. **Fail:** any `[Migrate]` line, or `schema vnil`.

### C-06-b — future-versioned database is left alone

- **Setup:** log out. Edit `SavedVariables/WhatGroup.lua`, set `["schemaVersion"] = 99` inside the
  `global` table. Log in.
- **Steps:** `/wg debug on` → read the console; `/reload`; log out and re-open the SavedVariables
  file.
- **Expected:** the console shows `[Migrate] db is newer (v99) — left as-is`; after logout the file
  still reads `["schemaVersion"] = 99`.
- **Pass:** value unchanged at 99. **Fail:** the value was rewritten to 1.
- **Cleanup:** restore a *fresh SV* before continuing.

---

## C-07 — Teleport button anchor

**Change covered:** C-07 — nil-safe geometry (F-005).

- **Setup:** `/reload`. A character that knows at least one dungeon teleport (any Path-of spell).
- **Steps:**
  1. `/wg test`.
  2. Look at the **Teleport:** row of the popup.
  3. Hover the icon, then click it.
  4. Drag the popup by its title bar to a different screen position, close it (**ESC**), `/reload`,
     `/wg test` again.
- **Expected:** the teleport icon sits immediately right of the **Teleport:** label, vertically
  centered on that row (not overlapping the Playstyle row, not off the frame). Hover shows the spell
  tooltip. Click casts (or is desaturated at 50% alpha with no tooltip if you don't know the spell —
  The Stonevault, spell 445269). After `/reload` the popup re-opens at the dragged position with the
  icon still correctly placed.
- **Pass:** icon aligned in all four steps, no Lua error on first build. **Fail:** icon at the
  frame's top-left corner, overlapping text, or an arithmetic error on first `/wg test`.

---

## C-08 — Defaults button latch

**Change covered:** C-08 — the deferred build no longer latches (F-013).

- **Setup:** `/reload`.
- **Steps:**
  1. `/wg config` → click **General** in the sidebar.
  2. Confirm a **Defaults** button in the page header (top-right).
  3. Press **ESC** to close Settings; re-open with `/wg config` → **General**. Repeat three times.
  4. Click **Defaults** → click **Yes** in the confirmation popup.
- **Expected:** the Defaults button is present on **every** visit, and there is never more than one.
  Step 4 prints `[WG] all settings reset to defaults` and the console shows a single `[Reset]
  restored N settings to defaults (profile wiped)` line with **no** per-row `[Set]` lines.
- **Pass:** exactly one button every time; one `[Reset]` line. **Fail:** the button missing on any
  visit, two buttons, or a burst of `[Set]` lines.

---

## C-09 — Housekeeping (locale keys, alias, lint globals, chat voice)

**Change covered:** C-09 (F-008, F-010, F-011, F-012).

- **Setup:** `/reload`.
- **Steps:**
  1. `/wg config` → **General**. Read the sidebar entry and the page title.
  2. Enter combat on a dummy, type `/wg config` while in combat.
  3. `/wg` (bare) and read the help block.
  4. Leave combat.
- **Expected:** step 1's sidebar reads **General** under **Ka0s WhatGroup** (unchanged). Step 2
  prints the library's combat refusal (`cannot open settings during combat — Blizzard's
  category-switch is protected`) and opens nothing. Step 3 prints the `[WG] v<version> slash
  commands` header and all 11 verbs. No chat line anywhere starts with a capitalized sentence that
  reads unlike the rest.
- **Pass:** all labels render as English words (never `SCREAMING_SNAKE` or a raw key), combat
  refusal appears once per attempt. **Fail:** any placeholder-looking text, or a missing panel entry.

---

## C-10 — Release hygiene

**Change covered:** C-10 (F-007). Documentation-only; verify by reading, not by clicking.

- **Steps:**
  1. `/wg version` in game.
  2. Open `WhatGroup.toc`, `core/WhatGroup.lua` and `README.md`.
- **Expected:** the version printed in game, `## Version:`, `WhatGroup.VERSION`, the
  `## What's new in <X.Y.Z>` heading and the top `## Version History` row **all** name the same
  version; the What's new bullets describe the `/wg reset` / `/wg resetall` change.
- **Pass:** five places agree. **Fail:** any disagreement.

---

## Regression suite (not tied to one change)

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` three times in a row | No Lua error; `[WG]` prints nothing unsolicited |
| R-2 | Fresh SV → login | Settings populate at defaults; `/wg list` shows all 9 rows with their default values |
| R-3 | Login sequence | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` with no error; **Ka0s WhatGroup** already present in Settings → AddOns **without** running `/wg config` |
| R-4 | Enter and leave combat with the popup open and the debug console open | Both stay visible; no error; no "Interface action failed because of an AddOn" |
| R-5 | Toggle **every** option in Settings → General and Notify once each | Each toggle prints one `[Set] <path> = <value>` console line and the widget stays in sync |
| R-6 | `/wg set notify.delay 3`, then join a group | Notification and popup appear ~3s after the join |
| R-7 | `/wg set enabled off`, apply to a group, get invited, accept | No capture, no notification, no popup; console shows `[Capture] wiped (addon disabled)` if something was in flight |
| R-8 | `/wg set notify.showTeleport toggle` twice | Value flips both times; `[Set]` line each time |
| R-9 | AceDB profile switch (`/run WhatGroup` is not available — switch via a second character on the same account) | Settings load for the new profile with no error; panel widgets re-sync |
| R-10 | Click the chat `[Click here to view details]` link after `/reload` | Prints the "Group info no longer available …" hint, no popup, no error |
| R-11 | `/wg debug on`, `/wg debug`, close the console with **ESC**, re-open Settings → General | The **Debug console** checkbox reflects the window being closed |
| R-12 | `/wg reset` (bare) | Prints the deprecation block naming `/wg reset <path>` and `/wg resetall` |
| R-13 | `/wg resetall` → **Yes** | One `[Reset]` line; every setting back to default; `/wg list` confirms |
| R-14 | Rename `libs/LibKa0s` to `libs/LibKa0s_off`, `/reload` | Addon still loads; first `[WG]` line names the missing library; `/wg config`, `/wg debug` and `/wg list` each say so once; **no Lua error**. Restore the folder afterwards. |

---

## Taint-specific tests

The review flagged no new taint defects, but C-01/C-07 touch the lazily-built secure surface, so
re-run the existing guarantees:

| # | Check | Expected |
|---|---|---|
| T-1 | Fresh `/reload`, do **not** open the popup. Open the game menu (**ESC**) and click **Logout**, then cancel. | No red "Interface action failed because of an AddOn" text; the Logout dialog appears |
| T-2 | Repeat T-1 **after** `/wg test` has built the popup once | Same — no ADDON_ACTION_FORBIDDEN |
| T-3 | In combat on a dummy, click an action bar slot; then `/wg test` (popup already built) | Action fires normally; popup shows; the teleport button keeps its previous visual state until combat ends, then updates |
| T-4 | Open the panel from `/wg config` **and** from **ESC → Options → AddOns → Ka0s WhatGroup → General** | Both routes reach the same page and render the same widgets |
| T-5 | `/wg resetall` → **Yes** while a StaticPopup has never been shown this session | The confirmation dialog appears and works (lazy registration), no taint error afterwards on **ESC → Logout** |

---

## Localization sanity

C-09 touches `locales/enUS.lua`. English-only content is a documented scope decision
(`docs/scope.md`), so this is a "nothing broke" check rather than a translation check.

- Switch the client to **deDE**, `/reload`, then run: `/wg test`, `/wg config` → **General**,
  `/wg` (help).
- **Expected:** every WhatGroup string still renders as readable English (the metatable fallback
  answers each key with itself); Blizzard-sourced strings (playstyle names, YES/NO on the reset
  popup) render in German; nothing renders as a bare key in caps.
- Switch back to enUS afterwards.

---

## Performance spot-checks

No perf-tagged changes were made (C-02 removes a small unbounded accumulation). One optional check:

- `/run collectgarbage("collect") collectgarbage("count")` — note the number. Apply to and cancel
  ten Premade listings. Re-run the same command.
- **Expected:** the second reading is within normal churn of the first; no monotonic growth
  attributable to WhatGroup (which is what C-02 addresses).

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01-a | | | |
| C-01-b | | | |
| C-01-c | | | |
| C-02 | | | |
| C-03 / C-04 | | | |
| C-05 | | | |
| C-06-a | | | |
| C-06-b | | | |
| C-07 | | | |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | |
| R-1 … R-14 | | | |
| T-1 … T-5 | | | |
| Localization | | | |
| Perf spot-check | | | |
</content>
