# Summary (WhatGroup)

LibKa0s v1.70.0 -> v1.71.0 from the local annotated tag `v1.71.0` (`cb274a4`), base from this repo's
CLAUDE.md provenance line, confirmed by the last payload commit `3fd8a2f` and a payload-matches diff
against v1.70.0. Six library files move a minor (Env 2, Slash 20, SlashParse 2, OptionsIdList 4,
WidgetsLineChart 3, WidgetsAutocomplete 2); no file added or removed. Kit revision 37 -> 38
(`README.md`, `framework.lua`, `inventory.lua`; new `secrets.lua`). CLAUDE.md provenance rolled in
the same commit. Item RV-WG, finding `WG-A-02`.

- **Delivered free (class A):** kit 38's Totals (`docs/test-cases.md` regenerated: `Skipped` row,
  Total 914, equal to the README badge); Env 2, Slash 20.2 and OptionsIdList 4, carried by re-vendor
  with no code change.
- **Contract blockers:** none (01_DELTA.md 3g).
- **Adopted:** `Kit.secret` family, adopted in this run by WG-01 (a later commit).
- **Not adopted:** WidgetsLineChart 3 and WidgetsAutocomplete 2 (Widgets declined, #12).
- **Span bundle:** `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` records the two unrecorded sweep
  re-vendors (`9677d99`, `3fd8a2f`).
- **Docs:** `docs/testing.md`, `docs/debug.md` and `docs/debug-content.md` no longer name a vendored
  tag (`v1.68.1`); they point at the CLAUDE.md provenance line, so a re-vendor cannot stale them.

Gates (all through `ka0s-bounded`): tests 914 passed / 0 failed / 1 skipped before and after the
copy (the kit-38 inventory now counts the skip on its own row), both vendor-sync cases green;
luacheck 0/0; lizard no function above CCN 15; vendor parity `diff -r` against the tag empty.
