# Summary: LibKa0s v1.58.0 -> v1.60.0

## The tag, and the minors

- **Tag:** v1.58.0 -> v1.60.0 (`bed0eb1`), taken with `git archive` from the sibling checkout's tag.
  The base comes from the `CLAUDE.md` provenance line, and the payload matched v1.58.0 byte for byte.
- **Kit revision:** 26 -> 27. The kit gains `test_diagnostics_contract.lua`.
- **Per-file minors:** WidgetsDragHandle 2 -> 3, DebugLog 13 -> 14, Slash 15 -> 16, and the new
  DebugLogDiagnostics 1. No file was removed and no skew was found.
- **Re-vendor commit:** `DR-WG-01`. It carries both payloads, the provenance line, the owed re-pins
  and this bundle.

## Delivered free (class A)

- The 3000-line console buffer and the 128-line slack (DebugLog 14).
- `lib.TIME_COPY`, the copy-timing aid, which is off by default.
- `diagnostics` on Slash's default live list. It becomes live while disabled once DR-WG-03 adds the row.

## Contract blockers (3g)

None. The re-pins the library's CHANGELOG names all landed in the copy commit:

- `core/DebugLogSetup.lua`'s library-absent stub gains `RunDiagnostics`, which prints
  `/wg diagnostics is unavailable: the LibKa0s library did not load.`, writes nothing and returns 0.
  It also gains `BuildDiagnostics` (an empty report) and `DebugVerb` (`false`). With the stub
  reverted, `parity: the DebugLog stub carries the whole live surface` fails on exactly these three
  members, which is the falsification run.
- `tests/loader.lua`'s hand-typed LibKa0s list gains `DebugLogDiagnostics.lua` after `DebugLog.lua`
  (the harness's XML-order case found this: 22 files expected, 21 listed).
- `tests/run.lua` declares the kit's `test_diagnostics_contract` suite. It is one declared skip until
  `Kit.diagnostics` is wired in DR-WG-03.
- `tests/test_slash.lua`'s live-verb copy gains `diagnostics`. The live-row count allows for the one
  live verb without a row until DR-WG-03 adds it.

## Adopted

None in this run. The plan adopts the diagnostics report and Slash 16's verb in DR-WG-03.

## Declined

None. The close mark is not a candidate here because WhatGroup has no DragHandle. No issues were filed, as the plan directs.

## Docs the copy made false

`docs/testing.md`'s vendor-gate note now names v1.60.0 as the vendored tag. `docs/test-cases.md` and
the README badge are covered under Gates.

## Left for later items

Doc sites that still say `1500` lines or "twelve" live verbs (`docs/ARCHITECTURE.md:262`,
`docs/smoke-tests.md:106,736`, `docs/slash-dispatch.md:154`) are DR-WG-05's and M4's sync-docs.

## Gates

Tests come from `ka0s-bounded lua tests/run.lua`, lint from `ka0s-bounded luacheck .` and
complexity from `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Point | Tests | Lint | Lizard |
|---|---|---|---|
| Before the copy (v1.58.0) | 787 passed, 0 failed | not run | not run |
| After the copy and the re-pins, before the loader fix | 786 passed, 1 failed, 1 skipped (XML-order case) | not run | not run |
| At the commit | 787 passed, 0 failed, 1 skipped (788 total) | 0 / 0 in 51 files | 0 functions above CCN 15 |

`docs/test-cases.md` is regenerated (788 cases) and the README badge reads 787/788 passing. The one
skip is the kit's declared diagnostics-contract skip.
