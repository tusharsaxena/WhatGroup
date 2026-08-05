# 03 — Manual smoke tests (in-client)

Execute **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Everything that runs
headless — `luacheck .`, `lua tests/run.lua`, `lizard` — was already run in Step 0 and is recorded in
`01_FINDINGS.md`; it is **not** repeated here.

**Pre-flight (one command, then log in):**

```
luacheck . && lua tests/run.lua
```

Both must be clean/green before you install the build. Expect **425 passed, 0 failed** once C-02,
C-03 and C-08 have landed (422 today).

---

## Pre-flight — client setup

1. Retail only. TOC declares `## Interface: 120007`; do not test on Classic (anti-patterns #15 —
   this addon is Retail-only by design).
2. Copy the working tree to `World of Warcraft/_retail_/Interface/AddOns/WhatGroup/`.
3. `/console scriptErrors 1` — Lua errors must be visible, not swallowed.
4. Character requirements: one character who **knows at least one dungeon teleport spell** (any
   Dungeon Teleport from a Mythic+ season) and one who does **not**, so T-05 can exercise both arms
   of the teleport button. A second player or a guildmate is needed for the group-join tests; the
   Premade Group Finder listing you apply to must be one you can actually be invited to.
5. Before the first run: back up `WTF/Account/<ACCOUNT>/SavedVariables/WhatGroup.lua`, then delete it
   so R-02 starts from genuinely fresh SavedVariables.
6. `/etrace` open and filtered to `LFG_LIST_APPLICATION_STATUS_UPDATED` and `GROUP_ROSTER_UPDATE`
   makes T-01 and T-02 legible; `/wg debug on` then `/wg debug` puts the addon's own trace on screen.

---

## T-01 — Master switch actually stops the addon (C-01)

**Change covered:** C-01 — gate the `inviteaccepted` branch on `db.profile.enabled`.

**Setup:** fresh login, no combat, `/wg debug on` and the console window open.

**Steps:**
1. `/wg config` → **General** → untick **Enable**. (Or `/wg set enabled false`.)
2. Confirm with `/wg get enabled` that it reads `false`.
3. Open the Premade Group Finder, apply to any listed group.
4. Wait for the group leader to invite you; **accept** the invite.
5. Watch chat and the screen for 15 seconds after joining.

**Expected:**
- **No** `[WG] You have joined a group!` line and no `- Group:` / `- Instance:` / `- Leader:` lines.
- **No** WhatGroup popup window appears.
- The debug console shows `[LFG] appID=… status=inviteaccepted` followed by
  `[LFG] ignored: addon disabled`.
- No Lua error.

**Pass / Fail:** PASS only if zero WhatGroup chat lines and zero popup between the accept and 15s
after the roster settles. Any `[WG]` notification line is a FAIL — that is exactly the F-001 symptom.

---

## T-02 — Re-enabling resumes the full flow (C-01 regression guard)

**Change covered:** C-01 — the gate must not be sticky.

**Setup:** immediately after T-01, still grouped or after leaving the group.

**Steps:**
1. `/wg set enabled true`.
2. `/wg reload`-free: leave the group if still in one, then apply to another Premade listing.
3. Accept the invite.

**Expected:** the full seven-line chat summary prints (`You have joined a group!`, `Group:`,
`Instance:`, `Type:`, `Leader:`, `Playstyle:` where available, and the `[Click here to view
details]` link), and the popup opens (Auto Show is on by default). Debug console shows
`[Invite] accepted appID=… → "<title>" map=… (source=fresh)`.

**Pass / Fail:** PASS if the notification and popup both appear. FAIL if the gate from C-01 leaked
into the enabled path.

---

## T-03 — `/wg get` no longer writes to SavedVariables (C-03)

**Change covered:** C-03 — read-only path resolution.

**Setup:** fresh login.

**Steps:**
1. `/wg resetall` → confirm **Yes** in the popup. (This wipes `db.profile` and re-threads defaults.)
2. `/wg get notify.delay` and `/wg get frame.autoShow` — note the printed values.
3. `/reload`.
4. Exit the game fully (SavedVariables are only flushed on logout/reload), then open
   `WTF/Account/<ACCOUNT>/SavedVariables/WhatGroup.lua` in a text editor.

**Expected:** every key under `["profile"]` corresponds to a schema row in `settings/Schema.lua` —
`enabled`, `frame.autoShow`, `notify.{enabled,delay,showInstance,showType,showLeader,showPlaystyle,
showClickLink,showTeleport}`. There are **no** empty tables and no keys the schema does not declare.

