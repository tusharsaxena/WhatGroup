# 01 — Findings (review of 2026-08-05)

**Verdict: minor issues.** The addon loads, lints clean, and its 422-case suite is green. One
functional defect is real and user-visible — the master switch does not actually stop the addon —
and the test that claims to cover it passes for a reason unrelated to the switch. Everything else
is design-level or cosmetic. Nothing here blocks a release once F-001/F-002 land.

Standards cross-check: **performed**, against the Ka0s WoW Addon Standard **v2.21.0 (2026-08-04)**.
The network fetch of `raw.githubusercontent.com` did not return inside the timeout; the standard was
read instead from the local read-only clone at
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/` (index + all 25 section
files under `standards/standards/`), which is the same text.

---

## Measurement run (Step 0 — everything below was executed today, from the repo root)

| Suite | Command | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — 0 warnings / 0 errors in 14 files, exit 0 |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — **422 passed, 0 failed, 422 total**, exit 0 |
| Test-case inventory | `lua5.1 tests/run.lua --list > <scratch>/test-cases.md` | **pass** — 491 lines; `diff` vs committed `docs/test-cases.md` is **empty** |
| Offline perf runner | — | **skipped (not present)** — this addon ships no `tests/perf.lua`, no `docs/performance.md` and no `docs/perf-runs/`; it wires no `LibKa0s-Perf-1.0` bucket and brackets no path. No perf claim in this document is measured. |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **pass** — 808 functions, 5573 NLOC, avg CCN 1.7, **0 functions above CCN 15**. Highest single function: `WhatGroup@533-573@./core/WhatGroup.lua`, CCN 13. |
| `make test` | — | **skipped (no Makefile)** |
| Vendor sync | `diff -r libs/LibKa0s/ ../LibKa0s/…` | **skipped (out of scope)** — this run is constrained to a single repository, so no sibling library repo was read. Drift between `libs/LibKa0s/` and its source repo is therefore **unverified**, not clean (anti-patterns #45). Same for `tests/_kit/` vs `../LibKa0s/testkit/`. |

**Committed records vs. today's run:** no disagreement. `docs/test-cases.md` is byte-identical to a
fresh `--list`; `docs/automated-tests/RESULTS.md` and `20260804-233335/manifest.json` report
422/422, lint 0/0 over 14 files, maxCcn 13, 0 CCN warnings, `perf: skip` — all reproduced exactly.
The newest bundle's stamp (`git.sha 2111c54…`, `dirty: true`, branch `feat/fix-ccn`) is two
**docs-only** commits behind HEAD (`b31c90d`), so it is *slightly stale in provenance and exactly
current in measurement*. No finding below rests on a stale number.

**Not run here (needs a game client):** taint repros, real-combat behavior, locale rendering,
`/reload` migration. Those are in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — The master switch does not stop the addon; a disabled WhatGroup still notifies and opens the popup `[design]` `[ux]`

**Where:** `core/WhatGroup.lua:619-671` (`LFG_LIST_APPLICATION_STATUS_UPDATED`, the
`"inviteaccepted"` branch) — contrast the gate at `core/WhatGroup.lua:488`.

**Problem:** `OnApplyToGroup` early-returns when `db.profile.enabled` is false, but the
`inviteaccepted` branch calls `self:CaptureGroupInfoFromApplication(appID)` (`:639`)
**unconditionally**. That path re-fetches from the LFG API, sets `self.pendingInfo` (`:650`) and
calls `_TryFireJoinNotify` (`:671`), none of which consult `enabled`. The apply-time gate only
suppresses the *queued* copy; it never suppresses the *fresh* one. `docs/capture-pipeline.md:42`
draws the gate on the apply branch alone, so the design doc shows the same gap.

**Impact:** a user who turns the addon off still gets the full chat summary and the popup on their
next Premade-Group join, contradicting the shipped promise in the Enable tooltip
(`settings/Schema.lua:92`: *"When off, WhatGroup ignores group applications entirely — no capture,
no notification, no popup"*) and the README. `Helpers.Set("enabled", false)` firing `WipeCapture`
(`settings/Schema.lua:104`) does not help: the wipe clears state that the `inviteaccepted` handler
then rebuilds from scratch.

**Measured:** reproduced headlessly against this tree. With `Helpers.Set("enabled", false)`, a live
`mock.searchResults[100]`, `inGroup = true`, and one
`LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")`, the addon set
`pendingInfo.title = "Real Group"`, fired 1 AceTimer, printed all seven notification lines
(`[WG] You have joined a group!` … `[Click here to view details]`) and created `WhatGroupFrame`.

