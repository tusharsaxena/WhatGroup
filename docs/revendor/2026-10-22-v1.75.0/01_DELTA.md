Delta: LibKa0s v1.71.0 -> v1.75.0

# LibKa0s v1.71.0 to v1.75.0: the delta (WhatGroup)

Item WG-RV of the 2026-10-22 run "LibKa0s issues #45-#58"
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`). It was run per the installed
`/dev-copilot:wow-revendor-libka0s` (2.4.0) with no interview and no issue filing, because the run's
`inputs/OWNER_SCOPE.md` and the item spec decide every candidate in advance. Copied from the
annotated tag `v1.75.0` (tag object `eae0ee5`, LibKa0s commit `265a89e`) with
`git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x`. The tag is **local only**. It
sits on LibKa0s's `feat/2026-10-22-libka0s-issues-45-58` and stays off origin until the owner gives
the go-ahead.

## 3a. The base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit); git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0
diff -rq <v1.71.0>/LibKa0s libs/LibKa0s && diff -rq <v1.71.0>/testkit tests/_kit && echo payload-matches
# payload-matches
```

The provenance line, the last payload commit and the payload all agree, so the base is **v1.71.0**.
`git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` lists 56 commits. This addon never vendored
v1.72.0, v1.73.0 or v1.74.0 (none was tagged on origin), so 3h needs no span bundle. The newest
earlier bundle, `2026-10-07-v1.71.0/`, states base v1.70.0, which matches its own provenance
history, so there is nothing to correct.

## 3b / 3c. Per-file minors (the tag's `LibKa0s.xml`, 40 files)

| File | old (v1.71.0) | new (v1.75.0) | Since |
|---|---|---|---|
| `Core.lua` | 10 | 11 (comment-only) | v1.75.0 |
| `Item.lua` | 2 | 3 (`Item.BonusIDsFromLink`) | v1.75.0 |
| `Glow.lua` | (new) | 1 (`LibKa0s-Glow-1.0`) | v1.75.0 |
| `Media.lua` | 4 | 5 (`ICON_SETS`, `IconAuthor`, 5,836 names) | v1.74.0 |
| `MediaIcons.lua` | (new) | `ICONS_MINOR` 1 | v1.74.0 |
| `Widgets.lua` | 12 | 13 (`W.SearchBox`, `W.TestStrip`) | v1.75.0 |
| `DebugLog.lua` | 19 | 20 (comment-only) | v1.75.0 |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` 2 | 3 (header names Glow and Sim) | v1.75.0 |
| `Options.lua` | 28 | 29 (Drawer attach; structural refresh keeps scroll) | v1.73.0 |
| `OptionsIdList.lua` | `IDLIST_MINOR` 4 | 5 (comment-only) | v1.75.0 |
| `OptionsTabs.lua` | `TABS_MINOR` 8 | 9 (`O.__releaseChrome` removed, LibKa0s#45) | v1.75.0 |
| `OptionsDrawer.lua` | (new) | `DRAWER_MINOR` 1 (`O.Drawer`) | v1.73.0 |
| `Perf.lua` | 14 | 15 (`Perf.Note` top level) | v1.72.0 |
| `PerfPanel.lua` | `PANEL_MINOR` 6 | 7 (comment-only) | v1.75.0 |
| `Sim.lua` | (new) | 1 (`LibKa0s-Sim-1.0`) | v1.75.0 |
| `SimTimeline.lua` | (new) | `TIMELINE_MINOR` 1 | v1.75.0 |
| `SimPanel.lua` | (new) | `SIM_PANEL_MINOR` 1 | v1.75.0 |
| every other file (23) | | unchanged | |

Command: the 3c loop over `git -C ../LibKa0s show v1.75.0:LibKa0s/LibKa0s.xml`, printing only the
rows that differ. The XML now lists 40 files, up from 34, and no file was removed. No consumer
file was behind, so there is no cross-major skew.

## 3d. Both diffs

Before the copy, the content diff `diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s` named
the 12 files above that moved and the 6 new files only in the tag. It also listed 113 `Only in
<tag>/.../media/icons` entries: the 111 new Open Iconic marks plus the `phosphor/` and `game-icons/`
folders. The testkit diff named `README.md`, `framework.lua`, `inventory.lua`, `mock_base.lua`,
`mock_record.lua`, `run-automated-tests.sh` and `vendor_sync.lua`, with `latch.lua` only in the tag.
**Nothing was only in the addon**, so the copy deletes nothing outside the prune.

After `cp -r` of both payloads, and **before the prune**, both content diffs and both byte diffs
were empty (`CONTENT-CLEAN`). After the prune, the only remaining difference is the expected
`Only in <tag>/LibKa0s/media/icons` set: everything this addon does not declare.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

The addon consumes ten majors: Core, Env, Compat, Lifecycle, Media, DebugLog, Options, Schema,
Slash and Launcher, one lookup site each, unchanged from v1.71.0. It does not consume Widgets
(declined, #12), Perf (declined, #7), Bus, Pool, Item, or the two new majors Glow and Sim.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION =' <tag>/testkit/framework.lua tests/_kit/framework.lua
# <tag>/testkit/framework.lua:20:Kit.VERSION = 41
# tests/_kit/framework.lua:20:Kit.VERSION = 38
```

