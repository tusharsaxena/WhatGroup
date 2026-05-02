# Ka0s WhatGroup — Proposed Changes (HLD + LLD)

Pairs with [REVIEW_FINDINGS.md](./REVIEW_FINDINGS.md). HLD groups findings into themes; LLD lists per-finding code-shape changes.

---

## HLD — themes

### Theme A: Combat-safety hardening of the secure popup
**Findings covered:** F-001, F-002, F-003.
**Rationale:** The addon's secure-button design is correct out-of-combat (parent the secure button to the popup, use the implicit-parent SetPoint form, set attributes via `SetAttribute`). What's missing is the combat-edge handling. Three code paths can drive the secure button mid-combat (chat-link click, `/wg show`, popup auto-show after a fast LFG accept), and `Settings.Register()` can plausibly be called from a future caller bypassing the slash-handler combat guard. The fix is a small "deferred-config" pattern: when in combat, perform the layout / register work that doesn't touch protected attributes, queue the rest on `PLAYER_REGEN_ENABLED`, and expose a clear chat hint.
**Alternatives considered:**
- *Just refuse to show the popup in combat.* Rejected — the user joins LFG mid-combat all the time; refusing the popup defeats its purpose. The popup itself is non-secure, only the teleport button is.
- *Make the teleport button a non-secure clickable that calls `CastSpellByName`.* Rejected — `CastSpellByName` is also protected in retail and fires `ADDON_ACTION_FORBIDDEN`. The macro-attribute path is the only legal route.
- *Fully build the frame at file-load.* Rejected — that re-introduces the documented Logout taint.
**Trade-off:** The combat-edge popup will show with an unconfigured (hidden) teleport button, then the button surfaces when combat ends. UX-honest, taint-clean.

### Theme B: Tighten the single-write-path for settings
**Findings covered:** F-008, F-018.
**Rationale:** The convention "one row in `Settings.Schema` drives every surface" is well-established and load-bearing for the addon's slash UX, panel UX, and reset path. But the `Helpers.Set` API is misleading — it's the raw write, not the orchestrated path. Three independent callers (panel widget callbacks, `applyFromText`, `RestoreDefaults`) each manually compose `H.Set + onChange + RefreshAll`. Folding the orchestration into `Helpers.Set` (and renaming the raw write to `Helpers.RawSet`) collapses the duplication and makes future setters write through the right path by default.
**Alternatives considered:**
- *Leave `Helpers.Set` as-is, document that callers must call onChange + RefreshAll.* Rejected — that's where we are today and `runDebug` already half-bypasses the convention. Convention has to be defended by code, not by docs.
- *Move all setters through `applyFromText`.* Rejected — `applyFromText` is a CLI-text-parsing function, the wrong abstraction layer for panel callbacks and reset.
**Trade-off:** Existing call sites that already compose `Set + onChange + RefreshAll` (the three above) become one line each, but anyone who wanted "raw write without side-effects" has to use `RawSet` explicitly.

### Theme C: De-duplicate playstyle and group-type label tables
**Findings covered:** F-007.
**Rationale:** Two truth sources for the same enum mapping is the textbook DRY violation; the rationale documented in `docs/frame.md` (avoiding cross-file dependency) doesn't hold given that `WhatGroup_Frame.lua` already calls four other things on the `WhatGroup` table. Move the helpers onto `WhatGroup` (or onto a shared `WhatGroup.Labels` namespace) once.
**Alternatives considered:**
- *Move both into a new `WhatGroup_Labels.lua` file.* Rejected — extra TOC line for two tables and two functions is overweight.
- *Leave duplicated, add a unit-test that pins the two copies in sync.* Rejected — there is no test infra; manual smoke tests can't detect drift.
**Trade-off:** `WhatGroup_Frame.lua` gains an explicit dependency on `WhatGroup.Labels` (or similar). That dependency already exists implicitly (through `WhatGroup:GetTeleportSpell` etc.) so no real new coupling.

### Theme D: Doc/comment correctness sweep
**Findings covered:** F-005, F-006, F-012, F-013.
**Rationale:** A cluster of small drift between code and docs/comments. None are user-visible but each is a trap for a future contributor. Sweep them in one pass.
**Trade-off:** None.