**Fix direction:** gate the `inviteaccepted` branch on the same `db.profile.enabled` read the apply
branch uses, at the top of the handler rather than at each call site. Do **not** move the gate into
`CaptureGroupInfo` — `/wg test` and `/wg show` deliberately bypass the capture pipeline
(`core/WhatGroup.lua:486-487`) and a gate there would also need an exemption, which is how the two
paths drift apart.

### F-002 — The test that claims to cover the master switch passes for an unrelated reason `[tests]`

**Where:** `tests/test_capture.lua:63-76`, case *"capture: master switch off means nothing is
queued"* (inventory line `docs/test-cases.md:254`).

**Problem:** the case sets `enabled = false` (`:67`), then at `:71` sets
`mock.searchResults[100] = nil` — commented *"fresh fetch nil -> no data anywhere"* — before firing
`inviteaccepted`. Its `assertNil(addon.pendingInfo)` (`:75`) therefore holds because the search
result is gone, **not** because the switch is off. Delete the gate at `core/WhatGroup.lua:488`
entirely and this case still passes; that is testing-§12's "a test that cannot fail is worse than no
test", in its negative-assertion form. The companion case *"re-enabling the master switch resumes
capturing"* (`tests/test_capture.lua:261-275`) uses the same `searchResults[10] = nil` setup, so it
too proves less than its name.

**Impact:** F-001 is a defect on a path the inventory advertises as covered, which is why it
survived three audit cycles and two prior reviews. The sleeping case is the more valuable half of
this pair.

**Fix direction:** keep the search result **live** across the `inviteaccepted` fire so the only
thing that can suppress the capture is the switch, and add the missing
`-- red under:` comment naming the mutation (testing-§12). Never weaken an assertion to make a suite
green; here the assertion is fine and the *fixture* is what defeats it.

---

## Medium

### F-003 — `Helpers.Get` mutates the saved profile: the path resolver writes on a read `[design]`

**Where:** `settings/Schema.lua:206-220` (`Resolve`), reached from `Helpers.Get` at `:222-229`.

**Problem:** `Resolve` is shared by the read and the write path, and its parent walk
(`if type(parent[k]) ~= "table" then parent[k] = {} end`, `:216`) creates every missing intermediate
table **before it knows whether the caller intends to write**. A `Get` of an unmaterialized nested
path therefore leaves empty tables in `db.profile`, which AceDB then serializes into `WhatGroupDB`.

**Measured:** reproduced headlessly — `Helpers.Get("brandnew.deep.leaf")` returns `nil` and leaves
`db.profile.brandnew` and `db.profile.brandnew.deep` as live tables in the profile.

**Impact:** bounded today rather than harmless. The slash CLI cannot reach it (LibKa0s-Slash's
`CliGet`/`CliSet` reject an unknown path at `libs/LibKa0s/Slash.lua:522-523` before calling `get`),
so the reachable cases are schema paths whose parent is absent: immediately after
`RestoreAllDefaults`'s `wipe(WhatGroup.db.profile)` (`settings/Schema.lua:390`), on a hand-edited
SavedVariables file, and on any future schema row added under a new parent. Each accumulates keys
the user never set. The function's own header comment does not mention the write, so the next reader
will assume `Get` is pure.

**Fix direction:** give `Resolve` a create-if-missing flag, defaulted off, and have `Get` resolve
read-only (returning `nil` on a missing parent) while `RawSet` keeps the creating walk. This does
not touch the single-write-path invariant — `Helpers.Set` remains the sole orchestrated seam.

### F-004 — The popup re-implements `Labels.GetPlaystyleLabel` instead of calling it `[design]`

**Where:** `modules/Frame.lua:292-296`, duplicating `core/WhatGroup.lua:391-396`.

