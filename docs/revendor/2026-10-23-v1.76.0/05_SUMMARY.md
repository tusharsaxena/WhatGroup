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

## Addendum: the tag moved (WG-RV2)

LibKa0s item LK-91 moved the local annotated tag `v1.76.0` from commit `9949368` to `7e81ff7`
("bound step-panel labels before the command column"), so the step-panel label truncates with an
ellipsis instead of running under the slash-command column. Item WG-RV2 re-vendored both payloads
whole from the moved tag and re-ran `tools/prune-icons.lua` (kept 4 files, removed 5,836). The
provenance line already read v1.76.0 and is kept.

- **Changed files:** `libs/LibKa0s/SimPanel.lua` (the step-panel label fix; SimPanel minor stays
  5) and `libs/LibKa0s/PerfPanel.lua` (the same fix in the perf copy of the
  renderer, PerfPanel minor 7 to 8). The kit
  (`tests/_kit/`) is unchanged; kit revision 41.
- **Contract blockers:** none. WhatGroup consumes neither panel directly.
- Gates: tests 942 passed / 0 failed / 1 skipped (`test_vendor_sync` green against the moved
  tag), luacheck 0 / 0 in 59 files, no authored `.lua` over 1500 lines (largest 1427).
- Smoke owed: none.
