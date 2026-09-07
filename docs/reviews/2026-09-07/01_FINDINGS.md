# WhatGroup — Review Findings (2026-09-07)

**Verdict: minor issues.** Nothing blocking ships today. One shipped settings control
(`General visibility`) does not do what its own README and docs promise, and a ratified
`performance-§12` deviation rests on an invariant the code breaks on two paths. Everything else is
convention drift, latent coupling and test-shape nits. This is one of the most carefully reasoned
repos in the collection — the great majority of what looks odd on first read is already argued in a
comment or ratified in `docs/ARCHITECTURE.md`, and this review checked before filing.

Standards cross-check: **performed**. Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**, fetched
from `standards/STANDARDS.md` and every section file its Sections list links.

---

## Measurement run (Step 0 — what was measured today)

| Suite | Command (repo root) | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — 0 warnings / 0 errors in 16 files |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — 528 passed, 0 failed, 0 skipped, 528 total |
| Test-case inventory | `lua5.1 tests/run.lua --list` → scratch | **pass** — 609 lines; **byte-identical** to committed `docs/test-cases.md` (no drift) |
| Offline perf runner | `lua5.1 tests/perf.lua` | **skipped** — `tests/perf.lua` does not exist. Not a gap: the absence is a ratified `performance-§12` deviation (`docs/ARCHITECTURE.md` → Documented deviations, two rows) |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → scratch | **pass** — 0 warnings, 1004 functions, 7047 NLOC, avg CCN 1.8; **max CCN 15** at `WhatGroup@675-738@./core/WhatGroup.lua` (`LFG_LIST_APPLICATION_STATUS_UPDATED`) |
| `make test` | — | **n/a** — no `Makefile` at the repo root |
| Vendor sync | `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` and `diff -r tests/_kit/ ../LibKa0s/testkit/` | **pass** — sibling checkout present; every file identical once CR is stripped (the working tree is CRLF per `.gitattributes`, the source repo LF). The suite's own two gate cases also passed rather than skipped |

Scope of the counts above: `luacheck .` and `lizard` covered the whole repo with `libs/` and
`tests/_kit/` excluded by config/flag; the test run covered the 17 suites declared in
`tests/run.lua:59-77`.

### Committed artifacts vs. today's run

- **`docs/test-cases.md`** — agrees exactly. No action.
- **`docs/performance.md`** — still accurate. Its `RegisterEvent` / `OnUpdate` / `C_Timer` sweep
  matches the tree, and the one repeating timer it names (`modules/Frame.lua:275`) is still the only
  one. See `WHATGROUP-R-02` for a claim *inside* it that the code no longer supports.
- **`docs/automated-tests/RESULTS.md`** — its newest row (`20260825-103505`, git
  `28c09168`, stamped `2026-08-25T10:35:05+05:30`) records **485** tests, 6377 NLOC, 906 functions.
  Today: **528**, 7047, 1004. That is ordinary staleness of a frozen release-checkpoint record and
  is **not** a finding. What *is* a finding is that the file's own `## Test suite` prose cites an
  even older run — `WHATGROUP-R-08`.
- Max CCN has **not** drifted: 15 today, 15 in the newest bundle's `manifest.json`. The watch list
  is empty in both.

**Nothing in this block required the game client.** In-client checks are in `03_SMOKE_TESTS.md`.

---

## High

### WHATGROUP-R-01 — `General visibility` is never re-evaluated on a combat transition `[ux]` `[design]`

**Where:** `modules/Frame.lua:148-151` (`ApplyFrameVisibility`), `modules/Frame.lua:665-668`
(the show-side gate), `settings/Panel.lua:246` (its only caller).

**Problem.** `visibility` is consulted at exactly two moments: inside `ShowFrame`, and from the
dropdown's own `onChange`. Nothing registers `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, and
`ApplyFrameVisibility` can only ever **hide** — `if not visibilityAllows() then f:Hide() end`.

**Impact.** `Only in combat` is close to inert. The join notify fires out of combat, so the popup is
built, populated, and left off screen (this is deliberate and documented); combat then starts and
nothing calls `ShowFrame` again, so it never appears. The only way to see the popup under that
setting is to type `/wg show` while already fighting. The mirror value has the mirror defect: a
popup opened under `Only out of combat` stays on screen when combat begins. Both contradict
`README.md:75` ("decides when the popup is allowed on screen at all") and
`docs/frame.md` → *Visibility*, neither of which mentions that the gate is evaluated only at call
time. The sibling that owns the same canonical `options-ui-§15` row —
`AbsorbTracker/modules/Display.lua:251` — drives its `visibilityAllows()` off
`PLAYER_REGEN_DISABLED`/`ENABLED`, so this addon is the outlier rather than the pattern.

