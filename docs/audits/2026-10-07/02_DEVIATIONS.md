# 02 — Deviations (2026-10-07)

**Standard:** v2.76.1 (2026-10-07). **ID prefix:** `WG-` (stable since 2026-07-12). Recurring
deviations keep their IDs: WG-71 and WG-77 are **reopened**, and WG-48 is **carried**. The one new ID
is **WG-84**.

**Grading is by impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure is
**Low** or **Info** even when the rule it fails is a MUST, and the entry still names that MUST.

## Tally: both numbers, with their basis

| | Count |
|---|---|
| **Headline tally (roots only)** | **4** |
| Derived dependents (`derived from …`, excluded above) | 0 |
| **Total including dependents** | **4** |

By impact grade (roots only; with no dependents, the total reads the same):

| Grade | Count | IDs |
|---|---|---|
| **High** | **0** | none |
| **Medium** | **0** | none |
| **Low** | **3** | WG-71 · WG-77 · WG-84 |
| **Info** | **1** | WG-48 |

**MUST failures:** **3 roots** (WG-71, WG-77, WG-84), and **3** including dependents. All three are
**Low**, because no user, SavedVariables or session can reach any of them today. The Low grade does
not make any of those rules optional. WG-48 fails no MUST: the checkpoint it concerns is the release,
and none has been cut since the last record.

**Verdict: minor deviations.** Nothing is High or Medium. The 2026-09-23 run's one Medium (WG-64, the
`EventRegistry` survivor of the stand-down) and every other root it filed are closed. What remains is
two doc and record lapses that recurred after closure, one latent registration, and a stale run
record.

---

## Recorded deviations: accepted, not re-filed

The register is `docs/ARCHITECTURE.md` → `## Documented deviations` (`:372`), with six rows at
`:380-385`. Each row below is accepted, and none counts toward the tally or the MUST count
(`audit-review-history`). Every trigger was evaluated against today's tree and every evidence id was
resolved. The evidence is in 03 §B.

| Rule (row) | Decided | Trigger evaluated today | Evidence ids | Status |
|---|---|---|---|---|
| `performance-§12`, the exemption is not claimed (`:380`) | 2026-08-06 | (1) The upstream amendment has **not** landed: `performance-§12` in v2.76.1 still re-arms the wiring on "the first `OnUpdate` handler, repeating ticker, or in-combat event handler". (2) The regenerated sweep shows exactly one repeating timer (`modules/Frame.lua:587`), still window-bounded. | issues #7 and #18 resolve, both `state:will-not-do` | **Confirmed, not fired.** |
| `localization-§1` (`:381`) | 2026-08-05 | `ls locales/` → `enUS.lua` only. | `F-006 (docs/reviews/2026-08-05/)` resolves at `01_FINDINGS.md:172` | **Confirmed, not fired.** |
| `events-frames-taint-§8` (`:382`) | 2026-08-05 | (1) The trigger-set sweep returns **0**. (2) Both `pout` fallbacks are still unreachable: `WhatGroup._print` is set at `core/WhatGroup.lua:189`, and the TOC loads that file before every `settings\` file. | `WG-37 (docs/audits/2026-08-05/)` resolves at `02_DEVIATIONS.md:113` | **Confirmed, not fired.** Its cited line numbers (`:887`, `:895`, `:903`) still land on the three chat rows. |
| `standalone-windows`, footer **Close** with no mark (`:383`) | 2026-08-25 | The footer still holds one wide action button, `closeBtn` (`modules/Frame.lua:906`). | `WG-52` | **Confirmed, not fired.** |
| `standalone-windows`, ESC proxy in `UISpecialFrames` (`:384`) | 2026-09-12 | The popup still parents a `SecureActionButtonTemplate` (`modules/Frame.lua:861`). The section's *"Secure/action-button content is the exception"* sentence is unchanged. | none cited | **Confirmed, not fired.** |
| `options-ui-§1`, route (b) for the composed rows on a library-absent load (`:385`) | 2026-09-24 | `options-ui-§1` still makes route (a) a **SHOULD** for `enable`/`disable`, and v2.76.1 names WhatGroup#22 there by name. #22 is closed `state:done` and not reopened. | #22 resolves | **Confirmed, not fired.** |

**Rows whose cited rule the standard has since changed:** none.

**`state:will-not-do` issues with no register row:** the will-not-do issues are #5, #7, #9–#14, #18
and #21. None of them is a ratified deviation missing its home:
- #7 and #18 back the `performance-§12` row.
- #5 declines a MAY field (`X-Wago-ID`).
- #11 records a library gap.
- #9 and #10 keep host-owned helpers the library does not supply.
- #12, #13, #14 and #21 decline optional modules (Widgets, Item, Pool, Bus) that `library-stack-§7`
  does not require.

## Examined and deliberately not filed

- **`lock` / `unlock` verbs.** `slash-commands-§8` is a MAY. No row is owed.
- **`ARCHITECTURE.md`'s own map row** is absent. This is a MAY, and an audit MUST NOT file either state.
- **The two *Not applicable* map rows** (`message-bus.md`, `perf-analysis/README.md`) point at files that
  do not exist. That is the stated *Not applicable* shape, not a dangling row. Both triggers are
  measured as not fired: 0 messages, and no harness wired.
- **`core\Database.lua`'s TOC line carries no note.** Its position is conventional. Nothing reads
  `NS.SCHEMA_VERSION` or `NS:RunMigrations` at file scope, and both are reached at `OnInitialize` /
  call time. `toc-file-§5`'s SHOULD is per group, and the `# Core` group marks its conventional
  positions. No row.