**Problem:** `PopulateFields` open-codes the exact playstyle resolution the shared helper already
performs — prefer `playstyleString`, else `Labels.PLAYSTYLE[generalPlaystyle]`, else `""` — and
reaches into `Labels.PLAYSTYLE` directly (`:294`) rather than through `Labels.GetPlaystyleLabel`.
Two lines above it, the same function *does* call the sibling helper `Labels.GetGroupTypeLabel`
(`:283`), so the file is inconsistent with itself. The comment at `core/WhatGroup.lua:356-358`
asserts the opposite of what the code does: *"Shared label namespace consumed by both
ShowNotification (chat) and WhatGroup_Frame.PopulateFields (popup). Single source of truth so a new
playstyle enum or group-type rule lands in one place."*

**Impact:** no user-visible bug today (the two implementations agree), but a new playstyle rule now
has to land in two places, and the comment actively tells the next author it only has to land in
one. That is the drift the shared namespace exists to prevent.

**Fix direction:** call `Labels.GetPlaystyleLabel(info)` and keep the em-dash placeholder branch
local to the popup, which is genuinely the popup's presentation choice.

### F-005 — The secure teleport button registers both click edges, so one click runs the macro twice `[design]`

**Where:** `modules/Frame.lua:145` (`teleportBtn:RegisterForClicks("AnyUp", "AnyDown")`), with the
macro wired at `:230-231`.

**Problem:** `SecureActionButtonTemplate` dispatches its action on **every** registered click event.
Registering both `AnyUp` and `AnyDown` on a button whose `type` is `macro` therefore attempts
`/cast <spell>` twice per physical press. The addon's own code documents the double invocation:
the `PreClick` handler at `:244-249` exists solely to *"gate on the down edge to emit exactly one
line per press"* — an explicit acknowledgment that the handler fires twice, which the secure action
beside it does too.

**Impact:** the second cast attempt is rejected by the client (already casting / spell in progress),
so the visible symptom is a spurious red error rather than a double teleport — but it is noise on a
button whose whole job is one press, and the pattern hides a real bug the day a non-idempotent
action is wired to the same button. Not reproducible headlessly (the mock has no
`RegisterForClicks` semantics); **verify in client** per `03_SMOKE_TESTS.md`.

**Fix direction:** register a single edge — `RegisterForClicks("AnyUp")` — and drop the `down`
condition in `PreClick`, which then fires exactly once by construction rather than by filtering.
Note that the write is a secure-frame configuration, so it stays inside `buildFrame`/the existing
`InCombatLockdown` queue (events-frames-taint-§2); this change does not add a new protected call
site.

---

## Low

### F-006 — Five locale rows have no call site, and the settings surface they name is hardcoded English `[locale]`

**Where:** `locales/enUS.lua:67-70` (`"Ka0s WhatGroup"`, `"General"`, `"Slash Commands"`,
`"Defaults"`) and `locales/enUS.lua:104` (`"cannot open settings during combat — Blizzard's
category-switch is protected"`).

**Problem:** none of the five keys is referenced by any `.lua` file in the addon. The strings they
name are passed as bare literals — `settings/OptionsSetup.lua:99` (`parentTitle = "Ka0s
WhatGroup"`), `settings/Panel.lua:176` (`Helpers.Section(ctx, "Slash Commands")`),
`settings/Panel.lua:220` (`CreatePanel("WhatGroupGeneralPanel", "General", …)`) — while the combat
notice is now composed inside LibKa0s-Options (options-ui-§2), so the addon no longer owns that
string at all. Every schema row's `label` and `tooltip` (`settings/Schema.lua:88-200`) is likewise
raw English.

**Impact:** a translator editing these five rows would see nothing change in game. The locale
module's own SCOPE note (`locales/enUS.lua:18-25`) does not claim the settings panel, so this is a
stale surface rather than a coverage gap — but the rows read as coverage.

**Fix direction:** delete the four dead panel keys and the retired combat-notice key rather than
routing the literals through `L`. Routing them would be the larger, riskier change (the panel/page
strings are also `pageKey`-adjacent identifiers the library matches on), and localization-§3 requires
only that `enUS.lua` ship — not that every internal label pass through it. If a translation is ever
wanted for the panel, that is one deliberate change covering `label`/`tooltip` too, not five orphan
rows.

### F-007 — The secure button's anchor offsets are computed from possibly-nil rect queries `[design]`

**Where:** `modules/Frame.lua:139-140`.

