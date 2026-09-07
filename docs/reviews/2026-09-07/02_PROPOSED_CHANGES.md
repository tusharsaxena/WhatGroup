# WhatGroup — Proposed Changes (2026-09-07)

Derived from `01_FINDINGS.md`. **Standard resolved: Ka0s WoW Addon Standard v2.38.0 (2026-09-02)**,
fetched in full (index + every section file linked from its Sections list). The standards
cross-check was **performed**; every change below states its conformance.

**No change in this document targets a path under `libs/` or `tests/_kit/`.** There are no upstream
findings in this review, so there is no upstream change-set section — the vendored payload is
byte-identical to `../LibKa0s` at v1.25.0 and no defect was found in it.

---

## HLD — themes

### Theme A — make `visibility` a state the addon *maintains*, not a question it asks once

**Covers:** `WHATGROUP-R-01`, and path 1 of `WHATGROUP-R-02`.

The settings revamp gave WhatGroup the canonical `options-ui-§15` Master controls block, including
`General visibility` with its four values. The dropdown was wired the way a *size* or *alpha*
setting is wired — read it when you draw, and re-read it when the user changes it. But two of its
four values are functions of a variable the user does not control and that changes without touching
the panel: combat state. A setting whose answer changes on its own needs an event, not an
`onChange`.

The change is therefore small and structural rather than a patch: `visibilityAllows()` already
exists and already answers correctly; what is missing is (a) something that calls it when combat
starts or ends, and (b) a `ApplyFrameVisibility` that can act in both directions rather than only
hiding.

**Alternatives considered.**

- *Poll on a timer.* Rejected outright. `performance-§12`'s re-check trigger names a repeating
  ticker specifically, and this addon has spent two ratified deviation rows arguing about the one it
  already has. Adding a second to answer a question the client fires an event for is exactly the
  anti-pattern the standard's OnUpdate/ticker rules exist to prevent.
- *Gate at the show call only, and document the limitation instead of fixing it.* Rejected. The
  README already promises the behaviour (`README.md:75`), the label is the collection's canonical
  one, and a sibling with the same row (`AbsorbTracker/modules/Display.lua:251`) implements it
  correctly — so "document it" would ratify one addon behaving differently from another under the
  same control, which is the drift `options-ui-§15` exists to end.
- *Show the popup on combat entry even with no `pendingInfo`.* Rejected. A "No data" popup appearing
  the moment a player pulls is worse than nothing. The re-show is gated on there being something to
  show.

**Trade-off.** This adds the addon's first `PLAYER_REGEN_DISABLED` registration. That is a
combat-window event handler, which touches the `performance-§12` argument — but its body is one
`visibilityAllows()` call (a table read and up to three string compares) plus at most one
`Show`/`Hide`, and criteria (b) and (c) of the existing declined-wiring row are untouched. The
deviation row needs a sentence, not a re-decision. Called out explicitly in Theme B's doc work.

### Theme B — restore the invariant the perf deviation is built on, and say so in the record

**Covers:** `WHATGROUP-R-02`.

Two ratified rows in `docs/ARCHITECTURE.md`, plus `docs/performance.md`, plus the code comment at
`modules/Frame.lua:166-175`, all rest on one sentence: the cooldown ticker *cannot outlive the window
that armed it*. That sentence is the whole reason `LibKa0s-Perf-1.0` is vendored-but-not-wired here.
It is currently false on two paths. The right response is to **make the sentence true again** —
which is a three-line change — and then to correct the evidence, not to weaken the claim and not to
wire Perf. `performance-§12`'s criteria (b) and (c) are unaffected by this defect and the row already
argues them; re-litigating the deviation because its supporting detail slipped would be the wrong
lesson.

**Alternative considered.** *Arm the ticker unconditionally and cancel it in more places.* Rejected:
more cancel sites is more surface for the same class of miss. Arming only when the frame is actually
on screen is one condition in one place, and it reads as the invariant it protects.

