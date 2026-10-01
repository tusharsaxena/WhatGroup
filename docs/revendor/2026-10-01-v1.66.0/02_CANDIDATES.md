# Candidates (WhatGroup)

Listed, **not interviewed** this cycle: spec S4 of the 2026-10-01 GitHub issue pass defers adoption,
and its GI-LK-13 consumer census picks these up.

| # | Class | Surface | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|---|
| C1 | B | Slash 19: the host `parse` receives `textOf`; pass it on as `lib.ParseValue(row, text, textOf)` | `docs/api/Slash/version-19.1-docs.md:59`, `:595`, `:759`; CHANGELOG v1.66.0 `### Slash minor 19` | `settings/Slash.lua:224-241` | Adopt next cycle: the descriptor's `L.ERR_BOOL` then reaches the refusal through the library and the `err == lib.STRINGS.ERR_BOOL` remap (`:237-238`) can go | Replaces host code (a 4-line remap); `tests/test_slash.lua` already pins the refusal wording |
| C2 | A | DebugLog 19, Slash 19 `lib:New` helper hoists | CHANGELOG v1.66.0 `### DebugLog minor 19, and what else ...` | none | Delivered on the copy | none |
| C3 | — | OptionsWidgets 34 `RenderGrid(ctx, items, parent, opts)`, OptionsTabs 8 `untabbedSkipRender` / `disabledReplaces` / `rerender`, WidgetsReorder | CHANGELOG v1.66.0 `### OptionsWidgets minor 34`, `### OptionsTabs minor 8`, `### Widgets minor 12` | none | Not applicable: WhatGroup draws no grid, tabbed schema page or reorder list of its own | none |
| C4 | C | Perf 14 (`PerfSampler`, `PerfCommands`, budgets, zero-count parents) | CHANGELOG v1.66.0 `### Perf minor 14 ...` | — | Settled decline on structural grounds (#7, LIBKA0S-15, `CLAUDE.md` Hard rules); nothing in v1.66.0 moves its premise | — |