### Theme E: Capture-pipeline correctness audit
**Findings covered:** F-004, F-010, F-011.
**Rationale:** The capture pipeline is the addon's core value proposition and most of it is right. The three issues are: (a) `GetSearchResultInfo(appID)` is undocumented and may break, (b) the notify timer doesn't cancel on group-leave, (c) the master-switch can leak captures already in flight. None individually critical, but together they make the pipeline edge-cases brittle.
**Alternatives considered:**
- *Replace `GetSearchResultInfo(appID)` with `GetApplicationInfo(appID)`.* Best long-term fix; needs verification of which fields `GetApplicationInfo` exposes vs. what `GetSearchResultInfo` does.
- *Cancel the notify timer with a generation counter.* Cleaner than tracking the timer handle (`C_Timer.NewTimer` returns one but `C_Timer.After` doesn't).
**Trade-off:** Minor — generation counter adds one local. The API change for `GetSearchResultInfo` → `GetApplicationInfo` is a verify-then-do.

### Theme F: Frame-layout decoupling from magic numbers
**Findings covered:** F-009.
**Rationale:** Hard-coded `(92, -68)` for the teleport button's anchor against a non-secure frame computed from row-counts is the kind of thing that breaks the day someone reorders rows. Compute the offset from the same constants the rows use.
**Trade-off:** Slightly more arithmetic at build time; readability win.

### Theme G: Cleanup nits
**Findings covered:** F-014, F-015, F-016, F-017.
**Rationale:** Each is a small consistency / clarity nudge. Roll them into one cleanup pass that doesn't touch behaviour.
**Trade-off:** None.

---

## LLD — per-finding change set

### F-001 — Combat-guard `ConfigureTeleportButton`
**File:** `WhatGroup_Frame.lua` (around `:200-247`).
**Change:** Wrap the secure-attribute and Show/Hide block in an `InCombatLockdown()` check. When in combat, hide the button and queue a re-run of `ConfigureTeleportButton` on `PLAYER_REGEN_ENABLED` (one-shot, registered against `f` or against the addon's existing event registrations).
```lua
ConfigureTeleportButton = function(btn, icon, info)
    if InCombatLockdown() then
        btn:Hide()              -- pre-combat Show was OK; this Hide is rejected, so guard
        f._pendingTeleportInfo = info
        if not f._regenRegistered then
            f._regenRegistered = true
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function(self, ev)
                if ev == "PLAYER_REGEN_ENABLED" and self._pendingTeleportInfo then
                    ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon,
                                            self._pendingTeleportInfo)
                    self._pendingTeleportInfo = nil
                end
            end)
        end
        return
    end
    -- existing body
end
```
**Risk:** Adding an event handler to the popup frame is fine — `f` is non-secure. The one-shot `_regenRegistered` flag prevents duplicate registrations. Unit-of-test: `/wg test` in combat → popup shows with no teleport button → drop combat → button appears.

### F-002 — Defer first `buildFrame()` past combat
**File:** `WhatGroup_Frame.lua` `WhatGroup:ShowFrame()` (`:286-301`).
**Change:** At the top of `ShowFrame`, if `f` is nil and `InCombatLockdown()`, queue the build on `PLAYER_REGEN_ENABLED` and print a one-line chat hint. The popup will show on combat-end with full functionality.
```lua
function WhatGroup:ShowFrame()
    if not f and InCombatLockdown() then
        if WhatGroup._print then
            WhatGroup._print("Popup deferred until combat ends.")
        end
        if not WhatGroup._frameBuildQueued then
            WhatGroup._frameBuildQueued = true
            local pending = WhatGroup.pendingInfo
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                WhatGroup._frameBuildQueued = nil
                WhatGroup.pendingInfo = WhatGroup.pendingInfo or pending
                WhatGroup:ShowFrame()
            end)
        end
        return
    end
    buildFrame()
    -- existing body
end
```
**Risk:** None — the deferred build is the same code path as the regular first-show.

### F-003 — Add an `InCombatLockdown` guard inside `Settings.Register()`
**File:** `WhatGroup_Settings.lua` `Settings.Register()` (`:922`).
**Change:** First line after the idempotent guard, refuse during combat and print a hint. Belt-and-suspenders behind the existing `runConfig` guard.
```lua
function Settings.Register()
    if WhatGroup._settingsRegistered or not _G.Settings or … then return end
    if InCombatLockdown() then
        if WhatGroup._print then
            WhatGroup._print("Cannot register settings panel during combat.")
        end
        return
    end
    -- existing body
end
```
**Risk:** None.

### F-004 — Replace `GetSearchResultInfo(appID)` with `GetApplicationInfo(appID)` in the inviteaccepted re-capture
**File:** `WhatGroup.lua:554` and `CaptureGroupInfo` (`:263`).
**Change:** Split `CaptureGroupInfo` into two paths. The apply-time path stays as-is (`GetSearchResultInfo(searchResultID)`). The re-capture path calls `C_LFGList.GetApplicationInfo(appID)`, which returns `(applicationID, lfgListID, status, …)`; use `lfgListID` (the searchResultID for the apply) to call `GetSearchResultInfo` and then `GetActivityInfoTable` as today.
```lua
function WhatGroup:CaptureGroupInfoFromApplication(appID)
    if not (C_LFGList.GetApplicationInfo) then return nil end
    local _, lfgListID = C_LFGList.GetApplicationInfo(appID)
    if not lfgListID then return nil end
    return self:CaptureGroupInfo(lfgListID)
end
```
Then in the inviteaccepted handler: `local fresh = self:CaptureGroupInfoFromApplication(appID)`.
**Risk:** This needs in-game verification — confirm `C_LFGList.GetApplicationInfo` exists at retail interface 120000-120005 and returns the expected fields. If not, fall back to the current behaviour with a code comment that it's an undocumented quirk. **Action:** verify before applying.

### F-005 — Fix `Settings.Register()` header comment
**File:** `WhatGroup_Settings.lua:912`.
**Change:** "Called from WhatGroup:OnEnable. Idempotent." → "Called lazily from `runConfig` (the `/wg config` slash handler) on first invocation. Idempotent. **Not** called from `OnEnable` — see [docs/wow-quirks.md → Lazy popup, secure button, and Settings registration](../docs/wow-quirks.md) for the taint reasoning."
**Risk:** None.

### F-006 — Fix `docs/scope.md` hook descriptions
**File:** `docs/scope.md:20`, `:38`.
**Change:** Replace "SecureHook on ApplyToGroup" with "direct `hooksecurefunc` on `C_LFGList.ApplyToGroup`". Cross-reference the exact function names used in `WhatGroup.lua:39, 45`.
**Risk:** None.

### F-007 — Consolidate playstyle / group-type helpers
**File:** New `WhatGroup.Labels` namespace exposed on the addon table from `WhatGroup.lua` (extract the existing locals); `WhatGroup_Frame.lua` removes its duplicates and reads from `WhatGroup.Labels`.
**Change sketch in `WhatGroup.lua`:**
```lua
WhatGroup.Labels = {
    PLAYSTYLE = { … },                       -- the existing local table
    GetPlaystyleLabel = function(info) … end,
    GetGroupTypeLabel = function(info) … end,
}
```
**Change sketch in `WhatGroup_Frame.lua`:** drop the local `PLAYSTYLE_LABELS` and `GetGroupTypeLabel`; replace call sites with `WhatGroup.Labels.PLAYSTYLE`, `WhatGroup.Labels.GetGroupTypeLabel(info)`.
**Risk:** Load-order. `WhatGroup_Frame.lua` loads after `WhatGroup.lua`, so `WhatGroup.Labels` exists by the time `WhatGroup_Frame.lua` reads it at file-load. The `PLAYSTYLE_LABELS` and `GetGroupTypeLabel` reads in `WhatGroup_Frame.lua` happen inside `PopulateFields` (called from `ShowFrame`, post-load), so no file-load timing concern even if the table is built lazily.

### F-008 — Make `Helpers.Set` the orchestrated single write-path
**File:** `WhatGroup_Settings.lua:201-205` (`Helpers.Set`), and call sites in `WhatGroup.lua` and `WhatGroup_Settings.lua`.
**Change:**
```lua
function Helpers.RawSet(path, value)
    local parent, key = Resolve(path)
    if not parent then return end
    parent[key] = value
end

function Helpers.Set(path, value, opts)
    Helpers.RawSet(path, value)
    local def = Helpers.FindSchema(path)
    if def and def.onChange and not (opts and opts.skipOnChange) then
        local ok, err = pcall(def.onChange, value)
        if not ok then pout("onChange for " .. path .. " failed: " .. tostring(err)) end
    end
    if not (opts and opts.skipRefresh) then
        Helpers.RefreshAll()
    end
end
```
Then `applyFromText`, `makeCheckbox.OnValueChanged`, `makeSlider.OnValueChanged`, and `RestoreDefaults` collapse to a single `Helpers.Set(path, value)` call. `runDebug` does the same. The `RestoreDefaults` loop passes `{skipRefresh = true}` and calls `RefreshAll` once at the end (perf).
**Risk:** Behaviour-equivalent for current call sites; new shape catches the next setter caller automatically.

### F-009 — Compute teleport-button anchor from row constants
**File:** `WhatGroup_Frame.lua:147-169`.
**Change:** Track the y-offset accumulated by `MakeLabel` calls, anchor `teleportBtn` at `("TOPLEFT", LABEL_WIDTH + 6 + 14, computedYOffset)` (the +14 is the content's left padding from `f`). Replace `content:SetHeight(math.abs(yGap) * 6 + 24)` with the same accumulated y-offset + a trailing pad. A small struct of `{ row, label, value, y }` per row is enough.
**Risk:** Need to retest popup layout at default UI scale + at 0.65 and 1.15 for visual regression.

### F-010 — Cancel scheduled notify on group-leave via a generation counter
**File:** `WhatGroup.lua:489-511` and `:529-535`.
**Change:**
```lua
local notifyGen = 0
function WhatGroup:_TryFireJoinNotify(reason)
    -- existing gates …
    notifiedFor = self.pendingInfo
    notifyGen = notifyGen + 1
    local thisGen = notifyGen
    local capturedInfo = self.pendingInfo
    C_Timer.After(delay, function()
        if notifyGen ~= thisGen then return end          -- cancelled
        if self.pendingInfo ~= capturedInfo then return end  -- replaced
        self:ShowNotification()
        if autoShow then self:ShowFrame() end
    end)
end
```
Then in `GROUP_ROSTER_UPDATE`'s leave branch, `notifyGen = notifyGen + 1` to invalidate any pending timer.
**Risk:** Adds two locals, no behaviour change for the happy path.

### F-011 — Wipe capture state when `enabled` flips false
**File:** `WhatGroup_Settings.lua` `enabled` schema row (`:73-79`).
**Change:** Add `onChange = function(v) if not v then WhatGroup:WipeCapture() end end` to the `enabled` row, and add a `WhatGroup:WipeCapture()` method in `WhatGroup.lua` that wipes `captureQueue`, `pendingApplications`, sets `pendingInfo` and `notifiedFor` to nil, and bumps `notifyGen` (per F-010).
**Risk:** None — wipe is what `GROUP_ROSTER_UPDATE` does on leave; reusing the path is consistent.

### F-012 / F-013 — Clean up dead-code fallbacks in `CaptureGroupInfo`
**File:** `WhatGroup.lua:271, 284`.
**Change:** Either drop `or info.title` and `(info.activityID and {info.activityID})`, or annotate "// historical fallback for old API shape, not currently reachable". Drop is cleaner.
**Risk:** None.

### F-014 — Drop `VALUE_COLORS` no-op resolvers, or wire them to a real source
**File:** `WhatGroup_Frame.lua:38-52`.
**Change:** Either delete the `VALUE_COLORS` table and the `ColorizeValue` helper, replacing call sites with a plain `value:SetText(text)`, OR populate the table with at least one functional resolver (e.g. color-by-group-type). Delete is the smaller change.
**Risk:** None for delete.

### F-015 — Document `pickKnownSpell` contract or return `(spellID, isKnown)`
**File:** `WhatGroup.lua:327-337`.
**Change:** Return a second value `isKnown`; downstream callers (`ShowNotification`, `ConfigureTeleportButton`) use it directly instead of re-calling `IsSpellKnown`.
**Risk:** Two callers update; both already call `IsSpellKnown` separately so the change is mechanical.

### F-016 — Use `helpers()` accessor uniformly
**File:** `WhatGroup.lua:675, 682`.
**Change:** Replace `self.Settings.Schema` with `WhatGroup.Settings and WhatGroup.Settings.Schema or {}` (or factor a `schema()` accessor mirroring `helpers()`).
**Risk:** None.

### F-017 — Add a debug-mode log in `Helpers.Get` for unknown paths
**File:** `WhatGroup_Settings.lua:195-199`.
**Change:**
```lua
function Helpers.Get(path)
    local parent, key = Resolve(path)
    if not parent then
        if WhatGroup.debug and WhatGroup._dbg then
            WhatGroup._dbg("Helpers.Get: no path -> " .. tostring(path))
        end
        return nil
    end
    return parent[key]
end
```
**Risk:** None.

### F-018 — Track refresher order alongside the hash
**File:** `WhatGroup_Settings.lua:34, 309-316, 701-704, 724-727`.
**Change:** Add `Settings._refresherOrder = {}` next to `_refreshers`. When registering a refresher, append to the order array. `RefreshAll` iterates the array.
**Risk:** None — order matches schema source order, which is the panel render order.