### Theme C — stop hand-copying what the library publishes, and pin the list that isn't pinned

**Covers:** `WHATGROUP-R-04`, `WHATGROUP-R-05`, `WHATGROUP-R-11`, `WHATGROUP-R-12`.

Four instances of the same failure mode: a value or a list that exists authoritatively somewhere
else, restated by hand where the restatement can drift with no error. `settings/OptionsSetup.lua`
already argues this position better than this document can, and refuses to copy `MASTER_GROUP` into
its degraded stub for precisely this reason — the live path just didn't get the memo. The suite list
is the same shape at the harness level, and `testing-§9` names two reference implementations to copy
rather than invent.

**Alternative considered.** *Auto-discover suites from the directory* — permitted by `testing-§9`
("a runner that auto-discovers its suites satisfies this by construction"). Rejected here because
`tests/run.lua:56` documents the order as load-order-sensitive and the ordering is deliberate;
auto-discovery would sort alphabetically and change it. The two-direction pin keeps the explicit
order and closes the hole.

### Theme D — close the small correctness and hygiene gaps

**Covers:** `WHATGROUP-R-03`, `WHATGROUP-R-06`, `WHATGROUP-R-07`, `WHATGROUP-R-09`,
`WHATGROUP-R-10`, `WHATGROUP-R-14`.

Independent, small, mostly one-file changes with no shared surface. Grouped only for scheduling.

### Theme E — resync the record

**Covers:** `WHATGROUP-R-08`, `WHATGROUP-R-13`, plus the doc follow-on from Themes A and B.

---

## LLD — change set

### C-01 — combat-transition visibility (`WHATGROUP-R-01`)

**Files:** `modules/Frame.lua`, `core/WhatGroup.lua`, `docs/frame.md`, `tests/test_frame.lua`.

`modules/Frame.lua:148-151`, before → after:

```lua
-- before
function WhatGroup:ApplyFrameVisibility()
    if not f then return end
    if not visibilityAllows() then f:Hide() end
end

-- after
function WhatGroup:ApplyFrameVisibility()
    if not f then return end
    if not visibilityAllows() then return f:Hide() end
    -- Symmetric now, and gated on there being something to show: a "No data" popup
    -- appearing the moment the player pulls is worse than no popup at all.
    if WhatGroup.pendingInfo and not f:IsShown() then
        f:Show()
        f:Raise()
    end
end
```

`core/WhatGroup.lua`, in `OnEnable` beside the two existing registrations:

```lua
self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChanged")
self:RegisterEvent("PLAYER_REGEN_ENABLED",  "OnCombatStateChanged")
```

with a handler that is a single `self:ApplyFrameVisibility()` guarded on the method existing
(`modules/Frame.lua` loads after `core/WhatGroup.lua` but the handler runs at event time, so the
guard is belt-and-braces, matching the style at `settings/Schema.lua:261`).

**Risk.** `PLAYER_REGEN_DISABLED` fires while `InCombatLockdown()` may still read `false` — a known
client quirk, and one this collection has already been bitten by
(`AbsorbTracker/modules/Display.lua:245` carries the comment). `visibilityAllows()` reads
`InCombatLockdown()` directly, so under `inCombat` the first fire could evaluate stale. Mitigation:
do the `Show`/`Hide` decision from the event *name* rather than from `InCombatLockdown()` when the
handler was reached by an event — pass the event through and let `visibilityAllows(inCombat)` take
an optional override. Pin it with a case that fires `PLAYER_REGEN_DISABLED` with `mock.combat` still
`false`.

**Standards conformance.** `events-frames-taint` — events registered in `OnEnable`, never
`OnInitialize`; no unit-filtered event is involved. `options-ui-§15` — the canonical row's
*behaviour* now matches its canonical label. No new deviation. The obvious alternative (a polling
timer) was rejected because `performance-§12` names a repeating ticker as the trigger that re-arms
the full Perf wiring MUST.

