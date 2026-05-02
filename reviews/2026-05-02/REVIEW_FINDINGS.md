# Ka0s WhatGroup — Review Findings (2026-05-02)

**Verdict:** Minor issues. No taint regressions, no data-loss risks, no broken contracts. The codebase is well-organized, the taint history is well-documented, and invariants line up with intent. The findings below are mostly combat-edge bugs, design hazards in the secure-button configuration path, doc/comment drift, and a handful of correctness questions worth running down.

Severity counts: Critical 0, High 3, Medium 8, Low 7.

---

## High

### F-001 — `ConfigureTeleportButton` mutates a SecureActionButtonTemplate from non-secure code, no `InCombatLockdown` guard
**Location:** `WhatGroup_Frame.lua:200-247` (`ConfigureTeleportButton`), called from `PopulateFields` (`:282`), called from `WhatGroup:ShowFrame()` (`:298`).
**Problem:** `ConfigureTeleportButton` calls `btn:SetAttribute("type", …)`, `btn:SetAttribute("macrotext", …)`, `btn:EnableMouse(...)`, `btn:Show()`, and `btn:Hide()` on a `SecureActionButtonTemplate` button. None of these are guarded by `InCombatLockdown()`. If the popup is opened during combat — via `/wg show`, the chat link, or popup auto-show after a fast LFG accept that lands inside an active combat tick — the secure-action attribute writes are silently dropped (no error, but the button's `/cast` macro never gets set or gets stale state) and the `:Show()` / `:Hide()` calls are rejected. The popup chrome still renders, but the teleport button is non-functional until the player reopens it after combat.
**Impact:** UX bug. The headline feature (one-click dungeon teleport) silently misbehaves in combat. Worse, the failure mode is "the button shows but does nothing or the wrong thing" rather than a clear "wait until combat ends" message.
**Tag:** `[taint][bug]`

### F-002 — `buildFrame()` creates the SecureActionButtonTemplate button on first show; if first show is in combat, frame creation can taint or fail
**Location:** `WhatGroup_Frame.lua:72-248` (`buildFrame`), specifically `:160-164` (`CreateFrame("Button", … "SecureActionButtonTemplate")` + `RegisterForClicks` + `Hide()`).
**Problem:** The whole `buildFrame()` body is wrapped in a one-shot guard and runs on the first `ShowFrame()` call. If that first call lands during combat, `CreateFrame` for a SecureActionButtonTemplate is allowed but `RegisterForClicks("AnyUp", "AnyDown")` (`:163`) and `Hide()` (`:164`) on the freshly-created secure button are protected. Combination of `buildFrame` running mid-combat plus the lazy entry into `UISpecialFrames` (`tinsert(UISpecialFrames, "WhatGroupFrame")` at `:184`) is also a concern — UISpecialFrames mutation is not blocked but having a half-built popup is observable to the user.
**Impact:** First-show during combat may produce a popup with a broken teleport button until `/reload`. Easy to repro: `/wg test` while in combat on a fresh login.
**Tag:** `[taint][bug]`

### F-003 — `runConfig`'s lazy `Settings.Register()` builds AceGUI panels on first `/wg config`; if the user runs it during combat the InCombatLockdown gate sits on top of the slash command but `Settings.Register()` can still be called from any future code path that bypasses the guard
**Location:** `WhatGroup.lua:835` (combat gate), `WhatGroup.lua:847-849` (`Settings.Register()` call), `WhatGroup_Settings.lua:922-1003` (registration body, including `_G.Settings.RegisterCanvasLayoutCategory` / `RegisterAddOnCategory` / `RegisterCanvasLayoutSubcategory`).
**Problem:** Today `Settings.Register()` is only reachable through `runConfig`, which has a combat guard. That's correct. But the registration body itself has no guard, and the `Settings.Register` symbol is public on `WhatGroup.Settings`. A future caller (or a refactor that moves the call to a different entry point) could bypass the guard. The Settings API surface is documented elsewhere (per the addon's own taint analysis) as combat-protected. Recommend the guard live inside `Settings.Register()` itself, not just in the slash handler — defense in depth, since the addon already knows the call is combat-sensitive.
**Impact:** Latent footgun. Any future caller that forgets the guard will reintroduce taint.
**Tag:** `[taint][design]`

---

## Medium

