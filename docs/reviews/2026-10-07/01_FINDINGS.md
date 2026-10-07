# WhatGroup — review findings (2026-10-07)

**Verdict: minor issues, with one High.** Nothing blocks loading or corrupts data. One High is a
secret-value compare in the teleport-cooldown reader. In combat it can stop the join notice
part-way through, and it freezes the popup's countdown.

**Resolved scope:** the whole repository (`all`) at `57a08e9`, on branch
`feat/2026-10-07-review-audit-remediation` with a clean tree. Profile `wow`, kind `addon`. Vendored
`libs/` and `tests/_kit/` were read only where the addon's descriptors and stubs depend on them.

## Measurement run

All runs used the bounded runner `~/.claude/dev-copilot/bin/ka0s-bounded`, from the repo root. Output
went to a session scratch directory, and nothing was written into the repo.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 59 files | `ka0s-bounded luacheck .` |
| Headless suite | **pass**: 914 passed, 0 failed, 1 skipped, 915 total (exit 0). The skip is the kit's `diagnostics contract: an addon that opts out…` case, which does not apply: this addon keeps the default | `ka0s-bounded lua5.1 tests/run.lua` |
| `--list` inventory | **pass**: identical to the committed `docs/test-cases.md` (CR-normalized `diff` is empty) | `ka0s-bounded lua5.1 tests/run.lua --list` to scratch |
| Offline perf | **ran**: 8 scenarios, no assertion failure (exit 0) | `ka0s-bounded lua5.1 tests/perf.lua` |
| Complexity (sighted) | **pass**: 0 warnings, 1792 functions, 13412 NLOC, avg CCN 1.9, **max CCN 15** (`encode@336-366@./tests/perf.lua`). Kit revision 37, so the run is sighted, and the console line names no blind files | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | **not applicable**: there is no `Makefile` | — |
| Vendor sync | **pass**: `diff -r libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -r tests/_kit ../LibKa0s/testkit` are both empty. The sibling is at tag `v1.70.0` with a clean tree | `diff -r …` |
| Cross-addon (4 classes) | **pass, 4/4 clean**, run over all 11 addons from `ADDONS.md` and scoped to each addon's TOC-derived load list. (1) 22 slash roots, no duplicates, no raw `SLASH_*` (WhatGroup: `wg`, `whatgroup`). (2) One minors line: `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12`. (3) `diff -rq` against AbsorbTracker's 159-file `libs/LibKa0s` is empty for all 11. (4) `## Interface: 120100` is uniform. The LibKa0s tag moved from the agent brief's v1.56.0 baseline to v1.70.0, so the brief is stale; that is not drift | the four loops in the overlay's *cross-addon pass*, run from `GIT/` |

