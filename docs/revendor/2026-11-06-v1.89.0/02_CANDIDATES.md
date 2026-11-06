# Candidates, v1.85.0 -> v1.89.0

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the tag's `CHANGELOG.md` blocks v1.86.0 to
v1.89.0, and the moved majors' API documents.

## A. Delivered by the re-vendor

- **DebugLogDiagnostics minor 7**: the diagnostics report's `LibKa0s running:` line names `IconBrowser`
  (CHANGELOG v1.86.0, "DebugLogDiagnostics minor 7"). No member moves.
- **Kit revision 51**: `mock_ace.lua`'s CallbackHandler registry clears an entry only where one exists, so
  an `Unregister*` during a dispatch can no longer raise `invalid key to 'next'` (CHANGELOG v1.89.0, "Test
  kit revision 51"). A flake fix for every suite that sends AceEvent callbacks.
- **Widgets minor 23** and **Toast minor 4** ride along in the payload. Flat menus draw what 22 drew, and
  a toast with no `stack` is the minor 3 toast. This addon looks up neither major (`01_DELTA.md` 3e).

## B. Host change required

- **Widgets 23 cascading-menu fields** (`submenu`, `radio`, `selected`, `opts.check`; CHANGELOG v1.87.0,
  `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`): **not applicable**. The host has no `W.ContextMenu`
  use site (`grep -rn 'ContextMenu\|MenuUtil' core modules settings` finds nothing). Nothing to offer.
- **Toast 4 stack** (`stack`, `stackGrow`, `stackGap`, `SetStack`; CHANGELOG v1.88.0): **not applicable**.
  The addon does not consume Toast.

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (new in v1.86.0, `docs/api/IconBrowser/version-1.1.1-docs.md`): a
  host-configured icon chooser window. WhatGroup's UI lets the player choose no icon, so there is nothing
  for it to replace or add to. Blast radius if ever adopted: additive, plus `search` in the icon line.
  Settled by the owner's ruling (run plan, Decisions table): recorded here, no issue.

No contract blocker (`01_DELTA.md` 3g), so nothing here was resolved outside this list.