**Pass / Fail:** PASS if the profile contains only schema-declared keys. FAIL if any empty table or
unknown key appears.

---

## T-04 — Popup playstyle still renders identically (C-04)

**Change covered:** C-04 — popup calls `Labels.GetPlaystyleLabel`.

**Setup:** any character, out of combat.

**Steps:**
1. `/wg test` — this injects a capture with `playstyleString = ""` and
   `generalPlaystyle = FunSerious`, exercising the **enum** branch.
2. Read the popup's **Playstyle:** row.
3. Close the popup. Join a real Premade group whose listing carries a playstyle description (the
   LFG UI shows one) — this exercises the **playstyleString** branch.
4. Read the popup's **Playstyle:** row again, and the chat `- Playstyle:` line.

**Expected:** step 2 shows the localized enum label ("Fun (Serious)" on enUS — Blizzard's
`GROUP_FINDER_GENERAL_PLAYSTYLE3`). Step 4 shows the listing's own playstyle text, and the popup row
and the chat row show **the same string**. A group with neither shows a dim `—` in the popup and no
`Playstyle:` chat row at all.

**Pass / Fail:** PASS if popup and chat agree in all three cases and no row renders blank or `nil`.

---

## T-05 — Teleport button casts exactly once per click (C-05)

**Change covered:** C-05 — `RegisterForClicks("AnyUp")` only. **This is the change that cannot be
verified headlessly; it is the reason this document exists.**

**Setup:** a character who **knows** a dungeon teleport (e.g. any current-season Mythic+ teleport),
standing in a city, out of combat, `/wg debug on` with the console open.

**Steps:**
1. Join (or `/wg test`, then use a real join for the teleport to be castable) a group for a dungeon
   whose teleport you know, so the popup's teleport icon is bright rather than desaturated.
2. Hover the teleport icon — confirm the spell tooltip appears.
3. Left-click the icon **once**. Do not double-click.
4. Read the debug console and the chat error area.
5. Press **Esc** to cancel the teleport cast.
6. Repeat steps 3–5 on a character who does **not** know the spell (icon desaturated, ~50% alpha).

**Expected:**
- Exactly **one** `[Frame] teleport button pressed → /cast <SpellName> (spellID=…, button=LeftButton)`
  line in the console per click — not two.
- The teleport cast begins once. **No** red "You are already casting" / "Another action is in
  progress" error follows the single click.
- On the character who does not know the spell: the icon is desaturated, the button does not respond
  to the mouse, and no `PreClick` line and no error appear.

**Pass / Fail:** PASS if one click yields exactly one console line, one cast start, and zero red
errors. Two console lines or a spurious cast error is a FAIL — the double-edge dispatch survived.

---

## T-06 — Popup builds and anchors correctly (C-07)

**Change covered:** C-07 — guarded offset derivation.

**Setup:** fresh SavedVariables (so no saved popup position), out of combat.

**Steps:**
1. `/wg test`.
2. Inspect the popup: the **Teleport:** label and the teleport icon must sit on the same baseline,
   with the icon immediately to the right of the label column — the same alignment as the
   **Playstyle:** row's value above it.
3. Drag the popup by its title bar to a screen corner, close it, `/reload`, `/wg test` again.
4. Confirm the popup reopens at the dragged position with the icon **still** aligned to its label.

**Pass / Fail:** PASS if the icon is aligned in both step 2 and step 4 and no Lua error appears when
the popup is first built. FAIL on any misalignment (the fallback offsets fired when they should not
have) or on an error inside `ShowFrame`.

---

## T-07 — Locale rows removed without changing any visible string (C-06)

**Change covered:** C-06 — five dead locale rows deleted.

**Setup:** any character, out of combat.

**Steps:**
1. `/wg config`.
2. Read the sidebar entry name, the landing page's heading above the command list, the **General**
   sub-page name, and the **Defaults** button in the page header.
3. Enter combat (target dummy) and run `/wg config`.

**Expected:** the sidebar reads **Ka0s WhatGroup**, the heading reads **Slash Commands**, the
sub-page reads **General**, the header button reads **Defaults** — all exactly as before the change.
In combat, `/wg config` prints the gray `[WG] cannot open settings during combat — Blizzard's
category-switch is protected` notice and the panel does **not** open.

**Pass / Fail:** PASS if all four strings are unchanged and the combat refusal still prints the
canonical sentence. Any string rendering as a raw key (e.g. a literal `SLASH_COMMANDS`) is a FAIL.

