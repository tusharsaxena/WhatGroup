# Ka0s WhatGroup — Execution Plan

Pairs with [01_FINDINGS.md](./01_FINDINGS.md) and [02_PROPOSED_CHANGES.md](./02_PROPOSED_CHANGES.md). Milestones are ordered. Tasks within a milestone may be parallelized where files are disjoint; serial constraints are called out.

---

## Milestone 1 — Doc/comment correctness sweep
**Done when:** Every comment and doc in the repo accurately describes the current code; a fresh contributor can read any single doc and not be misled.
**Why first:** Cheapest, no behavioural risk; clears the ground for the larger changes that follow without those changes also fixing doc drift in the same commit.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-1.1 | doc-cleanup | F-005 | `WhatGroup_Settings.lua:912` (header comment only) | Single comment edit. |
| T-1.2 | doc-cleanup | F-006 | `docs/scope.md:20, 38` | Two phrasing fixes. |

**Concurrency:** T-1.1 and T-1.2 touch disjoint files — **parallelizable**.
**Checkpoint:** Read both files end-to-end, confirm wording matches code. No in-game test needed.
**Suggested commit:** "Fix stale comments on Settings.Register caller and SecureHook references".

---

## Milestone 2 — Cleanup nits
**Done when:** Dead code paths removed, accessors used uniformly, observability hook added, refresher order made deterministic.
**Why second:** Low risk, clears up the call-graph before the bigger refactors in M3+. Doing it before M3 means the M3 changes don't need to re-touch the same surface.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-2.1 | lua-refactorer | F-012, F-013 | `WhatGroup.lua:271, 284` | Drop dead-code fallbacks. |
| T-2.2 | lua-refactorer | F-014 | `WhatGroup_Frame.lua:38-52, 262-280` | Drop `VALUE_COLORS` and `ColorizeValue`; inline `:SetText(text)` at call sites. |
| T-2.3 | lua-refactorer | F-015 | `WhatGroup.lua:327-349, 423-431`; `WhatGroup_Frame.lua:200-247` | `pickKnownSpell` returns `(spellID, isKnown)`; callers use it directly. |
| T-2.4 | lua-refactorer | F-016 | `WhatGroup.lua:675, 682` | Use `helpers()`-style accessor for Schema reads. |
| T-2.5 | lua-refactorer | F-017 | `WhatGroup_Settings.lua:195-199` | Debug-mode log on missing path. |
| T-2.6 | lua-refactorer | F-018 | `WhatGroup_Settings.lua:34, 309-316, 701-704, 724-727` | Track refresher order array; iterate it. |

**Concurrency:**
- T-2.1, T-2.4 (both `WhatGroup.lua`) → **serialize** with each other.
- T-2.3 (`WhatGroup.lua` + `WhatGroup_Frame.lua`) → **serialize** with T-2.1 / T-2.4 on `WhatGroup.lua`.
- T-2.2 (`WhatGroup_Frame.lua` only) → **parallelizable** with T-2.1 / T-2.4 / T-2.5 / T-2.6 (but **serialize** with T-2.3 on `WhatGroup_Frame.lua`).
- T-2.5 / T-2.6 (both `WhatGroup_Settings.lua`) → **serialize** with each other.
- Recommended grouping for one agent: do T-2.1 + T-2.4 + T-2.3 in `WhatGroup.lua` in one pass, then T-2.5 + T-2.6 in `WhatGroup_Settings.lua`, then T-2.2 in `WhatGroup_Frame.lua`.

**Checkpoint:** Run `docs/smoke-tests.md` §Quick reference (boot health + slash commands + popup) — no behavioural changes expected. The teleport line should still render with `(not learned)` tags identical to before.
**Suggested commit:** "Cleanup: drop dead fallbacks, unify accessors, deterministic refresh order".

---

