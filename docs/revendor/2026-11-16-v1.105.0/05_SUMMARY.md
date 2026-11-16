# 05 Summary

- Tag moved v1.93.0 -> v1.105.0, base taken from the CLAUDE.md provenance line. Kit revision 53 -> 57. Files that moved a minor, and the ten new files: see 01_DELTA.md.
- Span bundle: none. Base correction: none.
- Delivered for free (class A): skin row and hot-mark colors, library window header marks, the console footer and plain-text Copy, library tooltip placement, slider-box junk revert, two font faces.
- Contract blockers: none.
- LibKa0s icons: line kept as written (`settings` already declared). Prune: Open Iconic only, net no change; sounds none. README credits unchanged.
- Dead stub mirrors: none.
- Host files changed beside the payload and the provenance line: `tests/loader.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `core/Compat.lua`. No behavior change: the new stub members and Compat readers have no caller.
- Adopted: nothing. Declined: nothing. Owed in phase [3]: #92 (`modules/Frame.lua:545`), #86 (the popup's title bar), #87 (`core/TestPreview.lua:34`), #79 (verify; none known) and the `DefaultSkin` MUST.
- Gate (Retail, the only client this addon lists): `ka0s-bounded lua tests/run.lua` 1103 passed, 0 failed, 1 skipped, 1104 total; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 77 files; largest addon file 1309 lines (`docs/test-cases.md`), under the 1500 cap.
- Pre-existing drift, not this run's: `docs/test-cases.md` lacks the three `test_client_globals.lua` cases (it reads 1100 against the suite's 1103 listed) since v1.93.0's kit 53; left for a sync-docs pass.
- Smoke owed (owner): the class A lines above, in game, per `06_SMOKE_TESTS.md` of the run bundle.