Line endings (an observation only; the audit owns this check): `.gitattributes` carries `* text=auto eol=crlf`
and the `*.sh` / `*.py` LF carve-outs. `git ls-files --eol` finds 0 tracked non-`.sh` text files with
LF in the working tree.

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md`: the newest bundle, `20260927-031637`, measured `62680d3`, which is
  50 commits behind HEAD. It records max CCN **13** over **1591** functions, against today's **15** over
  **1792**. The new maximum is `encode` in `tests/perf.lua`, which is ungated runner code at the ceiling,
  not over it. The record is stale, not non-compliant, and regenerating it belongs to release.
- `docs/performance.md:146-147`: today's run differs on two deterministic figures (see F-006).
- `docs/test-cases.md` and the README `Tests-914/914_passing` badge **agree** with the run. The badge
  counts passes and excludes the one skip.

**Standards cross-check:** the cross-check used Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The
index and 19 of its 27 section files were fetched from GitHub. The other 8 (`preview-mode`,
`public-api`, `savedvariables`, `slash-commands`, `standalone-windows`, `testing`, `toc-file`,
`versioning-git`) had not finished downloading when this review closed. For those, the local sibling
checkout `../WowAddonStandards` (`f472389`, the same v2.76.1 header) was read in their place.

---

## High

### F-001 — The teleport-cooldown reader compares values that can be secret in combat `[taint]`

- **Where:** `core/Compat.lua:109-112`
  `function Compat.GetSpellCooldownRemaining(spellID)` … `if start <= 0 or duration <= GCD_SECONDS then return 0 end`.
  It has two production callers:
  - The popup's cooldown ticker, `modules/Frame.lua:587-589`:
    `cooldownTimer = WhatGroup:ScheduleRepeatingTimer(function()` / `local left = NS.Compat.GetSpellCooldownRemaining(spellID)` / `if left > 0 then return renderNote(left) end`.
  - The chat summary's Teleport row, `core/WhatGroup.lua:828`:
    `elseif NS.Compat.GetSpellCooldownRemaining(spellID) > 0 then`.
- **Problem:** `start` and `duration` come from `LibKa0s-Compat-1.0`'s `GetSpellCooldown`. That
  library's contract says (`libs/LibKa0s/Compat.lua:232-233`):
  *"`startTime`, `duration` and `modRate` may be secret in combat … gate with IsSecret before any
  arithmetic."* The host compares them with `<=` and does arithmetic on them without a guard.
  `NS.Compat` has no `IsSecret` member to guard with. The addon already knows about the hazard:
  `modules/Diagnostics.lua:21` says *"Compat.GetSpellCooldownRemaining is not called here, because it
  subtracts."* The diagnostics report is protected, but the two production paths are not.
- **Impact:**
  - **Ticker:** a popup left open into combat raises a Lua error on the first tick. AceTimer reschedules
    a repeating timer only after its callback returns (`libs/AceTimer-3.0/AceTimer-3.0.lua:57-60`), so
    the ticker dies there. The countdown freezes until the popup is reopened, and
    `cooldownTimer` stays a stale non-nil handle.
  - **Join notice:** a join notice that fires in combat raises inside `ShowNotification`. The details
    link row is never printed. Because `ShowNotification` runs before `ShowFrame` in the same timer
    callback (`core/WhatGroup.lua:1026` `self:ShowNotification()` comes before `:1041`
    `self:ShowFrame()`), the auto-show popup and its combat defer never happen either.
  - **The guard runs even for a ready spell:** `start <= 0` is evaluated whenever `isEnabled` is true,
    which includes a ready spell.
- **Evidence:**
  - **Harness probe, run in scratch with no change to the repo:** the probe kept the real addon and the
    real library, and only replaced the mock's cooldown table with values that raise on comparison. The
    ticker tick raised `./core/Compat.lua:112: attempt to compare table with number`, and
    `ShowNotification()` raised the same error.
  - **Not verified in the client:** whether 12.1.0 marks *this player's teleport* cooldown secret has
    not been checked in game. The library contract above and KickCD's Compat (`core/Compat.lua:98-100`:
    *"startTime/duration/modRate may be "secret" — never compare or do arithmetic on them in tainted
    scope"*) both say these fields can be secret. The in-client confirmation is S-001 in
    `03_SMOKE_TESTS.md`.
  - **Standard:** `events-frames-taint-§8` says to never compare such a value with `<`/`>` (*"raises"*).
    Its trigger set includes *"any other API a client build protects in combat"*. It grades *"an
    unguarded secret on a repeating ticker"* by exactly this freeze.
- **Reachability:** any player who has learned an M+ teleport, on the default profile
  (`notify.showTeleport = true`, `visibility = "always"`). Two paths reach it:
  - they leave the popup open with a teleport cooldown running when combat starts, which is the ticker
    path; or
  - their join notice fires while they are in combat, for example when they accept an invite
    mid-pull in the open world, or when they type `/wg test notify` during a fight having learned *Path
    of the Windrunners*. This is the notify path.
  Both paths depend on the client returning secret cooldown fields in combat (see Evidence).
- **Coverage:** `docs/test-cases.md` lists ticker and teleport-row cases, so the inventory claims these
  paths. The mock cannot produce a secret, so the suite never takes them in combat. That is F-002.

## Medium

### F-002 — The test mock cannot produce a secret cooldown, so the suite is asleep under F-001 `[tests]`

- **Where:** `tests/wow_mock.lua:568-571`
  `GetSpellCooldown = function(id)` / `return mock.spellCooldowns[id]` /
  `or { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }`.
  The mock has no `issecretvalue` global and no secret-value helper.
- **Problem:** every cooldown case feeds plain numbers. The combat-time behavior of the ticker and the
  Teleport row is therefore unmeasurable. Every case passes against code that raises in the configuration
  the feature exists for: a popup left open through a pull.
- **Impact:** F-001 shipped through 914 green cases, and a regression that re-introduces an unguarded
  compare would also go green.
- **Reachability:** only the test inventory. The shipped behavior is F-001's.
- Related upstream gap: F-009.

### F-003 — `/wg test notify` and the panel's **Test** button overwrite the player's real capture `[ux]`

- **Where:** `core/WhatGroup.lua:1308-1309`
  `function WhatGroup:RunTest()` / `self.pendingInfo = self:SampleInfo()`.
  It is reached from `settings/Panel.lua:336-338` (`onClick = function()` /
  `if WhatGroup.RunTest then WhatGroup:RunTest() end`) and from `/wg test notify`.
- **Problem:** the one-shot test writes the sample group into `pendingInfo`, which is the slot that holds
  the real group the player joined. Nothing restores the real capture afterwards. Test mode was built
  specifically to avoid this. Its comment says *"A record of its own rather than a write to
  `pendingInfo`, so a real capture the player is still holding survives"*. The one-shot route does not
  follow the same rule.
- **Impact:** for the rest of that group's session, the details link, `/wg show` and the launcher's
  *Show window* all open *"Test Group — Windrunner Spire +12"* instead of the group the player is in.
  This conflicts with `preview-mode`'s *"MUST clear the preview and return to live data"*: there is no
  live data left to return to.
- **Reachability:** any player in a real Premade Group Finder group who tunes the chat rows and clicks
  **Test**, or types `/wg test notify`. Both are documented, on the default profile.

### F-004 — The panel's **Test** button, pressed while the addon is disabled, leaves a popup that appears when the addon is re-enabled `[ux]`

- **Where:** `core/WhatGroup.lua:1309-1312`, which runs `ShowFrame` while the addon is stood down. The
  gate declines the show (`modules/Frame.lua:1184-1188`, `if not visibilityAllows() then` …
  `gateWithheld = true`), and the re-show arm later fires (`modules/Frame.lua:456-457`,
  `if gateWithheld and WhatGroup.pendingInfo and not onScreen() then` / `showPopup()`).
- **Problem:** the step-by-step behavior:
  1. `docs/slash-dispatch.md:89` documents the Test button as *"the surviving preview route"* while the
     addon is disabled.
  2. With the addon disabled, the button prints the chat summary. It also builds the popup, which
     includes the secure teleport button and the `UISpecialFrames` proxy. `visibilityAllows()` refuses
     because the addon is stood down, so the popup is never shown.
  3. `gateWithheld = true` is recorded, and the sample stays in `pendingInfo`.
  4. When the player later re-enables the addon, `NS.StandUp` → `ApplyFrameVisibility` → the re-show
     arm puts the stale sample popup on screen without being asked.
- **Impact:** the "preview" never shows the popup, and enabling the addon then opens a sample-group
  window the player did not ask for.
- **Evidence:** harness probe, run in scratch. After `Set("enabled", false)` and `RunTest()` the popup
  was built with `shown=false`. After `Set("enabled", true)` it was `shown=true` with
  `title=Test Group — Windrunner Spire +12`.
- **Coverage:** the test that claims this path, `tests/test_lifecycle.lua:485-493`
  (`test("lifecycle: the panel Test button previews while the addon is disabled"` …
  `assertTrue(NS.addon.pendingInfo ~= nil, "the preview still runs from the panel")`), asserts only that
  state was written. It never checks the popup. The case is named for a preview it does not verify, so
  it counts as coverage while providing none (`testing-§12`).
- **Reachability:** any player who disables the addon, opens Settings → General and clicks **Test**,
  then re-enables it.

## Low

### F-005 — The Height tooltip states the wrong default `[ux]`

- **Where:**
  - `settings/Schema.lua:282`:
    `tooltip = "Height of the group-info popup, in pixels. The default 260 is the size the popup shipped at.",`
  - The shipped default is `defaults/Profile.lua:40` `height   = 280,`.
  - The comment at `modules/Frame.lua:58-61` (*"`FRAME_HEIGHT = 260` … their shipped defaults ARE those
    two numbers"*) is stale in the same way.
- **Impact:** the player-facing tooltip says 260 next to a slider whose *Defaults* button restores 280.
- **Reachability:** any player who hovers the Popup → Height slider.

### F-006 — `docs/performance.md` is stale against today's offline run `[docs]`

- **Where:** `docs/performance.md:146-147`. The committed figures are
  `combatGateFlipping … | 7.0 | 1064.1 |` and `showFrameRepeat | 500 | 18.0 | 1744.5 | … Re-measured 2026-09-24`.
- **Problem:** today's run gives `combatGateFlipping` 960.0 bytes/iter and `showFrameRepeat` 19.0
  api/iter. The API count is deterministic. The extra call per show is consistent with the Role row
  added after the 2026-09-24 measurement (WhatGroup#1), but that cause has not been bisected.
- **Reachability:** a document only; no runtime effect.

### F-007 — `reloadProfile`'s migration comment promises something the global stamp cannot do `[naming]`

- **Where:** `core/WhatGroup.lua:245-247`
  `local function reloadProfile(self)` / `-- The incoming profile may predate the current schema version.` /
  `self:RunMigrations()`.
- **Problem:** the migration stamp is account-wide (`core/Database.lua:40-46`:
  `local from = g.schemaVersion or 0` … `g.schemaVersion = v`). Once it is current, this call is a
  no-op on every profile event. An "incoming profile" therefore never migrates here. `Database.lua`'s
  header gives the correct rule: a profile-scoped step must walk every stored profile itself. A
  maintainer who trusts this comment could write the first real profile step against the active
  profile only.
- **Reachability:** a comment. There is no runtime effect today, because the only step is the 0→1
  no-op stamp.

## Upstream (these do not land in this repo)

### F-008 — The standard's §8 trigger set does not name `C_Spell.GetSpellCooldown` `[upstream]` (WowAddonStandards)

- **Where:** `WowAddonStandards/standards/standards/events-frames-taint.md:163-172`, *"The named APIs —
  the MUST's trigger set"*. It lists absorbs, health, threat and aura amounts, then *"any other API a
  client build protects in combat"*.
- **Problem:** LibKa0s-Compat documents `GetSpellCooldown`'s `startTime` / `duration` / `modRate` as
  possibly secret in combat (`LibKa0s/Compat.lua:232`). The standard says *"When a build protects a new
  API, extend the list here — that is an upstream edit"*, and that edit has not been made. Audits grade
  against the named list, so a site like F-001 has been graded as the out-of-set SHOULD, or not filed at
  all.
- **Remediation:** fix this in WowAddonStandards. Add the `C_Spell.GetSpellCooldown` fields (and
  `C_Spell.GetSpellCooldownDuration`'s remaining time) to the named list, and bump the standard's
  version. This is **not** a local edit.
- **Reachability:** the standard's text only. It affects how F-001's class is graded across the
  collection, not shipped behavior.

### F-009 — The LibKa0s test kit has no secret-value mock `[upstream]` (LibKa0s, `testkit/`)

- **Where:** `tests/_kit/*.lua` (vendored from `LibKa0s/testkit`): `grep -i issecretvalue` finds nothing.
- **Problem:** every consumer that has to test combat-secret paths has to write its own simulator.
  MultiMeters already carries a 226-line `tests/mock_secrets.lua`, and WhatGroup needs one for F-002.
  This is the per-repo duplication that anti-patterns #47 names.
- **Remediation:** fix this in LibKa0s. Add an additive secret simulator to `testkit/` (a
  `secret(v)` value that raises on compare, arithmetic and concat, plus an `issecretvalue` the mocks
  answer), bump `Kit.VERSION`, and re-vendor `tests/_kit/` into every consumer as its own commit. This
  is **not** a local edit to `tests/_kit/`.
- **Reachability:** only the test inventories of consumers. It has no runtime effect.

---

Counts: **Critical 0 · High 1 · Medium 3 · Low 3 · Upstream 2 (Low)**. These are F-001 to F-009. The
two upstream findings are graded Low and are listed separately.
