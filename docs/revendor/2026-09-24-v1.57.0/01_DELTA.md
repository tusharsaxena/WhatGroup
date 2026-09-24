# Re-vendor delta: LibKa0s v1.56.0 -> v1.57.0

Written 2026-09-24 for plan item `M5-WG` of the 2026-09-23 review and standards-audit remediation
(milestone M5, the always-on launcher status tooltip), in the shape of the `RV-WG` bundle
(`docs/revendor/2026-09-23-v1.56.0/`). Scope: pre-flight, resolve, delta and copy, plus the one
adoption the release owes (`launcher-§1`), which M5-WG takes in the same change rather than as a
separate interview: the owner ruled the tooltip a MUST before the merge, so there is no candidate to
decline. This bundle therefore carries no `02_CANDIDATES.md`, `03_DECISIONS.md` or
`04_EXECUTION_PLAN.md`.

## Step 0: pre-flight on the newest bundle's base

```sh
b=docs/revendor/2026-09-23-v1.56.0   # newest single-tag bundle
head -1 $b/01_DELTA.md               # "Delta: LibKa0s v1.55.0 -> v1.56.0"
```

`WhatGroup  2026-09-23-v1.56.0  base v1.55.0  vendored-before v1.55.0@a60a3d6  ok`

No base correction is owed.

## Step 2: the tag

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.57.0 (local tag, not pushed)
git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/tag/
```

Extracted from the tag (`aa37bc9`), never from the library's working tree or a checkout of it.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
git log -1 --format=%h -- libs/LibKa0s tests/_kit                     # 06fe762 (RV-WG)
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/old/
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

- `CLAUDE.md:79`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.56.0 (MIT).`
- The last payload commit `06fe762` left the line at v1.56.0, and the payload printed
  `payload-matches`. **Base: v1.56.0.** The range is `v1.56.0..v1.57.0`, two library commits
  (`281f26f` LK-36: Launcher minor 3; `aa37bc9` LK-36: the release run's record).

## 3b. Actual version

Every vendored minor equalled v1.56.0's before the copy. Claim and fact agree; no skew.

## 3c. Per-file minor delta

| File | Constant | v1.56.0 (vendored) | v1.57.0 (tag) |
|---|---|---|---|
| `Launcher.lua` | `MINOR` | 2 | **3** |

Every other file in `LibKa0s.xml` is byte-identical between the two tags (`git diff --stat
v1.56.0 v1.57.0 -- LibKa0s testkit`: one file, +109 / -4). No file is added or removed, no
`NEEDS_*` floor rises, and there is **no cross-major skew**.

## 3d. Both diffs

Before the copy, `diff -rq` of the tag against the vendored folders, with and without
`--strip-trailing-cr`, reported exactly one line, `libs/LibKa0s/Launcher.lua differ`, and nothing
under `tests/_kit`.

After the copy (`rm -rf` both folders, then `cp -r <scratch>/tag/LibKa0s/. libs/LibKa0s/` and
`cp -r <scratch>/tag/testkit/. tests/_kit/`, with the kit's shell runner kept executable), all four
diffs are **empty**. Git sees one changed payload file, `libs/LibKa0s/Launcher.lua`.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
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

`Launcher/version-2-docs.md` -> `Launcher/version-3-docs.md` (read at the tag), with the v1.57.0
block of the library's `CHANGELOG.md` and its *What a consumer owes on re-vendoring v1.57.0*.

| What moved under an unchanged surface | Reaches WhatGroup? |
|---|---|
| The LDB object's `OnTooltipShow` is always the library's `drawTooltip`: title, `Enabled`, optional `Locked` / `Test mode`, the host's lines, the two click hints, drawn while disabled too | **Yes, class A**: the button answers a hover with the status block on the copy alone. WhatGroup passed no `onTooltipShow`, so nothing is drawn twice. No host test called `OnTooltipShow`, so nothing went red (775/775 after the copy). |
| `onTooltipShow` now appends instead of replacing | No: WhatGroup passes none. |
| Five new optional descriptor fields (`version`, `isLocked`, `isTestMode`, `leftClickLabel`, `slash`) and fourteen `TOOLTIP_*` strings | **Owed by `launcher-§1`** (standard v2.66.0), taken by M5-WG below. |

`__Attach*` sweep: no hits, as at v1.56.0.

## Blockers

None. The copy alone is green.

## What M5-WG owes, and takes

- `version`: the TOC's, through `NS.Version` (`core/EnvSetup.lua`), dropping `?` so a degraded
  read draws the label alone.
- `isLocked`: WhatGroup has a Lock frame row (`locked`, profile; `modules/Frame.lua` reads it at
  drag time), so it is passed.
- `isTestMode`: WhatGroup has a test mode (`state.testMode`, `NS.State.testMode`), so it is passed.
- `leftClickLabel`: rung (a), the group popup (the standard's `ADDONS.md`), as
  `L["Toggle group popup"]`, keyed in `locales/enUS.lua`.
- `slash`: not passed. The hint's `/wg` is read out of `NS.SlashCommands:DisabledLine()`.
- `onTooltipShow`: none before, none after.

## 3h. Tags vendored and never recorded

v1.56.0 has its bundle and v1.57.0 is this one; the range adds no unrecorded tag.
