# 02 — Deviations (2026-09-23)

**Standard:** v2.64.0 (2026-09-23). **ID prefix:** `WG-` (stable since 2026-07-12). IDs that recur keep
their numbers. New IDs this run start at **WG-64**, and **WG-57** is reopened on a new reading.

**Grading is by impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure is
**Low** or **Info** even when the rule it fails is a MUST, and the entry still names that MUST.

## Tally — both numbers, with their basis

| | Count |
|---|---|
| **Headline tally (roots only)** | **22** |
| Derived dependents (`derived from …`, excluded above) | 3 (WG-63, WG-65, WG-66) |
| **Total including dependents** | **25** |

By impact grade, **roots only**:

| Grade | Count | IDs |
|---|---|---|
| **High** | **0** | — |
| **Medium** | **1** | WG-64 |
| **Low** | **16** | WG-57 · WG-61 · WG-67 · WG-68 · WG-69 · WG-70 · WG-71 · WG-72 · WG-73 · WG-74 · WG-75 · WG-76 · WG-77 · WG-78 · WG-79 · WG-81 |
| **Info** | **5** | WG-48 · WG-56 · WG-80 · WG-82 · WG-83 |

With dependents counted, the grades read High 0 · Medium 1 · Low **19** · Info 5, for 25. All three
dependents are Low.

**MUST failures:** **16 roots**, which is every Medium and Low root except WG-76 (a SHOULD). No Info
root fails an open MUST. With the three dependents, all of which also fail a MUST, the figure is **19**.
Fifteen of the sixteen MUST roots are **Low**: none of them can reach a user, their SavedVariables or
their session today. The Low grade does not make any of those rules optional.

**Scope markers.**
- **WG-74** is **libka0s-upstream**. The defect is in the vendored kit, and it shows up in this repo's
  generated inventory.
- **WG-56** and **WG-82** are **standards-upstream**.
- **WG-57** carries an upstream-clarification option.

**Verdict: minor deviations.** Nothing is High. The one Medium, **WG-64**, is a registration that
survives the stand-down: the `EventRegistry` "SetItemRef" callback. It is the only survivor of the
`slash-commands-§7` census, and the suite and the hub both miss it. Everything else is structural,
documentary or latent.
- Of the 7 roots on 2026-09-08, 4 have closed (WG-51, WG-54, WG-58, WG-62) and 3 have carried
  forward (WG-61, WG-48, WG-56). WG-57 is reopened.
- Most of today's new roots come from rules this repository had never been measured against. These
  include `events-frames-taint-§1`'s two new subsections (v2.63.0), the re-vendor-bundle MUST, the
  `slash-commands-§7` census, and the `debug-logging-§4` sink rule, which the 2026-09-08 bundle did not
  check at the site level.

---

## Recorded deviations — accepted, not re-filed

The register is `docs/ARCHITECTURE.md` → `## Documented deviations` (`:485`), with five rows at
`:502-506`. Each row below matches one of them, and none counts toward the tally or the MUST count
(`audit-review-history`). Every trigger was evaluated against today's tree. Evidence is in 03 §B.

