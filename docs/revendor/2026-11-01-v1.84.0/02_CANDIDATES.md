# Candidates (WhatGroup, LibKa0s v1.83.0 to v1.84.0)

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the tag's `CHANGELOG.md` block v1.84.0
and the `docs/api/` documents it links. The stub member is a blocker (`01_DELTA.md`), not a candidate.

## A. Delivered on the re-vendor alone

- **The peels.** Pure moves, so no pixel or public member changes.
- **The WoW Default measure.** No size moved.
- **The note and reset walks** (Slash 21, Options 35, Schema 3). This schema holds no `note` row.
- **The drag handle's scale measure and show re-fit** (WidgetsDragHandle 10). This addon draws no
  strip: `grep -rn DragHandle core modules settings` finds nothing.
- **The diagnostics identity line** (DebugLogDiagnostics 6) gains Charts when the major is loaded.
  `/wg debug diagnostics` output is the only change a player could read.

## B. Host change required

- **Flow seams `beforeGroup` and `afterSubgroup`** (OptionsFlow 2). Additive. `settings/Panel.lua`
  passes `afterGroup` only and needs nothing else. Recommendation: decline.
- **The `note` row** (OptionsFlow 2, Schema 3). Additive. Nothing here carries a free-standing note.
  Recommendation: decline.
- **`O.PositionBlock`** (OptionsCompose 15). The popup has no X and Y rows; it is placed by dragging.
  Recommendation: decline.
- **`O.PageBanner{ acts }`** (OptionsTabs 13). `settings/Panel.lua` records why this addon has no
  banner. Recommendation: decline.

## C. Whole-module adoption

- **`LibKa0s-Charts-1.0`.** This addon draws no charts. Recommendation: decline.
- **Perf and Bus** stay declined on the recorded grounds in `docs/ARCHITECTURE.md`. Nothing in this
  range moves those premises.
