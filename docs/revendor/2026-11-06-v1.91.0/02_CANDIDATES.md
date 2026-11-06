# Candidates, v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` block v1.91.0,
and the moved majors' API documents (`docs/api/Core/version-17.1-docs.md`,
`docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md`,
`docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`), each diffed against the v1.90.0 document.

## A. Delivered by the re-vendor

- **WidgetsLineChart 7** (CHANGELOG v1.91.0, FU-L1; Widgets document, "The line chart's lines in
  physical pixels"): the axis, grid, markers, crosshair and series are physical pixels at any UI
  scale. This takes no host change. This addon draws no line chart and looks up no Widgets major
  (`01_DELTA.md` 3e), so nothing it draws changes.
- **The four peels** (CHANGELOG v1.91.0, FU-L2): `CorePixel.lua` (Core 17), `WidgetsDropdown.lua`
  (Widgets 26), `SkinPaintHud.lua` and `SkinAceConfirm.lua` (SkinPaintExtras 19). Each is a pure move,
  with no member, option or behaviour change. They arrive on the copy, and their only host cost is the
  test loader list, which `01_DELTA.md` 3g records as a blocker fixed in the re-vendor commit.

## B. Host change required

None. The range adds no public surface, descriptor field, row type or seam.

## C. Whole-module adoption

None new in this range, since no new major arrived. IconBrowser is settled as at v1.89.0 and v1.90.0,
because this addon has no icon chooser.

There is no contract blocker (`01_DELTA.md` 3g), so nothing here was resolved outside this list.
