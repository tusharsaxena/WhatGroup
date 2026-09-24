# Re-vendor delta: LibKa0s v1.57.0 -> v1.58.0

Written 2026-09-25 for plan item `M6-WG` of the 2026-09-23 review and standards-audit remediation
(milestone M6, the launcher's left-click settings and right-click options menu), in the shape of the
`M5-WG` bundle (`docs/revendor/2026-09-24-v1.57.0/`). Scope: pre-flight, resolve, delta and copy,
plus the one adoption the release owes (`launcher-§2`, standard v2.67.0), which M6-WG takes in the
same change rather than as a separate interview: the owner ruled the menu a MUST before the merge,
so there is no candidate to decline. This bundle therefore carries no `02_CANDIDATES.md`,
`03_DECISIONS.md` or `04_EXECUTION_PLAN.md`.

## Step 0: pre-flight on the newest bundle's base

```sh
b=docs/revendor/2026-09-24-v1.57.0   # newest single-tag bundle
head -1 $b/01_DELTA.md               # "Re-vendor delta: LibKa0s v1.56.0 -> v1.57.0"
```

`WhatGroup  2026-09-24-v1.57.0  base v1.56.0  vendored-before v1.56.0  ok`

No base correction is owed.

## Step 2: the tag

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.58.0 (local tag, not pushed)
git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/tag/
```

Extracted from the tag (`34931c9`), never from the library's working tree or a checkout of it.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/old/
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

- `CLAUDE.md:79`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.57.0 (MIT).`
- The last payload commit `6fa4e71` (M5-WG) left the line at v1.57.0, and the payload printed
  `payload-matches`. **Base: v1.57.0.** The range is `v1.57.0..v1.58.0`, two library commits
  (`02999d0` LK-37: Launcher minor 4; `34931c9` LK-37: the release run's record).

## 3b. Actual version

Every vendored minor equalled v1.57.0's before the copy. Claim and fact agree; no skew.

## 3c. Per-file minor delta

| File | Constant | v1.57.0 (vendored) | v1.58.0 (tag) |
|---|---|---|---|
| `Launcher.lua` | `MINOR` | 3 | **4** |

Every other file in `LibKa0s.xml` is byte-identical between the two tags (`git diff --stat
v1.57.0 v1.58.0 -- LibKa0s testkit`: one file, +163 / -94). No file is added or removed, no
`NEEDS_*` floor rises (`NEEDS_CORE = 1`, as before), and there is **no cross-major skew**.

## 3d. Both diffs

Before the copy, `diff -rq` of the tag against the vendored folders reported exactly one line,
`libs/LibKa0s/Launcher.lua differ`, and nothing under `tests/_kit`.

After the copy (`rm -rf` both folders, then `cp -r <scratch>/tag/LibKa0s/. libs/LibKa0s/` and
`cp -r <scratch>/tag/testkit/. tests/_kit/`), all four diffs (`diff -r` and
`diff -r --strip-trailing-cr`, both payloads) are **empty**. Git sees one changed payload file,
`libs/LibKa0s/Launcher.lua`.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core settings modules
```

Ten majors consumed, one lookup site each: Core (`core/CoreSetup.lua:39`), Env
(`core/EnvSetup.lua:41`), Compat (`core/Compat.lua:34`), Lifecycle (`core/LifecycleSetup.lua:38`),
**Launcher (`core/LauncherSetup.lua:42`)**, Media (`core/MediaSetup.lua:50`), DebugLog
(`core/DebugLogSetup.lua:20`), Options (`settings/OptionsSetup.lua:17`), Slash
(`settings/Slash.lua:113`) and Schema (`settings/SchemaSetup.lua:236`). Launcher is the only one
whose minor moved.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION = 26` in both the tag and the vendored copy (`tests/_kit/framework.lua:20`). The kit
bytes are v1.56.0's; the pairing rule holds with no kit move.

## 3g. Contract delta

`Launcher/version-3-docs.md` -> `Launcher/version-4-docs.md` (read at the tag), with the v1.58.0
block of the library's `CHANGELOG.md` and its *What a consumer owes on re-vendoring v1.58.0*.

| What moved under an unchanged surface | Reaches WhatGroup? |
|---|---|
| Left-click always calls `openSettings`; `onClick` is ignored | **Yes, class A (breaking for rung (a))**: on the copy alone the left button stopped toggling the group popup and opened the panel. Three host tests went red (the rung (a) toggle, the left-click dismissal ending test mode, the disabled refusal). |
| The disabled left-click refusal (`disabledLine`) is gone | **Yes**: `disabled 8` in `tests/test_disabled.lua` and the launcher refusal case went red. |
| The tooltip hints are fixed (`Left-click: Open settings`, `Right-click: Options menu`); `leftClickLabel` and `slash` are ignored | **Yes**: the three tooltip-shape cases went red on the hint lines. |
| Right-click opens `MenuUtil.CreateContextMenu` when the descriptor passes at least one pair; otherwise the panel | No on the copy alone: WhatGroup passed `isEnabled` but no `setEnabled`, so right-click still opened the panel. |
| Four new optional toggles (`setEnabled`, `toggleLock`, `toggleTestMode`, `toggleWindow`) and one accessor (`isWindowShown`); seven `MENU_*` strings and `TOOLTIP_OPTIONS_MENU` | **Owed by `launcher-§2`** (standard v2.67.0), taken by M6-WG below. |

Seven cases red after the copy (773 / 7 of 780), every one a pin on minor 3's click or hint
behavior, which is what the library's CHANGELOG says a consumer re-pins. No stub member moved:
the member manifest is version 3's.

`__Attach*` sweep over the addon's own code: no hits, as at v1.57.0.

## Blockers

None. The reds are the owed re-pins, not contract breaks the addon cannot adopt.

## What M6-WG owes, and takes

The standard's `ADDONS.md` row for Ka0s WhatGroup records four entries: *Enabled · Locked · Test
mode · Show window (the group popup)*. The code has all four, so the row and the code agree.

- `setEnabled(on)` → `WhatGroup:SlashEnabled(on)`, which is `runEnabled`, the body both
  `/wg enable` and `/wg disable` call (`settings/Slash.lua`). `isEnabled` stays the latch.
- `toggleLock` → `WhatGroup:SlashToggleLock()`, which runs `/wg set locked toggle`. WhatGroup
  registers no `/wg lock` verb (slash-commands-§8 MAY: the lock is the *Lock frame* checkbox), so
  the lock's slash path is the schema CLI over the row's own path, through the same write seam.
  `isLocked` stays the profile's `locked`.
- `toggleTestMode` → `WhatGroup:SlashToggleTestMode()`, which is `runTest("")`, bare `/wg test`.
  `isTestMode` stays `NS.State.testMode`.
- `toggleWindow` → `WhatGroup:ToggleFrame()` (the Close button's and ESC's seam), and
  `isWindowShown` → the new `WhatGroup:IsFrameOnScreen()`, the same `onScreen()` ToggleFrame
  branches on.
- Deleted: `onClick`, `leftClickLabel` (and its locale row `L["Toggle group popup"]`) and
  `disabledLine`. `slash` was never passed.
- Kept from M5: `version`, `isLocked`, `isTestMode`. No `onTooltipShow`.

## 3h. Tags vendored and never recorded

v1.57.0 has its bundle and v1.58.0 is this one; the range adds no unrecorded tag.
