# 05 — Execution plan (2026-09-23)

This plan orders every finding in `02_DEVIATIONS.md`: the Medium, the Lows and the Infos. It covers
**22 roots and 3 dependents**, and each step is tied to its ID. The design is in
`04_TECHNICAL_DESIGN.md`.

**Upstream comes first.** LibKa0s and WowAddonStandards change before this addon does. Then the whole
LibKa0s payload is re-vendored, and only then does work in WhatGroup begin.

**Gate for every WhatGroup commit** (`testing-§4`):
- `~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua`: all green.
- `~/.claude/wow-addon/bin/ka0s-bounded luacheck .`: 0/0.
- Regenerate `docs/test-cases.md` and the README `[tests]` badge in the same change whenever the case
  count moves (`testing-§5`).

Each sprint ends at a green, committable checkpoint, so the plan can be resumed at any sprint
boundary.

---

## Sprint U — upstream (outside this repo; blocks Sprint R)

- [ ] **U1 (WG-74)** — in `LibKa0s/testkit/` (`test_prose.lua`, `test_eol.lua`,
  `test_layout_cap.lua`, `framework.lua`, 74 lines), spell citations as `filename-§N`, or record an
  ASCII exception upstream (04 §0).
  - Bump the kit revision.
  - Library suites green.
- [ ] **U2 (WG-66, optional collection-wide half)** — add an `EventRegistry` fake plus a callback
  survey to `testkit/mock_base.lua` / `mock_record.lua` (04 §0).
  - If U2 is declined, S2-4's local survey is still the fix.
- [ ] **U3** — tag a LibKa0s release that carries U1 (and U2).
- [ ] **U4 (WG-82)** — `WowAddonStandards`:
  - (1) `AUDIT.md` step 4's re-vendor check: "High" → "grade by impact (step 5)".
  - (2) `toc-file-§3`: "currently `120007`" → `120100`, or remove the literal.
  - (3) `layout-§4`: say whether "ships" is normative for the `.png` source.
- [ ] **U5 (WG-56)** — `documentation-§3` Tier 1 row: `Tab | Covers` vs "one row per settings
  subcategory". Pick one wording.
- [ ] **U6 (WG-57)** — `architecture-§4` applicability: does an AceAddon shell's own event handling
  count as "a module that registers game events"? Record the answer, and pick 04 §6's branch A, B or C.

## Sprint R — re-vendor LibKa0s whole (after U3)

- [ ] **R1** — copy `../LibKa0s/LibKa0s/` → `libs/LibKa0s/` and `../LibKa0s/testkit/` → `tests/_kit/`,
  both **whole folder**. Bump `CLAUDE.md:79`'s provenance line to the U3 tag **in the same commit**.
  Run `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`.
- [ ] **R2 (WG-71)** — write `docs/revendor/<date>-v<tag>/01_DELTA.md` + `05_SUMMARY.md` as a
  **consolidated** bundle. It gets a *Backlog* section naming the 25 unrecorded tags (v1.18.0 → v1.24.0
  and v1.35.0 → v1.53.0, listed in 02 WG-71) and the three folded commits `f98ef41`, `127baa1` and
  `f74893a`.
  - **Do not** back-fill a folder per tag.
  - Re-run `AUDIT.md`'s bundle check. It must print nothing.
- [ ] **R3 (WG-74 lands)** — regenerate `docs/test-cases.md` (`lua tests/run.lua --list >
  docs/test-cases.md`). Confirm the four malformed case names are gone and the badge still matches.
- [ ] **R4** — gate:
  - `diff -r` the new tag's `LibKa0s/` against `libs/LibKa0s` and `testkit/` against `tests/_kit`.
    Both must be empty.
  - `tests/test_vendor_sync.lua` green.
  - Full suite green, lint 0/0.
- **Checkpoint R** — commit (re-vendor commit; `versioning-git` prefers it stand alone).

## Sprint S1 — stand-down: the Medium (WG-64, WG-65, WG-66)

- [ ] **S1-1 (WG-66 first, test-first)** — extend `regNames` in `tests/test_disabled.lua` (`:76-82`) to
  include `mock.EventRegistry.__callbacks("SetItemRef")`. Run the suite: step 3 must go **red** against
  today's code. That run is the falsification.
- [ ] **S1-2 (WG-64)** — `core/WhatGroup.lua`: extract `registerLinkCallback()` (file-load call kept).
  - `NS.StandDown` calls `EventRegistry:UnregisterCallback("SetItemRef", WhatGroup)`.
  - `NS.StandUp` calls `registerLinkCallback()`.
  - Reword the `:96-99` comment.
  - Suite green, with the `-- red under:` comment added at step 3.
