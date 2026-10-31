# Refresh 1: the v1.84.0 re-cut (M3-RV)

The tag moved on the run branch before its release was pushed, so this is a refresh and not a new
re-vendor: `git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing, and the provenance
line already names the tag. `01_DELTA.md` line 1 stands.

- **Old:** not recoverable, because a moved tag leaves no reflog entry. The vendored payload was
  content-identical to e917ccd833768b8fe68e9542d3fbf6b38cab6659, the last commit before the re-cut
  (`diff -r --strip-trailing-cr` empty apart from the pruned icons).
- **New:** `git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'` = 7a8bc0f133ed118d2c79c7c5288b97964e24fae5.
- **Why:** the owner's ruling of 2026-11-01, `Ka0sMedia_*` is the only media picker (LibKa0s#73).

Per-file minors that moved (3c's loop against both):

| File | Constant | Old | New |
|---|---|---|---|
| `Options.lua` | `MINOR` | 35 | 36 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 40 | 41 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 15 | 16 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 9 | 10 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 1 | 2 |
| `SkinAce.lua` | `ACE_MINOR` | 5 | 6 |

Kit revision stays 47. Six payload files changed; no file added or removed upstream, and the `tests/_kit`
copy is unchanged.

**Contract read:** the tag's "A consumer owes" list names a test pinning `LSM30_*`, a test expecting
`__PatchLSM30Border` to wrap, and a page calling `AceGUI:Create("LSM30_*")`. None exists here, so
there is no blocker: `git grep -nE 'PatchLSM30|LSM30|AceGUIWidgetLSM' -- ':!libs' ':!tests/_kit' ':!docs'`
matches nothing. WhatGroup never vendored AceGUI-3.0-SharedMediaWidgets. `H.FontGroup`,
`H.BorderGroup` and `H.BarGroup` are library-absent stubs with no call site that names a dialog control.

**Icons:** `close, copy, clear, eye, settings.` kept; the prune kept 6 files and removed 5834.

**Gate after the copy:** `lua tests/run.lua` 1046 passed, 0 failed, 1 skipped; `luacheck` 0 warnings,
0 errors in 76 files; both through `ka0s-bounded`. `docs/test-cases.md` unchanged.
