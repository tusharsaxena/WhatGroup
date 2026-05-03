# Ka0s WhatGroup — Review Smoke Tests

Validation checklist for the M1–M7 changes from [REVIEW_EXECUTION_PLAN.md](./REVIEW_EXECUTION_PLAN.md). Pairs with [REVIEW_FINDINGS.md](./REVIEW_FINDINGS.md) and [REVIEW_PROPOSED_CHANGES.md](./REVIEW_PROPOSED_CHANGES.md).

This is **review-specific** — focused tests for the behaviour changes the milestones actually shipped. For the canonical addon-wide smoke checklist (boot, slash, panel, real LFG flow, persistence, patch-day, lib-refresh) see [`docs/smoke-tests.md`](../../docs/smoke-tests.md). Run the review checklist below first; pull from the canonical doc for sections it references.

**Critical sections** are flagged 🔴. They guard against the addon's most fragile invariants — Logout taint, write-path correctness, combat-edge secure frames. Treat a failure in those as a release blocker.

---

## How to use

1. Work top-to-bottom. Each milestone section assumes the prior commits are in place.
2. Tick boxes inline as you go (or in a copy of this file).
3. If anything fails, capture: the exact step, observed vs. expected output, full chat log around the failure, and any Lua error.
4. Once all sections pass, archive — this doc captures a point-in-time review and isn't intended to be re-run.

**Setup once before starting:**

- Cold launch the client (close fully, relaunch). Don't `/reload` between sections unless a step says to.
- Pull a target dummy in a major city (Stormwind / Orgrimmar) so combat scenarios are one keypress away.
- Start with `/wg debug` ON for the whole pass — most tests depend on the `[WG][DBG]` trace.

---

## Pre-flight

Establishes a clean baseline before exercising the changes.

| # | Step | Expected | Critical |
|---|------|----------|----------|
| P.1 | Cold launch, no `/reload`, watch chat for 30 s | No `[WG]` lines, no Lua errors | |
| P.2 | `/reload` | No errors, no taint warnings | |
| P.3 | ESC → Logout → log straight back in | Character logs out cleanly. No `ADDON_ACTION_FORBIDDEN ... 'callback()'` line | 🔴 |
| P.4 | `/wg debug` | `Debug mode: ON` printed | |

If P.3 fails on a fresh boot, none of the rest will be valid — the boot path itself has regressed. See [`docs/wow-quirks.md → Lazy popup, secure button, and Settings registration`](../../docs/wow-quirks.md).

---

## M1 — Doc/comment correctness sweep (`c954ebf`)

**Findings covered:** F-005, F-006.
**Runtime behaviour:** none. Doc-only commit.

| # | Step | Expected |
|---|------|----------|
| M1.1 | Open `WhatGroup_Settings.lua:912` in an editor; read the `Settings.Register()` header comment | Comment says "Called lazily from `runConfig`" + xref to `docs/wow-quirks.md`. Does **not** say "Called from `WhatGroup:OnEnable`". |
| M1.2 | Open `docs/scope.md` and search for "SecureHook" | Zero hits. Both prior occurrences (lines 20, 38) now say "direct `hooksecurefunc` on `C_LFGList.ApplyToGroup`". |

No in-game test required.

---

## M2 — Cleanup nits (`b503562`)

**Findings covered:** F-012, F-013, F-014, F-015, F-016, F-017, F-018.
**What changed:** Dead-code fallbacks dropped, `VALUE_COLORS` / `ColorizeValue` deleted, `pickKnownSpell` returns `(spellID, isKnown)`, `schema()` accessor added, `Helpers.Get` debug-logs missing paths, refresher iteration is now schema-ordered.

### M2.1 Synthetic notify + popup — F-012, F-013, F-014, F-015

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

**Expected popup:** Six rows populated. Plain white value text — no orphan colour markup. Teleport icon full-alpha if you know the spell, desaturated 50%-alpha otherwise.

The "(not learned)" tag in chat and the desaturation in the popup both depend on the new `(spellID, isKnown)` tuple from `pickKnownSpell` — if either misbehaves (always desaturated, always full, both wrong), F-015's tuple migration regressed.

### M2.2 Helpers.Get debug log — F-017

1. `/wg debug` (confirm ON)
2. `/wg get bogus.path` 

**Expected:** Two lines back-to-back:

```
[WG][DBG] Helpers.Get: no path -> bogus.path
[WG] Setting not found: bogus.path
```

The first line is new — without M2's change, only the second line printed.

### M2.3 Schema accessor — F-016

1. `/wg list`

**Expected:** Same output shape as before — every setting under its `[section]` header. Internally `listSettings` now uses the `schema()` accessor; if the rewrite broke, output would be empty or "Settings layer not ready yet".

### M2.4 Deterministic refresher iteration — F-018

