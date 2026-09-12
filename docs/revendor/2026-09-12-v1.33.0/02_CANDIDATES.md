# 02 — Candidates: LibKa0s v1.33.0

Sources: `git -C ../LibKa0s log --oneline v1.32.0..v1.33.0`, the v1.33.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/api/Options/version-17.15.4.3-docs.md`,
`../LibKa0s/docs/api/Slash/version-9-docs.md` and `../LibKa0s/docs/api/testkit/version-18-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **The font preload (Options minor 17).** **A no-op here.** The Options descriptor supplies no `getLSM` (`settings/OptionsSetup.lua:213`), so the preload returns at `type(d.getLSM) ~= "function"` before it creates a frame or a FontString. The two call sites still run: the OnShow hook `O.CreatePanel` installs, and the call inside `SetRenderer`'s OnShow, which this addon wraps (`settings/OptionsSetup.lua:253`) to defer the body a frame. Neither touches AceGUI. `tests/test_panel.lua`'s GameMenu contract (`:211`) passes unchanged; the in-client GameMenu → Logout taint smoke test is still owed.
- **The `count` docstrings (Options 17, Slash 9).** Comments only; nothing to adopt.
- **Kit revision 18, the `OnProfileCopied` key.** **Not reached by a copy test.** WhatGroup uses the kit's AceDB, but its one copy test (`tests/test_debuglog.lua:434`) calls `OnProfileCopied` directly with a source.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

None. v1.33.0 adds no descriptor field and no member to adopt.

## Class C: whole-module adoption

None. No module is new at this tag.
