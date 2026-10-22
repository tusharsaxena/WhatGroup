# Summary (WhatGroup)

This is the LibKa0s v1.71.0 to v1.75.0 re-vendor, item WG-RV of the 2026-10-22 run. It was copied
from the local annotated tag `v1.75.0` (commit `265a89e`). The base comes from this repo's
CLAUDE.md provenance line, confirmed by the last payload commit and a payload-matches diff against
v1.71.0. Twelve library files move a minor and six arrive (`Glow.lua`, `MediaIcons.lua`,
`OptionsDrawer.lua`, `Sim.lua`, `SimTimeline.lua`, `SimPanel.lua`), for 40 files in all. The kit
moves from revision 38 to 41. Refs: LibKa0s#45, #46, #47, #55, #57.

- **Declaration:** `LibKa0s icons: close, copy, clear.` sits directly under the provenance line
  (`CLAUDE.md`). No provenance split was needed.
- **Prune** (`tools/prune-icons.lua` from the tag): kept 4 files, removed 5,836.
  - Open Iconic: 221 marks removed. `clear`, `close`, `copy` and `LICENSE-open-iconic.txt` are kept.
  - Phosphor: the whole `phosphor/` folder is removed (1,434 marks and its license).
  - Game-icons: the whole `game-icons/` folder is removed (4,178 marks, its license and
    `AUTHORS.txt`).
  - Compared with v1.71.0, which shipped 113 Open Iconic marks, the tracked icon folder goes from
    114 files to 4.
- **Delivered free (class A):** Options 29 structural refresh keeps the scroll offset (profile
  switch); the diagnostics header names Glow and Sim; and the comment-only minors (Core 11,
  DebugLog 20, OptionsIdList 5, PerfPanel 7). From the kit: 39's `__fireUnconditional`, 40's icon
  gate and 41's crashed-lizard fail.
- **Contract blockers, all fixed in this commit** (01_DELTA.md 3g):
  - (a) `H.Drawer` no-op in the Options stub.
  - (b) dead `H.__releaseChrome` mirror deleted (LibKa0s#45), and the stub comment's count fixed.
  - (c) disabled-6 now fires for real, with no stand-down reds.
  - (d) icon tests rewritten to the declaration (two new cases, one replaced, the `info.tga` check
    turned into an IdList-declares-info rule).
  - (e) `tests/loader.lua` follows the tag's XML order.
  - (f) kit 41 named in `DEPENDENCIES.md` and `docs/testing.md`.
- **README credit added:** `**Open Iconic** icons (the debug console's copy, clear and close marks),
  by Waybury, MIT license (<https://github.com/iconic/open-iconic>), with the license beside them in
  the bundled payload.` No Phosphor or Game-icons line, since neither set ships.
- **Dead stub mirrors removed:** `H.__releaseChrome` (`settings/OptionsSetup.lua`).
- **Docs:** `ARCHITECTURE.md`, `module-map.md`, `testing.md` and `common-tasks.md` (refresh recipe:
  `git archive` from the tag, prune, gate) now describe the `media/icons` carve-out. In
  `smoke-tests.md`, DIAG-12 and DIAG-13 name the blank-square failure, their Result lines are
  reset, and both are listed under Pending sign-off. `docs/test-cases.md` was regenerated and the
  README badge reads 935/935.
- **Adopted:** none. **Declined:** none filed (03_DECISIONS.md; Sim stays with WhatGroup#24).
  **Unreached:** none.

Gates (all through `ka0s-bounded`):

- Before the copy: tests 934 passed / 0 failed / 1 skipped.
- After the copy and the blocker fixes: tests 935 passed / 0 failed / 1 skipped, with
  `test_vendor_sync` green against tag v1.75.0 and the declaration.
- luacheck 0 warnings / 0 errors in 59 files.
- No authored `.lua` over 1500 lines.
- `git ls-files libs/LibKa0s/media/icons` lists 4 files.
- Smoke owed (owner): DIAG-12, DIAG-13, an INSTALL-1 rerun with a `/wg diagnostics` header check, and
  the profile-switch scroll check (run items SM-WG-1 to SM-WG-4).
