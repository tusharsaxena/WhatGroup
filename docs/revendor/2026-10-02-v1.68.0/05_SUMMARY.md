# Summary (WhatGroup)

LibKa0s v1.67.0 -> v1.68.0 from the local annotated tag (`cc9f5eb`; base from the `CLAUDE.md`
provenance line, confirmed against the payload); kit revision 35 unchanged. One minor moved:
WidgetsDragHandle 3 -> 4 (`LibKa0s-Widgets-1.0` key 12.1.3 -> 12.1.4). No span bundle (3h empty),
no base correction (Step 0 ok), no file deleted, no cross-major skew, no contract blocker.

- Delivered on the copy (class A): nothing visible; the addon draws no drag strip.
- Adopted: nothing.
- Declined: C1 `tooltipPlace`, not applicable (no drag strip). Not filed: not a real gap.
- Unreached: none.

Docs moved in the re-vendor commit: the `CLAUDE.md` provenance line, `docs/testing.md`'s "as this is
written" tag, and the "as vendored from" stamps in `docs/debug.md` and `docs/debug-content.md`
(DebugLog itself is unchanged at 19.2.1). `DEPENDENCIES.md` names kit revision 35, still correct.

Gate after the copy (every Lua run through `ka0s-bounded`):

- tests: 914 passed, 0 failed, 1 skipped, 915 total, including `test_vendor_sync.lua`'s three cases;
  the cases did not change (`diff <(lua tests/run.lua --list) docs/test-cases.md` empty, README badge
  914/914 unchanged)
- luacheck: 0 warnings / 0 errors in 59 files
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`): pass, warnings 0,
  maxCcn 15, blindFiles 0, 1792 functions, bandFiles 3, overCapFiles 0. Its one-suite run bundle was
  not kept.
- vendor gate: `diff -r` against the tag's archive, and `diff -r` / `diff -r --strip-trailing-cr`
  against `../LibKa0s/LibKa0s` and `../LibKa0s/testkit`, empty for both payloads.