- **`docs/module-map.md` has no row per test file.** Every `tests/*.lua` is named in
  `docs/testing.md`, the verification doc that owns them. Five prior runs read Tier 1 the same way, so
  no row is filed.
- **The combat edge writes no line of its own when nothing changes.** Every reaction the edge causes is
  logged: the held-work flush (`modules/Frame.lua:288`), the popup transition with its cause
  (`:392`) and test mode ending (`:1099`). `debug-logging-§8` asks for a line naming the state taken,
  and the consequences carry it.
- **`NS.Debug("Profile", "switched to '%s'", tostring(...))`** (`core/WhatGroup.lua:283`) calls
  `tostring` ahead of the gate. It passes a format and raw values, as `debug-logging-§4` asks, on a
  player-initiated event that fires at most once per profile switch. Not a hot path.
- **The README's `## Credits` says the font "ships inside the bundled LibKa0s payload".** That sentence
  locates a credited asset. It is not a library inventory or the provenance line (`documentation-§1`).
- **The sighted runner's max CCN is 15** (`encode@336-366` in `tests/perf.lua`). The threshold is
  *above* 15, so this is no warning.
- **Setter-level combat gates** on `ApplyFrameSize` / `ApplyFrameScale`. These fall under
  `options-ui-§2`'s SHOULD and are not a second page-level lock.
- **`Category-enUS: Chat`.** `toc-file-§1` forbids filing against a category value.

---

## Low

### WG-84 — the stand-down's owed-`Hide` registration is a bare `RegisterEvent`, outside the `pcall`ed helper
**Section:** `events-frames-taint-§1` (**MUST**: *every `RegisterEvent` goes through a single
`pcall`ed helper*, *a host on v1.56.0 or later **MUST** register through them*) · **Where:**
`core/WhatGroup.lua:436`. The hub claim it contradicts is at `docs/ARCHITECTURE.md:184-186`. *New.*

