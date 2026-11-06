# Candidates, v1.89.0 -> v1.90.0

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the tag's `CHANGELOG.md` block v1.90.0, and
the moved majors' API documents (`docs/api/Core/version-16-docs.md`,
`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`, `docs/api/Widgets/version-24.5.12.6.8.5-docs.md`,
`docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md`).

## A. Delivered by the re-vendor

- **Core 16, SkinPaint 19, SkinPaintExtras 18** (CHANGELOG v1.90.0, "One physical pixel"): the pixel
  watch and `P.px` move into Core; a skin's icon and input edges keep their physical-pixel sizing. No
  host change, no member moves.
- **Widgets 24, WidgetsAutocomplete 8** ride along in the payload: every `W.Dropdown`, `W.SearchBox`,
  shared menu and autocomplete edge is one physical pixel. This addon looks up no Widgets major
  (`01_DELTA.md` 3e), so nothing it draws changes.
- **Skin 17, OptionsAppearance 7** (CHANGELOG v1.90.0, "A copy leaves a host's Scope alone"): an Apply
  to all or Skin-tab copy from this addon to a `keepScope` owner (the Skin Tester) no longer overwrites
  that owner's Scope. Delivered on the copy; the source side owes nothing.

## B. Host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin 17): **not applicable**. It is for a host whose
  Scope deviates from the default by design; WhatGroup's registration (`core/SkinSetup.lua:550`) has no
  documented Scope deviation, and the run assigns the opt-out to the Skin Tester alone (`SF1-ST`).

## C. Whole-module adoption

None new in this range (no new major). IconBrowser stays settled as at v1.89.0 (no icon chooser).

No contract blocker (`01_DELTA.md` 3g), so nothing here was resolved outside this list.

## The column-header check (SF1 item 5)

The owner ruled that a column-header row with a grey line directly above or below it is wrong, and
that LootHistory's `NS.Skin.SortHeaderBar` header, which has no such lines, is right
(`SF1_SMOKE_FEEDBACK.md`, item 5 and `SF1-DR`).

**WhatGroup draws no column-header row, so it has no such line.** Its one window of its own is the
group popup, built in `modules/FrameLayout.lua`: a title bar (`modules/FrameLayout.lua:36-59`) over
label/value rows (`MakeLabel`, `modules/FrameLayout.lua:73-83`), the teleport row and the Close button
(`:167`). It has no column headers. No line is drawn under the title either, by an earlier ruling
(`modules/FrameLayout.lua:31-33`, R4-SEP: the popup carries no `f.divider`). `SortHeaderBar` and
`Divider` appear only in the library-absent Skin stub's no-op name list (`core/SkinSetup.lua:456`,
`:458`), and the addon never calls either. `Options_HorizontalDivider` appears only in a comment
(`settings/Panel.lua:96`). The settings panel, debug console and perf panel are built by the library.
Found with `grep -rnE 'SortHeader|Divider|[Hh]eader|CreateLine|Separator' --include='*.lua' core
modules settings`. **No `SF1-WG-HDR` change is owed, and no code was changed.**