Kit revision **38 -> 41**:

- 39 lets `M.__fireUnconditional` reach method-name and function handlers after an unregister, and
  adds `Kit.assertLatchHoldOrder` (`latch.lua`).
- 40 makes `vendor_sync.lua` hold `media/icons/` to the `LibKa0s icons:` declaration.
- 41 turns a crashed or bounded lizard run into a complexity fail with a `crashedFiles` bucket, and
  drops the dead `Kit.__deviationRows` / `Kit.__declineFor`. This addon calls neither:
  `grep -rn '__deviationRows\|__declineFor' tests` outside `_kit` is empty.

Both payloads come from the one tag in one commit, so the pairing rule holds by construction.

## 3g. Contract delta

Majors whose minor moved, intersected with the majors this addon consumes: **Core, Media, DebugLog
and Options**.

- **Core 11, DebugLog 20, OptionsIdList 5.** Comment-only (#57). No member or behavior moved.
- **Media 5 / MediaIcons 1.** `ICONS` grows to 5,836 names; `ICON_SETS` and `IconAuthor` are new.
  `NS.Icon` passes names through to `Media.Icon` unchanged, so no host contract moves. The surface
  parity case for Media is unaffected (this addon carries no Media stub pinned by name).
- **DebugLogDiagnostics 3.** The `LibKa0s running:` line names Glow and Sim. This addon does not
  parse its own report.
- **Options 29 / OptionsDrawer 1 (v1.73.0).** A structural refresh of a page on screen now keeps its
  scroll offset. `settings/Profiles.lua:86` calls `H.RefreshPanel(page, true)` on a profile switch
  and never scrolled back to the top by hand, so this arrives free (smoke SM-WG-4). `O.Drawer` is
  new on the live surface. **Blocker (a).**
- **OptionsTabs 9.** `O.__releaseChrome` is removed. **Blocker (b).**

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty.

### Blockers (fixed in this commit)

- **(a) Options stub Drawer parity.** `tests/test_surface_parity.lua` "parity: the Options helpers
  stub carries the whole live surface" went red after the copy (`Drawer is missing (live:
  function)`). Fix: `settings/OptionsSetup.lua` stub gains `H.Drawer = function() end`, inert for
  the shape reason like `NavRail`.
- **(b) Dead `H.__releaseChrome` mirror** (LibKa0s#45, OWNER_SCOPE G, the KickCD M4-09
  precedent). Deleted from the stub. The block comment's count moves from "nine ... twelve in all"
  to "eight ... eleven in all", with one sentence on why the ninth went.
- **(c) Kit 39 `__fireUnconditional`.** `tests/test_disabled.lua` "disabled 6" now really reaches
  `GROUP_ROSTER_UPDATE` and `OnCombatStateChanged` while stood down. It stayed green: **no
  stand-down reds**, so no handler needed a new `NS.IsStoodDown()` guard.
- **(d) Icon tests rewritten to the declaration (3j).** After the prune,
  `tests/test_mediasetup.lua` "the whole catalog has a file in the vendored copy" and
  `tests/test_libka0s.lua` "...and the help-mark art is on disk" (`info.tga`) went red.
  - The whole-catalog case is replaced by "every declared icon has a file in the vendored copy, and
    nothing undeclared ships". It parses `CLAUDE.md` with the kit's
    `VendorSync.iconDeclaration`, never a second parser.
  - The hand list `DRAWN = { "close" }` becomes `LIBRARY_DRAWN = { "clear", "close", "copy" }`, with
    each draw site named in a comment.
  - A new case, "the declaration names every icon the library draws for this addon", is red when a
    name is dropped from the `CLAUDE.md` line. This was checked by mutation in a scratch copy.
  - The `info.tga` block now asserts that a settings file calling `IdList` (other than the
    degradation stub) forces `info` onto the declaration. Today no such call exists. This was also
    red under mutation, with an `O.IdList(...)` call appended to `settings/Panel.lua`.
- **(e) `tests/loader.lua` LIBKA0S list.** It now follows the tag's XML order. `Glow.lua` goes after
  `Item.lua`, `MediaIcons.lua` after `Media.lua`, `OptionsDrawer.lua` after `OptionsNav.lua`, and
  `Sim.lua`, `SimTimeline.lua` and `SimPanel.lua` after `PerfPanel.lua`. Each carries a "New in
  LibKa0s vX ... Nothing here adopts it" comment. No `WidgetsStepPanel.lua`: LK-11's outcome was B,
  so the tag has no such file.
- **(f) Stale kit-revision mentions.** `DEPENDENCIES.md` section 2.3 and the `complexity` row in
  `docs/testing.md` now name kit revision 41 and say that a crashed or bounded lizard run is a
  complexity fail (`crashedFiles` 0 required). The historical comments in `tests/run.lua` stay
  as they are.

## 3h. Tags vendored and never recorded

None. Every tag this addon vendored has a bundle, and v1.72.0 through v1.74.0 were never vendored
here.

## 3i. The icon declaration

**Decided by the run's item spec (WG-RV), so not re-asked:**

```
LibKa0s icons: close, copy, clear.
```

- **close**: library-drawn by `Core.MakeCloseButton` (`libs/LibKa0s/Core.lua:245`,
  `Media.Icon(addonName, "close")`). It is reached through the DebugLog console and its copy window
  because `core/DebugLogSetup.lua:155` passes `addonName`, and through `NS.MakeCloseButton`
  (`core/CoreSetup.lua:164-166`), which has no caller today.
- **copy**, **clear**: the DebugLog title bar (`libs/LibKa0s/DebugLog.lua:292-293`, via
  `makeIconButton` at `:241`).
- **No addon-drawn icon.** `NS.Icon` (`core/MediaSetup.lua:65`) has no caller outside tests (see the
  header at `:31`). `modules/Frame.lua`'s Close is a text button.
- **info is not declared.** Only `OptionsIdList`'s help mark draws it, and this addon builds no id
  list: `settings/OptionsSetup.lua:137` is the degradation stub, and `settings/Panel.lua` draws none.
  WhatGroup hosts no `W.TestStrip`; per OWNER_SCOPE A #48 and F, its "Test Group - ..." content is
  its marker.
- No `ph:` or `gi:` names.

Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, and this repo's own
`tests/test_mediasetup.lua:19`, which listed only `close`). The owner's in-client smoke is the
backstop: a pruned icon still resolves to a path and draws blank (DIAG-12, DIAG-13).

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

This finds `tests/test_libka0s.lua:303-304` (`info.tga`) and `tests/test_mediasetup.lua:112, :125,
:139-141, :198`. Of these, `:139-141` (the whole-catalog loop) and the `info.tga` open were
blockers. Both are fixed under (d). `:112` and `:198` read `Media.ICONS` (the catalog of names, not
files), and `:125` reads only the drawn names, so all three stay correct after the prune.
