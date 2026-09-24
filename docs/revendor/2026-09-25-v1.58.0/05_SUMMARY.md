# Summary: LibKa0s v1.57.0 -> v1.58.0

## The tag, and the minors

- **Tag:** v1.57.0 -> v1.58.0, from the sibling checkout's local tag with `git archive`. The base
  comes from the `CLAUDE.md` provenance line, and the payload matched v1.57.0 byte for byte.
- **Kit revision:** 26, unchanged.
- **Per-file minors:** one file moves, Launcher 3 -> 4. No file added or removed, no skew.
- **Re-vendor commit:** the `M6-WG` commit, which carries the payload, the provenance line in
  `CLAUDE.md`, this bundle and the `launcher-§2` adoption.

## Delivered free (class A)

- **Launcher 4:** left-click opens the settings panel in either state, and the tooltip's hints read
  `Left-click: Open settings` / `Right-click: Options menu`. On the copy alone this also stopped the
  left button toggling the group popup, which is why the adoption lands in the same commit.

## Contract blockers (3g)

None.

## Adopted

`launcher-§2`'s options menu, in `core/LauncherSetup.lua`: all four pairs, each toggle the body its
verb runs — `setEnabled` (`/wg enable|disable`), `toggleLock` (`/wg set locked toggle`; there is no
`/wg lock` verb), `toggleTestMode` (bare `/wg test`) and `toggleWindow` / `isWindowShown` (the group
popup, `WhatGroup:ToggleFrame` / `WhatGroup:IsFrameOnScreen`). `onClick`, `leftClickLabel` and
`disabledLine` are gone, with the dead locale row. The menu is tested through `tests/mock_menu.lua`,
a `MenuUtil` fake modeled on LibKa0s's own, installed on every build by `tests/wow_mock.lua`:
eleven cases in `tests/test_launcher.lua` (entries and order, each toggle's output compared line for
line with its slash command's, the grayed disabled state, the degraded no-MenuUtil path, a source
pin on the pairs and the retired fields) and `disabled 8` in `tests/test_disabled.lua`.

## Declined

None.

## Gates

Tests come from `ka0s-bounded lua5.1 tests/run.lua`, lint from `ka0s-bounded luacheck .`, and
complexity from `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Point | Tests | Lint | Lizard |
|---|---|---|---|
| Before the copy (v1.57.0) | 780 passed, 0 failed | not run | not run |
| After the copy (v1.58.0) | 773 passed, 7 failed (the owed re-pins, 3g) | not run | not run |
| After the adoption | 787 passed, 0 failed | 0 / 0 in 51 files | 0 functions above CCN 15 |

Largest authored `.lua`: `tests/test_frame.lua`, 1422 lines.
