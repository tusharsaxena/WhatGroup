# Smoke tests

WhatGroup has no automated test suite — every behaviour the addon ships is validated **manually, in-game**. This file is the canonical checklist. Run the relevant section after any of:

- `/wow-addon:commit` of a non-trivial change
- A WoW patch (Interface bump)
- A `libs/` refresh from KickCD
- Before tagging a release

Each section lists steps, the expected outcome, and (when relevant) the bug it guards against. Times are wall-clock estimates assuming you're already logged in.

---

## 1. Boot smoke (~1 min)

Verifies the addon loads cleanly and registers nothing that taints Blizzard's secure-execute chain.

### 1.1 Cold load

1. Quit the game completely.
2. Launch, log in to any character.
3. Open chat.

**Expected:** No Lua errors. No `[WG]` lines on first boot beyond what `/wg debug` would print (which is OFF by default).

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
- After `/wg config` (exercises lazy `Settings.Register`)
- After `/wg reset` confirm (exercises lazy `StaticPopupDialogs["WHATGROUP_RESET_ALL"]`)
- After clicking the teleport button on the popup
- After applying to a real LFG group

If **any** of these tests reproduces the taint error, the boot path has regressed — see [wow-quirks.md → Taint propagation in the boot window](./wow-quirks.md) and [common-tasks.md → Adding a Blizzard-protected surface touch](./common-tasks.md).

---

## 2. Slash commands smoke (~3 min)

Every entry in `WhatGroup.COMMANDS` is exercised at least once.

| # | Step | Expected |
|---|------|----------|
| 2.1 | `/wg` | Help index prints, listing all commands with the `[WG]` prefix. |
| 2.2 | `/wg help` | Same as 2.1. |
| 2.3 | `/whatgroup help` | Same — long alias works. |
| 2.4 | `/wg list` | Every setting prints under its `[section]` header with current value. |
| 2.5 | `/wg get enabled` | Prints `enabled = true`. |
| 2.6 | `/wg set notify.delay 2.5` | Prints `notify.delay = 2.5s`. Re-running `/wg get notify.delay` confirms. |
| 2.7 | `/wg set notify.enabled toggle` | Toggles bool — confirm with `/wg get notify.enabled`. Run twice to restore. |
| 2.8 | `/wg debug` | Prints `Debug mode: ON` (or OFF). Toggle back. |
| 2.9 | `/wg show` (no group, no pendingInfo) | Prints "No group info available. Use `/wg test` to preview." |
| 2.10 | `/wg test` | Synthetic chat notification + popup fire (full coverage in §4). |
| 2.11 | `/wg show` (right after 2.10) | Re-opens the same popup. |
| 2.12 | `/wg config` | Settings panel opens on the **Ka0s WhatGroup** landing page; the **General** subcategory is visible/expanded in the sidebar. |
| 2.13 | `/wg reset` | StaticPopup confirm appears. **Yes** resets all settings; **No** cancels. |
| 2.14 | `/wg gibberish` | Prints `unknown command 'gibberish'` followed by the help index. |
| 2.15 | `/wg config` while in combat | Prints "Cannot open the settings panel during combat. Try again after combat ends." (Pull a target dummy first to enter combat.) |

---

## 3. Settings panel smoke (~3 min)

Verifies AceGUI rendering, schema-driven widget refresh, and the Defaults flow.

### 3.1 Landing page

1. `/wg config`

**Expected:** Logo image renders. Notes one-liner is visible. "Slash Commands" heading + one row per `COMMANDS` entry. Scrollbar is visible (greyed out if content fits).

### 3.2 General subcategory

1. Click **General** in the Settings sidebar tree.

**Expected:** Two-column layout. Section headers **General** and **Notify**. **Defaults** button in the top-right corner. Hovering any widget shows a tooltip with the schema row's `tooltip` field.

### 3.3 Widget round-trip

1. Toggle **Auto Show** off.
2. Slide **Notification Delay** to 3.0s.
3. Close the Settings panel.
4. `/wg get frame.autoShow` → `false`.
5. `/wg get notify.delay` → `3.0s`.
6. `/wg set frame.autoShow on` → re-open Settings → checkbox is checked.
7. Restore both to defaults.

**Expected:** Panel widgets and slash-command get/set agree at every step. The schema-driven `_refreshers` keep the open panel in sync with `/wg set` writes.

### 3.4 Defaults button

1. Make several changes via the panel.
2. Click **Defaults**.
3. **Yes** in the confirm popup.

**Expected:** Every changed widget snaps back to its declared default. `/wg list` shows defaults. The chat line "all settings reset to defaults" prints with the `[WG]` prefix.

