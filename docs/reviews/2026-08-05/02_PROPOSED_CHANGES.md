# 02 — Proposed changes (HLD + LLD)

Derived from `01_FINDINGS.md`. Standards resolved: **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**,
read from the local read-only clone of `WowAddonStandards` (the network fetch timed out; the local
`standards/STANDARDS.md` + all 25 files under `standards/standards/` are the same text). Every
change below was checked against it; the rules that shaped or constrained a change are cited inline
as `filename-§N`.

**No entry in this document targets a path under `libs/` or `tests/_kit/`.**

---

## HLD

### Theme A — Make the master switch mean what it says (F-001, F-002)

The addon has two entry points into the capture pipeline and only one of them is gated. The fix is
not to add a second gate at the second site — that is how the two drift — but to move the gate to
the boundary both handlers share: the event handler's front door. The apply-time gate stays where it
is because it also avoids the wasted `GetSearchResultInfo` call.

The test half of this theme matters more than the code half. The existing case is green today and
would stay green if the gate were deleted, so *fixing the code without fixing the fixture leaves the
regression undetectable*. testing-§12 requires a negative-asserting case to be proven red by
mutation and to carry a `-- red under:` comment; both cases in this pair get one.

**Alternative rejected:** gating inside `CaptureGroupInfo` itself. It is the single choke point and
looks like the tighter fix, but `/wg test` and the panel Test button deliberately bypass the
pipeline (`core/WhatGroup.lua:486-487`, `:688`), and `/wg show` re-opens a capture taken while
enabled. A gate there would need per-caller exemptions, which is the same two-places problem in a
new location. Rejected on architecture-§5 (one seam, one meaning).

### Theme B — Stop the read path from writing (F-003)

`Resolve` currently serves two callers with two intents through one behavior. Splitting the intent —
not the function — keeps the single-write-path invariant (`Helpers.Set` remains the only orchestrated
seam, slash-commands-§5 / options-ui-§1) while making `Get` observably pure.

**Alternative rejected:** having `Get` deep-copy or pcall around the walk. Both leave the write in
place and add cost; the flag is the smaller and more honest change.

### Theme C — Honor the single-source-of-truth comments the code already makes (F-004)

Two label helpers exist and the popup calls one of them. Calling both is a two-line change that makes
the comment at `core/WhatGroup.lua:356-358` true. No new abstraction — the abstraction is already
written, exported and tested.

### Theme D — One click, one cast (F-005)

`RegisterForClicks("AnyUp", "AnyDown")` on a secure macro button is a double dispatch that the
`PreClick` handler already works around. Removing the second edge removes the workaround with it.
The change stays inside the existing lazy-build and combat-queue structure, so no new protected call
site is introduced (events-frames-taint-§2, §4).

### Theme E — Cleanups (F-006, F-007, F-008)

Independent, low-risk, disjoint files. Grouped only so they can be committed together.

### Upstream change-set (separate — lands in another repo)

| Entry | Owning repo | Files | Change | Version move | This repo's exit |
|---|---|---|---|---|---|
| **U-01** (F-U01) | LibKa0s | `Core.lua`, `DebugLog.lua`, `Slash.lua`, `OptionsWidgets.lua`, `Perf.lua` | Rewrite 29 British-spelled words in authored comments to US English (`colour`→`color`, `grey`→`gray`, `synthesise`→`synthesize`, `coloured`→`colored`) | bump each touched file's LibStub **minor** | re-vendor the whole `libs/LibKa0s/` folder as its own commit; no other change |
| **U-02** (F-U02) | LibKa0s | `libs/LibKa0s/`, `tests/_kit/` | Run `diff -r` against the library repo's ship folder and testkit from an unconstrained checkout; resolve any difference by re-vendoring the whole folder | n/a (verification) | a clean `diff`, or a re-vendor commit |

Neither is a local edit. anti-patterns #45/#47 and the vendored-code rule make a patch under
`libs/` a silent regression the moment the folder is copied again.

---

## LLD

### C-01 — Gate the `inviteaccepted` branch on the master switch
**Covers:** F-001 · **File:** `core/WhatGroup.lua` · **Function:** `LFG_LIST_APPLICATION_STATUS_UPDATED` (`:619`)

Before — the handler runs regardless of `enabled`, and only the apply branch is gated:

```lua
function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)
    NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))
    if newStatus == "applied" then
```

After — one gate at the front door, after the trace line so a disabled addon still explains itself
in the console (debug-logging-§8: the "why nothing happened" trace is the one line that must survive
an early return):

```lua
function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)
    NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))
    -- Master switch, same read OnApplyToGroup uses (:488). It belongs at the handler's
    -- boundary rather than at the capture call below, because BOTH the queued and the
    -- re-fetched capture reach pendingInfo through this handler.
    if not (self.db and self.db.profile and self.db.profile.enabled) then
        NS.Debug("LFG", "ignored: addon disabled")
        return
    end
    if newStatus == "applied" then
```

