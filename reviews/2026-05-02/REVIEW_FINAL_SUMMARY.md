# Ka0s WhatGroup — Review Final Summary

End-state of the 2026-05-02 principal-engineer review after all proposed milestones executed. Pairs with [REVIEW_FINDINGS.md](./REVIEW_FINDINGS.md), [REVIEW_PROPOSED_CHANGES.md](./REVIEW_PROPOSED_CHANGES.md), [REVIEW_EXECUTION_PLAN.md](./REVIEW_EXECUTION_PLAN.md), and [REVIEW_SMOKE_TESTS.md](./REVIEW_SMOKE_TESTS.md).

This doc assumes the [smoke tests](./REVIEW_SMOKE_TESTS.md) have all passed. Until they do, treat the changes as landed-but-unverified.

---

## Verdict

**Ship-ready.** The original review's finding count was 0 critical / 3 high / 8 medium / 7 low. After M1–M7:

- All 3 high-severity findings → **resolved**.
- 7 of 8 medium-severity findings → **resolved**; 1 (F-004) → **deferred behind a documented TODO** (see [Deferred work](#deferred-work)).
- All 7 low-severity findings → **resolved**.

The original verdict ("Minor issues. No taint regressions, no data-loss risks, no broken contracts.") still holds, with the high-severity combat-edge bugs (F-001, F-002) and design hazards (F-003, F-008) now addressed in code rather than just acknowledged.

---

## At-a-glance stats

| Metric | Value |
|---|---|
| Milestones executed | 7 of 7 |
| Commits added to `main` | 7 |
| Findings resolved in code | 17 of 18 |
| Findings deferred | 1 (F-004) |
| Distinct files touched | 9 |
| Net line delta | +244 / −168 (+76 net) |
| Branch position post-review | `main` is **7 ahead of `origin/main`** (not pushed) |

Files touched (commit ranges in parens):

- `WhatGroup.lua` (M2, M3, M5, M6)
- `WhatGroup_Frame.lua` (M2, M4, M6, M7)
- `WhatGroup_Settings.lua` (M1, M2, M3, M4, M5, M6)
- `CLAUDE.md` (M6)
- `docs/scope.md` (M1)
- `docs/frame.md` (M6)
- `docs/file-index.md` (M6)
- `docs/capture-pipeline.md` (M6)
- `docs/common-tasks.md` (M6)

---

## Findings status

| ID | Severity | Title | Status | Landed in |
|---|---|---|---|---|
| F-001 | High | `ConfigureTeleportButton` mutates secure attrs without combat guard | ✅ Resolved | M4 (`335a531`) |
| F-002 | High | First-show in combat can taint `buildFrame` | ✅ Resolved | M4 (`335a531`) |
| F-003 | High | `Settings.Register()` lacked self-guard on `InCombatLockdown` | ✅ Resolved | M4 (`335a531`) |
| F-004 | Med | `inviteaccepted` re-fetch uses undocumented `appID` → `GetSearchResultInfo` shape | ⏸ Deferred | TODO at `WhatGroup.lua:574`, plan in M5 (`46fecf7`) |
| F-005 | Med | `Settings.Register()` header comment said it's called from `OnEnable` | ✅ Resolved | M1 (`c954ebf`) |
| F-006 | Med | `docs/scope.md` still described hooks as `SecureHook` | ✅ Resolved | M1 (`c954ebf`) |
| F-007 | Med | Duplicated `PLAYSTYLE_LABELS` / `GetGroupTypeLabel` between two files | ✅ Resolved | M6 (`e03d7fb`) |
| F-008 | Med | `Helpers.Set` was a raw write; orchestration scattered across callers | ✅ Resolved | M3 (`6e5d52d`) |
| F-009 | Med | Frame layout hard-coded `(92, -68)` for the teleport button | ✅ Resolved | M7 (`a019b14`) |
| F-010 | Med | Notify `C_Timer.After` callback had no cancel path on group-leave | ✅ Resolved | M5 (`46fecf7`) |
| F-011 | Med | Master-switch off-flip didn't wipe in-flight capture state | ✅ Resolved | M5 (`46fecf7`) |
| F-012 | Low | `info.title` fallback in `CaptureGroupInfo` was dead code | ✅ Resolved | M2 (`b503562`) |
| F-013 | Low | `info.activityID` fallback was dead code | ✅ Resolved | M2 (`b503562`) |
| F-014 | Low | `VALUE_COLORS` resolvers all returned `nil` | ✅ Resolved | M2 (`b503562`) |
| F-015 | Low | `pickKnownSpell` contract muddied (returns fallback even when not learned) | ✅ Resolved | M2 (`b503562`) |
| F-016 | Low | Settings.Schema reads bypassed the `helpers()` accessor pattern | ✅ Resolved | M2 (`b503562`) |
| F-017 | Low | `Helpers.Get` returned `nil` silently for unknown paths | ✅ Resolved | M2 (`b503562`) |
| F-018 | Low | `Helpers.RefreshAll` iterated `pairs()` (non-deterministic order) | ✅ Resolved | M2 (`b503562`) |

---

## Per-milestone breakdown

### M1 — Doc/comment correctness sweep

**Commit:** `c954ebf` — *Fix stale comments on Settings.Register caller and SecureHook references*
**Findings:** F-005, F-006
**Diffstat:** 2 files changed, +8 −3
**Files:** `WhatGroup_Settings.lua`, `docs/scope.md`

Two pure documentation fixes:

- `WhatGroup_Settings.lua:912` — `Settings.Register()` header comment rewritten from "Called from `WhatGroup:OnEnable`" to "Called lazily from `runConfig` (the `/wg config` slash handler) on first invocation … **Not** called from `OnEnable` …" with a cross-reference to `docs/wow-quirks.md`'s taint-reasoning section.
- `docs/scope.md` — both occurrences of "`SecureHook` on `ApplyToGroup`" replaced with "direct `hooksecurefunc` on `C_LFGList.ApplyToGroup`". The second one's rationale paragraph rewritten to reflect the actual taint reason (AceHook closures, not "we only observe").

**Behaviour delta:** none. Doc-only.

### M2 — Cleanup nits

**Commit:** `b503562` — *Drop dead fallbacks, unify accessors, deterministic refresh order*
**Findings:** F-012, F-013, F-014, F-015, F-016, F-017, F-018
**Diffstat:** 3 files changed, +48 −43
**Files:** `WhatGroup.lua`, `WhatGroup_Frame.lua`, `WhatGroup_Settings.lua`

Cluster of small consistency / clarity fixes:

- **Dead-code fallbacks dropped** — `info.name or info.title` → `info.name`; `info.activityIDs or (info.activityID and {…})` → `info.activityIDs or {}`. Neither alternate path was reachable on retail 12.x.
- **`pickKnownSpell` returns `(spellID, isKnown)`** — the second value makes the "found a learned spell vs. fell back to first list entry" distinction explicit. `ShowNotification` and `ConfigureTeleportButton` consume the tuple instead of re-calling `IsSpellKnown(spellID)`.
- **`schema()` accessor mirroring `helpers()`** — `listSettings` now reads via `schema()` instead of dereferencing `self.Settings.Schema` directly, matching the existing accessor pattern.
- **`Helpers.Get` debug-logs missing paths** — when `WhatGroup.debug` is on, a typo'd path prints `Helpers.Get: no path -> <path>` before returning `nil`. Saves diagnostic time on schema-key typos.
- **Deterministic refresher order** — new `Settings._refresherOrder` array tracks the registration order; `RefreshAll` iterates the array instead of `pairs(_refreshers)`. No observable change today (refreshers are independent), but eliminates a latent ordering hazard if the panel ever gains cross-row visual coupling.
- **`VALUE_COLORS` and `ColorizeValue` deleted** — every resolver returned `nil`; the abstraction had no callers and no callers-to-be. `PopulateFields` call sites collapsed from `ColorizeValue(text, VALUE_COLORS.x, info)` to `text` directly.

**Behaviour delta:** none user-visible (all changes are equivalent or strictly more correct). The new debug log is the only added chat output, gated on `/wg debug`.

### M3 — Single write-path consolidation 🔴

**Commit:** `6e5d52d` — *Orchestrate Helpers.Set, split low-level write into RawSet*
**Findings:** F-008
**Diffstat:** 2 files changed, +33 −32
**Files:** `WhatGroup.lua`, `WhatGroup_Settings.lua`

Most architecturally significant change in the review. Before: every caller of `Helpers.Set` manually composed `Helpers.Set + def.onChange + Helpers.RefreshAll` (or forgot one of the three). After: `Helpers.Set` orchestrates all three; raw writes go through the new `Helpers.RawSet`.

Public API change:

```lua
-- New low-level write (no side effects). For genuinely side-effect-free
-- writes (none today). Use Helpers.Set for everything else.
Helpers.RawSet(path, value)

-- Orchestrated: writes value, fires onChange, refreshes panel widgets.
-- Optional opts table: {skipOnChange=true} or {skipRefresh=true}.
Helpers.Set(path, value, opts)
```

Caller collapses (now one-liners):

- CLI `applyFromText` — was 5 lines, now 1.
- Panel widget `OnValueChanged` callbacks (checkbox + slider) — were 4 lines each, now 1.
- `Helpers.RestoreDefaults` — passes `{skipRefresh=true}` per row, refreshes once at the end.
- Slash command `runDebug` — no longer pre-sets `WhatGroup.debug`; the schema row's `onChange` does it via the orchestrated path. The early-boot fallback (when Settings layer hasn't loaded) still writes `db.profile.debug` and `WhatGroup.debug` directly.
- `fireOnChange` helper deleted (no longer referenced).

**Behaviour delta:** equivalent for every existing call site (each was already invoking the three pieces manually). The future-proofing benefit: any new caller of `Helpers.Set` automatically gets onChange + refresh without remembering to wire them up.

### M4 — Combat-safety hardening 🔴

**Commit:** `335a531` — *Defer secure-button config, frame build, settings register past combat*
**Findings:** F-001, F-002, F-003
**Diffstat:** 2 files changed, +64 −0 (pure additions — three guard layers)
**Files:** `WhatGroup_Frame.lua`, `WhatGroup_Settings.lua`

Three defer-on-combat guards added; no behaviour removed:

- **`ConfigureTeleportButton` (F-001)** — Now first-checks `InCombatLockdown()`. In combat: stashes `info` on `f._pendingTeleportInfo`, registers `PLAYER_REGEN_ENABLED` on the popup frame, and bails. On combat-end, the event handler reruns `ConfigureTeleportButton` with the most recently-stashed info. Repeated calls during combat are safe (the stash overwrites; `RegisterEvent` is idempotent).
- **`WhatGroup:ShowFrame` first-build (F-002)** — Now checks `not f and InCombatLockdown()`. If both: prints `[WG] Popup deferred until combat ends.` and queues the build via a one-shot wait frame. On combat-end, restores `pendingInfo` only if it was cleared mid-wait, then re-enters `ShowFrame`. Once the popup has been built once this session, subsequent in-combat shows route through `ConfigureTeleportButton`'s own guard.
- **`Settings.Register()` self-guard (F-003)** — Defense-in-depth on top of the existing `runConfig` combat refusal. Refuses with `[WG] Cannot register settings panel during combat.` if any future caller bypasses the slash-handler guard.

**Behaviour delta:** in combat, the popup or panel may show with a one-cycle delay (until `PLAYER_REGEN_ENABLED`). The previous out-of-combat fast path is unchanged — same number of frame creations, same anchor math, same `Show()` cadence.

### M5 — Capture-pipeline correctness

**Commit:** `46fecf7` — *Cancel stale notify timers and wipe capture on master-switch off*
**Findings:** F-010, F-011 fully; F-004 deferred
**Diffstat:** 2 files changed, +35 −4
**Files:** `WhatGroup.lua`, `WhatGroup_Settings.lua`

- **Generation-counter notify cancellation (F-010)** — New file-local `notifyGen` counter. `_TryFireJoinNotify` captures the current generation when scheduling its `C_Timer.After` callback; the callback bails if `notifyGen` was bumped in the meantime, or if `pendingInfo` was replaced. Group-leave wipes bump the generation, so a notify scheduled before the leave never fires.
- **`WipeCapture` consolidation (F-011)** — New `WhatGroup:WipeCapture()` wipes `pendingInfo`, `notifiedFor`, `captureQueue`, `pendingApplications`, and bumps `notifyGen`. `GROUP_ROSTER_UPDATE`'s leave branch routes through it. The `enabled` schema row gains `onChange = function(v) if not v then WhatGroup:WipeCapture() end end`, so flipping the master switch off mid-flight cancels any in-flight capture.
- **F-004 deferred** — `TODO(F-004)` comment at `WhatGroup.lua:574` documents that the `inviteaccepted` re-capture passes `appID` to `C_LFGList.GetSearchResultInfo`, which is undocumented but observed-to-work behaviour. Migration to `C_LFGList.GetApplicationInfo` is gated on in-game verification at retail interface 120000–120005. See [Deferred work](#deferred-work).

**Behaviour delta:** edge-case correctness — leaving a group during the notify-delay window no longer surfaces an empty-data popup; toggling master-switch off mid-pipeline no longer leaks a notify after-the-fact. Happy path identical.

### M6 — Label dedup

**Commit:** `e03d7fb` — *Consolidate playstyle and group-type labels under WhatGroup.Labels*
**Findings:** F-007 + opportunistic doc-drift cleanup
**Diffstat:** 7 files changed, +42 −78
**Files:** `WhatGroup.lua`, `WhatGroup_Frame.lua`, `CLAUDE.md`, `docs/frame.md`, `docs/file-index.md`, `docs/capture-pipeline.md`, `docs/common-tasks.md`

Single source of truth for the playstyle / group-type label mappings:

- New `WhatGroup.Labels` namespace on the addon table holds `PLAYSTYLE` (enum → string) and `GetGroupTypeLabel(info)` / `GetPlaystyleLabel(info)`.
- `WhatGroup.lua` defines them; a file-local `Labels` alias is used at the call sites in `ShowNotification`.
- `WhatGroup_Frame.lua` drops its duplicate `PLAYSTYLE_LABELS` table and `GetGroupTypeLabel` function; `PopulateFields` reads `WhatGroup.Labels.*`.
- `docs/frame.md` — the "Why … are duplicated" section deleted; replaced with a brief "Shared label helpers" note. Table rows and edge-case bullets updated to reference `WhatGroup.Labels.*`.
- Opportunistic doc-drift cleanup in the same commit since the label rename and the M2 dead-code drop both left stale references in unrelated docs:
  - `CLAUDE.md` — `PLAYSTYLE_LABELS` reference updated to `WhatGroup.Labels.{GetGroupTypeLabel, PLAYSTYLE}`.
  - `docs/file-index.md` — drops mention of `PLAYSTYLE_LABELS` and the now-deleted `VALUE_COLORS`; adds the actual layout constants present.
  - `docs/capture-pipeline.md` — `PLAYSTYLE_LABELS` references updated.
  - `docs/common-tasks.md` — recipe step naming `VALUE_COLORS.<name>` resolver dropped (the resolver table is gone).

**Behaviour delta:** none. Both consumers (chat + popup) read from the same table now; before, they read from identical-but-separate tables.

### M7 — Frame layout from rendered geometry

**Commit:** `a019b14` — *Anchor teleport button from label geometry, drop magic offsets*
**Findings:** F-009
**Diffstat:** 1 file changed, +14 −8
**Files:** `WhatGroup_Frame.lua`

- Teleport button position derived from `lblPort:GetLeft()`, `lblPort:GetTop()`, `f:GetLeft()`, `f:GetTop()` and the `LABEL_WIDTH` constant. Replaces the hard-coded `(92, -68)` "LEFT" anchor with `("TOPLEFT", btnX, btnY)`.
- `content:SetHeight(math.abs(yGap) * 6 + 24)` line removed — `content` had both `TOPLEFT` and `BOTTOMRIGHT` anchored, so `SetHeight` was a no-op overridden by the anchors.

**Behaviour delta:** layout-equivalent at default UI scale (the magic numbers were tuned to land at the same point). Future-proof — adding or reordering rows, or changing `LABEL_WIDTH` / `yGap`, no longer requires retuning the button offsets.

---

## Deferred work

### F-004 — `C_LFGList.GetSearchResultInfo(appID)` undocumented behaviour

**Status:** Deferred. Comment at `WhatGroup.lua:574` documents the situation.
**Why:** Migrating to `C_LFGList.GetApplicationInfo(appID)` → `lfgListID` → `GetSearchResultInfo(lfgListID)` is the documented path. The plan required in-game verification that `GetApplicationInfo` exists at retail interface 120000–120005 and returns a usable `lfgListID`. That verification couldn't be performed during the review's execution pass, so the migration was deferred per the plan's contingency: *"if not [verified], leave the code as-is and add a `// undocumented behaviour, verify` comment instead."*

**Risk if not migrated:** Low today. The undocumented appID-as-searchResultID behaviour has been stable across recent retail patches. If a future patch hardens the type check on `GetSearchResultInfo`, the `fresh` re-capture in the `inviteaccepted` handler would silently return `nil` and the addon would fall back to the queued capture (same pendingInfo, slightly older mapID — not a hard break).

**Remediation when ready:** Apply the proposed change at [REVIEW_PROPOSED_CHANGES.md → F-004](./REVIEW_PROPOSED_CHANGES.md):

```lua
function WhatGroup:CaptureGroupInfoFromApplication(appID)
    if not C_LFGList.GetApplicationInfo then return nil end
    local _, lfgListID = C_LFGList.GetApplicationInfo(appID)
    if not lfgListID then return nil end
    return self:CaptureGroupInfo(lfgListID)
end
```

…and call it from `LFG_LIST_APPLICATION_STATUS_UPDATED` instead of `self:CaptureGroupInfo(appID)`. Verify in-game with `/wg debug` enabled that the `Capture: title=… mapID=…` line still prints with a non-nil mapID after `inviteaccepted`.

---

## Doc backlog

Drift introduced by M2/M3/M5 that wasn't in the review's M6 scope (which only covered M6's own label rename plus opportunistic cleanup). Worth a `/wow-addon:sync-docs` pass before the next release:

- **`docs/file-index.md`** — Helpers list still says `Get / Set / FindSchema, ValidateSchema, RestoreDefaults / RefreshAll`. Doesn't mention M3's new `RawSet`. The `WhatGroup_Settings.lua` blurb doesn't mention `_refresherOrder` (M2). The `WhatGroup.lua` blurb lists the session-only state but doesn't mention M5's `notifyGen` or `WhatGroup:WipeCapture`.
- **`docs/capture-pipeline.md`** — captured-info table at lines 175 / 183 still lists the `info.title` and `{info.activityID}` fallbacks deleted in M2.

These are doc-correctness, not behavioural. Not blocking; not part of the review's scope.

---

## Where to go next

1. **Run [REVIEW_SMOKE_TESTS.md](./REVIEW_SMOKE_TESTS.md).** All sections, but pay attention to the 🔴 critical items.
2. **Decide on F-004.** Verify `GetApplicationInfo` in-game next time you're playing on retail; either apply the migration above or leave the TODO and revisit on patch days.
3. **Address doc backlog** via `/wow-addon:sync-docs` when ready.
4. **Push `main`.** Branch is 7 ahead of `origin/main`. Push when smoke tests are green.
5. **Decide on a version bump.** None of M1–M7 forces a version change (no breaking API, no schema changes, no Interface bump). If you want to ship the combat-safety improvements as a user-visible release, decide on a SemVer-appropriate bump separately from this review.

---

## Cross-references

- [REVIEW_FINDINGS.md](./REVIEW_FINDINGS.md) — original 18 findings
- [REVIEW_PROPOSED_CHANGES.md](./REVIEW_PROPOSED_CHANGES.md) — HLD themes + per-finding LLD
- [REVIEW_EXECUTION_PLAN.md](./REVIEW_EXECUTION_PLAN.md) — milestone ordering, concurrency, suggested commits
- [REVIEW_SMOKE_TESTS.md](./REVIEW_SMOKE_TESTS.md) — review-specific validation checklist
- [docs/smoke-tests.md](../../docs/smoke-tests.md) — canonical addon-wide smoke checklist (boot, slash, panel, real LFG flow, persistence, patch-day, lib-refresh)