Direct user-visible test isn't possible (refreshers are independent today). Indirect:

1. `/wg config` — confirm panel still renders.
2. `/wg reset` → confirm.

**Expected:** Every widget snaps back to default. If the new `_refresherOrder` array missed a row (registration bug), one or more widgets would stay at the pre-reset value.

---

## M3 — Single write-path consolidation (`6e5d52d`) 🔴

**Findings covered:** F-008.
**What changed:** `Helpers.Set` now orchestrates `RawSet → onChange → RefreshAll`. `applyFromText`, panel widget callbacks, `RestoreDefaults`, and `runDebug` are one-liners. `fireOnChange` deleted.

This is the **most-critical correctness milestone**. Every setting flows through `Helpers.Set` now; a regression here breaks every panel widget and every slash setter at once.

### M3.1 CLI round-trip per row — full coverage

For every schema row, run `/wg set <path> <value>` and verify `/wg get <path>` reflects it. Restore the default at the end.

| # | Path | Set value | Verify |
|---|------|-----------|--------|
| M3.1a | `enabled` | `false` | `/wg get enabled` → `false`. **Then** `/wg set enabled true`. |
| M3.1b | `frame.autoShow` | `false` | `/wg get frame.autoShow` → `false`. Restore to `true`. |
| M3.1c | `notify.enabled` | `false` | Restore to `true`. |
| M3.1d | `debug` | `false` (then `true` to restore) | `WhatGroup.debug` toggles too — confirm by running `/wg get bogus.path` after each change: only the `true` state should produce the `Helpers.Get: no path` debug line from M2.2. |
| M3.1e | `notify.delay` | `4.5` | `/wg get notify.delay` → `4.5s`. Restore to `1.5`. |
| M3.1f | `notify.showInstance` | toggle | Restore. |
| M3.1g | `notify.showType` | toggle | Restore. |
| M3.1h | `notify.showLeader` | toggle | Restore. |
| M3.1i | `notify.showPlaystyle` | toggle | Restore. |
| M3.1j | `notify.showTeleport` | toggle | Restore. |
| M3.1k | `notify.showClickLink` | toggle | Restore. |

If any row's `/wg get` doesn't reflect the `/wg set`, the orchestrated `Helpers.Set` regressed.

### M3.2 Panel ↔ CLI bidirectional sync

1. Open `/wg config` → click **General**.
2. Toggle **Auto Show** off via the checkbox.
3. Without closing the panel: `/wg get frame.autoShow` → expect `false`.
4. `/wg set frame.autoShow on` (slash, panel still open).
5. The panel checkbox should **immediately re-tick** without needing to close/reopen.

The auto-tick in step 5 verifies that the orchestrated `Helpers.Set` ran `RefreshAll` after the slash write.

6. Restore Auto Show to default.

### M3.3 Defaults reset — full row coverage

1. Change **all** of these via the panel: Auto Show off, Print to Chat off, Debug on, Notification Delay 5.0, every Notify show* checkbox toggled.
2. Click **Defaults** → **Yes**.
3. After confirm: `/wg list`.

**Expected:** Every row prints its declared default. **Including** the `debug` row's effect — `WhatGroup.debug` should be back to `false`. Confirm by running `/wg get bogus.path` — the `Helpers.Get: no path` debug line should NOT print (debug is off).

If the `debug` row resets in `db.profile` but `WhatGroup.debug` stays true, the orchestrated Set's `onChange` step regressed.

### M3.4 Logout taint check — post-write-path stress

After M3.1 → M3.3:

1. ESC → Logout → log back in.

**Expected:** Clean logout, no `ADDON_ACTION_FORBIDDEN`. The orchestrated write-path doesn't touch any secure surface, but worth confirming after a heavy write-path workout. 🔴

---

## M4 — Combat-safety hardening (`335a531`) 🔴

**Findings covered:** F-001, F-002, F-003.
**What changed:** `ConfigureTeleportButton` defers when `InCombatLockdown()` and reruns on `PLAYER_REGEN_ENABLED`. `WhatGroup:ShowFrame` defers first-time `buildFrame()` past combat. `Settings.Register` self-guards on `InCombatLockdown`.

### M4.1 ConfigureTeleportButton mid-combat — F-001

Setup: have an out-of-combat popup ready first so `buildFrame` has run.

1. Out of combat: `/wg test` → popup appears with teleport button (full-alpha if you know Stonevault teleport).
2. Close popup.
3. Pull a target dummy. Confirm in combat (red name plate, combat icon).
4. **In combat:** `/wg test`.

**Expected:** Popup appears with all six rows populated. The teleport button retains its prior state (visible from step 1, possibly stale icon). No Lua error, no `ADDON_ACTION_FORBIDDEN`.

5. Drop combat (kill the dummy or walk away).

**Expected:** Within ~1 s of the `PLAYER_REGEN_ENABLED` event, the teleport button updates — same icon as step 1.

