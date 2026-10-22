# Decisions (WhatGroup, LibKa0s v1.71.0 to v1.75.0)

This run had no interview and filed no GitHub issue. The 2026-10-22 run's milestone M2 is
non-interactive, and its `inputs/OWNER_SCOPE.md` section A decides every candidate. Each decision
below cites that file as its source.

| Candidate | Decision | Source |
|---|---|---|
| `W.SearchBox` (Widgets 13) | Not adopted | OWNER_SCOPE A #52: adopters are LootHistory, BankLedger and DropWatcher. Widgets is declined here (#12) |
| `W.TestStrip` (Widgets 13) | Not adopted | OWNER_SCOPE A #48 (adopters are DropWatcher, LootHistory, BankLedger and MultiMeters) and F (WhatGroup's "Test Group - ..." content is its marker) |
| `LibKa0s-Glow-1.0` | Not adopted | OWNER_SCOPE A #56: adopters are DropWatcher, QuickComms and KickCD |
| `Item.BonusIDsFromLink` (Item 3) | Not adopted | OWNER_SCOPE A #51: adopters are BankLedger and LootHistory |
| `O.Drawer` (OptionsDrawer 1) | Not adopted (stub no-op only, blocker a) | OWNER_SCOPE A: not a named adoption; the panel has nothing to fold away |
| `LibKa0s-Sim-1.0` | Not adopted in this run | OWNER_SCOPE A #54: [WhatGroup#24](https://github.com/tusharsaxena/WhatGroup/issues/24) stays open, `state:triaged`, repointed at Sim-1.0 |
| Options 29 scroll keep, comment-only minors, DebugLogDiagnostics 3, Media 5, kit 39-41 | Carried by the re-vendor, no code change | this commit |

No decline issue was filed. The run files nothing in M2 (its ruling), and Sim's existing issue #24
already records it. Unreached: none.