### 3.5 Test button

1. Settings panel → **General** → **Test** button.

**Expected:** Same flow as `/wg test` — chat notification + popup. Confirms the Test button shares the `WhatGroup:RunTest()` code path with the slash command.

---

## 4. Synthetic flow smoke — `/wg test` (~1 min)

Exercises the notify + popup pipeline end-to-end without needing a real LFG application.

1. `/wg test`

**Expected chat output (with default toggles):**

```
[WG] You have joined a group!
[WG]   - Group: Test Group — Stonevault +12
[WG]   - Instance: Dungeons > Mythic+ > The Stonevault
[WG]   - Type: Mythic+
[WG]   - Leader: Testadin-Silvermoon
[WG]   - Playstyle: Fun (Serious)
[WG]   - Teleport: [Path of the Corrupted Foundry]   (or "(not learned)" if you don't have the spell)
[WG]   - [Click here to view details]
```

**Expected popup:** All six rows populated (Group / Instance / Type / Leader / Playstyle / Teleport). Teleport icon is full-alpha if you know `Path of the Corrupted Foundry`, desaturated 50%-alpha otherwise.

### 4.1 Teleport button click

1. With the popup open from step 4 above, hover the teleport icon.
2. Click it (only meaningful if you have the spell learned).

**Expected:**
- Tooltip shows the spell.
- If learned: cast initiates (or fails for in-combat / wrong zone — that's still success: the secure click reached `CastSpellByID`).
- If not learned: nothing happens (button is `EnableMouse(false)`).
- **No `ADDON_ACTION_FORBIDDEN` line in chat.** This is the secure-button regression test.

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

1. `/wg debug` to turn on debug logging.
2. `/reload`
3. Open Premade Group Finder, find a Mythic+ or raid group.
4. Click **Apply**.
5. Wait for invite, accept it.
6. Watch chat.

**Expected debug trace (order may vary slightly):**

```
[WG][DBG] ApplyToGroup id=<N>
[WG][DBG] Capture: title=<X> activityID=<A> mapID=<M>
[WG][DBG] LFG_STATUS appID=<N> status=applied
[WG][DBG] LFG_STATUS appID=<N> status=invited            (some flows skip this)
[WG][DBG] LFG_STATUS appID=<N> status=inviteaccepted
[WG][DBG] inviteaccepted: pendingInfo=title=<X> mapID=<M>
[WG][DBG] ROSTER inGroup=true wasInGroup=false hasPending=true
[WG][DBG] Notify(<reason>) scheduling in <delay>s
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

**Expected debug trace:**

```
[WG][DBG] ROSTER inGroup=false wasInGroup=true hasPending=true
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

6. `/wg set notify.delay 1.5` to restore the default.

---

## 7. Patch-day smoke (~5 min)

Run after bumping the `## Interface:` line in `WhatGroup.toc` for a major patch.

1. Log in on the patched client.

**Expected:** No "out of date" warning in the AddOns dialog.

2. Run §1 (Boot smoke).
3. Run §4 (Synthetic flow — `/wg test`).
4. Run §5.1 (Real LFG flow, single application).

If any Blizzard API broke (e.g. fields renamed on `C_LFGList.GetActivityInfoTable`), the most likely failure point is `CaptureGroupInfo` returning incomplete data — see [capture-pipeline.md → Captured info](./capture-pipeline.md#captured-info) for the field list and remediation steps.

---

## 8. Lib-refresh smoke (~2 min)

Run after re-copying `libs/` from KickCD (see [common-tasks.md → Refresh embedded libs](./common-tasks.md#refresh-embedded-libs)).

1. `/reload` — confirm no boot errors.
2. `/wg config` — confirm AceGUI widgets render normally.
3. `/wg test` — confirm the pipeline still works end-to-end.

If a new Ace3 module was added or removed in KickCD, also update `WhatGroup.toc`'s lib block to match the directory layout. AceGUI's `.xml` always loads last because it pulls in `widgets/`.

---

## 9. Quick reference checklist

For a fast pre-release pass, run at minimum:

- [ ] §1.3 — ESC → Logout after `/reload`
- [ ] §1.3 — ESC → Logout after `/wg test`
- [ ] §1.3 — ESC → Logout after `/wg config`
- [ ] §2.1, §2.10, §2.12, §2.13 — `/wg help`, `/wg test`, `/wg config`, `/wg reset`
- [ ] §3.4 — Defaults button confirm flow
- [ ] §4.1 — Click teleport button (no taint)
- [ ] §5.1 — One real LFG apply → join

If all of those pass, the addon is in shippable shape for the 80% case. Run the full suite for releases tagged with feature work.
