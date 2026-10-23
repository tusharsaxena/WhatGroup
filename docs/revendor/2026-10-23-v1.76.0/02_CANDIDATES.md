# Candidates (WhatGroup, LibKa0s v1.75.2 to v1.76.0)

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` (8 commits), the tag's `CHANGELOG.md`
block v1.76.0, and the `docs/api/` documents it links. The base, v1.75.2, comes from this repo's
CLAUDE.md provenance line. 01_DELTA.md 3g found no blockers.

## A. Delivered on the re-vendor alone

- **Nothing that reaches this addon at runtime.** Both moved majors, Widgets and Sim, are carried and
  never looked up here. The client still loads every file of the XML, so the new minors win
  LibStub's comparison in any session where WhatGroup's copy is the newest. That is harmless, since
  the changes are additive (Widgets 14) or affect only a Sim host's own panel (SimTimeline 3,
  SimPanel 5).

## B. Host change required

- **`W.TestStrip` `kind = "sim"`** (Widgets 14; `docs/api/Widgets/version-14.1.4.3.2-docs.md`). The
  simulation flavor of the mode strip. Not a candidate here, because WhatGroup has no simulator and
  no strip. OWNER_SCOPE C and 03_SPEC end state 2 rule that WhatGroup keeps its marker: the sample's
  "Test Group - ..." content.
- **Sim auto-run** (SimTimeline 3 / SimPanel 5; `docs/api/Sim/version-2.3.5-docs.md`). This only
  matters to a Sim host. WhatGroup's simulator request is
  [WhatGroup#24](https://github.com/tusharsaxena/WhatGroup/issues/24), which stays open and
  `state:triaged`. Any simulator built for it gets the auto-run behavior by construction.

## C. Release-process change (not a library surface)

- **The release re-look of preview and simulation data** (LK-25 in the library's
  `docs/releasing.md`; standard v2.87.0 preview-mode, *Kept current at every release*). For this
  addon it covers `WhatGroup:SampleInfo()` at each version bump. It is recorded in
  `docs/common-tasks.md`, *Bump the addon version*, by the standards half of this item.
