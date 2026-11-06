# Summary

- **Tag:** v1.85.0 -> v1.89.0, base from the provenance line (`CLAUDE.md:48`). Minors: Toast 3 -> 4,
  Widgets 22 -> 23, DebugLogDiagnostics 6 -> 7, and the new major IconBrowser (three files at 1). Kit
  50 -> 51. Table in `01_DELTA.md`. No span bundle, no base correction, no refresh.
- **For free (class A):** the diagnostics report names IconBrowser; kit 51's CallbackHandler unregister
  guard. Widgets 23 and Toast 4 ride along unused (this addon looks up neither).
- **Blockers:** no contract change. `tests/loader.lua` gains the three IconBrowser files in XML order,
  in the re-vendor commit. No Toast stub is owed (no Toast lookup). No dead stub mirror.
- **Icons:** `LibKa0s icons:` line kept unchanged, all Open Iconic. The prune kept 13 files (the twelve
  marks and the set's license) and removed 5827 (every undeclared Open Iconic, Phosphor and Game-icons
  file of the whole copy). The shipped set equals the one on master, so the README credits are unchanged.
  No provenance split.
- **Adopted:** nothing (the plan names no adoption for WhatGroup). **Declined:** nothing, no issue
  filed. IconBrowser settled (no icon chooser); cascading-menu fields not applicable (no `W.ContextMenu`
  site). No undecided candidate.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 77 files;
  `ka0s-bounded lua tests/run.lua` 1100 passed, 0 failed, 1 skipped (the diagnostics opt-out case, by
  design); largest own file 1256 lines, under the 1500 cap.