The remediation of WG-67 routed the four feature registrations through `NS.SafeRegisterEvent`
(`:374-382`). The fifth registration the addon owns, the transient `PLAYER_REGEN_ENABLED` that
`NS.StandDown` takes when it is disabled in combat while owing the popup a protected `Hide`, is still
`self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")`.
- The hub says the event rows are registered through the helper, *"never a bare
  `self:RegisterEvent`"*. That reads as true of the whole surface and is not.
- **Latent, so Low.** The same name is registered through the helper at login (`:382`), so it could only
  raise on a client that has already rejected it there. In that case the raise would come out of the
  latch's `standDown` callback after the teardown above it had finished, losing only the owed `Hide`'s
  completion.

**Fix:** `NS.SafeRegisterEvent(self, "PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded", NS.RejectedEvents)`.
Pin it with the kit mock's `__badEvents` in `tests/test_disabled.lua`, so that a rejected name leaves
`NS.StandDown` completing. See 04 §1.

### WG-71 — v1.69.0 and v1.70.0 were vendored with no re-vendor bundle and no register row · *reopened*
**Section:** `audit-review-history` (**MUST**: *every re-vendor commit … has a `docs/revendor/` bundle
naming the tag … or the absence is a row in `## Documented deviations`*) · **Where:** `9677d99`
(2026-10-06, v1.69.0, kit 37) and `3fd8a2f` (2026-10-07, v1.70.0), and `docs/revendor/` (newest bundle
`2026-10-04-v1.68.1`). *Reopened: closed on 2026-09-23 by the span bundle (`5e4d690`).*

