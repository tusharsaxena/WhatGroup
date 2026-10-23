Delta: LibKa0s v1.75.2 -> v1.76.0

# LibKa0s v1.75.2 to v1.76.0: the delta (WhatGroup)

Item WG-RV of the 2026-10-23 run "sim auto-run, QC preview selector, mode strips, MM/KCD simulators"
(`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`). It was run per the installed
`/dev-copilot:wow-revendor-libka0s` (2.4.0) with no interview and no issue filing, because the item
spec lists candidates without adopting them. Copied from the annotated tag `v1.76.0` (tag object
`546e284`, LibKa0s commit `9949368`) with `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools |
tar -x`. The tag is **local only** (`git -C ../LibKa0s ls-remote --tags origin v1.76.0` prints
nothing). It sits on LibKa0s's `feat/2026-10-23-sim-preview-mode-strips` and stays off origin until
the owner gives the go-ahead.

## 3a. The base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 8cbd735 Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)
diff -rq <v1.75.2>/LibKa0s libs/LibKa0s     # only the undeclared media/icons entries
diff -rq <v1.75.2>/testkit tests/_kit && echo kit-match
# kit-match
```

The provenance line, the last payload commit and the payload all agree, so the base is **v1.75.2**.
`git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` lists 8 commits (LK-00, LK-01, LK-10, LK-25 and
the LK-90 release commits, plus the v1.75.2 merge). Step 0 for this addon: the newest earlier
single-tag bundle, `2026-10-22-v1.75.0/`, states base v1.71.0, which matches the provenance line
before its re-vendor (`08dd668`), so there is nothing to correct.

## 3b / 3c. Per-file minors (the tag's `LibKa0s.xml`, 40 files)

| File | old (v1.75.2) | new (v1.76.0) | What moved |
|---|---|---|---|
| `Widgets.lua` | 13 | 14 | `W.TestStrip` `opts.kind = "sim"` (cyan) and read-only `strip.kind` |
| `SimTimeline.lua` | `TIMELINE_MINOR` 2 | 3 | a verb start or restart plays the run by itself |
| `SimPanel.lua` | `SIM_PANEL_MINOR` 4 | 5 | Run all removed; Pause/Resume, Restart, Stop |
| every other file (37) | | unchanged | |

Command: the 3c loop over `git -C ../LibKa0s show v1.76.0:LibKa0s/LibKa0s.xml`, printing only the
rows that differ. The XML still lists 40 files, and no file was added or removed. No consumer file
was behind, so there is no cross-major skew.

## 3d. Both diffs

Before the copy, `diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s` named the three files
above, plus the expected `Only in <tag>/LibKa0s/media/icons` entries (everything this addon does not
declare). `diff -rq <tag>/testkit tests/_kit` was empty. **Nothing was only in the addon**, so the
copy deletes nothing outside the prune.

After `cp -r` of both payloads, and **before the prune**, both content diffs and both byte diffs
were empty (`CONTENT-CLEAN`). After the prune, the only remaining difference is the expected
`Only in <tag>/LibKa0s/media/icons` set.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

Ten majors, one lookup site each, unchanged from v1.75.0: Core (`core/CoreSetup.lua:39`), Env
(`core/EnvSetup.lua:41`), Compat (`core/Compat.lua:36`), Lifecycle (`core/LifecycleSetup.lua:38`),
Media (`core/MediaSetup.lua:50`), DebugLog (`core/DebugLogSetup.lua:20`), Options
(`settings/OptionsSetup.lua:17`), Schema (`settings/SchemaSetup.lua:236`), Slash
(`settings/Slash.lua:129`) and Launcher (`core/LauncherSetup.lua:42`). It does not consume Widgets
(declined, #12) or Sim (WhatGroup#24), the two majors that moved.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION =' <tag>/testkit/framework.lua tests/_kit/framework.lua
# <tag>/testkit/framework.lua:20:Kit.VERSION = 41
# tests/_kit/framework.lua:20:Kit.VERSION = 41
```

Kit revision **41, unchanged**. Both payloads come from the one tag in one commit, so the pairing
rule holds by construction.

## 3g. Contract delta

Majors whose minor moved (Widgets, Sim) intersected with the majors this addon consumes: **none**.
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty.
The `tests/test_surface_parity.lua` stubs pin no Widgets or Sim member, and the suite stays green
after the copy. **No blockers.**

One stale comment follows the payload: `tests/loader.lua`'s LIBKA0S list named the Sim files at
"minor 2 each". It now names Sim minor 2, SimTimeline minor 3 and SimPanel minor 5 as of v1.76.0.
The list's order already matches the tag's XML, which did not change.

## 3h. Tags vendored and never recorded

```sh
# the standards audit's re-vendor walk (the command's step 3h), run before this copy
grep -vxF -f recorded.txt vendored.txt
# v1.75.1
# v1.75.2
```

v1.75.1 (`91d30b1`) and v1.75.2 (`8cbd735`) were vendored by the 2026-10-23 post-run fixes with no
bundle of their own. They are recorded in the span bundle written beside this one,
`docs/revendor/2026-10-23-v1.75.1-v1.75.2/`.

## 3i. The icon declaration

Unchanged and kept: `LibKa0s icons: close, copy, clear.`, the next non-blank line under the
provenance line. Its evidence is in `2026-10-22-v1.75.0/01_DELTA.md` 3i. v1.76.0 adds no
library-drawn name (the set is closed at v1.75.0, library-stack-§7), and `W.TestStrip`'s mark is
host art that this addon does not use. Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, and this repo's own `tests/test_mediasetup.lua:19`), so the owner's
in-client smoke stays the backstop: a pruned icon still resolves to a path and draws blank.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The hits are the declaration-driven cases written at v1.75.0. None opens a file for every catalog
name, so nothing is a blocker.