**Reachability:** Any player who picks *Only in combat* or *Only out of combat* from the Master
controls dropdown — a shipped, documented control reachable from the settings panel on a default
install. No developer verb, no hand-edited SavedVariable.

**Coverage.** `tests/test_frame.lua:817` and `:832` pin the build/show split and are correct as far
as they go; **no case drives a combat transition with the popup already built**, which is why the
gap survived the revamp. That absence is part of this finding.

**Fix direction.** Register the two regen events (`OnEnable`, per `events-frames-taint`), and make
`ApplyFrameVisibility` symmetric — hide when the gate closes, and `f:Show()` when it opens *and*
there is a `pendingInfo` worth showing. The show side must stay behind the existing
`InCombatLockdown` reasoning for anything that moves the secure child; a bare `Show`/`Hide` on the
popup is already treated as unprotected here (`modules/Frame.lua:150`), so no new combat exposure.

---

## Medium

### WHATGROUP-R-02 — the cooldown ticker can outlive the window that armed it, on two paths `[perf]` `[design]`

**Where:** `modules/Frame.lua:257-286` (`applyTeleportNote`), armed at `:275`; stopped from
`modules/Frame.lua:351` (`f:SetScript("OnHide", stopCooldownTicker)`).

**Problem.** `OnHide` only fires on a *transition* from shown to hidden. Two paths arm the 1 Hz
ticker against a popup that is already hidden and stays hidden, so no exit path ever cancels it:

1. `ShowFrame` calls `PopulateFields()` at `modules/Frame.lua:664` — which reaches
   `ConfigureTeleportButton` and arms the ticker — **before** the visibility gate at
   `modules/Frame.lua:665` returns without showing. Under `inCombat`/`outOfCombat` (see
   `WHATGROUP-R-01`) that is the normal path.
2. `deferTeleportUntilCombatEnds` (`modules/Frame.lua:315-330`) replays
   `ConfigureTeleportButton` on `PLAYER_REGEN_ENABLED`. If the player closed the popup during the
   wait, the replay arms a ticker on a hidden frame.

**Impact.** One `C_Spell.GetSpellCooldown` and one `SetText` per second against an invisible
FontString, until the cooldown reaches zero — up to the full teleport cooldown. The runtime cost is
small. What makes this worth filing is that the *ratified* `performance-§12` deviation row in
`docs/ARCHITECTURE.md` — the argument for not wiring `LibKa0s-Perf-1.0` at all — rests on the claim
that the ticker "cannot outlive the window that armed it … cancelled from the popup's `OnHide`,
from the top of every `ConfigureTeleportButton` run, and by the tick that sees the cooldown reach
zero". The same sentence is in the code comment at `modules/Frame.lua:166-175` and in
`docs/performance.md`. On these two paths it is false, and that row's own re-check trigger (2) —
*"any repeating work starts running with the popup closed"* — has therefore fired.

**Reachability:** Path 2 is a default profile: open the popup, enter combat, close it, leave
combat. Path 1 needs the non-default visibility values. Neither needs a developer verb.

**Fix direction.** Gate the arming on the frame actually being shown, or cancel the ticker on the
same `return` the visibility gate takes and on the deferred replay when `f:IsShown()` is false.
Then re-state the invariant in the deviation row rather than deleting it — the row stands, its
evidence needs one clause. Do **not** answer this by wiring Perf: `performance-§12`'s criteria (b)
and (c) are unchanged and the row already argues them.

**Coverage gap.** `tests/test_frame.lua:391` ("closing the popup cancels the ticker") and `:403`
("re-opening arms exactly one ticker") both start from a *shown* popup. Neither shape above is
exercised.

### WHATGROUP-R-03 — the reset popup registration assigns the Blizzard global, not just a key `[taint]`

**Where:** `settings/Schema.lua:577` — `StaticPopupDialogs = StaticPopupDialogs or {}`.

**Problem.** The surrounding comment (`settings/Schema.lua:566-575`) correctly explains that writing
into `StaticPopupDialogs` at file load leaked taint into GameMenu's button closures, and defers
registration to first use because of it. The line immediately after that comment then assigns the
**global itself** — a strictly stronger taint act than the indexed write on the next line, because
it marks the global variable rather than one field of the table Blizzard's `StaticPopup_Show`
reads. The guard buys nothing: `StaticPopupDialogs` is present in every retail client, so the `or {}`
branch is dead, and `Settings.EnsureResetPopup` is already lazy.