### C-02 — the ticker never arms against a hidden popup (`WHATGROUP-R-02`)

**Files:** `modules/Frame.lua`, `docs/ARCHITECTURE.md`, `docs/performance.md`,
`tests/test_frame.lua`.

In `applyTeleportNote` (`modules/Frame.lua:257-286`), guard the arm at `:275`:

```lua
-- before
    elseif remaining > 0 then
        renderNote(remaining)
        cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function() … end, 1)

-- after
    elseif remaining > 0 then
        renderNote(remaining)
        -- ARMED ONLY AGAINST A VISIBLE POPUP. OnHide fires on a TRANSITION, so a ticker armed
        -- against an already-hidden frame has no cancel site at all -- which is the one thing the
        -- performance-§12 deviation row says cannot happen. The note is still rendered above, so a
        -- later Show finds the right text and ConfigureTeleportButton re-arms from scratch.
        if f and f:IsShown() then
            cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function() … end, 1)
        end
```

`ShowFrame` then needs one line after `f:Show()` (`modules/Frame.lua:670`) so a popup that *does*
reach the screen still gets its ticker: re-run `ConfigureTeleportButton(fields.teleportBtn,
fields.teleportIcon, WhatGroup.pendingInfo)` — cheap, idempotent, and it already calls
`stopCooldownTicker` first. Alternatively arm from `f`'s `OnShow`; pick one and say which in the
comment.

Then correct the evidence: the second `performance-§12` row in `docs/ARCHITECTURE.md` gains a clause
naming the visible-only condition as *how* the invariant is enforced, and `docs/performance.md`'s
ticker row is regenerated. **The rows are not retired and Perf is not wired** — criteria (b) and (c)
stand unchanged.

**Risk.** If `ShowFrame`'s re-configure is forgotten, a live cooldown renders its note once and stops
counting down — visible, and caught by the existing `tests/test_frame.lua:376` case.

**Standards conformance.** `performance-§12` — the declined wiring stays declined on its unchanged
grounds (b) and (c); this change *restores* the factual basis of criterion (a)'s successor argument
rather than weakening it. `audit-review-history` — the deviation row is amended in place with its
re-check trigger intact, never deleted.

### C-03 — drop the `StaticPopupDialogs` global assignment (`WHATGROUP-R-03`)

**File:** `settings/Schema.lua:577`. Delete the line. The indexed write on `:578` is the
registration; the guard protected against a client with no `StaticPopupDialogs`, which does not
exist. Extend the comment block at `:566-575` by one sentence saying that assigning the *global*
is a stronger taint act than writing one of its keys, and that the lazy registration is the whole
mitigation.

**Standards conformance.** `events-frames-taint` — reduces the addon's taint surface; introduces
nothing. `anti-patterns` — no new global write.

### C-04 — read `MASTER_GROUP` from the instance (`WHATGROUP-R-04`)

**File:** `settings/Panel.lua:284-286`.

```lua
-- before
local AFTER_GROUP = {
    ["Master controls"] = MASTER_TAIL,

-- after
local AFTER_GROUP = {
    -- The library's published key, not a copy of it (options-ui-§8, anti-patterns #47). The
    -- literal fallback is for the degraded path, where settings/OptionsSetup.lua's stub
    -- deliberately publishes no layout data.
    [Helpers.MASTER_GROUP or "Master controls"] = MASTER_TAIL,
```

**Risk.** None functional. Note the table is built at file load, after
`settings/OptionsSetup.lua` has run, so `Helpers` is already the library instance.

**Standards conformance.** `options-ui-§8` and `anti-patterns` #47 — removes a host copy of library
data. The rejected alternative — copying `MASTER_GROUP` into the degraded stub so both sides read the
same constant — would violate `options-ui-§1`'s prohibition on carrying the library's data into the
stub, which is why the fallback is an inline literal at the one site rather than a stub member.

