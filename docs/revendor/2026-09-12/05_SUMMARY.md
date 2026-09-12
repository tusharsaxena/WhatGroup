# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** (annotated tag `e369e0f`) |
| Files that moved in `libs/LibKa0s/` | **none**. Every LibStub minor is unchanged, and the content diff was empty before the copy. |
| Kit revision | **15 → 16**. `README.md`, `framework.lua`, `mock_base.lua` and `vendor_sync.lua` changed. |
| Files removed upstream | none |
| Cross-major skew found | none |

Both payloads were copied whole from `git archive v1.30.0`, and the `CLAUDE.md` provenance line was
rolled in the same commit. The same commit also rolls the version echo at `docs/testing.md:233`,
regenerates `docs/test-cases.md` and updates the README `tests` badge (testing-§5).

## What reached this addon for free

- **The runner-mode case (#28).** It gives the gate a 569th case and closes audit finding WG-51.
- **`Printf` on the `NewAddon` target (#30).** It is inert here, because the addon never calls it.

## What was adopted

No shims were removed. This addon never carried a copy of any of the four kit-16 fixes.

## What was declined

- **#29 and #27**: #29 cannot reach this harness without a migration. `tests/wow_mock.lua`
  replaces `NewAddon`'s event recorder with its own handler-name model (`mock.addonEvents` and
  `fireAddonEvent`). #27 does reach it, through the wrapped `aceGUI.Create`, but nothing calls
  `Release`, and the ScrollFrame `OnRelease` models a different thing from `AceGUI:Release`.
  Proposed as an issue, and nothing was filed during the run (owner decision, 2026-09-12). The owner
  later approved it, and it is filed as
  [tusharsaxena/WhatGroup#19](https://github.com/tusharsaxena/WhatGroup/issues/19). Detail is in
  `02_CANDIDATES.md`.

## Gates

| Gate | Before | After |
|---|---|---|
| `lua tests/run.lua` | 568 passed, 0 failed, 0 skipped | **569 passed, 0 failed, 0 skipped** |
| `luacheck .` | 0 / 0 in 41 files | **0 / 0 in 41 files** |
| `tests/test_vendor_sync.lua` | 2 cases, green | **3 cases, green**. The new one is the runner mode. |

`luacheck`'s figure is scoped by `.luacheckrc`'s `exclude_files`, which excludes `libs/` and
`tests/_kit/`. A clean run says the **host** is clean. The payload's own gate runs upstream.

## Not pushed

Committed on `chore/libka0s-1.30.0-arch5` only. Pushing and merging are `/wow-addon:finalize`'s job.