- [ ] **S1-3** — add the smoke test to `docs/smoke-tests.md`: disable → enable → GameMenu Logout →
  click a details link. Run it in client.
  - If it taints, revert S1-2 and add a `slash-commands-§7` register row instead. WG-66 then stays open
    as its own root.
- [ ] **S1-4 (WG-65)** — `docs/ARCHITECTURE.md:158-161`, `:170`, `:238-241`: only the two
  `hooksecurefunc` rows survive.
- **Checkpoint S1** — commit.

## Sprint S2 — event registration (WG-67, WG-68)

- [ ] **S2-1 (WG-67, test-first)** — add a case seeding the kit mock's `__badEvents` with one of the four
  events. Assert the other three register, `Settings.Register` and `NS.Launcher:Register` ran, and the
  rejection is recorded. It is red today.
- [ ] **S2-2 (WG-67)** — add the `safeRegister` helper with the `C_EventUtils.IsEventValid` front gate
  and `pcall`, plus `NS.RejectedEvents`. Surface it in the `[Init]` summary, emitted on
  `/wg debug on`. Route `registerFeatureEvents` and `:347` through it.
- [ ] **S2-3 (WG-68, test-first)** — retarget the combat-defer cases in `tests/test_frame.lua` to drive
  `PLAYER_REGEN_ENABLED` through AceEvent.
- [ ] **S2-4 (WG-68)** — implement the pending-work queue drained from `OnCombatStateChanged`
  (04 §2).
  - Delete `buildWaitFrame` and the `f:RegisterEvent` in `deferTeleportUntilCombatEnds`.
  - `NS.FrameStandDown` clears the queue.
  - Keep `rawRegs` in `tests/test_disabled.lua` as the guard that no raw registration returns.
- [ ] **S2-5** — record the probing trade in `docs/midnight-quirks.md` (`events-frames-taint-§1`).
- **Checkpoint S2** — commit.

## Sprint S3 — debug sink, TOC, launcher literal (WG-69, WG-70, WG-81)

- [ ] **S3-1 (WG-69)** — rewrite the 16 sites in 03 §E to `NS.Debug(tag, fmt, …)`. Re-run the §E
  census. It must report 0, apart from the known `settings/OptionsSetup.lua:188` vararg false positive.
- [ ] **S3-2 (WG-69 follow-on)** — amend the `events-frames-taint-§8` register row (`:504`). The
  pre-formatting half no longer describes the tree, and only the two `pout` fallbacks remain.
- [ ] **S3-3 (WG-70)** — add the load-bearing comment above `WhatGroup.toc:42`, naming
  `core/WhatGroup.lua:87`, and a conventional note for `core\Util.lua`.
- [ ] **S3-4 (WG-81)** — `core/LauncherSetup.lua:151-152`: drop the `"Ka0s WhatGroup is disabled."` literal.
- **Checkpoint S3** — commit.

## Sprint S4 — tests (WG-72, WG-63)

- [ ] **S4-1 (WG-72)** — `tests/test_surface_parity.lua`: add by-name parity cases for
  `LibKa0s-Launcher-1.0` and `LibKa0s-Lifecycle-1.0`, each with its grep named in a comment.
  - Register their live instances with `Kit.setSurfaceSource` in `tests/run.lua`.
  - Rewrite the header inventory (`:1-43`).
- [ ] **S4-2 (WG-63)** — `tests/test_register.lua`:
  - resolve `-R-`/`F-` ids against `docs/reviews/` rather than skipping them (`:94`);
  - drop a bundle's *Recorded deviations* echo from `isAssigned`'s corpus (`:59-77`).
  - It must go **red** against today's `:503`/`:504` before S5-1 fixes them.
- **Checkpoint S4** — commit only after S5-1 turns S4-2 green. Land S4-2 and S5-1 together.

## Sprint S5 — docs and register (WG-61, WG-78, WG-75, WG-76, WG-77, WG-79, WG-73, WG-80, WG-83, WG-57)

- [ ] **S5-1 (WG-61)** — `docs/ARCHITECTURE.md:503` `WG-R-06` → `F-006`, and `:504` `WG-A-08` →
  `WG-37`. Extend the key at `:494-498`. S4-2 goes green.
- [ ] **S5-2 (WG-78)** — `:503` Rule cell → `` `localization-§1` ``.
- [ ] **S5-3 (WG-75)**:
  - Trim `docs/compat-layer.md` to the six addon shims, with a pointer for the two library members.
  - Change `:464` from "eight" to "six".
  - Trim `docs/debug.md` to the addon's own content and set `:462`'s row honestly, or mark it Not
    applicable and move the tag vocabulary to Tier 3.
