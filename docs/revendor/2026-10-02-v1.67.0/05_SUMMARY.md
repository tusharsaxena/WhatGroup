# Summary (WhatGroup)

LibKa0s v1.66.0 -> v1.67.0 from the local tag `0bccf4c` (base from the `CLAUDE.md` provenance line);
kit revision 35 unchanged. Minors: Core 9 -> 10, Options 27 -> 28, OptionsIdList 2 -> 3. No contract
blocker. Nothing adopted here: C1 (`addonName`) is CA-WG-NM's, C2 (Core 10 grip fields) has no
consumer in this addon, C3 is delivered on the copy. Nothing filed.

Docs moved in the re-vendor commit: the `CLAUDE.md` provenance line, `docs/testing.md`'s
"as this is written" tag, and the "as vendored from" stamps in `docs/debug.md` and
`docs/debug-content.md` (DebugLog itself is unchanged at 19.2.1). `DEPENDENCIES.md` names kit
revision 35, still correct.

Gate after the copy:

- tests: 913 passed, 0 failed, 1 skipped, 914 total (unchanged; `docs/test-cases.md` regenerated with
  no diff, README badge 913/913 unchanged)
- luacheck: 0 warnings / 0 errors in 59 files
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`): pass, warnings 0,
  maxCcn 15, blindFiles 0, 1791 functions, bandFiles 3, overCapFiles 0. Its one-suite run bundle was
  not kept.
- vendor gate: `diff -r` against the tag's archive and `diff -r --strip-trailing-cr` against
  `../LibKa0s/LibKa0s` empty for both payloads.
