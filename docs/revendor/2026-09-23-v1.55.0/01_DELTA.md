# Re-vendor delta: LibKa0s v1.54.2 -> v1.55.0

Written 2026-09-23, **before** the copy (`revendor-libka0s.md` Step 3). Scope: Steps 2 to 4 only
(resolve, delta, copy). Candidates and adoption (Steps 5 to 8) belong to a later pass; nothing
here is adopted.

## Step 2: the tag

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.55.0 (tagged locally, not pushed)
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/tag/
```

Extracted from the tag, not from the working tree.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
```

`CLAUDE.md:79` - `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.54.2 (MIT).`

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Every vendored minor equals v1.54.2's. Claim and fact agree; no skew before the copy.

## 3c. Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows), minors from the same
grep over `<scratch>/tag/LibKa0s/*.lua`.

| File | Constant | v1.54.2 (vendored) | v1.55.0 (tag) |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Compat-1.0`)** |
| `Lifecycle.lua` | `MINOR` | 1 | 1 |
| `Bus.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Bus-1.0`)** |
| `Schema.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Schema-1.0`)** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 14 | 14 |
| `Launcher.lua` | `MINOR` | 1 | 1 |
| `Options.lua` | `MINOR` | 23 | 23 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | 30 |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | 3 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 12 | 12 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

No existing file's minor moves. **No cross-major skew.** The payload gains three files and
`LibKa0s.xml` gains their three `<Script>` rows (Compat after Env; Bus and Schema after
Lifecycle).

```sh
git -C ../LibKa0s diff --stat v1.54.2 v1.55.0 -- LibKa0s testkit
```

`LibKa0s/`: `Bus.lua` +347, `Compat.lua` +298, `Schema.lua` +650, `LibKa0s.xml` +3.
`testkit/`: `README.md`, `framework.lua`, `run-automated-tests.sh`, `test_eol.lua`,
`test_prose.lua` changed; `test_layout_cap.lua` new (+737).

## 3d. Both diffs (before the copy)

```sh
diff -rq --strip-trailing-cr <scratch>/tag/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/tag/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/tag/testkit tests/_kit
diff -rq                     <scratch>/tag/testkit tests/_kit
```

- Library, content and bytes read the same: `Only in <tag>: Bus.lua, Compat.lua, Schema.lua`, and
  `LibKa0s.xml differ`. Every other file byte-identical.
- Kit, content and bytes read the same: `README.md`, `framework.lua`, `run-automated-tests.sh`,
  `test_eol.lua`, `test_prose.lua` differ; `Only in <tag>: test_layout_cap.lua`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing removed upstream, so the copy
  deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

| Major | Lookup site |
|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:39` |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua:41` |
| `LibKa0s-Lifecycle-1.0` | `core/LifecycleSetup.lua:38` |
| `LibKa0s-Launcher-1.0` | `core/LauncherSetup.lua:42` |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua:49` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:17` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:113` |

Eight majors consumed, one lookup site each. The three new majors (Compat, Bus, Schema) have no
lookup anywhere: unadopted, and they feed Step 5 (not this pass). Perf, Widgets, Pool and Item are
reached only through the library's own internal lookups.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/tag/testkit/framework.lua tests/_kit/framework.lua
```

Tag: `Kit.VERSION = 25` (`framework.lua:20`). Vendored: `24`. Revision 25 is the kit that ships
with v1.55.0, and both payloads move in one commit. The revision-11 floor for LibKa0s v1.9.0 and
newer is satisfied by construction.

## 3g. Contract delta

**Library.** The read is the majors whose minor moved (3c: none) intersected with the majors this
addon looks up (3e: eight). The intersection is empty, so no library contract can have moved
under a surface this addon calls.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
```

No hits: this addon hands the library no host-supplied member through an `__Attach*` seam.

**Kit.** Revision 25 changes what the harness requires of the runner, with no signature moving.
These do not appear in 3c, and each one reddens the run on the copy.

1. **Suite declaration is keyed by the pair (basename, directory)** (`framework.lua` rev 25,
   `collectKitHoles`). Under rev 24 the bare `"test_prose"` entry in `tests/run.lua:124` wired
   this repo's own `tests/test_prose.lua` and *also* satisfied the inventory for
   `tests/_kit/test_prose.lua`, so the kit's copy loaded zero cases and nothing said so. Rev 25
   reports that as a collision (a failure, and `Kit.run` aborts before any case runs) unless the
   runner wires `{ name = "test_prose", dir = "tests/_kit/" }` and the repo copy goes, or a
   `## Documented deviations` row keyed `localization-5` declines the kit gate by path.
   Commit `7f38ddd`'s message says the repo copy was deleted and the kit gate wired; the tree
   shows neither happened (`git show --stat 7f38ddd` touches only `CLAUDE.md` and `tests/_kit/`).
2. **`tests/_kit/test_layout_cap.lua` arrives undeclared** and fails the inventory until wired as
   `{ name = "test_layout_cap", dir = "tests/_kit/" }` (`testing-§9`). It then requires a
   `### Files over the 1500-line cap` census directly under `## Documented deviations` in
   `docs/ARCHITECTURE.md` (`layout-§1`); an empty census is written as a result ("Nothing is over
   the cap today"), never left blank.
3. **The kit's prose gate carries the full `localization-§5` list**, and five tracked lines hold
   `cancelled`. One is prose (`core/WhatGroup.lua:317`). Four are tokens the repo does not own:
   Blizzard's `LFG_LIST_APPLICATION_STATUS_UPDATED` status (`core/WhatGroup.lua:940`,
   `docs/data-flow.md:56`, `tests/test_capture.lua:437`) and AceTimer's handle field
   (`tests/test_notify.lua:159`). The repo's own gate waived those four per file and per word;
   the kit reads the same waivers from `tests/prose_waivers.lua` (`localization-§5`'s waiver MAY).
4. **The hand-typed library list** at `tests/loader.lua:24` (`LIBKA0S`) is pinned to the XML by
   `tests/test_harness.lua:51`, so it must gain `Compat.lua`, `Bus.lua`, `Schema.lua` in XML order
   in the same commit. The `NO_LIBKA0S` skip lists (`tests/test_envsetup.lua:18`,
   `tests/test_libka0s.lua:489`, `tests/test_mediasetup.lua:24`) name the payload for the
   whole-library-missing case and gain the same three.

## Blockers

**None that need a decision.** No library contract moved under a consumed surface (3g, library
half). The four kit-side items above are required wiring, and each is resolved beside the payload
in the vendor commit, or in a prep commit that is green on the old kit (items 1 and 3, and the
census heading of item 2).
