Delta: LibKa0s v1.85.0 -> v1.89.0

Item `V89-WG` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`. The tag is pushed
(tag object `0bd4839`, commit `df00e5f`), extracted with
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C <scratch>`. Written before the copy.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md`:

    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).

The last commit touching either payload, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is
`be6f5d5` (R6-RV2: Re-vendor LibKa0s v1.85.0), and its CLAUDE.md names v1.85.0. No `CLAUDE.md` commit
since. The base is **v1.85.0**.

Step 0 (the run's `inputs/step0-preflight.txt`): `WhatGroup  2026-11-01-v1.85.0  base v1.84.0
vendored-before v1.84.0@ca3ad1c  ok`. No base correction.

`git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`: 25 commits, the v1.86.0 icon browser (IconBrowser
major, DebugLogDiagnostics 7), the v1.87.0 cascading menus (Widgets 23), the v1.88.0 toast stack
(Toast 4) and the v1.89.0 kit revision 51. `git -C ../LibKa0s diff --stat v1.85.0 v1.89.0`: 83 files.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reads every file at
its v1.85.0 minor (Toast 3, Widgets 22, DebugLogDiagnostics 6, no IconBrowser files). Line and bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s/LibKa0s.xml` loop)

| File | Old | New |
|---|---|---|
| `Toast.lua` | 3 | **4** |
| `Widgets.lua` | 22 | **23** |
| `DebugLogDiagnostics.lua` | 6 | **7** |
| `IconBrowserSources.lua` | (absent) | **1** (new major `LibKa0s-IconBrowser-1.0`) |
| `IconBrowserWindow.lua` | (absent) | **1** |
| `IconBrowser.lua` | (absent) | **1** |

Every other file is unchanged. No consumer file is ahead of or behind the tag except as listed: no
cross-major skew.

## 3d. Diffs before the copy

`diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (content): `DebugLogDiagnostics.lua`,
`LibKa0s.xml`, `Toast.lua`, `Widgets.lua` differ; `Only in <scratch>/LibKa0s` for the three IconBrowser
files; `Only in <scratch>/LibKa0s/media/icons` for the undeclared icons (the declaration working). No
`Only in libs/LibKa0s`, no `differ` under `media/icons`. The byte diff (`diff -rq`) lists the same
paths and nothing else, so no line-ending drift.

`diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit`: `README.md`, `framework.lua`,
`mock_ace.lua` differ (kit 51). Byte diff the same.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Media (`core/MediaSetup.lua:50`), Lifecycle (`core/LifecycleSetup.lua:38`), Launcher
(`core/LauncherSetup.lua:42`), Env (`core/EnvSetup.lua:41`), Skin (`core/SkinSetup.lua:79`), DebugLog
(`core/DebugLogSetup.lua:20`), Core (`core/CoreSetup.lua:46`), Compat (`core/Compat.lua:36`), Options
(`settings/OptionsSetup.lua:17`), Slash (`settings/Slash.lua:134`), Schema (`settings/SchemaSetup.lua:236`).

No lookup of Toast, Widgets or IconBrowser. The host has no `W.ContextMenu` site
(`grep -rn 'ContextMenu\|MenuUtil' core modules settings` finds nothing; the launcher's right-click menu is
the library's own `MenuUtil` menu, `Launcher.lua:478-488`, minor unchanged).

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` reads 51, `tests/_kit/framework.lua:20` reads 50.
Both payloads move together in one commit, which keeps the pairing rule (kit 11+ with v1.9.0+) by
construction.

## 3g. Contract delta

Moved majors intersected with consumed ones: DebugLog (DebugLogDiagnostics 7). Its change is one report
line (`LibKa0s running:` names `IconBrowser`, CHANGELOG v1.86.0), no member moves. Toast 4 owes a host's
instance stub `SetStack`, `Visible` and `FrameFor` (CHANGELOG v1.88.0); this addon has no Toast lookup
and no Toast stub, so nothing is owed. Widgets 23 is not looked up by the host.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`:
no site.

**Blockers:** no contract change. One mechanical blocker, found by the gate after the copy rather than
by this read: `tests/loader.lua`'s explicit LibKa0s list must match `LibKa0s.xml` in XML order (the
harness case "the explicit LibKa0s list matches LibKa0s.xml, in XML order", red with `expected 67, got
64`). Fixed in the re-vendor commit by listing `IconBrowserSources.lua`, `IconBrowserWindow.lua` and
`IconBrowser.lua` after `OptionsMedia.lua`, as the tag's XML has them (`LibKa0s.xml:58-60`).

## 3h. Span check

The audit walk plus the provenance-roll walk from the store's horizon (2026-08-25): 63 tags vendored,
63 recorded, `grep -vxF -f recorded.txt vendored.txt` prints nothing. No span bundle.

## 3i. The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md`:

    49:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

The next non-blank line after the provenance line; no split owed. **Kept as is (decided by the run, no
re-ask).** The range adds library-drawn names only for surfaces this addon does not wire: `search` and
`close` for the icon browser (tag `docs/releasing.md:371-372`), and `confirm` for an owned
`W.ContextMenu` radio tick (`docs/releasing.md:365`), already declared. Hand lists have drifted before
(KickCD `tests/test_mediasetup.lua:28`, this addon's own `tests/test_mediasetup.lua:19`); the owner's
in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
`tests/test_mediasetup.lua:128,141,167-176,189,261`. These were narrowed to the declaration at the v1.75.0
re-vendor and pass against the v1.85.0 prune; the set is unchanged, so no blocker.
