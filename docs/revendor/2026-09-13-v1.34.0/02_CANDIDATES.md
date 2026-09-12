# 02 — Candidates: LibKa0s v1.34.0

Sources: `git -C ../LibKa0s log --oneline v1.33.0..v1.34.0`, the v1.34.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/releasing.md` ("Re-vendoring consumers"),
`../LibKa0s/docs/api/Slash/version-10-docs.md`, `../LibKa0s/docs/api/Options/version-18.15.5.3-docs.md`
and `../LibKa0s/docs/api/testkit/version-19-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **The whole-value string parse (Slash minor 10).** **Reached, and no row newly keeps a multi-word
  value.** The descriptor's `parse` (`settings/Slash.lua:128`) only adds the `toggle` word for `bool`
  rows and maps the bool error. It hands everything to `lib.ParseValue`. The schema declares eight
  `bool` and three `number` rows. The one `string` row the CLI reaches is the composed `visibility`
  enum (`settings/Schema.lua:474`, composed at `settings/Panel.lua:204`; the prefix is empty). Its
  four values are single words: `always`, `inCombat`, `outOfCombat` and `never`. So the only visible
  change is a refusal. A probe of `/wg set visibility always junk` at v1.34.0 left the stored value
  alone, where minor 9 stored `always`. `/wg set visibility inCombat` still stores it.
- **The *Reset all settings* tooltip (Options minor 18, OptionsCompose minor 5).** **Unchanged, and
  still correct.** The block is composed through `Helpers.MasterControls` (`settings/Panel.lua:204`),
  and the descriptor supplies no `resetProfile`. The text therefore stays byte for byte *"Restore
  every setting in this addon to its default."* The button's `onResetAll` (`settings/Panel.lua:229`)
  raises `WHATGROUP_RESET_ALL`. Its accept runs the host's `Helpers.RestoreAllDefaults`, which
  overrides the library's member of that name: one `db:ResetProfile()` plus the `sessionOnly` rows
  by hand. That resets every setting this addon has. `AceDB:New(…, true)` (`core/WhatGroup.lua:214`)
  puts every character on the one shared `Default` profile, and the addon ships no profile UI, so a
  player has no other profile. The profile wording would promise *"your other profiles are not
  affected"* to someone who has none. `profilesPage` does not apply either.
- **The taint-sensitive options wrapper.** **Untouched.** `settings/OptionsSetup.lua:243`–`:254`
  wraps `O.EnsureDefaultsButton` and `O.SetRenderer` on the instance, so both build a frame late.
  Options minor 18 changes three things: the `MINOR` constant, the three `RESET_ALL_TIP*` strings,
  and one call, `lib.__AttachCompose(O)` becoming `lib.__AttachCompose(O, d)`. OptionsCompose minor 5
  changes only how the tooltip string is chosen. Neither touches `SetRenderer`,
  `EnsureDefaultsButton`, AceGUI or `StaticPopupDialogs`. The taint pin in `tests/test_panel.lua`
  (`:208`–`:212`, the reset dialog is not registered at load, which would taint GameMenu callbacks)
  passes unchanged, and the suite is 608 before and after. The in-client **GameMenu → Logout** smoke
  check is still owed.
- **Kit revision 19, `OnProfileReset` without a key.** **Reached, and nothing moves.** The harness
  builds on the kit's AceDB (`tests/wow_mock.lua:83`). `tests/test_debuglog.lua:263`, `:413` and
  `:427` reset through it. The handler (`core/WhatGroup.lua:256`) is a no-argument closure, so it
  never read a key.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

None. `profilesPage` is read only with `resetProfile`. This addon ships no Profiles page, and its
global reset goes through its own `Helpers.RestoreAllDefaults`, never the library's.

## Class C: whole-module adoption

None. No module is new at this tag.