---

## Regression suite (not tied to one change)

| # | Check | Expected |
|---|---|---|
| R-01 | `/reload` with the popup open and the debug console open | Both close and reopen cleanly on the next `/wg test` / `/wg debug`; no error |
| R-02 | First login with SavedVariables deleted | Defaults populate; `/wg list` shows every row at its shipped default; `WhatGroupDB` exists after logout |
| R-03 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No Lua error at any point; **Ka0s WhatGroup** is in Settings → AddOns **without** running `/wg config` first |
| R-04 | Enter and leave combat with the popup open | Popup stays visible; no error; the teleport button keeps its state |
| R-05 | `/wg show` in combat, popup never built this session | Prints `[WG] Popup deferred until combat ends.`; popup opens automatically once combat drops |
| R-06 | Every settings toggle flipped at least once via the panel, then `/wg list` | Every value in `/wg list` matches the widget state; each flip logs one `[Set] <path> = <value>` console line |
| R-07 | Every toggle flipped again via `/wg set <path> toggle` | Panel widgets re-sync on screen without reopening the panel |
| R-08 | `/wg resetall` → **Yes** | Exactly one `[Reset] restored N settings to defaults (profile wiped)` console line and **zero** `[Set]` lines; all widgets return to defaults |
| R-09 | `/wg reset` with no argument | Prints the three-line deprecation notice pointing at `/wg reset <path>` and `/wg resetall`; resets nothing |
| R-10 | Click a stale `[Click here to view details]` link after leaving the group | Prints the "Group info no longer available" hint; no popup, no error |
| R-11 | Every verb in `/wg help` invoked once | Each produces output; none errors; the list matches `README.md:49-60` |
| R-12 | GameMenu (Esc) → click **Logout**, then **Settings**, then **Macros** | No `ADDON_ACTION_FORBIDDEN` red text — the taint deferrals in `modules/Frame.lua` and `settings/Schema.lua:444` still hold |

---

## Taint-specific tests

Raised because C-05 touches a `SecureActionButtonTemplate` frame and C-01 changes an event handler
that runs during a group join.

| # | Check | Expected |
|---|---|---|
| X-01 | Open the popup **for the first time this session while in combat** (`/wg show` at a target dummy with a live capture) | Chat hint prints; **no** popup and **no** secure frame is created during combat; popup builds automatically on `PLAYER_REGEN_ENABLED` |
| X-02 | With the popup already built, join a group **while in combat** so the teleport button must reconfigure | No error; the button keeps its previous visual state during combat and updates to the new dungeon's teleport the moment combat ends |
| X-03 | After X-02, click any action bar slot | No `Interface action failed because of an AddOn` red text |
| X-04 | Open the settings panel from `/wg config` **and** from Esc → Options → AddOns → Ka0s WhatGroup | Both open the same page; neither produces a forbidden-action error |
| X-05 | Full session: log in, `/wg test`, open panel, open debug console, join a group, then Esc → **Logout** | Logout works; no `ADDON_ACTION_FORBIDDEN … 'callback()'` |

---

## Localization sanity

C-06 touches `locales/enUS.lua`, so one non-enUS pass is warranted.

1. Switch the client to **deDE**, log in, `/wg test`.
2. Confirm the popup and the chat summary render — untranslated English is **expected and correct**
   (the metatable returns the key), but nothing may render as an empty string or as a raw
   SCREAMING_SNAKE token.
3. Confirm the **Playstyle** row shows Blizzard's *German* playstyle wording, since those values come
   from `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` rather than from `NS.L`.
4. Confirm `/wg config` opens and the four panel strings from T-07 still read correctly.

---

## Performance spot-checks

**Not applicable.** This addon ships no perf harness: there is no `tests/perf.lua`, no
`docs/performance.md` and no `docs/perf-runs/`; it wires no `LibKa0s-Perf-1.0` bucket and brackets no
path (`docs/automated-tests/RESULTS.md` records `perf: skip` for the same reason). None of C-01…C-08
is perf-tagged, none touches an `OnUpdate` or a per-frame path, and no claim in this bundle asserts a
cost change. Adding a capture protocol here would be inventing evidence for a claim nobody made.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| T-01 | | | |
| T-02 | | | |
| T-03 | | | |
| T-04 | | | |
| T-05 | | | |
| T-06 | | | |
| T-07 | | | |
| R-01…R-12 | | | |
| X-01…X-05 | | | |
| Locale (deDE) | | | |