### C-05 — pin the suite list, both directions (`WHATGROUP-R-05`)

**Files:** `tests/run.lua` (publish the list through `Kit.expose`), `tests/test_harness.lua` (two
cases), `docs/test-cases.md` + README `[tests]` badge.

Copy the shape from the reference implementations `testing-§9` names — BankLedger
`tests/test_harness.lua:22-32` and PanelMaster `tests/test_harness.lua:19-32` — rather than inventing
one. Distinct failure messages per direction, as the rule requires.

**Regression pressure.** This adds **2** cases: 528 → 530. `docs/test-cases.md` and the README
`[tests]` badge must move **in the same commit** (`testing`), regenerated with
`lua5.1 tests/run.lua --list`. Never hand-edited.

**Standards conformance.** `testing-§9` — closes a stated MUST. `testing-§12` — both cases assert a
set relation and go red under a real mutation (add a file, remove a list entry), so neither is
vacuous.

### C-06 — `C_SpellBook.IsSpellKnown` rung in `Compat` (`WHATGROUP-R-06`)

**Files:** `core/Compat.lua:62-67`, `tests/test_compat.lua`.

```lua
function Compat.IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID) and true or false
    end
    if IsSpellKnown then
        return IsSpellKnown(spellID) and true or false
    end
    return false
end
```

**Risk.** Behaviour change if the two APIs disagree on a spell. Verify in-client
(`03_SMOKE_TESTS.md`, T-06) before merging — this is the one change in the set that a headless suite
cannot settle, and the finding is filed **unverified** for that reason.

**Standards conformance.** `compat` — `Compat` is the sole owner of variant spell APIs and the ladder
now matches its three siblings in the same file. No deviation introduced. **This change must not be
made blind**: if the in-client check shows `C_SpellBook.IsSpellKnown` absent or disagreeing, the
compliant outcome is to leave the shim and record why in a comment, not to guess.

### C-07 — key the capture queue by search-result id (`WHATGROUP-R-07`)

**File:** `core/WhatGroup.lua` — `OnApplyToGroup` (`:539-556`),
`LFG_LIST_APPLICATION_STATUS_UPDATED` (`:675-738`).

Replace the FIFO `captureQueue` with `capturesByResult[searchResultID] = captured`. On `"applied"`,
resolve the search-result id from the `appID` through the same
`C_LFGList.GetApplicationInfo` bridge `CaptureGroupInfoFromApplication` (`:341-365`) already uses,
including its `pcall`, its table-vs-multireturn tolerance and its fall-back-to-`appID` behaviour —
extract that resolution into a local so the two call sites share one implementation rather than
growing a second. Clear `pendingApplications[appID]` on the terminal statuses the handler currently
ignores.

**Risk.** This is the addon's core capture path and the change is not cosmetic.
`tests/test_capture.lua` has 428 lines over it already; add cases for two interleaved applies
resolving to the right captures, and for a declined application not leaking. `WipeCapture`
(`:638-656`) must wipe the new table — it currently `wipe(captureQueue)`s a table that would no
longer exist.

**Complexity note for the next release.** `LFG_LIST_APPLICATION_STATUS_UPDATED` is today's **max CCN
15** function (`WhatGroup@675-738@./core/WhatGroup.lua`, fresh `lizard` run, at the release gate's
cap of >15). Extracting the id resolution into a named local should move it **down**; the four
`elseif` branches of the source-preference ladder at `:706-713` are the bulk of the count. Confirm
by the next release's regeneration — do **not** run `lizard` into the repo as part of this work.

**Standards conformance.** `architecture` — the capture pipeline stays inside `core/WhatGroup.lua`
with no new module boundary. `compat` — the LFG API access stays behind `NS.Compat` /
`CaptureGroupInfoFromApplication` and no new direct call is introduced.

### C-08 — `.pkgmeta` ignore list (`WHATGROUP-R-09`)

