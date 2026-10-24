# Summary (WhatGroup)

This is the LibKa0s v1.76.0 to v1.77.0 re-vendor, item WG-RV of the 2026-10-24 run. It was copied
from the local annotated tag `v1.77.0` (commit `78240f7`). The base comes from this repo's CLAUDE.md
provenance line, confirmed by the last payload commit (`ec996a4`) and a payload-matches diff against
v1.76.0.

- **Moved:** twelve library files (01_DELTA.md 3c), and one new, `OptionsKeybinds.lua`, so the XML
  now lists 41 files. Kit revision 41 to 42, with three new kit files.
- **Declaration:** `LibKa0s icons: close, copy, clear.` is kept as is.
- **Prune** (`tools/prune-icons.lua` from the tag): kept 4 files, removed 5,836. The tracked icon
  folder stays at 4 files, so the README's Open Iconic credit is unchanged.
- **Contract blocker:** the Options degradation stub owed four new members (`KeybindingsTab`,
  `KeybindRows`, `KEYBINDS_UNCHANGED`, `StrataTooltip`). It was fixed in the re-vendor commit, in
  `settings/OptionsSetup.lua`.
- **Addon ripple:** `tests/loader.lua` loads `OptionsKeybinds.lua` and its Sim comment names
  SimPanel minor 6. `DEPENDENCIES.md` and `docs/testing.md` name kit revision 42 for the complexity
  runner. The CLAUDE.md provenance line reads v1.77.0.
- **Delivered free:** the debug console is toplevel and raises a shown StaticPopup over itself.
- **Adopted here:** none. WG-KB and WG-ZS adopt the rest (03_DECISIONS.md). **Declined:** none
  filed. **Unreached:** none.
- **Span bundle:** none needed. Every vendored tag has a bundle.

Gates (all through `ka0s-bounded`):

- After the copy, before the fixes: tests 940 passed / 2 failed / 1 skipped. The two failures were
  the loader's XML-order check (40 files listed, 41 shipped) and the Options stub parity check.
- After the fixes: tests 942 passed / 0 failed / 1 skipped, with `test_vendor_sync` green against
  tag v1.77.0 and the declaration.
- luacheck 0 warnings / 0 errors in 59 files.
- No authored `.lua` over 1500 lines (largest: `modules/Frame.lua`, 1427).
- Smoke owed: none for this item. The console's toplevel raise is the library's smoke (SM-LK list).