### F-004 — `LFG_LIST_APPLICATION_STATUS_UPDATED` re-fetches via `C_LFGList.GetSearchResultInfo(appID)` but `appID` is not documented as a valid `searchResultID`
**Location:** `WhatGroup.lua:554` — `local fresh = self:CaptureGroupInfo(appID)`. `CaptureGroupInfo` (`:264`) calls `C_LFGList.GetSearchResultInfo(appID)` directly.
**Problem:** Per the LFG API, `LFG_LIST_APPLICATION_STATUS_UPDATED` provides an `appID`, while `C_LFGList.GetSearchResultInfo` is documented to accept a `searchResultID`. The capture-pipeline doc (`docs/capture-pipeline.md:95`) claims "for the player's own application is the same value as the searchResultID — feeding it back into GetSearchResultInfo works." This is undocumented Blizzard behaviour, not a contract. The proper API for application data is `C_LFGList.GetApplicationInfo(appID)`. If a future patch hardens the type check on `GetSearchResultInfo`, the `fresh` re-capture silently returns nil and the addon falls back to the queued capture (which is the safety-net path, so the user-visible failure is "popup data is slightly stale, mapID may be missing").
**Impact:** Functional bug risk. Worth verifying in-game with `/wg debug` whether the `fresh` re-capture is actually returning a populated table today, or whether the queued fallback is doing all the work.
**Tag:** `[bug-risk][design]`

### F-005 — Doc/comment drift: `WhatGroup_Settings.lua:912` says `Settings.Register()` is "Called from WhatGroup:OnEnable"
**Location:** `WhatGroup_Settings.lua:912`. Actual caller: `WhatGroup.lua:847-849` in `runConfig`.
**Problem:** The header comment on `Settings.Register` says it's called from `OnEnable`. The whole point of the lazy-registration pattern (extensively documented elsewhere) is that it is **not** called from `OnEnable` because doing so taints GameMenu callbacks. A future contributor reading only this comment could re-introduce the taint regression.
**Impact:** Misleading doc on the most taint-sensitive function in the addon.
**Tag:** `[doc-drift]`

### F-006 — Doc drift: `docs/scope.md` still describes hooks as `SecureHook on ApplyToGroup`
**Location:** `docs/scope.md:20` and `:38`.
**Problem:** Two places in `scope.md` say "`SecureHook` on `ApplyToGroup`" / "Every hook is observation-only — `SecureHook` on `ApplyToGroup`". Both are stale. The actual code uses direct `hooksecurefunc(C_LFGList, "ApplyToGroup", …)` (no AceHook). `ARCHITECTURE.md`, `CLAUDE.md`, and `docs/wow-quirks.md` all correctly say `hooksecurefunc`; only `scope.md` lags.
**Impact:** A new contributor reading `scope.md` first would assume AceHook is in use, contradicting the project's hardest invariant.
**Tag:** `[doc-drift]`

### F-007 — Duplicated `PLAYSTYLE_LABELS` and `GetGroupTypeLabel` between `WhatGroup.lua` and `WhatGroup_Frame.lua`
**Location:** `WhatGroup.lua:374-385` (`PLAYSTYLE_LABELS` + `GetPlaystyleLabel`) and `:351-369` (`GetGroupTypeLabel`); `WhatGroup_Frame.lua:29-34` (duplicate `PLAYSTYLE_LABELS`) and `:54-64` (duplicate `GetGroupTypeLabel`).
**Problem:** Two identical local copies of the playstyle table and the group-type derivation. The duplication is intentional per `docs/frame.md`, but the rationale (Frame doesn't take a load-time dependency on `WhatGroup.lua`'s internals) is weak: `WhatGroup_Frame.lua` already calls `WhatGroup:GetTeleportSpell`, `WhatGroup._dbg`, `WhatGroup.pendingInfo`, and reads `Enum.LFGEntryGeneralPlaystyle` (which comes from the client, not `WhatGroup.lua`). There is no actual load-order reason for the duplication — both files run after all libs and after `Enum` exists. The risk: if `WhatGroup.lua` adds a new `PlayStyle` enum (e.g. a 5th category Blizzard introduces), only one of the two copies gets updated.
**Impact:** Two truth sources where one would do. Drift hazard.
**Tag:** `[design][duplication]`