**File:** `.pkgmeta`. Add `media/screenshots`, `CLAUDE.md`, `DEPENDENCIES.md` under `ignore:`,
beside the existing logo entries and under the same comment. Keep `README.md` and `LICENSE`.

**Standards conformance.** `packaging` — vendored libs stay, no `externals:` block appears, the
ignore list grows only with dev-only and client-unloadable content.

### C-09 — broaden the private-art case (`WHATGROUP-R-10`)

**File:** `tests/test_mediasetup.lua:147-155`. Replace the single-path check with a scan of `media/`
for any `.ttf`/`.otf` and for any filename matching the library's `ICONS` catalog keys. Keep
`media/logos/` and `media/screenshots/` explicitly allowed. Pass count unchanged (one case, wider
assertion), so no inventory move.

**Standards conformance.** `testing-§12` — the case gains falsifiability rather than losing it;
add the `-- red under:` note naming the mutation (drop any `.ttf` into `media/`).

### C-10 — assert the L-trap sweep actually read each seam file (`WHATGROUP-R-11`)

**File:** `tests/test_libka0s.lua:803-811`. Add `assertTrue(src ~= nil, "seam file missing: " ..
path)` before the existing `assertNil`, and derive `SEAM_FILES` from the TOC-derived load list
filtered to `*Setup.lua` plus `settings/Slash.lua`, rather than the hand-written list at `:23-28`.
Pass count unchanged.

**Standards conformance.** `testing-§9` — one more hand-maintained list derived rather than restated.

### C-11 — pass `addonName` to the composer (`WHATGROUP-R-12`)

**File:** `settings/Panel.lua:207` — `addonName = addonName,`. One line.

### C-12 — read `autoShow` at fire time (`WHATGROUP-R-14`)

**File:** `core/WhatGroup.lua:603-606` / `:627`. Move the `autoShow` read inside the scheduled
callback, beside the existing `self.pendingInfo ~= capturedInfo` identity check. `delay` stays where
it is — it is the timer's argument and must be read at schedule time.

### C-13 — resync the record (`WHATGROUP-R-08`, `WHATGROUP-R-13`, doc follow-on)

**Files:** `docs/automated-tests/RESULTS.md` (`## Test suite` prose only — never a recorded row and
never a recorded number), `docs/frame.md` → *Visibility*, `docs/settings-panel.md:344`,
`README.md:75`, `docs/ARCHITECTURE.md` (the `performance-§12` row amendment from C-02), and a
working-tree re-checkout for the six line-ending stragglers.

The `RESULTS.md` prose should be re-pointed as part of the **next recorded run**
(`/wow-addon:automated-tests`), not hand-written now — that keeps the file's single-path trend line
honest.

**Standards conformance.** `automated-tests` — recorded rows and `manifest.json` values are never
hand-edited; only the narrative moves. `line-endings-§2` — the remediation is a working-tree
re-checkout, because `git add --renormalize .` fixes the index and not the working tree.

---

## Changes deliberately **not** proposed

- **Wiring `LibKa0s-Perf-1.0`.** `WHATGROUP-R-02` looks like a reason to. It is not:
  `performance-§12`'s criteria (b) and (c) are unchanged and the two ratified rows already argue
  them at length. The compliant response is C-02 plus a one-clause amendment to the row.
- **Anything under `libs/` or `tests/_kit/`.** No defect was found there; the payload is
  byte-identical to `../LibKa0s` v1.25.0.
- **Editing or deleting a test to move a number.** No suite is red.
- **Routing the schema `label`/`tooltip` strings through `NS.L`.** The partial-routing deviation is
  ratified in `docs/ARCHITECTURE.md` with a re-check trigger (the first non-English locale file)
  that has not fired.
- **Adding a title-bar close mark to the popup.** The footer-`Close`-without-a-mark decision is a
  ratified `standalone-windows-§33` deviation, decided on a screenshot, with a live re-check trigger.
