# Candidates (WhatGroup, LibKa0s v1.71.0 to v1.75.0)

Sources: `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` (56 commits), the tag's `CHANGELOG.md`
blocks v1.72.0 to v1.75.0 and their "What a consumer owes" lists, and the `docs/api/` documents
they link. The base, v1.71.0, comes from this repo's CLAUDE.md provenance line. The blockers in
01_DELTA.md 3g are not candidates and are not listed here.

## A. Delivered on the re-vendor alone

- **Options 29: a structural refresh keeps the scroll offset** (v1.73.0). `settings/Profiles.lua:86`
  refreshes the shown page structurally on a profile switch, and that refresh no longer jumps to the
  top. No code change (smoke SM-WG-4).
- **Core 11, DebugLog 20, OptionsIdList 5, PerfPanel 7** (v1.75.0, #57). Comment-only.
- **DebugLogDiagnostics 3** (v1.75.0). The `/wg diagnostics` header's `LibKa0s running:` line now
  names Glow, Sim, SimTimeline and SimPanel (smoke SM-WG-3).
- **Media 5 / MediaIcons 1** (v1.74.0). The catalog grows to 5,836 names. `NS.Icon` resolves the
  same three marks as before.
- **Kit 39-41.** `__fireUnconditional` reaches method-name handlers (the disabled-6 case is now real
  and green), the icon-declaration gate, and a crashed lizard run counted as a complexity fail.
- **Perf 15** (v1.72.0). Perf is declined here (#7), so it is carried and never wired.

## B. Host change required

- **`W.SearchBox`** (Widgets 13, #52; `docs/api/Widgets/version-13.1.4.3.2-docs.md`). The flat
  filter-bar search box. It would add a new dependency on the Widgets major, which is declined (#12),
  and WhatGroup has no filter bar. Additive.
- **`W.TestStrip`** (Widgets 13, #48). The test-mode strip. Not recommended: OWNER_SCOPE A #48 names
  the adopters (DropWatcher, LootHistory, BankLedger, MultiMeters), and OWNER_SCOPE F counts
  WhatGroup's "Test Group - ..." content as its preview marker. Additive.
- **`Item.BonusIDsFromLink`** (Item 3, #51). This addon reads no item links. Additive.
- **`O.Drawer`** (OptionsDrawer 1, v1.73.0). The slide-out drawer. The panel is bool, number and one
  enum across a few tabs, with no per-subject detail to fold away. Additive. The stub no-op is a
  blocker fix, not an adoption.

## C. Not consumed by this addon (whole-module)

- **`LibKa0s-Glow-1.0`** (#56). WhatGroup draws no glow. OWNER_SCOPE A names DropWatcher,
  QuickComms and KickCD as the adopters.
- **`LibKa0s-Sim-1.0`** (#53, #54). An in-game simulator. The addon's own recorded request is
  [WhatGroup#24](https://github.com/tusharsaxena/WhatGroup/issues/24), which stays open and
  `state:triaged`, repointed at Sim-1.0 by OWNER_SCOPE A #54. It is not built in this run (the run
  builds simulators in LootHistory and BankLedger only).