### F-008 — `Helpers.Set` does NOT call `def.onChange`; only `applyFromText` does
**Location:** `WhatGroup_Settings.lua:201-205` (`Helpers.Set`), `WhatGroup.lua:743-747` (`applyFromText` calls onChange), `WhatGroup.lua:880-884` (`runDebug` calls `H.Set` without firing onChange).
**Problem:** `Helpers.Set(path, value)` is a raw write — it does not run the schema row's `onChange`. The CLI's `applyFromText` runs `H.Set` then `def.onChange` then `H.RefreshAll`. The Defaults reset path runs `H.Set` then `def.onChange` then `H.RefreshAll`. The Settings panel widget callbacks (`makeCheckbox`, `makeSlider`) run `H.Set` then `fireOnChange`. Every documented "single write path" actually consists of `H.Set` + an explicit onChange + an explicit Refresh. The naming `Helpers.Set` suggests "this is the single write path" but it's not — it's only one third of the path. `runDebug` happens to work because it pre-sets `WhatGroup.debug` before calling `H.Set`, so it doesn't need to fire the `debug` row's onChange. But the next person adding a setter caller may not realize `H.Set` is the raw lower layer.
**Impact:** Single-write-path naming/design hazard. Two reasonable fixes: rename `Helpers.Set` to `Helpers.RawSet` and introduce a `Helpers.Set` that orchestrates `RawSet + onChange + RefreshAll`, OR fold onChange + a refresher-call into the existing `Helpers.Set`.
**Tag:** `[design][naming]`

### F-009 — Frame layout uses fixed-pixel offsets that drift if any field changes
**Location:** `WhatGroup_Frame.lua:160-169` — `teleportBtn:SetPoint("LEFT", 92, -68)`, `content:SetHeight(math.abs(yGap) * 6 + 24)`.
**Problem:** The teleport button anchors to `f` with hard-coded `(92, -68)` — a magic position computed by counting label heights at design time. The label rows are computed with `MakeLabel(..., yGap)` chains (relative anchors), but the secure button can't anchor relative to a non-secure region (per the addon's own quirk doc), so it sits at fixed offsets. If anyone changes `LABEL_WIDTH` (`:23`), `yGap` (`:24`), or inserts a new field row, the teleport button no longer aligns with the Teleport label. The `content:SetHeight(math.abs(yGap) * 6 + 24)` line has the same issue (the magic 6 = number of rows, hard-coded).
**Impact:** Maintenance hazard. Mitigation: derive the offsets from the same constants the labels use, or anchor the button to the popup at `("TOPLEFT", LABEL_WIDTH + 6 + 14, headerOffset + (rowIndex * yGap))` computed at build time.
**Tag:** `[design][maintainability]`

### F-010 — `_TryFireJoinNotify` schedules notify+popup with `C_Timer.After`; nothing cancels the timer if the player leaves the group during the delay
**Location:** `WhatGroup.lua:489-511` (`_TryFireJoinNotify`).
**Problem:** When notify is scheduled via `C_Timer.After(delay, function() … end)`, the closure captures `self` and the current `pendingInfo` reference. If the player leaves the group during the `notify.delay` window (default 1.5s, configurable to 10s), `GROUP_ROSTER_UPDATE` clears `self.pendingInfo` to nil. The scheduled callback then fires `ShowNotification()` (which checks `info` is nil and returns early — fine) but also calls `ShowFrame()` if `autoShow` is on. `ShowFrame()` calls `PopulateFields()`, which sees `info == nil` and renders "No data" placeholders, then `f:Show()` — the user gets an empty popup for a group they just left.
**Impact:** Edge-case UX bug. The "No data" popup auto-opens on a group-leave during the delay window.
**Tag:** `[bug][ux]`

