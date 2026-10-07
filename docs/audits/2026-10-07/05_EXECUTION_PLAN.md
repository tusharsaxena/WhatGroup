# 05 — Execution plan (2026-10-07)

This is the hand-off to the remediation engagement. Every step names its deviation ID. The design is in
`04_TECHNICAL_DESIGN.md`. **Figures here match `02_DEVIATIONS.md`:**
- 4 roots, 0 dependents, 3 MUST failures, all Low; plus 1 Info.
- 20 schema rows (12 declared, Chat 9).
- 9 Compat shims.
- 2 unrecorded tags (v1.69.0, v1.70.0).
- 50 commits since the last record.

Gate for every code commit: `ka0s-bounded lua tests/run.lua` (today 914/1/915, exit 0) and
`ka0s-bounded luacheck .` (0/0 in 59 files). Regenerate `docs/test-cases.md` and the README badge when
the case count moves (`testing-§5`). Commit subjects start with the ID (`WG-84: …`).

## Sprint 1 — code (one commit)

- [ ] **WG-84.** Write the test first. Add a case to `tests/test_disabled.lua`:
  - `__badEvents = { PLAYER_REGEN_ENABLED = true }` after login;
  - a popup that owes a `Hide`;
  - combat on, then disable;
  - assert that `NS.StandDown` completes, the four feature registrations are gone, and
    `NS.RejectedEvents` holds the name once.

  Run the suite and see the case go **red** against `core/WhatGroup.lua:436`.
- [ ] **WG-84.** Replace `:436` with
  `NS.SafeRegisterEvent(self, "PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded", NS.RejectedEvents)`.
  Confirm the case goes green and add its `-- red under:` line.
- [ ] **WG-84.** Regenerate `docs/test-cases.md` and set the README badge to 915/915 (one case added).
  The badge count assumes nothing else moved, so re-read the `## Totals` table.
- [ ] Green gate, then commit `WG-84: route the stand-down's owed-Hide registration through SafeRegisterEvent`.

## Sprint 2 — docs and record (two commits)

- [ ] **WG-71.** Create `docs/revendor/2026-10-07-v1.69.0-v1.70.0/01_DELTA.md`, with line 1 exactly
  `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`, then the per-tag delta (04 §2).
- [ ] **WG-71.** Create `05_SUMMARY.md` with one line per tag: carried by sweep (`9677d99`,
  `3fd8a2f`), nothing adopted, Widgets declined (#12).
- [ ] **WG-71.** Re-run `AUDIT.md`'s re-vendor loop (03 §C.6). `unrecorded:` prints nothing. Commit
  `WG-71: span bundle for the v1.69.0 and v1.70.0 re-vendors`.
- [ ] **WG-77.** Hub `docs/ARCHITECTURE.md:69`, `:71`, `:76`, `:155`: twenty / seventeen / twelve /
  Chat (9).
- [ ] **WG-77.** `docs/module-map.md:24`: twelve / twenty / Chat (9). `:130`: `performance.md` describes
  the declined wiring, not the exemption.
- [ ] **WG-77.** `docs/ARCHITECTURE.md:349`: nine shims. `docs/compat-layer.md:16-17`: "Nine shims" with
  the standard's grep verbatim, and the Role group added to the table at `:23-30`.
- [ ] **WG-77.** `core/Compat.lua:3`: drop "Loaded first among the addon files" for the true position.
- [ ] **WG-77.** `.luacheckrc:71` → `tests/loader.lua:132`. `.luacheckrc:102` → name
  `OnCombatStateChanged` (`:1080`).
- [ ] **WG-77.** `DEPENDENCIES.md:46` → `tests/loader.lua:137`.
- [ ] **WG-77.** `.pkgmeta:20-21`: two screenshots, about 220K, and not "the only entries" that change
  a download.
- [ ] **WG-77.** Re-run 03 §C.2 and §C.4. Every citation resolves and every count matches. Run the green
  gate, because `tests/test_lintconfig.lua` reads `.luacheckrc`. Commit
  `WG-77: roll the doc counts and comment citations to the tree`.
- [ ] Run `/dev-copilot:sync-docs`. Point `CLAUDE.md`'s "newest frozen compliance snapshot" at
  `docs/audits/2026-10-07/`.

## Sprint 3 — at the next release (no separate commit)

- [ ] **WG-48.** Run the full four-suite runner (bounded) on kit 37 as part of the release change. This
  is the record's first sighted bundle:
  - confirm `suites.complexity.blindFiles` = 0;
  - in `ANALYSIS.md`, mark the function-count jump (1591 → ~1792) as *newly measured*;
  - disposition the new band entry `tests/test_libka0s.lua`;
  - carry the `core/WhatGroup.lua` and `modules/Frame.lua` dispositions (both under their 1450
    re-check).
- [ ] **WG-48.** Confirm that `RESULTS.md` no longer names `/wow-addon:bump-version`.

## Done when

- `02_DEVIATIONS.md`'s three Low roots are closed by commits whose subjects start `WG-84:`, `WG-71:` and
  `WG-77:`.
- WG-48 is closed by the release bundle.
- A re-run of this audit's mechanical checks (03 §A–§D) reports:
  - the re-vendor loop with nothing unrecorded;
  - no bare `RegisterEvent` in shipped source;
  - all 48 file:line citations resolving;
  - the hub's counts equal to the tree.
- The six register rows stay accepted, and their triggers are re-evaluated at the next audit.
