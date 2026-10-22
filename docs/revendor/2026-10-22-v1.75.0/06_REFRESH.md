# Refresh (WhatGroup)

Item WG-RV2 of the 2026-10-22 run. After WG-RV vendored LibKa0s from the local annotated tag `v1.75.0`
at commit `265a89e`, the tag moved twice before it was pushed: to `6bf5f3e` (LK-26: Sim minor 2,
SimTimeline minor 2) and then to `9e5c4e2` (LK-27: SimPanel minor 2), its final position. This file
records the refresh from `265a89e` to `9e5c4e2`. The files before it (01 to 05) are frozen and
describe the copy at `265a89e`.

- **Copy:** the same procedure WG-RV used. `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools`,
  `cp -r` of both ship folders whole, then the tag's `tools/prune-icons.lua` against the unchanged
  `LibKa0s icons: close, copy, clear.` line (kept 4 files, removed 5,836). No file existed only in
  the addon's copy, so nothing else was deleted.
- **Files that changed:** `libs/LibKa0s/Sim.lua`, `libs/LibKa0s/SimTimeline.lua` and
  `libs/LibKa0s/SimPanel.lua`, as expected. `tests/_kit/` is unchanged (kit revision 41).
- **New minors:** `LibKa0s-Sim-1.0` shell (`Sim.lua`) 1 to 2, `SimTimeline.lua` 1 to 2,
  `SimPanel.lua` 1 to 2.
- **Provenance:** the `CLAUDE.md` line stays `v1.75.0`, since the tag name did not change.
- **Addon ripple:** the `tests/loader.lua` comment that named the Sim files' minors now reads
  minor 2. Nothing else in the addon pins a Sim minor, and WhatGroup still does not adopt the Sim
  major (WhatGroup#24).