**Risk:** the handler also performs the `wipe(captureQueue)` / `wipe(pendingApplications)` bookkeeping
at `:661-662`. Returning early skips it — which is correct, because the off-flip's
`WipeCapture("addon disabled")` (`settings/Schema.lua:104`) already emptied both, and nothing can
refill them while the switch is off (the apply gate at `:488` sees to that). Verified against
`test_capture.lua`'s re-enable case, which re-applies before accepting.

**Standards:** architecture-§5 (one seam per invariant); debug-logging-§8 (early return keeps its
trace). No new deviation.

### C-02 — Make the two master-switch cases falsifiable
**Covers:** F-002 · **File:** `tests/test_capture.lua` (`:63-76`, `:261-275`)

Remove the `mock.searchResults[…] = nil` line that currently does the work of the assertion, so the
switch is the only thing that can suppress the capture. Add the `-- red under:` comment testing-§12
asks for, and prove it by deleting the C-01 gate and watching the case go red before reverting from
a `cp` backup (never `git checkout` — testing-§12's own warning).

```lua
test("capture: master switch off means nothing is queued", function()
    local NS, _, mock = T.bootAddon()
    local addon = NS.addon
    addon.db.profile.enabled = false
    mock.searchResults[100] = baseInfo({ activityIDs = { 500 } })
    mock.activities[500] = { mapID = 111 }
    addon:OnApplyToGroup(100)
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    -- The search result STAYS LIVE across the accept: a disabled addon must decline to
    -- capture data that is sitting right there. Nilling it (as this case used to) made the
    -- assertion hold whether or not the gate existed.
    -- red under: drop the `enabled` guard at the top of
    --            LFG_LIST_APPLICATION_STATUS_UPDATED in core/WhatGroup.lua.
    addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")
    assertNil(addon.pendingInfo)
end)
```

Add one new case asserting the user-visible half — that no notification line is printed and no
`WhatGroupFrame` is created while disabled — since F-001's real symptom is output, not state.

**Test-count impact:** **422 → 423**. Per testing-§5, `docs/test-cases.md` and the README `[tests]`
badge (`README.md:7`) move **in the same commit** as this change, regenerated with
`lua tests/run.lua --list > docs/test-cases.md`. Never hand-edited.

**Standards:** testing-§12 (falsifiability, `-- red under:` comment, `cp` backup); testing-§5
(inventory + badge move together). No new deviation.

### C-03 — Read-only path resolution for `Helpers.Get`
**Covers:** F-003 · **File:** `settings/Schema.lua` (`:206-229`)

```lua
-- `create` is opt-IN. The write path needs the parent tables materialized; the READ path
-- must not leave keys in the profile that AceDB will then serialize (a Get of an absent
-- nested path used to create every level of it).
local function Resolve(path, create)
    ...
    for i = 1, #segments - 1 do
        local k = segments[i]
        if type(parent[k]) ~= "table" then
            if not create then return nil, nil end
            parent[k] = {}
        end
        parent = parent[k]
    end
    return parent, segments[#segments]
end

function Helpers.Get(path)  local parent, key = Resolve(path)        ... end
function Helpers.RawSet(path, value) local parent, key = Resolve(path, true) ... end
```

**Risk:** `Get`'s existing "no path" branch already returns `nil` after a `NS.Debug` line
(`:224-227`), so a missing parent now takes an established path rather than a new one. `RestoreAllDefaults`
is unaffected — it goes through `Helpers.Set` → `RawSet`, which passes `create = true`.

Add one case: `Get` of an absent nested path returns `nil` **and** leaves `db.profile` unchanged.
**Test-count impact:** +1 (**→ 424** cumulative with C-02); inventory and badge move with it.

**Standards:** savedvariables-§1 (the profile holds what the user set); slash-commands-§5 /
options-ui-§1 (single write seam preserved — `Helpers.Set` is untouched). No new deviation.

### C-04 — Popup calls the shared playstyle helper
**Covers:** F-004 · **File:** `modules/Frame.lua` (`:292-296`)

```lua
-- Before
local playStyle = info.playstyleString
if not playStyle or playStyle == "" then
    playStyle = Labels.PLAYSTYLE[info.generalPlaystyle] or ""
end

-- After — same helper the chat notification uses (core/WhatGroup.lua:391), so a new
-- playstyle rule lands in one place, as that file's comment already claims.
local playStyle = Labels.GetPlaystyleLabel(info)
```

The em-dash placeholder on the next line stays: it is the popup's presentation, not the label rule.

**Risk:** behavior-identical by inspection; `test_frame.lua` and `test_labels.lua` already cover both
the string and the enum branch, so this is a characterization-covered refactor (testing-§13).
**Test-count impact:** none.

### C-05 — One click edge on the secure teleport button
**Covers:** F-005 · **File:** `modules/Frame.lua` (`:145`, `:244-249`)

```lua
-- :145
teleportBtn:RegisterForClicks("AnyUp")   -- was ("AnyUp", "AnyDown")
```

and the `PreClick` handler loses its `if down then` filter, because it now fires exactly once by
construction rather than by filtering:

```lua
btn:SetScript("PreClick", function(_, mouseButton)
    NS.Debug("Frame", "teleport button pressed \226\134\146 /cast " .. spellName
        .. " (spellID=" .. tostring(spellID) .. ", button=" .. tostring(mouseButton) .. ")")
end)
```

**Risk:** the only behavior a user could notice is the cast landing on mouse-**up** rather than
mouse-down. This is a secure-frame configuration write and stays inside `buildFrame` and the existing
`InCombatLockdown` queue at `:191-205`, so no protected call moves into a combat-reachable path.
Requires in-client confirmation (`03_SMOKE_TESTS.md`, T-05) — it cannot be verified headlessly.

**Standards:** events-frames-taint-§2 (secure writes stay behind the lockdown queue), §4 (the
protected-action firewall stays one module). No new deviation.

### C-06 — Delete the five dead locale rows
**Covers:** F-006 · **File:** `locales/enUS.lua` (`:67-70`, `:104`)

Remove the `Ka0s WhatGroup` / `General` / `Slash Commands` / `Defaults` block and the retired
`cannot open settings during combat …` row, replacing the block with a one-line note that the panel
chrome is the options library's and the panel's own labels/tooltips live in `settings/Schema.lua`.

**Rejected alternative:** routing `settings/OptionsSetup.lua:99`, `settings/Panel.lua:176`/`:220` and
every schema `label`/`tooltip` through `L`. It is the larger change, it touches strings the options
library also matches on structurally, and localization-§3 requires only that `enUS.lua` ship — not
that every internal label pass through it. Five orphan rows that silently do nothing are worse than
an honest absence; a real panel translation is one deliberate change, later.

**Standards:** localization-§2/§3 (English string as key; `enUS.lua` present). No new deviation.

### C-07 — Guard the derived secure-button offsets
**Covers:** F-007 · **File:** `modules/Frame.lua` (`:139-140`)

```lua
-- GetLeft/GetTop answer nil when a region's rect has not resolved. The chain here does
-- resolve, but the arithmetic is inside the one-shot builder — a nil would raise and the
-- popup would never exist, so the derived form gets a floor rather than a crash.
local lp, fl = lblPort:GetLeft(), f:GetLeft()
local lt, ft = lblPort:GetTop(),  f:GetTop()
local btnX = (lp and fl) and ((lp - fl) + LABEL_WIDTH + 6) or (14 + LABEL_WIDTH + 6)
local btnY = (lt and ft) and (lt - ft) or -(38 + 5 * -yGap)
```

The fallbacks restate the anchors already written at `:95` (`content` inset 14) and `:126` (the row
stride), so they degrade to the same position rather than a guess.

**Risk:** the fallback branch is unreachable in the mock, so it will not be covered by a test. That
is acceptable for a guard whose whole purpose is a case the harness cannot produce; it is noted here
rather than papered over with a test that pins the mock's behavior.

### C-08 — Cover or drop the `NS.Util.format` fallback
**Covers:** F-008 · **File:** `tests/test_libka0s.lua` (preferred) or `core/CoreSetup.lua:76-82`

Preferred: one case loading with `skip = { "libs/LibKa0s/Core.lua" }` (`tests/loader.lua:62-64`
already supports it — this is testing-§8's "load with the module genuinely absent", not a hand-stub)
that calls `NS.Util.format("%s = %s", "a", 1)` and asserts the printed line. **Test-count impact:**
+1 (**→ 425** cumulative). Inventory and badge move with it.

Fallback option if the shape proves not worth pinning: delete `core/CoreSetup.lua:76-82` and let the
degraded `NS.Util.format` be absent, matching `NS.MakeCloseButton`'s honest `return nil` two lines
below. Do **not** leave it as-is.

---

## Standards conformance summary

| Change | Rules checked | New deviation? |
|---|---|---|
| C-01 | architecture-§5, debug-logging-§8, events-frames-taint-§1 | No |
| C-02 | testing-§5, testing-§12 | No |
| C-03 | savedvariables-§1, slash-commands-§5, options-ui-§1 | No |
| C-04 | architecture-§5, testing-§13 | No |
| C-05 | events-frames-taint-§2, §4 | No |
| C-06 | localization-§1/§2/§3 | No |
| C-07 | events-frames-taint-§6 | No |
| C-08 | testing-§8, testing-§5 | No |
| U-01, U-02 | anti-patterns #45/#46/#47, localization-§5, testing-§11 | Upstream — no local edit |

Two rules were checked and found **not** violated, so no finding was raised: savedvariables-§5 /
anti-patterns #54 (`or`-defaulting a stored falsy value) — the `or` chains in
`core/WhatGroup.lua:210-241` operate on **LFG API capture data**, not on stored settings, and the
file argues the case explicitly at `:204-209`; the actual settings reads at `:488`, `:547` and
`:549` use `== false` / truthiness correctly. And anti-patterns #22 — the settings **category** is
registered eagerly at `OnEnable` (`core/WhatGroup.lua:160-162`), with only the body lazy.