### F-011 — `OnApplyToGroup` enabled-gate test is not consistent with the "session-only state" invariant
**Location:** `WhatGroup.lua:447-454`.
**Problem:** When `db.profile.enabled` is false, `OnApplyToGroup` early-returns. But `LFG_LIST_APPLICATION_STATUS_UPDATED` is registered unconditionally and still fires through `applied` / `inviteaccepted`. If the user toggles `enabled` from `true` to `false` while a capture is mid-pipeline (already in `captureQueue` or `pendingApplications`), the partial state survives the toggle and may produce a notify on the eventual join — even though the user just disabled the addon. The cleanest fix is to wipe `captureQueue` / `pendingApplications` / `pendingInfo` / `notifiedFor` whenever `enabled` flips false (in the `enabled` row's `onChange`).
**Impact:** Master-switch semantics aren't exact: a user expecting "Off → no popup ever" can still see a popup from a pre-toggle apply.
**Tag:** `[bug][ux]`

---

## Low

### F-012 — `info.title` fallback in `CaptureGroupInfo` is dead code
**Location:** `WhatGroup.lua:271` — `title = info.name or info.title or "Unknown"`.
**Problem:** `C_LFGList.GetSearchResultInfo` returns a structure with `name` but no `title` field. The `or info.title` fallback never matches. Either drop it or comment-document why it's defensive.
**Impact:** Confusing-on-read.
**Tag:** `[naming][cleanup]`

### F-013 — `info.activityIDs[1]` fallback to `info.activityID` is dead code
**Location:** `WhatGroup.lua:284` — `activityIDs = info.activityIDs or (info.activityID and {info.activityID}) or {}`.
**Problem:** `GetSearchResultInfo` always returns `activityIDs` (even if a one-element table). The `info.activityID` fallback is dead.
**Impact:** Confusing-on-read.
**Tag:** `[naming][cleanup]`

### F-014 — `WhatGroup_Frame.lua` declares `VALUE_COLORS` resolvers that all return `nil`
**Location:** `WhatGroup_Frame.lua:38-44`.
**Problem:** Every entry is `function(info) return nil end`. The `ColorizeValue` helper (`:46-52`) handles nil-or-empty, so the resolvers never actually colorize. Either delete the table and inline the no-op behaviour into `PopulateFields`, or delete the resolvers and keep the call site simple. Today this is a "color hook in case we want it later" surface that has no callers and no callers-to-be in the schema.
**Impact:** Dead-ish abstraction.
**Tag:** `[design][cleanup]`

### F-015 — `pickKnownSpell` may return a spellID that `IsSpellKnown` is false for, with no caller-visible distinction
**Location:** `WhatGroup.lua:327-337`.
**Problem:** When the spell map value is a table and the player knows none of the listed spells, `pickKnownSpell` returns `value[1]` so the popup at least shows a desaturated icon. But `GetTeleportSpell` then returns this spellID with no signal that "this is a fallback, not the player's known spell". Callers downstream re-check `IsSpellKnown` (in `ShowNotification` and `ConfigureTeleportButton`), which is fine. But the contract is awkward: "picks the known one if any, otherwise pretends the first is known". Document the contract or add a second return value (`spellID, isKnown`).
**Impact:** Naming clarity.
**Tag:** `[naming]`

### F-016 — `Settings.Helpers` is exported but `Settings.Schema` and `Settings.Helpers` are read directly by `WhatGroup.lua`
**Location:** `WhatGroup.lua:599` (`return WhatGroup.Settings and WhatGroup.Settings.Helpers`), `:675` (`self.Settings.Schema`), `:682` (`self.Settings.Schema`).
**Problem:** Some code reads `WhatGroup.Settings.Helpers` directly; some uses the local `helpers()` accessor. Pick one.
**Impact:** Style consistency.
**Tag:** `[naming]`

### F-017 — `Helpers.Get(path)` returns nil silently when path doesn't exist; debugging an undefined path is harder than it should be
**Location:** `WhatGroup_Settings.lua:195-199`.
**Problem:** A typo in a path (`/wg get notify.showInstance` vs. `/wg get notify.showinstance`) returns nil through `Helpers.Get`, but `getSetting` first calls `H.FindSchema(path)` which catches the bad path with a proper error. Inside helpers, however, a typo elsewhere (e.g. in code) silently gets nil. Consider making `Helpers.Get` log a debug line on schema-mismatch when `WhatGroup.debug` is on.
**Impact:** Diagnostic friction.
**Tag:** `[observability]`

### F-018 — `Helpers.RefreshAll` calls every refresher in `pairs` order; refresher order is non-deterministic
**Location:** `WhatGroup_Settings.lua:309-316`. Refreshers are stored in a hash table (`Settings._refreshers[def.path] = …`), iterated with `pairs`.
**Problem:** Mostly harmless — refreshers are independent. But if the panel ever has cross-row visual coupling (e.g. greying out one row when another flips), the order would matter and `pairs` would shuffle it. Lua-idiomatic fix: keep refreshers in an array (or track an explicit order list) and iterate in schema order.
**Impact:** Latent ordering hazard.
**Tag:** `[design]`