## Milestone 3 — Single-write-path consolidation
**Done when:** `Helpers.Set` is the orchestrated path (Set + onChange + Refresh); all call sites collapse to one line.
**Why before M4 / M5:** M5 (capture-pipeline) adds an `onChange` to the `enabled` row; that path needs to call `WhatGroup:WipeCapture()` on toggle. With M3's orchestrated `Helpers.Set`, M5 becomes a one-line change. Also: M3 changes `Helpers.RestoreDefaults` to use the orchestrated set, which reduces M5's risk surface.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-3.1 | lua-refactorer | F-008 | `WhatGroup_Settings.lua:201-205` | Introduce `Helpers.RawSet`; rewrite `Helpers.Set` to orchestrate. |
| T-3.2 | lua-refactorer | F-008 | `WhatGroup_Settings.lua:290-304, 695-699, 719-722` | Collapse `RestoreDefaults` and widget callbacks to use the new `Helpers.Set`. |
| T-3.3 | lua-refactorer | F-008 | `WhatGroup.lua:743-748, 880-887` | Collapse `applyFromText` and `runDebug`. |

**Concurrency:** T-3.1 must precede T-3.2 / T-3.3. T-3.2 and T-3.3 touch disjoint files post-T-3.1 — **parallelizable**.
**Checkpoint:** Run `docs/smoke-tests.md` §Settings panel + §`/wg list/get/set/reset` — every checkbox / slider in the panel must still update both the runtime and the chat-side `/wg get` output; `/wg reset` must still trigger the popup and reset every row including running `debug`'s onChange that updates `WhatGroup.debug`.
**Suggested commit:** "Make Helpers.Set the orchestrated single write-path; introduce Helpers.RawSet for low-level writes".

---

## Milestone 4 — Combat-safety hardening of the secure popup
**Done when:** The popup never tries to mutate secure-button state during `InCombatLockdown()`; first-show in combat defers to `PLAYER_REGEN_ENABLED`; `Settings.Register()` carries its own combat guard.
**Why after M3:** Lower risk to layer combat-edge handling on top of the cleaned-up state shape. M4 doesn't depend on M3 logically but ordering it after M3 means smoke tests against M4 changes aren't simultaneously exercising new write-path code.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-4.1 | wow-secure-frames | F-001 | `WhatGroup_Frame.lua:200-247` | `ConfigureTeleportButton` combat-defer + `PLAYER_REGEN_ENABLED` rerun. |
| T-4.2 | wow-secure-frames | F-002 | `WhatGroup_Frame.lua:286-301` | `WhatGroup:ShowFrame` combat-defer for first-build. |
| T-4.3 | wow-secure-frames | F-003 | `WhatGroup_Settings.lua:922-927` | `Settings.Register` self-guards on `InCombatLockdown`. |

**Concurrency:** T-4.1 and T-4.2 both touch `WhatGroup_Frame.lua` — **serialize** them. T-4.3 (`WhatGroup_Settings.lua`) is **parallelizable** with both.
**Checkpoint (manual, in-game):**
1. Out of combat: `/wg test` → popup with teleport button as before.
2. In combat: `/wg test` (first time this session) → chat hint, no popup yet → drop combat → popup appears with teleport button configured.
3. In combat: `/wg test` (after the popup has been built once this session) → popup shows, teleport button is hidden during combat → drop combat → button surfaces correctly.
4. GameMenu Logout regression test (`docs/smoke-tests.md §1.3`): no `ADDON_ACTION_FORBIDDEN` after a session that included combat-edge popup activity.
**Suggested commit:** "Combat-safety: defer secure-button config and first frame build until PLAYER_REGEN_ENABLED".

---

## Milestone 5 — Capture-pipeline correctness
**Done when:** Notify timer cancels on group-leave; master-switch flip wipes pipeline state; `inviteaccepted` re-capture uses a documented API path.
**Why after M3 + M4:** M5 adds an `onChange` to the `enabled` row that depends on M3's orchestrated path. Combat-edge of the new wipe call site is contained — non-secure code, no taint surface — so M4 is not a hard dependency, but doing M5 last keeps each milestone's smoke-test scope minimal.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-5.1 | lua-refactorer | F-010 | `WhatGroup.lua:489-511, 529-535` | Generation counter cancels stale `C_Timer.After` callbacks. |
| T-5.2 | lua-refactorer | F-011 | `WhatGroup.lua` (new `WhatGroup:WipeCapture()`); `WhatGroup_Settings.lua:73-79` (`enabled.onChange`) | Master-switch flip → wipe. |
| T-5.3 | wow-api-migrator | F-004 | `WhatGroup.lua:263-320, 537-585` | New `CaptureGroupInfoFromApplication(appID)` that uses `C_LFGList.GetApplicationInfo`. **Verify in-game first** that the function exists and returns `lfgListID` at retail interface 120000-120005; if not, leave the code as-is and add a `// undocumented behaviour, verify` comment instead. |