- [ ] **S5-4 (WG-76)** — spill `## The stand-down` to `docs/stand-down.md` (Tier 3 row) and
  `## Load order`'s per-file list to `docs/module-map.md`.
  - `wc -l docs/ARCHITECTURE.md` ≤ ~400.
  - Update `tests/test_docmap.lua` and `tests/test_doc_structure.lua` if they pin anything that moved.
- [ ] **S5-5 (WG-77)** — apply the eight corrections in 02's WG-77 table. README `:41`/`:48` go
  through the de-AI pass (`documentation-§1`).
- [ ] **S5-6 (WG-79)** — `DEPENDENCIES.md`:
  - add Python 3 + Pillow under *Release / assets*, with install and verify lines, citing `layout-§4`;
  - relabel lizard "optional per commit, required at release".
- [ ] **S5-7 (WG-73)** — fix the five malformed citations: `core/LauncherSetup.lua:143`,
  `tests/prose_waivers.lua:2`, `:4`, `tests/run.lua:140`, `:145`. Re-run the §F sweep. It must print 0
  authored malformed hits.
- [ ] **S5-8 (WG-80)** — `settings/Panel.lua:87`: build the landing-logo path from `addonName`.
- [ ] **S5-9 (WG-83)** — `.luacheckrc:17`: add `"docs/revendor/"`, and update
  `tests/test_lintconfig.lua` if it pins the list.
- [ ] **S5-10 (WG-57)** — apply U6's outcome:
  - (C) nothing to change, WG-57 closes;
  - (B) add an `architecture-§4` register row with re-check trigger "a second feature module, or a
    second consumer of the join data";
  - (A) the minimal bus of 04 §6, with its stand-down wiring and `## Message Bus` documentation.
- **Checkpoint S5** — commit.

## Sprint S6 — record (WG-48; plus WG-56 and WG-82 once upstream lands)

- [ ] **S6-1 (WG-48)** — at the next release, run `tests/_kit/run-automated-tests.sh` with all four
  suites from a clean tree. This is the first kit-revision-25 run, and it emits the commit and
  clean/dirty cells.
  - Disposition `core/WhatGroup.lua` (band 1000–1500) in `RESULTS.md`.
  - Write `ANALYSIS.md`.
  - The release gate is all four at `pass` plus 0 CCN > 15. HEAD max is 14.
- [ ] **S6-2 (WG-56, WG-82)** — when U4/U5 land and the standard is re-fetched, re-check
  `docs/settings-panel.md`'s table and `.pkgmeta:30-31` against the amended text. Nothing changes here
  unless the amendment makes one of them normative.
- **Checkpoint S6** — the release commit.

---

## Closure check (for the next audit)

| ID | Closed when |
|---|---|
| WG-64 | `grep -n 'UnregisterCallback("SetItemRef"' core/WhatGroup.lua` hits inside `NS.StandDown`. The smoke test is recorded clean. |
| WG-65 | `docs/ARCHITECTURE.md` has no survivor claim other than the two `hooksecurefunc` rows. |
| WG-66 | `regNames` reads `EventRegistry` callbacks, and a `-- red under:` names the unregister. |
| WG-67 | A `__badEvents` case is green, and `NS.RejectedEvents` is reachable via `/wg debug on`. |
| WG-68 | `git ls-files 'modules/*.lua' \| xargs grep -n ':RegisterEvent('` returns nothing. |
| WG-69 | §E's census returns only the vararg false positive. |
| WG-70 | `WhatGroup.toc` has a comment above `core\Compat.lua` naming `core/WhatGroup.lua:87`. |
| WG-71 | `AUDIT.md`'s bundle check prints nothing. |
| WG-72 | The parity suite has Launcher and Lifecycle cases. |
| WG-73, WG-74 | The §F sweep prints 0 malformed hits in authored files and in `docs/test-cases.md`. |
| WG-75 | `compat-layer.md` documents only the 6 counted shims, and the `debug.md` row is honest. |
| WG-76 | `wc -l docs/ARCHITECTURE.md` ≤ ~400. |
| WG-77 | All eight 02-table lines are corrected. |
| WG-78, WG-61, WG-63 | The register rows cite `localization-§1`, `F-006` and `WG-37`, and `tests/test_register.lua` resolves `-R-`/`F-` ids. |
| WG-79 | `DEPENDENCIES.md` names Pillow, and lizard's release role is stated. |
| WG-80 | `settings/Panel.lua` derives the logo path from `addonName`. |
| WG-81 | There is no refusal literal in `core/LauncherSetup.lua`. |
| WG-83 | `.luacheckrc` excludes `docs/revendor/`. |
| WG-57 | U6's answer is applied (C, B or A). |
| WG-48 | The next release bundle's row is at HEAD with its commit cells. |
| WG-56, WG-82 | Upstream text is amended. |
