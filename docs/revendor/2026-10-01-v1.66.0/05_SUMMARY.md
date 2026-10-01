# Summary (WhatGroup)

LibKa0s v1.65.0 -> v1.66.0 from the local tag (base from the `CLAUDE.md` provenance line); kit
revision 34 -> 35. Minors: Widgets 12 + WidgetsReorder 1, DebugLog 19, Slash 19 + SlashParse 1,
OptionsWidgets 34, OptionsTabs 8, Perf 14 + PerfSampler 1 + PerfCommands 1. Span bundle
`2026-10-01-v1.64.0-v1.65.0/` records the two tags vendored without a bundle. No contract blocker.
Nothing adopted (C1 deferred to GI-LK-13), nothing filed.

Gate after the copy:

- tests: 887 passed, 0 failed, 1 skipped, 888 total (879 / 1 / 880 before: the eight
  `test_lizard_sighted` cases)
- luacheck: 0 warnings / 0 errors in 59 files
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`): pass, warnings 0,
  maxCcn 15, blindFiles 0, 1750 functions (raw lizard listed 1693), bandFiles 3, overCapFiles 0.
  No newly revealed function above CCN 15.
- vendor gate: `diff -r` and `diff -r --strip-trailing-cr` against the tag empty for both payloads.
