# Summary: LibKa0s v1.56.0 -> v1.57.0

## The tag, and the minors

- **Tag:** v1.56.0 -> v1.57.0, from the sibling checkout's local tag with `git archive`. The base
  comes from the `CLAUDE.md` provenance line, and the payload matched v1.56.0 byte for byte.
- **Kit revision:** 26, unchanged.
- **Per-file minors:** one file moves, Launcher 2 -> 3. No file added or removed, no skew.
- **Re-vendor commit:** the `M5-WG` commit, which carries the payload, the provenance line in
  `CLAUDE.md`, this bundle and the `launcher-§1` adoption.

## Delivered free (class A)

- **Launcher 3:** the minimap button and any broker display show the library's status tooltip on
  hover, enabled or disabled.

## Contract blockers (3g)

None.

## Adopted

`launcher-§1`'s descriptor fields, in `core/LauncherSetup.lua`: `version` (the TOC's, via
`NS.Version`), `isLocked` (the profile's `locked`), `isTestMode` (`NS.State.testMode`) and
`leftClickLabel` (`L["Toggle group popup"]`). Five cases in `tests/test_launcher.lua` pin the
lines through the mock, including the disabled state.

## Declined

None. `slash` is not passed because `DisabledLine()` already names `/wg enable`; `onTooltipShow`
is not passed because the addon has no line of its own to append.

## Gates

Tests come from `ka0s-bounded lua5.1 tests/run.lua`, lint from `ka0s-bounded luacheck .`, and
complexity from `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Point | Tests | Lint | Lizard |
|---|---|---|---|
| Before the copy (v1.56.0) | 775 passed, 0 failed | not run | not run |
| After the copy (v1.57.0) | 775 passed, 0 failed | not run | not run |
| After the adoption | 780 passed, 0 failed | 0 / 0 in 50 files | 0 functions above CCN 15 |

Largest authored `.lua`: `tests/test_frame.lua`, 1422 lines.