```lua
local btnX = (lblPort:GetLeft() - f:GetLeft()) + LABEL_WIDTH + 6
local btnY = lblPort:GetTop()  - f:GetTop()
```

**Problem:** these run inside `buildFrame`, on a frame that was explicitly hidden nine lines earlier
(`:51`) and has never been shown. `GetLeft`/`GetTop` return `nil` when a region's rect has not been
resolved; an arithmetic on `nil` raises, and the raise happens inside `ShowFrame` — so the popup
would never build and the failure would surface as a bare Lua error rather than a degraded popup.
The anchor chain here (`UIParent` → `f` → `content` → labels) is fully resolvable, so this is a
latent hazard rather than an observed failure. **Unverified** — the headless mock returns numbers
unconditionally, so no test in the 422 can distinguish the two cases.

**Fix direction:** guard the two subtractions and fall back to the constant offsets the comment
already describes as derivable, or force a layout resolution before querying. Keep the derived form
as the primary path — the comment at `:132-138` is right that hardcoded offsets are the worse
option.

### F-008 — `NS.Util.format` is published on both paths and called by nothing `[design]`

**Where:** `core/CoreSetup.lua:76-82` (fallback) and `:135` (library binding).

**Problem:** zero call sites anywhere in `core/`, `modules/`, `settings/`, `locales/`, `defaults/`
or `tests/`. The file argues for publishing it (`:73-75`: *"Nothing calls Format today, which is
exactly why its absence would go unnoticed"*), and the argument is sound for the **binding** at
`:135`. It is weaker for the 7-line hand-written fallback at `:76-82`, which no test exercises and
which will therefore be first executed, in a degraded install, by whichever caller is added later.

**Impact:** minimal — a small piece of untested code on a path only a broken install reaches.
Noted rather than urged.

**Fix direction:** either add one case that loads with `libs/LibKa0s/Core.lua` skipped (the loader
already supports `opts.skip`, `tests/loader.lua:62-64`) and asserts the fallback's output shape, or
drop the fallback and let the degraded `NS.Util.format` be `nil` — but not the middle state of
shipping an implementation nothing has ever run.

---

## Upstream — does NOT land in this repo

### F-U01 — `libs/LibKa0s/` carries British spellings in authored comments `[upstream]` `[locale]`

**Owning repo:** LibKa0s (the Ka0s-owned shared library vendored at `libs/LibKa0s/`).

**Where:** 29 occurrences across five files — `libs/LibKa0s/Core.lua:76-79,100,156` (`grey`,
`colour`, `colours`, `Synthesise`), `libs/LibKa0s/DebugLog.lua:180,230,242,253,304,306`
(`coloured`, `grey`, `colour`, `Coloured`), `libs/LibKa0s/Slash.lua:540` (`colour shape`),
`libs/LibKa0s/OptionsWidgets.lua` (5), `libs/LibKa0s/Perf.lua` (1).

**Problem:** anti-patterns #46 and localization-§5 name code comments explicitly as authored English
text that must use the US dialect, precisely so `grep -r color` finds every call site and the
collection sweeps with one pattern. No user-facing string is affected — the defect is confined to
comments — which is why it is Low severity but still real.

**Remediation — this is NOT a local edit.** Fix in the LibKa0s repo, bump the affected files'
LibStub minors, then re-vendor the whole `libs/LibKa0s/` folder into this addon (and every other
consumer) as its own commit. A patch applied here is reverted by the next whole-folder copy, and
the reversion would appear in this repo's history as a file copy with no traceable cause.

### F-U02 — Vendor drift between `libs/LibKa0s/` (and `tests/_kit/`) and their source repos is unverified `[upstream]`

**Problem:** the byte-identity check anti-patterns #45 and testing-§11 exist for — `diff -r
libs/LibKa0s/ ../LibKa0s/<ship folder>/` and `diff -r tests/_kit/ ../LibKa0s/testkit/` — was **not
run**, because this review was scoped to a single repository and may not read a sibling repo. Both
copies test green here, which is exactly the condition under which drift is invisible: each repo's
suite tests its own copy.

**Remediation:** run both `diff`s in an unconstrained checkout before the next release. Any
difference is resolved by re-vendoring the whole folder from the library repo — never by editing
either side.