**Concurrency:** T-5.1, T-5.2, T-5.3 all touch `WhatGroup.lua` — **serialize**.
**Checkpoint (manual, in-game):**
1. Apply to a group, accept invite, immediately leave during the 1.5s notify delay → no popup appears, no chat notify (T-5.1 verification).
2. Apply to a group, before the invite arrives flip `/wg set enabled false` → no popup or chat when invite arrives (T-5.2 verification).
3. Apply to a Mythic+ group → notify and popup show with mapID-driven teleport icon (T-5.3 verification — same as today, just via a different API).
**Suggested commit:** "Capture pipeline: cancel stale notify timers, wipe state on master-switch flip, use GetApplicationInfo for invite re-capture".

---

## Milestone 6 — De-duplicate playstyle/group-type helpers
**Done when:** `WhatGroup.Labels` is the only source for `PLAYSTYLE_LABELS` and `GetGroupTypeLabel`; `WhatGroup_Frame.lua` reads from it.
**Why last:** Lowest priority. The duplication is a real code smell but well-documented as intentional today; if M1-M5 introduce other changes to either helper, doing M6 last avoids merge conflicts.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-6.1 | lua-refactorer | F-007 | `WhatGroup.lua:351-385` (extract to `WhatGroup.Labels`); `WhatGroup_Frame.lua:29-64, 267, 278` (use `WhatGroup.Labels`); `docs/frame.md` (drop "intentional duplication" rationale) | Extract once, consume once. |

**Concurrency:** Single task.
**Checkpoint:** `/wg test` (Mythic+ data) shows the same Type and Playstyle text as before in both chat and popup; manually inject a non-Mythic+ category to verify the type-label fallthroughs still match across both surfaces.
**Suggested commit:** "Consolidate playstyle and group-type label helpers under WhatGroup.Labels".

---

## Milestone 7 — Frame layout from constants
**Done when:** Teleport button position derives from `LABEL_WIDTH` / `yGap` / row count rather than the magic `(92, -68)`.

| Task ID | Owner-agent role | Findings | Files touched | Notes |
|---|---|---|---|---|
| T-7.1 | wow-frame-layout | F-009 | `WhatGroup_Frame.lua:121-169` | Track per-row y-offsets; anchor teleport button using them. |

**Checkpoint:** Open the popup at UI scale 0.65, 1.0, 1.15. Teleport button must align horizontally with the "Teleport:" label and sit on the same row across all three scales.
**Suggested commit:** "Frame layout: derive teleport button position from row constants".

---

## Critical-path / concurrency summary

```
M1 (docs)       ───parallel───   T-1.1, T-1.2

M2 (cleanup)    ───series────►   T-2.1 → T-2.4 → T-2.3
                                    │
                                    └──parallel──   T-2.2  (Frame only)
                T-2.5 → T-2.6                       (Settings only)

M3 (write-path) T-3.1 ──► (T-3.2, T-3.3 parallel)

M4 (combat)     T-4.1 → T-4.2  (Frame, serial)
                T-4.3          (Settings, parallel)

M5 (pipeline)   T-5.1 → T-5.2 → T-5.3   (all WhatGroup.lua, serial)

M6 (dedupe)     T-6.1

M7 (layout)     T-7.1
```

## Hard checkpoints (human-in-the-loop)

- **End of M1:** No tests. Visual diff of the two doc files only.
- **End of M2:** Smoke tests §Boot health + §Slash commands.
- **End of M3:** Smoke tests §Settings panel + §/wg list/get/set/reset. **Critical** — write-path is core; verify each schema row's behaviour after the consolidation.
- **End of M4:** Smoke tests §Combat scenarios + §1.3 GameMenu Logout regression. **Critical** — taint regression check; this is the addon's most fragile invariant.
- **End of M5:** Smoke tests §LFG real-flow + §Master switch.
- **End of M6:** Smoke tests §/wg test (popup + chat output).
- **End of M7:** Smoke tests §Popup at multiple UI scales.
- **Before tagging a release:** Full `docs/smoke-tests.md` checklist (the user does this — do not bump version).

## Incremental commit strategy

One commit per task is overkill; one commit per milestone is right-sized. Each milestone produces one commit with the suggested message above. Milestones must merge in order even though tasks within a milestone may parallelize.