If the button stays in its stuck state past combat-end, the deferred-rerun closure misbehaved.

### M4.2 First-show-in-combat defer — F-002

This requires the popup to have **never been built this session**, so `/reload` first.

1. `/reload`
2. Pull a target dummy. Stay in combat.
3. **In combat:** `/wg test`.

**Expected chat:**

```
[WG] Popup deferred until combat ends.
```

**Expected:** No popup yet. No Lua error.

4. Drop combat.

**Expected:** The popup appears immediately on combat-end with the synthetic Test Group data, full teleport button.

5. ESC → Logout → log back in. 🔴 **Critical** — combat-edge popup build is one of the most taint-prone code paths.

**Expected:** Clean logout, no `ADDON_ACTION_FORBIDDEN`.

### M4.3 Settings.Register combat-guard — F-003

Defense-in-depth check; the slash handler `runConfig` already refuses, but the guard inside `Settings.Register()` itself is the new layer.

1. `/reload` (so Settings haven't been registered this session).
2. Pull dummy, enter combat.
3. **In combat:** `/wg config`.

**Expected:** The existing `runConfig` combat refusal prints (matches §2.15 of `docs/smoke-tests.md`). No panel opens.

4. Drop combat. `/wg config`.

**Expected:** Panel opens normally, lands on the **Ka0s WhatGroup** parent page with **General** subcategory expanded in the sidebar.

5. ESC → Logout → log back in. 🔴

**Expected:** Clean logout.

### M4.4 Logout regression battery 🔴

Run §1.3 of `docs/smoke-tests.md`'s full Logout battery after the M4 tests:

- ESC → Logout right after `/reload`
- After `/wg test` (out of combat)
- After `/wg test` (in combat → drop combat → popup)
- After `/wg config` (out of combat)
- After `/wg reset` confirm

**Each must produce a clean logout with no `ADDON_ACTION_FORBIDDEN`.**

---

## M5 — Capture-pipeline correctness (`46fecf7`)

**Findings covered:** F-010, F-011 (full); F-004 deferred.
**What changed:** `notifyGen` cancels stale `C_Timer.After` callbacks; `WhatGroup:WipeCapture()` consolidates wipe; `enabled.onChange` calls it on off-flip.

### M5.1 Notify timer cancels on group-leave — F-010

Setup: bump `notify.delay` so the cancellation window is wide enough to act in.

1. `/wg set notify.delay 5.0`
2. Apply to a real LFG group. Wait for an invite. Accept.
3. **Within 5 seconds of accepting** (before the popup appears), `/leavegroup`.

**Expected:** No popup appears. No `[WG] You have joined a group!` chat line. The scheduled `C_Timer.After` callback fired but bailed because `notifyGen` was bumped by `WipeCapture`.

In `[WG][DBG]` trace you should see the `Notify(<reason>) scheduling in 5.0s` line, then the leave's `ROSTER inGroup=false ... hasPending=true` line. The notify-fire line is **absent** (no debug print on the cancelled fire by design).

4. `/wg set notify.delay 1.5` to restore.

### M5.2 Master switch wipes in-flight capture — F-011

1. Apply to a real LFG group. Watch the `[WG][DBG] Capture: title=...` line print.
2. **Before** the group leader sends an invite (i.e. while the apply is still pending), `/wg set enabled false`.
3. Group leader accepts you, you accept the invite, you join the group.

**Expected:** No popup, no chat notification on join. The `enabled.onChange` flip fired `WipeCapture()`, which cleared the `pendingApplications[appID]` entry — by the time `inviteaccepted` fires, there's no pending capture to surface.

In `[WG][DBG]` trace: the `LFG_STATUS appID=<N> status=inviteaccepted` line still prints (the event handler runs), but `inviteaccepted: pendingInfo=NIL`.

4. `/wg set enabled true` to restore.

### M5.3 Mythic+ teleport icon — F-004 deferred check

Confirms the existing `GetSearchResultInfo(appID)` path still produces a mapID-driven teleport icon. F-004's `GetApplicationInfo` migration is deferred; this test is the safety net.

1. Apply to any retail Mythic+ group. Accept the invite.

**Expected:** Popup shows the correct dungeon's teleport spell icon. (The TODO at `WhatGroup.lua:574` flags that the API path is undocumented but observed-to-work; if Blizzard hardens the type check on `GetSearchResultInfo`, this test would start failing and the F-004 migration would become required.)

---

## M6 — Label dedup (`e03d7fb`)

**Findings covered:** F-007.
**What changed:** `PLAYSTYLE_LABELS` and `GetGroupTypeLabel` consolidated under `WhatGroup.Labels`; `WhatGroup_Frame.lua` reads from there.

### M6.1 Type + Playstyle agree across surfaces

1. `/wg test`.

**Expected (both chat AND popup):**

- Type: `Mythic+`
- Playstyle: `Fun (Serious)`

If chat and popup disagree, the dedup migration broke one consumer's read of `WhatGroup.Labels`.

### M6.2 Real-LFG variety pass

If you can't pull multiple real groups:

1. `/wg test` for the synthetic case.
2. Apply to one **non-Mythic+** group (raid, dungeon, PvP).

**Expected:** Type label matches the activity correctly:
- Raid (Current) for current-tier raid
- Heroic Raid for heroic
- PvP for PvP categoryID
- Dungeon for normal/heroic 5-man
- Group as the final fallback

Chat and popup must show identical strings.

---

## M7 — Frame layout from rendered geometry (`a019b14`)

**Findings covered:** F-009.
**What changed:** Teleport button position derived from `lblPort:GetLeft()/GetTop()` instead of magic `(92, -68)`. `content:SetHeight` line dropped (was a no-op).

### M7.1 Default scale visual

1. `/wg test` at your current UI scale.

**Expected:** Teleport icon sits horizontally aligned with the "Teleport:" label, vertically on the same row, ~6 px gap to the right of the label text.

### M7.2 UI scale 0.65

1. ESC → Settings → Accessibility → Adjust UI Scale → set to `0.65`.
2. `/reload` (required for full re-layout).
3. `/wg test`.

**Expected:** Teleport icon still aligned with "Teleport:" label. Popup proportions look correct. No layout glitches.

### M7.3 UI scale 1.15

1. UI scale → `1.15`. `/reload`. `/wg test`.

**Expected:** Same as M7.2. Button stays aligned.

4. Restore your preferred UI scale and `/reload`.

If the button drifts at any scale, `lblPort:GetLeft()/GetTop()` returned unexpected values during `buildFrame`. The most likely fix would be deferring the GetLeft/GetTop read to right before SetPoint via a dummy SetPoint pass.

---

## Final regression sweep 🔴

After all milestone-specific tests pass, run the full Logout battery one more time as a clean confirmation no individual milestone left lingering taint.

| # | Step | Expected |
|---|------|----------|
| F.1 | `/reload` → ESC → Logout → log in | Clean. No `ADDON_ACTION_FORBIDDEN`. |
| F.2 | `/wg test` → ESC → Logout → log in | Clean. |
| F.3 | `/wg config` → close panel → ESC → Logout → log in | Clean. |
| F.4 | `/wg reset` → confirm → ESC → Logout → log in | Clean. |
| F.5 | Click teleport button on popup → ESC → Logout → log in | Clean. (Casts the teleport if learned; the click reaching the secure handler is the regression test.) |
| F.6 | Apply to a real LFG group → join → notify fires → ESC → Logout → log in | Clean. |
| F.7 | Combat-edge: pull dummy → `/wg test` (deferred popup) → drop combat → popup appears → ESC → Logout → log in | Clean. |

If any of F.1–F.7 fails, the corresponding milestone has reintroduced taint. Bisect by which step is the first to fail.

---

## Sign-off

When everything above is green:

- [ ] Pre-flight P.1–P.4
- [ ] M1.1, M1.2 (visual diff)
- [ ] M2.1 — synthetic flow
- [ ] M2.2 — debug log on missing path
- [ ] M2.3 — `/wg list`
- [ ] M2.4 — Defaults reset
- [ ] **M3.1 — every schema row CLI round-trip** 🔴
- [ ] **M3.2 — panel ↔ CLI bidirectional sync** 🔴
- [ ] **M3.3 — Defaults reset incl. `WhatGroup.debug`** 🔴
- [ ] M3.4 — Logout after write-path stress
- [ ] **M4.1 — teleport button mid-combat → resumes on combat-end** 🔴
- [ ] **M4.2 — first-show-in-combat defer + Logout** 🔴
- [ ] M4.3 — Settings.Register combat-refusal + Logout
- [ ] **M4.4 — Logout battery (5 scenarios)** 🔴
- [ ] M5.1 — notify timer cancels on group-leave
- [ ] M5.2 — master-switch wipe of in-flight capture
- [ ] M5.3 — Mythic+ teleport icon (F-004 deferred safety net)
- [ ] M6.1 — `/wg test` Type + Playstyle agree
- [ ] M6.2 — real-LFG type variety
- [ ] M7.1 — default UI scale alignment
- [ ] M7.2 — UI scale 0.65 alignment
- [ ] M7.3 — UI scale 1.15 alignment
- [ ] **F.1–F.7 — final Logout regression sweep** 🔴

If all critical 🔴 items pass, the M1–M7 changes are shippable. The non-critical items being green raises confidence; failures there are usually fixable without reverting commits.

After sign-off, push `main` (currently 7 ahead of `origin/main`) when ready, and decide on a release version bump separately.