`AUDIT.md`'s check, run verbatim from the horizon `2026-08-25`, reads 51 distinct tags off `CLAUDE.md`
at the commits touching `libs/LibKa0s/` or `tests/_kit/`. It reads 49 recorded tags off the store.
`grep -vxF` prints **v1.69.0** and **v1.70.0**. Both commits are stand-alone `chore: re-vendor`
commits made outside `/dev-copilot:wow-revendor-libka0s`.
- The payload diff itself is clean (03 §A).
- The bundle would record what arrived: `WidgetsLineChart.lua`, `WidgetsAutocomplete.lua` and kit 37's
  `mock_lines.lua`. It would also record that nothing was adopted. WhatGroup has no chart and no
  autocomplete field, and Widgets is declined (#12).

Low: a missing record, which no player can reach.

**Fix:** one consolidated span bundle, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, holding only
`01_DELTA.md` (line 1 exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`) and
`05_SUMMARY.md` (one line per tag, *carried by sweep, nothing adopted*). See 04 §2.

### WG-77 — docs and comments have drifted from the tree · *reopened*
**Section:** `documentation-§5` (**MUST**: keep the doc set in sync with code). `DEPENDENCIES.md`'s line
is also `documentation-§7` (**MUST** evidence-based, **MUST NOT** drift). · **Where:** the sites below.
*Reopened: closed on 2026-09-23 by `4fe12b8` (WG-25).*

Filed as **one** rolled-up finding, because the fix is one sync pass. Most of the drift arrived with
WhatGroup#1 (`2ed2aa5`, 2026-10-01), which added the `notify.showRole` row and three role shims
without rolling the counts that describe them.

| Site | Says | Tree says |
|---|---|---|
| `docs/ARCHITECTURE.md:69`, `:71`, `:76`, `:155` | "Nineteen rows — sixteen profile-scoped", "Eleven are declared in `settings/Schema.lua`", "**Chat** (8)", "over the nineteen rows above" | **20** rows, **17** profile-scoped, **12** declared in `settings/Schema.lua` (9 Chat + 3 Popup: `add{` at `:152` through `:278`), **Chat (9)**. The table right below it already lists `notify.showRole` (`:97`), and `docs/settings-panel.md:346` already says Chat 9. |
| `docs/module-map.md:24` | "Eleven rows are declared here … giving nineteen rows … **Chat** (8)" | the same 12 / 20 / 9 |
| `docs/ARCHITECTURE.md:349` (the Tier 2 trigger cell) | "`core/Compat.lua` publishes six addon-specific shims" | `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **9** (`RoleToken`, `AssignedRole` and `RoleIconMarkup` joined). `docs/module-map.md:127` already says "the nine". The trigger fires either way, so the status is honest and only the count is wrong. |
| `docs/compat-layer.md:16-17` and its shim table (`:23-30`) | "**Six shims**, counted the way `documentation-§3` counts them", quoting `grep -cE '^\s*function\s+[A-Za-z_.]+\.'` | 9 by either grep. The quoted pattern is not `documentation-§3`'s. The table lists six, and the role shims are documented only in the section at `:109`. |
| `core/Compat.lua:3` | "Loaded first among the addon files (see WhatGroup.toc)" | The TOC loads `CoreSetup`, `MediaSetup` and `Util` before it (`WhatGroup.toc:46-54`) |
| `.luacheckrc:71` | "`tests/loader.lua:129` CLEARS it" | the clear is at `tests/loader.lua:132` |
| `.luacheckrc:102` | "The sibling handler at :707 does read it" | `:707` is a comment inside the teleport lookup. The handler is `WhatGroup:OnCombatStateChanged` at `core/WhatGroup.lua:1080`. |
| `DEPENDENCIES.md:46` | "`tests/loader.lua:134` calls `setfenv(chunk, env)`" | the call is at `tests/loader.lua:137` |
| `.pkgmeta:20-21` | "the only entries here that change a download. Three screenshots, 880K" | `git ls-files media/screenshots` → **2** files, `du -sh` → **216K**. The `media/logos/*.png` / `*.jpg` lines below also change a download. |
| `docs/module-map.md:130` | `performance.md` is "the `performance-§12` no-combat-path exemption + the committed whole-repo combat-path sweep" | the exemption ended 2026-08-06, and the page says so in its first paragraph. It documents the **declined** wiring and the sweep. |

Low: docs and comments only. No site is player-facing. **Fix:** correct each line in one sync pass, and
use the standard's own grep in `compat-layer.md`. See 04 §3.

---

## Info

### WG-48 — the automated-test record is 50 commits behind HEAD and has never recorded a sighted run · *carried, re-measured*
**Section:** `automated-tests-§1`, `§3` (*The complexity gate is sighted*), `§4`, `§6`, anti-pattern
#51 · **Where:** `docs/automated-tests/RESULTS.md:35` (newest row), `docs/automated-tests/20260927-031637/manifest.json:10`, `:16`

| | Recorded `20260927-031637` (`62680d3`) | HEAD `57a08e9`, sighted runner, `--no-bundle` |
|---|---|---|
| NLOC | 12183 | **13412** |
| Functions | 1591 (raw `lizard`, unsighted) | **1792** (sighted, parity clean) |
| Max CCN | 13 | **15** (`encode` in `tests/perf.lua`) |
| CCN warnings | 0 | 0 |
| `blindFiles` | *not recorded* (kit 34) | **0** |
| Files in the 1000–1500 band | 2 | **3** (`tests/test_libka0s.lua` 1037 entered; `core/WhatGroup.lua` 1161 → 1313, `modules/Frame.lua` 1211 → 1319) |
| Tests | 824/0/824 | **914/1/915** |
| `luacheck` files | 56 | **59** |

- Distance: `git rev-list --count 62680d3..HEAD` → **50**.
- The newest bundle predates kit revision 35. Its manifest carries no `suites.complexity.blindFiles`,
  so the record holds no sighted measurement at all. `1d64539` ran the sighted suite once on
  re-vendoring (maxCcn 15, blindFiles 0) and kept no bundle.
- Nothing crossed a threshold. Neither band file reached its stated re-check at 1450.
- The watch list's two **Accepted** entries have each been carried by one release run (1 of 3), so
  this is not #53. `tests/test_libka0s.lua`'s band entry will be new and blank at the next run.
- `RESULTS.md:15` still names `/wow-addon:bump-version`. That is runner-generated text and is rewritten
  by the next run.
- The checkpoint is the release, and there has been none since 1.5.0 (`20260927-030357`). That keeps
  this at Info.

**Fix:** the next release run is a full four-suite bundle on kit 37, which is the record's first
sighted bundle. Disposition `tests/test_libka0s.lua` in it, and record its function count as *newly
measured*, not *newly crossed* (`automated-tests-§3`). See 04 §4.

---

## Closed since 2026-09-23

Measured today, not assumed. The evidence is in 03 §E.

| ID | Closed by | Evidence today |
|---|---|---|
| WG-64 | `4d7f5d0` (plan WG-01) | `NS.StandDown` unregisters the callback (`core/WhatGroup.lua:423`), and `NS.StandUp` re-registers it |
| WG-65 | same | the hub now says the `EventRegistry` callback is gone while disabled (`docs/ARCHITECTURE.md:169-170`, `:180`) |
| WG-66 | same, plus `586e8d6` (plan WG-10) | `tests/test_disabled.lua:75-79` surveys `EventRegistry` callbacks, and `:150` names the mutation |
| WG-57 | rule change (v2.65.0 `architecture-§4` amendment) | the shell plus one feature module that registers no event is below the threshold. Hub `:127-137` |
| WG-61, WG-63 | `a9a2631` (plan WG-22) | the rows cite `F-006 (docs/reviews/2026-08-05/)` and `WG-37 (docs/audits/2026-08-05/)`, and both resolve. `tests/test_register.lua` holds the key. |
| WG-67 | `7716a32` (plan WG-06) | four `NS.SafeRegisterEvent` calls, and rejections surfaced. One bare call remains, which is WG-84, a new and narrower finding. |
| WG-68 | `ca66be1` (plan WG-05) | `modules/Frame.lua` registers no event, and its deferrals go on the combat-end queue drained by the addon's handler |
| WG-69 | `16eceb4` (plan WG-16) | no `NS.Debug(` call site concatenates its message |
| WG-70 | `e443552` (plan WG-20) | `WhatGroup.toc` annotates `core\Compat.lua` and `core\Util.lua` |
| WG-72 | `e872a1e` (plan WG-14) | by-name parity for Launcher and Lifecycle (`tests/test_surface_parity.lua:207`, `:223`) |
| WG-73 | `9fe6cea` and later | 889 `filename-§N` citations in live authored files; 0 malformed, 0 out of range, 0 retired dotted |
| WG-74 | upstream kit | 0 `§`-less citations in `tests/_kit/*.lua` (kit 37) |
| WG-75 | `e85c662` (plan WG-24) + v2.68.0 | `compat-layer.md` documents only host shims. `debug.md`'s trigger now fires in every addon (diagnostics). |
| WG-76 | `45a2eac` (plan WG-28) | hub 393 lines |
| WG-78 | `a9a2631` | the row's Rule cell reads `localization-§1` |
| WG-79 | `581724e` (plan WG-27) | `DEPENDENCIES.md` names Python 3 + Pillow and "lizard required at release" |
| WG-80 | `feab72b` (plan WG-17) | `settings/Panel.lua:96` builds the path from the folder name |
| WG-81 | `8148df2` (plan WG-13), M6-WG | the launcher has no host refusal literal; the retired fields are gone (`core/LauncherSetup.lua:210`) |
| WG-82 | upstream | `AUDIT.md` now grades the re-vendor check by step 5. `toc-file-§3` carries no Interface literal. `layout-§4` now says the `.png` is excluded from the package. |
| WG-83 | `93531c0` (plan WG-18) | `exclude_files` includes `docs/revendor/` (`.luacheckrc:18`) |
| WG-56 | upstream (v2.41.0+ wording) | Tier 1 now names a `Page \| Covers` table, and `docs/settings-panel.md:336` carries one |

## Recorded as compliant, not as omissions

Measured and passing, so no row is filed.

- **`layout`:** §1 (skeleton; census present, current and gated; no generator) through §4 (TGA type
  2, 128², 32 bpp).
- **`toc-file`:** §1–§5. Every load-bearing line is annotated and every TOC line citation resolves.
- **`library-stack`:**
  - §1–§3.
  - §7: whole payload, both `diff -r` empty, provenance only in `CLAUDE.md`, ten majors with stubs.
  - §8: seam fed `addonName`, one `RegisterLSM`, no private media.
- **`architecture`:** §1–§7, with §4 below threshold. Named state is written down. There is no
  registry.
- **`savedvariables`:** all five sections.
- **`options-ui`:**
  - §1: `addonName` passed; stubs; route (b) under its row.
  - §2: no second lock, nothing closes the settings window in combat.
  - §5, §9, §12.
  - §13–§15: a strip on General, one band, the composed `Master controls` block, and a test mode that
    ends and is refused in combat.
  - §16–§18 do not engage.
- **`standalone-windows`:** one `MakeCloseButton` wrapper (`core/CoreSetup.lua:163-165`) and its
  degraded twin (`:100`). The two rows above.
- **`preview-mode`:** compliant.
- **`launcher`:** §1–§5. One object, label, four menu pairs matching `ADDONS.md`, `debug` and
  `debugAtEnable`, no `onTooltipShow`, `global.minimap.shown` exempt from reset.
- **`slash-commands`:** §1–§8. The stand-down is one latch with no second path. Registrations are
  unregistered, apart from WG-84's transient, which is unregistered on fire. The live surface is built
  on `lib.LIVE_VERBS` plus `profile`, and the conformance suite asserts on the registration set.
- **`debug-logging`:**
  - §1–§14.
  - The diagnostics check, items 1–7.
  - The library's-own-lines check, items 1–6: sink passed to all four descriptors, `debugAtEnable`,
    no host edge line, the console's gates used, stub parity.
- **`localization`:** §1 via its row, §2–§5. The prose gate is wired.
- **`events-frames-taint`:** §2–§7, and §8 via its row. §1 apart from WG-84.
- **`compat`:** a single `Compat` file wired onto `LibKa0s-Compat-1.0`.
- **`public-api`:** not engaged.
- **`packaging`:** checks (a), (b) and (c) clean.
- **`line-endings`:** all seven sections. Canonical body, (e) = 0, kit gate wired.
- **`lint`:** 0/0 over 59 files, test tree in scope, no top-level `ignore`.
- **`testing`:**
  - §1–§15.
  - The vendor gate passes against v1.70.0.
  - Inventory and badge in sync, with the skip excluded from both figures.
  - `test_lizard_sighted` is wired.
  - Every run is bounded.
- **`performance`:** via the ratified §12 row. `tests/perf.lua` and `docs/performance.md` are present,
  and the sweep is current.
- **`automated-tests`:** §2 (runner vendored, `100755`) and §3's sighted gate (kit 37, wired, no local
  scanner, no raw-`lizard` gate line). The record itself is WG-48.
- **`documentation`:**
  - §1: README order, badges, bullets, Reporting a bug, Credits.
  - §2 and §4.
  - §3: tiers, four tables, no orphans, hub shape.
  - §6, §7 apart from WG-77's one line, and §9.
  - §5 is WG-77.
- **`audit-review-history`:** the register MUSTs are met, `LEDGER.md` is absent, and issues are
  labeled and prefix-free. The re-vendor MUST is WG-71.
- **`naming-cheatsheet`, `versioning-git`.**

Anti-patterns clear: **#1–#76 and #78–#92**. #77 is not auditable.
- #54 is clear: no `or`-defaulting over stored fields was introduced since the last run.
- #85 is clear: the stand-down is a latch with no draw-gate survivor.
