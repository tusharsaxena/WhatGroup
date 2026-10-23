# Summary (WhatGroup)

This is the LibKa0s v1.75.2 to v1.76.0 re-vendor, item WG-RV of the 2026-10-23 run. It was copied
from the local annotated tag `v1.76.0` (commit `9949368`). The base comes from this repo's CLAUDE.md
provenance line, confirmed by the last payload commit (`8cbd735`) and a payload-matches diff against
v1.75.2.

- **Moved:** three library files, Widgets 13 to 14, SimTimeline 2 to 3 and SimPanel 4 to 5. None
  arrives or leaves; there are still 40 files. Kit revision 41 is unchanged.
- **Declaration:** `LibKa0s icons: close, copy, clear.` is kept as is.
- **Prune** (`tools/prune-icons.lua` from the tag): kept 4 files, removed 5,836. The tracked icon
  folder stays at 4 files, so the README's Open Iconic credit is unchanged.
- **Contract blockers:** none. Neither moved major is consumed here.
- **Addon ripple:** the `tests/loader.lua` Sim comment names the v1.76.0 minors. The CLAUDE.md
  provenance line reads v1.76.0.
- **Span bundle:** `docs/revendor/2026-10-23-v1.75.1-v1.75.2/` records the two tags vendored
  earlier on 2026-10-23 without a bundle.
- **Adopted:** none. **Declined:** none filed (03_DECISIONS.md). **Unreached:** none.

Gates (all through `ka0s-bounded`):

- Before the copy: tests 941 passed / 1 failed / 1 skipped. The failure was the eol gate:
  `docs/smoke-tests.md` was bare LF on disk while the index held CRLF, left over from an earlier
  write that bypassed git's filters. It was repaired with `rm` and `git checkout`, so there is no
  content change.
- After the copy: tests 942 passed / 0 failed / 1 skipped, with `test_vendor_sync` green against
  tag v1.76.0 and the declaration.
- luacheck 0 warnings / 0 errors in 59 files.
- No authored `.lua` over 1500 lines (largest: `modules/Frame.lua`, 1427).
- Smoke owed: none. No runtime surface of this addon moved.
