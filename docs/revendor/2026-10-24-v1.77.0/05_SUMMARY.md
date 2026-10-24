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

## Re-vendor after the tag moved (M3)

Item WG-RV2. LK-95 moved the local annotated tag `v1.77.0` to carry the M3 settings-layout surface.
Both payloads were copied whole again from the tag (`git archive v1.77.0 LibKa0s testkit tools`),
then pruned with the tag's own `tools/prune-icons.lua`.

- **Tag:** old commit `78240f7` (the WG-RV copy), new commit
  `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (tag object `b2b8ee25c5f9fa26db146254bf786b366dec986b`).
- **Moved:** one library file, `OptionsCompose.lua`, compose minor 8 to 11 (9: MasterControls
  `notes`, `resetPositionTooltip`, `lockIsPreview` and the frameless packing; 10: the group composers'
  `tooltips`; 11: `O.ResetAllTooltip(tail)`). No other library file and no kit file changed, so the
  kit revision stays 42 and the XML still lists 41 files.
- **Declaration:** `LibKa0s icons: close, copy, clear.` is kept as is. The prune kept 4 files and
  removed 5,836, so the README's icon credit is unchanged.
- **Contract blocker:** the surface-parity test went red on `ResetAllTooltip`. The Options
  degradation stub in `settings/OptionsSetup.lua` now answers it with an inert empty string.
- **Provenance:** the CLAUDE.md line stays at v1.77.0 and records no sha or kit revision, so nothing
  rolls.
- **Adopted here:** none. WG-LY adopts the layout surface.
- **Standard:** no drift. Between WG-RV and WS-95 the standard only added options-ui-§21 and edited
  §7 and §12 to §16 in place. No section was renumbered or retired.

Gates (through `ka0s-bounded`): after the copy, 956 passed / 1 failed (stub parity) / 1 skipped.
After the stub fix, 957 passed / 0 failed / 1 skipped, with `test_vendor_sync` green against the
moved tag. luacheck 0 warnings / 0 errors in 62 files. No authored `.lua` over 1500 lines (largest
`modules/Frame.lua`, 1472).

## Re-vendor after the tag moved again (one key button)

Item WG-RV3. LK-96 moved the local annotated tag `v1.77.0` again, for the owner's follow-up to 015:
one key button and Clear per row on the Keybindings tab. Both payloads were copied whole again from
the tag (`git archive v1.77.0 LibKa0s testkit tools`), then pruned with the tag's own
`tools/prune-icons.lua`.

- **Tag:** old commit `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (the WG-RV2 copy), new commit
  `2f2b2e22b4c9219cd8a4101d7e894681c7aea16e` (tag object `e9b126d961c2970e5b14d0566480f7c1d8b5e5e8`).
- **Moved:** one library file, `OptionsKeybinds.lua`, keybinds minor 3 to 4 (one key button and
  Clear per row; the button reads `<first key> +N` and its tooltip names every key; the strings
  `KEY1` / `KEY2` are gone and `KEY`, `KEY_MORE`, `KEYS_ALL`, `KEYS_OTHER` are new). In the kit,
  `bindings_xml.lua` and its README row: `Kit.keybindThroughTab(row, 2, ...)` on a one-button row
  writes the second key through the library's model, as the client's page would. The kit revision
  stays 42 and the XML still lists 41 files.
- **Declaration:** `LibKa0s icons: close, copy, clear.` is kept as is. The prune kept 4 files and
  removed 5,836, so the README's icon credit is unchanged.
- **Contract:** no new public Options member, so the degradation stub is unchanged and the
  surface-parity test stayed green. The one red case was the addon's own
  `tests/test_keybinds.lua`, which pinned two slots per row; it now pins one key button and Clear,
  and a new case pins a second key reading `<key> +1` on the button.
- **Addon ripple:** `docs/settings-panel.md`, `docs/smoke-tests.md` (LAUNCH-18 and LAUNCH-19
  rewritten, set back to not run and listed under Pending sign-off; SM-WG-RV3 added to LAUNCH-18),
  the README and the `tests/loader.lua` comment describe the one key button. `Bindings.xml`,
  `NS.BINDINGS` and the labels are untouched.
- **Provenance:** the CLAUDE.md line stays at v1.77.0, so nothing rolls.

Gates (through `ka0s-bounded`): after the copy, 964 passed / 1 failed (the addon's two-slot
assertion) / 1 skipped. After the fix and the new case, 966 passed / 0 failed / 1 skipped, with
`test_vendor_sync` green against the moved tag. luacheck 0 warnings / 0 errors in 62 files. No authored `.lua` over 1500 lines (largest
`modules/Frame.lua`, 1472).