**Impact.** A taint source added for no behavioural gain, on a path the player reaches deliberately.
Whether it produces a visible `ADDON_ACTION_FORBIDDEN` depends on what Blizzard code touches the
global afterwards; the point is that it is gratuitous.

**Reachability:** Any player who clicks **Defaults** on the General page, clicks **Reset all
settings** in the Master controls tab, or types `/wg resetall` — three documented, UI-reachable
routes, all through `Settings.EnsureResetPopup`.

**Fix direction.** Delete the assignment; keep `StaticPopupDialogs["WHATGROUP_RESET_ALL"] = { … }`.
No sibling in the collection carries this line (checked across the other eight), so it is local.

### WHATGROUP-R-04 — the tab-tail hook key hardcodes a value the library publishes `[design]`

**Where:** `settings/Panel.lua:285` — `["Master controls"] = MASTER_TAIL`.
Published by the library at `libs/LibKa0s/OptionsCompose.lua:50` (`local MASTER_GROUP = "Master
controls"`) and exported at `:189` (`O.MASTER_GROUP = MASTER_GROUP`).

**Problem.** `RenderTabbedSchema` fires `afterGroup` hooks keyed by the row's `group`, and the
composer stamps `MASTER_GROUP` onto the rows it emits. This file keys its hook off a hand-typed copy
of that string instead of `Helpers.MASTER_GROUP`. This repo's own `settings/OptionsSetup.lua:104-109`
argues at length that `MASTER_GROUP` is *the library's published data* and refuses to copy it into
the degraded stub for exactly this reason — the host copy is the copy that goes stale
(`options-ui-§8`, `anti-patterns` #47). The one place it *is* copied is the live path.

**Impact.** The day the library renames the group, the Master controls tab's closing
**Reset position / Reset all settings** button pair silently stops rendering. No error, no lint
warning; `tests/test_panel.lua:347` would go red only if it does not hardcode the same literal.

**Reachability:** Nobody today — the two strings agree in the vendored payload. Latent, and it
breaks silently when it breaks, which is why it is filed rather than shrugged at.

**Fix direction.** `[Helpers.MASTER_GROUP or "Master controls"] = MASTER_TAIL` — the fallback keeps
the degraded path working, where the stub deliberately does not publish the constant.

### WHATGROUP-R-05 — the runner's suite list is not pinned in either direction `[tests]`

**Where:** `tests/run.lua:59-77` declares 17 suites; `tests/test_harness.lua` pins the TOC-derived
addon list (`:27`), that every derived path exists (`:38`), that no `libs/` path leaked (`:44`), the
explicit LibKa0s list against the XML (`:51`), and the load ordering (`:73`) — but nothing pins the
**suite list**.

**Rule:** `testing-§9` — *"MUST pin the suite list … in both directions, with distinct messages per
direction"*, naming BankLedger (`tests/test_harness.lua:22-32`) and PanelMaster
(`tests/test_harness.lua:19-32`) as the reference implementations to copy.

**Impact.** Both failure modes are silent by construction. A new `tests/test_*.lua` that is written,
committed and never added to the list simply never runs, and the gate stays green with a
confidently-wrong pass count. A renamed suite is reported as a skip rather than a failure, so its
cases quietly stop contributing.

**Reachability:** Only the test harness — no shipped behaviour. Graded Medium on that basis, not
higher; but it is the finding most likely to hide the *next* one.

**Fix direction.** Two cases in `tests/test_harness.lua`, copied from the named reference
implementation: every `tests/test_*.lua` on disk appears in the declared list, and every declared
path exists on disk. Publish the list through `Kit.expose` alongside `loadAddon` as those repos do.

### WHATGROUP-R-06 — `Compat.IsSpellKnown` is the one spell shim with no modern-namespace rung `[deprecated-api]`

**Where:** `core/Compat.lua:62-67`.

**Problem.** `Compat` exists precisely so the version-variant spell APIs live in one file, and its
three siblings all try the modern namespace first and fall back:
`Compat.GetSpellName` (`:24`, `C_Spell.GetSpellName` → `GetSpellInfo`), `GetSpellTexture` (`:40`),
`GetSpellLink` (`:52`). `IsSpellKnown` goes straight to the bare global with no
`C_SpellBook.IsSpellKnown` rung above it.

**Impact.** The failure is silent and total in the direction that matters: `Compat.IsSpellKnown`
returns `false` when the API is unavailable (`:66`), so if the global is ever removed every teleport
in the addon renders as "not learned" — desaturated icon, `Teleport spell not learned` note, macro
never armed — with no Lua error and no debug line saying why.

**Verification status: unverified.** I did not confirm against a live 12.0.7 client whether the
global `IsSpellKnown` is still present or is now only a compatibility alias for
`C_SpellBook.IsSpellKnown`. The finding stands on the **asymmetry within `Compat` itself**, which is
observable from the source and is a `compat` concern regardless of the current client's answer.

**Reachability:** Nobody on 12.0.7 today, as far as this review can establish. Filed as a
currency/consistency defect in the module whose entire job is to absorb exactly this.

**Fix direction.** Add the `C_SpellBook.IsSpellKnown` rung above the global, matching the ladder its
three siblings already use, and keep the `false` default. One `tests/test_compat.lua` case per rung,
as that suite already does for the others.

### WHATGROUP-R-07 — the capture→application pairing is positional and can mismatch `[design]`

**Where:** `core/WhatGroup.lua:677-681` (`table.remove(captureQueue, 1)` on `"applied"`),
queued at `:549` (`table.insert(captureQueue, captured)` in `OnApplyToGroup`).

**Problem.** `OnApplyToGroup` pushes one capture per `C_LFGList.ApplyToGroup` call, and the
`"applied"` status event pops the **head** of that FIFO and binds it to whatever `appID` arrived.
Nothing correlates the two — not the `searchResultID` the capture was taken from, not the `appID`.
Two applications in flight whose `"applied"` events arrive in a different order than the applies
were issued pair each capture with the other's `appID`.

**Impact.** The mismatch is largely masked downstream: `"inviteaccepted"` re-fetches through
`CaptureGroupInfoFromApplication(appID)` (`:704`) and prefers that fresh capture whenever it carries
a `mapID` (`:706-713`). The queued capture only wins when the fresh fetch has no `mapID` — at which
point the popup and the chat summary describe the wrong group. Separately, `pendingApplications`
entries for applications that end in `"declined"` are never removed until the next
`"inviteaccepted"` or a group-leave (`:677-684` handles only three statuses), so the table grows for the
life of a session spent browsing.

**Reachability:** A player applying to several groups in quick succession — routine Premade Group
Finder use — *and* an invite accepted where the fresh re-fetch yields no `mapID`. Two conditions,
both plausible, neither requiring anything unusual.

**Fix direction.** Key the queue by `searchResultID` rather than treating it as a FIFO: stash
`captures[searchResultID] = captured` in `OnApplyToGroup`, and resolve the id on `"applied"` through
the same `C_LFGList.GetApplicationInfo(appID)` bridge `CaptureGroupInfoFromApplication` already uses
and already degrades gracefully around. Clear `pendingApplications[appID]` on `"declined"` /
`"cancelled"` / `"failed"` in the same pass.

---

## Low

### WHATGROUP-R-08 — `RESULTS.md`'s prose cites an older run than its own newest row `[docs]`

`docs/automated-tests/RESULTS.md` → `## Test suite` reads *"Current state as of `20260807-121935`:
**462 cases**"* and points at that bundle's `test-cases.md` as "the authority". The newest row in the
table directly above is `20260825-103505` at **485**, and today's run is **528**. A reader who takes
the prose at its word is three runs and 66 cases behind. The table itself is correct and frozen; only
the narrative is stale. **Reachability:** a maintainer reading the trend line; no runtime effect.
**Fix:** re-point the paragraph at the newest row as part of the next recorded run. Never hand-edit a
recorded number — the paragraph is prose, the rows are not.

### WHATGROUP-R-09 — `media/screenshots/` ships to every player `[packaging]`

`.pkgmeta:18-19` ignores `media/logos/*.png` and `media/logos/*.jpg`, with the reasoning at `:15-17`: *"WoW cannot
read .png or .jpg at all … shipping them would add megabytes to every download for files the client
physically cannot use."* `media/screenshots/` is 880 KB of exactly those file types, for exactly that
reason, and is **not** ignored. `CLAUDE.md` and `DEPENDENCIES.md` — both dev-only — also ship.
**Reachability:** every player who downloads the addon; 880 KB, not a correctness issue.
**Fix:** add `media/screenshots`, `CLAUDE.md` and `DEPENDENCIES.md` to the `ignore:` list. Keep
`README.md` and `LICENSE`.

### WHATGROUP-R-10 — the "no private copy of the shared art" case checks one filename `[tests]`

`tests/test_mediasetup.lua:147-155` is titled *"this addon ships no private copy of the shared art
(anti-patterns #63)"* and asserts on exactly one literal path,
`media/fonts/JetBrainsMono-Regular.ttf`. A private copy under any other name — a Bold face, a second
family, a duplicated `close.tga` under `media/icons/` — passes green. The assertion is narrower than
its title by a wide margin, which is the shape that reads as coverage while providing little.
**Reachability:** the test inventory only. **Fix:** scan `media/` for any `.ttf`/`.otf` and for any
filename matching the library's `ICONS` catalog, and assert the set is empty; keep the existing path
as one member of it.

### WHATGROUP-R-11 — the L-trap sweep skips a seam file it cannot read, silently `[tests]`

`tests/test_libka0s.lua:803-811` loops `SEAM_FILES` and wraps the assertion in `if src then` — so a
renamed or moved seam file narrows the sweep with no red. `SEAM_FILES` itself
(`tests/test_libka0s.lua:23-28`) is hand-maintained and lists four files; `core/MediaSetup.lua` and
`core/EnvSetup.lua` are LibKa0s setup files too and are absent from it (correctly today — neither
passes a descriptor — but nothing pins that). The matcher itself is properly falsified at `:787-801`,
which is exemplary and is why this is Low rather than higher. **Reachability:** the test inventory
only. **Fix:** `assertTrue(src ~= nil, "seam file missing: " .. path)` before the `assertNil`, and
derive `SEAM_FILES` from a glob of `*Setup.lua` plus `settings/Slash.lua` rather than listing it.

### WHATGROUP-R-12 — `addonName` passed to the composer as a literal `[naming]`

`settings/Panel.lua:207` — `addonName = "WhatGroup"` — while the file's own first vararg
(`settings/Panel.lua:14`, `local addonName, NS = ...`) holds the folder name. `core/EnvSetup.lua`'s
header calls this out by name as *"the spelling that goes stale the day the folder is renamed and
answers nil without raising a thing"*, and `core/MediaSetup.lua:66` and `core/DebugLogSetup.lua:133`
both do it correctly. **Reachability:** nobody, until a folder rename. **Fix:** pass `addonName`.

### WHATGROUP-R-13 — six tracked paths disagree with the `.gitattributes` CRLF pin `[structure]`

`.gitattributes:26` pins `* text=auto eol=crlf` (correct for a client-bound repo, `line-endings-§2`),
with the `*.sh text eol=lf` carve-out at `:34` and the binary block at `:43-65` — the file body is
right. The working tree disagrees on six paths: `.pkgmeta`, `locales/enUS.lua`,
`tests/test_debuglog.lua`, `tests/test_mediasetup.lua` and `docs/revendor/2026-08-25/05_SUMMARY.md`
are `w/lf`, and `docs/revendor/2026-08-25/01_DELTA.md` is `w/mixed`. Measured with
`git ls-files --eol`. **This is a review observation only** — the authoritative check and its
rolled-up straggler count belong to `/wow-addon:standards-audit`. **Reachability:** a contributor
diffing those files; no runtime effect. **Fix:** the working tree needs a re-checkout, not just
`git add --renormalize .`, which fixes the index only (`line-endings-§2`).

### WHATGROUP-R-14 — `autoShow` is snapshotted at schedule time, `delay` is not `[logic]`

`core/WhatGroup.lua:603-606` reads both `notify.delay` and `frame.autoShow` when the timer is
*scheduled*, then the callback at `:627` uses the captured `autoShow`. `delay` has to be read then —
it is the timer's argument. `autoShow` is a display decision that only matters when the callback
fires, and the callback already re-reads `self.pendingInfo` for exactly that reason. A player who
unticks **Open Automatically** during the delay window still gets a popup.
**Reachability:** requires `notify.delay > 0` (the shipped default is `0`, `defaults/Profile.lua:43`)
*and* a toggle inside that window. Marginal. **Fix:** read `frame.autoShow` inside the callback,
beside the existing `pendingInfo` identity check.

---

## Upstream findings

**None.** Nothing in this review lands under `libs/` or `tests/_kit/`. The vendored payload is
byte-identical to `../LibKa0s` at the tag `CLAUDE.md` claims (v1.25.0), and the two defects that
*touch* the library seam — `WHATGROUP-R-04` and `WHATGROUP-R-06` — are both in this addon's own
files and are fixed here.
