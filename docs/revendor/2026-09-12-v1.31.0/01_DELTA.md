# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit`. The tag resolves to `30db4ed` ("The v1.31.0
release record"). `git -C ../LibKa0s tag --sort=-v:refname | head -1` answers `v1.31.0`, and the
sibling's working tree was clean.

Written before anything was copied. This is a non-interactive run (triage wave B2, 2026-09-12): the
owner decided in advance that WhatGroup migrates its harness onto the kit (#19, option 1), so the
decisions are recorded in `03_DECISIONS.md` without an interview.

This is the second re-vendor dated 2026-09-12. The first, v1.29.0 → v1.30.0, is the frozen bundle at
`docs/revendor/2026-09-12/`; this one takes the `-v1.31.0` suffix so that bundle stays untouched.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.30.0 (MIT). That line is the
```

The line sits mid-paragraph under `## Bundled LibKa0s`. Only the version moves.

## 3b — Actual version, before this run

```
grep -HoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 10, Pool 3, Slash 7, Widgets 9,
`WIDGETS_MINOR` 14, `COMPOSE_MINOR` 3, `SCROLL_MINOR` 3, `PANEL_MINOR` 5. These match v1.30.0's
release block, so the line and the bytes **agreed**.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | Constant | v1.30.0 | v1.31.0 |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other shipped file | as above | unchanged | unchanged |

Two secondary files of the Options major move. No file is behind the tag after the copy, so
**no cross-major skew is possible**.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua
diff -rq                    <tag>/testkit tests/_kit     # the same three
```

Five files differ in content, and the byte diff names the same five, so there is no line-ending
drift on either side. There are **no `Only in` lines**, so nothing was removed upstream and no
deletion inside either payload is warranted.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Core (`core/CoreSetup.lua:39`), Env (`core/EnvSetup.lua:41`), Media (`core/MediaSetup.lua:49`),
DebugLog (`core/DebugLogSetup.lua:20`), Options (`settings/OptionsSetup.lua:17`), Slash
(`settings/Slash.lua:64`). These are the six seams `CLAUDE.md` names; no seventh lookup site. Perf is
declined on structural grounds (LIBKA0S-15, WhatGroup#7). This release does not touch Perf, so that
premise is unchanged.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
<tag>/testkit/framework.lua:20:Kit.VERSION = 17
tests/_kit/framework.lua:20:Kit.VERSION = 16
```

Kit revision **16 → 17**. Both payloads are copied whole, in the same commit as the provenance line.
The pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11 in the same commit) is met by construction.

## Baseline gate, before the copy

`lua tests/run.lua`: 573 passed, 0 failed, 0 skipped, 573 total. `luacheck .`: 0 warnings / 0 errors
in 41 files. The runner is recorded `100755` in the index.
