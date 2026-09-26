# Decisions (WhatGroup)

- No adoption in this item: the sweep plan scopes the candidate interview out, and there are no candidates.
- `tests/loader.lua`'s hand-typed LIBKA0S list gains `OptionsRegistry.lua`, `OptionsIds.lua`, `OptionsIdList.lua` and `OptionsCombat.lua` in XML order, so the harness's XML-order case stays green.
- The library-absent stub in `settings/OptionsSetup.lua` needs nothing: there is no new public member, and the surface-parity case stays green unchanged.
- `docs/test-cases.md` regenerated: no change (823 cases; the kit adds none to this repo's suites).
- Plan: `Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/` (WG-ATS-RV, ATS-20, ATS-21).
