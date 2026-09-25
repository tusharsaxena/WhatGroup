# Re-vendor delta: LibKa0s v1.58.0 -> v1.60.0

Written 2026-09-26 for plan item `DR-WG-01` of the 2026-09-25 diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`, milestone M3), run as
`/wow-addon:revendor-libka0s --tag v1.60.0`. The range skips v1.59.0 on purpose: the plan gives every
addon one re-vendor, straight to v1.60.0, which carries v1.59.0's DragHandle change as well.

## Step 2: the tag

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.60.0
git -C ../LibKa0s rev-parse --short v1.60.0^{commit}   # bed0eb1
git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/wg-v160/
```

Extracted from the tag, never from the library's working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/wg-v158/
diff -rq <scratch>/wg-v158/LibKa0s libs/LibKa0s && diff -rq <scratch>/wg-v158/testkit tests/_kit && echo payload-matches
```

- `CLAUDE.md:79`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.58.0 (MIT).`
- The payload printed `payload-matches`. **Base: v1.58.0.** The range `v1.58.0..v1.60.0` is sixteen
  library commits, from `e8faa5d` (WidgetsDragHandle minor 3) to `bed0eb1` (the v1.60.0 release record).

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Every vendored minor equalled v1.58.0's before the copy. The claim and the payload agree, and there is no skew.

## 3c. Per-file minor delta

Files read from the tag's `LibKa0s/LibKa0s.xml`, in load order.

| File | Constant | v1.58.0 (vendored) | v1.60.0 (tag) |
|---|---|---|---|
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | **3** |
| `DebugLog.lua` | `MINOR` | 13 | **14** |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` | absent | **1** (new file) |
| `Slash.lua` | `MINOR` | 15 | **16** |

Every other file is unchanged: Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 10, Launcher 4, Options 24, OptionsWidgets 31, OptionsTabs 4,
OptionsCompose 7, OptionsScroll 4, Perf 13, PerfPanel 5. `git diff --stat v1.58.0 v1.60.0 -- LibKa0s
testkit` lists eight files, +868 / -39. One file is added (`DebugLogDiagnostics.lua`), none is removed,
no `NEEDS_*` floor rises, and there is **no cross-major skew**.

## 3d. Both diffs

Before the copy, `diff -rq` of the tag against the vendored folders listed `DebugLog.lua`,
`LibKa0s.xml`, `Slash.lua` and `WidgetsDragHandle.lua` as differing, `Only in <tag>:
DebugLogDiagnostics.lua`, and under the kit `README.md` and `framework.lua` as differing, with
`Only in <tag>: test_diagnostics_contract.lua`. The content diff (`--strip-trailing-cr`) shows the same
set. So the copy is behind the tag and has not forked. Nothing appears as `Only in libs/LibKa0s`.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Ten majors are consumed, each at one lookup site: Core (`core/CoreSetup.lua:39`), Env (`core/EnvSetup.lua:41`),
Compat (`core/Compat.lua:34`), Lifecycle (`core/LifecycleSetup.lua:38`), Launcher
(`core/LauncherSetup.lua:42`), Media (`core/MediaSetup.lua:50`), **DebugLog
(`core/DebugLogSetup.lua:20`)**, Options (`settings/OptionsSetup.lua:17`), **Slash
(`settings/Slash.lua:113`)** and Schema (`settings/SchemaSetup.lua:236`). DebugLog and Slash are the
consumed majors whose minors moved. WhatGroup has no DragHandle host (`grep -rln DragHandle core
settings modules` returns nothing), so WidgetsDragHandle 3 reaches a file the addon never calls.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/wg-v160/testkit/framework.lua tests/_kit/framework.lua
```

The tag has `Kit.VERSION = 27` and the vendored copy has 26. The kit moves this time and gains
`test_diagnostics_contract.lua`. Both payloads are copied whole in one commit, so the pairing rule
holds by construction.

## 3g. Contract delta

Read `DebugLog/version-13-docs.md` → `version-14.1-docs.md` and `Slash/version-15-docs.md` →
`version-16-docs.md` at the tag, together with the v1.60.0 block of the library's `CHANGELOG.md` and
its section *What a consumer owes on re-vendoring v1.60.0*.

| What moved under an unchanged surface | Reaches WhatGroup? |
|---|---|
| `MAX_BUFFER` 1500 → 3000, `BUFFER_SLACK` 64 → 128 (`version-14.1-docs.md`, Compatibility) | The code needs no change: `grep -rn '1500\|MAX_BUFFER\|BUFFER_SLACK' tests/*.lua core settings modules` finds no buffer literal in any suite (the two `1500` hits are the layout-§1 file cap). Doc sites that say `N / 1500 lines` (`docs/ARCHITECTURE.md:262`, `docs/smoke-tests.md:106,736`) are DR-WG-05's. |
| The library-absent DebugLog stub is an instance surface, so it gains `RunDiagnostics`, `BuildDiagnostics` and `DebugVerb` (`version-14.1-docs.md`, Compatibility) | **Yes.** The `parity: the DebugLog stub carries the whole live surface` case (`tests/test_surface_parity.lua:90`) fails until `core/DebugLogSetup.lua`'s stub gains all three. The stub goes in the copy commit. |
| `lib.LIVE_VERBS` gains `diagnostics` (`Slash/version-16-docs.md`) | WhatGroup passes no `liveVerbs` (`settings/Slash.lua:105`), so the default applies. There is no `diagnostics` row yet, so a disabled `/wg diagnostics` still answers `unknown command`, because the gate sits after the COMMANDS lookup. The host's copy of the list, `tests/test_slash.lua:473-475`, gains the verb in the copy commit. The live-row count at `:561` then allows for the one live verb that has no row yet, until DR-WG-03 adds the row. |
| The kit's suite inventory: `tests/run.lua` must declare `test_diagnostics_contract` from `tests/_kit/` | **Yes.** `Kit.assertSuiteInventory` fails the run until the suite is declared. With `Kit.diagnostics` unset it registers one declared skip. |

`__Attach*` sweep over the addon's own code (`grep -rn '__Attach[A-Za-z]*' . --include='*.lua'
--exclude-dir=libs --exclude-dir=_kit`): no hits.

## Blockers

None. Every item above is an owed re-pin that the CHANGELOG names, and each one lands in the copy
commit.
