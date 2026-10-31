# Refresh 2: the v1.84.0 re-cut (M4-RV)

The tag moved again on the run branch before its release was pushed, so this is a refresh and not a
new re-vendor: `git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing, and the provenance
line already names the tag. `01_DELTA.md` line 1 stands.

- **Old:** 7a8bc0f133ed118d2c79c7c5288b97964e24fae5, the commit `06_REFRESH_1.md` records.
- **New:** `git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'` = b5229b876e803768322fb4d8c66be69f01c8e4a1.
- **Why:** the owner's ruling of 2026-11-01, `lib.__PatchLSM30Border` is deleted with no stub.

Per-file minors that moved (3c's loop against both):

| File | Constant | Old | New |
|---|---|---|---|
| `Options.lua` | `MINOR` | 36 | 37 |
| `OptionsDrawer.lua` | `DRAWER_MINOR` | 3 | 4 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 2 | 3 |

Kit revision stays 47. Three payload files changed; no file added or removed upstream, and the
`tests/_kit` copy is unchanged.

**Contract read:** WhatGroup calls no `__PatchLSM30Border`, and neither its stubs nor its tests name
it: `git grep -n 'PatchLSM30' -- ':!libs' ':!tests/_kit' ':!docs/revendor'` matches nothing. So this
refresh removes no authored code, no test and no stub surface, and no test pins a moved minor. There
is no blocker. The mention in `06_REFRESH_1.md` is history and stays.

**Icons:** `close, copy, clear, eye, settings.` kept; the prune kept 6 files and removed 5834.

**Gate after the copy:** `lua tests/run.lua` 1046 passed, 0 failed, 1 skipped; `luacheck` 0 warnings,
0 errors in 76 files; both through `ka0s-bounded`. `docs/test-cases.md` unchanged.