| Rule (row) | Decided | Trigger evaluated today | Status |
|---|---|---|---|
| `performance-§12`, "the exemption is not claimed" (`:502`) | 2026-08-06 | (1) The upstream amendment has **not** landed: `performance-§12` in v2.64.0 still re-arms the wiring on "the first … repeating ticker". The only commits touching `performance.md` since 2026-09-08 changed §6 and §10 hunks. (2) The only repeating timer is still `modules/Frame.lua:486`. There is no `OnUpdate` and no ticker. | **Confirmed, not fired.** Its text points at "the row above" and "the exemption row above", but both were retired on 2026-09-08 (WG-77). |
| `localization-§3` (`:503`) | 2026-08-05 | `ls locales/` → `enUS.lua` only. | **Confirmed, not fired.** Its evidence id `WG-R-06` resolves to the wrong finding (WG-61). Its Rule cell should cite `localization-§1` (WG-78). |
| `events-frames-taint-§8` (`:504`) | 2026-08-05 | (1) The trigger-set sweep returns **0**. (2) Both `pout` fallbacks (`settings/Panel.lua:27`, `settings/Schema.lua:52`) are still unreachable: the TOC loads `core\WhatGroup.lua` (`:48`) before every `settings\` file (`:78-84`). | **Confirmed, not fired.** Its evidence id `WG-A-08` resolves to nothing (WG-61). |
| `standalone-windows`, footer **Close** with no mark (`:505`) | 2026-08-25 | The popup footer still holds one wide action button, `closeBtn` (`modules/Frame.lua:770-778`). | **Confirmed, not fired.** |
| `standalone-windows`, ESC proxy in `UISpecialFrames` (`:506`) | 2026-09-12 | The popup still parents a `SecureActionButtonTemplate` (`modules/Frame.lua:725`). The section's "Secure/action-button content is the exception" parenthetical dates from 2026-07-13 (`070caf2`), before this row was written, so it is not an amendment that has since landed. | **Confirmed, not fired.** |

**Rows whose cited rule the standard has since changed:** none of the five cites a rule whose
substance moved. One row cites the **wrong** section of an unchanged rule (WG-78).

**`state:will-not-do` issues with no register row:** the will-not-do issues are #5, #7, #9–#14, #18
and #21. None of them is a ratified deviation missing its home. #7 and #18 back the `performance-§12`
row. The others decline optional LibKa0s modules (Widgets, Item, Pool, Bus), a MAY field
(`X-Wago-ID`), a library gap (#11), or host-owned helpers the library does not supply (#9, #10).

## Examined and deliberately not filed

- **`lock` / `unlock` verbs.** `slash-commands-§8` is a MAY and names WhatGroup explicitly as the
  "checkbox and no verbs" shape that is fine. No row is owed.
- **`ARCHITECTURE.md`'s own map row.** It is absent. This is a MAY, and an audit MUST NOT file either
  state.
- **The popup's close control.** The `MakeCloseButton(` grep returns only the wrapper
  (`core/CoreSetup.lua:136`) and its stub (`:100`). The popup draws no title-bar close. Its labeled
  footer button sits under the ratified 2026-08-25 row.
- **Compat / Bus / Schema adoption.** v2.64.0 requires none of them (`library-stack-§7`). Compat is
  adopted, Bus is declined (#21) and Schema is deferred (#22). Not a finding in any state.
- **`RESULTS.md` has no commit SHA or clean/dirty cells.** Those cells bind from each repo's first run
  on kit revision 25 (`automated-tests-§4`). This repo re-vendored to revision 25 today and has not run
  on it yet, so they are not yet owed (see WG-48).
- **`options-ui-§13`(h), the wrapped-strip geometry.** Three short tabs, so nothing wraps. The pitch
  rule is the library's, and it is audited in its own repo.
- **Setter-level combat gates** on `ApplyFrameSize` / `ApplyFrameScale` (`modules/Frame.lua:92-96`,
  `:139-143`). `options-ui-§2` names these as the SHOULD, not a second page-level lock.
- **`Category-enUS: Chat`.** `toc-file-§1` forbids filing against a category value on the strength of
  a list.
- **`ResolveSearchResultID`'s shape handling** (`core/WhatGroup.lua:547-573`). This is defensive
  handling of a current API, not a deprecated one, so `compat` does not reach it.

---

## Medium

### WG-64 — the `EventRegistry` "SetItemRef" callback survives the stand-down, gated instead of unregistered
**Section:** `slash-commands-§7` (**MUST** — *every … registration the addon owns is actually
UNREGISTERED*, and the `hooksecurefunc` carve-out **MUST NOT** be generalized to anything that has a
real unregister), anti-pattern #85 · **Where:** `core/WhatGroup.lua:108-111` (registration),
`:96-100` (gate), `:329-349` (`NS.StandDown`, which never unregisters it) · *new*

`core/WhatGroup.lua` registers the details-link click at file load with
`EventRegistry:RegisterCallback("SetItemRef", …, WhatGroup)`. `NS.StandDown` unregisters the four
AceEvent registrations and the two raw frame registrations. It never calls
`EventRegistry:UnregisterCallback("SetItemRef", WhatGroup)`.

The callback's body gates on `NS.IsStoodDown()` instead. The comment at `:96-99` justifies this by
sharing "slash-commands-§7's one sanctioned exception" with the `hooksecurefunc("SetItemRef")` fallback.
The section names that exception as one-way APIs only: *"An addon MUST NOT generalize the
`hooksecurefunc` carve-out to anything that has a real unregister."* `EventRegistry` has one. The
addon's own mock models it (`tests/wow_mock.lua:684-687`).

Medium, per the stand-down grading: a live registration that survives, reachable and degraded, with no
user-visible error. The cost is small, because Blizzard's addon-link handler only raises "SetItemRef"
for an `addon:` link click. But a disabled WhatGroup still enters Lua on every such click from any
addon, which is exactly the draw-gate shape §7 exists to end. It is also the one survivor that breaks
the hub's claim that only the two `hooksecurefunc` rows remain (WG-65), and the conformance suite
cannot see it (WG-66).

**Fix:** unregister in `NS.StandDown` and re-register in `NS.StandUp`, sharing one register function
with the file-load path. Keep the file-load registration for the enabled boot. Then confirm in game
that GameMenu Logout stays clean across a disable/enable cycle (04 §1). If the in-client check shows a
taint cost, record a `slash-commands-§7` register row instead, and the MUST stays filed until that row
exists.

#### WG-65 — the hub says only the two `hooksecurefunc` rows survive the stand-down · *derived from WG-64*
**Section:** `documentation-§5` (**MUST**), `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:158-161`, `:170`, `:238-241`

`:158-159` says *"Every row below is registered while the addon is ENABLED and gone while it is
disabled, except the two `hooksecurefunc` rows"*. The table then lists the `EventRegistry` callback at
`:170`, and that callback is not gone. `:238-241` repeats the claim. Low: doc only. It stays a
dependent because the root's fix makes the sentence true.

#### WG-66 — `tests/test_disabled.lua`'s registration survey cannot see an `EventRegistry` callback · *derived from WG-64*
**Section:** `testing-§12` (**MUST** — a test that cannot fail), `slash-commands-§7` (*The conformance
test* — step 3 asserts from the mock's registry that **nothing** the addon registered survives) ·
**Where:** `tests/test_disabled.lua:76-82` (`regNames`), `tests/wow_mock.lua:694` (`__callbacks`, never surveyed)

`regNames` reads the kit's `__registrations()` (AceEvent, messages, buckets) and this repo's raw
frame stub. The `EventRegistry` fake keeps its live table behind `__callbacks`, and no survey reads it,
so steps 3, 6 and 9 go green with WG-64's survivor in place.
- Low: the gap is in a test.
- It stays a dependent because it is closed in the same change as WG-64.
- It **graduates** if WG-64 is closed by a register row rather than by unregistering, because the
  survey would then still be blind to the next such registration.

**Fix:** add `mock.EventRegistry.__callbacks("SetItemRef")` (keyed by owner) to `regNames`, with a
`-- red under:` line naming the dropped `UnregisterCallback`. Optionally take the survey upstream into
the kit's `mock_record` (04 §1).

---

## Low

### WG-57 — the addon registers game events, so `architecture-§4`'s bus MUST applies as written, and there is no bus · *reopened*
**Section:** `architecture-§4` (**MUST** — *binds an addon with two or more feature modules, **or any
module that registers game events***) · **Where:** `core/WhatGroup.lua:294-302`,
`docs/ARCHITECTURE.md:122-129` · *reopened (rejected in triage as `WHATGROUP-A-12` on 2026-09-07; not
re-filed 2026-09-08)*

The 2026-09-08 bundle treated WhatGroup as sub-threshold, arguing that §4's hazard (the same-target
clobber) cannot arise with no messages. That is the rule's **rationale**. Its **applicability clause**
is a different sentence, and it names *"any module that registers game events"*.
- `core/WhatGroup.lua` registers four game events, and `modules/Frame.lua` registers
  `PLAYER_REGEN_ENABLED` on two frames.
- The two modules talk by direct calls: `WhatGroup:ShowFrame`, `WhatGroup:GetTeleportSpell`,
  `NS.FrameStandDown`.
- `## Message Bus` records the sub-threshold reasoning, which the clause reserves for "one feature
  module and no event traffic".

Low: nothing is reachable. The MUST is still named.

**Fix (pick one):**
1. Adopt a minimal bus for the core → Frame traffic, declared once as constants.
2. File a `## Documented deviations` row citing `architecture-§4` with a re-check trigger.
3. Take the ambiguity upstream: does an AceAddon shell that registers events count as "a module"?

The third is the likeliest outcome, and 04 §6 recommends it.

### WG-61 — two register rows cite evidence ids that resolve to nothing or to a different finding · *carried from 2026-09-08*
**Section:** `audit-review-history` (**MUST** — the third register MUST: every evidence id a row cites
resolves), `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:503` (`WG-R-06`), `:504` (`WG-A-08`), the resolution key at `:494-498`

Unchanged since the last run.
- `WG-R-06` resolves through the key at `:494-496` to `WHATGROUP-R-06` in `docs/reviews/2026-09-07/`,
  which is *"`Compat.IsSpellKnown` is the one spell shim with no modern-namespace rung"*
  (`01_FINDINGS.md:197`, closed as issue #15). That is not the localization decision. The row's real
  evidence is `F-006` in `docs/reviews/2026-08-05/`.
- `WG-A-08` appears only where the 2026-09-07 and 2026-09-08 bundles quote this same row. No bundle
  assigns it. Its real evidence is `WG-37` in `docs/audits/2026-08-05/02_DEVIATIONS.md`.

Low: a citation cannot harm a player.

**Fix:** `WG-R-06` → `F-006` (2026-08-05 review), `WG-A-08` → `WG-37` (2026-08-05 audit). Extend the
key at `:494-498` to name those id shapes.

#### WG-63 — the register-evidence gate is green against WG-61 · *derived from WG-61, carried*
**Section:** `testing-§12` (**MUST**), `audit-review-history` · **Where:** `tests/test_register.lua:94` (skips any `-R-` id), `:59` (`isAssigned` accepts any table cell in any bundle)

Unchanged. `git log -- tests/test_register.lua` → last touched `e735453` (2026-09-08). It stays a
dependent and closes in the same change as WG-61. It graduates if WG-61 is closed without tightening
the gate.

### WG-67 — the event-registration block does not survive one retired event name
**Section:** `events-frames-taint-§1` (**MUST** ×2 — *registration is isolated per event through a
single `pcall`ed helper*; *the rejected names are recorded and reachable by the player*; plus the
`C_EventUtils.IsEventValid` **SHOULD**) · **Where:** `core/WhatGroup.lua:293-304`,
`modules/Frame.lua:529`, `:1028` · *new (the subsection arrived in v2.63.0, `957b3c5`)*

`registerFeatureEvents` calls `self:RegisterEvent` four times, bare. Modern retail raises on an
unknown name. `OnEnable` runs this helper **first** (`:373`), so one retired name would abort
`OnEnable` before `Settings.Register()` (`:388`), `NS.Launcher:Register()` (`:397`) and the latch
(`:405`) ever run. The player would be left with no panel entry, no minimap button and a disabled
switch that does nothing, and no Lua error unless script errors are on.
- The two raw `RegisterEvent` calls in `modules/Frame.lua` are not isolated either.
- No list of rejected names exists, and nothing reaches one through `/wg debug`.
- No `IsEventValid` front gate exists.

Low: all four events are current today, so this is a latent risk.

**Fix:** add one `pcall`ed `registerEvent` helper that records rejections and is surfaced through the
debug console or `/wg debug`, and front-gate it with `C_EventUtils.IsEventValid` where it exists.
Route the four AceEvent registrations, and WG-68's replacement, through it. Pin it with the kit mock's
`__badEvents`.

### WG-68 — two private frames carry ordinary `PLAYER_REGEN_ENABLED` traffic outside AceEvent
**Section:** `events-frames-taint-§1` (**MUST NOT** — *create per-module frames to carry ordinary event
traffic*; the only carve-out is a `RegisterUnitEvent` filter) · **Where:** `modules/Frame.lua:526-541`
(`f:RegisterEvent`), `:1026-1038` (`buildWaitFrame`) · *new (carve-out text arrived in v2.63.0)*

`deferTeleportUntilCombatEnds` registers `PLAYER_REGEN_ENABLED` on the popup frame `f` and swaps its
`OnEvent` script. `ShowFrame`'s first-show-in-combat defer creates `buildWaitFrame = CreateFrame("Frame")`
for the same event. Both are plain `RegisterEvent` on an event the client does not filter by unit. The
carve-out says: *"Not a private `RegisterEvent` for an event the client does not filter by unit …
is outside the carve-out and is a deviation."*

The 2026-09-08 bundle examined these same two registrations under `architecture-§4` and did not file
them. This is a different rule, which did not exist then.

Low: both frames are torn down correctly by `NS.FrameStandDown` (`:1115-1123`).

**Fix:** drain both deferrals from AceEvent. Either fold them into the existing
`OnCombatStateChanged("PLAYER_REGEN_ENABLED")` handler as a pending-work queue, or register on a
private AceEvent-embedded target (`AceEvent:Embed({})`). The addon object already owns
`PLAYER_REGEN_ENABLED`, and AceEvent keys one handler per (event, target). See 04 §2.

### WG-69 — sixteen debug call sites build the message before the gate
**Section:** `debug-logging-§4` (**MUST NOT** — *build the message before the call*; the sink is
zero-allocation when off only if the formatting is deferred behind the gate) · **Where:** 16 sites,
listed in 03 §E · *new at the site level*

Examples:
- `NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))`
  (`core/WhatGroup.lua:973`) concatenates on **every** `LFG_LIST_APPLICATION_STATUS_UPDATED`, with
  debug off.
- So do the `[Roster]` transition line (`:916`) and the `[Frame]` teleport resolution
  (`modules/Frame.lua:504`) on every popup populate.

The ratified `events-frames-taint-§8` row covers these same sites for **secret safety**. That row does
not reach `debug-logging-§4`, which is a performance MUST NOT and a different rule.

Low: none of these paths is per-frame, and the waste is a handful of short strings per event.

**Fix:** rewrite each as `NS.Debug(tag, "fmt %s", a, b)`, which is mechanical. The census command is
in 03 §E.

### WG-70 — `core\Compat.lua`'s TOC position is load-bearing and unannotated
**Section:** `toc-file-§5` (**MUST** — *a line whose position is load-bearing MUST carry a comment
naming what resolves at load*) · **Where:** `WhatGroup.toc:42`, `core/WhatGroup.lua:87` · *new (the
file-scope call arrived 2026-09-12, `fcf8197`)*

`core/WhatGroup.lua:87`, `local ADDON_LINK_TYPE = NS.Compat.AddOnLinkType()`, runs at file load. It
requires `core\Compat.lua` to load before `core\WhatGroup.lua`, and `WhatGroup.toc:42` carries no
comment saying so. If the line is moved below, `NS.Compat` is nil at load and the addon raises.
`toc-file-§5` counts that as a load-bearing position.
- `core\Util.lua` (`:41`) is conventional and also unannotated. That is `toc-file-§5`'s per-file
  SHOULD, and it is not filed separately while the MUST row is open.

Low: config and comments, with no user reach.

**Fix:** add one comment above `:42` naming `NS.Compat.AddOnLinkType()` and `core/WhatGroup.lua:87`,
plus a conventional note for Util.

### WG-71 — twenty-five vendored LibKa0s tags since the store's first bundle have no re-vendor bundle and no register row
**Section:** `audit-review-history` (**MUST** — *every re-vendor commit … has a `docs/revendor/`
bundle naming the tag … or the absence is a row in `## Documented deviations`*) · **Where:** `git log
--since=2026-08-25 -- libs/LibKa0s` (32 commits), `docs/revendor/` (8 bundles) · *new (rule and check
new since 2026-09-08)*

Ran `AUDIT.md`'s check verbatim from the horizon `2026-08-25`.
- **31** distinct tags were vendored, read off `CLAUDE.md` at each commit that touched
  `libs/LibKa0s/`.
- **6** tags are recorded: v1.25.0, v1.31.0, v1.32.0, v1.33.0, v1.34.0 and v1.55.0.
- That leaves **25** unrecorded tags: v1.18.0, v1.18.1, v1.19.0, v1.23.0, v1.24.0, v1.26.0–v1.29.0,
  v1.35.0–v1.39.0 (with v1.36.1 and v1.36.2), v1.42.0, v1.44.0, v1.45.0, v1.46.1, v1.47.0 and
  v1.50.0–v1.53.0.
- Three of the re-vendors were folded into feature commits (`f98ef41`, `127baa1`, `f74893a`). The check
  found them because it reads the payload, not the subject line.

**Grade: Low, and the conflict is recorded.** `AUDIT.md`'s text for this specific check calls such a
tag *"a High finding"*. Its own step 5, and this run's grading rule, say that a doc-only or config-only
failure is Low even under a MUST. No player, SavedVariables or session can reach a missing bundle. The
impact rule wins here, and the contradiction is filed upstream as part of WG-82.

**Fix:** one **consolidated** bundle, `docs/revendor/<date>-v<next-tag>/`, whose `01_DELTA.md` names
the span v1.18.0 → v1.53.0 as carried by sweeps. The standard names this as the compliant answer to a
backlog. Do not back-fill a folder per tag.

### WG-72 — no stub-surface parity case for the Launcher and Lifecycle seams
**Section:** `testing-§8` (**MUST** — *per adopted LibKa0s module, a stub-surface parity case … member
list derived by grep, the grep named in the case's comment, the degraded arm from a partial load*) ·
**Where:** `tests/test_surface_parity.lua:3-4` (the header inventory says "five seams"), the missing
cases for `core/LauncherSetup.lua` and `core/LifecycleSetup.lua` · *new*

`tests/test_surface_parity.lua` covers Core, DebugLog, Slash, Options and Compat. The addon adopts
nine majors. Env and Media publish the same wrapper functions on both paths, and the Core namespace
parity case catches a missing key there.
- Launcher's stub has one hand-listed member test (`tests/test_launcher.lua:391-403`), with no parity
  comparison and no named grep.
- Lifecycle's stub has neither.
- Both stubs match their live members today (5 and 8), so nothing is broken. The gate that would
  notice a drift is what is missing.

Low: degraded path only.

**Fix:** add two by-name parity cases, `assertSurfaceParity(stub, "LibKa0s-Launcher-1.0")` and the
same for Lifecycle, with the grep that produced each member list in its comment. Correct the header
inventory while there.

### WG-73 — five malformed standards citations in authored files
**Section:** `documentation-§6` (**MUST** — *a malformed … reference is a MUST fix*, enumerated
individually) · **Where:** five sites · *new*

| Site | Text |
|---|---|
| `core/LauncherSetup.lua:143` | `-- GATED ON THE STAND-DOWN LATCH (slash-commands-@7). …` |
| `tests/prose_waivers.lua:2` | `-- (tests/_kit/test_prose.lua, localization-5).` |
| `tests/prose_waivers.lua:4` | `-- A waiver is localization-5's MAY for a British spelling …` |
| `tests/run.lua:140` | `-- The US-English prose gate (localization-5) is the kit's too, …` |
| `tests/run.lua:145` | `-- The layout-1 cap gate, new in kit revision 25: …` |

None of these parses as `filename-§N`.
- The first is a typo.
- The other four copy the kit's ASCII spelling (WG-74).
- The out-of-range and bare-file sweeps return **0**, so WG-62's `lint-§1` and `code-quality-§3` are
  gone. The retired dotted `§N.M` form returns **0**. Commands are in 03 §F.

Low: comments.

**Fix:** `slash-commands-§7`, `localization-§5`, `layout-§1`.

### WG-74 — the vendored kit spells its citations without `§`, and they render into this repo's generated inventory · *libka0s-upstream*
**Section:** `documentation-§6` (**MUST**) · **Where:** **74** lines across four vendored kit files:
`tests/_kit/test_prose.lua` (35), `test_eol.lua` (25), `test_layout_cap.lua` (9) and `framework.lua`
(5). The command is in 03 §F. Four of them are rendered into `docs/test-cases.md:784`, `:788`, `:789`
and `:808` · *new*

The kit's case names and comments write `localization-5`, `line-endings-5`, `layout-1`, `testing-12` and
similar, with no `§`.
The case names are rendered by `--list` into this repo's `docs/test-cases.md`, which is tracked and
generated, and cannot be hand-edited.

Low: generated doc text.

**Fix:** upstream in `LibKa0s/testkit/`, then re-vendor and regenerate `docs/test-cases.md`. If an
ASCII-only constraint exists in the kit, the fix is a `§`-bearing string built at runtime or a
documented exemption. It is not this repo's to patch (`testing-§1`).

### WG-75 — two Tier 2 docs document LibKa0s's substrate instead of this addon's
**Section:** `documentation-§3` (**MUST NOT** — *shims `LibKa0s` supplies … MUST NOT be re-documented*;
the Conditional row's trigger must be the stated trigger) · **Where:**
`docs/compat-layer.md:21-22` (and its ladder prose), `docs/ARCHITECTURE.md:464`, `:462`, `docs/debug.md` · *new*

1. `docs/compat-layer.md:21-22` documents `GetSpellName` and `GetSpellTexture` rung by rung, and marks
   them **the library's**. The section forbids exactly that. The map row at `:464` says `core/Compat.lua`
   publishes *"eight addon-specific shims"*. The standard's count, `grep -cE
   '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua`, answers **6**, because two of the eight
   are the library's members, assigned at `core/Compat.lua:50` and `:58`.
2. `docs/debug.md` is registered **Present** at `:462` on *"The addon's own debug surface beyond the
   library console"*. The Tier 2 trigger is *"ships debug surfaces **beyond** the `LibKa0s` default
   console"*, and WhatGroup ships none: no dump verb and no second window. Most of the page (*The
   window*, *Line format*, *Font*, *Copy / Clear*) restates `LibKa0s-DebugLog-1.0`'s guarantees.

Low: docs.

**Fix:**
- Cut `compat-layer.md` down to the six addon shims, with a one-line pointer for the two library
  members, and correct the map count to "six".
- For `debug.md`, either mark the row **Not applicable**, citing the trigger, or keep the page but trim
  it to what is WhatGroup's own (the descriptor fields, the tag vocabulary, "adding a debug line") and
  say plainly in the row that the trigger has not fired.

### WG-76 — the hub is 533 lines
**Section:** `documentation-§3` (**SHOULD** — *the whole file SHOULD stay under roughly 400 lines*) ·
**Where:** `docs/ARCHITECTURE.md` (533 lines by `wc -l`) · *new*

No **mandated** section is past ~60 lines, so the spill MUST holds. The mass sits in unmandated
sections:
- `## The stand-down`, `:193-282`, about 90 lines.
- `## Invariants worth not breaking`, `:313-341`, very long lines.
- `## Load order`, `:367-410`.
- `## External dependencies`, `:349-365`.

Low, SHOULD.

**Fix:** spill *The stand-down* to a Tier 3 `docs/stand-down.md` and *Load order* to `module-map.md`
(its canonical home), leaving a summary and one link for each.

### WG-77 — docs have drifted from the tree
**Section:** `documentation-§5` (**MUST** — keep the doc set in sync with code); `README.md` also
`documentation-§1` · **Where:** the sites below · *new*

| Site | Says | Tree says |
|---|---|---|
| `README.md:41`, `:48` | the places you dragged "the two windows" / "the popup and debug windows" persist | the library does not persist the console's position (`docs/debug.md:119`, issue #11) |
| `docs/ARCHITECTURE.md:19` | capture keeps a "FIFO queue + appID map" | captures are keyed by `searchResultID`; the FIFO was removed (`docs/data-flow.md:102-106`) |
| `docs/module-map.md:68` | data-flow covers "LFG state machine + FIFO" | same |
| `docs/ARCHITECTURE.md:55` | "its eight seams" | the row lists nine files; nine majors are wired |
| `docs/ARCHITECTURE.md:319` | lists five degrading seams and "the other three read it" | four files are listed as readers; Env, Media, Launcher, Lifecycle and Compat also carry fallbacks |
| `docs/ARCHITECTURE.md:383` | `LibKa0s.xml` "spells out `Core` → `Env` → `Pool` → … → `PerfPanel`" (16 files) | 21 files; `Compat`, `Lifecycle`, `Bus`, `Schema`, `WidgetsDragHandle` missing |
| `docs/ARCHITECTURE.md:502` | "the row above names", "the exemption row above" | that row was retired 2026-09-08 (`:508-521`) |
| `core/MediaSetup.lua:33-34` | "modules/Frame.lua simply skips the mark beside its footer label" | the footer mark was removed (register row `:505`) |

Low: docs and comments. The README pair reaches a player as a wrong answer, but costs nothing when
wrong. **Fix:** correct each line. README edits go through the de-AI pass (`documentation-§1`).

### WG-78 — the English-only register row is keyed to the wrong section
**Section:** `audit-review-history` (**MUST** — report a register entry whose cited rule is now
*governed by a different rule*); `localization-§3` (*state 2 is a row … citing `localization-§1`*) ·
**Where:** `docs/ARCHITECTURE.md:503` · *new*

`localization-§3`'s second terminal state is *"a row in its `## Documented deviations` register …
citing `localization-§1`"*. The routing SHOULD lives in §1. This row's Rule cell reads
`` `localization-§3` ``.

Low: register text.

**Fix:** change the Rule cell to `localization-§1`. The row is otherwise already the state-2 row
(English-only, re-check trigger "the first non-English locale file").

### WG-79 — `DEPENDENCIES.md` understates two release-time tools
**Section:** `documentation-§7` (**MUST** — evidence-based; the *Release / assets* group names
*anything needed … to regenerate committed assets: Python and its packages*) · **Where:**
`DEPENDENCIES.md:190-192`, `:92-99` · *new*

1. `:190-192` says *"No image or font tooling is required, because nothing regenerates them from
   source in this repo … there is no committed pipeline to reproduce"*. `layout-§4` fixes a recipe
   for the committed `media/logos/whatgroup.logo.128.tga`: Pillow, `convert("RGBA").resize((128, 128),
   LANCZOS)`, *"Regenerate rather than hand-edit"*. That recipe needs Python 3 and Pillow.
2. `:92` labels lizard **optional**, and `:97-99` says an absent lizard is *"a skip, not that the addon
   is broken"*. At the tag, `automated-tests-§3` treats a complexity skip as a gate that did **not
   pass**. lizard is optional for a commit and required for a release, and the file should say so in
   those terms.

Low: doc. **Fix:** add Python 3 + Pillow (via `pipx`/`apt`, with a verify line) to *Release / assets*,
citing `layout-§4`. Re-label lizard as "required at release".

### WG-81 — the launcher's fallback re-spells the collection's refusal line
**Section:** `slash-commands-§7` (*The refusal line* — **MUST NOT** be re-spelled per addon, per verb or
per call site) · **Where:** `core/LauncherSetup.lua:148-155` · *new*

The disabled left-click prints `Sl:DisabledLine()`, or, if that is absent, the literal
`"Ka0s WhatGroup is disabled."` (`:152`). The literal has a trailing period and does not name
`/wg enable`, so it is not the mandated shape. It is unreachable today, because both branches of
`settings/Slash.lua` publish `DisabledLine`. That makes it a latent second spelling.

Low. **Fix:** drop the `or` literal, or make it the same `Sl`-less shape the degraded Slash stub uses
(`settings/Slash.lua:168-170`).

---

## Info

### WG-48 — the automated-test record is 29 commits behind HEAD · *carried, re-measured*
**Section:** `automated-tests-§1`, `§4`, anti-pattern #51 · **Where:** `docs/automated-tests/RESULTS.md:26`, `:66-86`

| | Recorded `20260916-184548` (`d64656b`) | HEAD `1124ac4` |
|---|---|---|
| NLOC | 9903 | **10462** |
| Functions | 1298 | **1368** |
| Max CCN | 15 | **14** |
| `lizard` warnings | 0 | 0 |
| Files in the 1000–1500 band | 2 | **3** (`core/WhatGroup.lua` 1099 entered) |
| `luacheck` files | 45 | **48** |
| Test cases | 667 | **727** |

- Distance: `git rev-list --count d64656b..HEAD` → **29**.
- Nothing crossed a threshold. One file entered the band, and that entry is owed a disposition at the
  next release.
- The watch list holds two **Accepted** entries. One has been carried by one release run and the other
  by none, so this is not #53.
- The release is the checkpoint, and there has been no release since 1.4.0 (`20260910-234511`). That
  keeps this at Info.
- The next run is the first on kit revision 25, and it will also add the commit and clean/dirty cells.

**Fix:** run `tests/_kit/run-automated-tests.sh` as part of the next release, and disposition
`core/WhatGroup.lua` there.

### WG-56 — the `Tab | Covers` table wording contradicts its own granularity, now in `documentation-§3` · *standards-upstream, relocated*
**Section:** `documentation-§3` Tier 1 `settings-panel.md` row · **Where:** `docs/settings-panel.md:327-341`

v2.41.0 moved the table out of the README. The README now has none, as `documentation-§1` item 5
requires, and item 5 is closed. The standard's new row still calls it *"the `Tab | Covers` table (one
row per settings subcategory)"*.
- The column is named **Tab**, but the rows are **pages**.
- WhatGroup has one subcategory and three tabs.
- `docs/settings-panel.md` carries a per-tab table derived from the schema (8/8/3 rows, matching
  `group` order) and the page → tab → row tree. That is the substance the section asks for.

**Fix (upstream):** decide between `Page | Covers` and per-tab rows, and word the row to match.

### WG-80 — the landing-page logo path hand-types the folder name
**Section:** closest rule `options-ui-§5` (logo at `Interface\AddOns\<Folder>\media\logos\…`); no MUST
fails · **Where:** `settings/Panel.lua:87`

`MAIN_LOGO_TEXTURE` types `"WhatGroup"`. `core/LauncherSetup.lua:54-55` builds the 128 icon's path from
`addonName` for the reason `library-stack-§8` gives: a hand-typed folder draws nothing and raises
nothing after a rename. This repo's own issue #17 (`WHATGROUP-R-12`) fixed the same pattern at another
line of the same file. **Fix:** build the path from `addonName`.

### WG-82 — three upstream text issues met while auditing · *standards-upstream*
1. **`AUDIT.md` grades one check against its own step 5.** The re-vendor-bundle check says a missing
   tag *"is a **High** finding"*. Step 5 says doc-only failures are Low. See WG-71.
2. **`toc-file-§3` says "currently `120007`"**, while every sibling Ka0s TOC carries `120100`.
3. **`layout-§4` says the editable `.png` source "ships but is never loaded".** `.pkgmeta:30-31` here
   excludes it from the package, deliberately (the comment is at `:27-29`). Either the sentence is
   descriptive only, or packaging the source is owed. The standard should say which.

### WG-83 — `.luacheckrc` omits the template's `docs/revendor/` exclusion
**Section:** `lint` (template) · **Where:** `.luacheckrc:13-17`

The template's `exclude_files` ends `"docs/revendor/", "_dev/", "tests/_kit/"`. This repo's list lacks
`docs/revendor/`, while its own comment at `:13` says *"Under docs/ only the FROZEN evidence bundles are
excluded"*. `docs/revendor/` is such a bundle store. It holds no Lua today, so the lint result is
unaffected. The `RESULTS.md` standing section quotes the list verbatim. **Fix:** add `"docs/revendor/"`.

---

## Closed since 2026-09-08

Measured, not assumed.

| ID | Closed by | Evidence |
|---|---|---|
| WG-51 | kit revision 25 (`vendor_sync.lua:371-375`) | `tests/test_vendor_sync.lua` now reports *"the automated-test runner is recorded executable (100755)"*: PASS. `git ls-files -s` → `100755`. |
| WG-54 | respelled | `core/WhatGroup.lua:60` reads *"traveled"* and `:979` reads *"the emptiness is the behavior"*. The kit prose gate, with the published lists taken whole, passes. |
| WG-58 | rule change (v2.63.0) | `.superpowers` is conditional now. The directory is absent, and check (c) prints nothing. |
| WG-62 | respelled | The sweep for `lint-§` and `code-quality-§` over authored files returns **0**. |

## Recorded as compliant, not as omissions

Measured and passing, so no row is filed.

`layout`:
- §1: modular skeleton; census present and current; kit cap gate wired; no generator outside
  `tools/`.
- §2 and §3.
- §4: TGA type 2, 128², 32 bpp.

`toc-file`:
- §1 (field order, own `IconTexture`) and §2, the latter via the register row.
- §3, apart from the upstream note.
- §4.
- §5, apart from WG-70.

`library-stack`:
- §1–§3.
- §7: whole payload, both `diff -r` empty, provenance line only in `CLAUDE.md`.
- §8: seam, `RegisterLSM`, no private media.
- §9: no `LSMPatch`.

`architecture`: §1–§3, §5 (named state and write-path census), §6 and §7. §4 is WG-57.

`savedvariables`: all five sections.

`options-ui`:
- §1 (stub shapes), §2 (no second lock, no close in combat), §5, §8, §9 and §12 (verbatim wording).
- §13–§15: strip on every non-exempt page, one band, the `Master controls` block composed.
- §16–§18 do not engage.

`standalone-windows`: one wrapper, `ApplySkin`, ESC via a ratified row, and position persisted.

`preview-mode`: session test mode, ends in combat.

`launcher`, all five sections: one object, label, rung (a), global `minimap.hide` that survives both
resets, own icon.

`slash-commands`:
- §1–§6.
- §7 apart from WG-64 and WG-81.
- §8, which is a MAY.

`debug-logging`: §1–§3, §5–§13. §4 is WG-69.

`localization`:
- §1 and §2.
- §3 via its row.
- §4.
- §5: kit prose gate wired, lists taken whole, waivers per file and per word with reasons.

`events-frames-taint`: §2–§7, and §8 via its row. §1 is WG-67 and WG-68.

`compat`, `public-api` (not engaged), `packaging` (all three checks clean).

`line-endings`, all seven sections: canonical body, check (e) = 0, kit EOL gate including the body
case.

`lint`: 0/0 over 48 files, test tree in scope, no top-level `ignore`. WG-83 is Info.

`testing`:
- §1–§7.
- §8, apart from WG-72.
- §9: suite list pinned both ways and kit suites declared by path.
- §10 (n/a), §11, §13 and §14 (7.2 s serial, under the ~10 s `--jobs` threshold).
- §15: bounded kit, no budget overrides, no host paths.
- §12, apart from WG-63 and WG-66.

`performance`: via the ratified §12 row. `tests/perf.lua` is present, and `docs/performance.md` is
present.

`automated-tests` §1–§7: release run `20260910-234511` has `ANALYSIS.md`, perf skip reason stated,
standing sections generated.

`documentation`:
- §1, apart from WG-77's README pair.
- §2 and §4.
- §3: four tables, no orphans or dangling rows, all Tier 1 present, Tier 2 statuses honest except
  WG-75. The hub SHOULD is WG-76.
- §5, apart from WG-77.
- §6, apart from WG-73 and WG-74.
- §7, apart from WG-79.
- §9: headers present and grandfathered above the bootstrap.

`audit-review-history`: stores dated, re-vendor bundles tagged since 2026-09-12, no `LEDGER.md`,
issues labeled and prefix-free. The register MUSTs are WG-61 and WG-78, and the re-vendor MUST is
WG-71.

`naming-cheatsheet`, `versioning-git`.

Anti-patterns clear: **#1–#15, #17–#45, #47–#63, #65–#68, #70–#76, #78–#84, #86–#88**.
- #16 (cap) is clear as well: no file is over the cap.
- #46 is clear as of this run.
- #64 is the library's concern and clear.
- #69 is clear: every row carries a `group`.
- #77 is not auditable.
- #85 is WG-64's single survivor.
- #56's gate half is WG-72.
